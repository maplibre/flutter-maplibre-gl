#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'maplibre_gl'
  s.version          = '0.0.1'
  s.summary          = 'A new Flutter plugin.'
  s.description      = <<-DESC
A new Flutter plugin.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'maplibre_gl/Sources/maplibre_gl/**/*'
  s.dependency 'Flutter'
  # When updating the dependency version,
  # make sure to also update the version in Package.swift.
  s.dependency 'MapLibre', '6.5.0'
  s.swift_version = '5.0'
  s.ios.deployment_target = '12.0'
end

