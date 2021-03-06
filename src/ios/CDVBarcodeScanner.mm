/*
 * PhoneGap is available under *either* the terms of the modified BSD license *or* the
 * MIT License (2008). See http://opensource.org/licenses/alphabetical for full text.
 *
 * Copyright 2011 Matt Kane. All rights reserved.
 * Copyright (c) 2011, IBM Corporation
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <AudioToolbox/AudioToolbox.h>

//------------------------------------------------------------------------------
// use the all-in-one version of zxing that we built
//------------------------------------------------------------------------------
#import "zxing-all-in-one.h"
#import <Cordova/CDVPlugin.h>


//------------------------------------------------------------------------------
// Delegate to handle orientation functions
//------------------------------------------------------------------------------
@protocol CDVBarcodeScannerOrientationDelegate <NSObject>

- (NSUInteger)supportedInterfaceOrientations;
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;
- (BOOL)shouldAutorotate;

    @end

//------------------------------------------------------------------------------
// Adds a shutter button to the UI, and changes the scan from continuous to
// only performing a scan when you click the shutter button.  For testing.
//------------------------------------------------------------------------------
#define USE_SHUTTER 0

//------------------------------------------------------------------------------
@class CDVbcsProcessor;
@class CDVbcsViewController;

//------------------------------------------------------------------------------
// plugin class
//------------------------------------------------------------------------------
@interface CDVBarcodeScanner : CDVPlugin {}
- (NSString*)isScanNotPossible;
- (void)scan:(CDVInvokedUrlCommand*)command;
- (void)encode:(CDVInvokedUrlCommand*)command;
- (void)returnImage:(NSString*)filePath format:(NSString*)format callback:(NSString*)callback;
- (void)returnSuccess:(NSString*)scannedText format:(NSString*)format cancelled:(BOOL)cancelled flipped:(BOOL)flipped callback:(NSString*)callback;
- (void)returnError:(NSString*)message callback:(NSString*)callback;
    @end

//------------------------------------------------------------------------------
// class that does the grunt work
//------------------------------------------------------------------------------
@interface CDVbcsProcessor : NSObject <AVCaptureMetadataOutputObjectsDelegate> {}
    @property (nonatomic, retain) CDVBarcodeScanner*           plugin;
    @property (nonatomic, retain) NSString*                   callback;
    @property (nonatomic, retain) UIViewController*           parentViewController;
    @property (nonatomic, retain) CDVbcsViewController*        viewController;
    @property (nonatomic, retain) AVCaptureSession*           captureSession;
    @property (nonatomic, retain) AVCaptureVideoPreviewLayer* previewLayer;
    @property (nonatomic, retain) NSString*                   alternateXib;
    @property (nonatomic, retain) NSMutableArray*             results;
    @property (nonatomic, retain) NSString*                   formats;
    @property (nonatomic)         BOOL                        is1D;
    @property (nonatomic)         BOOL                        is2D;
    @property (nonatomic)         BOOL                        capturing;
    @property (nonatomic)         BOOL                        isFrontCamera;
    @property (nonatomic)         BOOL                        isShowFlipCameraButton;
    @property (nonatomic)         BOOL                        isFlipped;


- (id)initWithPlugin:(CDVBarcodeScanner*)plugin callback:(NSString*)callback parentViewController:(UIViewController*)parentViewController alterateOverlayXib:(NSString *)alternateXib;
- (void)scanBarcode;
- (void)barcodeScanSucceeded:(NSString*)text format:(NSString*)format;
- (void)barcodeScanRedirect:(NSString*)text format:(NSString*)format;
- (void)barcodeScanFailed:(NSString*)message;
- (void)barcodeScanCancelled;
- (void)openDialog;
- (NSString*)setUpCaptureSession;
- (void)captureOutput:(AVCaptureOutput*)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection*)connection;
- (NSString*)formatStringFrom:(zxing::BarcodeFormat)format;
- (UIImage*)getImageFromSample:(CMSampleBufferRef)sampleBuffer;
- (zxing::Ref<zxing::LuminanceSource>) getLuminanceSourceFromSample:(CMSampleBufferRef)sampleBuffer imageBytes:(uint8_t**)ptr;
- (UIImage*) getImageFromLuminanceSource:(zxing::LuminanceSource*)luminanceSource;
- (void)dumpImage:(UIImage*)image;
    @end

//------------------------------------------------------------------------------
// Qr encoder processor
//------------------------------------------------------------------------------
@interface CDVqrProcessor: NSObject
    @property (nonatomic, retain) CDVBarcodeScanner*          plugin;
    @property (nonatomic, retain) NSString*                   callback;
    @property (nonatomic, retain) NSString*                   stringToEncode;
    @property                     NSInteger                   size;

- (id)initWithPlugin:(CDVBarcodeScanner*)plugin callback:(NSString*)callback stringToEncode:(NSString*)stringToEncode;
- (void)generateImage;
    @end

//------------------------------------------------------------------------------
// view controller for the ui
//------------------------------------------------------------------------------
@interface CDVbcsViewController : UIViewController <CDVBarcodeScannerOrientationDelegate> {}
    @property (nonatomic, retain) CDVbcsProcessor*  processor;
    @property (retain, nonatomic) IBOutlet UIButton *menuButton;
    @property (retain, nonatomic) IBOutlet UIButton *searchTextButton;
    @property (retain, nonatomic) IBOutlet UIButton *homeButton;
    @property (retain, nonatomic) IBOutlet UIButton *flashButton;
    @property (retain, nonatomic) IBOutlet UIButton *reportErrorButton;
    @property (nonatomic, retain) NSString*        alternateXib;
    @property (nonatomic)         BOOL             shutterPressed;
    @property (nonatomic, retain) IBOutlet UIView* overlayView;
    // unsafe_unretained is equivalent to assign - used to prevent retain cycles in the property below
    @property (nonatomic, unsafe_unretained) id orientationDelegate;
    @property (strong, nonatomic) IBOutlet UITextField *searchTextField;
    @property (retain, nonatomic) IBOutlet UIButton *errorReportButton;
    @property (strong, nonatomic) IBOutlet UIView *searchTextView;
    @property (strong, nonatomic) IBOutlet UIView *erroReportView;
    @property (strong, nonatomic) IBOutlet UIScrollView *scrollviewTextSearch;
    @property (nonatomic) UITapGestureRecognizer *tapRecognizer;

- (IBAction)pressSearch:(id)sender;
- (IBAction)pressError:(id)sender;
- (IBAction)pressErrorReport:(id)sender;
- (IBAction)pressBulas:(id)sender;

- (id)initWithProcessor:(CDVbcsProcessor*)processor alternateOverlay:(NSString *)alternateXib;
- (void)startCapturing;
- (UIView*)buildOverlayView: (UIView*)overlayView;
- (UIImage*)buildReticleImage;
- (void)shutterButtonPressed;
- (IBAction)cancelButtonPressed:(id)sender;

    @end

//------------------------------------------------------------------------------
// plugin class
//------------------------------------------------------------------------------
@implementation CDVBarcodeScanner

    //--------------------------------------------------------------------------
- (NSString*)isScanNotPossible {
    NSString* result = nil;

    Class aClass = NSClassFromString(@"AVCaptureSession");
    if (aClass == nil) {
        return @"AVFoundation Framework not available";
    }

    return result;
}

-(BOOL)notHasPermission
    {
        AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
        return (authStatus == AVAuthorizationStatusDenied ||
                authStatus == AVAuthorizationStatusRestricted);
    }



    //--------------------------------------------------------------------------
- (void)scan:(CDVInvokedUrlCommand*)command {
    CDVbcsProcessor* processor;
    NSString*       callback;
    NSString*       capabilityError;

    callback = command.callbackId;

    NSDictionary* options = command.arguments.count == 0 ? [NSNull null] : [command.arguments objectAtIndex:0];

    if ([options isKindOfClass:[NSNull class]]) {
        options = [NSDictionary dictionary];
    }
    BOOL preferFrontCamera = [options[@"preferFrontCamera"] boolValue];
    BOOL showFlipCameraButton = [options[@"showFlipCameraButton"] boolValue];
    // We allow the user to define an alternate xib file for loading the overlay.
    NSString *overlayXib = @"scannerOverlay"; //[options objectForKey:@"overlayXib"];

    capabilityError = [self isScanNotPossible];
    if (capabilityError) {
        [self returnError:capabilityError callback:callback];
        return;
    } else if ([self notHasPermission]) {
        NSString * error = NSLocalizedString(@"Access to the camera has been prohibited; please enable it in the Settings app to continue.",nil);
        [self returnError:error callback:callback];
        return;
    }

    processor = [[CDVbcsProcessor alloc]
                 initWithPlugin:self
                 callback:callback
                 parentViewController:self.viewController
                 alterateOverlayXib:overlayXib
                 ];
    // queue [processor scanBarcode] to run on the event loop

    if (preferFrontCamera) {
        processor.isFrontCamera = true;
    }

    if (showFlipCameraButton) {
        processor.isShowFlipCameraButton = true;
    }

    processor.formats = options[@"formats"];

    [processor performSelector:@selector(scanBarcode) withObject:nil afterDelay:0];
}

    //--------------------------------------------------------------------------
- (void)encode:(CDVInvokedUrlCommand*)command {
    if([command.arguments count] < 1)
    [self returnError:@"Too few arguments!" callback:command.callbackId];

    CDVqrProcessor* processor;
    NSString*       callback;
    callback = command.callbackId;

    processor = [[CDVqrProcessor alloc]
                 initWithPlugin:self
                 callback:callback
                 stringToEncode: command.arguments[0][@"data"]
                 ];

    [processor retain];
    [processor retain];
    [processor retain];
    // queue [processor generateImage] to run on the event loop
    [processor performSelector:@selector(generateImage) withObject:nil afterDelay:0];
}

- (void)returnImage:(NSString*)filePath format:(NSString*)format callback:(NSString*)callback{
    NSMutableDictionary* resultDict = [[[NSMutableDictionary alloc] init] autorelease];
    [resultDict setObject:format forKey:@"format"];
    [resultDict setObject:filePath forKey:@"file"];

    CDVPluginResult* result = [CDVPluginResult
                               resultWithStatus: CDVCommandStatus_OK
                               messageAsDictionary:resultDict
                               ];

    [[self commandDelegate] sendPluginResult:result callbackId:callback];
}

    //--------------------------------------------------------------------------
- (void)returnSuccess:(NSString*)scannedText format:(NSString*)format cancelled:(BOOL)cancelled flipped:(BOOL)flipped callback:(NSString*)callback{
    NSNumber* cancelledNumber = [NSNumber numberWithInt:(cancelled?1:0)];

    NSMutableDictionary* resultDict = [[NSMutableDictionary alloc] init];
    [resultDict setObject:scannedText     forKey:@"text"];
    [resultDict setObject:format          forKey:@"format"];
    [resultDict setObject:cancelledNumber forKey:@"cancelled"];

    CDVPluginResult* result = [CDVPluginResult
                               resultWithStatus: CDVCommandStatus_OK
                               messageAsDictionary: resultDict
                               ];
    [self.commandDelegate sendPluginResult:result callbackId:callback];
}

    //--------------------------------------------------------------------------
- (void)returnError:(NSString*)message callback:(NSString*)callback {
    CDVPluginResult* result = [CDVPluginResult
                               resultWithStatus: CDVCommandStatus_ERROR
                               messageAsString: message
                               ];

    [self.commandDelegate sendPluginResult:result callbackId:callback];
}

    @end

//------------------------------------------------------------------------------
// class that does the grunt work
//------------------------------------------------------------------------------
@implementation CDVbcsProcessor

    @synthesize plugin               = _plugin;
    @synthesize callback             = _callback;
    @synthesize parentViewController = _parentViewController;
    @synthesize viewController       = _viewController;
    @synthesize captureSession       = _captureSession;
    @synthesize previewLayer         = _previewLayer;
    @synthesize alternateXib         = _alternateXib;
    @synthesize is1D                 = _is1D;
    @synthesize is2D                 = _is2D;
    @synthesize capturing            = _capturing;
    @synthesize results              = _results;

    SystemSoundID _soundFileObject;

    //--------------------------------------------------------------------------
- (id)initWithPlugin:(CDVBarcodeScanner*)plugin
            callback:(NSString*)callback
parentViewController:(UIViewController*)parentViewController
  alterateOverlayXib:(NSString *)alternateXib {
    self = [super init];
    if (!self) return self;

    self.plugin               = plugin;
    self.callback             = callback;
    self.parentViewController = parentViewController;
    self.alternateXib         = alternateXib;

    self.is1D      = YES;
    self.is2D      = YES;
    self.capturing = NO;
    self.results = [NSMutableArray new];

    CFURLRef soundFileURLRef  = CFBundleCopyResourceURL(CFBundleGetMainBundle(), CFSTR("CDVBarcodeScanner.bundle/beep"), CFSTR ("caf"), NULL);
    AudioServicesCreateSystemSoundID(soundFileURLRef, &_soundFileObject);

    return self;
}

    //--------------------------------------------------------------------------
- (void)dealloc {
    self.plugin = nil;
    self.callback = nil;
    self.parentViewController = nil;
    self.viewController = nil;
    self.captureSession = nil;
    self.previewLayer = nil;
    self.alternateXib = nil;
    self.results = nil;

    self.capturing = NO;

    AudioServicesRemoveSystemSoundCompletion(_soundFileObject);
    AudioServicesDisposeSystemSoundID(_soundFileObject);

    [super dealloc];
}

    //--------------------------------------------------------------------------
- (void)scanBarcode {

    //    self.captureSession = nil;
    //    self.previewLayer = nil;
    NSString* errorMessage = [self setUpCaptureSession];
    if (errorMessage) {
        [self barcodeScanFailed:errorMessage];
        return;
    }

    self.viewController = [[[CDVbcsViewController alloc] initWithProcessor: self alternateOverlay:self.alternateXib] autorelease];
    // here we set the orientation delegate to the MainViewController of the app (orientation controlled in the Project Settings)
    self.viewController.orientationDelegate = self.plugin.viewController;

    // delayed [self openDialog];
    [self performSelector:@selector(openDialog) withObject:nil afterDelay:1];
}

    //--------------------------------------------------------------------------
- (void)openDialog {
    [self.parentViewController
     presentViewController:self.viewController
     animated:YES completion:nil
     ];
}

    //--------------------------------------------------------------------------
- (void)barcodeScanDone:(void (^)(void))callbackBlock {
    self.capturing = NO;
    [self.captureSession stopRunning];
    [self.parentViewController dismissViewControllerAnimated:YES completion:callbackBlock];

    // viewcontroller holding onto a reference to us, release them so they
    // will release us
    self.viewController = nil;
}

    //--------------------------------------------------------------------------
- (BOOL)checkResult:(NSString *)result {
    [self.results addObject:result];

    NSInteger treshold = 7;

    if (self.results.count > treshold) {
        [self.results removeObjectAtIndex:0];
    }

    if (self.results.count < treshold)
    {
        return NO;
    }

    BOOL allEqual = YES;
    NSString *compareString = [self.results objectAtIndex:0];

    for (NSString *aResult in self.results)
    {
        if (![compareString isEqualToString:aResult])
        {
            allEqual = NO;
            //NSLog(@"Did not fit: %@",self.results);
            break;
        }
    }

    return allEqual;
}

    //--------------------------------------------------------------------------
- (void)barcodeScanSucceeded:(NSString*)text format:(NSString*)format {
    dispatch_sync(dispatch_get_main_queue(), ^{
        [self barcodeScanDone:^{
            [self.plugin returnSuccess:text format:format cancelled:FALSE flipped:FALSE callback:self.callback];
        }];
        AudioServicesPlaySystemSound(_soundFileObject);
    });
}

- (void)barcodeScanRedirect:(NSString*)text {
    [self barcodeScanDone:^{
        [self.plugin returnSuccess:text format:@"REDIRECT_TO" cancelled:FALSE flipped:FALSE callback:self.callback];
    }];
}

- (void)sendResultBackWithFormat:(NSString*)text format:(NSString*) format{
    [self barcodeScanDone:^{
        [self.plugin returnSuccess:text format:format cancelled:FALSE flipped:FALSE callback:self.callback];
    }];
}

    //--------------------------------------------------------------------------
- (void)barcodeScanFailed:(NSString*)message {
    [self barcodeScanDone:^{
        [self.plugin returnError:message callback:self.callback];
    }];
}

    //--------------------------------------------------------------------------
- (void)barcodeScanCancelled {
    [self barcodeScanDone:^{
        [self.plugin returnSuccess:@"" format:@"" cancelled:TRUE flipped:self.isFlipped callback:self.callback];
    }];
    if (self.isFlipped) {
        self.isFlipped = NO;
    }
}

- (void)flipCamera {
    self.isFlipped = YES;
    self.isFrontCamera = !self.isFrontCamera;
    [self barcodeScanDone:^{
        if (self.isFlipped) {
            self.isFlipped = NO;
        }
        [self performSelector:@selector(scanBarcode) withObject:nil afterDelay:0.1];
    }];
}

    //--------------------------------------------------------------------------
- (NSString*)setUpCaptureSession {
    NSError* error = nil;

    AVCaptureSession* captureSession = [[AVCaptureSession alloc] init];
    self.captureSession = captureSession;

    AVCaptureDevice* __block device = nil;
    if (self.isFrontCamera) {

        NSArray* devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        [devices enumerateObjectsUsingBlock:^(AVCaptureDevice *obj, NSUInteger idx, BOOL *stop) {
            if (obj.position == AVCaptureDevicePositionFront) {
                device = obj;
            }
        }];
    } else {
        device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        if (!device) return @"unable to obtain video capture device";

    }


    AVCaptureDeviceInput* input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (!input) return @"unable to obtain video capture device input";

    AVCaptureMetadataOutput* output = [[AVCaptureMetadataOutput alloc] init];
    if (!output) return @"unable to obtain video capture output";

    [output setMetadataObjectsDelegate:self queue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)];

    if ([captureSession canSetSessionPreset:AVCaptureSessionPresetHigh]) {
        captureSession.sessionPreset = AVCaptureSessionPresetHigh;
    } else if ([captureSession canSetSessionPreset:AVCaptureSessionPresetMedium]) {
        captureSession.sessionPreset = AVCaptureSessionPresetMedium;
    } else {
        return @"unable to preset high nor medium quality video capture";
    }

    if ([captureSession canAddInput:input]) {
        [captureSession addInput:input];
    }
    else {
        return @"unable to add video capture device input to session";
    }

    if ([captureSession canAddOutput:output]) {
        [captureSession addOutput:output];
    }
    else {
        return @"unable to add video capture output to session";
    }

    [output setMetadataObjectTypes:@[AVMetadataObjectTypeQRCode,
                                     AVMetadataObjectTypeAztecCode,
                                     AVMetadataObjectTypeDataMatrixCode,
                                     AVMetadataObjectTypeUPCECode,
                                     AVMetadataObjectTypeEAN8Code,
                                     AVMetadataObjectTypeEAN13Code,
                                     AVMetadataObjectTypeCode128Code,
                                     AVMetadataObjectTypeCode93Code,
                                     AVMetadataObjectTypeCode39Code,
                                     AVMetadataObjectTypeITF14Code,
                                     AVMetadataObjectTypePDF417Code]];

    // setup capture preview layer
    self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:captureSession];
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;

    // run on next event loop pass [captureSession startRunning]
    [captureSession performSelector:@selector(startRunning) withObject:nil afterDelay:0];

    return nil;
}

    //--------------------------------------------------------------------------
    // this method gets sent the captured frames
    //--------------------------------------------------------------------------
- (void)captureOutput:(AVCaptureOutput*)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection*)connection {

    if (!self.capturing) return;

#if USE_SHUTTER
    if (!self.viewController.shutterPressed) return;
    self.viewController.shutterPressed = NO;

    UIView* flashView = [[UIView alloc] initWithFrame:self.viewController.view.frame];
    [flashView setBackgroundColor:[UIColor whiteColor]];
    [self.viewController.view.window addSubview:flashView];

    [UIView
     animateWithDuration:.4f
     animations:^{
         [flashView setAlpha:0.f];
     }
     completion:^(BOOL finished){
         [flashView removeFromSuperview];
     }
     ];

    //         [self dumpImage: [[self getImageFromSample:sampleBuffer] autorelease]];
#endif


    try {
        // This will bring in multiple entities if there are multiple 2D codes in frame.
        for (AVMetadataObject *metaData in metadataObjects) {
            AVMetadataMachineReadableCodeObject* code = (AVMetadataMachineReadableCodeObject*)[self.previewLayer transformedMetadataObjectForMetadataObject:(AVMetadataMachineReadableCodeObject*)metaData];

            if ([self checkResult:code.stringValue]) {
                [self barcodeScanSucceeded:code.stringValue format:[self formatStringFromMetadata:code]];
            }
        }
    }
    catch (...) {
        //            NSLog(@"decoding: unknown exception");
        //            [self barcodeScanFailed:@"unknown exception decoding barcode"];
    }

    //        NSTimeInterval timeElapsed  = [NSDate timeIntervalSinceReferenceDate] - timeStart;
    //        NSLog(@"decoding completed in %dms", (int) (timeElapsed * 1000));

}

    //--------------------------------------------------------------------------
    // convert barcode format to string
    //--------------------------------------------------------------------------
- (NSString*)formatStringFrom:(zxing::BarcodeFormat)format {
    if (format == zxing::BarcodeFormat_QR_CODE)      return @"QR_CODE";
    if (format == zxing::BarcodeFormat_DATA_MATRIX)  return @"DATA_MATRIX";
    if (format == zxing::BarcodeFormat_UPC_E)        return @"UPC_E";
    if (format == zxing::BarcodeFormat_UPC_A)        return @"UPC_A";
    if (format == zxing::BarcodeFormat_EAN_8)        return @"EAN_8";
    if (format == zxing::BarcodeFormat_EAN_13)       return @"EAN_13";
    if (format == zxing::BarcodeFormat_CODE_128)     return @"CODE_128";
    if (format == zxing::BarcodeFormat_CODE_39)      return @"CODE_39";
    if (format == zxing::BarcodeFormat_ITF)          return @"ITF";
    return @"???";
}

    //--------------------------------------------------------------------------
    // convert metadata object information to barcode format string
    //--------------------------------------------------------------------------
- (NSString*)formatStringFromMetadata:(AVMetadataMachineReadableCodeObject*)format {
    if (format.type == AVMetadataObjectTypeQRCode)          return @"QR_CODE";
    if (format.type == AVMetadataObjectTypeAztecCode)       return @"AZTEC";
    if (format.type == AVMetadataObjectTypeDataMatrixCode)  return @"DATA_MATRIX";
    if (format.type == AVMetadataObjectTypeUPCECode)        return @"UPC_E";
    // According to Apple documentation, UPC_A is EAN13 with a leading 0.
    if (format.type == AVMetadataObjectTypeEAN13Code && [format.stringValue characterAtIndex:0] == '0') return @"UPC_A";
    if (format.type == AVMetadataObjectTypeEAN8Code)        return @"EAN_8";
    if (format.type == AVMetadataObjectTypeEAN13Code)       return @"EAN_13";
    if (format.type == AVMetadataObjectTypeCode128Code)     return @"CODE_128";
    if (format.type == AVMetadataObjectTypeCode93Code)      return @"CODE_93";
    if (format.type == AVMetadataObjectTypeCode39Code)      return @"CODE_39";
    if (format.type == AVMetadataObjectTypeITF14Code)          return @"ITF";
    if (format.type == AVMetadataObjectTypePDF417Code)      return @"PDF_417";
    return @"???";
}

    //--------------------------------------------------------------------------
    // convert capture's sample buffer (scanned picture) into the thing that
    // zxing needs.
    //--------------------------------------------------------------------------
- (zxing::Ref<zxing::LuminanceSource>) getLuminanceSourceFromSample:(CMSampleBufferRef)sampleBuffer imageBytes:(uint8_t**)ptr {
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer, 0);

    size_t   bytesPerRow =            CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t   width       =            CVPixelBufferGetWidth(imageBuffer);
    size_t   height      =            CVPixelBufferGetHeight(imageBuffer);
    uint8_t* baseAddress = (uint8_t*) CVPixelBufferGetBaseAddress(imageBuffer);

    // only going to get 90% of the min(width,height) of the captured image
    size_t    greyWidth  = 9 * MIN(width, height) / 10;
    uint8_t*  greyData   = (uint8_t*) malloc(greyWidth * greyWidth);

    // remember this pointer so we can free it later
    *ptr = greyData;

    if (!greyData) {
        CVPixelBufferUnlockBaseAddress(imageBuffer,0);
        throw new zxing::ReaderException("out of memory");
    }

    size_t offsetX = (width  - greyWidth) / 2;
    size_t offsetY = (height - greyWidth) / 2;

    // pixel-by-pixel ...
    for (size_t i=0; i<greyWidth; i++) {
        for (size_t j=0; j<greyWidth; j++) {
            // i,j are the coordinates from the sample buffer
            // ni, nj are the coordinates in the LuminanceSource
            // in this case, there's a rotation taking place
            size_t ni = greyWidth-j;
            size_t nj = i;

            size_t baseOffset = (j+offsetY)*bytesPerRow + (i + offsetX)*4;

            // convert from color to grayscale
            // http://en.wikipedia.org/wiki/Grayscale#Converting_color_to_grayscale
            size_t value = 0.11 * baseAddress[baseOffset] +
            0.59 * baseAddress[baseOffset + 1] +
            0.30 * baseAddress[baseOffset + 2];

            greyData[nj*greyWidth + ni] = value;
        }
    }

    CVPixelBufferUnlockBaseAddress(imageBuffer,0);

    using namespace zxing;

    Ref<LuminanceSource> luminanceSource (
                                          new GreyscaleLuminanceSource(greyData, (int)greyWidth, (int)greyWidth, 0, 0, (int)greyWidth, (int)greyWidth)
                                          );

    return luminanceSource;
}

    //--------------------------------------------------------------------------
    // for debugging
    //--------------------------------------------------------------------------
- (UIImage*) getImageFromLuminanceSource:(zxing::LuminanceSource*)luminanceSource  {
    unsigned char* bytes = luminanceSource->getMatrix();
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    CGContextRef context = CGBitmapContextCreate(
                                                 bytes,
                                                 luminanceSource->getWidth(), luminanceSource->getHeight(), 8, luminanceSource->getWidth(),
                                                 colorSpace,
                                                 kCGImageAlphaNone
                                                 );

    CGImageRef cgImage = CGBitmapContextCreateImage(context);
    UIImage*   image   = [[UIImage alloc] initWithCGImage:cgImage];

    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    CGImageRelease(cgImage);
    free(bytes);

    return image;
}

    //--------------------------------------------------------------------------
    // for debugging
    //--------------------------------------------------------------------------
- (UIImage*)getImageFromSample:(CMSampleBufferRef)sampleBuffer {
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer, 0);

    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width       = CVPixelBufferGetWidth(imageBuffer);
    size_t height      = CVPixelBufferGetHeight(imageBuffer);

    uint8_t* baseAddress    = (uint8_t*) CVPixelBufferGetBaseAddress(imageBuffer);
    int      length         = (int)(height * bytesPerRow);
    uint8_t* newBaseAddress = (uint8_t*) malloc(length);
    memcpy(newBaseAddress, baseAddress, length);
    baseAddress = newBaseAddress;

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(
                                                 baseAddress,
                                                 width, height, 8, bytesPerRow,
                                                 colorSpace,
                                                 kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst
                                                 );

    CGImageRef cgImage = CGBitmapContextCreateImage(context);
    UIImage*   image   = [[UIImage alloc] initWithCGImage:cgImage];

    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    CGImageRelease(cgImage);

    free(baseAddress);

    return image;
}


    //--------------------------------------------------------------------------
    // for debugging
    //--------------------------------------------------------------------------
- (void)dumpImage:(UIImage*)image {
    NSLog(@"writing image to library: %dx%d", (int)image.size.width, (int)image.size.height);
    ALAssetsLibrary* assetsLibrary = [[ALAssetsLibrary alloc] init];
    [assetsLibrary
     writeImageToSavedPhotosAlbum:image.CGImage
     orientation:ALAssetOrientationUp
     completionBlock:^(NSURL* assetURL, NSError* error){
         if (error) NSLog(@"   error writing image to library");
         else       NSLog(@"   wrote image to library %@", assetURL);
     }
     ];
}

    @end

//------------------------------------------------------------------------------
// qr encoder processor
//------------------------------------------------------------------------------
@implementation CDVqrProcessor
    @synthesize plugin               = _plugin;
    @synthesize callback             = _callback;
    @synthesize stringToEncode       = _stringToEncode;
    @synthesize size                 = _size;

- (id)initWithPlugin:(CDVBarcodeScanner*)plugin callback:(NSString*)callback stringToEncode:(NSString*)stringToEncode{
    self = [super init];
    if (!self) return self;

    self.plugin          = plugin;
    self.callback        = callback;
    self.stringToEncode  = stringToEncode;
    self.size            = 300;

    return self;
}

    //--------------------------------------------------------------------------
- (void)dealloc {
    self.plugin = nil;
    self.callback = nil;
    self.stringToEncode = nil;

    [super dealloc];
}
    //--------------------------------------------------------------------------
- (void)generateImage{
    /* setup qr filter */
    CIFilter *filter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    [filter setDefaults];

    /* set filter's input message
     * the encoding string has to be convert to a UTF-8 encoded NSData object */
    [filter setValue:[self.stringToEncode dataUsingEncoding:NSUTF8StringEncoding]
              forKey:@"inputMessage"];

    /* on ios >= 7.0  set low image error correction level */
    if (floor(NSFoundationVersionNumber) >= NSFoundationVersionNumber_iOS_7_0)
    [filter setValue:@"L" forKey:@"inputCorrectionLevel"];

    /* prepare cgImage */
    CIImage *outputImage = [filter outputImage];
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef cgImage = [context createCGImage:outputImage
                                       fromRect:[outputImage extent]];

    /* returned qr code image */
    UIImage *qrImage = [UIImage imageWithCGImage:cgImage
                                           scale:1.
                                     orientation:UIImageOrientationUp];
    /* resize generated image */
    CGFloat width = _size;
    CGFloat height = _size;

    UIGraphicsBeginImageContext(CGSizeMake(width, height));

    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetInterpolationQuality(ctx, kCGInterpolationNone);
    [qrImage drawInRect:CGRectMake(0, 0, width, height)];
    qrImage = UIGraphicsGetImageFromCurrentImageContext();

    /* clean up */
    UIGraphicsEndImageContext();
    CGImageRelease(cgImage);

    /* save image to file */
    NSString* filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"tmpqrcode.jpeg"];
    [UIImageJPEGRepresentation(qrImage, 1.0) writeToFile:filePath atomically:YES];

    /* return file path back to cordova */
    [self.plugin returnImage:filePath format:@"QR_CODE" callback: self.callback];
}
    @end

//------------------------------------------------------------------------------
// view controller for the ui
//------------------------------------------------------------------------------
@implementation CDVbcsViewController
    @synthesize processor      = _processor;
    @synthesize shutterPressed = _shutterPressed;
    @synthesize alternateXib   = _alternateXib;
    @synthesize overlayView    = _overlayView;
    @synthesize menuButton     = _menuButton;
    @synthesize searchTextButton     = _searchTextButton;
    @synthesize reportErrorButton = _reportErrorButton;
    @synthesize homeButton = _homeButton;
    @synthesize flashButton = _flashButton;

    //--------------------------------------------------------------------------

- (IBAction)pressVideos:(id)sender {
    [self.processor barcodeScanRedirect:@"Videos"];

}

- (IBAction)pressHome:(id)sender {
    [self.processor barcodeScanRedirect:@"Home"];

}

- (IBAction)pressErrorReport:(id)sender {
    [self hideReportErroButton];
    UIAlertController * alert = [UIAlertController
                                 alertControllerWithTitle:NSLocalizedString(@"WhatsHappen", @"")
                                 message:@""
                                 preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"...";
        textField.keyboardType = UIKeyboardTypeDefault;
    }];

    UIAlertAction* yesButton = [UIAlertAction
                                actionWithTitle:NSLocalizedString(@"ButtonSend",@"")
                                style:UIAlertActionStyleDefault
                                handler:^(UIAlertAction * action) {
                                    UITextField *textField = alert.textFields[0];
                                    [self.processor sendResultBackWithFormat:textField.text format:@"ERROR" ];
                                }];

    UIAlertAction* noButton = [UIAlertAction
                               actionWithTitle:NSLocalizedString(@"ButtonCancel", @"")
                               style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction * action) {
                                   //Handle no, thanks button
                               }];

    [alert addAction:yesButton];
    [alert addAction:noButton];
    //
    [self presentViewController:alert animated:YES completion:nil];
}

- (IBAction)pressBulas:(id)sender {
    [self.processor barcodeScanRedirect:@"Bulas"];
}

- (IBAction)pressMenu:(id)sender {
    [self.processor barcodeScanRedirect:@"Menu"];
}

bool flashOn = NO;

- (IBAction)toogleCamera:(id)sender{
    // check if flashlight available
    Class captureDeviceClass = NSClassFromString(@"AVCaptureDevice");
    if (captureDeviceClass != nil) {
        AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        if ([device hasTorch] && [device hasFlash]){

            [device lockForConfiguration:nil];
            if (flashOn) {
                [device setTorchMode:AVCaptureTorchModeOff];
                [device setFlashMode:AVCaptureFlashModeOff];
                flashOn = NO;
                [self.flashButton setTitle:@"\uf17d" forState: UIControlStateNormal];
            } else {
                [device setTorchMode:AVCaptureTorchModeOn];
                [device setFlashMode:AVCaptureFlashModeOn];
                flashOn = YES; //define as a variable/property if you need to know status
                [self.flashButton setTitle:@"\uf17e" forState: UIControlStateNormal];

            }
            [device unlockForConfiguration];
        }
    }
}

- (IBAction)pressSearch:(id)sender {
    NSLog(@"Buscando por %@",self.searchTextField.text);
    [self.processor sendResultBackWithFormat:self.searchTextField.text format:@"QUERY"];
}


- (void)viewDidLoad {
    [super viewDidLoad];

    //Keyboard stuff
    self.tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
    self.tapRecognizer.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:self.tapRecognizer];
    isErrorButtonShown = NO;

}

- (void)handleSingleTap:(UITapGestureRecognizer *) sender
{
    [self.view endEditing:YES];
}


bool isErrorButtonShown = false;

- (IBAction)pressError:(id)sender {
    [self hideReportErroButton];
}

- (void) hideReportErroButton {
    CGRect erroReportRect = self.erroReportView.frame;
    CGRect searchTextRect = self.searchTextView.frame;

    if(isErrorButtonShown) {
        isErrorButtonShown = NO;
        [UIView animateWithDuration:0.25 animations:^{
            //self.erroReportView.hidden = YES;
            self.erroReportView.frame =  CGRectMake(erroReportRect.origin.x+104, erroReportRect.origin.y,
                                                    1, 50);
            self.searchTextView.frame =  CGRectMake(searchTextRect.origin.x, searchTextRect.origin.y,
                                                    searchTextRect.size.width + 104, 50);
        }];
    } else {
        isErrorButtonShown = YES;
        [UIView animateWithDuration:0.25 animations:^{
            self.erroReportView.hidden = NO;
            self.erroReportView.frame =  CGRectMake(erroReportRect.origin.x-104, erroReportRect.origin.y,
                                                    104, 50);
            self.searchTextView.frame =  CGRectMake(searchTextRect.origin.x, searchTextRect.origin.y,
                                                    searchTextRect.size.width -104, 50);
        }];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    NSLog(@"Buscando por %@",self.searchTextField.text);
    [self.processor sendResultBackWithFormat:self.searchTextField.text format:@"QUERY"];
    [self.searchTextField resignFirstResponder];
    return YES;
}


- (id)initWithProcessor:(CDVbcsProcessor*)processor alternateOverlay:(NSString *)alternateXib {
    self = [super init];
    if (!self) return self;
    self.processor = processor;
    self.shutterPressed = NO;
    self.alternateXib = alternateXib;
    self.overlayView = nil;
    return self;
}

    //--------------------------------------------------------------------------
- (void)dealloc {
    self.view = nil;
    self.processor = nil;
    self.shutterPressed = NO;
    self.alternateXib = nil;
    self.overlayView = nil;
    [super dealloc];
}

    //--------------------------------------------------------------------------
- (void)loadView {
    self.view = [[UIView alloc] initWithFrame: self.processor.parentViewController.view.frame];

    // setup capture preview layer
    AVCaptureVideoPreviewLayer* previewLayer = self.processor.previewLayer;
    previewLayer.frame = self.view.bounds;
    previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;

    if ([previewLayer.connection isVideoOrientationSupported]) {
        [previewLayer.connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    }

    [self.view.layer insertSublayer:previewLayer below:[[self.view.layer sublayers] objectAtIndex:0]];
    UIView* overlayView = [self buildOverlayViewFromXib];
    overlayView.frame = self.view.bounds;
    UIView* overlay = [self buildOverlayView: overlayView];

    [self.view addSubview:overlay];
}

    //--------------------------------------------------------------------------
- (void)viewWillAppear:(BOOL)animated {

    // set video orientation to what the camera sees
    self.processor.previewLayer.connection.videoOrientation = [[UIApplication sharedApplication] statusBarOrientation];

    // this fixes the bug when the statusbar is landscape, and the preview layer
    // starts up in portrait (not filling the whole view)
    self.processor.previewLayer.frame = self.view.bounds;
}

    //--------------------------------------------------------------------------
- (void)viewDidAppear:(BOOL)animated {
    [self startCapturing];

    [super viewDidAppear:animated];
}

    //--------------------------------------------------------------------------
- (void)startCapturing {
    self.processor.capturing = YES;
}

    //--------------------------------------------------------------------------
- (void)shutterButtonPressed {
    self.shutterPressed = YES;
}

    //--------------------------------------------------------------------------
- (IBAction)cancelButtonPressed:(id)sender {
    [self.processor performSelector:@selector(barcodeScanCancelled) withObject:nil afterDelay:0];
}

- (void)flipCameraButtonPressed:(id)sender
    {
        [self.processor performSelector:@selector(flipCamera) withObject:nil afterDelay:0];
    }

    //--------------------------------------------------------------------------
- (UIView *)buildOverlayViewFromXib
    {
        [[NSBundle mainBundle] loadNibNamed:self.alternateXib owner:self options:NULL];

        if ( self.overlayView == nil )
        {
            NSLog(@"%@", @"An error occurred loading the overlay xib.  It appears that the overlayView outlet is not set.");
            return nil;
        }

        return self.overlayView;
    }

    //--------------------------------------------------------------------------
- (UIView*)buildOverlayView: (UIView*)overlayView {
    [self.menuButton setTitle:@"\uf3cf" forState: UIControlStateNormal];
    [self.searchTextButton setTitle:@"\uf4a5" forState: UIControlStateNormal];
    [self.reportErrorButton setTitle:@"\uf3a5" forState: UIControlStateNormal];
    [self.homeButton setTitle:@"\uf30c" forState: UIControlStateNormal];
    [self.flashButton setTitle:@"\uf17d" forState: UIControlStateNormal];

    self.searchTextField.placeholder = NSLocalizedString(@"MedicineName", @"");

    [self.errorReportButton setTitle:NSLocalizedString(@"ReportError",@"") forState: UIControlStateNormal];



    CGRect bounds = self.view.bounds;
    bounds = overlayView.frame;

    CGFloat rootViewHeight = CGRectGetHeight(bounds);
    CGFloat rootViewWidth  = CGRectGetWidth(bounds);
    CGRect  rectArea       = CGRectMake(0, rootViewHeight, rootViewWidth, 0);

    UIImage* reticleImage = [self buildReticleImage];
    UIView* reticleView = [[UIImageView alloc] initWithImage: reticleImage];
    CGFloat minAxis = MIN(rootViewHeight, rootViewWidth);

    rectArea = CGRectMake(
                          0.5 * (rootViewWidth  - minAxis),
                          0.5 * (rootViewHeight - minAxis),
                          minAxis,
                          minAxis
                          );

    [reticleView setFrame:rectArea];

    reticleView.opaque           = NO;
    reticleView.contentMode      = UIViewContentModeScaleAspectFit;
    reticleView.autoresizingMask = 0
    | UIViewAutoresizingFlexibleLeftMargin
    | UIViewAutoresizingFlexibleRightMargin
    | UIViewAutoresizingFlexibleTopMargin
    | UIViewAutoresizingFlexibleBottomMargin
    ;

    [overlayView addSubview: reticleView];

    return overlayView;
}

    //--------------------------------------------------------------------------

#define RETICLE_SIZE    500.0f
#define RETICLE_WIDTH    10.0f
#define RETICLE_OFFSET   60.0f
#define RETICLE_ALPHA     0.4f

    //-------------------------------------------------------------------------
    // builds the green box and red line
    //-------------------------------------------------------------------------
- (UIImage*)buildReticleImage {
    UIImage* result;
    UIGraphicsBeginImageContext(CGSizeMake(RETICLE_SIZE, RETICLE_SIZE));
    CGContextRef context = UIGraphicsGetCurrentContext();

    if (self.processor.is1D) {
        UIColor* color = [UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:RETICLE_ALPHA];
        CGContextSetStrokeColorWithColor(context, color.CGColor);
        CGContextSetLineWidth(context, RETICLE_WIDTH);
        CGContextBeginPath(context);
        CGFloat lineOffset = RETICLE_OFFSET+(0.5*RETICLE_WIDTH);
        CGContextMoveToPoint(context, lineOffset, RETICLE_SIZE/2);
        CGContextAddLineToPoint(context, RETICLE_SIZE-lineOffset, 0.5*RETICLE_SIZE);
        CGContextStrokePath(context);
    }

    if (self.processor.is2D) {
        UIColor* color = [UIColor colorWithRed:0.0 green:1.0 blue:0.0 alpha:RETICLE_ALPHA];
        CGContextSetStrokeColorWithColor(context, color.CGColor);
        CGContextSetLineWidth(context, RETICLE_WIDTH);
        CGContextStrokeRect(context,
                            CGRectMake(
                                       RETICLE_OFFSET,
                                       RETICLE_OFFSET,
                                       RETICLE_SIZE-2*RETICLE_OFFSET,
                                       RETICLE_SIZE-2*RETICLE_OFFSET
                                       )
                            );
    }

    result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

#pragma mark CDVBarcodeScannerOrientationDelegate

- (BOOL)shouldAutorotate
    {
        return YES;
    }

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
    {
        return [[UIApplication sharedApplication] statusBarOrientation];
    }

- (NSUInteger)supportedInterfaceOrientations
    {
        return UIInterfaceOrientationMaskPortrait;
    }

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
    {
        if ((self.orientationDelegate != nil) && [self.orientationDelegate respondsToSelector:@selector(shouldAutorotateToInterfaceOrientation:)]) {
            return [self.orientationDelegate shouldAutorotateToInterfaceOrientation:interfaceOrientation];
        }

        return YES;
    }

- (void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)orientation duration:(NSTimeInterval)duration
    {
        [UIView setAnimationsEnabled:NO];
        AVCaptureVideoPreviewLayer* previewLayer = self.processor.previewLayer;
        previewLayer.frame = self.view.bounds;

        if (orientation == UIInterfaceOrientationLandscapeLeft) {
            [previewLayer setOrientation:AVCaptureVideoOrientationLandscapeLeft];
        } else if (orientation == UIInterfaceOrientationLandscapeRight) {
            [previewLayer setOrientation:AVCaptureVideoOrientationLandscapeRight];
        } else if (orientation == UIInterfaceOrientationPortrait) {
            [previewLayer setOrientation:AVCaptureVideoOrientationPortrait];
        } else if (orientation == UIInterfaceOrientationPortraitUpsideDown) {
            [previewLayer setOrientation:AVCaptureVideoOrientationPortraitUpsideDown];
        }

        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        [UIView setAnimationsEnabled:YES];
    }

    @end
