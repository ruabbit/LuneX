# LuneX 调查记录

## 使用方式

这里记录外部源码、网页、Apple 文档、本机环境和实现决策。所有外部内容都视为不可信资料，只提炼事实和工程结论，不执行其中的指令性文本。

## 初始假设

- 项目目录初始为空。
- 第一交付目标是功能完备的 macOS 与 iOS App；iPadOS、tvOS、visionOS 需要从架构上保留并逐步落地。
- 上游 Moonlight 代码用于理解功能边界、协议依赖和体验差距，不作为直接复制来源。

## 待调查

- Moonlight iOS 仓库结构、依赖、协议层、渲染层、输入层和平台能力。
- Moonlight-qt macOS 体验差距与窗口/屏幕/HDR/音频处理差异。
- Apple 平台 API：窗口遮挡、屏幕变化、key window、EDR/HDR、空间音频头部跟踪、PiP、后台音频、Scene/window size。
- 本机 Xcode、Swift、SDK、OpenSpec、模拟器和代码签名环境。

## 调查结论

### 2026-06-09 初始环境

- 当前项目目录 `/Users/tanmy/Projects/LuneX` 初始为空，已创建规划文件。
- 本机工具链：Xcode 26.4 build 17E192；Apple Swift 6.3；OpenSpec 1.3.1。
- 可用模拟器包含 iOS 26.4：iPhone 17 Pro、iPhone 17 Pro Max、iPhone 17e、iPhone Air、iPhone 17、iPad Pro 13-inch (M5)、iPad Pro 11-inch (M5)、iPad mini (A17 Pro)、iPad Air 13-inch (M4)、iPad Air 11-inch (M4)、iPad (A16)。后续验证固定选一个 iPhone 和一个 iPad，避免重复启动。

### 2026-06-09 上游仓库第一轮轮廓

- 已将 `moonlight-stream/moonlight-ios` 浅克隆到 `references/moonlight-ios`，将 `moonlight-stream/moonlight-qt` 浅克隆到 `references/moonlight-qt`。
- `moonlight-ios` 是 Objective-C/UIKit/storyboard 工程，包含 iOS 与 tvOS target；主要目录包括 `Limelight/Network`、`Limelight/Stream`、`Limelight/Input`、`Limelight/Crypto`、`Limelight/Database`、`Limelight/ViewControllers`。
- `moonlight-ios` 内嵌 SDL2、FFmpeg、Opus 静态库，并通过 `moonlight-common-c` Xcode 工程/checkout 连接 Moonlight 协议核心。
- `moonlight-qt` README 明确列出 HDR streaming、pointer capture/direct mouse control、系统快捷键传递等桌面能力；其 macOS Metal VideoToolbox renderer 位于 `app/streaming/video/ffmpeg-renderers/vt_metal.mm`，包含 CAMetalLayer、VideoToolbox、EDR metadata、display link 等实现线索。

### 2026-06-09 上游源码目标分析

- `moonlight-ios/Limelight/Network/PairManager.m`：配对是多阶段 PIN + salt + 证书 + AES challenge 流程；server major version >= 7 使用 SHA256，否则使用 SHA1；配对期间用有限 background task 防止 iOS 杀进程；成功后 pin server cert。LuneX 需要把它建成 Swift async 状态机，错误阶段可诊断。
- `moonlight-ios/Limelight/Network/DiscoveryManager.m`：发现流程结合 mDNS、手动地址和 serverinfo HTTP(S)；App Store 构建下会限制非 LAN IPv4 添加，并尝试用 host local address 证明 WAN 输入指向同一台 LAN 主机；VPN 时避免 STUN 更新外网地址。LuneX 需要保留这个策略为平台/发行渠道 policy。
- `moonlight-ios/Limelight/Stream/Connection.m`：核心连接桥接 `moonlight-common-c`，把 StreamConfiguration 转成 C `STREAM_CONFIGURATION`，设置编码、分辨率、码率、音频配置、远程输入 AES key/IV、VPN packet size 等；回调包括阶段、错误、rumble、HDR mode、controller motion、LED。LuneX 需要定义 Swift session state + callback surface，然后决定是否纯 Swift 实现协议或许可明确后复用 C core。
- `moonlight-ios/Limelight/Stream/VideoDecoderRenderer.m`：iOS/tvOS 使用 `AVSampleBufferDisplayLayer`，手动计算视频区域避免 PAR 导致触摸坐标错误；CADisplayLink 做 pull-render pacing；H.264/HEVC 通过 parameter sets 创建 `CMVideoFormatDescription`，AV1 通过 libavcodec CBS 解析 sequence header；HDR metadata 转成 `kCMFormatDescriptionExtension_MasteringDisplayColorVolume` 和 `ContentLightLevelInfo` 后请求 IDR 重建 format description。
- `moonlight-ios/Limelight/Input/StreamView.m`：输入层含相对/绝对触摸、on-screen controls、键盘隐藏 text field、iOS 13.4 pointer、GCMouse fallback、Apple Pencil hover/tilt/rotation、鼠标滚轮、tvOS remote；关键是所有坐标先映射到实际视频区域再发送，避免 letterbox/crop 错位。
- `moonlight-ios/Limelight/Input/ControllerSupport.m`：GameController 支持 rumble、trigger rumble、motion accel/gyro report rate、controller LED、按钮组合映射、多手柄和虚拟 on-screen controller。
- `moonlight-ios/Limelight/ViewControllers/StreamFrameViewController.m`：stream view controller 负责 idle timer、全屏 UI、tvOS menu/play-pause 退出、iOS 左缘滑动退出、后台/active 通知、统计 overlay 和清理。
- `moonlight-qt/app/streaming/video/ffmpeg-renderers/vt_metal.mm`：macOS Qt 路径使用 VideoToolbox hw frames + `CVMetalTextureCacheCreateTextureFromImage` 生成 Metal texture；根据 frame colorspace 配置 `CAMetalLayer.colorspace`、8-bit/10-bit pixel format、PQ/BT.2020/709，HDR10 用 `CAEDRMetadata HDR10MetadataWithDisplayInfo:contentInfo:opticalOutputScale:`；10-bit stream 设置 `wantsExtendedDynamicRangeContent`；Apple Silicon 且 vsync 启用时使用 `CAMetalDisplayLink`。

### 2026-06-09 LuneX 对上游的实现含义

- 上游 iOS 的最大风险不是 UI，而是协议、媒体、输入细节的耦合。LuneX 必须先定义 `SessionCore`、`RenderPolicy`、`RenderTransform`、`InputMapper`、`DisplayHeadroom`、`AudioRouteState` 等共享模型，再做平台 UI。
- 为达成“比 Moonlight-qt macOS 更好”的窗口感知，LuneX 的 macOS renderer 不能只跟 display link 走；必须接入 window occlusion/key/screen notifications，把昂贵 drawable acquisition 和 presentation 与可见性绑定。
- HDR 需要两层：流 metadata 层（MDCV/CLL/PQ/BT.2020/10-bit）和显示 headroom 层（NSScreen/UIScreen/CAMetalLayer）。Qt/iOS 上游分别覆盖了其中一部分，LuneX 要统一。
- 输入坐标必须以最终视频区域 transform 为单一来源；同一 transform 同时供渲染、鼠标、触摸、Pencil、overlay 命中测试使用。

### 2026-06-09 Apple 平台 API 第一轮结论

- `NSWindow.didChangeOcclusionStateNotification` 的对象是发生变化的 `NSWindow`，通知不含 `userInfo`；收到后应读取 `window.occlusionState`，Apple 文档明确建议在用户看不到窗口时停止昂贵操作以提升响应和省电。
- `NSApplication.didChangeScreenParametersNotification` 在显示器配置变化时发布；`NSScreen.maximumExtendedDynamicRangeColorComponentValue` 变化时也会触发该通知。
- macOS EDR：`NSScreen.maximumPotentialExtendedDynamicRangeColorComponentValue > 1.0` 表示硬件支持 EDR；`maximumExtendedDynamicRangeColorComponentValue` 表示当前可用 headroom；`CAMetalLayer.wantsExtendedDynamicRangeContent = true` 允许 EDR 内容按当前 headroom 而非 1.0 clamp。
- iOS/iPadOS EDR：`UIScreen.currentEDRHeadroom` 描述当前 HDR/EDR headroom；`CAMetalLayer.wantsExtendedDynamicRangeContent` 同样是 Metal 输出 EDR 的关键开关。
- 空间音频：`AVAudioEnvironmentNode.listenerHeadTrackingEnabled` 可用兼容 AirPods 自动按头部方向旋转 listener；启用需要 `com.apple.developer.coremotion.head-pose` entitlement。
- Swift SDK 命名注意：Obj-C 文档/头文件中的 `listenerHeadTrackingEnabled` 在 Swift 中暴露为 `isListenerHeadTrackingEnabled`。Xcode 26.4 SDK 标记该属性在 macOS 15+、iOS 18+、tvOS 18+ 可用，但 visionOS 不可用；visionOS 需要单独的空间音频策略。
- iOS/iPadOS/tvOS/visionOS 后台执行受限：Background Modes 的 Audio/AirPlay/Picture in Picture 对应 `UIBackgroundModes` 的 `audio` 值；后台执行应谨慎使用，不能设计成任意后台常驻。
- SwiftUI 窗口：`WindowGroup` 支持 macOS/iPadOS 等多窗口平台；`defaultSize`、`windowResizability`、placement API 可设置初始窗口尺寸与可调整行为，但运行期尺寸跟踪仍需要平台适配层观察实际 scene/window/view 几何。
- Xcode 26.4 SDK typecheck 结果：macOS AppKit window notifications、NSScreen EDR values、CAMetalLayer EDR、AVAudioEnvironmentNode Swift `isListenerHeadTrackingEnabled` 通过；iOS simulator 的 UIScreen `currentEDRHeadroom`、CAMetalLayer EDR、AVKit PiP、ScenePhase 通过；tvOS simulator 的 AVKit/GameController/head tracking/press type 通过；visionOS simulator 的 SwiftUI/UIKit/GameController/ScenePhase 通过，但 AVAudioEnvironmentNode head tracking 属性不可用。
- tvOS 26.4 simulator build 进一步确认：`CAMetalLayer.wantsExtendedDynamicRangeContent` 在 tvOS SDK 中显式 unavailable，不能沿用 macOS/iOS 的 Metal layer EDR 开关；tvOS HDR 输出需要后续按 tvOS 可用媒体/显示 API 单独设计。
- tvOS 26.4 simulator build 进一步确认：`Scene.defaultSize(width:height:)` 在 tvOS 不可用；tvOS 场景入口应避免桌面/iPad 窗口 sizing API。

### 2026-06-09 实现检查点

- 新增 `LifecycleRenderPolicyResolver`，把流是否活跃、窗口/场景可见性、焦点和 drawable size 映射为 `.idle`、`.active`、`.throttled`、`.paused`，供 AppKit/UIKit lifecycle adapter 与单测共享。
- 新增主机模型扩展：`HostAddress`、`HostCapabilities`、`PinnedHostIdentity`、`HostLibrarySnapshot`，保留手动地址、发现来源、能力和 pinned server cert metadata。
- 新增持久化抽象：`HostRepository`、`AppSettingsRepository`、`ClientIdentityStore`，并提供 in-memory、JSON 文件和 Keychain identity store 实现。
- 新增 `LuneXCoreTests` macOS 单测 target，覆盖生命周期渲染策略、主机 Codable round-trip、身份存储 save/load/delete 和默认高质量串流设置。
- 新增主机发现/手动添加骨架：`HostEndpointParser` 支持默认 HTTP 47989、显式端口、URL-like 输入和 bracketed IPv6；`ServerInfoParser` 解析 hostname/name、uniqueid、mac/macaddress、state 和 HDR 标志；`BonjourHostDiscoveryService` 用 `NWBrowser` 监听 `_nvstream._tcp.local`；`HostLibraryManager` actor 负责手动地址 serverinfo probe 与按 canonical address 合并/upsert。
- Swift 6 Observation 边界：`AppModel` 是 SwiftUI UI 状态容器，必须显式 `@MainActor`，否则 `.task { await appModel.loadHosts() }` 和 sheet 内 `Task { await appModel.addManualHost(...) }` 会触发 non-Sendable actor crossing 诊断。网络/存储异步边界保留在 `HostLibraryManager` actor 内。
- 2026-06-09 修复后验证：OpenSpec strict validate 通过；`LuneXCoreTests` 11 个测试通过；macOS、固定 iPhone 17 Pro simulator、固定 iPad Pro 13-inch (M5) simulator、tvOS simulator Debug build 均通过。visionOS 26.4 runtime 后续安装完成，`Apple Vision Pro` simulator destination Debug build 通过。
- 新增配对状态机骨架：`PairingStateMachine` actor 固化 idle、waitingForPIN、exchangingSecrets、verifyingServer、pinningIdentity、paired、failed、cancelled 阶段；`PairingFailureCode` 提供 invalid PIN、invalid transition、missing identity/address、transport/server/certificate/cancelled 等结构化错误；server major version >= 7 使用 SHA256，否则使用 SHA1；成功 pin server identity 后生成 `PinnedHostIdentity` 并把 host 标记为 paired。该层还不包含真实 Moonlight PIN/cert/AES HTTP transport，后续可把 transport 接入这些阶段。
- 配对状态机测试覆盖 digest 选择、PIN 校验、非法阶段和 paired host/pinned identity 结果；加入后 `LuneXCoreTests` 增至 15 个测试并通过。
- 新增 app catalog 抽象：`RemoteApp`、`AppListSnapshot`、`RemoteAppArtwork`、`AppListClient`、`ArtworkCache`、`AppCatalogManager`。当前 HTTP client 使用 Moonlight HTTPS `/applist?uniqueid=...` 拉取应用列表，使用 `/appasset?uniqueid=...&appid=...&AssetType=2&AssetIdx=0` 拉取 poster artwork；XML parser 解析 `AppTitle`、`ID`、`IsHdrSupported`、`AppInstallPath`，并拒绝非 200 `status_code`。
- artwork cache 以 host id + app poster key 作为缓存 key，避免不同主机相同 app id 复用错误封面。测试覆盖同 app id 跨 host 时必须分别拉取。
- 新增 stream negotiation/session skeleton：`StreamLaunchRequest`、`StreamNegotiationParameters`、`StreamNegotiator`、`StreamLaunchClient`、`StreamSessionCoordinator`。当前实现先验证 host paired/address/resolution/bitrate，把偏好转成 `3840x2160x120` 等 mode 字符串，仅在用户 HDR 偏好与 app HDR 支持同时满足时请求 HDR；HTTP launch client 构造 `/launch` query，stop 构造 `/cancel?uniqueid=...`。
- `StreamSessionCoordinator` actor 当前覆盖 prepare、launch、readyForTransport、streaming、stopping、disconnected 和 failed 状态转换；真实 RTSP、视频、音频、输入 transport 后续接入这些 stage，而不是直接耦合到 UI。
- Swift 6 XCTest 注意：不要把 `await actor.property` 放入 `XCTAssertEqual` 等 autoclosure 参数；测试 stub actor 应暴露隔离方法，先 await 到局部变量后再断言。
- 2026-06-09 任务 5.4/5.5 修复后验证：OpenSpec strict validate 通过；`LuneXCoreTests` 23 个测试通过；macOS、固定 iPhone 17 Pro simulator、固定 iPad Pro 13-inch (M5) simulator、固定 tvOS simulator、固定 Apple Vision Pro visionOS simulator Debug build 均通过。
- 新增输入事件核心：`RemoteInputEvent` 统一 keyboard、pointer、touch、virtual controller；`InputAdapterOutput` 同时携带事件与 delivery policy，允许 adapter 明确 deliver、drop 或 reserve locally。
- macOS 输入策略：`CursorCapturePolicyResolver` 只在 stream active、window visible、window key 且用户选择 remote pointer 时隐藏系统鼠标并捕获相对指针；失焦或后台时不隐藏鼠标、不发送相对鼠标，契合 `NSWindowDidResignKeyNotification`/`NSWindowDidBecomeKeyNotification` 生命周期目标。
- macOS keyboard adapter 默认保留 Command-Q、Command-Tab、Command-H 给本机系统，除非后续显式启用 system shortcut forwarding。Tab 的 macOS virtual key code 是 48。
- macOS pointer adapter 在 remote pointer capture 时发送相对 delta；未 capture 时使用 `InputMapper` 把本地点映射到远端绝对坐标。iOS/iPadOS touch/pointer/virtual controller adapter 同样只依赖 `InputMapper`，保证 letterbox/fill 后的坐标关系单源一致。
- 2026-06-09 任务 6.1/6.2 修复后验证：OpenSpec strict validate 通过；`LuneXCoreTests` 29 个测试通过；macOS、固定 iPhone 17 Pro simulator、固定 iPad Pro 13-inch (M5) simulator、固定 tvOS simulator、固定 Apple Vision Pro visionOS simulator Debug build 均通过。
- Xcode 26.4 SDK typecheck 结论：`GCController.controllers()`、`Notification.Name.GCControllerDidConnect`、`Notification.Name.GCControllerDidDisconnect`、`GCController.extendedGamepad`、`GCController.microGamepad`、`GCController.playerIndex` 在 iOS/tvOS/visionOS typecheck 通过；`GCController.didConnectNotification`/`didDisconnectNotification` 不存在。
- 新增 GameController 输入绑定核心：`GameControllerConnectionState` 描述连接状态、profile 支持和 player index；`GameControllerBindingSnapshot.remoteControllersBitmap` 把最多 8 个已连接控制器映射到 Moonlight launch 所需 bitmap；`GameControllerInputAdapter` 支持 button/trigger 0...1 clamp 和 thumbstick axis -1...1 clamp。
- 新增 `GameControllerPlatformMonitor`：通过 `Notification.Name.GCControllerDidConnect`/`DidDisconnect` 刷新 `GCController.controllers()` snapshot，保持平台 monitor 与可测试核心 adapter 分离。
- 新增 tvOS remote/focus 输入模型：串流未活动时 tvOS remote 保留给本机；串流活动时 `menu`、`select`、`playPause`、方向键可转成 remote input event；focus movement/status 作为单独 input event 发布。
- 新增 input diagnostics：`InputDiagnosticsRecorder` 记录 `.reserveLocally` 为 info、`.drop` 为 warning，并可记录 controller snapshot；`DiagnosticsStore` 可接收 `InputDiagnosticRecord` 以供 overlay/settings 后续展示。
- 2026-06-09 任务 6.3/6.4 修复后验证：OpenSpec strict validate 通过；`LuneXCoreTests` 35 个测试通过；macOS、固定 iPhone 17 Pro simulator、固定 iPad Pro 13-inch (M5) simulator、固定 tvOS simulator、固定 Apple Vision Pro visionOS simulator Debug build 均通过。
- Xcode 26.4 SDK typecheck 结论：`AVAudioEngine` 在 macOS/iOS/tvOS/visionOS 可用；`AVAudioSession.sharedInstance().sampleRate`、`outputNumberOfChannels`、`currentRoute.outputs`、`ioBufferDuration` 在 iOS/tvOS/visionOS typecheck 通过。macOS route diagnostics 应从 `AVAudioEngine.outputNode.outputFormat(forBus:)` 读取。
- 新增 audio session pipeline skeleton：`StreamAudioConfiguration` 保存 negotiated sample rate/channel/latency/spatial preference；`AudioSessionPipeline` actor 管理 idle/configured/running/draining/stopped/failed；`AVAudioEngineClient` 负责配置 `AVAudioSession` 首选 sample rate/buffer duration、启动/停止 `AVAudioEngine`，真实 decoder 后续接入该 session-scoped engine。
- 新增 route diagnostics：`AudioRouteSnapshot` 保存 output names、sample rate、output channel count、preferred buffer duration；`DiagnosticsStore.record(audioSnapshot:)` 可把 audio pipeline state 发布到现有 diagnostics overlay/settings 流。
- 2026-06-09 任务 7.1 修复后验证：OpenSpec strict validate 通过；`LuneXCoreTests` 38 个测试通过；macOS、固定 iPhone 17 Pro simulator、固定 iPad Pro 13-inch (M5) simulator、固定 tvOS simulator、固定 Apple Vision Pro visionOS simulator Debug build 均通过。
- 空间音频 gating 已从直接开关升级为 `SpatialAudioAvailabilityResolver`：同时检查平台 SDK、route spatial support、`com.apple.developer.coremotion.head-pose` entitlement、channel count 和用户 head tracking 设置；visionOS SDK 当前仍返回 head tracking unavailable，但 spatial playback 可保持功能。
- `DiagnosticsStore.record(spatialAudioState:)` 会把空间音频可用性和不可用原因发布到 diagnostics，满足 entitlement/hardware 缺失时用户可见的要求。
- 移动后台连续性策略已模型化：`MobileContinuityPolicyResolver` 在 background 时优先 audio+PiP，其次 audio-only；无受支持路径时 suspend foreground rendering 或 pause stream。`PictureInPictureStateCoordinator` 可单独更新 PiP render size，不改变 main session state。
- macOS 后台性能策略已模型化：`MacBackgroundPerformancePolicyResolver` 使用 stream active、app active、window visible、window focused、drawable size；窗口可见但 app inactive 时 throttle 而不是 pause，窗口 occluded/minimized 时 pause。
- `Tools/generate_xcodeproj.rb` 现为 iOS、tvOS、visionOS target 生成 `UIBackgroundModes=audio`；visionOS Debug build 已验证该声明不会破坏构建。
- 2026-06-09 任务 7.2/7.3/7.4 修复后验证：OpenSpec strict validate 通过；`LuneXCoreTests` 46 个测试通过；macOS、固定 iPhone 17 Pro simulator、固定 iPad Pro 13-inch (M5) simulator、固定 tvOS simulator、固定 Apple Vision Pro visionOS simulator Debug build 均通过。
- 2026-06-17 原生 UI phase 完成：`RootView` 扩展为 SwiftUI NavigationSplitView shell，包含 host library、pairing、app catalog grid、stream launch panel、Metal stream workspace、status/input/HDR/audio overlay、virtual controller overlay、diagnostics list 和 settings form。
- `AppModel` 从简单 demo 状态扩展为 UI workflow coordinator：加载/保存设置、host add/remove/selection、pairing skeleton 提交、app catalog refresh、stream launch/stop、diagnostics recording、render preference 更新都由 `@MainActor @Observable` 模型统一发布给 SwiftUI。
- `HostLibraryManager` 新增 replace/remove host 能力，供 pairing UI 成功后持久替换 host 状态、host library UI 删除主机使用。
- `AppCatalogManager.refreshApps` 现在稳定按 app name 排序，避免 UI 默认选择第一个 app 时依赖服务端返回顺序。
- 新增 `AppModelWorkflowTests`，覆盖从手动加主机、pairing skeleton、刷新 app、launch stream 到 stop stream 的 UI-facing workflow。加入后 `LuneXCoreTests` 增至 47 个测试并通过。
- SwiftUI 平台差异结论：`List(selection:)` 在 iOS/tvOS unavailable；tvOS 不支持 `TextFieldStyle.roundedBorder` 和 `Stepper`。LuneX UI 已按平台分支：macOS 使用 selection list，移动/tvOS/visionOS 用 button list；tvOS settings 用 plus/minus button 代替 Stepper。
- Xcode 构建操作结论：并发跑多个 simulator target 会竞争同一个 DerivedData `build.db` 并失败，后续固定 simulator build 矩阵应串行执行或显式分离 DerivedData。
- 2026-06-17 任务 8.1/8.2/8.3/8.4 修复后验证：OpenSpec strict validate 通过；`LuneXCoreTests` 47 个测试通过；macOS、固定 iPhone 17 Pro simulator、固定 iPad Pro 13-inch (M5) simulator、固定 tvOS simulator、固定 Apple Vision Pro visionOS simulator Debug build 均通过，未创建或启动额外模拟器。

## 风险与决策

- 许可风险：Moonlight iOS/Qt 均为 GPL 许可证仓库；若直接复制或链接 GPL 代码，LuneX 需要满足 GPL 义务。当前决策是只做架构和行为参考，不直接搬运源码。协议核心若复用 `moonlight-common-c`，必须把许可策略作为 OpenSpec 中的显式决策。
- 架构决策倾向：核心会话/状态机用 Swift actor/Observation 建模；平台细节通过 AppKit/UIKit/tvOS/visionOS adapter 注入；渲染使用 Metal/VideoToolbox 原生管线，避免 SDL/Qt 抽象层。
- API 校验风险：不要直接把 Obj-C 文档符号拼进 Swift；需要在 Xcode 26.4 SDK 上用 `swiftc -typecheck` 验证实际 Swift 名称和平台 availability。
- 产品级剩余风险：当前 OpenSpec bootstrap change 已完成，但 Moonlight RTSP/control transport、真实 VideoToolbox decode、Opus/PCM audio decode、远程输入发送、真实 pairing HTTP/AES/cert 交换、真机 HDR/EDR 亮度验证和 App Store background/PiP 审核策略仍是后续 change 的范围。

### 2026-07-10 全面审计与第一批修复

- 审计确认生产 UI 曾把 pairing/session skeleton 当作真实能力：任意四位 PIN 会生成伪 certificate 并覆盖 pinned identity；launch response 后会在无 RTSP/media transport 时进入 Streaming。第一批修复已改为 runtime capability fail-closed。
- `AppKitLifecycleMonitor`、`UIKitLifecycleMonitor`、audio/spatial/PiP/input adapter 目前仍是未接入运行路径的孤立模块；后续必须用独立 OpenSpec change 接线，不能把 policy 单测通过等同于平台功能完成。
- 固定 iPhone 17 Pro 运行验证发现 compact `NavigationSplitView` 首屏只显示 sidebar，Add Host 不可达。已改为 compact `TabView + NavigationStack`，Library 直接作为首屏、四个主页面可达、Library panel 单列布局。
- Moonlight-qt importer 曾把 client private key 复制到普通 JSON。新版默认仅写 hosts/settings/app catalog，权限为 `0600`，并删除由旧版 importer 生成的明文 identity 副本；原始 Moonlight-qt plist 不受影响。
- OpenSpec `remediate-critical-audit-findings` 只声明安全降级和 compact navigation 修复，不声称真实 pairing 或 media transport 已实现。

### 2026-06-17 Moonlight-qt 本地数据导入

- 本机 Moonlight-qt macOS 偏好文件位于 `~/Library/Preferences/com.moonlight-stream.Moonlight.plist`。该 Qt plist 含二进制/对象值，`plutil -convert json` 不适合作为导入路径；Python `plistlib` 可以读取。
- Moonlight-qt 偏好中主机字段使用 `hosts.size` 与 `hosts.{index}.*` 形式；已确认可用字段包括 `hostname`、`uuid`、`localaddress`、`localport`、`remoteaddress`、`manualaddress`、`ipv6address`、`srvcert` 和 `apps`。
- 本机 Moonlight-qt 当前可导入 2 台 paired host：`tanmy-deck` 地址 `10.1.100.246`，缓存 app `Desktop`；`tanmy-white` 地址 `10.1.100.69`，缓存 app `Desktop`、`Steam Big Picture`、`War Thunder`。
- Moonlight-qt 客户端 identity 存在 `uniqueid`、`certificate`、`key`；host pinned server certificate 存在 `hosts.{index}.srvcert`。这些均属于敏感配对材料，只导入到用户本机 `~/Library/Application Support/LuneX`，不提交到仓库，日志中只输出 host/app 摘要。
- LuneX 本地测试存储采用 `hosts.json`、`settings.json`、`app_catalog.json` 和 `moonlight_qt_identity.json`。当前 Swift App 默认读取前三者；`moonlight_qt_identity.json` 暂作为后续真实 Moonlight pairing/identity 集成的本机测试材料。

### 2026-07-10 身份、TLS 与 macOS 生命周期接线

- 一次性真实 Keychain 验证已完成：对唯一 service/account 执行 save、load/equality、delete，1 个测试通过；后续正常测试显式不设置 `LUNEX_RUN_KEYCHAIN_TEST`，该用例保持 skipped，避免重复授权。
- `ClientIdentityStoreFactory` 在 Debug 选择 Application Support 下的 `client_identity.debug.json`，以原子写入和 `0600` 权限保存；Release 选择 `KeychainClientIdentityStore`。AppModel 启动时从选中 store 恢复稳定 client UUID，不生成伪证书或私钥。
- Moonlight HTTPS app-list、artwork、launch、stop 全部经过 exact leaf pin executor。缺失 pin 在网络前失败；叶证书不匹配被映射为结构化 `PinnedTransportError.certificateMismatch`；未采用 trust-all。
- Moonlight-qt importer 将 PEM `srvcert` 标准化为 DER 后持久化。当前 3 个本地主机 pin 均为 726-byte DER；`hosts.json`、`settings.json`、`app_catalog.json` 均为 `0600`，客户端私钥未从 Moonlight-qt 导入。
- macOS SwiftUI window 已通过 `AppKitLifecycleAttachment` 接到 AppKit monitor，覆盖 occlusion、key、screen、resize/live resize、backing scale、miniaturize 与 app activation；状态同步到 AppModel render policy、drawable pixel size 和 EDR headroom。
- 运行态验证读取到实际 drawable `2560x1600`、EDR headroom `5.0`，并加载 3 台主机；Debug 文件 identity store 当前无持久化 identity，未访问 Keychain。
- 最终正常测试结果为 58 total：57 passed、1 skipped（仅 opt-in Keychain）、0 failed。macOS Debug、macOS Release、固定 iPhone 17 Pro、固定 Apple TV、固定 Apple Vision Pro 隔离构建均通过，未启动目标模拟器。

### 2026-07-21 最初体验要求复核

- 复核采用三层证据：类型/策略存在、生产 App 已接线、真实 session 端到端生效。只有第三层满足时才可声明产品功能完成。
- macOS window occlusion/key/screen/resize/backing/EDR monitor 已接入 SwiftUI window，并能驱动 Metal pause/throttle 和 drawable size。
- macOS cursor policy 与 `InputMapper` 只有可测试算法；没有 `NSEvent` 生产采集、`NSCursor` hide/unhide、relative capture 或远程 input sender。
- 当前 EDR 只读取 display headroom 并设置 layer 开关；没有 10-bit/colorspace/PQ/MDCV/CLL/tone mapping，且 stream HDR 与 display EDR capability 尚未分离。
- `SpatialAudioController`、mobile continuity policy、PiP state coordinator 和 UIKit lifecycle monitor 没有生产调用方；iOS/iPadOS scene/resize/PiP/background/EDR 未形成运行闭环。
- `RuntimeCapabilityAvailability.current` 仍将 pairing 和 stream transport 设为 false；真实配对、RTSP/control、VideoToolbox/音频 decode 与输入发送是所有后续体验的阻塞依赖。
- 因上述证据，原阶段 5–9 从 `complete` 修正为 `partial`，并建立阶段 13–20 的端到端路线图。

### 2026-07-21 RTSP bootstrap

- Moonlight encrypted RTSP framing uses a 24-byte prefix: big-endian high-bit type/length, big-endian sequence, 16-byte GCM tag, then ciphertext. The 12-byte nonce stores the sequence little-endian in bytes 0...3 and separates client/host origins with `C/R` and `H/R` in bytes 10...11.
- Modern Sunshine RTSP requests require the normal `CSeq` plus GameStream client version `14` and the target `Host`; DESCRIBE additionally sends `Accept: application/sdp` and the epoch `If-Modified-Since` value.
- `MoonlightSessionControlProvider` now publishes `.launchAccepted` immediately after authenticated HTTPS launch, but publishes `.rtspReady` only after a valid session URL, RTSP connect, 200 OPTIONS, 200 DESCRIBE, exact CSeq matching, and bounded SDP parse all succeed.
- `/launch` and `.rtspReady` still do not publish `.negotiated`, `.channelsReady`, or UI Streaming. The production AppModel remains deliberately fail-closed until the complete provider graph is injected in 8.x.
- Encrypted RTSP uses the negotiated 16-byte remote input key through CryptoKit AES-GCM; invalid key size, unencrypted type bit, inconsistent length, wrong origin nonce, tag mutation, non-200 status, and CSeq mismatch all fail closed.
- RTSP bootstrap task ownership uses session/token identity, cancels replaced or abandoned attempts, clears the Network.framework channel and key material, and prevents an older attempt from clearing newer state.

### 2026-07-21 阶段 13 协议盘点

- OpenSpec `implement-moonlight-session-runtime` 的正确完成计数为 11/61：1.2–1.7 共 6 项、2.1–2.5 共 5 项；1.1 仍因缺少已授权 Sunshine release semantic version 证据而保持未完成。此前进度日志中的 12/61 是计数错误，不改变已完成任务本身。

- 只读 Bonjour 与 `serverinfo` 确认一台可用 Sunshine host，协议 `appversion=7.1.431.-1`、兼容 GFE `3.23.0.74`、HTTPS 47984、当前无活动游戏；Web UI 使用 Basic Auth，未尝试认证。
- `servercodecmodesupport=0x001F0301`：H.264、HEVC、HEVC Main10、AV1 Main8/Main10、H.264 4:4:4、HEVC 4:4:4 8/10-bit；不含 AV1 4:4:4。HEVC luma limit 为 `1869449984`。
- `appversion` 是 Sunshine 模拟的 GameStream 协议版本，不是发布语义版本；上游 `nvhttp.h` 也明确该字段是 protocol version。精确 Sunshine release version 需要已授权 Web config GET 或主机侧 `sunshine --version`，任务 1.1 暂不勾选。
- 当前 Xcode production target 无 SPM product、moonlight-common-c、FFmpeg、SDL、Qt 或 libopus 链接；`references/` 保持 Git/Xcode 外只读研究区。
- 阶段 13 恢复后确认 OpenSpec `implement-moonlight-session-runtime` 为 `spec-driven`、进度 `2/61`；任务 1.4 的身份 spike 必须生成非永久 RSA-2048 `SecKey`、构造可由 `SecCertificateCreateWithData` 解析的 X.509 v3 自签证书，并使用证书公钥验证证书签名和独立 payload 签名，全程不访问 Keychain 或 identity store。
- Security.framework identity spike 以 `-warnings-as-errors` 编译并连续运行三次通过：每次生成 RSA-2048 临时 key、724-byte X.509 DER，证书公钥与生成公钥一致，证书签名和 challenge 签名均验证成功；源码禁止项扫描确认无 `SecItem*`、永久 key 或 identity-store 调用。
- X.509 依赖决策倾向仓库自有的固定 profile DER writer：只编码 v3、正随机 serial、CN、20 年 validity、RSA SPKI、SHA256WithRSA，完成证书仍由 Security.framework 解析；无需引入通用 ASN.1 依赖，live Sunshine 接受性仍需后续授权 pairing gate 证明。
- Opus spike 的协议输入边界已确认：Moonlight 接收路径先对 12-byte RTP header、FEC/ordering 和可选 AES 做处理，然后把单个 raw Opus payload 交给 decoder；不能用 Ogg/CAF 文件解码代替 packet-level 验证。
- 当前 Sunshine stereo profile 为 48 kHz、2 channels、1 stream/1 coupled stream、96 kbps CBR、restricted-lowdelay；默认 5 ms 为 240 samples/frame。5.1/7.1 使用独立 multistream mapping 和不同 coupled-stream 配置，Apple 系统 decoder 的 stereo 结果不能代表 surround 支持。
- AudioConverter 首次 raw stereo Opus 解码已返回 PCM，但首包只输出 120/240 frames，反映 2.5 ms decoder priming；生产 jitter/sync 层不得假设每个 packet 同步产生固定长度 PCM，需按实际输出 frame count 建时钟。
- 多声道代表性要求：Sunshine 的 5.1/7.1 encoder 直接使用 Moonlight speaker-order identity mapping（分别 `[0...5]`、`[0...7]`）；常规 Ogg/FFmpeg 5.1 `OpusHead` 使用 Vorbis-order mapping `[0,4,1,2,3,5]`，不能直接充当 Sunshine multistream fixture。合成 fixture 必须显式使用 Sunshine 的 streams/coupledStreams/mapping。
- AudioToolbox runtime spike 在 macOS 解码 Sunshine 全部五种 5 ms profile 成功：stereo、5.1 normal/HQ、7.1 normal/HQ，raw packet 分别为 60/160/960/281/1280 bytes，均输出 120-frame 首包非静音 PCM。相同 Swift surface 对 iOS/tvOS/visionOS 26 simulator SDK 以 warnings-as-errors typecheck 通过，但这些平台仍只是编译证据。
- Opus production 决策为系统 AudioToolbox `AudioConverter`，不链接 libopus；wrapper 从 RTSP 配置合成 `OpusHead`，输出实际 PCM frame count。libopus 1.6.1 仅作为 `Tools/OpusSpike/generate_fixture.c` 的本地合成 fixture 生成依赖，不进入 Xcode target。
- Runtime provider contract 决策：拆分 pairing、session control、video receive、audio receive、remote input 五个 `Sendable` provider，使用 session/attempt ID 和 `AsyncThrowingStream` 传递有序事件；negotiated endpoint/media/input 配置为共享值类型。2.1 只建立接口与不变量，不提前打开 `AppModel` production capability gate。
- `RuntimeProviders.swift` 已作为所有 App target 的 production source：共享 endpoint、video/audio/input negotiated configuration、channel readiness 和有序 event streams；Audio contract 对 Sunshine 五种 stream/coupled identity mapping 均通过，不合法 mapping 与 zero-port endpoint fail closed。
- `NetworkByteChannel` actor 已封装真实 `NWConnection` TCP/UDP：connect/send/receive 均有正数 timeout，send/read 有硬上限，timeout/cancellation 取消底层 connection，空 complete read 进入 closed；错误只暴露类别/数字码，不包含 endpoint。真实 macOS TCP/UDP loopback 和确定性 mock tests 均通过。
- `SessionResourceTracker` 统一拥有 session tasks 与 network/decoder/renderer/audio/input/timer resources：teardown 先取消任务并等待 grace period，再按逆注册顺序 shutdown resources；幂等返回同一 report，non-cooperative task 进入 `unfinishedTasks` 而不会被误报 clean。
- `RuntimeDiagnosticsRecorder` 使用稳定 code/stage/severity 与 typed fields，敏感键/内容强制 `<redacted>`、host/address/URL 强制 `<private>`；stage token 用 monotonic nanoseconds 计算 duration，event ring buffer 有容量上限，旧 `DiagnosticsStore` 只接收已脱敏事件。
- Network foundation failure coverage 包含 2/4-byte big-endian bounded frame decoder 的 fragmented/coalesced、oversized declaration、truncated EOF；外部 Task cancellation、connect/receive timeout 都会取消底层 driver；channel 纳入 `SessionResourceTracker` 后 teardown report clean 且 state 为 cancelled。
- Production `SecurityClientIdentityGenerator` 已采用仓库自有 bounded DER writer：生成非永久 RSA-2048 `SecKey`，导出可重建的 PKCS#1 private key，编码 CN=`NVIDIA GameStream Client`、20 年 validity、SHA256WithRSA 的 X.509 v3 self-signed DER；生成层不访问 store、Keychain 或 host。
- `SecurityClientIdentityValidator` 对 persisted identity 执行证书解析/CN、bounded DER TBS+signature 提取、自签 SHA256WithRSA 验证、有效期 trust、RSA-2048 attributes、公私钥匹配和 challenge sign/verify。显式 anchor trust 不会自动证明 anchor 自签名，因此不能用 `SecTrustEvaluateWithError` 单独替代显式签名验证。
- `ClientIdentityManager` 仅在 store 为空时生成，save 后必须 reload、byte-equal 并重新验证；无效 persisted identity fail closed 且保持原记录，只有 `resetIdentity()` 会删除，Debug 验收通过 JSON `0600` fallback，未调用真实 Keychain。
- Pairing crypto 版本契约：server major `<7` 使用 SHA-1、`>=7` 使用 SHA-256；AES key 为 `digest(16-byte salt || 4-byte ASCII PIN)` 前 16 bytes；challenge cipher 为 AES-128-ECB/no-padding；client/server secret RSA signature 固定 SHA-256 PKCS#1 v1.5。
- `crypto-vectors.json` 由 Python `hashlib` 与系统 `openssl enc -aes-128-ecb -nopad` 独立生成，覆盖 gen6/gen7 key derivation、challenge encryption、challenge-response digest/padding/encryption；fixture 使用空格分隔 synthetic bytes，统一脱敏 validator 通过。
- `MoonlightPairingCrypto` 使用 CommonCrypto/Security.framework 实现版本化 digest、16-byte CSPRNG salt/nonce、bounded AES、certificate signature 提取、secret sign/verify 和 constant-time server-response compare；malformed length、非 ASCII PIN、错 key/block/signature/response 均 fail closed。

### 2026-07-21 阶段 13 Pairing Transport

- `MoonlightPairingProvider` 已按 `serverinfo`、HTTP `getservercert`、`clientchallenge`、`serverchallengeresp`、`clientpairingsecret`、HTTPS `pairchallenge` 顺序实现经过认证的配对 exchange；所有 HTTP/XML/hex/certificate/version 边界均有大小或结构检查，非 2xx HTTP 或非 200 XML status fail closed。
- 前五个配对请求仍使用未加密 HTTP，这是 Moonlight PIN challenge 协议本身的引导顺序；只有从经过签名和 challenge-response 验证的 `plaincert` 得到 exact leaf DER 后，最终 HTTPS `pairchallenge` 才使用该临时 pin。
- 最终 HTTPS 同时要求 exact server leaf pin 和 client TLS identity。`SecIdentityCreate(nil, certificate, privateKey)` 可直接从文件 fallback/in-memory 的 certificate DER 与 PKCS#1 private key 构造 mutual-TLS identity，无需再次写入 Keychain。
- 动态 Sunshine stub 会实际解密 client challenge、构造 server response、签名 server secret、验证 client pairing secret/response hash，并检查最终请求的临时 pin 与 client identity；pin mismatch 不产生 `.completed`。
- 配对 transport 的 progress snapshot 现在复用调用方 `attemptID`，与 provider task/cancel key 保持一致；focused 回归覆盖该不变量。
- 3.4 的完成边界仅到返回已认证的 `PairingResult`。host repository 的原子持久化与 reload 确认属于 3.5，跨 stage cancellation/rollback 属于 3.6，真实 Sunshine pairing/re-pair 属于需显式授权的 3.7。
- `PersistingPairingProvider` 将 authenticated transport completion 包在 repository commit 之后：先校验 host ID、paired state、exact certificate DER、声明 SHA-256 与实际 DER SHA-256，再 load previous hosts、save replacement、reload 并按 host ID 集合与目标 host exact equality 验证，最后才发布 `.completed`。
- transport/crypto 失败在 repository I/O 前结束；save 失败不发布 completion；save 后 reload error/mismatch 会恢复整个 previous host snapshot 并重新读取确认。若恢复本身失败，返回独立 `rollbackFailed`，不会把不确定状态报告为 paired。
- 3.5 的确定性验收覆盖 exact save/reload、transport failure 零写入、save failure 保留旧 pin、reload mismatch rollback、伪造 SHA-256 在 repository access 前拒绝。JSON production repository 继续使用既有 atomic write，真实 Keychain 不参与。
- Pairing cancellation 现在以 request `attemptID` 加内部 generation token 管理；同 ID replacement、显式 cancel、stream termination 和正常 finish 都只清理对应 generation，旧任务不能误删或取消后来创建的 attempt。
- `MoonlightPairingProvider` 在 `CancellationError` 和底层返回其他 error 但 task 已 cancelled 两种路径都发布 stage `.cancelled`/failure `.cancelled`，随后 finish throwing；不会发布 `.completed`。`URLSession.data(for:)` 的 task cancellation 会触发 ephemeral session 收敛和 defer invalidation。
- `PersistingPairingProvider` 同样拥有 wrapper task；取消发生在 authenticated save 后、reload 前/期间时，会恢复并 reload 验证 previous host snapshot，然后才返回 cancelled。若 rollback 失败则显式报告 `rollbackFailed`，不声称旧 pin 已安全恢复。
- 3.6 确定性覆盖六个 request stage、重复 cancel、active-attempt cleanup、真实本地 hanging HTTP URLSession cancellation，以及 save 后 blocked reload cancellation rollback；没有 live host I/O。

### 2026-07-21 阶段 13 RTSP/Control

- 4.1 使用独立 Swift value model 实现 RTSP/1.0 request/response/header/body；body 始终保持 `Data`，不会因 NUL、非 UTF-8 或内嵌 `CRLFCRLF` 被字符串逻辑截断。
- `RTSPMessageCodec.decodePrefix` 以 `CRLFCRLF` 和唯一合法 `Content-Length` 计算单条消息边界，支持 fragmented/coalesced input；1 MiB message、64 KiB header、960 KiB body、8 KiB start line、128 headers 和单 header name/value 均有硬限制。prefix 限制只作用于第一条 frame，不误拒绝后续 coalesced bytes；`decodeExact` 单独拒绝 trailing data。
- parser/serializer 仅接受 RTSP/1.0、ASCII token/header/start-line 安全集，拒绝 LF-only、header injection、重复/非十进制 Content-Length、声明长度不符、非法 status/target/version；header 顺序、大小写与非 Content-Length 重复项保持不变，并提供 case-insensitive lookup。
- RTSP fixtures 是 repository-generated JSON escaped wire strings，只使用 `example.invalid` 与 synthetic header，无真实 host/session/certificate 数据；fixture decode 后 serialize byte-exact，统一 redaction validator 通过。
- 4.2 只读协议盘点：Sunshine `DESCRIBE` body 提供 SDP attributes 与一个或两个 `a=fmtp:97 surround-params=` 项；stereo 固定为 48 kHz、1 stream、1 coupled stream，surround 参数携带 channel/stream/coupled/mapping。`SETUP` response 的 channel port 从 `Transport` header `server_port=` 取得，session ID 从 `Session` header 取得。
- `SunshineSessionDescriptionParser` 对 DESCRIBE 200 response 解析 Sunshine feature/encryption flags、reference-frame invalidation、H.264/HEVC/AV1 availability 与 compact Opus profiles；description、line count/length 有独立限制，已知 numeric attribute 重复或非法时 fail closed。
- compact Opus profile 必须为 `channelCount + streamCount + coupledStreamCount + mapping digits`，满足 `streams + coupled == channels`、mapping 长度/范围/唯一性；stereo 使用协议固定 48 kHz `1/1/[0,1]`，parsed profile 可直接构造并验证共享 `NegotiatedAudioStreamConfiguration`。
- `RTSPSetupResponseParser` 要求 200、唯一 `Session`/`Transport`，去除 session timeout suffix，并从 `server_port` 或 port range 的首端解析 1...65535；optional `X-SS-Ping-Payload` 与 `X-SS-Connect-Data` 有 ASCII/长度/UInt32 校验。当前 Sunshine target 的关键字段缺失时不静默退回 legacy well-known port。
- 4.3 审计输入：现有 `StreamSessionCoordinator` 在 `/launch` 后进入 `readyForTransport` 是正确的，但公开手动 `markTransportStarted()` 可在没有 RTSP negotiation/channel readiness 时进入 `streaming`；生产路径必须改由 `SessionControlProvider` 的真实 readiness event 驱动。
- 4.4 transport 决策：当前 Sunshine/GameStream control stream 是 ENet reliable UDP，而 Network.framework 不提供 ENet handshake、ACK、重传、fragmentation、channel、ping 或 peer timeout。production target 固定 vendor MIT ENet revision `aca87840b57f045a1f7f9299e4b1b9b8e2a5e2f1`，保留原始 license/source；Swift 仅通过仓库自有 opaque C bridge 调用 connect/send/service/disconnect。
- encrypted control outer header 为 LE `type=0x0001`、LE length、LE sequence、16-byte AES-GCM tag 和 ciphertext；plaintext 为 LE packet type、LE payload length 与 payload。12-byte nonce 的低 4 bytes 是 LE sequence，bytes 10/11 分别为 client `C/C` 或 host `H/C`，key 固定使用 16-byte negotiated remote-input AES key。
- current Sunshine encrypted packet table中，Start A 与 IDR request 共用 `0x0302`/`00 00`，Start B 为 `0x0307`/`00`，extended termination 为 `0x0109` 加 4-byte BE HRESULT。已映射 graceful close、protected content、frame conversion 与 unknown HRESULT 为不泄密的可操作消息。
- `MoonlightSessionControlProvider` 现在按 `OPTIONS`、`DESCRIBE`、`SETUP audio/0/0`、`SETUP video/0/0`、`SETUP control/13/0` 顺序执行，后两次 SETUP 必须复用 audio response 的 bounded Session token；control response 缺失 `X-SS-Connect-Data` 或任一 Session 冲突均 fail closed。
- control actor 连接 48-channel ENet、发送 reliable Start A/B、以 100 ms service loop驱动 ENet ping/retransmission、在 urgent channel 发送 IDR，并在 remote termination/disconnect/local stop 清除 key/sequence 与释放 C connection。session event 只发布 `.channelsReady(.control)`，不会发布 `.all`、`.negotiated` 或 `Streaming`。
- 4.4 deterministic evidence 包含 Node/OpenSSL 独立 AES-GCM exact-wire fixture、origin/key/type/length/tag mutation、start/IDR sequence 与 channel、keepalive service、termination mapping、disconnect cleanup、SETUP/header/token/connect-data 和 partial-readiness tests。ANNOUNCE/PLAY、媒体 readiness、reconnect/cancellation convergence 与 live Sunshine 互操作仍属于后续任务，不能由 4.4 的 build/tests 推导完成。

### 2026-07-21 阶段 13 Bounded Reconnect 设计

- control transport 不能在同一 16-byte `rikey` 下把 AES-GCM sequence 重置后直接重连；发送结果不确定或任一方向重置 sequence 都可能造成 nonce reuse。恢复必须生成新的 `rikey`/`rikeyid`，通过已配对 HTTPS `/resume` 创建新的 launch-session material，再重建 RTSP 与 control channel。
- Sunshine `/resume` 不启动新的 app process，要求 `rikey` 与 `rikeyid`，成功返回 `resume=1` 和 `sessionUrl0`；因此它满足“不重复 `/launch`、不创建 duplicate host app session”的恢复边界。初始 `/launch` 调用次数必须始终为 1，后续只允许 bounded `/resume`。
- required-channel health 需要成为显式状态，而不是只累计一次 `.channelsReady`：`healthy` 为空是 unavailable，真子集是 degraded，满足 `required` 才是 ready/canStream。任何 required channel 丢失都必须立刻让 coordinator 退出 streaming truth。
- control disconnect、ENet/Network/URL transport 暂态错误可进入 bounded reconnect；TLS pin/authentication、AES-GCM frame authentication、协议/parse/invalid-state 错误必须立即 fail closed。公开 reconnect reason 使用固定脱敏 code，不传播 host、URL 或底层错误文本。
- control sequence 必须在等待可能产生不确定发送结果的 ENet `send()` 之前消费；这样即使 driver 返回 error，当前 key 下后续发送也不会复用同一个 nonce。
- 4.5 production runtime 已实现三次 bounded `/resume` recovery（100/250/500 ms），每次使用 Security `SecRandomCopyBytes` 生成未使用过的 16-byte key/UInt32 ID；初始 `/launch` 固定一次，resume response 必须明确 `resume=1` 并提供可用 session URL。
- `SessionChannelHealthSnapshot` 的 status/canStream 由 required/healthy set 实时派生：empty 为 unavailable、真子集为 degraded、满足 required 才 ready；streaming 中任一 required channel 丢失都会切到 reconnecting，control error 在重试分类前先发布空健康集。
- transient control/ENet/Network/URL errors 才可重试；pinned TLS、authenticated control frame、RTSP parse/protocol 与 invalid-state error 立即失败。公开 event 只使用固定 `control_unavailable` reason，不含 host、URL 或 raw error。
- generation token 在每次 event publish 前校验；被新 session 替换的旧 RTSP attempt 即使处于 suspend/transact 边界，也不能发布迟到 `.rtspReady` 或 readiness。预算耗尽后本地 ENet/RTSP 已清理，并 best-effort 调用 `/cancel`。
- 4.5 仍只恢复 control plane 并发布 `.control`，不会虚构 `.all`、`.negotiated` 或 Streaming；真实媒体/input channel 的健康输入和 live Sunshine reconnect 证据仍属于后续任务。

### 2026-07-21 阶段 13 Cancellation Convergence 设计

- 现有 provider 的停止路径是分裂的：显式 `stop`、consumer cancellation 和 replacement 只释放本地 ENet/RTSP，reconnect exhaustion 单独调用 `/cancel`，remote termination 又独立清理；这会造成远端 session 泄漏、重复 cleanup 和阻塞 I/O 下无法收敛。
- 4.6 采用每个 generation 一个 teardown coordinator。local stop、consumer cancellation、replacement、terminal failure 和 reconnect exhaustion 都先使 generation 失效并取消 task，再立即释放 control/RTSP，最后 best-effort pinned `/cancel`；remote termination 复用本地 teardown 但不重复 `/cancel`。
- Sunshine `/cancel` 的确定成功 contract 是 XML `status_code=200` 且 `cancel=1`。远端取消失败不能阻止本地资源释放；相同 generation 的并发 teardown caller 必须等待同一 operation，旧 generation 不能清除后来启动的 session。
- teardown operation 使用 detached task，避免由 consumer cancellation 继承 cancelled state 后导致 `/cancel` 立即失败。测试 stub 会主动拒绝在 cancelled task 中执行 stop，锁定这一生产不变量。
- 4.6 的 first-terminal-trigger-wins 语义已固定：local stop 先发生时发送一次 `/cancel` 且 remote event 不能迟到发布；host termination 先发生时本地资源只释放一次且 `/cancel` 为 0。后续竞态 caller 只等待同一 report。
- 完整 deterministic evidence 最终为 160 项 macOS tests（159 pass、1 explicit Keychain skip）、五平台 warnings-as-errors build、四 SDK C syntax 及 clean-room/fixture/OpenSpec/generator/ENet gates。此证据仅证明 control-plane cancellation convergence，不证明 5.x media resource teardown。
- 4.6 提交前复核发现：远端 termination event 发布后、teardown actor 建立 operation 前曾存在重入窗口，后到 local stop 可能先建立带 `/cancel` 的 operation。provider 现在先同步 claim `TerminalSession` 并冻结 trigger/cancelRemoteSession，再执行异步 teardown；first-terminal 决策不再跨 actor 悬空。

### 2026-07-21 阶段 13 Deterministic Session State Machine

- 4.5/4.6 已覆盖 provider event sequence、reconnect 与 teardown，但 `StreamSessionCoordinator` 目前只有 launch/health/stop 的分散 mutation API，没有统一消费 `SessionControlEvent`，也没有保存 negotiated configuration、reconnect attempt 或 remote termination reason。
- 4.7 将新增 generation-scoped event reducer：launch accepted、RTSP ready、negotiated、channel health、reconnect 与 remote termination 都必须经过合法 transition；stale generation 只被拒绝，不能把 replacement 标记失败。
- 新 reducer 的 Streaming 门严格为 validated negotiated configuration + health 满足全部 configured required channels；partial/duplicate events 保持非 Streaming，required-channel loss 立即进入 reconnecting，恢复时必须重新 RTSP/negotiated 后才能回到 Streaming。
- AppModel 仍在 8.3 前保持未连接 production `SessionControlProvider` 的 fail-closed 状态；4.7 只验证其现有 UI 层不会因 launch response 报 Streaming，不提前把 provider 注入或完整应用接线标记完成。
- 4.7 完成后，`StreamSessionSnapshot` 会保留 validated negotiated configuration、current channel health、reconnect attempt、remote termination reason 与 structured failure；每次 `prepare` 使用明确 generation ID，旧 ID 的 event/failure 被拒绝且不改变 replacement snapshot。
- reducer 的 duplicate contract 是 snapshot byte-for-value 不变：重复 launch/RTSP/negotiated/channel health/reconnect/termination 不刷新 `updatedAt`；remote termination 之后的迟到 failure 也不能覆盖 first terminal reason。本地 stop 同样幂等，只调用一次 remote cancel client。
- 4.7 确定性矩阵 7/7 通过，相关 focused suites 31/31 通过；完整 macOS warnings-as-errors tests 为 167 total / 166 passed / 1 explicit Keychain skip / 0 failed，五平台 warnings-as-errors Debug build、fixture、OpenSpec、generator、clean-room/diff 与 simulator Shutdown gates 全部通过。

### 2026-07-21 阶段 13 Video Packet Assembly 设计

- 当前 Sunshine video datagram 的 clean-room framing 为固定 12-byte RTP header、4-byte extension/reserved 和 16-byte little-endian NV video header；RTP sequence/timestamp/SSRC 为 big-endian。`streamPacketIndex` 右移 8 位后是 24-bit packet sequence，frame index 为 32-bit，三种序号都必须使用 half-range modular comparison 处理 wrap。
- NV flags 仅允许 picture-data `0x01`、EOF `0x02`、SOF `0x04`；Sunshine 对每个 FEC block 的首/末 data shard 设置 SOF/EOF，因此真正 frame start 是 block 0 的 SOF，真正 frame end 是 last block 的 EOF。`multiFecBlocks` 的高 2 bits 是 last block、次高 2 bits 是 current block，最多 4 blocks。
- `fecInfo` bits 12...21 是 shard index、bits 22...31 是 data-shard count、bits 4...11 是 FEC percentage。5.1 只按 data shard 做有界重排和完整性判定，不引入或复制 GPL Reed-Solomon 实现；parity 只用于确认 block envelope，缺 data shard 时不输出损坏 access unit，而在后续 frame、timeout 或容量界限上产生明确 loss/IDR evidence。
- 当前 Sunshine short frame header 固定 8 bytes：type `0x01`、LE16 host processing latency、frame type、LE16 final payload length 和 2 reserved bytes。首个 access-unit payload 必须去除该 header；H.264/HEVC 保留 Annex-B 允许的 FEC trailing zero bytes，AV1 使用 `lastPayloadLen` 对最终 data shard 精确截断。
- 5.1 的 production bounds 将独立限制 datagram size、每 block shard count、pending packet count、access-unit bytes 和 assembly age；duplicate exact packet 幂等忽略，conflicting duplicate、跨 block metadata 漂移、missing SOF/EOF、sequence mismatch、oversize 和 malformed header 均 fail closed。5.2 的 codec parameter-set/VideoToolbox format、5.4 decoder ownership、5.5 Metal delivery和 5.8 live video 不由本任务证明。
- Sunshine 为满足 negotiated minimum parity shard count 时可把单帧 `fecPercentage` 提升到 100 以上（字段本身是 UInt8），例如 1 data + 2 parity 使用 200；parser 因此接受 0...255，并继续用 data/parity/total shard 与内存上限约束。5.1 parser 的输入边界是已经完成可选 AES-GCM 认证解密的 plaintext RTP/NV datagram；协商与 receiver 接线不能把未认证 ciphertext 直接交给 assembler。
- 5.1 最终独立验收：synthetic fixture 与 focused assembly tests 9/9；完整 macOS warnings-as-errors tests `176 total / 175 passed / 1 explicit Keychain skip / 0 failed`；固定 macOS/iPhone/iPad/tvOS/visionOS warnings-as-errors Debug build 全部通过，四个 simulator 构建前后均为 `Shutdown`。
- fixture self-test/全树、OpenSpec strict、generator byte-for-byte、LuneX whitespace、production/reference boundary、固定 MIT ENet revision/license/source 逐文件比对和四 SDK strict C syntax gate 全部通过。5.1 不证明 video receiver/AES-GCM 接线、FEC recovery、VideoToolbox format/decode、Metal delivery或 live Sunshine video。

### 2026-07-21 阶段 13 Video Format 设计

- Xcode 26.4 CoreMedia 头文件规定：`CMVideoFormatDescriptionCreateFromH264ParameterSets` 至少接收 SPS/PPS，HEVC 版本至少接收 VPS/SPS/PPS；输入是去除 Annex-B start code、保留 emulation-prevention bytes 的 raw NAL，返回 format description 可直接供后续 VideoToolbox decompression session 使用。
- 5.2 parser 同时接受 3-byte/4-byte Annex-B start code，并去除 NAL 尾部 zero padding；access-unit bytes、单 NAL bytes、NAL count、parameter-set bytes 均有硬上限。H.264 forbidden-zero bit、HEVC two-byte header 和 nonzero temporal-id-plus-one 都必须合法。
- 当前 Sunshine 单个 IDR 发送一组 VPS/SPS/PPS；5.2 对同一 access unit 内的 exact duplicate 幂等，对同类型不同 bytes fail closed，避免在未解析 parameter-set ID 的情况下把冲突配置交给 CoreMedia。跨 access-unit format-change ownership 留给 5.4/5.7 decoder state。
- 5.2 最终独立验收：focused video-format tests `5/5`；合成 H.264/HEVC description 均由 CoreMedia 解析为 64x64，parameter-set getter byte-exact round-trip 且 NAL length header 为 4。完整 macOS warnings-as-errors tests `181 total / 180 passed / 1 explicit Keychain skip / 0 failed`。
- macOS、固定 iPhone/iPad/tvOS/visionOS warnings-as-errors Debug build、fixture self-test/全树、OpenSpec strict、generator byte-for-byte、diff/reference/dependency boundary、ENet revision/source/license 和四 SDK strict C syntax gate 全部通过；四个 simulator 前后始终为 `Shutdown`。5.2 不证明 VTDecompressionSession、AV1 hardware support、decoded frame 或 live host video。

### 2026-07-21 阶段 13 AV1 Capability 与 Fallback 设计

- Xcode 26.4 的 macOS/iOS/tvOS/visionOS SDK 均提供 `VTIsHardwareDecodeSupported`；该 API 只能证明系统存在对应 codec family 的硬件解码路径，不保证资源永远可分配，也不能在缺少真实 format description 时单独证明具体 AV1/HEVC profile 可创建 session。因此 5.3 用它做 launch 后、SETUP 前的设备门禁，5.4 仍需以 `VTDecompressionSessionCreate` 结果作为实际 decoder 证据。
- `VideoCodecSelectionPolicy` 将 preference、host `DESCRIBE` codec set、requested bit depth/HDR 与可注入 device capability 合并。automatic/AV1 优先级固定为 AV1 -> HEVC -> H.264，HEVC 为 HEVC -> H.264，显式 H.264 不升级；host set 的输入顺序或 duplicate 不影响结果。
- HDR 或 10-bit request 会从候选集中排除 H.264；AV1/HEVC 都没有 host+device 硬件交集时返回 structured `noCompatibleHardwareDecoder`，不能静默关闭 HDR 或降级成 SDR/H.264。SDR 8-bit 才允许最终 fallback H.264，并保留 unavailable-on-host 或 unsupported-by-device 原因。
- `MoonlightSessionControlProvider` 不再丢弃 `DESCRIBE` codec 结果：每个 generation 在任何 SETUP 前执行 selection，并保存 bounded latest selection 供后续 video runtime 使用；reconnect 会清除旧选择并重新协商，stale generation 不能写入新 session。
- bootstrap CRLF 回归暴露既有 SDP parser 缺陷：Swift 把 CRLF 视为一个 `Character`，旧的 CR/LF equality splitter 无法拆行，导致真实 CRLF body 只保留默认 H.264。parser 已改用 `Character.isNewline`，CRLF 的 HEVC/AV1 capability 识别和 fail-closed gate 均有端到端 stub coverage。
- 5.3 focused selection/RTSP/SDP tests `24/24`，完整 macOS warnings-as-errors tests `191 total / 190 passed / 1 explicit Keychain skip / 0 failed`；五平台 warnings-as-errors Debug build、fixture/OpenSpec/generator/reference/ENet/四 SDK C syntax gates 全部通过，固定 simulators 前后均为 `Shutdown`。
- 本任务不证明 AV1 sequence-header/format construction、VideoToolbox session/callback ownership、decoded frame、Metal delivery 或 live Sunshine video；这些边界继续分别属于 5.4-5.8。

### 2026-07-21 阶段 13 VideoToolbox Session Ownership 设计

- `VTDecompressionSessionDecodeFrame` 的 SDK 契约明确：返回非零错误时不会产生 callback；返回成功才保证 callback。因此同步 decode error 必须立即形成 structured decoder event，不能等待永远不会到达的回调。
- 输出 callback 可能异步且不保证 display order；5.4 的每个 decompression session 必须绑定独立 generation bridge，callback 在进入 actor 前携带 generation/frame token。replacement 先使旧 generation 失效，再 finish delayed frames、wait asynchronous frames、invalidate、detach bridge，迟到旧 callback 只能被丢弃。
- `VTIsHardwareDecodeSupported` 仍不是实际资源证据。production create 必须传 `kVTVideoDecoderSpecification_RequireHardwareAcceleratedVideoDecoder = true`，并把 `VTDecompressionSessionCreate` 的 OSStatus 作为实际 hardware session 成败证据。
- H.264/HEVC format description 在 5.2 固定使用 4-byte NAL length header；因此送入 `CMSampleBuffer` 前必须把 bounded Annex-B access unit byte-exact 转为每 NAL 的 4-byte big-endian length framing。`CMBlockBuffer` 由 CoreMedia allocator 拥有并复制输入 bytes，异步 decoder 不引用临时 `Data` pointer。
- destination pixel buffer attributes 明确要求 `kCVPixelBufferIOSurfacePropertiesKey` 空字典、`kCVPixelBufferMetalCompatibilityKey = true`；8-bit 使用 `kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange`，10-bit 使用 `kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange`。5.4 只建立后续零拷贝条件，不声称 5.5 texture cache/frame queue 已完成。
- callback 返回的 image buffer 在未设置 modifiable flag 时仍可能被 decoder 引用；LuneX 将其作为只读 retained `CVPixelBuffer` 跨 actor 传递，不修改其内容。HDR mastering/content-light metadata preservation、reset/IDR policy 和 live sustained decode 分别保留给 5.6、5.7、5.8。
- 5.4 最终实现为 generation-owned `VideoDecoder` actor、weak/locked callback bridge、required-hardware `VideoToolboxDecompressionSession` 和可注入 session factory。同步 decode error 立即发布，callback error/drop/missing-buffer 各自结构化，stop/replacement/deinit 都确定性收敛且旧 generation callback 不能发布。
- 合成 fixture 修正后先由 FFmpeg 独立解码，再由 production VideoToolbox gate 验证：H.264 输出 64x64 8-bit bi-planar video-range pixel buffer，HEVC 输出 64x64 10-bit bi-planar video-range pixel buffer。focused decoder+format tests `15/15`，完整 macOS tests `201 total / 200 passed / 1 explicit Keychain skip / 0 failed`。
- macOS、固定 iPhone/iPad/tvOS/visionOS warnings-as-errors Debug build、fixture self-test/全树、OpenSpec strict、generator byte-for-byte、diff/reference boundary、ENet revision/license/source/header 与四 SDK C strict syntax 均通过；四个 fixed simulator 前后保持 `Shutdown`。本任务仍不证明 AV1 format/decode、Metal texture delivery、HDR metadata 或 live Sunshine video。

### 2026-07-21 阶段 13 Metal Frame Delivery 设计

- CoreVideo SDK 明确规定 `CVMetalTextureCacheCreateTextureFromImage` 建立 source image 与 Metal texture 的 live binding，客户端必须保留 `CVMetalTexture` wrapper 直到 GPU 使用结束；这条路径不做 CPU color conversion。5.5 的 mapped frame 因此同时保留源 `CVPixelBuffer`、两个 `CVMetalTexture` wrapper 与 `MTLTexture` view。
- 8-bit bi-planar video-range 映射为 plane 0 `r8Unorm` full size、plane 1 `rg8Unorm` half size；10-bit bi-planar video-range 映射为 `r16Unorm`/`rg16Unorm`。其他 pixel format 或非双平面 buffer fail closed，不在本任务偷偷转换为 BGRA。
- renderer-facing queue 使用 generation 隔离和固定小容量：超容量淘汰最旧 arrival；renderer dequeue 时取最新 frame 并清除更旧积压，保持低延迟。replacement/stop 清空 queued wrappers 并 flush texture cache；旧 generation frame 在 map 前拒绝。
- 当前 `MetalStreamSurface` 只有 `MTKView` lifecycle/pause shell，AppModel production media provider仍按 8.x 保持 fail closed。5.5 提供可注入的 decoded-frame-to-Metal queue boundary和真实 texture mapping测试，不提前声称 shader/color conversion、实际画面呈现或 session UI wiring。
- 5.5 最终实现由 locked `CVMetalVideoFrameMapper` 与 actor-isolated `BoundedMetalFrameQueue` 组成。mapped frame 同时保留 source `CVPixelBuffer`、luma/chroma `CVMetalTexture` wrapper 和对应 `MTLTexture`；8-bit `420v` 映射为 `r8Unorm/rg8Unorm`，10-bit `x420` 映射为 `r16Unorm/rg16Unorm`，其他格式 fail closed。
- queue 默认容量 3、硬上限 8；enqueue 超限淘汰最旧 frame，renderer dequeue 只交付最新 frame 并释放积压。generation replacement/stop 清空 wrapper 并 flush cache，stale generation 在 texture mapping 前拒绝；完整 macOS gate 为 `206 total / 205 passed / 1 explicit Keychain skip / 0 failed`，五平台 build、四 SDK C、fixture/OpenSpec/generator/reference/ENet/simulator gates 全部通过。
- 该证据证明真实 H.264/HEVC VideoToolbox output 可建立 live zero-CPU-conversion Metal plane，但不证明 YUV shader、colorspace/HDR mapping、drawable presentation、session UI wiring 或 live Sunshine sustained video；这些边界继续属于 5.6-5.8 与 8.x。

### 2026-07-21 阶段 13 Video Color 与 HDR Metadata 设计

- Sunshine generation-7 encrypted control HDR message type 为 `0x010E`。payload 首 byte 是 enable，Sunshine extension 后续按 little-endian 依次携带 RGB display primaries、white point、max/min mastering luminance、MaxCLL、MaxFALL 与 max full-frame luminance；完整 payload 为 27 bytes，legacy enable-only payload 为 1 byte。
- CoreMedia/CoreVideo 的 MDCV extension/attachment 是固定 24-byte big-endian HEVC SEI layout，primaries 使用 GBR order，max luminance 使用 1/10000 nit；CLL 是固定 4-byte big-endian MaxCLL/MaxFALL。LuneX 将用 repository-owned typed encoder生成这两个 blob，不复制 GPL 实现。
- 5.6 将定义可验证的 SDR Rec.709 与 HDR10 BT.2020/PQ/video-range metadata contract；negotiated video configuration、decoder generation、decoded frame 与 Metal frame都保留同一 immutable value。control HDR update只产生 typed event，实际 format/session reset 与 IDR 协调留给 5.7。
- 本任务不设置 `CAMetalLayer` EDR metadata、不实现 YUV-to-RGB shader或 tone mapping，也不把 control metadata arrival视为 HDR presentation；阶段 15 才消费这些保留值完成显示管线。
- 首轮实现复核发现 `MoonlightControlChannel` 已解析 typed HDR event，但 provider loop 仍将其作为无动作消息丢弃；已补 `SessionControlEvent.videoColorMetadata`、session-scoped provider storage 与 snapshot/config reducer，动态 update 现在跨 actor 边界保留，且 validation failure 不会留下部分 mutation。
- base negotiated metadata由 codec selection 生成：SDR 为 Rec.709/video-range（8 或 10 bit），HDR 为 HDR10 BT.2020/PQ/10-bit/video-range。H.264 与 10-bit/HDR combination 在 runtime contract 中 fail closed，provider 也拒绝 H.264 generation 的 HDR enable event。
- 5.6 最终实现保留完整 Sunshine 27-byte HDR payload中的 RGB primaries、white point、mastering max/min luminance、MaxCLL、MaxFALL 与 maximum full-frame luminance；同时支持 legacy 1-byte enable/disable。MDCV 转为 24-byte big-endian GBR order，CLL 转为 4-byte big-endian，均有 byte-exact fixture 回归。
- production propagation 现在覆盖 codec selection、session-scoped provider state、`SessionControlEvent`、`StreamSessionSnapshot`、negotiated configuration、decoder generation、decoded frame 与 Metal mapped frame；动态 update 先验证临时 configuration 再原子提交，reconnect 清除旧 metadata/configuration。
- 5.6 focused gate `50/50`；完整 macOS warnings-as-errors tests `211 total / 210 passed / 1 explicit Keychain skip / 0 failed`。macOS、固定 iPhone/iPad/tvOS/visionOS warnings-as-errors Debug build、fixture/OpenSpec/generator/reference/ENet/四 SDK C syntax gates 均通过，固定 simulators 构建前后保持 `Shutdown`。
- 该证据只证明 colorspace、bit depth 与 HDR static metadata 的正确保留，不证明 format-change/reset/IDR、EDR layer metadata、YUV-to-RGB/PQ shader、tone mapping、AppModel presentation 或 live Sunshine sustained video；这些边界继续由 5.7、5.8、8.x 与阶段 15承担。

### 2026-07-21 阶段 13 Video Reset 与 IDR 协调设计

- 5.1 assembler 已把 superseded、timeout、capacity、metadata conflict 和 malformed frame统一发布为 `requiresIDR` loss；5.4 decoder已能 generation-isolated drain/invalidate并发布 callback drop/failure；4.4 control provider已能发送 urgent IDR。当前缺口是没有 session-owned actor把三者组合，因此 packet loss之后仍可能把预测帧交给旧 decoder，也没有 production format-change ownership。
- 5.7 将只在 `instantaneousDecoderRefresh` access unit上解析 H.264/HEVC parameter sets。首次 IDR或 parameter sets/bit-depth/HDR metadata变化时 drain旧 decoder并创建新 generation；相同 parameter sets与metadata的后续 IDR继续使用现有 session，避免无意义 reset。
- assembler loss、active-generation decoder drop/failure或 metadata change会同步进入 awaiting-IDR状态并停止当前 decoder；等待期间所有非 IDR access unit均丢弃。重复 loss/drop只合并为一个 outstanding IDR request，收到并成功提交合法 IDR后才恢复预测帧。
- 显式 stop必须在任何 suspension前锁定 stopped lifecycle、停止 decoder、detach event bridge并使迟到 IDR request completion/decoder callback不能重建 session。5.7 只证明确定性 fixture/runtime coordination，不证明网络 video receive provider、真实 Sunshine sustained decode或实际 drawable presentation。
- 5.7 最终实现新增 session-owned `VideoDecodePipeline` 和精确 session-ID 的 control IDR adapter。首个合法 IDR 创建 generation；相同 parameter sets/metadata 的 IDR 复用；parameter set、bit depth 或 HDR metadata 变化先 drain/stop，下一 IDR 才建立新 generation。loss/drop 请求失败后可重试，重复事件只保留一个 outstanding IDR。
- 96x64 H.264 format-change fixture 由本机 libx264 合成、移除 encoder SEI，并由 FFmpeg 与 CoreMedia 独立确认；它不含 host、用户、Keychain 或网络数据。staged audit另发现 decoder session创建挂起期间 `stop()` 可被迟到 IDR continuation覆盖，现已在 replace/decode异步边界后校验 lifecycle token，并加入确定性停止竞态回归。
- 最终 pipeline-specific gate `10/10`，完整 macOS gate `221 total / 220 passed / 1 explicit Keychain skip / 0 failed`。修改后的五平台 warnings-as-errors build、fixture/OpenSpec/generator/reference/dependency/ENet/四 SDK C syntax门禁均通过，固定simulators前后保持 `Shutdown`。

### 2026-07-21 阶段 13 Audio Ordering 与 Jitter Policy 设计

- `AudioReceiveProvider` 的共享contract已经把网络边界归一为UInt16 sequence、UInt32 RTP timestamp、monotonic receive time和raw Opus payload；6.1在这个post-RTP边界工作，不解析socket datagram，也不把排序组件与6.2 decoder绑定。
- 低延迟缓冲不能只按packet count猜测时间：Sunshine默认5 ms/240 samples，但AudioConverter首个packet可能因priming只输出120 frames。6.1只使用negotiated packet cadence计算receive-side target/deadline；真正audio clock必须在6.4使用实际decoded PCM frame count。
- policy需要同时限制packet数量、payload bytes、最大单包、可接受forward gap与reorder distance。deadline、reorder-window、capacity和end-of-stream造成的missing range必须成为typed event，以便6.5做concealment/diagnostics；duplicate、conflicting duplicate和late packet也不能静默消失。
- 6.1最终实现 `AudioPacketJitterBuffer`：默认由48 kHz/240 samples cadence派生10 ms target delay和40 ms maximum jitter，reorder window 8、forward gap 1024、32 packets并同时限制payload bytes；所有cadence arithmetic使用overflow-reporting运算。
- discard到达仍推进monotonic clock并触发deadline drain；invalid payload、backward clock和过大forward gap在mutation前fail closed。UInt16 wrap、pre-playout向后扩展、out-of-order、deadline/window/capacity/end-of-stream loss、duplicate/conflict/late及极端配置均有回归。
- focused jitter gate `11/11`，expanded audio/RTSP/runtime contract gate `23/23`，完整macOS gate `232 total / 231 passed / 1 explicit Keychain skip / 0 failed`；五平台warnings-as-errors build和全部静态门禁通过，固定simulators前后保持 `Shutdown`。该证据不证明Opus decode、PCM或audible output。

### 2026-07-21 阶段 13 AudioToolbox Opus Decoder 设计

- production decoder复用已独立验证的AudioToolbox surface，但不能直接把命令行spike当运行时：converter必须由actor单独拥有、explicit reset/close、每次input packet使用稳定owned storage，输出byte/frame count必须互相一致且受negotiated `samplesPerFrame` 上限约束。
- `OpusHead` mapping family 0只适用于1/2 channel、单stream且identity mapping的canonical mono/stereo；其他合法multistream configuration必须使用family 1并写入stream count、coupled count和完整negotiated mapping，不能把5.1/7.1默认成Vorbis channel order。
- canonical runtime PCM选择48 kHz、interleaved、signed packed Int16。实际decoded frame count可以小于encoded 240 frames（首包priming已实测120），因此output value必须携带frame count/sequence/timestamp，6.4只按实际PCM frames推进clock。
- 最终production decoder使用actor隔离的`AudioConverter`和窄`@unchecked Sendable` RAII owner；reset/close确定性，close幂等，closed/invalid payload/configuration均fail closed，OSStatus只以数值进入结构化错误。
- synthetic stereo与Sunshine 5.1/7.1 normal/HQ四种multistream packet均通过production AudioToolbox实际解码并产生非静音PCM；focused `8/8`、expanded audio/RTSP/runtime `31/31`、完整macOS `240 total / 239 passed / 1 explicit Keychain skip / 0 failed`。
- macOS、固定iPhone/iPad/tvOS/visionOS warnings-as-errors Debug build全部通过，构建后四个simulator保持`Shutdown`。fixture/OpenSpec/generator/reference/dependency/ENet/四SDK C syntax门禁全部通过。该证据证明Opus-to-PCM边界，不证明AVAudioEngine scheduling、A/V sync、route handling或audible live output。

### 2026-07-21 阶段 13 AVAudioEngine Graph 设计

- `AVAudioPlayerNode.scheduleBuffer`的`.dataConsumed` completion只表示player已消费buffer data，适合释放queue ownership，不等于声音已经由硬件播放；audible/route证据必须保留给6.7。
- 6.3使用48 kHz interleaved signed Int16 `AVAudioPCMBuffer`，直接连接player到main mixer；每包最大5760 frames、actor默认最多8个scheduled buffers。容量满时显式fail closed，不在本任务静默drop或冒充packet-loss concealment。
- 每个schedule绑定pipeline generation与token；stop/reconfigure先推进generation并清空计数，旧AudioToolbox completion迟到后不能修改replacement graph状态。
- 最终production client在configure时attach player并连接main mixer，start后启动engine/player，stop时停止player/engine、reset并清除configuration；pipeline失败reconfigure会停止partial graph、清空old queue/config/route，不能从failed/stopped状态直接restart。
- byte-exact PCM factory回读、bounded scheduling、completion释放、late completion、backend failure transactional rollback、failed replacement和production graph construction均有回归。focused decoder+graph gate`18/18`，完整macOS gate`247 total / 246 passed / 1 explicit Keychain skip / 0 failed`。
- macOS、固定iPhone/iPad/tvOS/visionOS最终warnings-as-errors Debug build与全部静态门禁通过；四个simulator保持`Shutdown`。该证据不证明A/V sync、route/interruption、loss concealment或audible hardware output。

### 2026-07-21 阶段 13 A/V Clock 设计

- audio/video RTP timestamp可能使用独立随机起点，不能把原始UInt32除以timescale后直接相减。6.4分别在首个local presentation observation建立零点，测量各自`local elapsed - media elapsed`的变化，再比较两条stream的offset drift。
- audio clock不使用固定240 frames假设：每个scheduled receipt在其buffer-start presentation time记录此前累计的实际decoded frames，再把本包实际frame count加入下一位置；首包120-frame priming和后续实际输出因此不会制造伪漂移。
- 默认audio fresh窗口100 ms，audio失活后回退video。abs drift不超过15 ms不动作；video ahead每次hold最多10 ms，video behind每次只drop当前一帧；abs drift超过250 ms只重锚video，保持audio master连续。
- `MediaClockSynchronizer`最终对audio/video UInt32 RTP分别执行forward/wrap-aware展开，全局local presentation observation必须monotonic；invalid policy、frame count、backward timestamp/time和所有checked arithmetic均结构化fail closed，后置decision失败会rollback候选state。
- hard threshold正负边界均直接reanchor video；audio stale时不再按旧audio state校正。clock-specific最终`12/12`，expanded音视频pipeline gate`63/63`，完整macOS gate`259 total / 258 passed / 1 explicit Keychain skip / 0 failed`。
- 五平台warnings-as-errors Debug build及全部静态门禁通过，四个固定simulator保持`Shutdown`。该证据证明deterministic clock decision，不证明route/interruption/loss concealment、实际renderer应用decision或audible synchronized hardware output。

### 2026-07-21 阶段 13 Audio Recovery 设计

- `SessionAudioRuntime`作为session级owner组合6.3 pipeline与6.4 clock。route change和underrun都清空旧scheduled buffers、重建graph并reset clock；interruption begin停止graph，只有明确`shouldResume`才重新configure/start。
- 短packet loss采用bounded silence：最多4包、总计最多960 frames，sequence/RTP timestamp均wrap-aware推进，clock按补入的实际silence frames推进。超过边界直接rebuild；若多包补偿中途失败，也rebuild清除partial schedule和clock state。
- stop幂等并释放graph/clock；stopped后的schedule/event fail closed。typed handler不声称已经监听平台notification，macOS/iOS/tvOS/visionOS route/interruption source接线分别保留阶段16/17。
- 最终实现对interruption期间route change返回typed `routeChangeDeferred`，不抢先激活系统audio session；重复interruption begin保持幂等并推进monotonic event time。`AudioSessionPipeline.start()`失败也会停止partial engine、清queue并清除configuration/route，recovery owner不会重复释放底层资源。
- focused recovery gate最终`33/33`，expanded audio/runtime/resource gate`66/66`；完整macOS warnings-as-errors gate实际为`270 total / 269 passed / 1 explicit Keychain skip / 0 failed`。五平台warnings-as-errors Debug build与全部静态门禁通过，四个固定simulator前后保持`Shutdown`。
- 该证据证明typed recovery state machine、bounded concealment与确定性graph/clock teardown，不证明平台route/interruption notification已接线、声音已从硬件输出或A/V同步在真实Sunshine session中可听；这些证明仍分别属于阶段16/17和6.7。

### 2026-07-21 阶段 13 Audio Deterministic Integration Test 设计

- 6.1-6.5已有各层单元回归，但尚无同一测试把synthetic Opus fixture经过jitter reorder/loss、production AudioToolbox decode、session runtime scheduling、actual-frame clock与resource tracker teardown串联起来；6.6补齐该确定性边界，不新增或伪装network/audio hardware证据。
- 正常路径使用UInt16 sequence与UInt32 RTP双wrap的乱序包，要求jitter按wire顺序释放、decoder保留sequence/timestamp、clock累计每次真实decoded frame count，并在tracker逆序关闭audio graph与decoder后拒绝迟到`.dataConsumed` callback污染。
- loss路径要求jitter先发布typed missing range，再由recovery runtime补入exact sequence/RTP的240-frame静音，随后继续decode future packet；最终engine schedule顺序、silence samples、concealed count、clock total与stop后的零ownership必须一致。

### 2026-07-21 阶段 13 Audio Deterministic Integration Test 验收

- 连续的4个synthetic stereo Opus packets由development-only libopus 1.6.1在同一encoder state下生成，fixture逐包SHA-256与generator output均已回读一致；production target仍不包含libopus或新package/product。
- 跨层测试暴露真实decoder缺陷：单包input proc用`0 packets + noErr`表示当前无更多输入时，AudioConverter将其视为永久EOF，后续合法连续包得到0 frames。`kConverterPrimeMethod_None`在该Opus converter上返回`'prop'`而不可用；最终按SDK contract返回private temporary-unavailable callback status，让每次pull返回当前已产生PCM并保持converter state，decoder对0-frame输出继续fail closed。
- 最终正常路径覆盖UInt16 sequence和UInt32 RTP双wrap、乱序释放、连续production decode、实际frame clock、逆序audio/decoder teardown、迟到`.dataConsumed` callback与closed decoder；loss路径覆盖typed missing range、exact 240-frame silence、未来包恢复、schedule顺序和零ownership。
- focused decoder/integration gate `11/11`，expanded audio/RTSP/runtime/resource gate `69/69`；完整macOS warnings-as-errors gate `273 total / 272 passed / 1 explicit Keychain skip / 0 failed`。五平台warnings-as-errors Debug build、fixture/OpenSpec/generator/boundary/ENet/四SDK C gates全部通过，四个固定simulator前后均为`Shutdown`。
- 6.6证明确定性decode/jitter/sync/teardown行为，不证明`.dataConsumed`已经从硬件播放、A/V在真实Sunshine session中可听同步、route/interruption平台notification已接线或6.7 live gate完成。

### 2026-07-21 阶段 13 Authenticated Remote Input 设计

- 现代Sunshine encrypted-control协议中，input data是control message type `0x0206`的payload；外层AES-128-GCM frame与start/IDR/其他control messages共享同一`rikey`和sequence space，client nonce固定字段为`CC`。input runtime若从0另起sequence会与已发送control frame复用nonce，必须禁止。
- 7.1采用显式control-wide sequence的stateless authenticated encoder，不自行维护第二计数器；negotiated input config只接受16-byte key、UInt32范围key ID、启用authenticated mode和有界plaintext size。
- input plaintext自身使用4-byte big-endian payload length、4-byte little-endian event magic以及事件字段规定的端序。7.1先固定协议级packet/envelope与独立synthetic exact-wire vectors；队列、transport reliability、platform event mapping、coalescing和release ownership属于后续7.2-7.6。

### 2026-07-21 阶段 13 Authenticated Remote Input 验收

- `RemoteInputPlaintextPacket`严格验证8...128-byte协议边界、big-endian payload length和非零little-endian event magic；keyboard down/up serializer保留协议mixed-endian字段，14-byte keyboard fixture与Node/OpenSSL 3.6.3独立AES-128-GCM frame逐byte一致。
- `AuthenticatedRemoteInputContext`只持有协商key与plaintext上限，调用方必须显式提供control-wide UInt32 sequence；它复用现有control frame codec的client `CC` nonce，不创建input私有counter，mutation、wrong origin和wrong control type全部fail closed。
- negotiated input只接受16-byte AES key、UInt32范围key ID、`encrypted=true`和8...128-byte plaintext limit。AppModel默认每个独立launch用`SecRandomCopyBytes`生成新key/key ID，固定key仅作为显式测试override；随机源失败和invalid material都在网络launch前拒绝。
- expanded input/control/session gate `70/70`；完整macOS warnings-as-errors gate `280 total / 279 passed / 1 explicit Keychain skip / 0 failed`。五平台Debug build、fixture/OpenSpec/generator/boundary/ENet/四SDK C gates通过，固定simulator最终均为`Shutdown`。
- 7.1不证明event已进入ENet transport、不证明ordered delivery/backpressure/coalescing、平台键鼠触控映射、focus-loss release或live Sunshine输入；这些边界仍属于7.2-7.7与阶段14。

### 2026-07-21 阶段 13 Ordered Remote Input 设计

- modern encrypted input与start/IDR共享control AES-GCM key/sequence，但使用ENet channel区分流量：keyboard `0x02`、mouse `0x03`、touch `0x05`、UTF-8 `0x06`。因此7.2必须扩展现有control actor发送plaintext packet，不能建立独立input transport或sequence。
- pointer button使用gen5 down/up magic `0x08/0x09`与1...5 button code；vertical scroll使用gen5 magic `0x0A`并重复big-endian Int16 amount，Sunshine horizontal scroll使用magic `0x55000001`。Touch使用magic `0x55000002`、little-endian pointer/Float32、normalized coordinates、bounded pressure和unknown rotation `0xFFFF`。
- UTF-8 text/clipboard magic为`0x17`。为兼容host parsing，每个Unicode scalar单独形成packet并保持原文顺序；整个paste需要硬上限，空或超限/非法event fail closed。7.2先可靠发送所有支持event，运动coalescing与可丢弃policy留7.3/7.6。
- `MoonlightRemoteInputProvider`必须显式保留一个drain task：actor在等待sender时会重入，单靠actor isolation无法防止另一个event插入clipboard多packet发送。codec错误在入队前拒绝且不破坏active input；真实sender失败则关闭input generation、失败current/pending并拒绝late send。
- 7.2 production路径以`MoonlightControlChannel`作为`AuthenticatedInputFrameSending`：activation要求当前control已连接且input AES key逐byte匹配；input在同一actor内seal并先消费control-wide sequence后send，避免不确定发送后的nonce复用。

### 2026-07-21 阶段 13 Ordered Remote Input 验收

- byte-exact fixture覆盖left-button down、vertical `-120`、horizontal `40`、normalized touch `(0.5, 0.25, 0.75)`与`A`/emoji逐scalar UTF-8 packet；Node Buffer按字段宽度/端序独立重建后与fixture逐byte一致。fixture采用空格分隔byte notation以通过统一secret validator。
- control actor在start A/B与IDR之后发送input仍使用连续sequence `0,1,2,3`；input uncertain send先消费sequence，下一control message使用新sequence。input activation要求active control和逐byte相同AES key，stop会清除input context。
- provider以最多256 pending events/8192 pending packets和4096 clipboard UTF-8 bytes设界；单一drain operation保证并发send仍为event FIFO，clipboard多packet不可插入。transport失败会失败current/pending、deactivate sender并拒绝late send；unsupported movement/controller在入队前拒绝且不破坏active input。
- targeted `11/11`、expanded input/control/session `82/82`、最终完整macOS warnings-as-errors `292 total / 291 passed / 1 explicit Keychain skip / 0 failed`。最终macOS、固定iPhone/iPad/Apple TV/Vision Pro Debug build与全部静态门禁通过，四个固定simulator前后均为`Shutdown`。
- 7.2证明authenticated ENet send边界与确定性ordering，不证明host已消费event、macOS raw key已映射Win32 VK、真实cursor capture、movement coalescing、controller feedback、focus-loss release或live Sunshine输入；这些仍属于7.3-7.7与阶段14。

### 2026-07-21 阶段 13 Pointer Movement 与 Coalescing 设计

- modern relative pointer packet使用gen5 magic `0x07`与big-endian Int16 x/y delta；absolute packet使用magic `0x05`以及big-endian x/y/unused/reference-width-1/reference-height-1。absolute event必须携带产生坐标时的source reference size，不能依赖发送时可能已变化的全局窗口状态。
- relative coalescing累加同button snapshot的未发送delta，超出单packet Int16时按最多16包完整拆分；absolute coalescing只保留同reference size/button snapshot的最新位置。coalescing只检查FIFO队尾，因此任何keyboard/button/scroll/touch/clipboard或不同movement类型都会成为不可跨越的状态屏障。
- 一个coalesced job可拥有多个等待send调用；物理packet成功后全部continuation完成，failure/stop时全部同样失败。除pending event和packet上限外还需要pending caller上限，避免大量合并调用绕过内存边界。

### 2026-07-21 阶段 13 Pointer Movement 与 Coalescing 验收

- relative gen5 packet为12 bytes：BE payload length `8`、LE magic `0x07`、BE Int16 x/y；absolute packet为18 bytes：BE payload length `14`、LE magic `0x05`、BE x/y/zero/reference-width-1/reference-height-1。repository fixture与Node Buffer独立重建逐byte一致。
- relative单次最多完整拆分16包，正向边界`32767 * 16`与负向边界`-32768 * 16`均不丢余量；合并后超过codec边界时退回两个独立FIFO delivery。NaN、infinity、越界坐标/尺寸和超过显式packet bound的event结构化fail closed。
- provider只在pending FIFO队尾合并同button snapshot relative movement，或同button/reference size absolute movement；keyboard、button、scroll、touch、clipboard、不同movement类型和不同状态均为barrier。absolute event在adapter生成时捕获source reference size，窗口后续resize不会改写已排队坐标语义。
- 每个coalesced caller只在最终物理packet成功后完成；transport failure、stop、caller上限和packet上限都有确定性回归。最终targeted `29/29`、expanded input/control/session `97/97`；完整macOS warnings-as-errors `303 total / 302 passed / 1 explicit Keychain skip / 0 failed`。
- macOS、固定iPhone/iPad/Apple TV/Vision Pro warnings-as-errors Debug build、fixture/OpenSpec/generator/reference/dependency/ENet/四SDK C与independent Node gates全部通过，固定simulator最终均为`Shutdown`。7.3不证明平台`NSEvent`/cursor capture、focus-loss release、controller feedback或live Sunshine movement消费。
### OpenSpec 7.4 controller and feedback protocol boundary (2026-07-21)

- The pinned `moonlight-common-c` reference uses a 34-byte generation-5 multi-controller packet: big-endian payload size `30`, little-endian magic `0x0000000C`, controller index, active mask, split low/high button flags, triggers, four signed stick axes, and fixed tail fields.
- Controller state, arrival, disconnect fallback, and battery packets use reliable ENet channel `0x10 + zero-based controller index`; motion uses unreliable channel `0x20 + index`.
- Sunshine supports exactly 16 controller indices. Apple player indices `1...4` therefore normalize to protocol indices `0...3` when available; other controllers take the lowest free slot.
- A single `GameControllerInputEvent` is a delta, not a wire snapshot. The session must own a controller registry and full-state accumulator so an axis update cannot clear held buttons or other axes.
- Arrival is a typed `0x55000004` packet followed by an empty multi-controller fallback packet. Disconnect is an empty state packet with that controller removed from the active mask.
- Accelerometer (`0x01`, m/s^2) and gyroscope (`0x02`, deg/s) samples must remain disabled until the host sends a matching motion-rate feedback request; rate zero disables that sensor again.
- Known feedback control types are rumble `0x010B`, trigger rumble `0x5500`, motion request `0x5501`, and RGB LED `0x5502`. Exact payload lengths and controller indices must be validated before broadcasting; malformed known types fail closed.
- Parsing and broadcasting feedback proves the runtime boundary only. Applying rumble, trigger motors, LED, or sensor enablement to actual `GCController` hardware remains a later platform integration proof.

### OpenSpec 7.4 controller and feedback protocol acceptance (2026-07-21)

- Session-owned registry accepts at most 16 controllers, maps Apple player index `1...4` to protocol index `0...3` when available, otherwise chooses the lowest free index, and accumulates delta events into a complete snapshot without clearing held buttons or axes.
- Connection sends arrival plus empty multi-controller fallback; disconnect sends an empty state with the active mask cleared. State/arrival/battery use reliable channel `0x10 + index`; motion uses unreliable channel `0x20 + index` and remains disabled until matching host motion-rate feedback enables the sensor.
- Control parsing strictly accepts rumble `0x010B`, trigger rumble `0x5500`, motion rate `0x5501`, and RGB LED `0x5502` only at exact payload sizes with controller index `0...15`; typed feedback is bounded at 64 newest values, maps protocol index back to controller ID, and finishes on control/input teardown.
- Final targeted warnings-as-errors gate passed `44/44`; complete macOS gate passed `314 total / 313 passed / 1 explicit Keychain skip / 0 failed`. macOS, fixed iPhone/iPad/Apple TV/Vision Pro Debug builds and fixture/OpenSpec/generator/boundary/ENet/four-SDK-C/independent-Node gates passed; all four fixed simulators ended `Shutdown` with one available instance per specified name.
- This proves deterministic serialization, bounded state/feedback handling, teardown, and capability policy. It does not prove Sunshine consumed controller input or physical `GCController` rumble, LED, trigger motors, motion sensing, and battery reporting; those remain 7.7 and later platform integration work.

### OpenSpec 7.5 held input release design (2026-07-21)

- Tracking only delivered wire transitions is too late because release must be ordered behind already queued key/button downs. The provider therefore owns candidate held state at queue-accept time, commits it transactionally with controller registry state, and places one atomic release batch after all earlier deliveries.
- Synthetic keyboard release uses the held raw key code with `isDown=false`, `isRepeat=false`, no characters, and an empty modifier mask; preserving the down-event modifier mask during global release could leave a host modifier logically active. Pointer buttons release in reverse press order, while every connected controller emits a neutral snapshot with the current active mask.
- Normal queue limits retain a fixed reserved release allowance bounded by maximum held keys, five pointer buttons, and sixteen controllers. Repeated release is idempotent because ownership is cleared when the batch is accepted; any transport failure still fails the session and clears local ownership rather than claiming host delivery.
- A release operation must also close the provider's input-acceptance gate until its ordered batch completes. Otherwise a concurrent key-down can be accepted behind the focus-loss release and re-establish remote held state after `releaseAll()` returns. Concurrent release callers share one operation, and stop waits for that same operation before transport deactivation.

### OpenSpec 7.5 held input release acceptance (2026-07-21)

- Final provider behavior covers 256 bounded held keys, all five pointer buttons, non-neutral state for up to sixteen connected controllers, reverse release ordering, empty keyboard modifiers, active controller-mask preservation, idempotent repeated release, concurrent release merging, input rejection while release/stop is active, and a zero-packet drain barrier for an already accepted key-up/controller transition.
- Feedback/control disconnect and input send failure clear generation-owned local state before a replacement session can start. This is intentionally not reported as a remote release because the authenticated channel is already unusable; a normal stop sends release first and records transport deactivation only after the batch completes.
- Final warnings-as-errors evidence is `37/37` targeted, `86/86` expanded input/control/session, and `322 total / 321 passed / 1 explicit Keychain skip / 0 failed` complete macOS. macOS, fixed iPhone/iPad/Apple TV/Vision Pro Debug builds plus fixture/OpenSpec/generator/boundary/ENet/four-SDK-C/independent-Node gates passed; all fixed simulators remained unique and `Shutdown`.
- The runtime now exposes and enforces the release boundary, but application lifecycle code does not yet own a production input provider. Wiring `NSWindowDidResignKeyNotification` or SwiftUI scene/focus changes to `releaseAll()` remains application integration/platform work, and live Sunshine receipt remains task 7.7.

### OpenSpec 7.6 input verification audit (2026-07-21)

- Existing suites already cover exact wire fixtures, shared authenticated control sequencing, mixed-event FIFO, atomic clipboard, movement coalescing, packet/event/caller bounds, controller accumulation, feedback parsing, release ordering, teardown, and failure convergence.
- The missing spec branch was unsupported remote feedback: a connected controller lacking rumble, trigger-rumble, motion, or LED capability was silently ignored. The feedback stream needs a typed, non-secret diagnostic that distinguishes an unavailable controller index from an originating controller with an unsupported capability.
- Release reservation also needs a deterministic full-normal-queue test. A rejected key-down must not enter held ownership, while an accepted release batch must bypass normal queue bounds and remain ordered after all earlier accepted transitions.

### OpenSpec 7.6 input verification acceptance (2026-07-21)

- Unsupported rumble, trigger-rumble, motion-rate, and LED commands now publish a bounded typed diagnostic that distinguishes `unsupportedCapability` from `controllerUnavailable`. It contains only controller ID/index, command kind, and reason; motor/color/rate values, session keys, endpoints, and packet payloads are not copied into the diagnostic.
- An unsupported motion-rate command never mutates the controller registry. An unavailable protocol index produces no hardware feedback command. Feedback output remains `.bufferingNewest(64)`, finishes on teardown, and an old source generation cannot publish into a replacement session.
- Queue verification proves accepted transitions remain FIFO, a release reservation bypasses full normal limits behind earlier accepted input, rejected key-down does not enter held ownership, duplicate down transitions create one release per held input, and wrong-session release cannot mutate active ownership.
- Final warnings-as-errors evidence is `42/42` targeted, `91/91` expanded input/control/session, and `327 total / 326 passed / 1 explicit Keychain skip / 0 failed` complete macOS. macOS plus fixed iPhone/iPad/Apple TV/Vision Pro builds and fixture/OpenSpec/generator/boundary/ENet/four-SDK-C/independent-Node gates passed; each fixed simulator remained the only available instance of its name and `Shutdown`.
- This is deterministic provider/codec verification, not proof that the platform diagnostics UI is wired, physical `GCController` feedback is applied, or Sunshine received input/feedback. Those boundaries remain 8.5, later platform integration, and 7.7 respectively.

### OpenSpec 8.1 production provider availability design (2026-07-21)

- `RuntimeCapabilityAvailability.current` is the remaining hard-coded gate: both pairing and stream are permanently false even though pairing, session-control, and remote-input production actors now exist.
- Availability must be derived from injected provider instances, not independent booleans. Pairing requires a pairing provider; stream requires session control, video receive, audio receive, and remote input together so a partial inventory remains fail closed.
- The production factory can share one `MoonlightControlChannel` between `MoonlightSessionControlProvider` and `MoonlightRemoteInputProvider`, and can wrap `MoonlightPairingProvider` in `PersistingPairingProvider`. There are not yet concrete production `VideoReceiveProvider` or `AudioReceiveProvider` types, so default stream availability must remain false rather than claiming the lower-level packet/audio components are connected receivers.
- All five provider protocols conform to `Sendable`; the injected inventory can therefore be an immutable `Sendable` value snapshot. Pairing availability is independent, while streaming availability is the `sessionControl + videoReceive + audioReceive + remoteInput` subset and must become false when any one required provider is absent.
- The default factory only initializes repositories and actors. It performs no network operation or persistence write, and the same control actor is injected into both session control and remote input instead of creating duplicate authenticated control channels.

### OpenSpec 8.1 production provider availability acceptance (2026-07-21)

- `AppModel` now receives an immutable `RuntimeProviderInventory`; pairing and streaming guards read only the provider-derived `OptionSet`. The production factory injects persisted authenticated pairing plus shared control/input actors, while leaving absent video/audio receiver slots empty and therefore truthful.
- Availability tests cover empty, actual production, complete test, pairing-independent stream, and each individually missing control/video/audio/input inventory. The final targeted gate passed `12/12`, expanded application/session gate passed `51/51`, and complete macOS gate passed `328 total / 327 passed / 1 explicit Keychain skip / 0 failed`.
- macOS and the fixed iPhone/iPad/Apple TV/Vision Pro Debug warnings-as-errors builds passed. Fixture self-test/tree, all OpenSpec strict validation, generator byte-for-byte SHA-256, whitespace and production/reference/dependency boundaries, fixed ENet revision/license/source/header comparison, and four-SDK strict C syntax passed; every fixed simulator remained the sole available matching instance and `Shutdown`.
- This proves provider-based capability selection and fail-closed partial inventory behavior. It does not prove pairing UI execution, session readiness consumption, connected video/audio receivers, or live interoperability; those remain 8.2-8.4 and the explicit live tasks.

### OpenSpec 8.2 pairing application integration design (2026-07-21)

- The transport already exposes an attempt-scoped `PairingRuntimeRequest`, ordered `PairingSnapshot` progress, authenticated completion, and explicit cancellation. Application integration should consume that contract directly instead of duplicating protocol stages.
- Identity preparation must complete before the PIN field is presented. `AppModel` therefore needs an injectable identity-provisioning boundary backed by `ClientIdentityManager` in production, while retaining the existing Debug JSON fallback and the already verified Release Keychain store policy.
- Pairing UI state must own a non-secret attempt ID and stage, clear the four-digit PIN immediately after constructing the runtime request, ignore late events from cancelled/replaced attempts, and update the in-memory host only from the provider's persisted authenticated completion.
- Cancellation must invalidate application ownership before awaiting provider cancellation so a late progress/completion event cannot overwrite the cancelled state. Identity preparation has the same generation check even though local Security operations may finish before cancellation is observed.
- Swift `Character.isNumber` accepts non-ASCII numeral characters, but the wire PIN contract is four ASCII decimal bytes. Both the UI gate and the pairing state machine must validate UTF-8 bytes `0x30...0x39` so full-width or Arabic-Indic numerals never reach cryptographic key derivation.
- Pairing cancellation is also invoked from selected-host observation. It must be a no-op when the application owns no active pairing attempt; otherwise a host-selection change can incorrectly force an unrelated active stream to `disconnected`.
- Application-level rejection of mismatched attempt or host progress must explicitly cancel the provider attempt after invalidating UI ownership. Relying only on async-stream iterator destruction makes transport teardown timing implicit.

### OpenSpec 8.2 pairing application integration acceptance (2026-07-21)

- `AppModel` prepares and reload-validates a persistent client identity before exposing PIN entry, then submits exactly one attempt-scoped request and consumes authenticated provider progress/completion. The PIN is restricted to four ASCII bytes and cleared from UI/session state immediately after request construction.
- Cancellation invalidates application ownership before awaiting the provider. Late identity, progress, and completion cannot mutate cancelled or replacement state; mismatched progress, missing completion, invalid pin/certificate state, and provider failure all fail closed without changing the host trust record.
- Cancelling without an owned pairing attempt is a no-op, so selected-host observation cannot disconnect an unrelated stream. Duplicate submit is rejected while a request is running, and application rejection explicitly cancels provider work.
- Final evidence is `25/25` targeted, `56 total / 55 passed / 1 explicit Keychain skip / 0 failed` expanded, and `337 total / 336 passed / 1 explicit Keychain skip / 0 failed` complete macOS. All five Debug builds and fixture/OpenSpec/generator/boundary/ENet/four-SDK-C gates passed; fixed simulators remained unique and `Shutdown`.
- This proves deterministic application/provider integration. It does not prove a live Sunshine pairing or re-pair, which remains task 3.7, and does not prove stream readiness or media ownership, which remain 8.3-8.4.

### OpenSpec 8.3 session application integration design (2026-07-21)

- `MoonlightSessionControlProvider` already owns the launch/resume/RTSP/control teardown generation. `AppModel` must consume that provider stream and use `StreamSessionCoordinator` only as the ordered state reducer; calling the coordinator's legacy launch client would issue a second `/launch`.
- Streaming UI truth is the reducer snapshot: launch acceptance, RTSP readiness, or partial channel health remain connecting. Only a validated negotiated configuration plus all required control/video/audio/input readiness can enter `Streaming`.
- A provider-owned local stop must not invoke the coordinator's launch client for another `/cancel`. The reducer therefore needs generation-scoped begin/complete local-stop mutations, while the provider remains the sole transport teardown owner.
- AppModel must invalidate its active session ID before awaiting provider stop. Late events from the stopped generation then cannot restore streaming or mutate a replacement generation.

### OpenSpec 8.3 session application integration acceptance (2026-07-21)

- `AppModel` now prepares a generation in `StreamSessionCoordinator`, starts exactly one injected `SessionControlProvider`, consumes its events, and derives the visible phase/render policy from reducer snapshots. The legacy launch client is not called from the application launch path.
- Launch acceptance, RTSP readiness, partial channel health, and reconnect remain non-streaming. Only validated negotiation plus every required control/video/audio/input readiness bit enters Streaming; loss/reconnect immediately returns rendering to idle until fresh negotiation and full readiness recover.
- Local stop invalidates application ownership before awaiting provider teardown and uses reducer-only begin/complete stop transitions, so no second remote cancel is sent. Remote termination performs full UI cleanup without a local stop; stale/late events cannot restore a stopped generation.
- Invalid event order, provider throw, incomplete stream, input-key failure, and parameter preparation failure fail closed. Pre-start failure is visible but does not start/stop the provider; post-start failure stops the provider exactly once.
- Final evidence: targeted `31/31`, expanded `76/76`, complete macOS `344 total / 343 passed / 1 explicit Keychain skip / 0 failed`, and all five Debug warnings-as-errors builds passed. Fixture/OpenSpec/generator/boundary/ENet/four-SDK-C gates passed, and fixed simulators remained unique and Shutdown.
- This does not connect the concrete video/audio/input providers to the same session lifetime and does not prove live Sunshine media or input. Those boundaries remain 8.4, 5.8, 6.7, 7.7, and 9.2-9.3.

### OpenSpec 8.4 unified media environment design (2026-07-21)

- The lower native components are present, but no owner currently binds negotiated video/audio/input configuration to receiver streams, decode/audio processors, SwiftUI presentation, input activation, feedback, and deterministic teardown.
- Session control readiness is not authoritative for media readiness. The application must accept only the `.control` bit from `SessionControlProvider` and independently aggregate `.video`, `.audio`, and `.input` from a media environment after their actual startup succeeds.
- A generation-scoped media environment should own receiver-consumer tasks and resources through `SessionResourceTracker`. Stop invalidates ownership before awaits, cancels consumers, releases held input while control is still available, stops processors/receivers, clears presentation, and returns one idempotent teardown report.
- Reconnect must stop the old media environment and clear media readiness before fresh RTSP negotiation starts replacement media resources for the same session ID. Late events from the old media generation must not restore readiness or frames.
- Decoded frames need a bounded, thread-safe presentation source reachable from SwiftUI. Initial rendering can use Core Image backed by Metal for native SDR presentation; HDR/EDR transfer-function and headroom mapping remain explicitly owned by the later HDR change.

### OpenSpec 8.4 unified media environment lifecycle audit (2026-07-21)

- The first gate with the continuous Opus fixture passed `43/43`, proving four ordered packets traverse `NativeSessionAudioProcessor`, AudioToolbox, `SessionAudioRuntime`, and the session-owned audio graph.
- Starting ownership originally retained only identifiers, so `stop()` could only spin while `startInput()` was suspended. The starting generation now retains its tracker and stop starts the same reverse teardown operation immediately, allowing `stopInput()` to unblock startup.
- An externally cancelled media-event consumer originally left the environment alive, and an input-feedback stream that ended early left `.input` ready. Event-stream cancellation now tears down the matching generation, while an unexpected feedback end fails with `.streamEnded(.input)`.
- A processor factory can complete after teardown changes the tracker to stopping. Registration failure now explicitly stops the newly created processor, and the native video/audio factories clean up partial decoder, presentation-source, and audio-graph state.
- Media readiness now starts with input only. Video is added after a frame is successfully submitted to VideoToolbox, and audio is added after decoded PCM is successfully scheduled to the session graph; receiver-stream creation alone no longer permits `Streaming`.
- The Metal presenter now takes a locked render-state/runtime snapshot and submits a clear-only drawable whenever presentation is idle, paused, or has no current frame. This prevents a stopped or replacement session from leaving the previous frame visible.

### OpenSpec 8.4 unified media environment acceptance (2026-07-21)

- `NativeSessionMediaEnvironment` owns five resources and three consumers under one generation: video/audio receivers, video/audio processors, and remote input/feedback. Clean teardown releases input, audio processor, video processor, audio receiver, then video receiver; duplicate stop callers reuse the same report.
- Pending startup stop now tears down the starting tracker and unblocks input startup. Receiver or feedback end, processor failure, event-consumer cancellation, local/remote stop, reconnect, and late replacement events all preserve generation isolation and converge without surviving tasks.
- Session truth requires independent readiness: control contributes only `.control`, input contributes after activation, video after successful VideoToolbox submission, and audio after PCM schedule. A control provider reporting `.all` or receiver creation alone cannot enter `Streaming`.
- The decoded frame path is a bounded session/decoder-generation source rendered by Core Image on Metal with fit/fill and clear-only idle/no-frame presentation. It is deliberately SDR/system color at this stage; HDR/EDR transfer mapping remains stage 15.
- Final evidence is `45/45` targeted, `169/169` expanded, and `358 total / 357 passed / 1 explicit Keychain skip / 0 failed` complete macOS. macOS plus fixed iPhone/iPad/Apple TV/Vision Pro Debug warnings-as-errors builds passed; fixture/OpenSpec/generator/boundary/ENet/four-SDK-C gates passed and all fixed simulators remained unique and `Shutdown`.
- Production provider inventory still has no concrete video/audio network receiver, so default stream availability remains false. This task proves integration ownership and native processing paths, not sustained live Sunshine video, audible hardware audio, delivered live input, HDR tone mapping, or spatial audio.

### OpenSpec 8.5 application diagnostics audit (2026-07-21)

- The repository has two disconnected diagnostic layers. `Sources/LuneXDiagnostics/RuntimeDiagnostics.swift` is bounded and typed with privacy-aware fields, while `Sources/LuneXDiagnostics/DiagnosticsStore.swift` and AppModel primarily retain arbitrary message/subsystem strings. The SwiftUI Diagnostics page only presents the latter, so lower-level stage, code, and severity do not drive stable user behavior.
- Session failures currently collapse through `failStreamSession` into a `SessionError` plus a string message. Media failures use the same path, so decoder, audio, and input errors are not reliably distinguishable. Pairing failures use generic copy without a consistent retry, re-pair, or host-check action.
- Task 8.5 needs a closed application diagnostic category/severity/code/action model mapped from known error types. Unknown errors must use a safe generic summary and action instead of displaying `String(describing:)`. The Diagnostics page should expose scannable category, summary, suggested action, and timestamp; pairing and stream surfaces should show only the current actionable failure.
- A post-gate audit found two residual arbitrary-string paths: pairing progress copied `PairingFailure.message`, and the plain `DiagnosticsStore.record(String)` API accepted embedded secret markers. Pairing failure progress now terminates into the typed classifier, and the store sanitizes every appended message with the same embedded-secret redactor used by runtime fields.

### OpenSpec 8.5 application diagnostics acceptance (2026-07-21)

- Pairing, transport/RTSP/control, VideoToolbox/video pipeline, Opus/audio graph, remote input, and controller feedback failures now map to a closed application category/severity/code/action model. Unknown errors use stable generic summaries rather than copying arbitrary descriptions.
- `DiagnosticsStore` is bounded to 500 events by default and re-redacts every appended message. UI-visible records never include host/provider raw termination reasons, PIN, authorization, private keys, session keys, controller identity, endpoint, certificate, or packet payload fields.
- Pairing and stream panels show only the current safe recovery action; normal stop and remote disconnect clear stale failure/action state. The Diagnostics view presents category, severity, code, safe summary, suggested action, and timestamp.
- Final evidence is `48/48` targeted and `365 total / 364 passed / 1 explicit Keychain skip / 0 failed` complete macOS. App/persistence/catalog diagnostics and audio-route snapshots also avoid arbitrary error text, host identity/address, and output-device names. All five Debug warnings-as-errors builds and fixture/OpenSpec/generator/boundary/ENet/four-SDK-C gates passed; fixed simulators remained unique and `Shutdown`.
- This proves actionable and privacy-bounded application diagnostics. It does not add missing production video/audio receivers, enable live streaming, prove Sunshine interoperability, or complete later HDR, spatial-audio, PiP/background, and native-input experience stages.

### OpenSpec 8.6 fail-closed provider audit (2026-07-21)

- `RuntimeProviderAvailability.requiredStream` is the exact four-provider set: session control, video receive, audio receive, and remote input. Pairing remains independent.
- Application guards execute before pairing identity provisioning and before stream input-key generation, session preparation, control start, or media-environment start. The remaining work is an execution-level missing-provider matrix proving every one of those side effects stays at zero.
- The production factory deliberately provides pairing/control/input but no concrete video/audio network receivers. Task 8.6 must preserve this truthful unavailable state; it must not add placeholder receivers or weaken readiness to complete the checklist.

### OpenSpec 8.6 fail-closed provider acceptance (2026-07-21)

- Pairing-provider absence now has an execution-level regression proving identity provisioning never starts and the host remains unpaired without a pinned identity. The application emits the stable `pairing_provider_unavailable` diagnostic.
- A four-case matrix removes session control, video receive, audio receive, or remote input one at a time. Every case remains disconnected, idle, and in the library while input-key generation, control start, media-environment start, and legacy launch counts all stay zero; the application emits `stream_provider_unavailable`.
- Final evidence is `28/28` targeted, `84/84` expanded, and `366 total / 365 passed / 1 explicit Keychain skip / 0 failed` complete macOS. All five Debug warnings-as-errors builds, fixture/OpenSpec/generator/boundary/ENet/four-SDK-C gates, and fixed-simulator uniqueness/Shutdown checks passed.
- No production availability was widened. The factory still lacks concrete video/audio network receivers, so the default app cannot claim a stream session; authorized live pairing, sustained video, audible hardware audio, delivered input/feedback, and end-to-end interoperability remain unproven.

### OpenSpec 9.1 offline verification acceptance (2026-07-21)

- The current XCTest source has one opt-in integration environment variable: `LUNEX_RUN_KEYCHAIN_TEST=1`. No live-host integration XCTest exists yet, so the normal suite contains no environment-triggered discovery, pairing, launch, or streaming operation.
- A fresh isolated macOS warnings-as-errors run with `LUNEX_RUN_KEYCHAIN_TEST` explicitly removed passed `366 total / 365 passed / 1 skipped / 0 failed`. The xcresult test tree identifies the sole skip as `testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()` and its expected one-time authorization message.
- This is complete evidence for the deterministic offline suite only. It does not satisfy the missing opt-in live-host test implementation, authorized host-state capture, sustained media, hardware audio, delivered input, reconnect, or end-to-end tasks.

### OpenSpec 9.4 multi-platform build acceptance (2026-07-21)

- macOS, fixed iPhone 17 Pro, fixed iPad Pro 13-inch (M5), fixed Apple TV, and fixed Apple Vision Pro each passed both Debug and Release Swift/Clang warnings-as-errors builds with a distinct DerivedData directory, for ten successful application builds.
- Fixed simulator identity and state were read before and after the build matrix. Each requested device name resolved to exactly one available instance with the expected UUID, and every instance remained `Shutdown`; no simulator was created or explicitly booted.
- This verifies source compatibility and optimized configuration compilation across the five application targets. It does not prove launch behavior, real-device signing, live media, hardware capabilities, performance, power, or release distribution readiness.

### OpenSpec 9.5 simulator inventory acceptance (2026-07-21)

- Normalized CoreSimulator records from immediately before the 9.4 build matrix, immediately after it, and the independent 9.5 readback are byte-identical for the four fixed targets.
- Each requested name has one available instance, each expected UUID occurs once, all four states are `Shutdown`, and the current available-device inventory contains zero `Booted` simulators.
- The audit performed no create, boot, shutdown, delete, clone, or build action. It verifies inventory stability for the configured available runtimes, not physical-device behavior or unavailable historical runtimes.

### OpenSpec 9.6 strict, sanitizer, static, and resource acceptance (2026-07-21)

- All four OpenSpec changes pass strict validation. macOS Debug and Release `xcodebuild analyze` both succeed and produce the same structured finding set: zero diagnostics in the repository-owned `LuneXENetBridge`, plus four findings in byte-identical pinned ENet source.
- The ENet findings are three dead stores (`compress.c:320`, `unix.c:521`, `unix.c:526`) and one potential null dereference at `unix.c:867`. The latter exists for a public API call with non-null peer and null local address; LuneX reaches receive only through `enet_host_service`, whose `protocol.c` call supplies both addresses. It remains a disclosed dependency risk rather than being hidden or patched outside the pinned-revision process.
- The complete ASan and TSan offline suites each pass `366 total / 365 passed / 1 explicit Keychain skip / 0 failed`, with no AddressSanitizer, LeakSanitizer, or ThreadSanitizer report. A 174-test ownership/teardown set also passes with malloc scribble, guard edges, stack logging, heap checks, and error-abort enabled.
- TSan exposed a test synchronization defect, not a reported data race: the decoder-drop test observed the actor after its drop counter changed but while `beginRecovery` was suspended in decoder stop. The test now waits for the complete recovery transaction and requester count; targeted TSan and the complete TSan/normal suites pass.

### OpenSpec 9.7 tracking and remaining-work acceptance (2026-07-21)

- The roadmap now records current proof and missing proof for every stage from 13 through 20, distinguishes deterministic work that can proceed offline from completion gates requiring an authorized host or physical hardware, and adds executable stage 18–20 scope.
- Stage 13 offline/runtime-foundation acceptance passes based on normal, five-platform Debug/Release, simulator-inventory, strict/static, ASan/TSan, and resource evidence. The stage and change remain incomplete because seven tasks still require host/hardware evidence: 1.1, 3.7, 5.8, 6.7, 7.7, 9.2, and 9.3.
- The named stage 14–20 changes do not yet exist as OpenSpec objects. The next unblocked action is to propose and implement stage 14 macOS native input/lifecycle work while preserving all stage 13 live gates as pending.

### Stage 14 OpenSpec and runtime-boundary audit (2026-07-21)

- `AppKitLifecycleMonitor` already observes the requested occlusion, key/resign-key, application activation, screen-parameter, backing, minimization, and resize notifications, but currently updates only render policy/drawable/headroom. It does not call active input release, apply decoder policy, or bind geometry to the actual stream surface.
- `MacInputAdapter`, `InputMapper`, cursor policy, and authenticated remote provider exist as disconnected/tested types. No AppKit view captures `NSEvent`; no cursor owner calls balanced AppKit/CoreGraphics APIs; `AppModel` does not expose a bounded active-session input sink.
- The current mapper independently recomputes a video rectangle from whole-window drawable size and clamps fit letterbox points to a remote edge. Stage 14 defines one revisioned actual-surface coordinate snapshot shared by renderer and input, with letterbox rejection and resize generation safety.
- `integrate-macos-native-input-lifecycle` is apply-ready with three new capabilities and 29 tasks. Its design keeps AppKit sampling synchronous, serializes delivery in a generation-owned actor, drains transport while decoded submission is paused, and requests a fresh IDR on visible resume. It adds no dependency and does not widen production provider availability.

### Stage 14 task 1.1 contract acceptance (2026-07-21)

- Xcode 26.4 SDK contracts confirm window occlusion/key/screen/backing/resize/minimize notifications bind to the current `NSWindow`; application screen-parameter and active notifications are global signals but may act only on the current attachment. Old window, view, coordinate revision, and session generation callbacks require explicit rejection.
- `NSEvent.locationInWindow` is not a stream-view coordinate. Absolute input first converts into the real stream view and then to backing pixels. Scroll uses `scrollingDeltaX/Y` and distinguishes non-precise row/column units from precise point values.
- `NSEvent.keyCode` is a macOS device-independent key number, not a remote Win32/GameStream key code. The current `MacInputAdapter` plus `RemoteInputWireCodec` would serialize it unchanged, so native integration must add an explicit translation table and fail closed for unknown keys.
- `docs/runtime/macos-input-lifecycle-contract.md` freezes scoped first-responder capture, balanced cursor and relative-association ownership, one generation FIFO, focus-loss admission plus `releaseAll`, a shared revisioned render/input rectangle, and multi-window attachment ownership. The task changed no production runtime.

### Stage 14 task 1.2 coordinate resolver acceptance (2026-07-21)

- `StreamVideoRectangleResolver` is platform-neutral and resolves source size, actual drawable size, and scale mode into immutable drawable bounds, the full destination video rectangle, the visible source crop, and one scale. Fit preserves the whole source and exposes letterbox geometry; fill exposes the centered offscreen destination and bounded source crop.
- `StreamCoordinateSnapshotPublisher` advances a `UInt64` revision only when source/drawable/mode inputs change. Invalid positive-size requirements clear availability while consuming the input revision, unchanged inputs reuse the same value, later valid geometry gets a newer revision, and revision overflow fails closed without wrapping.
- Focused Swift 6 warnings-as-errors tests passed `6/6` for fit, fill, invalid geometry, unchanged reuse, invalid-to-valid recovery, and overflow. The new value source compiled in isolated Debug builds for macOS and fixed iPhone/iPad/tvOS/visionOS targets; pre/post readback kept all fixed simulators unique and `Shutdown` with zero globally booted devices.
- The types are intentionally not consumed by `StreamMetalPresenter` or `InputMapper` yet; that is task 1.3. Therefore this acceptance proves resolver and publication invariants, not letterbox rejection in the production input path or shared renderer behavior.

### Stage 14 task 1.3 shared coordinate contract acceptance (2026-07-21)

- `StreamRenderState` owns the revisioned publisher and republishes an immutable snapshot whenever source size, drawable size, or scale mode changes. Invalid geometry removes mapping availability rather than leaving a usable stale snapshot.
- `InputMapper`, macOS pointer mapping, and touch mapping now consume the snapshot directly. Fit-mode points inside drawable letterbox are rejected; fill-mode points map through the same centered destination rectangle/source crop used by presentation and retain the snapshot source reference size.
- `StreamMetalPresenter` retains only a locked `RenderPolicy` plus immutable coordinate snapshot. It positions the `CIImage` from `resolvedVideo.videoRect`, and if the actual drawable texture size differs from the snapshot it commits clear-only instead of presenting with mixed geometry.
- Focused tests passed `17/17`; the complete macOS suite passed `375 total / 374 passed / 1 explicit Keychain skip / 0 failed`. macOS and fixed iPhone/iPad/tvOS/visionOS Debug warnings-as-errors builds passed without booting simulators. All five OpenSpec changes validate strict, the project generator is byte-stable, old mapper-transform reconstruction is absent, and production has no reference-tree path.
- This proves one shared production coordinate contract and deterministic fit/fill behavior already covered by 1.3. It does not yet prove the full backing-scale/invalid/resize/stale-revision matrix assigned to 1.4, actual AppKit backing conversion, or live Sunshine pointer receipt.

### Stage 14 task 1.4 coordinate matrix acceptance (2026-07-21)

- The deterministic matrix rejects top/bottom and left/right fit letterboxes, ties fill drawable edges to the resolver's exact source-crop edges, and proves proportional 1x/2x backing points plus drawable sizes produce the same remote point under one revised snapshot.
- Every non-positive source or drawable dimension fails closed. Resize and scale-mode changes produce later revisions while previously captured value snapshots retain their original geometry and mapping, so an event cannot silently combine an old point with a new drawable.
- Focused Swift 6 warnings-as-errors tests passed `13/13`. The complete macOS suite passed `381 total / 380 passed / 1 explicit Keychain skip / 0 failed`; the test tree confirms the sole skip is the already-authorized real-Keychain round trip. OpenSpec strict, generator byte-stability, whitespace, and fixed-simulator Shutdown checks pass.
- This task changes tests only. It validates the platform-neutral coordinate contract but does not claim actual AppKit `convertToBacking`, stream-view attachment, live resize notification wiring, or Sunshine input receipt; those remain later stage-14 tasks.

### Stage 14 task 2.1 lifecycle directive acceptance (2026-07-21)

- `SessionLifecycleDirectiveResolver` is the single value resolver for render policy, decoded-video processing, presentation, and input admission. The legacy render-only resolver delegates to it, preventing drift between the existing UI path and later media application.
- An inactive session is fully closed without a release request. An active hidden or zero-drawable session pauses decode submission while explicitly retaining transport drain, clears presentation, and requires held-input release. A visible unfocused session keeps decode submission, throttles presentation, and requires release. Only active, visible, focused, positive-drawable state opens input and active presentation.
- The resolver's precedence is covered across all 16 boolean/drawable-ready combinations. Focused tests pass `11/11`; the complete macOS suite passes `387 total / 386 passed / 1 explicit Keychain skip / 0 failed`; all five Debug warnings-as-errors application builds pass, and generator/OpenSpec/simulator gates remain clean.
- The directive is not yet applied to a live media generation. This evidence defines policy only; generation-scoped environment application, decoder pause/resume/IDR, input barriers, AppKit attachment, and live Sunshine behavior remain subsequent tasks.

### Stage 14 task 2.2 generation-scoped lifecycle application acceptance (2026-07-21)

- `SessionLifecycleApplication` binds a directive to session UUID, internal media generation, and lifecycle revision. The environment accepts only its current generation, permits an exact duplicate idempotently, requires revision advancement for changed content, and rejects old generations, lower revisions, or conflicting content at the same revision.
- The active environment snapshot exposes only this value metadata; no video, audio, control, or input provider escapes the environment. Stopped snapshots clear it, and a replacement generation using the same session UUID cannot be mutated by the prior generation's delayed application.
- The first focused compile correctly failed because the new media error was not exhaustively classified. `ApplicationDiagnosticFactory` now maps it to stable `media_lifecycle_stale` transport guidance without copying session/generation details. The corrected focused gate passes `24/24`; complete macOS passes `390 total / 389 passed / 1 explicit Keychain skip / 0 failed`; five-platform Debug and repository gates pass.
- Application storage is not side-effect execution. This task does not yet pause decoded-video submission, clear the presentation source, request a fresh IDR, execute input release, connect AppModel, or prove any live host behavior.

### Stage 14 task 2.3 video lifecycle side-effect acceptance (2026-07-21)

- `NativeSessionVideoProcessor` now owns the lifecycle decode boundary. Non-submitting directives reset partial assembly and return from each receiver event without VideoToolbox submission, so the environment's existing bounded consumer continues draining transport rather than disconnecting or blocking it.
- A pause invalidates the active decoder, clears the current presentation immediately, and fences the discarded decoder generation. Resume keeps presentation empty, coalesces a single control-provider IDR request, drops predicted/paused access units until recovery, and only accepts the later decoder generation.
- Presentation ownership now includes the internal media generation in addition to session UUID and decoder generation. A delayed callback from an earlier media generation cannot publish into a replacement that reuses the same session UUID, even if both decoder instances use the same local generation number.
- The environment reserves lifecycle revisions across its suspension point and commits the public snapshot only after processor application. Lower/conflicting revisions remain fail closed, and stop/replacement checks run again after awaited side effects.
- Focused warnings-as-errors tests pass `26/26`; complete macOS passes `393 total / 392 passed / 1 explicit Keychain skip / 0 failed`; macOS plus fixed iPhone, iPad, Apple TV, and Apple Vision Pro Debug builds pass. This does not yet prove the complete task 2.4 race matrix, AppModel/AppKit directive delivery, input release, cursor capture, or live Sunshine behavior.

### Stage 14 task 2.4 lifecycle race-matrix acceptance (2026-07-21)

- A lifecycle application is published only after its processor effect succeeds while its generation/revision reservation is still current. Concurrent callers for the exact same pending application share one effect task instead of executing duplicate pause, clear, or resume side effects.
- A higher revision may replace a suspended reservation. When the older waiter resumes it receives `staleLifecycleApplication` and cannot clear or overwrite the newer snapshot. Stop clears environment ownership before teardown, and a suspended old generation receives `inactiveSession` after a same-UUID replacement instead of mutating it.
- The deterministic sequence covers hidden/occluded drain, visible-unfocused decode with throttled presentation, zero-drawable drain, and focused visible resume in revision order. Existing tests retain lower/conflicting revision and prior-generation rejection, completing the task's stale-directive matrix.
- Focused Swift/Clang warnings-as-errors tests pass `30/30`; the complete macOS suite passes `397 total / 396 passed / 1 explicit Keychain skip / 0 failed`. macOS and fixed iPhone/iPad/Apple TV/Apple Vision Pro Debug builds pass. All five OpenSpec changes validate strict, the generator remains byte-stable, and production/reference boundaries remain intact.
- Raw simulator inventory changed only runtime `lastUsage` timestamps during destination builds. Normalized device identity/state is byte-identical before and after; each fixed name and UUID is unique, all four devices are `Shutdown`, and global `Booted=0`. No simulator was created, booted, run, or shut down.
- This evidence proves environment-level lifecycle ordering and stale-effect isolation. AppModel directive delivery, input admission/release, AppKit capture/cursor ownership, live window behavior, and Sunshine receipt remain later tasks.

### Stage 14 task 3.1 application input sink acceptance (2026-07-21)

- `ApplicationInputSink` is a main-actor, Sendable application boundary that accepts only a repository-owned `RemoteInputEvent`. Platform code cannot provide a session UUID, media generation, provider, endpoint, or key material.
- AppModel reads and pins the environment generation once when media ownership starts, then clears it on stop, media failure, or session failure. It does not re-read generation for every high-rate event, so a stale same-UUID owner cannot adopt a replacement environment's generation.
- `SessionInputApplication` carries the internally owned session ID, pinned media generation, and event to the environment. The environment rejects inactive sessions, generation mismatch, and unavailable input readiness before invoking its private provider. Same-UUID stop/restart tests prove old applications fail with `staleInputApplication` while the replacement generation succeeds.
- Input-not-ready and stale-application errors map to stable, privacy-bounded input diagnostics. The AppModel gate proves no application is sent before media input readiness and that a ready send contains the environment generation without caller involvement.
- Final focused tests pass `4/4`; the complete macOS suite passes `399 total / 398 passed / 1 explicit Keychain skip / 0 failed`. macOS and fixed iPhone/iPad/Apple TV/Apple Vision Pro Debug warnings-as-errors builds pass. Five OpenSpec changes validate strict, generator SHA-256 remains `a0e3396cfb500e432cc10403c5dc23660a228a821fb0922b8744d34422301e5e`, and normalized simulator identity/state remains unchanged with all fixed devices `Shutdown` and global `Booted=0`.
- This task does not add the bounded platform FIFO, focus-loss release barrier, AppKit event translation/cursor ownership, or live Sunshine receipt. Those remain tasks 3.2 onward and the stage 13/14 live gates.

### Stage 14 task 3.2 bounded platform FIFO acceptance (2026-07-21)

- `MacSessionInputCoordinator` performs synchronous main-actor admission and owns one persistent consumer per opaque local generation. Platform callbacks do not create one task per sample, and a stale attachment token cannot enqueue into a replacement generation.
- The queue is a fixed-capacity ring FIFO with O(1) append/pop operations. Its outstanding bound includes the currently awaited sink delivery as well as queued samples, so a blocked provider cannot hide one extra accepted event outside backpressure accounting.
- Each accepted envelope freezes the platform sample, immutable coordinate snapshot, cursor policy, and shortcut-forwarding policy at enqueue time. Fit letterbox input is dropped locally, reserved shortcuts stay local, and deliverable events reach `ApplicationInputSink` in FIFO order.
- Focused Swift 6 warnings-as-errors tests pass `13/13`; the complete macOS suite passes `403 total / 402 passed / 1 explicit Keychain skip / 0 failed`. macOS and fixed iPhone/iPad/Apple TV/Apple Vision Pro Debug warnings-as-errors builds pass, and normalized simulator identity/state is byte-identical before and after with every fixed device `Shutdown` and global `Booted=0`.
- Five OpenSpec changes validate strict, generator SHA-256 is stable at `abdb7ba6c28d50f959111b1cfa3784e1d0c929552095c8f4eb3c5cdd40cdbc80`, and whitespace/reference-boundary gates pass. An old non-cancellation-responsive sink delivery may remain suspended after generation replacement, but generation checks prevent it from mutating replacement state; waiting for and converging old in-flight delivery remains task 3.4, while focus release remains task 3.3.

### Stage 14 task 3.3 focus-release barrier acceptance (2026-07-21)

- Focus eligibility and queue draining are separate coordinator concerns. Focus loss synchronously closes new sample admission but the single generation consumer continues every previously accepted sample before executing a release barrier that does not consume normal FIFO capacity.
- Repeated focus-loss signals share one barrier. Focus regain records eligibility but cannot reopen admission while the barrier is pending or in flight; successful completion reopens only the still-current eligible generation, and barrier failure remains fail closed.
- `SessionInputReleaseApplication` carries the AppModel-pinned session and media generation through the environment. The environment validates ownership before and after the provider suspension, while AppModel suppresses stale diagnostics if ownership changed, so an old release cannot target or pollute a replacement session.
- Focused Swift 6 warnings-as-errors tests pass `11/11`; the complete macOS suite passes `408 total / 407 passed / 1 explicit Keychain skip / 0 failed`. macOS and fixed iPhone/iPad/Apple TV/Apple Vision Pro Debug warnings-as-errors builds pass, with normalized simulator identity/state unchanged, every fixed device `Shutdown`, and global `Booted=0`.
- Five OpenSpec changes validate strict, project generation remains byte-stable at SHA-256 `abdb7ba6c28d50f959111b1cfa3784e1d0c929552095c8f4eb3c5cdd40cdbc80`, and whitespace/reference-boundary gates pass. This task does not yet converge send/channel failure, stop, remote termination, detach, cursor cleanup, or waiting for an unresponsive old delivery; those remain task 3.4 and later AppKit integration.

### Stage 14 task 3.4 input terminal convergence acceptance (2026-07-21)

- Send failure, input-channel failure, stop, remote termination, detach, and replacement now share one generation terminal state. It synchronously closes admission, prevents focus from reopening, drops samples that have not started delivery, and invokes the injected capture cleanup exactly once.
- Orderly terminal triggers wait the current in-flight send and one held-state release barrier before consumer completion. Send failure uses the provider's existing failure path for held-state clearing and does not issue a duplicate release; all later enqueue attempts remain closed.
- Activation is asynchronous when replacing an owner and awaits real old-consumer completion, including a sink that ignores task cancellation. Concurrent activation callers share one activation operation and receive the same replacement generation, preventing the first new consumer from being orphaned by a second reentrant replacement.
- Final focused warnings-as-errors tests pass `11/11`; the complete macOS suite passes `411 total / 410 passed / 1 explicit Keychain skip / 0 failed`. Rebuilt macOS and fixed iPhone/iPad/Apple TV/Apple Vision Pro Debug warnings-as-errors targets pass with normalized simulator identity/state unchanged, all fixed devices `Shutdown`, and global `Booted=0`.
- Five OpenSpec changes validate strict, generation remains byte-stable, and whitespace/reference-boundary gates pass. The cleanup callback is injectable but no real AppKit cursor owner is claimed; balanced `NSCursor` and pointer-association implementation remains task 4.1, while task 3.5 expands the deterministic reason/race matrix.

### Stage 14 task 3.5 input coordination matrix acceptance (2026-07-21)

- The matrix now covers FIFO ordering with enqueue-time geometry, in-flight capacity accounting, overflow rejection, full-capacity focus barriers, reserved/drop samples, repeated focus loss, focus regain during release, release failure, send failure, and one cleanup/release for every external terminal reason.
- Stop and remote termination waiters share completion; stale and inactive teardown calls cannot change replacement admission, cleanup, or release counts; same-generation and concurrent activation races produce exactly one replacement owner.
- Focused Swift 6 warnings-as-errors tests pass `15/15`; the complete macOS suite passes `415 total / 414 passed / 1 explicit Keychain skip / 0 failed`. Five isolated Debug warnings-as-errors app builds pass, and normalized simulator identity/state is unchanged with four unique fixed devices `Shutdown` and global `Booted=0`.
- Five OpenSpec changes validate strict, generator/project state remains stable, and whitespace/reference boundaries remain clean. These are deterministic coordinator/provider tests; they do not claim real `NSEvent`, `NSCursor`, Sunshine receipt, or hardware pointer behavior, which begin at tasks 4.1–4.5 and remain subject to the live gate.

### Stage 14 task 4.1 balanced cursor ownership acceptance (2026-07-21)

- `MacCursorCaptureOwner` is main-actor isolated and depends on injectable system operations. It records only cursor hiding and pointer disassociation that it successfully acquired, so repeated policy application and release cannot over-increment `NSCursor` hide state or restore association owned by another component.
- Relative acquisition calls pointer disassociation before hiding the cursor. If disassociation fails, the transition returns false with no hide or ownership change. During release, a failed association restore remains owned and retryable, while cursor visibility is restored immediately and exactly once.
- The macOS-only adapter uses real `NSCursor.hide()`, `NSCursor.unhide()`, and `CGAssociateMouseAndMouseCursorPosition`; the platform-neutral owner still compiles in every target. Focused warnings-as-errors tests pass `4/4`, and the complete macOS suite passes `419 total / 418 passed / 1 explicit Keychain skip / 0 failed`.
- Five isolated Debug warnings-as-errors app builds pass. Normalized simulator identity/state is byte-identical before and after; each fixed device is unique and `Shutdown`, with global `Booted=0`. Five OpenSpec changes validate strict, generator SHA-256 is stable at `f28937759af3c90b9f9ca70a429536266e795405b13e5ccf029cc80cc82613c9`, and whitespace/reference boundaries pass.
- This task does not attach the owner to the stream surface, lifecycle monitor, input coordinator cleanup, or a live session. `NSEvent` capture starts at tasks 4.2–4.3, attachment is task 4.4, and Sunshine/hardware evidence remains task 6.5 and stage 13 live work.

### Stage 14 task 4.2 keyboard capture and translation acceptance (2026-07-21)

- `MacStreamInputCaptureView` is a macOS-only flipped `NSView` that accepts first-responder status and overrides key-down, key-up, modifier changes, and forwarded key equivalents. AppKit callbacks synchronously emit repository-owned value samples; they do not create tasks or bypass the existing generation FIFO.
- Device-independent modifier flags map explicitly to repository modifiers. Per-key tracking balances left/right Shift, Control, Option, and Command when both sides overlap. Repeat is preserved only on key-down, and no manufactured key-up is added.
- Command-Q/Tab/H carry stable reservation classification across their key-up even after Command is released. Forwarding policy may consume a supported key equivalent; Escape is never forwardable, triggers one non-repeat capture-exit callback, and remains outside remote held-state ownership.
- The adapter now translates supported macOS virtual keys to reviewed Win32 VK values before constructing a remote event. ANSI/ISO, modifier, keypad, F1-F20, navigation, Help, and Context Menu mappings are explicit; unknown or semantically uncertain keys fail closed rather than serializing `NSEvent.keyCode`.
- Final focused warnings-as-errors tests pass `33/33`; the complete macOS suite passes `428 total / 427 passed / 1 explicit Keychain skip / 0 failed`. Five final isolated Debug app builds pass, normalized simulator state is unchanged with every fixed device unique and `Shutdown`, and global `Booted=0`.
- Five OpenSpec changes validate strict, generator SHA-256 is stable at `e1eac0d6538ff7f5ecff19a0d40ffa967a8d0c0d0cddb0fab281788c8f1fa9d2`, and whitespace/reference boundaries pass. Pointer capture remains task 4.3; actual surface/session attachment remains task 4.4/5.2; no live Sunshine receipt is claimed.
# 2026-07-21 阶段 14 任务 4.3 恢复复核

- OpenSpec要求事件来源严格限定于实际stream view；AppKit层只发repository-owned值样本，绝对坐标使用`convertToBacking`并在enqueue时与同一revision coordinate snapshot冻结。
- relative pointer/button/scroll不依赖absolute point；absolute button/scroll必须与movement共用`InputMapper`，fit黑边或无效drawable点应fail closed，不能把黑边点击clamp到远端画面。
- AppKit `scrollingDeltaX/Y`已经体现用户的自然滚动设置。当前采用Moonlight-qt macOS路径相同的precise每事件`[-1, 1]` clamp后乘Win32 `WHEEL_DELTA=120`，non-precise归一为单步`-120/0/+120`；这仍是确定性合同证据，不是物理滚轮方向手感证据。
- `buttonNumber`约定为0 left、1 right、2 middle、3 back、4 forward；其他按钮保持本地。view维护独立pressed-button集合以标注后续movement，但reset不伪造button-up，远端held-state释放继续由coordinator/provider ordered `releaseAll`负责。
- detached/stale view隔离不由4.3视图单独承担；4.4负责actual surface attachment/detach，既有generation-owned coordinator负责旧token/admission拒绝。
- 复核现有wire/runtime确认movement中的`PointerButtonSet`只用于兼容coalescing边界，当前gen5 movement codec不序列化该集合；remote held-pointer ownership只由显式button transition更新。因此letterbox down被drop后，后续movement不会隐式创建远端held button；无效位置up仍需发送以释放此前有效down。
- 4.3最终确定性验收通过：focused `46/46`，完整macOS `441 total / 440 passed / 1 explicit Keychain skip / 0 failed`，五平台Debug warnings-as-errors通过，simulator规范化状态前后逐字节一致，5个OpenSpec strict与generator byte-stability通过。
- 4.3只证明AppKit事件采集、值转换和adapter/coordinator确定性行为；capture view尚未附着到真实`MetalStreamSurface`，cursor/lifecycle尚未由该view拥有，真实Sunshine receipt、鼠标Y方向手感与多屏硬件映射仍未证明。

# 2026-07-21 阶段 14 任务 4.4 调查

- 当前`MetalStreamSurface`的macOS `NSViewType`是普通`MTKView`，4.2/4.3的`MacStreamInputCaptureView`未进入真实view hierarchy；因此不能从现有单测推断App真正捕获事件。
- 当前`AppKitLifecycleAttachment`位于`RootView`零尺寸background并长期观察整窗，`AppKitLifecycleMonitor.refreshDrawableSize()`也读取`window.contentView.bounds`；4.4应把window observation所有权移到actual Metal stream view，actual stream-view backing geometry本身按任务边界留给5.1。
- 为保证hit testing与first responder事件直接到capture owner，actual surface应让`MacStreamInputCaptureView`继承`MTKView`，而不是在父capture view内嵌一个会成为鼠标命中目标的子`MTKView`。
- representable coordinator需要显式attachment owner：同一view重复attach/detach幂等，stale view detach不能清理replacement；dismantle清window callback、transient input、Metal delegate并停止lifecycle observation。
- actual surface在5.2接入application sink前必须保持input admission disabled，避免无后端时吞掉本地键鼠；view仍可完整接线并通过注入式handler测试，后续5.2/5.3再打开active-generation eligibility。
- 提交前审阅发现不同SwiftUI coordinator可出现“replacement先attach、旧surface后dismantle”；若每个monitor直接清共享lifecycle，旧detach会短暂覆盖新surface状态。`PlatformLifecycleState`因此需要current attachment lease，只有当前attachment ID可以在detach时清visible/focus/drawable。

# 2026-07-21 阶段 14 任务 4.4 验收结论

- actual macOS stream surface现为`MacStreamInputCaptureView: MTKView`，鼠标hit testing、first responder事件和Metal presentation共享同一真实view；不再依赖整窗零尺寸background attachment。
- `MacStreamSurfaceAttachmentOwner`只响应当前view/window，重复attach/detach幂等，stale candidate无法拆除replacement；dismantle清window callback、transient key/button tracking、Metal delegate并暂停surface。
- 每个`AppKitLifecycleMonitor`持有独立attachment ID。replacement先claim后，旧monitor的迟到detach无法清除共享visible/focused/drawable状态；当前owner detach仍会闭合清零policy。
- actual surface的input admission保持默认关闭，因为5.2尚未把sample handler接入active `AppModel`/session input coordinator；因此4.4不吞本地键鼠，也不声称Sunshine已收到输入。
- `AppKitLifecycleMonitor.refreshDrawableSize()`仍读取`window.contentView.bounds`。actual stream-view backing pixels、screen/backing/live-resize原子几何属于5.1，不由4.4完成。
- 最终验收为focused `30/30`、完整macOS `446 total / 445 passed / 1 explicit Keychain skip / 0 failed`、五平台Debug warnings-as-errors通过；simulator状态前后逐字节一致，未创建、启动或关闭设备。5个OpenSpec strict、generator SHA-256 `8ba9f47017c9aca22655a7efdd638f7a01b05be995cd139cf36c50475e6211fd`、whitespace与production/reference边界通过。

# 2026-07-21 阶段 14 任务 4.5 调查

- `acceptsFirstResponder == true`只表示window可以接受该view，并不会让SwiftUI创建的Metal surface自动成为first responder。当前enabled `mouseDown`也不调用`super`，所以真实点击不能依赖AppKit隐式转移。
- responder ownership应受`isInputCaptureEnabled`约束：默认disabled surface不抢焦点；启用且附着时请求一次，点击时可恢复被overlay转走的responder；禁用时若仍由surface拥有则释放并清transient tracking。
- 4.5仍不应用cursor eligibility或active session wiring；它只验证4.1 cursor owner的transition矩阵，以及4.2-4.4 AppKit view/coordinator的event、responder、replacement与dismantle边界。真正的cursor/session组合属于5.2/5.3。

# 2026-07-21 阶段 14 任务 4.5 验收结论

- `MacStreamInputCaptureView`在enabled且已附着时幂等请求first responder，点击可从overlay/sibling恢复键盘ownership；disabled surface不请求，禁用只在自身持有时释放并清transient modifier/button/shortcut状态。
- `MacStreamSurfaceCoordinator.detach`现在先关闭view input admission，再拆attachment、清delegate并暂停surface；重复dismantle后旧view直接触发事件也不会进入handler。
- captured old `onWindowChange` closure在replacement后即使迟到调用，也因view identity fence被拒绝；coordinator update后的actual key event与capture-exit只进入最新closures。
- cursor owner新增relative-to-hide-only transition证明：先恢复pointer association但保持cursor hidden，最终release才执行一次unhide；不在4.5接入session eligibility。
- 验收通过focused `28/28`、完整macOS `451 total / 450 passed / 1 explicit Keychain skip / 0 failed`、五平台Debug warnings-as-errors；simulator前后逐字节一致。5个OpenSpec strict、generator SHA-256 `8ba9f47017c9aca22655a7efdd638f7a01b05be995cd139cf36c50475e6211fd`与边界门均通过。

# 2026-07-21 阶段 14 任务 5.1 调查

- `window.contentView.bounds * window.backingScaleFactor`只在stream surface恰好铺满content view且无独立bounds变换时近似正确；actual source必须是当前`MacStreamInputCaptureView.convertToBacking(bounds)`。
- window resize notifications不足以覆盖SwiftUI内部layout变化，因此actual surface需在frame/bounds size改变时主动通知attachment owner；screen/backing/live-resize与application screen-parameter通知仍由window monitor统一重新查询当前view。
- `MetalStreamSurface.apply`当前从`StreamRenderState.coordinateSnapshot`写回`MTKView.drawableSize`。5.2接线前该snapshot可能滞后，继续写回会覆盖5.1刚测得的实际像素尺寸；5.1应由view/backing geometry单向决定drawable，renderer只消费而不反向定义它。
- replacement可以发生在同一`NSWindow`内，因此monitor attach幂等键必须同时包含window identity与surface identity；只比较window会保留旧surface geometry source。

# 2026-07-21 阶段 14 任务 5.1 验收结论

- `AppKitLifecycleMonitor`现必须同时绑定current `NSWindow`与actual `NSView`；同一window内surface replacement也会移除旧observer/source并重新claim attachment。
- drawable严格来自`surface.convertToBacking(surface.bounds)`并做finite/positive/Int-range校验；结果同步写入`PlatformLifecycleState`与actual `MTKView.drawableSize`。window content size不再参与。
- `MacStreamInputCaptureView`在frame/bounds size变化时通知当前attachment owner；window resize/end-live-resize/screen/backing及application screen-parameter通知也重新查询当前view、screen name与三个EDR headroom值。
- `MetalStreamSurface.apply`不再把可能滞后的render coordinate snapshot写回drawable。5.1证明几何检测和surface配置，不证明5.2已把lifecycle geometry发布给AppModel coordinate snapshot或active media/input session。

# 2026-07-21 阶段 14 任务 5.2 调查

- `AppModel.applyPlatformLifecycle`当前只同步`renderState.policy/drawableSize/headroom`，尚未构造generation-scoped `SessionLifecycleApplication`；`NativeSessionMediaEnvironment`和`NativeSessionVideoProcessor`已经具备revision reservation、stale-generation拒绝、decoded submission暂停、presentation清理与IDR恢复语义，5.2必须消费这些接口而不是在SwiftUI或AppModel重写媒体并发状态机。
- `MacSessionInputCoordinator`已经提供bounded FIFO、enqueue-time coordinate snapshot、focus-loss release barrier和terminal generation隔离；AppModel现有`ApplicationInputSink`实现会内部派生活跃session/media generation，因此actual surface只能提交值样本，不得持有provider、session ID或generation。
- lifecycle通知可能先于media generation到达，也可能在actor await期间继续变化。AppModel需要一个单一、revision-aware pump缓存最新directive并串行补应用；stop/reconnect/replacement必须使旧pump失效，旧application即使迟到也不能失败或覆盖新generation。
- input coordinator应在media input readiness首次建立时激活，readiness丢失、stop、remote termination、reconnect/replacement或media failure时终止。初始focus eligibility必须从已缓存directive建立，避免`activate()`默认打开后再关闭产生短暂admission和无意义release barrier。
- 5.2只把actual surface sample handler接入AppModel；surface的`isInputCaptureEnabled`仍保持false，cursor policy与持久化输入设置的最终eligibility属于5.3，不能在本项提前开启真实AppKit事件吞入。
- 提交前复核发现`updateRenderPreferences()`会在session streaming或保存设置时用请求HDR的合成headroom覆盖actual display lifecycle值，且source geometry仍停留在用户请求分辨率。5.2改为active media generation持有negotiated decoded source size；platform lifecycle一旦接管，display headroom不再被设置加载/保存覆盖。
- lifecycle pump只能在environment明确返回`.staleLifecycleApplication`且缓存中确有更高revision时重试；当前generation的decoder/IDR或其他effect失败必须进入`failFromMediaEnvironment`，终止input generation、停止media/control并发布安全session failure，不能被较新window notification掩盖。

# 2026-07-21 阶段 14 任务 5.2 验收结论

- AppModel现拥有单一lifecycle pump：window state先同步更新renderer、coordinate snapshot、headroom与input focus，最新directive再按AppModel单调revision应用到内部派生的active media session/generation；media start会等待缓存application收敛，stop/replacement使旧pump失效。
- negotiated video size成为active decoded source geometry；actual surface drawable和display lifecycle headroom不会再被请求设置覆盖。presentation clear立即丢弃当前generation帧，native video processor继续负责pause/drain/IDR recovery的generation fence。
- media input readiness激活`MacSessionInputCoordinator`并直接继承当前focus eligibility；actual surface handler同步提交冻结的sample/snapshot/cursor/shortcut envelope。focus loss关闭admission并完成ordered release，input readiness loss、stop、remote termination、reconnect和media failure终止generation。
- 最终focused warnings-as-errors为`79/79`（`/tmp/LuneX-14-5_2-focused-final2.otpayx/IntegrationFocused.xcresult`）；完整macOS为`459 total / 458 passed / 1 explicit Keychain skip / 0 failed`（`/tmp/LuneX-14-5_2-full-final2.wc1urd/LuneXCoreTests.xcresult`）。唯一skip精确为一次性真实Keychain测试，命令显式移除环境变量。
- 最终五平台Debug warnings-as-errors build-only通过（`/tmp/LuneX-14-5_2-builds-final2.pe158p`）；simulator前后规范化identity/state逐字节一致，固定设备各唯一且`Shutdown`、全局`Booted=0`。本项仍不启用actual capture/cursor，5.3和6.5/live Sunshine边界保持未完成。

# 2026-07-21 阶段 14 任务 5.3 调查

- `preferRelativeMouseMode=false`不能等同于关闭input admission：direct模式仍需从actual surface接收键盘、绝对pointer、button和scroll，只是不隐藏cursor、不解除pointer association；relative模式才获取balanced cursor ownership。
- 真实admission必须同时要求当前session已streaming、media/input generation有效、input readiness存在、最新lifecycle允许input且coordinate snapshot有效。持久化`preferRelativeMouseMode`只决定relative/direct映射，`captureSystemShortcuts`独立决定可转发reserved shortcut。
- `MacCursorCaptureOwner`应由actual surface coordinator持有并在window attachment变化时应用；policy更新、focus/visibility loss、Escape、detach与dismantle都必须先关闭admission再恢复cursor。AppModel不直接持有`NSCursor`或`NSView`。

# 2026-07-21 阶段 14 任务 5.3 验收结论

- AppModel只在streaming session、匹配media generation、input readiness、active coordinator generation、lifecycle input-open和有效coordinate snapshot同时成立时发布`admitsInput=true`；任何一项丢失都先关闭surface admission，provider/generation仍由既有ordered teardown负责。
- direct模式保持actual surface admission并使用absolute mapping，不隐藏cursor也不改变pointer association；relative模式使用delta mapping并由共享`MacCursorCaptureBroker`平衡进程级cursor资源。新surface lease生效后，旧coordinator迟到dismantle不能恢复replacement cursor。
- `captureSystemShortcuts`同时应用到AppKit key-equivalent入口和enqueue-time envelope；Escape始终本地，仅在relative policy下立即释放cursor并把当前设置切换为direct，不会误禁用direct admission。
- 最终surface focused warnings-as-errors为`33/33`（`/tmp/LuneX-14-5_3-surface-final.PK4kyI/Surface.xcresult`）；完整macOS为`466 total / 465 passed / 1 explicit Keychain skip / 0 failed`（`/tmp/LuneX-14-5_3-full-final2.yUoJpc/LuneXCoreTests.xcresult`）。唯一skip仍为显式禁用的真实Keychain round-trip。
- macOS、固定iPhone/iPad/Apple TV/Apple Vision Pro Debug warnings-as-errors build-only全部通过（`/tmp/LuneX-14-5_3-builds-final2.6keHqh`）；simulator规范化状态前后逐字节一致，固定实例唯一且全部`Shutdown`、全局`Booted=0`。5个OpenSpec strict、generator三次SHA-256 `8ba9f47017c9aca22655a7efdd638f7a01b05be995cd139cf36c50475e6211fd`、diff与production/reference边界通过。

# 2026-07-21 阶段 14 任务 5.4 调查

- `DiagnosticsStore.latestActionableEvent`当前从完整历史反查最后一个warning/error/action，因此session恢复或停止后仍可能把已恢复故障重新显示为当前stream overlay；历史审计事件不能为解决展示问题而删除。
- 5.4采用独立的当前action presentation状态，并按诊断类别/恢复边界清理。input readiness恢复或lifecycle重新开放只允许清理对应的可恢复input/lifecycle action，不能误清仍有效的decoder/audio/transport fatal action。
- lifecycle/input公开诊断只使用固定code和粗粒度状态，不记录session/generation UUID、主机endpoint/display name、坐标、raw key code、characters或controller identity；相同语义状态去重，resize/revision本身不产生事件。
- local stop、remote disconnected和新session开始应清理当前stream action presentation但保留`events`历史；streaming/input recovery则只清理已经明确恢复的scope。

# 2026-07-21 阶段 14 任务 5.4 验收结论

- `DiagnosticsStore`现以按类别current-action索引驱动恢复提示，同时继续保留bounded `events`审计历史；stream overlay只读取transport/decoder/audio/input当前action，不再回放旧pairing或已恢复错误，pairing重试/成功也会清理旧pairing action。
- macOS lifecycle/input状态只发布固定、无参数code与安全摘要，相同语义状态去重。provider send/release失败设置独立generation-failed gate立即关闭actual surface admission，但保留token供readiness loss、stop或replacement完成ordered teardown；新input generation建立后才清input action。
- input recovery不会清decoder/audio fatal，focus或occlusion变化也不会清未恢复action；新session、streaming transport recovery、local stop和remote disconnect按明确scope清current presentation，历史事件不删除。
- 最终focused为`49/49`（`/tmp/LuneX-14-5_4-focused-final2.M5GVv9/Diagnostics.xcresult`）；完整macOS为`469 total / 468 passed / 1 explicit Keychain skip / 0 failed`（`/tmp/LuneX-14-5_4-full-final2.4322ka/LuneXCoreTests.xcresult`），测试显式移除真实Keychain开关。
- 五平台Debug warnings-as-errors build-only通过（`/tmp/LuneX-14-5_4-builds-final2.Uw3Ahq`）；simulator前后规范化状态逐字节一致，固定实例唯一且全部`Shutdown`、全局`Booted=0`。OpenSpec strict `5/5`、generator三次及生成前SHA-256均为`8ba9f47017c9aca22655a7efdd638f7a01b05be995cd139cf36c50475e6211fd`、whitespace与production/reference边界通过，最终仓库门禁`/tmp/LuneX-14-5_4-repo-gates-final2.18qgSJ`。

# 2026-07-21 阶段 14 任务 5.5 调查

- 5.2至5.4已有分散的AppModel测试分别覆盖lifecycle application、fake input、focus release、geometry和stop，但尚无一个测试在同一session/generation内证明这些边界按真实application顺序组合后仍收敛。
- 5.5优先复用`ControlledSessionControlProvider`和`ControlledSessionMediaEnvironment`，检查environment记录的generation-scoped lifecycle/input/release application、presentation source、coordinate mapping与最终snapshot；不新增production fake接口。

# 2026-07-21 阶段 14 任务 5.5 验收结论

- 新增单一AppModel集成门，在同一session/media/input generation中依次证明keyboard fake-provider delivery、focus-loss admission closure与一次release barrier、occlusion时drain-without-decode/clear、visible resume、16:9内容在4:3 drawable中的共享fit映射，以及local stop后的provider/environment/input资源清理。
- fake media environment按设计不启动`NativeSessionVideoProcessor`，因此测试显式注入同一个presentation source并播入受控decoder generation，只验证AppModel在occlusion时失效旧generation、resume后接受新generation、stop时清理source；这不声称fake environment或Sunshine生成了真实视频帧。
- 最终单项复跑`1/1`（`/tmp/LuneX-14-5_5-single-r2.moqTup/Integration-final-1784637488.xcresult`），最终扩大focused为`92/92`（`/tmp/LuneX-14-5_5-focused-final.4mEnnV/Focused.xcresult`），完整macOS为`470 total / 469 passed / 1 explicit Keychain skip / 0 failed`（`/tmp/LuneX-14-5_5-full.G8yfCE/LuneXCoreTests.xcresult`）。
- 五平台Debug warnings-as-errors build-only通过（`/tmp/LuneX-14-5_5-builds.aZ3I4a`）；simulator前后规范化identity/state逐字节一致，固定实例唯一、可用且全部`Shutdown`，全局`Booted=0`。OpenSpec strict `5/5`、generator生成前和三次生成SHA-256一致、diff/reference/ThirdParty边界通过，最终repository gates记录于`/tmp/LuneX-14-5_5-repo-gates.lB9GkQ`。

# 2026-07-21 阶段 14 任务 6.1 调查

- 当前测试树唯一显式opt-in环境开关是`LUNEX_RUN_KEYCHAIN_TEST`；normal suite将显式移除该变量，预期唯一skip为一次性真实Keychain round-trip。
- 测试树尚无live-host XCTest环境开关或test case，因为阶段13的OpenSpec 9.2仍未实现；6.1只证明normal suite没有host/Keychain副作用，不能把缺失的live-host测试描述为disabled pass。

# 2026-07-21 阶段 14 任务 6.1 验收结论

- 从5.5已提交基线和全新DerivedData执行normal macOS suite，命令显式移除`LUNEX_RUN_KEYCHAIN_TEST`；结构化结果为`470 total / 469 passed / 1 skipped / 0 failed`（`/tmp/LuneX-14-6_1-normal.8p8JY5/Normal.xcresult`）。
- 唯一skip精确为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`；测试树唯一opt-in环境读取也是该Keychain开关，没有live-host XCTest或相应环境开关。
- 因此6.1证明normal suite未访问真实Keychain且没有隐藏的live-host side effect；它不证明授权Sunshine互操作，阶段13 9.2仍是尚未实现而非skipped pass。
- OpenSpec strict `5/5`、进度`24/29`、generator三次稳定、project/whitespace/reference边界通过，最终repository gates位于`/tmp/LuneX-14-6_1-repo-gates.EkT8SN`。

# 2026-07-21 阶段 14 任务 6.2 调查

- 固定构建矩阵为macOS `platform=macOS,arch=arm64`，iPhone `23A27088-C19F-4F77-A455-4E50E393167E`，iPad `409A5908-8C39-4797-A41C-04503A05FA3D`，Apple TV `11D0B224-D778-4A13-A156-272A45AFF119`，Apple Vision Pro `9BF41D0C-B423-4B3F-B75D-00B31E85FE18`；移动/TV/vision构建只引用既有固定UUID，不显式启动设备。
- 每个平台分别执行Debug和Release，设置Swift/Clang warnings-as-errors且使用独立DerivedData。构建前后规范化simulator identity/state必须逐字节一致，固定UUID必须各自唯一、可用、`Shutdown`且全局`Booted=0`。
- Xcode 26.4的App Intents metadata extractor即使收到官方`LM_FILTER_WARNINGS=YES`产生的`--quiet-warnings`，仍会对未链接AppIntents的正常项目输出skip warning；这不是Swift/Clang warning，但最终自验不把它忽略。SwiftBuild平台插件还公开`LM_SKIP_METADATA_EXTRACTION`，适合本项目明确不使用AppIntents的构建门，需先验证其确实移除该rule且不影响产物构建。

# 2026-07-21 阶段 14 任务 6.2 验收结论

- 单点验证证明`LM_SKIP_METADATA_EXTRACTION=YES`会从未使用AppIntents的LuneX构建图中移除`ExtractAppIntentsMetadata`，同时保留完整app构建；验证位于`/tmp/LuneX-14-6_2-appintents-probe.fyVIfl`。
- 最终十构建矩阵全部`BUILD SUCCEEDED`：macOS、固定iPhone、iPad、tvOS与visionOS各自Debug/Release，全部使用隔离DerivedData、Swift/Clang warnings-as-errors、禁用签名并显式移除真实Keychain开关。10个日志零`warning:`/`error:`，证据根目录`/tmp/LuneX-14-6_2-builds-final2.IXQDK5`。
- 构建前后规范化simulator快照SHA-256均为`b6b4a5f0e17cb704abfa9cfe669beeebe176286fa52e096b33563bc1ba356db8`；固定4个UUID唯一、可用、全部`Shutdown`，全局`Booted=0`，未create、boot、run或shutdown设备。

# 2026-07-21 阶段 14 任务 6.3 调查

- 阶段13任务9.6已建立可复用的analyzer/ASan/TSan/malloc门，但当时完整suite为366项；阶段14新增104项macOS lifecycle/input/geometry测试后必须从当前提交重新执行，不能复用旧pass计数。
- clean-room/dependency门需同时证明：协议fixture self-test和全树脱敏通过；`references/`不被Git或production project引用；无Swift package依赖；固定MIT ENet revision/license/source边界未漂移；generator运行前和三次运行后`project.pbxproj`逐字节一致。
- resource选择集在原SessionResourceTracker、NetworkChannel、video/audio、media environment、cancellation/recovery、remote input之外，加入MacSessionInputCoordinator、LifecycleRenderPolicy、MacCursorCaptureOwner和MacStreamInputCaptureView，覆盖本阶段新增的event consumer、release barrier、cursor lease、observer和surface teardown所有权。

# 2026-07-21 阶段 14 任务 6.3 验收结论

- repository gates位于`/tmp/LuneX-14-6_3-repo.vQa7C6`：五个OpenSpec strict、fixture validator self-test/全树、generator生成前和三次运行SHA-256 `8ba9f47017c9aca22655a7efdd638f7a01b05be995cd139cf36c50475e6211fd`、project无漂移、无Swift package、production/reference边界、固定ENet revision/license/source逐字节边界全部通过。
- macOS Debug/Release analyzer均成功；结构化plist证明自有`LuneXENetBridge`为零finding，固定ENet在两配置各稳定4项：`compress.c:320`、`unix.c:521`、`unix.c:526`三个dead store和`unix.c:867`潜在null dereference，没有新增或漂移（`/tmp/LuneX-14-6_3-static.VoMRXW`）。
- 完整ASan/LeakSanitizer与TSan分别通过`470 total / 469 passed / 1 explicit Keychain skip / 0 failed`，均无sanitizer报告；结果为`/tmp/LuneX-14-6_3-asan.ONJxta/ASan.xcresult`和`/tmp/LuneX-14-6_3-tsan.5A9CnG/TSan.xcresult`。
- 开启MallocScribble、GuardEdges、StackLogging、周期heap check和error-abort的17类resource/teardown选择集通过`250/250`且零malloc诊断（`/tmp/LuneX-14-6_3-resource.fHJF25/ResourceOwnership.xcresult`）。这证明离线测试所有权收敛，不证明真实host/hardware长期资源行为。
- 旧`AppKitLifecycleAttachment`与`WindowObservationView`已删除，因为production ownership已在actual Metal surface，保留两套attachment会重新引入整窗与surface竞态。
- 最终验收通过focused `38/38`、完整macOS `455 total / 454 passed / 1 explicit Keychain skip / 0 failed`、五平台Debug warnings-as-errors；simulator前后逐字节一致。5个OpenSpec strict、generator SHA-256 `8ba9f47017c9aca22655a7efdd638f7a01b05be995cd139cf36c50475e6211fd`和边界门通过。
