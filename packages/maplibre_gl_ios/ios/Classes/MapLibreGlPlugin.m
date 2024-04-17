#import "MapLibreGlPlugin.h"
#import <maplibre_gl_mobile/maplibre_gl_mobile-Swift.h>

@implementation MapLibreGlPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  [SwiftMapLibreGlPlugin registerWithRegistrar:registrar];
}
@end
