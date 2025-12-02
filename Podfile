# Uncomment the next line to define a global platform for your project
platform :ios, '13.0'

target 'AudioSafety' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Agora Audio-Only SDK (matching Android version 4.4.0)
  pod 'AgoraAudio_iOS', '4.4.0'

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
    end
  end
end
