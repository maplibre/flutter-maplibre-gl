#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'maplibre_gl'
  s.version          = '0.25.0'
  s.summary          = 'MapLibre GL Flutter plugin'
  s.description      = <<-DESC
MapLibre GL Flutter plugin.
                       DESC
  s.homepage         = 'https://maplibre.org'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'MapLibre' => 'info@maplibre.org' }
  s.source           = { :path => '.' }
  s.source_files = 'maplibre_gl/Sources/maplibre_gl/**/*'
  s.dependency 'Flutter'
  # When updating the dependency version,
  # make sure to also update the version in Package.swift.
  s.dependency 'MapLibre', '6.19.1'
  s.swift_version = '5.0'
  s.ios.deployment_target = '13.0'
end

