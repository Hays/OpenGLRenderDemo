//
//  ViewController.m
//  OpenGLRenderDemo
//
//  Created by 黄文希 on 2018/7/12.
//  Copyright © 2018 Hays. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#include <assert.h>
#include <CoreServices/CoreServices.h>
#include <mach/mach.h>
#include <mach/mach_time.h>
#include <unistd.h>
#import <OpenGL/gl3.h>
#import "VideoGLView.h"

@interface ViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>

@property (weak) IBOutlet VideoGLView *openGLView;
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) dispatch_queue_t captureQueue;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.wantsLayer = YES;
    self.captureQueue = dispatch_queue_create("com.hays.opengl.capture", DISPATCH_QUEUE_SERIAL);
}

- (void)viewDidAppear {
    [super viewDidAppear];
    [self initCaptureSession];
    [self startSession];
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

- (void)startSession {
    if (![_captureSession isRunning]) {
        [_captureSession startRunning];
    }
}

- (void)stopSession {
    if ([_captureSession isRunning]) {
        [_captureSession stopRunning];
    }
}

- (void)initCaptureSession
{
    _captureSession = [[AVCaptureSession alloc] init];
    
    [_captureSession beginConfiguration];
    
    if ([_captureSession canSetSessionPreset:AVCaptureSessionPreset640x480])
        [_captureSession setSessionPreset:AVCaptureSessionPreset640x480];
    
    AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSCAssert(captureDevice, @"no device");
    
    NSError *error;
    AVCaptureDeviceInput *input = [[AVCaptureDeviceInput alloc] initWithDevice:captureDevice error:&error];
    [_captureSession addInput:input];
    
    //-- Create the output for the capture session.
    AVCaptureVideoDataOutput * dataOutput = [[AVCaptureVideoDataOutput alloc] init];
    [dataOutput setAlwaysDiscardsLateVideoFrames:YES]; // Probably want to set this to NO when recording
    
    for (int i = 0; i < dataOutput.availableVideoCVPixelFormatTypes.count; i++) {
        char fourr[5] = {0};
        *((int32_t *)fourr) = CFSwapInt32([dataOutput.availableVideoCVPixelFormatTypes[i] intValue]);
        NSLog(@"%s", fourr);
    }
    
    //-- Set to YUV420.
    [dataOutput setVideoSettings:@{(id)kCVPixelBufferPixelFormatTypeKey:[NSNumber numberWithInt:kCVPixelFormatType_24RGB],
                                   (id)kCVPixelBufferWidthKey:@960,
                                   (id)kCVPixelBufferHeightKey:@540}];
    
    // Set dispatch to be on the main thread so OpenGL can do things with the data
    [dataOutput setSampleBufferDelegate:self queue:self.captureQueue];
    
    NSAssert([_captureSession canAddOutput:dataOutput], @"can't output");
    
    [_captureSession addOutput:dataOutput];
    
    [_captureSession commitConfiguration];
    
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    static CMFormatDescriptionRef desc;
    if (!desc) {
        desc = CMSampleBufferGetFormatDescription(sampleBuffer);
        NSLog(@"%@", desc);
    }
    
    CVImageBufferRef buffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    [self.openGLView setImage:buffer];
    
    [self frameUpdate];
}

- (void)frameUpdate
{
    static int fps = 0;
    
    static uint64_t        start;
    uint64_t        end;
    uint64_t        elapsed;
    Nanoseconds     elapsedNano;
    
    // Start the clock.
    if (start == 0) {
        start = mach_absolute_time();
    }
    
    
    // Stop the clock.
    
    end = mach_absolute_time();
    
    // Calculate the duration.
    
    elapsed = end - start;
    
    // Convert to nanoseconds.
    
    // Have to do some pointer fun because AbsoluteToNanoseconds
    // works in terms of UnsignedWide, which is a structure rather
    // than a proper 64-bit integer.
    
    elapsedNano = AbsoluteToNanoseconds( *(AbsoluteTime *) &elapsed );
    
    if (* (uint64_t *) &elapsedNano > 1000000000ULL) {
//        NSLog(@"fps : %d", fps);
        fps = 0;
        start = end;
    }
    
    fps++;
    
}

@end
