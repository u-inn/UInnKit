#
# Be sure to run `pod lib lint UInnKit.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'UInnKit'
  s.version          = '0.1.1'
  s.summary          = 'Some useful sdks for ios development'
  s.swift_version    = '4.2'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
Some useful sdks for ios development, currently we provide IAP, Push, Network and basic utitlies
                       DESC

  s.homepage         = 'https://github.com/u-inn/UInnKit'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Theo Chen' => 'me@theochen.com' }
  s.source           = { :git => 'https://github.com/u-inn/UInnKit.git', :tag => s.version.to_s }
  s.social_media_url = 'http://www.u-inn.cn'

  s.ios.deployment_target = '9.3'
  
  s.static_framework = true
  
  # s.resource_bundles = {
  #   'UInnKit' => ['UInnKit/Assets/*.png']
  # }

  s.source_files = 'UInnKit/Classes/*.swift'
  #s.public_header_files = 'UInnKit/Classes/*.h'
  
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
  
  # 基础模块
  s.subspec 'Utils' do |ss|
      ss.source_files = 'UInnKit/Classes/Utils/**/*.{swift,m,h}'
    ss.public_header_files = 'UInnKit/Classes/Utils/*.h'
  end
  
  # 内购模块
  s.subspec 'IAP' do |ss|
      ss.dependency 'RxSwift'
      ss.dependency 'Alamofire'
      ss.dependency 'UInnKit/Utils'
      ss.source_files = 'UInnKit/Classes/IAP/**/*.swift'
  end
  
  # 推送模块
  s.subspec 'Push' do |ss|
    ss.dependency 'RxSwift'
    ss.dependency 'Alamofire'
    s.dependency 'Firebase/Core', '~> 5.12.0'
    s.dependency 'Firebase/Messaging'
    s.dependency 'AlicloudPush', '~> 1.9.8'
    ss.dependency 'UInnKit/Utils'
    
    ss.source_files = 'UInnKit/Classes/Push/**/*.{swift,m,h}'
    ss.public_header_files = 'UInnKit/Classes/Push/*.h'

  end
  
  # 网络模块
  s.subspec 'Network' do |ss|
    ss.dependency 'RxSwift'
    ss.dependency 'Alamofire'
    ss.dependency 'UInnKit/Utils'
    
    ss.source_files = 'UInnKit/Classes/Network/**/*.swift'
  end
  
  
end
