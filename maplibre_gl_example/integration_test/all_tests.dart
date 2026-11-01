// Runs every integration test in one app launch.
//
// `flutter test integration_test` installs and starts the app once per file,
// and on an emulator the later launches sometimes fail to connect ("Failed to
// load ... Connection closed before full header was received"). One entry
// point avoids that and builds once, which is also what CI runs:
//
//   flutter test integration_test/all_tests.dart -d <device id>
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/all_tests.dart -d web-server
//
// Each file still runs on its own as well. manual_location_web_test.dart is
// not included: it imports package:web, which does not compile for Android
// or iOS, so CI runs it on its own on web. ambient_cache_size_test.dart runs
// first, so its database reset happens before any other map uses the store.
import 'add_image_size_test.dart' as add_image_size;
import 'ambient_cache_size_test.dart' as ambient_cache_size;
import 'android_feature_drag_test.dart' as android_feature_drag;
import 'android_tap_timing_test.dart' as android_tap_timing;
import 'annotations_test.dart' as annotations;
import 'attribution_test.dart' as attribution;
import 'camera_test.dart' as camera;
import 'feature_id_test.dart' as feature_id;
import 'feature_hit_tolerance_test.dart' as feature_hit_tolerance;
import 'geojson_query_test.dart' as geojson_query;
import 'haptic_feedback_test.dart' as haptic_feedback;
import 'map_lifecycle_test.dart' as map_lifecycle;
import 'my_location_style_test.dart' as my_location_style;
import 'offline_region_metadata_test.dart' as offline_region_metadata;
import 'pan_inertia_test.dart' as pan_inertia;
import 'placement_transitions_test.dart' as placement_transitions;
import 'platform_parity_test.dart' as platform_parity;
import 'polygon_hole_test.dart' as polygon_hole;
import 'style_layers_test.dart' as style_layers;
import 'style_misc_test.dart' as style_misc;
import 'web_feature_state_test.dart' as web_feature_state;

void main() {
  ambient_cache_size.main();
  add_image_size.main();
  android_feature_drag.main();
  android_tap_timing.main();
  annotations.main();
  attribution.main();
  camera.main();
  feature_id.main();
  feature_hit_tolerance.main();
  geojson_query.main();
  haptic_feedback.main();
  map_lifecycle.main();
  my_location_style.main();
  offline_region_metadata.main();
  pan_inertia.main();
  placement_transitions.main();
  platform_parity.main();
  polygon_hole.main();
  style_layers.main();
  style_misc.main();
  web_feature_state.main();
}
