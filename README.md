# FilterChain

A lightweight Metal-based filter pipeline for camera and video apps on iOS. Feed live camera frames or still images through a sequence of fullscreen fragment shader passes, with zero texture allocation overhead per frame.

## Installation

Add the package via Swift Package Manager:

```swift
.package(url: "https://github.com/minoltax700/FilterChain", from: "0.1.0")
```

Or add it as a local package in Xcode via **File → Add Package Dependencies**.

## Usage

### Live camera preview (pull-based)

Create a `FilterChain`, set it as your `MTKView`'s delegate, and feed it camera frames:

```swift
let view = MTKView()
view.device = MTLCreateSystemDefaultDevice()
view.colorPixelFormat = .bgra8Unorm

if let filterChain = FilterChain(pixelFormat: .bgra8Unorm) {
    view.delegate = filterChain
    // feed frames from AVCaptureVideoDataOutputSampleBufferDelegate:
    filterChain.updateInput(sampleBuffer: sampleBuffer)
}
```

`FilterChain` renders on every `MTKView` draw tick using whatever the most recent input frame was.

### Still image / offline (push-based)

```swift
// From a CVPixelBuffer:
let outputPixelBuffer = try filterChain.render(pixelBuffer: inputPixelBuffer)

// From a MTLTexture:
let outputTexture = try filterChain.render(texture: inputTexture)

// Into a texture you already own:
try filterChain.render(inputTexture: inputTexture, to: outputTexture)
```

### Applying filters

```swift
let grain = Filter(fragmentFunction: "grainFragment", bundle: .main)
let vignette = Filter(fragmentFunction: "vignetteFragment", bundle: .main)

try filterChain.setFilters([grain, vignette])
```

Filters are applied in order. Call `setFilters([])` to revert to pass-through. Each `setFilters` call rebuilds the pipeline state objects, so avoid calling it on every frame.

## Creating a custom filter

A filter is a Metal fragment function in a compiled `.metal` file. Add the file to your target, then reference the function by name when creating a `Filter`.

### Fragment shader contract

Every fragment shader receives:
- `VSOut in [[stage_in]]` — interpolated vertex data including UV coordinates (`in.uv`)
- `texture2d<float> source [[texture(0)]]` — the previous stage's output (or the original input for the first filter)

The `VSOut` struct from FilterChain's vertex shader:

```metal
struct VSOut {
    float4 position [[position]];
    float2 uv;       // (0,0) top-left, (1,1) bottom-right
};
```

Your fragment function must match this input signature:

```metal
fragment float4 myFilterFragment(VSOut in [[stage_in]],
                                 texture2d<float> source [[texture(0)]]);
```

### Example: grayscale filter

```metal
#include <metal_stdlib>
using namespace metal;

struct VSOut {
    float4 position [[position]];
    float2 uv;
};

fragment float4 grayscaleFragment(VSOut in [[stage_in]],
                                  texture2d<float> source [[texture(0)]]) {
    constexpr sampler s(filter::linear);
    float4 color = source.sample(s, in.uv);
    float luma = dot(color.rgb, float3(0.299, 0.587, 0.114));
    return float4(luma, luma, luma, color.a);
}
```

Register it:

```swift
let grayscale = Filter(fragmentFunction: "grayscaleFragment", bundle: .main)
try filterChain.setFilters([grayscale])
```

### Filters in a Swift Package

If your filter lives in its own Swift package, pass `Bundle.module` instead of `.main`:

```swift
let grayscale = Filter(fragmentFunction: "grayscaleFragment", bundle: .module)
```

## How chaining works

FilterChain keeps a pair of intermediate Metal textures (ping-pong). For a chain of N filters:

- **N = 0** — input passes directly to output (no processing)
- **N = 1** — input → filter → output (no intermediate textures needed)
- **N ≥ 2** — input → filter₁ → ping → filter₂ → pong → … → filterₙ → output

The intermediate textures are allocated once at the current input size and reused every frame. They are only reallocated if the input resolution changes.

## Thread safety

`updateInput(sampleBuffer:)` and `updateInput(pixelBuffer:)` can be called from any thread (typically a camera data queue). The `draw(in:)` callback is driven by `MTKView` on the render thread. No explicit locking is performed on `inputTexture`; this follows the same pattern as `MTKView`-based renderers in Apple sample code where a torn read at worst drops one frame.
