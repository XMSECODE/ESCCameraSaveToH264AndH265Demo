//
//  ESCSaveToH265FileTool.h
//  ESCCameraH264Demo
//
//  Created by xiang on 5/31/19.
//  Copyright © 2019 xiang. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ESCSaveToH265FileTool : NSObject

@property(nonatomic,copy)NSString* filePath;

/**
 yuv文件转h265压缩文件
 */
+ (void)yuvToH264EncoderWithVideoWidth:(NSInteger)width
                                height:(NSInteger)height
                           yuvFilePath:(NSString *)yuvFilePath
                          h265FilePath:(NSString *)h265FilePath
                             frameRate:(NSInteger)frameRate;

/**
 yuv流转h265压缩文件
 */
- (void)setupVideoWidth:(NSInteger)width
                 height:(NSInteger)height
              frameRate:(NSInteger)frameRate
           h265FilePath:(NSString *)h265FilePath;

/**
 填充需要压缩的yuv流数据
 */
- (void)encoderYUVData:(NSData *)yuvData;

- (void)stopRecord;

@end

NS_ASSUME_NONNULL_END
