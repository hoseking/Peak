Pod::Spec.new do |s|
  s.name         = "Peak"
  s.version      = "1.2.0"
  s.summary      = "A collection of iOS and OS X audio tools, written in Swift."
  s.homepage     = "https://github.com/hoseking/Peak"
  s.license      = "MIT"
  s.author       = { "hoseking" => "steviehosking@gmail.com" }
  s.ios.deployment_target = "8.0"
  s.osx.deployment_target = "10.9"
  s.source       = { :git => "https://github.com/hoseking/Peak.git", :tag => s.version }
  s.frameworks   = "AudioToolbox"
  s.default_subspec = "Audio"

  s.subspec "Audio" do |sp|
    sp.source_files = "Source/Audio/**/*"
  end

  s.subspec "AudioFile" do |sp|
    sp.source_files = "Source/AudioFile/**/*"
  end

  s.subspec "MIDI" do |sp|
    sp.source_files = "Source/MIDI/**/*"
  end
end
