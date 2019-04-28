//
//  ESCSaveToH264FileTool.m
//  ESCCameraH264Demo
//
//  Created by xiang on 2018/6/20.
//  Copyright © 2018年 xiang. All rights reserved.
//

#import "ESCSaveToH264FileTool.h"
#import "ESCVideoToolboxYUVToH264EncoderTool.h"

@interface ESCSaveToH264FileTool () <ESCVideoToolboxYUVToH264EncoderToolDelegate>

@property(nonatomic,strong)ESCVideoToolboxYUVToH264EncoderTool* yuvToH264EncoderTool;

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


/**
 yuv文件转h264压缩文件
 */
+ (void)yuvToH264EncoderWithVideoWidth:(NSInteger)width
                                height:(NSInteger)height
                           yuvFilePath:(NSString *)yuvFilePath
                          h264FilePath:(NSString *)h264FilePath
                             frameRate:(NSInteger)frameRate {
    
}

/**
 yuv流转h264压缩文件
 */
- (void)setupVideoWidth:(NSInteger)width
                 height:(NSInteger)height
              frameRate:(NSInteger)frameRate
           h264FilePath:(NSString *)h264FilePath {
    self.filePath = h264FilePath;
    if (self.filePath) {
        self.recordQueue = dispatch_queue_create("recordQueue", DISPATCH_QUEUE_SERIAL);
        dispatch_sync(self.recordQueue, ^{
            [[NSFileManager defaultManager] removeItemAtPath:self.filePath error:nil];
            [[NSFileManager defaultManager] createFileAtPath:self.filePath contents:nil attributes:nil];
            self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:self.filePath];
            self.width = width;
            self.height = height;
            self.frameRate = frameRate;
            ESCVideoToolboxYUVToH264EncoderTool *tool = [[ESCVideoToolboxYUVToH264EncoderTool alloc] init];
            self.yuvToH264EncoderTool = tool;
            [self.yuvToH264EncoderTool setupVideoWidth:width height:height frameRate:frameRate delegate:self];
        });
    }
}

/**
 填充需要压缩的yuv流数据
 */
- (void)encoderYUVData:(NSData *)yuvData {
    [self.yuvToH264EncoderTool encoderYUVData:yuvData];
}

- (void)stopRecord {
    [self.yuvToH264EncoderTool endYUVDataStream];
}

#pragma mark - ESCVideoToolboxYUVToH264EncoderToolDelegate
- (void)encoder:(ESCVideoToolboxYUVToH264EncoderTool *)encoder h264Data:(void *)h264Data dataLenth:(NSInteger)lenth {
    NSData *h264data = [NSData dataWithBytes:h264Data length:lenth];
//    NSLog(@"接收到数据");
    [self.fileHandle writeData:h264data];
}

- (void)encoderEnd:(ESCVideoToolboxYUVToH264EncoderTool *)encoder {
    dispatch_sync(self.recordQueue, ^{
        if (self.fileHandle) {
            [self.fileHandle closeFile];
        }
    });
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

@end
