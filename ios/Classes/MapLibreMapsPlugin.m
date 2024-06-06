#import "MapLibreMapsPlugin.h"
#import <maplibre_gl/maplibre_gl-Swift.h>

@implementation MapLibreMapsPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftMapLibreGlFlutterPlugin registerWithRegistrar:registrar];
}
@end
