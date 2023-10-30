Pod::Spec.new do |spec|
  spec.name         = "SwiftHotReload"
  spec.version      = "0.0.1"
  spec.summary      = "Hot Reload on Swift"
  spec.description  = <<-DESC
  Hot reload on swift app using at _dynamicReplacement
                   DESC
  spec.homepage     = "https://github.com/banjun/SwiftHotReload"
  spec.license      = "MIT"
  spec.author             = { "banjun" => "banjun@gmail.com" }
  spec.ios.deployment_target = "14.0"
  spec.osx.deployment_target = "11.0"
  # spec.watchos.deployment_target = "2.0"
  # spec.tvos.deployment_target = "9.0"
  spec.visionos.deployment_target = "1.0"
  spec.source       = { :git => "https://github.com/banjun/SwiftHotReload.git", :tag => "#{spec.version}" }
  spec.source_files  = "Sources/**/*.swift"
  spec.swift_version = "5.1"
end
