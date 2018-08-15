# ScreenRecorderKit

##Features

支持录制UIView及其子类
代理回调
分段录制
回删
随时预览
异常情况自动暂停


##Cocoapods

##Usage


###start or pause
```
let recorder = SRViewRecorder.init(view: self.view!, folderName: "recorders")
recorder.start()
recorder.pause()
```

###delegate

```
onViewRecorderPaused
onViewRecorderStarted
onViewRecorderProgressing(seconds: CGFloat)
onViewRecorderProgressing(seconds: CGFloat)
onViewRecorderError(error: Error)
```


###and more

please read codes