//
//  YACachedLayer.h
//  Caching Core Graphics Layer
//
//  Copyright (c) 2012 Johan Nordberg <code@johan-nordberg.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this
//  software and associated documentation files (the "Software"), to deal in the Software
//  without restriction, including without limitation the rights to use, copy, modify,
//  merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
//  permit persons to whom the Software is furnished to do so, subject to the
//  following conditions:
//
//  The above copyright notice and this permission notice shall be included
//  in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
//  INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
//  PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
//  OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
//  SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import <QuartzCore/QuartzCore.h>

#ifndef YACachedLayerDebug
// set to 1 to enable cache logging
#define YACachedLayerDebug 0
#endif

@interface YACachedLayer : CALayer

// key used to store the layers bitmap data to disk after drawing
// must be set for the cache to work
@property (nonatomic, strong) NSString *cacheKey;

- (id)initWithCacheKey:(NSString *)cacheKey;

// directory where bitmapdata is stored, default implementation uses NSCachesDirectory
+ (NSString *)cacheDirectory;

// the shared memory cache object
+ (NSCache *)memoryCache;

// deletes all cached images for specified key
+ (void)purgeCacheForCacheKey:(NSString *)key;

// returns the current disk usage for the specified key
+ (unsigned long long)sizeForCacheKey:(NSString *)key;

// subclasses can implement this to allow different states to be cached
// default implementation returns nil for all keys, which means omit the key from cache
- (NSString *)formattedValueForKey:(NSString *)key;

// draws the layers current state and saves to disk
// returns YES if a image was drawn
// can be called from a background thread
- (BOOL)cacheIfNeeded;

@end

// set this to enable usage of private frameworks to load imagedata back from
// the layer.contents (CABackingStore) - use only for testing!
//#define YACachedLayerUsesPrivateFrameworks 1

//
// results
//
// using private frameworks
// Loaded 21 images in 24.501442 seconds (avg: 1.166735)
// Loaded 21 images in 24.487525 seconds (avg: 1.166073)
// Loaded 21 images in 24.560788 seconds (avg: 1.169561)
//
// using own draw implementation
// Loaded 21 images in 24.757300 seconds (avg: 1.178919)
// Loaded 21 images in 24.703683 seconds (avg: 1.176366)
// Loaded 21 images in 24.700365 seconds (avg: 1.176208)
//
