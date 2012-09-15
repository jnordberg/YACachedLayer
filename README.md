
# YACachedLayer

A caching Core Animation layer

## About

YACachedLayer is a CALayer subclass that can be used to cache complex draws to
disk. It supports preloading on a background thread and caching different
states of the same layer.

## How to use

Include YACachedLayer in your project and use it as backing for a UIView.

```obj-c

@implementation CachedView

+ (Class)layerClass {
  return [YACachedLayer class];
}

- (id)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    ((YACachedLayer *)self.layer).cacheKey = @"MyCacheKey";
  }
  return self;
}

- (void)drawRect:(CGRect)rect {
  // do some drawing
}

@end
```

For more complex draws you can subclass it like you would any normal CALayer

```obj-c

@implementation ExampleLayer

- (void)drawInContext:(CGContextRef)context {
  [[UIColor redColor] setFill];
  CGContextFillRect(context, self.bounds);
}

@end
```

You can also implement `formattedValueForKey:` to cache multiple states of the layer. 
Check the source and the example project for more details.

--

Made by [Johan Nordberg](http://johan-nordberg.com) and licensed
under the [MIT-License](http://en.wikipedia.org/wiki/MIT_License)
