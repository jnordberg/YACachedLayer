//
//  CachedView.m
//  Cached Layer Example
//
//  Created by Johan Nordberg on 2012-07-10.
//  Copyright (c) 2012 FFFF00 Agents AB. All rights reserved.
//

#import "CachedView.h"
#import "YACachedLayer.h"

// example of how you could implement a cache backed UIView

#define kCacheKey @"MyCachedView"

@implementation CachedView

+ (Class)layerClass {
  return [YACachedLayer class];
}

- (id)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    ((YACachedLayer *)self.layer).cacheKey = kCacheKey;
  }
  return self;
}

- (void)drawRect:(CGRect)rect {
  // do some drawing
}

@end
