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
// or iOS, so CI runs it on its own on web.
import 'android_feature_drag_test.dart' as android_feature_drag;
import 'annotations_test.dart' as annotations;
import 'camera_test.dart' as camera;
import 'geojson_query_test.dart' as geojson_query;
import 'haptic_feedback_test.dart' as haptic_feedback;
import 'pan_inertia_test.dart' as pan_inertia;
import 'style_layers_test.dart' as style_layers;
import 'style_misc_test.dart' as style_misc;
import 'web_feature_state_test.dart' as web_feature_state;

void main() {
  android_feature_drag.main();
  annotations.main();
  camera.main();
  geojson_query.main();
  haptic_feedback.main();
  pan_inertia.main();
  style_layers.main();
  style_misc.main();
  web_feature_state.main();
}
