//
//  ESCVideoToolboxEncodeH264DataTool.h
//  ESCCameraH264Demo
//
//  Created by xiang on 2019/4/28.
//  Copyright © 2019 xiang. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


@class ESCVideoToolboxYUVToH264EncoderTool;

@protocol ESCVideoToolboxYUVToH264EncoderToolDelegate<NSObject>

/**
 压缩后的h264数据流
 */
- (void)encoder:(ESCVideoToolboxYUVToH264EncoderTool*)encoder h264Data:(void *)h264Data dataLenth:(NSInteger)lenth;

/**
 压缩结束
 */
- (void)encoderEnd:(ESCVideoToolboxYUVToH264EncoderTool *)encoder;

@end

@interface ESCVideoToolboxYUVToH264EncoderTool : NSObject


@property(nonatomic,weak)id delegate;

//sps和pps数据是否包含在关键帧前面，默认为YES
@property(nonatomic,assign)BOOL spsAndPpsIsIncludedInIframe;

/**
 yuv流转h264流
 */
- (void)setupVideoWidth:(NSInteger)width
                 height:(NSInteger)height
              frameRate:(NSInteger)frameRate
               delegate:(id<ESCVideoToolboxYUVToH264EncoderToolDelegate>)delegate;

/**
 填充需要压缩的yuv流数据
 */
- (void)encoderYUVData:(NSData *)yuvData;

/**
 yuv流数据接收完毕
 */
-(void)endYUVDataStream;

@end

NS_ASSUME_NONNULL_END
