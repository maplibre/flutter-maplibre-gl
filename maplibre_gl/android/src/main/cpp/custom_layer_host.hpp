// The custom layer interface of MapLibre Native, as android-sdk-opengl ships it (13.7.1:
// include/mln/style/layers/custom_layer_host.hpp and the parameter headers next to it). The SDK
// publishes no headers, so the declarations are repeated here: CustomLayer takes ownership of a
// CustomLayerHost* and calls it through this vtable. Keep it in step with the SDK version in
// build.gradle; a changed interface in a newer SDK has to be mirrored here.
#pragma once

#include <array>

namespace mln {
namespace gfx {
class Context;
} // namespace gfx

namespace style {

struct CustomLayerInitParameters {
    virtual ~CustomLayerInitParameters() = default;
};

struct CustomLayerRenderParameters {
    double width;
    double height;
    double latitude;
    double longitude;
    double zoom;
    double bearing;
    double pitch;
    double fieldOfView;
    std::array<double, 16> projectionMatrix;
    std::array<double, 16> nearClippedProjectionMatrix;
};

class CustomLayerHost {
public:
    virtual ~CustomLayerHost() = default;
    virtual void initialize(const CustomLayerInitParameters&) = 0;
    virtual void preRender(const gfx::Context&, const CustomLayerRenderParameters&) {}
    virtual void render(const CustomLayerRenderParameters&) = 0;
    virtual void contextLost() = 0;
    virtual void deinitialize() = 0;
};

} // namespace style
} // namespace mln
