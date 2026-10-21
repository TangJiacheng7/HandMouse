# HandMouse

用 Mac 摄像头控制鼠标的开源原型。

HandMouse 在本机通过 Apple Vision 识别手部关键点，将食指移动映射为指针
控制，并用拇指与食指捏合完成点击和拖动。视频帧只在内存中处理，不会保存
或上传。

## 功能

- 摄像头实时手部关键点与骨架预览
- 食指相对移动控制指针
- 拇指与食指捏合点击、保持捏合拖动
- 五指张开暂停，左右挥掌横向滚动
- One Euro 指针平滑与捏合迟滞，降低抖动和误点击
- 内置相机、桌上视角相机与连续互通相机选择
- `⌃⌥⌘Esc` 紧急暂停

## 环境

- macOS 14 或更高版本
- Apple Silicon 或 Intel Mac
- Xcode Command Line Tools

## 构建

```sh
git clone git@github.com:TangJiacheng7/HandMouse.git
cd HandMouse
./scripts/check_all.sh
open outputs/HandMouse.app
```

首次使用时：

1. 允许 HandMouse 使用摄像头。
2. 点击“开始控制”。
3. 在“系统设置 → 隐私与安全性 → 辅助功能”中允许 HandMouse。
4. 退出并重新打开 App，使权限生效。

重新构建会改变本地开发版签名；如果辅助功能不再生效，请在系统设置中移除
旧记录，再重新添加最新的 `HandMouse.app`。

## 手势

- 食指指向并移动：移动鼠标。
- 拇指和食指捏合并松开：单击。
- 捏住后移动：拖拽。
- 五指张开：暂停指针移动；快速左右挥掌：横向滚动。
- `⌃⌥⌘Esc`：随时紧急暂停。

摄像头菜单可选择 Mac 内置相机、桌上视角相机或 iPhone 连续互通相机。

## 验证

`./scripts/check_all.sh` 会运行 12 个单元测试、F0–F4 分阶段验收、
Release 构建、App 权限声明检查和运行时 smoke test。

## 隐私

HandMouse 不包含网络请求、遥测或视频录制。摄像头画面仅在当前进程内用于
手部姿态推断。

## 许可证

[MIT](LICENSE)
