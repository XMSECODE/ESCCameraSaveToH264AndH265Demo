//
//  ESCSaveToH264FileTool.h
//  ESCCameraH264Demo
//
//  Created by xiang on 2018/6/20.
//  Copyright © 2018年 xiang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>

@interface ESCSaveToH264FileTool : NSObject

@property(nonatomic,copy)NSString* filePath;

/**
 yuv文件转h264压缩文件
 */
+ (void)yuvToH264EncoderWithVideoWidth:(NSInteger)width
                                height:(NSInteger)height
                           yuvFilePath:(NSString *)yuvFilePath
                          h264FilePath:(NSString *)h264FilePath
                             frameRate:(NSInteger)frameRate;

/**
 yuv流转h264压缩文件
 */
- (void)setupVideoWidth:(NSInteger)width
                 height:(NSInteger)height
              frameRate:(NSInteger)frameRate
           h264FilePath:(NSString *)h264FilePath;

/**
 填充需要压缩的yuv流数据
 */
- (void)encoderYUVData:(NSData *)yuvData;

- (void)stopRecord;

@end
