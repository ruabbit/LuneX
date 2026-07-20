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
