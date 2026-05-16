require 'json'

package = JSON.parse(File.read(File.join(__dir__, 'package.json')))

Pod::Spec.new do |s|
  s.name         = 'react-native-advanced-share-intent'
  s.version      = package['version']
  s.summary      = package['description']
  s.license      = package['license']
  s.authors      = package['author']
  s.homepage     = package['homepage']
  s.source       = { :git => package['repository']['url'], :tag => "#{s.version}" }
  s.module_name  = 'AdvancedShareIntent'
  s.platforms    = { :ios => '13.0' }
  s.source_files = 'ios/**/*.{h,m,mm,swift}'
  s.requires_arc = true
  s.dependency 'React-Core'
end
