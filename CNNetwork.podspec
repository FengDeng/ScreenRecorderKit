
Pod::Spec.new do |s|
  s.name             = 'ScreenRecorder'
  s.version          = '1.0.0'
  s.summary          = 'A short description of ScreenRecorder.'


  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC
  s.homepage         = 'https://github.com/704292743@qq.com/ScreenRecorder'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { '704292743@qq.com' => '704292743@qq.com' }
  s.source           = { :git => 'git@git.51wakeup.cn:iOS-Team/CNNetwork.git', :branch => 'master' }

  s.platform     = :ios, "8.0"
  s.swift_version = "4.1"
  s.source_files = 'CNNetwork/Classes/**/*'

  s.dependency "RxSwift"
  s.dependency "Alamofire"
end
