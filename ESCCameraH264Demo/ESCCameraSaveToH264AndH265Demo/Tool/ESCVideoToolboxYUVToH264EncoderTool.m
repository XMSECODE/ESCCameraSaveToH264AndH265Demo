//
//  ESCVideoToolboxEncodeH264DataTool.m
//  ESCCameraH264Demo
//
//  Created by xiang on 2019/4/28.
//  Copyright © 2019 xiang. All rights reserved.
//

#import "ESCVideoToolboxYUVToH264EncoderTool.h"
#import <VideoToolbox/VideoToolbox.h>

@interface ESCVideoToolboxYUVToH264EncoderTool ()

@property(nonatomic,assign)NSInteger frameID;

@property(nonatomic,assign)VTCompressionSessionRef EncodingSession;

@property(nonatomic,assign)NSInteger width;

@property(nonatomic,assign)NSInteger height;

@property(nonatomic,assign)NSInteger frameRate;

@property(nonatomic,assign)BOOL initComplete;

@property(nonatomic,strong)dispatch_queue_t recordQueue;

@property(nonatomic,strong)NSData* spsData;

@property(nonatomic,strong)NSData* ppsData;

@end

@implementation ESCVideoToolboxYUVToH264EncoderTool

- (instancetype)init {
    self = [super init];
    if (self) {
        self.spsAndPpsIsIncludedInIframe = YES;
    }
    return self;
}

/**
 yuv流转h264流
 */
- (void)setupVideoWidth:(NSInteger)width
                 height:(NSInteger)height
              frameRate:(NSInteger)frameRate
               delegate:(id<ESCVideoToolboxYUVToH264EncoderToolDelegate>)delegate {
    self.delegate = delegate;
    self.recordQueue = dispatch_queue_create("recordQueue", DISPATCH_QUEUE_SERIAL);
    dispatch_sync(self.recordQueue, ^{
        self.width = width;
        self.height = height;
        self.frameRate = frameRate;
        [self initVideoToolBox];
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
                                                 didCompressToH264,
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

- (void)gotSpsPps:(NSData *)sps pps:(NSData *)pps {
    const uint8_t bytes[] = {0x00,0x00,0x00,0x01};
    NSData *ByteHeader = [NSData dataWithBytes:bytes length:4];
    NSMutableData *ppsData = [NSMutableData dataWithData:ByteHeader];
    [ppsData appendData:pps];
    NSMutableData *spsData = [NSMutableData dataWithData:ByteHeader];
    [spsData appendData:sps];
    self.spsData = spsData;
    self.ppsData = ppsData;
}

- (void)gotEncodedData:(NSData*)data isKeyFrame:(BOOL)isKeyFrame {
    if (isKeyFrame == YES) {
        if (self.spsAndPpsIsIncludedInIframe == YES) {
            if (self.delegate && [self.delegate respondsToSelector:@selector(encoder:h264Data:dataLenth:)]) {
                uint8_t index = 0;
                uint8_t *h264data = malloc(data.length + 4 + self.spsData.length + self.ppsData.length);
                
                uint8_t *ppsPoint = (uint8_t *)[self.ppsData bytes];
                memcpy(h264data + index, ppsPoint, self.ppsData.length);
                index += self.ppsData.length;
                
                uint8_t *spsPoint = (uint8_t *)[self.spsData bytes];
                memcpy(h264data + index, spsPoint, self.spsData.length);
                index += self.spsData.length;
                
                const uint8_t bytes[] = {0x00,0x00,0x00,0x01};
                memcpy(h264data + index, bytes, 4);
                index += 4;
                
                uint8_t *h264Point = (uint8_t *)[data bytes];
                memcpy(h264data + index, h264Point, data.length);
                
                [self.delegate encoder:self h264Data:h264data dataLenth:data.length + 4 + self.spsData.length + self.ppsData.length];
                free(h264data);
            }
        }else {
            if (self.delegate && [self.delegate respondsToSelector:@selector(encoder:h264Data:dataLenth:)]) {
                if (self.ppsData) {
                    uint8_t *ppsPoint = (uint8_t *)[self.ppsData bytes];
                    [self.delegate encoder:self h264Data:ppsPoint dataLenth:self.ppsData.length];
                }
                if (self.spsData) {
                    uint8_t *spsPoint = (uint8_t *)[self.spsData bytes];
                    [self.delegate encoder:self h264Data:spsPoint dataLenth:self.spsData.length];
                }
                uint8_t *h264data = malloc(data.length + 4);
                const uint8_t bytes[] = {0x00,0x00,0x00,0x01};
                memcpy(h264data, bytes, 4);
                uint8_t *h264Point = (uint8_t *)[data bytes];
                memcpy(h264data + 4, h264Point, data.length);
                [self.delegate encoder:self h264Data:h264data dataLenth:data.length + 4];
                free(h264data);
            }
        }
    }else {
        if (self.delegate && [self.delegate respondsToSelector:@selector(encoder:h264Data:dataLenth:)]) {
            uint8_t *h264data = malloc(data.length + 4);
            const uint8_t bytes[] = {0x00,0x00,0x00,0x01};
            memcpy(h264data, bytes, 4);
            uint8_t *h264Point = (uint8_t *)[data bytes];
            memcpy(h264data + 4, h264Point, data.length);
            [self.delegate encoder:self h264Data:h264data dataLenth:data.length + 4];
            free(h264data);
        }
    }
}

+ (NSData *)readDataFromSampleBufferRef:(CMSampleBufferRef)sampleBufferRef {
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBufferRef);
    return [self readDataFromBlockBuffer:dataBuffer];
}

+ (NSData *)readDataFromBlockBuffer:(CMBlockBufferRef)dataBuffer {
    size_t length, totalLength;
    char *dataPointer;
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    if (statusCodeRet == noErr) {
        NSData* data = [[NSData alloc] initWithBytes:dataPointer length:totalLength];
        return data;
    }
    return nil;
}

void didCompressToH264(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags, CMSampleBufferRef sampleBuffer) {
    //    NSLog(@"didCompressH264 called with status %d infoFlags %d", (int)status, (int)infoFlags);
    if (status != 0) {
        return;
    }
    
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
        NSLog(@"didCompressH264 data is not ready ");
        return;
    }
    ESCVideoToolboxYUVToH264EncoderTool* encoder = (__bridge ESCVideoToolboxYUVToH264EncoderTool *)outputCallbackRefCon;
    
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
    
    //读取数据
    NSData *resultData = [ESCVideoToolboxYUVToH264EncoderTool readDataFromSampleBufferRef:sampleBuffer];
    if (resultData != nil) {
        size_t bufferOffset = 0;
        static const int AVCCHeaderLength = 4; // 返回的nalu数据前四个字节不是0001的startcode，而是大端模式的帧长度length
        // 循环获取nalu数据
        while (bufferOffset < resultData.length - AVCCHeaderLength) {
            uint32_t NALUnitLength = 0;
            [resultData getBytes:&NALUnitLength range:NSMakeRange(bufferOffset, AVCCHeaderLength)];
            
            // 从大端转系统端
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            NSData *getData = [resultData subdataWithRange:NSMakeRange(AVCCHeaderLength + bufferOffset, NALUnitLength)];
            [encoder gotEncodedData:getData isKeyFrame:keyframe];
            //            NSLog(@"%lu",(unsigned long)getData.length);
            // Move to the next NAL unit in the block buffer
            bufferOffset += AVCCHeaderLength + NALUnitLength;
        }
    }
}

- (void)EndVideoToolBox {
    VTCompressionSessionCompleteFrames(_EncodingSession, kCMTimeInvalid);
    VTCompressionSessionInvalidate(_EncodingSession);
    CFRelease(_EncodingSession);
    _EncodingSession = NULL;
    if (self.delegate && [self.delegate respondsToSelector:@selector(encoderEnd:)]) {
        [self.delegate encoderEnd:self];
    }
}


/**
 填充需要压缩的yuv流数据
 */
- (void)encoderYUVData:(NSData *)yuvData {
    dispatch_sync(self.recordQueue, ^{
        if (self.initComplete == YES) {
//            [self encode:sampleBufferRef];
            CVPixelBufferRef pixeBuffer;
            CVReturn result = CVPixelBufferCreate(NULL, self.width, self.height, kCVPixelFormatType_420YpCbCr8Planar, NULL, &pixeBuffer);
            if (result == kCVReturnSuccess) {
                CVPixelBufferLockBaseAddress(pixeBuffer, 0);
                uint8_t *yPoint = CVPixelBufferGetBaseAddressOfPlane(pixeBuffer, 0);
                uint8_t *uPoint = CVPixelBufferGetBaseAddressOfPlane(pixeBuffer, 1);
                uint8_t *vPoint = CVPixelBufferGetBaseAddressOfPlane(pixeBuffer, 2);
                uint8_t *yuvPoint = (uint8_t *)[yuvData bytes];
                memcpy(yPoint, yuvPoint, self.width * self.height);
                memcpy(uPoint, yuvPoint + self.width * self.height, self.width * self.height / 4);
                memcpy(vPoint, yuvPoint + self.width * self.height * 5 / 4, self.width * self.height / 4);
                CVPixelBufferUnlockBaseAddress(pixeBuffer, 0);
                [self encode:pixeBuffer];
            }else {
                NSLog(@"创建 CVPixelBufferRef 失败。");
            }
        }
    });
}

- (void)encode:(CVPixelBufferRef)imageBuffer {
    // 帧时间，如果不设置会导致时间轴过长。
    CMTime presentationTimeStamp = CMTimeMake(self.frameID++, 1000);
    VTEncodeInfoFlags flags;
    OSStatus statusCode = VTCompressionSessionEncodeFrame(_EncodingSession,
                                                          imageBuffer,
                                                          presentationTimeStamp,
                                                          kCMTimeInvalid,
                                                          NULL, NULL, &flags);
    CVPixelBufferRelease(imageBuffer);
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

/**
 yuv流数据接收完毕
 */
-(void)endYUVDataStream {
    [self EndVideoToolBox];
}

@end
