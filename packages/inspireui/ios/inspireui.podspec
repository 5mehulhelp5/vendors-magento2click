#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint inspireui.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'inspireui'
  s.version          = '1.0.0'
  s.summary          = 'Common useful and Widget Use For FluxStore Products (Flutter E-Commerce App)'
  s.description      = <<-DESC
A new Flutter plugin project.
                       DESC
  s.homepage         = 'https://inspireui.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'InspireUI' => 'hi@inspireui.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '9.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
