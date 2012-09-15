//
//  YACachedLayer.m
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

#import "YACachedLayer.h"
#import <objc/runtime.h>

#ifdef YACachedLayerUsesPrivateFrameworks
CFTypeID CABackingStoreGetTypeID();
CGImageRef CABackingStoreGetCGImage(void *store);
#endif

typedef enum {
  CacheHitTypeMiss,
  CacheHitTypeDisk,
  CacheHitTypeMemory
} CacheHitType;

static NSCache *__memoryCache;

@interface YACachedLayer ()
+ (NSArray *)filesBelongingToCacheKey:(NSString *)key;
- (NSString *)pathForCacheKey:(NSString *)key;
- (UIImage *)imageFromCurrentState;
- (void)storeImage:(UIImage *)image atPath:(NSString *)path;
@end

@implementation YACachedLayer

@synthesize cacheKey = _cacheKey;

+ (NSString *)cacheDirectory {
  return [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
}

+ (NSCache *)memoryCache {
  if (!__memoryCache) {
    __memoryCache = [[NSCache alloc] init];
  }
  return __memoryCache;
}

+ (unsigned long long)sizeForCacheKey:(NSString *)key {
  unsigned long long size = 0;
  NSDictionary *attributes;
  NSError *error;
  NSString *path;

  NSArray *files = [self filesBelongingToCacheKey:key];
  NSString *cacheDirectory = [self cacheDirectory];
  NSFileManager *fileManager = [NSFileManager defaultManager];

  for (NSString *filename in files) {
    path = [cacheDirectory stringByAppendingPathComponent:filename];
    attributes = [fileManager attributesOfItemAtPath:path error:&error];
    size += [attributes fileSize];
  }

  return size;
}

+ (void)purgeCacheForCacheKey:(NSString *)key {
  NSArray *files = [self filesBelongingToCacheKey:key];

#if YACachedLayerDebug
  NSLog(@"Purging %d image(s) from cache", files.count);
#endif

  NSError *error;
  NSString *path;
  for (NSString *filename in files) {
    path = [[self cacheDirectory] stringByAppendingPathComponent:filename];

    // remove image from memory cache
    [[self memoryCache] removeObjectForKey:path];

    // remove image from disk
    if (![[NSFileManager defaultManager] removeItemAtPath:path error:&error]) {
      NSLog(@"YACachedLayer - purgeCacheForCacheKey: Unable to remove file '%@' (%@)", path, error);
    }
  }
}

+ (NSArray *)filesBelongingToCacheKey:(NSString *)key {
  NSError *error;
  NSArray *files;

  NSString *cacheDirectory = [self cacheDirectory];
  NSFileManager *fileManager = [NSFileManager defaultManager];
  files = [fileManager contentsOfDirectoryAtPath:cacheDirectory error:&error];

  if (error) {
    NSLog(@"YACachedLayer - filesBelongingToCacheKey: Unable to scan cache directory '%@' (%@)", cacheDirectory, error);
    return [NSArray new];
  }

  NSString *predicateString = [NSString stringWithFormat:@"SELF BEGINSWITH '%@-'", key];
  NSPredicate *predicate = [NSPredicate predicateWithFormat:predicateString];

  return [files filteredArrayUsingPredicate:predicate];
}

#pragma mark -

- (id)init {
  if ((self = [super init])) {
    self.needsDisplayOnBoundsChange = YES;
    self.contentsScale = [[UIScreen mainScreen] scale];
  }
  return self;
}

- (id)initWithCacheKey:(NSString *)cacheKey {
  if ((self = [self init])) {
    self.cacheKey = cacheKey;
  }
  return self;
}

- (NSString *)formattedValueForKey:(NSString *)key {
  // use if you need to cache different states for the layer
  // return a string with the value for the key given
  // or nil to exclude the key from the list
  return nil;
}

- (NSString *)pathForCacheKey:(NSString *)key {
  NSString *dir = [[self class] cacheDirectory];
  NSString *path = [dir stringByAppendingPathComponent:key];

  // add size to filename
  CGSize size = self.bounds.size;
  path = [path stringByAppendingFormat:@"-%.0f%.0f", size.width, size.height];

  // append properties defined with formattedValueForKey as "-<key><formattedValue>"
  unsigned int outCount, i;
  objc_property_t *properties = class_copyPropertyList([self class], &outCount);
  for(i = 0; i < outCount; i++) {
    objc_property_t property = properties[i];
    const char *propName = property_getName(property);
    if (propName) {
      NSString *propertyKey = [NSString stringWithCString:propName encoding:NSUTF8StringEncoding];
      NSString *formattedValue = [self formattedValueForKey:propertyKey];
      if (formattedValue != nil) {
        path = [path stringByAppendingFormat:@"-%@%@", propertyKey, formattedValue];
      }
    }
  }
  free(properties);

  // add scale using Apple's @<scale>x format
  CGFloat scale = [UIScreen mainScreen].scale;
  if (scale != 1) {
    path = [path stringByAppendingFormat:@"@%.0fx", scale];
  }

  // finally add png file extension
  path = [path stringByAppendingPathExtension:@"png"];

  return path;
}

- (void)display {
  NSString *imagePath;
  UIImage *cacheImage;
  CacheHitType hit = CacheHitTypeMemory;

#if YACachedLayerDebug
  NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
#endif

  if (_cacheKey) {
    imagePath = [self pathForCacheKey:_cacheKey];
    cacheImage = [[[self class] memoryCache] objectForKey:imagePath];
    if (!cacheImage) {
      cacheImage = [UIImage imageWithContentsOfFile:imagePath];
      hit = CacheHitTypeDisk;
    }
  } else {
    NSLog(@"YACachedLayer - display: Warning no cache key set, drawing is not cached");
  }

  // no image found on disk or in memory - draw it
  if (!cacheImage) {
    hit = CacheHitTypeMiss;
    cacheImage = [self imageFromCurrentState];
  }

  self.contents = (__bridge id)cacheImage.CGImage;

  if (!_cacheKey) return;

  // store image in memory cache
  if (hit != CacheHitTypeMemory) {
    [[[self class] memoryCache] setObject:cacheImage forKey:imagePath];
  }

  if (hit == CacheHitTypeMiss) {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
    dispatch_async(queue, ^{
      // store image on disk
      [self storeImage:cacheImage atPath:imagePath];
    });
  }

#if YACachedLayerDebug
  NSLog(@"Layer=%p Cache=%d Time=%.0fms\n  %@", self, hit,
        ([NSDate timeIntervalSinceReferenceDate] - start) * 1000,
        imagePath);
#endif
}

- (UIImage *)imageFromCurrentState {
  UIImage *rv;

#ifdef YACachedLayerUsesPrivateFrameworks
  [super display];
  CGImageRef image = (__bridge CGImageRef)self.contents;
  if (image && CFGetTypeID(image) != CGImageGetTypeID()) {
    if (CFGetTypeID(image) == CABackingStoreGetTypeID()) {
      image = CABackingStoreGetCGImage(image);
      rv = [UIImage imageWithCGImage:image];
    } else {
      NSLog(@"Error: contents is not a CABackingStore (%@)", image);
    }
  } else {
    NSLog(@"Error: no image loaded to contents");
  }
#else
  UIGraphicsBeginImageContextWithOptions(self.bounds.size, self.opaque, self.contentsScale);
  [self drawInContext:UIGraphicsGetCurrentContext()];
  rv = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
#endif

  return rv;
}

- (void)storeImage:(UIImage *)image atPath:(NSString *)path {
  NSData *imageData = UIImagePNGRepresentation(image);
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if (![fileManager createFileAtPath:path contents:imageData attributes:nil]) {
    NSLog(@"YACachedLayer - storeImage:atPath: Could not save image %@ to %@", image, path);
  }
}

- (BOOL)cacheIfNeeded {
  if (!_cacheKey) {
    NSLog(@"YACachedLayer - cacheIfNeeded Can not cache, no cache key set");
    return NO;
  }

  NSString *path = [self pathForCacheKey:_cacheKey];
  NSFileManager *fileManager = [NSFileManager defaultManager];
  if (![fileManager fileExistsAtPath:path]) {
    [self storeImage:[self imageFromCurrentState] atPath:path];
    return YES;
  }

  return NO;
}

@end
