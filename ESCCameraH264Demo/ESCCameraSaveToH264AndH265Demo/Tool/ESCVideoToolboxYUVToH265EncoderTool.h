//
//  ESCVideoToolboxYUVToH265EncoderTool.h
//  ESCCameraH264Demo
//
//  Created by xiang on 5/31/19.
//  Copyright © 2019 xiang. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ESCVideoToolboxYUVToH265EncoderTool;

@protocol ESCVideoToolboxYUVToH265EncoderToolDelegate<NSObject>

/**
 压缩后的h265数据流
 */
- (void)encoder:(ESCVideoToolboxYUVToH265EncoderTool*)encoder h265Data:(void *)h25Data dataLenth:(NSInteger)lenth;

/**
 压缩结束
 */
- (void)encoderEnd:(ESCVideoToolboxYUVToH265EncoderTool *)encoder;

@end

@interface ESCVideoToolboxYUVToH265EncoderTool : NSObject

//ios 11系统，iphone 7及以后的设备才支持h265硬编码

@property(nonatomic,weak)id delegate;

//sps和pps数据是否包含在关键帧前面，默认为YES
@property(nonatomic,assign)BOOL spsAndPpsIsIncludedInIframe;

/**
 yuv流转h265流
 */
- (void)setupVideoWidth:(NSInteger)width
                 height:(NSInteger)height
              frameRate:(NSInteger)frameRate
               delegate:(id<ESCVideoToolboxYUVToH265EncoderToolDelegate>)delegate;

/**
 填充需要压缩的yuv流数据
 */
- (void)encoderYUVData:(NSData *)yuvData;

/**
 yuv流数据接收完毕
 */
-(void)endYUVDataStream;

@end


