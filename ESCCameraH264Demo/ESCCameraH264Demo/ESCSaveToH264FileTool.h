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

- (void)startRecordWithWidth:(NSInteger)width height:(NSInteger)height frameRate:(NSInteger)frameRate;

- (void)addFrame:(CMSampleBufferRef)sampleBufferRef;

- (void)stopRecord;

+ (NSData *)readDataFromSampleBufferRef:(CMSampleBufferRef)sampleBufferRef;

+ (NSData *)readDataFromBlockBuffer:(CMBlockBufferRef)dataBuffer;

@end
