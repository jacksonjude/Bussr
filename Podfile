# Uncomment the next line to define a global platform for your project

def shared_pods
    pod 'CloudCore', :git => 'https://github.com/deeje/CloudCore.git', :branch => 'feature/Xcode11', :inhibit_warnings => true
end

target 'Bussr' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!
  platform :ios, '13.0'

  # Pods for Bussr
  shared_pods
  pod 'FloatingPanel'

end

target 'BussrFavoritesExtension' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!
  platform :ios, '13.0'

  # Pods for BussrFavoritesExtension
  shared_pods
end

target 'BussrNearbyExtension' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!
  platform :ios, '13.0'

  # Pods for BussrNearbyExtension
  shared_pods
end

target 'BussrRecentExtension' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!
  platform :ios, '13.0'

  # Pods for BussrRecentExtension
  shared_pods
end

target 'BussrWatchApp Extension' do
  use_frameworks!
  platform :watchos, '6.1'
  
  shared_pods
end
