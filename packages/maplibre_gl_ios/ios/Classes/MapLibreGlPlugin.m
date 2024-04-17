#import "MapLibreGlPlugin.h"
#import <maplibre_gl_ios/maplibre_gl_ios-Swift.h>

@implementation MapLibreGlPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  [SwiftMapLibreGlPlugin registerWithRegistrar:registrar];
}
@end
