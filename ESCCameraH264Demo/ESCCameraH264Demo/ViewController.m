//
//  ViewController.m
//  ESCCameraH264Demo
//
//  Created by xiang on 2018/6/20.
//  Copyright © 2018年 xiang. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>
#import "ESCSaveToH264FileTool.h"
#import "ESCSaveToH265FileTool.h"

@interface ViewController () <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (strong, nonatomic) IBOutlet UIButton *recordToH264Button;

@property(nonatomic,strong)AVCaptureSession* captureSession;

@property (nonatomic, strong) AVCaptureVideoDataOutput *videoDataOutput;

@property(nonatomic,assign)BOOL isRecording;

@property(nonatomic,strong)dispatch_queue_t videoDataOutputQueue;

@property(nonatomic,strong)ESCSaveToH264FileTool* h264Tool;

@property(nonatomic,strong)ESCSaveToH265FileTool* h265Tool;

@property(nonatomic,strong)NSDateFormatter* dateFormatter;

@property(nonatomic,strong)NSFileHandle* temFileHandle;

@property(nonatomic,assign)int yuvFrameCount;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSString *filePath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask , YES).lastObject;
    filePath = [NSString stringWithFormat:@"%@/tem1280_720.yuv",filePath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath] == NO) {
    }else {
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
    }
    [[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil];
    
//    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
//    self.temFileHandle = fileHandle;
    
    [self initCapureSession];

}

- (IBAction)didClickRecordToH264Button:(id)sender {
    if (self.isRecording) {
        [self.recordToH264Button setTitle:@"start record video to H264" forState:UIControlStateNormal];
        [self.captureSession stopRunning];
        [self.h264Tool stopRecord];
        [self.h265Tool stopRecord];
        NSLog(@"结束");
    }else {
        [self.recordToH264Button setTitle:@"stop record video to H264" forState:UIControlStateNormal];
        [self.captureSession startRunning];
        
        self.h264Tool = [[ESCSaveToH264FileTool alloc] init];
        NSString *filePath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).lastObject;
        NSString *h264FilePath = [NSString stringWithFormat:@"%@/%@.h264",filePath,[self.dateFormatter stringFromDate:[NSDate date]]];
        [self.h264Tool setupVideoWidth:1280 height:720 frameRate:25 h264FilePath:h264FilePath];
        
        self.h265Tool = [[ESCSaveToH265FileTool alloc] init];
        NSString *h265FilePath = [NSString stringWithFormat:@"%@/%@.h265",filePath,[self.dateFormatter stringFromDate:[NSDate date]]];
        [self.h265Tool setupVideoWidth:1280 height:720 frameRate:25 h265FilePath:h265FilePath];
        NSLog(@"开始");
    }
    self.isRecording = !self.isRecording;
}

-(void)initCapureSession{
    //创建AVCaptureDevice的视频设备对象
    AVCaptureDevice* videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    NSError* error;
    //创建视频输入端对象
    AVCaptureDeviceInput* input = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
    if (error) {
        NSLog(@"创建输入端失败,%@",error);
        return;
    }
    
    //创建功能会话对象
    self.captureSession = [[AVCaptureSession alloc] init];
    //设置会话输出的视频分辨率
    /*
     AVCaptureSessionPreset1920x1080
     AVCaptureSessionPreset1280x720
     AVCaptureSessionPreset960x540
     iphone 6处理1080p的视频性能不足
     iphone 6s可以处理1080p视频
     */
    
    [self.captureSession setSessionPreset:AVCaptureSessionPreset1280x720];
    
    //添加输入端
    if (![self.captureSession canAddInput:input]) {
        NSLog(@"输入端添加失败");
        return;
    }
    [self.captureSession addInput:input];
    
    //显示摄像头捕捉到的数据
    AVCaptureVideoPreviewLayer* layer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
    layer.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height - 100);
    [self.view.layer addSublayer:layer];
    
    //创建输出端
    AVCaptureVideoDataOutput *videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    //会话对象添加输出端
    if ([self.captureSession canAddOutput:videoDataOutput]) {
        [self.captureSession addOutput:videoDataOutput];
        self.videoDataOutput = videoDataOutput;
        //创建输出调用的队列
        dispatch_queue_t videoDataOutputQueue = dispatch_queue_create("videoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
        self.videoDataOutputQueue = videoDataOutputQueue;
        //设置代理和调用的队列
        [self.videoDataOutput setSampleBufferDelegate:self queue:videoDataOutputQueue];
        //设置延时丢帧
        self.videoDataOutput.alwaysDiscardsLateVideoFrames = NO;
    }
}


#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    NSData *yuvData = [self getYUV420DataWithPixelBuffer:sampleBuffer];
    if (self.h264Tool && self.isRecording) {
        [self.h264Tool encoderYUVData:yuvData];
        [self.h265Tool encoderYUVData:yuvData];
    }
}

- (NSData *)getYUV420DataWithPixelBuffer:(CMSampleBufferRef)sampleBuffer {
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
    void *y_data = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
    void *uv_data = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 1);
    
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    //420v 数据分布
    /*
     struct CVPlanarPixelBufferInfo_YCbCrBiPlanar {
     CVPlanarComponentInfo  componentInfoY;
     CVPlanarComponentInfo  componentInfoCbCr;
     };
     */
    NSData *ydata = [NSData dataWithBytes:y_data length:width * height];
    NSMutableData *uData = [NSMutableData data];
    NSMutableData *vData = [NSMutableData data];
    for (int i = 0; i < width * height / 2; i++) {
        [uData appendBytes:(uv_data + i) length:1];
        i++;
        [vData appendBytes:(uv_data + i) length:1];
    }
    
    NSMutableData *yuvData = [NSMutableData data];
    [yuvData appendData:ydata];
    [yuvData appendData:uData];
    [yuvData appendData:vData];
    
    if (self.yuvFrameCount <= 200) {
        [self.temFileHandle writeData:ydata];
        [self.temFileHandle writeData:uData];
        [self.temFileHandle writeData:vData];
        self.yuvFrameCount++;
    }else {
        [self.temFileHandle closeFile];
        self.temFileHandle = nil;
    }
    CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
    
    return yuvData;
}

- (void)captureOutput:(AVCaptureOutput *)output didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection NS_AVAILABLE(10_7, 6_0) {
    NSLog(@"did drop %@",output);
}


#pragma mark - getter
- (NSDateFormatter *)dateFormatter {
    if (_dateFormatter == nil) {
        _dateFormatter = [[NSDateFormatter alloc] init];
        _dateFormatter.dateFormat = @"yyyy_MM_dd_HH_mm_ss";
    }
    return _dateFormatter;
}
@end
