//
//  ViewController.m
//  SilentCam
//
//  Created by shuichi on 12/12/02.
//  Copyright (c) 2012年 Shuichi Tsutsumi. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>



@interface ViewController ()
<AVCaptureVideoDataOutputSampleBufferDelegate>
{
    BOOL isRequireTakePhoto;
    BOOL isProcessingTakePhoto;
    void *bitmap;
}
@property (nonatomic, strong) IBOutlet UIView *previewView;
@property (nonatomic, strong) UIImage *imageBuffer;
@end



@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self initCamera];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}


#pragma mark -------------------------------------------------------------------
#pragma mark Private

- (void)initCamera {
    
    // バッファ作成
    size_t width = 640;
    size_t height = 480;
    bitmap = malloc(width * height * 4);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGDataProviderRef dataProviderRef = CGDataProviderCreateWithData(NULL, bitmap, width * height * 4, NULL);
    CGImageRef cgImage = CGImageCreate(width, height, 8, 32, width * 4, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst, dataProviderRef, NULL, 0, kCGRenderingIntentDefault);
    self.imageBuffer = [UIImage imageWithCGImage:cgImage];
    CGColorSpaceRelease(colorSpace);
    CGDataProviderRelease(dataProviderRef);
    
    // カメラデバイスの初期化
    AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    // 入力の初期化
    NSError *error = nil;
    AVCaptureInput *captureInput = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice
                                                                         error:&error];
    
    if (!captureInput) {
        NSLog(@"ERROR:%@", error);
        return;
    }
    
    // セッション初期化
    AVCaptureSession *captureSession = [[AVCaptureSession alloc] init];
    [captureSession addInput:captureInput];
    [captureSession beginConfiguration];
    //    captureSession.sessionPreset = AVCaptureSessionPresetPhoto;
    captureSession.sessionPreset = AVCaptureSessionPreset640x480;
    [captureSession commitConfiguration];
    
    // プレビュー表示
    AVCaptureVideoPreviewLayer *previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:captureSession];
    previewLayer.automaticallyAdjustsMirroring = NO;
    previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    previewLayer.frame = self.view.bounds;
    [self.previewView.layer insertSublayer:previewLayer atIndex:0];
    
    // 出力の初期化
    AVCaptureVideoDataOutput *videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    [captureSession addOutput:videoOutput];
    
    // ビデオデータ取得方法の設定
    videoOutput.videoSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    AVCaptureConnection *connection = [[videoOutput connections] lastObject];
    connection.videoMaxFrameDuration = CMTimeMake(1, 20);	// 20fps
    videoOutput.alwaysDiscardsLateVideoFrames = YES;
    dispatch_queue_t queue = dispatch_queue_create("com.overout223.myQueue", NULL);
    [videoOutput setSampleBufferDelegate:self
                                   queue:queue];
    dispatch_release(queue);
    
    
    // セッション開始
    [captureSession startRunning];
}



#pragma mark -------------------------------------------------------------------
#pragma mark AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    
    if (isRequireTakePhoto) {
        
        isRequireTakePhoto = NO;
        isProcessingTakePhoto = YES;
        
        CVPixelBufferRef pixbuff = CMSampleBufferGetImageBuffer(sampleBuffer);
        
        if(CVPixelBufferLockBaseAddress(pixbuff, 0) == kCVReturnSuccess){
            
            memcpy(bitmap, CVPixelBufferGetBaseAddress(pixbuff), 640 * 480 * 4);
            
            CMAttachmentMode attachmentMode;
            CFDictionaryRef metadataDictionary = CMGetAttachment(sampleBuffer, CFSTR("MetadataDictionary"), &attachmentMode);
            
            // フォトアルバムに保存
            ALAssetsLibrary* library = [[ALAssetsLibrary alloc] init];
            
            [library writeImageToSavedPhotosAlbum:self.imageBuffer.CGImage
                                         metadata:(NSDictionary *)CFBridgingRelease(metadataDictionary)
                                  completionBlock:^(NSURL *assetURL, NSError *error) {
                                      
                                      NSLog(@"URL:%@", assetURL);
                                      NSLog(@"error:%@", error);
                                      isProcessingTakePhoto = NO;
                                  }];
            
            CVPixelBufferUnlockBaseAddress(pixbuff, 0);
		}
	}
}



#pragma mark -------------------------------------------------------------------
#pragma mark IBAction

- (IBAction)pressShutter {
    
	if (!isProcessingTakePhoto) {
        
        isRequireTakePhoto = YES;
    }
}


@end
