#import <XCTest/XCTest.h>
#import "UnityAdsTests-Bridging-Header.h"
#import "MediaPlayer/MPVolumeView.h"
#import <MediaPlayer/MediaPlayer.h>

@interface VolumeChangeTestsWebApp : UADSWebViewApp
@property (nonatomic, strong) XCTestExpectation *expectation;
@property (nonatomic, strong) NSString *fulfillingEvent;
@property (nonatomic, strong) NSString *collectEvents;
@property (nonatomic, strong) NSMutableArray *collectedEvents;
@property (nonatomic, strong) id fulFilledParam;
@end

@implementation VolumeChangeTestsWebApp
@synthesize expectation = _expectation;
@synthesize collectEvents = _collectEvents;
@synthesize collectedEvents = _collectedEvents;

- (id)init {
    self = [super init];
    if (self) {
    }
    
    return self;
}

- (BOOL)invokeCallback:(UADSInvocation *)invocation {
    return true;
}

- (BOOL)sendEvent:(NSString *)eventId category:(NSString *)category params:(NSArray *)params {
    return true;
}

- (BOOL)sendEvent:(NSString *)eventId category:(NSString *)category param1:(id)param1, ... {
    NSLog(@"GOT_EVENT=%@", eventId);
    if (self.fulfillingEvent && [self.fulfillingEvent isEqualToString:eventId]) {
        NSLog(@"FULFILLING=%@", eventId);
        if (self.expectation) {
            [self.expectation fulfill];
        }
        else {
        }
    }
    
    if (self.collectEvents && [self.collectEvents isEqualToString:eventId]) {
        NSLog(@"COLLECTING=%@", eventId);
        if (!self.collectedEvents) {
            self.collectedEvents = [[NSMutableArray alloc] init];
        }
        
        [self.collectedEvents addObject:param1];
    }
    
    return true;
}

- (BOOL)invokeMethod:(NSString *)methodName className:(NSString *)className receiverClass:(NSString *)receiverClass callback:(NSString *)callback params:(NSArray *)params {
    return true;
}

@end

@interface VolumeChangeTests : XCTestCase <UADSVolumeChangeDelegate>
@property (nonatomic, strong) UADSAVPlayer *videoPlayer;
@property (nonatomic, strong) UADSVideoView *videoView;
@property (nonatomic, strong) UISlider *volumeSlider;
@property (nonatomic, strong) MPVolumeView *volumeView;
@end

@implementation VolumeChangeTests

-(void)setUp {
    VolumeChangeTestsWebApp *webViewApp = [[VolumeChangeTestsWebApp alloc] init];
    [UADSWebViewApp setCurrentApp:webViewApp];
    [[UADSWebViewApp getCurrentApp] setWebAppLoaded:true];
    [[UADSWebViewApp getCurrentApp] setWebAppInitialized:true];
    
    [self setVideoView:[[UADSVideoView alloc] initWithFrame:CGRectMake(0, 0, 400, 400)]];
    [self.videoView setVideoFillMode:AVLayerVideoGravityResizeAspect];
    
    AVURLAsset *asset = nil;
    AVPlayerItem *item = [AVPlayerItem playerItemWithAsset:asset];
    [self setVideoPlayer:[[UADSAVPlayer alloc] initWithPlayerItem:item]];
    [self.videoView setPlayer:self.videoPlayer];
    
    [[UIApplication sharedApplication].keyWindow.rootViewController.view addSubview:self.videoView];
    
    self.volumeView = [[MPVolumeView alloc] initWithFrame:CGRectMake(60, 260, 200, 200)];
    self.volumeView.showsRouteButton = YES;
    self.volumeView.showsVolumeSlider = YES;
    self.volumeView.hidden = false;
    [[UIApplication sharedApplication].keyWindow.rootViewController.view addSubview:self.volumeView];
    
    __weak __typeof(self)weakSelf = self;
    [[self.volumeView subviews] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ([obj isKindOfClass:[UISlider class]]) {
            __strong __typeof(weakSelf)strongSelf = weakSelf;
            strongSelf.volumeSlider = obj;
            *stop = YES;
        }
    }];
}

-(void)tearDown {
    if (self.videoView) {
        [self.videoView removeFromSuperview];
        self.videoView = NULL;
    }
    if (self.volumeView) {
        [self.volumeView removeFromSuperview];
        self.volumeView = NULL;
    }
}

-(void)testVolumeChangeDelegate {
    if ([UADSDevice isSimulator]) {
        NSLog(@"Device is simulator, Skipping a videoview test");
        return;
    }

    self.volumeSlider.value = 0.5f;
    
    XCTAssertNotNil(self.volumeSlider, @"Should have a volume slider");
    [UADSVolumeChange registerDelegate:self];
    
    XCTestExpectation *prepareExpectation = [self expectationWithDescription:@"prepareExpectation"];
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        [self.videoPlayer prepare:[TestUtilities getTestVideoUrl] initialVolume:1.0f timeout:10000];
    });

    [(VolumeChangeTestsWebApp *)[UADSWebViewApp getCurrentApp] setExpectation:prepareExpectation];
    [(VolumeChangeTestsWebApp *)[UADSWebViewApp getCurrentApp] setFulfillingEvent:@"PREPARED"];

    __block BOOL success = true;
    [self waitForExpectationsWithTimeout:30 handler:^(NSError * _Nullable error) {
        if (error) {
            success = false;
        }
    }];

    XCTAssertTrue(success, @"Prepare expectation was not opened properly or an error occurred!");

    [self.videoPlayer play];
    
    XCTestExpectation *progressExpectation = [self expectationWithDescription:@"playExpectation"];
    [(VolumeChangeTestsWebApp *)[UADSWebViewApp getCurrentApp] setExpectation:progressExpectation];
    [(VolumeChangeTestsWebApp *)[UADSWebViewApp getCurrentApp] setFulfillingEvent:@"PROGRESS"];
    
    success = true;
    [self waitForExpectationsWithTimeout:30 handler:^(NSError * _Nullable error) {
        if (error) {
            success = false;
        }
    }];

    [(VolumeChangeTestsWebApp *)[UADSWebViewApp getCurrentApp] setCollectEvents:@"VOLUME_CHANGED"];
    
    self.volumeSlider.value = 1.0f;

    XCTestExpectation *volumeChangedExpectation = [self expectationWithDescription:@"volumeChangedExpectation"];
    [(VolumeChangeTestsWebApp *)[UADSWebViewApp getCurrentApp] setExpectation:volumeChangedExpectation];
    [(VolumeChangeTestsWebApp *)[UADSWebViewApp getCurrentApp] setFulfillingEvent:@"VOLUME_CHANGED"];

    success = true;
    [self waitForExpectationsWithTimeout:10 handler:^(NSError * _Nullable error) {
        if (error) {
            success = false;
        }
    }];

    XCTAssertEqual([(VolumeChangeTestsWebApp *)[UADSWebViewApp getCurrentApp] collectedEvents].count, 1, @"Should have one event");
    XCTAssertEqualObjects([(VolumeChangeTestsWebApp *)[UADSWebViewApp getCurrentApp] collectedEvents][0], [NSNumber numberWithFloat:1.0f], @"Should have 1.0 as received volume");

    [UADSVolumeChange unregisterDelegate:self];
    
    self.volumeSlider.value = 0.8f;

    [UADSVolumeChange registerDelegate:self];

    self.volumeSlider.value = 0.6f;

    XCTestExpectation *volumeChangedExpectation2 = [self expectationWithDescription:@"volumeChangedExpectation2"];
    [(VolumeChangeTestsWebApp *)[UADSWebViewApp getCurrentApp] setExpectation:volumeChangedExpectation2];
    [(VolumeChangeTestsWebApp *)[UADSWebViewApp getCurrentApp] setFulfillingEvent:@"VOLUME_CHANGED"];
    
    success = true;
    [self waitForExpectationsWithTimeout:10 handler:^(NSError * _Nullable error) {
        if (error) {
            success = false;
        }
    }];
    
    XCTAssertEqual([(VolumeChangeTestsWebApp *)[UADSWebViewApp getCurrentApp] collectedEvents].count, 2, @"Should have one event");
    XCTAssertEqualObjects([(VolumeChangeTestsWebApp *)[UADSWebViewApp getCurrentApp] collectedEvents][0], [NSNumber numberWithFloat:0.6f], @"Should have 0.6 as received volume");

    XCTestExpectation *completeExpectation = [self expectationWithDescription:@"completeExpectation"];
    [(VolumeChangeTestsWebApp *)[UADSWebViewApp getCurrentApp] setExpectation:completeExpectation];
    [(VolumeChangeTestsWebApp *)[UADSWebViewApp getCurrentApp] setFulfillingEvent:@"COMPLETED"];
    
    success = true;
    [self waitForExpectationsWithTimeout:10 handler:^(NSError * _Nullable error) {
        if (error) {
            success = false;
        }
    }];
}

-(void)onVolumeChanged:(float)volume {
    [[UADSWebViewApp getCurrentApp] sendEvent:@"VOLUME_CHANGED" category:@"DEVICEINFO" param1:[NSNumber numberWithFloat:volume]];
}
@end
