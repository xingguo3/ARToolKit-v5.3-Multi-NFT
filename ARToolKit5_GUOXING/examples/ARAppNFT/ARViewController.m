//
//  ARViewController.m
//  ARApp2
//

//
//  ARViewController.m
//  ARApp2
//


#import "ARViewController.h"
#import <AR/gsub_es.h>
#import "../ARAppCore/ARMarkerSquare.h"
#import "../ARAppCore/ARMarkerMulti.h"
#import "../ARAppCore/ARMarkerNFT.h"
#import "../ARAppCore/trackingSub.h"

#define VIEW_DISTANCE_MIN        5.0f
#define VIEW_DISTANCE_MAX        2000.0f


//
// ARViewController
//
@interface ARViewController (ARViewControllerPrivate)
- (void) loadNFTData;
- (void) startRunLoop;
- (void) stopRunLoop;
- (void) setRunLoopInterval:(NSInteger)interval;
- (void) mainLoop;
@end

@implementation ARViewController {
    
    BOOL            running;
    NSInteger       runLoopInterval;
    NSTimeInterval  runLoopTimePrevious;
    BOOL            videoPaused;
    BOOL            videoAsync;
    CADisplayLink  *runLoopDisplayLink;
    
    // Video acquisition
    AR2VideoParamT *gVid;
    
    // Marker detection.
    ARHandle       *gARHandle;
    ARPattHandle   *gARPattHandle;
    long            gCallCountMarkerDetect;
    
    // Transformation matrix retrieval.
    AR3DHandle     *gAR3DHandle;
    
    // Markers.
    NSMutableArray *markers;
    NSMutableArray *markersNFT;
    NSMutableArray *markersNFT1;
    
    // Drawing.
    ARParamLT      *gCparamLT;
    ARView         *glView;
    VirtualEnvironment *virtualEnvironment;
    ARGL_CONTEXT_SETTINGS_REF arglContextSettings;
    
    // NFT.
    THREAD_HANDLE_T     *threadHandle;
    THREAD_HANDLE_T     *threadHandle1;
    AR2HandleT          *ar2Handle;
    AR2HandleT          *ar2Handle1;
    KpmHandle           *kpmHandle;
    KpmHandle           *kpmHandle1;
    AR2SurfaceSetT      *surfaceSet[PAGES_MAX]; // Weak-reference. Strong reference is now in ARMarkerNFT class.
    AR2SurfaceSetT      *surfaceSet1[PAGES_MAX];
    
    // NFT results.
    int detectedPage;
    int detectedPage1;// -2 Tracking not inited, -1 tracking inited OK, >= 0 tracking online on page.
    float trackingTrans[3][4];
    float trackingTrans1[3][4];
}

@synthesize glView, virtualEnvironment, markers,markersNFT,markersNFT1;
@synthesize arglContextSettings;
@synthesize running, runLoopInterval;


-(IBAction)SecViewController:(id)sender{
    
    
}


- (void)loadViews
{
//    self.wantsFullScreenLayout = YES;
    
    // This will be overlaid with the actual AR view.
    NSString *irisImage = nil;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        irisImage = @"Iris-iPad.png";
    }  else { // UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone
        CGSize result = [[UIScreen mainScreen] bounds].size;
        if (result.height == 568) {
            irisImage = @"Iris-568h.png"; // iPhone 5, iPod touch 5th Gen, etc.
        } else { // result.height == 480
            irisImage = @"Iris.png";
        }
    }
    UIView *irisView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:irisImage]] autorelease];
    irisView.userInteractionEnabled = YES;
    self.view = irisView;
    [self start];
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Init instance variables.
    glView = nil;
    virtualEnvironment = nil;
    markers = nil;
    markersNFT = nil;
    markersNFT1 = nil;
    gVid = NULL;
    gCparamLT = NULL;
    gARHandle = NULL;
    gARPattHandle = NULL;
    gCallCountMarkerDetect = 0;
    gAR3DHandle = NULL;
    arglContextSettings = NULL;
    running = FALSE;
    videoPaused = FALSE;
    runLoopTimePrevious = CFAbsoluteTimeGetCurrent();
    videoAsync = FALSE;
    detectedPage = -2;
    detectedPage1 = -2;

    
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
//    [self start];
}

- (IBAction)startCamera:(id)sender {
    [self loadViews];
}
- (IBAction)userGuides:(UIButton *)sender {
    internViewControl *svc = [[internViewControl alloc] initWithNibName:nil bundle:nil];
    [self presentModalViewController:svc animated:YES ];
    [svc release];
}

//-(IBAction)userGuide:(id)sender {
//    SecViewController *svc = [[SecViewController alloc] initWithNibName:nil bundle:nil];
//    [self presentModalViewController:svc animated:YES ];
//    [svc release];
//}

- (IBAction)LoadV:(UIButton *)sender {
    
}

// On iOS 6.0 and later, we must explicitly report which orientations this view controller supports.
//- (NSUInteger)supportedInterfaceOrientations
//{
//    return UIInterfaceOrientationMaskPortrait;
//}

// On iOS 6.0 and later, we must explicitly report which orientations this view controller supports.
- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

- (void)startRunLoop
{
    if (!running) {
        // After starting the video, new frames will invoke cameraVideoTookPicture:userData:.
        if (ar2VideoCapStart(gVid) != 0) {
            NSLog(@"Error: Unable to begin camera data capture.\n");
            [self stop];
            return;
        }
        if (!videoAsync) {
            // But if non-async video (e.g. from a movie file) we'll need to generate regular calls to mainLoop using a display link timer.
            runLoopDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(mainLoop)];
            [runLoopDisplayLink setFrameInterval:runLoopInterval];
            [runLoopDisplayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        }
        running = TRUE;
    }
}

- (void)stopRunLoop
{
    if (running) {
        ar2VideoCapStop(gVid);
        if (!videoAsync) {
            [runLoopDisplayLink invalidate];
        }
        running = FALSE;
    }
}

- (void) setRunLoopInterval:(NSInteger)interval
{
    if (interval >= 1) {
        runLoopInterval = interval;
        if (running) {
            [self stopRunLoop];
            [self startRunLoop];
        }
    }
}

- (BOOL) isPaused
{
    if (!running) return (NO);
    
    return (videoPaused);
}

- (void) setPaused:(BOOL)paused
{
    if (!running) return;
    
    if (videoPaused != paused) {
        if (paused) ar2VideoCapStop(gVid);
        else ar2VideoCapStart(gVid);
        videoPaused = paused;
        if (!videoAsync) {
            if (runLoopDisplayLink.paused != paused) runLoopDisplayLink.paused = paused;
        }
#  ifdef DEBUG
        NSLog(@"Run loop was %s.\n", (paused ? "PAUSED" : "UNPAUSED"));
#  endif
    }
}

static void startCallback(void *userData);

- (void) start
{
    // Open the video path.
    char *vconf = ""; // See http://www.artoolworks.com/support/library/Configuring_video_capture_in_ARToolKit_Professional#AR_VIDEO_DEVICE_IPHONE
    if (!(gVid = ar2VideoOpenAsync(vconf, startCallback, self))) {
        NSLog(@"Error: Unable to open connection to camera.\n");
        [self stop];
        return;
    }
}

static void startCallback(void *userData)
{
    ARViewController *vc = (ARViewController *)userData;
    
    [vc start2];
}

- (void) start2
{
    // Find the size of the window.
    int xsize, ysize;
    if (ar2VideoGetSize(gVid, &xsize, &ysize) < 0) {
        NSLog(@"Error: ar2VideoGetSize.\n");
        [self stop];
        return;
    }
    
    // Get the format in which the camera is returning pixels.
    AR_PIXEL_FORMAT pixFormat = ar2VideoGetPixelFormat(gVid);
    if (pixFormat == AR_PIXEL_FORMAT_INVALID) {
        NSLog(@"Error: Camera is using unsupported pixel format.\n");
        [self stop];
        return;
    }
    
    // Work out if the front camera is being used. If it is, flip the viewing frustum for
    // 3D drawing.
    BOOL flipV = FALSE;
    int frontCamera;
    if (ar2VideoGetParami(gVid, AR_VIDEO_PARAM_IOS_CAMERA_POSITION, &frontCamera) >= 0) {
        if (frontCamera == AR_VIDEO_IOS_CAMERA_POSITION_FRONT) flipV = TRUE;
    }
    
    // Tell arVideo what the typical focal distance will be. Note that this does NOT
    // change the actual focus, but on devices with non-fixed focus, it lets arVideo
    // choose a better set of camera parameters.
    ar2VideoSetParami(gVid, AR_VIDEO_PARAM_IOS_FOCUS, AR_VIDEO_IOS_FOCUS_0_3M);
    
    // Load the camera parameters, resize for the window and init.
    ARParam cparam;
    if (ar2VideoGetCParam(gVid, &cparam) < 0) {
        char cparam_name[] = "Data2/camera_para.dat";
        NSLog(@"Unable to automatically determine camera parameters. Using default.\n");
        if (arParamLoad(cparam_name, 1, &cparam) < 0) {
            NSLog(@"Error: Unable to load parameter file %s for camera.\n", cparam_name);
            [self stop];
            return;
        }
    }
    if (cparam.xsize != xsize || cparam.ysize != ysize) {
#ifdef DEBUG
        fprintf(stdout, "*** Camera Parameter resized from %d, %d. ***\n", cparam.xsize, cparam.ysize);
#endif
        arParamChangeSize(&cparam, xsize, ysize, &cparam);
    }
#ifdef DEBUG
    fprintf(stdout, "*** Camera Parameter ***\n");
    arParamDisp(&cparam);
#endif
    if ((gCparamLT = arParamLTCreate(&cparam, AR_PARAM_LT_DEFAULT_OFFSET)) == NULL) {
        NSLog(@"Error: arParamLTCreate.\n");
        [self stop];
        return;
    }
    
    // AR init.
    if ((gARHandle = arCreateHandle(gCparamLT)) == NULL) {
        NSLog(@"Error: arCreateHandle.\n");
        [self stop];
        return;
    }
    if (arSetPixelFormat(gARHandle, pixFormat) < 0) {
        NSLog(@"Error: arSetPixelFormat.\n");
        [self stop];
        return;
    }
    if ((gAR3DHandle = ar3DCreateHandle(&gCparamLT->param)) == NULL) {
        NSLog(@"Error: ar3DCreateHandle.\n");
        [self stop];
        return;
    }
    
    // NFT init.
    //
    
    // KPM init.
    kpmHandle = kpmCreateHandle(gCparamLT, pixFormat);
    kpmHandle1 = kpmCreateHandle(gCparamLT, pixFormat);
    if (!kpmHandle||!kpmHandle1) {
        NSLog(@"Error: kpmCreateHandle.\n");
        [self stop];
        return;
    }
    
    // AR2 init.
    if (!(ar2Handle = ar2CreateHandle(gCparamLT, pixFormat, AR2_TRACKING_DEFAULT_THREAD_NUM))||!(ar2Handle1 = ar2CreateHandle(gCparamLT, pixFormat, AR2_TRACKING_DEFAULT_THREAD_NUM))) {
        NSLog(@"Error: ar2CreateHandle.\n");
        [self stop];
        return;
    }
    
    if (threadGetCPU() <= 1) {
#ifdef DEBUG
        NSLog(@"Using NFT tracking settings for a single CPU.");
#endif
        ar2SetTrackingThresh(ar2Handle, 5.0);
        ar2SetSimThresh(ar2Handle, 0.50);
        ar2SetSearchFeatureNum(ar2Handle, 16);
        ar2SetSearchSize(ar2Handle, 6);
        ar2SetTemplateSize1(ar2Handle, 6);
        ar2SetTemplateSize2(ar2Handle, 6);
        ar2SetTrackingThresh(ar2Handle1, 5.0);
        ar2SetSimThresh(ar2Handle1, 0.50);
        ar2SetSearchFeatureNum(ar2Handle1, 16);
        ar2SetSearchSize(ar2Handle1, 6);
        ar2SetTemplateSize1(ar2Handle1, 6);
        ar2SetTemplateSize2(ar2Handle1, 6);
    } else {
#ifdef DEBUG
        NSLog(@"Using NFT tracking settings for more than one CPU.");
#endif
        ar2SetTrackingThresh(ar2Handle, 5.0);
        ar2SetSimThresh(ar2Handle, 0.50);
        ar2SetSearchFeatureNum(ar2Handle, 16);
        ar2SetSearchSize(ar2Handle, 12);
        ar2SetTemplateSize1(ar2Handle, 6);
        ar2SetTemplateSize2(ar2Handle, 6);
        ar2SetTrackingThresh(ar2Handle1, 5.0);
        ar2SetSimThresh(ar2Handle1, 0.50);
        ar2SetSearchFeatureNum(ar2Handle1, 16);
        ar2SetSearchSize(ar2Handle1, 12);
        ar2SetTemplateSize1(ar2Handle1, 6);
        ar2SetTemplateSize2(ar2Handle1, 6);
    }
    // NFT dataset loading will happen later.
    
    // Runloop setup.
    // Determine whether ARvideo will return frames asynchronously.
    int ret0;
    if (ar2VideoGetParami(gVid, AR_VIDEO_PARAM_IOS_ASYNC, &ret0) != 0) {
        NSLog(@"Error: Unable to query video library for status of async support.\n");
        [self stop];
        return;
    }
    videoAsync = (BOOL)ret0;
    
    if (videoAsync) {
        // libARvideo on iPhone uses an underlying class called CameraVideo. Here, we
        // access the instance of this class to get/set some special types of information.
        CameraVideo *cameraVideo = ar2VideoGetNativeVideoInstanceiPhone(gVid->device.iPhone);
        if (!cameraVideo) {
            NSLog(@"Error: Unable to set up AR camera: missing CameraVideo instance.\n");
            [self stop];
            return;
        }
        
        // The camera will be started by -startRunLoop.
        [cameraVideo setTookPictureDelegate:self];
        [cameraVideo setTookPictureDelegateUserData:NULL];
    }
    
    // Other ARToolKit setup.
    arSetMarkerExtractionMode(gARHandle, AR_USE_TRACKING_HISTORY_V2);
    //arSetMarkerExtractionMode(gARHandle, AR_NOUSE_TRACKING_HISTORY);
    //arSetLabelingThreshMode(gARHandle, AR_LABELING_THRESH_MODE_MANUAL); // Uncomment to use  manual thresholding.
    
    // Allocate the OpenGL view.
    glView = [[[ARView alloc] initWithFrame:[[UIScreen mainScreen] bounds] pixelFormat:kEAGLColorFormatRGBA8 depthFormat:kEAGLDepth16 withStencil:NO preserveBackbuffer:NO] autorelease]; // Don't retain it, as it will be retained when added to self.view.
    glView.arViewController = self;
    [self.view addSubview:glView];
    
    // Create the OpenGL projection from the calibrated camera parameters.
    // If flipV is set, flip.
    GLfloat frustum[16];
    arglCameraFrustumRHf(&gCparamLT->param, VIEW_DISTANCE_MIN, VIEW_DISTANCE_MAX, frustum);
    [glView setCameraLens:frustum];
    glView.contentFlipV = flipV;
    
    // Set up content positioning.
    glView.contentScaleMode = ARViewContentScaleModeFill;
    glView.contentAlignMode = ARViewContentAlignModeCenter;
    glView.contentWidth = gARHandle->xsize;
    glView.contentHeight = gARHandle->ysize;
    BOOL isBackingTallerThanWide = (glView.surfaceSize.height > glView.surfaceSize.width);
    if (glView.contentWidth > glView.contentHeight) glView.contentRotate90 = isBackingTallerThanWide;
    else glView.contentRotate90 = !isBackingTallerThanWide;
#ifdef DEBUG
    NSLog(@"[ARViewController start] content %dx%d (wxh) will display in GL context %dx%d%s.\n", glView.contentWidth, glView.contentHeight, (int)glView.surfaceSize.width, (int)glView.surfaceSize.height, (glView.contentRotate90 ? " rotated" : ""));
#endif
    
    // Setup ARGL to draw the background video.
    arglContextSettings = arglSetupForCurrentContext(&gCparamLT->param, pixFormat);
    
    arglSetRotate90(arglContextSettings, (glView.contentWidth > glView.contentHeight ? isBackingTallerThanWide : !isBackingTallerThanWide));
    if (flipV) arglSetFlipV(arglContextSettings, TRUE);
    int width, height;
    ar2VideoGetBufferSize(gVid, &width, &height);
    arglPixelBufferSizeSet(arglContextSettings, width, height);
    
    // Prepare ARToolKit to load patterns.
    if (!(gARPattHandle = arPattCreateHandle())) {
        NSLog(@"Error: arPattCreateHandle.\n");
        [self stop];
        return;
    }
    arPattAttach(gARHandle, gARPattHandle);
    
    // Load marker(s).
    NSString *markerConfigDataFilename = @"Data2/markers.dat";
    NSString *markerConfigDataFilenameNFT = @"Data2/markersNFT.dat";
    NSString *markerConfigDataFilenameNFT1 = @"Data2/markersNFT1.dat";
    int mode;
    if ((markers = [ARMarker newMarkersFromConfigDataFile:markerConfigDataFilename arPattHandle:gARPattHandle arPatternDetectionMode:&mode]) == nil) {
        NSLog(@"Error loading markers.\n");
        [self stop];
        return;
    }
    if ((markersNFT = [ARMarker newMarkersFromConfigDataFile:markerConfigDataFilenameNFT arPattHandle:NULL arPatternDetectionMode:NULL]) == nil) {
        NSLog(@"Error loading markers.\n");
        [self stop];
        return;
    }
    if ((markersNFT1 = [ARMarker newMarkersFromConfigDataFile:markerConfigDataFilenameNFT1 arPattHandle:NULL arPatternDetectionMode:NULL]) == nil) {
        NSLog(@"Error loading markers.\n");
        [self stop];
        return;
    }
#ifdef DEBUG
    NSLog(@"Marker count = %d\n", [markers count]);
    NSLog(@"Marker count = %d\n", [markersNFT count]);
    NSLog(@"Marker count = %d\n", [markersNFT1 count]);
#endif
    
    [self loadNFTData];
    // Set the pattern detection mode (template (pictorial) vs. matrix (barcode) based on
    // the marker types as defined in the marker config. file.
    arSetPatternDetectionMode(gARHandle, mode); // Default = AR_TEMPLATE_MATCHING_COLOR
    
    // Other application-wide marker options. Once set, these apply to all markers in use in the application.
    // If you are using standard ARToolKit picture (template) markers, leave commented to use the defaults.
    // If you are usign a different marker design (see http://www.artoolworks.com/support/app/marker.php )
    // then uncomment and edit as instructed by the marker design application.
    //arSetLabelingMode(gARHandle, AR_LABELING_BLACK_REGION); // Default = AR_LABELING_BLACK_REGION
    //arSetBorderSize(gARHandle, 0.25f); // Default = 0.25f
    //arSetMatrixCodeType(gARHandle, AR_MATRIX_CODE_3x3); // Default = AR_MATRIX_CODE_3x3
    
    // Set up the virtual environment.
    self.virtualEnvironment = [[[VirtualEnvironment alloc] initWithARViewController:self] autorelease];
    [self.virtualEnvironment addObjectsFromObjectListFile:@"Data2/models.dat" connectToARMarkers:markers];
    [self.virtualEnvironment addObjectsFromObjectListFile:@"Data2/modelsNFT.dat"  connectToARMarkers:markersNFT];
    [self.virtualEnvironment addObjectsFromObjectListFile:@"Data2/modelsNFT1.dat" connectToARMarkers:markersNFT1];
    
    
    float pose[16] = {1.0f, 0.0f, 0.0f, 0.0f,  0.0f, 1.0f, 0.0f, 0.0f,  0.0f, 0.0f, 1.0f, 0.0f,  0.0f, 0.0f, 0.0f, 1.0f};
    [glView setCameraPose:pose];
    
    // For FPS statistics.
    arUtilTimerReset();
    gCallCountMarkerDetect = 0;
    
    //Create our runloop timer
    [self setRunLoopInterval:2]; // Target 30 fps on a 60 fps device.
    [self startRunLoop];
}

- (void)loadNFTData
{
    int i;
    
    // If data was already loaded, stop KPM tracking thread and unload previously loaded data.
    trackingInitQuit(&threadHandle);
    trackingInitQuit(&threadHandle1);
    for (i = 0; i < PAGES_MAX; i++) {
        surfaceSet[i] = NULL; // Discard weak-references.
        surfaceSet1[i] = NULL;
    }
    
    KpmRefDataSet *refDataSet = NULL, *refDataSet1 = NULL;
    int pageCount = 0, pageCount1 = 0;
    
    for (ARMarker *marker in markersNFT) {
        if ([marker isKindOfClass:[ARMarkerNFT class]]) {
            ARMarkerNFT *markerNFT = (ARMarkerNFT *)marker;
            
            // Load KPM data.
            KpmRefDataSet  *refDataSet2;
            printf("Read %s.fset3\n", markerNFT.datasetPathname);
            if (kpmLoadRefDataSet(markerNFT.datasetPathname, "fset3", &refDataSet2) < 0 ) {
                NSLog(@"Error reading KPM data from %s.fset3", markerNFT.datasetPathname);
                markerNFT.pageNo = -1;
                continue;
            }
            markerNFT.pageNo = pageCount;
            if (kpmChangePageNoOfRefDataSet(refDataSet2, KpmChangePageNoAllPages, pageCount) < 0) {
                NSLog(@"Error: kpmChangePageNoOfRefDataSet");
                exit(-1);
            }
            if (kpmMergeRefDataSet(&refDataSet, &refDataSet2) < 0) {
                NSLog(@"Error: kpmMergeRefDataSet");
                exit(-1);
            }
            printf("  Done.\n");
            
            // For convenience, create a weak reference to the AR2 data.
            surfaceSet[pageCount] = markerNFT.surfaceSet;
            
            pageCount++;
            if (pageCount == PAGES_MAX) break;
        }
    }
    
    for (ARMarker *marker in markersNFT1) {
        if ([marker isKindOfClass:[ARMarkerNFT class]]) {
            ARMarkerNFT *markerNFT = (ARMarkerNFT *)marker;
            
            // Load KPM data.
            KpmRefDataSet  *refDataSet21;
            printf("Read %s.fset3\n", markerNFT.datasetPathname);
            if (kpmLoadRefDataSet(markerNFT.datasetPathname, "fset3", &refDataSet21) < 0 ) {
                NSLog(@"Error reading KPM data from %s.fset3", markerNFT.datasetPathname);
                markerNFT.pageNo = -1;
                continue;
            }
            markerNFT.pageNo = pageCount1;
            if (kpmChangePageNoOfRefDataSet(refDataSet21, KpmChangePageNoAllPages, pageCount1) < 0) {
                NSLog(@"Error: kpmChangePageNoOfRefDataSet");
                exit(-1);
            }
            if (kpmMergeRefDataSet(&refDataSet1, &refDataSet21) < 0) {
                NSLog(@"Error: kpmMergeRefDataSet");
                exit(-1);
            }
            printf("  Done.\n");
            
            // For convenience, create a weak reference to the AR2 data.
            surfaceSet1[pageCount1] = markerNFT.surfaceSet;
            
            pageCount1++;
            if (pageCount1 == PAGES_MAX) break;
        }
    }
    
    if (kpmSetRefDataSet(kpmHandle, refDataSet) < 0) {
        NSLog(@"Error: kpmSetRefDataSet");
        exit(-1);
    }
    if (kpmSetRefDataSet(kpmHandle1, refDataSet1) < 0) {
        NSLog(@"Error: kpmSetRefDataSet1");
        exit(-1);
    }
    kpmDeleteRefDataSet(&refDataSet);
    kpmDeleteRefDataSet(&refDataSet1);
    
    // Start the KPM tracking thread.
    threadHandle = trackingInitInit(kpmHandle);
    threadHandle1 = trackingInitInit(kpmHandle1);
    if (!threadHandle) exit(0);
    if (!threadHandle1) exit(0);
}


- (void) mainLoop
{
    // Request a video frame.
    AR2VideoBufferT *buffer = ar2VideoGetImage(gVid);
    if (buffer) [self processFrame:buffer];
}

- (void) cameraVideoTookPicture:(id)sender userData:(void *)data
{
    AR2VideoBufferT *buffer = ar2VideoGetImage(gVid);
    if (buffer) [self processFrame:buffer];
}

- (void) processFrame:(AR2VideoBufferT *)buffer
{
    if (buffer) {
        
        // Upload the frame to OpenGL.
        if (buffer->bufPlaneCount == 2) arglPixelBufferDataUploadBiPlanar(arglContextSettings, buffer->bufPlanes[0], buffer->bufPlanes[1]);
        else arglPixelBufferDataUpload(arglContextSettings, buffer->buff);
        
        gCallCountMarkerDetect++; // Increment ARToolKit FPS counter.
#ifdef DEBUG
        NSLog(@"video frame %ld.\n", gCallCountMarkerDetect);
#endif
#ifdef DEBUG
        if (gCallCountMarkerDetect % 150 == 0) {
            NSLog(@"*** Camera - %f (frame/sec)\n", (double)gCallCountMarkerDetect/arUtilTimer());
            gCallCountMarkerDetect = 0;
            arUtilTimerReset();
        }
#endif
        if (threadHandle) {
            // Perform NFT tracking.
            float            err;
            int              ret;
            int              pageNo;
            
            if( detectedPage == -2 ) {
                trackingInitStart( threadHandle, buffer->buff );
                detectedPage = -1;
            }
            if( detectedPage == -1 ) {
                ret = trackingInitGetResult( threadHandle, trackingTrans, &pageNo);
                if( ret == 1 ) {
                    if (pageNo >= 0 && pageNo < PAGES_MAX) {
                        detectedPage = pageNo;
#ifdef DEBUG
                        NSLog(@"Detected page %d.\n", detectedPage);
#endif
                        ar2SetInitTrans(surfaceSet[detectedPage], trackingTrans);
                    } else {
                        NSLog(@"Detected bad page %d.\n", pageNo);
                        detectedPage = -2;
                    }
                } else if( ret < 0 ) {
                    detectedPage = -2;
                }
            }
            if( detectedPage >= 0 && detectedPage < PAGES_MAX) {
                if( ar2Tracking(ar2Handle, surfaceSet[detectedPage], buffer->buff, trackingTrans, &err) < 0 ) {
                    detectedPage = -2;
                } else {
#ifdef DEBUG
                    NSLog(@"Tracked page %d.\n", detectedPage);
#endif
                }
            }
        } else detectedPage = -2;
        
        if (threadHandle1) {
            // Perform NFT tracking.
            float            err;
            int              ret;
            int              pageNo;
            
            if( detectedPage1 == -2 ) {
                trackingInitStart( threadHandle1, buffer->buff );
                detectedPage1 = -1;
            }
            if( detectedPage1 == -1 ) {
                ret = trackingInitGetResult( threadHandle1, trackingTrans1, &pageNo);
                if( ret == 1 ) {
                    if (pageNo >= 0 && pageNo < PAGES_MAX) {
                        detectedPage1 = pageNo;
#ifdef DEBUG
                        NSLog(@"Detected page %d.\n", detectedPage1);
#endif
                        ar2SetInitTrans(surfaceSet1[detectedPage1], trackingTrans1);
                    } else {
                        NSLog(@"Detected bad page %d.\n", pageNo);
                        detectedPage1 = -2;
                    }
                } else if( ret < 0 ) {
                    detectedPage1 = -2;
                }
            }
            if( detectedPage1 >= 0 && detectedPage1 < PAGES_MAX) {
                if( ar2Tracking(ar2Handle1, surfaceSet1[detectedPage1], buffer->buff, trackingTrans1, &err) < 0 ) {
                    detectedPage1 = -2;
                } else {
#ifdef DEBUG
                    NSLog(@"Tracked page %d.\n", detectedPage1);
#endif
                }
            }
        } else detectedPage1 = -2;
        
        // Detect the markers in the video frame.
        if (arDetectMarker(gARHandle, buffer->buff) < 0) return;
        int markerNum = arGetMarkerNum(gARHandle);
        ARMarkerInfo *markerInfo = arGetMarker(gARHandle);
#ifdef DEBUG
        NSLog(@"found %d marker(s).\n", markerNum);
#endif
        
        ARMarkerSquare *mk1 = markers[0];
        ARMarkerSquare *mk2 = markers[1];
        ARMarkerNFT *mk3 = markersNFT1[0];
        ARMarkerNFT *mk4 = markersNFT1[0];
        
        if ([mk1 isKindOfClass:[ARMarkerSquare class]]) {
            [(ARMarkerSquare *)mk1 updateWithDetectedMarkers:markerInfo count:markerNum ar3DHandle:gAR3DHandle];
        } else if ([mk1 isKindOfClass:[ARMarkerMulti class]]) {
            [(ARMarkerMulti *)mk1 updateWithDetectedMarkers:markerInfo count:markerNum ar3DHandle:gAR3DHandle];
        } else {
            [mk1 update];
        }
        
        if (!mk1.isValid){
            if ([mk2 isKindOfClass:[ARMarkerSquare class]]) {
                [(ARMarkerSquare *)mk2 updateWithDetectedMarkers:markerInfo count:markerNum ar3DHandle:gAR3DHandle];
            } else if ([mk2 isKindOfClass:[ARMarkerMulti class]]) {
                [(ARMarkerMulti *)mk2 updateWithDetectedMarkers:markerInfo count:markerNum ar3DHandle:gAR3DHandle];
            } else {
                [mk2 update];
            }
        } else
            [mk2 update];
        
        for (ARMarker *marker in markersNFT) {
            if ([marker isKindOfClass:[ARMarkerNFT class]]&&!mk2.isValid) {
                [(ARMarkerNFT *)marker updateWithNFTResultsDetectedPage:detectedPage trackingTrans:trackingTrans];
            } else {
                [marker update];
            }
        }
        
        for (ARMarker *marker in markersNFT1) {
            if ([marker isKindOfClass:[ARMarkerNFT class]]&&!mk2.isValid) {
                [(ARMarkerNFT *)marker updateWithNFTResultsDetectedPage:detectedPage1 trackingTrans:trackingTrans1];
            } else {
                [marker update];
            }
        }
        
        
        //        void moveLeft(){
        //            //Find out which model we need to modify
        //            for (int i = 0; i < NUM_MODELS; i++)
        //            { models[i].visible = arwQueryMarkerTransformation(models[i].patternID, models[i].transformationMatrix);
        //                if (models[i].visible)
        //                { models[i].offset -= 1.0; }
        //
        //            }
        //
        //        }
        
        
        // Get current time (units = seconds).
        NSTimeInterval runLoopTimeNow;
        runLoopTimeNow = CFAbsoluteTimeGetCurrent();
        [virtualEnvironment updateWithSimulationTime:(runLoopTimeNow - runLoopTimePrevious)];
        
        // The display has changed.
        [glView drawView:self];
        
        // Save timestamp for next loop.
        runLoopTimePrevious = runLoopTimeNow;
    }
}

- (IBAction)stop
{
    int i;
    
    [self stopRunLoop];
    
    self.virtualEnvironment = nil;
    
    [markers release];
    [markersNFT release];
    [markersNFT1 release];
    markers = nil;
    markersNFT1 = nil;
    markersNFT = nil;
    
    if (arglContextSettings) {
        arglCleanup(arglContextSettings);
        arglContextSettings = NULL;
    }
    [glView removeFromSuperview]; // Will result in glView being released.
    glView = nil;
    
    // NFT cleanup.
    trackingInitQuit(&threadHandle);
    trackingInitQuit(&threadHandle1);
    detectedPage = -2;
    detectedPage1 = -2;
    for (i = 0; i < PAGES_MAX; i++) surfaceSet[i] = NULL; // Discard weak-references.
    for (i = 0; i < PAGES_MAX; i++) surfaceSet1[i] = NULL;
    ar2DeleteHandle(&ar2Handle);
    ar2DeleteHandle(&ar2Handle1);
    kpmDeleteHandle(&kpmHandle);
    kpmDeleteHandle(&kpmHandle1);
    
    if (gARHandle) arPattDetach(gARHandle);
    if (gARPattHandle) {
        arPattDeleteHandle(gARPattHandle);
        gARPattHandle = NULL;
    }
    if (gAR3DHandle) ar3DDeleteHandle(&gAR3DHandle);
    if (gARHandle) {
        arDeleteHandle(gARHandle);
        gARHandle = NULL;
    }
    arParamLTFree(&gCparamLT);
    if (gVid) {
        ar2VideoClose(gVid);
        gVid = NULL;
    }
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewWillDisappear:(BOOL)animated {
    [self stop];
    [super viewWillDisappear:animated];
}

- (void)dealloc {
    [super dealloc];
}

// ARToolKit-specific methods.
- (BOOL)markersHaveWhiteBorders
{
    int mode;
    arGetLabelingMode(gARHandle, &mode);
    return (mode == AR_LABELING_WHITE_REGION);
}

- (void)setMarkersHaveWhiteBorders:(BOOL)markersHaveWhiteBorders
{
    arSetLabelingMode(gARHandle, (markersHaveWhiteBorders ? AR_LABELING_WHITE_REGION : AR_LABELING_BLACK_REGION));
}


@end
