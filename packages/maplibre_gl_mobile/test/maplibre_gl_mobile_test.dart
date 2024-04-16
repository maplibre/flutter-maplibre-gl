// import 'package:flutter_test/flutter_test.dart';
// import 'package:maplibre_gl_mobile/maplibre_gl_mobile.dart';
// import 'package:maplibre_gl_mobile/maplibre_gl_mobile_platform_interface.dart';
// import 'package:maplibre_gl_mobile/maplibre_gl_mobile_method_channel.dart';
// import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// class MockMaplibreGlMobilePlatform
//     with MockPlatformInterfaceMixin
//     implements MaplibreGlMobilePlatform {

//   @override
//   Future<String?> getPlatformVersion() => Future.value('42');
// }

// void main() {
//   final MaplibreGlMobilePlatform initialPlatform = MaplibreGlMobilePlatform.instance;

//   test('$MethodChannelMaplibreGlMobile is the default instance', () {
//     expect(initialPlatform, isInstanceOf<MethodChannelMaplibreGlMobile>());
//   });

//   test('getPlatformVersion', () async {
//     MaplibreGlMobile maplibreGlMobilePlugin = MaplibreGlMobile();
//     MockMaplibreGlMobilePlatform fakePlatform = MockMaplibreGlMobilePlatform();
//     MaplibreGlMobilePlatform.instance = fakePlatform;

//     expect(await maplibreGlMobilePlugin.getPlatformVersion(), '42');
//   });
// }
