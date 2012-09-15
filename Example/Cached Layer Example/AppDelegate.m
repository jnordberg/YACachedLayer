//
//  AppDelegate.m
//  Cached Layer Example
//
//  Created by Johan Nordberg on 2012-07-10.
//  Copyright (c) 2012 FFFF00 Agents AB. All rights reserved.
//

#import "AppDelegate.h"
#import "ExampleLayer.h"

#define kLayerCacheKey @"Example"

@interface AppDelegate () {
  ExampleLayer *layer;
  UIProgressView *progress;
  UIButton *purgeButton;
  UIButton *preloadButton;
}

@end

@implementation AppDelegate

@synthesize window = _window;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

  CGRect bounds = [[UIScreen mainScreen] bounds];

  self.window = [[UIWindow alloc] initWithFrame:bounds];
  self.window.backgroundColor = [UIColor whiteColor];

  layer = [[ExampleLayer alloc] initWithCacheKey:kLayerCacheKey];
  layer.frame = bounds;
  layer.opaque = YES;
  layer.actions = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                   [NSNull null], @"contents",
                   nil];
  [self.window.layer addSublayer:layer];

  [self setupBullshitUIInFrame:bounds];

  [NSTimer scheduledTimerWithTimeInterval:5
                                   target:self
                                 selector:@selector(updateCacheSizeDisplay)
                                 userInfo:nil
                                  repeats:YES];

  return YES;
}

- (void)updateCacheSizeDisplay {
  dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0ul);
  dispatch_async(queue, ^{
    unsigned long long cacheSize = [ExampleLayer sizeForCacheKey:kLayerCacheKey];
    float size = (float)cacheSize / 1000;
    NSString *stuffix = @"kb";
    if (size > 999) {
      size /= 1000;
      stuffix = @"mb";
    }

    NSString *buttonText = [NSString stringWithFormat:@"Purge cache (%.0f%@)", size, stuffix];

    dispatch_sync(dispatch_get_main_queue(), ^{
      [purgeButton setTitle:buttonText forState:UIControlStateNormal];
    });
  });
}

- (void)purgeCache {
  [ExampleLayer purgeCacheForCacheKey:kLayerCacheKey];
}

- (void)startPreload {
  // preloads all possible states of the example layer in the background

  // show progress bar
  progress.hidden = NO;
  preloadButton.enabled = NO;
  [UIView animateWithDuration:0.8 animations:^{
    progress.alpha = 1;
  }];

  NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
  __block NSUInteger num_drawn = 0;

  // start drawing all states in a background thread
  dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
  dispatch_async(queue, ^{
    ExampleLayer *l = [[ExampleLayer alloc] initWithCacheKey:kLayerCacheKey];
    l.frame = [UIScreen mainScreen].bounds;

    for (int i = 0; i < kExampleLayerNumStates + 1; i++) {
      // use a autoreleasepool otherwise the memory might grow too much before the loop is done
      @autoreleasepool {
        l.hue = ((float)i / kExampleLayerNumStates);
         // tell layer to draw directly into cache
        NSTimeInterval s = [NSDate timeIntervalSinceReferenceDate];
        if ([l cacheIfNeeded]) {
          num_drawn++;
          NSLog(@"Finished caching %d in %fms", i, ([NSDate timeIntervalSinceReferenceDate] - s) * 1000);
        }
        
        // send a message to the main thread with a progress update
        dispatch_sync(dispatch_get_main_queue(), ^{
          [self preloadUpdate:i];
        });
      }
    }

    dispatch_sync(dispatch_get_main_queue(), ^{
      NSTimeInterval delta = [NSDate timeIntervalSinceReferenceDate] - start;
      NSLog(@"Loaded %d images in %f seconds (avg: %.0f)", num_drawn, delta, delta / num_drawn);
      [self preloadFinished];
    });
  });
}

- (void)preloadUpdate:(int)currentIndex {
  progress.progress = (float)currentIndex / kExampleLayerNumStates;
  progress.progressTintColor = [UIColor colorWithHue:progress.progress saturation:0.6 brightness:0.4 alpha:1];
}

- (void)preloadFinished {
  [UIView animateWithDuration:0.8 animations:^{
    progress.alpha = 1;
  } completion:^(BOOL finished) {
    progress.hidden = YES;
    preloadButton.enabled = YES;
  }];
  [self updateCacheSizeDisplay];
}

- (void)sliderChange:(UISlider *)sender {
  sender.thumbTintColor = [UIColor colorWithHue:sender.value
                                     saturation:0.8 brightness:0.4 alpha:1];
  layer.hue = sender.value;
}

- (void)startAnimation:(UIButton *)sender {
  CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"hue"];
  //anim.fromValue = [NSNumber numberWithFloat:0];
  anim.toValue = [NSNumber numberWithFloat:1];
  anim.fillMode = kCAFillModeBackwards;
  anim.duration = 2.0;
  [layer addAnimation:anim forKey:@"hueAnimation"];
}

- (void)setupBullshitUIInFrame:(CGRect)_bounds {
  const CGFloat pad = 8;

  CGRect bounds = _bounds;

  bounds.origin.y = _bounds.size.height - 30 - pad;
  bounds.origin.x += pad;
  bounds.size.height = 30;
  bounds.size.width -= pad * 2 + 75;
  
  UISlider *slider = [[UISlider alloc] initWithFrame:bounds];
  [slider setMaximumTrackTintColor:[UIColor blackColor]];
  [slider setMinimumTrackTintColor:[UIColor blackColor]];
  [slider addTarget:self action:@selector(sliderChange:) forControlEvents:UIControlEventValueChanged];
  slider.minimumValue = 0.0;
  slider.maximumValue = 1.0;
  [self sliderChange:slider];
  
  bounds.origin.x += 4;
  bounds.origin.y -= 20;
  bounds.size.height = 20;
  bounds.size.width -= 4 * 2;
  
  progress = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
  progress.frame = bounds;
  progress.hidden = YES;
  progress.alpha = 0;
  progress.progressTintColor = [UIColor blackColor];
  
  bounds.size.height = 25;
  bounds.size.width = 65;
  bounds.origin.x = _bounds.size.width - bounds.size.width - 8;
  bounds.origin.y = _bounds.size.height - bounds.size.height - 8;
  
  UIButton *animateButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
  animateButton.frame = bounds;
  [animateButton setTitle:@"Animate" forState:UIControlStateNormal];
  [animateButton addTarget:self action:@selector(startAnimation:) forControlEvents:UIControlEventTouchUpInside];

  bounds.origin.y = 18;
  bounds.origin.x = _bounds.size.width - 8 - 110;
  bounds.size.width = 110;
  bounds.size.height = 40;
  
  preloadButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
  preloadButton.frame = bounds;
  [preloadButton setTitle:@"Start preload" forState:UIControlStateNormal];
  [preloadButton setTitle:@"Loading..." forState:UIControlStateDisabled];
  [preloadButton addTarget:self action:@selector(startPreload) forControlEvents:UIControlEventTouchUpInside];
  
  bounds.origin.x = 8;
  bounds.size.width = 180;
  
  purgeButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
  purgeButton.frame = bounds;
  [purgeButton addTarget:self action:@selector(purgeCache) forControlEvents:UIControlEventTouchUpInside];
  [self updateCacheSizeDisplay];

  [self.window addSubview:slider];
  [self.window addSubview:animateButton];
  [self.window addSubview:progress];
  [self.window addSubview:preloadButton];
  [self.window addSubview:purgeButton];
  [self.window makeKeyAndVisible];
}

@end
