//
//  ESCSaveToH264FileTool.m
//  ESCCameraH264Demo
//
//  Created by xiang on 2018/6/20.
//  Copyright © 2018年 xiang. All rights reserved.
//

#import "ESCSaveToH264FileTool.h"

@interface ESCSaveToH264FileTool ()

@property(nonatomic,strong)NSFileHandle* fileHandle;

@property(nonatomic,assign)NSInteger frameID;

@property(nonatomic,assign)VTCompressionSessionRef EncodingSession;

@property(nonatomic,assign)NSInteger width;

@property(nonatomic,assign)NSInteger height;

@property(nonatomic,assign)NSInteger frameRate;

@property(nonatomic,assign)BOOL initComplete;

@property(nonatomic,strong)dispatch_queue_t recordQueue;

@end

@implementation ESCSaveToH264FileTool

- (void)startRecordWithWidth:(NSInteger)width height:(NSInteger)height frameRate:(NSInteger)frameRate{
    if (self.filePath) {
        self.recordQueue = dispatch_queue_create("recordQueue", DISPATCH_QUEUE_SERIAL);
        dispatch_sync(self.recordQueue, ^{
            [[NSFileManager defaultManager] removeItemAtPath:self.filePath error:nil];
            [[NSFileManager defaultManager] createFileAtPath:self.filePath contents:nil attributes:nil];
            self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:self.filePath];
            self.width = width;
            self.height = height;
            self.frameRate = frameRate;
            [self initVideoToolBox];
        });
    }
}

- (void)addFrame:(CMSampleBufferRef)sampleBufferRef {
    dispatch_sync(self.recordQueue, ^{
        if (self.fileHandle && self.initComplete == YES) {
            [self encode:sampleBufferRef];
        }
    });
}

- (void)stopRecord {
    dispatch_sync(self.recordQueue, ^{
        if (self.fileHandle) {
            [self.fileHandle closeFile];
            [self EndVideoToolBox];
        }
    });
}



- (void)initVideoToolBox {
    
    self.frameID = 0;
    
    int width = (int)self.width;
    int height = (int)self.height;
    //创建编码会话对象
    OSStatus status = VTCompressionSessionCreate(NULL,
                                                 width,
                                                 height,
                                                 kCMVideoCodecType_H264,
                                                 NULL,
                                                 NULL,
                                                 NULL,
                                                 didCompressH264,
                                                 (__bridge void *)(self),
                                                 &self->_EncodingSession
                                                 );
    
    NSLog(@"H264: VTCompressionSessionCreate %d", (int)status);
    if (status != 0) {
        NSLog(@"H264: Unable to create a H264 session");
        self.EncodingSession = NULL;
        return ;
    }
    // 设置实时编码输出（避免延迟）
    VTSessionSetProperty(self->_EncodingSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
    // h264 profile, 直播一般使用baseline，可减少由于b帧带来的延时
    VTSessionSetProperty(self->_EncodingSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Baseline_AutoLevel);
    
    // 设置关键帧（GOPsize)间隔
    int frameInterval = (int)(self.frameRate / 2);
    CFNumberRef  frameIntervalRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &frameInterval);
    VTSessionSetProperty(self->_EncodingSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, frameIntervalRef);
    
    // 设置期望帧率
    int fps = (int)self.frameRate;
    CFNumberRef fpsRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &fps);
    VTSessionSetProperty(self->_EncodingSession, kVTCompressionPropertyKey_ExpectedFrameRate, fpsRef);
    
    //不产生B帧
    VTSessionSetProperty(self->_EncodingSession, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse);
    
    // 设置编码码率(比特率)，如果不设置，默认将会以很低的码率编码，导致编码出来的视频很模糊
    // 设置码率，上限，单位是bps
    int bitRate = width * height * 3 * 4 * 8;
    CFNumberRef bitRateRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &bitRate);
    VTSessionSetProperty(self->_EncodingSession, kVTCompressionPropertyKey_AverageBitRate, bitRateRef);
    // 设置码率，均值，单位是byte
    int bitRateLimit = width * height * 3 * 4;
    CFNumberRef bitRateLimitRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &bitRateLimit);
    VTSessionSetProperty(self->_EncodingSession, kVTCompressionPropertyKey_DataRateLimits, bitRateLimitRef);
    
    // Tell the encoder to start encoding
    status = VTCompressionSessionPrepareToEncodeFrames(self->_EncodingSession);
    if (status == 0) {
        self.initComplete = YES;
    }else {
        NSLog(@"init compression session prepare to encode frames failure");
    } 
}

- (void)encode:(CMSampleBufferRef)sampleBuffer {
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // 帧时间，如果不设置会导致时间轴过长。
    CMTime presentationTimeStamp = CMTimeMake(self.frameID++, 1000);
    VTEncodeInfoFlags flags;
    OSStatus statusCode = VTCompressionSessionEncodeFrame(_EncodingSession,
                                                          imageBuffer,
                                                          presentationTimeStamp,
                                                          kCMTimeInvalid,
                                                          NULL, NULL, &flags);
    if (statusCode != noErr) {
        if(_EncodingSession != NULL) {
            NSLog(@"H264: VTCompressionSessionEncodeFrame failed with %d", (int)statusCode);
            VTCompressionSessionInvalidate(_EncodingSession);
            CFRelease(_EncodingSession);
            _EncodingSession = NULL;
            NSLog(@"encodingSession release");
            return;
        }
    }
//    NSLog(@"H264: VTCompressionSessionEncodeFrame Success");
}

- (void)gotSpsPps:(NSData *)sps pps:(NSData *)pps {
//    NSLog(@"gotSpsPps %d %d", (int)[sps length], (int)[pps length]);
    const char bytes[] = "\x00\x00\x00\x01";
    NSData *ByteHeader = [NSData dataWithBytes:bytes length:4];
    [self.fileHandle writeData:ByteHeader];
    [self.fileHandle writeData:sps];
    [self.fileHandle writeData:ByteHeader];
    [self.fileHandle writeData:pps];
    
}

- (void)gotEncodedData:(NSData*)data isKeyFrame:(BOOL)isKeyFrame {
//    NSLog(@"gotEncodedData %d", (int)[data length]);
    if (self.fileHandle != NULL)
    {
        const char bytes[] = "\x00\x00\x00\x01";
        size_t length = (sizeof bytes) - 1; //string literals have implicit trailing '\0'
        NSData *ByteHeader = [NSData dataWithBytes:bytes length:length];
        [self.fileHandle writeData:ByteHeader];
        [self.fileHandle writeData:data];
    }
}

- (void)EndVideoToolBox {
    VTCompressionSessionCompleteFrames(_EncodingSession, kCMTimeInvalid);
    VTCompressionSessionInvalidate(_EncodingSession);
    CFRelease(_EncodingSession);
    _EncodingSession = NULL;
}

void didCompressH264(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags, CMSampleBufferRef sampleBuffer) {
//    NSLog(@"didCompressH264 called with status %d infoFlags %d", (int)status, (int)infoFlags);
    if (status != 0) {
        return;
    }
    
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
        NSLog(@"didCompressH264 data is not ready ");
        return;
    }
    ESCSaveToH264FileTool* encoder = (__bridge ESCSaveToH264FileTool *)outputCallbackRefCon;
    
    bool keyframe = !CFDictionaryContainsKey( (CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0)), kCMSampleAttachmentKey_NotSync);
    // 判断当前帧是否为关键帧
    // 获取sps & pps数据
    if (keyframe) {
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        size_t spsSize, spsCount;
        const uint8_t *sparameterSet;
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sparameterSet, &spsSize, &spsCount, 0 );
        if (statusCode == noErr) {
            // Found sps and now check for pps
            size_t ppsSize, ppsCount;
            const uint8_t *pparameterSet;
            OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pparameterSet, &ppsSize, &ppsCount, 0 );
            if (statusCode == noErr) {
                // Found pps
                NSData *sps = [NSData dataWithBytes:sparameterSet length:spsSize];
                NSData *pps = [NSData dataWithBytes:pparameterSet length:ppsSize];
                if (encoder) {
                    [encoder gotSpsPps:sps pps:pps];
                }
            }
        }
    }
    
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char *dataPointer;
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    if (statusCodeRet == noErr) {
        size_t bufferOffset = 0;
        static const int AVCCHeaderLength = 4; // 返回的nalu数据前四个字节不是0001的startcode，而是大端模式的帧长度length
        
        // 循环获取nalu数据
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            uint32_t NALUnitLength = 0;
            // Read the NAL unit length
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);
            
            // 从大端转系统端
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            
            NSData* data = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength];
            [encoder gotEncodedData:data isKeyFrame:keyframe];
            
            // Move to the next NAL unit in the block buffer
            bufferOffset += AVCCHeaderLength + NALUnitLength;
        }
    }
}


@end
