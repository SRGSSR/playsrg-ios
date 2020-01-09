source 'https://github.com/CocoaPods/Specs.git'

platform :ios, '9.0'
inhibit_all_warnings!

abstract_target 'PlaySRG' do
  pod 'AutoCoding', '~> 2.2.3'
  pod 'BDKCollectionIndexView', '~> 2.0.0'
  pod 'Firebase/RemoteConfig', '~> 5.15.0'
  pod 'FSCalendar', '2.7.9'
  pod 'google-cast-sdk-no-bluetooth', '~> 4.4.6' 
  pod 'InAppSettingsKit', '~> 2.10.0'
  pod 'MGSwipeTableCell', '~> 1.6.8'
  pod 'paper-onboarding', '~> 6.1.3'
  pod 'SwiftMessages', '~> 7.0.0'
  pod 'UrbanAirship-iOS-SDK', '9.4.0'
  
  target 'Play SRF' do
  end

  target 'Play RSI' do
  end

  target 'Play RTS' do
  end

  target 'Play RTR' do
  end

  target 'Play SWI' do
  end

  project 'PlaySRG.xcodeproj', 'Debug' => :debug, 'Nightly' => :release, 'Beta' => :release, 'AppStore' => :release
end

# Fix deployment target warnings. See https://stackoverflow.com/questions/37160688/set-deployment-target-for-cocoapodss-pod
post_install do |lib|
  lib.pods_project.targets.each do |target|
      target.build_configurations.each do |config|
          config.build_settings.delete 'IPHONEOS_DEPLOYMENT_TARGET'
      end
  end
end
