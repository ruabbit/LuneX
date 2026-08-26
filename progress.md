# LuneX 进度日志

## 2026-06-09

- 创建项目跟踪文件：`task_plan.md`、`findings.md`、`progress.md`。
- 确认当前工作目录 `/Users/tanmy/Projects/LuneX` 初始为空。
- 读取 `planning-with-files-zh` 技能说明，确认需要持续维护三个规划文件。
- 记忆命中 OpenSpec 本机安装历史与计划文件同步偏好；当前项目仍以本地检查为准。
- 浅克隆 `moonlight-stream/moonlight-ios` 到 `references/moonlight-ios`，浅克隆 `moonlight-stream/moonlight-qt` 到 `references/moonlight-qt`，用于只读架构参考。
- 检查本机环境：Xcode 26.4、Swift 6.3、OpenSpec 1.3.1、iOS 26.4 iPhone/iPad 模拟器可用。
- 通过 Apple 官方文档确认 macOS 窗口遮挡、屏幕变化、EDR、iOS EDR、空间音频头部跟踪、后台模式/PiP 和 SwiftUI 窗口 API 的第一轮可行性。
- 更新 `findings.md`，记录第一轮调查结论与许可/架构风险。
- 运行 `openspec init --tools codex --force .`，生成 `openspec/config.yaml` 和 `.codex/skills/` OpenSpec 指令。
- 创建 OpenSpec change `bootstrap-native-apple-client`。
- 写入 `proposal.md`、`design.md`、7 个 capability spec delta 和 `tasks.md`，共 38 个实现任务。
- 运行 `openspec validate bootstrap-native-apple-client --strict --json`，结果为 1/1 passed、0 issues。
- 更新 `task_plan.md`：阶段 0、2、3 complete；阶段 1 in_progress。
- 进行 Xcode 26.4 SDK API typecheck；发现 `AVAudioEnvironmentNode.listenerHeadTrackingEnabled` 在 Swift 中应使用 `isListenerHeadTrackingEnabled`，且 visionOS 不可用。已记录为平台 gating 要求。
- 重跑修正后的 SDK typecheck：macOS、iOS simulator、tvOS simulator、visionOS simulator 均通过；visionOS 只验证通用窗口/控制器能力，不验证不可用的 head tracking 属性。
- 完成 OpenSpec 任务 1.1、1.2、1.3、1.4，并在 `tasks.md` 勾选。
- 添加 SwiftUI 多平台脚手架源码、`Tools/generate_xcodeproj.rb` 和 `Resources/Assets.xcassets`。
- 生成 `LuneX.xcodeproj`，`xcodebuild -list` 可识别 `LuneX-macOS`、`LuneX-iOS`、`LuneX-tvOS`、`LuneX-visionOS` 四个 schemes。
- 首次 macOS build 失败，原因是 project 生成器让 Xcode 查找 `Sources/Sources/...` 和 `Resources/Resources/...`；已修正生成器 group path。
- macOS Debug build 已通过。
- 首次 iOS simulator build 失败，原因是 `DisplayHeadroomReader.read(screen: UIScreen = .main)` 在 Swift 6 中把 main actor-isolated 默认值用于非隔离上下文；已改为显式 `@MainActor read(screen:)`。
- 用户补充要求使用 Git，远程仓库为 `git@github.com:ruabbit/LuneX.git`，并要求缺失 simulator runtime 可以安装，不视为限制。
- 创建线程目标执行：分析 Moonlight 并构建 LuneX 原生 SwiftUI Apple 全平台客户端。
- 初始化 Git 仓库并设置 `origin git@github.com:ruabbit/LuneX.git`。
- 创建 `.gitignore`，排除 `references/`、DerivedData/build、Xcode 用户状态和 result bundles。
- 将 Git 默认分支改为 `main`。
- iPhone 17 Pro simulator 和 iPad Pro 13-inch (M5) simulator 均已 boot，仅各启动一个实例。
- iOS simulator build 通过，iPadOS simulator build 通过。
- iOS app 安装并启动到 iPhone simulator，bundle id `dev.lunex.client.ios`，进程号 70033。
- iOS/iPadOS app 安装并启动到 iPad simulator，bundle id `dev.lunex.client.ios`，进程号 70032。
- 截图验证非黑屏：`artifacts/iphone-lunex.png`、`artifacts/ipad-lunex.png`。`artifacts/` 已加入 `.gitignore`，作为本地验证产物。
- tvOS 26.4 simulator runtime 下载已启动，大小约 3.76 GB。
- visionOS 26.4 simulator runtime 下载已启动，大小约 7.31 GB。
- OpenSpec 任务更新：2.1-2.4、3.1-3.3、4.1-4.4、9.1-9.4 已完成。
- 新增 `LifecycleRenderPolicyResolver` 和 `LuneXCoreTests`，完成生命周期到渲染策略单测；首次测试 target 漏编 `DisplayHeadroom.swift`，已修正。
- 新增主机模型、能力模型、pinned identity metadata、App settings、client identity store、JSON 文件 repository 和 Keychain identity store。
- `xcodebuild -project LuneX.xcodeproj -scheme LuneXCoreTests -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test` 通过，8 个测试通过。
- `openspec validate bootstrap-native-apple-client --strict --json` 再次通过，1/1 passed、0 issues。
- macOS Debug build 重新通过，并修正 AppKit notification callback 的 Swift 6 main actor warning。
- 固定 iPhone 17 Pro simulator build 和固定 iPad Pro 13-inch (M5) simulator build 重新通过，未创建或启动额外同类模拟器。
- tvOS 26.4 simulator runtime 已安装；`LuneX-tvOS` simulator build 首次发现 `CAMetalLayer.wantsExtendedDynamicRangeContent` 在 tvOS unavailable，第二次发现 `Scene.defaultSize` 在 tvOS unavailable，均已按平台 gating 修正；第三次 tvOS simulator build 通过，未启动 tvOS 模拟器。
- visionOS 26.4 simulator runtime 下载进程仍在运行，尚未出现在 `simctl list runtimes`。
- OpenSpec 任务更新：3.4、5.1、9.5 已完成。
- 会话恢复脚本提示上一轮有 42 条未同步上下文；已重新读取 `task_plan.md`、`findings.md`、`progress.md`、OpenSpec tasks 和当前源码，并以本轮验证结果为准继续。
- 修复 Swift 6 actor isolation 构建错误：`AppModel` 增加 `@MainActor`，解决 SwiftUI `.task`/sheet Task 调用 `loadHosts()` 和 `addManualHost(...)` 时的 non-Sendable crossing 诊断。
- `openspec validate bootstrap-native-apple-client --strict --json` 通过，1/1 passed、0 issues。
- `xcodebuild -project LuneX.xcodeproj -scheme LuneXCoreTests -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test` 通过，11 个测试通过。
- macOS Debug build 通过。
- 固定 iPhone 17 Pro simulator `23A27088-C19F-4F77-A455-4E50E393167E` Debug build 通过。
- 固定 iPad Pro 13-inch (M5) simulator `409A5908-8C39-4797-A41C-04503A05FA3D` Debug build 通过。
- 固定 tvOS simulator destination `11D0B224-D778-4A13-A156-272A45AFF119` Debug build 通过，未启动额外 tvOS 模拟器。
- visionOS 26.4 runtime 下载进程仍在运行；`xcodebuild -showdestinations` 显示 `visionOS 26.4 is not installed`，visionOS 构建等待 runtime 安装完成。
- OpenSpec 任务更新：5.2 已完成。任务进度更新为 23/38。
- 新增 `Sources/LuneXNetworking/Pairing.swift`：配对阶段 actor、SHA1/SHA256 digest 选择、结构化 `PairingFailure`、PIN 校验、server identity pinning 到 `MoonlightHost`。
- 新增 `Tests/LuneXCoreTests/PairingStateMachineTests.swift`，覆盖 server major version digest 选择、非法 PIN、非法阶段和成功 paired host/pinned identity。
- 更新 `Tools/generate_xcodeproj.rb`，重新生成 `LuneX.xcodeproj/project.pbxproj`，把 pairing 源码加入 app/test targets。
- `xcodebuild -project LuneX.xcodeproj -scheme LuneXCoreTests -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test` 再次通过，15 个测试通过。
- 新增 pairing 源码后，macOS、固定 iPhone 17 Pro、固定 iPad Pro 13-inch (M5)、固定 tvOS simulator destination Debug build 均再次通过。
- visionOS 26.4 runtime 下载进程仍在运行，`showdestinations` 仍显示 `visionOS 26.4 is not installed`。
- OpenSpec 任务更新：5.3 已完成。任务进度更新为 24/38。
- 创建 Git 初始提交 `51e5e8c Initial native SwiftUI Apple client scaffold`，包含 50 个项目/源码/测试/OpenSpec/规划文件；`references/` 与 `artifacts/` 仍为 ignored。
- 远端为 `git@github.com:ruabbit/LuneX.git`；直接 `git push -u origin main` 失败，错误为 `Connection closed by 20.205.243.166 port 22`。随后 `ssh -T git@github.com` 与 `git ls-remote origin` 均复现同一 SSH 22 端口连接关闭问题。`ssh -T -p 443 git@ssh.github.com` 成功认证为 `ruabbit`；最终用 `GIT_SSH_COMMAND='ssh -p 443 -o HostName=ssh.github.com' git push -u origin main` 推送成功。
- visionOS 26.4 runtime 安装完成，`xcrun simctl list runtimes` 出现 `visionOS 26.4 (26.4 - 23O243)`。
- `xcodebuild -project LuneX.xcodeproj -scheme LuneX-visionOS -configuration Debug -destination 'platform=visionOS Simulator,id=9BF41D0C-B423-4B3F-B75D-00B31E85FE18' CODE_SIGNING_ALLOWED=NO build` 通过，未创建或启动额外 visionOS simulator。
- 会话恢复脚本提示上一轮有 63 条未同步上下文；已重新读取 `task_plan.md`、`findings.md`、`progress.md`、OpenSpec tasks、新增 tests/source 和 git status，以当前验证结果为准继续。
- 新增 `Sources/LuneXNetworking/AppCatalog.swift`：app-list XML parser、HTTPS app list/artwork client、in-memory artwork cache、`AppCatalogManager` actor。
- 新增 `Tests/LuneXCoreTests/AppCatalogTests.swift`：覆盖 app list XML 解析、非 OK 状态拒绝、artwork cache 命中、host-scoped artwork cache。
- 新增 `Sources/LuneXNetworking/StreamNegotiation.swift`：stream launch request/parameters、HTTP `/launch` 和 `/cancel` client、launch response parser、`StreamSessionCoordinator` actor。
- 新增 `Tests/LuneXCoreTests/StreamNegotiationTests.swift`：覆盖 launch 参数、未配对 host 拒绝、launch response 解析、coordinator ready/streaming/disconnected 状态转换。
- 修复 Swift 6 XCTest actor isolation：测试不再在 `XCTAssertEqual` autoclosure 中直接 `await` actor-isolated properties，而是通过 stub actor 方法读取计数到局部变量后断言。
- 更新 `Tools/generate_xcodeproj.rb` 并重新生成 `LuneX.xcodeproj/project.pbxproj`，把 app catalog 和 stream negotiation 源码/测试纳入对应 targets。
- `xcodebuild -project LuneX.xcodeproj -scheme LuneXCoreTests -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test` 通过，23 个测试通过。
- macOS Debug build 通过。
- 固定 iPhone 17 Pro simulator `23A27088-C19F-4F77-A455-4E50E393167E` Debug build 通过。
- 固定 iPad Pro 13-inch (M5) simulator `409A5908-8C39-4797-A41C-04503A05FA3D` Debug build 通过。
- 固定 tvOS simulator destination `11D0B224-D778-4A13-A156-272A45AFF119` Debug build 通过，未启动额外 tvOS 模拟器。
- 固定 Apple Vision Pro visionOS simulator destination `9BF41D0C-B423-4B3F-B75D-00B31E85FE18` Debug build 通过，未启动额外 visionOS 模拟器。
- `openspec validate bootstrap-native-apple-client --strict --json` 通过，1/1 passed、0 issues。
- OpenSpec 任务更新：5.4、5.5 已完成。任务进度更新为 26/38。
- 新增 `Sources/LuneXInput/InputEvents.swift`：统一 keyboard、pointer、touch、virtual controller remote input event 模型，以及 deliver/drop/reserve-local delivery policy。
- 新增 `Sources/LuneXInput/MacInputAdapter.swift`：macOS cursor capture policy resolver、keyboard adapter、pointer move/button/scroll adapter；默认保留 Command-Q、Command-Tab、Command-H 给本机系统。
- 新增 `Sources/LuneXInput/TouchInputAdapter.swift`：iOS/iPadOS touch、pointer hover、virtual controller event model，坐标统一经 `InputMapper` 映射。
- 更新 `Sources/LuneXInput/InputMapper.swift` 和 `Sources/LuneXPlatform/PlatformLifecycle.swift`，让 `InputMapper`、`RemotePoint`、`RenderTransform` 显式 `Sendable`，适配后续 session actor 边界。
- 新增 `Tests/LuneXCoreTests/InputAdapterTests.swift`：覆盖 focused/visible/active cursor capture、macOS 相对/绝对 pointer、Command-Tab 本地保留、touch 坐标映射、virtual controller value clamp。
- 更新 `Tools/generate_xcodeproj.rb` 并重新生成 `LuneX.xcodeproj/project.pbxproj`，把输入源码和测试纳入 app/test targets。
- `xcodebuild -project LuneX.xcodeproj -scheme LuneXCoreTests -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test` 通过，29 个测试通过。
- macOS、固定 iPhone 17 Pro simulator、固定 iPad Pro 13-inch (M5) simulator、固定 tvOS simulator destination、固定 Apple Vision Pro visionOS simulator destination Debug build 均通过，未创建或启动额外模拟器。
- `openspec validate bootstrap-native-apple-client --strict --json` 通过，1/1 passed、0 issues。
- OpenSpec 任务更新：6.1、6.2 已完成。任务进度更新为 28/38。
- 进行 GameController SDK typecheck；`GCController.didConnectNotification`/`didDisconnectNotification` 不存在，改用 `Notification.Name.GCControllerDidConnect` 和 `Notification.Name.GCControllerDidDisconnect`。修正后 iOS、tvOS、visionOS typecheck 均通过。
- 新增 `Sources/LuneXInput/GameControllerInputAdapter.swift`：controller connection snapshot、remote controller bitmap、controller element event mapping、GameController platform monitor。
- 新增 `Sources/LuneXInput/TVRemoteFocusInputAdapter.swift`：tvOS remote button、press type mapper 和 focus event model；串流未活动时 remote 输入保留本机。
- 新增 `Sources/LuneXInput/InputDiagnostics.swift`：reserved/dropped/unsupported input 诊断记录，以及 controller snapshot diagnostic。
- 更新 `Sources/LuneXInput/InputEvents.swift`，加入 physical game controller、tvOS remote 和 focus input event。
- 更新 `Sources/LuneXDiagnostics/DiagnosticsStore.swift`，支持接收 `InputDiagnosticRecord`。
- 新增 `Tests/LuneXCoreTests/ControllerAndDiagnosticsTests.swift`：覆盖 controller button/axis mapping、remote controller bitmap、tvOS remote/focus policy、input diagnostics severity/subsystem/controller status。
- 更新 `Tools/generate_xcodeproj.rb` 并重新生成 `LuneX.xcodeproj/project.pbxproj`，把 GameController/tvOS remote/diagnostics 源码与测试纳入 targets。
- `xcodebuild -project LuneX.xcodeproj -scheme LuneXCoreTests -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test` 通过，35 个测试通过。
- macOS、固定 iPhone 17 Pro simulator `23A27088-C19F-4F77-A455-4E50E393167E`、固定 iPad Pro 13-inch (M5) simulator `409A5908-8C39-4797-A41C-04503A05FA3D`、固定 tvOS simulator destination `11D0B224-D778-4A13-A156-272A45AFF119`、固定 Apple Vision Pro visionOS simulator destination `9BF41D0C-B423-4B3F-B75D-00B31E85FE18` Debug build 均通过，未创建或启动额外模拟器。
- `openspec validate bootstrap-native-apple-client --strict --json` 通过，1/1 passed、0 issues。
- OpenSpec 任务更新：6.3、6.4 已完成。任务进度更新为 30/38。
- 进行 AVFAudio SDK typecheck；`AVAudioEngine` 在 macOS/iOS/tvOS/visionOS 通过，`AVAudioSession.sharedInstance().sampleRate`、`outputNumberOfChannels`、`currentRoute.outputs`、`ioBufferDuration` 在 iOS/tvOS/visionOS 通过。
- 新增 `Sources/LuneXAudio/AudioSessionPipeline.swift`：stream audio configuration、latency policy、pipeline stage、stop reason、route snapshot、`AudioEngineClient` protocol、`AVAudioEngineClient`、`AudioRouteInspector` 和 `AudioSessionPipeline` actor。
- 更新 `Sources/LuneXDiagnostics/DiagnosticsStore.swift`，支持记录 `AudioPipelineSnapshot` 到 diagnostics event。
- 新增 `Tests/LuneXCoreTests/AudioPipelineTests.swift`：覆盖 configure/start/stop route snapshot、missing configuration failure、audio snapshot diagnostics。
- 更新 `Tools/generate_xcodeproj.rb` 并重新生成 `LuneX.xcodeproj/project.pbxproj`，把 audio pipeline 源码和测试纳入 targets。
- `xcodebuild -project LuneX.xcodeproj -scheme LuneXCoreTests -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test` 通过，38 个测试通过。
- macOS、固定 iPhone 17 Pro simulator、固定 iPad Pro 13-inch (M5) simulator、固定 tvOS simulator destination、固定 Apple Vision Pro visionOS simulator destination Debug build 均通过，未创建或启动额外模拟器。
- `openspec validate bootstrap-native-apple-client --strict --json` 通过，1/1 passed、0 issues。
- OpenSpec 任务更新：7.1 已完成。任务进度更新为 31/38。
- 更新 `Sources/LuneXAudio/AudioRouteState.swift`：新增 `SpatialAudioCapabilityContext`、`SpatialAudioPlatform`、`SpatialAudioAvailabilityResolver`，按 platform SDK、route spatial support、head-pose entitlement、channel count 和用户设置计算 spatial/head tracking 可用性。
- 更新 `Sources/LuneXDiagnostics/DiagnosticsStore.swift`，支持记录 `AudioRouteState` 的空间音频可用性和 unavailable reason。
- 新增 `Sources/LuneXPlatform/ContinuityPolicy.swift`：mobile background/PiP continuity policy、PiP render size coordinator、macOS visibility-based background performance policy。
- 更新 `Sources/LuneXCore/AppSettings.swift`，把 `ContinuityPreferences.defaults` 纳入持久化设置模型。
- 更新 `Tools/generate_xcodeproj.rb`，把 `ContinuityPolicy.swift` 和 `ContinuityPolicyTests.swift` 纳入 targets，并为 visionOS target 生成 `INFOPLIST_KEY_UIBackgroundModes=audio`。
- 新增 `Tests/LuneXCoreTests/ContinuityPolicyTests.swift`：覆盖 spatial audio entitlement/channel/platform gating、spatial diagnostics、mobile audio+PiP/background fallback、PiP size update、macOS inactive visible throttle 和 occluded pause。
- 首次新增 continuity tests 后，`LuneXCoreTests` 构建失败，原因是测试支持源码漏纳入 `AudioRouteState.swift`；已修正生成器并重新生成 project。
- `xcodebuild -project LuneX.xcodeproj -scheme LuneXCoreTests -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test` 通过，46 个测试通过。
- macOS、固定 iPhone 17 Pro simulator、固定 iPad Pro 13-inch (M5) simulator、固定 tvOS simulator destination、固定 Apple Vision Pro visionOS simulator destination Debug build 均通过，未创建或启动额外模拟器；visionOS target 带 `UIBackgroundModes=audio` 仍构建通过。
- `openspec validate bootstrap-native-apple-client --strict --json` 通过，1/1 passed、0 issues。
- OpenSpec 任务更新：7.2、7.3、7.4 已完成。任务进度更新为 34/38。

## 2026-06-17

- 重新创建线程目标：继续完成 LuneX 原生 SwiftUI Moonlight Apple 全平台客户端剩余 OpenSpec 工作，优先完成 macOS 与 iOS/iPadOS 功能完备 UI、验证、提交并推送。
- 读取 `planning-with-files-zh` 与 `openspec-apply-change` 技能说明，恢复 `task_plan.md`、`findings.md`、`progress.md` 和 OpenSpec apply 状态。
- `openspec instructions apply --change bootstrap-native-apple-client --json` 显示剩余任务为 8.1、8.2、8.3、8.4，进度 34/38。
- 扩展 `Sources/LuneXCore/AppModel.swift`：新增 navigation selection、selected host/app、pairing UI state、catalog UI state、stream launch state；接入 host add/remove/replace、settings load/save、app refresh、pairing skeleton、stream launch/stop 和 diagnostics。
- 扩展 `Sources/LuneXNetworking/HostDiscovery.swift`：`HostLibraryManager` 新增 `replaceHost(_:)` 与 `removeHost(id:)`，供 pairing UI 和 host library 删除流程使用。
- 重写 `Sources/LuneXApp/RootView.swift`：实现 NavigationSplitView shell、host library、pairing panel、app catalog grid、stream launch panel、Metal stream workspace、stream status overlay、virtual controller overlay、diagnostics screen、settings screen。
- 首轮 iOS/tvOS build 发现 SwiftUI API 差异：`List(selection:)` 在 iOS/tvOS unavailable，tvOS 不支持 `TextFieldStyle.roundedBorder` 与 `Stepper`；已按平台分支修正。
- 首轮并发 simulator build 出现 DerivedData build database lock；后续改为按固定 simulator ID 串行验证。
- 新增 `Tests/LuneXCoreTests/AppModelWorkflowTests.swift`，覆盖 UI-facing workflow：manual host add、pairing skeleton、app catalog refresh、launch stream、stop stream。
- 更新 `Tools/generate_xcodeproj.rb` 并重新生成 `LuneX.xcodeproj/project.pbxproj`，把 AppModel 测试支持源码和新 workflow test 纳入测试 target。
- 修复 `AppModelWorkflowTests` 暴露的 app 顺序不稳定问题：`AppCatalogManager.refreshApps` 统一按 app name 排序。
- `xcodebuild -project LuneX.xcodeproj -scheme LuneXCoreTests -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test` 通过，47 个测试通过。
- `openspec validate bootstrap-native-apple-client --strict --json` 通过，1/1 passed、0 issues。
- `xcodebuild -project LuneX.xcodeproj -scheme LuneX-macOS -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build -quiet` 通过。
- 固定 iPhone 17 Pro simulator `23A27088-C19F-4F77-A455-4E50E393167E` Debug build 通过。
- 固定 iPad Pro 13-inch (M5) simulator `409A5908-8C39-4797-A41C-04503A05FA3D` Debug build 通过。
- 固定 tvOS simulator destination `11D0B224-D778-4A13-A156-272A45AFF119` Debug build 通过。
- 固定 Apple Vision Pro visionOS simulator destination `9BF41D0C-B423-4B3F-B75D-00B31E85FE18` Debug build 通过。
- OpenSpec 任务更新：8.1、8.2、8.3、8.4 已完成。任务进度更新为 38/38。
- 追加阶段 10：从本机 Moonlight-qt 偏好导入真实 paired host/app cache 作为 LuneX 本地测试数据。
- 创建 `Tools/import_moonlight_qt_data.py`，用 `plistlib` 读取 `~/Library/Preferences/com.moonlight-stream.Moonlight.plist`，输出到 `~/Library/Application Support/LuneX`；脚本只打印 host/app 摘要，不打印 certificate/private key/server cert 明文。
- 更新 `Sources/LuneXPersistence/JSONFileStores.swift`，新增 `JSONFileAppCatalogSnapshotRepository` 与 `AppStorageLocations`，让 LuneX 默认从用户 Application Support 读取 `hosts.json`、`settings.json`、`app_catalog.json`。
- 更新 `Sources/LuneXNetworking/AppCatalog.swift`，新增 `AppCatalogSnapshotRepository` 与 in-memory 测试实现。
- 更新 `Sources/LuneXCore/AppModel.swift`，默认持久化从 Application Support JSON 读取，`loadInitialState()` 会加载 settings、hosts、cached apps，刷新 app list 后会保存 snapshot。
- 更新 `Tests/LuneXCoreTests/AppModelWorkflowTests.swift`，显式注入 `InMemoryAppCatalogSnapshotRepository`，避免单测覆盖本机导入的 app cache。
- 创建 `script/build_and_run.sh` 与 `.codex/environments/environment.toml`，提供 Codex macOS Run 入口；脚本使用项目本地 `build/DerivedData`，支持 `run`、`--verify`、`--debug`、`--logs`、`--telemetry`。
- 新增 `JSONFileAppCatalogSnapshotRepository` round-trip 单测；首次写法把 `try await repository.loadSnapshots()` 直接放入 `XCTAssertEqual` autoclosure，Swift 6 构建失败，已改为先 await 到局部变量再断言。
- 执行 `python3 Tools/import_moonlight_qt_data.py`，写入 `~/Library/Application Support/LuneX/hosts.json`、`settings.json`、`app_catalog.json`、`moonlight_qt_identity.json`；导入摘要为 2 台 paired host、4 个 cached app 条目。
- 本地 JSON 摘要校验：`tanmy-deck` paired 地址 `10.1.100.246`，cached app `Desktop`；`tanmy-white` paired 地址 `10.1.100.69`，cached apps `Desktop`、`Steam Big Picture`、`War Thunder`；client certificate/private key 存在但未输出明文。
- `xcodebuild -project LuneX.xcodeproj -scheme LuneXCoreTests -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test -quiet` 通过，48 个测试通过。
- `./script/build_and_run.sh --verify` 通过，当前唯一运行的 `LuneX-macOS` 进程来自 `/Users/tanmy/Projects/LuneX/build/DerivedData/Build/Products/Debug/LuneX-macOS.app`。
- 使用 Computer Use 检查前台窗口：Library 显示 `tanmy-deck`、`tanmy-white` 两台 paired host，默认选中 `tanmy-deck` 时显示 cached `Desktop` app。

## 2026-07-10

- 完成代码与 UI/UX 全面审计：确认伪 pairing 会覆盖 pinned identity、launch 会在无 transport 时显示 Streaming、平台 lifecycle/HDR/audio/PiP/input 模块未接入运行路径、iPhone compact 导航阻断、导入私钥以明文 JSON 保存等问题。
- 审计验证：48 个 macOS 单测通过；macOS、iOS、tvOS、visionOS 构建通过；复用固定 iPhone 17 Pro simulator 运行当前 App，确认首屏停留 sidebar 且 Add Host 不可达，审计后已关闭该 simulator。
- 创建 OpenSpec change `remediate-critical-audit-findings`，新增 `runtime-integrity` 与 `compact-navigation` capability，开始第一批安全和导航修复。
- `AppModel` 新增 runtime capability availability；真实 provider 未接入时 pairing 保持 host/pinned identity 不变，stream launch 不调用网络 client、不进入 Streaming，并记录明确 diagnostics。
- Moonlight-qt importer 默认不再复制 certificate/private key identity JSON，写出的 hosts/settings/app catalog 权限收紧到 `0600`；已执行新版 importer 并删除旧版生成的 `moonlight_qt_identity.json`。
- iPhone compact root 改为 `TabView + NavigationStack`，Library 首屏直接显示 Add Host，Library/Stream/Diagnostics/Settings 四个 tab 可达，Library 内容按单列堆叠并为浮动 tab bar 保留底部滚动空间。
- 新增 fail-closed workflow 回归测试；`LuneXCoreTests` 49 个测试通过，OpenSpec strict validate 通过。
- 使用独立 DerivedData 构建 macOS、固定 iPhone 17 Pro、tvOS、visionOS target，全部通过；固定 iPhone 实际安装运行并截图验证 compact UI，随后已关闭该 simulator，未创建其他同类设备。
- 创建并推送提交 `04fa2ef Fail closed on unavailable Moonlight transport` 到 `origin/main`（`c7b08d6..04fa2ef`）。OpenSpec `remediate-critical-audit-findings` 13/13 tasks complete。
- 开始下一批 OpenSpec `integrate-identity-trust-macos-lifecycle`：Keychain 仅做一次 opt-in 集成验证，后续 Debug 使用文件 fallback；实现 pinned TLS 和 macOS live lifecycle/EDR 接线。
- 完成 `integrate-identity-trust-macos-lifecycle` 实现：Debug `0600` JSON identity fallback、Release Keychain factory、稳定 client UUID 恢复、exact leaf pinned HTTPS、macOS window lifecycle/EDR/Metal runtime wiring。
- 一次性 Keychain xctest 已完成 save/load/equality/delete，1 passed、0 failed；按用户约束不再重复运行。最终正常测试显式移除 `LUNEX_RUN_KEYCHAIN_TEST`，58 total、57 passed、1 Keychain skipped、0 failed。
- 补齐 TLS 错误契约与测试：pin mismatch 映射为 `certificateMismatch`，缺失 pin 在网络前失败，app-list 与 launch/stop 均验证 pin/HTTPS 路由。
- 最终构建矩阵通过：macOS Debug、macOS Release、固定 iPhone 17 Pro `23A27088-C19F-4F77-A455-4E50E393167E`、固定 Apple TV `11D0B224-D778-4A13-A156-272A45AFF119`、固定 Apple Vision Pro `9BF41D0C-B423-4B3F-B75D-00B31E85FE18`；使用隔离 DerivedData，目标模拟器保持 Shutdown。
- `./script/build_and_run.sh --verify` 通过；运行日志确认 lifecycle monitor attached、drawable `2560x1600`、EDR `5.0`、Debug 文件 store 无 identity、加载 3 台保存主机。当前 App 保持运行。
- OpenSpec strict validate 1/1 passed，`git diff --check` 通过；3 个导入 pin 均为 726-byte DER，本地 hosts/settings/app catalog 文件权限均为 `0600`。OpenSpec 任务 1.1-4.3 已完成，4.4 等待提交与推送成功后勾选。
- 创建并推送功能提交 `faf9ef9 Integrate pinned identity and macOS lifecycle` 到 `origin/main`（`f9b9adb..faf9ef9`）；OpenSpec 4.4 条件满足，阶段 12 与 change 任务更新为 complete。

## 2026-07-21

- 按最初体验要求重新审计完成口径，确认 macOS lifecycle/Metal 节流已接线，但 cursor capture、完整 HDR、空间音频、iOS/iPadOS lifecycle/PiP/后台连续性仍未形成真实 session 运行闭环。
- 修正 `task_plan.md`：阶段 5–9 从 `complete` 改为 `partial`，新增阶段 13–20；后续以生产接线、确定性测试和授权 live-host/真机证据为完成门。
- 创建 `docs/runtime-completion-roadmap.md`，明确真实 runtime → macOS input → HDR → spatial audio → mobile continuity → tvOS/visionOS → UX → Release 验证的依赖顺序。
- 创建 OpenSpec change `implement-moonlight-session-runtime`，包含 proposal、design、5 个 capability specs 和 61 项依赖有序任务，作为所有平台体验修复的第一阻塞阶段。
- 继续遵守 Keychain 约束：正常开发与测试使用文件/in-memory fallback，不重复运行已完成的一次性真实 Keychain 验证。
- 创建并推送规划提交 `fb725d3 Plan end-to-end Moonlight runtime completion` 到 `origin/main`；新 change strict validation 通过并处于 `ready` 状态。
- 重新创建活动目标并开始阶段 13；只读盘点 Sunshine `serverinfo`、Bonjour、公开 Web UI 认证边界和 codec mode mask，未配对、launch 或修改 host。
- 完成 OpenSpec 任务 1.2、1.3：新增 clean-room 边界、协议清单、pairing/RTSP/control/video/audio/input fixture 目录和自动脱敏校验器；任务 1.1 因 Sunshine 语义版本需要授权读取而保持未完成。
- 从磁盘跟踪文件、活动 goal 和 OpenSpec apply instructions 恢复阶段 13：目标仍为 active，change 为 `spec-driven`、进度 `2/61`，工作树仅含阶段 13 未提交变更；下一项为不触发 Keychain 的 Security.framework identity/certificate spike。
- 完成并独立验收 OpenSpec 任务 1.4：新增 `Tools/IdentitySpike`，以 Security.framework 临时 RSA-2048 key 构造和解析 X.509 v3 自签证书，连续三次完成证书/挑战验签；验证无 Keychain、identity store、host I/O 或密钥落盘。
- 新增 `docs/runtime/dependency-decisions.md`，记录固定 profile 仓库自有 DER writer 决策草案；待依赖与 strict validation 验收后勾选任务 1.5。
- 完成并验收 OpenSpec 任务 1.5：静态检查确认无 Swift package、Xcode package product 或 ASN.1 第三方依赖；Security.framework spike、fixture validator、OpenSpec strict validation 和 `git diff --check` 全部通过。
- 完成并独立验收 OpenSpec 任务 1.6：新增合成 5 ms raw Opus fixture、AudioToolbox packet decoder spike 和开发用 multistream fixture generator；macOS 实测 Sunshine stereo/5.1/7.1 normal/HQ 全部解码为非静音 PCM，iOS/tvOS/visionOS SDK typecheck 通过。
- 修复 fixture validator：JSON 结构化放行键名精确为 `sha256` 的 64-hex 公开摘要，同时拒绝其他字段、64+ 长 hex 和 65 字符奇数长度绕过；self-test 与实际 fixture 扫描通过。
- 更新 Opus dependency decision：选择 Apple AudioToolbox production path，不加入 libopus；待独立依赖检查与 strict validation 通过后勾选任务 1.7。
- 完成并验收 OpenSpec 任务 1.7：production source/project 无 libopus 或 package dependency；checked-in stereo fixture、五 profile decoder 矩阵、fixture validator、OpenSpec strict validation 和 diff check 全部通过。当前 change 进度为 6/61，任务 1.1 保持授权信息阻塞，继续 2.x runtime foundation。
- 创建并推送阶段 13 协议/依赖里程碑提交 `749d1b5 Validate runtime protocol dependencies` 到 `origin/main`，开始任务 2.1 production provider contracts；保持 AppModel fail-closed，直到真实实现和 8.x 注入完成。
- 完成并独立验收 OpenSpec 任务 2.1：新增五类 `Sendable` runtime provider contracts 与 5 个 contract tests；完整 macOS tests 通过（真实 Keychain 仍 skipped），macOS 和固定 iPhone/iPad/tvOS/visionOS 隔离构建通过，所有 simulator 前后均为 Shutdown。change 进度 7/61。
- 完成并独立验收 OpenSpec 任务 2.2：新增 cancellable/bounded/timed `NWConnection` channel 和 7 个 tests，含真实 TCP/UDP loopback；完整 warnings-as-errors tests、固定五平台 build、fixture/OpenSpec/diff gates 通过，simulator 前后保持 Shutdown。change 进度 8/61。
- 完成并独立验收 OpenSpec 任务 2.3：新增 session task/resource ownership tracker 和 5 个 tests，覆盖 clean teardown、逆序 release、幂等、late registration 拒绝和 unfinished task 报告；完整 tests/跨平台 builds/OpenSpec/diff gates 通过。change 进度 9/61。
- 完成并独立验收 OpenSpec 任务 2.4：新增 structured runtime diagnostics、敏感/私有字段 redaction、monotonic stage timing、bounded buffer 和 5 个 tests；完整 tests 与固定平台 builds 通过。change 进度 10/61。
- 完成并独立验收 OpenSpec 任务 2.5：network tests 增至 13 个，覆盖 malformed frame、分片/合帧、timeout、外部 cancellation、TCP/UDP loopback 与 session-owned release；修复 `Data.removeFirst` 后非零 `startIndex` 导致的第二帧切片崩溃。完整 gates 通过；因 1.1 仍未完成，change 权威进度为 11/61。
- 从 session catch-up、活动 goal、规划文件和 OpenSpec apply instructions 恢复阶段 13；确认 2.1–2.5 工作树尚未提交，先重新执行独立 foundation gate，再提交并推送后进入 3.1。
- 重新独立验收 2.1–2.5 foundation：完整 macOS warnings-as-errors tests 通过，真实 Keychain 用例按约束 skipped；macOS、固定 iPhone/iPad/Apple TV/Vision Pro Debug 串行构建通过，四个 simulator 前后均为 Shutdown。
- fixture self-test 通过；首次实际扫描误写目录为 `Tests/Fixtures/MoonlightProtocol`，已确认正确根目录为 `Tests/Fixtures/Moonlight` 并重新执行。OpenSpec strict validation、`git diff --check` 均通过。
- 完成并独立验收 OpenSpec 任务 3.1：新增 production Security.framework RSA-2048/X.509 v3 identity generator 和 2 个 tests，验证 PKCS#1 私钥重建、证书解析、公私钥匹配及每次生成材料不同；完整 macOS tests 与固定五平台 warnings-as-errors build 通过，真实 Keychain skipped，simulator 保持 Shutdown。
- 完成并独立验收 OpenSpec 任务 3.2：新增 production identity validator/manager 和 5 个 lifecycle tests，覆盖证书自签验证、篡改拒绝、错配 key 拒绝、JSON persistence/reload/reuse、显式 reset 与无效旧身份不替换；完整 macOS tests 与固定五平台 warnings-as-errors build 通过，真实 Keychain skipped，simulator 保持 Shutdown。
- 完成并独立验收 OpenSpec 任务 3.3：新增共享 bounded X.509 envelope parser、CommonCrypto/Security pairing primitives、gen6/gen7 Python/OpenSSL 合成向量和 5 个 tests；完整 macOS tests、固定五平台 warnings-as-errors build、fixture self-test/扫描通过，真实 Keychain skipped，simulator 保持 Shutdown。
- 完成并独立验收 OpenSpec 任务 3.4：新增 production `MoonlightPairingProvider`、bounded XML/request executor、临时 exact-leaf pin 与 in-memory mutual-TLS identity；动态 Sunshine stub 覆盖完整六阶段 challenge/signature exchange 与 final pin mismatch。
- 3.4 提交前审计发现 progress snapshot 曾由状态机生成独立 UUID；已让 `PairingStateMachine` 接收并发布请求 `attemptID`，新增 transport 回归断言，focused `PairingTransportTests` 4/4 通过。
- 3.4 完整 gate 以 `exit_code=0` 完成：完整 macOS tests 通过且真实 Keychain 用例 skipped；macOS、固定 iPhone 17 Pro、固定 iPad Pro、固定 Apple TV、固定 Apple Vision Pro warnings-as-errors Debug build 通过；fixture self-test/扫描、OpenSpec strict validation、`git diff --check` 通过。
- 验收结束时四个固定 simulator 均为 `Shutdown`，未创建或启动额外设备。OpenSpec 权威进度更新为 15/61；3.5 host pin 持久提交尚未开始，3.7 live pairing 未执行。
- 完成并独立验收 OpenSpec 任务 3.5：新增 `PersistingPairingProvider` 与 5 个 transaction tests；authenticated result 的 exact DER/SHA/host state 必须 save 后 reload 验证成功才向调用方发布 `.completed`。
- 3.5 首次 focused build 因调用另一文件 private `Data.hexString` 失败；改用 production/test 局部 SHA-256 hex helper 后 focused tests 5/5 通过，并将错误写入 `task_plan.md`。
- 3.5 完整 gate 通过：全量 macOS warnings-as-errors tests、macOS/iPhone/iPad/tvOS/visionOS Debug build、fixture self-test/扫描、OpenSpec strict validation 与 diff check 全部成功；真实 Keychain skipped，固定 simulator 均为 `Shutdown`。OpenSpec 权威进度更新为 16/61。
- 完成并独立验收 OpenSpec 任务 3.6：transport/persistence provider 使用 attempt generation token 管理任务；取消 stage 明确为 `.cancelled`，同 ID replacement/stream termination/重复 cancel 幂等清理，旧 attempt 不影响新 attempt。
- 新增六阶段 blocking Sunshine stub cancellation、真实 hanging HTTP `URLSession.data(for:)` cancellation、save 后 blocked reload rollback tests；focused pairing suites 12/12 通过，URLSession 取消在本地测试中快速收敛。
- 3.6 完整 gate 通过：全量 macOS warnings-as-errors tests、macOS/iPhone/iPad/tvOS/visionOS Debug build、fixture self-test/扫描、OpenSpec strict validation、diff check 全部成功；真实 Keychain skipped，四个固定 simulator 均为 `Shutdown`。OpenSpec 权威进度更新为 17/61。
- 任务 3.7 仍需显式授权的 isolated Sunshine test identity 与 host state；本轮未执行 live pairing/re-pair，继续推进不改变 host state 的 4.x RTSP/control 实现。
- 完成并独立验收 OpenSpec 任务 4.1：新增 byte-safe RTSP/1.0 models、bounded prefix/exact decoder、serializer、repository-generated wire fixtures 和 6 个 tests；覆盖 binary body、fragment/coalesce、header lookup、malformed limits、injection 与 length mismatch。
- 4.1 focused tests/fixture scan 通过；提交前审计修正 prefix decoder 对大 coalesced buffer 的错误总长判断，并把 delimiter 查找改为无临时数组比较，新增 combined buffer 大于单 frame 上限的回归。
- 4.1 完整 gate 通过：全量 macOS warnings-as-errors tests、macOS/iPhone/iPad/tvOS/visionOS Debug build、fixture self-test/扫描、OpenSpec strict validation、diff check 全部成功；真实 Keychain skipped，四个固定 simulator 均为 `Shutdown`。OpenSpec 权威进度更新为 18/61。
- 完成并独立验收 OpenSpec 任务 4.2：新增 Sunshine DESCRIBE/SETUP typed parsers、synthetic negotiation fixture 和 4 个 tests；解析 feature/encryption/codec/Opus、session/port/ping/connect values，并拒绝 malformed/duplicate/missing negotiated fields。
- 4.2 完整 gate 通过：全量 macOS warnings-as-errors tests、macOS/iPhone/iPad/tvOS/visionOS Debug build、fixture self-test/扫描、OpenSpec strict validation、diff check 全部成功；真实 Keychain skipped，四个固定 simulator 均为 `Shutdown`。OpenSpec 权威进度更新为 19/61。
- 完成并独立验收 OpenSpec 任务 4.3：新增 `RTSPBootstrap.swift` 和 8 个 bootstrap tests，支持 `rtsp://`/`rtspenc://` endpoint、Sunshine OPTIONS/DESCRIBE、AES-GCM encrypted RTSP framing、CSeq/status fail-closed 和 task/session token 生命周期。
- 4.3 修正 session truth：`StreamSessionCoordinator.markTransportStarted` 必须满足全部 required channel readiness；`AppModel` 不再因 `/launch` response 手动进入 Streaming，在 8.x production provider 注入前保持明确 fail-closed。
- 4.3 协议审查补齐 `X-GS-ClientVersion: 14` 与 `Host` headers；加密 framing 与本地只读参考中的 24-byte header、BE sequence、LE nonce、`C/R`/`H/R` origin separation 一致，未复制或链接 GPL production source。
- 4.3 focused tests 17/17 通过；完整 macOS warnings-as-errors tests 通过且真实 Keychain test skipped。macOS、固定 iPhone 17 Pro、固定 iPad Pro、固定 Apple TV、固定 Apple Vision Pro 隔离 Debug build 全部通过。
- fixture self-test/扫描、OpenSpec strict validation、generator consistency、`git diff --check` 全部通过；验收前后四个固定 simulator 均为 `Shutdown`，未创建或启动额外设备。OpenSpec 权威进度更新为 20/61，下一项为 4.4 control channel。
- 开始 OpenSpec 任务 4.4：确认当前 Sunshine/GameStream control transport 需要 ENet reliable UDP，选择固定 MIT ENet revision `aca87840b57f045a1f7f9299e4b1b9b8e2a5e2f1`，以未修改 vendor source、仓库自有窄 C bridge 和 Swift serial driver 集成；设计、clean-room 与依赖决策已同步。
- 已 vendor `ThirdParty/ENet`、新增 `LuneXENetBridge` 并接入 generator；四平台 SDK 严格 C syntax compile 和现有 RTSP focused Xcode integration 已通过。`ENetControlTransport.swift` 刚加入但尚未编译，4.4 仍为进行中，不得视为完成或更新 `20/61` 权威进度。
- 完成 OpenSpec 任务 4.4：新增 fixed MIT ENet vendor、opaque C bridge、serial Swift driver、encrypted control frame codec 与 session-owned control actor；实现 48-channel connect、Start A/B、100 ms ENet service/keepalive、urgent IDR、extended termination 与 host error mapping。
- RTSP bootstrap 扩展为 audio/video/control 三次 SETUP，严格传播并比对 Session token、解析 negotiated ports 并要求 `X-SS-Connect-Data`；control operational 后只发布 `.channelsReady(.control)`，remote termination 后同时释放 ENet 与 RTSP，仍不发布 `.all`/`.negotiated`/`Streaming`。
- 4.4 focused control/RTSP/negotiation tests `19/19` 通过；全量 macOS warnings-as-errors tests 通过且真实 Keychain test skipped。macOS、固定 iPhone 17 Pro、固定 iPad Pro、固定 Apple TV、固定 Apple Vision Pro 隔离 Debug build 全部通过。
- ENet vendor revision/license/source逐文件匹配只读 review clone；自有 C bridge 与 vendor C 在 macOS/iOS simulator/tvOS simulator/visionOS simulator 四 SDK strict syntax gate 通过，第三方 warning suppression 保持 PBXBuildFile scoped，production source graph 无 GPL/reference 输入。
- fixture validator self-test/全树、generator consistency、OpenSpec strict validation、`git diff --check` 与 dependency/source/license audit 全部通过；验收前后四个固定 simulator 均为 `Shutdown`。OpenSpec 权威进度更新为 `21/61`，下一项为 4.5 bounded reconnect/channel health。

## 2026-07-21 阶段 13 任务 4.5 启动

- 已从磁盘恢复活动目标与 OpenSpec `implement-moonlight-session-runtime`，核对 `HEAD == origin/main == 63dec2d`、工作树 clean、权威进度 `21/61`，4.4 已完成并推送。
- 已读取 proposal、design、五份 spec 与 tasks；当前执行 4.5 `Implement bounded reconnect and channel-health aggregation without duplicate host sessions`。
- 已核对只读 Moonlight iOS/Sunshine 行为：恢复使用 `/resume`，必须提供 fresh `rikey`/`rikeyid`，成功返回 `resume=1`/`sessionUrl0`；不会重新启动 app。direct ENet same-key sequence reset 被拒绝为 AES-GCM nonce 风险。
- 4.5 验收计划：先实现 health/retry/key contracts、HTTP `/resume`、RTSP/control recovery 与 sequence consumption，再运行 focused fault/race tests；通过后才执行完整跨平台 build/test/fixture/OpenSpec/license/source/simulator-state gate，最后更新 22/61、提交并推送。

## 2026-07-21 阶段 13 任务 4.5 完成

- 新增 `SessionRecovery.swift`：required-channel health snapshot/aggregator、三次 100/250/500 ms reconnect policy、可注入 sleeper、Security random remote-input key generator 与 fail-closed transient error classifier。
- `HTTPStreamLaunchClient` 新增独立 `/resume` contract；resume 必须返回 `resume=1`，同时支持 Sunshine `sessionUrl0`。`MoonlightSessionControlProvider` 在 control 丢失时先发布空健康集，仅调用 `/resume`，每次使用 fresh key，重建 RTSP/control；不重复 `/launch`。
- control AES-GCM sequence 改为在等待 ENet send 前消费，避免不确定 send failure 后复用 nonce。`StreamSessionCoordinator` 现在持有 current health，required channel 丢失后从 streaming 进入 reconnecting，只有全部 required 恢复才回到 streaming。
- 4.5 focused control/RTSP/recovery tests 最终 `29/29` 通过；覆盖 exact `/resume` query/marker、SecureRandom generator、policy validation、eventually succeeds、三次 exhaustion、best-effort cancel、non-retryable frame/authentication、duplicate key、one launch、fresh keys、health truth、sequence consumption 与 old-attempt late publish suppression。
- 完整 macOS warnings-as-errors tests 最终 `150 total / 149 passed / 1 skipped / 0 failed`；skipped 仅为显式 opt-in 真实 Keychain round-trip，`LUNEX_RUN_KEYCHAIN_TEST` 未设置，未再次访问 Keychain。
- macOS、固定 iPhone 17 Pro、固定 iPad Pro 13-inch、固定 Apple TV、固定 Apple Vision Pro warnings-as-errors Debug build 全部通过；构建前后四个 simulator 均为 `Shutdown`，未创建或 boot 新实例。
- 自有 C bridge 与 pinned ENet 在 macOS/iOS simulator/tvOS simulator/visionOS simulator 四 SDK strict syntax gate 通过；fixture self-test/全树、OpenSpec strict、generator byte-for-byte、LuneX whitespace、production GPL/reference boundary、ENet revision/license/source match 全部通过。
- OpenSpec 4.5 更新为完成，权威进度 `22/61`；下一项为 4.6 remote cancel/local cancellation convergence。live host reconnect、媒体/input readiness 与完整 streaming 仍未执行或声称完成。

## 2026-07-21 阶段 13 任务 4.6 启动

- 4.5 已以 `5f41652 Implement bounded session reconnect` 提交并推送，`HEAD == origin/main`、工作树 clean 后进入 4.6。
- 4.6 范围限定为 remote/local cancellation convergence：显式 stop、stream consumer cancellation、replacement、remote termination、terminal failure 与 reconnect exhaustion 统一进入 generation-owned 幂等 teardown；不提前实现 4.7 完整状态矩阵或 5.x media runtime。
- 验收重点为阻塞 launch/RTSP/reconnect sleep/resume 的取消收敛、重复 stop、remote/local race、`/cancel` failure 本地资源仍释放，以及旧 generation 不影响新 session。

## 2026-07-21 阶段 13 任务 4.6 完成

- 新增 generation-owned `SessionControlTeardownCoordinator`：local stop、consumer cancellation、replacement、terminal failure 和 reconnect exhaustion 都先使 active generation 失效、取消 bootstrap，再由 detached teardown operation 依次释放 ENet/RTSP 并 best-effort 调用 pinned `/cancel`；同 generation 并发 caller 复用一个 operation。
- host termination 只执行本地 teardown，不重复 `/cancel`。`HTTPStreamLaunchClient.stop` 现在要求 Sunshine XML `status_code=200` 且 `cancel=1`；远端失败记录为 teardown evidence，但本地资源照常释放。`StreamSessionCoordinator` 在 cancel error 时也收敛到 `disconnected`。
- 4.6 focused cancellation/HTTP/replacement gate 最终 15/15 通过；覆盖重复 stop、consumer cancellation、launch/RTSP transact/reconnect sleep/resume 阻塞取消、remote/local race、cancel failure、detached cleanup cancellation 隔离、replacement remote cancel 和 old generation suppression。
- 完整 macOS warnings-as-errors tests 最终为 `160 total / 159 passed / 1 skipped / 0 failed`；唯一 skipped 仍是未设置 `LUNEX_RUN_KEYCHAIN_TEST` 的真实 Keychain round-trip，未再次访问真实 Keychain。
- macOS、固定 iPhone 17 Pro、固定 iPad Pro 13-inch、固定 Apple TV、固定 Apple Vision Pro warnings-as-errors Debug build 全部通过；四 SDK strict C syntax、fixture self-test/扫描、OpenSpec strict、generator byte-for-byte、production GPL/reference boundary、pinned ENet revision/license/source/header 比对全部通过。
- OpenSpec 4.6 更新为完成，权威进度 `23/61`；下一项为 4.7 deterministic state-machine tests。媒体/input readiness 与完整 Streaming 仍未实现或声称完成。
- 4.6 封版审计修正 remote-termination/local-stop 重入竞态：session provider actor 在任何异步 teardown 前锁定 `TerminalSession`，后到请求复用首个 terminal trigger；新增用例证明远端终止后 stop 不发送 `/cancel`，focused cancellation suite `8/8`、RTSP/recovery/negotiation 扩展 gate `38/38` 通过，且显式清除了 `LUNEX_RUN_KEYCHAIN_TEST`。
- 竞态修正后重新执行完整五平台 warnings-as-errors Debug build，macOS、固定 iPhone、固定 iPad、固定 Apple TV 与固定 Apple Vision Pro 全部通过；这些 simulator 始终保持 `Shutdown`，没有创建、boot 或重复启动设备。

## 2026-07-21 阶段 13 任务 4.7 启动

- 4.6 已以 `52a19ac Converge session cancellation teardown` 提交并推送，`HEAD == origin/main`、工作树 clean 后进入 4.7。
- 4.7 范围限定为 deterministic session state-machine matrix：分别验证 provider event sequence、`StreamSessionCoordinator` transport truth 与 `AppModel` UI-derived phase；不提前实现 5.x media packet/decode runtime。
- 验收矩阵覆盖 success、partial readiness、required-channel loss、bounded reconnect success/exhaustion、non-retryable failure、remote termination reason、local stop、replacement generation、duplicate event idempotency 与 invalid transition fail-closed。

## 2026-07-21 阶段 13 任务 4.7 完成

- `StreamSessionCoordinator` 新增 generation-scoped `SessionControlEvent` reducer；snapshot 保存 negotiated configuration、reconnect attempt 和 remote termination reason。Streaming 只允许在 launch accepted、RTSP ready、validated negotiated config 且全部 required channels healthy 后进入。
- required-channel loss 立即退出 Streaming；新 reconnect attempt 清空健康集和旧 negotiated config，必须重新收到 RTSP/negotiated/all-ready 才恢复。stale generation、未知 readiness bit 和非法顺序均 fail closed 且不污染当前 snapshot。
- duplicate launch/RTSP/negotiated/health/reconnect/termination 保持 snapshot 完全不变；remote termination 后迟到 failure 保留 first-terminal reason，本地 stop 幂等且只调用一次 remote cancel client。
- 新增 `SessionStateMachineTests` 7 项，相关 state/recovery/negotiation/AppModel focused gate `31/31` 通过；完整 macOS warnings-as-errors tests 为 `167 total / 166 passed / 1 skipped / 0 failed`，唯一 skipped 是未启用 `LUNEX_RUN_KEYCHAIN_TEST` 的真实 Keychain round-trip。
- macOS、固定 iPhone、固定 iPad、固定 Apple TV、固定 Apple Vision Pro warnings-as-errors Debug build 全部通过；fixture self-test/全树、OpenSpec strict、generator byte-for-byte、production/reference boundary 与 diff check 通过，四个 simulator 始终为 `Shutdown`。
- OpenSpec 4.7 更新为完成，权威进度 `24/61`；下一项为 5.1 bounded video packet reordering、loss detection 与 codec access-unit assembly。AppModel production provider 接线仍属于 8.x，真实媒体和 Streaming 仍未声称完成。

## 2026-07-21 阶段 13 任务 5.1 启动

- 4.7 已以 `21471cc Add deterministic session state matrix` 提交并推送，`HEAD == origin/main`、工作树 clean 后进入 5.1。
- 5.1 范围限定为 bounded video packet reordering、loss detection 和 codec access-unit assembly；5.2 parameter-set parsing/VideoToolbox format、5.4 decoder ownership 与 live video 均不提前实现或声称完成。
- 先核对 repository protocol inventory、sanitized video fixture 与只读 Moonlight/Sunshine packet framing，再定义 sequence wrap、frame boundary、duplicate/late packet、gap/IDR 和 memory/time bound contract。

## 2026-07-21 阶段 13 任务 5.1 完成

- 新增 `VideoPacketAssembly.swift`、synthetic byte-exact fixture 和 9 项 tests：解析固定 RTP/NV header，处理 16/24/32-bit wrap、最多四个 multi-FEC block 的 data-shard reorder、duplicate/late/gap/timeout/capacity/metadata loss，并输出 IDR evidence。
- H.264/HEVC access unit 保留 Annex-B trailing zero padding；AV1 使用 Sunshine short-header `lastPayloadLen` 精确截断。parity packet 明确丢弃，不复制或链接 GPL Reed-Solomon；receiver 必须在调用 parser 前完成可选 AES-GCM 认证解密。
- focused assembly tests `9/9`、完整 macOS warnings-as-errors tests `176 total / 175 passed / 1 skipped / 0 failed`；唯一 skipped 仍是未设置 `LUNEX_RUN_KEYCHAIN_TEST` 的真实 Keychain round-trip，未再次访问 Keychain。
- macOS、固定 iPhone 17 Pro、固定 iPad Pro 13-inch、固定 Apple TV、固定 Apple Vision Pro warnings-as-errors Debug build 全部通过；四个固定 simulator 前后均为 `Shutdown`，未创建或 boot 设备。
- fixture self-test/全树、OpenSpec strict、generator byte-for-byte、diff/reference boundary、ENet revision/license/source match 与四 SDK strict C syntax 全部通过。OpenSpec 5.1 更新为完成，权威进度 `25/61`；下一项为 5.2 H.264/HEVC parameter-set parsing 与 VideoToolbox format construction。

## 2026-07-21 阶段 13 任务 5.2 启动

- 5.1 已以 `521d2b5 Add bounded video packet assembly` 独立提交并推送，`HEAD == origin/main`、工作树 clean 后进入 5.2。
- Xcode 26.4 SDK 头文件确认 H.264 format 需要 raw SPS/PPS，HEVC 需要 raw VPS/SPS/PPS；两条 CoreMedia factory API 在 macOS/iOS/tvOS/visionOS 均可用，NAL length header 统一选择 4 bytes。
- 使用本机 libx264/libx265 对纯黑 64x64 单帧生成完全合成的 Annex-B parameter-set fixture；不包含 host、用户、Keychain 或网络数据，也不把 FFmpeg/libx26x 链接到 production target。

## 2026-07-21 阶段 13 任务 5.2 完成

- 新增 `VideoFormatDescription.swift`：bounded 3/4-byte Annex-B splitter、H.264 SPS/PPS 和 HEVC VPS/SPS/PPS parser、forbidden-bit/HEVC temporal-id 校验、exact-duplicate 幂等与 conflicting-set fail-closed。
- CoreMedia factory 使用同步有效的 nonoptional raw NAL pointer array创建 4-byte NAL-length H.264/HEVC format description；合成 64x64 fixture 在 getter round-trip 中 byte-exact。focused tests `5/5` 通过。
- 完整 macOS warnings-as-errors tests `181 total / 180 passed / 1 skipped / 0 failed`；唯一 skipped 仍是未启用 `LUNEX_RUN_KEYCHAIN_TEST` 的真实 Keychain round-trip，未再次访问 Keychain。
- macOS、固定 iPhone、固定 iPad、固定 Apple TV、固定 Apple Vision Pro warnings-as-errors Debug build 全部通过；simulator 前后均为 `Shutdown`。fixture/OpenSpec/generator/diff/reference/ENet/four-SDK-C gates 全部通过。
- OpenSpec 5.2 更新为完成，权威进度 `26/61`；下一项为 5.3 AV1 capability negotiation 和 unsupported-device fallback policy。VideoToolbox decompression-session ownership 与 decode callback 仍属于 5.4。

## 2026-07-21 阶段 13 任务 5.3 启动

- 5.2 已以 `b932dc7 Build native H264 and HEVC formats` 独立提交并推送，`HEAD == origin/main`、工作树 clean 后进入 5.3。
- Xcode 26.4 五平台 SDK 均提供 `VTIsHardwareDecodeSupported`；生产 capability provider 将只把该 API 的硬件解码结果用于 H.264、HEVC、AV1 设备门禁，单测使用可注入 deterministic capability set。
- 当前 RTSP `DESCRIBE` 已解析 host codec family 但丢弃结果；5.3 将选择策略接入真实 bootstrap 路径。HDR/10-bit 只允许 AV1/HEVC，不能静默降级为 SDR/H.264；VideoToolbox session ownership、AV1 format construction 与真实帧解码仍属于后续任务。

## 2026-07-21 阶段 13 任务 5.3 完成

- 新增 `VideoCodecSelection.swift`：可注入 device capability、确定性 AV1 -> HEVC -> H.264 preference/fallback、structured fallback/error 和三种 codec 到 CoreMedia type 的精确映射；production provider 使用 `VTIsHardwareDecodeSupported`。
- `MoonlightSessionControlProvider` 在 `DESCRIBE` 后、任何 SETUP 前执行并保存 selection；HDR/10-bit 排除 H.264，没有 AV1/HEVC host+device 硬件交集时 fail closed。reconnect 清除旧 selection 后重新协商。
- 新增 8 项 selection tests 和 2 项 bootstrap gate tests；同时由真实 CRLF response 发现并修复 SDP splitter 缺陷，改用 `Character.isNewline`。selection/RTSP/SDP focused gate 最终 `24/24` 通过。
- 完整 macOS warnings-as-errors tests `191 total / 190 passed / 1 skipped / 0 failed`；唯一 skipped 仍是未设置 `LUNEX_RUN_KEYCHAIN_TEST` 的真实 Keychain round-trip，未再次访问 Keychain。
- macOS、固定 iPhone、固定 iPad、固定 Apple TV、固定 Apple Vision Pro warnings-as-errors Debug build 全部通过；构建前后四个 simulator 均为 `Shutdown`，未创建或 boot 新实例。
- fixture self-test/全树、OpenSpec strict、generator byte-for-byte、LuneX whitespace、production/reference boundary、ENet revision/license/source/header 和四 SDK strict C syntax gates 全部通过。
- OpenSpec 5.3 更新为完成，权威进度 `27/61`；下一项为 5.4 VideoToolbox decompression-session ownership 与 callback-to-actor bridging。AV1 format construction、真实 decoder/frame 和 live video 仍未由 5.3 证明。

## 2026-07-21 阶段 13 任务 5.4 启动

- 5.3 已以 `5357a2e Gate AV1 hardware codec negotiation` 独立提交并推送；恢复时确认 `HEAD == origin/main`、工作树 clean、OpenSpec 权威进度 `27/61`。
- 当前执行 5.4 `Implement VideoToolbox decompression-session ownership and callback-to-actor bridging`；范围限定为 generation-owned session、硬件 decoder create、异步 callback 到 actor 的桥接和确定性 teardown，不提前声称 5.5 Metal delivery、5.6 HDR metadata、5.7 reset policy 或 5.8 live video。
- 后续测试继续显式清除 `LUNEX_RUN_KEYCHAIN_TEST`，不再次访问真实 Keychain；跨平台构建只使用既有固定 simulator destination，不创建或 boot 新设备。
- 5.4 focused gate 已通过：10 项 decoder/session tests 与 5 项既有 format tests 共 `15/15`。production 路径实际创建 required-hardware VideoToolbox session，并从合成 64x64 H.264 8-bit 与 HEVC 10-bit IDR 收到有效 `CVPixelBuffer` callback。
- 原 `parameter-sets.json` 的占位 IDR 被 VideoToolbox 和 FFmpeg 同时判定为 bad data；已用本机 libx264/libx265 重生成无主机数据黑帧，移除 encoder SEI，仅保留参数集/IDR，先经 FFmpeg 独立解码后再进入 fixture。此证据仍不等于 live Sunshine sustained video。

## 2026-07-21 阶段 13 任务 5.4 完成

- 新增 generation-owned `VideoDecoder` actor、weak/locked `VideoDecompressionCallbackBridge`、required-hardware `VideoToolboxDecompressionSession`、owned CoreMedia sample construction 和可注入 session factory；replacement/stop/deinit 均执行 idempotent finish/wait/invalidate teardown，stale callback 被拒绝。
- H.264/HEVC bounded Annex-B access unit 在进入 `CMSampleBuffer` 前转为 4-byte big-endian NAL length framing；CoreMedia 自行分配 block memory并复制 bytes。输出 attrs 明确为 IOSurface-backed、Metal-compatible，8-bit/10-bit 分别选择 video-range bi-planar pixel format。
- focused decoder+format tests 最终 `15/15`；真实 production factory 成功创建 required-hardware session，并从合成 H.264 8-bit 与 HEVC 10-bit IDR 分别收到有效 64x64 pixel buffer。同步/异步 error、drop、missing image、replacement、late callback、重复 stop、deinit、malformed/oversized 和 create failure 均有回归。
- 完整 macOS warnings-as-errors tests 最终 `201 total / 200 passed / 1 skipped / 0 failed`；唯一 skipped 是未设置 `LUNEX_RUN_KEYCHAIN_TEST` 的真实 Keychain round-trip，本任务未再次访问真实 Keychain。
- macOS、固定 iPhone 17 Pro、固定 iPad Pro 13-inch、固定 Apple TV、固定 Apple Vision Pro warnings-as-errors Debug build 全部通过；构建前后四个 simulator 均为 `Shutdown`，未创建或 boot 新实例。
- fixture validator self-test/全树、OpenSpec strict、generator byte-for-byte、LuneX whitespace、production/reference boundary、固定 ENet revision/license/source/header 和四 SDK strict C syntax gates 全部通过。
- OpenSpec 5.4 更新为完成，权威进度 `28/61`；下一项为 5.5 zero-copy CVPixelBuffer-to-Metal texture delivery 与 bounded frame queue。AV1 format/decode、HDR metadata/reset policy 和 live Sunshine sustained video仍未声称完成。

## 2026-07-21 阶段 13 任务 5.5 启动

- 5.4 已以 `61a3247 Own VideoToolbox decode sessions` 独立提交并推送；确认 `HEAD == origin/main`、工作树 clean 后进入 5.5。
- 5.5 范围限定为 IOSurface-backed `CVPixelBuffer` 到 `CVMetalTexture` 的零 CPU-copy plane 映射、session-owned texture cache 和有界 newest-frame queue；色彩矩阵、HDR metadata/tone mapping、format reset 与 live sustained video仍分别留给 5.6-5.8。
- 测试继续显式清除 `LUNEX_RUN_KEYCHAIN_TEST`，并只使用四个固定 simulator destination，不创建或 boot 设备。
- 5.5 focused warnings-as-errors gate 已通过：`MetalVideoFrameDeliveryTests` 5 项与 `VideoDecompressionSessionTests` 10 项，共 `15/15`；production mapping 从真实 VideoToolbox H.264 `420v` 与 HEVC `x420` 输出建立 `r8Unorm/rg8Unorm` 与 `r16Unorm/rg16Unorm` live Metal plane，且保留同一 source `CVPixelBuffer` 与 `CVMetalTexture` wrapper。完整跨平台封版门禁尚未执行，因此任务仍保持未勾选、未提交。
- 5.5 完整 macOS warnings-as-errors tests 已通过；xcresult 精确统计 `206 total / 205 passed / 1 skipped / 0 failed`，唯一 skipped 是未设置 `LUNEX_RUN_KEYCHAIN_TEST` 的真实 Keychain round-trip，本轮未访问 Keychain。fixture validator self-test/全树、OpenSpec strict、generator byte-for-byte、LuneX whitespace 与 production/reference boundary 同步通过。

## 2026-07-21 阶段 13 任务 5.5 完成

- 新增 locked `CVMetalVideoFrameMapper`：使用 session-owned `CVMetalTextureCacheCreateTextureFromImage` 将 decoder-native `420v`/`x420` 双平面 pixel buffer 映射为 `r8Unorm/rg8Unorm` 或 `r16Unorm/rg16Unorm`，mapped frame 保留 source buffer、CoreVideo wrappers 与 Metal views；其他 pixel format/plane/layout/device mismatch fail closed。
- 新增 actor-isolated `BoundedMetalFrameQueue`：默认容量 3、硬上限 8，超限淘汰最旧 frame，`dequeueLatest()` 交付最新 frame 并释放积压；generation replacement/stop 清空 queue 并 flush cache，stale frame 在 mapping 前拒绝，decoder start/frame/stop event 可直接驱动该边界。
- focused decoder+Metal gate `15/15`；完整 macOS warnings-as-errors tests `206 total / 205 passed / 1 skipped / 0 failed`，唯一 skipped 仍为显式 opt-in 真实 Keychain round-trip。macOS、固定 iPhone、固定 iPad、固定 Apple TV 与固定 Apple Vision Pro warnings-as-errors Debug build全部通过，四个 simulator 构建前后均为 `Shutdown`。
- fixture self-test/全树、OpenSpec strict、generator byte-for-byte、LuneX whitespace、production/reference boundary、固定 ENet revision/license/source/header 和四 SDK strict C syntax gates 全部通过。OpenSpec 5.5 更新为完成，权威进度 `29/61`；下一项为 5.6 colorspace/bit-depth/mastering/content-light metadata preservation。
- 当前证据不等于 shader color conversion、HDR tone mapping、drawable presentation、AppModel production wiring 或 live Sunshine sustained video；这些范围仍保持未完成。

## 2026-07-21 阶段 13 任务 5.6 启动

- 5.5 已以 `7e670d1 Deliver decoded frames to Metal` 独立提交并推送，确认 `HEAD == origin/main`、工作树 clean 后进入 5.6。
- 5.6 范围限定为 negotiated colorspace/bit depth 与 Sunshine control HDR mastering/content-light metadata 的 typed preservation、Apple CoreMedia blob encoding 以及 decoder/Metal generation传播；format reset/IDR属于 5.7，EDR/tone mapping属于阶段 15。
- 测试继续显式清除 `LUNEX_RUN_KEYCHAIN_TEST`；跨平台 build 只使用既有四个固定 simulator destination且保持 `Shutdown`。
- 5.6 expanded focused warnings-as-errors gate 已通过 `50/50`：4 项 color metadata、6 项 control、5 项 runtime contract、10 项 decoder、5 项 Metal、12 项 RTSP bootstrap 与 8 项 session state matrix。覆盖 byte-exact Sunshine `0x010E`、Apple 24-byte MDCV/4-byte CLL、provider/snapshot/config preservation、invalid/stale fail-closed 与真实 VideoToolbox-to-Metal metadata lifetime。

## 2026-07-21 阶段 13 任务 5.6 完成

- 新增 typed SDR Rec.709 与 HDR10 BT.2020/PQ/video-range metadata contract，解析 Sunshine generation-7 `0x010E` legacy/27-byte HDR mode payload，并 byte-exact 生成 Apple 24-byte MDCV 与 4-byte CLL 数据。
- provider 不再丢弃 HDR control event；metadata 以 session/generation 隔离方式传播到 coordinator snapshot、negotiated video configuration、VideoToolbox decoder generation、decoded frame 与 Metal mapped frame。H.264+10-bit/HDR、HDR+8-bit/Rec.709、SDR stale light metadata 和非法色度/亮度均 fail closed。
- focused warnings-as-errors gate `50/50`；完整 macOS gate `211 total / 210 passed / 1 skipped / 0 failed`，唯一 skipped 仍为未设置 `LUNEX_RUN_KEYCHAIN_TEST` 的真实 Keychain round-trip，本轮未访问真实 Keychain。
- macOS、固定 iPhone、固定 iPad、固定 Apple TV、固定 Apple Vision Pro warnings-as-errors Debug build 全部通过；构建后四个 simulator 均为 `Shutdown`，未创建或 boot 新实例。
- fixture validator self-test/全树、OpenSpec strict、generator byte-for-byte、LuneX whitespace、production/reference/dependency boundary、固定 ENet revision/license/source/header 和四 SDK strict C syntax gates 全部通过。首次 C gate 的 zsh 标量文件列表错误已记录，并以数组逐文件复验通过。
- OpenSpec 5.6 更新为完成，权威进度 `30/61`；下一项为 5.7 format-change、decoder-reset、IDR-request、dropped-frame 与 teardown tests。EDR/tone mapping、AppModel presentation 和 live Sunshine sustained video仍保持未完成。

## 2026-07-21 阶段 13 任务 5.7 启动

- 5.6 已以 `618d556 Preserve video color metadata` 独立提交并推送，确认 `HEAD == origin/main`、工作树 clean 后进入 5.7。
- 盘点确认 assembler loss、generation-owned VideoToolbox decoder、Metal generation queue和 urgent control IDR接口均已存在，但没有 production coordinator负责 loss/format/metadata change后的 drain、IDR coalescing、预测帧阻断与恢复。
- 5.7 范围限定为 session-owned video decode/reset coordinator及 format-change、decoder reset、IDR request、dropped frame、teardown race确定性测试；video socket接入、AppModel presentation和授权 live Sunshine sustained video仍分别属于后续 8.x、5.8。
- 新增 `VideoDecodePipeline` 与 control-provider IDR adapter：首次/变化 IDR创建 generation，相同参数集复用 session；loss/drop/metadata change停止旧 generation、合并 outstanding IDR并阻断预测帧；stop在 suspension前锁定 lifecycle并 detach callback bridge。
- 新增 96x64 repository-generated H.264 format-change fixture，encoder SEI已移除；FFmpeg独立解码通过，CoreMedia解析为预期 96x64。expanded focused warnings-as-errors gate `43/43` 通过，其中 8 项新 pipeline tests覆盖参数变化、IDR coalescing、metadata reset、decoder drop、session-ID routing、重复 stop、迟到 callback与 in-flight IDR teardown race。

## 2026-07-21 阶段 13 任务 5.7 完成

- 新增 session-owned `VideoDecodePipeline` 与 `SessionControlVideoIDRRequester`：首个合法 IDR 建立 decoder generation，相同 parameter sets/metadata复用；format、bit depth或HDR metadata变化先停止旧 generation，等待下一 IDR重建。loss/drop期间阻断预测帧并合并 outstanding IDR，发送失败允许后续重试。
- staged audit发现 decoder session创建挂起时，`stop()` 虽先锁定stopped状态，迟到的IDR continuation仍可能重写active generation；现已在decoder replace/decode每个异步边界后校验lifecycle token，并新增挂起factory回归。Swift 6首次因Task闭包捕获XCTest `self`拒绝编译，改为Task前构造Sendable access unit后通过。
- pipeline-specific最终回归为 `10/10`；修改后完整 macOS warnings-as-errors gate `221 total / 220 passed / 1 skipped / 0 failed`，唯一skip仍为显式opt-in真实Keychain round-trip，本轮通过 `env -u LUNEX_RUN_KEYCHAIN_TEST` 未再次访问Keychain。
- macOS、固定 iPhone、固定 iPad、固定 Apple TV、固定 Apple Vision Pro warnings-as-errors Debug build全部通过；原构建会话真实退出 `0`，四个 simulator构建后均为 `Shutdown`，未创建或boot新实例。
- fixture self-test/全树、OpenSpec strict、generator byte-for-byte、LuneX whitespace、production/reference/dependency boundary、固定 ENet revision/license/source/header逐文件比对和macOS/iOS Simulator/tvOS Simulator/visionOS Simulator strict C syntax gates全部通过。
- OpenSpec 5.7更新为完成，权威进度 `31/61`。5.8需要授权 live Sunshine持续解码与clean stop证据，当前保持未完成；下一项可离线执行任务为6.1 bounded audio packet ordering与jitter-buffer policy。video socket/AppModel wiring、EDR mapping和live sustained video仍未声称完成。

## 2026-07-21 阶段 13 任务 6.1 启动

- 5.7已以 `d3e49c9 Coordinate video decoder recovery` 独立提交并推送；确认 `HEAD == origin/main`、工作树clean、OpenSpec权威进度 `31/61` 后进入6.1。5.8继续等待授权live Sunshine证据，不以fixture替代。
- 6.1范围限定为post-RTP `ReceivedAudioPacket` 的UInt16 wrap-aware排序、目标playout delay、最大jitter deadline、重排窗口、packet/byte双容量和loss/discard事件；Opus decode、PCM scheduling、A/V clock和route/underrun处理仍分别属于6.2-6.5。
- 后续测试继续显式清除 `LUNEX_RUN_KEYCHAIN_TEST`，跨平台build只使用既有固定simulator destination且不boot设备。

## 2026-07-21 阶段 13 任务 6.1 完成

- 新增 `AudioPacketJitterBuffer`：UInt16 wrap-aware sequence ordering、pre-playout backward adjustment、10 ms target/40 ms deadline、8-packet reorder window、1024 forward-gap bound、32 packet/byte双容量和idempotent finish；ready/loss/discard均为typed event。
- 首轮audit修复discarded arrival不驱动deadline的问题，duplicate/conflict/late现在推进monotonic clock并drain；invalid payload/过大gap不部分修改状态。第二轮audit将cadence计算改为checked arithmetic，`samplesPerFrame = Int.max`结构化fail closed。
- focused jitter gate `11/11`，expanded audio/RTSP/runtime contract gate `23/23`；完整macOS warnings-as-errors gate `232 total / 231 passed / 1 skipped / 0 failed`，唯一skip为未启用真实Keychain round-trip，本轮继续使用file fallback。
- macOS、固定iPhone、固定iPad、固定Apple TV、固定Apple Vision Pro warnings-as-errors Debug build全部通过；四个simulator验收前后均为 `Shutdown`，未创建或boot额外实例。
- fixture self-test/全树、OpenSpec strict、generator byte-for-byte、LuneX whitespace、production/reference/dependency boundary、固定ENet revision/license/source/header和四SDK strict C syntax gates全部通过。
- OpenSpec 6.1更新为完成，权威进度 `32/61`。下一项为6.2 approved AudioToolbox Opus decode与PCM format conversion；6.1不证明decoder、audio engine、A/V clock或audible live output。

## 2026-07-21 阶段 13 任务 6.2 启动

- 6.1已以 `e2814ad Bound audio packet jitter` 独立提交并推送；确认 `HEAD == origin/main`、工作树clean、OpenSpec权威进度 `32/61` 后进入6.2。
- 6.2采用已批准的Apple AudioToolbox `AudioConverter`，从negotiated channel/stream/coupled/mapping构造bounded `OpusHead`，把单个post-RTP raw Opus packet转换为canonical interleaved signed-16 PCM并返回实际frame count；production target不加入libopus。
- AVAudioEngine graph、A/V clock、route/interruption/underrun和audible live evidence仍分别属于6.3-6.7；测试继续显式清除真实Keychain opt-in。

## 2026-07-21 阶段 13 任务 6.2 完成

- 新增actor-owned `AudioToolboxOpusDecoder`：Apple `AudioConverter`解码negotiated Opus，family 0覆盖canonical mono/stereo，family 1保留multistream stream/coupled/mapping；输出48 kHz interleaved signed Int16 PCM和实际frame count、sequence、RTP timestamp。
- converter由窄`@unchecked Sendable` RAII owner唯一dispose；packet input拥有稳定storage，payload、samples/frame、output frames/bytes均有硬上限和一致性检查；reset、幂等close与closed-state fail closed均有回归。
- repository-generated stereo、5.1 normal/HQ、7.1 normal/HQ fixtures由development-only libopus 1.6.1生成并经统一脱敏、SHA-256 readback和production decode验证；production Xcode graph未加入libopus或任何新package/product。
- focused decoder gate `8/8`，expanded audio/RTSP/runtime contract gate `31/31`；完整macOS warnings-as-errors gate为`240 total / 239 passed / 1 skipped / 0 failed`，唯一skip仍为未设置`LUNEX_RUN_KEYCHAIN_TEST`的真实Keychain round-trip，本轮继续使用file fallback。
- macOS、固定iPhone、固定iPad、固定Apple TV、固定Apple Vision Pro warnings-as-errors Debug build全部通过；四个simulator构建前后均为`Shutdown`，没有创建或boot新实例。
- fixture self-test/全树、OpenSpec strict、generator byte-for-byte、LuneX whitespace、production/reference/dependency boundary、固定ENet revision/license/source/header和四SDK strict C syntax gates全部通过。
- OpenSpec 6.2更新为完成，权威进度`33/61`。下一项为6.3 session-owned AVAudioEngine graph；6.2不证明PCM scheduling、A/V sync、route/interruption/underrun处理或audible live output。

## 2026-07-21 阶段 13 任务 6.3 启动

- 6.2已以`be5d98f Decode Opus with AudioToolbox`独立提交并推送；确认`HEAD == origin/main`、工作树clean、OpenSpec权威进度`33/61`后进入6.3。
- 现有`AVAudioEngineClient`只prepare/start空engine，未包含player node、PCM conversion或schedule。6.3限定为session-owned player-to-main-mixer graph、bounded PCM scheduling、completion与teardown ownership；A/V clock、route/interruption、underrun/loss继续属于6.4-6.5，audible hardware证据属于6.7。

## 2026-07-21 阶段 13 任务 6.3 完成

- production `AVAudioEngineClient`现在attach `AVAudioPlayerNode`并以48 kHz interleaved signed Int16 format连接main mixer；`AVAudioPCMBufferFactory`在1...5760 frames、1...8 channels和exact sample count边界内byte-exact复制decoded PCM。
- `AudioSessionPipeline`默认拥有production client，最多保留8个scheduled buffers；每个schedule携带generation/token，`.dataConsumed` completion只释放对应ownership。stop/reconfigure推进generation并清空队列，迟到completion不能污染replacement graph。
- staged audit修复失败reconfigure保留旧configuration并允许restart的问题；configure failure现在停止partial graph并清空queue/config/route，start只接受configured/running。backend schedule failure transactional rollback，production client stop后也拒绝绕过actor直接schedule。
- focused decoder+graph warnings-as-errors gate`18/18`；expanded audio/RTSP/runtime/resource gate在新增最终边界前为`42/42`，最终完整macOS gate覆盖全部新增回归并为`247 total / 246 passed / 1 skipped / 0 failed`，唯一skip仍是真实Keychain opt-in。
- macOS、固定iPhone、固定iPad、固定Apple TV、固定Apple Vision Pro最终warnings-as-errors Debug build全部通过；四个simulator前后均为`Shutdown`，没有创建或boot新实例。
- fixture self-test/全树、OpenSpec strict、generator byte-for-byte、LuneX whitespace、production/reference/dependency boundary、固定ENet revision/license/source/header和四SDK strict C syntax gates全部通过。
- OpenSpec 6.3更新为完成，权威进度`34/61`。下一项为6.4 A/V clock与bounded resynchronization；6.3不证明同步、route/interruption/loss handling或audible live output。

## 2026-07-21 阶段 13 任务 6.4 启动

- 6.3已以`2e1cf01 Schedule PCM through AVAudioEngine`独立提交并推送；确认`HEAD == origin/main`、工作树clean、OpenSpec权威进度`34/61`后进入6.4。
- 6.4以audio为fresh时的master、video为audio stale时的fallback；drift定义为各stream相对首个local presentation anchor的offset变化，避免直接比较独立随机RTP起点。audio媒体位置只累计实际decoded frame count，video使用90 kHz wrap-aware timestamp。

## 2026-07-21 阶段 13 任务 6.4 完成

- 新增session-owned `MediaClockSynchronizer`：fresh audio为master、audio超过100 ms无observation时回退video；两条stream分别以首个local presentation observation为零点，比较`local elapsed - media elapsed`变化，不直接相减独立随机RTP起点。
- audio position只累计`AudioScheduleReceipt.frameCount`实际decoded frames，首包120-frame priming回归证明不会按固定240误算；video以90 kHz UInt32 RTP wrap-aware forward delta推进。audio/video wrap、backward timestamp、backward local time和invalid policy均有确定性回归。
- abs drift不超过15 ms不动作；video ahead hold最多10 ms，video behind每次只drop当前frame；abs drift达到250 ms正负边界时只reanchor video并保持audio连续。stale audio下禁止依据旧audio state校正。
- staged audit加入后置snapshot/decision error rollback，任何checked arithmetic failure不留下candidate stream、observation time或action部分mutation。首轮两个失败向量是未实际形成drift及已触发audio stale fallback，修正测试时序/专用fresh policy后通过。
- clock-specific最终`12/12`；expanded audio/video assembly/decode/Metal gate`63/63`；最终完整macOS warnings-as-errors gate`259 total / 258 passed / 1 skipped / 0 failed`，唯一skip仍为未启用真实Keychain round-trip。
- macOS、固定iPhone、固定iPad、固定Apple TV、固定Apple Vision Pro warnings-as-errors Debug build全部通过；四个simulator前后均为`Shutdown`。fixture/OpenSpec/generator/reference/dependency/ENet/四SDK C gates全部通过。
- OpenSpec 6.4更新为完成，权威进度`35/61`。下一项为6.5 route/interruption/underrun/packet-loss/teardown handling；6.4不证明实际renderer校正应用或audible synchronized output。

## 2026-07-21 阶段 13 任务 6.5 启动

- 6.4已以`68a4ff8 Bound audio video clock drift`独立提交并推送；确认`HEAD == origin/main`、工作树clean、OpenSpec权威进度`35/61`后进入6.5。
- 6.5新增session级recovery owner统一处理route rebuild、interruption pause/resume、underrun、短loss静音补偿与stop；平台notification到typed event的接线保留阶段16/17，audible真机证据保留6.7。

## 2026-07-21 阶段 13 任务 6.5 完成

- 新增session-owned `SessionAudioRuntime`，统一拥有6.3 `AudioSessionPipeline`与6.4 `MediaClockSynchronizer`：route change与underrun停止旧graph、清queue、重建并reset clock；interruption只在明确`shouldResume`时恢复。
- 短packet loss最多补4包、总计960 frames静音，sequence/RTP timestamp wrap-aware推进且clock只累计实际补入frames；超限直接rebuild，多包补偿中途失败也清除partial schedule与partial clock。
- interruption期间route change返回typed deferred action；stop幂等，stopped后schedule/event fail closed；non-monotonic time、invalid policy/state、graph failure与overflow均结构化。pipeline engine-start failure同时停止partial graph并清除queue/configuration/route。
- focused recovery/pipeline/clock gate最终`33/33`；expanded audio decode/jitter/sync/runtime/resource gate`66/66`。
- 完整macOS warnings-as-errors gate实际为`270 total / 269 passed / 1 skipped / 0 failed`，唯一skip为显式opt-in真实Keychain round-trip；本任务始终使用`env -u LUNEX_RUN_KEYCHAIN_TEST`，继续走file/in-memory fallback。
- macOS、固定iPhone、固定iPad、固定Apple TV、固定Apple Vision Pro warnings-as-errors Debug build全部通过；四个simulator构建前后均为`Shutdown`，没有创建或boot新实例。
- fixture self-test/全树、OpenSpec strict、generator byte-for-byte、LuneX whitespace、production/reference/dependency boundary、固定ENet revision/license/source/header逐文件比对和四SDK strict C syntax gates全部通过。
- OpenSpec 6.5更新为完成，权威进度`36/61`。下一项为6.6 deterministic audio decode/jitter/synchronization/resource-release tests；6.5不证明平台notification接线或audible synchronized hardware output。

## 2026-07-21 阶段 13 任务 6.6 启动

- 6.5已以`463a6fd Handle audio runtime recovery`独立提交并推送；确认`HEAD == origin/main`、工作树clean、OpenSpec权威进度`36/61`后进入6.6。
- 现有decode、jitter、clock、recovery与resource tests均以单层为主；6.6新增跨层production Opus fixture integration，覆盖乱序/wrap、短loss静音、actual decoded-frame clock、pending buffer teardown、迟到completion与decoder close。
- 6.6仍不启动真实Keychain、simulator或Sunshine session，也不把`.dataConsumed`解释为audible playback；6.7保持授权硬件live gate。

## 2026-07-21 阶段 13 任务 6.6 完成

- 新增两条跨层确定性audio integration tests：正常路径覆盖UInt16 sequence/UInt32 RTP双wrap乱序、连续production Opus decode、actual-frame clock、逆序resource teardown和迟到completion；loss路径覆盖typed missing range、exact 240-frame silence、future packet恢复、schedule顺序与零ownership。
- 新增4包连续synthetic stereo Opus fixture及development-only generator packet-index能力，逐包base64和SHA-256回读一致。集成测试暴露`AudioConverter` input proc的`0 packets + noErr`会永久结束连续流；Opus converter不支持prime-method property，最终改为SDK规定的temporary-unavailable callback error并保持codec state，0-frame PCM继续fail closed。
- focused decoder/integration gate`11/11`，expanded audio/RTSP/runtime/resource gate`69/69`；完整macOS warnings-as-errors gate`273 total / 272 passed / 1 skipped / 0 failed`，唯一skip为未启用真实Keychain round-trip，本轮继续使用file/in-memory fallback。
- macOS、固定iPhone、固定iPad、固定Apple TV、固定Apple Vision Pro warnings-as-errors Debug build全部通过；四个simulator构建前后均为`Shutdown`，没有创建或boot新实例。
- fixture self-test/全树、OpenSpec strict、generator byte-for-byte、LuneX whitespace、production/reference/dependency boundary、固定ENet revision/license/source/header、development fixture generator及四SDK strict C syntax gates全部通过。
- OpenSpec 6.6更新为完成，权威进度`37/61`。6.7需要授权硬件audible synchronized audio证据，当前不以fixture或`.dataConsumed`替代；下一项可离线任务为7.1 negotiated input key setup与byte-exact authenticated event serialization。

## 2026-07-21 阶段 13 任务 7.1 启动

- 6.6已以`33d1811 Add deterministic audio integration tests`独立提交并推送；确认`HEAD == origin/main`、工作树clean、OpenSpec权威进度`37/61`后进入7.1，6.7继续等待授权硬件可听证据。
- 当前Sunshine full encrypted control path把input plaintext作为control type `0x0206`的payload，并与start/IDR/control消息共享同一16-byte `rikey`和control-wide UInt32 sequence；7.1禁止另建input sequence，以免同key复用AES-GCM nonce。
- 7.1范围限定为negotiated key/config严格验证、bounded input plaintext packet和显式control sequence的byte-exact authenticated envelope；ordered delivery、coalescing、controller/feedback与focus-loss release分别保留7.2-7.6。
- 初轮focused gate已完成`42/42`。封版审计确认AppModel旧生产默认固定输入key会造成跨session key/nonce安全风险，现已改为每次launch调用安全随机generator，并补充连续launch与generator失败前置阻断测试；plaintext packet同时拒绝零event magic。

## 2026-07-21 阶段 13 任务 7.1 完成

- 新增bounded remote-input plaintext和keyboard mixed-endian serializer；协商配置只接受AES-128、UInt32 key ID、authenticated mode与8...128-byte plaintext。authenticated envelope固定control type `0x0206`并要求调用方显式传入共享control sequence，禁止input另起counter复用AES-GCM nonce。
- 新增独立synthetic keyboard/AES-GCM fixture，Node crypto通过OpenSSL 3.6.3重新生成的plaintext、`CC` nonce、tag/ciphertext和完整control frame均byte-exact一致；mutation、wrong origin/type、invalid key/config/length/magic全部fail closed。
- AppModel移除生产固定`01...10`输入key，默认每个独立launch调用`SecureRemoteInputKeyMaterialGenerator`；连续launch使用不同key，generator failure在network launch前停止。显式override只用于确定性测试。
- targeted修正后`11/11`，expanded input/control/session gate`70/70`；完整macOS warnings-as-errors gate`280 total / 279 passed / 1 skipped / 0 failed`，唯一skip为未启用的一次性真实Keychain round-trip，本任务继续使用file/in-memory fallback。
- macOS、固定iPhone、固定iPad、固定Apple TV、固定Apple Vision Pro warnings-as-errors Debug build全部通过。Xcode构建后iPhone曾短暂显示Booted但在shutdown命令到达前已自动关闭；最终四个固定simulator均为`Shutdown`，未创建或启动第二个同类设备。
- fixture self-test/全树、OpenSpec strict、generator byte-for-byte、LuneX whitespace、production/reference/dependency boundary、固定ENet revision/license/source/header、Node/OpenSSL independent vector与四SDK strict C syntax gates全部通过。
- OpenSpec 7.1更新为完成，权威进度`38/61`。该结果不证明transport delivery、ordering/backpressure、platform mapping、coalescing、focus-loss release或live Sunshine input；下一项为7.2 ordered keyboard/pointer-button/scroll/touch/clipboard delivery。

## 2026-07-21 阶段 13 任务 7.2 启动

- 7.1已以`bf5e111 Authenticate remote input events`独立提交并推送；确认`HEAD == origin/main`、工作树clean、OpenSpec权威进度`38/61`后进入7.2。
- ordered input必须复用`MoonlightControlChannel`actor拥有的control-wide sequence；provider只排队protocol plaintext，不能预先seal frame或持有第二个counter。start时还必须验证协商input key与当前control connection key一致。
- 7.2范围为keyboard、pointer button、vertical/horizontal scroll、Sunshine touch和bounded UTF-8 clipboard的可靠有序delivery；relative/absolute pointer movement、coalescing、controller/feedback与focus-loss release继续保留7.3-7.5。
- 首次定向测试误用`LuneX-macOS` scheme，因该scheme未配置Test action以exit 66结束；已核对工程scheme并改用`LuneXCoreTests`，不重复该失败命令。
- 完成7.2第一轮production实现：新增pointer-button/双轴scroll/normalized touch/per-Unicode-scalar UTF-8 codec、clipboard 4096-byte上限、control共享sequence input发送与bounded FIFO provider；Touch adapter现在携带source reference size并严格clamp pressure到0...1。
- 7.2 targeted warnings-as-errors最终`11/11`通过；覆盖五类事件混合顺序、clipboard多packet不被并发事件插入、wrong/inactive session、key mismatch、stop late send、transport fail current/pending、input uncertain-send sequence不复用及unsupported 7.3/7.4事件拒绝。扩大回归与完整封版门禁尚未运行，任务保持未勾选。
- 首次静态fixture self-test拒绝新向量中的连续长hex；已改为空格分隔byte notation并保留byte-exact内存比较，未放宽secret validator。静态门禁将在修正后从头重跑。

## 2026-07-21 阶段 13 任务 7.2 完成

- 新增完整7.2 event codec与authenticated delivery：keyboard channel `0x02`、mouse `0x03`、touch `0x05`、UTF-8 `0x06`；pointer button、双轴scroll、normalized touch和逐Unicode scalar clipboard均为可靠发送，clipboard总UTF-8上限4096 bytes。
- `MoonlightControlChannel`现在验证input key与active control key一致，并使用同一actor的control-wide sequence完成seal/send；不确定input send先消费sequence。`MoonlightRemoteInputProvider`用bounded FIFO和唯一drain task保证多packet event不可被actor reentrancy插入，transport failure后current/pending/late event全部fail closed。
- targeted最终`11/11`，expanded input/control/session `82/82`；最终完整macOS warnings-as-errors为`292 total / 291 passed / 1 skipped / 0 failed`，唯一skip是未启用的一次性真实Keychain round-trip，本任务继续使用file/in-memory fallback。
- 最终macOS、固定iPhone、固定iPad、固定Apple TV、固定Apple Vision Pro warnings-as-errors Debug build全部通过；固定simulator构建前后均为`Shutdown`，未创建或启动第二个同类设备。
- fixture self-test/全树、OpenSpec strict、generator byte-for-byte、LuneX whitespace、production/reference/dependency boundary、固定ENet revision/license/source/header、Node independent ordered vector与四SDK strict C syntax gates全部通过。
- OpenSpec 7.2更新为完成，权威进度`39/61`。该结果不证明movement/coalescing、controller/feedback、held-state release、平台key mapping/cursor capture或live Sunshine input；下一项为7.3 coalesced relative/absolute pointer movement。

## 2026-07-21 阶段 13 任务 7.3 启动

- 7.2已以`a3c2f4d Deliver ordered remote input events`独立提交并推送，`HEAD == origin/main`、工作树clean、OpenSpec权威进度`39/61`后进入7.3。
- 只读核对moonlight-ios固定common revision `48d7f1a`：relative gen5 magic为`0x07`并累加/Int16分片，absolute magic为`0x05`并保留最新位置与reference dimensions。7.3将在现有bounded provider队尾做安全coalescing，不跨越任何状态转换。
- 7.3第一次focused compile在测试helper处失败：`outboundPackets`返回`RemoteInputOutboundPacket`，测试误把数组直接传给只接受plaintext的delta decoder；已改为显式提取`.plaintext`，未改动production协议行为。

## 2026-07-21 阶段 13 任务 7.3 完成

- 新增gen5 relative/absolute mouse movement codec：relative使用LE magic `0x07`与BE Int16 delta，absolute使用LE magic `0x05`与BE coordinates/reference-size-minus-one；adapter把坐标生成时的source reference size固化进absolute event。
- relative delta最多16包完整分片，正向`32767 * 16`与负向`-32768 * 16`极值均无丢失；合并后超过codec上限会退回独立FIFO delivery。invalid finite/range/reference输入与显式queue/caller/packet上限均fail closed。
- provider只合并pending队尾兼容movement：relative要求相同button snapshot并累加，absolute要求相同button/reference size并保留最新坐标；keyboard/button/scroll/touch/clipboard、relative/absolute互换与状态变化全部形成barrier。所有coalesced continuation只在物理send成功后完成，failure/stop时全部一致失败。
- final targeted warnings-as-errors `29/29`，expanded input/control/session `97/97`；完整macOS warnings-as-errors `303 total / 302 passed / 1 skipped / 0 failed`，唯一skip为未启用真实Keychain round-trip，本任务继续使用file/in-memory fallback。
- macOS、固定iPhone、固定iPad、固定Apple TV、固定Apple Vision Pro warnings-as-errors Debug build全部通过；四个固定simulator最终均为`Shutdown`，没有创建或boot重复设备。
- fixture self-test/全树、OpenSpec strict、generator byte-for-byte、LuneX whitespace、production/reference/dependency boundary、固定ENet revision/license/source/header、四SDK strict C syntax与Node independent movement vector全部通过。
- OpenSpec 7.3更新为完成，权威进度`40/61`。该结果不证明阶段14 `NSEvent`/cursor capture接线、7.4 controller feedback、7.5 held-state release或7.7 live Sunshine已消费movement；下一项为7.4 controller/motion/battery/LED/rumble/trigger-rumble handling。
## 2026-07-21 - Resume stage 13 at OpenSpec 7.4

- Recovered the active goal and file-backed plan after context handoff.
- Confirmed `main` and `origin/main` are both at `8ed1ff4` with a clean worktree.
- Confirmed OpenSpec `implement-moonlight-session-runtime` is ready at `40/61`; 7.4 is the next offline implementation task.
- Re-read every OpenSpec context artifact and the `openspec-apply-change` / `planning-with-files` instructions.
- Started 7.4 with no real-Keychain execution and no simulator boot or creation.

## 2026-07-21 阶段 13 任务 7.4 恢复验收

- 活动 goal 仍为 active；重新读取 planning-with-files、OpenSpec apply 指令及 proposal/design/specs/tasks，change 为 `spec-driven`、权威进度 `40/61`。
- 修复新增 activation/teardown 并发测试的 Swift 6 sending-closure 诊断：在 `Task` 外预先构造 Sendable endpoint/configuration，避免闭包捕获 non-Sendable `XCTestCase self`；生产实现未改动。
- 后续验收继续显式清除 `LUNEX_RUN_KEYCHAIN_TEST`，不再次访问真实 Keychain；只复用既有固定 simulator destination，不创建或主动 boot 新设备。

## 2026-07-21 阶段 13 任务 7.4 完成

- 新增16-slot session controller registry、Apple player-index稳定映射、完整state accumulator、arrival/disconnect fallback以及controller state/motion/battery byte-exact codec；axis delta不会清除held buttons，state和motion只在安全条件下合并。
- control channel严格解析rumble、trigger rumble、motion-rate和RGB LED，按protocol index映射回controller ID并通过容量64的typed stream广播；capability gate阻止不支持的feedback、motion和battery，motion按sensor type等待host rate请求且rate 0重新禁用。
- staged audit补齐feedback-source termination、activation/teardown重入与capability回归；最终targeted warnings-as-errors `44/44`，完整macOS `314 total / 313 passed / 1 explicit Keychain skip / 0 failed`。本轮始终显式清除`LUNEX_RUN_KEYCHAIN_TEST`，未再次访问真实Keychain。
- macOS、固定iPhone、固定iPad、固定Apple TV、固定Apple Vision Pro warnings-as-errors Debug build全部通过。fixture self-test/全树、OpenSpec strict、generator byte-for-byte、LuneX whitespace、production/reference/dependency boundary、固定ENet revision/license/source/header、四SDK strict C syntax与independent Node controller reconstruction全部通过。
- 四个固定simulator最终均为`Shutdown`，且每个指定名称只有一个可用实例；未创建或重复启动设备。OpenSpec 7.4更新为完成，权威进度`41/61`，下一项为7.5 focus loss/disconnect/input failure时释放held remote keys/buttons。
- 7.4只证明serialization、state accumulation、bounded feedback mapping与teardown，不证明Sunshine消费、物理`GCController` rumble/LED/sensor接线、7.5 held-state release或7.7 live互操作。

## 2026-07-21 阶段 13 任务 7.5 启动

- 7.4已以`29ce60b Implement controller input feedback`独立提交并推送；确认`HEAD == origin/main`、工作树clean、OpenSpec权威进度`41/61`后进入7.5。
- 7.5范围限定为provider-owned held key/pointer-button/controller state与ordered release batch：focus owner调用`releaseAll`，显式stop在deactivate前尝试release；input/control已失败时只能清除本地ownership并truthfully teardown，不能声称host收到release。
- held key集合需要显式容量，重复keydown不能重复占用；合成key-up清空modifier mask，pointer按反向press order释放，controller保持连接/active mask但发送neutral state。release batch不得被并发event插入，并保留有界backpressure。
- 恢复后首次定向测试命令因包含清理旧`/tmp`结果的`rm -rf`而被工具策略在进程创建前拒绝；未执行构建或测试。后续改用`mktemp`生成全新隔离目录，不再重复该清理方式。
- 最后加入的共享`releaseOperation`已经在Swift 6 warnings-as-errors下重新编译，`RemoteInputDeliveryTests`保持`34/34`通过；结果为`/tmp/LuneX-7_5-latest.7vYTVe/RemoteInputDelivery.xcresult`。下一步补齐并发release合并与disconnect/failure replacement ownership回归。
- 新增三项并发/断线回归后的首次编译失败：测试把跨actor的`await`直接放进`XCTAssertEqual`同步autoclosure。生产源码无诊断；修复为先读取actor值到局部常量再断言，不重复原写法。
- 并发审计发现release批次在途时仍可接受新keydown并排在release之后，造成focus-loss调用返回后重新形成远端held state；provider现于共享`releaseOperation`或stop期间拒绝新输入。定向warnings-as-errors gate为`37/37`，`0 skipped / 0 failed`，结果`/tmp/LuneX-7_5-release-gate.CU1g2a/RemoteInputDelivery.xcresult`。
- 扩展input/control/session gate覆盖wire codec、delivery、platform adapters、control、provider contract、session cancellation/state和diagnostics，结果`86/86`、`0 skipped / 0 failed`，xcresult为`/tmp/LuneX-7_5-expanded.NTU9u3/InputControlSession.xcresult`。

## 2026-07-21 阶段 13 任务 7.5 完成

- 完整macOS Swift 6 warnings-as-errors gate通过：`322 total / 321 passed / 1 explicit Keychain skip / 0 failed`，结果`/tmp/LuneX-7_5-full-macos.4RRgp9/LuneXCoreTests.xcresult`；通过`env -u LUNEX_RUN_KEYCHAIN_TEST`明确禁用真实Keychain路径。
- macOS、固定iPhone 17 Pro、固定iPad Pro 13-inch (M5)、固定Apple TV、固定Apple Vision Pro隔离Debug warnings-as-errors build全部退出成功。构建后四个固定simulator仍各一个可用实例且全部`Shutdown`，未创建或主动boot任何设备。
- fixture validator self-test/全树、全部四个OpenSpec change strict validation、generator SHA-256 byte-for-byte、LuneX whitespace、production/reference/dependency boundary、固定ENet revision/license/source/header 18文件逐字节比对、四SDK strict C syntax与Node independent release reconstruction全部通过。
- OpenSpec 7.5更新为完成，权威进度`42/61`，下一项为7.6 serialization/ordering/backpressure/focus-loss/remote-feedback verification suite。当前证据只证明provider release serialization、ownership与teardown；不证明平台focus lifecycle已接线或Sunshine实际收到release。

## 2026-07-21 阶段 13 任务 7.6 启动

- 7.5已以`3f95977 Release held remote input state`独立提交并推送，确认`HEAD == origin/main`、工作树clean、OpenSpec权威进度`42/61`后进入7.6。
- 覆盖矩阵确认现有suite已覆盖wire/auth/order/coalescing/backpressure/controller/release/failure主要路径，但remote feedback spec的unsupported-capability diagnostic仍为空白；7.6将补typed diagnostic及满队列release reservation、重复held transition和wrong-session isolation回归。
- 首次7.6定向warnings-as-errors gate完成`40`项：`39 passed / 1 failed`。唯一失败是新queue-reservation测试把wire中little-endian键码按big-endian读取，实际发送顺序仍为`0x50, 0x51, 0x51, 0x50`；已修正测试解码，不修改生产codec。
- 继续补充provider feedback输出`.bufferingNewest(64)`的确定性溢出回归，以及stop/replacement后旧feedback stream不能污染新generation的隔离回归；测试上游可显式使用unbounded buffer，使容量断言只归因于被测provider。
- 第二次7.6定向gate完成`42`项：`41 passed / 1 failed`；queue reservation和旧generation隔离均通过。容量测试在provider仍处理上游时开始消费，因生产/消费并行而收到全部66项；改为等待feedback-source teardown触发的sender deactivation完成标记后再读取已关闭stream，从而确定性验证静止缓冲区的latest-64语义。
- 最终7.6定向Swift 6 warnings-as-errors gate通过`42/42`、零skip/零失败；扩展wire/delivery/platform-adapter/control/provider-contract/session-cancellation/session-state gate通过`91/91`、零skip/零失败。

## 2026-07-21 阶段 13 任务 7.6 完成

- 完整macOS Swift 6 warnings-as-errors gate通过：`327 total / 326 passed / 1 explicit Keychain skip / 0 failed`，结果`/tmp/LuneX-7_6-full-macos.1Dudba/LuneXCoreTests.xcresult`；始终使用`env -u LUNEX_RUN_KEYCHAIN_TEST`，没有再次访问真实Keychain。
- macOS、固定iPhone 17 Pro、固定iPad Pro 13-inch (M5)、固定Apple TV、固定Apple Vision Pro隔离Debug warnings-as-errors build全部退出成功；四个固定simulator最终各为唯一可用同名实例且全部`Shutdown`，未创建或主动boot设备。
- fixture validator self-test/全树、全部四个OpenSpec change strict validation、generator SHA-256 byte-for-byte、LuneX whitespace、production/reference/dependency boundary、固定ENet revision/license/source/header 18文件逐字节比对、四SDK strict C syntax与Node independent input/release reconstruction全部通过。
- OpenSpec 7.6更新为完成，权威进度`43/61`。7.7需要授权live Sunshine keyboard/pointer/controller/feedback证据，不能以fixture替代；下一项可离线任务为8.1 production provider availability injection。

## 2026-07-21 阶段 13 任务 8.1 启动

- 7.6已以`2e5d4af Complete remote input verification`独立提交并推送，确认`HEAD == origin/main`、工作树clean、OpenSpec权威进度`43/61`后进入8.1；7.7保持等待授权live Sunshine证据。
- 8.1限定为typed provider inventory、由实际注入项推导availability以及production factory；不提前实现8.2 pairing UI执行、8.3 session event驱动或8.4 media/input lifetime wiring。
- 审计确认production pairing、session-control与remote-input actor已存在，control可由后两者共享；production video/audio receive provider尚不存在，因此默认stream availability必须继续fail closed。
- 恢复后首轮`AppModelWorkflowTests` Swift 6 warnings-as-errors定向验收通过`7/7`，结果`/tmp/LuneX-8_1-targeted.E65PRj/AppModelWorkflow.xcresult`；命令显式清除`LUNEX_RUN_KEYCHAIN_TEST`，没有访问真实Keychain。
- 进一步审计确认五个provider protocol均为`Sendable`、production factory构造不触网不写文件且control/input共享同一`MoonlightControlChannel`。inventory字段收紧为不可变快照，并补充control/video/audio/input任一缺失均保持stream fail-closed、pairing独立于stream集合的回归。

## 2026-07-21 阶段 13 任务 8.1 完成

- 最终定向`AppModelWorkflowTests + RuntimeProviderContractTests` Swift 6 warnings-as-errors gate通过`12/12`；扩展pairing/application/session control/state/cancellation/recovery gate通过`51/51`，均零skip/零失败。
- 完整macOS gate通过`328 total / 327 passed / 1 explicit Keychain skip / 0 failed`，结果`/tmp/LuneX-8_1-full-macos.pIcPDb/LuneXCoreTests.xcresult`；全程显式清除`LUNEX_RUN_KEYCHAIN_TEST`，没有再次访问真实Keychain。
- macOS、固定iPhone 17 Pro、固定iPad Pro 13-inch (M5)、固定Apple TV、固定Apple Vision Pro隔离Debug warnings-as-errors build全部通过；没有创建或主动boot模拟器，最终四个固定实例均唯一且为`Shutdown`。
- fixture validator self-test/全树、全部OpenSpec change strict validation、generator SHA-256 byte-for-byte、whitespace、production/reference/dependency boundary、固定ENet revision/license/source/header 18文件逐字节比对和四SDK strict C syntax全部通过。
- OpenSpec 8.1更新为完成，权威进度`44/61`。当前production pairing显示available但`submitPairingPIN()`尚未消费provider，这是8.2必须立即修复的中间态；stream因缺production video/audio receiver继续truthfully unavailable。

## 2026-07-21 阶段 13 任务 8.2 启动

- 8.1已以`fa3c68b Inject production runtime providers`独立提交并推送，确认`HEAD == origin/main`、工作树clean、OpenSpec权威进度`44/61`后进入8.2。
- 现有`MoonlightPairingProvider + PersistingPairingProvider`已提供attempt-scoped progress/completion/cancel和认证后save/reload；8.2限定为AppModel identity preparation、event consumption、late-attempt isolation、host/UI更新及SwiftUI阶段/取消控制，不修改clean-room wire protocol。
- PIN只保留在短生命周期UI/request内：构造request后立即清空UI PIN，不写diagnostics、不放入持久session state。正常测试继续显式禁用真实Keychain，使用in-memory/file identity provisioner。
- 恢复后确认上一轮8.2定向结果`22/22`通过；继续审计并修复无active attempt的cancel误改stream phase、错误attempt/host progress未显式cancel provider两项应用层ownership问题。
- 新增duplicate submit、mismatched progress fail-closed/provider cancellation、无active pairing取消不影响stream三项回归；最终定向`AppModelWorkflowTests + PairingStateMachineTests + ClientIdentityLifecycleTests` Swift 6 warnings-as-errors gate通过`25/25`，零skip/零失败，结果`/tmp/LuneX-8_2-targeted-audit.O6PEIA/PairingApplication.xcresult`。测试环境显式清除`LUNEX_RUN_KEYCHAIN_TEST`，未访问真实Keychain。

## 2026-07-21 阶段 13 任务 8.2 完成

- 扩展pairing crypto/transport/persistence/provider/application/identity gate通过`56 total / 55 passed / 1 explicit Keychain skip / 0 failed`；完整macOS Swift 6 warnings-as-errors gate通过`337 total / 336 passed / 1 explicit Keychain skip / 0 failed`，结果`/tmp/LuneX-8_2-full-macos.WqX8tS/LuneXCoreTests.xcresult`。两者均显式清除`LUNEX_RUN_KEYCHAIN_TEST`，未再次访问真实Keychain。
- macOS、固定iPhone 17 Pro、固定iPad Pro 13-inch (M5)、固定Apple TV、固定Apple Vision Pro隔离Debug warnings-as-errors build全部通过；最终四个固定simulator各为唯一可用同名实例且全部`Shutdown`，未创建或主动boot设备。
- fixture validator self-test/全树、全部4个OpenSpec change strict validation、generator SHA-256 byte-for-byte、whitespace、production/reference/dependency boundary、固定ENet revision/license/source/header 18文件逐字节比对和四SDK strict C syntax全部通过。
- OpenSpec 8.2更新为完成，权威进度`45/61`。该验收不代表3.7 live Sunshine pairing/re-pair证据；下一项为8.3 launch/stop UI消费session actor事件并从channel readiness派生phase。

## 2026-07-21 阶段 13 任务 8.3 启动

- 8.2已以`33cbdb3 Connect authenticated pairing UI`独立提交并推送，确认`HEAD == origin/main`、工作树clean、OpenSpec权威进度`45/61`后进入8.3。
- AppModel改为只启动注入的`SessionControlProvider`，将全部event交给generation-scoped `StreamSessionCoordinator.prepare/apply/fail`；旧coordinator HTTP launch client不再位于应用launch路径，避免重复`/launch`。
- 本地stop先失效AppModel session ownership，再由provider执行transport teardown；coordinator新增纯状态的begin/complete local-stop，不发送第二次remote cancel。测试将覆盖partial readiness、完整streaming、remote termination、local stop、duplicate launch和异常/incomplete event stream。

## 2026-07-21 OpenSpec 8.3 定向验收

- Session catch-up确认唯一未同步失败是三处XCTest assertion把`await`置于同步autoclosure。已改为先读取actor-isolated launch count到局部值，再调用断言。
- 修正后的Swift 6 warnings-as-errors定向门通过`28/28`：`AppModelWorkflowTests + SessionStateMachineTests`零失败，结果`/tmp/LuneX-8_3-targeted.YoHao2/SessionApplication.xcresult`。
- 扩展验收前继续补充AppModel层remote termination完整清理、reconnect readiness truth、invalid event order fail-closed与provider stop ownership回归。

## 2026-07-21 阶段 13 任务 8.3 完成

- AppModel现只启动注入的session-control provider，coordinator仅作为generation-scoped reducer；应用launch路径不再调用legacy HTTP launch client，避免第二次`/launch`。本地stop由provider独占transport teardown，reducer begin/complete stop不发送第二次`/cancel`。
- Streaming UI与render active严格要求validated negotiated configuration和control/video/audio/input全部ready；launch accepted、RTSP ready、partial readiness、reconnect均保持非streaming。remote termination、late event、duplicate launch、invalid order、provider throw/incomplete、pre-start参数失败均有确定性回归。
- 最终定向Swift 6 warnings-as-errors gate通过`31/31`，结果`/tmp/LuneX-8_3-targeted-prep.E3wdGa/SessionApplication.xcresult`；扩展session/application gate通过`76/76`，结果`/tmp/LuneX-8_3-expanded.cRdUFi/ExpandedSessionApplication.xcresult`。
- 完整macOS gate通过`344 total / 343 passed / 1 explicit Keychain skip / 0 failed`，结果`/tmp/LuneX-8_3-full-macos.XSr3wo/LuneXCoreTests.xcresult`。全程使用`env -u LUNEX_RUN_KEYCHAIN_TEST`，没有再次访问真实Keychain。
- macOS、固定iPhone、固定iPad、固定Apple TV、固定Apple Vision Pro Debug warnings-as-errors build全部通过，根目录`/tmp/LuneX-8_3-platform-builds.41TB2V`；四个固定simulator前后均唯一且为`Shutdown`，未创建或主动boot额外设备。
- fixture self-test/全树、全部4个OpenSpec对象strict validation、generator SHA-256 byte-for-byte、whitespace、production/reference/dependency boundary、固定ENet revision/license/source/header 18文件逐字节比对和四SDK strict C syntax全部通过。
- OpenSpec 8.3更新为完成，权威进度`46/61`。该验收不代表8.4统一video/audio/input lifetime或任何live Sunshine端到端证据；下一项为8.4。

## 2026-07-21 阶段 13 任务 8.4 启动

- 8.3已以`2e3fe2f Connect session control UI`独立提交并推送，确认`HEAD == origin/main`、工作树clean、OpenSpec权威进度`46/61`后进入8.4。
- 代码盘点确认VideoToolbox/Metal frame delivery、AudioToolbox/AVAudioEngine runtime和remote-input actor均已存在，但AppModel只消费control provider，production inventory仍缺具体video/audio receiver，因此stream availability保持truthfully false。
- 8.4限定为统一session-owned media environment：聚合control/media readiness，启动/消费receiver与native processor，激活input/feedback，连接decoded frame presentation，并在local stop、remote termination、reconnect或failure时一次性清理。不得用control provider的`.all`绕过真实media readiness。
- 第一版实现已加入`NativeSessionMediaEnvironment`、normalized video assembly/VideoToolbox processor、jitter/Opus/AVAudioEngine processor和thread-safe decoded-frame presentation source；AppModel开始独立聚合control与media readiness，并在四类terminal/reconnect路径统一停止media environment。
- `MetalStreamSurface`已接入presentation source，以Core Image on Metal做初始native SDR frame呈现与fit/fill定位；HDR transfer/headroom mapping仍明确留在阶段15。

## 2026-07-21 OpenSpec 8.4 生命周期审计

- 最新连续Opus fixture加入后，定向Swift 6 warnings-as-errors门通过`43/43`，结果`/tmp/LuneX-8_4-targeted-audio.EvVZVP/MediaEnvironment.xcresult`；使用`env -u LUNEX_RUN_KEYCHAIN_TEST`，未访问真实Keychain。
- 新增并修复pending input startup主动teardown、feedback stream提前结束fail closed、media event consumer取消自动teardown三类生命周期边界。
- 补充processor创建后注册竞态和native video/audio factory半初始化失败回滚；下一步重新运行定向门并继续expanded/full验收。
- 生命周期修复后的定向门通过`45/45`，结果`/tmp/LuneX-8_4-targeted-lifecycle.IuPDOR/MediaEnvironment.xcresult`。进一步将media readiness从receiver创建收紧为input启动、VideoToolbox frame submission和PCM graph schedule三项独立里程碑；首轮readiness门为`44 passed / 1 failed`，唯一失败是测试未把jitter buffer在`.closed`时的成功flush计入ready，已修正测试观测而未放宽production策略。
- readiness修正后定向门重新通过`45/45`，结果`/tmp/LuneX-8_4-targeted-final.5qauT6/MediaEnvironment.xcresult`。Metal presenter补充锁定状态快照和idle/no-frame clear-only提交，避免停止后旧drawable残留；下一步执行扩展media/application gate。
- 扩展media/application gate通过`169/169`，结果`/tmp/LuneX-8_4-expanded.E5zYnp/ExpandedMedia.xcresult`；完整macOS通过`358 total / 357 passed / 1 explicit Keychain skip / 0 failed`，结果`/tmp/LuneX-8_4-full-macos.i7xdkX/LuneXCoreTests.xcresult`。
- 首轮app-target平台构建在macOS/iPhone发现`makeCoordinator()`返回private presenter的访问级别错误；已中止后续重复失败并将presenter改为fileprivate，下一轮使用首错即停的串行脚本。

## 2026-07-21 阶段 13 任务 8.4 完成

- 最终定向Swift 6 warnings-as-errors gate通过`45/45`，结果`/tmp/LuneX-8_4-targeted-final.5qauT6/MediaEnvironment.xcresult`；扩展video/audio/input/application gate通过`169/169`，结果`/tmp/LuneX-8_4-expanded.E5zYnp/ExpandedMedia.xcresult`。
- 完整macOS gate通过`358 total / 357 passed / 1 explicit Keychain skip / 0 failed`，结果`/tmp/LuneX-8_4-full-macos.i7xdkX/LuneXCoreTests.xcresult`；所有测试均使用`env -u LUNEX_RUN_KEYCHAIN_TEST`，没有再次访问真实Keychain。
- macOS、固定iPhone 17 Pro、固定iPad Pro 13-inch (M5)、固定Apple TV、固定Apple Vision Pro Debug warnings-as-errors构建全部通过，根目录`/tmp/LuneX-8_4-platform-builds-r4.90Lsdh`。四个固定simulator构建前后均唯一且为`Shutdown`，未创建或主动boot设备。
- fixture validator self-test/全树、4个OpenSpec change strict validation、generator SHA-256 byte-for-byte、LuneX whitespace、production/reference/dependency boundary、固定ENet revision/license/source/header 18文件逐字节比对与四SDK strict C syntax全部通过。
- OpenSpec 8.4更新为完成，权威进度`47/61`。production仍缺具体video/audio network receiver，因此stream availability继续fail closed；5.8/6.7/7.7和9.2-9.3 live证据、阶段15 HDR与阶段16空间音频均未被此验收替代。下一项为8.5 actionable diagnostics。

## 2026-07-21 阶段 13 任务 8.5 启动

- 8.4已以`5a0065e Connect unified media environment`独立提交并推送；确认`HEAD == origin/main`、工作树clean、OpenSpec权威进度`47/61`后进入8.5。
- 现有底层`RuntimeDiagnosticsRecorder`支持severity、stage、code、字段隐私与secret redaction，但AppModel和SwiftUI主要消费字符串型`DiagnosticsStore`；pairing/session/media失败尚未稳定分类为pairing/transport/decoder/audio/input，也没有一致的用户恢复建议。
- 8.5范围限定为无秘密、可执行的应用诊断模型、错误分类和原生UI呈现；不得把endpoint、PIN、证书、session key、packet payload或底层错误任意字符串直接暴露给UI，不改变production provider可用性和live证据边界。
- 首轮定向warnings-as-errors编译在测试启动前失败：三处`failPairingAttempt`实参将factory静态值简写为`ApplicationDiagnostic`成员。已改用完整`ApplicationDiagnosticFactory.*`限定名；失败证据保留在`/tmp/LuneX-8_5-targeted.sBydHN/ActionableDiagnostics.xcresult`，下一轮使用新隔离目录。
- 第二轮定向门完成编译并运行`35`项，`34 passed / 1 failed`；唯一失败是既有input-key测试依赖错误文案含`failed`。现将未知key-generator错误按launch request上下文收敛为typed `invalidInputKey`，测试改验input类别/code/action与安全摘要；失败证据为`/tmp/LuneX-8_5-targeted-r2.gqlNH9/ActionableDiagnostics.xcresult`。
- 第三轮定向Swift 6 warnings-as-errors门通过`35/35`，结果`/tmp/LuneX-8_5-targeted-r3.WPVd6C/ActionableDiagnostics.xcresult`。门后审计继续移除pairing progress的raw failure message，并在DiagnosticsStore统一append边界加入嵌入secret过滤；新增plain-message redaction回归后需再次复验。
- 最终定向Swift 6 warnings-as-errors门通过`37/37`，结果`/tmp/LuneX-8_5-targeted-r4.uq3yAO/ActionableDiagnostics.xcresult`；新增回归确认raw pairing failure和普通diagnostic message中的secret marker均不会进入UI可见事件。
- macOS产品target Swift 6 warnings-as-errors构建通过，隔离DerivedData为`/tmp/LuneX-8_5-macos-build.B1Am9X`；该证据只证明当前应用target可编译，8.5仍需扩展/完整测试、五平台构建与仓库门禁后才能勾选。

## 2026-07-21 阶段 13 任务 8.5 完成

- 最终生产差异审计确认pairing/session/media底层任意错误字符串不再直达UI；正常stop和remote termination补充清除陈旧`errorMessage`/`actionMessage`。进一步移除通用AppModel诊断中的host地址/名称与任意persistence/catalog错误文本，并从audio snapshot诊断移除输出设备名；最终定向Swift 6 warnings-as-errors门通过`48/48`，结果`/tmp/LuneX-8_5-targeted-r6.eL0Y01/ActionableDiagnostics.xcresult`。
- 修改后的完整macOS门通过`365 total / 364 passed / 1 explicit Keychain skip / 0 failed`，结果`/tmp/LuneX-8_5-full-r2.63vSlE/LuneXCoreTests.xcresult`；全程使用`env -u LUNEX_RUN_KEYCHAIN_TEST`，没有再次访问真实Keychain。
- 修改后的macOS、固定iPhone 17 Pro、固定iPad Pro 13-inch (M5)、固定Apple TV、固定Apple Vision Pro Debug warnings-as-errors构建全部通过，根目录`/tmp/LuneX-8_5-platform-builds-r2.0YDpJn`；构建前后四个simulator各唯一且为`Shutdown`，未创建或主动boot设备。
- fixture validator self-test/全树、全部OpenSpec strict validation、generator SHA-256 byte-for-byte、whitespace、production/reference/dependency boundary、固定ENet revision/license/source/header 18文件逐字节比对、四SDK strict C syntax与固定simulator唯一/Shutdown复核全部通过，最终门禁目录`/tmp/LuneX-8_5-repo-gates-r4.uUbuvL`。
- OpenSpec 8.5更新为完成，权威进度`48/61`。production仍缺具体video/audio network receiver，因此stream availability保持fail closed；3.7/5.8/6.7/7.7与9.2-9.3 live证据、阶段15 HDR、阶段16空间音频和阶段17移动连续性均未被本次验收替代。下一项为8.6。

## 2026-07-21 阶段 13 任务 8.6 启动

- 生产inventory审计确认stream availability必须同时包含session control、video receive、audio receive与remote input；默认factory只有pairing/control/input，因video/audio缺失继续truthfully unavailable。
- `launchSelectedApp()`的availability guard位于remote input key生成、coordinator prepare、control start和media environment start之前；`beginPairing()`的pairing-provider guard位于identity provision之前。8.6将补充四种单provider缺失矩阵与pairing缺失的无副作用证明，不以availability位图断言单独替代执行路径测试。

## 2026-07-21 阶段 13 任务 8.6 完成

- pairing缺provider回归确认identity provision未启动、host仍未配对且无pinned identity；四种required stream provider逐一缺失矩阵确认input-key generation、control start、media environment start与legacy launch计数全部为零，状态保持library/disconnected/idle并输出稳定诊断。
- 定向Swift 6 warnings-as-errors gate通过`28/28`，结果`/tmp/LuneX-8_6-targeted.n7wWDn/FailClosedProviders.xcresult`；扩展provider/session/cancellation/recovery/media/diagnostics gate通过`84/84`，结果`/tmp/LuneX-8_6-expanded.geI1yx/FailClosedExpanded.xcresult`。
- 完整macOS gate通过`366 total / 365 passed / 1 explicit Keychain skip / 0 failed`，结果`/tmp/LuneX-8_6-full.lDob5D/LuneXCoreTests.xcresult`；所有测试显式使用`env -u LUNEX_RUN_KEYCHAIN_TEST`，没有再次访问真实Keychain。
- macOS、固定iPhone 17 Pro、固定iPad Pro 13-inch (M5)、固定Apple TV、固定Apple Vision Pro Debug warnings-as-errors构建全部通过，根目录`/tmp/LuneX-8_6-platform-builds.E5pqLP`；构建前后四个simulator各唯一且为`Shutdown`，未创建或主动boot设备。
- fixture validator self-test/全树、4个OpenSpec change strict validation、generator逐字节一致、whitespace、production/reference/dependency boundary、固定ENet revision/license/source/header 18文件逐字节比对与四SDK strict C syntax全部通过，最终门禁目录`/tmp/LuneX-8_6-repo-gates-r2.bTa33D`。首次simulator `jq all`表达式和首次OpenSpec JSON断言错误均在执行状态修改前停止，已记录并用新表达式/新隔离目录完整复验。
- OpenSpec 8.6更新为完成，权威进度`49/61`。production仍因缺具体video/audio network receiver保持fail closed；3.7/5.8/6.7/7.7与9.2-9.3 live证据仍未完成。下一项为9.1禁用live-host和真实Keychain路径的正常离线测试。

## 2026-07-21 阶段 13 任务 9.1 启动

- 全仓库测试环境开关审计确认普通XCTest目前只有`LUNEX_RUN_KEYCHAIN_TEST=1`可启用真实Keychain round-trip；9.2所需live-host XCTest尚未实现，因此默认套件没有可被环境误触发的discovery/pairing/launch网络路径。
- 9.1使用全新隔离DerivedData/xcresult并显式`env -u LUNEX_RUN_KEYCHAIN_TEST`运行完整macOS套件；唯一允许的skip必须是已验证过一次、后续按用户约束不再访问的真实Keychain测试。

## 2026-07-21 阶段 13 任务 9.1 完成

- 独立完整macOS Swift 6/Clang warnings-as-errors离线套件通过`366 total / 365 passed / 1 skipped / 0 failed`，结果`/tmp/LuneX-9_1-offline.vWMJzq/OfflineTests.xcresult`；命令显式使用`env -u LUNEX_RUN_KEYCHAIN_TEST`。
- 通过xcresult tests树精确确认唯一skip为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，提示为一次性授权Keychain验证；没有其他skip、expected failure或失败。
- OpenSpec 9.1更新为完成，权威进度`50/61`。当前没有9.2 live-host XCTest，且production仍缺具体video/audio receiver，因此9.1不替代3.7/5.8/6.7/7.7/9.2/9.3；下一可执行项为9.4 Debug/Release五平台构建。

## 2026-07-21 阶段 13 任务 9.4 启动

- 9.2/9.3因缺少opt-in live-host XCTest、具体授权host状态和production video/audio receiver保持未完成；不阻塞独立可执行的9.4 build验证。
- 9.4采用严格口径：macOS、固定iPhone、固定iPad、固定Apple TV、固定Apple Vision Pro均分别执行Debug与Release warnings-as-errors构建，共10次；每次使用独立DerivedData，构建前后只读验证固定simulator唯一且`Shutdown`，不创建或主动boot设备。

## 2026-07-21 阶段 13 任务 9.4 完成

- macOS、固定iPhone 17 Pro、固定iPad Pro 13-inch (M5)、固定Apple TV、固定Apple Vision Pro均通过Debug与Release Swift/Clang warnings-as-errors构建，共10次成功；每次使用独立DerivedData，证据根目录`/tmp/LuneX-9_4-builds.nQRQAw`。
- 构建前后只读`simctl list`均确认四个固定simulator名称各只有一个available实例、UUID精确匹配且为`Shutdown`；未创建或主动boot设备。
- OpenSpec 9.4更新为完成，权威进度`51/61`。该证据是多平台源码/优化配置编译证明，不替代真机签名、运行、live Sunshine媒体、硬件能力、性能功耗或发布就绪证明；下一项为9.5独立模拟器单实例验收。

## 2026-07-21 阶段 13 任务 9.5 启动

- 9.5不执行build、create、boot或shutdown；只读比较9.4构建前/后和当前三份`simctl list devices available --json`，严格验证四个固定名称各一项、UUID不变、状态始终`Shutdown`且当前所有available simulator的Booted计数为零。

## 2026-07-21 阶段 13 任务 9.5 完成

- 9.4构建前、构建后与9.5当前三份CoreSimulator JSON经固定字段规范化后逐字节一致；iPhone 17 Pro、iPad Pro 13-inch (M5)、Apple TV、Apple Vision Pro各有一个available同名实例，预期UUID各出现一次且全部`Shutdown`。
- 当前全部available simulator的Booted计数为`0`；审计没有执行create、clone、boot、shutdown、delete或build，证据目录`/tmp/LuneX-9_5-simulator-audit.ZqTbQP`。
- OpenSpec 9.5更新为完成，权威进度`52/61`。该证据限定于已配置available runtime的模拟器inventory稳定性，不证明真机行为；下一项为9.6 strict/static/resource-leak验证。

## 2026-07-21 阶段 13 任务 9.6 启动

- 9.6独立矩阵包括：全部OpenSpec strict validation、macOS Debug/Release `xcodebuild analyze`、完整离线ASan套件、并发/ownership相关TSan选择集，以及开启MallocScribble/MallocGuardEdges/MallocStackLogging的resource teardown选择集。
- sanitizer和resource测试继续显式`env -u LUNEX_RUN_KEYCHAIN_TEST`，不接触真实Keychain或live host；每项使用独立DerivedData/xcresult。资源选择集覆盖SessionResourceTracker、NetworkChannel、VideoDecompression/DecodePipeline、AudioPipeline/Recovery、SessionMediaEnvironment、SessionCancellation/Recovery与RemoteInputDelivery。

## 2026-07-21 阶段 13 任务 9.6 完成

- 全部4个OpenSpec change strict validation通过；macOS Debug/Release `xcodebuild analyze`均成功。结构化plist显示自有`LuneXENetBridge`为零finding，固定且与上游逐字节一致的ENet在两配置均稳定产生4项：3个dead store和`unix.c:867`潜在null dereference；后者对LuneX唯一`enet_host_service`调用路径不可达但保留为披露的依赖风险。静态证据目录`/tmp/LuneX-9_6-static.FSakvB`。
- 完整ASan+LeakSanitizer离线套件通过`366 total / 365 passed / 1 explicit Keychain skip / 0 failed`，无sanitizer诊断，结果`/tmp/LuneX-9_6-asan.BsZfIn/ASan.xcresult`。
- 完整TSan首轮没有race报告，但decoder-drop测试只等待drop计数并在合法actor reentrancy中间态断言IDR状态，产生`364 passed / 1 failed / 1 skipped`。测试改为等待decoder释放、awaiting/outstanding IDR、pipeline/requester计数完整收敛；目标TSan通过`1/1`，结果`/tmp/LuneX-9_6-tsan-targeted.ezI7C9/TSanTargeted.xcresult`。
- 修正后完整TSan通过`366 total / 365 passed / 1 explicit Keychain skip / 0 failed`且无ThreadSanitizer报告，结果`/tmp/LuneX-9_6-tsan-r2.YItvB8/TSan.xcresult`。MallocScribble/GuardEdges/StackLogging/heap-check/error-abort下resource ownership/teardown选择集通过`174/174`且无malloc诊断，结果`/tmp/LuneX-9_6-resource.lwHznn/ResourceOwnership.xcresult`。
- 最终未启用sanitizer的完整macOS warnings-as-errors套件通过`366 total / 365 passed / 1 explicit Keychain skip / 0 failed`，结果`/tmp/LuneX-9_6-final-normal.8ZuCiE/FinalNormal.xcresult`；OpenSpec strict复核仍为`4/4`。
- OpenSpec 9.6更新为完成，权威进度`53/61`。下一可执行项为9.7更新跟踪、记录剩余平台体验工作并封版提交；live-host/hardware任务仍保持未完成。

## 2026-07-21 阶段 13 任务 9.7 启动

- 审计现有OpenSpec inventory：bootstrap、critical audit remediation、identity/trust/macOS lifecycle均all done；session runtime为`53/61`，阶段14–20路线图中的change名称尚未创建为OpenSpec对象。
- 9.7将把阶段13已证明/未证明边界、7项live/hardware blocker、阶段14–20离线可推进与硬件完成门、以及阶段18–20具体交付补入`docs/runtime-completion-roadmap.md`，再同步三份跟踪文件与OpenSpec task状态。

## 2026-07-21 阶段 13 任务 9.7 完成

- `docs/runtime-completion-roadmap.md`新增阶段13–20当前证据/缺口表、离线推进与硬件完成门边界，并补齐阶段18 tvOS/visionOS、阶段19原生产品工作流/无障碍、阶段20 Release性能质量的可执行交付和验收项。
- 阶段13阶段级自验收结论：离线/runtime foundation通过；live/hardware未通过。1.1、3.7、5.8、6.7、7.7、9.2、9.3继续保持pending，production因缺video/audio network receiver继续fail closed，不以9.1/9.4/9.5/9.6证据替代。
- OpenSpec 9.7更新为完成，权威进度`54/61`；全部4个现有OpenSpec change strict validation通过。等待授权host/hardware期间，下一可执行工作为创建阶段14 `integrate-macos-native-input-lifecycle` change并推进确定性实现。

## 2026-07-21 阶段 14 OpenSpec 启动

- 创建`integrate-macos-native-input-lifecycle`，完成proposal、design、`macos-native-input-capture`、`macos-session-lifecycle-control`、`stream-coordinate-transform`三项spec与29项tasks；artifact状态apply-ready，单change strict validation通过。
- 现状审计确认AppKit notification只驱动render state；真实NSEvent、balanced cursor ownership、active-session input sink、focus-loss release barrier、actual stream-surface transform与decoder pause/resume均未接线。阶段14保持production fail closed并保留stage13 live证据缺口。
- 后续按OpenSpec任务逐项独立验收/提交/推送；当前第一项为1.1 macOS event/modifier/shortcut/cursor/coordinate/multi-window ownership合同清单。

## 2026-07-21 阶段 14 任务 1.1 启动

- 对照Xcode 26.4 AppKit/CoreGraphics SDK头文件与repository-owned实现，清点window/application notification作用域、`NSEvent`键码/修饰键/坐标/滚轮语义、cursor关联恢复和多窗口observer/generation所有权；不修改运行行为。

## 2026-07-21 阶段 14 任务 1.1 完成

- 新增`docs/runtime/macos-input-lifecycle-contract.md`，固化实际stream-surface scoped capture、view-to-backing坐标、共享revisioned video rect、bounded FIFO、focus-loss `releaseAll` barrier、balanced cursor owner及旧window/session generation拒绝合同。
- 明确`NSEvent.keyCode`是macOS device-independent key number而非远端Win32/GameStream键码；当前adapter/wire raw passthrough在真实接线前必须由显式translation替代，未知键fail closed。
- OpenSpec 1.1标记完成，权威进度`1/29`；本任务仅改文档和跟踪，没有触碰production source、generator或project。下一项为1.2 revisioned coordinate snapshot和共享fit/fill video rectangle resolver。

## 2026-07-21 阶段 14 任务 1.2 启动

- 设计平台无关的immutable coordinate point/rect、resolved drawable video rect/source crop、revisioned snapshot与变更驱动publisher；保持现有`RenderTransform`和renderer/mapper行为到1.3再迁移。

## 2026-07-21 阶段 14 任务 1.2 完成

- 新增`Sources/LuneXPlatform/StreamCoordinateSnapshot.swift`：fit/fill resolver统一计算drawable bounds、destination video rect、source crop和scale；publisher仅在source/drawable/mode变更时推进revision，无效geometry和`UInt64`溢出均fail closed。
- 新增`StreamCoordinateSnapshotTests`并同步generator/project；focused Swift 6/Clang warnings-as-errors测试通过`6/6`，无skip，结果`/tmp/LuneX-14-1_2-focused.v2yyeb/StreamCoordinateSnapshot.xcresult`。所有测试显式`env -u LUNEX_RUN_KEYCHAIN_TEST`，未再次访问真实Keychain。
- macOS、固定iPhone 17 Pro、固定iPad Pro 13-inch (M5)、固定Apple TV和固定Apple Vision Pro Debug warnings-as-errors隔离构建全部通过，证据根目录`/tmp/LuneX-14-1_2-platforms.behknb`；只执行build，没有创建、boot或运行simulator。构建前后四个固定UUID均唯一且为`Shutdown`，全局Booted计数为0。
- OpenSpec 1.2标记完成，权威进度`2/29`。resolver尚未接入renderer或`InputMapper`，生产letterbox拒绝和共享rectangle仍待1.3；下一项为1.3消费接线。

## 2026-07-21 阶段 14 任务 1.3 完成

- `StreamRenderState`接管revisioned snapshot publisher；`StreamMetalPresenter`锁内只保存render policy与immutable snapshot，按共享`resolvedVideo.videoRect`定位画面，并在snapshot drawable与真实texture尺寸不一致时clear-only。`InputMapper`、macOS与touch adapter改为消费同一snapshot，fit黑边拒绝且fill按共享crop映射。
- focused Swift 6 warnings-as-errors gate首轮因浮点exact断言和缺source geometry的测试前置失败，修正测试后通过`17/17`，结果`/tmp/LuneX-14-1_3-focused-r2.849jv5/SharedCoordinateContract.xcresult`。完整macOS gate通过`375 total / 374 passed / 1 explicit Keychain skip / 0 failed`，结果`/tmp/LuneX-14-1_3-full.1e0xb6/LuneXCoreTests.xcresult`；全部测试使用`env -u LUNEX_RUN_KEYCHAIN_TEST`。
- 首次五平台build误用不存在的`LuneX` scheme，在编译与simulator运行前一致终止；枚举工程后改用四个实际App scheme。macOS、固定iPhone 17 Pro、固定iPad Pro 13-inch (M5)、固定Apple TV与固定Apple Vision Pro Debug warnings-as-errors构建全部通过，隔离根目录前缀`/tmp/LuneX-14-1_3-platforms-r2.*`。
- 构建前后固定simulator均唯一、available且`Shutdown`，全局Booted为0；未create、boot或run simulator。全部5个OpenSpec change strict通过，generator前后project SHA-256同为`0751025a3a049f7312b2552eac3d944c043a0f1e39d75ee388a714d524609633`，whitespace、旧mapper transform扫描与production/reference边界通过。
- OpenSpec 1.3标记完成，权威进度`3/29`。本任务不证明AppKit backing conversion、完整resize/stale revision矩阵或live Sunshine输入；下一项为1.4确定性坐标测试矩阵。

## 2026-07-21 阶段 14 任务 1.4 启动

- 1.3已以`8bc349a`独立提交并推送，确认`HEAD == origin/main`且工作树clean。1.4在既有测试文件内扩展确定性矩阵，不提前实现属于4.3的AppKit capture或`convertToBacking`。
- 矩阵覆盖fit上下/左右letterbox拒绝、fill drawable边界与source crop边界一致、1x/2x backing点和drawable同步缩放、source/drawable全部非正维度、resize前后immutable snapshot隔离、scale-mode revision与旧snapshot保留。

## 2026-07-21 阶段 14 任务 1.4 完成

- focused Swift 6 warnings-as-errors坐标矩阵通过`13/13`，结果`/tmp/LuneX-14-1_4-focused.4m6B2p/CoordinateMatrix.xcresult`；Xcode中途对已断开物理设备的notification service警告未影响指定macOS destination或结构化结果。
- 完整macOS suite通过`381 total / 380 passed / 1 explicit Keychain skip / 0 failed`，结果`/tmp/LuneX-14-1_4-full.7Fq2Qs/LuneXCoreTests.xcresult`；测试树精确确认唯一skip为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`。命令显式移除`LUNEX_RUN_KEYCHAIN_TEST`，未再次访问真实Keychain。
- 全部5个OpenSpec change strict通过；generator前后project SHA-256保持`0751025a3a049f7312b2552eac3d944c043a0f1e39d75ee388a714d524609633`，whitespace通过。任务只改测试，1.3刚通过的五平台production build仍适用，不重复运行相同App build作为新证据。
- 固定iPhone/iPad/Apple TV/Apple Vision Pro均保持唯一且`Shutdown`，全局Booted为0，未create、boot或run simulator。OpenSpec 1.4标记完成，权威进度`4/29`；下一项为2.1生命周期directive。

## 2026-07-21 阶段 14 任务 2.1 启动

- 1.4已以`c252806`独立提交并推送，确认`HEAD == origin/main`且工作树clean。现有`LifecycleRenderPolicyResolver`只返回renderer policy，无法原子表达decoder submission、presentation clear/throttle与input release admission。
- 2.1新增平台无关的闭合directive和reason枚举：inactive、occluded/hidden、drawable unavailable、visible unfocused与active focused五种优先级状态；本任务只建立值合同和确定性resolver，不接入media environment或提前声称decoder已暂停。

## 2026-07-21 阶段 14 任务 2.1 完成

- 新增`SessionLifecycleClosureReason`、`VideoProcessingDirective`、`PresentationLifecycleDirective`、`InputLifecycleDirective`与聚合`SessionLifecycleDirective`；legacy `LifecycleRenderPolicyResolver`委托给新resolver，避免render-only路径漂移。
- focused Swift 6 warnings-as-errors gate通过`11/11`，结果`/tmp/LuneX-14-2_1-focused.P7k3Jd/LifecycleDirective.xcresult`。完整macOS suite通过`387 total / 386 passed / 1 explicit Keychain skip / 0 failed`，结果`/tmp/LuneX-14-2_1-full.K9t2Vn/LuneXCoreTests.xcresult`；测试树确认唯一skip仍为一次性真实Keychain测试。
- macOS、固定iPhone 17 Pro、固定iPad Pro 13-inch (M5)、固定Apple TV、固定Apple Vision Pro Debug warnings-as-errors构建全部通过，隔离目录前缀`/tmp/LuneX-14-2_1-builds.*`。只执行build，未boot或run simulator。
- 全部5个OpenSpec change strict通过，generator前后project SHA-256保持`0751025a3a049f7312b2552eac3d944c043a0f1e39d75ee388a714d524609633`，whitespace通过；固定simulator名称/UUID各唯一、全部`Shutdown`且全局Booted为0。OpenSpec 2.1标记完成，权威进度`5/29`，下一项为2.2 generation-scoped application。

## 2026-07-21 阶段 14 任务 2.2 启动

- 2.1已以`9350326`独立提交并推送，确认`HEAD == origin/main`且工作树clean。审计确认仅以session UUID校验不足以拒绝同一UUID停止后重用时的迟到lifecycle callback。
- 新增`SessionLifecycleApplication`同时携带session ID、media generation、lifecycle revision和闭合directive；environment只允许当前generation的revision前进，完全相同application幂等，旧generation、revision回退与同revision冲突内容fail closed。snapshot只公开无秘密application元数据，SwiftUI不接触provider。

## 2026-07-21 阶段 14 任务 2.2 完成

- environment新增generation/revision-scoped `applyLifecycle`入口与snapshot metadata；同session UUID replacement generation会拒绝旧application，完全相同重复幂等，revision回退或同revision冲突内容返回typed stale error。
- 首轮focused在测试启动前因新增media error未同步`ApplicationDiagnostics`穷尽switch而失败，结果`/tmp/LuneX-14-2_2-focused.T8m4Rx/LifecycleApplication.xcresult`；补稳定`media_lifecycle_stale`安全诊断和回归后，focused通过`24/24`，结果`/tmp/LuneX-14-2_2-focused-r2.W5n9Lc/LifecycleApplication.xcresult`。
- 完整macOS suite通过`390 total / 389 passed / 1 explicit Keychain skip / 0 failed`，结果`/tmp/LuneX-14-2_2-full.R3q7Hs/LuneXCoreTests.xcresult`；唯一skip经test tree确认仍为一次性真实Keychain测试，命令显式移除`LUNEX_RUN_KEYCHAIN_TEST`。
- macOS和固定iPhone/iPad/Apple TV/Apple Vision Pro Debug warnings-as-errors构建全部通过，目录前缀`/tmp/LuneX-14-2_2-builds.*`。全部5个OpenSpec strict、generator byte-stability、whitespace与固定simulator唯一/Shutdown/全局Booted=0通过。OpenSpec 2.2标记完成，权威进度`6/29`；下一项为2.3实际video pause/clear/IDR恢复。

## 2026-07-21 阶段 14 任务 2.3 启动

- 2.2已以`a5061f4`独立提交并推送，确认`HEAD == origin/main`且工作树clean。2.3沿receiver consumer、native processor、decode pipeline和presentation source真实所有权链实现drain/pause/clear/IDR恢复。
- 审计发现presentation source只校验session UUID和decoder generation；同UUID replacement可能让旧callback与新decoder generation编号碰撞，因此本任务同时加入media generation fence。
- 首轮focused命令在编译前因误用无test action的`LuneX-macOS` scheme终止，且命令尾部使用了zsh只读变量`status`；结果目录`/tmp/LuneX-14-2_3-focused.baExrT`。已确认改用`LuneXCoreTests`和普通变量`rc`在新目录重跑。
- 第二轮focused进入Swift编译后只发现新测试在`XCTAssertEqual`非并发autoclosure内直接`await` actor属性，结果`/tmp/LuneX-14-2_3-focused-r2.JqZ90f/LifecycleVideo.xcresult`；改为先await局部值再同步断言。
- 五平台build前只读simulator审计再次误把`as $ids`写在对象literal字段内，`jq`编译失败但原始JSON已保存且没有设备操作；这是14.1.2已知错误的重复，已改为对象外先绑定并规定后续复用固定脚本。

## 2026-07-21 阶段 14 任务 2.3 完成

- lifecycle application现在通过environment的revision reservation调用generation-owned video processor；receiver consumer持续读取，processor在pause期间重置partial assembly并跳过decode submission。恢复只通过既有session control provider请求一个fresh IDR，重复active directive不重复请求。
- `VideoDecodePipeline`新增可恢复pause/resume、paused access-unit drop、lifecycle-token submission invalidation和IDR合并；pause中途作废的submission不会误触发session teardown。presentation source同时按session/media/decoder generation过滤，并记录已作废decoder generation以拒绝极晚旧`sessionStarted`与frame。
- 最终focused Swift 6/Clang warnings-as-errors gate通过`26/26`，无skip，结果`/tmp/LuneX-14-2_3-focused-r5.qApHqK/LifecycleVideo.xcresult`。完整macOS通过`393 total / 392 passed / 1 explicit Keychain skip / 0 failed`，结果`/tmp/LuneX-14-2_3-full.PObxun/LuneXCoreTests.xcresult`；唯一skip经test tree精确确认是`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`。
- macOS与固定iPhone 17 Pro、iPad Pro 13-inch (M5)、Apple TV、Apple Vision Pro Debug warnings-as-errors构建全部通过，证据根目录`/tmp/LuneX-14-2_3-builds.Y4xnSH`。构建前后simulator JSON逐字节一致，四个名称各一、固定UUID均`Shutdown`、全局`Booted=0`，未create、boot、run或shutdown设备。
- 5个OpenSpec change strict validation、generator byte-stability、whitespace与production/reference边界全部通过；project SHA-256前后均为`0751025a3a049f7312b2552eac3d944c043a0f1e39d75ee388a714d524609633`。OpenSpec 2.3标记完成，权威进度`7/29`；下一项为2.4完整lifecycle状态/竞态矩阵。

## 2026-07-21 阶段 14 任务 2.4 启动

- 2.3已以`ca37cfc`独立提交并推送，确认`HEAD == origin/main`且工作树clean。2.4覆盖occlusion、focus、zero-drawable、visible resume、stop、same-UUID replacement、stale revision和并发duplicate application。
- 并发duplicate验收要求相同application共享一个in-flight effect，不能在processor副作用仍悬挂时提前发布applied snapshot；更高revision可取代旧reservation，旧awaiter恢复后必须得到stale且不能回退新状态。

## 2026-07-21 阶段 14 任务 2.4 完成

- environment现在让完全相同的pending lifecycle application共享一个effect task；effect成功且generation/revision reservation仍匹配时才发布snapshot。更高revision可以取代悬挂旧reservation，stop/failure清除operation owner，同UUID replacement不会被旧awaiter回写。
- 新增occlusion/focus/zero-drawable/resume顺序、并发duplicate单effect、悬挂旧revision被新revision击败、stop后同UUID replacement隔离四类测试；既有stale revision/generation测试共同完成2.4矩阵。
- focused warnings-as-errors gate通过`30/30`，无skip，结果`/tmp/LuneX-14-2_4-focused.s1IMBS/LifecycleMatrix.xcresult`。完整macOS通过`397 total / 396 passed / 1 explicit Keychain skip / 0 failed`，结果`/tmp/LuneX-14-2_4-full.FaICoD/LuneXCoreTests.xcresult`；测试命令显式移除`LUNEX_RUN_KEYCHAIN_TEST`，未访问真实Keychain。
- macOS、固定iPhone 17 Pro、iPad Pro 13-inch (M5)、Apple TV与Apple Vision Pro Debug warnings-as-errors构建全部通过，证据根目录`/tmp/LuneX-14-2_4-builds.ZOABSV`。原始simulator JSON只变化runtime `lastUsage`时间；规范化设备身份/状态前后逐字节一致，四个名称和固定UUID各唯一、全部`Shutdown`、全局`Booted=0`，未create、boot、run或shutdown设备。
- 5个OpenSpec change strict validation、generator byte-stability、whitespace和production/reference边界通过；project SHA-256前后均为`0751025a3a049f7312b2552eac3d944c043a0f1e39d75ee388a714d524609633`。OpenSpec 2.4标记完成，权威进度`8/29`；下一项为3.1 application input sink。

## 2026-07-21 阶段 14 任务 3.1 启动

- 2.4已以`f04e56f`独立提交并推送，确认`HEAD == origin/main`且工作树clean。现有`AppModel.sendRemoteInput`不暴露session UUID，但环境发送只校验UUID，没有携带media generation；同UUID replacement的旧application无法在environment边界显式拒绝。
- 3.1新增main-actor application input sink合同、generation-scoped input application和input unavailable/stale typed error。AppModel从environment snapshot内部推导generation，environment在provider调用前再次验证session、generation和input readiness；本任务不提前实现3.2 bounded platform FIFO。
- 首轮focused通过3项、失败1项：新增input诊断测试误把既有安全摘要中的普通`session`单词视为隐私泄漏；文案不含UUID/generation值。删除该过严断言，保留稳定分类/code/action及无generation检查，在新隔离目录重跑。

## 2026-07-21 阶段 14 任务 3.1 完成

- 新增main-actor `ApplicationInputSink`，调用方只能提交typed `RemoteInputEvent`。AppModel在media environment启动所有权建立时读取并固定generation，stop/media failure/session failure均清空；高频event不重复获取resource snapshot，也不能误采用同UUID replacement的generation。
- environment发送入口改为`SessionInputApplication`，在provider调用前校验active session、media generation和input readiness；新增`inputUnavailable`/`staleInputApplication`及稳定input diagnostics。测试证明未ready零发送、ready application内部携带generation、同UUID replacement拒绝旧application。
- 最终focused warnings-as-errors通过`4/4`，结果`/tmp/LuneX-14-3_1-focused-r3.POmEvA/ApplicationInputSink.xcresult`。完整macOS通过`399 total / 398 passed / 1 explicit Keychain skip / 0 failed`，结果`/tmp/LuneX-14-3_1-full-r2.lX9rRJ/LuneXCoreTests.xcresult`；命令显式移除`LUNEX_RUN_KEYCHAIN_TEST`，未访问真实Keychain。
- macOS、固定iPhone 17 Pro、iPad Pro 13-inch (M5)、Apple TV和Apple Vision Pro Debug warnings-as-errors构建全部通过，证据根目录`/tmp/LuneX-14-3_1-builds-r2.hIfFhv`。规范化simulator清单前后逐字节一致，名称/UUID各唯一、全部`Shutdown`、全局`Booted=0`，未create、boot、run或shutdown设备。
- 5个OpenSpec strict、generator byte-stability、whitespace及production/reference边界通过；project SHA-256前后均为`a0e3396cfb500e432cc10403c5dc23660a228a821fb0922b8744d34422301e5e`。OpenSpec 3.1标记完成，权威进度`9/29`；下一项为3.2 bounded generation-owned FIFO。

## 2026-07-21 阶段 14 任务 3.2 启动

- 3.1已以`bed004e`独立提交并推送，确认`HEAD == origin/main`且工作树clean。3.2使用main-actor同步admission和每generation单一consumer，避免每个`NSEvent`创建可能重排的unstructured task。
- 队列元素冻结enqueue-time coordinate snapshot、cursor policy和shortcut forwarding policy；容量同时计算in-flight与queued sample。当前任务实现FIFO与backpressure，不提前实现3.3 focus release barrier或3.4完整failure/teardown convergence。

## 2026-07-21 阶段 14 任务 3.2 完成

- 新增`MacSessionInputCoordinator`：同步main-actor admission、opaque generation token、固定容量O(1)环形FIFO、每代单consumer与有界唤醒stream；旧token、inactive generation和包含in-flight的容量溢出均同步拒绝。
- focused warnings-as-errors通过`13/13`，结果`/tmp/LuneX-14-3_2-focused-r2.6M84eP/MacSessionInputCoordinator.xcresult`。完整macOS通过`403 total / 402 passed / 1 explicit Keychain skip / 0 failed`，结果`/tmp/LuneX-14-3_2-full.Vvimeo/LuneXCoreTests.xcresult`；命令显式移除`LUNEX_RUN_KEYCHAIN_TEST`，未访问真实Keychain。
- macOS、固定iPhone 17 Pro、iPad Pro 13-inch (M5)、Apple TV和Apple Vision Pro Debug warnings-as-errors构建全部退出成功，证据根目录`/tmp/LuneX-14-3_2-builds.q9O7ei`。规范化simulator清单前后逐字节一致，名称/UUID各唯一、全部`Shutdown`、全局`Booted=0`，未create、boot、run或shutdown设备。
- 5个OpenSpec change strict、generator byte-stability、whitespace与production/reference边界通过；project SHA-256两次生成前后均为`abdb7ba6c28d50f959111b1cfa3784e1d0c929552095c8f4eb3c5cdd40cdbc80`。OpenSpec 3.2标记完成，权威进度`10/29`；下一项为3.3 focus-loss admission closure与共享held-input `releaseAll` barrier。
- 3.2不宣称旧不可取消sink send已完成等待式teardown：replacement后旧delivery可继续悬挂，但generation fence阻止其修改新状态。该收敛属于3.4；focus release属于3.3。

## 2026-07-21 阶段 14 任务 3.3 启动

- 3.2已以`682ecfb`独立提交并推送，确认`HEAD == origin/main`且工作树clean。3.3在同一个generation consumer中加入focus-loss barrier：先同步关闭新sample admission，继续drain此前已接受的sample，再执行一个共享`releaseAll`，屏障完成前即使focus恢复也不重新开放。
- release通过AppModel内部固定的session/media generation构造application，并由environment在provider调用前后校验；旧focus operation不得读取或释放same-UUID replacement generation。

## 2026-07-21 阶段 14 任务 3.3 完成

- coordinator在失焦时同步关闭admission但继续drain accepted FIFO，随后执行一个不占普通容量的共享release barrier；重复失焦不重复release，屏障pending/in-flight期间回焦仍保持关闭，成功后仅同一eligible generation重开，失败保持fail closed。
- `SessionInputReleaseApplication`将AppModel固定的session/media generation传入environment；provider suspension前后均校验ownership，旧release错误只有调用时generation仍current才记录诊断。coordinator和真实AppModel race测试均证明replacement不受旧回调影响。
- 最终focused warnings-as-errors通过`11/11`，结果`/tmp/LuneX-14-3_3-focused-r3.OZCdOo/FocusRelease.xcresult`。完整macOS通过`408 total / 407 passed / 1 explicit Keychain skip / 0 failed`，结果`/tmp/LuneX-14-3_3-full.HGv3HA/LuneXCoreTests.xcresult`；命令显式移除`LUNEX_RUN_KEYCHAIN_TEST`，未访问真实Keychain。
- macOS、固定iPhone 17 Pro、iPad Pro 13-inch (M5)、Apple TV和Apple Vision Pro Debug warnings-as-errors构建全部通过，证据根目录`/tmp/LuneX-14-3_3-builds.OTxzEU`。规范化simulator清单前后逐字节一致，名称/UUID各唯一、全部`Shutdown`、全局`Booted=0`，未create、boot、run或shutdown设备。
- 5个OpenSpec change strict、generator byte-stability、whitespace与production/reference边界通过；project SHA-256两次生成前后均为`abdb7ba6c28d50f959111b1cfa3784e1d0c929552095c8f4eb3c5cdd40cdbc80`。OpenSpec 3.3标记完成，权威进度`11/29`；下一项为3.4 failure/teardown convergence。

## 2026-07-21 阶段 14 任务 3.4 启动

- 3.3已以`2f5635e`独立提交并推送，确认`HEAD == origin/main`且工作树clean。3.4把send failure、input-channel failure、stop、remote termination、detach与replacement收敛到同一个generation terminal path。
- replacement激活改为async：必须等待旧consumer当前in-flight send/release真正返回；terminal path同步关闭admission、丢弃未开始sample、执行一次注入式capture cleanup并共享consumer completion，避免cancel不响应时旧delivery跨代存活。

## 2026-07-21 阶段 14 任务 3.4 完成

- coordinator新增generation-scoped terminal reason/result与一次性capture cleanup；send failure不重复release，其他terminal trigger等待当前send和共享release barrier，终止期间focus不能重开admission，queued sample被同步丢弃。
- replacement activation改为async并等待旧consumer真实完成；审阅发现并修复两个并发activation可能连续创建两代的MainActor reentrancy，现共享一个activation task并返回同一replacement generation。
- 最终focused warnings-as-errors通过`11/11`，结果`/tmp/LuneX-14-3_4-focused-r2.kp6TJJ/Termination.xcresult`。修改后完整macOS通过`411 total / 410 passed / 1 explicit Keychain skip / 0 failed`，结果`/tmp/LuneX-14-3_4-full-r2.shEz9u/LuneXCoreTests.xcresult`；未访问真实Keychain。
- 修改后macOS、固定iPhone 17 Pro、iPad Pro 13-inch (M5)、Apple TV和Apple Vision Pro Debug warnings-as-errors构建全部通过，证据根目录`/tmp/LuneX-14-3_4-builds-r2.2QPSxQ`。规范化simulator清单前后逐字节一致，四个固定实例唯一且全部`Shutdown`，全局`Booted=0`。
- 5个OpenSpec strict、generator byte-stability、whitespace与production/reference边界通过。OpenSpec 3.4标记完成，权威进度`12/29`；下一项为3.5完整input coordination竞态矩阵。

## 2026-07-21 阶段 14 任务 3.5 启动

- 3.4已以`868e4f8`独立提交并推送，确认`HEAD == origin/main`且工作树clean。3.5只扩展确定性矩阵，覆盖全部external terminal reason、full-capacity focus barrier、terminal release failure及stale/inactive teardown隔离，不提前实现AppKit cursor/view。

## 2026-07-21 阶段 14 任务 3.5 完成

- 新增四组矩阵：input-channel failure/stop/remote termination/detach均一次release+cleanup；普通容量满时focus barrier仍可预约；terminal release失败仍完成关闭；stale/inactive teardown对replacement零副作用。
- focused warnings-as-errors通过`15/15`，结果`/tmp/LuneX-14-3_5-focused.ejam0P/Matrix.xcresult`。完整macOS通过`415 total / 414 passed / 1 explicit Keychain skip / 0 failed`，结果`/tmp/LuneX-14-3_5-full.uXXjYE/LuneXCoreTests.xcresult`；未访问真实Keychain。
- macOS、固定iPhone 17 Pro、iPad Pro 13-inch (M5)、Apple TV和Apple Vision Pro Debug warnings-as-errors构建全部通过，证据根目录`/tmp/LuneX-14-3_5-builds.XvlSHg`。规范化simulator清单前后逐字节一致，四个固定实例唯一且全部`Shutdown`，全局`Booted=0`。
- OpenSpec 3.5标记完成，权威进度`13/29`；ordered macOS session input coordination小节完成，下一项4.1实现balanced AppKit cursor owner。

## 2026-07-21 阶段 14 任务 4.1 启动

- 3.5已以`7a34105`独立提交并推送，确认`HEAD == origin/main`且工作树clean。4.1实现main-actor cursor owner与可注入system operations，真实`NSCursor`/CoreGraphics实现仅在macOS编译。
- owner只记录并逆转自身成功执行的hide与pointer disassociation；relative acquisition先解除关联、成功后才隐藏，获取失败不改变cursor可见性。重复policy/cleanup幂等，association恢复失败仍立即unhide并保留association ownership供后续重试。
- 新增`MacCursorCaptureOwner`、macOS `AppKitCursorSystemOperations`与注入式测试；初版focused `4/4`后复核发现获取顺序会在association失败时留下隐藏cursor，已修正production和测试，旧结果不作为最终证据。

## 2026-07-21 阶段 14 任务 4.1 完成

- 最终focused Swift/Clang warnings-as-errors通过`4/4`，结果`/tmp/LuneX-14-4_1-focused-r2.OCEdIM/CursorOwner.xcresult`；覆盖balanced/idempotent capture、acquisition failure零ownership、restore failure可重试和hide-only policy。
- 完整macOS suite结构化通过`419 total / 418 passed / 1 explicit Keychain skip / 0 failed`，结果`/tmp/LuneX-14-4_1-full.9Gr5Jt/LuneXCoreTests.xcresult`；唯一skip为显式禁用的真实Keychain round-trip，未再次访问Keychain。
- macOS、固定iPhone 17 Pro、iPad Pro 13-inch (M5)、Apple TV和Apple Vision Pro Debug warnings-as-errors构建全部通过，证据根目录`/tmp/LuneX-14-4_1-builds.6sCLS5`。规范化simulator清单前后逐字节一致，四个固定实例唯一且全部`Shutdown`，全局`Booted=0`。
- 5个OpenSpec strict、generator byte-stability（SHA-256 `f28937759af3c90b9f9ca70a429536266e795405b13e5ccf029cc80cc82613c9`）、whitespace与production/reference边界通过。OpenSpec 4.1标记完成，权威进度`14/29`；下一项4.2实现first-responder keyboard/modifier/shortcut capture view。
- 4.1只证明cursor owner及真实AppKit/CoreGraphics adapter可编译、所有权转换确定且可恢复；尚未接入stream surface、window lifecycle或coordinator cleanup，不能当作实际remote cursor capture或Sunshine receipt证据。

## 2026-07-21 阶段 14 任务 4.2 启动

- 4.1已以`6d9c30c`独立提交并推送，确认`HEAD == origin/main`且工作树clean。4.2实现macOS-only flipped first-responder capture view、key/modifier/repeat/reserved-shortcut值样本和显式macOS virtual-key到Win32 VK翻译，不提前接入实际stream surface。
- 首轮focused在测试编译阶段发现当前SDK的`NSEvent.keyEvent`要求非optional characters；production无编译错误。测试factory对`flagsChanged`改用空字符串，并使用新隔离目录重跑。

## 2026-07-21 阶段 14 任务 4.2 完成

- 新增macOS-only `MacStreamInputCaptureView`：flipped、可成为first responder，override keyDown/keyUp/flagsChanged/performKeyEquivalent；左右modifier keyCode独立平衡，repeat原样保留，Command-Q/Tab/H分类跨key-up持续，Escape始终本地且非repeat仅触发一次capture-exit callback。
- `MacInputAdapter`不再把macOS `NSEvent.keyCode`直接送wire；显式翻译已确认的ANSI/ISO、modifier、keypad、F1-F20、navigation和context-menu键到Win32 VK，未知Fn、媒体音量和语义未确认的keypad equals fail closed。审阅修正`kVK_Help`为`VK_HELP (0x2F)`。
- 最终focused Swift/Clang warnings-as-errors通过`33/33`，结果`/tmp/LuneX-14-4_2-focused-final.RqwnSz/KeyboardCapture.xcresult`。完整macOS suite结构化通过`428 total / 427 passed / 1 explicit Keychain skip / 0 failed`，结果`/tmp/LuneX-14-4_2-full-final.kwwfBb/LuneXCoreTests.xcresult`；唯一skip为显式禁用的真实Keychain round-trip。
- macOS、固定iPhone 17 Pro、iPad Pro 13-inch (M5)、Apple TV和Apple Vision Pro Debug warnings-as-errors最终重跑全部通过，证据根目录`/tmp/LuneX-14-4_2-builds-final.WDEInh`。规范化simulator清单前后逐字节一致，四个固定实例唯一且全部`Shutdown`，全局`Booted=0`。
- 5个OpenSpec strict、generator byte-stability（SHA-256 `e1eac0d6538ff7f5ecff19a0d40ffa967a8d0c0d0cddb0fab281788c8f1fa9d2`）、whitespace与production/reference边界通过。OpenSpec 4.2标记完成，权威进度`15/29`；下一项4.3实现pointer/button/scroll/backing conversion。
- 4.2证明真实AppKit键盘事件采集类型和翻译可工作，但capture view尚未嵌入`MetalStreamSurface`、绑定session generation或调用coordinator enqueue；不声称live Sunshine收到任何键盘事件。

## 2026-07-21 阶段 14 任务 4.3 恢复

- 从文件化计划和session catchup恢复：`HEAD`为已推送的`1c6184e`，工作树只有`MacInputAdapter.swift`与`MacStreamInputCaptureView.swift`的pointer/button/scroll初稿；OpenSpec权威进度仍为`15/29`。
- 当前补丁尚未增加测试、编译或运行任何focused/full/five-platform验收，因此4.3保持未完成；既往4.2证据不能替代当前实现的验收。
- 下一步读取change全部context files，复核view-to-backing转换、按钮状态时序、absolute letterbox拒绝和scroll归一化，再补确定性测试并运行独立质量门。
- 生产复核发现absolute模式在视频内button-down后若于fit letterbox释放，原初稿会丢弃button-up并可能滞留远端held state；已改为仅拒绝无效absolute down，无效位置的up仍发送`point: nil`以保持释放平衡。
- 已补AppKit真实事件路由、嵌套view/non-zero bounds backing转换、五键映射、drag按钮集合、reset、unsupported button、precise/line scroll及relative/absolute adapter矩阵；尚未编译，4.3仍保持未完成。
- 首轮focused warnings-as-errors共`46`项，新增4.3测试全部通过，但既有focus FIFO测试仍使用旧语义的`absolute button-down + nil point`，现被新adapter正确drop，导致预期操作序列少一个button事件；结果`/tmp/LuneX-14-4_3-focused.UhDQWC/PointerCapture.xcresult`保留为失败证据。
- 已把该回归输入改为有效absolute点并断言映射坐标；下一轮必须使用新隔离DerivedData重新验证，不沿用首轮结果。
- 第二轮focused Swift/Clang warnings-as-errors结构化通过`46/46`、无skip，结果`/tmp/LuneX-14-4_3-focused-r2.tdCOzt/PointerCapture.xcresult`；覆盖capture view、adapter和coordinator回归。
- 代码复核确认movement button snapshot当前不进入wire held ownership，显式button transition才更新provider held state；letterbox down drop与outside up释放不会被movement绕过。下一门为完整macOS suite，4.3仍未勾选。
- 完整macOS Swift/Clang warnings-as-errors套件结构化通过`441 total / 440 passed / 1 explicit Keychain skip / 0 failed`，结果`/tmp/LuneX-14-4_3-full.O3Kbrf/LuneXCoreTests.xcresult`；唯一skip精确为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`。
- 完整测试命令显式移除`LUNEX_RUN_KEYCHAIN_TEST`，没有再次访问真实Keychain。下一门为修改后五平台Debug构建与simulator identity/state守卫，4.3仍未勾选。
- 修改后macOS、固定iPhone 17 Pro、iPad Pro 13-inch (M5)、Apple TV和Apple Vision Pro Debug Swift/Clang warnings-as-errors构建全部通过，证据根目录`/tmp/LuneX-14-4_3-builds.AV2kXY`。
- 构建前后规范化simulator identity/state JSON逐字节一致；四个固定名称/UUID各唯一且全部`Shutdown`，全局`Booted=0`，未create、boot、run或shutdown任何设备。下一门为OpenSpec/generator/repository边界与最终diff审查。

## 2026-07-21 阶段 14 任务 4.3 完成

- `MacStreamInputCaptureView`现覆盖mouse move/drag、left/right/middle/back/forward down/up与scroll；独立维护pressed-button集合，reset只清本地tracking，远端释放仍由ordered `releaseAll`负责。
- absolute点经window-to-flipped-view再到backing pixels转换并减去实际view backing bounds原点；relative button/scroll不要求absolute point。fit letterbox拒绝absolute movement/down/scroll，但无效位置button-up仍发送`point:nil`避免远端held state滞留。
- focused gate最终`46/46`，结果`/tmp/LuneX-14-4_3-focused-r2.tdCOzt/PointerCapture.xcresult`；完整macOS `441 total / 440 passed / 1 explicit Keychain skip / 0 failed`，结果`/tmp/LuneX-14-4_3-full.O3Kbrf/LuneXCoreTests.xcresult`。
- 五平台Debug warnings-as-errors通过，证据`/tmp/LuneX-14-4_3-builds.AV2kXY`；规范化simulator状态前后逐字节一致，固定实例唯一且全部`Shutdown`，全局`Booted=0`。
- 5个OpenSpec strict、generator双跑byte-stability（SHA-256 `e1eac0d6538ff7f5ecff19a0d40ffa967a8d0c0d0cddb0fab281788c8f1fa9d2`）、whitespace与真实`references/`路径边界通过。OpenSpec 4.3标记完成，权威进度`16/29`；下一项为4.4 actual stream-surface attachment/detach。
- 4.3不证明view已附着active stream、真实Sunshine已收到事件、物理鼠标Y方向/加速手感或多显示器硬件映射；分别保留给4.4/5.2与6.5，阶段13仍为`54/61 in_progress`。

## 2026-07-21 阶段 14 任务 4.4 启动

- 4.3已以`5698719`独立提交并推送，确认`HEAD == origin/main`且工作树clean。4.4只负责把capture与lifecycle observation附着到actual macOS stream surface并在SwiftUI replacement/dismantle时幂等拆卸。
- 本项不提前实现5.2的AppModel/media/coordinator application integration；先调查`MetalStreamSurface`、`NSViewRepresentable`、`AppKitLifecycleMonitor`与现有cursor cleanup ownership，再确定最小attachment边界。
- 首轮focused在测试启动前编译失败：`MTKView.init(coder:)`在Xcode 26.4为non-failable designated initializer，旧`NSView`子类的`init?`签名不能override。已改为unavailable non-failable `init(coder:)`，下一轮使用新隔离DerivedData。
- 第二轮focused在测试启动前发现test target未编入`AppKitLifecycleMonitor.swift`和`MetalStreamSurface.swift`，新attachment owner不可见；同时`observedWindows.first`形成`NSWindow??`无法直接做identity比较。已同步generator test-support sources并显式unwrap断言，下一轮使用新目录。
- 第三轮focused Swift/Clang warnings-as-errors结构化通过`29/29`、无skip，结果`/tmp/LuneX-14-4_4-focused-r3.eOtvN0/SurfaceAttachment.xcresult`；覆盖actual window callback、disabled admission、monitor reset、重复attach/detach与stale dismantle隔离。
- macOS App target warnings-as-errors构建通过，隔离DerivedData为`/tmp/LuneX-14-4_4-macos-build.8vjQDF`，确认`RootView`条件初始化和`NSViewRepresentable` production conformance可编译。4.4仍需完整套件、五平台与仓库门禁后才完成。
- 完整macOS suite结构化通过`445 total / 444 passed / 1 explicit Keychain skip / 0 failed`，结果`/tmp/LuneX-14-4_4-full.o2NK1V/LuneXCoreTests.xcresult`；唯一skip仍精确为一次性真实Keychain测试，命令显式移除`LUNEX_RUN_KEYCHAIN_TEST`。
- 下一门为当前源码和generator修改后的五平台Debug构建及simulator前后状态守卫；4.4仍未勾选。
- 首轮五平台Debug warnings-as-errors与simulator状态门通过，证据`/tmp/LuneX-14-4_4-builds.CGpuoi`；但提交前审阅发现跨coordinator replacement可由旧monitor detach清零新surface共享lifecycle，因此该构建证据不再作为最终结果。
- 已增加`PlatformLifecycleState` current attachment lease与“replacement先attach、旧monitor后detach”回归；只有当前attachment可在dismantle时清visible/focus/drawable。production已变化，focused/full/five-platform均须重跑。
- lease修正后的最终focused warnings-as-errors通过`30/30`、无skip，结果`/tmp/LuneX-14-4_4-focused-final.wTD7bt/SurfaceAttachment.xcresult`；明确覆盖replacement monitor先取得共享lifecycle后旧dismantle零副作用。
- lease修正后的完整macOS suite结构化通过`446 total / 445 passed / 1 explicit Keychain skip / 0 failed`，结果`/tmp/LuneX-14-4_4-full-final.EoPoDt/LuneXCoreTests.xcresult`；唯一skip精确为一次性真实Keychain测试，未访问真实Keychain。
- lease修正后的最终macOS、固定iPhone 17 Pro、iPad Pro 13-inch (M5)、Apple TV与Apple Vision Pro Debug Swift/Clang warnings-as-errors构建全部通过，证据根目录`/tmp/LuneX-14-4_4-builds-final.fqr0Yj`。
- 构建前后规范化simulator identity/state逐字节一致；四个固定名称/UUID各唯一且全部`Shutdown`，全局`Booted=0`，未create、boot、run或shutdown任何设备。

## 2026-07-21 阶段 14 任务 4.4 完成

- actual macOS `MetalStreamSurface`现直接创建`MacStreamInputCaptureView: MTKView`，capture与Metal presentation不再分属父子view；`RootView`移除整窗background lifecycle attachment，actual surface负责window observation。
- attachment owner对同一view/window重复attach幂等，stale candidate detach无副作用；dismantle清callback、transient input state、Metal delegate并暂停surface。共享attachment lease保证replacement先attach后，旧coordinator迟到dismantle不能覆盖新surface lifecycle。
- actual surface input admission仍默认关闭；5.1 actual stream-view backing geometry、5.2 active AppModel/media/input coordinator连接、5.3 capture eligibility和6.5 live Sunshine/hardware证明均保持未完成。
- 最终focused为`30/30`（`/tmp/LuneX-14-4_4-focused-final.wTD7bt/SurfaceAttachment.xcresult`）；完整macOS为`446 total / 445 passed / 1 explicit Keychain skip / 0 failed`（`/tmp/LuneX-14-4_4-full-final.EoPoDt/LuneXCoreTests.xcresult`），测试显式移除`LUNEX_RUN_KEYCHAIN_TEST`。
- 五平台Debug warnings-as-errors通过（`/tmp/LuneX-14-4_4-builds-final.fqr0Yj`），simulator状态前后逐字节一致。5个OpenSpec strict、generator三次SHA-256均为`8ba9f47017c9aca22655a7efdd638f7a01b05be995cd139cf36c50475e6211fd`、whitespace与production/reference边界通过。
- OpenSpec 4.4标记完成，权威进度`17/29`；下一项为4.5 AppKit cursor transition、responder、event translation、attachment与dismantle测试矩阵。阶段13仍为`54/61 in_progress`，不以本次离线证据替代production video/audio receiver或授权live-host/hardware证据。

## 2026-07-21 阶段 14 任务 4.5 启动

- 4.4已以`14eff16`独立提交并推送，确认`HEAD == origin/main`且工作树clean。4.5扩展AppKit-focused cursor、responder、event translation、attachment与dismantle回归，不重复4.2/4.3已有基础事件矩阵。
- 审阅发现capture surface仅声明`acceptsFirstResponder`，但启用admission后没有实际请求first responder；点击路径又直接处理button而不调用`super`，因此仅有能力声明不足以证明键盘事件可达。4.5将补启用/附着/点击时的幂等responder acquisition及禁用释放，同时保持默认admission关闭。
- 4.5 focused macOS Swift/Clang warnings-as-errors gate一次通过`28/28`、无skip，结果`/tmp/LuneX-14-4_5-focused.ZiDrwr/AppKitFocused.xcresult`；覆盖cursor relative-to-hide-only transition、responder启用/点击/禁用、stale window callback、latest coordinator handler与重复dismantle。
- 完整macOS suite通过`451 total / 450 passed / 1 explicit Keychain skip / 0 failed`，结果`/tmp/LuneX-14-4_5-full.ns7pyI/LuneXCoreTests.xcresult`；test tree确认唯一skip精确为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，未访问真实Keychain。
- macOS、固定iPhone 17 Pro、iPad Pro 13-inch (M5)、Apple TV与Apple Vision Pro Debug Swift/Clang warnings-as-errors构建全部通过，证据根目录`/tmp/LuneX-14-4_5-builds.WacHba`；构建前后固定simulator identity/state逐字节一致，全部唯一且`Shutdown`，全局`Booted=0`。

## 2026-07-21 阶段 14 任务 4.5 完成

- enabled actual capture surface在window attachment和mouse-down时幂等请求first responder；禁用时只释放自身ownership并清transient tracking。默认surface仍disabled，不会抢本地键盘焦点。
- repeated SwiftUI dismantle现在首先关闭input admission，再清window callback、attachment、Metal delegate并暂停surface；旧view后续直接事件调用不产生sample。stale window callback与旧handler均不能影响replacement。
- cursor relative-to-hide-only transition、responder transfer、actual event latest-closure routing、attachment replacement与dismantle cleanup均有AppKit-focused回归；本项不提前接入5.2/5.3 active session/cursor policy。
- focused `28/28`（`/tmp/LuneX-14-4_5-focused.ZiDrwr/AppKitFocused.xcresult`）；完整macOS `451 total / 450 passed / 1 Keychain skip / 0 failed`（`/tmp/LuneX-14-4_5-full.ns7pyI/LuneXCoreTests.xcresult`）；五平台Debug通过（`/tmp/LuneX-14-4_5-builds.WacHba`）。
- 5个OpenSpec strict、generator三次SHA-256 `8ba9f47017c9aca22655a7efdd638f7a01b05be995cd139cf36c50475e6211fd`、whitespace与production/reference边界通过。OpenSpec 4.5标记完成，权威进度`18/29`；第4节Native AppKit capture/cursor ownership已完成，下一项5.1 actual stream-view geometry。阶段13仍为`54/61 in_progress`。

## 2026-07-21 阶段 14 任务 5.1 启动

- 4.5已以`f311ac1`独立提交并推送，确认`HEAD == origin/main`且工作树clean。5.1负责actual stream-view backing geometry与display/headroom state，不提前执行5.2 AppModel/media lifecycle application。
- 当前monitor仍从`window.contentView.bounds * backingScaleFactor`派生drawable，无法表示嵌套/缩放后的actual Metal surface；`MetalStreamSurface.apply`又可能用旧render coordinate snapshot反向覆盖`MTKView.drawableSize`。本项将让monitor绑定window+surface，统一处理view geometry、screen、backing和live-resize变化，并移除旧snapshot对actual drawable的覆盖。
- 5.1首轮focused包装器错误分支误用zsh只读变量`status`，但保留日志显示真实构建在测试前失败：attachment owner的weak optional view传入新`attach(window,surface:)`前未unwrap。已在observe边界guard当前view并将包装器变量改为`exit_code`，下一轮使用全新DerivedData。
- 修正后focused macOS Swift/Clang warnings-as-errors通过`38/38`、无skip，结果`/tmp/LuneX-14-5_1-focused-r2.qCiegh/SurfaceGeometry.xcresult`；覆盖actual backing geometry、Metal drawable同步、frame/bounds、same-window replacement及五类window/application display通知。
- 完整macOS suite通过`455 total / 454 passed / 1 explicit Keychain skip / 0 failed`，结果`/tmp/LuneX-14-5_1-full.7R2U3Q/LuneXCoreTests.xcresult`；测试显式移除`LUNEX_RUN_KEYCHAIN_TEST`，未访问真实Keychain。
- macOS、固定iPhone 17 Pro、iPad Pro 13-inch (M5)、Apple TV与Apple Vision Pro Debug Swift/Clang warnings-as-errors构建全部通过，证据根目录`/tmp/LuneX-14-5_1-builds.BgYKnF`；simulator前后规范化identity/state逐字节一致，固定实例唯一且全部`Shutdown`，全局`Booted=0`。

## 2026-07-21 阶段 14 任务 5.1 完成

- lifecycle attachment现绑定actual window+Metal surface；drawable由surface backing bounds派生并同步MTKView，不再读取window content bounds。same-window replacement也会切换geometry source。
- surface frame/bounds变化和window resize/end-live-resize/screen/backing、application screen-parameter通知均刷新当前display name、EDR headroom与drawable；detach清display/headroom/drawable且受attachment lease保护。
- 删除已无production调用的零尺寸`AppKitLifecycleAttachment`，并移除render snapshot对actual drawable的反向写入。5.2的AppModel/media/input application仍保持未完成。
- focused `38/38`（`/tmp/LuneX-14-5_1-focused-r2.qCiegh/SurfaceGeometry.xcresult`）；完整macOS `455 total / 454 passed / 1 Keychain skip / 0 failed`（`/tmp/LuneX-14-5_1-full.7R2U3Q/LuneXCoreTests.xcresult`）；五平台Debug通过（`/tmp/LuneX-14-5_1-builds.BgYKnF`）。
- 5个OpenSpec strict、generator三次SHA-256 `8ba9f47017c9aca22655a7efdd638f7a01b05be995cd139cf36c50475e6211fd`、whitespace与production/reference边界通过。OpenSpec 5.1标记完成，权威进度`19/29`；下一项5.2 application/media integration。阶段13仍为`54/61 in_progress`。

## 2026-07-21 阶段 14 任务 5.2 启动

- 从session catch-up、文件化计划、active goal和OpenSpec全部context恢复；确认`HEAD == origin/main == 762e7c8`、工作树clean，OpenSpec权威进度`19/29`，四个固定simulator实例唯一且全部`Shutdown`。
- 5.2范围限定为`PlatformLifecycleState -> AppModel -> renderer/media lifecycle`和`actual surface -> AppModel -> active MacSessionInputCoordinator -> ApplicationInputSink`连接；不提前开启5.3 persisted capture/cursor eligibility，不把deterministic provider delivery声称为Sunshine live receipt。
- 实现将使用AppModel-owned单一lifecycle pump和media-readiness-owned input generation；已有media environment revision/generation语义、video presentation recovery和input FIFO/release barrier保持不重写。完成前需新增AppModel集成测试并执行focused/full/five-platform、simulator、OpenSpec、generator和repository边界门禁。
- 首轮快速编译中`LuneXCoreTests`误用`build` action导致无匹配destination，后续改用该scheme的`test` action；macOS App真实编译定位到lifecycle pump弱引用闭包把Task推导为`Task<Void?, Never>`，已改为显式unwrap self后返回`Void`，不重复无效命令。
- 新增3项AppModel focused测试单独运行`3/3`通过；扩大到AppModel/lifecycle/media/input coordinator共78项时出现2个测试观察竞态：一个在session尚未进入streaming前断言render active，另一个在fake release已记录但coordinator完成计数尚未回写时断言。测试改为等待最终session/coordinator状态，production逻辑未因中间状态断言改写。
- 修正等待后相关focused门`78/78`通过，完整macOS suite为`458 total / 457 passed / 1 explicit Keychain skip / 0 failed`。五平台Debug warnings-as-errors build-only通过，证据`/tmp/LuneX-14-5_2-builds.doirzl`；simulator前后规范化JSON逐字节一致，固定实例各唯一且全部`Shutdown`、全局`Booted=0`。
- 提交前复核补上negotiated decoded source geometry ownership，并阻止设置刷新覆盖actual lifecycle display headroom；因为production已变化，相关focused/full/five-platform证据必须重新验证，前述结果只保留为中间证据。
- 第二次diff复核收紧lifecycle pump错误分类：仅明确stale application可在更高revision下重试，真实effect failure必须失败并清理session；新增AppModel failure convergence测试。production再次变化，最终门禁从focused开始重新执行。

## 2026-07-21 阶段 14 任务 5.2 完成

- 最终相关focused Swift/Clang warnings-as-errors通过`79/79`，结果`/tmp/LuneX-14-5_2-focused-final2.otpayx/IntegrationFocused.xcresult`；覆盖lifecycle缓存/顺序、negotiated geometry/headroom、fake-provider input、focus release、零drawable和effect failure convergence。
- 完整macOS suite结构化通过`459 total / 458 passed / 1 explicit Keychain skip / 0 failed`，结果`/tmp/LuneX-14-5_2-full-final2.wc1urd/LuneXCoreTests.xcresult`；唯一skip精确为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，测试显式移除`LUNEX_RUN_KEYCHAIN_TEST`。
- macOS、固定iPhone 17 Pro、iPad Pro 13-inch (M5)、Apple TV与Apple Vision Pro Debug warnings-as-errors build-only全部通过，证据`/tmp/LuneX-14-5_2-builds-final2.pe158p`。构建前后simulator规范化JSON逐字节一致，固定实例唯一且全部`Shutdown`，全局`Booted=0`。
- 5个OpenSpec strict、generator三次SHA-256 `8ba9f47017c9aca22655a7efdd638f7a01b05be995cd139cf36c50475e6211fd`、whitespace与production/reference边界通过。OpenSpec 5.2标记完成，权威进度`20/29`；下一项5.3 persisted capture/cursor eligibility，阶段13仍为`54/61 in_progress`。

## 2026-07-21 阶段 14 任务 5.3 启动

- 5.2已以`69584be Connect macOS lifecycle to active session`独立提交并通过SSH 443推送；确认`HEAD == origin/main`、工作树clean后进入5.3。
- 5.3范围限定为active session/input readiness/lifecycle/geometry与持久化输入设置派生actual surface admission、direct/relative映射、shortcut forwarding和balanced cursor application；privacy diagnostics属于5.4，完整application gate属于5.5，live Sunshine/hardware receipt属于6.5。

## 2026-07-21 阶段 14 任务 5.3 完成

- actual `MetalStreamSurface`现消费AppModel发布的`MacInputSurfacePolicy`：direct与relative均可admit input，只有relative通过共享lease broker隐藏cursor并解除pointer association；association获取失败fail closed。settings变更即时更新relative/direct与shortcut policy，Escape只退出relative。
- 封版审阅补齐双coordinator replacement和同coordinator view replacement：旧attachment/dismantle只释放匹配lease，不能通过inactive policy重取全局cursor ownership，也不能因残留旧view identity拒绝新surface。
- 最终surface focused `33/33`（`/tmp/LuneX-14-5_3-surface-final.PK4kyI/Surface.xcresult`）；完整macOS `466 total / 465 passed / 1 Keychain skip / 0 failed`（`/tmp/LuneX-14-5_3-full-final2.yUoJpc/LuneXCoreTests.xcresult`），测试显式移除`LUNEX_RUN_KEYCHAIN_TEST`。
- 最终五平台Debug warnings-as-errors通过（`/tmp/LuneX-14-5_3-builds-final2.6keHqh`）；simulator前后规范化状态逐字节一致，固定实例唯一且全部`Shutdown`、全局`Booted=0`。OpenSpec strict `5/5`、generator三次SHA-256 `8ba9f47017c9aca22655a7efdd638f7a01b05be995cd139cf36c50475e6211fd`、diff/reference边界通过。
- OpenSpec 5.3标记完成，权威进度`21/29`；下一项5.4为privacy-bounded input/lifecycle diagnostics与recovery/stop stale action清理。阶段13仍为`54/61 in_progress`，本项不声称live Sunshine receipt或物理cursor手感证明。

## 2026-07-21 阶段 14 任务 5.4 启动

- session catch-up、文件化计划、active goal与OpenSpec已恢复并互相核对；`HEAD == origin/main == 0c461b1`且启动前工作树clean，阶段14权威进度`21/29`。
- 5.4范围限定为privacy-bounded lifecycle/input语义诊断、同状态去重和恢复/停止后的当前action清理；历史事件继续保留，不提前执行5.5 application integration gate或6.x live hardware证明。
- 测试继续显式移除`LUNEX_RUN_KEYCHAIN_TEST`，不再次访问真实Keychain；五平台build-only复用既有固定且Shutdown的simulator，不create、boot、run或shutdown设备。
- 最终定向Swift/Clang warnings-as-errors门通过`49/49`、无skip，结果`/tmp/LuneX-14-5_4-focused-final2.M5GVv9/Diagnostics.xcresult`；覆盖current-action/history分离、privacy固定payload、语义状态去重、真实provider send失败fail-closed、readiness恢复选择性清理与stop历史保留。
- 完整macOS suite结构化通过`469 total / 468 passed / 1 explicit Keychain skip / 0 failed`，结果`/tmp/LuneX-14-5_4-full-final2.4322ka/LuneXCoreTests.xcresult`；唯一skip精确为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，测试命令显式移除环境变量。
- 五平台构建前只读simulator审计确认四个固定UUID各自唯一、可用且全部`Shutdown`，全局`Booted=0`；下一门为macOS与固定iPhone/iPad/tvOS/visionOS Debug warnings-as-errors build-only及构建后逐字节状态比较。
- 5.4最终定向Swift/Clang warnings-as-errors门禁通过`49/49`、无skip，结果`/tmp/LuneX-14-5_4-focused-r3.pDAiXq/Diagnostics.xcresult`；覆盖current action按类别清理、历史保留、固定privacy payload、lifecycle/input状态去重、真实fake-provider send failure、readiness recovery、fatal decoder保留和stop清理。
- input provider拒绝后AppModel以独立failed gate立即关闭surface admission，同时保留generation token供readiness loss/stop回收；恢复generation建立后才清input action。下一门为完整macOS suite。

## 2026-07-21 阶段 14 任务 5.4 完成

- current action与完整历史已分离；恢复按pairing/transport/input等明确类别清理，stream overlay不再从完整历史回放旧错误。lifecycle/input固定状态code按语义去重，真实fake-provider send failure关闭admission且保留generation teardown ownership。
- 最终focused `49/49`（`/tmp/LuneX-14-5_4-focused-final2.M5GVv9/Diagnostics.xcresult`）；完整macOS `469 total / 468 passed / 1 Keychain skip / 0 failed`（`/tmp/LuneX-14-5_4-full-final2.4322ka/LuneXCoreTests.xcresult`），唯一skip精确为一次性真实Keychain测试。
- macOS、固定iPhone 17 Pro、iPad Pro 13-inch (M5)、Apple TV与Apple Vision Pro Debug warnings-as-errors build-only全部通过，证据`/tmp/LuneX-14-5_4-builds-final2.Uw3Ahq`；构建前后simulator规范化JSON逐字节一致，固定实例唯一且全部`Shutdown`、全局`Booted=0`。
- 5个OpenSpec strict、generator三次及生成前SHA-256 `8ba9f47017c9aca22655a7efdd638f7a01b05be995cd139cf36c50475e6211fd`、whitespace与production/reference边界通过。OpenSpec 5.4标记完成，权威进度`22/29`；下一项为5.5完整application integration gate，阶段13仍为`54/61 in_progress`。

## 2026-07-21 阶段 14 任务 5.5 启动

- 5.4已以`3cecf50 Publish bounded macOS lifecycle diagnostics`独立提交并推送，确认`HEAD == origin/main`且工作树clean；OpenSpec权威进度`22/29`。
- 5.5限定为单一application-level确定性集成门：同一fake session证明provider delivery、focus release、occlusion pause/resume、resize mapping和clean teardown，不把fake-provider观察声称为授权Sunshine host receipt。
- 首次单项测试命令误用不存在的`LuneX` scheme，`xcodebuild`在编译前以65退出；该结果不属于源码失败。下一步先从工程读取实际scheme，再使用新的命令执行门禁。
- 正确scheme下的首轮单项warnings-as-errors测试通过；补强generation断言后的复跑命令因包含不必要的临时`.xcresult`删除而被安全规则在启动前拒绝。后续使用唯一结果路径，不重复该清理方式。

## 2026-07-21 阶段 14 任务 5.5 完成

- 单一application-level门在同一fake session中串联keyboard delivery、focus release、occlusion pause/resume、1600x1200 resize后的fit坐标映射与local stop clean teardown；不新增production fake接口，也不将fake receipt声称为Sunshine host receipt。
- fake environment不启动native video processor；测试显式注入presentation source并播入受控decoder generation，验证AppModel occlusion失效旧generation、resume接受新generation和stop清理source。该fixture不证明真实视频帧或Sunshine receipt。
- 最终单项warnings-as-errors复跑`1/1`通过（`/tmp/LuneX-14-5_5-single-r2.moqTup/Integration-final-1784637488.xcresult`）；最终扩大focused五测试簇`92/92`通过（`/tmp/LuneX-14-5_5-focused-final.4mEnnV/Focused.xcresult`）。
- 完整macOS `470 total / 469 passed / 1 explicit Keychain skip / 0 failed`（`/tmp/LuneX-14-5_5-full.G8yfCE/LuneXCoreTests.xcresult`），测试显式移除`LUNEX_RUN_KEYCHAIN_TEST`，唯一skip精确为真实Keychain round-trip。
- macOS、固定iPhone 17 Pro、iPad Pro 13-inch (M5)、Apple TV与Apple Vision Pro Debug warnings-as-errors build-only全部通过（`/tmp/LuneX-14-5_5-builds.aZ3I4a`）；前后simulator规范化JSON逐字节一致，四个固定实例唯一、可用且`Shutdown`，全局`Booted=0`。
- OpenSpec strict `5 passed / 0 failed`，generator生成前与三次生成SHA-256均为`8ba9f47017c9aca22655a7efdd638f7a01b05be995cd139cf36c50475e6211fd`，project无漂移、whitespace、reference和ThirdParty边界通过（`/tmp/LuneX-14-5_5-repo-gates.lB9GkQ`）。OpenSpec 5.5标记完成，权威进度`23/29`；下一项6.1为normal tests/唯一Keychain skip门，阶段13仍为`54/61 in_progress`。

## 2026-07-21 阶段 14 任务 6.1 启动

- 5.5已以`db11c35 Gate macOS application integration`独立提交并推送，确认`HEAD == origin/main`且工作树clean后进入6.1。
- 测试树仅有`LUNEX_RUN_KEYCHAIN_TEST`一个opt-in变量；本项将从全新DerivedData执行normal macOS suite并显式移除该变量，结构化核对唯一skip。阶段13 9.2缺失的live-host XCTest不视为本项通过证据。

## 2026-07-21 阶段 14 任务 6.1 完成

- 从`db11c35`干净提交基线和全新DerivedData运行normal macOS suite，显式移除`LUNEX_RUN_KEYCHAIN_TEST`；结果`470 total / 469 passed / 1 explicit Keychain skip / 0 failed`（`/tmp/LuneX-14-6_1-normal.8p8JY5/Normal.xcresult`）。
- 串行结构化读回确认唯一skip为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`；测试树没有live-host XCTest/opt-in开关，因此阶段13 9.2继续标记为缺失，不能把不存在的测试算作disabled pass。
- OpenSpec strict `5/5`、generator三次SHA-256 `8ba9f47017c9aca22655a7efdd638f7a01b05be995cd139cf36c50475e6211fd`、project/whitespace/reference边界通过（`/tmp/LuneX-14-6_1-repo-gates.EkT8SN`）。OpenSpec 6.1标记完成，权威进度`24/29`；下一项6.2为macOS Debug/Release与固定iPhone/iPad/tvOS/visionOS warnings-as-errors构建门。

## 2026-07-21 阶段 14 任务 6.2 启动

- 6.1主记录与迟到的repository-gate证据已分别以`005c6dd`、`c82649b`提交并推送；确认`HEAD == origin/main`后进入6.2。提交后另一路遗留写入曾把两条已提交证据覆盖为旧尾部，并导致首次`apply_patch`上下文校验失败；已基于Git证据合并恢复，不使用回退命令。
- 本项从只读simulator快照开始，对macOS与固定iPhone 17 Pro、iPad Pro 13-inch (M5)、Apple TV、Apple Vision Pro分别执行Debug/Release warnings-as-errors build-only；每个构建使用隔离DerivedData，不create、boot、run或shutdown任何simulator。
- 首次构建矩阵包装器因`/bin/bash -lc`脚本文本又被外层zsh解释，`jq`引号在进入bash前破坏并以127退出；失败发生在创建证据目录和任何`xcodebuild`/simulator操作之前。后续改由执行工具直接选择`/bin/bash`，不重复嵌套shell方案。
- 第一轮十构建均`BUILD SUCCEEDED`且simulator不变，但每个日志都有Xcode `appintentsmetadataprocessor`对项目未链接AppIntents的skip warning。第二轮从Xcode `AppIntentsMetadata.xcspec`采用`LM_FILTER_WARNINGS=YES`，命令已带`--quiet-warnings`但Xcode 26.4仍输出相同warning；最终零诊断检查因此退出1，不能作为最终门。下一步用SwiftBuild平台插件公开的`LM_SKIP_METADATA_EXTRACTION=YES`先做单点验证。

## 2026-07-21 阶段 14 任务 6.2 完成

- `LM_SKIP_METADATA_EXTRACTION=YES`单点门通过：未使用的AppIntents extractor rule不再运行，macOS Debug构建成功且日志零诊断（`/tmp/LuneX-14-6_2-appintents-probe.fyVIfl`）。
- 最终macOS、固定iPhone 17 Pro、iPad Pro 13-inch (M5)、Apple TV与Apple Vision Pro的Debug/Release共十个warnings-as-errors build-only全部通过，10个日志零`warning:`/`error:`，证据`/tmp/LuneX-14-6_2-builds-final2.IXQDK5`。
- simulator规范化快照前后SHA-256同为`b6b4a5f0e17cb704abfa9cfe669beeebe176286fa52e096b33563bc1ba356db8`；固定UUID各唯一、可用且全部`Shutdown`，全局`Booted=0`。OpenSpec 6.2标记完成，权威进度`25/29`；下一项6.3为深度质量门。

## 2026-07-21 阶段 14 任务 6.3 启动

- 6.2已以`8e261dc Verify Apple platform release builds`独立提交并推送，确认`HEAD == origin/main`且工作树clean后进入6.3。
- 复用阶段13任务9.6的严格口径并覆盖当前新增macOS input/lifecycle ownership：五个OpenSpec strict、generator三次、fixture/clean-room/dependency边界、macOS Debug/Release analyzer、完整ASan、完整TSan，以及malloc/resource teardown选择集。所有测试显式移除`LUNEX_RUN_KEYCHAIN_TEST`，不访问live host或真实Keychain。

## 2026-07-21 阶段 14 任务 6.3 完成

- repository门通过：OpenSpec strict `5/5`、fixture self-test/全树、generator生成前/三次SHA-256均为`8ba9f47017c9aca22655a7efdd638f7a01b05be995cd139cf36c50475e6211fd`，clean-room/reference、无Swift package与固定ENet边界通过（`/tmp/LuneX-14-6_3-repo.vQa7C6`）。
- Debug/Release analyzer成功且结构化结果一致：自有bridge 0项，固定ENet每配置4项已披露finding，无新增（`/tmp/LuneX-14-6_3-static.VoMRXW`）。
- 完整ASan与TSan各`470 total / 469 passed / 1 Keychain skip / 0 failed`且零sanitizer报告；ASan首轮日志正则误把命令行`-enableAddressSanitizer`当作报告并退出1，收紧到实际`ERROR:`/`SUMMARY:`前缀后同一结果通过，无需重跑。
- 17类malloc/resource集合在scribble、guard edges、stack logging、heap check和error-abort下通过`250/250`，零malloc报告。最终汇总脚本首次在zsh误用保留的`path`变量覆盖`PATH`而找不到`cmp`，改为直接bash和`evidence_path`后全门汇总通过。
- OpenSpec 6.3标记完成，权威进度`26/29`；下一项6.4为固定simulator identity/state独立只读门，6.5真实Sunshine/hardware仍不以离线证据替代。

## 2026-07-21 阶段 14 任务 6.4 启动

- 6.3已以`e59bf5f Run macOS lifecycle quality gates`独立提交并推送，确认`HEAD == origin/main`且工作树clean后进入6.4。
- 本项只读获取当前CoreSimulator JSON，并与6.2最终构建矩阵的before/after规范化快照比较；不执行build/test，也不调用create、clone、boot、bootstatus、shutdown、delete或app run/install。

## 2026-07-21 阶段 14 任务 6.4 完成

- 6.2 before/after与6.4当前三份规范化simulator快照逐字节一致，SHA-256均为`b6b4a5f0e17cb704abfa9cfe669beeebe176286fa52e096b33563bc1ba356db8`（`/tmp/LuneX-14-6_4-simulator-audit.zJRuWk`）。
- 四个固定名称与UUID各唯一、可用且全部`Shutdown`，所有available simulator的`Booted=0`；本项仅只读list/compare，没有build/test或设备状态命令。
- OpenSpec 6.4标记完成，权威进度`27/29`。6.5仍要求授权Sunshine host、物理鼠标和多显示器，不以模拟器/fixture替代；下一可执行项为6.6最终跟踪、剩余限制与提交推送。

## 2026-07-21 阶段 14 任务 6.6 完成

- 阶段14路线图已同步production、normal/五平台、strict/generator/dependency、analyzer/ASan/TSan/malloc与simulator证据，补充6.5授权Sunshine版本/test app、物理键鼠、focus/occlusion、resize和不同scale多显示器的逐项checklist。
- OpenSpec 6.6标记完成，权威进度`28/29 in_progress`；6.5未执行，change不可archive且阶段不标记complete。阶段13仍为`54/61`和7项live/hardware缺口，不做跨阶段证据替代。
- 6.1至6.4均已逐项独立提交推送；本项完成strict/diff验收和独立提交推送后，将再执行一次阶段14级离线自验，然后创建并推进阶段15 `implement-native-hdr-edr-pipeline`。

## 2026-07-21 阶段 14 离线阶段级自验

- 在已推送`3ef99ee`、clean tree和全新DerivedData上，完整macOS suite通过`470 total / 469 passed / 1 explicit Keychain skip / 0 failed`且日志零诊断（`/tmp/LuneX-14-stage-acceptance.ce4byY/Stage14Acceptance.xcresult`）。
- OpenSpec strict `5/5`、project hash稳定、HEAD/远端一致；只读复核固定simulator全部可用且`Shutdown`，全局`Booted=0`。
- 阶段14 offline acceptance通过，但状态仍为`28/29 in_progress`，唯一6.5真实Sunshine/硬件门保持pending；下一步进入阶段15 OpenSpec提案和确定性实现。

## 2026-07-21 阶段 15 OpenSpec 创建

- 创建`implement-native-hdr-edr-pipeline`的proposal、design、三份capability spec和33项依赖有序tasks；OpenSpec strict validation通过且change为apply-ready，权威进度`0/33`。
- HDR change明确连接现有metadata/P010/Metal plane/headroom foundation，替换actual fixed-sRGB presentation为显式Metal color/tone-map/surface contract；不引入第三方或GPL依赖。
- 物理HDR/SDR显示器、亮度/颜色、HDR signaling、headroom和跨屏验证保留6.5，不由shader readback、模拟器或layer property替代。提案独立提交推送后进入1.1 inventory。

## 2026-07-21 阶段 15 任务 1.1 启动

- OpenSpec提案已以`65c28eb Plan native HDR EDR pipeline`独立提交并推送，确认`HEAD == origin/main`且工作树clean；change权威进度`0/33`。
- 1.1仅盘点decoded格式、metadata ownership、actual renderer、Apple EDR API、平台差异和物理硬件证明边界，不修改runtime行为；后续immutable合同与production实现分别从1.2开始。
- Apple API结论以本机Xcode 26.4 SDK headers/module availability与严格typecheck为准；上游仓库只读，不复制代码。测试继续不访问真实Keychain，也不创建、启动或运行simulator。

## 2026-07-21 阶段 15 任务 1.1 完成

- `docs/runtime/hdr-edr-contract.md`固化当前production数据流、未接线Metal mapper/queue、fixed-sRGB actual presenter、display-vs-stream HDR误接、Apple SDK 26.4 API矩阵和硬件证明边界；没有修改runtime源码。
- warnings-as-errors SDK probe确认macOS/iOS完整headroom+layer EDR能力、tvOS仅UIScreen headroom/颜色空间且layer EDR unavailable、visionOS layer EDR可编译但UIScreen unavailable；首个统一probe在tvOS按真实availability失败后拆分验证，未放宽平台假设。
- OpenSpec 1.1标记完成，权威进度`1/33`。下一项1.2定义immutable color/display/surface value contract和closed resolver errors。

## 2026-07-21 阶段 15 任务 1.2 启动

- 1.1已以`9dd3ba6 Inventory native HDR EDR boundaries`独立提交并推送，确认`HEAD == origin/main`且工作树clean；OpenSpec权威进度`1/33`。
- 1.2仅定义platform-neutral immutable color signature、display revision、platform capability、mapping mode、surface/metadata/render configuration合同和fail-closed invariant errors；不连接actual presenter、shader、AppModel或lifecycle。
- 新合同必须能区分tvOS的headroom-without-layer-EDR与visionOS的layer-EDR-without-headroom，并保证SDR、HDR-to-SDR与HDR-EDR surface组合不可被静默混用。

## 2026-07-21 阶段 15 任务 1.2 完成

- 新增`HDRRenderColorSignature`、`HDRDisplayRevision`、`HDRPlatformOutputCapabilities`、`HDRMappingMode`、`HDRSurfaceContract`、`HDRRenderConfigurationIdentity`和closed `HDRRenderResolutionError`；`VideoColorMetadata`值类型增加`Hashable`，但metadata ownership仍保持单一且没有runtime wiring。
- surface合同只接受BGRA8+sRGB SDR或RGBA16Float+extended-linear P3/BT.2020 HDR10 EDR组合；configuration拒绝generation/revision 0、SDR/HDR source与mapping错配以及mapping/surface错配。tvOS与visionOS capability不对称得到独立测试覆盖。
- focused结果`12/12`（`/tmp/LuneX-15-1_2-focused-final.qzvPB6/HDRRenderContract.xcresult`）；完整macOS suite为`482 total / 481 passed / 1 explicit Keychain skip / 0 failed`（`/tmp/LuneX-15-1_2-full.JvPq5Q/LuneXCoreTests.xcresult`）。唯一skip仍是`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，所有命令显式移除`LUNEX_RUN_KEYCHAIN_TEST`。
- macOS、固定iPhone、iPad、tvOS与visionOS五平台Debug warnings-as-errors build-only全部通过（`/tmp/LuneX-15-1_2-builds.MjyUqg`）；simulator前后规范化状态逐字节一致，四个固定设备均唯一、可用、`Shutdown`且全局`Booted=0`，未执行设备create/clone/boot/launch/shutdown/delete。
- repository gates位于`/tmp/LuneX-15-1_2-repo-gates-final.6fIeqD`：OpenSpec strict `6/6`、generator三次稳定且SHA-256为`be87633006a8ab40568fa6b9bb0be5de3018c40a93f80fbf1d9438775aaac0d9`、production/reference边界、无Swift Package、精确Keychain skip与`git diff --check`通过。
- OpenSpec 1.2标记完成，权威进度`2/33`。本证据不证明actual `CVPixelBuffer`布局、production presenter、shader readback、layer runtime property或物理HDR/SDR亮度与颜色；下一项1.3实现actual decoded layout/metadata compatibility validator。

## 2026-07-21 阶段 15 任务 1.3 启动

- 1.2已以`1d4d9bc Define immutable HDR render contracts`独立提交并推送，确认`HEAD == origin/main`且工作树clean；OpenSpec权威进度`2/33`。
- 1.3限定为actual CoreVideo pixel format/plane geometry、bit depth/range、negotiated codec与primaries/transfer/matrix/light metadata compatibility validator；不绑定frame generation/signature、不修改mapper/queue/presenter或AppModel。
- production只接受8-bit NV12 video-range Rec.709 SDR和HEVC/AV1 10-bit P010 video-range BT.2020/PQ HDR10。真实pixel buffer读取与可注入layout错误路径都必须确定性覆盖。

## 2026-07-21 阶段 15 任务 1.3 完成

- 新增`HDRDecodedVideoContractValidator`，从actual `CVPixelBuffer`读取pixel format、image/plane尺寸并只接受8-bit NV12 video-range或10-bit P010 video-range；full-range、BGRA、错误plane count/geometry和bit-depth mismatch均返回typed closed failure。
- validator将HDR10限定为HEVC/AV1 + 10-bit + BT.2020/PQ/BT.2020，并将SDR限定为8-bit Rec.709；`VideoColorMetadata.validate()`继续验证MDCV、CLL和maximum-full-frame-luminance边界。返回contract保留codec和完整immutable `HDRRenderColorSignature`，不从mutable CoreVideo attachment猜测新语义。
- focused结果`8/8`（`/tmp/LuneX-15-1_3-focused.dJioYj/HDRDecodedVideoContract.xcresult`）；完整macOS suite为`490 total / 489 passed / 1 explicit Keychain skip / 0 failed`（`/tmp/LuneX-15-1_3-full.K1E4Eu/LuneXCoreTests.xcresult`），日志零源码诊断。唯一skip精确为`testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，命令显式移除`LUNEX_RUN_KEYCHAIN_TEST`。
- macOS、固定iPhone、iPad、tvOS与visionOS五平台Debug warnings-as-errors build-only全部通过（`/tmp/LuneX-15-1_3-builds-final.fyVqH8`）；simulator前后规范化SHA-256均为`045d55961d523ff13abb1b67d8f084a479050cfdab82af71e1e3e451a96ce7c8`，固定四设备均唯一、可用、`Shutdown`且全局`Booted=0`，未执行create/clone/boot/launch/shutdown/delete。
- repository gates位于`/tmp/LuneX-15-1_3-repo-gates-final.4UGNTO`：OpenSpec strict `6/6`、generator运行前和三次运行SHA-256均为`1e2fc40dec8a16717f09efad32859318c3b377db6135edd04f82bde2d9767cae`、project无漂移、production/reference边界、无Swift Package及`git diff --check`通过。
- OpenSpec 1.3标记完成，权威进度`3/33`。本证据不证明frame generation/signature binding、Metal texture layout/device ownership、renderer、shader或物理HDR；下一项1.4实现platform-neutral video-range、Rec.709/BT.2020 matrix、SDR transfer、PQ与gamut reference math。

## 2026-07-21 阶段 15 任务 1.4 启动

- 1.3已以`09d6533 Validate decoded HDR video contracts`独立提交并推送，确认`HEAD == origin/main`且工作树clean；OpenSpec权威进度`3/33`。
- 1.4实现pure Swift reference math：8/10-bit video-range normalization、Rec.709/BT.2020 non-constant-luminance YCbCr matrix、BT.709 inverse transfer、ST 2084 PQ EOTF和D65 sRGB/Display-P3/BT.2020 linear gamut conversion。
- 输入code/finite bounds和输出finite结果必须fail closed；本项不实现1.5 source peak/headroom shoulder，不接入shader或production presenter。

## 2026-07-21 阶段 15 任务 1.4 完成

- 新增pure Swift `HDRColorReferenceMath`：8/10-bit video-range code normalization、Rec.709/BT.2020 non-constant-luminance YCbCr、BT.709 inverse transfer、ST 2084 PQ绝对nits EOTF和D65 sRGB/Display-P3/BT.2020 linear gamut conversion；非有限、code越界与过大linear input均typed fail closed。
- focused `7/7`（`/tmp/LuneX-15-1_4-focused-final.aMIRAd/HDRColorReferenceMath.xcresult`）；完整macOS `497 total / 496 passed / 1 explicit Keychain skip / 0 failed`（`/tmp/LuneX-15-1_4-full.5aiVKx/LuneXCoreTests.xcresult`），唯一skip仍为真实Keychain opt-in且日志零源码诊断。
- macOS、固定iPhone/iPad/tvOS/visionOS五平台Debug warnings-as-errors通过（`/tmp/LuneX-15-1_4-builds.6aJ4jz`）；simulator前后SHA-256均为`045d55961d523ff13abb1b67d8f084a479050cfdab82af71e1e3e451a96ce7c8`，全部固定设备`Shutdown`且全局`Booted=0`。
- repository gates位于`/tmp/LuneX-15-1_4-repo.lZwC8m`：OpenSpec strict `6/6`、generator三次稳定且project SHA-256为`fd2e7fba3373edcdb1abc50415dd44440fd37d20f26b87c4210756c37642b367`、reference/dependency/whitespace边界通过。
- OpenSpec 1.4标记完成，权威进度`4/33`。本证据不证明1.5 source peak/headroom shoulder、Metal shader、production output或物理HDR；下一项1.5。

## 2026-07-21 阶段 15 任务 1.5 启动

- 1.4已以`98ad24b Implement HDR color reference math`独立提交并推送，确认`HEAD == origin/main`且工作树clean；OpenSpec权威进度`4/33`。
- source peak从validated mastering maximum与非零MaxCLL取安全约束，缺失时使用1000-nit fallback，并限制为100...10000 nits且暴露basis/clamp状态。
- 100 nits及以下保持`nits/100`；显示可直接容纳时保持线性EDR，否则仅对highlights使用连续单调shoulder并严格受current headroom限制。potential headroom不参与本合同。

## 2026-07-21 阶段 15 任务 1.5 完成

- 新增`HDRSourcePeakResolver`和`HDRLuminanceMapping`：mastering/MaxCLL取安全约束并暴露basis，缺失使用1000-nit fallback，结果限制100...10000 nits；current headroom限定1...64且potential headroom不进入输入。
- mapping在100 nits及以下保持`nits/100`，source peak可直接容纳时线性映射，否则以连续单调log shoulder压入current headroom；headroom=1提供明确SDR fallback并保持reference white。
- focused `7/7`（`/tmp/LuneX-15-1_5-focused-final.G92DHJ/HDRLuminanceMapping.xcresult`）；完整macOS `504 total / 503 passed / 1 explicit Keychain skip / 0 failed`（`/tmp/LuneX-15-1_5-full.nZTm5t/LuneXCoreTests.xcresult`），唯一skip和日志边界通过。
- 五平台Debug warnings-as-errors通过（`/tmp/LuneX-15-1_5-builds.louq0p`）；simulator前后SHA-256均为`045d55961d523ff13abb1b67d8f084a479050cfdab82af71e1e3e451a96ce7c8`，固定设备均`Shutdown`且全局`Booted=0`。
- repository gates位于`/tmp/LuneX-15-1_5-repo.z327fj`：OpenSpec strict `6/6`、generator三次稳定且project SHA-256为`6342e672d7af9aff2908bda8551eb10b22b20ba85cee844fe0e422f90920100d`、reference/dependency/whitespace门通过。
- OpenSpec 1.5标记完成，权威进度`5/33`。未接入shader/renderer/surface且不证明物理HDR；下一项1.6。

## 2026-07-21 阶段 15 任务 1.6 启动

- 1.5已以`0e47f99 Implement HDR luminance mapping`独立提交并推送，确认`HEAD == origin/main`且工作树clean；OpenSpec权威进度`5/33`。
- 1.6新增有界确定性网格，覆盖8/10-bit code domain、BT.709/PQ monotonicity、D65 gamut cube round-trip、source-peak metadata truth table、multiple source/headroom shoulder continuity和decoded codec/dynamic-range组合。
- 测试不使用随机输入，不访问Keychain/host/simulator runtime，也不把CPU contract描述为shader或物理HDR证明。

## 2026-07-21 阶段 15 任务 1.6 完成

- 新增有界deterministic grids覆盖8/10-bit code domain、4097点BT.709/PQ monotonicity、三gamut 5x5x5 cube round-trip、24组source/headroom shoulder、metadata fallback truth table及codec/dynamic-range组合。
- 网格发现rounded BT.709 inverse transfer在0.081附近有向下跳变；production改用连续精确alpha/beta与`4.5*beta`cut，1.4+1.6联合focused重跑`14/14`（`/tmp/LuneX-15-1_6-focused-recheck.uRruj7/HDRFoundation.xcresult`）。
- 完整macOS `512 total / 511 passed / 1 explicit Keychain skip / 0 failed`（`/tmp/LuneX-15-1_6-full.qqQNp2/LuneXCoreTests.xcresult`）；五平台Debug warnings-as-errors通过（`/tmp/LuneX-15-1_6-builds.Hdh9rO`），simulator前后哈希均为`045d55961d523ff13abb1b67d8f084a479050cfdab82af71e1e3e451a96ce7c8`。
- repository gates位于`/tmp/LuneX-15-1_6-repo.luZbmL`：OpenSpec strict `6/6`、generator三次稳定且project SHA-256为`1c8a50a136572246843d406311257caef1f45e443e9bd97d9ea11219786d2682`、reference/dependency/whitespace门通过。
- OpenSpec 1.6标记完成，权威进度`6/33`。CPU合同不证明shader/physical HDR；下一项2.1。

## 2026-07-21 阶段 15 任务 2.1 启动

- 从`71660be`、`HEAD == origin/main`和clean tree恢复；OpenSpec `implement-native-hdr-edr-pipeline`为`6/33 ready`，下一项确认为2.1。
- 本项仅在decoded frame创建时冻结decoder generation与metadata-derived color signature，Metal frame透传同一binding，并对active render configuration执行typed generation/signature compatibility；不提前实现2.2 plane/device validation、2.3 queue revision/flush或presenter wiring。
- 所有现有`DecodedVideoFrame`字段均无构造后赋值，能收紧为不可变`let`；raw `VideoColorMetadata`只由decoded frame持有，Metal frame不复制第二份raw metadata。
- frame binding与render contract的首轮focused warnings-as-errors门通过`19/19`、零skip/失败（`/tmp/LuneX-15-2_1-focused.Y17NwU/FrameBinding.xcresult`）；命令显式移除`LUNEX_RUN_KEYCHAIN_TEST`且不访问网络或simulator。
- 本轮恢复后的focused包装先后发现三项验收错误：误用无test action的`LuneX-macOS` scheme；zsh只读变量`status`覆盖返回码；HDR/SDR配置helper加入局部变量后缺显式`return`。前两项未改变源码行为，第三项已修为`return try HDRRenderConfigurationIdentity(...)`；最终证据不复用这些失败运行。
- 完整macOS suite通过`514 total / 513 passed / 1 skipped / 0 failed`（`/tmp/LuneX-15-2_1-full.G6y7ZL/LuneXCoreTests.xcresult`），唯一skip精确为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，构建日志零warning/error。
- macOS、固定iPhone、iPad、tvOS与visionOS五平台Debug warnings-as-errors build-only全部通过（`/tmp/LuneX-15-2_1-builds.bEQNit`）；simulator前后规范化SHA-256均为`045d55961d523ff13abb1b67d8f084a479050cfdab82af71e1e3e451a96ce7c8`，四个固定实例均唯一、可用且`Shutdown`，全局`Booted=0`。
- repository首轮包装器已通过OpenSpec strict `6/6`和generator三次稳定，但裸`references/`扫描把`Library/Preferences/`的字符子串误报并以1退出；该误报不是production reference泄漏，后续改用路径token边界且不重复已通过门。

## 2026-07-21 阶段 15 任务 2.1 完成

- 最终focused warnings-as-errors gate通过`19/19`、零skip/失败（`/tmp/LuneX-15-2_1-focused-final2.d3RLRD/FrameBinding.xcresult`）；覆盖immutable metadata snapshot、SDR/HDR matching configuration、stale generation/signature和真实8/10-bit VideoToolbox-to-Metal frame binding。
- 完整macOS结构化通过`514 total / 513 passed / 1 explicit Keychain skip / 0 failed`（`/tmp/LuneX-15-2_1-full.wcwquA/LuneXCoreTests.xcresult`）；唯一skip精确为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，命令显式移除`LUNEX_RUN_KEYCHAIN_TEST`。
- 五平台Debug warnings-as-errors build-only全部通过（`/tmp/LuneX-15-2_1-builds.JbfIV0`）。simulator构建前后规范化SHA-256均为`faab504ded9ac0f2b4e78151ee2dc98182575d55f37231dca28a5a8a9409d944`，四个固定实例各唯一、可用且`Shutdown`，全局`Booted=0`。
- repository gates通过（`/tmp/LuneX-15-2_1-repo.4udJFX`）：OpenSpec strict `6/6`、fixture self-test/全树、generator三次稳定且project SHA-256为`1c8a50a136572246843d406311257caef1f45e443e9bd97d9ea11219786d2682`、production/reference/dependency与whitespace边界全部通过。
- OpenSpec 2.1标记完成，权威进度`7/33`。本项不证明2.2 mapper完整验证、2.3 queue revision/flush、Metal shader、production HDR输出或物理显示器行为；下一项2.2。
- 未完成门重跑时，按最新mtime选中了同范围并发验收流的不同证据目录布局，边界/diff/status已执行但最终hash文件名不存在而退出；源码未变化，后续固定核对`D3aZxd`与`4udJFX`，不再按mtime猜测。
- final2 focused/full xcresult、唯一Keychain skip与五个平台成功日志已直接读回；其build目录未保留所记录的simulator before/after JSON，因此不以该目录复证inventory，改用本轮`/tmp/LuneX-15-2_1-builds.bEQNit`中前后逐字节一致的快照作为2.1 simulator证据。
- `bEQNit` simulator快照已再次`cmp`并验证固定设备/`Booted=0`；随后OpenSpec artifact读回误按顶层`.valid`而非`.items[].valid`退出，后续仅按真实schema重跑尚未完成的repository检查。

## 2026-07-21 阶段 15 任务 2.2 启动

- 2.1实现已以`db45bcd`推送，补充验收读回以`60bb957`推送；`HEAD == origin/main`且工作树clean，OpenSpec权威进度`7/33`。
- 现有mapper能创建8/10-bit Metal planes并合并检查texture尺寸/format/device，但只要求CoreVideo plane尺寸为正，没有复用1.3 exact image/luma/chroma geometry，也没有在texture创建前验证actual pixel layout与frozen color signature。
- 本轮大补丁遇到同范围并发实现后被原子拒绝且无部分写入；审计后沿用其`validateForMetalMapping`、explicit plane contracts与dimension/format/device validators，不创建第二套合同。
- `HDRDecodedVideoContractTests + MetalVideoFrameDeliveryTests` focused warnings-as-errors通过`17/17`、零skip/失败（`/tmp/LuneX-15-2_2-focused.lT2uQr/MetalMapping.xcresult`）。
- 完整macOS suite通过`516 total / 515 passed / 1 explicit Keychain skip / 0 failed`（`/tmp/LuneX-15-2_2-full.iEyO5I/LuneXCoreTests.xcresult`），唯一skip精确为允许的真实Keychain round-trip，命令显式移除`LUNEX_RUN_KEYCHAIN_TEST`且日志零warning/error。
- macOS、固定iPhone/iPad/tvOS/visionOS五平台Debug warnings-as-errors build-only全部通过（`/tmp/LuneX-15-2_2-builds.3TxwnW`）；simulator前后规范化SHA-256均为`045d55961d523ff13abb1b67d8f084a479050cfdab82af71e1e3e451a96ce7c8`，固定实例唯一、可用且`Shutdown`，全局`Booted=0`。

## 2026-07-21 阶段 15 任务 2.2 完成

- `validateForMetalMapping`让decoder与mapper共享8/10-bit video-range、exact luma/chroma geometry及完整metadata规则；mapper在texture创建前比较validated signature与2.1 frozen binding，并以explicit plane contracts约束`.r8/.rg8`或`.r16/.rg16`。
- mapped texture分别typed验证dimensions、pixel format与active device registry ownership，不再以单一layout错误混合三种失败；真实VideoToolbox 8/10-bit frame仍保持zero-copy CoreVideo texture ownership。
- focused `17/17`、完整macOS `516 total / 515 passed / 1 explicit Keychain skip / 0 failed`、五平台Debug warnings-as-errors和只读simulator不变门通过。repository gates位于`/tmp/LuneX-15-2_2-repo.sKcOvW`：OpenSpec strict `6/6`、fixture self-test/全树、generator三次稳定且SHA-256为`1c8a50a136572246843d406311257caef1f45e443e9bd97d9ea11219786d2682`、reference/dependency/whitespace边界通过。
- OpenSpec 2.2标记完成，权威进度`8/33`。本项不证明2.3 queue color/display revision rejection与flush、Metal shader、production presenter/surface或物理HDR显示；下一项2.3。

## 2026-07-21 阶段 15 任务 2.3 启动

- 2.2已以`48b2359 Validate Metal video frame contracts`独立提交并推送，`HEAD == origin/main`且工作树clean；OpenSpec权威进度`8/33`。
- queue调用面仅限当前类型与测试，因此删除generation-only decoder-event消费旁路，改为显式`HDRRenderConfigurationIdentity` apply/enqueue/dequeue/stop API；这防止后续presentation绕过color/display revision ownership。
- configuration transition清queued frame并flush mapper；queued entry保存映射时configuration，enqueue/dequeue依次拒绝stale generation、color signature、display revision与其余mapping/surface contract，stale调用不能清除replacement queue。
- focused warnings-as-errors通过`10/10`、零skip/失败（`/tmp/LuneX-15-2_3-focused.ttjPti/QueueRevisions.xcresult`）。
- 完整macOS suite通过`517 total / 516 passed / 1 explicit Keychain skip / 0 failed`（`/tmp/LuneX-15-2_3-full.lv2SaQ/LuneXCoreTests.xcresult`），唯一skip精确为允许的真实Keychain round-trip，日志零warning/error。
- 首轮五平台包装器在首个build前因Bash同一`local`声明提前引用`n`而被`set -u`拒绝；仅生成只读simulator before快照，没有执行xcodebuild或任何设备状态命令。后续分行赋值并从新目录完整重跑。
- 最终macOS、固定iPhone/iPad/tvOS/visionOS五平台Debug warnings-as-errors build-only全部通过（`/tmp/LuneX-15-2_3-builds-final.B23yJ4`）；simulator前后SHA-256均为`045d55961d523ff13abb1b67d8f084a479050cfdab82af71e1e3e451a96ce7c8`，固定实例唯一、可用且`Shutdown`，全局`Booted=0`。

## 2026-07-21 阶段 15 任务 2.3 完成

- `BoundedMetalFrameQueue`现由完整`HDRRenderConfigurationIdentity`而非generation单独驱动；queued entry绑定映射时configuration，所有配置变化先清旧entry并flush mapper，再发布replacement identity。
- enqueue/dequeue依次typed拒绝stale generation、color signature、display revision及mapping/surface contract。stale dequeue返回nil但保留current queue，current configuration随后仍能取得replacement frame；各类drop与generation/render-contract reset分别计数。
- focused `10/10`、完整macOS `517 total / 516 passed / 1 explicit Keychain skip / 0 failed`、五平台Debug warnings-as-errors和simulator不变门通过。repository gates位于`/tmp/LuneX-15-2_3-repo.9QB8QY`：OpenSpec strict `6/6`、fixtures、generator三次稳定且SHA-256为`1c8a50a136572246843d406311257caef1f45e443e9bd97d9ea11219786d2682`、reference/dependency/whitespace边界通过。
- OpenSpec 2.3标记完成，权威进度`9/33`。本项不证明2.4扩大matrix、shader/renderer/presenter、surface signaling或物理HDR行为；下一项2.4。

## 2026-07-21 阶段 15 任务 2.4 启动

- 2.3已以`f54f5a7 Revision Metal frame queue contracts`独立提交并推送，`HEAD == origin/main`且工作树clean；OpenSpec权威进度`9/33`。
- 2.4仅扩大测试矩阵，不新增production抽象：真实8/10-bit buffer经production mapper+queue覆盖SDR/HDR；layout failure后later current frame恢复；generation/display stale dequeue保留replacement；replacement/cache flush与stop/late frame teardown按exact counter验证。
- focused warnings-as-errors通过`13/13`、零skip/失败（`/tmp/LuneX-15-2_4-focused.zj5jWj/FrameContractMatrix.xcresult`）。
- 完整macOS suite通过`520 total / 519 passed / 1 explicit Keychain skip / 0 failed`（`/tmp/LuneX-15-2_4-full.GBqvtu/LuneXCoreTests.xcresult`），唯一skip精确为允许的真实Keychain round-trip，日志零warning/error。
- macOS、固定iPhone/iPad/tvOS/visionOS五平台Debug warnings-as-errors build-only全部通过（`/tmp/LuneX-15-2_4-builds.0Lccsq`）；simulator前后SHA-256均为`045d55961d523ff13abb1b67d8f084a479050cfdab82af71e1e3e451a96ce7c8`，固定实例唯一、可用且`Shutdown`，全局`Booted=0`。

## 2026-07-21 阶段 15 任务 3.1 启动

- 2.4已以`23962fa Gate Metal frame contract transitions`独立提交并推送，确认`HEAD == origin/main`且工作树clean；OpenSpec权威进度`10/33`。
- 3.1范围限定为repository-owned Metal shader资源与可编译pure shader functions，覆盖video-range、YCbCr matrix、transfer decode、gamut conversion、luminance mapping和opaque output；typed Swift uniforms/pipeline cache、renderer与readback分别留给3.2至3.4。
- 四个平台`xcrun --sdk ... metal --version`均报告缺少Xcode Metal Toolchain；先通过官方`xcodebuild -downloadComponent MetalToolchain`安装，不以Swift编译或文本扫描替代shader编译证明。

## 2026-07-21 阶段 15 任务 3.1 完成

- 安装官方Metal Toolchain后，新增`HDRVideoShaders.metal`，覆盖8-bit NV12与left-aligned P010 video-range normalization、Rec.709/BT.2020 YCbCr、continuous Rec.709 inverse transfer、ST 2084 PQ absolute nits、sRGB/Display-P3/BT.2020 gamut conversion、reference-white shoulder、finite final bound和opaque alpha；HDR-to-SDR明确使用headroom `1.0`。
- generator将`.metal`作为`sourcecode.metal`纳入四个App与macOS test target的Sources phase，并以`MTL_FAST_MATH=NO`和`MTL_TREAT_WARNINGS_AS_ERRORS=YES`编译；focused测试从测试bundle的`default.metallib`读回vertex/fragment entry points并通过`8/8`（`/tmp/LuneX-15-3_1-focused-r2.iM4OlJ`）。
- 完整macOS suite通过`521 total / 520 passed / 1 explicit Keychain skip / 0 failed`（`/tmp/LuneX-15-3_1-full.ENQuct`），唯一skip精确为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，命令显式移除`LUNEX_RUN_KEYCHAIN_TEST`。
- macOS、固定iPhone/iPad/tvOS/visionOS五平台Debug build-only均实际执行`CompileMetalFile`与`MetalLink`并通过（`/tmp/LuneX-15-3_1-builds.n6rALQ`）；simulator前后SHA-256均为`045d55961d523ff13abb1b67d8f084a479050cfdab82af71e1e3e451a96ce7c8`，固定实例唯一、可用且`Shutdown`，全局`Booted=0`。
- repository gates位于`/tmp/LuneX-15-3_1-repo.kUL0UT`：OpenSpec strict `6/6`、fixtures、generator三次稳定且project SHA-256为`084cbaa6ca1aae12218965e8ffde90718f25d90ed2689653eb67c975b4d8f894`、四SDK precise Metal compile/link、reference/dependency/whitespace边界通过。OpenSpec权威进度`11/33`，下一项3.2。
- 3.1仅证明repository ownership、shader compile/link和entry-point load；pixel-accurate GPU readback归3.4，typed uniforms/cache归3.2，renderer/presenter归3.3/3.5，surface signaling与物理亮度/颜色/跨屏证明仍未完成。

## 2026-07-21 阶段 15 任务 3.2 启动

- 3.1已以`ad42efe Add native HDR Metal shaders`独立提交并推送，确认`HEAD == origin/main`且工作树clean；OpenSpec权威进度`11/33`。
- 3.2限定为固定32-byte Swift/Metal uniform ABI、从validated frame/render configuration生成closed values，以及按input layout/mapping mode/output pixel format键控的bounded thread-safe LRU pipeline cache；不提前接入3.3 renderer或3.5 production presenter。
- 首轮focused通过`8/8`，但审计发现actor cache无法被同步`MTKViewDelegate.draw(in:)`直接消费，且HDR-to-SDR若接受headroom大于1的CPU mapping会形成CPU/GPU合同分歧；改为锁保护同步cache并要求fallback mapping headroom精确为1后重新验收。

## 2026-07-21 阶段 15 任务 3.2 完成

- 新增固定32-byte/4-byte alignment的`HDRMetalShaderUniforms`，逐字段验证Swift offset与Metal ABI；uniform只能由matching validated frame/render configuration创建，HDR source peak必须从immutable color signature复算一致，SDR拒绝HDR mapping，HDR-to-SDR要求CPU mapping headroom精确为1。
- 新增closed `HDRMetalPipelineKey`与真实`AppleHDRMetalPipelineStateFactory`，仅接受NV12/SDR/BGRA8、P010/HDR-to-SDR/BGRA8和P010/HDR-EDR/RGBA16三种组合。同步锁保护LRU cache有明确capacity、hit/miss/failure/eviction/flush计数，支持实时draw回调，并保证同key并发只创建一个state、失败不缓存、清理幂等。
- 最终focused `36/36`且零诊断（`/tmp/LuneX-15-3_2-focused-final.RtsEP5/HDRMetalPipeline.xcresult`）；完整macOS `529 total / 528 passed / 1 explicit Keychain skip / 0 failed`且零诊断（`/tmp/LuneX-15-3_2-full.6wwJEc/LuneXCoreTests.xcresult`）。真实Keychain开关显式移除。
- macOS、固定iPhone/iPad/tvOS/visionOS五平台Debug零诊断build通过（`/tmp/LuneX-15-3_2-builds.ZSe1im`）；simulator前后规范化SHA-256均为`045d55961d523ff13abb1b67d8f084a479050cfdab82af71e1e3e451a96ce7c8`，固定实例唯一、可用且`Shutdown`，全局`Booted=0`。
- repository gates位于`/tmp/LuneX-15-3_2-repo.p6v3tE`：OpenSpec strict `6/6`、fixture self-test/全树、generator三次稳定且project SHA-256为`f077b6b13bfc009f726968bc7b01090284ac089297d407d8d589d22ac8cd376c`、production/reference/dependency与whitespace边界通过；shader未改且SHA-256保持`cc2fd6dcfc451bca929292d3f774b22c919165fb41b7f5bd6a05e47e539f0e2b`。
- OpenSpec 3.2标记完成，权威进度`12/33`。本项不证明renderer command encoding、viewport/video rectangle、GPU readback、production presenter切换或物理HDR；下一项3.3。

## 2026-07-21 阶段 15 任务 2.4 完成

- 新增真实8/10-bit queue mapping矩阵，分别验证SDR `.r8/.rg8`和HDR `.r16/.rg16` output plane及frozen dynamic range；invalid 10-bit/SDR layout抛错后queue ownership不变，later valid frame正常恢复。
- replacement矩阵锁定queued discard、generation reset count、cache flush、stale generation/display dequeue不清current entry、replacement delivery、stop discard/flush、late inactive frame不调用mapper和duplicate stop no-op。
- focused `13/13`、完整macOS `520 total / 519 passed / 1 explicit Keychain skip / 0 failed`、五平台Debug warnings-as-errors和simulator不变门通过。repository gates位于`/tmp/LuneX-15-2_4-repo.J7MgyQ`：OpenSpec strict `6/6`、fixtures、generator三次稳定且SHA-256为`1c8a50a136572246843d406311257caef1f45e443e9bd97d9ea11219786d2682`、reference/dependency/whitespace边界通过。
- OpenSpec 2.4标记完成，权威进度`10/33`。第2组确定性自验完成，但不证明Metal shader、renderer/presenter、surface signaling或物理HDR；下一项3.1。

## 2026-07-21 阶段 15 任务 2.3 启动

- 从`48b2359`恢复，确认`HEAD == origin/main`、初始工作树clean且无运行中的build/git进程；OpenSpec权威进度`8/33`。
- 2.3范围限定为bounded Metal frame queue对active immutable render configuration的所有权、generation/color/display/mapping-surface mismatch拒绝，以及generation/render-contract切换时的queued-frame清理和texture-cache flush；不提前实现2.4完整矩阵、shader、presenter或surface runtime wiring。
- 只读审计期间检测到共享执行流写入`MetalVideoFrameDelivery.swift`而未同步测试；保留并审计该来源不明修改，不回退。当前实现方向为queue持有active configuration、调用方在enqueue/dequeue携带configuration identity、切换时清队列/flush；下一步补齐编译兼容与focused行为测试。
## 2026-07-21 阶段 15 任务 3.3 恢复

- 运行 planning-with-files session catchup，确认未同步内容只是上一轮 `3.2` 已推送、`3.3` 尚未编辑的检查点；`git diff --stat` 为空。
- 核对活动目标仍覆盖阶段 13–20，无需重复创建；仓库为 `main`，`HEAD/origin/main=34c71edb36976814914b29e18a54bcb2d5647377`，工作树 clean，无残留构建/Git写进程。
- 读取 OpenSpec status/apply 指令及 proposal/design/specs/tasks；阶段 15 当前 `12/33`，开始 3.3 injectable generation/revision-owned Metal renderer。
- 记录固定四类 simulator 的唯一、available、`Shutdown` 基线；本任务继续禁用真实 Keychain 测试并保持 simulator inventory 不变。
- 检测并等待共享执行流的3.3 focused测试完成；证据`/tmp/LuneX-15-3_3-focused-result-second.eVOvYz/HDRMetalVideoRenderer.xcresult`为`7/7 passed, 0 skipped, 0 failed`。工作树包含同名renderer/test/shader/generator/project修改，已保留且开始审计，不回退来源不明改动。
- 审计确认基础zero-copy/geometry/真实encoder合同成立，但异步completion ownership和replacement cache复用缺失；进入定向补强并新增late completion回归。
- 3.3 首次 focused 编译失败：测试试图直接构造 `HDRMetalShaderUniforms` 的 raw 字段，但该类型只开放 validated contract/configuration/mapping initializer；production renderer 与 Metal shader 已编译。修复为通过合法 HDR contract 构造与 active SDR configuration 不匹配的 uniforms，继续验证 fail-closed，不增加测试专用后门。
- 3.3 自审补充 HDR stale-signature fixture 后，测试 helper 因局部 `isHDR` 使单表达式函数变为多语句而缺少显式 `return`；编译器在测试执行前拒绝。补上显式返回后从新 DerivedData 重跑，不复用失败证据。
- 随后检测到共享执行流把command submitter扩展为completion-handler合同并加入ownership revision及late-completion测试；保留该补强。同步wait路径改为GPU完成后在调用线程回调，避免renderer持锁等待时Metal completion线程反向等待同一锁；replacement/stop/command failure继续按spec flush renderer-owned pipeline cache。

## 2026-07-21 阶段 15 任务 3.3 完成

- 新增`HDRMetalVideoRenderer`、Apple command submitter和16-byte geometry uniforms；renderer按active generation/color/display/surface ownership验证zero-copy plane、uniform、geometry、device、target及drawable identity，使用明确viewport/scissor、black clear、fragment texture `0/1`和typed buffer `0`编码。异步completion以ownership revision隔离replacement/stop，相关failure和teardown释放pipeline cache。
- 最终focused `9/9`且零失败（`/tmp/LuneX-15-3_3-focused-result-fifth.CxE888/HDRMetalVideoRenderer.xcresult`）；包含真实offscreen Metal command completion、fit/fill crop、same-generation stale HDR signature、zero-copy identity、invalid target/uniform、replacement/stop late completion和submission failure。
- 完整macOS为`538 total / 537 passed / 1 explicit Keychain skip / 0 failed`（`/tmp/LuneX-15-3_3-full-result.LrPP7D/LuneXCoreTests.xcresult`）；唯一skip精确为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，测试命令显式移除`LUNEX_RUN_KEYCHAIN_TEST`。
- macOS及固定iPhone/iPad/tvOS/visionOS五平台Debug warnings-as-errors build-only均`0 warning / 0 error`（`/tmp/LuneX-15-3_3-builds.WgyE0u`）。四个固定simulator前后规范化清单逐字一致，SHA-256均为`c9a13bf461f160776b0acdf63b9562e684a4dd4f5a464fdbe978f2a233b6dbf3`，全部唯一、available且`Shutdown`，未执行设备管理命令。
- repository gates位于`/tmp/LuneX-15-3_3-repo.CeDCBo`：OpenSpec strict `6/6`、fixture self/full、generator三次稳定、project SHA-256为`b340e4ea43bc866bb05d5f2842346cc87968ab282698148d7b406e3db73d0a1d`，production/reference/dependency/whitespace边界通过。
- OpenSpec 3.3标记完成，权威进度`13/33`。本项不证明GPU pixel accuracy、production presenter切换、EDR surface signaling或物理HDR；下一项3.4执行offscreen shader readback并与CPU reference vectors比较。
- 恢复后提交前独立复验再次通过：generator输出SHA-256仍为`b340e4ea43bc866bb05d5f2842346cc87968ab282698148d7b406e3db73d0a1d`，`git diff --check`通过；全新DerivedData下`HDRMetalVideoRendererTests`为`9/9 passed / 0 skipped / 0 failed`（`/tmp/LuneX-15-3_3-reverify.FiOY7J/HDRMetalVideoRenderer.xcresult`），命令显式移除`LUNEX_RUN_KEYCHAIN_TEST`。

## 2026-07-21 阶段 15 任务 3.4 启动

- 3.3已以`1840026 Add revision-owned HDR Metal renderer`独立提交并推送，确认`HEAD == origin/main`且工作树clean；OpenSpec权威进度`13/33`。
- 已重新读取change的proposal/design/三份spec/tasks及现有shader、CPU reference math、luminance mapping、pipeline、renderer与测试合同。3.4限定为真实offscreen shader readback和CPU/GPU oracle，不提前替换3.5 production presenter或实现4.x surface signaling。
- 计划用private `.bgra8Unorm_srgb`/`.rgba16Float` target加blit readback，显式处理sRGB存储编码、RGBA half-float、P010 left-aligned code、格式量化容差、opaque alpha、fit letterbox和fill crop；测试期间继续显式移除`LUNEX_RUN_KEYCHAIN_TEST`且不改变simulator状态。
- 共享执行流首轮focused的6项中2项通过、4项在进入数值断言前因早期1x1输入把chroma尺寸算为0而崩溃；当前文件已修为half尺寸至少1，但失败xcresult不计验收。进一步把output target改为private storage并通过shared buffer blit回读，输入纹理在unified/discrete GPU分别使用shared/managed storage，并增加由真实geometry resolver生成的fit opaque-black letterbox readback。
- 最终版focused从全新DerivedData通过`7/7 passed / 0 skipped / 0 failed`（`/tmp/LuneX-15-3_4-focused-final.76O3LO/HDRMetalShaderReadback.xcresult`），覆盖SDR black/reference-white/Rec.709 primaries、PQ near-black/reference-white/peak、Rec.2020到P3 primary、HDR-to-SDR、finite/opaque、NaN sanitize、fill crop和fit letterbox；命令显式移除真实Keychain开关。

## 2026-07-22 阶段 15 任务 3.4 完成

- 新增`HDRMetalShaderReadbackTests.swift`并纳入generator-owned macOS test target；真实Metal pipeline把NV12/P010 code纹理渲染到private sRGB/half-float target，再经blit回读并与CPU reference math比较。P010保持left-aligned 10-bit，fit clear为opaque black，fill实际采样non-full crop。
- focused通过`7/7`（`/tmp/LuneX-15-3_4-focused-final.MtIc50/HDRMetalShaderReadback.xcresult`）；完整macOS通过`545 total / 544 passed / 1 explicit Keychain skip / 0 failed`（`/tmp/LuneX-15-3_4-final-1784649981999/LuneXCoreTests.xcresult`），唯一skip精确为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，xcresult build diagnostics为`0 warning / 0 error / 0 analyzer warning`。
- macOS及固定iPhone/iPad/tvOS/visionOS五平台Debug warnings-as-errors build-only在最终树上全部成功且分别执行`CompileMetalFile`与`MetalLink`（`/tmp/LuneX-15-3_4-final-1784649981999`）。simulator清单前后逐字一致，SHA-256均为`045d55961d523ff13abb1b67d8f084a479050cfdab82af71e1e3e451a96ce7c8`，固定四实例唯一、available、`Shutdown`且全局`Booted=0`。
- repository gates位于`/tmp/LuneX-15-3_4-repo.tbmx0q`：OpenSpec strict `6/6`、fixture self-test/全树、generator生成前和三次运行SHA-256均为`3a559222444abb28bd41a4411b0951105d687aa5f6e3cf145488ed3339ede097`，reference/dependency/whitespace边界通过。
- OpenSpec 3.4标记完成，权威进度`14/33`。本项证明offscreen GPU数值，不证明3.5 production presenter切换、4.x surface signaling或物理HDR；下一项3.5。
- 提交前自审将texture payload、readback coordinate和blit completion从“断言后继续”改为guard+typed throw，防止坏测试输入进入Metal API；全新DerivedData focused再次`7/7 passed / 0 skipped / 0 failed`（`/tmp/LuneX-15-3_4-focused-guarded.dJ4EPW/HDRMetalShaderReadback.xcresult`）。

## 2026-07-22 阶段 15 任务 3.5 启动

- 3.4已以`1ed7d2b Verify HDR Metal shader readback`独立提交并推送，确认`HEAD == origin/main`且工作树clean；OpenSpec权威进度`14/33`。
- 审计production调用链确认`StreamMetalPresenter`仍使用Core Image固定sRGB路径，实际SwiftUI macOS/iOS/tvOS/visionOS surface均通过该presenter；3.5将接入`CVMetalVideoFrameMapper + HDRMetalVideoRenderer`并保留clear/fit/fill/throttle/pause/stale行为。
- 第4组surface/display resolver尚未存在，故3.5固定匹配sRGB surface：SDR显式Metal，HDR显式HDR-to-SDR fallback；不以`DisplayHeadroom.supportsEDR`直接启用EDR intent，动态float drawable/colorspace和current-headroom mapping留给4.1至4.4。

## 2026-07-22 阶段 15 任务 3.5 暂停检查点

- production presenter未提交工作树已移除Core Image路径，接入`CVMetalVideoFrameMapper + HDRMetalVideoRenderer`，固定`.bgra8Unorm_srgb` surface，SDR使用`.sdr`、HDR使用headroom `1`的`.hdrToSDR`；macOS和mobile dismantle显式停止并失效runtime，layer intent暂时强制SDR。
- 新增`StreamMetalPresenterTests`并纳入generator-owned project；全新DerivedData focused warnings-as-errors通过`5/5`，含真实`DecodedVideoFrame -> mapper -> renderer -> offscreen sRGB target` GPU回读及invalidate后fail-closed，结果`/tmp/LuneX-15-3_5-focused.PrglEY/StreamMetalPresenter.xcresult`。测试命令显式移除`LUNEX_RUN_KEYCHAIN_TEST`，未访问真实Keychain。
- 用户要求暂停以更新macOS时，完整macOS suite和五平台Debug build-only正在并行执行；已立即向首组六个`xcodebuild`发送中断并以`130`退出。随后检测到中断前异步执行流延迟启动的另一组五平台build，也已按其`/tmp/LuneX-15-3_5-builds-*`路径定向发送INT/TERM并确认进程表无残留。因此所有中断运行均不计验收，OpenSpec `3.5`保持未完成、未勾选、未提交、未推送。
- 暂停时工作树包含`MetalStreamSurface.swift`、`StreamMetalPresenterTests.swift`、generator/project及`findings.md`/`progress.md`修改；`git diff --check`通过。恢复后先核对Xcode/SDK/runtime与simulator清单，再从完整macOS suite、五平台build-only和repository gates重新验收，不重复运行已通过的focused测试除非环境或源码变化。

## 2026-07-22 阶段 15 任务 3.5 完成

- 恢复后审计共享工作树并补强terminal invalidation、opaque-black clear、macOS/mobile dismantle、SDR-only layer intent与四项plan resolver测试；共享执行流追加真实production runtime offscreen GPU测试后保留并审计，未增加public或测试专用后门。
- 全新DerivedData focused通过`14/14 passed / 0 skipped / 0 failed`（`/tmp/LuneX-15-3_5-focused-final.jc3pIV/StreamMetalPresenter.xcresult`）；完整macOS通过`550 total / 549 passed / 1 explicit Keychain skip / 0 failed`（`/tmp/LuneX-15-3_5-full.Dis35D/LuneXCoreTests.xcresult`），唯一skip为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`且命令显式移除`LUNEX_RUN_KEYCHAIN_TEST`。
- macOS、固定iPhone/iPad/tvOS/visionOS五平台Debug warnings-as-errors build-only全部通过（`/tmp/LuneX-15-3_5-builds-1784650856524`）；simulator前后清单逐字一致，SHA-256均为`a4f4478ed56e83535f5a8e7fda2ebd80e047fb169c1271648a41a1fbd61b07af`，四实例唯一、available、`Shutdown`且全局`Booted=0`。
- 3.5标记完成，OpenSpec权威进度`15/33`。本项不证明3.6完整failure/resource矩阵、4.x EDR surface/display adaptation或6.5物理显示器结果；下一项3.6。
## 2026-07-29 阶段 15 任务 3.6 恢复

- 用户完成macOS更新并明确恢复推进；长期目标重新激活，仍保持阶段13至20完整范围、真实Keychain仅一次验证和每类simulator单实例约束。
- 恢复审计确认`HEAD == origin/main == fe94bcd`，仅`MetalStreamSurface.swift`与`StreamMetalPresenterTests.swift`保留3.6未提交修改，`git diff --check`通过，且没有残留`xcodebuild`、generator或Git写进程。
- 当前环境为macOS 27.0 build `26A5388g`、Xcode 26.4 build `17E192`、Swift 6.3、macOS/iOS SDK 26.4。原固定26.4 iPhone/iPad/Apple TV/Apple Vision Pro仍available且`Shutdown`；系统更新另行新增iOS 27/xrOS 27实例，且一个非固定iOS 26.4 `iPhone 17`已经`Booted`。本任务不创建、启动、关闭或删除任何simulator，并以当前只读清单作为新的前置基线。
- OpenSpec `implement-native-hdr-edr-pipeline`仍为spec-driven、`15/33`，当前唯一任务为3.6。恢复后显式消费protocol existential `runtime.present`返回值、删除无决策生产者的`presentationFailure`枚举项，并统一macOS/mobile暂停清屏为`requestsImmediateDraw`调度合同。
- 首轮恢复focused从全新DerivedData通过`12/12 passed / 0 skipped / 0 failed`（`/tmp/LuneX-15-3_6-focused-r3.4PjdSL/StreamMetalPresenter.xcresult`），warnings-as-errors编译并实际运行production offscreen GPU路径。Xcode在启动时输出设备build-number兼容性日志，且AppIntents工具输出“No AppIntents dependency”跳过提示；两者不是Swift/Metal源码诊断，后续仍需以xcresult结构化核对。
- focused通过后的自审发现暂停优先级和资源释放幂等性不足：暂停且无drawable会先等待而不停止runtime；runtime内部失败清理后presenter catch再次`stop()`会重复renderer stop/mapper flush。已让inactive policy优先于drawable gate，并用显式presentation-resource ownership使重复stop/invalidate不重复释放；下一次focused必须从新DerivedData验证补充断言。
- 最终focused在补充runtime factory失败所有权测试后，从第三套全新DerivedData通过`13/13 passed / 0 skipped / 0 failed`（`/tmp/LuneX-15-3_6-focused-final.nU9UnS/StreamMetalPresenter.xcresult`）；结构化build result为`0 warning / 0 error / 0 analyzer warning`。
- 完整macOS suite从全新DerivedData通过`558 total / 557 passed / 1 skipped / 0 failed`（`/tmp/LuneX-15-3_6-full.bdiiI8/LuneXCoreTests.xcresult`），唯一skip由日志精确确认为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，结构化build result仍为零warning/error/analyzer warning。
- Xcode 26.4在macOS 27 beta上执行`xcresulttool get test-results tests`时尝试移动内部`database.sqlite3`并报同名项已存在；未重复该失败路径，改用xcresult summary证明总数并用原始xcodebuild日志精确核对唯一skip。该工具兼容性问题不影响测试执行或result bundle结构化summary。

## 2026-07-29 阶段 15 任务 3.6 完成

- production presenter新增可注入runtime/renderer边界及结构化snapshot；configuration替换、frame cache、coordinate revision resize、pipeline/configuration failure、terminal invalidation、configure replacement/factory failure均可确定性观察。inactive policy优先于drawable gate，后台无drawable仍释放资源；显式ownership使failure后的presenter stop和重复stop/invalidate不重复renderer stop/mapper flush。
- 最终focused `13/13`与完整macOS `558 total / 557 passed / 1 explicit Keychain skip / 0 failed`通过，xcresult为零warning/error/analyzer warning。五平台Debug warnings-as-errors build-only全部通过且各自执行一次Metal compile/link，证据目录`/tmp/LuneX-15-3_6-builds.Mzx7WR`。
- simulator构建前后完整规范化清单逐字一致，SHA-256均为`0470edc00aea815358b4bed51fa43b73b79a5cbc61f80856f9630c6128568d41`；固定26.4 iPhone/iPad/Apple TV/Apple Vision Pro均available且`Shutdown`，最终全局`Booted=0`。未创建、启动、关闭或删除任何设备。
- repository gates位于`/tmp/LuneX-15-3_6-repo.JEHVIJ`：OpenSpec strict `6/6`、fixture self-test/全树、generator生成前及三次运行SHA-256均为`6cd73abecaca22c14d60d0b378b34ac57c44e5fce60e8eef5f10dac959da368d`，reference/dependency/CoreImage/whitespace边界通过。
- OpenSpec 3.6标记完成，权威进度`16/33`；阶段15保持`in_progress`。本项不证明4.x EDR surface/display adaptation、HDR signaling或6.5物理亮度/颜色，下一项4.1。

## 2026-07-29 阶段 15 任务 4.1 启动

- 恢复并核对活动目标；`main`工作树clean，`HEAD == origin/main == 867ff8f`，无残留构建或Git写进程。
- 读取planning-with-files、OpenSpec apply skill、change全部proposal/design/spec/tasks；OpenSpec权威进度为`16/33`，开始4.1。
- 4.1范围锁定为可注入platform surface adapter、typed supported/unsupported/application failure结果、完整surface snapshot与原子回滚；production只允许通过adapter重申当前SDR contract，不在4.3 resolver之前主动开启EDR。
- 所有后续测试继续显式移除`LUNEX_RUN_KEYCHAIN_TEST`，不执行真实Keychain round-trip；不创建、启动、关闭或删除simulator。
- 读取Xcode 26.4 QuartzCore/CoreGraphics headers并执行四SDK Swift warnings-as-errors探针：macOS、iOS、visionOS可用EDR intent/metadata，tvOS得到三项明确unavailable诊断；extended-linear Display P3与ITU-R 2020 colorspace名称四SDK均存在。
- 首个探针因zsh不拆分`SDK target`整行而在编译前失败，已改为`while read -r sdk target`成功复验并记录到`task_plan.md`。
- 新增`HDRSurfaceTransactionAdapter`、平台capability、typed application outcome/error及Apple `MTKView/CAMetalLayer` backend；进入EDR按format/colorspace/metadata/intent顺序提交，返回SDR先关闭intent并清metadata，mutation failure恢复完整native snapshot，rollback failure清除reported ownership。
- production presenter已删除四处布尔式`DisplayHeadroomReader.configure`调用，首次配置通过adapter原子应用当前既有SDR contract；surface unsupported/failure会失效runtime、移除delegate并暂停view，不会继续创建presentation runtime。4.3 resolver完成前仍不主动请求EDR。
- 首轮focused从全新DerivedData通过`22/22 passed / 0 skipped / 0 failed`，其中adapter `8/8`、presenter `14/14`；真实macOS layer覆盖SDR→float EDR→SDR的view/layer pixel format、colorspace、intent与metadata。xcresult build result为`0 warning / 0 error / 0 analyzer warning`，证据`/tmp/LuneX-15-4_1-focused.5VFZSs/HDRSurfaceAdapter.xcresult`。

## 2026-07-29 阶段 15 任务 4.1 完成

- 完整macOS suite从全新DerivedData通过`567 total / 566 passed / 1 skipped / 0 failed`（`/tmp/LuneX-15-4_1-full.0poC2y/LuneXCoreTests.xcresult`）；唯一skip为显式禁用的`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，结构化结果为零warning/error/analyzer warning。
- macOS及固定iPhone/iPad/tvOS/visionOS五平台Debug warnings-as-errors build-only全部通过并各自实际执行一次Metal compile/link，证据目录`/tmp/LuneX-15-4_1-builds.VX5kfG`。构建前后规范化simulator清单逐字一致，SHA-256均为`0470edc00aea815358b4bed51fa43b73b79a5cbc61f80856f9630c6128568d41`；固定四实例均available/`Shutdown`且全局`Booted=0`，未执行simulator生命周期命令。
- repository gates位于`/tmp/LuneX-15-4_1-repo.DWlFHH`：OpenSpec strict `6/6`、fixture validator self-test/全树、generator运行前及连续三次SHA-256均为`ed35a1f7a1233c38e2d4e3f25784fe24199727392a5d0018811e7d68e8073b4e`，production/reference、dependency、CoreImage regression、diff/自有文件whitespace边界全部通过。
- 自审确认typed unsupported不修改native state，成功rollback保留先前active ownership，rollback failure清除ownership，tvOS不引用unavailable API且visionOS最终build通过。OpenSpec 4.1标记完成，权威进度`17/33`；阶段15保持`in_progress`，下一项4.2。

## 2026-07-29 阶段 15 任务 4.2 启动

- 4.1已以`18ca5ba Add atomic HDR surface adapter`独立提交并推送，确认`HEAD == origin/main`且工作树clean；OpenSpec权威进度`17/33`。
- 4.2范围限定为platform lifecycle中的独立display snapshot/revision publisher：attached/detached可用性、display identity或headroom语义变化才增长；attachment owner在相同display/headroom下的replacement本身不增长，stream active、focus、visibility和单纯drawable resize也不增长。不提前实现4.3 eligibility/configuration resolver或5.1 AppModel render-configuration接线。
- 初始实现让revision使用checked `UInt64`增长并在耗尽时清除snapshot、fail closed；重复NaN headroom按相同无效语义去重。iOS reader改为读取真实`potentialEDRHeadroom`，macOS monitor用内部`NSScreenNumber`区分可能同名显示器且不再把identity写入public日志。
- 首轮focused编译成功并通过18项，但既有AppKit通知测试仍期待旧`localizedName`而1项失败；xcresult为`18 passed / 1 failed`，不计验收。断言已改为内部screen number并增加重复通知/resize不增长display revision的验证。包装器末尾另误用zsh只读变量`status`，后续改用`build_status`且使用全新DerivedData。
- 第二轮focused从全新DerivedData通过`19/19 passed / 0 skipped / 0 failed`（`/tmp/LuneX-15-4_2-focused-r2.taLuUO/DisplayLifecycle.xcresult`）；覆盖semantic display/headroom revision、detach/stale owner、NaN去重、counter exhaustion、既有AppModel headroom传播及AppKit screen/backing/resize通知。测试命令显式移除真实Keychain开关。
- 首轮完整suite为`571 total / 569 passed / 1 Keychain skip / 1 failed`，唯一失败是另一项既有surface geometry测试仍期待旧`localizedName`；不计验收。已抽取测试侧screen-number helper统一两处identity断言，下一轮从全新DerivedData重跑。
- 第二轮完整macOS suite从全新DerivedData通过`571 total / 570 passed / 1 skipped / 0 failed`（`/tmp/LuneX-15-4_2-full-r2.YcZB9m/LuneXCoreTests.xcresult`）；唯一skip精确为真实Keychain round-trip，结构化build result为`0 warning / 0 error / 0 analyzer warning`。
- 首轮五平台包装器在macOS build成功且Metal compile/link各1次后，零源码诊断的`rg -c`返回空输出，导致整数断言失败；不计验收。未进入任何simulator build或生命周期操作，后续计数显式默认0并从新目录完整重跑。
- 五平台Debug warnings-as-errors build-only从新证据目录全部通过且每个平台Metal compile/link各1次、源码诊断0（`/tmp/LuneX-15-4_2-builds-r2.7MtKMF`）。前后规范化simulator清单逐字一致，SHA-256均为`ae1d4726c924c8a482aeb73847ca98acf2c093b8e56605773681d0f96fabc58b`；固定四实例唯一、available、`Shutdown`且全局`Booted=0`，未执行simulator生命周期命令。

## 2026-07-29 阶段 15 任务 4.2 完成

- repository gates位于`/tmp/LuneX-15-4_2-repo.19jLRj`：OpenSpec strict `6/6`、fixture validator self-test/全树、generator运行前及连续三次SHA-256均为`ed35a1f7a1233c38e2d4e3f25784fe24199727392a5d0018811e7d68e8073b4e`，production/reference、dependency、CoreImage regression、diff/自有文件whitespace边界全部通过。
- 自审确认display revision与stream/focus/visibility/geometry revision独立，same-display headroom变化会发布新snapshot，stale detach不影响replacement，counter exhaustion清除snapshot，内部screen identity不进入public日志。OpenSpec 4.2标记完成，权威进度`18/33`；阶段15保持`in_progress`，下一项4.3。
- 恢复后的最终生成器/strict/apply/diff门再次通过，并将文档触发条件收紧为attached/detached可用性、display identity和headroom；相同display/headroom下的attachment owner replacement本身不是revision输入。4.2已提交为`d37aed8 Add revisioned display headroom state`。
- 首次组合命令未返回push诊断，随后直连SSH 22、SSH 443和HTTPS 443均超时而DNS正常；发现本机Surge系统代理后，以SOCKS5恢复GitHub连接。fetch确认首次push实际已发布`d37aed8`，因此不强推本地amend，而把3行诊断记录重放为远端4.2提交之后的独立跟踪提交。

## 2026-07-29 阶段 15 任务 4.3 启动

- `d37aed8 Add revisioned display headroom state`与跟踪提交`c191e52 Record HDR task push recovery`均已推送，确认`HEAD == origin/main`且工作树clean；OpenSpec权威进度`18/33`。
- 已重新读取change proposal/design/spec/tasks及现有render contract、decoded validator、luminance mapping、surface adapter、presenter与display publisher。4.3实现纯resolver和确定性测试，不提前修改production presenter/AppModel，不执行4.4 transition orchestration。
- 输入锁定为actual decoded layout/metadata、decoder generation、user preference、injected platform capabilities、revision-owned display snapshot/exhaustion及drawable/applied surface state；输出区分SDR、EDR、typed SDR fallback、closed error和surface application requirement，且不携带display identity。
- 首轮focused误用不含test action的`LuneX-macOS` scheme，Xcode在编译前以“not currently configured for the test action”退出；该结果不计验收。项目已有`LuneXCoreTests` scheme，后续使用新DerivedData/result bundle重跑。
- 第二轮focused进入编译后因`HDRRenderConfigurationResolverInput`无用途地声明`Hashable`失败；display snapshot只保证带NaN去重语义的`Equatable`，不应强制hash。已移除input hash约束，resolved configuration/output仍保持`Hashable`，失败bundle不计验收。
- 第三轮focused实际运行`23`项，`22 passed / 1 failed`；失败fixture同时把8-bit伪HDR metadata配到P010，validator正确优先报告bit-depth/layout mismatch。fixture改为NV12以隔离metadata缺陷，失败bundle不计验收。
- 第四轮仍为`22 passed / 1 failed`：即使改用NV12，8-bit HDR按既有合同仍应先返回layout mismatch。fixture改为合法HDR10/P010字段加全零content-light metadata，使结构检查通过后唯一触发invalid metadata；此前bundle继续不计验收。
- 最终focused从全新DerivedData通过`23/23 passed / 0 skipped / 0 failed`（`/tmp/LuneX-15-4_3-focused-final.NgLzao/HDRRenderConfigurationResolver.xcresult`），结构化结果为零warning/error/analyzer warning；覆盖SDR-on-EDR、HDR EDR、P3/2020选择、typed fallback、无fallback closed、metadata/layout、generation/display/drawable和display identity隐私边界。

## 2026-07-29 阶段 15 任务 4.3 完成

- 完整macOS suite从全新DerivedData通过`582 total / 581 passed / 1 skipped / 0 failed`（`/tmp/LuneX-15-4_3-full.TvTnJC/LuneXCoreTests.xcresult`）；唯一skip为显式禁用的`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，结构化结果为零warning/error/analyzer warning。
- macOS及固定iPhone/iPad/tvOS/visionOS五平台Debug warnings-as-errors build-only全部通过并各自实际执行一次Metal compile/link，证据目录`/tmp/LuneX-15-4_3-builds.Fu1BUO`。构建前后规范化simulator清单逐字一致，SHA-256均为`acf879865a6beef7e7491896dc562a30cf3ee75aa248fbaebcc3a0376e3f9c3c`；固定四实例均唯一、available、`Shutdown`且全局`Booted=0`，未执行simulator生命周期命令。
- `HDRRenderConfigurationResolver`从实际decoded layout/metadata、decoder generation、HDR preference、platform capability、revision-owned display snapshot/current headroom、drawable与adapter-owned surface解析唯一immutable SDR、EDR、typed HDR-to-SDR fallback或closed结果，并只公开display revision。
- OpenSpec 4.3标记完成，权威进度`19/33`；阶段15保持`in_progress`，下一项4.4负责清除不兼容presentation并原子应用surface/pipeline transition。production presenter/AppModel尚未接线resolver，当前证据不证明production EDR、HDR signaling、live Sunshine HDR或物理亮度/颜色。
- 首轮repository组合门的reference-path正则在zsh嵌套引号层被截断并以`unmatched "`退出；失败发生在临时目录创建后、generator/OpenSpec/fixture执行前，不计验收。后续拆分边界扫描并使用新证据目录完整重跑。
- 第二轮repository门的generator运行前/三次SHA-256均为预期`1275a7954c8c23a5e3113a036addb0548efefc81c8a7f141257e7156ac3d08d0`，OpenSpec原始结果也为6项全部valid；但包装器误按旧schema读取`summary`而主动失败。该轮部分结果不计最终验收，后续按`summary.totals`与`.items[].valid`从新目录完整重跑。
- 最终repository gates位于`/tmp/LuneX-15-4_3-repo-final.9MawyM`：OpenSpec strict `6/6`、apply `19/33`且4.3已完成、fixture validator self-test/全树、generator运行前及连续三次SHA-256均为`1275a7954c8c23a5e3113a036addb0548efefc81c8a7f141257e7156ac3d08d0`，production/reference、无Swift Package依赖、Core Image regression、diff与自有文件whitespace边界全部通过。

## 2026-07-29 阶段 15 任务 4.4 启动

- 4.3已以`e0a4cee Resolve HDR render configurations`独立提交并经Surge SOCKS5推送；代理远端核对确认`HEAD == origin/main == e0a4cee`且工作树clean。
- 首次远端核对漏加代理，`git fetch origin main`无输出挂起后主动中止；未修改工作树。改用既有SOCKS5命令后成功，后续GitHub操作固定带代理。
- 重新读取change design/spec、surface adapter、resolver、Metal presenter/runtime/renderer、display publisher与focused tests。4.4只建立resolved configuration到surface/runtime的transition ownership，不提前实现5.1 AppModel/lifecycle/preference调用链或5.3 diagnostics。
- 首轮focused在测试启动前编译失败：`configure(_:)`中的SDR `surface`局部声明在`do`块内，却在后续锁内记录ownership，报`Cannot find 'surface' in scope`。失败证据`/tmp/LuneX-15-4_4-focused.x4nEnC/StreamMetalTransitions.xcresult`不计验收；已提升局部声明，后续使用全新路径重跑。
- macOS更新后恢复确认活动目标仍覆盖阶段13至20；系统为macOS 27 beta build `26A5388g`，Xcode仍为26.4 build `17E192`、Swift 6.3。`HEAD == origin/main == e0a4cee`，4.4的两项源码/测试修改及三份持久化计划修改仍完整保留，未发现残留构建或Git写操作。
- 第二轮focused从全新DerivedData通过`19/19 passed / 0 skipped / 0 failed`，结构化结果为零warning/error/analyzer warning（`/tmp/LuneX-15-4_4-focused-r2.EkWQ89/StreamMetalTransitions.xcresult`）。该结果证明当前resolved transition基础合同可编译运行，但尚未覆盖closed后恢复、EDR stop恢复SDR及幂等、replacement旧view隔离、surface failure ownership与迟到clear revision隔离，因此4.4仍为进行中。
- 第三轮focused加入closed恢复、EDR stop幂等、replacement旧view隔离、typed unsupported与surface mutation failure后运行`24`项，`23 passed / 1 failed`（`/tmp/LuneX-15-4_4-focused-r3.lerTso/StreamMetalTransitions.xcresult`），不计验收。唯一失败是恢复用例以默认`.idle` render policy却断言view恢复为非paused；实现按当前策略保持paused是正确行为，测试改为显式`.active`后从全新证据路径重跑。
- 第四轮focused从全新DerivedData通过`24/24 passed / 0 skipped / 0 failed`（`/tmp/LuneX-15-4_4-focused-r4.k7LJb3/StreamMetalTransitions.xcresult`），结构化build result为`0 warning / 0 error / 0 analyzer warning`。新增矩阵证明closed后能按当前active策略重建runtime/surface，EDR stop幂等恢复SDR，旧view迟到transition不修改replacement，typed unsupported与已回滚mutation failure均撤销presenter的surface/runtime ownership。
- 完整macOS suite从全新DerivedData通过`592 total / 591 passed / 1 skipped / 0 failed`（`/tmp/LuneX-15-4_4-full.bjZpFY/LuneXCoreTests.xcresult`）；唯一skip精确为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，结构化build result为`0 warning / 0 error / 0 analyzer warning`。
- 首轮五平台包装器被默认zsh在首个build前以`${!names[@]}: bad substitution`拒绝；只完成了前置只读simulator清单，未执行xcodebuild或任何设备生命周期操作，不计验收。后续显式使用Bash、全新证据目录和新的前置清单完整重跑。
- 第二轮五平台Debug warnings-as-errors build-only从全新DerivedData全部通过，macOS、固定iPhone/iPad/tvOS/visionOS各自实际执行一次Metal compile/link且结构化diagnostics均为零（`/tmp/LuneX-15-4_4-builds-r2.PHAPtV`）。构建前后规范化simulator清单逐字一致，SHA-256均为`0470edc00aea815358b4bed51fa43b73b79a5cbc61f80856f9630c6128568d41`；固定四实例唯一、available、`Shutdown`且全局`Booted=0`，未执行任何simulator生命周期命令。
- 首轮repository组合门的fixture、OpenSpec strict/apply、generator三次稳定、reference/dependency/Core Image/diff边界均已通过，但自写“所有tracked文本”whitespace口径误纳入固定vendor ENet并命中其172处上游尾随空格，因此整轮不计最终验收。核对确认命中全部位于`ThirdParty/ENet`，LuneX自有文件与当前diff均clean；后续恢复既有“排除vendor、自有文件+diff”边界并从全新目录完整重跑。
- 最终repository gates位于`/tmp/LuneX-15-4_4-repo-r2.U0Xavj`：OpenSpec strict `6/6`、apply在勾选前正确为`19/33`、fixture validator self-test/全树、generator运行前及连续三次SHA-256均为`1275a7954c8c23a5e3113a036addb0548efefc81c8a7f141257e7156ac3d08d0`，production/reference、无Swift Package依赖、Core Image regression、diff与排除vendor的自有文件whitespace边界全部通过。

## 2026-07-29 阶段 15 任务 4.4 完成

- `StreamMetalPresenter`新增resolved configuration transition ownership：configuration变化清旧presentation、失效runtime、应用surface、创建replacement runtime后才发布新ownership；首个新surface drawable先opaque clear，coordinate/backing变化只清pipeline/frame cache，stop/closed/replacement恢复SDR并隔离stale view。
- 同一presentation合同从resolver的`.requiresApplication`变为`.ready`时只刷新最新resolved observer/诊断语义，不重建surface/runtime；最终focused `25/25`、完整macOS `593 total / 592 passed / 1 Keychain skip / 0 failed`、五平台Debug Metal build、simulator不变与repository gates通过。OpenSpec 4.4标记完成，权威进度更新为`20/33`，阶段15保持`in_progress`，提交推送后进入4.5 macOS screen/headroom/stale-window/surface/teardown与first-clear transition矩阵。
- production SwiftUI/AppModel尚未调用resolver/transition，5.1仍负责AppModel/lifecycle/preference/actual surface接线；本次离线证据不证明production EDR signaling、live Sunshine HDR、物理亮度/颜色或跨显示器视觉结果。

## 2026-07-29 阶段 15 任务 4.4 提交前复验

- macOS更新后恢复持久化计划、活动目标与OpenSpec；`HEAD == origin/main == e0a4cee`，4.4未提交diff完整，Xcode 26.4、Swift 6.3及26.4 simulator runtimes可用。只读清单显示所有设备为`Shutdown`，未创建、启动、关闭或删除simulator。
- 提交前自审确认合成`HDRResolvedRenderConfiguration`相等性错误包含observer-only `surfaceState`：同一presentation合同首次从`.requiresApplication`应用成功后，下一次resolver返回`.ready`会误触发surface/runtime重建。
- 已把unchanged语义限定为identity、完整validated frame contract、luminance mapping、实际surface ownership及非空runtime；命中时只刷新最新resolved诊断值，不失效runtime或重跑adapter。新增真实resolver两次解析回归，锁定adapter contract、runtime factory/invalidation及transition count均不增加。
- 4.4完成标记暂保留但视为提交前复验中；只有新的focused、完整macOS、五平台build、simulator不变和repository gates全部通过后，旧验收才会被替换并提交。
- 第一轮恢复后focused额外开启静态分析，25项测试全部通过，但固定第三方`ThirdParty/ENet`产生4条既有analyzer issue，且未关闭的AppIntents extractor产生1条metadata skip提示；该bundle不作为零诊断验收证据。没有修改vendor，后续恢复项目既定分层口径。
- 最终focused从全新DerivedData通过`25/25 passed / 0 skipped / 0 failed`（`/tmp/LuneX-15-4_4-focused-r6.c32hIZ/StreamMetalTransitions.xcresult`）；结构化warning/error/analyzer warning均为0，日志诊断为0，Metal compile/link各1次。命令显式移除真实Keychain开关并以`LM_SKIP_METADATA_EXTRACTION=YES`关闭项目未使用的AppIntents规则。
- 完整macOS suite从全新DerivedData通过`593 total / 592 passed / 1 skipped / 0 failed`（`/tmp/LuneX-15-4_4-full-r2.wpnfVE/LuneXCoreTests.xcresult`）；唯一skip从原始日志精确确认是`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，结构化warning/error/analyzer warning均为0，日志诊断为0，Metal compile/link各1次。
- Xcode 26.4在macOS 27 beta上再次于读取xcresult tests明细时报告内部`database.sqlite3` move冲突；不重跑已成功suite，使用可读的summary/build-results及原始日志证明总数、唯一skip和零诊断，与既有工具缺陷边界一致。
- macOS及固定iPhone/iPad/tvOS/visionOS五平台Debug warnings-as-errors build-only从全新DerivedData全部通过（`/tmp/LuneX-15-4_4-builds-r3.Kir4YH`）；每个平台结构化warning/error/analyzer warning均为0，并实际执行Metal compile/link各1次。
- 构建前后完整规范化simulator清单逐字一致，SHA-256均为`0470edc00aea815358b4bed51fa43b73b79a5cbc61f80856f9630c6128568d41`；四个固定UUID各唯一、available、`Shutdown`，全局`Booted=0`。只执行build与只读list/compare，没有create、boot、launch、shutdown或delete设备。
- 第一轮恢复后repository包装器把真实`Sources/LuneXApp`误写为不存在的顶层`LuneXApp`；虽然其余fixture/OpenSpec/generator/package/Core Image/whitespace门通过且扫描结果为空，该轮production boundary证据不完整，不计最终验收。改用正确路径后从新证据目录完整重跑。
- 最终repository gates从全新目录`/tmp/LuneX-15-4_4-repo-r4.4sQhqd`通过：fixture validator self-test/全树、OpenSpec strict `6/6`与apply `20/33`、generator运行前及连续三次SHA-256 `1275a7954c8c23a5e3113a036addb0548efefc81c8a7f141257e7156ac3d08d0`、production/reference/package/Core Image/diff及排除vendor的自有whitespace边界全部成立。
- 最终diff自审未发现新的ownership、失败恢复、stale view或迟到clear缺口；4.4全部门禁通过，可以独立提交并推送。

## 2026-07-29 阶段 15 任务 4.5 启动

- 4.4已以`790d4e2 Rebuild HDR presentation transitions`独立提交并经Surge SOCKS5推送；fetch确认`HEAD == origin/main == 790d4e2`且工作树clean。
- OpenSpec `implement-native-hdr-edr-pipeline`为`spec-driven`且权威进度`20/33`；4.5范围为macOS screen/headroom、same-display headroom、stale-window、surface transition、SDR-on-EDR、HDR-on-SDR、HDR-on-EDR、first opaque clear与teardown确定性组合测试，不提前执行4.6跨平台adapter或5.1 production graph。
- 单层合同已有分散覆盖，但缺少lifecycle display snapshot -> resolver -> presenter的同一revision-owned组合矩阵，以及transition后实际首个draw只clear、第二个draw才present的直接证明。后续优先新增独立macOS integration test file并运行focused warnings-as-errors gate。
- 首轮focused编译成功，stale-window、display/headroom transition和SDR/HDR模式3项通过，first-clear 1项失败（`/tmp/LuneX-15-4_5-focused-r1.UlB2Wm/MacHDRTransitions.xcresult`），不计验收。headless `MTKView.draw()`不同步回调delegate，因此transition后正确保留pending clear；测试改为显式驱动第一draw并断言只clear，再驱动第二draw断言才present。
- 修正后focused `4/4`、扩展lifecycle/resolver/surface/presenter矩阵`96/96`、完整macOS `597 total / 596 passed / 1 Keychain skip / 0 failed`及五平台Debug build均通过，但提交前diff自审发现stale lease仅保护surface publication，旧window的occlusion/key通知仍可覆盖replacement visibility/focus，因此这些结果视为中间证据。
- AppKit monitor现将在visibility、focus与surface回调入口统一验证current attachment lease；stale-window回归扩展为同时发送resize、occlusion与resign-key通知并锁定replacement geometry/display/visibility/focus。修复后从新证据路径重跑验收。

## 2026-07-29 阶段 15 任务 4.5 完成

- 最后一次lease修复后的focused从`/tmp/LuneX-15-4_5-focused-r3.3PP363/MacHDRTransitions.xcresult`通过`4/4 passed / 0 skipped / 0 failed`。最终扩展矩阵从全新DerivedData通过`96/96`，结果为`/tmp/LuneX-15-4_5-expanded-final.32w6lE/MacHDRExpanded.xcresult`，结构化warning/error/analyzer warning均为0。
- 完整macOS suite从全新DerivedData通过`597 total / 596 passed / 1 skipped / 0 failed`，结果为`/tmp/LuneX-15-4_5-full-final.sDxaJJ/LuneXCoreTests.xcresult`，结构化诊断为0。Xcode 26.4在macOS 27读取test明细时再次触发内部`database.sqlite3` move冲突；直接查询bundle数据库确认唯一skip为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`及其显式Keychain opt-in原因，本轮始终使用`env -u LUNEX_RUN_KEYCHAIN_TEST`。
- 五平台矩阵首个命令误用不存在的`LuneX` scheme并在任何编译前退出，不计验收且未触及simulator。最终从新目录`/tmp/LuneX-15-4_5-builds-final-r2.9oTdzH`依次完成macOS、固定iPhone/iPad/tvOS/visionOS Debug warnings-as-errors build-only；五个xcresult均为`0 warning / 0 error / 0 analyzer warning`，每个平台各生成`HDRVideoShaders.air`和`default.metallib`。
- 构建前后规范化simulator清单逐字一致，SHA-256均为`0470edc00aea815358b4bed51fa43b73b79a5cbc61f80856f9630c6128568d41`；四个固定UUID均available且`Shutdown`，全局`Booted=0`。只执行build与只读清单，没有create、clone、boot、launch、shutdown或delete设备。
- repository预扫有一条嵌套引号正则被zsh在执行前拒绝，随后使用精确路径token；最终门禁位于`/tmp/LuneX-15-4_5-repo-final.bIPQJN`。fixture validator self-test/全树、OpenSpec strict `6/6`、generator初始与连续三次SHA-256 `3240822c692a403dfd732a4ae0c283408381c2d8180abc9d7c69e2f3c589cfcf`、production/reference、Swift Package、Core Image、diff与排除vendor的自有whitespace边界全部通过。
- OpenSpec 4.5标记完成，权威进度更新为`21/33`；阶段15保持`in_progress`。下一项4.6为iOS/iPadOS、tvOS与visionOS compile-safe capability adapters；5.1 production graph、EDR signaling、live Sunshine HDR和6.5物理显示器证据仍未完成。

## 2026-07-29 阶段 15 任务 4.6 启动

- 4.5已以`5048a89 Verify macOS HDR display transitions`独立提交并经Surge SOCKS5推送；fetch确认`HEAD == origin/main == 5048a89`且工作树clean。OpenSpec权威进度`21/33`，下一项精确为4.6。
- Context7查询Apple Developer Documentation时连接失败；改用Apple官方developer文档检索与本机Xcode 26.4 SDK header交叉验证。未加引号的QuartzCore swiftinterface glob被zsh在读取前拒绝，随后改为逐平台SDK header路径。
- 4.6范围限定为平台capability结果和surface能力的单一来源、typed unsupported/fallback与确定性测试；不提前接入5.1 `AppModel`/media/render graph，不把平台API availability当作设备EDR或物理HDR证明。
- 新增`HDRPlatformOutputCapabilityAdapter`与typed capability resolution：macOS/iOS为候选supported，tvOS因extended-range surface API不可用返回SDR fallback，visionOS因缺少current headroom来源返回SDR fallback。`HDRSurfaceAdapterCapabilities.current`改为从同一平台结果派生，消除resolver/surface两套硬编码；tvOS的compile-safe `DisplayHeadroomReader`读取`UIScreen` current/potential EDR headroom，但仍因surface边界禁止宣称HDR输出。
- 4.6 focused warnings-as-errors测试位于`/tmp/LuneX-15-4_6-focused.qhzI9m`，`HDRRenderContractTests`、`HDRSurfaceAdapterTests`、`HDRRenderConfigurationResolverTests`共`33/33 passed / 0 skipped / 0 failed`；覆盖四平台精确矩阵、surface派生一致性、tvOS unsupported-output SDR fallback及visionOS current-headroom-unavailable fallback。
- 五平台compile-safe Debug build位于`/tmp/LuneX-15-4_6-builds.UzHQPD`：macOS、固定iPhone、固定iPad、tvOS、visionOS全部warnings-as-errors成功并生成Metal产物；每个build log仅有Xcode `appintentsmetadataprocessor`在未链接AppIntents时跳过提取的工具提示，没有Swift/Clang/Metal源码诊断。
- 构建前后规范化available simulator清单逐字一致，SHA-256均为`2bb77586c245e0839dcb73d06a66e5ec85ce0d2424d504654f3e1c307e5d6534`；四个固定UUID始终`Shutdown`，全局`Booted=0`。未执行create、clone、boot、launch、shutdown或delete。

## 2026-07-29 阶段 15 任务 4.6 完成

- 完整macOS warnings-as-errors suite位于`/tmp/LuneX-15-4_6-full.6POMvJ`，xcresult为`599 total / 598 passed / 1 skipped / 0 failed`。唯一skip精确为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`及其`LUNEX_RUN_KEYCHAIN_TEST=1` opt-in说明；所有测试均显式`env -u LUNEX_RUN_KEYCHAIN_TEST`，没有再次访问真实Keychain。
- repository gates位于`/tmp/LuneX-15-4_6-repo.9opc3n`：fixture validator self-test/全树、OpenSpec strict `6/6`、generator运行前与连续三次SHA-256均为`3240822c692a403dfd732a4ae0c283408381c2d8180abc9d7c69e2f3c589cfcf`，production/reference、Swift Package、Core Image、diff与排除vendor的自有whitespace边界全部通过。
- OpenSpec 4.6标记完成，权威进度更新为`22/33`；阶段15保持`in_progress`。下一项5.1为production `AppModel`、media environment、presentation source、actual stream surface与active renderer revision接线；EDR compositor signaling、live Sunshine HDR与6.5物理显示器证据仍未完成。

## 2026-07-29 阶段 15 任务 5.1 恢复

- 恢复活动目标、planning-with-files与OpenSpec上下文，确认5.1仍为进行中且工作树与续接记录一致。
- 修正后的五套扩大测试全部通过，包含旧coordinate revision用例及实际macOS `MTKView/CAMetalLayer` transition；正常测试显式移除`LUNEX_RUN_KEYCHAIN_TEST`。
- production event-order审计识别并修复frame-before-start交付：更高decoder generation的自包含decoded contract可建立ownership，旧revision decoder-start及旧media generation clear保持拒绝。
- 新增乱序/旧media generation断言后，focused AppModel HDR graph从全新DerivedData通过；5.1尚未勾选，待完整审计与全套验收。
- 首次追加记录的补丁因`findings.md`与`progress.md`尾部结构不同而在写入前被拒绝；随后以实际尾部上下文重新应用，未丢失或覆盖已有记录。
- presentation revision exhaustion首轮四项focused为`3 passed / 1 failed`，失败精确为exhausted source拒绝后续event却保留调用方刚写入的decoder generation；该轮不计验收。已统一首次溢出与后续发布尝试的ownership清理路径，待从相同矩阵复验。

## 2026-07-29 阶段 15 任务 5.1 完成

- revision exhaustion与ownership四项从全新证据路径`4/4`通过；最终扩大矩阵`132/132`、完整macOS `604 total / 603 passed / 1 explicit Keychain skip / 0 failed`，唯一skip精确为显式opt-in真实Keychain测试，所有正常测试均使用`env -u LUNEX_RUN_KEYCHAIN_TEST`。
- `StreamVideoPresentationSource`、native video processor、media environment、AppModel、lifecycle render state和actual Metal presenter现组成session/media/decoder/revision-owned production graph；真实decoded layout/metadata与真实display snapshot/current headroom进入resolver，相同resolution不重复重建surface/runtime。
- macOS及固定iPhone/iPad/tvOS/visionOS Debug warnings-as-errors build-only均成功、零结构化诊断并生成Metal AIR/metallib。simulator规范化清单前后SHA-256同为`60efff618098f956b1cc1cb74e83f4b122b6e52e186130ece4eb02ebcab2f49d`，固定四实例保持唯一、available、`Shutdown`且全局`Booted=0`，未执行任何simulator生命周期命令。
- repository strict/fixture/generator/reference/package/Core Image/diff/owned-whitespace门全部通过，最终证据目录`/tmp/LuneX-15-5_1-repo-final.6NWoUy`。OpenSpec 5.1标记完成，权威进度更新为`23/33`；阶段15保持`in_progress`。
- 下一项5.2负责从active session、preference、valid source contract、platform/display capability和current headroom完整派生eligibility，并移除legacy synthetic settings fallback。5.3 diagnostics、live Sunshine HDR、compositor signaling和6.5物理显示器证据保持未完成。

## 2026-07-29 阶段 15 任务 5.2 启动

- 5.1已以`a49e9e9 Connect native HDR presentation graph`独立提交并经Surge SOCKS5推送；fetch确认`HEAD == origin/main == a49e9e9`且工作树clean。OpenSpec权威进度`23/33`，下一项精确为5.2。
- 5.2范围限定为删除settings-derived synthetic headroom，并在production eligibility入口要求streaming session、current media/video readiness、active decoder generation及negotiated/decoded metadata一致；不提前实现5.3 diagnostics、5.4 broader integration gate或5.5 UI。
- 系统更新后恢复确认goal仍active、Xcode 26.4/Swift 6.3可用、全局`Booted=0`，工作树仅含暂停前5.2修改。focused `3/3`证据保持有效；新扩大矩阵`134/134 passed / 0 skipped / 0 failed`，xcresult结构化diagnostics为0，所有测试显式移除真实Keychain开关。
- 提交前审计发现reconnect snapshot晚于media teardown的fail-closed时序缺口。production现先应用权威reconnecting snapshot、关闭HDR/input/render policy，再执行generation-owned media teardown；测试增加挂起stop期间resolution已关闭，以及video readiness丢失立即关闭的断言。待从全新DerivedData重跑focused/扩大矩阵后再进入完整门禁。
- 首轮新transition focused为`2 total / 1 passed / 1 failed`：video readiness丢失回归通过，reconnect回归在通用wait helper超时。该xcresult不计验收；先让helper转发真实调用点，再以新证据目录定位具体等待，避免盲目重复。
- 诊断轮把失败精确定位到HDR激活等待：测试跨control/media两个独立stream并发发送HDR metadata与decoded events，metadata若后到会按正确ownership语义清除先到frame。测试改为先等待negotiated metadata生效再发送decoder/frame；production reconnect顺序修复保持不变。该轮另有已断开remote-device notification service的Xcode工具提示，不连接或管理该设备，也不计作源码验收。
- 修正后的transition focused从`/tmp/LuneX-15-5_2-transition-focused-r2.Cal540/Focused.xcresult`通过`2/2 passed / 0 skipped / 0 failed`，xcresult结构化warning/error/analyzer warning均为0。下一步从全新DerivedData重跑五组扩大矩阵。
- 最终五组扩大矩阵从`/tmp/LuneX-15-5_2-expanded-final.XXyEAk/Expanded.xcresult`通过`134/134 passed / 0 skipped / 0 failed`，xcresult结构化warning/error/analyzer warning均为0。下一步运行完整macOS suite，继续显式禁用真实Keychain路径。
- 完整macOS suite从`/tmp/LuneX-15-5_2-full-final.feeAfW/LuneXCoreTests.xcresult`通过`606 total / 605 passed / 1 skipped / 0 failed`；唯一skip精确为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，结构化diagnostics为0。下一步只读核对固定simulator后运行五平台build-only。
- 五平台build-only位于`/tmp/LuneX-15-5_2-builds-final.5HWLf7`：macOS、固定iPhone/iPad/tvOS/visionOS全部warnings-as-errors成功，五个xcresult均为零结构化diagnostics，每个平台均生成Metal AIR/metallib。
- simulator before/after清单逐字一致，SHA-256均为`1e519a51173fb10edc516770dc4df32c5cf1396442152fc30638d88c6c0adf79`；固定四实例保持唯一、available、`Shutdown`且全局`Booted=0`，未执行任何生命周期命令。下一步运行repository gates。
- 首轮repository包装器在strict-valid变量赋值行混入无意义字符串，fixture与OpenSpec strict完成后、generator和边界门禁前退出；未改代码/project/设备，该目录不计验收。修正后从全新目录完整重跑。

## 2026-07-29 阶段 15 任务 5.2 完成

- repository最终门禁从新目录`/tmp/LuneX-15-5_2-repo-final-r2.L9LM2w`完整通过：fixture validator self-test/全树、OpenSpec strict `6/6`、勾选前apply `23/33`且task 24=false、generator初始与连续三次SHA-256 `3240822c692a403dfd732a4ae0c283408381c2d8180abc9d7c69e2f3c589cfcf`、production/reference/package/Core Image/diff及自有whitespace边界全部通过。
- 5.2实现删除settings-derived synthetic headroom，并把HDR/EDR eligibility收紧到权威streaming snapshot、current media/video readiness、active decoder generation、matching negotiated/decoded metadata，再结合user preference、platform/display capability和真实current headroom解析。
- reconnect顺序改为先应用reconnecting snapshot并关闭render/input/HDR eligibility，再等待media teardown；focused `2/2`、扩大矩阵`134/134`、完整macOS `606 total / 605 passed / 1 Keychain skip / 0 failed`及五平台Debug Metal build均已通过任务级验收。正常测试未启用真实Keychain。
- OpenSpec 5.2标记完成，权威进度更新为`24/33`；阶段15保持`in_progress`。下一项5.3为deduplicated privacy-bounded active-SDR/active-EDR/fallback/error diagnostics。5.4 application gate、5.5 status/settings UI、live Sunshine HDR、compositor EDR signaling及物理亮度/颜色/跨显示器证据仍未完成。

## 2026-07-29 阶段 15 任务 5.3 恢复

- macOS更新后恢复确认活动goal仍为阶段13至20，`HEAD == origin/main == 7184e18`，OpenSpec权威进度`24/33`，工作树仅含暂停前5.3九个文件；本轮不触发真实Keychain或任何simulator生命周期操作。
- 已有实现覆盖稳定HDR类别/代码、privacy-bounded文案、语义去重、仅清`.hdr`的recovery，以及resolver/presenter到AppModel的production回调。提交前审计确认旧SwiftUI presenter在replacement已激活后迟到`stop()`可无条件发布`.inactive`并清除新状态。
- 修复增加presenter-owned UUID lease：configure claim，状态携带owner，stop发布inactive后release；AppModel只接受当前owner的surface事件，resolver的权威closed状态仍可直接发布。新增AppModel与两个真实presenter replacement回归，覆盖旧owner迟到failure/stop不能覆盖replacement。
- 首轮ownership focused在测试编译阶段因新回归误用不存在的`sdrVideoRange()`停止；production源码无诊断。结果`/tmp/LuneX-15-5_3-ownership-focused-r1.zr70yd/Ownership.xcresult`不计验收，fixture改用既有`rec709VideoRange()`后从全新路径重跑。
- 修正后的ownership focused通过`3/3`，扩大`RuntimeDiagnosticsTests + AppModelWorkflowTests + StreamMetalPresenterTests`矩阵通过`84/84`，完整macOS suite通过`612 total / 611 passed / 1 explicit Keychain skip / 0 failed`；所有xcresult结构化diagnostics为0。
- macOS与固定iPhone/iPad/tvOS/visionOS Debug App build全部warnings-as-errors成功并生成Metal artifacts；simulator规范化清单前后SHA-256同为`b4647483e9c488adce9837dfa317dc8bae4a5262249059840f1f80f4fb1dc4e5`，固定四实例唯一、available、`Shutdown`且全局`Booted=0`。
- 首轮repository包装器已完成fixture/strict/apply/generator/reference/package/Core Image/diff/whitespace实质门，但最终仅用于打印摘要的`jq`嵌套引号编译失败并使总退出码为3；该轮不计最终验收，改用无嵌套插值的TSV读回并从全新目录完整重跑。

## 2026-07-29 阶段 15 任务 5.3 完成

- production最后补强后的expanded gate位于`/tmp/LuneX-15-5_3-expanded-final2.hN5slx`并通过`84/84`；完整macOS gate位于`/tmp/LuneX-15-5_3-full-final2.1ezRUN`并通过`612 total / 611 passed / 1 explicit Keychain skip / 0 failed`。两者结构化warning/error/analyzer warning均为0，正常测试未启用真实Keychain。
- 五平台最终build-only位于`/tmp/LuneX-15-5_3-builds-final2.h2BFAz`：macOS、固定iPhone/iPad/tvOS/visionOS均`succeeded`、结构化diagnostics为0，并各生成Metal AIR/metallib。simulator规范化before/after清单逐字一致，SHA-256同为`0470edc00aea815358b4bed51fa43b73b79a5cbc61f80856f9630c6128568d41`；固定四实例唯一、available、`Shutdown`且全局`Booted=0`。
- 最终构建证据首次读回在zsh只读变量`status`处退出；此前simulator比较已完成，但该包装器不计完整验收。改用`build_status`后只重跑未完成的五平台结果/Metal产物读回并通过，未重复生成或操作simulator。
- production最后补强后的repository gates从全新目录`/tmp/LuneX-15-5_3-repo-final3.fZC1hP`完整通过：fixture self-test/全树、OpenSpec strict `6/6`、apply `25/33`且task 25=true/task 26=false、generator初始与连续三次SHA-256均为`3240822c692a403dfd732a4ae0c283408381c2d8180abc9d7c69e2f3c589cfcf`、reference/package/Core Image/diff/owned-whitespace边界全部成立。此前`repo-final-r2`仅保留为最后一行production补强前的中间证据。
- production现发布deduplicated privacy-bounded active SDR/EDR、typed SDR fallback、invalid-input、unsupported-output、stale-revision与pipeline-failure diagnostics；recovery只清`.hdr` current action并保留其他类别与bounded history。
- presenter UUID lease修复replacement ownership：新surface claim后，旧surface迟到failure/draw/stop/release均不能覆盖当前AppModel HDR诊断。ownership `3/3`、扩大矩阵`84/84`、完整macOS `612 total / 611 passed / 1 Keychain skip / 0 failed`及五平台Debug Metal build通过。
- OpenSpec 5.3标记完成，权威进度更新为`25/33`；阶段15保持`in_progress`。下一项5.4为SDR、HDR EDR、headroom downgrade/recovery、metadata、cross-display revision、stale-frame及clean-stop的application integration gate；5.5 UI和live/physical证据继续未完成。
- 提交前完整diff自审发现普通clear failure仅发布诊断而未像first-clear/present failure一样停止runtime；已补`runtime.stop()`，并从全新路径完成expanded/full/five-platform/repository最终门禁。

## 2026-07-29 阶段 15 任务 5.4 启动

- 5.3已以`18db97d Publish bounded HDR diagnostics`独立提交并经Surge SOCKS5推送；fetch确认`HEAD == origin/main == 18db97d`且工作树clean。OpenSpec权威进度`25/33`，下一项精确为5.4。
- 既有AppModel、macOS display transition、Metal frame queue与presenter测试分别覆盖合同片段，但没有单一application ownership流程同时贯穿session/media/decoder、actual presentation source、resolved surface、诊断、revision replacement与stop。
- 5.4在既有`AppModelWorkflowTests`中扩展一个单一gate，使用真实`AppModel + StreamVideoPresentationSource + StreamMetalPresenter`和只记录提交的test runtime，串联HDR EDR、invalid metadata closed/recovery、same-display headroom downgrade/recovery、cross-display revision、SDR metadata change、old HDR frame rejection与clean stop；不增加production抽象或提前实现5.5 UI。
- 首个全新warnings-as-errors focused gate通过`1/1 passed / 0 skipped / 0 failed`，证据`/tmp/LuneX-15-5_4-application-focused.dEqGMa/HDRApplication.xcresult`。测试显式移除`LUNEX_RUN_KEYCHAIN_TEST`，未访问真实Keychain。
- 为使CI选择器直接对应OpenSpec 5.4，最终测试名收紧为`testHDRApplicationIntegrationCoversPresentationRevisionsStaleFramesAndCleanStop()`；重命名后从全新DerivedData通过`1/1`且结构化diagnostics为0，证据`/tmp/LuneX-15-5_4-application-focused-final.unFK3K/HDRApplication.xcresult`。
- 扩大`AppModelWorkflowTests + MacHDRDisplayTransitionTests + MetalVideoFrameDeliveryTests + StreamMetalPresenterTests + RuntimeDiagnosticsTests`矩阵通过`100/100 passed / 0 skipped / 0 failed`，结构化diagnostics为0，证据`/tmp/LuneX-15-5_4-expanded.QnquMp/HDRApplicationExpanded.xcresult`。
- 完整macOS warnings-as-errors suite通过`612 total / 611 passed / 1 skipped / 0 failed`，唯一skip精确为`testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`且结构化diagnostics为0；证据`/tmp/LuneX-15-5_4-full.K42fer/LuneXCoreTests.xcresult`。正常测试仍未再次访问真实Keychain。
- 五平台Debug warnings-as-errors build-only位于`/tmp/LuneX-15-5_4-builds.oG7GAk`：macOS、固定iPhone/iPad/tvOS/visionOS全部成功、结构化diagnostics为0，并各生成一个AIR与metallib。simulator规范化before/after SHA-256同为`0470edc00aea815358b4bed51fa43b73b79a5cbc61f80856f9630c6128568d41`，固定四实例唯一、available、`Shutdown`且全局`Booted=0`。
- 勾选前repository gates位于`/tmp/LuneX-15-5_4-repo-pre.pu7Q0g`：fixture self-test/全树、OpenSpec strict `6/6`、apply `25/33`且task 26=false、generator初始与连续三次SHA-256 `3240822c692a403dfd732a4ae0c283408381c2d8180abc9d7c69e2f3c589cfcf`、reference/package/Core Image/diff/owned-whitespace边界全部通过。

## 2026-07-29 阶段 15 任务 5.4 完成

- 勾选后的repository最终门禁位于`/tmp/LuneX-15-5_4-repo-final.qhBCAc`：fixture self-test/全树、OpenSpec strict `6/6`、apply `26/33`且task 26=true/task 27=false、generator初始与连续三次SHA-256均为`3240822c692a403dfd732a4ae0c283408381c2d8180abc9d7c69e2f3c589cfcf`，reference/package/Core Image/diff/owned-whitespace边界全部通过。
- OpenSpec 5.4标记完成，权威进度更新为`26/33`；阶段15保持`in_progress`。下一项5.5为accessibility-safe native HDR status/settings presentation；6.1–6.6验证/硬件/跟踪任务保持未完成。
- 5.4只增强test target：production graph不新增test hook或抽象，shared recording runtime只记录production presenter已经接受的configuration identity；App targets仍以原始production runtime、mapper与renderer构建。
- 确定性gate不证明compositor实际进入EDR、live Sunshine HDR、物理峰值亮度/颜色准确性、跨显示器视觉一致性或异步GPU fault穷尽；这些边界继续由5.5、6.5及后续阶段保留。

## 2026-07-29 阶段 15 任务 5.5 启动

- 用户完成macOS更新后恢复执行。goal仍active；Git/OpenSpec复核为`HEAD == origin/main == f03151d`、工作树clean、`26/33`，下一项5.5。
- 环境复核为macOS 27.0 build `26A5388g`、Xcode 26.4 build `17E192`、Swift 6.3、Apple SDK 26.4。固定四个26.4 simulator保持唯一、available、`Shutdown`且全局`Booted=0`，未执行任何生命周期命令。
- 5.5范围限定为privacy-bounded observable HDR presentation state、实际状态驱动的stream overlay、Settings当前模式/fallback状态行和明确accessibility label/value；不暴露raw metadata、frame值、host/app identity、display identifier、headroom或revision，不提前执行6.1–6.6。
- 正常测试继续使用`env -u LUNEX_RUN_KEYCHAIN_TEST`，不会再次触发真实Keychain授权；完成实现后先跑focused映射/AppModel/UI接线验收，再进入扩大矩阵与任务级完整门。
- 首轮focused在测试编译阶段因新文件引用`AppModelWorkflowTests.swift`内的三个`private` stub失败，production源码没有报错，测试尚未执行，该证据目录不计验收。测试改为只构造默认无副作用依赖并注入`.unavailable` runtime provider与内存identity store；不调用load、不访问网络/文件/Keychain，待从全新DerivedData重跑。
- macOS 27.0配Xcode 26.4在xcodebuild启动时输出DVT device build-number/empty supported-platform提示；实际target graph与SDK 26.4编译继续启动。该工具层提示与Swift/Clang/xcresult结构化源码诊断分开记录。
- 修正后的focused从全新DerivedData通过`4/4 passed / 0 skipped / 0 failed`，证据`/tmp/LuneX-15-5_5-focused-r2.UDfWjY/HDRPresentationStatus.xcresult`；xcresult结构化warning/error/analyzer warning均为0。覆盖完整语义映射、privacy-bounded固定文案、AppModel当前状态与stale presenter ownership、RootView实际状态/无障碍接线。
- focused test target不编译`RootView.swift`，因此下一步单独构建真实`LuneX-macOS` App target，再运行AppModel/diagnostics/status扩大测试矩阵；源码接线断言不能替代App target编译。
- 真实`LuneX-macOS` Debug App从`/tmp/LuneX-15-5_5-macos-app.N9ylXY`通过warnings-as-errors build，RootView与status model实际编译，xcresult结构化warning/error/analyzer warning均为0，并生成Metal AIR/metallib。
- diagnostics/AppModel/presenter/status扩大矩阵从`/tmp/LuneX-15-5_5-expanded.tygcGG/HDRPresentationExpanded.xcresult`通过`88/88 passed / 0 skipped / 0 failed`，结构化diagnostics为0。
- 完整diff UI自审发现三项状态固定横排在较长fallback/error文案与compact宽度下有溢出风险；改用原生`ViewThatFits`在横排不适配时切换为纵排，并将响应式接线加入5.5 focused gate。此前focused/expanded/build降为修改前中间证据，最终门禁将从新DerivedData重跑。

## 2026-07-29 阶段 15 任务 5.5 完成

- 响应式修改后的focused gate从`/tmp/LuneX-15-5_5-focused-final.4vTrJf/HDRPresentationStatus.xcresult`通过`4/4 passed / 0 skipped / 0 failed`。完整macOS gate从`/tmp/LuneX-15-5_5-full.S8E3xi/LuneXCoreTests.xcresult`通过`616 total / 615 passed / 1 skipped / 0 failed`；唯一skip精确为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，所有结构化diagnostics为0。
- 最终真实macOS App build位于`/tmp/LuneX-15-5_5-macos-app-final.do7VL5`；固定iPhone/iPad/tvOS/visionOS build位于`/tmp/LuneX-15-5_5-builds-final.EKRCNe`。五平台均warnings-as-errors成功、结构化diagnostics为0，并各生成一个Metal AIR与metallib。
- simulator before/after规范化清单逐字一致，SHA-256同为`1213126bde9e530f4ecf568822aaab79d4519a8758ab3b508903b426546c3e12`；固定四实例唯一、available、`Shutdown`且全局`Booted=0`，未执行任何create/boot/launch/shutdown/delete命令。
- 勾选前repository gates位于`/tmp/LuneX-15-5_5-repo-pre.bVdzlK`：fixture self-test/全树、OpenSpec strict `6/6`、apply `26/33`且task 27=false、generator初始与连续三次SHA-256均为`600e420b58fa40401b81e5a9a7360f2e71a52f63d7ae3e4c5e51c4eae02f18ab`，reference/package/Core Image/diff/owned-whitespace边界全部通过。
- 勾选后的repository最终门禁位于`/tmp/LuneX-15-5_5-repo-final.xPjFOk`：fixture/OpenSpec strict `6/6`、apply `27/33`且task 27=true/task 28=false、generator hash稳定、reference/package/Core Image/diff/owned-whitespace边界全部通过。
- OpenSpec 5.5标记完成，权威进度更新为`27/33`；阶段15保持`in_progress`。下一项6.1为normal tests与唯一Keychain skip确认；6.2–6.6、live Sunshine HDR、compositor EDR signaling、物理亮度/颜色/跨显示器证据及设备功耗/性能仍未完成。

## 2026-07-29 阶段 15 任务 6.1 完成

- 从已推送且clean的`93096e3`启动6.1；测试源码审计确认`LUNEX_RUN_KEYCHAIN_TEST`是唯一`LUNEX_RUN_*`读取点，normal suite不存在其他live-host运行入口。
- 独立gate位于`/tmp/LuneX-15-6_1-normal.5ecda4`：运行前无任何`LUNEX_RUN_*` opt-in，命令显式移除`LUNEX_RUN_KEYCHAIN_TEST`，并从全新DerivedData运行完整macOS warnings-as-errors tests。
- xcresult为`616 total / 615 passed / 1 skipped / 0 failed`，唯一skip精确为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`；expected failure为0，结构化warning/error/analyzer warning均为0，没有再次访问真实Keychain。
- 勾选后的repository最终门禁位于`/tmp/LuneX-15-6_1-repo-final.nERR5w`：OpenSpec `28/33`、task 28=true/task 29=false、strict `6/6`、generator hash稳定且所有仓库边界成立。
- OpenSpec 6.1标记完成，权威进度更新为`28/33`；下一项6.2为macOS Debug/Release及固定iPhone/iPad/tvOS/visionOS targets的隔离warnings-as-errors构建。

## 2026-07-29 阶段 15 任务 6.2 完成

- 从已推送且clean的`64c24eb`启动6.2；前置只读盘点确认固定iPhone/iPad/Apple TV/Vision Pro实例唯一、available、`Shutdown`且全局`Booted=0`。
- 证据目录`/tmp/LuneX-15-6_2-builds.0NL62s`包含macOS、固定iPhone、固定iPad、tvOS与visionOS的Debug/Release共10个隔离warnings-as-errors build。全部xcresult为`succeeded`且structured warning/error/analyzer warning为0，每个配置各生成一个Metal AIR与metallib。
- simulator before/after清单逐字一致，SHA-256同为`1213126bde9e530f4ecf568822aaab79d4519a8758ab3b508903b426546c3e12`；未执行任何create/boot/launch/shutdown/delete命令。6.4仍需独立读回，不以本项提前勾选。
- 勾选后的repository最终门禁位于`/tmp/LuneX-15-6_2-repo-final.gB9WWq`：OpenSpec `29/33`、task 29=true/task 30=false、strict `6/6`、generator hash稳定且所有仓库边界成立。
- OpenSpec 6.2标记完成，权威进度更新为`29/33`；下一项6.3为OpenSpec strict、generator、clean-room/dependency、Metal compilation、analyzer、ASan、TSan、malloc ownership与renderer resource-release综合门禁。

## 2026-07-29 阶段 15 任务 6.3 启动

- macOS更新完成后恢复审计确认`HEAD == origin/main == 4895be6`且起始工作树clean；当前环境为macOS 27.0 build `26A5388g`、Xcode 26.4 build `17E192`、Swift 6.3、OpenSpec 1.3.1。
- 6.3从当前提交重新执行fixture/OpenSpec/generator/clean-room/dependency、独立Metal产物、Debug/Release analyzer、完整ASan/TSan及扩展HDR renderer/presenter的malloc/resource-release门，不复用6.2构建或阶段14旧结果。
- 所有测试继续显式`env -u LUNEX_RUN_KEYCHAIN_TEST`并使用Debug文件fallback，不再次触发真实Keychain授权；本项不执行任何simulator create、clone、boot、launch、shutdown、delete、install或run操作。

## 2026-07-29 阶段 15 任务 6.3 完成

- repository/Metal门位于`/tmp/LuneX-15-6_3-repo.nmQyYT`：fixture、OpenSpec strict `6/6`、generator三次哈希`600e420b58fa40401b81e5a9a7360f2e71a52f63d7ae3e4c5e51c4eae02f18ab`、clean-room/dependency/Core Image/whitespace、固定ENet和四SDK direct Metal compile/link全部通过。
- Debug/Release analyzer位于`/tmp/LuneX-15-6_3-static.UVX4ks`：自有bridge零finding，固定ENet两配置各4项且逐字段不漂移。完整ASan与TSan各`616 total / 615 passed / 1 Keychain skip / 0 failed`，零sanitizer report与结构化诊断，证据分别为`/tmp/LuneX-15-6_3-asan.UQAIlh`和`/tmp/LuneX-15-6_3-tsan.ITcsdz`。
- 最终24类malloc/resource-release门在关闭无关coverage后从`/tmp/LuneX-15-6_3-resource-r2.eougt0`通过`343/343`，零malloc报告及结构化diagnostics；阶段15新增的frame delivery、shader readback、pipeline、renderer、surface adapter、presenter、macOS display transition与AppModel均在选择集中。
- 两个bash包装器最初在shell启动前被外层JavaScript模板的`${...}`解析阻止；analyzer expected TSV和ASan skip复核各有一次旧文本口径不匹配。以上均改为字段/当前日志语义判定，不重跑已成功的analyzer或ASan。首轮resource虽`343/343`，但因`llvm-profdata`继承MallocStackLogging产生1条工具warning而不计最终零诊断证据。
- 勾选后的repository最终门禁位于`/tmp/LuneX-15-6_3-repo-final.cuq58y`：OpenSpec `30/33`、task 30=true/task 31=false、strict `6/6`、generator与全部仓库边界稳定。
- OpenSpec 6.3标记完成，权威进度更新为`30/33`；下一项6.4仅执行固定simulator identity/state的独立只读验收，不创建、启动、关闭、删除、安装或运行模拟器。6.5物理HDR/SDR显示器与live Sunshine证据仍未完成。

## 2026-07-29 阶段 15 任务 6.4 完成

- 6.3已以`80ba050 Run HDR quality and resource gates`独立提交并推送，fetch确认`HEAD == origin/main == 80ba050`且工作树clean后进入只读6.4。
- `/tmp/LuneX-15-6_4-simulator-audit-r2.1eiDpv`证明6.2 before/after与当前三份规范化清单逐字一致，SHA-256均为`1213126bde9e530f4ecf568822aaab79d4519a8758ab3b508903b426546c3e12`；四个固定26.4 runtime/name/UUID identity各唯一、available且`Shutdown`，全局`Booted=0`。
- 首轮额外要求产品名称跨所有runtime全局唯一，因iOS/xrOS 27的系统同名实例而退出；这不表示固定UUID重复。最终按`runtime + name + UUID`验证OpenSpec固定identity，并披露跨runtime实例。本项没有创建、启动、关闭、删除、安装或运行任何模拟器。
- OpenSpec 6.4标记完成，权威进度更新为`31/33`。6.5需要授权Sunshine HDR、compositor/物理显示器与跨屏测量证据，当前不可勾选；下一可执行项为6.6更新计划、路线图和硬件限制并封版推送。

## 2026-07-29 阶段 15 任务 6.6 完成

- 6.4已以`54d68fe Verify fixed HDR simulator identities`独立提交并推送，fetch确认`HEAD == origin/main == 54d68fe`且工作树clean后执行6.6。
- 同步OpenSpec、`task_plan.md`、`findings.md`、`progress.md`、runtime roadmap和HDR合同；补齐6.5授权Sunshine版本、参考图、HDR/SDR显示器、动态headroom、跨屏、sleep/reconnect、clean stop及脱敏测量/截图证据清单。
- OpenSpec 6.6标记完成，权威进度更新为`32/33 in_progress`；唯一剩余6.5没有硬件证据，不archive change、不把阶段15标记complete。6.6通过strict/generator/diff门并独立提交推送后，将在已推送HEAD执行一次阶段15离线自验，再进入阶段16 OpenSpec提案与实现。

## 2026-07-29 阶段 15 离线阶段级自验

- 6.6已以`372ca60 Document HDR hardware acceptance boundary`独立提交并推送；fetch确认`HEAD == origin/main == 372ca60`且工作树clean。
- 全新DerivedData完整macOS suite从`/tmp/LuneX-15-stage-acceptance.fbXbLy/Stage15Acceptance.xcresult`通过`616 total / 615 passed / 1 Keychain skip / 0 failed`，唯一skip精确为真实Keychain opt-in，结构化diagnostics为0。
- OpenSpec strict `6/6`、进度`32/33`且6.5唯一pending、generator SHA-256 `600e420b58fa40401b81e5a9a7360f2e71a52f63d7ae3e4c5e51c4eae02f18ab`、固定simulator只读状态门全部通过。
- 该自验只封版阶段15离线证据，不把6.5标记完成。记录提交推送后进入阶段16空间音频OpenSpec提案与实现，并保持阶段13/14/15的live/hardware缺口不变。

## 2026-07-29 阶段 16 启动

- 用户确认macOS更新完成并恢复推进。`planning-with-files` catchup、活动goal、Git、OpenSpec和工具链均已复核：`HEAD == origin/main == 24321b2`、工作树clean、阶段15 `32/33 in_progress`，macOS 27.0/Xcode 26.4/Swift 6.3/OpenSpec 1.3.1。
- 固定simulator约束继续生效；只读检查为全局`Booted=0`，本阶段在具体任务要求前不执行create/clone/boot/bootstatus/launch/shutdown/delete/install/run。
- Keychain已完成唯一一次真实验证；后续命令继续显式`env -u LUNEX_RUN_KEYCHAIN_TEST`并使用Debug文件fallback，不再次触发授权。
- 当前先审计实际audio graph、route/interruption/reconnect ownership、AppModel/UI与SDK availability，随后创建并严格验证OpenSpec `integrate-spatial-audio-runtime`，再按任务逐项实现、自验、提交和推送。
- 已完成第一轮production盘点：`AVAudioEngineClient`当前只有`player -> mainMixer`，`SpatialAudioController`持有另一棵未接入播放的environment node，`NativeSessionAudioProcessorFactory`固定`spatialAudioEnabled: false`；现有能力resolver和diagnostics不是session/runtime owner。
- 已核对Xcode 26.4 SDK headers与Apple官方文档：多声道bed应使用带channel layout的`.ambienceBed`，移动/TV/vision平台需结合`setSupportsMultichannelContent`和spatial capability通知；listener head tracking property在visionOS unavailable。以上作为阶段16 OpenSpec设计输入，尚未修改production源码。

## 2026-07-29 阶段 16 OpenSpec与任务 1.1 完成

- 创建`integrate-spatial-audio-runtime`的proposal、design、3个capability specs和35项tasks；OpenSpec strict通过`1/1 valid / 0 issues`，apply为`ready`。
- 1.1盘点确认production仍是`player -> mainMixer`，孤立controller不影响真实PCM；Moonlight 5.1/7.1为WAVE顺序，Core Audio `WAVE_7_1`可无交换表达；route/recovery/AppModel/UI与entitlement/hardware证据边界已记录。
- 四平台Swift warnings-as-errors API probe通过且没有操作simulator。OpenSpec 1.1已勾选，权威进度`1/35`；下一项1.2实现不可变channel-layout合同。

## 2026-07-30 阶段 16 任务 1.2 完成

- 新增`Sources/LuneXAudio/StreamAudioChannelLayout.swift`并同步generator/project：不可变mono/stereo/WAVE 5.1/WAVE 7.1语义顺序、Moonlight mask、Core Audio tag、空间eligibility、稳定signature和unsupported-count error。
- 最终focused证据`/tmp/LuneX-16-1_2-focused-final.oYLfia`为`2/2`，扩大`AudioPipelineTests`证据`/tmp/LuneX-16-1_2-expanded.1785341970`为`13/13`；两者结构化diagnostics均为0。
- 新合同通过四平台26 SDK warnings-as-errors typecheck，generator连续SHA-256为`f574f90c46d6fcc614ad9601d4df3b6787e0de1750689f9d1a5ba55d616a04ff`。OpenSpec 1.2已勾选，权威进度`2/35`；下一项1.3为语义空间状态snapshot与resolver。

## 2026-07-30 阶段 16 任务 1.3 完成

- 新增`Sources/LuneXAudio/SpatialAudioRuntimeState.swift`及测试并同步generator/project：graph、平台策略、route capability、entitlement、fixed/head-tracked presentation、typed fallback和semantic revision均为不可变Sendable值。
- 审查修复了关闭head tracking时绕过平台策略与visionOS fixed readback的问题；resolver现在只根据同revision graph/route事实发布状态，macOS route unknown与移动/TV route unsupported策略保持显式分层。
- 最终focused证据`/tmp/LuneX-16-1_3-focused-r2.NN47Sb`为`8/8 passed / 0 skipped / 0 failed`且结构化diagnostics为0；四平台26 SDK warnings-as-errors typecheck、OpenSpec strict、`git diff --check`和generator稳定性均通过。
- 测试显式移除Keychain opt-in且未操作simulator。OpenSpec 1.3已勾选，权威进度`3/35`；下一项1.4绑定negotiated configuration与decoded PCM的单一layout identity。

## 2026-07-30 阶段 16 任务 1.4 完成

- negotiated audio、decoder PCM和pipeline config改为存储canonical `StreamAudioChannelLayout`，raw count只在RTSP输入边界解析一次并在各层派生；decoder、concealment和schedule不再独立重建或仅按整数比较声道语义。
- 新增同声道数错序拒绝与RTSP/decoder identity回归，并更新所有session/AppModel测试构造点。focused`46/46`、扩大`84/84`均通过且结构化diagnostics为0。
- 首轮iOS generic build因缺launch screen产生1条Xcode工程warning，build虽succeeded但未计零诊断验收；generator补`INFOPLIST_KEY_UILaunchScreen_Generation=YES`后，最终macOS/iOS/tvOS/visionOS四平台App build均0 warning/error/analyzer warning。
- OpenSpec strict、`git diff --check`及generator连续SHA-256 `6038b4542bfc2c3a0eacfdc0f0c4176cc5db08837ee23dc02045c02f0e35f64e`通过；Keychain opt-in保持移除且未操作simulator。OpenSpec进度`4/35`，下一项1.5。

## 2026-07-30 阶段 16 任务 1.5 完成

- 增加192组合platform/preference/route/entitlement resolver主网格及graph/layout/algorithm/strategy/readback、stale graph/route、output/channel-limit边界；既有channel order/tag/mask、ambiguous count和同count错序拒绝继续纳入扩大门。
- layout signature identifier改为闭合layout kind；新增1...64严格容量的`SpatialAudioRuntimeHistory`，验证duplicate revision去重、conflict/stale拒绝、旧值淘汰与只保存privacy-safe snapshot。该纯值类型不提前实现3.5 route monitor或5.2 diagnostics owner。
- 最终focused`29/29`、扩大`78/78 passed / 0 skipped / 0 failed`；macOS/iOS/tvOS/visionOS generic-device Debug App warnings-as-errors build全部成功且编译器warning/error为0。测试显式移除Keychain opt-in，未选择、启动或修改simulator。
- OpenSpec strict、`git diff --check`和generator初始/连续两次SHA-256 `6038b4542bfc2c3a0eacfdc0f0c4176cc5db08837ee23dc02045c02f0e35f64e`通过。OpenSpec 1.5已勾选，权威进度`5/35`；下一项2.1扩展injectable engine client graph intent与actual spatial runtime snapshot合同。

## 2026-07-30 阶段 16 任务 2.1 完成

- 扩展`AudioEngineClient.configure`为纯值`configuration + SpatialAudioGraphIntent -> SpatialAudioRuntimeSnapshot`合同；pipeline保存actual snapshot并fail closed验证revision/layout/route与activation一致性，failure/start/stop清理actual状态。`SessionAudioRuntime`在start/rebuild中复用同一immutable intent，production mixer不虚报spatial active。
- focused warnings-as-errors gate位于`/tmp/LuneX-16-2_1-focused.1G5ijI`并通过`27/27`；最终expanded gate位于`/tmp/LuneX-16-2_1-expanded.NyQDxe`并通过`68/68 passed / 0 skipped / 0 failed`。两份xcresult结构化warning/error/analyzer warning均为0，测试显式移除`LUNEX_RUN_KEYCHAIN_TEST`。
- macOS、iOS、tvOS、visionOS generic-device Debug App build分别位于`/tmp/LuneX-16-2_1-build-macos.J9pfNu`、`/tmp/LuneX-16-2_1-build-ios.vgZNuJ`、`/tmp/LuneX-16-2_1-build-tvos.bDeb2F`和`/tmp/LuneX-16-2_1-build-visionos.hhYFzw`；全部warnings-as-errors succeeded，结构化diagnostics为0，未启动、安装、运行或修改simulator。
- OpenSpec strict、纯值协议与未提前实现2.2至2.5的源码边界、`git diff --check`、generator连续SHA-256 `6038b4542bfc2c3a0eacfdc0f0c4176cc5db08837ee23dc02045c02f0e35f64e`通过。OpenSpec 2.1已勾选，权威进度`6/35`；下一项2.2构造带显式Core Audio channel layout的interleaved `AVAudioFormat`并验证buffer-list channel/byte ownership。

## 2026-07-30 阶段 16 任务 2.2 启动

- `6e541b6 Add spatial audio engine intent contract`已推送，fetch确认`HEAD == origin/main`且工作树clean后进入2.2。
- Apple AVFAudio文档、Xcode 26.4 headers与本地Swift探针确认多于2声道必须使用explicit `AVAudioChannelLayout` initializer；当前production的channel-count initializer无法建立5.1/7.1 format。
- 当前只实现共享explicit format factory和PCM buffer-list channel/byte ownership，不attach environment node、不设置ambience-bed/algorithm/head tracking或平台route API。测试继续显式移除Keychain opt-in且不操作simulator。

## 2026-07-30 阶段 16 任务 2.2 完成

- 新增`Sources/LuneXAudio/AVAudioStreamFormatFactory.swift`并同步generator/project；只为48 kHz canonical mono/stereo/WAVE 5.1/WAVE 7.1构造显式layout、interleaved Int16格式，并读回验证完整ASBD。production engine connection与PCM buffer使用同一factory。
- buffer factory在copy前验证单一interleaved buffer、exact channel count、exact mutable/immutable byte size与非nil owner pointer；新增四layout格式/ASBD/ownership/样本顺序矩阵，以及44.1 kHz和同声道数错序layout拒绝测试。
- focused gate位于`/tmp/LuneX-16-2_2-focused.X4QVoy`并通过`20/20`；expanded audio/runtime/media/spatial gate位于`/tmp/LuneX-16-2_2-expanded.4871bi`并通过`71/71 passed / 0 skipped / 0 failed`。两份xcresult结构化warning/error/analyzer warning均为0。
- macOS、iOS、tvOS、visionOS generic-device Debug warnings-as-errors App build分别位于`/tmp/LuneX-16-2_2-build-macos.1785345411219`、`/tmp/LuneX-16-2_2-build-ios.1785345411220`、`/tmp/LuneX-16-2_2-build-tvos.1785345411220`和`/tmp/LuneX-16-2_2-build-visionos.1785345411220`；四份result bundle均succeeded且结构化diagnostics为0。包装器的zsh只读`status`错误不改变xcodebuild终态，已直接从xcresult读回。
- repository gate位于`/tmp/LuneX-16-2_2-repo-pre.uF5zts`：OpenSpec strict、generator三次SHA-256 `ccf808d5433b17ef02b02a915b880f1ba77e6a95ee27abb0fdcc3f638ac84e20`、五target membership与`git diff --check`通过。测试继续显式移除Keychain opt-in且未操作simulator。
- OpenSpec 2.2已勾选，权威进度更新为`7/35`；下一项2.3 attach session-owned environment node并建立eligible ambience-bed graph。2.2不证明environment graph、route/head tracking、entitlement或硬件空间音频。

## 2026-07-30 阶段 16 任务 2.3 启动

- 2.2已以`7a4db76 Validate explicit spatial audio formats`独立提交并推送，fetch确认`HEAD == origin/main`且工作树clean后进入2.3。
- Context7 Apple AVFAudio、Xcode 26.4 headers与未启动硬件的本机probe确认：先连接environment output再读取applicable algorithms，eligible bed使用`.ambienceBed`，且只在`.auto`属于applicable集合时选择它。
- 当前实现把environment纳入`AVAudioEngineClient`唯一所有权，eligible路径连接`player -> environment -> mainMixer`，disabled/unsupported路径保持direct mixer；移除持有第二个孤立environment的旧controller。2.5之前不启用listener head tracking或visionOS intended experience，3.x之前不监听route/session notification。

## 2026-07-30 阶段 16 任务 2.3 完成

- `AVAudioEngineClient`新增唯一session-owned environment node、actual graph readback和平台/route/layout eligibility；eligible stereo/WAVE 5.1/WAVE 7.1连接`player -> environment -> mainMixer`，只在连接后applicable集合含`.auto`时选择`.ambienceBed + .auto`。disabled路径保持direct mixer，stop清除graph connections。
- 删除`AudioRouteState.swift`中持有第二个无声environment的旧`SpatialAudioController`。production当前没有listener head tracking、visionOS intended experience或route/session notification接线。
- 最终focused gate位于`/tmp/LuneX-16-2_3-focused-final.KFeHQK`并通过`21/21`；expanded gate位于`/tmp/LuneX-16-2_3-expanded.GD6mkP`并通过`72/72 passed / 0 skipped / 0 failed`。两份xcresult结构化warning/error/analyzer warning均为0。
- macOS/iOS/tvOS/visionOS generic-device Debug warnings-as-errors build位于`/tmp/LuneX-16-2_3-build-{macos,ios,tvos,visionos}.1785346100312`；四份result bundle均succeeded且结构化diagnostics为0，未选择或操作simulator。
- repository pre-gate位于`/tmp/LuneX-16-2_3-repo-pre.EqUwFd`：OpenSpec strict、唯一environment owner、applicable algorithm顺序、2.5/3.x API未提前出现、`git diff --check`和generator三次SHA-256 `ccf808d5433b17ef02b02a915b880f1ba77e6a95ee27abb0fdcc3f638ac84e20`通过。
- OpenSpec 2.3已勾选，权威进度更新为`8/35`；下一项2.4实现mono、用户关闭、unsupported route/algorithm和graph failure的完整typed nonspatial fallback，不虚报activation。

## 2026-07-30 阶段 16 任务 2.4 完成

- 新增同步injectable environment graph builder和闭合graph fallback readback。eligible graph若缺`.auto`或部分配置失败，client会清除player/environment output connection，重建并验证`player -> mainMixer`，保留有效PCM configuration。
- resolver优先级已调整：合法revision/output/route snapshot之后依次处理用户关闭、unsupported layout、unsupported route、typed graph failure、actual environment/algorithm/strategy，因此route不再被generic graph mode遮蔽。
- focused warnings-as-errors gate`39/39`通过，证据`/tmp/LuneX-16-2_4-focused.Ay4a8o/SpatialFallback.xcresult`；expanded audio/recovery/runtime/media gate`74/74`通过，证据`/tmp/LuneX-16-2_4-expanded.YVmJGf/SpatialFallbackExpanded.xcresult`。两份结果0 skip/failed且结构化warning/error/analyzer warning为0，均显式移除真实Keychain opt-in。
- macOS、iOS、tvOS、visionOS generic-device Debug warnings-as-errors build全部成功，证据`/tmp/LuneX-16-2_4-build-{macos,ios,tvos,visionos}.1785346796029`；四份xcresult结构化diagnostics为0，未创建、启动、安装、运行、关闭或删除simulator。
- repository final gate为`/tmp/LuneX-16-2_4-repo-final.c5LkRu`：OpenSpec `9/35 ready`与strict、唯一environment owner、2.5 API边界、generator稳定SHA-256 `ccf808d5433b17ef02b02a915b880f1ba77e6a95ee27abb0fdcc3f638ac84e20`和`git diff --check`通过。
- OpenSpec 2.4已勾选，权威进度更新为`9/35`；下一项2.5只实现平台正确的listener head tracking/visionOS intended spatial experience，不把属性readback、编译或模拟器当作AirPods/可听定位真机证明。

## 2026-07-30 阶段 16 任务 2.5 完成

- 新增injectable `AVAudioSpatialPlatformApplying`与production adapter。macOS/iOS/tvOS仅在用户开启且entitlement为`.granted`时请求`isListenerHeadTrackingEnabled`，并把实际属性读回交给resolver；关闭、缺失entitlement、fallback、reconfigure和stop都不会保留true状态。
- visionOS 26只编译`AVAudioOutputNode.intendedSpatialExperience`分支，按用户偏好设置并读回`.headTracked`或`.fixed`，reset/direct fallback/stop恢复`.bypassed`。graph readback新增平台策略、listener capability/readback和vision experience字段。
- focused warnings-as-errors gate为`/tmp/LuneX-16-2_5-focused.iNPJG2`，通过`41/41`；expanded audio/recovery/runtime/media gate为`/tmp/LuneX-16-2_5-expanded.EOEpX4`，通过`76/76 passed / 0 skipped / 0 failed`。两份结构化diagnostics均为0，测试显式移除真实Keychain opt-in。
- macOS、iOS、tvOS、visionOS generic-device Debug warnings-as-errors build均成功，证据`/tmp/LuneX-16-2_5-build-{macos,ios,tvos,visionos}.1785347392506`；四份xcresult均0 warning/error/analyzer warning，未选择或操作simulator。
- repository gate为`/tmp/LuneX-16-2_5-repo-final.yqhF1t`：OpenSpec strict、唯一environment owner、compile branch/API扫描、clean-room边界、generator稳定哈希与`git diff --check`通过。首轮静态脚本误将3处listener API引用断言为2并提前退出；修正预期后只完成余下门禁，未更改产品实现或工程内容。
- OpenSpec 2.5已勾选，权威进度更新为`10/35`；下一项2.6补齐topology、schedule/readback、vision策略、partial failure、stop/idempotence和resource release测试。当前证据不声称AirPods、signed entitlement、visionOS可听定位或物理多声道输出已验证。

## 2026-07-30 阶段 16 任务 2.6 完成

- 扩展`AudioPipelineTests`：同count错序PCM拒绝后容量保持可用；stereo/WAVE 5.1/WAVE 7.1 production ambience-bed graph在schedule前后readback稳定；head-tracked graph降级到direct mixer会先清平台状态，重复stop稳定。
- partial environment connection和algorithm failure均验证不调用platform apply、清理environment拓扑并继续PCM；新增client/injected adapter ARC释放回归，并继续复用visionOS strategy、resolver、recovery和late-completion矩阵。
- focused gate为`/tmp/LuneX-16-2_6-focused-r2.zgzpXm`，通过`43/43`；expanded gate为`/tmp/LuneX-16-2_6-expanded.VNUinJ`，通过`78/78 passed / 0 skipped / 0 failed`。两份结构化diagnostics均为0，测试显式移除真实Keychain opt-in。
- macOS、iOS、tvOS、visionOS generic-device Debug warnings-as-errors build全部成功且四份xcresult结构化diagnostics为0，未选择或操作simulator。首次visionOS外层编排未形成xcresult，因此没有计为通过；直接exec在新隔离目录完整重跑后验收。
- OpenSpec strict、generator稳定SHA-256 `ccf808d5433b17ef02b02a915b880f1ba77e6a95ee27abb0fdcc3f638ac84e20`、完整diff自审和`git diff --check`通过。OpenSpec 2.6已勾选，权威进度`11/35`；下一项3.1为injectable Security-backed embedded entitlement reader。
- 当前ARC/readback/build证据不替代6.4 malloc/resource gate，也不证明AirPods head tracking、visionOS可听空间定位、signed entitlement provisioning或物理多声道输出。

## 2026-07-30 阶段 16 任务 3.1 启动

- `b2fb0c5 Expand spatial audio graph tests`已推送，fetch确认`HEAD == origin/main`且工作树clean后进入3.1。
- Context7 Apple Security源码、本机SDK header和Swift typecheck确认SecTask entitlement查询是macOS公开API；iOS 26.4不导出该Swift符号。当前实现将使用macOS Security backend与其他平台fail-closed backend，不调用私有API。
- 本项只实现injectable embedded entitlement query和true/false/missing/malformed/unreadable解析测试；3.2才新增generator-owned entitlement文件/build settings，route/session接线仍属于3.3至4.x。

## 2026-07-30 阶段 16 任务 3.1 完成

- 新增`EmbeddedHeadPoseEntitlementReader.swift`及独立tests并同步generator/project。macOS production使用公开Security SecTask查询，typed boundary只允许literal CFBoolean true获得`.granted`；false/missing、malformed和read error全部fail closed。
- iOS/tvOS/visionOS 26.4 SDK不公开SecTask查询符号，production编译分支明确返回`.unreadable`且不声明私有API；OpenSpec design已同步这一限制和后续signed-artifact/physical proof边界。
- 最终focused`4/4`、expanded entitlement/resolver/audio graph`47/47 passed / 0 skipped / 0 failed`，结构化diagnostics均为0；真实当前进程SecTask smoke query不访问Keychain。
- macOS、iOS、tvOS、visionOS generic-device Debug warnings-as-errors build全部succeeded，四份xcresult结构化diagnostics为0，未选择或操作simulator。
- OpenSpec strict、generator稳定SHA-256 `a82a2c95509603c047d02e72a7804d46caa3a23dff90613b5a2471e06551b378`、source membership、private API boundary和`git diff --check`通过。OpenSpec 3.1已勾选，权威进度`12/35`；下一项3.2为generator-owned macOS/iOS/tvOS entitlement文件与build settings。

## 2026-07-30 阶段 16 任务 3.2 完成

- 新增三份独立head-pose entitlement plist并扩展generator：Configuration group持有file references，macOS/iOS/tvOS Debug/Release设置各自`CODE_SIGN_ENTITLEMENTS`，visionOS与tests保持无设置。
- `plutil`及JSON typed gate确认每份文件只有一个Boolean true key；八组`xcodebuild -showBuildSettings`确认三平台路径和visionOS absence，test target Debug/Release同样absence。
- `/tmp/LuneX-16-3_2-builds.UPibfE`完成四平台Debug+Release generic-device warnings-as-errors、unsigned build，8/8 succeeded且结构化diagnostics为0；未操作simulator。
- OpenSpec strict、generator稳定SHA-256 `00c4566845e6b2b72b5ddce04f825a6e0c9e0a68111bd0b1ed8609f5044bedb7`、project membership、Resources隔离和`git diff --check`通过。OpenSpec 3.2已勾选，权威进度`13/35`；下一项3.3为移动/TV/vision `AVAudioSession` adapter。
- 本项不证明signed provisioning或真机entitlement；不能以unsigned build和plist内容替代6.6硬件/签名验收。

## 2026-07-30 阶段 16 任务 3.3 完成

- 新增generator-owned `MobileAudioSessionAdapter.swift`与注入测试；production engine在iOS/iPadOS、tvOS、visionOS通过同一owner配置playback/moviePlayback、multichannel declaration、sample rate/buffer duration、maximum-clamped preferred channels、route spatial-port readback与deactivation。
- 激活失败原子回滚多声道声明与session active状态；stop清除声明并通知其他音频。output name仅保留为有界诊断值，capability只读取port布尔值；capability notification名称已适配，实际observer/去重保留3.5。
- focused `7/7`、expanded audio graph/resolver/runtime `52/52 passed / 0 skipped / 0 failed`；两份结果均使用`env -u LUNEX_RUN_KEYCHAIN_TEST`，expanded结构化diagnostics为0。
- 四平台generic-device Debug unsigned warnings-as-errors build全部succeeded且结构化warning/error/analyzer warning为0；iOS target device family为`1,2`并覆盖iPadOS编译面，未操作simulator。
- OpenSpec strict、五target membership、旧direct shared-session调用absence、output-name noninference、`git diff --check`及generator稳定SHA-256 `8be5fad05baba9ff45a8f192186766ab3bf0ea483f276d0400291ee69c6d9de0`通过。
- OpenSpec 3.3已勾选，预期权威进度`14/35`；下一项3.4为macOS actual engine output format与graph result驱动的route/output capability。当前证据不替代签名、route通知、AirPods或物理声道/可听验收。

## 2026-07-30 阶段 16 任务 3.4 完成

- 新增generator-owned macOS actual-output capability resolver并接入production `AVAudioEngineClient` readback：只消费真实output format与graph mode/fallback/connection/applicable algorithm，不接受output name输入。
- focused `6/6`、expanded `56/56 passed / 0 skipped / 0 failed`，expanded结构化warning/error/analyzer warning为0；命令显式移除`LUNEX_RUN_KEYCHAIN_TEST`。
- 四平台generic-device Debug unsigned warnings-as-errors build全部succeeded且结构化diagnostics为0，未操作simulator。
- OpenSpec strict、five-target membership、output-name absence、`git diff --check`及generator稳定SHA-256 `a306bccd3be7666c185bd9fcb2dd54418634ffba01603045638e6a71f0236a7d`通过。
- OpenSpec 3.4已勾选，预期权威进度`15/35`；下一项3.5为有界route/interruption/media-services/spatial-capability monitor与deduplicated semantic revision。当前capability readback不替代通知接线、runtime rebuild或物理硬件验收。

## 2026-07-30 阶段 16 任务 3.5 完成

- 新增generator-owned `SpatialAudioRouteMonitor.swift`与9项测试：移动家族真实NotificationCenter名称适配、纯值capability reader、有界`bufferingNewest` stream、初始snapshot、语义去重、interruption/media-services转换、reset-without-lost、stop/deinit、late-callback suppression及revision exhaustion均已覆盖。
- 最终focused `9/9`、expanded `69/69 passed / 0 skipped / 0 failed`；macOS、iOS/iPadOS、tvOS、visionOS generic-device Debug unsigned warnings-as-errors build全部succeeded，所有xcresult的warning/error/analyzer warning均为0。
- OpenSpec strict、source/test membership、`git diff --check`与generator稳定SHA-256 `58624b6c963c78240dfb4226acb8ce55752768700643e1ac5a8b8ba120c68038`通过。测试显式移除`LUNEX_RUN_KEYCHAIN_TEST`，没有访问真实Keychain，也没有创建、启动或操作simulator。
- OpenSpec 3.5已勾选，权威进度更新为`16/35`；下一项3.6补齐entitlement、platform matrix、multichannel limit、capability/equivalent notification、missing route、output-name noninference、deactivate与真实observer cleanup测试。3.5不证明runtime graph rebuild、签名权限或物理空间音频。

## 2026-07-30 阶段 16 任务 3.6 启动

- 3.5已以`7636fd4 Observe spatial audio route revisions`独立提交并推送，fetch确认`HEAD == origin/main`且工作树clean后进入3.6。
- 本项只补平台adapter、entitlement和真实NotificationCenter observer矩阵；不接入`SessionAudioRuntime` graph rebuild、processor/media environment、AppModel或UI。测试继续显式移除真实Keychain opt-in，且不创建或操作simulator。

## 2026-07-30 阶段 16 任务 3.6 完成

- 扩展mobile adapter matrix：9组layout/maximum组合、multiport capability与名称非推断、missing route、capability notification和deactivate失败后的本地state清理；扩展真实NotificationCenter source的对象过滤、start替换、stop/deinit token清理和monitor等价通知去重。
- 最终focused `24/24`、expanded `77/77 passed / 0 skipped / 0 failed`；macOS、iOS/iPadOS、tvOS、visionOS generic-device Debug unsigned warnings-as-errors build全部succeeded，六份xcresult的warning/error/analyzer warning均为0。
- OpenSpec strict、覆盖静态门、`git diff --check`与generator稳定SHA-256 `58624b6c963c78240dfb4226acb8ce55752768700643e1ac5a8b8ba120c68038`通过。测试显式移除`LUNEX_RUN_KEYCHAIN_TEST`，未访问真实Keychain，也未创建、启动或操作simulator。
- OpenSpec 3.6已勾选，权威进度更新为`17/35`；下一项4.1将route/spatial policy revision串行接入`SessionAudioRuntime`，处理interruption期间延后、原子rebuild及media-clock/concealment保持。3.6不证明runtime接线、签名权限或物理空间音频。

## 2026-07-30 阶段 16 任务 4.1 启动

- 3.6已以`1101a7c Expand spatial route adapter tests`独立提交并推送，fetch确认`HEAD == origin/main`且工作树clean后进入4.1。
- 本项只扩展`SessionAudioRuntime`的route/spatial policy revision串行化、interruption延后、原子rebuild及media-clock/concealment保持；monitor ownership、processor event stream、media environment和AppModel分别保留给4.2至4.4。
- 更新后环境复核为macOS 27.0、Xcode 26.4、Swift 6.3；长期goal保持active，OpenSpec权威进度仍为`17/35`，没有运行中的build/test或simulator操作。
- `SessionAudioRuntime`已加入FIFO异步operation gate并新增typed spatial-policy revision入口；聚焦测试正在覆盖单次精确重建、等价/冲突/陈旧拒绝、中断latest-wins、concealment/clock保持、late completion、graph failure及in-flight操作串行化。
- 首次测试命令误用不含test action的`LuneX-macOS` scheme且未预建日志目录，未进入编译；切换`LuneXCoreTests`后首轮编译准确暴露4处XCTest同步autoclosure内`await`错误，已改为先读取actor值再断言。两次均为命令/测试代码问题，不是产品运行失败。
- 聚焦r2继续在编译期拒绝并发测试Task捕获XCTestCase `self`；已在创建Task前生成immutable PCM值，避免sending closure跨并发域捕获测试实例。

## 2026-07-30 阶段 16 任务 4.1 完成

- `SessionAudioRuntime`现以独立FIFO异步operation gate串行化start、schedule、discontinuity、spatial policy、stop和snapshot；等待期间取消的Task在取得gate后立即抛出`CancellationError`，不会执行迟到调度。
- 新spatial-policy入口严格校验consistent route revision、固定平台和单调event/revision：等价intent返回bounded unchanged，冲突/陈旧/非法intent typed fail closed；更高revision在running时原子重建，在interruption时latest-wins延后到resume。
- policy rebuild使用精确最新intent，失效旧scheduled-buffer generation、拒绝late completion并重置media clock，同时保持累计concealment frame count；graph失败清理pipeline并把runtime收敛到failed。
- 最终focused `/tmp/LuneX-16-4_1-focused-final-r2.1785353593.xcresult` 为`17/17 passed`，expanded `/tmp/LuneX-16-4_1-expanded-final-r2.1785353609.xcresult` 为`74/74 passed`；均`0 skipped / 0 failed`并显式移除真实Keychain opt-in。
- macOS、iOS/iPadOS、tvOS、visionOS generic-device Debug unsigned warnings-as-errors最终build位于`/tmp/LuneX-16-4_1-builds.1785353391/*/Build-final.xcresult`，4/4 succeeded；六份最终xcresult结构化warning/error/analyzer warning均为0。
- OpenSpec strict、`git diff --check`、scope boundary及generator双次稳定SHA-256 `58624b6c963c78240dfb4226acb8ce55752768700643e1ac5a8b8ba120c68038`通过；未访问真实Keychain，未创建、启动或操作simulator。
- OpenSpec 4.1已勾选，预期权威进度`18/35`；下一项4.2扩展`NativeSessionAudioProcessor`及factory以拥有route monitor、当前spatial preferences、graph generation和semantic audio-state stream。4.1不接线processor/media environment/AppModel，也不证明签名权限或物理空间音频。

## 2026-07-30 阶段 16 任务 4.2 启动

- 4.1已以`2e95452 Serialize spatial audio recovery`独立提交并推送；fetch确认`HEAD == origin/main`且工作树clean后进入4.2。
- 本项只扩展`NativeSessionAudioProcessor`和factory的route monitor、spatial preference、graph generation及semantic audio-state stream ownership；media environment forwarding、AppModel和UI分别保留给4.3、4.4和5.x。
- 恢复后核对长期goal仍为active，OpenSpec为`18/35 ready`且下一项4.2；catchup只发现本段启动日志未提交，代码仍等于`origin/main`的`2e95452`。
- Apple AVFAudio文档确认route notification在secondary thread交付并要求route/capability变化后重新查询当前能力。4.2设计因此将让monitor读取实际engine owner，并同步保护共享mobile adapter/macOS engine readback；processor使用独立单调policy revision，避免route与preference各自revision碰撞。
- 预定semantic event只携带bounded cause/stage/spatial snapshot/recovery fields，不携带output names、free-form graph error或clock payload；graph generation只随真实initial/rebuild递增。测试仍显式移除真实Keychain opt-in，不操作simulator。

## 2026-07-30 系统更新后恢复

- 持久goal保持`active`，目标仍为阶段13至20；OpenSpec `integrate-spatial-audio-runtime`为`18/35 ready`，继续当前4.2，不跳过未完成的live/hardware证据。
- 环境核对为Xcode 26.4、Swift 6.3；iOS/tvOS/visionOS 26.4与27.0 runtime存在，当前没有Booted simulator。本项不需要创建、启动、安装、运行或关闭simulator。
- 工作树中的audio/runtime/test与planning改动均属于暂停前4.2；consumer-cancellation测试已经移除无关的`Task.result`读取，取消后只yield一次，再以成功graph reconfigure和未停止route source证明processor存活。
- 恢复后的首轮focused命令误用无test action的`LuneX-macOS` scheme，在任何编译前退出；该轮不计证据。下一轮改用`LuneXCoreTests`、全新DerivedData/result bundle并继续显式`env -u LUNEX_RUN_KEYCHAIN_TEST`。
- 首次有效focused运行编译与7/8 case通过，consumer cancellation case已通过；唯一graph-failure case超时。根因是route observer在`convergeRuntimeFailure`中取消自身，导致紧随其后的`runtime.snapshot` cancellation check抛出而不发布`.failed`。修复为只stop/finish monitor流，不自取消observer，待发布失败快照后自然退出。

## 2026-07-30 阶段 16 任务 4.2 完成

- processor/factory现统一拥有实际engine route reader、route monitor、内存态spatial preferences、独立policy revision、graph generation和有界semantic audio event stream；AudioToolbox decoder抽象为可注入`SessionAudioDecoding`，所有factory部分失败路径均停止monitor/runtime并关闭decoder。
- route/preference/scheduling/stop经processor operation gate串行；中断latest-wins、等价去重、failure收敛、consumer cancellation不反向停止、late callback抑制和stop顺序均有确定性回归。自取消导致`.failed`漏发的问题已经修复。
- 最终focused `/tmp/LuneX-16-4_2-focused-r4.bBXtAK/Focused.xcresult`为`8/8`；expanded `/tmp/LuneX-16-4_2-expanded.NWbZpu/Expanded.xcresult`为`88/88`；完整macOS `/tmp/LuneX-16-4_2-full.yxRLuS/LuneXCoreTests.xcresult`为`698 total / 697 passed / 1 explicit Keychain skip / 0 failed`。全部结构化warning/error/analyzer warning为0。
- macOS、iOS/iPadOS、tvOS、visionOS generic-device Debug unsigned warnings-as-errors build位于`/tmp/LuneX-16-4_2-builds.lp76FS/*/Build.xcresult`，4/4 succeeded且结构化diagnostics为0。前后全局`Booted=0`，没有创建、启动或操作simulator。
- OpenSpec strict、scope/privacy静态门、`git diff --check`与generator双次稳定SHA-256 `733bedca4c341da86c790bfdc406301e4d244d827cca0292c767a9db107ae3e6`通过；测试始终显式移除`LUNEX_RUN_KEYCHAIN_TEST`，没有再次访问真实Keychain。
- OpenSpec 4.2已勾选，权威进度更新为`19/35`；下一项4.3把current-generation audio runtime state经`NativeSessionMediaEnvironment`转发并拒绝stale processor/rebuild事件。4.2不证明AppModel/UI已接线，也不证明签名entitlement、AirPods head tracking、route transition可听同步或物理多声道定位。

## 2026-07-30 阶段 16 任务 4.3 启动

- 4.2已以`6ab3e50 Own spatial audio processor state`独立提交并推送，fetch确认`HEAD == origin/main`且工作树clean；OpenSpec权威进度`19/35`，进入4.3。
- 本项新增media-generation-owned audio runtime wrapper、environment event/snapshot转发、第4个tracked consumer及stale sequence/graph/session过滤；AppModel只保持枚举穷尽，实际应用状态和preference binding留给4.4。
- 继续显式移除真实Keychain opt-in，不创建、启动或操作simulator；4.3离线证据不替代签名entitlement、AirPods、route transition或物理多声道验收。
- 系统更新后恢复确认Xcode 26.4、Swift 6.3、长期goal active且`main == origin/main`；catchup中的未同步内容正是本项4.3未提交改动，没有回滚或覆盖。
- 测试替身已改为持有长期打开的audio runtime stream，正常stop才结束；环境测试任务计数同步为4，并新增current-generation转发/snapshot、sequence与graph回退、同session replacement迟到事件、runtime stream意外结束四类回归。下一步从全新隔离DerivedData运行focused gate。
- focused `/tmp/LuneX-16-4_3-focused.4BWxwO/Focused.xcresult`已结构化确认`27/27 passed / 0 skipped / 0 failed`，warning/error/analyzer warning为0。首次诊断读回误用已废弃的`xcresulttool get issues`子命令，测试结果本身不受影响；已改用Xcode 26.4的`get build-results`并成功读取零诊断，后续证据统一使用新子命令。

## 2026-07-30 阶段 16 任务 4.3 完成

- `NativeSessionMediaEnvironment`新增media-generation-owned audio runtime wrapper、统一event/snapshot转发和第4个tracked consumer；只接受当前session/generation、匹配processor session、严格递增sequence且不回退graph generation的事件。
- 同session replacement迟到processor事件、错session、sequence重复/回退、graph回退和runtime stream意外结束均有确定性回归；默认测试processor改为正常生命周期内保持stream打开，stop时才finish，避免伪造production早停。
- focused `/tmp/LuneX-16-4_3-focused.4BWxwO/Focused.xcresult`为`27/27`，expanded `/tmp/LuneX-16-4_3-expanded.AQ1t5f/Expanded.xcresult`为`93/93`，完整macOS `/tmp/LuneX-16-4_3-full.3CnFbV/LuneXCoreTests.xcresult`为`702 total / 701 passed / 1 explicit Keychain skip / 0 failed`；三份结构化diagnostics均为0。
- macOS、iOS/iPadOS、tvOS、visionOS generic-device Debug unsigned warnings-as-errors build位于`/tmp/LuneX-16-4_3-builds.DF4774/*/Build.xcresult`，4/4 succeeded且结构化diagnostics为0。
- OpenSpec strict `7/7`、source/test membership、privacy/reference/package/Core Image/fixture/secret/diff静态门与generator双次稳定SHA-256 `733bedca4c341da86c790bfdc406301e4d244d827cca0292c767a9db107ae3e6`通过；测试始终显式移除真实Keychain opt-in，前后全局`Booted=0`且未操作simulator。
- OpenSpec 4.3已勾选，预期权威进度`20/35`；下一项4.4绑定AppModel actual audio/spatial state及preference changes并在stop/failure/reconnect/replacement清理。4.3只保留AppModel显式no-op，不证明4.4/5.x或6.6物理验收。

## 2026-07-30 阶段 16 任务 4.4 启动

- 4.3已以`2bb2405 Forward spatial audio runtime state`独立提交并推送，fetch确认`HEAD == origin/main`且工作树clean；OpenSpec权威进度`20/35`，进入4.4。
- 本项新增generation-scoped preference application、AppModel未持久化desired preferences、actual audio runtime state和统一清理；AppSettings持久化/迁移、正式diagnostics与UI分别保留给5.1、5.2和5.4。
- 继续显式移除真实Keychain opt-in，不创建、启动或操作simulator；4.4离线状态接线不替代签名entitlement、AirPods head tracking、真实route transition或可听多声道验收。
- production与测试fake已完成第一版接线：environment在processor preference调用前后复核generation；AppModel启动时应用desired preference、读取environment snapshot、消费单调actual runtime event，并在stop/failure/reconnect/replacement清空actual state而保留用户意图。下一步先运行静态差异检查和4.4 focused编译测试。
- 首轮focused编译成功且environment/AppModel `31/31`用例通过，唯一失败是新diagnostic测试把既有固定安全摘要中的通用单词`session`误判为隐私泄漏；文案不含UUID、host/app、generation或原始错误。删除该过严断言，保留category/code/action和无generation检查，并从全新DerivedData重跑完整focused gate。
- 4.4首轮repository包装器在OpenSpec strict已经生成`7/7 valid`结果后，误按旧JSON schema读取`summary.valid`并立即退出；当前CLI字段为`summary.totals`。该轮未运行generator、未修改工程文件且不计验收，后续从全新证据目录按当前schema完整重跑。
- 4.4第二轮repository包装器通过strict、fixtures、generator与静态边界后，误用summary风格的`testStatus`/`identifier`读取`xcresulttool tests`明细，导致唯一skip集合被解析为空并退出；实际test node字段为`result`/`nodeIdentifier`，只读复核唯一skip是显式Keychain用例。该轮不计最终组合验收，后续用正确字段从全新证据目录完整重跑。

## 2026-07-30 阶段 16 任务 4.4 完成

- 新增generation-scoped spatial preference application与稳定`.staleAudioApplication` audio diagnostic；environment在processor异步调用前后复核session/generation，replacement期间的迟到完成不能覆盖当前generation。
- AppModel现拥有未持久化desired preference与current actual audio runtime；新generation读取snapshot并应用desired preference，stream event只接受匹配session/generation、严格递增sequence和不回退graph generation。stop、远端结束、media/control failure、reconnect和replacement均清理actual state但保留desired preference。
- 最终focused `/tmp/LuneX-16-4_4-focused-r2.VmkTPP/Focused.xcresult`为`32/32`，expanded `/tmp/LuneX-16-4_4-expanded.hAMfHp/Expanded.xcresult`为`114/114`，完整macOS `/tmp/LuneX-16-4_4-full.RGwfr7/LuneXCoreTests.xcresult`为`706 total / 705 passed / 1 explicit Keychain skip / 0 failed`；全部结构化diagnostics为0。
- macOS、iOS/iPadOS、tvOS、visionOS generic-device Debug unsigned warnings-as-errors build位于`/tmp/LuneX-16-4_4-builds.1785357260030/*/Build.xcresult`，4/4 succeeded且结构化diagnostics为0。
- 最终repository gate `/tmp/LuneX-16-4_4-repo-final.s9yPFw`通过OpenSpec strict `7/7`、fixtures、membership、reference/package/Core Image/secret/diff边界及generator双次稳定SHA-256 `733bedca4c341da86c790bfdc406301e4d244d827cca0292c767a9db107ae3e6`；唯一skip为显式真实Keychain用例，前后全局`Booted=0`且未操作simulator。
- OpenSpec 4.4已勾选，权威进度更新为`21/35`；下一项4.5补齐route/interruption、capability downgrade/recovery、preference、underrun/concealment、stale completion、stop/restart和generation replacement回归矩阵。本项不证明5.x settings/UI或6.6签名/物理可听验收。

## 2026-07-30 阶段 16 任务 4.5 启动

- 4.4已以`9e9bece Bind spatial audio application state`独立提交并推送；fetch确认`HEAD == origin/main`且工作树clean，OpenSpec权威进度`21/35`，进入4.5。
- 现有底层测试分别覆盖route-during-interruption、underrun/concealment、preference policy、late schedule completion和environment generation replacement，但缺少capability downgrade/recovery、interruption期间route+preference latest-wins、audio snapshot stop/restart及in-flight preference completion跨same-session replacement的组合回归。
- 本项只补runtime/processor/environment/AppModel恢复与replacement测试矩阵；不提前实现4.6完整7.1 application gate、5.x settings/diagnostics/UI或6.6硬件验收。测试继续显式移除真实Keychain opt-in且不操作simulator。
- 首轮focused在测试执行前被warnings-as-errors拒绝：新environment测试对本文件非throwing `waitUntil`写了多余`try`。删除该单点后使用全新DerivedData/result bundle重跑；失败bundle不计验收且没有production行为失败。

## 2026-07-30 阶段 16 任务 4.5 完成

- 新增processor capability downgrade/recovery typed状态与单调sequence/graph generation回归；新增runtime concealment+interruption+latest policy+route+late completion组合回归；新增environment悬挂preference跨stop/restart/replacement的post-await stale与snapshot隔离回归。
- focused `/tmp/LuneX-16-4_5-focused-r2.BdIcbk/Focused.xcresult`为`56/56`，expanded `/tmp/LuneX-16-4_5-expanded.SuNKjD/Expanded.xcresult`为`115/115`，完整macOS `/tmp/LuneX-16-4_5-full.xB6T2k/LuneXCoreTests.xcresult`为`709 total / 708 passed / 1 explicit Keychain skip / 0 failed`；全部结构化diagnostics为0。
- macOS、iOS/iPadOS、tvOS、visionOS generic-device Debug unsigned warnings-as-errors build位于`/tmp/LuneX-16-4_5-builds.1785357974699/*/Build.xcresult`，4/4 succeeded且结构化diagnostics为0。
- repository gate `/tmp/LuneX-16-4_5-repo.A1M8ns`通过OpenSpec strict `7/7`、fixtures、test membership、reference/package/Core Image/secret/diff边界及generator双次稳定SHA-256 `733bedca4c341da86c790bfdc406301e4d244d827cca0292c767a9db107ae3e6`；唯一skip为显式Keychain测试，前后全局`Booted=0`且未操作simulator。
- OpenSpec 4.5已勾选，权威进度更新为`22/35`；下一项4.6新增跨negotiated 7.1 PCM、environment graph、readiness、route downgrade、entitlement fallback、reconnect replacement、diagnostics与clean stop的application integration gate。本项不替代4.6或6.6硬件证据。

## 2026-07-30 阶段 16 任务 4.6 启动

- 系统更新后已恢复持久goal与planning-with-files/OpenSpec上下文；`main == origin/main == 2a9d54f`且工作树clean，macOS 27.0、Xcode 26.4、全局`Booted=0`。
- 4.6将新增一条真实native application integration gate：`AppModel -> NativeSessionMediaEnvironment -> NativeSessionAudioProcessor -> SessionAudioRuntime -> injectable AudioEngineClient`，使用合法WAVE 7.1 `5 streams / 3 coupled / identity mapping`和有效8声道interleaved PCM。
- gate覆盖三路media readiness、missing-entitlement fixed spatial、route unsupported downgrade、stable runtime diagnostic code、reconnect replacement、旧generation迟到route rejection与两代clean stop。5.2正式diagnostics store、signed entitlement、AirPods head tracking、真实route/可听声道/live Sunshine证据明确不在本项冒充完成。
- 普通测试继续显式`env -u LUNEX_RUN_KEYCHAIN_TEST`；4.6不操作simulator。
- 首轮focused编译零Swift/Clang诊断，但测试在首包readiness等待超时：production realtime jitter policy要求两个5ms packet形成10ms target delay，单包按设计不交付。失败bundle不计验收；两代输入均改为两个连续包后从全新DerivedData重跑。
- 第二轮已执行完整reconnect/stop链路，唯一失败是remote input release计数预期为2而实际为4：每代先由AppModel input-generation termination释放，再由environment resource teardown幂等释放，随后各`stopInput`一次。断言校正为两代合计4次release/2次stop后从全新目录重跑。
- 第三轮在reconnect teardown snapshot的clean断言发生竞态：provider stop计数在resource shutdown中先更新，actor的`lastTeardownReport`在operation返回后才发布；同步条件可能早一个actor重入窗口满足。测试改为明确等待`sessionID == nil && lastTeardownReport != nil`再验收clean，不更改production行为。

## 2026-07-30 阶段 16 任务 4.6 完成

- 新增一条合法WAVE 7.1 application integration gate，真实穿过AppModel、native media environment、audio processor/factory、session audio runtime与可注入engine边界；覆盖三路readiness、missing-entitlement fixed spatial、route downgrade、reconnect replacement、旧generation迟到route拒绝和两代clean stop。
- focused `/tmp/LuneX-16-4_6-focused-r4.BIVX3s/Focused.xcresult`为`1/1`，expanded `/tmp/LuneX-16-4_6-expanded.zm2GVX/Expanded.xcresult`为`116/116`，完整macOS `/tmp/LuneX-16-4_6-full.4tYlIq/LuneXCoreTests.xcresult`为`710 total / 709 passed / 1 explicit Keychain skip / 0 failed`；全部结构化diagnostics为0。
- macOS、iOS/iPadOS、tvOS、visionOS generic-device Debug unsigned warnings-as-errors build位于`/tmp/LuneX-16-4_6-builds.1785359087336/*/Build.xcresult`，4/4 succeeded且结构化diagnostics为0。
- repository gate `/tmp/LuneX-16-4_6-repo.rgF6wJ`通过OpenSpec strict `7/7`、fixtures、test membership、reference/package/Core Image/secret/privacy/diff边界及generator双次稳定SHA-256 `733bedca4c341da86c790bfdc406301e4d244d827cca0292c767a9db107ae3e6`；唯一skip为显式Keychain测试，前后全局`Booted=0`且未操作simulator。
- 首次完成落账补丁因`findings.md`现有标题为“任务 4.6 恢复调查”而不是预期的“任务 4.6 调查”被整体拒绝，文件未发生部分修改；读取精确锚点后以本次补丁完成。
- 首次commit后的推送前全文一致性扫描发现`task_plan.md`末尾阶段摘要仍为`22/35 / 当前4.6`；在任何push前修正为`23/35 / 当前5.1`，重新验证并amend同一任务提交。
- 首次amend验证包装器用`rg -c`断言零匹配，`rg`在正确的零匹配下返回1并被`set -e`提前终止；该轮未执行stage/amend。改为显式`if rg ...; then fail`后重跑。
- OpenSpec 4.6已勾选，权威进度更新为`23/35`；下一项5.1实现spatial-audio/head-tracking设置默认值、持久化、旧JSON迁移与active-stream更新。本项不替代5.2-5.4产品状态/诊断/UI或6.6签名与物理可听证据。

## 2026-07-30 阶段 16 任务 5.1 启动

- 4.6已以`77540aa Cover spatial audio application integration`独立提交并推送；fetch确认`HEAD == origin/main`且工作树clean，OpenSpec权威进度`23/35`，进入5.1。
- 本项新增向后兼容`AppSettings.audio`默认值、旧JSON缺键迁移、JSON repository round-trip，以及AppModel从持久化desired设置派生首代/reconnect preference并在active stream内更新。
- 保持现有显式Save Settings持久化语义，不提前实现5.2 diagnostics、5.3 action ownership或5.4 Settings/stream UI。普通测试继续显式移除真实Keychain opt-in，本项不操作simulator。
- 首轮focused在测试执行前被编译器拒绝：actor `loadSettings()`的`await`位于`XCTAssertEqual`同步autoclosure。production无编译错误；先await到局部`AppSettings`再断言，并从全新DerivedData重跑，失败bundle不计验收。
- 四平台Debug build均已成功形成xcresult；首次结构化读回包装器使用zsh只读变量`status`并在首个平台赋值时退出。build无需重跑，改用`result_state`从四份现有结果只读复核。
- 第二次结构化读回误用不存在的`.result`字段；Xcode 26.4 `build-results`实际为`.status`，首份结果已显示`succeeded`与零诊断，但组合断言按`null`退出。改用当前schema继续只读复核。
- 首轮repository gate的strict、fixture、generator与membership已通过，但“旧stored preference应为零匹配”使用`rg -c ... || true`，零匹配产生空字符串并使`test "" = 0`退出。该轮不计最终验收；改为显式`if rg ...; then fail`并从新证据目录完整重跑。
- 第二轮repository gate通过到secret boundary，privacy扫描却覆盖整个既有`HostAndPersistenceTests.swift`并命中历史identity/证书测试，不是本次settings新增内容。该轮不计最终验收；收紧为`AppSettings.swift`全文和当前diff新增行后完整重跑。

## 2026-07-30 阶段 16 任务 5.1 完成

- 新增`AppSettings.audio`及与runtime preference的单一转换；完全缺失或partial旧JSON逐键补`.nativeDefault`，错误类型仍fail closed。AppModel desired preference直接从settings派生，active stream更新同步修改可持久化值并应用到当前media generation。
- 最终focused `/tmp/LuneX-16-5_1-focused-final.2KOvVZ/Focused.xcresult`为`5/5`；最终完整macOS `/tmp/LuneX-16-5_1-final.1785360178629/full/LuneXCoreTests.xcresult`为`713 total / 712 passed / 1 explicit Keychain skip / 0 failed`；全部结构化diagnostics为0。
- macOS、iOS/iPadOS、tvOS、visionOS generic-device Debug unsigned warnings-as-errors最终build位于`/tmp/LuneX-16-5_1-final.1785360178629/{macOS,iOS,tvOS,visionOS}/Build.xcresult`，4/4 succeeded且结构化diagnostics为0。
- repository gate `/tmp/LuneX-16-5_1-repo-final-r2.Qm9CQl`通过OpenSpec strict `7/7`、fixtures、membership、settings migration scope、reference/package/Core Image/secret/privacy/diff边界及generator双次稳定SHA-256 `733bedca4c341da86c790bfdc406301e4d244d827cca0292c767a9db107ae3e6`；唯一skip为显式Keychain测试，前后全局`Booted=0`且未操作simulator。
- OpenSpec 5.1已勾选，权威进度更新为`24/35`；下一项5.2替换free-form spatial diagnostics为稳定privacy-bounded active/fixed/head-tracked/visionOS/fallback/entitlement/route-layout/recovery/graph-failure状态。本项不替代5.2-5.5产品诊断/UI或6.6硬件证据。

## 2026-07-30 阶段 16 任务 5.2 启动

- 系统更新后的恢复门通过：`main == origin/main == eb16c80`、工作树clean、Xcode 26.4、26.4平台SDK齐全、全局`Booted=0`；OpenSpec `integrate-spatial-audio-runtime`为`spec-driven / 24 of 35 / ready`。
- 当前任务以typed `SpatialAudioDiagnosticState`替换旧free-form spatial diagnostics，并把AppModel current-generation actual runtime接入固定诊断；稳定code/summary/severity/action和privacy-bounded payload必须由确定性测试锁定。
- 5.2不提前完成5.3的跨类别action去重/恢复清理，不操作simulator，不触发真实Keychain；物理route、signed entitlement、AirPods、可听声道与live Sunshine证据继续保留未完成。
- 第一版删除`DiagnosticsStore.record(spatialAudioState:)`自由文本入口，新增封闭runtime到diagnostic state映射、固定factory payload与AppModel current-generation接线；stale generation不发布，真实clear保留历史并发布inactive。
- 首轮focused的21项测试和xcresult均通过，但zsh包装器读取`PIPESTATUS[0]`为空，不作为最终组合证据。随后收紧语义，避免把一般packet recovery或processor failure误报为空间图恢复/失败，并用显式Bash与全新目录重跑。
- 最终focused `/tmp/LuneX-16-5_2-focused-final.ho4eUn/Focused.xcresult`明确`EXIT=0`且`21/21 passed / 0 skipped / 0 failed`；下一步运行扩大runtime/application回归。

## 2026-07-30 阶段 16 任务 5.2 完成

- typed spatial diagnostic state/factory、旧free-form API删除与AppModel current-generation发布已完成；stale generation不发布，stop/reconnect/replacement记录inactive但不删除bounded历史。5.3的current action去重与跨类别recovery clearing没有提前实现。
- focused `/tmp/LuneX-16-5_2-focused-final.ho4eUn/Focused.xcresult`为`21/21`，expanded `/tmp/LuneX-16-5_2-expanded.ADG2gj/Expanded.xcresult`为`136/136`，完整macOS `/tmp/LuneX-16-5_2-full.cyD4Kp/LuneXCoreTests.xcresult`为`714 total / 713 passed / 1 explicit Keychain skip / 0 failed`；唯一skip精确为`HostAndPersistenceTests/testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`。
- macOS、iOS/iPadOS、tvOS、visionOS generic-device Debug build `/tmp/LuneX-16-5_2-builds.1785361191751/*/Build.xcresult`为4/4 succeeded；所有test/build结构化errors、warnings、analyzer warnings均为0。
- repository gate `/tmp/LuneX-16-5_2-repo.2o6msb`通过OpenSpec strict `7/7`、fixture、generator、membership、legacy API absence、privacy、secret、reference与diff边界；generator SHA-256保持`733bedca4c341da86c790bfdc406301e4d244d827cca0292c767a9db107ae3e6`，前后全局`Booted=0`且未操作simulator。
- OpenSpec 5.2已勾选，权威进度更新为`25/35`；下一项5.3处理current audio action去重与精准recovery clearing，普通测试继续移除真实Keychain opt-in。

## 2026-07-30 阶段 16 任务 5.3 启动

- 5.2已以`bcce83f Add stable spatial audio diagnostics`提交并推送，fetch确认`HEAD == origin/main`且工作树clean；OpenSpec为`25/35 ready`，当前任务5.3。
- 本项在store层分离bounded history与current action ownership：等价action仍进入历史但不刷新current owner；AppModel健康空间状态只清理`.audio`。
- 回归将同时持有pairing、transport、decoder、HDR、audio与input current actions，验证空间恢复只移除audio，其他五类current owner与全部历史保持不变。本项不操作simulator、不触发真实Keychain。
- focused `/tmp/LuneX-16-5_3-focused.O2HD8t/Focused.xcresult`已结构化确认`23/23 passed / 0 skipped / 0 failed`，error/warning/analyzer warning均为0。首轮外层zsh包装器在测试成功后误读Bash专用`PIPESTATUS[0]`并以1退出，不是产品或测试失败；其余管线固定为显式`/bin/bash`。
- expanded `/tmp/LuneX-16-5_3-expanded.kzcDJU/Expanded.xcresult`已结构化确认`138/138 passed / 0 skipped / 0 failed`，error/warning/analyzer warning均为0；diagnostics、AppModel、audio processor、media environment、runtime state与recovery回归均通过。
- full macOS `/tmp/LuneX-16-5_3-full.NbKZws/LuneXCoreTests.xcresult`已结构化确认`716 total / 715 passed / 1 skipped / 0 failed`，唯一skip精确为`HostAndPersistenceTests/testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`；error/warning/analyzer warning均为0。
- macOS、iOS/iPadOS、tvOS、visionOS generic-device Debug unsigned warnings-as-errors build位于`/tmp/LuneX-16-5_3-builds.TpwXAFYpDMUF/*/Build.xcresult`，4/4 succeeded且四份结构化error/warning/analyzer warning均为0；未使用simulator destination。

## 2026-07-30 阶段 16 任务 5.3 完成

- `DiagnosticsStore`现保留每次等价action的bounded history，但不刷新同category current owner/date；AppModel接受当前generation健康空间状态后只清理`.audio`，pairing、transport、decoder、HDR与input current owner及全部历史保持不变。
- focused `/tmp/LuneX-16-5_3-focused.O2HD8t/Focused.xcresult`为`23/23`，expanded `/tmp/LuneX-16-5_3-expanded.kzcDJU/Expanded.xcresult`为`138/138`，完整macOS `/tmp/LuneX-16-5_3-full.NbKZws/LuneXCoreTests.xcresult`为`716 total / 715 passed / 1 explicit Keychain skip / 0 failed`；所有结构化diagnostics为0。
- 四平台generic-device Debug build `/tmp/LuneX-16-5_3-builds.TpwXAFYpDMUF/*/Build.xcresult`为4/4 succeeded；repository gate `/tmp/LuneX-16-5_3-repo.uVLOZx`通过strict `7/7`、fixtures、membership/ownership/privacy/secret/reference/package/Core Image/diff边界及generator双次稳定SHA-256 `733bedca4c341da86c790bfdc406301e4d244d827cca0292c767a9db107ae3e6`。
- OpenSpec 5.3已勾选，权威进度更新为`26/35`；下一项5.4以actual runtime替换静态stream spatial pill，并加入原生spatial/head-tracking Settings controls及inactive/fallback状态。前后全局`Booted=0`，未操作simulator，也未触发真实Keychain。

## 2026-07-30 阶段 16 任务 5.4 启动

- 5.3已以`78972fa Scope spatial audio action recovery`独立提交并推送，fetch确认`HEAD == origin/main`且工作树clean；OpenSpec为`26/35 ready`，进入5.4。
- 本项新增actual-runtime-derived空间音频presentation status/content，以同一状态驱动stream pill和Settings当前播放行；原生spatial/head-tracking Toggle通过现有async AppModel入口应用到活动generation，不能直接改settings绕过runtime。
- 5.4补状态映射与基本UI接线回归；5.5保留responsive compact/wide、localization-safe copy、完整accessibility、preference migration、diagnostic ownership与actual-state UI矩阵。普通测试继续移除真实Keychain opt-in，本项不操作simulator。
- 第一版已新增closed presentation mode/fallback/content映射、AppModel actual状态派生、overlay实际pill、Settings原生Toggle与当前播放行；Toggle通过自定义Binding调用async runtime入口，失败收敛为既有typed diagnostic。测试覆盖inactive/nonspatial/fixed/head-tracked/vision/recovery/failure、fallback保留actual mode、privacy copy与静态UI接线。
- 首轮focused `/tmp/LuneX-16-5_4-focused.m6j5Ot/Focused.xcresult`在测试执行前因无类型`nil`同时匹配runtime-state与runtime-event两个Optional initializer而编译失败；production源码无诊断。nil fixture改为明确`SessionMediaAudioRuntimeState?.none`，该bundle不计验收并从全新目录重跑。
- 修正后的focused `/tmp/LuneX-16-5_4-focused-r2.OhQjwn/Focused.xcresult`通过`9/9`：4个空间音频presentation/UI接线测试、4个HDR相邻presentation测试及1个AppModel实际空间音频状态绑定测试全部通过；命令显式移除`LUNEX_RUN_KEYCHAIN_TEST`并使用全新DerivedData，未操作simulator。
- 扩大回归`/tmp/LuneX-16-5_4-expanded.Z1D2el/Expanded.xcresult`通过`146/146`，覆盖presentation、runtime diagnostics、AppModel workflow、native audio processor、media environment、spatial resolver和audio recovery；focused与expanded两份xcresult的结构化error、warning和analyzer warning均为0，检查时全局`Booted=0`。

## 2026-07-30 阶段 16 任务 5.4 完成

- actual-runtime presentation status、stream overlay、Settings原生spatial/head-tracking Toggle与当前播放状态行已完成；静态`Spatial gated`已删除，fallback保留实际播放模式，Toggle通过async AppModel入口更新当前generation。
- focused为`9/9`，expanded为`146/146`，完整macOS为`720 total / 719 passed / 1 explicit Keychain skip / 0 failed`；唯一skip精确为`HostAndPersistenceTests/testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，三份测试xcresult的结构化diagnostics均为0。
- 四平台generic-device Debug unsigned warnings-as-errors build `/tmp/LuneX-16-5_4-builds.JIxcKyvQdoBh/*/Build.xcresult`为4/4 succeeded且结构化diagnostics为0；repository gate `/tmp/LuneX-16-5_4-repo.Uk74JV`通过strict `7/7`、fixtures、generator、membership、UI wiring、privacy/secret/reference/package/Core Image/diff与模拟器不变边界。
- OpenSpec 5.4已勾选，权威进度更新为`27/35`；下一项5.5负责完整responsive compact/wide、localization-safe copy、accessibility、migration、diagnostic ownership与actual-state UI wiring测试。全程未触发真实Keychain，前后`Booted=0`且未操作simulator。

## 2026-07-30 阶段 16 任务 5.5 启动

- 5.4已以`7221c10 Present actual spatial audio state`提交并推送，fetch确认`HEAD == origin/main`且工作树clean；OpenSpec为`27/35 ready`，当前任务5.5。
- 已核对Apple SwiftUI当前文档：stored `String`不会自动本地化，`LocalizedStringResource`可直接用于`Label`；`ViewThatFits`用于按可用空间选择布局，size class与accessibility Dynamic Type可作为明确compact条件。
- 实现将把空间presentation copy改为本地化resource，以resource组合显式accessibility value；Settings新增compact/accessibility单列和wide双列+fit fallback。回归将锁定布局决策、本地化资源、accessibility、已有JSON migration、diagnostic ownership及desired preference不伪造actual state。
- 首轮focused的8项测试和xcresult均通过且结构化diagnostics为0，但zsh包装器在`TEST SUCCEEDED`后读取不存在的`PIPESTATUS[0]`而退出1；该bundle不计最终组合证据，改用显式`/bin/bash`与全新DerivedData/result bundle重跑。
- 最终focused `/tmp/LuneX-16-5_5-focused-final.WvMx9M/Focused.xcresult`为`8/8`；expanded `/tmp/LuneX-16-5_5-expanded.MXyeC7/Expanded.xcresult`为`153 total / 152 passed / 1 explicit Keychain skip / 0 failed`。两份结构化diagnostics均为0，普通测试均显式移除`LUNEX_RUN_KEYCHAIN_TEST`，全局`Booted=0`。
- 完整macOS `/tmp/LuneX-16-5_5-full.wno5fl/LuneXCoreTests.xcresult`为`721 total / 720 passed / 1 explicit Keychain skip / 0 failed`；唯一skip精确为`HostAndPersistenceTests/testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，结构化error/warning/analyzer warning均为0。
- 首轮四平台build在macOS universal x86_64批次被warnings-as-errors拒绝：macOS 26弃用`Text + Text`；arm64此前通过但该跨平台轮不计验收。accessibility value改为一个本地化格式中的两个resource-backed `Text`插值，允许翻译重排并保持无动态`String`拼接，随后从全新证据目录复验。

## 2026-07-30 阶段 16 任务 5.5 完成

- 修复后的focused `/tmp/LuneX-16-5_5-focused-interpolation.PaelqZ/Focused.xcresult`结构化读回为`8/8 passed / 0 skipped / 0 failed`；四平台最终build `/tmp/LuneX-16-5_5-builds-final.WD1MzP/{macOS,iOS,tvOS,visionOS}/Build.xcresult`全部`succeeded`且error/warning/analyzer warning均为0。
- macOS更新完成后使用全新DerivedData复验：expanded `/tmp/LuneX-16-5_5-expanded-post-update.4tXrcu/Expanded.xcresult`为`153 total / 152 passed / 1 skipped / 0 failed`；完整suite `/tmp/LuneX-16-5_5-full-post-update.QxPwgF/LuneXCoreTests.xcresult`为`721 total / 720 passed / 1 skipped / 0 failed`。两份build-results均为0 diagnostics。
- 唯一skip精确为`HostAndPersistenceTests/testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`；所有普通测试显式移除`LUNEX_RUN_KEYCHAIN_TEST`并继续使用Debug文件fallback，没有再次授权或访问真实Keychain。
- repository pre-gate `/tmp/LuneX-16-5_5-repo-pre.UJvBhh`与勾选后final gate `/tmp/LuneX-16-5_5-repo-final.m6xKRr`均通过OpenSpec strict `7/7`、fixture self-test/全树、source/test membership、responsive/localization/accessibility/actual-state UI wiring、settings migration、diagnostic ownership、privacy/secret/reference/package/Core Image/diff边界，以及generator连续两次稳定SHA-256 `e2032fc8188e7e194396531f72c57f836d7a04029ad85fb783296ab71b8ac242`；final apply为`28/35`且6.1仍pending。
- 前后simulator inventory完全一致且全局`Booted=0`；本任务未创建、启动、安装、运行、关闭或删除任何simulator。OpenSpec 5.5已勾选，权威进度更新为`28/35`，下一项6.1重新运行normal tests并验证live-host/真实Keychain路径关闭和唯一允许skip。

## 2026-07-30 阶段 16 任务 6.1 启动

- 5.5已以`7bc3814 Verify responsive spatial audio UI`独立提交并推送；fetch确认`HEAD == origin/main`且工作树clean，OpenSpec为`28/35 ready`，当前任务6.1。
- 测试源码静态审计确认唯一环境opt-in为`LUNEX_RUN_KEYCHAIN_TEST`，没有live-host XCTest或相应环境入口。normal suite将显式移除Keychain opt-in，从全新DerivedData运行，并精确断言唯一skip。
- 本项不访问真实Keychain、不发起live-host连接、不操作simulator；缺失的live-host XCTest、授权Sunshine互操作和物理音频行为继续保持未完成。

## 2026-07-30 阶段 16 任务 6.1 完成

- normal suite `/tmp/LuneX-16-6_1-normal.430OTY/Normal.xcresult`从已推送clean `7bc3814`和全新DerivedData运行，结构化结果为`721 total / 720 passed / 1 skipped / 0 failed / 0 expected failures`，build error/warning/analyzer warning均为0。
- 唯一skip精确为`HostAndPersistenceTests/testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`；测试命令显式移除`LUNEX_RUN_KEYCHAIN_TEST`，ambient opt-in为空。
- Tests/Sources只有一个环境读取文件和一个`LUNEX_RUN_*` token，均属于一次性真实Keychain用例；live-host XCTest/环境入口不存在，因此normal suite没有隐藏host副作用，但不替代阶段13 9.2缺失实现。
- 首个结构化包装器因macOS Bash 3.2没有`mapfile`而在只读验收阶段退出；suite无需重跑，POSIX兼容包装器从同一bundle完成全部断言。前后simulator inventory一致且`Booted=0`。
- repository final gate `/tmp/LuneX-16-6_1-repo-final.zd8HeZ`通过OpenSpec strict `7/7`、apply `29/35`、normal xcresult复核、fixture self-test/全树、environment opt-in边界、generator双次稳定SHA-256 `e2032fc8188e7e194396531f72c57f836d7a04029ad85fb783296ab71b8ac242`和simulator不变门。
- OpenSpec 6.1已勾选，权威进度更新为`29/35`；下一项6.2运行macOS Debug/Release和固定iPhone、iPad、tvOS、visionOS warnings-as-errors隔离构建。

## 2026-07-30 阶段 16 任务 6.2 启动

- 6.1已以`394601c Verify normal spatial audio tests`独立提交并推送；fetch确认`HEAD == origin/main`且工作树clean，OpenSpec为`29/35 ready`，当前任务6.2。
- 固定26.4 simulator UUID为iPhone `23A27088-C19F-4F77-A455-4E50E393167E`、iPad `409A5908-8C39-4797-A41C-04503A05FA3D`、Apple TV `11D0B224-D778-4A13-A156-272A45AFF119`、Vision Pro `9BF41D0C-B423-4B3F-B75D-00B31E85FE18`；四者唯一、available、`Shutdown`且全局`Booted=0`。
- 将顺序运行macOS和四个固定destination各Debug/Release共10个隔离warnings-as-errors build，设置`LM_SKIP_METADATA_EXTRACTION=YES`并验证每份xcresult零诊断、每配置Metal AIR/metallib存在；不执行任何simulator lifecycle操作。

## 2026-07-30 阶段 16 任务 6.2 完成

- 证据目录`/tmp/LuneX-16-6_2-builds.BW59PU`包含macOS、固定iPhone、固定iPad、tvOS与visionOS的Debug/Release共10个隔离DerivedData/result bundle。全部build为`succeeded`，structured error/warning/analyzer warning为0，每个配置各生成一个Metal AIR与metallib。
- 构建命令显式移除`LUNEX_RUN_KEYCHAIN_TEST`、禁用签名、启用Swift/Clang/Metal warnings-as-errors并设置`LM_SKIP_METADATA_EXTRACTION=YES`；未运行测试或再次访问真实Keychain。
- simulator规范化before/after清单逐字一致，SHA-256均为`5d39940efaf4b37d2592952a96973621dda435f7a92cf2d43d911ea5df48140a`；原始JSON差异仅为三个26.4 runtime的`lastUsage.arm64`时间。固定四实例仍唯一、available、`Shutdown`且全局`Booted=0`，未执行任何设备生命周期命令。
- repository final gate `/tmp/LuneX-16-6_2-repo-final-r3.dInpIv`通过OpenSpec strict `7/7`、apply `30/35`、generator双次稳定SHA-256 `e2032fc8188e7e194396531f72c57f836d7a04029ad85fb783296ab71b8ac242`、simulator不变、产品源码零diff与真实Keychain opt-in零新增门。
- OpenSpec 6.2已勾选，权威进度更新为`30/35`；下一项6.3为OpenSpec strict、generator stability、clean-room/dependency、direct SDK API probes、static analyzer及repository-boundary gates。6.5独立simulator验收和6.6真机硬件验收保持未完成。

## 2026-07-30 阶段 16 任务 6.3 启动

- 6.2已以`d7e0d4b Verify spatial audio platform builds`独立提交并推送；fetch确认`HEAD == origin/main`且起始工作树clean，OpenSpec为`30/35 ready`，当前任务6.3。
- 将从当前提交重新运行fixture/OpenSpec/generator、clean-room/reference/package/entitlement/dependency边界、四SDK ENet/bridge严格C编译、四平台空间音频public API正向与预期失败probe，以及macOS Debug/Release analyzer。
- 本项不运行真实Keychain、ASan、TSan、malloc/resource gate或simulator lifecycle操作；6.4与6.5保持独立验收，6.6 signed entitlement和物理听感仍未完成。

## 2026-07-30 阶段 16 任务 6.3 完成

- repository/API gate `/tmp/LuneX-16-6_3-repository-r2.L5luEV`通过fixture self-test/全树、OpenSpec strict `7/7`、apply `30/35`、generator四次稳定SHA-256 `e2032fc8188e7e194396531f72c57f836d7a04029ad85fb783296ab71b8ac242`、clean-room/reference/package/dependency/entitlement/private-symbol/whitespace边界。
- macOS/iOS/tvOS/visionOS四SDK严格C门均覆盖固定8个ENet source和自有bridge并通过；四平台public spatial API正向probe通过，visionOS listener与三移动平台`SecTask`预期失败probe精确符合SDK availability。
- Debug/Release analyzer `/tmp/LuneX-16-6_3-analyzer.HjnMkl`均成功，xcresult为0 error、0 compiler warning、4 analyzer warning；结构化plist确认自有bridge为0 finding，固定ENet四项在两配置逐字段一致。
- analyzer最终比较首次因expected TSV在含单引号description后写入字面量反斜杠`t`而退出；两次analyzer无需重跑，从同一xcresult/plist以字段化expected复核8项精确相等。
- repository final gate `/tmp/LuneX-16-6_3-repo-final.tSc9IJ`通过OpenSpec strict `7/7`、apply `31/35`、generator稳定、fixture、四SDK C/API和analyzer证据读回、产品源码零diff与真实Keychain opt-in零新增门。
- OpenSpec 6.3已勾选，权威进度更新为`31/35`；下一项6.4运行ASan、TSan、malloc scribble/guard、resource ownership、graph replacement、observer cancellation和scheduled-buffer release gates。

## 2026-07-30 阶段 16 任务 6.4 启动

- 6.3已以`ab82fcb Run spatial audio quality gates`独立提交并推送；fetch确认`HEAD == origin/main`且起始工作树clean，OpenSpec为`31/35 ready`，当前任务6.4。
- 将从当前提交分别用全新DerivedData/result bundle运行完整ASan与TSan；malloc强化门关闭coverage并选择11个空间音频graph/scheduling/observer/processor/media/AppModel相关suite。
- 所有命令继续显式移除`LUNEX_RUN_KEYCHAIN_TEST`，不再次访问真实Keychain；本项只使用macOS test destination，不执行任何simulator生命周期操作。
- 首轮完整ASan使用裸`ENABLE_ADDRESS_SANITIZER=YES`后，XCTest在运行任何case前于sanitizer interceptor bootstrap阶段abort；该bundle不计产品验收。对照阶段15成功命令后改用`-enableAddressSanitizer YES`、显式`ASAN_OPTIONS`和全新DerivedData，最小启动探针`/tmp/LuneX-16-6_4-asan-probe.vIYl4j`已通过`16/16`且零诊断/零sanitizer report，随后按相同口径运行完整suite。
- 完整ASan最终证据`/tmp/LuneX-16-6_4-asan-final.PQ8zJN`通过`721 total / 720 passed / 1 explicit Keychain skip / 0 failed`，唯一skip精确、结构化诊断为0，日志无AddressSanitizer/LeakSanitizer报告；接着从全新DerivedData运行完整TSan。

## 2026-07-30 阶段 16 任务 6.4 完成

- 完整TSan最终证据`/tmp/LuneX-16-6_4-tsan-final.or1COq`通过`721 total / 720 passed / 1 explicit Keychain skip / 0 failed`，唯一skip精确、结构化诊断为0且日志无ThreadSanitizer report。
- 11类malloc/resource集合`/tmp/LuneX-16-6_4-resource-final.v7bmDv`在关闭coverage、开启scribble/pre-scribble/guard edges/stack logging/逐分配heap check/error-abort后通过`185/185`，实际suite清单精确匹配且无skip、无allocator report、无结构化诊断。
- 最终只读组合门再次从三份xcresult/log验证ASan与TSan各`721/720/1/0`、resource `185/185`、唯一Keychain skip、零诊断和零sanitizer/malloc report；实际case覆盖graph replacement、observer cancellation、scheduled-buffer release/late completion、processor/media/AppModel replacement与clean stop。
- OpenSpec 6.4已勾选，权威进度更新为`32/35`；下一项6.5仅从当前环境只读验收固定simulator identity/state，不创建、克隆、启动、安装、运行、关闭或删除设备。6.6 signed entitlement和物理音频硬件验收保持未完成。
- repository final gate `/tmp/LuneX-16-6_4-repo-final.7VDx6H`通过fixture self-test/全树、OpenSpec strict `7/7`、apply `32/35`、generator双次稳定SHA-256 `e2032fc8188e7e194396531f72c57f836d7a04029ad85fb783296ab71b8ac242`、ASan/TSan/resource证据读回、Keychain opt-in关闭、产品源码/测试/工程零diff及无残留测试进程门。
- generator不支持`--help`且会忽略参数直接生成工程；调查调用生成结果与当前工程字节一致。正式门改为明确运行并比较生成前与连续两次哈希，不依赖帮助模式。

## 2026-07-30 阶段 16 任务 6.5 启动

- 6.4已以`44aa494 Verify spatial audio memory safety`独立提交并推送；确认`HEAD == origin/main`且工作树clean，OpenSpec为`32/35 ready`，当前任务6.5。
- 本项只执行`simctl list devices available -j`并结构化读取当前清单，与6.2 before/after规范化快照比较；不执行build/test或任何simulator生命周期命令。

## 2026-07-30 阶段 16 任务 6.5 完成

- 独立只读证据`/tmp/LuneX-16-6_5-simulator-audit.ILGwlv`证明6.2 before/after与当前三份规范化清单逐字一致，SHA-256均为`5d39940efaf4b37d2592952a96973621dda435f7a92cf2d43d911ea5df48140a`。
- 当前51个available simulator中，固定四个26.4 runtime/name/UUID组合和UUID均各自唯一、available、`Shutdown`，全局`Booted=0`。只执行一次只读list及文件比较，没有create、clone、boot、bootstatus、install、launch、run、shutdown、delete、build或test。
- 固定identity首轮jq因`all()`作用域错误退出；不重复设备查询，对同一已保存JSON修正变量绑定后通过全部断言。
- OpenSpec 6.5已勾选，权威进度更新为`33/35`；6.6 signed entitlement和物理音频硬件验收保持pending，下一可执行项6.7同步跟踪、硬件说明和proof boundary并执行阶段级离线自验。
- repository final gate `/tmp/LuneX-16-6_5-repo-final.oyRbHE`通过OpenSpec strict `7/7`、apply `33/35`、三份simulator快照/固定identity/Booted=0读回、Keychain opt-in关闭、产品源码/测试/工程零diff及无残留测试进程门。

## 2026-07-30 阶段 16 任务 6.7 启动

- 6.5已以`ace5275 Verify spatial audio simulator inventory`独立提交并推送；确认`HEAD == origin/main`且工作树clean，OpenSpec为`33/35 ready`。
- 6.7将新增production空间音频合同并同步runtime roadmap、entitlement/signed provisioning与6.6硬件验收说明、离线/模拟器/物理证明边界；完成后运行阶段16级fresh normal、strict、generator和已保存simulator证据自验。
- 6.6继续保持pending；没有授权物理设备、签名profile、AirPods、built-in/wired/HDMI和live Sunshine证据时，不archive change、不把阶段16标为complete。
- 已新增空间音频合同并把runtime roadmap从过期`17/35`更新为当前`33/35`及明确6.6物理边界；产品源码、测试、Configuration、Tools和工程文件均未修改。
- 阶段级fresh normal `/tmp/LuneX-16-stage-acceptance.SuOHsB`通过`721 total / 720 passed / 1 explicit Keychain skip / 0 failed`，唯一skip精确、结构化diagnostics为0且真实Keychain opt-in关闭。

## 2026-07-30 阶段 16 任务 6.7 完成

- 阶段级组合门`/tmp/LuneX-16-stage-gate.IC7uoV`通过fixture、OpenSpec strict `7/7`、apply `33/35`、generator双次稳定哈希、fresh normal `721/720/1/0`、ASan/TSan各`721/720/1/0`、resource `185/185`及固定simulator `Shutdown/Booted=0`读回。
- `docs/runtime/spatial-audio-contract.md`现统一production graph/ownership、canonical channel layout、四平台route/API、signed entitlement、recovery/generation、actual UI/diagnostics、离线证据和6.6硬件矩阵；runtime roadmap同步为`34/35 in_progress`。
- OpenSpec 6.7已勾选，权威进度为`34/35`。6.6保持唯一pending，change不archive、阶段不标记complete；后续可推进阶段17，但不能用移动/模拟器/离线证据回填空间音频物理验收。
- repository final gate `/tmp/LuneX-16-6_7-repo-final.SxZAWt`通过fixture、OpenSpec strict `7/7`、apply `34/35`、generator稳定、stage normal `721/720/1/0`读回、合同/proof boundary、6.6唯一pending、Keychain opt-in关闭及产品源码/测试/配置/工具/工程零diff门。

## 2026-07-30 阶段 17 OpenSpec 恢复与产物起草

- macOS更新后恢复active goal；确认仓库在`main`，`HEAD == origin/main == 7ec593a`，起始dirty仅为阶段17 proposal和调查记录，没有产品源码、测试或工程配置修改。
- 运行planning-with-files session catch-up并核对交接、Git、OpenSpec与三份持久文件；未发现未同步的额外实现。
- 读取当前UIKit lifecycle、mobile Metal surface、EDR reader、decoded frame、AppModel/media ownership、generator和阶段16 OpenSpec样式；本机Xcode 26.4 SDK确认actual view/window、scene notifications、mobile EDR与sample-buffer PiP public API边界。
- 起草`integrate-mobile-scene-pip-continuity`三个capability specs、cross-module design和36项tasks；下一步执行OpenSpec strict、artifact status、generator稳定性和diff边界，自验通过后独立commit/push，再进入apply 1.1。
- 首轮artifact status已为4/4 done，但strict发现4个requirement把`SHALL`换行到描述第二行，validator只检查首行而拒绝；该轮不计验收，生成器哈希仍稳定且没有产品源码漂移。已把四个首行改为显式规范词，准备从新证据目录完整复验。
- 最终规划产物门`/tmp/LuneX-17-openspec-final.FWT2cM`通过4/4 artifacts done、OpenSpec strict `1/1`、apply `0/36`、三个spec目录、生成器连续两次稳定SHA-256 `e2032fc8188e7e194396531f72c57f836d7a04029ad85fb783296ab71b8ac242`、`git diff --check`与产品源码/测试/配置/工具/工程零diff边界。下一步独立提交推送artifact后直接进入1.1。

## 2026-07-30 阶段 17 任务 1.1 调查

- 规划提交`44a6ab5 Specify mobile scene and PiP continuity`已推送，`HEAD == origin/main`且起始工作树clean；OpenSpec为`0/36 ready`，当前任务1.1只做inventory/API/proof boundary，不改变runtime。
- 盘点UIKit surface、coordinate/input、decoded presentation、mobile audio session、media environment、AppModel/UI、generator、既有HDR合同和roadmap，确认可复用所有权与实际缺口。
- 首轮strict API probe因Swift 6 conformance isolation和iOS18弃用的display-layer直接queue API失败，不计验收；改用显式`@MainActor` isolated conformance与`AVSampleBufferVideoRenderer`后，最终probe `/tmp/LuneX-17-1_1-api.IsXyyw`在iOS26 simulator SDK、warnings-as-errors下零诊断通过，且未操作simulator。
- 新增`docs/runtime/mobile-scene-pip-continuity-contract.md`，固定现状矩阵、generator配置、Xcode 26.4 API、target ownership、geometry/input、PiP/background policy、确定性/固定simulator/物理验收边界；roadmap阶段17更新为in_progress。

## 2026-07-30 阶段 17 任务 1.1 完成

- 预验收`/tmp/LuneX-17-1_1-pre.NxDp6S`通过OpenSpec strict `1/1`、apply `0/36`起始状态、最终API probe零诊断读回、合同关键边界、generator稳定SHA-256 `e2032fc8188e7e194396531f72c57f836d7a04029ad85fb783296ab71b8ac242`和产品源码/测试/配置/工具/工程零diff。
- 1.1已勾选，权威进度更新为`1/36`。本项只新增stage17 runtime合同并同步跟踪，没有修改runtime、测试、配置、generator或工程；不证明system PiP、background duration、Stage Manager、external display、mobile EDR物理输出或live Sunshine。
- 勾选后final gate `/tmp/LuneX-17-1_1-final.XgU7D7`通过strict `1/1`、apply `1/36`且next精确为1.2、API probe读回、generator稳定、唯一untracked为权威合同及产品源码/测试/配置/工具/工程零diff边界。

## 2026-07-30 阶段 17 任务 1.2 启动

- 1.1已以`12217f8 Inventory mobile continuity runtime`提交并推送，确认`HEAD == origin/main`且起始工作树clean；OpenSpec为`1/36 ready`，当前任务1.2。
- 新增平台无关`MobileSceneWindowState`值合同、checked publisher和focused tests；raw invalid sample发布closed unavailable state，等价语义去重，revision overflow清空snapshot并永久fail closed。
- 首个跨文件补丁因generator测试列表锚点错误整体拒绝且没有部分落盘；读取真实列表后已精确加入product/test-support/test membership。
- focused `/tmp/LuneX-17-1_2-focused.QKl5av/Focused.xcresult`通过`10/10`且测试日志无skip；首轮结构化包装器误把当前summary的空`statistics`数组当旧对象，在expanded启动前退出。focused不重跑，改按顶层计数和build-results count字段复核后再运行expanded。
- expanded `/tmp/LuneX-17-1_2-expanded.g6gGdq/Expanded.xcresult`结构化通过`45/45`且零诊断；完整macOS `/tmp/LuneX-17-1_2-full.jJvCLB/Full.xcresult`通过`731 total / 730 passed / 1 explicit Keychain skip / 0 failed`且零诊断。
- 四目标首轮Debug generic builds `/tmp/LuneX-17-1_2-builds.eQfqRS`均成功；最终代码审阅随后收紧rect终点bounded validation并补回归，因此上述测试/build只保留为调查证据，不作为最终exact-source验收，使用全新目录重跑focused/full/build门。

## 2026-07-30 阶段 17 任务 1.2 完成

- final focused `/tmp/LuneX-17-1_2-focused-final.rszp6V/Focused.xcresult`结构化通过`10/10`；完整macOS `/tmp/LuneX-17-1_2-full-final.ZAkxIp/Full.xcresult`通过`731 total / 730 passed / 1 explicit Keychain skip / 0 failed`。两份build-results均为零error/warning/analyzer warning。
- 唯一skip结构化精确为`HostAndPersistenceTests/testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`；所有测试显式移除`LUNEX_RUN_KEYCHAIN_TEST`，未再次访问真实Keychain。
- final四目标Debug generic builds `/tmp/LuneX-17-1_2-builds-final.D8zUzY`的macOS、iOS/iPadOS、tvOS、visionOS均succeeded且结构化诊断为0；read-only simulator evidence `/tmp/LuneX-17-1_2-simulator.Dh14B0`确认固定iPhone/iPad各唯一且`Booted=0`，未执行任何simulator生命周期命令。
- repository pre-gate `/tmp/LuneX-17-1_2-repo-pre.GhjEqI`通过OpenSpec strict `1/1`、apply `1/36`、generator连续稳定SHA-256 `2685f46d6032985088f50f32148cec137d18863d858149ea3511d98e062e38f5`、product/test membership、finite/privacy边界与diff检查。
- 1.2已勾选，权威进度更新为`2/36`。本项只提供值合同，actual UIKit view/window/scene、PiP controller、background continuity和mobile EDR runtime仍未接线。
- 勾选后repository final gate `/tmp/LuneX-17-1_2-repo-final.NSPpto`通过strict `1/1`、apply `2/36`且next精确为1.3、final focused/full/build/simulator证据读回、generator稳定、membership、合同、privacy和diff边界。
- macOS更新结束后从交接点恢复，确认Xcode仍为`26.4 (17E192)`；fresh focused evidence `/tmp/LuneX-17-1_2-post-update-focused.NbSCKe`在macOS 27.0通过`10/10`、零skip，xcresult为`succeeded`且结构化error/warning/analyzer warning均为0。命令行设备枚举提示未进入结构化构建诊断；未访问Keychain或操作simulator。

## 2026-07-30 阶段 17 任务 1.3 启动

- 1.2已以`c486c20 Define mobile scene window state`提交并推送，确认`HEAD == origin/main`且起始工作树clean；OpenSpec为`2/36 ready`，当前任务1.3。
- 新增平台无关PiP generation/capability/lifecycle/failure/frame-sink/restoration snapshot、effectful deterministic reducer和actual-state continuity-path resolver/reducer；native active只能来自`didStart`，request/configuration不能伪造active。
- frame sink snapshot只允许nonzero decoder generation且pending frame容量最多1；restoration使用current PiP generation和checked ordinal lease，completion effect只由匹配的pending lease产生，invalidate会fail closed完成pending lease并flush/release sink。
- 首轮focused `/tmp/LuneX-17-1_3-focused.DIFdOM`在编译期失败：实例转移调用的`replacing` helper误声明为`static`，9处调用被Swift 6.3拒绝；测试未启动。已改为实例私有helper，后续使用全新证据目录重跑。

## 2026-07-30 阶段 17 任务 1.3 完成

- 修复编译后focused r2通过`13/13`；状态机审阅再修复starting期间capability/sink变化、continuity对current sink operational的要求和revision overflow丢弃原始operational effect三处边界，final focused `/tmp/LuneX-17-1_3-focused-r3.3Mbkb9`通过`15/15`且零结构化诊断。
- expanded `/tmp/LuneX-17-1_3-expanded.z64xdg`覆盖PiP、scene/window和旧continuity兼容性并通过`32/32`。完整macOS `/tmp/LuneX-17-1_3-full.nw8ngg`通过`746 total / 745 passed / 1 explicit Keychain skip / 0 failed`，唯一skip精确为`HostAndPersistenceTests/testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`；所有测试显式移除`LUNEX_RUN_KEYCHAIN_TEST`。
- exact-source四平台generic-device Debug warnings-as-errors build `/tmp/LuneX-17-1_3-builds.Acgnna`的macOS、iOS/iPadOS、tvOS和visionOS均`succeeded`，四份xcresult结构化error/warning/analyzer warning均为0。
- 只读simulator盘点确认固定iPhone 17 Pro `23A27088-C19F-4F77-A455-4E50E393167E`和iPad Pro 13-inch (M5) `409A5908-8C39-4797-A41C-04503A05FA3D`各唯一、available、`Shutdown`，全局`Booted=0`；未执行create、clone、boot、install、launch、run、shutdown或delete。
- OpenSpec 1.3已勾选，权威进度更新为`3/36`。本项只证明Foundation PiP/continuity值合同、deterministic reducer、generation/revision/cleanup语义和四平台编译；不证明actual AVKit/frame sink、system PiP、background duration、signed配置、Stage Manager、mobile EDR、真机或live Sunshine。下一项为1.4 mobile EDR值合同。

## 2026-07-30 阶段 17 任务 1.4 启动

- 1.3已以`91697e7 Define mobile Picture in Picture state`提交并推送，fetch后确认`HEAD == origin/main`且起始工作树clean；OpenSpec为`3/36 ready`，当前任务1.4。
- 新mobile EDR值层复用1.2的surface/display generation、既有`HDRDisplayRevision`和`HDRDisplaySnapshot`；不保存screen/object/marketing identity，render snapshot的`displayID`固定为nil。
- headroom normalization复用HDR luminance pipeline的`64.0`上限：有限`0...64`归一为`1...64`，current不得超过potential；无效值只发布typed conservative-SDR fallback，不保留原始无界数值或借用global screen。

## 2026-07-30 阶段 17 任务 1.4 完成

- 首轮focused `/tmp/LuneX-17-1_4-focused.mw3FZQ`通过`10/10`；提交前审阅把available state与最终snapshot initializer收紧为file-private，补负值和超过`64.0`边界，final focused `/tmp/LuneX-17-1_4-focused-final.Y6tFJ8`再次通过`10/10`且零结构化诊断。
- expanded `/tmp/LuneX-17-1_4-expanded.7sN4P7`覆盖mobile EDR、scene/window、lifecycle display revision、HDR luminance mapping和render resolver并通过`55/55`。完整macOS `/tmp/LuneX-17-1_4-full.SQ2yAU`通过`756 total / 755 passed / 1 explicit Keychain skip / 0 failed`，唯一skip精确为真实Keychain opt-in；所有测试显式移除`LUNEX_RUN_KEYCHAIN_TEST`。
- exact-source四平台generic-device Debug warnings-as-errors build `/tmp/LuneX-17-1_4-builds.yyaIVE`的macOS、iOS/iPadOS、tvOS和visionOS均`succeeded`，四份xcresult结构化error/warning/analyzer warning为0。
- 只读盘点确认固定iPhone/iPad各唯一、available、`Shutdown`且全局`Booted=0`，没有执行任何simulator生命周期操作。OpenSpec 1.4已勾选，权威进度更新为`4/36`，下一项1.5。
- 本项只证明actual-display generation值、bounded headroom normalization、typed conservative-SDR fallback、privacy-safe existing HDR revision bridge和四平台编译；不证明actual UIKit screen reader/observer、Metal reconfiguration、visible EDR、external display、真机或live Sunshine。

## 2026-07-30 阶段 17 任务 1.5 启动

- 1.4已以`013e5e5 Define mobile EDR display state`提交并推送，确认`HEAD == origin/main`且起始工作树clean；OpenSpec为`4/36 ready`，当前任务1.5只扩展值层确定性测试，不提前接入2.x/3.x/4.x production adapter。
- 扩展矩阵覆盖3,840项continuity policy笛卡尔组合、PiP完整合法/非法transition、semantic duplicate、restoration并发/ordinal/overflow、frame-sink容量上下界、三类revision到max再overflow、scene数值边界、EDR归一化等价类和invalid payload隐私收敛。
- macOS 27.0更新后恢复，现场确认`HEAD == origin/main == 013e5e5`，Xcode仍为26.4、Swift为6.3；固定iOS 26.4 iPhone/iPad均available且`Shutdown`，全局无Booted设备，未操作simulator。
- 首轮1.5 focused执行`51`项、`49`项通过、`2`项失败：coordinate boundary用例的`1 x 1` bounds同时继承默认top/bottom safe-area而按合同正确关闭；unprepared `.startRequested`按能力门返回`.pictureInPictureUnavailable`而非普通`.invalidTransition`。生产合同未显示异常；测试分别显式使用zero safe-area并按事件精确断言拒绝类别，待全新DerivedData/result bundle复验。
- 修正后的final focused `/tmp/LuneX-17-1_5-focused-final.viWjAE/Focused.xcresult`结构化通过`51/51 passed / 0 skipped / 0 failed`，build-results的error、warning与analyzer warning均为0；测试显式移除`LUNEX_RUN_KEYCHAIN_TEST`。
- 完整macOS gate `/tmp/LuneX-17-1_5-full.YQ8HXp/Full.xcresult`通过`772 total / 771 passed / 1 skipped / 0 failed`；唯一skip精确为`HostAndPersistenceTests/testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，结构化error、warning与analyzer warning均为0。

## 2026-07-30 阶段 17 任务 1.5 完成

- exact-source四平台generic-device Debug warnings-as-errors build `/tmp/LuneX-17-1_5-builds.yraPq0`的macOS、iOS/iPadOS、tvOS和visionOS均出现精确一次`BUILD SUCCEEDED`，四份xcresult的error、warning与analyzer warning均为0；只执行build action，没有启动simulator。
- repository gate `/tmp/LuneX-17-1_5-repository.gMZ1oo`通过OpenSpec strict `1/1`、generator初始与连续两次稳定SHA-256 `401bbe515bb4ece1a7af350d45eb923a3fa50ca35201a1ad5613d1efce99ccf3`、test membership、增量privacy和`git diff --check`。固定iOS 26.4 iPhone/iPad各唯一、available、`Shutdown`且全局`Booted=0`；只执行一次只读inventory。
- OpenSpec 1.5已勾选，权威进度更新为`5/36`，下一项2.1扩展mobile `MTKView`的injectable attachment callback边界。本项不回填actual UIKit/AVKit、system PiP/background、Stage Manager、external display、mobile EDR、signed/physical/live Sunshine证明。

## 2026-07-30 阶段 17 任务 2.1 启动

- 1.5已以`f055e5a Expand mobile continuity contract tests`独立提交并推送，fetch后确认`HEAD == origin/main`且工作树clean；OpenSpec为`5/36 ready`，当前任务2.1只扩展iOS/iPadOS `MTKView` callback边界，不提前实现2.2 scene/window owner。
- Xcode 26.4 public SDK与Context7 Apple文档确认`registerForTraitChanges(_:handler:)`返回`any UITraitChangeRegistration`并可显式`unregisterForTraitChanges(_:)`；部署目标26.0无需兼容分支。实现使用弱surface、可替换/失效的main-actor relay，封闭事件只包含`didMoveToWindow`、layout、safe-area和registered traits，不携带UIKit对象身份或raw payload。
- 首轮focused `/tmp/LuneX-17-2_1-focused.2gQgFg`在测试执行前被warnings-as-errors拒绝：局部弱观察引用`weak var weakSurface`从未赋值修改。production源码没有编译错误；按Swift 6.3诊断改为`weak let`，该bundle不计验收并从全新路径重跑。
- 修正后focused `/tmp/LuneX-17-2_1-focused-r2.eXTz63/Focused.xcresult`结构化通过`2/2 passed / 0 skipped / 0 failed`且diagnostics为0；iOS generic-device App build `/tmp/LuneX-17-2_1-ios-build.Q09W8q/Build.xcresult`成功且结构化error、warning与analyzer warning均为0，没有操作simulator。
- 更新后完整macOS证据`/tmp/LuneX-17-2_1-post-update.4S4rH3/full/Full.xcresult`在macOS 27.0通过`774 total / 773 passed / 1 skipped / 0 failed`，结构化error、warning与analyzer warning均为0；命令显式移除`LUNEX_RUN_KEYCHAIN_TEST`。
- 同一组合包装器在完整测试后因zsh数组索引触发`bad substitution`，四平台build均未启动；该错误只影响包装脚本，后续build使用显式Bash和全新证据目录，不把失败包装器视为四平台验收。

## 2026-07-30 阶段 17 任务 2.1 完成

- 显式Bash重跑的四平台证据`/tmp/LuneX-17-2_1-builds-post-update.UWtmEU`中macOS、iOS/iPadOS、tvOS和visionOS generic Debug全部成功；四份xcresult均为`succeeded`且error、warning与analyzer warning为0。
- 完整macOS唯一skip结构化精确为`HostAndPersistenceTests/testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`；正常测试与build均显式移除`LUNEX_RUN_KEYCHAIN_TEST`，没有再次访问真实Keychain。
- 只读simulator证据`/tmp/LuneX-17-2_1-simulator-post-update.rUDTIT`确认固定iPhone 17 Pro与iPad Pro 13-inch (M5)在iOS 26.4 runtime各唯一、available、`Shutdown`且全局`Booted=0`；只执行一次inventory，没有任何生命周期操作。
- OpenSpec 2.1已勾选，权威进度更新为`6/36`。本项只证明injectable callback boundary、relay lifetime/teardown、iOS API编译和跨平台隔离；不证明live UIKit callback、actual scene/window/screen owner、Stage Manager/geometry/input、PiP/background、mobile EDR、signed/physical/live Sunshine。下一项2.2。
- 首轮repository gate `/tmp/LuneX-17-2_1-repository.Dlb0Ix`在generator前因包装器误读不存在的OpenSpec `.summary.totals.invalid`字段退出；保存JSON实际为`1/1 passed`且`.items[].valid == true`。该轮不计最终验收，按当前CLI的`.summary.totals.failed`从全新目录重跑。
- 第二轮repository gate `/tmp/LuneX-17-2_1-repository-final.SwCvyR`已通过strict `1/1`、apply `6/36`和generator稳定，但全文件禁词检查误命中既有decoded-frame `ObjectIdentifier`；current diff新增行没有命中。该轮不计最终组合验收，静态检查收紧到新增行后从全新目录重跑。
- 最终repository gate `/tmp/LuneX-17-2_1-repository-final-r2.DdYYLT`通过OpenSpec strict `1/1`、apply `6/36`且next精确为2.2、generator连续稳定SHA-256 `401bbe515bb4ece1a7af350d45eb923a3fa50ca35201a1ad5613d1efce99ccf3`、source/test membership、iOS callback/trait静态边界、更新后完整test/build/simulator证据读回、Keychain opt-in关闭、privacy与`git diff --check`。

## 2026-07-30 阶段 17 任务 2.2 启动

- 2.1已以`04bbd98 Add mobile surface attachment callbacks`独立提交并推送，fetch后确认`HEAD == origin/main`且工作树clean；OpenSpec为`6/36 ready`，当前任务2.2不提前实现scene通知、geometry normalizer、drawable/input或AppModel接线。
- 新通用main-actor attachment owner固定一个`MobileSceneSurfaceGeneration`和surface identity，弱持有surface/window/scene/screen，拒绝stale generation、错误surface及invalidation后回调；同步handler只接收current-generation actual attachment或invalidated transition。
- iOS view resolver只沿`MobileStreamMetalView.window -> UIWindow.windowScene -> UIWindow.screen`派生attachment，不读取`UIScreen.main`、`connectedScenes`或SwiftUI `scenePhase`；per-view checked generation sequence在UInt64耗尽后fail closed。
- focused证据`/tmp/LuneX-17-2_2-focused.tjvteD/Focused.xcresult`覆盖2.1 relay及2.2 replacement/detach、stale generation/surface、late callback、idempotent invalidation和weak ownership，通过`5/5 passed / 0 skipped / 0 failed`且结构化diagnostics为0。
- iOS generic-device证据`/tmp/LuneX-17-2_2-ios-build.Lh2fpu/Build.xcresult`成功且结构化error、warning与analyzer warning均为0；只执行build action，没有操作simulator。
- expanded presenter证据`/tmp/LuneX-17-2_2-expanded.5sWe4b/Expanded.xcresult`通过`31/31`且零结构化diagnostics；完整macOS `/tmp/LuneX-17-2_2-full.dOhBLh/Full.xcresult`通过`777 total / 776 passed / 1 skipped / 0 failed`且零结构化diagnostics。
- Xcode 26.4枚举full case tree时触发`database.sqlite3 couldn't be moved`工具错误；不重复同一失败子命令。原始xcodebuild日志精确确认唯一skip为`HostAndPersistenceTests/testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，命令显式移除真实Keychain opt-in。

## 2026-07-30 阶段 17 任务 2.2 完成

- exact-source四平台证据`/tmp/LuneX-17-2_2-builds.PpGqRf`中macOS、iOS/iPadOS、tvOS和visionOS generic Debug全部成功，四份xcresult均为`succeeded`且error、warning与analyzer warning为0；只执行build action。
- 只读simulator证据`/tmp/LuneX-17-2_2-simulator.5RvcxU`确认固定iPhone 17 Pro和iPad Pro 13-inch (M5)在iOS 26.4 runtime各唯一、available、`Shutdown`且全局`Booted=0`；只调用一次inventory，没有生命周期操作。
- OpenSpec 2.2已勾选，权威进度更新为`7/36`。本项证明generation/surface-scoped actual attachment derivation、replacement/detach、stale/late rejection、weak teardown和跨平台编译；不证明live UIKit callback、scene notification、Stage Manager/geometry/input、PiP/background、mobile EDR、signed/physical/live Sunshine。下一项2.3。
- repository gate `/tmp/LuneX-17-2_2-repository.sgylpZ`通过OpenSpec strict `1/1`、apply `7/36`且next精确为2.3、generator连续稳定SHA-256 `401bbe515bb4ece1a7af350d45eb923a3fa50ca35201a1ad5613d1efce99ccf3`、membership、actual-view-only/weak-owner静态边界、focused/expanded/full、四平台build和保存的simulator证据读回、Keychain opt-in关闭、privacy与`git diff --check`。

## 2026-07-30 阶段 17 任务 2.3 启动

- 2.2已以`717f09f Add mobile scene attachment owner`独立提交并推送，fetch后确认`HEAD == origin/main`且工作树clean；OpenSpec为`7/36 ready`，当前任务2.3只闭合attached scene生命周期通知，不提前实现geometry/drawable/input。
- 新main-actor observer设计以surface generation和per-attachment UUID过滤回调；NotificationCenter token只订阅actual attached scene对象，replacement/detach/invalidate移除全部token，排队迟到任务再以observation UUID和current scene拒绝。
- 四个semantic映射为didActivate=`active`、willDeactivate=`inactive`、didEnterBackground=`background`、willEnterForeground=`inactive`；同scene相同activity去重，新scene即使初始activity相同也发布一次replacement初始状态。
- 首个production/tests/tracking组合补丁因hunk边界格式错误被`apply_patch`整体拒绝，工作树没有部分源码或测试改动；已拆为三个精确补丁继续。
- 首轮focused证据`/tmp/LuneX-17-2_3-focused.JhJVq9`在测试启动前失败，唯一production编译错误为`MetalStreamSurface.swift:324:9 cannot access property 'observers' with a non-Sendable type '[any NSObjectProtocol]' from nonisolated deinit`；该bundle不计验收，也不复用其DerivedData/result bundle。
- 修复保持显式资源释放：增加窄作用域、幂等的NotificationCenter token store，让main-actor observer在replacement/detach/invalidate主动清理，token store自身deinit仅作Objective-C observer兜底；不使用`@preconcurrency import Foundation`掩盖Swift 6.3诊断。
- 修复后的focused证据`/tmp/LuneX-17-2_3-focused-r2.MJ6961/Focused.xcresult`通过`3/3 passed / 0 skipped / 0 failed`，结构化error、warning与analyzer warning均为0；覆盖wrong-scene过滤/activity去重、scene replacement/old-token cancellation/detach和stale generation/queued-late/invalidation。
- iOS generic-device证据`/tmp/LuneX-17-2_3-ios-build.ULp392/Build.xcresult`成功且结构化diagnostics为0，确认Xcode 26.4 iOS SDK下四个`UIScene`通知、`activationState`读取和actual attachment接线均通过warnings-as-errors；只执行build action，没有操作simulator。
- expanded presenter证据`/tmp/LuneX-17-2_3-expanded.vyNEJV/Expanded.xcresult`通过`34/34`且零结构化diagnostics；完整macOS证据`/tmp/LuneX-17-2_3-full.sYEcAe/Full.xcresult`通过`780 total / 779 passed / 1 skipped / 0 failed`且零结构化diagnostics。
- 完整测试唯一skip精确为`HostAndPersistenceTests/testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`；全部命令显式移除`LUNEX_RUN_KEYCHAIN_TEST`，没有再次访问真实Keychain。
- exact-source四平台generic Debug分别保存于`/tmp/LuneX-17-2_3-build-macOS.UJWiu0`、`/tmp/LuneX-17-2_3-build-iOS.OGkriA`、`/tmp/LuneX-17-2_3-build-tvOS.zRSzBF`和`/tmp/LuneX-17-2_3-build-visionOS.NkirqG`；全部成功且四份xcresult的error、warning与analyzer warning均为0。
- 只读simulator证据`/tmp/LuneX-17-2_3-simulator.P2aGEm`确认固定iPhone 17 Pro和iPad Pro 13-inch (M5)在iOS 26.4 runtime中各唯一、UUID全局各唯一、available、`Shutdown`且全局`Booted=0`；只调用一次inventory，没有生命周期操作。
- OpenSpec 2.3已勾选，权威进度更新为`8/36`。本项证明actual attached-scene通知的generation/identity过滤、semantic dedup、replacement/detach/invalidation cancellation、queued-late拒绝与跨平台编译；不证明live UIKit通知、foreground全状态重采样、Stage Manager/geometry/input、PiP/background、mobile EDR、signed/physical/live Sunshine。下一项2.4。
- repository final gate `/tmp/LuneX-17-2_3-repository.B3wKMT`通过fixture self-test/全树、OpenSpec strict `1/1`、apply `8/36`且next精确为2.4、generator连续两次稳定SHA-256 `401bbe515bb4ece1a7af350d45eb923a3fa50ca35201a1ad5613d1efce99ccf3`、source/test membership、scene notification/generation/token cancellation静态边界、无global scene/screen fallback与无raw description隐私边界、focused/iOS API/expanded/full/四平台build及保存的单次simulator证据读回、Keychain opt-in关闭和`git diff --check`。

## 2026-07-30 阶段 17 任务 2.4 启动

- 2.3已以`2a87a0c Observe attached mobile scene lifecycle`独立提交并推送，fetch后确认`HEAD == origin/main`且工作树clean；OpenSpec为`8/36 ready`，当前任务2.4只连续发布normalized actual geometry和resize phase，不提前实现2.5 drawable/video/input绑定或5.x AppModel接线。
- 既有`MobileSceneWindowSnapshotPublisher`已具备finite bounds、safe-area/scale/drawable校验、semantic dedup和revision exhaustion；2.4在同一合同中补closed `resizing/settled`状态，由actual UIKit adapter提供view/window bounds、safe area、actual view scale、orientation和traits。
- runtime owner继续固定surface generation、弱持有actual UIKit对象，并按screen identity分配checked opaque display generation；layout/safe-area/trait callback立即发布resizing，静默期请求由可取消token确认后发布settled，replacement/detach/invalidate使旧token失效。
- Apple UIKit当前文档明确`UIView.contentScaleFactor`映射view逻辑points到实际device pixels，而`UIScreen.nativeScale`描述物理屏幕native比例；production reader因此以actual stream view的`contentScaleFactor`计算drawable，screen对象只用于attachment identity/display generation，避免缩放显示或window move时使用错误物理比例。
- 首轮focused `/tmp/LuneX-17-2_4-focused.tZztss`通过`5/5`且零结构化diagnostics；首轮iOS generic build `/tmp/LuneX-17-2_4-ios-build.ewC62N`在`MetalStreamSurface.swift`编译时被warnings-as-errors拒绝，精确诊断为`UIWindowScene.interfaceOrientation`自iOS 26 deprecated，测试未受影响且该build不计验收。
- Apple UIKit当前文档和Xcode 26.4诊断均要求从`UIWindowScene.effectiveGeometry.interfaceOrientation`读取当前方向；production reader改用该iOS 26 API，并从全新DerivedData/result bundle重跑。

## 2026-07-30 阶段 17 任务 2.4 完成

- 修正后的focused证据`/tmp/LuneX-17-2_4-focused-r2.SIRAdy/Focused.xcresult`通过`5/5 passed / 0 skipped / 0 failed`；iOS generic-device证据`/tmp/LuneX-17-2_4-ios-build-r2.iq6n8h/Build.xcresult`成功，二者结构化error、warning与analyzer warning均为0，deprecated orientation诊断已消失。
- expanded证据`/tmp/LuneX-17-2_4-expanded.jL6h9h/Expanded.xcresult`通过`53/53`；完整macOS证据`/tmp/LuneX-17-2_4-full.mHEzYQ/Full.xcresult`通过`785 total / 784 passed / 1 skipped / 0 failed`。唯一skip精确为`HostAndPersistenceTests/testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`；所有命令显式移除真实Keychain opt-in。
- exact-source四平台generic Debug证据为`/tmp/LuneX-17-2_4-build-macOS.hQfvSE`、`/tmp/LuneX-17-2_4-build-iOS.CT6QGd`、`/tmp/LuneX-17-2_4-build-tvOS.jVhWYw`和`/tmp/LuneX-17-2_4-build-visionOS.rHcj0k`；4/4成功且xcresult结构化diagnostics为0。
- 首个只读simulator jq包装器因布尔链改变输入而错误退出；`simctl`只调用一次，随后从同一`/tmp/LuneX-17-2_4-simulator.bOWTZD/devices.json`用显式`.devices as $devices`复核固定iPhone/iPad各唯一、available、`Shutdown`且全局`Booted=0`，没有生命周期操作。
- repository pre-gate `/tmp/LuneX-17-2_4-repository-pre.OHmxni`通过generator生成前及连续两次稳定SHA-256 `401bbe515bb4ece1a7af350d45eb923a3fa50ca35201a1ad5613d1efce99ccf3`、membership、actual-view-only geometry API、无global fallback/deprecated orientation和`git diff --check`；OpenSpec strict `1/1`通过。
- OpenSpec 2.4已勾选，权威进度更新为`9/36`。本项证明deterministic continuous normalized UIKit geometry和resize-settled semantics，不证明2.5 drawable/video/input绑定、live Stage Manager/rotation/external display、PiP/background、mobile EDR、signed/physical/live Sunshine。下一项2.5。
- 首个final repository包装器在JavaScript解析阶段误读Bash参数展开，命令未进入shell；改用`printenv`后的最终门`/tmp/LuneX-17-2_4-repository-final.oyMQnP`通过strict `1/1`、apply `9/36`且next精确为2.5、generator SHA、Keychain opt-in关闭、geometry/API静态边界、全部xcresult与保存的simulator证据读回和`git diff --check`。

## 2026-07-30 阶段 17 任务 2.5 启动

- 2.4已以`67b90ef Track mobile scene geometry`独立提交并推送，确认`HEAD == origin/main`且工作树clean；OpenSpec为`9/36 ready`，当前任务2.5只绑定同一mobile geometry revision到drawable、video fit/fill和touch/absolute pointer，不提前实现2.6扩展矩阵或5.x AppModel/media environment。
- 既有`StreamCoordinateSnapshot`、`StreamVideoRectangleResolver`、`InputMapper`和`TouchInputAdapter`已具备fit letterbox拒绝、fill crop映射、immutable revision和绝对输入转换；缺口是mobile actual scene snapshot没有原子驱动这些合同。
- 新binding owner固定surface generation和surface identity，以同一次valid scene update应用actual drawable、解析source/mode coordinate snapshot并发布含scene revision的binding；detached、invalid、stale或surface apply失败清空drawable/coordinate并使touch/hover typed drop。
- 系统更新后恢复并先等待既有测试cell，没有启动重复测试。owner focused证据`/tmp/LuneX-17-2_5-owner-focused.QL0y4t/Focused.xcresult`通过`4/4 passed / 0 skipped / 0 failed`，命令使用warnings-as-errors、禁用签名并显式移除`LUNEX_RUN_KEYCHAIN_TEST`。
- production审阅确认`MobileStreamMetalView`仍只转发scene snapshot，`updateUIView`仍从独立`renderState.coordinateSnapshot`写drawable且没有UIKit touch/hover入口；下一实现将把binding owner接入actual view和presenter/render-state，并提供generation-scoped可注入输入输出边界，网络发送仍留给5.x。
- production接线后的focused `/tmp/LuneX-17-2_5-focused-production.7Syvin`通过`5/5`，iOS generic-device build `/tmp/LuneX-17-2_5-ios-production-build.Kws9oP`成功；审阅随后发现旧binding不得覆盖更新中的render source/mode且drawable apply失败应允许同值重试，因此这两份只保留为调查证据。
- 收紧后的首轮focused `/tmp/LuneX-17-2_5-focused-final.xFPGX9`为`4 passed / 1 failed`；失败只因coordinator测试fixture仍期待不匹配旧binding覆盖新source/mode，production按新合同正确归零。已修正fixture，失败bundle不计验收并从全新路径重跑。
- exact-source focused `/tmp/LuneX-17-2_5-focused-final-r2.PgFLvr/Focused.xcresult`结构化通过`5/5 passed / 0 skipped / 0 failed`；iOS generic-device `/tmp/LuneX-17-2_5-ios-final-build.PKRXqq/Build.xcresult`为`succeeded`。两份结果的error、warning与analyzer warning均为0。
- macOS更新结束后恢复原expanded测试会话`43780`，没有启动重复命令；`/tmp/LuneX-17-2_5-expanded.I2l8Za/Expanded.xcresult`最终为`88/88 passed / 0 skipped / 0 failed / 0 expected failure`，结构化build status为`succeeded`且error、warning、analyzer warning均为0。
- 完整macOS normal suite从全新DerivedData运行，`/tmp/LuneX-17-2_5-full.YHUnbC/Full.xcresult`为`790 total / 789 passed / 1 explicit Keychain skip / 0 failed / 0 expected failure`；唯一skip由原始日志精确确认，测试命令显式移除`LUNEX_RUN_KEYCHAIN_TEST`，结构化error、warning、analyzer warning均为0。
- `xcresulttool get test-results tests`对该成功bundle触发Xcode 26.4已知的内部`database.sqlite3`同名move错误；没有重跑测试，使用同一bundle可读的summary/build-results与原始日志完成总数、唯一skip及零诊断证明。
- 四平台generic Debug build从独立DerivedData完成，证据根`/tmp/LuneX-17-2_5-builds.fF2JX1`；macOS、iOS、tvOS、visionOS全部`succeeded`、三类结构化诊断为0，并各生成一个Metal AIR与metallib。构建没有使用simulator destination。
- 只调用一次`simctl list devices available -j`并保存`/tmp/LuneX-17-2_5-simulator.yZPAhn/devices.json`；固定iPhone/iPad各唯一、名称在iOS 26.4中各唯一、available、`Shutdown`且全局`Booted=0`，未create、clone、boot、launch、shutdown或delete设备。

## 2026-07-30 阶段 17 任务 2.5 完成

- final代码审阅确认invalidation先发布nil/归零、source/mode mismatch fail closed、同值drawable apply可重试、iOS不再由旧coordinate snapshot单独写drawable，且tvOS/visionOS维持原非iOS drawable行为。
- repository pre-gate`/tmp/LuneX-17-2_5-repository-pre.vb0AcX`通过fixture、OpenSpec strict、apply、generator连续稳定SHA-256 `401bbe515bb4ece1a7af350d45eb923a3fa50ca35201a1ad5613d1efce99ccf3`、membership、static platform/privacy/network boundaries、focused/expanded/full/四平台build与单次simulator证据读回、Keychain opt-in关闭及`git diff --check`。
- OpenSpec 2.5已勾选，权威进度更新为`10/36`。本项证明确定性actual mobile surface geometry到drawable/video/input边界，不证明live UIKit touch、Stage Manager/rotation/external display、input transport、PiP/background、mobile EDR、signed/physical/live Sunshine。下一项2.6。
- 标记后的repository final gate`/tmp/LuneX-17-2_5-repository-final.wjEq5N`通过OpenSpec strict `1/1`、apply `10/36`且next精确为2.6、fixture、generator连续稳定SHA-256 `401bbe515bb4ece1a7af350d45eb923a3fa50ca35201a1ad5613d1efce99ccf3`、production/test静态边界、全部既有证据与保存的单次simulator inventory读回、Keychain opt-in关闭和`git diff --check`。

## 2026-07-30 阶段 17 任务 2.6 启动

- 2.5已以`79b805a Bind mobile stream geometry`独立提交并推送，确认`HEAD == origin/main`且工作树clean；OpenSpec为`10/36 ready`，当前任务2.6只补attachment/scene/geometry/binding/renderer/input确定性扩展矩阵，不提前实现3.x mobile EDR。
- 覆盖审计确认基础attachment、multi-scene、resize/settle、invalid、replacement/late work、fit/fill与input测试已存在；待补组合缺口为rotation+safe-area+trait连续revision、非坐标scene revision与coordinate revision关系，以及binding teardown到renderer/input的原子清理。
- 已新增三个组合测试与可参数化geometry fixture；focused`/tmp/LuneX-17-2_6-focused.VPjCwq/Focused.xcresult`一次通过`3/3 passed / 0 skipped / 0 failed / 0 expected failure`，结构化三类诊断为0，命令显式移除真实Keychain opt-in。
- 恢复后直接读取已有expanded bundle，没有重复启动测试；`/tmp/LuneX-17-2_6-expanded.LujnSa/Expanded.xcresult`结构化为`91/91 passed / 0 skipped / 0 failed / 0 expected failure`，build status为`succeeded`且error、warning、analyzer warning均为0。
- 完整macOS normal suite使用全新`/tmp/LuneX-17-2_6-full.sm8U4i`并显式移除`LUNEX_RUN_KEYCHAIN_TEST`，结构化通过`793 total / 792 passed / 1 skipped / 0 failed / 0 expected failure`；唯一skip精确为真实Keychain opt-in测试，build status为`succeeded`且三类结构化诊断为0。
- 首个四平台build包装器在进入`xcodebuild`前因zsh数组使用0-based索引而以`parameter not set`退出；`/tmp/LuneX-17-2_6-builds.C8VhgY`不计验收，未构建、未访问Keychain、未操作simulator。修正为1-based索引并从全新证据路径执行。
- 修正后的`/tmp/LuneX-17-2_6-builds-r2.cWlehS`完成macOS、iOS/iPadOS、tvOS和visionOS四个generic Debug build；4/4 `succeeded`，四份xcresult的error、warning、analyzer warning均为0，每个平台各有一个Metal AIR和metallib。全程未选择simulator destination。
- 仅调用一次`simctl list devices available -j`并保存`/tmp/LuneX-17-2_6-simulator.9X74tq/devices.json`；固定iPhone/iPad各全局唯一、available、`Shutdown`且全局`Booted=0`，没有执行任何simulator生命周期操作。

## 2026-07-30 阶段 17 任务 2.6 完成

- 提交前审阅确认三个新增组合测试覆盖rotation/safe-area/trait semantic revision、scene/coordinate revision分离、replacement late-work拒绝及renderer/input原子teardown；production源码、generator和工程零diff。
- repository pre-gate`/tmp/LuneX-17-2_6-repository-pre.kYmVui`通过fixture、OpenSpec strict、apply、generator连续稳定SHA-256 `401bbe515bb4ece1a7af350d45eb923a3fa50ca35201a1ad5613d1efce99ccf3`、membership/静态语义、全部test/build与保存的单次simulator证据读回、Keychain opt-in关闭和`git diff --check`。
- OpenSpec 2.6已勾选，预期权威进度更新为`11/36`；下一项3.1实现injectable actual-window `UIScreen` EDR reader。本项不证明live rotation/Stage Manager/external display、PiP/background、mobile EDR、signed/physical设备或live Sunshine。
- 标记后的repository final gate`/tmp/LuneX-17-2_6-repository-final.6TxH5F`通过strict `1/1`、apply `11/36`且next精确为3.1、fixture、generator稳定、production零diff、全部既有test/build及保存的单次simulator证据读回、Keychain opt-in关闭和`git diff --check`。

## 2026-07-30 阶段 17 任务 3.1 启动

- 2.6已以`07b61de Expand mobile geometry regression coverage`独立提交并推送，fetch确认`HEAD == origin/main`且工作树clean；OpenSpec为`11/36 ready`，下一项精确为3.1。
- 读取OpenSpec/运行合同、现有mobile EDR值合同、UIKit SDK header和warnings-as-errors API probe；本项将新增无observer的injectable actual-window reader与typed状态测试，不提前实现3.2通知owner或3.3 renderer接线。
- 新增泛型main-actor window/screen reader、iOS actual-window specialization并抽取唯一state normalizer；focused`/tmp/LuneX-17-3_1-focused.aHM9Xf/Focused.xcresult`一次通过`5/5`且结构化三类诊断为0，命令显式移除真实Keychain opt-in。
- iOS generic-device build`/tmp/LuneX-17-3_1-ios-build.4fDQV2/Build.xcresult`成功，结构化error、warning和analyzer warning为0，并产出Metal AIR/metallib；命令没有使用simulator destination，也没有操作任何simulator。
- expanded回归`/tmp/LuneX-17-3_1-expanded.qYKgQZ/Expanded.xcresult`通过`88/88 passed / 0 skipped / 0 failed / 0 expected failure`，build status成功且结构化三类诊断为0；真实Keychain opt-in保持移除。
- 完整macOS normal suite`/tmp/LuneX-17-3_1-full.uwx1Jb/Full.xcresult`通过`798 total / 797 passed / 1 explicit Keychain skip / 0 failed / 0 expected failure`，build status成功且结构化三类诊断为0；唯一skip由原始日志精确确认，测试命令显式移除真实Keychain opt-in。
- 四平台generic Debug build证据根`/tmp/LuneX-17-3_1-builds.yyPAS7`完成macOS、iOS/iPadOS、tvOS和visionOS `4/4 succeeded`；四份xcresult结构化三类诊断均为0，各自产出Metal AIR/metallib，且没有使用simulator destination。
- 只调用一次`simctl list devices available -j`并保存`/tmp/LuneX-17-3_1-simulator.9645Ji/devices.json`；固定iPhone/iPad各全局唯一、available、`Shutdown`且全局`Booted=0`，没有执行任何simulator生命周期操作。
- final审阅确认actual-window specialization无global screen fallback，missing generation在读取前关闭，throw与所有invalid headroom分类均typed且不保留raw值，shared normalizer没有改变publisher render snapshot行为。
- repository pre-gate`/tmp/LuneX-17-3_1-repository-pre.C7DYgz`通过fixture、OpenSpec strict、apply、generator连续稳定SHA-256 `401bbe515bb4ece1a7af350d45eb923a3fa50ca35201a1ad5613d1efce99ccf3`、membership/API/static boundaries、全部test/build和保存的单次simulator证据读回、Keychain opt-in关闭及`git diff --check`。
- OpenSpec 3.1已勾选，权威进度更新为`12/36`，下一项3.2实现attached-screen mode/brightness通知及foreground、trait、attachment重采样与replacement/cancellation/stale rejection。本项不证明live UIKit/visible EDR、renderer接线、signed/physical设备或live Sunshine。
- 标记后的repository final gate`/tmp/LuneX-17-3_1-repository-final.lNttpg`通过strict `1/1`、apply `12/36`且next精确为3.2、fixture、generator稳定、任务/静态边界、全部既有test/build与保存的单次simulator证据读回、Keychain opt-in关闭及`git diff --check`。

## 2026-07-30 阶段 17 任务 3.2 启动

- 3.1已以`6b4bfcd Add mobile EDR window reader`提交并推送，确认`HEAD == origin/main`且工作树clean；当前3.2只实现attached-screen mode/brightness观察、foreground/trait/attachment重采样与replacement/cancellation/stale rejection，不提前完成3.3 renderer接线。
- SDK header确认mode/brightness notification object为发生变化的`UIScreen`；实现将只向actual attached screen注册token，复用geometry display generation和既有weak/generation/observation UUID模式，不使用deprecated global screen connect/disconnect或global fallback。
- 首轮focused`/tmp/LuneX-17-3_2-focused.nMdQFy`在测试执行前因两个未重新赋值的`weak var`释放探针被warnings-as-errors拒绝；production无诊断。测试改用既有`weak let`模式，旧bundle不计验收。
- 修正后的focused`/tmp/LuneX-17-3_2-focused-r2.HTIEu7/Focused.xcresult`通过`3/3`且结构化三类诊断为0；覆盖通知过滤/去重、foreground/trait/replacement、旧token cancellation及stale/queued-late/weak teardown。
- 系统更新后接回原iOS generic-device build会话`42126`，未启动重复命令；`/tmp/LuneX-17-3_2-ios-build.d4qkeu/Build.xcresult`成功、结构化三类诊断为0，并生成Metal AIR/metallib。
- production审阅移除了EDR observer handler replacement入口，确保observer构造时的`[weak self]`转发不会在SwiftUI update时被外部闭包替换；将从全新证据目录重跑focused和iOS generic build后再进入expanded门。
- 收紧后focused`/tmp/LuneX-17-3_2-focused-r3.a8uyGB/Focused.xcresult`通过`3/3`，最终iOS generic build`/tmp/LuneX-17-3_2-ios-build-r2.kXMKCn/Build.xcresult`成功并生成Metal AIR/metallib；两份结构化三类诊断均为0。
- expanded`/tmp/LuneX-17-3_2-expanded.V2g6f5/Expanded.xcresult`通过`91/91`；完整normal suite`/tmp/LuneX-17-3_2-full.RI9uPU/Full.xcresult`通过`801 total / 800 passed / 1 explicit Keychain skip / 0 failed`，结构化三类诊断为0且真实Keychain opt-in显式移除。
- 四平台generic Debug最终4/4成功且零结构化诊断，每个平台均生成Metal AIR/metallib；macOS/tvOS/visionOS证据根`/tmp/LuneX-17-3_2-builds.qHhDGU`，iOS使用最终源码证据`/tmp/LuneX-17-3_2-ios-build-r2.kXMKCn`。
- 本任务唯一一次只读simulator inventory为`/tmp/LuneX-17-3_2-simulator.ViyoJi/devices.json`；iOS 27.0 runtime新增同名默认设备导致旧跨runtime名称唯一断言为false，但固定iOS 26.4 UUID仍各唯一、available、`Shutdown`，所有同名实例均Shutdown且全局`Booted=0`。没有进行任何simulator生命周期或删除操作。
- repository pre-gate`/tmp/LuneX-17-3_2-repository-pre.1H5uQd`通过fixture、strict/apply、generator连续稳定SHA-256 `401bbe515bb4ece1a7af350d45eb923a3fa50ca35201a1ad5613d1efce99ccf3`、membership/静态边界、全部证据读回、Keychain opt-in关闭与diff检查。

## 2026-07-30 阶段 17 任务 3.2 完成

- OpenSpec 3.2已勾选，权威进度预期为`13/36`，下一项3.3连接mobile display revision到既有HDR/render identity、Metal surface和current-generation stale-frame检查。
- 本项完成actual attached screen mode/brightness通知、attachment/layout/trait/foreground重采样、geometry display generation复用、replacement/cancellation/stale/queued-late拒绝及weak handler ownership；renderer reconfiguration、visible HDR/EDR、signed/physical设备和live Sunshine仍明确pending。
- 标记后的repository final gate`/tmp/LuneX-17-3_2-repository-final.YFE34c`通过strict/apply `13/36` next 3.3、fixture、generator稳定、静态边界、全部证据读回、Keychain opt-in关闭、预期七文件状态与diff检查。

## 2026-07-30 阶段 17 任务 3.3 启动

- 用户确认系统更新结束并要求继续推进；恢复active目标、planning-with-files与OpenSpec apply流程，确认`HEAD == origin/main == 397690c`、工作树clean、`integrate-mobile-scene-pip-continuity`为`13/36 ready`且next精确为3.3。
- 当前环境为macOS 27.0、Xcode 26.4 `17E192`和Swift 6.3；固定iOS 26.4 simulator UUID继续沿用，iOS 27.0自动生成的同名Shutdown设备不删除。3.3只会在验收末尾做一次新的只读inventory，不创建、clone、boot、launch、shutdown或delete设备。
- 只读审计确认mobile EDR snapshot、HDR display/render identity、presenter原子transition与decoder generation/color/frame-contract检查均已存在；实现将抽取共享纯HDR解析器，把actual mobile surface generation和display revision接入coordinator、render state与presenter，并补current/stale generation及EDR-to-SDR identity回归。
- 首轮focused的三个既有测试通过，新display binding测试因fixture未发布geometry而正确得到drawable-unavailable；补充同generation geometry后不放宽production，最终focused `/tmp/LuneX-17-3_3-focused-r3.J4yoI9`通过`4/4`且零结构化诊断。
- iOS generic App build `/tmp/LuneX-17-3_3-ios-build-r3.IABs6c` succeeded，完整产出arm64 App executable、debug dylib、Swift module与metallib；只使用generic device destination。
- expanded `/tmp/LuneX-17-3_3-expanded.wSwME7`通过`92/92`；完整normal `/tmp/LuneX-17-3_3-full.BKJTBg`通过`802 total / 801 passed / 1 explicit Keychain skip / 0 failed`，三类结构化诊断为0且Keychain opt-in显式移除。
- macOS、iOS/iPadOS、tvOS与visionOS generic Debug build 4/4 succeeded、零结构化诊断且各有AIR/metallib；没有选择或操作simulator。
- 唯一一次只读simulator inventory `/tmp/LuneX-17-3_3-simulator.Vdmok1/devices.json`确认固定iOS 26.4 iPhone/iPad各唯一、available、Shutdown，所有同名27.0设备也Shutdown且全局Booted为0。
- repository pre-gate `/tmp/LuneX-17-3_3-repository-pre.hZ88T2`通过fixtures、strict/apply、generator双次稳定、静态边界、全部证据读回、Keychain opt-in关闭及diff检查。

## 2026-07-30 阶段 17 任务 3.3 完成

- OpenSpec 3.3已勾选，权威进度更新为`14/36`；下一项3.4为原子EDR/SDR fallback、screen move、重复抑制、revision exhaustion与observer幂等teardown。
- 当前证明边界为离线合同、实际四平台编译、macOS测试和只读simulator inventory；物理iPhone/iPad、visible EDR、external display、功耗、签名与live Sunshine仍未证明。

## 2026-07-30 阶段 17 任务 3.4 完成

- 系统更新后恢复active目标、planning-with-files与OpenSpec上下文，确认`HEAD == origin/main == a6d4928`且工作树只有3.4的四个预期源码/测试改动；Keychain opt-in未设置。
- 实现typed mobile display event、一次性revision exhaustion、observer token/window/screen幂等释放和coordinator原子EDR-to-SDR关闭；同generation晚到snapshot不能恢复，replacement surface generation才重置。
- 最终focused `/tmp/LuneX-17-3_4-focused-r2.YYqyMg/Focused.xcresult`通过`71/71`，expanded `/tmp/LuneX-17-3_4-expanded.zblOHb/Expanded.xcresult`通过`83/83`，full `/tmp/LuneX-17-3_4-full.WDSNFL/Full.xcresult`通过`804 total / 803 passed / 1 explicit Keychain skip / 0 failed`。
- macOS、iOS/iPadOS、tvOS和visionOS四平台generic Debug build均succeeded、结构化三类诊断为0并产出AIR/metallib；保存的唯一simulator inventory确认固定iOS 26.4 iPhone/iPad各唯一、available、Shutdown且全局Booted为0，没有执行任何设备生命周期操作。
- 正确repository pre-gate通过fixture、OpenSpec strict/apply、generator初始及连续两次稳定SHA-256 `401bbe515bb4ece1a7af350d45eb923a3fa50ca35201a1ad5613d1efce99ccf3`、证据读回、静态fallback边界、Keychain opt-in关闭及diff检查。首次错误scheme与误传`.` fixture root均记录为非验收错误并用正确参数重跑。
- OpenSpec 3.4已勾选，预期权威进度`15/36`；下一项3.5补window-screen ownership、normalization、notification filtering、screen move、foreground restore、render-mode transition、stale frame和resource release扩展测试。generic build不替代签名、安装、真机、visible EDR或live Sunshine证据。

## 2026-07-30 阶段 17 任务 3.5 启动

- 3.4已以`33197b6 Close mobile EDR revision exhaustion`独立提交并推送，fetch确认`HEAD == origin/main`且工作树clean；OpenSpec为`15/36 ready`，下一项精确为3.5。
- 审计现有覆盖后，3.5将只补window-screen mismatch/foreground restore、queued old-screen notification/equal-headroom move、observer deinit resource release和draw中display reconfiguration stale-plan拒绝四项组合回归，不提前修改4.x PiP生产路径。
- 首轮focused `/tmp/LuneX-17-3_5-focused.bcArqI/Focused.xcresult`为`3 passed / 1 failed`；三个observer测试通过，presenter测试仅因离屏`MTKView`的transition内`draw()`不立即调用delegate，夹具少了一次mandatory clear后的draw。production零error/warning；失败bundle不计验收，显式拆分clear/present后从全新目录重跑。

## 2026-07-30 阶段 17 任务 3.5 完成

- 修正后的focused `/tmp/LuneX-17-3_5-focused-r2.c0eyOE/Focused.xcresult`通过`4/4`；恢复后只接续原expanded会话，`/tmp/LuneX-17-3_5-expanded.xAgACx/Expanded.xcresult`通过`75/75`。两份结果均为零结构化诊断。
- 完整macOS normal suite `/tmp/LuneX-17-3_5-full.mmlk41/Full.xcresult`通过`808 total / 807 passed / 1 skipped / 0 failed`，唯一skip精确为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`；命令显式移除`LUNEX_RUN_KEYCHAIN_TEST`，未再次访问真实Keychain。
- 四平台generic Debug build证据根`/tmp/LuneX-17-3_5-builds.BtDVeh`；macOS、iOS/iPadOS、tvOS和visionOS全部succeeded，error/warning/analyzer warning均为0，各有一个AIR与metallib。构建没有选择simulator destination。
- 本任务唯一一次`simctl list devices available -j`保存于`/tmp/LuneX-17-3_5-simulator.eONo7q/devices.json`；固定iOS 26.4 iPhone/iPad按runtime/name/UUID各唯一、available、Shutdown，全局Booted为0。iOS 27.0同名系统设备也为Shutdown；未执行create/clone/boot/install/launch/shutdown/delete。
- 首轮repository包装器在OpenSpec原始JSON已证明8/8 valid后误读旧`.summary.invalid`字段并于generator前退出，不计验收。corrected `/tmp/LuneX-17-3_5-repository-pre-r2.ETDMp3`从头通过fixture、strict、勾选前apply `15/36` next 3.5、generator三次稳定SHA-256、工程零diff和`git diff --check`。
- OpenSpec 3.5已勾选，预期权威进度`16/36`，下一项4.1定义injectable main-actor PiP controller/content-source/playback-delegate client boundary。本项不证明signed/physical/system-PiP/background/visible-EDR/live-Sunshine行为。

## 2026-07-30 阶段 17 任务 4.1 启动

- 3.5已以`dedfad0 Expand mobile EDR regression coverage`独立提交并推送，fetch确认`HEAD == origin/main`且工作树clean；OpenSpec为`16/36 ready`，下一项精确为4.1。
- 审计现有PiP值合同、OpenSpec设计/spec和Xcode 26.4 AVKit headers；Context7 Apple索引没有返回相关AVKit条目，因此本机公开SDK header和Swift importer probe作为当前API证据。
- 4.1限定为platform-neutral semantic values与`@MainActor` injectable client boundary，显式覆盖controller/content-source/playback-delegate ownership、playback state、capability/lifecycle event、render size、skip/restoration callback lease与completion；不提前创建AVKit对象、sample buffer或display layer。
- 首轮focused `/tmp/LuneX-17-4_1-focused.qn2xIj/Focused.xcresult`通过`26/26`；审阅后删除无用途component-name enum，补playback-delegate failure映射与stale callback completion，收紧后的`/tmp/LuneX-17-4_1-focused-r2.g2gYJ4/Focused.xcresult`通过`27/27`。
- 首个iOS AVKit probe因直接main-actor class conformance被Swift 6.3拒绝；改为协议级`@MainActor` isolated conformance后，macOS/iOS/tvOS/visionOS 26.4四SDK typecheck全部通过，锁定content-source initializer、playback delegate labels、skip/restoration completion和possibility/invalidate API。

## 2026-07-30 阶段 17 任务 4.1 完成

- 系统更新后恢复核验仍为Xcode 26.4、Swift 6.3与四平台26.4 SDK；`HEAD == origin/main == dedfad0`，没有工具链漂移。未重新查询、创建、启动或修改simulator，也未访问真实Keychain。
- 收紧后的focused `/tmp/LuneX-17-4_1-focused-r2.g2gYJ4/Focused.xcresult`通过`27/27`，expanded `/tmp/LuneX-17-4_1-expanded.0KNwFG/Expanded.xcresult`通过`75/75`；完整normal `/tmp/LuneX-17-4_1-full.bNF3gZ/Full.xcresult`为`812 total / 811 passed / 1 explicit Keychain skip / 0 failed`，三者结构化error、warning、analyzer warning均为0。
- 四平台generic Debug证据根`/tmp/LuneX-17-4_1-builds.w391o4`；macOS、iOS/iPadOS、tvOS、visionOS均succeeded且三类结构化诊断为0，每个平台各有一个AIR与metallib。复用本任务既有只读inventory `/tmp/LuneX-17-4_1-simulator.8aqwfY/devices.json`，固定iOS 26.4 iPhone/iPad各唯一、available、Shutdown，全局Booted为0。
- 最终repository pre-gate通过fixture self-test/全树、OpenSpec strict `8/8`、勾选前apply `16/36` next 4.1、generator初始及连续两次稳定SHA-256 `8e897a1edbf76ad1d3ad7d68f34c07bf82dddece5d0b341c13bf4f953ab20000`和`git diff --check`。
- OpenSpec 4.1已勾选，预期权威进度`17/36`，下一项4.2实现bounded current-generation pixel-buffer到sample-buffer adapter。本项不创建production AVKit controller/display layer，不证明签名、安装、系统PiP、后台持续时间、物理设备或live Sunshine。

## 2026-07-30 阶段 17 任务 4.2 启动

- 4.1已以`bc35b90 Define native PiP client boundary`独立提交并推送，fetch确认`HEAD == origin/main`且工作树clean；OpenSpec为`17/36 ready`，下一项精确为4.2。
- Context7未返回可用CoreMedia条目；改以Xcode 26.4公开SDK headers、四平台warnings-as-errors Swift importer probe、现有`DecodedVideoFrame`与HDR color contract为当前API证据。
- 4.2实现generation/decoder/color绑定的同步adapter，在同一`CVPixelBuffer`上补齐可传播color/HDR attachments，并用`CMVideoFormatDescriptionCreateForImageBuffer`和`CMSampleBufferCreateReadyWithImageBuffer`做ready浅包装；只缓存一个compatible format description，不创建decoder、layer或frame queue。
- 首轮focused `/tmp/LuneX-17-4_2-focused.0X5aRe/Focused.xcresult`通过`6/6`且结构化诊断为0；审阅后将首个active frame contract的提交移动到CoreMedia创建和same-image-buffer ownership验证之后，确保创建失败不留下部分激活状态。

## 2026-07-30 阶段 17 任务 4.2 完成

- 收紧后的focused `/tmp/LuneX-17-4_2-focused-r2.ngUF6h/Focused.xcresult`通过`6/6`；expanded `/tmp/LuneX-17-4_2-expanded.xyNelV/Expanded.xcresult`覆盖adapter、PiP state、HDR decoded contract、color metadata与VideoToolbox decode并通过`55/55`，两者结构化error、warning、analyzer warning均为0。
- 完整macOS normal `/tmp/LuneX-17-4_2-full.j3EE9l/Full.xcresult`通过`818 total / 817 passed / 1 skipped / 0 failed`，唯一skip精确为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`；测试显式移除`LUNEX_RUN_KEYCHAIN_TEST`，未再次访问真实Keychain。
- 四平台generic Debug build分别位于`/tmp/LuneX-17-4_2-build-macos.Fn9hny`、`/tmp/LuneX-17-4_2-build-ios.e2ZPkR`、`/tmp/LuneX-17-4_2-build-tvos.XTJjxz`与`/tmp/LuneX-17-4_2-build-visionos.P8uVtw`；全部succeeded、三类结构化诊断为0且各有一个AIR和metallib。
- repository pre-gate `/tmp/LuneX-17-4_2-repository-pre.WcWVHw`通过fixture self-test/全树、OpenSpec strict `8/8`、勾选前apply `17/36` next 4.2、generator三次稳定SHA-256 `d318f8dcb978bbe1fe852045546c05ac7e9a1af042a9faca0b6e5dfce7056471`、membership、no-second-decoder/no-layer/no-buffer-array静态门和`git diff --check`。
- 本项未查询或操作simulator。OpenSpec 4.2已勾选，预期权威进度`18/36`，下一项4.3实现production display-layer sink与单槽backpressure；4.2不证明系统PiP、签名/安装、后台持续时间、物理设备或live Sunshine。

## 2026-07-30 阶段 17 任务 4.3 启动

- 用户在macOS更新后要求继续推进；恢复active长期目标、planning-with-files和OpenSpec apply流程，确认`HEAD == origin/main == e7648ff`、工作树clean、change为`18/36 ready`且next精确为4.3，环境仍为macOS 27.0、Xcode 26.4和Swift 6.3。
- Context7 Apple索引没有返回相关AVFoundation条目；Xcode 26.4公开headers与四平台warnings-as-errors importer probe确认旧display-layer queue API已弃用，production保留真实`AVSampleBufferDisplayLayer`但只调用现代`sampleBufferRenderer`。
- 已新增main-actor injectable renderer client、真实display-layer client、generation-owned单槽sink和focused测试，覆盖ready enqueue、latest pending replacement、request/stop平衡、旧callback拒绝、format/color与discontinuity flush、failure recovery、stale generation、幂等invalidate和pending pixel-buffer release；尚未完成第一次focused编译。
- 全部测试继续显式移除`LUNEX_RUN_KEYCHAIN_TEST`；本项不查询、创建、启动或修改任何simulator，也不提前实现4.4 controller/content source。
- 首轮focused误用无test action的App scheme并在编译前退出；第二轮正确scheme进入编译后仅因两项通知使用ObjC常量名被Swift importer拒绝。两项均已记录并用现代Swift通知名修正，不计验收证据。
- 修正后的focused先通过`10/10`；自审又补renderer在callback前恢复ready时由直接新帧停止旧request的竞态回归，并收紧discontinuity后native仍失败的phase。最终`/tmp/LuneX-17-4_3-focused-r4.bKbRRS/Focused.xcresult`通过`11/11`，结构化error、warning、analyzer warning均为0。
- expanded `/tmp/LuneX-17-4_3-expanded.r22lC1/Expanded.xcresult`覆盖sink、sample adapter、PiP state、HDR decoded contract、color metadata与VideoToolbox decompression并通过`66/66`；结构化error、warning、analyzer warning均为0。
- 完整macOS normal `/tmp/LuneX-17-4_3-full.xytBQ3/Full.xcresult`通过`829 total / 828 passed / 1 skipped / 0 failed`，唯一skip结构化精确为`HostAndPersistenceTests/testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`；命令显式移除`LUNEX_RUN_KEYCHAIN_TEST`，三类结构化诊断为0。首轮repository包装器误按顶层`.valid`读取当前OpenSpec JSON，实际有效性位于`.items[].valid`，因此在第一个change后退出且generator未运行；第二轮已通过fixture、8/8 strict、apply、generator与静态边界，但误用zsh特殊变量`path`覆盖`PATH`，在focused证据读回前退出。两轮均不计验收，修正为`result_path`后从全新证据目录完整重跑。

## 2026-07-30 阶段 17 任务 4.3 完成

- 四平台generic Debug证据根`/tmp/LuneX-17-4_3-builds.rCA9Ft`；macOS、iOS/iPadOS、tvOS、visionOS均succeeded，error/warning/analyzer warning均为0并各有一个AIR与metallib。本项没有查询、创建、启动或修改simulator。
- 最终repository pre-gate `/tmp/LuneX-17-4_3-repository-pre-r3.CBjSuA`从头通过fixture self-test/全树、OpenSpec strict `8/8`、勾选前apply `18/36`、generator初始及连续两次稳定SHA-256 `7ad20d043399d853b23b8bdcd57e82e4c4a25da79bd563e39513ab3f8b85b75d`、membership、modern renderer/no-controller/no-second-decoder/no-buffer-array静态边界、focused/expanded/full/四平台build证据读回、Keychain opt-in关闭和`git diff --check`。
- OpenSpec 4.3已勾选，预期权威进度`19/36`，下一项4.4实现production `AVPictureInPictureController.ContentSource(sampleBufferDisplayLayer:playbackDelegate:)` adapter与actual possibility observation。4.3离线证据不证明系统PiP、后台持续时间、签名/安装、物理设备或live Sunshine。

## 2026-07-30 阶段 17 任务 4.4 启动

- 4.3已以`fd3bf2e Add native PiP display layer sink`独立提交并推送，fetch确认`HEAD == origin/main`且工作树clean；OpenSpec为`19/36 ready`，下一项精确为4.4。
- Context7没有AVKit匹配库；改用Xcode 26.4公开SDK headers和四平台Swift 6.3 warnings-as-errors stdin probe锁定content source、controller delegate、sample-buffer playback delegate与possibility KVO签名，四SDK均零诊断。
- 4.4实现可注入native controller bridge、真实AVKit content source/controller/playback delegate/KVO owner及generation-bound semantic client；restore/skip native completion各限一个并exactly-once完成。4.5 reducer编排、4.6 frame subscription和5.x continuity policy不提前实现。
- 测试继续显式移除`LUNEX_RUN_KEYCHAIN_TEST`并使用Debug文件fallback；本项不查询、创建、启动或修改simulator。
- 首轮focused通过`10/10`；自审补充missing/removed consumer completion后第二轮通过`11/11`。将native属性收紧为lazy ownership的第三轮编译和链接成功，但3个直接创建真实controller的测试在当前Mac PiP unsupported时崩溃于Swift non-optional `AVPictureInPictureController.init(contentSource:)`，其余`8/11`通过。该bundle不计验收；production bridge改为二次support gate并以纯adapter覆盖playback转换后从全新证据重跑。

## 2026-07-30 阶段 17 任务 4.4 完成

- 恢复后确认macOS 27.0、Xcode/四SDK 26.4和active长期目标；没有查询或操作simulator，也没有设置`LUNEX_RUN_KEYCHAIN_TEST`。
- Swift support gate不足以防止ObjC initializer返回nil；新增`LuneXAVKitBridge.h/.m`以nullable函数构造content source/controller，Swift factory分别映射`.platformUnsupported`与`.controllerUnavailable`。generator已支持`.m`类型和四App/test target membership。
- focused r5仅因测试局部量未unwrap IUO而在测试编译阶段停止；r6随后由macOS 27全新编译暴露既有display-layer notification token非Sendable deinit。两份失败bundle不计验收；测试改为显式`XCTUnwrap`，renderer notification ownership改为私有RAII token owner。
- final focused `/tmp/LuneX-17-4_4-focused-r7.9wHInC/Focused.xcresult`为`10/10`，expanded `/tmp/LuneX-17-4_4-expanded.c32aAr/Expanded.xcresult`为`54/54`，完整normal `/tmp/LuneX-17-4_4-full.Y47gn4/Full.xcresult`为`839 total / 838 passed / 1 explicit Keychain skip / 0 failed`；三类结构化诊断均为0。
- 四平台generic Debug证据根`/tmp/LuneX-17-4_4-builds.Pe6FfA`；macOS、iOS/iPadOS、tvOS、visionOS全部succeeded且三类诊断为0，每个平台均实际生成AVKit bridge object、AIR和metallib。
- repository pre-gate `/tmp/LuneX-17-4_4-repository-pre.qYzmQy`从头通过fixtures、strict `8/8`、勾选前apply `19/36`、generator连续稳定SHA-256 `d81fbc8118b460da6467e2276def7c682603f322f23f89f0277f32fa33ed4499`、membership、nullable/no-direct-Swift-initializer/no-second-decoder静态边界、全部结果读回、Keychain opt-in关闭和diff检查。
- OpenSpec 4.4已勾选，权威进度更新为`20/36`，下一项4.5实现generation-scoped prepare/start/stop/failure/restore/playback/invalidation/replacement reducer orchestration。本项不证明系统PiP、后台持续时间、签名/安装、物理设备或live Sunshine。
- 勾选后的repository final gate `/tmp/LuneX-17-4_4-repository-final.Ye3KA5`完整通过，OpenSpec为`20/36`且next精确为4.5；generator SHA-256仍为`d81fbc8118b460da6467e2276def7c682603f322f23f89f0277f32fa33ed4499`。

## 2026-07-30 阶段 17 任务 4.5 启动

- macOS更新完成后恢复active长期目标、planning-with-files与OpenSpec apply流程；确认`HEAD == origin/main == 8b433d2`，change为`20/36 ready`且next精确为4.5。测试继续显式移除`LUNEX_RUN_KEYCHAIN_TEST`，本项不查询、创建、启动或修改simulator。
- 恢复到3处交接中的未提交修改后，完成reducer/client/sink审计；新增main-actor lifecycle coordinator和display-layer sink conformance，接通prepare/start/stop/failure/capability/frame-sink/restore/playback/skip/render-size/invalidation/replacement effect与event路径。
- 修正terminal cleanup潜在reducer重入：引入terminating gate，终止先解绑consumer/client handler，再直接drain native callback lease；revision exhaustion不再通过restoration reducer完成pending callback。
- 补充已准备client snapshot恢复，避免幂等client `prepare()`不重放事件时卡在`preparing`。新增独立4.5测试矩阵并加入generator；尚未重新生成工程或完成第一次focused编译。
- 首轮focused `/tmp/LuneX-17-4_5-focused-r1.tHpdXD/Focused.xcresult`完整编译并执行`12`项，`11/12`通过；唯一失败是测试把`prepare()`返回的`.preparing` request snapshot与同步prepared回调后的current `.ready` snapshot混为同一断言。production顺序和其余11项均通过，测试已拆分两个时间点并准备从全新证据目录重跑。
- 修正后focused `/tmp/LuneX-17-4_5-focused-r2.G7TAOn/Focused.xcresult`通过`12/12`。通过后自审进一步收紧terminating窗口不接受consumer handler重入，并新增unexpected client invalidation不反向重复invalidate client、只释放一次sink且晚到callback inert的回归；需从全新证据目录重跑形成最终focused。
- 最终focused `/tmp/LuneX-17-4_5-focused-r3.uPLtnD/Focused.xcresult`通过`13/13`，expanded `/tmp/LuneX-17-4_5-expanded.NZQNho/Expanded.xcresult`通过`67/67`；两者error、warning、analyzer warning均为0。
- 完整macOS normal `/tmp/LuneX-17-4_5-full.YvZo7X/Full.xcresult`通过`852 total / 851 passed / 1 skipped / 0 failed`，唯一skip精确为`HostAndPersistenceTests/testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`；三类诊断为0且Keychain opt-in未设置。
- 四平台generic Debug首个包装器在执行任何build前因zsh 1-based数组与0-based下标冲突退出；未查询或操作设备，改用显式`/bin/bash`重跑。
- 系统更新前启动的显式Bash四平台generic Debug会话已在恢复后正常退出，四个平台均存在AIR、metallib和完整xcresult，coordinator也进入相应Swift file list。首轮恢复后结构化汇总误用zsh只读变量`status`而在第一份结果后退出；构建本身未失败，该包装器不计完整验收，改以Bash和`build_status`从四份结果重读。
- 修正后的四平台结构化读回全部通过。首轮repository pre-gate随后通过fixture、OpenSpec `8/8`、apply `20/36 next 4.5`与生成器三次稳定哈希，但把PBXBuildFile声明和Sources phase引用的双重文本出现数误当成target数而退出；改用generator清单、四平台实际Swift file list和focused测试执行联合证明membership，并从全新证据目录重跑。
- 最终repository pre-gate `/tmp/LuneX-17-4_5-repository-pre-r3.yEmyKt`从头通过fixture self-test/全树、OpenSpec strict `8/8`、勾选前apply `20/36 next 4.5`、generator三次稳定SHA-256 `08c464fa6d9996a861e05cca034278cc8bacb2d1b67003c5f27ff481d6953b97`、generator/四平台file-list/focused-test membership、terminal direct-drain/no-4.6/no-second-decoder静态边界、focused/expanded/full/四平台build证据读回、唯一Keychain skip、Keychain opt-in关闭和`git diff --check`。
- OpenSpec 4.5已勾选，预期权威进度`21/36`，下一项4.6订阅既有decoded-frame presentation source并协调foreground Metal pause/throttle/resume，不创建第二decoder。4.5没有查询或操作simulator，也不证明system PiP、后台持续时间、签名/安装、物理设备、Stage Manager、visible EDR或live Sunshine。

## 2026-07-30 阶段 17 任务 4.6 启动

- 4.5已以`9de72f9 Orchestrate native PiP lifecycle`独立提交并经Surge SOCKS推送；fetch确认`HEAD == origin/main`且工作树clean，OpenSpec为`21/36 ready`、next精确为4.6。
- 审计确认foreground Metal只轮询既有`StreamVideoPresentationSource.currentFrame()`，source缺少实际decoded-frame订阅；4.6将在同一source上增加锁外、可取消、generation-filtered delivery，并用单槽main-actor mailbox向4.2 adapter/4.3 sink交付同一pixel buffer。
- foreground policy只在native did-start后覆盖为paused或throttled，停止/失败/invalidation恢复最新baseline。4.6不创建decoder、不提前接入5.x background continuity owner，也不查询或操作simulator；普通测试继续显式移除`LUNEX_RUN_KEYCHAIN_TEST`。
- macOS更新完成后恢复active长期目标与OpenSpec apply现场；重新确认`HEAD == origin/main == 9de72f9`、change `21/36 ready`、next 4.6，工作树仅含交接中已知的4.6实现和测试草案。
- 完成第一轮静态审查：实现仍复用唯一presentation source和同一pixel buffer，不持有decoder；delivery callback在source锁外发布，订阅上限8，PiP mailbox为单槽且最多调度一个main-actor drain。修正测试中不存在的Display-P3 metadata factory、active后非法`startFailed`序列和脆弱的terminal snapshot断言；尚未生成工程或执行focused编译。
- generator已成功更新工程membership且`git diff --check`通过。首轮focused `/tmp/LuneX-17-4_6-focused-r1.d9Xy6x/Focused.xcresult`在测试源码编译阶段因helper误写不存在的`VideoTransferFunction.smpte2084`停止，尚未执行任何测试；合法名称为`.smpteST2084PQ`，已修正并将用全新证据路径重跑。
- focused r2 `/tmp/LuneX-17-4_6-focused-r2.k93atp/Focused.xcresult`继续编译到production source，Swift 6.3在4个`withLock` Optional-return closure上无法从`nil`推断返回类型；已显式标注`StreamVideoPresentationEvent?`，不改变状态或delivery语义，准备从全新r3证据重跑。
- focused r3 `/tmp/LuneX-17-4_6-focused-r3.XbyqcS/Focused.xcresult`通过原始`9/9`且结构化诊断为0。通过后自审发现presentation revision overflow虽清source frame，却不会通知新PiP订阅flush；已在可用delivery revision上发布terminal clear、释放订阅并拒绝后续订阅，同时保持回调在source锁外。
- 补充overflow terminal clear/订阅释放/回调内重入`source.snapshot()`回归后，focused r4 `/tmp/LuneX-17-4_6-focused-r4.DFk4f6/Focused.xcresult`通过`10/10`。该suite覆盖same pixel buffer、latest replay、单槽20帧合并、clear/stale decoder、format/color adapter replacement、confirmed-active前台pause/throttle/restore、订阅容量/取消、delivery与presentation revision exhaustion和pending teardown。
- expanded `/tmp/LuneX-17-4_6-expanded.ulAjxJ/Expanded.xcresult`通过`158/158`，完整macOS normal `/tmp/LuneX-17-4_6-full.dCC4dx/Full.xcresult`为`862 total / 861 passed / 1 explicit Keychain skip / 0 failed`；两者三类结构化诊断均为0。四平台generic Debug根`/tmp/LuneX-17-4_6-builds.Fgk0XV`，macOS/iOS/tvOS/visionOS均succeeded、三类诊断0且各有AIR/metallib。
- 首轮repository pre-gate `/tmp/LuneX-17-4_6-repository-pre.R8tkJ8`已通过fixtures、OpenSpec `8/8`、apply `21/36 next 4.6`和generator三次稳定SHA-256 `e968c9a18cb1df83a6ec3be7c3eaf565c5ba571845ef45d79eddf01c895b4787`，随后因静态membership断言把production source在App sources与test support sources两个generator清单中的合法出现次数误写为1而退出；实际精确为2，测试清单为1，该轮不计最终门禁。
- 最终repository pre-gate `/tmp/LuneX-17-4_6-repository-pre-r2.NqdHlK`从头通过fixtures、OpenSpec strict `8/8`、勾选前apply `21/36 next 4.6`、generator三次稳定SHA-256 `e968c9a18cb1df83a6ec3be7c3eaf565c5ba571845ef45d79eddf01c895b4787`、generator与四平台file-list membership、single-decoder/no-buffer-allocation、最多8订阅/单槽mailbox/single-task/same-pixel-buffer/confirmed-active静态边界、focused/expanded/full/四平台结果读回、唯一Keychain skip、Keychain opt-in关闭和`git diff --check`。
- OpenSpec 4.6已勾选，预期权威进度`22/36`、next 4.7；合同、路线图和三份planning文件已同步。4.6不查询或操作simulator，也不证明5.x application integration、system PiP、后台持续时间、签名/安装、物理设备或live Sunshine。
- 勾选后的repository final gate `/tmp/LuneX-17-4_6-repository-final.OXBdSE`完整通过同一门禁；OpenSpec精确为`22/36`、4.6 done、next 4.7，generator SHA-256仍为`e968c9a18cb1df83a6ec3be7c3eaf565c5ba571845ef45d79eddf01c895b4787`。

## 2026-07-30 阶段 17 任务 4.7 启动

- 4.6已以`e68d757 Share decoded frames with native PiP`独立提交并推送；fetch确认`HEAD == origin/main == e68d7574ec7cc72146bf80bd72595f443f884a9f`且工作树clean，OpenSpec为`22/36 ready`、next精确为4.7。
- 审计既有PiP分层测试后，4.7聚焦新presentation coordinator的跨层缺口：start-failure foreground policy、restore/skip/playback exactly-once、backpressure/rejection映射，以及replacement pending mailbox/pixel-buffer/coordinator/stale-handler释放隔离。production代码无需修改。
- macOS更新后恢复active长期目标、planning-with-files与OpenSpec apply现场；确认`HEAD == origin/main == e68d757`、Xcode/SDK 26.4、OpenSpec `22/36 ready`且next仍为4.7。普通测试继续显式移除`LUNEX_RUN_KEYCHAIN_TEST`，本项不查询或操作simulator。
- 首轮focused `/tmp/LuneX-17-4_7-focused-r1.ivwNlL/Focused.xcresult`在测试源码编译阶段停止，未执行测试；结构化结果为3 errors / 0 warnings / 0 analyzer warnings，具体为build cancelled、`compactMap`无法推断Optional lease类型、只读局部`weak var`被warnings-as-errors拒绝。production未报错；已显式标注closure返回`MobilePictureInPictureRestorationLease?`并改为`weak let`，将从全新证据目录重跑。
- 修正后的focused `/tmp/LuneX-17-4_7-focused-r2.FhZpRb/Focused.xcresult`通过`14/14`，结构化error、warning、analyzer warning均为0。新增跨层回归证明start failure不压制foreground、playback/restore/skip经presentation owner exactly-once落回native callback、sink pending/replacement/rejection正确映射计数，以及replacement释放旧runtime/pixel buffer并使stale handler无法影响新generation；既有10项4.6回归继续通过。
- expanded `/tmp/LuneX-17-4_7-expanded.w61I5u/Expanded.xcresult`覆盖presentation/lifecycle/state/AVKit/sample adapter/display-layer sink、session media environment、foreground Metal与HDR display transition九个suite并通过`162/162`；结构化error、warning、analyzer warning均为0。
- 完整macOS normal `/tmp/LuneX-17-4_7-full.106eJz/Full.xcresult`通过`866 total / 865 passed / 1 skipped / 0 failed`，唯一skip精确为`HostAndPersistenceTests/testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`；结构化error、warning、analyzer warning均为0且命令显式移除`LUNEX_RUN_KEYCHAIN_TEST`。
- 四平台generic Debug证据根`/tmp/LuneX-17-4_7-builds.LTHC6L`；macOS、iOS/iPadOS、tvOS、visionOS全部succeeded，error/warning/analyzer warning均为0并各有一个AIR与metallib。本项未查询、创建、启动或修改simulator；generic build不证明签名、安装、系统PiP或物理设备行为。
- 首轮repository pre-gate `/tmp/LuneX-17-4_7-repository-pre.*`已通过fixture self-test/全树、OpenSpec strict `8/8`、apply `22/36 next 4.7`和generator三次稳定，随后因`rg -c ... || true`在零decoder匹配时返回空输出而非数字0，Bash整数断言退出。该组合门不计验收；改用`grep -Ec`并从全新证据目录完整重跑。
- 最终repository pre-gate `/tmp/LuneX-17-4_7-repository-pre-r2.WcRUw4`从头通过fixtures、OpenSpec strict `8/8`、勾选前apply `22/36 next 4.7`、generator三次稳定SHA-256 `e968c9a18cb1df83a6ec3be7c3eaf565c5ba571845ef45d79eddf01c895b4787`、production/project零diff、test membership与四项新增综合回归、no-second-decoder/resource-release静态边界、focused/expanded/full/四平台证据读回、唯一Keychain skip、Keychain opt-in关闭和`git diff --check`。
- OpenSpec 4.7已勾选，预期权威进度`23/36`、next 5.1；合同、路线图和三份planning文件已同步。4.7不证明application/media continuity接线、system PiP、后台持续时间、签名/安装、物理设备或live Sunshine。
- 勾选后的repository final gate `/tmp/LuneX-17-4_7-repository-final.RZBqSu`完整通过同一门禁；OpenSpec精确为`23/36`、4.7 done、next 5.1，generator SHA-256仍为`e968c9a18cb1df83a6ec3be7c3eaf565c5ba571845ef45d79eddf01c895b4787`。

## 2026-07-30 阶段 17 任务 5.1 启动

- 4.7已以`51ec62d Complete native PiP regression matrix`独立提交并推送；fetch确认`HEAD == origin/main == 51ec62d02a640e83c68460e8eee37d13ea369bd6`且工作树clean。OpenSpec为`23/36 ready`，next精确为5.1。
- 审计发现旧`MobileContinuityPolicyResolver`仍会把capability/configuration presence当作active path，而4.1的`MobileContinuityPathResolver`已具备actual-state真值规则。5.1将旧action入口改为generation-bound actual state并复用path resolver，不提前实现5.2 serialized media owner。
- 普通测试继续显式移除`LUNEX_RUN_KEYCHAIN_TEST`并使用Debug文件fallback；本项不查询、创建、启动或修改simulator，generic build不替代system PiP/background/physical证明。

## 2026-07-30 阶段 17 任务 5.1 完成

- 实现generation-bound `MobileContinuityActualMediaState`并让旧application action resolver复用既有actual-path resolver；只接受generation相等的native-confirmed active PiP+operational sink或active/permitted audio，capability/configuration presence不能产生active proof。
- 首轮focused `/tmp/LuneX-17-5_1-focused.fBgrS6/Focused.xcresult`通过`37/37`；自审补充missing generation与unsupported capability组合回归后，最终focused `/tmp/LuneX-17-5_1-focused-r2.OR9fN0/Focused.xcresult`通过`38/38`。expanded `/tmp/LuneX-17-5_1-expanded.WrwNk8/Expanded.xcresult`通过`104/104`，三份结果结构化诊断均为0。
- 完整macOS normal `/tmp/LuneX-17-5_1-full.3SUqwE/Full.xcresult`为`870 total / 869 passed / 1 skipped / 0 failed`；唯一skip精确为`HostAndPersistenceTests/testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，测试显式移除`LUNEX_RUN_KEYCHAIN_TEST`且未再次访问真实Keychain。
- 并行读取同一full xcresult的summary/build/tests明细触发一次Xcode临时`database.sqlite3`冲突；测试和bundle未失败，改为串行读取后确认唯一skip。该工具层失败已记录，后续同一bundle不再并发访问。
- 四平台generic Debug根`/tmp/LuneX-17-5_1-builds.bPoD3X`；macOS、iOS/iPadOS、tvOS、visionOS全部succeeded，error/warning/analyzer warning均为0并各有一个AIR与metallib。本项未查询、创建、启动或修改simulator。
- repository pre-gate `/tmp/LuneX-17-5_1-repository-pre.rCT2kx`从头通过fixture self-test/全树、OpenSpec strict `8/8`、勾选前apply `23/36 next 5.1`、generator三次稳定SHA-256 `e968c9a18cb1df83a6ec3be7c3eaf565c5ba571845ef45d79eddf01c895b4787`、source/test membership、actual-state静态边界、全部结果读回、唯一Keychain skip、Keychain opt-in关闭和`git diff --check`。
- OpenSpec 5.1已勾选，预期权威进度`24/36`、next 5.2；合同、路线图和三份planning文件已同步。5.1不证明serialized application owner、system PiP、后台持续时间、签名/安装、物理设备或live Sunshine。

## 2026-07-30 阶段 17 任务 5.2 启动

- 5.1已以`e2ce869 Require actual mobile continuity state`独立提交并推送；fetch确认`HEAD == origin/main == e2ce8692371a26d3ea6fa5edb6a5ea5a41428e0b`且工作树clean。OpenSpec为`24/36 ready`，next精确为5.2。
- 开始审计serialized mobile media generation owner；确认media environment已有actor serialization，但UIKit/AVKit runtime必须保留main-actor ownership，audio runtime event尚不携带actual mobile session active状态。
- 普通测试继续显式移除`LUNEX_RUN_KEYCHAIN_TEST`并使用Debug文件fallback；5.2不查询、创建、启动或修改simulator，不以generic build冒充system PiP/background行为。
- macOS更新后恢复执行并运行planning session catchup；Git仍仅有5.2调查跟踪文件修改，OpenSpec仍为`24/36 next 5.2`，长期阶段13至20目标保持active。
- 5.2实现合同确定为generation/revision scoped纯值plan + FIFO serialized action owner：PiP继续decoder/control且抑制foreground Metal，audio-only停止视频解码但保留audio/control，无合法路径typed pause，显式stop typed teardown，foreground转换触发一次resample/restoration。
- generator已更新production/test membership且`git diff --check`通过。首轮focused `/tmp/LuneX-17-5_2-focused-r1.6rJoKl/Focused.xcresult`在测试源码编译阶段停止、0项执行：Swift 6.3拒绝两个并发`Task`捕获非Sendable `XCTestCase self`；production无诊断。测试改为Task创建前构造不可变Sendable input，并将从全新证据目录重跑。
- 修正后focused r2 `/tmp/LuneX-17-5_2-focused-r2.Mp27RZ/Focused.xcresult`通过`21/21`且结构化三类诊断为0。自审后补“PiP -> audio-only -> last legal path lost”即时pause和higher-revision重复stop无副作用回归；最终focused `/tmp/LuneX-17-5_2-focused-final.uVo4ul/Focused.xcresult`通过`22/22`，下一步执行scene/PiP/audio/lifecycle/media environment扩大门禁。
- expanded `/tmp/LuneX-17-5_2-expanded.nNWvVN/Expanded.xcresult`通过`154/154 passed / 0 skipped / 0 failed`，覆盖owner、continuity、PiP state/lifecycle/presentation、mobile scene、mobile audio adapter、native audio processor、通用lifecycle和media environment；focused/expanded结构化error、warning、analyzer warning均为0。
- 完整macOS normal `/tmp/LuneX-17-5_2-full.d6TUCM/Full.xcresult`成功，串行结构化复核为`881 total / 880 passed / 1 skipped / 0 failed`，唯一skip精确为显式真实Keychain round-trip，三类结构化诊断为0。首次结果读回误并行访问同一bundle触发临时`database.sqlite3`竞争；未重跑测试，改为串行读取并确认bundle完整。
- 四平台generic Debug根`/tmp/LuneX-17-5_2-builds.XeS4Cp`全部succeeded；macOS、iOS/iPadOS、tvOS、visionOS的error/warning/analyzer warning均为0且各有至少一个AIR与metallib。构建只使用generic destination，没有查询、创建、启动或修改simulator。

## 2026-07-30 阶段 17 任务 5.2 完成

- repository pre-gate `/tmp/LuneX-17-5_2-repository-pre.bOvRUF`通过fixture self-test/全树、OpenSpec strict `8/8`、勾选前apply `24/36 next 5.2`、generator三次稳定SHA-256 `e82012e5c6afa4b9ad169d908d17017366917b4da7887b65d64c413cc178c03a`、source/test membership、UIKit/AVKit object boundary、production/reference boundary和`git diff --check`。
- 合同、路线图、OpenSpec task和三份planning文件已同步；OpenSpec 5.2勾选后预期权威进度`25/36`、next 5.3。5.4才把serialized owner接入`NativeSessionMediaEnvironment`和`AppModel`，本项不证明system PiP、background duration、signed configuration、物理设备、Stage Manager、external display、visible EDR、power或live Sunshine。
- 首轮repository final gate `/tmp/LuneX-17-5_2-repository-final.Gr8Ik2`在fixture/OpenSpec/generator/静态边界通过后、xcresult读回前退出：zsh函数局部变量`path`覆盖`PATH`，使`xcrun`不可见。该轮不计验收；没有运行测试、访问Keychain或操作simulator，后续使用显式Bash和`result_path`从全新目录完整重跑。
- 显式Bash最终门 `/tmp/LuneX-17-5_2-repository-final-r2.FpX1K6`完整通过：fixture self/tree、OpenSpec strict `8/8`、apply `25/36`且5.2 done/next 5.3、generator三次稳定、membership/platform-object/reference/diff、focused `22/22`、expanded `154/154`、full `881/880/1/0`唯一Keychain skip、四平台generic Debug零诊断及AIR/metallib均成立。

## 2026-07-30 阶段 17 任务 5.3 启动

- 5.2已以`7614b6f Serialize mobile media continuity`独立提交并推送；fetch确认`HEAD == origin/main == 7614b6f899681bc358df6294278f3af66125e0a7`且工作树clean。OpenSpec为`25/36 ready`，next精确为5.3。
- 审计发现`INFOPLIST_KEY_UIBackgroundModes = audio`虽然存在于三个target的build settings，但iPhoneOS、tvOS和visionOS实际built `Info.plist`均没有该键。5.3将新增iOS专用源plist的单值`audio`数组并验证Debug/Release built artifacts；配置、签名接受和runtime行为保持独立证据。
- Context7当前Apple索引未返回所需属性表细节；改用Apple 2026 DocC JSON、Xcode 26.4官方模板和本机公开SDK headers作为当前API/configuration证据。本项不访问真实Keychain，不创建、克隆、启动或修改simulator。
- 新增iOS专用`Configuration/Info/LuneX-iOS.plist`，其`UIBackgroundModes`为唯一`audio`值；generator显式设置`INFOPLIST_FILE`并移除iOS/tvOS/visionOS三个无效单值build setting。探针 `/tmp/LuneX-17-5_3-config-probe.j3rZDL` 的iPhoneOS Debug built plist精确读回`[\"audio\"]`、`CFBundleSupportedPlatforms == [\"iPhoneOS\"]`且结构化诊断为0。
- 正式矩阵 `/tmp/LuneX-17-5_3-build-matrix.LUMoL0` 的iPhoneOS Debug/Release、macOS/tvOS/visionOS Debug五个build均成功，逐项结构化诊断为0、unsigned且有AIR/metallib；尾部plist循环错误假设macOS plist也位于app根，实际在`Contents/Info.plist`，因此组合验证尚不计完成。保留完整build/xcresult，用bundle内结构化搜索重新验证，不重复编译。
- 配置矩阵validation r2在built plist读回前因`rg -c ... || true`把零匹配变为空字符串而退出；工程实际为iOS `INFOPLIST_FILE`精确2处、旧`INFOPLIST_KEY_UIBackgroundModes`在工程和generator中均0处。改用`grep -Ec`后重新只读同一批完整build产物。
- validation r3 `/tmp/LuneX-17-5_3-build-matrix.LUMoL0/validation-r3`完整通过：iPhoneOS Debug/Release源与built plist均精确`[\"audio\"]`，device family精确`[1,2]`；macOS/tvOS/visionOS built plist无该键；五个build均unsigned、三类结构化诊断为0且有AIR/metallib。
- 首轮repository pre-gate `/tmp/LuneX-17-5_3-repository-pre.YlPn5M`通过fixture、OpenSpec和generator稳定后，在build证据读回前因把plist在generator中的正确2处（membership + `INFOPLIST_FILE`）误断言为1而退出；该轮不计验收，修正计数后从全新目录完整重跑。

## 2026-07-30 阶段 17 任务 5.3 完成

- 完整macOS normal `/tmp/LuneX-17-5_3-full.iJCZfF/Full.xcresult`通过`881 total / 880 passed / 1 explicit Keychain skip / 0 failed`，三类结构化诊断为0；普通测试显式移除`LUNEX_RUN_KEYCHAIN_TEST`且未再次访问真实Keychain。
- repository pre-gate `/tmp/LuneX-17-5_3-repository-pre-r2.cCRbWz`完整通过fixtures、OpenSpec strict `8/8`、勾选前apply `25/36 next 5.3`、generator三次稳定SHA-256 `388c77a4a7db43c724f3cfd7b27cfc3dddb9d6294cd8c53a02796f7a2e959a95`、source/project/built配置、五个unsigned build、full结果、唯一Keychain skip和diff检查。
- 合同、路线图、OpenSpec task和三份planning文件已同步；5.3勾选后预期权威进度`26/36`、next 5.4。5.3不证明signed acceptance或runtime background行为，5.4开始接入actual state到media environment/AppModel。

## 2026-07-30 阶段 17 任务 5.3 系统更新后再认证

- 系统更新后确认macOS 27.0、Xcode 26.4、macOS/iPhoneOS SDK 26.4；OpenSpec strict、fixture self/tree、`git diff --check`和生成器连续两次稳定SHA-256 `388c77a4a7db43c724f3cfd7b27cfc3dddb9d6294cd8c53a02796f7a2e959a95`通过。
- macOS全量 `/tmp/LuneX-17-5_3-resume-macos.FuAdPk/Full.xcresult`通过`881/880/1/0`，唯一skip仍为显式真实Keychain round-trip且三类结构化诊断为0；本轮显式移除`LUNEX_RUN_KEYCHAIN_TEST`。
- iOS Debug `/tmp/LuneX-17-5_3-resume-ios.WLlh6B/Debug.xcresult`和Release `/tmp/LuneX-17-5_3-resume-ios-release.ba93Px/Release.xcresult`均在generic device上unsigned成功、三类结构化诊断为0，built plist精确读回`["audio"]`、`["iPhoneOS"]`和`[1,2]`。
- 首轮iOS包装器因沿用旧产物名`LuneX.app`在成功Debug build后退出；确认真实产物`LuneX-iOS.app`后只读复核Debug并仅补跑未开始的Release。没有查询、创建、启动或修改simulator。

## 2026-08-06 阶段 17 任务 5.4 启动

- 从active goal、planning-with-files、OpenSpec apply和Git恢复；`HEAD == origin/main == b6a157e`、工作树起始clean，OpenSpec权威进度`26/36 ready`且next精确为5.4。
- 系统更新后的5.3再认证已完成；当前任务限定为scene/geometry/PiP/continuity/mobile EDR和bounded diagnostics接入`NativeSessionMediaEnvironment`/`AppModel`，不提前实现5.5 UI。
- 验收顺序为generation/replacement/stop/failure focused tests、扩大media/AppModel/PiP/scene/EDR/audio矩阵、完整macOS normal、五平台generic warnings-as-errors build、fixture/OpenSpec/generator/source/privacy/diff门禁；普通测试显式移除`LUNEX_RUN_KEYCHAIN_TEST`，本项不创建、克隆、boot、launch或修改simulator。
- 系统更新后恢复的focused `/tmp/LuneX-17-5_4-focused-resume-1/Focused.xcresult`通过`9 passed / 0 skipped / 0 failed`，结构化error、warning、analyzer warning均为0；敏感的duplicate pending effect与late completion/replacement回归均未挂起。测试显式移除`LUNEX_RUN_KEYCHAIN_TEST`，没有访问真实Keychain或操作simulator。
- 首轮expanded `/tmp/LuneX-17-5_4-expanded-resume-1/Expanded.xcresult`为`293 total / 292 passed / 1 failed`，唯一失败是既有spatial application integration在并行负载下耗尽注入的1秒teardown grace，remote-input尾部resource未执行，因此该轮不计验收；结构化build diagnostics仍为0。隔离证据`/tmp/LuneX-17-5_4-failure-isolation-1/Isolation.xcresult`在0.018秒通过该项，局部将测试grace改为5秒后从全新目录重跑expanded。
- 第二轮expanded `/tmp/LuneX-17-5_4-expanded-resume-2/Expanded.xcresult`提高grace后仍为`292/1`且相同cleanup计数失败，推翻单纯超时判断。根因确认为environment stop在active清理前await mobile owner导致consumer-cancellation actor重入；production改为原子共享包含mobile stop的teardown operation，测试grace恢复原值，下一轮从全新证据目录验证。
- 确定性并发stop回归`/tmp/LuneX-17-5_4-stop-race-regression-1/Regression.xcresult`在系统更新后恢复运行但持续265秒未结束，线程样本确认XCTest等待异步case；主动中断后结果为`TEST INTERRUPTED`，不计验收。根因不是新的Xcode环境，而是测试第二阻塞点位于tracker最多1秒grace之后，200次纯yield等待提前失败且空恢复导致永久自锁。
- 测试编排已改为ContinuousClock两秒等待并返回成功状态；两个等待点使用guard，失败时`releaseAllBlocks()`禁用未来阻塞、恢复既有continuation并等待stop收敛。下一步从全新DerivedData/result bundle只重跑该确定性回归，先确认production共享完整teardown operation。
- 回归r2 `/tmp/LuneX-17-5_4-stop-race-regression-2/Regression.xcresult`在0.941秒正常退出，未再挂起；结构化结果`0 passed / 1 failed`且build三类诊断为0。唯一失败是stop后iterator先读到apply时未消费的`.mobileRuntime`事件；夹具已改为stop前读取并验证该队列事件，r2不计验收。
- 确定性回归r3 `/tmp/LuneX-17-5_4-stop-race-regression-3/Regression.xcresult`通过`1/1`且三类结构化诊断为0；证明并发stop共享包含mobile owner stop与resource tracker teardown的同一完整operation。下一步将原9项focused与该回归合并为最终10项门禁。
- 最终focused `/tmp/LuneX-17-5_4-focused-final-1/Focused.xcresult`通过`10 passed / 0 skipped / 0 failed`且结构化error、warning、analyzer warning均为0；普通测试显式移除`LUNEX_RUN_KEYCHAIN_TEST`。下一步从全新目录第三次运行expanded 16-suite矩阵，预期因新增回归从293增至294项。
- expanded第三轮 `/tmp/LuneX-17-5_4-expanded-resume-3/Expanded.xcresult`通过`294 passed / 0 skipped / 0 failed`且三类结构化诊断为0；原clean-stop并行失败已由共享完整teardown operation修复并在负载矩阵中验证。下一步重跑iOS generic Debug，再执行完整macOS normal suite。
- iOS generic Debug `/tmp/LuneX-17-5_4-ios-final-1/Build.xcresult`unsigned成功，结构化error、warning、analyzer warning均为0，built plist为`UIBackgroundModes == ["audio"]`且AIR/metallib存在；未查询或操作simulator。下一步运行完整macOS normal suite。
- 完整macOS normal `/tmp/LuneX-17-5_4-full-final-1/Full.xcresult`通过`890 total / 889 passed / 1 skipped / 0 failed`且结构化三类诊断为0；唯一skip由测试树精确确认为`HostAndPersistenceTests/testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`。普通测试显式移除opt-in，未再次访问真实Keychain。
- macOS/tvOS/visionOS generic Debug在`/tmp/LuneX-17-5_4-builds-final-1`均已成功，iOS证据位于`/tmp/LuneX-17-5_4-ios-final-1`；首轮只读组合汇总因zsh只读变量`status`退出，构建不重跑，改名后从既有结果串行读回。
- 修正后的只读汇总确认macOS、iOS/iPadOS、tvOS、visionOS四项均`succeeded / 0 errors / 0 warnings / 0 analyzer warnings / AIR>=1 / metallib>=1`；iOS plist为唯一`audio` background mode，tvOS/visionOS无该键。未查询、创建、启动或修改simulator。
- repository gate r1在fixture与OpenSpec strict `8/8`后因嵌套shell引用把jq `.state`拼成`..state`而退出，generator尚未执行且工作区无额外变化；该轮不计验收，从新目录使用直接jq表达式完整重跑。
- repository gate r2通过fixtures、strict、generator四次同哈希、membership与privacy后，依赖扫描误纳入`references/moonlight-ios`快照自带的`Package.resolved`而退出；reference tree未跟踪且不进production工程。扫描改为排除整个reference tree，从全新目录完整重跑。

## 2026-08-06 阶段 17 任务 5.4 action 接线修复进行中

- 补读`/tmp/LuneX-17-5_4-focused-audit-1/Focused.xcresult`：`10/10`通过，三类结构化诊断为0。
- 新增generation-scoped mobile audio/control application；media environment action client开始完整下发video/audio/control，暂停或停止时释放远程输入，并使当前paused/stopped control plan拒绝新输入。
- native audio processor开始实现独立mobile policy pause/resume，与系统interruption状态组合；control provider开始按revision保存实际directive并在pause/stop时拒绝IDR。已补environment action矩阵与audio interruption组合回归，尚待首次编译验收。

## 2026-08-06 阶段 17 任务 5.4 系统更新后继续

- 长期goal保持active，`HEAD == origin/main == b6a157e`，OpenSpec仍为`26/36 ready`且next为5.4；本轮继续显式移除`LUNEX_RUN_KEYCHAIN_TEST`，不访问真实Keychain，也不查询或操作simulator。
- 串行结构化读回补充action回归`/tmp/LuneX-17-5_4-action-focused.A311ae/Focused.xcresult`：`4 passed / 0 skipped / 0 failed`，error、warning、analyzer warning均为0。
- 串行结构化读回iOS generic Debug`/tmp/LuneX-17-5_4-action-ios.gm4YyX/Build.xcresult`：`succeeded`且三类诊断为0；built plist唯一`UIBackgroundModes == [audio]`、`UIDeviceFamily == [1,2]`，AIR与metallib存在。该证据只证明补丁在iPhoneOS 26.4 SDK下编译，不替代完整5.4重验收。
- action续审修复generation-scoped分步续跑、pending pause输入拒绝、audio成功后提交、video同application恢复重试与AppModel suspended/foreground phase往返；generator重建与`git diff --check`通过。
- 新focused`/tmp/LuneX-17-5_4-action-audit-focused-1/Focused.xcresult`结构化通过`6 passed / 0 skipped / 0 failed`且三类诊断为0，覆盖production control generation/IDR gate、pending input、故障续跑、AppModel phase及两种audio/system interruption组合。下一步补video恢复失败与audio media-services组合后形成正式focused集合。
- 系统更新后取回正式focused `/tmp/LuneX-17-5_4-action-focused-final/Focused.xcresult`最终状态：`18 total / 17 passed / 1 failed / 0 skipped`，build error、warning、analyzer warning均为0；唯一失败精确位于`SessionMediaEnvironmentTests.swift:478`，旧断言期望`input.release`一次但实际为两次。
- 失败不是并发stop重新拆分teardown：完整action接线后mobile `.stop` action立即释放一次输入，resource tracker在关闭input provider前再执行一次幂等兜底释放；测试已改为精确验证两个所有权层各一次。该失败bundle不计验收，下一步从全新DerivedData/result bundle重跑单项回归，再重跑正式18项focused。
- 修正后的单项回归`/tmp/LuneX-17-5_4-stop-race-action-r4.laAXrY/Regression.xcresult`结构化通过`1 passed / 0 skipped / 0 failed`，build error、warning、analyzer warning均为0，执行0.011秒正常收敛；证明两个并发stop仍共享同一个mobile stop与完整resource teardown，同时输入即时释放和teardown兜底各精确执行一次。下一步重跑正式18项focused。
- 正式focused r2 `/tmp/LuneX-17-5_4-action-focused-final-r2.wUolwc/Focused.xcresult`结构化通过`18 passed / 0 skipped / 0 failed`，build error、warning、analyzer warning均为0；覆盖generation/replacement/failure/stop、pending input、分步故障续跑、production control gate、audio interruption/media-services组合、video IDR恢复、AppModel phase和有界diagnostics。下一步运行16-suite expanded矩阵，实际项数以新结果树为准。
- 16-suite expanded r1 `/tmp/LuneX-17-5_4-action-expanded-final.RmuiJw/Expanded.xcresult`为`301 total / 300 passed / 1 failed / 0 skipped`，build三类结构化诊断为0；唯一失败是consumer-cancellation测试连续耗尽两个2秒`waitUntil`，该bundle不计验收。
- 失败项隔离`/tmp/LuneX-17-5_4-consumer-cancel-isolation.DGNCUP/Isolation.xcresult`在0.007秒通过。测试已改为等待consumer实际消费首个stream事件，而不是仅观察environment task计数；该项使用有界5秒并行负载窗口，两个超时guard都会取消consumer并显式stop，避免失败残留。下一步从全新目录重跑该项，再重跑完整expanded。
- 修正后consumer-cancellation回归`/tmp/LuneX-17-5_4-consumer-cancel-regression-r2.FG9clf/Regression.xcresult`结构化通过`1/1`，三类build诊断为0，执行0.008秒；下一步从全新目录重跑完整301项expanded矩阵。

## 2026-08-06 阶段 17 任务 5.4 更新后恢复

- 用户结束macOS更新后恢复执行；当前环境重新读回为macOS 27.0 build 26A5388g、Xcode 26.4 build 17E192，active goal保持不变，`HEAD == origin/main == b6a157e`，未提交5.4代码与untracked `Sources/LuneXCore/SessionMobileRuntime.swift`完整保留。
- planning catchup确认上轮唯一未同步执行点是expanded r2的结构化读回；OpenSpec apply仍为`26/36 ready`、next精确为5.4。普通测试继续显式移除`LUNEX_RUN_KEYCHAIN_TEST`，不访问真实Keychain，不查询或操作simulator。
- 待串行读回结果为`/tmp/LuneX-17-5_4-action-expanded-final-r2.U2uuha/Expanded.xcresult`；在读取summary与build diagnostics前不把该轮记为通过，也不勾选5.4。
- expanded r2已串行结构化读回：`301 total / 301 passed / 0 skipped / 0 failed`，build status succeeded，error、warning、analyzer warning均为0；证据明确运行于更新后的macOS 27.0。本门完成，下一步运行fresh完整macOS normal suite。
- fresh完整macOS normal `/tmp/LuneX-17-5_4-action-full-final.BwDZJ2/Full.xcresult`通过`898 total / 897 passed / 1 skipped / 0 failed`；唯一skip精确为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，结构化error、warning、analyzer warning均为0。命令显式移除`LUNEX_RUN_KEYCHAIN_TEST`，没有再次访问真实Keychain。
- Xcode启动时输出空build-number `DVTDeviceOperation`与multiple matching macOS architecture文本warning，但xcresult的实际build warning count为0，warnings-as-errors测试成功；将其保留为Xcode工具层消息，不误计为源码诊断。
- generic Debug app矩阵`/tmp/LuneX-17-5_4-action-builds-final.15Ul1N`完整退出成功：macOS、iOS/iPadOS、tvOS、visionOS四个独立xcresult均`succeeded`且error、warning、analyzer warning为0；每个平台均有精确1个AIR、1个metallib和1个app产物。
- iOS built plist精确读回`UIBackgroundModes == ["audio"]`、`UIDeviceFamily == [1,2]`；macOS/tvOS/visionOS均无`UIBackgroundModes`。全矩阵使用generic placeholder destination、`CODE_SIGNING_ALLOWED=NO`且未查询、启动或修改simulator；该证据不证明签名接受、system PiP或后台持续时间。
- 只读恢复旧`repository-pre-3`确认其曾在较早5.4工作树通过，但该门早于后续audio/control/video action接线，不能复用为当前最终证据。已从当前rollout恢复其精确fixture/OpenSpec/generator/membership/privacy/reference/plist/result/diff口径，将从新目录重跑并加入当前证据路径、ENet license和自有树无package dependency断言。
- action最终repository gate首轮`/tmp/LuneX-17-5_4-action-repository-final.tepjpV`在fixtures、OpenSpec、generator、membership、privacy/reference/license/dependency/plist、全部test/build结果和artifact读回均通过后，因Bash `set -u`直接展开未定义`LUNEX_RUN_KEYCHAIN_TEST`而退出；该轮不计验收。变量检查改为精确扫描`env`，从全新目录完整重跑。
- corrected repository gate r2 `/tmp/LuneX-17-5_4-action-repository-final-r2.Qziu2H`从头完整通过：fixtures、OpenSpec strict `8/8`与apply `26/36 next 5.4`、generator初始及连续三次稳定SHA-256 `e3e17f904f3c8d0fc9827e26a731f0c9de6a3f5b4339e8215608b2ac1d70f853`、四平台source/test membership、platform-object/privacy/forbidden-API边界、reference/package/license/plist、focused `18/18`、expanded `301/301`、full `898/897/1/0`、四平台build和Metal artifact读回、Keychain opt-in未设置及`git diff --check`。
- 合同inventory、5.4 application/media-environment集成章节、阶段路线图、OpenSpec task及三份planning状态已同步；5.4现已勾选，预期权威进度`27/36`、next 5.5。下一步运行勾选后的最终状态/repository/diff门，再独立提交并推送；5.5代码尚未开始。
- 首个勾选后final-state包装器因JavaScript模板内含未转义Markdown反引号，在shell启动前以`SyntaxError: Unexpected number`退出；没有创建证据目录或修改仓库。文档匹配改为无反引号固定文本后从新目录重跑。
- 第二次final-state包装器仍遗漏三条结果匹配中的Markdown反引号并在shell前同错退出；仓库仍无额外变化。记录该错误的首个补丁又因空hunk被整体拒绝，修正补丁后下一轮移除模板中的全部反引号，不再做局部替换。
- 勾选后final-state r3 `/tmp/LuneX-17-5_4-action-final-state-r3.qd2ejg`完整通过：OpenSpec strict `8/8`、apply精确`27/36 next 5.5`且5.4 done、generator初始及连续三次稳定SHA-256 `e3e17f904f3c8d0fc9827e26a731f0c9de6a3f5b4339e8215608b2ac1d70f853`、合同/路线图无旧5.4 gap、privacy/API/reference/dependency/license/plist、focused `18/18`、expanded `301/301`、full `898/897/1/0`和四平台build/Metal证据均通过。5.4可独立提交推送，5.5尚未开始。
## 2026-08-06 阶段 17 任务 5.4 提交与 5.5 启动

- 5.4 提交前 `git diff --check` 和 staged scope 复核通过，新增 `Sources/LuneXCore/SessionMobileRuntime.swift` 已显式纳入；提交为 `77cac48 Integrate mobile runtime application state`。
- `git push origin main` 成功，fetch 后 `HEAD == origin/main == 77cac48fe295a58a9cb3432242f319647c625079`，工作树 clean。
- OpenSpec apply 为 `27/36 ready`、next 5.5。已开始只读提取 actual-state UI、PiP commands、continuity settings、compact/wide layout、localization 和 migration 合同，尚未修改 production UI。
- 初始代码审计确认 5.5 将集中修改 `AppSettings` migration、`AppModel` PiP command/value projection 与 `RootView` 的 stream/settings UI；production coordinator 与 actual runtime ownership 已存在，不新增第二套 PiP 状态机。
- UI 结构审计确认沿用既有 `ViewThatFits`/size-class 模式扩展 compact/wide，状态与偏好分别展示；下一步精读 coordinator 命令签名和 AppModel generation 字段后开始 production edits。
- 首次追加该审计记录时因补丁上下文混入繁体字符导致完整拒绝，production 文件无变化；已改用精确现有上下文重新应用。
- AppModel ownership 与 persistence 复核完成：actual state teardown 已闭合，5.5 不增加状态缓存；continuity migration 沿用现有 audio migration 的 Codable/repository 测试模式。
- 5.5 production 设计确定：新增共享 actual-state projection，AppModel 仅做 generation-safe PiP command bridge，RootView 消费 typed status 构建 accessible compact/wide UI；现在开始修改源码、生成器和 focused tests。
- 首次 value focused `/tmp/LuneX-17-5_5-value-focused.9nhxZP/Focused.xcresult` 在编译期失败：新 projection 误用了文件私有 `MobileDisplayEDRStateNormalizer.maximumHeadroom`；测试未运行。展示层改为同合同的私有有界常量 `64`，不改变 runtime normalizer 封装或验证语义。
- value focused r2 `/tmp/LuneX-17-5_5-value-focused-r2.iNGnjV/Focused.xcresult` 已越过 production 编译，测试夹具仍直接调用文件私有 EDR normalizer 而编译失败；改为通过真实 `MobileDisplayEDRSnapshotPublisher.update()` 构造状态后重跑。
- value focused r3 `/tmp/LuneX-17-5_5-value-focused-r3.e9Ldj3/Focused.xcresult` 通过新增 7 项 actual-state resolver 与 1 项 continuity migration，共 `8/8`。
- 首次 iOS UI generic build `/tmp/LuneX-17-5_5-ui-ios.o3Po6j/Build.xcresult` 在 `RootView.swift` 编译失败：局部 `@Bindable` getter 缺显式 return、两个 String/Text 包装位置颠倒，且补丁字符串转义丢失 EDR 插值反斜杠；均已按精确行修正，该 build 不计验收。
- iOS UI generic build r2 `/tmp/LuneX-17-5_5-ui-ios-r2.xLWbI4/Build.xcresult` 成功，结构化 summary 为 succeeded、0 errors、0 warnings、0 analyzer warnings；未查询或操作 simulator。
- build 后语义审计将 presentation resolver 的 session truth 从 `session.isStreaming` 收紧为 AppModel 实际仍持有的匹配 stream/media generation，确保 stopping 期间 actual 状态持续到 teardown 清空。
- 首次批量补测试补丁也曾因 generator 测试列表顺序假设错误而完整拒绝；已拆分并按实际成员位置成功应用，未产生半份测试文件。
- 5.5正式focused `/tmp/LuneX-17-5_5-focused.xrpILI/Focused.xcresult` 通过 `9 passed / 0 skipped / 0 failed`；expanded `/tmp/LuneX-17-5_5-expanded.4eDReh/Expanded.xcresult` 串行结构化读回为 `220 total / 219 passed / 1 skipped / 0 failed`，唯一skip精确为 `HostAndPersistenceTests/testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`。普通测试显式移除 `LUNEX_RUN_KEYCHAIN_TEST`，没有再次访问真实Keychain。
- 四平台generic Debug结果分别为 `/tmp/LuneX-17-5_5-build-macOS.GXj1up/Build.xcresult`、`/tmp/LuneX-17-5_5-build-iOS.MteT4o/Build.xcresult`、`/tmp/LuneX-17-5_5-build-tvOS.oCtGE5/Build.xcresult` 与 `/tmp/LuneX-17-5_5-build-visionOS.DzOKpU/Build.xcresult`；逐份串行读回均为 `succeeded / 0 errors / 0 warnings / 0 analyzer warnings`。全部使用generic placeholder、isolated DerivedData/xcresult、unsigned warnings-as-errors配置，未查询或操作simulator。
- 首次四平台包装器因工具策略拒绝固定目录的 `rm -rf` 而在任何build启动前退出，该轮不计验收；改为 `mktemp -d` 后完成上述四份独立结果。generic build只证明四SDK编译边界，不证明签名、安装、system PiP、后台持续时间、Stage Manager、visible EDR或物理输入/空间音频。
- fresh完整macOS normal `/tmp/LuneX-17-5_5-full.AFYgqg/Full.xcresult` 通过 `906 total / 905 passed / 1 skipped / 0 failed`；唯一skip精确为 `HostAndPersistenceTests/testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，结构化error、warning、analyzer warning均为0。命令显式移除 `LUNEX_RUN_KEYCHAIN_TEST`，继续使用文件/内存fallback。
- 5.5生成器审计已连续两次稳定重建 `LuneX.xcodeproj/project.pbxproj`，SHA-256均为 `78cab89798454bcb0bf629e42832423747475eee64165a42f04fbaebf106f817`；新production/test source在generator与工程membership中均存在，`git diff --check`通过。
- 首轮repository gate把 `Tools/validate_protocol_fixtures.py` 的可选fixture-root误传为仓库根 `.`，因此按设计命中未跟踪 `build/`、文档与 `references/` 内的UUID/哈希并退出；该轮不计验收，源码、fixture和工作树未被修改。OpenSpec strict在同轮已通过 `8/8`；后续改用工具默认 `Tests/Fixtures/Moonlight` 口径并从全新证据目录重跑完整repository gate。
- corrected repository gate `/tmp/LuneX-17-5_5-repository-pre.JEHdsa` 已通过fixtures、OpenSpec、generator、membership、UI合同及privacy/API扫描，但reference隔离正则同时匹配了用户明确要求保留的 `Tools/import_moonlight_qt_data.py` 内合法 `moonlight-qt` 数据源标识，因而退出且不计验收。三处匹配均不在production或Xcode graph；口径收紧为禁止实际 `references/` 路径进入 `Sources`、工程和generator，再从全新目录完整重跑。
- repository gate r2 `/tmp/LuneX-17-5_5-repository-pre-r2.uDkXvU` 已通过fixtures、OpenSpec、generator/membership、UI/privacy/reference/dependency/license与plist，随后测试结果读回函数使用局部变量名 `path`，覆盖zsh特殊 `path/PATH` 并使 `xcrun` 不可见；该轮不计验收。修正为显式Bash和 `result_path` 后从全新目录完整重跑，不重复任何build/test。
- repository pre-gate r3 `/tmp/LuneX-17-5_5-repository-pre-r3.CQDfTT` 从头完整通过：fixture self/tree、OpenSpec strict `8/8`与apply `27/36 next 5.5`、generator初始及连续三次稳定SHA-256 `78cab89798454bcb0bf629e42832423747475eee64165a42f04fbaebf106f817`、四平台compiler/test membership、UI/accessibility/localization静态合同、generation command边界、privacy/forbidden API、reference/dependency/ENet license、source/built plist、focused `9/9`、expanded `220/219/1/0`、fresh full `906/905/1/0`、四平台build零结构化诊断、Keychain opt-in未设置及diff检查。
- 5.5合同、路线图、OpenSpec task与三份planning文件已同步；5.5勾选后权威进度预期为`28/36`、next 5.6。下一步运行勾选后的final-state gate，再独立提交并推送；5.6回归扩展不得混入5.5提交。
- 续接后的首个只读编排在shell前因JavaScript局部变量覆盖工具命名空间退出；随后两轮final-state包装器分别因含Markdown反引号的静态断言与错误的coordinator字段名在test/build结果读回前退出。三轮均未重跑测试/构建或改变production行为；错误已记入`task_plan.md`，最终口径改为无反引号固定语义匹配和真实`mobilePictureInPictureCoordinator`字段。
- 5.5勾选后final-state r3 `/tmp/LuneX-17-5_5-final-state-r3.fivSJ8`从头通过：fixture self/tree、OpenSpec strict `8/8`、apply精确`28/36 next 5.6`且5.5 done、generator初始及连续三次稳定SHA-256 `78cab89798454bcb0bf629e42832423747475eee64165a42f04fbaebf106f817`、source/test membership、路线图/合同/planning当前状态、UI/accessibility/localization、generation command、privacy/API、reference/dependency/ENet license、source/built plist、focused `9/9`、expanded `220/219/1/0`、fresh full `906/905/1/0`、四平台build零结构化诊断、Keychain opt-in未设置及`git diff --check`。
- 路线图顶部阶段17汇总已从旧`27/36`/“5.5未完成”修正为`28/36`，明确5.5 actual-state UI/PiP commands/migration已完成，5.6与6.x仍待完成。5.5现在可独立提交并推送；物理system PiP、signed background、background duration、Stage Manager、external display、visible EDR、物理输入/空间音频、power/thermal与live Sunshine证明仍保持未完成。

## 2026-08-06 阶段 17 任务 5.5 提交与 5.6 启动

- 5.5提交为`6792840 Expose mobile continuity runtime state`并成功推送；fetch后`HEAD == origin/main == 67928408ceb90eb734c5ec6e90dca26838b14ffa`，工作树clean。
- OpenSpec apply为`28/36 ready`、next精确5.6。现有owner与media-environment测试已分别覆盖policy loss、audio-only、active PiP、foreground restore、replacement和shared clean teardown；5.6缺口收敛为AppModel跨层联合回归、diagnostic replacement ownership、actual-state UI/accessibility/localization合同与malformed continuity migration。
- 首次把test和tracking合并的补丁因`findings.md`尾句与实际文件不符被整体拒绝，三个test文件均未发生半份修改；已拆分并按真实上下文落盘。
- 5.6新增三类测试且不改production runtime：连续驱动AppModel的PiP、audio-only、policy loss、foreground restore、stop、replacement和第二次clean stop；静态验证RootView只用actual state并保留responsive/accessibility/localized interpolation；验证continuity malformed stored type fail closed。
- 5.6 focused `/tmp/LuneX-17-5_6-focused.3oZ597/Focused.xcresult`结构化通过`3 passed / 0 skipped / 0 failed`，build status succeeded且error、warning、analyzer warning均为0。普通测试显式移除`LUNEX_RUN_KEYCHAIN_TEST`，未操作simulator。
- 5.6 expanded `/tmp/LuneX-17-5_6-expanded.rMzx7g/Expanded.xcresult`覆盖12个AppModel/mobile owner/media environment/continuity/UI/diagnostic/persistence/PiP/scene/EDR suite，串行结构化读回为`246 total / 245 passed / 1 skipped / 0 failed`；唯一skip精确为`HostAndPersistenceTests/testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，build status `succeeded`且error、warning、analyzer warning均为0。命令显式移除`LUNEX_RUN_KEYCHAIN_TEST`，未查询或操作simulator。
- 5.6 fresh full macOS `/tmp/LuneX-17-5_6-full.vIdYY6/Full.xcresult`串行结构化读回为`909 total / 908 passed / 1 skipped / 0 failed`，唯一skip精确为显式真实Keychain round-trip；build status `succeeded`且error、warning、analyzer warning均为0。普通测试继续显式移除Keychain opt-in并使用文件/内存fallback。
- 5.6四平台generic Debug分别为`/tmp/LuneX-17-5_6-build-macOS.Cx4asx/Build.xcresult`、`/tmp/LuneX-17-5_6-build-iOS.0SUvDM/Build.xcresult`、`/tmp/LuneX-17-5_6-build-tvOS.pgu2WY/Build.xcresult`和`/tmp/LuneX-17-5_6-build-visionOS.DrKxPQ/Build.xcresult`；全部`succeeded/0/0/0`且各有AIR/metallib。iOS built plist为`UIBackgroundModes == ["audio"]`、`UIDeviceFamily == [1,2]`，其余平台无后台模式键。
- 5.6 repository pre-gate `/tmp/LuneX-17-5_6-repository-pre.yLerRh`从头通过fixtures、OpenSpec strict `8/8`与勾选前apply `28/36 next 5.6`、generator四次稳定SHA-256 `78cab89798454bcb0bf629e42832423747475eee64165a42f04fbaebf106f817`、membership/artifacts、UI/accessibility/localization、privacy/API、reference/dependency/ENet license、source/built plist、focused/expanded/full/四平台结果、Keychain opt-in未设置与diff检查。
- 合同、路线图、OpenSpec 5.6与三份planning文件已同步；5.6勾选后权威进度预期为`29/36`、next 6.1。下一步运行final-state gate，再独立提交并推送；本项没有修改production runtime、访问真实Keychain或操作simulator。
- 5.6勾选后final-state r2 `/tmp/LuneX-17-5_6-final-state-r2.RXA6yF`完整通过：fixture、OpenSpec strict `8/8`、apply精确`29/36 next 6.1`、generator四次稳定SHA-256、production diff clean、精确九文件scope、membership/docs/privacy/API/reference/dependency/license/plist、focused `3/3`、expanded `246/245/1/0`、full `909/908/1/0`、四平台build、Keychain opt-in未设置与diff检查。首轮包装器仅在shell前因Markdown反引号触发JavaScript语法错误，未运行门禁或改仓库，已记录并用无反引号匹配纠正。

## 2026-08-06 阶段 17 任务 5.6 提交与 6.1 启动

- 5.6提交为`d88533f Expand mobile continuity regression coverage`并成功推送；fetch后`HEAD == origin/main == d88533f6a2cba0b17f491dfccd3cbbe4ddc2fda7`，工作树clean。
- OpenSpec apply为`29/36 ready`、next精确6.1。6.1将从提交态重新运行完整macOS normal suite，显式移除真实Keychain/live-host opt-in，精确断言唯一skip并串行读取同一xcresult；不操作simulator。
- 6.1提交态normal `/tmp/LuneX-17-6_1-normal.8bwnco/Normal.xcresult`通过`909 total / 908 passed / 1 skipped / 0 failed / 0 expected failure`；唯一skip精确为真实Keychain round-trip，build status `succeeded`且error、warning、analyzer warning均为0。命令显式移除真实Keychain与live-host opt-in，未操作simulator。
- 6.1 repository pre-gate `/tmp/LuneX-17-6_1-repository-pre.QcX64y`通过fixture、OpenSpec strict `8/8`与勾选前apply `29/36 next 6.1`、generator稳定、normal结果与唯一skip读回、全部opt-in未设置和diff检查。OpenSpec 6.1已勾选，预期权威进度`30/36`、next 6.2。
- 6.1勾选后final-state `/tmp/LuneX-17-6_1-final-state.p8fbkL`通过fixture、OpenSpec strict `8/8`、apply精确`30/36 next 6.2`、generator稳定、合同/路线图当前态、normal `909/908/1/0`、唯一Keychain skip、全部opt-in未设置与diff检查；6.1可独立提交推送。

## 2026-08-06 阶段 17 任务 6.1 提交与 6.2 启动

- 6.1提交为`90fefbd Verify normal mobile continuity regression gate`并成功推送；fetch后`HEAD == origin/main == 90fefbd0bc4c52ed5af379b0b062c4f71af1cf5b`，工作树clean。
- OpenSpec apply为`30/36 ready`、next 6.2。6.2将构建macOS、固定iPhone、固定iPad、tvOS、visionOS的Debug/Release十配置；所有build隔离、禁用签名、warnings-as-errors、移除Keychain/live opt-in，固定simulator只作build destination且不执行生命周期操作。

## 2026-08-06 阶段 17 任务 6.2 完成

- `/tmp/LuneX-17-6_2-builds.ORyQlN`保留macOS、固定iPhone、固定iPad、tvOS与visionOS的Debug/Release十个独立DerivedData/result bundle；五个Debug沿用系统更新前已成功证据，只补跑缺失的五个Release，未重复构建Debug。
- 十份xcresult逐份串行结构化读回均为`succeeded / 0 errors / 0 warnings / 0 analyzer warnings`；每配置各有一份Metal AIR和metallib。iPhone/iPad产物为`iphonesimulator`、`UIDeviceFamily [1,2]`与单一`UIBackgroundModes [audio]`，其余平台无后台模式键。
- 首轮xcresult包装器因zsh保留只读变量`status`在第一份读回时退出；没有重跑任何build，改用Bash和`build_status`后从原bundle完成十项验收。
- 只执行一次post simulator inventory查询；pre/post规范化清单逐字一致，SHA-256同为`0470edc00aea815358b4bed51fa43b73b79a5cbc61f80856f9630c6128568d41`。固定iPhone/iPad各唯一、available、`Shutdown`且全局`Booted=0`，未create/clone/boot/install/launch/shutdown/delete设备。
- repository pre-gate `/tmp/LuneX-17-6_2-repository-pre.MR2Y1N`从头通过fixture self/tree、OpenSpec strict `8/8`与勾选前apply `30/36 next 6.2`、generator三次稳定SHA-256、十build/Metal/plist/simulator、Keychain opt-in未设置和`git diff --check`。
- OpenSpec 6.2已勾选，预期权威进度`31/36`、next 6.3。unsigned build-only证据不证明签名安装、system PiP、background duration、Stage Manager、visible EDR、物理输入/空间音频、功耗/热状态或live Sunshine。
- 勾选后final-state `/tmp/LuneX-17-6_2-final-state.lP9mOL`通过fixture、OpenSpec strict `8/8`、apply精确`31/36 next 6.3`、generator/docs、十build/Metal、simulator不变、Keychain opt-in未设置和diff检查。首轮final-state包装器仅在shell启动前因Markdown反引号触发JavaScript解析错误，未执行任何门禁或设备操作。

## 2026-08-06 阶段 17 任务 6.2 提交与 6.3 启动

- 6.2提交为`db4255c Verify mobile continuity platform builds`并成功推送；fetch后`HEAD == origin/main == db4255c9f5e49fb93780eb256d6df93422fa613e`，工作树clean。
- OpenSpec apply为`31/36 ready`、next精确6.3。6.3限定为repository/static analyzer门，不重复6.2 build、不运行normal/sanitizer/resource、不访问真实Keychain或查询/操作simulator。

## 2026-08-06 阶段 17 任务 6.3 完成

- repository/API gate `/tmp/LuneX-17-6_3-repository.NHQpyc`从头通过fixture self/tree、OpenSpec strict `8/8`与勾选前apply `31/36 next 6.3`、generator稳定SHA-256、全部source/test membership、clean-room/reference/SPM隔离、固定ENet revision/license/逐文件一致、iOS单一`audio` source plist、privacy/forbidden API、iOS mobile public API probe和四SDK AVKit/ENet strict compile。
- iOS API probe覆盖effective scene geometry、potential/current EDR headroom、registered trait changes、sample-buffer renderer及sample-buffer PiP content source/controller；只提供iOS 26.4 SDK availability，不声称物理runtime active。
- macOS Debug/Release analyzer保存在`/tmp/LuneX-17-6_3-analyzer.ZbHqMU`，两项均`succeeded`、0 error、0 compiler warning、4 analyzer finding。normalized finding逐项一致且全部属于byte-identical固定ENet；LuneX自有Sources与bridge finding为0。
- ENet 4项为3个unused store及1个`unix.c` generic nullable local-address dereference；production bridge不调用raw socket receive，vendor唯一production调用同时传入peer/local address，因此当前调用路径受约束，但finding仍作为第三方残余风险保留。
- 历史strict C命令搜索首轮因`rg`模式以`-W`开头被当作选项退出，只读查询未影响编译；改用`rg --`后完成。普通环境无任何`LUNEX_*`opt-in，本项没有运行测试、访问Keychain或查询/操作simulator。
- OpenSpec 6.3已勾选，预期权威进度`32/36`、next 6.4；下一步运行勾选后的final-state gate并独立提交推送。
- 勾选后final-state `/tmp/LuneX-17-6_3-final-state.U9aRrJ`通过fixture self/tree、OpenSpec strict `8/8`、apply精确`32/36 next 6.4`、generator、repository/API retained evidence、Debug/Release analyzer归属、docs、Keychain opt-in未设置和`git diff --check`。

## 2026-08-06 阶段 17 任务 6.3 提交与 6.4 启动

- 6.3提交为`ef0168c Verify mobile continuity repository gates`并成功推送；fetch后`HEAD == origin/main == ef0168cab7dba7b7461396c2eeb116ee5c4a90da`，工作树clean。
- OpenSpec apply为`32/36 ready`、next精确6.4。将以完整ASan、完整TSan和16-suite强化malloc/resource三份独立证据覆盖PiP frame/backpressure release、scene/screen observer cancellation、generation replacement和restoration completion；不访问真实Keychain或操作simulator。

## 2026-08-06 阶段 17 任务 6.4 完成

- 完整ASan `/tmp/LuneX-17-6_4-asan.wtKUhx`通过`909 total / 908 passed / 1 skipped / 0 failed / 0 expected failure`，唯一skip为真实Keychain opt-in，结构化diagnostics为0且日志无AddressSanitizer/LeakSanitizer报告。
- 完整TSan `/tmp/LuneX-17-6_4-tsan.7v8bx9`同样通过`909/908/1/0`、唯一Keychain skip、零结构化diagnostics和零ThreadSanitizer report；两项均显式移除`LUNEX_RUN_KEYCHAIN_TEST`、关闭coverage并串行测试。
- 强化malloc/resource `/tmp/LuneX-17-6_4-resource.6jwPh7`启用scribble/pre-scribble/guard edges/stack logging/逐分配heap check/error abort，精确16-suite通过`320/320`、0 skip、零结构化diagnostics和零allocator report；suite清单与预期逐字一致。
- 首轮repository pre-gate在generator后退出且未保留具体失败断言；全部retained evidence与当前环境随后只读通过。第二轮`/tmp/LuneX-17-6_4-repository-pre-r2.Ciyhr6`的checkpoints通过到reports，随后`pgrep -f`误匹配包装器自身命令行的`xcodebuild.log`路径；按进程名连续查询确认实际无测试进程。
- corrected pre-gate r3 `/tmp/LuneX-17-6_4-repository-pre-r3.M8A6Ib`从头通过fixture self/tree、OpenSpec strict `8/8`与勾选前apply `32/36 next 6.4`、generator三次稳定、ASan/TSan/resource结构化结果与报告、精确进程名、Keychain opt-in未设置和`git diff --check`。
- OpenSpec 6.4已勾选，预期权威进度`33/36`、next 6.5；下一步运行勾选后的final-state gate并独立提交推送。本项未查询或操作simulator。
- 首轮final-state唯一失败是全局精确进程名门命中另一个工作区`/Users/tanmy/Projects/TamaCore`正在运行的xctest；没有终止或干扰该进程。收紧为只匹配LuneX仓库/证据路径后，final-state r2 `/tmp/LuneX-17-6_4-final-state-r2.LbWI04`通过fixture、strict `8/8`、apply精确`33/36 next 6.5`、generator、三份结果、docs、LuneX无残留进程、Keychain opt-in和diff检查。

## 2026-08-06 阶段 17 任务 6.4 提交与 6.5 完成

- 6.4提交为`81b656e Verify mobile continuity memory safety`并成功推送；fetch后`HEAD == origin/main == 81b656ebc2c2f7404cc51444dcfc5b521fc379ea`，工作树clean。OpenSpec apply为`33/36 ready`、next精确6.5。
- 系统恢复后环境仍为macOS 27.0 build `26A5388g`、Xcode 26.4 build `17E192`。本项只进行一次CoreSimulator inventory读取；`/tmp/LuneX-17-6_5-simulator-audit.wNPE0P`证明6.2 pre/post/current规范化清单逐字一致且SHA-256均为`0470edc00aea815358b4bed51fa43b73b79a5cbc61f80856f9630c6128568d41`。
- 固定iOS 26.4 iPhone/iPad identity和UUID均各唯一、available、`Shutdown`，全局`Booted=0`。iOS 27.0同名默认实例按不同runtime披露且也保持`Shutdown`；没有创建、克隆或运行重复设备。
- 复用并只读验收6.2的固定iPhone/iPad Debug/Release四份build：全部`succeeded/0/0/0`、destination匹配固定UUID、各有AIR/metallib，built plist为`iphonesimulator`、family `[1,2]`和单一`audio`。没有重复build。
- 工程没有UI-test product target或XCUIApplication harness；因此没有启动、安装或launch-only伪UI门。本项未执行任何simulator生命周期变更，也未访问真实Keychain。OpenSpec 6.5已勾选，预期权威进度`34/36`、next 6.6；下一步运行勾选后的final-state gate并独立提交推送。
- 勾选后final-state `/tmp/LuneX-17-6_5-final-state-r2.GDMtqY`通过fixture、OpenSpec strict `8/8`、apply精确`34/36 next 6.6`、generator稳定、pre/post/current inventory、固定identity、四build/Metal/plist、UI target absent/no launch、simulator mutation none、Keychain opt-in未设置、无LuneX残留进程和diff检查。首轮final-state只因把中文UI边界误断言为英文固定短语退出；全部实质门已先通过且未重复simulator查询/build/test。

## 2026-08-06 阶段 17 任务 6.5 提交与 6.7 封版

- 6.5提交为`4ebfbc7 Verify mobile continuity simulator inventory`并成功推送；fetch后`HEAD == origin/main == 4ebfbc7f6e58f1ac6a66cd1412d0e3a4aa2d97b7`，工作树clean。OpenSpec为`34/36 ready`，pending 6.6和6.7。
- 6.6缺少授权signed physical iPhone/iPad、provisioning、system PiP/background duration、Stage Manager/external display、visible EDR、空间音频、live Sunshine和power/thermal证据，保持unchecked；不以simulator/offline结果替代。
- 6.7同步mobile continuity合同、runtime roadmap、OpenSpec与三份planning文件，修正simulator tier为identity/state/build及“有真实target才执行UI path”，新增五级proof matrix、6.6 receipt隐私/场景要求、唯一pending与不可archive边界。
- 6.7勾选后预期OpenSpec为`35/36 in_progress`且唯一pending 6.6。下一步执行strict/generator/docs/retained evidence final-state门、独立提交推送，再在已推送HEAD执行阶段17 fresh normal离线自验；测试继续移除真实Keychain opt-in且不操作simulator。
- 勾选后final-state `/tmp/LuneX-17-6_7-final-state-r2.3enrxA`通过fixture、strict `8/8`、apply精确`35/36 only 6.6 pending`、generator、normal `909/908/1 exact Keychain/0`、十build、analyzer归属、ASan/TSan/resource、fixed simulator、五级proof docs、Keychain opt-in、LuneX进程和diff检查。首轮读取不存在的skip清单虽未令包装器失败但不计干净最终证据；r2从保留`tests.json`精确验证唯一Skipped节点且未重复test/build/simulator。

## 2026-08-07 阶段 17 离线阶段级自验

- 6.7提交为`c7c9089 Document mobile continuity acceptance boundary`并成功推送；fetch后`HEAD == origin/main == c7c9089a965eb1eea100b84e844f87ab003f939d`，起始工作树clean。
- 从该提交用全新DerivedData/result bundle运行fresh完整macOS normal `/tmp/LuneX-17-stage-acceptance.xnt9je`，显式移除`LUNEX_RUN_KEYCHAIN_TEST`；结构化结果为`909 total / 908 passed / 1 skipped / 0 failed / 0 expected failure`，唯一skip精确为真实Keychain opt-in用例，build `succeeded`且error/warning/analyzer warning为0。
- 阶段组合门`/tmp/LuneX-17-stage-acceptance-final.k8BdmF`通过HEAD/remote parity、clean tree、fixture、strict `8/8`、apply精确`35/36 only 6.6 pending`、generator稳定、fresh normal、fixed simulator no-launch/no-mutation、Keychain opt-in unset、无残留LuneX进程与diff检查。
- 本自验没有再次访问真实Keychain，也没有查询、创建、启动或运行simulator；6.6 signed physical receipt保持唯一缺口，阶段17保持`in_progress`。记录提交推送后进入阶段18，不以阶段18证据回填6.6。

## 2026-08-07 阶段 18 OpenSpec 提案完成

- 阶段17自验记录已以`52ee4f5 Record mobile continuity stage acceptance`提交并推送，`HEAD == origin/main`且工作树clean后进入阶段18；阶段17仍为`35/36 in_progress`且6.6不变。
- 创建OpenSpec `integrate-tvos-visionos-runtime`，完成proposal、design、四份spec和50项tasks。能力覆盖tvOS remote/focus/controller与media/HDR/audio，以及visionOS actual window/input与windowed media/HDR/spatial audio。
- 设计固定main-actor平台对象、immutable generation/revision snapshot、单decoder/Metal/audio/session graph、ordered held release、system-reserved command、typed HDR/input/spatial fallback、privacy diagnostics与离线/simulator/signed/physical/live证明分层；Moonlight上游仅作只读行为参考。
- 首轮strict的5项spec因validator要求requirement首段显式`SHALL/MUST`而失败；改成`LuneX SHALL ...`规范首句后通过`9/9`。apply当前`0/50 ready`、next 1.1 inventory；proposal阶段没有修改production/test/generator，也未访问Keychain或操作simulator。

## 2026-08-07 阶段 18 任务 1.1 恢复与只读盘点

- 完成系统更新后的仓库、目标、工具链与OpenSpec恢复：`HEAD == origin/main == 4411f55`、工作树clean、active goal不变，OpenSpec `integrate-tvos-visionos-runtime`为`0/50 ready`且next 1.1。
- 重读全部OpenSpec context、三份planning文件、generator、RootView/Metal surface、tvOS remote/focus、GameController、HDR与audio/spatial现有实现；确认tvOS/visionOS尚无与current generation接线的actual platform owner。
- 仅一次读取simulator inventory，固定26.4 Apple TV UUID为`6C0EC809-4C15-4AEC-9470-00F91480CAA7`、Vision Pro UUID为`9BF41D0C-B423-4B3F-B75D-00B31E85FE18`，两者均available/Shutdown，全局Booted为0；披露27.0同名默认设备且未做任何生命周期操作。
- 完成Xcode 26.4 public SDK header精查：tvOS旧`wantsExtendedDynamicRangeContent`/`EDRMetadata`明确不可用，但SDK 26新增`preferredDynamicRange`/`contentsHeadroom`并保留screen headroom；visionOS的`UIScreen`/`UIWindowScene.screen`不可用，公开output-node intended spatial experience取代listener属性。
- 新增283行`docs/runtime/tvos-visionos-runtime-contract.md`，覆盖proof tiers、target/config、当前product ownership、tvOS输入/媒体、visionOS窗口/输入/媒体、API矩阵、固定simulator与physical/live/clean-room边界；自验确认`Sources/Tests/Tools/Configuration`行为diff为0。
- 勾选OpenSpec 1.1并同步runtime roadmap、`task_plan.md`、`findings.md`和`progress.md`，预期apply为`1/50 ready`、next 1.2；下一步运行strict/generator/repository final-state，独立提交并推送。
- final-state `/tmp/LuneX-18-1_1-final-state.H9NGtH`通过：fixture self/tree、OpenSpec strict `9/9`、apply精确`1/50 next 1.2`、generator 4次同哈希、target/config/entitlement、Xcode 26.4 API header、合同结构/privacy、clean-room/package/reference、runtime behavior diff 0与diff检查均通过。
- final-state明确`LUNEX_RUN_KEYCHAIN_TEST`和live-host opt-in未设置；未重跑build/test，未重复`simctl` inventory，也未执行任何simulator生命周期操作。下一步为1.1独立commit/push，然后进入1.2。

## 2026-08-07 阶段 18 任务 1.2 完成

- 从`1b88f5a`恢复未提交1.2代码，生成工程并修正测试`ReversedCollection`到Array。新增immutable checked platform presentation foundation及13项确定性测试，shared层无UIKit/GameController/AVFoundation/Metal framework对象。
- 语义审计把display headroom改为显式`unavailable/platform-reported` source，避免把visionOS当前无公开finite source写成永久禁止；补充`.none` audio strategy与head-tracking unavailable一致性。tvOS pointer继续按26.4 public API边界拒绝。
- 首轮代码focused`13/13`通过；语义修正后首轮fresh focused因Optional `.none`歧义被warnings-as-errors拒绝，显式类型修正后`/tmp/LuneX-18-1_2-focused-final2.V3FbgD`重新通过`13/13`。
- fresh完整macOS normal`/tmp/LuneX-18-1_2-normal.I2XCvy`通过`922/921/1/0`，唯一skip精确为显式真实Keychain round-trip；Keychain/live-host opt-in均unset。
- `/tmp/LuneX-18-1_2-builds.t1EbLt`保留macOS、固定iPhone/iPad/Apple TV/Vision Pro五份Debug build；全部`succeeded`且结构化error/warning/analyzer warning为0，新source membership/编译成立。没有create/clone/boot/install/launch/run/shutdown/delete或重复inventory。
- repository gate首轮因旧OpenSpec summary字段退出；第二轮因PBX membership双份文本计数口径退出。最终`/tmp/LuneX-18-1_2-repository-pre-r3.QwpaS0`从头通过fixtures、strict`9/9`、apply`1/50`、generator四次同哈希、membership、platform-object/privacy/reference和diff检查。
- 勾选OpenSpec 1.2并同步runtime合同、roadmap及三份planning文件，预期权威进度`2/50 ready`、next 1.3；下一步运行勾选后final-state并独立提交推送。
- 勾选后final-state`/tmp/LuneX-18-1_2-final-state.215ooC`完整通过strict`9/9`、apply`2/50 next 1.3`、retained focused/normal/五平台build、generator四次稳定、docs/membership/reference/platform-object、精确变更范围、Keychain/live opt-in、LuneX进程和diff门；未重跑test/build或查询/操作simulator。

## 2026-08-07 阶段 18 任务 1.3 恢复与首轮编译

- macOS更新完成后从`e79246a`恢复：`HEAD == origin/main`，active goal不变，OpenSpec `integrate-tvos-visionos-runtime`为`2/50 ready`、next 1.3；工作树只有1.3纯值合同、测试和generator membership。
- 重读planning skill、OpenSpec apply skill及proposal/design/四份spec/tasks；生成工程后`git diff --check`通过，未查询或操作simulator，Keychain/live-host opt-in继续显式移除。
- 首轮fresh focused证据`/tmp/LuneX-18-1_3-focused-first.2LRtZM`在Swift编译阶段失败，唯一代码错误是测试helper把`Int` slot传给`UInt8`；production合同已完成编译。修复helper时同步收紧release plan的press/controller分域错误、duplicate和reserved-state校验，下一步重新运行fresh focused。
- 首次同时追加source/test/planning的patch因`findings.md`上下文选择错误而在应用前原子失败，未产生半应用状态；随后拆分为code/test和各planning文件的精确patch。
- 修复测试helper后从全新证据目录运行focused final `/tmp/LuneX-18-1_3-focused-final.vfmkpn`，16项全部通过、0 fail/skip，结构化build error/warning/analyzer warning均为0。
- fresh完整macOS normal `/tmp/LuneX-18-1_3-normal.X2XdFh`通过`938 total / 937 passed / 1 skipped / 0 failed`，唯一skip仍是显式真实Keychain round-trip；Keychain/live-host opt-in均移除，没有再次访问真实Keychain。
- 五平台Debug `/tmp/LuneX-18-1_3-builds.H78vE4`中macOS、固定iPhone/iPad/Apple TV/Vision Pro全部`succeeded`，结构化error/warning/analyzer warning为0且每份均有AIR/metallib；仅使用固定UUID作为build destination，没有simulator inventory或生命周期操作。
- source/test语义审计确认local/stream ownership、六个remote按钮、reserved Menu/system command、balanced token、16-slot exact roster、lease-aware feedback和close admission -> remove handlers -> reverse button-up -> provider barrier -> restore focus顺序完整；合同不持有UIKit/GameController/AVFoundation/Metal对象或可持久化身份。
- 对新文件运行无仓库配置的`swift-format lint --strict`产生默认2-space与项目4-space不一致的非权威报告；不重写源码，后续以warnings-as-errors、结构化xcresult、`git diff --check`和人工diff作为格式/编译门。
- 已同步runtime contract、roadmap及三份planning文件；下一步执行fixture/OpenSpec/generator/membership/privacy/reference/repository pre-gate，通过后才勾选1.3并运行final-state。
- repository pre-gate `/tmp/LuneX-18-1_3-repository-pre.cR5mnp`通过fixture self/tree、OpenSpec strict `9/9`、apply精确`2/50 next 1.3`、generator SHA-256 `755323bf392b901cb0443bf5b2fc116a69b740b67f7e2930dd3c10c601c26779`连续4次稳定、五target/test membership、framework-object/privacy/reference、Keychain/live opt-in、无xcodebuild/xctest与diff门。
- pre-gate通过后勾选OpenSpec 1.3；下一步运行勾选后final-state，预期权威进度`3/50 ready`、next 1.4，不重复focused/normal/build或simulator inventory。
- 勾选后首个只读OpenSpec摘要因Python单行f-string转义错误退出，仓库未受影响；改用heredoc从JSON解析并确认`3/50 ready`、next 1.4，没有重复build/test或设备操作。
- 首个final-state包装器因未转义Markdown反引号在shell启动前退出；第二轮通过OpenSpec/generator/retained evidence后因文档`Actual stream-surface`句首大小写断言退出。两次都没有重复build/test或设备操作。
- 最终勾选后final-state `/tmp/LuneX-18-1_3-final-state-r2.piTqXW`完整通过：OpenSpec strict `9/9`、apply `3/50 next 1.4`、generator SHA-256 `755323bf392b901cb0443bf5b2fc116a69b740b67f7e2930dd3c10c601c26779`、retained focused `16/16`、normal `938/937/1 exact Keychain/0`、五build `succeeded/0/0/0`、五份AIR/metallib、精确十文件scope、docs/reference/opt-in/进程和diff门。

## 2026-08-07 阶段 18 任务 1.4 启动

- 1.3已提交推送为`d55d08c`，fetch后`HEAD == origin/main == d55d08cc108fd751846b5b27a236aea3b92186fa`且工作树clean；OpenSpec为`3/50 ready`、next 1.4。
- 重读visionOS window/input与media spec、design、1.2 platform foundation及既有held-release合同，确定1.4只新增pure-value effect/admission/presentation状态，不持有UIKit/RealityKit/GameController对象或连接actual runtime。
- 设计固定windowed mode与四类完整typed unavailable feature；输入只覆盖现有public capability snapshot的controller/keyboard/pointer/indirect paths；system/gaze/hand交互只有local reserve/drop。
- release reducer区分focus loss与teardown：两者都close admission并等待provider held-release barrier，只有teardown取消system observers和释放surface lease；released phase让重复stop返回零effect。
- 生成工程后首轮fresh focused `/tmp/LuneX-18-1_4-focused-first.M8I5D6`在测试编译阶段退出，唯一源码诊断是test helper的throwing nil-coalescing fallback缺少`try`；production合同已完成编译。修正后将从全新证据目录重跑。
- fresh focused final `/tmp/LuneX-18-1_4-focused-final.nm9d5D`通过`15/15`、0 skip/fail/expected failure，结构化build error/warning/analyzer warning均为0；覆盖windowed/unavailable、snapshot consistency、admission、system interaction、ordered release、idempotency与controller ownership。
- 下一步运行fresh完整macOS normal，再对macOS和固定26.4 iPhone/iPad/Apple TV/Vision Pro运行五平台Debug build；继续显式移除Keychain/live opt-in，不执行simulator inventory或生命周期操作。
- fresh完整macOS normal `/tmp/LuneX-18-1_4-normal.9HxEOi`通过`953 total / 952 passed / 1 skipped / 0 failed`，唯一skip精确为显式真实Keychain round-trip，0 expected failure且结构化build error/warning/analyzer warning为0。
- 五平台Debug `/tmp/LuneX-18-1_4-builds.9dNTC6`中macOS、固定iPhone/iPad/Apple TV/Vision Pro全部`succeeded/0 error/0 warning/0 analyzer warning`，每份均有一个AIR和一个metallib；固定UUID只作build destination，未读取或操作simulator。
- 已同步runtime contract、roadmap与三份planning文件；下一步执行repository pre-gate，通过后才勾选1.4并确认`4/50 next 1.5`。
- repository pre-gate `/tmp/LuneX-18-1_4-repository-pre.y4G7Md`通过fixture self/tree、OpenSpec strict `9/9`、apply精确`3/50 next 1.4`、generator SHA-256 `4b641128ba2139552abc2319671e0e4749b818167b5f9151ada3ac16c80774b0`连续4次稳定、五target/test membership、framework-object/remote-effect/privacy/reference、retained evidence、Keychain/live opt-in、进程与diff门。
- pre-gate通过后勾选OpenSpec 1.4；下一步确认`4/50 ready`、next 1.5并运行勾选后final-state，不重复focused/normal/build或simulator inventory。
- 勾选后确认OpenSpec为`4/50 ready`、next 1.5；状态文档已同步，下一步运行final-state并复用已成功的focused/normal/五build证据。
- 勾选后final-state `/tmp/LuneX-18-1_4-final-state.Hjcn6D`一次完整通过：OpenSpec strict `9/9`、apply `4/50 next 1.5`、generator SHA-256 `4b641128ba2139552abc2319671e0e4749b818167b5f9151ada3ac16c80774b0`、retained focused `15/15`、normal `953/952/1 exact Keychain/0`、五build `succeeded/0/0/0`、五份AIR/metallib、精确十文件scope、docs/framework/reference/opt-in/进程和diff门。

## 2026-08-07 阶段 18 任务 1.5 启动

- 1.4已提交推送为`165e0f6`，fetch后`HEAD == origin/main == 165e0f6fe1d11ef7d681a933da249675843ab48e`且工作树clean；OpenSpec为`4/50 ready`、next 1.5。
- 完成1.2–1.4测试矩阵审计，确认大部分边界已有单点覆盖；新增范围收紧为nonfinite controller adapter fail-closed、全generation/capability/geometry矩阵、max controller held-release、reserved no-remote及aggregate privacy serialization门。
- 本项优先修改既有test class，不新增重复contract或test target；只有adapter nonfinite路径需要最小production修复。
- macOS 27.0更新后恢复active goal并重读planning/OpenSpec全部上下文；Xcode 26.4及macOS/iOS/tvOS/visionOS 26.4 SDK可用，`HEAD == origin/main == 165e0f6`，没有查询或操作simulator。
- 已完成1.5实现与测试补丁：controller element拒绝NaN/Infinity并使用不含identity的固定drop reason；新增全generation exhaustion、geometry failure、platform capability、16-slot release、全reserved no-remote及runtime aggregate non-Encodable隐私矩阵。下一步从全新证据目录运行四类focused tests。
- 首轮fresh focused `/tmp/LuneX-18-1_5-focused.JHzHJc`在production编译阶段退出：加入nonfinite `guard`后原单表达式函数不再允许隐式返回，唯一源码错误为`InputAdapterOutput` initializer unused；测试没有执行。补充显式`return`后从全新证据目录重跑。
- 修复后的fresh focused `/tmp/LuneX-18-1_5-focused-final.TwI9GK`结构化通过`58/58 passed / 0 skipped / 0 failed / 0 expected failure`，build `succeeded`且error/warning/analyzer warning均为0；新增8项边界测试全部执行。命令显式移除Keychain/live-host opt-in且只使用macOS destination。
- fresh完整macOS normal `/tmp/LuneX-18-1_5-normal.Ii5uKb`结构化通过`961 total / 960 passed / 1 skipped / 0 failed / 0 expected failure`；唯一skip精确为`HostAndPersistenceTests/testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，build `succeeded`且error/warning/analyzer warning均为0。命令显式移除Keychain/live-host opt-in，继续使用文件/内存fallback。
- 五平台Debug `/tmp/LuneX-18-1_5-builds.epxn6e`中macOS、固定26.4 iPhone/iPad/Apple TV/Vision Pro全部`succeeded/0 error/0 warning/0 analyzer warning`，每个平台各有1份AIR和1份metallib；UUID只作build destination，没有simulator inventory或create/clone/boot/install/launch/run/shutdown/delete。
- 首个合同/roadmap/planning组合patch因合同文件换行锚点不精确被`apply_patch`原子拒绝，未产生部分修改；改用稳定标题和精确行拆分后完成同步。
- 已同步stage 18 runtime contract、roadmap及三份planning文件，保持OpenSpec `4/50 next 1.5`直到repository pre-gate通过；当前证据明确不提升为actual handler/runtime、physical device或live Sunshine证明。
- repository pre-gate `/tmp/LuneX-18-1_5-repository-pre.35UmDy`从头通过fixture self/tree、OpenSpec strict `9/9`、勾选前apply `4/50 next 1.5`、generator连续4次稳定SHA-256 `4b641128ba2139552abc2319671e0e4749b818167b5f9151ada3ac16c80774b0`、五target/test membership、nonfinite固定drop reason、8项新增测试、七类aggregate non-Encodable隐私边界、retained focused/normal/五build、精确十文件scope、reference/opt-in/进程与`git diff --check`。
- pre-gate通过后已勾选OpenSpec 1.5并同步权威进度为`5/50 ready`、next 1.6；下一步运行只读final-state，不重复focused/normal/build或simulator inventory。
- 勾选后final-state首轮误用不存在的`Fixtures/Protocol`根，在generator和xcresult读取前立即退出；这不是产品、构建或测试失败。读取validator默认根后从新目录完整重跑。
- final-state `/tmp/LuneX-18-1_5-final-state-r2.bBdtCr`通过fixtures、strict `9/9`、apply `5/50 next 1.6`、generator四次稳定同哈希、retained focused `58/58`、normal `961/960/1 exact Keychain/0`、五build `succeeded/0/0/0`、五平台AIR/metallib、精确十一文件scope、docs/privacy/reference/opt-in/进程与diff检查；没有重复测试、构建或simulator inventory。

## 2026-08-07 阶段 18 任务 1.6 启动

- 1.5已提交推送为`eb0ecc1`，fetch后`HEAD == origin/main == eb0ecc18b35f653444d6204f20592cfbd77d76de`且工作树clean；OpenSpec为`5/50 ready`、next 1.6。
- 已盘点既有阶段15/16/17 API合同、阶段18 public API矩阵及Xcode 26.4 tvOS/visionOS SDK headers。1.6将用仓库外临时Swift源分别验证正向可用API和预期失败的unavailable/deprecated边界，不把header存在或编译成功提升为runtime/physical proof。
- 本项不新增production runtime，不查询或操作simulator，不访问真实Keychain；probe evidence仅保存在`/tmp`，仓库只同步合同、路线图、OpenSpec和planning状态。
- 首轮两份UI probe因Swift 6.3拒绝Objective-C名称`UIWindowSceneGeometry`而失败；API在Swift中导入为`UIWindowScene.Geometry`。修正仓库外临时源后tvOS/visionOS UI probe均零诊断通过，production与仓库源码未受影响。
- 初步负向假设中的tvOS `GCMouse`实际零诊断编译，因此从expected-unavailable矩阵移除并以current/list/movement handler正向probe重验；该结果只证明SDK symbol surface，不改变当前tvOS pointer-unadvertised产品合同。
- 最终`/tmp/LuneX-18-1_6-api.ZD2a58`机器门通过：12类正向源在simulator/device SDK共`24/24`成功且零诊断，6类unavailable/deprecated源在两类SDK共`12/12`预期失败、0 unexpected success；保存toolchain、source、command/log/status和SHA-256。
- tvOS head-pose entitlement源码及Debug/Release build setting存在；visionOS无entitlement文件或`CODE_SIGN_ENTITLEMENTS`。probe全程没有simctl、runtime、签名/安装、物理设备、Keychain或live-host调用。
- 已同步runtime contract、roadmap及三份planning文件，OpenSpec保持`5/50 next 1.6`直到repository pre-gate通过；本项不需要重跑未受影响的normal或五平台app build。
- 首轮repository pre-gate `/tmp/LuneX-18-1_6-repository-pre.Xc0mN4`在fixtures、strict、apply与generator四次稳定后，因为把实际18个临时probe源误断言为19而退出；API/entitlement/doc/scope后续门尚未执行。修正计数并改用`plistlib`读取带点号entitlement key后从新目录完整重跑。
- repository pre-gate `/tmp/LuneX-18-1_6-repository-pre-r2.WVVlEP`通过fixtures、strict `9/9`、勾选前apply `5/50 next 1.6`、generator四次稳定同哈希、API正向/负向状态与诊断、toolchain/SDK、entitlement差异、精确五文件scope、reference/production/opt-in/进程和diff检查。
- pre-gate通过后已勾选OpenSpec 1.6并同步权威进度为`6/50 ready`、next 2.1；下一步只读final-state，不重跑app测试/构建或查询simulator。
- 勾选后final-state `/tmp/LuneX-18-1_6-final-state.e4uqxq`一次通过fixtures、strict `9/9`、apply `6/50 next 2.1`、generator四次同哈希、API `24/24 + 12/12`与诊断、entitlement差异、精确六文件scope、reference/production/opt-in/进程和diff检查；未执行app测试/构建、simctl、runtime或Keychain。

## 2026-08-07 阶段 18 任务 2.1 启动

- 系统更新后恢复检查通过：active goal不变，`HEAD == origin/main == cfee986c14c622c36448b3b735e9f2aa4e20b55c`、工作树clean；Xcode 26.4、Swift 6.3、tvOS/visionOS 26.4 SDK可用，OpenSpec为`6/50 ready`、next 2.1。
- 重读planning/OpenSpec skills、全部change context、三份planning文件及surface/mobile lifecycle/presenter tests/generator；没有查询或操作simulator，也没有访问真实Keychain。
- 确认2.1只新增tvOS/visionOS actual UIKit Metal view callback boundary：attachment/layout trigger与actual scene/visibility/scale/drawable/focus reading，配套replacement、late callback、weak ownership和幂等dismantle测试；generation owner、geometry normalization与application接线分别保留给2.2–2.5。
- 完成2.1实现：新增七类raw callback、generic state/relay和仅tvOS/visionOS编译的actual `TVVisionStreamMetalView`；SwiftUI make/update/dismantle分别创建、替换handler/刷新及失效callback，阶段17 iOS/iPadOS pipeline不变。
- focused final `/tmp/LuneX-18-2_1-focused-final.Dn6Ogw`通过`2/2`；direct tvOS `/tmp/LuneX-18-2_1-tvos-final.7cwVUt`与visionOS `/tmp/LuneX-18-2_1-visionos-final.9SGGGX` compile均成功。
- fresh normal `/tmp/LuneX-18-2_1-normal.qH028K`通过`963 total / 962 passed / 1 skipped / 0 failed`，唯一skip是显式真实Keychain round trip；Keychain/live-host opt-in均unset。
- 五平台Debug `/tmp/LuneX-18-2_1-builds.mherO0`中macOS、固定iPhone/iPad/Apple TV/Vision Pro均`succeeded/0/0/0`且各有AIR/metallib；无本任务build/test残留进程，没有查询或操作simulator。
- 已人工审阅完整code/test diff并同步runtime contract、roadmap及三份planning文件；OpenSpec保持`6/50 next 2.1`直到repository pre-gate通过。
- repository pre-gate `/tmp/LuneX-18-2_1-repository-pre.raFP1x`从头通过fixture self/tree、OpenSpec strict `9/9`与apply `6/50 next 2.1`、generator四次稳定同哈希、精确七文件scope、callback/weak ownership/iOS isolation/privacy/reference、retained focused/normal/五build、opt-in/进程及diff检查。
- pre-gate通过后已勾选OpenSpec 2.1并同步路线图与planning状态；预期权威进度`7/50 ready`、next 2.2，下一步运行只读final-state，不重复test/build或simulator inventory。
- 勾选后final-state `/tmp/LuneX-18-2_1-final-state.dAGCFP`从头通过fixture、strict `9/9`、apply精确`7/50 next 2.2`、generator四次同哈希、retained focused `2/2`、normal `963/962/1 exact Keychain/0`、五build `succeeded/0/0/0`、精确八文件scope、docs/privacy/reference/opt-in/进程与diff检查；2.1可独立提交推送。
- post-record人工diff发现状态补丁的通用锚点误命中历史阶段17任务5.6；production、tests和OpenSpec未受影响。已恢复历史行并仅将阶段18任务2.1标记为`complete`，随后重新运行轻量门。

## 2026-08-07 阶段 18 任务 2.2 启动

- 2.1已提交推送为`4069cc2`，fetch后`HEAD == origin/main == 4069cc2fc769f5c30afebb574390e335b5f34c56`且工作树clean；OpenSpec为`7/50 ready`、next 2.2。
- 重读2.2 change context、TVVision immutable contracts、2.1 raw callback bridge与阶段17 mobile attachment/lifecycle/geometry owner；确认visionOS不能采用`UIScreen`假设。
- 2.2将实现actual surface-only main-actor generation owner、checked immutable state与actual view接线；stale不发布、detach/invalid fail closed、weak ownership和idempotent invalidation。geometry revision/render/input/AppModel保持后置。
- 已完成2.2第一版实现与tests：generic owner/state/status/outcome验证surface generation/domain、actual identity/activity、tvOS screen、finite scale/drawable和focus/visibility；actual tvOS/visionOS view生成surface generation并在raw callback后驱动owner，SwiftUI暴露update handler且dismantle失效owner。
- 新增5项focused回归覆盖actual attachment/activity、detach/invalid recovery、visionOS no-screen、stale/late/invalidation、weak platform ownership及错误generation domain；下一步生成工程并运行2.1+2.2共7项focused tests。
- 首轮focused `/tmp/LuneX-18-2_2-focused-first.8da8sW`在测试执行前因Swift不允许initializer argument list内的条件编译而失败；owner本体尚无语义诊断。已把platform和resolver改为完整表达式的静态helper，将从全新证据目录重跑。
- 第二轮focused `/tmp/LuneX-18-2_2-focused-second.H4rge7`已通过production编译，但test fixture的无类型`.infinity`在`CGSize`中产生单一ambiguous诊断，0 tests执行；改为`CGFloat.infinity`后从新目录重跑。
- focused final `/tmp/LuneX-18-2_2-focused-final.lEpy5T`通过`7/7 passed / 0 skipped / 0 failed / 0 expected failure`；下一步分别编译actual tvOS与visionOS分支，再运行fresh normal。
- actual tvOS `/tmp/LuneX-18-2_2-tvos-first.DBIgFD`与visionOS `/tmp/LuneX-18-2_2-vision-first.qHmlwO`分支均`succeeded/0/0/0`；fresh normal `/tmp/LuneX-18-2_2-normal.YmP9ZH`通过`968/967/1 exact Keychain skip/0`。
- 五平台Debug `/tmp/LuneX-18-2_2-builds.TV1lzR`全部`succeeded/0 error/0 warning/0 analyzer warning`。语义复核后补充actual current-scene lifecycle token replacement/removal与六类invalid-state exact matrix，需从新目录重跑focused/normal/build受影响证据。
- 补强后focused `/tmp/LuneX-18-2_2-focused-final2.VLhqfP`通过`8/8`，actual tvOS `/tmp/LuneX-18-2_2-tvos-final.CSOrKb`与visionOS `/tmp/LuneX-18-2_2-vision-final.wkfDYn`均零诊断编译。
- final normal `/tmp/LuneX-18-2_2-normal-final.jGEblk`通过`969/968/1 exact Keychain skip/0`；final五平台Debug `/tmp/LuneX-18-2_2-builds-final.5K2Eqp`全部`succeeded/0 error/0 warning/0 analyzer warning`。
- 已同步runtime contract、roadmap及三份planning文件；OpenSpec保持`7/50 next 2.2`直到repository pre-gate通过，下一步人工diff与repository gate。
- macOS更新结束后恢复检查确认`HEAD == origin/main == 4069cc2`且七个2.2工作文件完整；主机为macOS 27.0、Xcode 26.4，active goal与OpenSpec `7/50 next 2.2`不变。
- 新工具链focused `/tmp/LuneX-18-2_2-focused-macos27.5VXuwb`通过`8/8`；fresh normal `/tmp/LuneX-18-2_2-normal-macos27.APoh6b`通过`969/968/1 exact Keychain skip/0`，真实Keychain/live-host opt-in显式移除。
- 五平台Debug复验`/tmp/LuneX-18-2_2-builds-macos27.IgW5lP`全部`succeeded/0 error/0 warning/0 analyzer warning`并各有一份AIR/metallib；固定26.4 UUID精确命中预定destination，仅执行build，没有读取或操作simulator。
- 人工diff复核确认weak framework ownership、invalid/detach fail-closed顺序、stale/late callback静默、actual current-scene token replacement/removal、visionOS无`UIScreen`、无`connectedScenes`且未越界实现2.3；下一步执行repository pre-gate。
- repository pre-gate `/tmp/LuneX-18-2_2-repository-pre-macos27.NmlEN1`完整通过fixtures、OpenSpec strict `9/9`与apply `7/50 next 2.2`、generator四次稳定、七文件scope、owner/membership/privacy/reference、focused `8/8`、normal `969/968/1/0`、五build/Metal、opt-in、进程与diff检查。
- pre-gate通过后已勾选OpenSpec 2.2并同步路线图与planning状态；预期权威进度`8/50 ready`、next 2.3。下一步只读final-state，不重复test/build或simulator inventory。
- 勾选后首轮final-state `/tmp/LuneX-18-2_2-final-state-macos27.Q9gSPi`已通过strict `9/9`、apply `8/50 next 2.3`、generator四次同哈希、八文件scope与diff检查，随后因合同目标短语跨两行而单行`rg`断言退出；该轮不计最终验收，未重复test/build/simulator，改为分别匹配两行后从新目录重跑。
- 修正后的勾选后final-state `/tmp/LuneX-18-2_2-final-state-macos27-r2.zjXtZr`从头通过fixtures、OpenSpec strict `9/9`与apply `8/50 next 2.3`、generator四次稳定、八文件scope、docs/owner/privacy/reference、retained focused/normal/五build/Metal、opt-in/进程及diff检查；2.2可独立提交推送。
- 2.2已提交推送为`488d99f`，fetch后`HEAD == origin/main == 488d99f4e08435b0f71018830d3d806a925f7431`且工作树clean；OpenSpec为`8/50 ready`、next 2.3。
- 重读2.3 specs/design、TVVision immutable geometry/snapshot、阶段17 mobile geometry owner、shared `StreamCoordinateSnapshot`/`InputMapper`、presenter与actual tvOS/visionOS view接线；确认2.3需由actual bounds/scale正向驱动drawable/render/input reference，并用单一semantic revision去重。
- 计划新增surface-local geometry binding owner和窄presenter coordinate application；callback类别不推进revision，invalid/detach/stale/revision exhaustion fail closed。2.4 coordinator、2.5 AppModel及actual platform input adapter保持后置。
- 完成2.3第一版production与focused tests：actual bounds/safe-area/scale正向生成drawable，scene/render/input共享`TVVisionSemanticRevision`，SwiftUI coordinator应用exact coordinate snapshot；新增6项测试并修复coordinate unavailable未清零drawable的fail-closed缺口。`git diff --check`通过，下一步运行generator和fresh focused compile/test。
- 首轮focused evidence `/tmp/LuneX-18-2_3-focused-first.Lf0vbb`因预检误匹配wrapper自身而在`xcodebuild`前退出，属于测试脚本错误而非源码/测试失败；记录后将用`pgrep -x xcodebuild`从fresh目录重跑。
- 第二轮focused `/tmp/LuneX-18-2_3-focused-second.R6XNb6`通过全部源码编译并执行14项，结果`13 passed / 1 failed`；唯一失败为invalid-geometry test helper将NaN转换为Int导致trap。已改用有限surface drawable构造generation state，并记录xcresult必须串行读取，下一步fresh重跑。
- fresh focused final `/tmp/LuneX-18-2_3-focused-final.3ydyxX`结构化通过`14/14 passed / 0 skipped / 0 failed / 0 expected failure`，build `succeeded`且error/warning/analyzer warning均为0；下一步direct tvOS与visionOS actual分支build。
- direct tvOS `/tmp/LuneX-18-2_3-tvos.z5gn3n`与visionOS `/tmp/LuneX-18-2_3-vision.vvrgyu` actual条件分支均结构化`succeeded/0/0/0`且各有AIR/metallib；只使用固定build destination，没有simulator inventory或生命周期操作。下一步fresh normal suite。
- fresh normal `/tmp/LuneX-18-2_3-normal.LQmuaL`通过`975/974/1 exact Keychain skip/0`；五平台Debug `/tmp/LuneX-18-2_3-builds.a3spj2`全部`succeeded/0/0/0`并各有AIR/metallib。已完成人工code/test diff与合同/roadmap/planning同步，下一步repository pre-gate，OpenSpec仍保持`8/50 next 2.3`。
- repository pre-gate `/tmp/LuneX-18-2_3-repository-pre.z6jCCO`完整通过后已勾选OpenSpec 2.3并同步为预期`9/50 ready`、next 2.4；下一步运行只读final-state，复用已通过的focused/normal/五build证据，不重复测试、构建或simulator inventory。
- 勾选后final-state `/tmp/LuneX-18-2_3-final-state.LZtrAB`完整通过fixtures、strict `9/9`、apply `9/50 next 2.4`、generator固定哈希、精确十文件scope、retained focused `14/14`、normal `975/974/1/0`、五平台build/Metal、privacy/opt-in/进程和diff检查；2.3状态为complete，下一步轻量post-record gate、人工diff、独立commit/push/fetch parity。
- 记录补齐后轻量post-record `/tmp/LuneX-18-2_3-post-record.zzaiMr`通过OpenSpec `9/50 next 2.4`、十文件scope、project哈希、四处final-state路径、retained evidence、空xcodebuild/xctest和diff检查；没有重跑test/build或读取/操作simulator，下一步最终人工diff与commit/push/fetch parity。
- 最终人工diff发现tvOS/visionOS actual `MTKView`仍允许系统默认auto-resize，与geometry owner唯一drawable writer合同冲突；已在`TVVisionStreamMetalView`初始化设置`autoResizeDrawable = false`。首次构建预检只读发现外部TamaSwift Release `xcodebuild` PID 93371，未终止或干扰，等待其自行结束后才启动LuneX验证。
- drawable-owner修复后fresh focused `/tmp/LuneX-18-2_3-owner-fix-focused.kY6Oxo`通过`14/14`且结构化诊断为0；direct tvOS `/tmp/LuneX-18-2_3-owner-fix-tvos.FCNNmM`与visionOS `/tmp/LuneX-18-2_3-owner-fix-vision.1Feeyo`均`succeeded/0/0/0`并各有一份AIR/metallib。固定UUID只作build destination，没有simulator inventory或生命周期操作；下一步修订后轻量final gate。
- 首轮修订final gate `/tmp/LuneX-18-2_3-final-amend.18u1Sh`在只读证据循环中把zsh特殊数组`path`作为变量，覆盖`PATH`后找不到`jq`；此前检查无失败且未修改仓库或重复test/build。变量改为`evidence_path`后，`/tmp/LuneX-18-2_3-final-amend-r2.0HXOJm`从头通过`9/50 next 2.4`、十文件scope、generator、single drawable writer、新三份与retained证据、opt-in/进程及diff门；2.3可提交推送。
- 2.3已提交推送为`f4b34ed Add tvOS visionOS geometry binding`；fetch后`HEAD == origin/main == f4b34ed2435f361f5fffaf1773e965a4024213a1`、工作树clean，OpenSpec为`9/50 ready`、next 2.4。
- 启动2.4：将盘点现有presentation source/presenter、HDR/audio route snapshot、diagnostic、generation replacement和resource teardown模式，设计shared serialized coordinator；2.5 media/AppModel及3.x–6.x actual platform wiring保持后置。真实Keychain/live-host禁用，不查询或操作simulator生命周期。
- 完成2.4首轮coordinator/action/test实现并生成工程membership；静态审计修复XCTest async autoclosure、scene-close旧sequence、terminal snapshot failure吞错和presentation component误归因。fresh focused `/tmp/LuneX-18-2_4-focused.aQS6ye`通过`8/8`，warnings-as-errors下编译与测试成功。
- focused后继续补强FIFO suspended-effect序列化、incomplete input `.inputUnavailable`、foreign session隔离、sequence exhaustion及old decoder generation rejection；OpenSpec仍保持`9/50 next 2.4`，需从全新目录重跑focused后再进入平台/normal验收。
- 第二轮focused `/tmp/LuneX-18-2_4-focused-r2.XwBk2c`为`12 total / 11 passed / 1 failed`；唯一失败是FIFO测试把同一scene transition按合同先发出的`.input(nil)`误判为并发input callback。production与其余11项通过，已改为比较挂起前后effect count，下一步从fresh目录复验且不复用该bundle。
- 修正后的fresh focused `/tmp/LuneX-18-2_4-focused-r3.FG8Ckv`结构化通过`12/12`、0 skip/fail/expected failure，build为`succeeded/0 error/0 warning/0 analyzer warning`。
- direct tvOS `/tmp/LuneX-18-2_4-tvos.AJeL2v`与visionOS `/tmp/LuneX-18-2_4-vision.B2ikcX`均结构化`succeeded/0 error/0 warning/0 analyzer warning`并各有AIR/metallib；固定UUID只用于build destination，没有simulator inventory或生命周期操作。下一步fresh normal。
- fresh normal `/tmp/LuneX-18-2_4-normal.p2HGpE`结构化通过`987 total / 986 passed / 1 skipped / 0 failed`，唯一skip为`HostAndPersistenceTests/testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`；build零诊断。下一步补macOS/iPhone/iPad app builds并复用已通过tvOS/visionOS组成五平台门。
- macOS、固定iPhone/iPad在`/tmp/LuneX-18-2_4-builds.qtsQKa`全部零诊断成功且有Metal产物，与已通过的fixed tvOS/visionOS组成五平台Debug门；未读取或操作simulator inventory。
- repository pre-gate `/tmp/LuneX-18-2_4-repository-pre.YGBLze`从头通过fixtures、OpenSpec strict `9/9`与勾选前`9/50 next 2.4`、generator四次稳定哈希、精确九文件scope、membership/ownership/privacy/clean-room、focused/normal/五平台证据、opt-in/进程/reference和diff检查。2.4已勾选，预期`10/50 next 2.5`；下一步只读final-state。
- 首轮勾选后final-state `/tmp/LuneX-18-2_4-final-state.n06XLb`通过`10/50 next 2.5`与全部只读门，但随后人工语义审阅发现display unavailable仍可render/replay并保留input eligibility；因此该final-state不计最终验收。已修正display fail-closed和recovery replay语义并新增回归，下一步从fresh focused开始重跑受影响证据。
- display修复首轮focused `/tmp/LuneX-18-2_4-display-fix-focused.h2OFQ6`为`13 total / 12 passed / 1 failed`；唯一失败发生在fixture构造，unavailable display错误地继续携带platform-reported headroom，production与其余12项通过。helper已按immutable display合同修正，失败bundle不复用。
- 修正fixture后的fresh focused `/tmp/LuneX-18-2_4-display-fix-focused-r2.cp7W6C`结构化通过`13/13`、零skip/fail/expected failure，build为`succeeded/0 error/0 warning/0 analyzer warning`；下一步重跑受production变化影响的normal与五平台build。
- 修订fresh normal `/tmp/LuneX-18-2_4-display-fix-normal.HPUEMu`通过`988 total / 987 passed / 1 exact Keychain skip / 0 failed`且build零诊断；修订五平台Debug `/tmp/LuneX-18-2_4-display-fix-builds.Zcj3Gg`全部零诊断成功并各有Metal产物，未查询或操作simulator。下一步修订final repository gate。
- 修订final wrapper首轮在fixture/OpenSpec/generator/scope后因membership文本计数低估build-file声明与phase引用而退出；第二轮通过修订test/build证据后因隐私正则误匹配普通scene/audioRoute/controller lease状态而退出。两轮均未重复test/build、访问Keychain或操作simulator。
- 修正后的final repository gate `/tmp/LuneX-18-2_4-display-fix-final-r3-cXPKxC`从头通过fixtures、OpenSpec strict `9/9`与apply `10/50 next 2.5`、generator四次稳定同哈希、精确十文件scope、membership、FIFO/single-current-delivery/display fail-closed/ordered teardown、privacy/clean-room、修订focused `13/13`、normal `988/987/1/0`、五平台build/Metal、opt-in、进程与diff检查。
- 2.4现可独立提交推送；当前证据仍不是2.5 AppModel application、actual adapters、signed artifact、physical HDR/input/spatial、live Sunshine或性能证明。
- 首轮post-record错误要求高层roadmap重复临时final-gate路径而退出；收窄为roadmap记录结论、runtime contract和三份planning记录具体路径后，`/tmp/LuneX-18-2_4-post-record-r2-vJDin3`通过`10/50 next 2.5`、十文件scope、project hash及diff检查，未重复test/build/generator。
- 2.4已提交推送为`a2e04df Add tvOS visionOS presentation coordinator`；fetch后`HEAD == origin/main == a2e04df187d36bae4eea695a29fb8c8270eb75df`且工作树clean，OpenSpec为`10/50 ready`、next 2.5。
- 启动2.5：将由`NativeSessionMediaEnvironment`每个media generation持有唯一coordinator和现有presentation source subscription，通过typed event把current/terminal snapshot送入`AppModel`；actual geometry只建立scene ownership，input/display/audio adapters保持后置。
- 2.5清理必须覆盖coordinator/media failure、reconnect、remote termination和stop，旧session/media/surface callback不得更新replacement；继续禁用真实Keychain/live host且不查询或操作simulator。
- 2026-08-07系统更新后恢复：active goal仍有效，`HEAD`与`origin/main`均为`a2e04df`，task 2.5六个预期文件保持未提交；session catchup、三份planning、OpenSpec status/apply和全部context files已复核。
- OpenSpec `integrate-tvos-visionos-runtime`仍为spec-driven `10/50 ready`、next 2.5；本轮不操作simulator inventory/lifecycle，继续显式禁用真实Keychain与live host。
- task 2.5首轮warnings-as-errors编译`/tmp/LuneX-18-2_5-compile-first-QVMjyp`唯一已知阻断为`ApplicationDiagnostics.swift`的error switch未覆盖新增stale/invalid platform-presentation application；已补固定privacy-bounded transport diagnostic映射，下一步从fresh evidence目录重跑。
- 第二轮warnings-as-errors编译`/tmp/LuneX-18-2_5-compile-second.FTXZUb`已越过production源和diagnostics，唯一错误为既有readiness/feedback测试event switch缺少`.tvVisionPlatformPresentation`；已显式忽略该不相关事件，下一步从第三个fresh目录复编。
- 第三轮warnings-as-errors编译`/tmp/LuneX-18-2_5-compile-third.axivxW`成功；production、tests与Metal均完成build-for-testing。进入语义审计后修复AppModel application catch无条件清掉已消费terminal failure snapshot的竞态，只保留同ownership的bounded failure phase。
- 首轮environment focused `/tmp/LuneX-18-2_5-env-focused-first.seHM1E`在执行前因两处XCTest async autoclosure编译错误退出；已先捕获snapshot再断言，下一轮使用fresh bundle。
- environment focused第二轮`/tmp/LuneX-18-2_5-env-focused-second.DrRTpN`通过`3/3`。随后增加AppModel immutable platform dependency/test injection，并修复local stop因control session先清零而未显式应用`.localStop`的问题。
- 增加deterministic terminal-race和media-failure AppModel回归后，final focused `/tmp/LuneX-18-2_5-focused-third.ILQdlM`结构化通过`8/8`且build `succeeded/0 error/0 warning/0 analyzer warning`；下一步最终人工diff/并发语义审计后运行fresh normal与五平台Debug。
- 恢复后的完整语义审计确认coordinator terminal后二次stop幂等、geometry application受operation ID和current session/media/ownership隔离、五平台compile-time默认platform正确，且2.5未越界实现actual input/display/HDR/audio adapters。
- normal首轮`/tmp/LuneX-18-2_5-normal.bZrKDT`因误用不存在的`LuneX` scheme在测试前退出；fresh `/tmp/LuneX-18-2_5-normal-r2.6qYfC2`改用`LuneXCoreTests`并显式移除Keychain/live-host opt-in，结构化通过`996/995/1 exact Keychain skip/0`且build零诊断。
- 五平台Debug `/tmp/LuneX-18-2_5-builds.zPlpja`全部`succeeded/0/0/0`并各有AIR/metallib；固定UUID只作build destination，没有inventory或create/clone/boot/install/launch/run/shutdown/delete。
- repository pre-gate首轮`/tmp/LuneX-18-2_5-repository-pre.CbrOkr`因误把fixture根设为`.`而扫描既有build/reference/docs后退出；修正为权威fixture根后，`/tmp/LuneX-18-2_5-repository-pre-r2.27GQDW`通过fixtures、strict`9/9`、pre-mark`10/50 next 2.5`、四次generator稳定哈希、scope、ownership/privacy/reference/opt-in/process和diff门。
- 已同步runtime contract、roadmap和三份planning并勾选OpenSpec 2.5；预期权威状态`11/50 ready`、next 2.6，下一步只读final-state，不重复test/build或simulator操作。
- final-state首轮`/tmp/LuneX-18-2_5-final-state.GOe1Eq`因`jq`管道优先级在OpenSpec JSON解析处退出，尚未读任何xcresult；修正后的`/tmp/LuneX-18-2_5-final-state-r2.6tknnX`只读通过strict`9/9`、`11/50 next 2.6`、13/13 scope、project hash、focused`8/8`、normal`996/995/1/0`、五平台/Metal和全部边界，未重复test/build/generator或simulator操作。
- 2.5已提交推送为`2157eb7`并fetch确认`HEAD == origin/main`、工作树clean；OpenSpec为`11/50 ready`、next 2.6。
- 启动2.6覆盖审计：surface/coordinator单层矩阵已完整，缺少AppModel queued geometry replacement/late callback及active platform owner下concurrent terminal teardown的跨层测试。发现stop/fail在`active=nil`前新增actor await的潜在重入窗口，将先以测试复现再最小修复。
- 系统更新后恢复确认Xcode 26.4与macOS/iOS/tvOS/visionOS 26.4 SDK可用，`HEAD == origin/main == 2157eb7`；未查询或操作simulator，真实Keychain/live-host opt-in仍禁用。
- 2.6首轮实现加入generation-scoped共享termination operation和可注入coordinator factory；新增active platform双stop及provider-failure/stop竞态测试，要求单terminal effect、共享clean report、重复stop复用、subscription归零与五类resource各停一次。
- AppModel新增surface ownership + geometry revision admission水位，避免replacement已排队但activation尚挂起时late old surface反向成为最后operation；新增确定性挂起测试，预期只提交`activate(surface 1) -> activate(surface 2) -> scene(surface 2)`。
- 下一步生成工程并运行warnings-as-errors focused编译/测试；当前修改尚未验收，OpenSpec 2.6保持未勾选。
- focused首轮预检在生成工程和启动测试前发现外部TamaSwift iOS Simulator Release `xcodebuild` PID 32408，因共享Xcode资源主动退出且未干预外部进程；该目录没有有效构建证据，等待进程结束后从fresh目录运行。
- focused第二轮`/tmp/LuneX-18-2_6-focused-second.MJ0oOv`在测试执行前发现两处相同Swift类型错误：`[weak self]`使terminal task推断为`Task<Void?, Never>`而reservation要求`Task<Void, Never>`；production其余编译未报告诊断。已改为显式task类型和`guard let self`，失败bundle不复用。
- focused第三轮`/tmp/LuneX-18-2_6-focused-third.1wPd3H`已使production在warnings-as-errors下编译通过；0 tests前仅新增environment测试中8处async值位于XCTest同步autoclosure而编译失败。已改为先await局部变量再同步断言，失败bundle不复用。
- focused第四轮`/tmp/LuneX-18-2_6-focused-fourth.EdK5uu`执行`3 total / 2 passed / 1 failed`：geometry queue和provider-failure/stop竞态通过；双stop唯一失败是测试误期望立即EOF，实际按合同先yield `.stopped(.localStop)`再结束。已改为显式验证terminal-before-end，production无需修改。
- focused第五轮`/tmp/LuneX-18-2_6-focused-final.L6uHOF`仍为`3/2/1`，检查源码发现上一补丁命中前部另一个EOF断言，目标双stop用例未改变且旧无owner测试被错误加上terminal要求。已精确恢复旧断言并按资源计数上下文修改目标；两项其余测试继续通过。
- fresh focused `/tmp/LuneX-18-2_6-focused-final-r2.jlY8sf`在Swift/Clang/Metal warnings-as-errors下结构化通过`3/3 passed / 0 skipped / 0 failed / 0 expected failure`。覆盖active platform双stop、provider-failure/stop first-terminal-wins和AppModel queued geometry replacement/late callback；下一步人工竞态审计并扩大既有surface/coordinator矩阵。
- focused后人工审计补齐event层同一replacement窗口：AppModel现拒绝低于highest admitted geometry ownership的platform snapshot；跨层测试在replacement排队但activation仍挂起时及replacement完成后各注入一次late owner state，均要求保持inert。该production修订需fresh focused复验。
- 审计修订后fresh `/tmp/LuneX-18-2_6-focused-final-r3.VB6cr5`继续通过`3/3`且零诊断；扩大相关矩阵`/tmp/LuneX-18-2_6-related-final.OQl0xr`结构化通过`88/88`、0 skip/fail/expected failure和0 warning/error，覆盖完整presenter/coordinator及相关environment/AppModel路径。
- 人工actor审计确认：terminal reservation在首个coordinator await前发布；stop/fail race保持first terminal wins；provider failure只异步启动tracker teardown避免consumer self-join；并发/后续stop均取得同一cached report；AppModel admission在runtime clear前保持最高surface generation和同surface最高revision。
- fresh normal `/tmp/LuneX-18-2_6-normal.rKKWHh`结构化通过`999 total / 998 passed / 1 skipped / 0 failed / 0 expected failure`且零诊断；唯一skip精确为真实Keychain opt-in测试，Keychain/live-host环境变量均unset。
- 五平台Debug `/tmp/LuneX-18-2_6-builds.k6M12b`中macOS、固定iPhone/iPad/Apple TV/Vision Pro全部`succeeded/0 error/0 warning/0 analyzer warning`且各有AIR/metallib；UUID只作build destination，未查询或操作simulator lifecycle。
- repository pre-gate首轮`/tmp/LuneX-18-2_6-repository-pre.2PfeAN`在fixture通过后因OpenSpec `jq`数组/根对象上下文混淆而退出；保存JSON读回确认`9/9 valid`，源码/OpenSpec没有失败。下一步以根对象断言从fresh目录执行未完成门禁，并复用focused、related、normal和五平台build证据。
- 修正后的repository pre-gate `/tmp/LuneX-18-2_6-repository-pre-r2.MNeROJ`完整通过strict `9/9`、pre-mark `11/50 next 2.6`、四次稳定generator、精确scope、语义、retained tests/builds、opt-in/reference/process和diff门；OpenSpec 2.6已勾选，预期`12/50 ready`、next 3.1。下一步只读final-state，不重复test/build/generator或simulator操作。
- 勾选后的只读final-state `/tmp/LuneX-18-2_6-final-state.Opv4SF`通过strict `9/9`、apply `12/50 next 3.1`、稳定project hash、精确十文件scope、retained focused/related/normal/五平台build及全部边界；2.6可独立提交推送，未重复test/build/generator或simulator操作。
- 2.6已提交推送为`46f027b`并fetch确认`HEAD == origin/main`、工作树clean；OpenSpec为`12/50 ready`、next 3.1。
- 启动3.1调查：既有`TVRemoteCaptureState`已提供generation/balanced/restricted reducer合同，但actual `TVVisionStreamMetalView`没有press override或runtime owner。计划接actual begin/end/cancel到main-actor identity/token owner，再复用AppModel现有`sendRemoteInput`路径；3.2–3.6 local focus/reserved/controller/release保持后置。
- 3.1第一版已接framework-free surface press owner、actual tvOS view callback、AppModel input application与四项focused路径；首轮`/tmp/LuneX-18-3_1-focused.KLHNd8`在0 tests前仅因验收命令向Metal linker传入不支持的`-warnings-as-errors`退出。工程已有Metal compiler `-Werror`，下一轮移除该额外linker参数并使用fresh bundle。
- 第二轮focused `/tmp/LuneX-18-3_1-focused-r2.b7SIpC`为`4/3/1`；三个owner用例通过，AppModel组合用例暴露测试等待的是fake environment的提前application记录而不是owner完成admission update。已加入只读无副作用disposition并等待captured/local真实状态；同时让UIKit active press固定began时surface generation，避免late finish被重标到replacement surface。下一步fresh focused复验。
- 修正后的fresh focused `/tmp/LuneX-18-3_1-focused-r3.tXpOru`结构化通过`4/4`且build零诊断；UUID delivery wait、无副作用admission屏障和balanced begin/end/cancel组合路径均通过。下一步fixed tvOS/visionOS actual分支build，不查询或操作simulator。
- fixed tvOS `/tmp/LuneX-18-3_1-tvos.54OJ6K`与visionOS `/tmp/LuneX-18-3_1-vision.22Jxk6`actual分支均零诊断成功且各有AIR/metallib；未查询或操作simulator。人工delivery审计发现up失败重试/queued down suppression缺口，已修订production与新增第五项owner回归，下一步fresh focused重验。
- 修订focused `/tmp/LuneX-18-3_1-focused-r4.e1UeNI`结构化通过`5/5`且零诊断；失败release retry、queued-down suppression、existing balanced/replacement/failure与AppModel组合路径全部通过。下一步41项扩大相关矩阵。
- 扩大相关矩阵 `/tmp/LuneX-18-3_1-related.SpHKnV`结构化通过`41/41`且零诊断；remote reducer/owner、surface generation/geometry与AppModel current/replacement/terminal路径均通过。下一步fresh normal，真实Keychain/live-host继续unset。
- fresh normal `/tmp/LuneX-18-3_1-normal.nIpesJ`结构化通过`1004/1003/1 exact Keychain skip/0`且零诊断；唯一skip为显式真实Keychain round trip。下一步五平台Debug，仅build固定destination。
- 五平台fresh Debug `/tmp/LuneX-18-3_1-builds.hQ7AVJ`全部结构化`succeeded/0/0/0`且各有AIR/metallib；没有simulator inventory或生命周期操作。已同步阶段18 runtime contract、roadmap和planning中的3.1实现、证据与未证明边界，下一步repository pre-gate。
- 系统更新后恢复并接管既有repository pre-gate session；`/tmp/LuneX-18-3_1-repository-pre.nYAHpJ`明确通过fixtures、strict `9/9`、pre-mark `12/50 next 3.1`、generator四次稳定、精确scope、source/membership、retained focused/related/normal/五平台build以及privacy/clean-room/reference/opt-in/process/diff门。
- 完成OpenSpec全上下文复读与最终人工语义审计后勾选3.1，并同步runtime contract、roadmap与三份planning为`13/50 next 3.2`；下一步仅运行fresh只读final-state，不重复test/build/generator或任何simulator操作。
- 首轮final-state `/tmp/LuneX-18-3_1-final-state.IrtwNB`通过strict、apply、工程哈希与精确scope后，被推测性的复数内部符号正则错误终止，尚未读取retained test/build。已确认实际单一failure-generation与failed-button up补发语义，下一步从fresh目录继续未完成门。
- corrected final-state `/tmp/LuneX-18-3_1-final-state-r2.f0WIxl`已通过current source/task semantics、retained `5/5`、`41/41`、`1004/1003/1/0`、五平台build/Metal、privacy/reference/opt-in/process/diff，并保留首轮strict `9/9`、`13/50 next 3.2`、hash/scope结果；没有重复test/build/generator或simulator操作。下一步post-record与独立提交推送。
- post-record `/tmp/LuneX-18-3_1-post-record.XZcSS0`通过`13/50 next 3.2`、project hash、12文件scope、evidence record、opt-in/process/reference和diff门；进入最终diff审计与独立提交推送。
- 3.1已提交推送为`e3abab8 Capture tvOS stream surface presses`；fetch确认`HEAD == origin/main`、工作树clean，OpenSpec为`13/50 ready`、next 3.2。
- 启动3.2审计：确认现有reducer已具overlay/notFocused release合同，缺口是tvOS SwiftUI overlay/workspace没有显式状态，AppModel只在actual UIKit focus callback后关闭admission。计划新增framework-free handoff gate、AppModel current application与明确tvOS focus target，不提前实现3.3 reserved commands或3.4–3.6 controller/release。
- 完成3.2首版production/test修改：framework-free handoff + fresh geometry focus边界、AppModel同步owner gate、tvOS conditional overlay/FocusState/Hide Controls，以及pure owner/application矩阵。首个AppModel大补丁因远距离锚点失败且无部分写入，已拆为局部补丁完成；下一步格式、diff与warnings-as-errors focused编译。
- 系统更新后接回唯一focused session 29733并等待到明确成功；`/tmp/LuneX-18-3_2-focused.xA2quo`结构化通过`4/4`且build零诊断，`git diff --check`通过，当前精确8文件scope与3.2预期一致。
- OpenSpec保持`13/50 next 3.2`未勾选；下一步构建fixed tvOS/visionOS actual条件分支，再做竞态人工审计与后续完整门禁。未查询或操作simulator inventory/lifecycle，Keychain/live-host opt-in继续unset。
- direct tvOS `/tmp/LuneX-18-3_2-tvos.2CvZrC`与visionOS `/tmp/LuneX-18-3_2-vision.XBsmrc`均结构化`succeeded/0/0/0`且有AIR/metallib；人工审计随后发现重复hide overlay会错误重置fresh-focus requirement。已改为同值no-op并加回归，旧focused/direct证据不再作为最终验收，下一步fresh重跑。
- 修订fresh focused `/tmp/LuneX-18-3_2-focused-r2.KTjwGJ`通过`4/4`；direct tvOS `/tmp/LuneX-18-3_2-tvos-r2.aq89tz`和visionOS `/tmp/LuneX-18-3_2-vision-r2.qU9HtD`均零诊断成功且有Metal产物。
- 扩大相关矩阵 `/tmp/LuneX-18-3_2-related.kbZRhO`通过`43/43`且零诊断；fresh normal `/tmp/LuneX-18-3_2-normal.KIqw0B`通过`1006/1005/1 exact Keychain skip/0`且零诊断。
- 五平台fresh Debug `/tmp/LuneX-18-3_2-builds.AwsH8s`全部结构化`succeeded/0/0/0`且各有AIR/metallib；固定UUID仅作build destination，没有simulator inventory或生命周期操作。已同步合同/roadmap/planning，下一步repository pre-gate。
- 首个文档同步补丁因错误的runtime contract换行锚点被原子拒绝，无部分写入；改用稳定章节标题后完成同步，没有重复test/build或模拟器操作。
- repository pre-gate `/tmp/LuneX-18-3_2-repository-pre.CmABju`完整通过fixtures、strict `9/9`、pre-mark `13/50 next 3.2`、generator四次稳定、精确十文件scope、语义与全部retained evidence/boundary；已勾选3.2并同步为预期`14/50 next 3.3`。下一步只读final-state，不重复test/build/generator或simulator操作。
- 勾选后的只读final-state `/tmp/LuneX-18-3_2-final-state.HzeLfq`通过strict `9/9`、apply `14/50 next 3.3`、稳定project hash、精确十一文件scope、current source/task、retained tests/builds及全部边界；3.2可独立提交推送，未重复test/build/generator或simulator操作。
- post-record `/tmp/LuneX-18-3_2-post-record.K9dE1v`通过`14/50 next 3.3`、project hash、十一文件scope、pre/final引用、retained counts、opt-in/process/reference和diff门；进入最终diff审计与独立提交推送。
- 最终diff审计发现overlay隐藏时remote termination/provider failure会留下无controls的Stream黑屏；已在统一platform clear中恢复overlay，并让现有reconnect/remote-termination测试验证两次终态恢复。此前3.2 test/build/pre/final证据失效，OpenSpec checkbox与roadmap已回退到`13/50 next 3.2`，需fresh重跑后再完成。
- 终态修订fresh focused `/tmp/LuneX-18-3_2-focused-r3.b9ciW0`通过`5/5`、相关矩阵`/tmp/LuneX-18-3_2-related-r2.FdIxGY`通过`43/43`、normal `/tmp/LuneX-18-3_2-normal-r2.7WhDLh`通过`1006/1005/1 exact Keychain skip/0`，均零诊断。
- 修订五平台Debug `/tmp/LuneX-18-3_2-builds-r2.huymlz`全部`succeeded/0/0/0`且各有AIR/metallib；固定UUID仅作destination，没有simulator inventory/lifecycle。下一步从头运行修订repository pre-gate。
- 修订repository pre-gate首轮在fixtures、OpenSpec、generator与scope通过后，因包装器用单行`rg`跨行匹配terminal overlay调用而退出；不是源码/测试失败。下一轮从fresh目录改用函数上下文断言，不重复test/build或simulator操作。
- 修订repository pre-gate `/tmp/LuneX-18-3_2-repository-pre-r3.rICtus`从头通过fixtures、strict/pre-mark、四次generator、十文件scope、terminal/source/test semantics、修订retained evidence与全部边界；已重新勾选3.2并推进为预期`14/50 next 3.3`。下一步只读final-state。
- 修订final-state `/tmp/LuneX-18-3_2-final-state-r2.dFJcBe`只读通过`14/50 next 3.3`、十一文件scope、project hash、terminal/current semantics、修订retained tests/五平台build和全部边界；没有重复test/build/generator/simulator操作，3.2可提交推送。
- 修订post-record `/tmp/LuneX-18-3_2-post-record-r2.CzhtnJ`通过`14/50 next 3.3`、project hash、十一文件scope、修订pre/final引用、retained counts、opt-in/process/reference和diff门；进入最终diff审计与独立提交推送。
- 系统更新后恢复确认macOS 27.0、Xcode 26.4、Swift 6.3可用，`HEAD == origin/main == b027b3c`、工作树clean、OpenSpec为`14/50 next 3.3`；未查询或操作simulator，Keychain/live-host opt-in继续禁用。
- 已完成3.3首轮SDK/合同审计：公开tvOS press responder可见方向、Select、Menu、Play/Pause、Page Up/Down、123和Four Colors，Home/volume/capture/power不具公开`UIPressType`入口；下一步实现纯值reserved-command owner回调、Menu/Back overlay application和typed bounded unavailable state，同时保持完整UIKit native escape lifecycle。
- 3.3首版focused `/tmp/LuneX-18-3_3-focused.PBeaEZ`通过`3/3`，direct tvOS `/tmp/LuneX-18-3_3-tvos.NVQQWx`与visionOS `/tmp/LuneX-18-3_3-vision.zGhsAR`均零结构化诊断成功；随后人工审计发现captured `pressesChanged`仍会落入UIKit，已补ownership分流，因此上述证据不作为最终验收，下一步从fresh目录重跑。
- 系统更新后恢复并等待既有修订focused会话明确退出；`/tmp/LuneX-18-3_3-focused-r2.BKpneI`终端结果为`TEST SUCCEEDED`，三个目标用例均通过。下一步串行读取该`.xcresult`及修订tvOS build，再运行fresh visionOS build；尚未勾选OpenSpec 3.3。
- 修订focused `/tmp/LuneX-18-3_3-focused-r2.BKpneI`已串行结构化确认为`3/3 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded/0 warning/0 error/0 analyzer warning`。
- 修订direct tvOS `/tmp/LuneX-18-3_3-tvos-r2.m8QkzS`和fresh visionOS `/tmp/LuneX-18-3_3-vision-r2.fmO2Sl`均结构化`succeeded/0/0/0`且各有一份AIR与一份metallib；固定UUID只作build destination，没有查询或操作simulator lifecycle，Keychain/live-host opt-in保持unset。
- 人工语义审计确认Menu/unsupported不进入remote handler且完整返回UIKit begin/change/end/cancel，captured changed不进入UIKit；Back/Menu overlay复用既有held release，typed state无raw identity，Home/volume/capture/power没有伪造callback。下一步扩大3.1/3.2/3.3相关矩阵。
- 扩大相关矩阵`/tmp/LuneX-18-3_3-related.PgiNcV`结构化通过`44/44 passed / 0 skipped / 0 failed / 0 expected failure`且build零诊断，覆盖完整remote/focus contract、surface owner/geometry及AppModel current/replacement/terminal路径。下一步fresh normal suite。
- fresh normal `/tmp/LuneX-18-3_3-normal.5ChBp1`结构化通过`1007 total / 1006 passed / 1 skipped / 0 failed / 0 expected failure`且build零诊断；唯一skip精确为显式真实Keychain round trip，Keychain/live-host opt-in均unset。下一步五平台fresh Debug builds。
- 五平台fresh Debug `/tmp/LuneX-18-3_3-builds.K29Tfl`中macOS、固定iPhone/iPad/Apple TV/Vision Pro全部`succeeded/0 error/0 warning/0 analyzer warning`且各有AIR/metallib；固定UUID仅作build destination，没有查询或操作simulator lifecycle。
- 系统更新后恢复核对`HEAD == origin/main == b027b3c`、OpenSpec `14/50 next 3.3`、十个预期修改文件与六组保留证据目录一致；没有运行中的LuneX `xcodebuild`，真实Keychain/live-host opt-in仍unset。
- 已同步Task 3.3 runtime contract、roadmap和三份planning到pre-mark状态；首个组合文档补丁因runtime contract换行锚点不匹配被原子拒绝，无部分修改，随后使用稳定章节标题和真实EOF完成。下一步运行fresh repository pre-gate，3.3仍未勾选。
- repository pre-gate `/tmp/LuneX-18-3_3-repository-pre.y7lh71`从头通过fixtures、strict `9/9`、pre-mark `14/50 next 3.3`、generator四次稳定、精确十二文件scope、source/membership/no-delivery、retained tests/builds及全部边界；OpenSpec 3.3已勾选并同步为预期`15/50 next 3.4`。下一步仅运行只读final-state。
- post-mark只读final-state `/tmp/LuneX-18-3_3-final-state.ZREyZa`通过strict `9/9`、apply `15/50 next 3.4`、稳定project hash、精确十三文件scope、current source/task、retained tests/builds及全部边界；没有重复test/build/generator/simulator操作。下一步post-record与最终diff审计。
- post-record `/tmp/LuneX-18-3_3-post-record.igbLBj`通过`15/50 next 3.4`、project hash、十三文件scope、pre/final记录、retained counts、opt-in/process/reference和diff门；最终diff/UIKit lifecycle审计无新问题，Task 3.3进入独立提交推送。
- 3.3已提交推送为`e600f6d Keep tvOS system commands local`；fetch确认`HEAD == origin/main`、工作树clean，OpenSpec为`15/50 ready`、next 3.4。
- 启动3.4调查：确认旧monitor仅发布connection list且production未使用，纯值16-slot/lease/roster合同已存在，AppModel仍固定空leases；coordinator同revision input逻辑需允许snapshot相同的lease-only变化。下一步实现pure slot runtime、actual tvOS handler owner、AppModel roster application与focused tests。
- 系统更新后续接3.4：重新读取planning与OpenSpec全部上下文，确认`HEAD == origin/main == e600f6d`、九文件scope和`15/50 next 3.4`一致。首轮focused `/tmp/LuneX-18-3_4-focused.hyTeNM`在0 tests时因对临时slot runtime调用mutating测试helper而编译失败；已改为局部`var`，下一步从fresh DerivedData/result bundle运行五项focused gate。
- 修正后的fresh focused `/tmp/LuneX-18-3_4-focused-r2.MyATKc`结构化通过`5/5 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded/0 warning/0 error/0 analyzer warning`。下一步fixed Apple TV build编译actual GameController owner；固定UUID只作destination，不查询或操作simulator生命周期。
- 首轮fixed Apple TV `/tmp/LuneX-18-3_4-tvos.Czp0Ks`编译actual分支时结构化失败为`2 errors / 0 warnings`，均为NotificationCenter block直接把非Sendable`Notification`送入main actor。已保留main queue observer并增加主线程fail-closed检查，通过私有unchecked reference只在该隔离边界内交付`GCController`；失败bundle不作验收，下一步fresh tvOS build。
- 修订fixed Apple TV `/tmp/LuneX-18-3_4-tvos-r2.9WJTuS`结构化通过`succeeded/0 warning/0 error/0 analyzer warning`且生成一份AIR和一份metallib；固定UUID只作build destination，没有查询、启动或创建simulator。下一步fixed Vision Pro隔离build。
- fixed Vision Pro `/tmp/LuneX-18-3_4-vision.uUQVaS`结构化通过`succeeded/0 warning/0 error/0 analyzer warning`且生成一份AIR和一份metallib；tvOS专属GameController owner未污染visionOS条件分支。下一步人工所有权/竞态/no-delivery审计。
- 人工审计确认actual handler cleanup与原queue恢复、disconnect replacement fresh lease、AppModel roster/geometry admission和same-revision coordinator规则成立，且3.4没有controller remote delivery/feedback或3.6 release实现。扩大相关矩阵 `/tmp/LuneX-18-3_4-related.USzkjv`结构化通过`85/85`且build零诊断；下一步fresh normal。
- fresh normal `/tmp/LuneX-18-3_4-normal.PblBXf`结构化通过`1011 total / 1010 passed / 1 exact Keychain skip / 0 failed / 0 expected failure`且build零诊断；唯一skip为显式真实Keychain round trip，真实Keychain/live-host opt-in均unset。下一步五平台Debug build矩阵。
- 五平台Debug `/tmp/LuneX-18-3_4-builds.ygHyOW`已逐份串行读取：macOS、fixed iPhone、fixed iPad、fixed Apple TV和fixed Vision Pro全部`succeeded/0 warning/0 error/0 analyzer warning`，每个平台各保留一份AIR和一份metallib；固定UUID仅作destination，没有查询或操作simulator lifecycle。
- 已把3.4 actual handler/slot/lease/roster ownership、AppModel current-generation application、same-revision lease-only coordinator规则、retained evidence与no-delivery/physical proof boundary同步到阶段18合同、roadmap及三份planning。OpenSpec仍保持pre-mark `15/50 next 3.4`，下一步fresh repository pre-gate。
- 首轮repository pre-gate `/tmp/LuneX-18-3_4-repository-pre.IydUi3`的fixture self/tree通过，但包装器沿用错误字段`summary.totals.total`后主动退出；保存的OpenSpec strict结果实际为`9 items / 9 passed / 0 failed`且全部`valid=true`。未运行generator或后续证据门；记录该轮为无效部分门禁，修正为`.summary.totals.items`后从新目录重跑。
- 修正后的repository pre-gate `/tmp/LuneX-18-3_4-repository-pre-r2.cKwJoH`完整通过fixture self/tree、strict `9/9`、pre-mark `15/50 next 3.4`、四次稳定generator、十一文件精确scope、current source/test/no-delivery语义、focused `5/5`、related `85/85`、normal `1011/1010/1/0`、direct/五平台build及privacy/reference/opt-in/process/diff边界。
- OpenSpec 3.4已勾选，预期权威状态为`16/50 ready`、next 3.5。下一步仅运行post-mark只读final-state，禁止重复test/build/generator或simulator操作。
- post-mark只读final-state `/tmp/LuneX-18-3_4-final-state.0GVsGm`通过strict `9/9`、apply `16/50 next 3.5`、稳定project hash、十二文件精确scope、current source/task/docs、全部retained tests/builds及privacy/reference/opt-in/process/diff边界；未重复test/build/generator/simulator操作。下一步post-record与最终diff审计。
- post-record `/tmp/LuneX-18-3_4-post-record.8PiBxS`通过`16/50 next 3.5`、稳定project hash、十二文件scope、pre/final记录、retained evidence、opt-in/process/reference和diff门；最终人工diff审计未发现新问题，Task 3.4进入独立提交推送。
- 3.4已提交推送为`da295bb Own tvOS controller runtime`；fetch确认`HEAD == origin/main`且工作树clean。OpenSpec为`16/50 ready`、next 3.5。
- 启动3.5数据流审计：现有remote provider已经拥有唯一controller registry、wire arrival/state/disconnect、held state与feedback capability gate；3.4 roster尚未进入该路径。确认不能直接发送低级`.controllerState`，因为它不会更新registry entry state；下一步设计opaque lease routing identity、preferred 16-slot complete snapshot、AppModel FIFO reconcile及current-lease actual feedback application。
- 完成3.5第一版shared/actual接线：高层atomic roster event、existing registry candidate reconcile、opaque lease ID、AppModel FIFO route/current feedback/motion drain，以及actual haptics/light/motion capability/application与cleanup。fresh macOS `/tmp/LuneX-18-3_5-compile-mac.c0RbId`和fixed Apple TV `/tmp/LuneX-18-3_5-compile-tv.qFXSAB`均零结构化诊断。
- 首轮focused `/tmp/LuneX-18-3_5-focused-first.UpxyQa`在0 tests时只有测试编译错误：parser无`leftTrigger`字段，且两处async iterator调用位于XCTest autoclosure。production/shared source编译无错误；修订测试后使用fresh证据重跑。
- 第二轮focused `/tmp/LuneX-18-3_5-focused-r2.QlwjMx`运行5项，registry preferred slot、atomic invalid replacement、opaque router和motion sample四项通过；AppModel唯一失败源于测试只等待controlled send记录，尚未等待routing Task随后写回state。build为零诊断；修订双完成条件后fresh重跑。
- fresh focused `/tmp/LuneX-18-3_5-focused-r3.vWrygN`结构化通过`5/5`且build零诊断。审计后继续收紧同批多controller final-mask fallback、haptic局部失败stop-all和complete state releaseAll覆盖，因此r3不作为最终修订证据，下一步fresh focused。
- 完成final-mask、releaseAll、profile handler恢复、haptic部分启动失败cleanup与A→B→C串行竞态修订。最终focused `/tmp/LuneX-18-3_5-focused-final-r2.qj3Kuj`通过`5/5`，build四类diagnostic均为0；较早`4/5`仅为测试presentation count仍使用旧固定值，改为geometry基数`+2/+3`后fresh通过。
- related `/tmp/LuneX-18-3_5-related-final.xOsmvX`通过`170/170`且零诊断；normal `/tmp/LuneX-18-3_5-normal-final.fFbr02`为`1015/1014/1 exact Keychain skip/0`且零诊断。`LUNEX_RUN_KEYCHAIN_TEST`与`LUNEX_RUN_LIVE_HOST_TEST`均保持unset。
- direct tvOS `/tmp/LuneX-18-3_5-tvos-final.Tnldhb`和五平台Debug `/tmp/LuneX-18-3_5-builds-final.10FtDl`全部结构化为`succeeded/0 error/0 warning/0 analyzer warning`，每个平台保留`1 AIR / 1 metallib`。固定UUID仅作build destination，未查询或操作simulator lifecycle。
- focused xcresult首次只读diagnostics包装命令因`jq`的`.errors?//empty`缺少空格发生parser error；改用正确表达式只读同一xcresult确认`0/0/0/0`，没有重复test/build。
- 已同步Task 3.5 runtime contract、completion roadmap、task plan、progress与findings的实现、证据、失败记录和proof boundary；OpenSpec仍保持pre-mark `16/50 next 3.5`。下一步fresh repository pre-gate，通过后才勾选。
- repository pre-gate `/tmp/LuneX-18-3_5-repository-pre.qGGaan`完整通过fixture self/tree、strict `9/9`、pre-mark `16/50 next 3.5`、四次稳定generator、十三文件精确scope、current source/test/membership语义、全部retained tests/builds及privacy/clean-room/reference/opt-in/process/diff边界。
- OpenSpec 3.5已勾选，预期权威状态为`17/50 ready`、next 3.6。下一步仅运行post-mark只读final-state，禁止重复test/build/generator或simulator操作。
- post-mark只读final-state `/tmp/LuneX-18-3_5-final-state.efZjqf`通过strict `9/9`、apply `17/50 next 3.6`、稳定project hash、十四文件精确scope、current source/task/docs、全部retained tests/builds及privacy/clean-room/reference/opt-in/process/diff边界；未重复test/build/generator/simulator操作。下一步post-record与最终diff审计。
- 首轮post-record在OpenSpec/scope后因循环变量名`path`覆盖zsh特殊命令路径数组而报`rg: command not found`；不是代码或证据失败。改用`evidence_path`后，fresh `/tmp/LuneX-18-3_5-post-record-r2.BNqR7l`通过`17/50 next 3.6`、project hash、十四文件scope、pre/final记录、retained evidence、opt-in/process/reference与diff门。
- 最终人工diff与tvOS 26.4 public header审计确认candidate registry atomic commit、final mask/held state、AppModel routing FIFO/current lease fences、bounded motion、profile handler/queue恢复与Core Haptics partial failure cleanup成立；default/all locality由SDK保证支持，trigger capability仍需left/right两项。未发现新问题，3.5进入独立提交推送。
- 3.5已提交推送为`d372f06 Route tvOS controller feedback`；fetch确认`HEAD == origin/main`且工作树clean。OpenSpec为`17/50 ready`、next 3.6。
- 启动3.6 release-path审计：底层existing provider barrier与pure `TVPlatformInputReleasePlan`顺序已存在，但actual surface owner只消费remote send effect；overlay/focus/scene和terminal clear尚未等待handler quiescence/provider release后再恢复local focus。
- 设计为扩展existing owner的完整effect executor和admission generation fence，AppModel负责停止/等待controller tasks、调用existing `releaseInput`、barrier后恢复overlay，并在fresh eligible geometry的open effect中重启actual controller runtime；不创建第二个held-state registry或release provider。
- 已完成3.6首版production接线：owner完整effect FIFO、actual admission/release pending fence、controller lease注入与terminal join；AppModel接入controller quiesce/restart、existing provider release、local overlay restoration及roster/motion/feedback gates。首轮静态包装器因独立`swift-format`不存在而在lint前退出，改用`xcrun swift-format`。
- Xcode默认`swift-format --strict`与仓库既有四空格风格不兼容，对完整文件产生数千条基线缩进诊断；按约束不运行整文件format，改用fresh warnings-as-errors编译/测试和局部人工格式审计。
- 续接人工竞态审计后将owner的release pending改为FIFO release-operation计数，并在实际应用open effect前增加current state/input/surface预检；新增replacement barrier阻塞期间并发terminal release的双barrier测试，要求旧open不执行、第二个barrier完成前pending不清零。
- owner focused修订版`/tmp/LuneX-18-3_6-owner-r2.88v2Tq`通过`27/27`；随后继续把AppModel update异常改为ordered fail-closed，并扩展owner合同异常、AppModel replacement/scene duplicate barrier及provider release failure回归，因此该27项结果仅作中间编译/回归证据，下一步fresh组合focused。
- fresh组合focused `/tmp/LuneX-18-3_6-focused-r3.ycXtoF`结构化通过`33/33`且build `succeeded/0 warning/0 error/0 analyzer warning`；真实Keychain/live-host opt-in保持unset，未查询或操作simulator lifecycle。下一步fixed Apple TV仅作build destination编译actual controller条件分支。
- fixed Apple TV direct build `/tmp/LuneX-18-3_6-tvos-r2.5BXadt`结构化通过`succeeded/0 warning/0 error/0 analyzer warning`，并生成一份AIR与一份metallib；固定UUID仅作destination，没有任何simulator生命周期操作。
- related matrix `/tmp/LuneX-18-3_6-related.kUZxE4`结构化通过`229/229 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded/0 warning/0 error/0 analyzer warning`；下一步最终production diff审计、fresh normal与五平台Debug。
- 最终审计发现并修复连续surface replacement旧open短暂重启及跨input generation新open被旧delivery generation过滤的问题；owner新增admission intent revision，两项新回归覆盖A→B→C和generation replacement。旧focused/related/direct build降为中间证据，下一步从fresh目录重跑修订focused与related。
- 修订后focused `/tmp/LuneX-18-3_6-focused-r4.MH3aFT`结构化通过`35/35 passed / 0 skipped / 0 failed / 0 expected failure`且build为`succeeded/0 warning/0 error/0 analyzer warning`；下一步fresh related matrix。
- 首轮修订related `/tmp/LuneX-18-3_6-related-r2.Bn31c8`结构化为`231/230/0 skipped/1 failed`且build零诊断；唯一macOS input失败是测试只等待coordinator actor ready而未等待AppModel active generation写回。已收紧等待条件，下一步fresh重跑related，失败bundle不作最终证据。
- 修订后related `/tmp/LuneX-18-3_6-related-r3.U316bz`结构化通过`231/231 passed / 0 skipped / 0 failed / 0 expected failure`且build为`succeeded/0 warning/0 error/0 analyzer warning`；下一步fresh fixed Apple TV direct build。
- 修订后direct fixed Apple TV `/tmp/LuneX-18-3_6-tvos-r3.z7MzTk`结构化通过`succeeded/0 warning/0 error/0 analyzer warning`并生成一份AIR/metallib；固定UUID仅作destination，下一步fresh normal suite。
- fresh normal `/tmp/LuneX-18-3_6-normal.dt203K`结构化通过`1022 total / 1021 passed / 1 exact Keychain skip / 0 failed / 0 expected failure`且build为`succeeded/0 warning/0 error/0 analyzer warning`；下一步五平台fresh Debug builds。
- macOS更新后续接确认Xcode 26.4/Swift 6.3、宿主macOS 27.0、Git基线与origin一致、Keychain/live-host opt-in unset，未查询或操作simulator lifecycle。
- 续接最终竞态审计发现跨generation open failure误标old generation，以及`invalidate()`后复用owner时旧defer可能扣除新pending release count；已改为effect-generation fail-closed、per-operation UUID release accounting与无回绕UUID admission intent token，并新增两项定向回归。暂停前focused/related/normal/direct/five-platform证据降为中间证据，下一步fresh focused。
- fresh focused `/tmp/LuneX-18-3_6-focused-r5.I6eHeU`结构化通过`37/37`，fresh related `/tmp/LuneX-18-3_6-related-r4.B4s4Tw`通过`233/233`；两者均`0 skipped / 0 failed / 0 expected failure`且build为`succeeded/0 warning/0 error/0 analyzer warning`。下一步fresh fixed tvOS direct build。
- fresh fixed tvOS direct `/tmp/LuneX-18-3_6-tvos-r4.wGNQq9`结构化通过`succeeded/0 warning/0 error/0 analyzer warning`并有一份AIR/metallib；固定UUID仅作build destination。
- fresh normal `/tmp/LuneX-18-3_6-normal-r2.fzHNaM`结构化通过`1024 total / 1023 passed / 1 exact Keychain skip / 0 failed / 0 expected failure`且build四类diagnostic为0；下一步五平台fresh Debug builds。
- 五平台fresh Debug `/tmp/LuneX-18-3_6-builds-r2.cEhpxR`全部结构化为`succeeded/0 warning/0 error/0 analyzer warning`且各有一份AIR/metallib；固定UUID仅作build destination，未执行simulator lifecycle。
- 已同步Task 3.6 runtime contract、completion roadmap、task plan、findings与progress的最终实现、证据、废弃证据原因和proof boundary；OpenSpec保持pre-mark `17/50 next 3.6`。下一步fresh repository pre-gate，通过后才勾选。
- 首轮repository pre-gate的静态断言误用不存在的`.restoreLocalNavigation` case名，在retained evidence前退出且不计验收；按实际`.restoreLocalFocus(reason)`修正。
- fresh repository pre-gate `/tmp/LuneX-18-3_6-repository-pre.w3TVP6`完整通过fixture self/tree、strict `9/9`、pre-mark `17/50 next 3.6`、四次稳定generator、九文件精确scope、current source/test/membership时序语义、全部retained tests/builds及privacy/clean-room/reference/opt-in/process/diff边界。
- OpenSpec 3.6已勾选，预期权威状态为`18/50 ready`、next 3.7。下一步仅运行post-mark只读final-state，禁止重复test/build/generator/simulator操作。
- post-mark只读final-state `/tmp/LuneX-18-3_6-final-state.a7qNA6`通过strict `9/9`、apply `18/50 next 3.7`、稳定project hash、十文件精确scope、current source/task/docs、全部retained tests/builds及privacy/clean-room/reference/opt-in/process/diff边界；未重复test/build/generator/simulator操作。下一步post-record与最终diff审计。
- post-record `/tmp/LuneX-18-3_6-post-record.dHIyHe`通过`18/50 next 3.7`、project hash、十文件scope、pre/final记录、retained evidence、opt-in/process/reference与diff门。
- 最终人工diff审计确认per-operation release accounting、actual admission、完整effect FIFO、controller quiesce/provider barrier/local restoration、stale-open intent fence、provider failure和terminal join成立；未发现新问题，3.6进入独立提交推送。
- 3.6已提交推送为`bfe4e10 Order tvOS held input release`；fetch确认`HEAD == origin/main`且工作树clean。OpenSpec为`18/50 ready`、next 3.7。
- 启动3.7 coverage inventory：逐项映射remote order、focus/overlay、reserved command、controller profile/slot/capacity/feedback/disconnect、stale callback、release/replacement/teardown的现有执行级回归，先找缺口再修改测试。
- coverage inventory确认大部分单项合同已有执行级覆盖，但发现legacy `TVRemoteFocusInputAdapter.focus()`会序列化本地focus identity，且active-stream Menu缺显式local reservation；已修为两者始终local-only并补两项adapter回归。
- AppModel完整tvOS input workflow新增scene release pending和stop后的stale roster/motion/feedback注入，断言不会恢复controller state、留下feedback decision或新增remote input send。下一步运行三项focused gate。
- 沿真实数据流发现`.tvRemote`被provider交给codec后必然`unsupportedEvent`，原focused 3/3只作为中间证据。已在provider边界归约六类supported Siri Remote按键到既有canonical keyboard wire，并新增六键balanced packet order、Menu/focus local-only及reverse-order exactly-once release回归；下一步fresh focused验证。
- fresh focused wire首轮仅在测试编译期因release预期数组推断为`Int`而退出；显式改为`[UInt16]`后的fresh `/tmp/LuneX-18-3_7-focused-wire-r2.VJmS3q`通过`6/6`且结构化diagnostics为0。首轮related执行`236`项仅发现旧inactive-stream测试误用Menu断言通用inactive原因；改用supported Select覆盖该分支后重新从fresh focused/related验收。
- 修订后fresh focused `/tmp/LuneX-18-3_7-focused-r3.g0X36e`结构化通过`7/7`，fresh related `/tmp/LuneX-18-3_7-related-r2.2QaiwN`通过`236/236`；均`0 skipped / 0 failed / 0 expected failure`且build warning/error/analyzer warning为0。下一步fresh normal suite。
- fresh normal `/tmp/LuneX-18-3_7-normal.WCovl0`结构化通过`1027 total / 1026 passed / 1 exact Keychain skip / 0 failed / 0 expected failure`且build三类diagnostics为0；fixed tvOS `/tmp/LuneX-18-3_7-tvos.PwAk1O`为零诊断并有一份AIR/metallib。五平台fresh Debug `/tmp/LuneX-18-3_7-builds.N3IHzH`全部零结构化诊断且各有一份AIR/metallib；固定UUID仅作build destination，未执行simulator lifecycle操作。
- 已同步3.7 provider mapping、local focus/Menu、stale callback、retained evidence与proof boundary到OpenSpec design/spec、阶段18 runtime contract、roadmap和三份planning。OpenSpec保持pre-mark `18/50 next 3.7`，下一步fresh repository pre-gate，通过后才勾选。
- macOS更新完成后恢复：session-catchup只报告本轮暂停检查点及已执行的恢复核对，没有未落盘的代码动作；重新确认Xcode `26.4` build `17E192`、Swift `6.3`、宿主macOS `27.0` build `26A5388g`、Keychain/live-host opt-in均unset、`HEAD == origin/main == bfe4e10`且仅有预期12个3.7文件。`git diff --check`通过，未查询或操作simulator inventory/lifecycle；下一步继续fresh repository pre-gate。
- 3.7 repository pre-gate首次包装调用在进入shell前被外层JavaScript把shell的`${...}`参数展开误解析为模板插值并抛出`SyntaxError: Unexpected token '%'`；没有创建gate目录、没有运行generator/test/build/simulator或改变工作区。改为显式转义shell展开后从fresh目录完整重跑。
- 第二轮partial pre-gate `/tmp/LuneX-18-3_7-repository-pre.psbsOR`通过fixtures、OpenSpec `9/9`与pre-mark `18/50 next 3.7`、generator四次稳定和精确12文件scope，但membership循环误用zsh特殊变量`path`覆盖命令搜索路径，随后报`rg: command not found`并退出；该轮不计验收，未重跑test/build或操作simulator。改用`source_file`后从fresh目录完整重跑。
- fresh repository pre-gate `/tmp/LuneX-18-3_7-repository-pre-r3.QRSRb6`完整通过fixture self/tree、OpenSpec strict `9/9`、pre-mark `18/50 next 3.7`、generator四次稳定SHA-256 `ef2e3e615f1dbd84b76bfe4c8681fab7d44291176f06324acd757fa1c1008353`、精确12文件scope、generator/project membership、provider mapping/Menu/focus local-only/resolved held-state/release语义、全部retained tests/builds及privacy/clean-room/reference/opt-in/process/diff边界。首次勾选补丁因planning记录中的字面量反斜杠锚点不匹配而原子拒绝、无部分修改；随后OpenSpec 3.7已勾选，下一步仅运行只读post-mark final-state，禁止重复test/build/generator/simulator操作。
- post-mark只读final-state `/tmp/LuneX-18-3_7-final-state.fKKBFH`通过strict `9/9`、apply `19/50 next 4.1`、稳定project hash、精确13文件scope、current source/task/tests、全部retained tests/builds及privacy/clean-room/reference/opt-in/process/diff边界；未重复test/build/generator/simulator操作。
- post-record `/tmp/LuneX-18-3_7-post-record.RaWllz`通过`19/50 next 4.1`、稳定project hash、13文件scope、五份权威文档中的pre/final记录、opt-in/process/reference与diff门；未重复test/build/generator/simulator操作。
- 最终只读文档搜索首轮因双引号内含Markdown反引号被zsh解析而报`unmatched \"`；改用单引号后确认runtime contract、roadmap与task plan没有残留3.7待门禁表述。完整生产/测试/OpenSpec/docs diff与authority check通过，未发现新的正确性、隐私或跨平台隔离问题，3.7进入独立提交推送。
- 3.7已提交推送为`685487d Complete tvOS input regression`；`git push`与fetch后确认`HEAD == origin/main == 685487d916f0a7baa628a214aa061c47584a1bf1`且工作树clean。OpenSpec权威进度为`19/50`、next 4.1。
- 启动4.1 actual tvOS媒体呈现盘点：按`openspec-apply-change`读取apply context，追踪actual scene/surface/geometry、`StreamMetalPresenter`、current decoded-frame source、stale rejection及clear/resume ownership；本项不提前实现HDR/audio或把unsigned build表述为runtime/physical证明。
- 4.1 inventory确认actual surface/presenter与platform coordinator当前是两条独立路径：presenter直接读取shared latest frame，coordinator production action client为noop。已确定最小修复为AppModel/environment注入的main-actor actual presentation owner，加presenter platform-admitted-frame模式及surface generation注册；先落执行级focused tests，再运行分层验收。
- 4.1首轮编译探针中macOS命令误用不存在的`LuneX` scheme而在build前退出；tvOS实际编译只报warnings-as-errors下恒真的`TVVisionStreamMetalView`条件转换。已按`makeUIView`分支的静态类型移除转换，后续改用`LuneX-macOS`，两项探针均不计最终验收。
- 最终记录的两次组合补丁分别因roadmap表格删除行遗漏unified-diff前缀、Markdown bullet上下文前缀错误而被`apply_patch`原子拒绝，均无部分修改；已按正确前缀拆分。runtime contract、completion roadmap、task plan、findings与progress同步完成后运行只读post-record和最终人工diff审计。
- 第三轮partial pre-gate `/tmp/LuneX-18-3_7-repository-pre-r2.qePvq5`进一步通过membership及mapping/local-only/resolved-held-state/release静态语义，随后因包装器以格式敏感文本匹配`"nodeType" : "Skipped Test"`而退出；实际压缩test-tree的唯一skip是结构化`nodeType="Test Case"/result="Skipped"`且精确为`HostAndPersistenceTests/testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`。改用`jq`递归结构化断言后从fresh目录完整重跑；该轮不计验收，未重跑test/build或操作simulator。

## 2026-08-07 阶段 18 任务 4.1 续接

- 系统更新后按planning-with-files catchup恢复，确认active goal、OpenSpec `19/50 next 4.1`、`HEAD == origin/main == 685487d`及仅有预期4.1工作树修改；未查询、创建、启动或操作simulator，Keychain/live-host opt-in保持unset。
- 续接人工审计发现frame-surface replacement、closed scene/display late video和in-flight旧draw三处未覆盖边界；production owner已增加admitted surface generation、scene/display eligibility、stale delivery/identity守卫，presenter新frame推进revision并使重复clear幂等。
- 新增actual `MTKView`/recording runtime focused测试，覆盖shared latest frame不能绕过platform admission、coordinator decoded frame实际进入presenter、scene loss清屏、surface replacement只恢复匹配frame及stale surface application inert；coordinator新增unknown display baseline SDR、decoder-start无`.video`与geometry revision重交current frame合同。尚未运行fresh focused，4.1不得勾选或提交。
- 首轮focused `/tmp/LuneX-18-4_1-focused.U0uUni`误用无test action的`LuneX-macOS` app scheme，在任何编译或测试前exit 66；不计验收。`xcodebuild -list`再次确认应使用`LuneXCoreTests` test scheme，下一轮从fresh目录运行且不重复失败命令。
- 第二轮focused `/tmp/LuneX-18-4_1-focused-r2.4AqAen`成功零源码诊断编译，coordinator两项与shared-source bypass一项通过，两个owner presenter用例失败。串行解析xcresult确认离屏`MTKView.draw()`不会自动回调delegate，recording runtime连初始clear都为0；测试改为在每个调度点显式调用`presenter.draw(in:)`，production调度未改，失败bundle不计最终证据。
- 扩展focused `/tmp/LuneX-18-4_1-focused-r4.Dx4SoW`为6/7通过，replacement ownership与新增边界均成立；唯一stale测试因主动draw合法重绘current frame而得到`[50,50]`，没有49/51/52/53 stale ID。修正预期为两次current且display unavailable后不再增加，失败bundle不计最终证据。
- fresh focused `/tmp/LuneX-18-4_1-focused-r5.1gdLMC`结构化通过`7/7 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded/0 warning/0 error/0 analyzer warning`；下一步运行完整presenter/coordinator/environment/AppModel/platform-state/geometry/frame/HDR related matrix。
- 系统更新结束后恢复4.1：重新确认Xcode `26.4`/Swift `6.3`、macOS `27.0`、Git基线`685487d`、预期九文件scope与Keychain/live-host opt-in unset；未查询或操作simulator。session-catchup报告的未同步尾部已按实际工作树和retained evidence补入三份planning文件。
- 已串行只读解析既有fresh related `/tmp/LuneX-18-4_1-related.hqr5RJ/related.xcresult`：`240/240 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded/0 warning/0 error/0 analyzer warning`。没有重复测试；下一步production/test diff竞态审计。
- production diff审计发现并修复owner replacement次序：foreign session不再因更高media generation接管，同session input-only generation replacement现可合法接管；新增执行级双向测试。production已变化，先前focused/related仅保留为中间证据，下一步fresh focused。
- 修订后fresh focused `/tmp/LuneX-18-4_1-focused-r6.EoFPrA`结构化通过`8/8 passed / 0 skipped / 0 failed / 0 expected failure`且build四类diagnostic为0；下一步fresh related matrix。
- 修订后fresh related `/tmp/LuneX-18-4_1-related-r2.ymJCRP`结构化通过`241/241 passed / 0 skipped / 0 failed / 0 expected failure`且build四类diagnostic为0；人工production/test diff审计未发现新缺口。下一步fresh normal suite。
- fresh normal `/tmp/LuneX-18-4_1-normal.nHnZZj`结构化通过`1035 total / 1034 passed / 1 skipped / 0 failed / 0 expected failure`且build四类diagnostic为0；唯一skip由原始日志精确确认为`HostAndPersistenceTests/testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`。test-tree只读子命令触发Xcode 26.4已知database move冲突，未重复，summary/build-results与日志已足够完成该门。
- fixed Apple TV direct Debug `/tmp/LuneX-18-4_1-tvos.4dvUQ4`结构化为`succeeded/0 warning/0 error/0 analyzer warning`且有`1 AIR/1 metallib`；固定UUID仅作build destination，未查询或操作simulator lifecycle。下一步fresh五平台Debug。
- 五平台首轮`/tmp/LuneX-18-4_1-builds.nhyiEK`仅进入macOS并在源码编译前因entitlement development-signing要求exit 65，其余平台未开始；不计验收。下一轮显式`CODE_SIGNING_ALLOWED=NO`保留离线编译边界并从fresh目录重跑。
- fresh unsigned五平台Debug `/tmp/LuneX-18-4_1-builds-r2.Pl3YcW`中macOS、fixed iPhone/iPad/Apple TV/Vision Pro均结构化为`succeeded/0 warning/0 error/0 analyzer warning`，每个平台各有`1 AIR/1 metallib`；UUID仅作build destination且未执行simulator lifecycle。已同步OpenSpec design/spec、阶段18 runtime contract、completion roadmap和三份planning，OpenSpec仍保持pre-mark `19/50 next 4.1`。
- repository pre-gate `/tmp/LuneX-18-4_1-repository-pre.cIhA16`完整通过fixtures、strict `9/9`、pre-mark `19/50 next 4.1`、四次稳定generator、精确13文件scope、membership/current semantics、focused `8/8`、related `241/241`、normal `1035/1034/1/0`、direct/five-platform builds及privacy/clean-room/reference/opt-in/process/diff边界。4.1已勾选，下一步只读final-state。
- 首个勾选同步补丁因runtime contract实际换行与预期锚点不一致被`apply_patch`原子拒绝，无部分修改；读取精确片段后拆分完成，没有重复任何验收命令。
- 首次post-mark final-state包装器在进入shell前因外层JavaScript template literal内含Markdown反引号而抛出`SyntaxError: Unexpected number`；没有创建证据或执行任何门禁/模拟器操作，已改为无反引号的静态匹配并从fresh目录运行。
- 修正后的post-mark final-state `/tmp/LuneX-18-4_1-final-state-r2.BFSidM`只读通过strict `9/9`、`20/50 next 4.2`、稳定project hash、精确14文件scope、current task/source/test/docs、全部retained evidence与privacy/clean-room/reference/opt-in/process/diff边界；没有重复test/build/generator/simulator操作。下一步post-record、最终diff审计和独立提交推送。
- 系统更新后再次恢复并确认Xcode `26.4`、Swift `6.3`、macOS `27.0`、`HEAD == origin/main == 685487d`、Keychain/live-host opt-in unset与精确14文件scope；没有查询或操作simulator。同步修正`task_plan.md`顶部阶段18摘要和roadmap中的4.1 gate路径。
- 首轮post-record `/tmp/LuneX-18-4_1-post-record.mkvGtQ`误用current-change strict并在合法`1/1`与错误预期`9/9`不符时退出；fresh `/tmp/LuneX-18-4_1-post-record-r2.AmeJ3m`改用repository `--all`口径后完整通过`20/50 next 4.2`、strict `9/9`、稳定project hash、14文件scope、五份权威记录、retained evidence及opt-in/process/reference/diff边界，未重复test/build/generator或simulator操作。下一步最终人工diff审计与独立提交推送。
- 最终production/test/OpenSpec/docs diff审计确认shared-latest bypass关闭、同owner production wiring、platform/session和media/presentation/input replacement顺序、sequence/platform/delivery/decoder/frame/surface/draw fence、scene/display clear、geometry重交、unbind/rebind、stop及old terminal/application边界完整；unknown display没有被提升为HDR能力，4.2–4.4保持pending。未发现新问题，4.1进入独立提交推送。
- 4.1已提交推送为`69832a2 Bind tvOS frame presentation`；fetch确认`HEAD == origin/main == 69832a233f9d8f11a232f5a4f6ab29c15733f3bd`且工作树clean，OpenSpec为`20/50 ready`、next 4.2。
- 启动4.2并完成首轮public SDK/现有HDR抽象盘点：tvOS旧EDR属性继续不可用，但26.4公开`CALayer.preferredDynamicRange`、`contentsHeadroom`、`toneMapMode`和actual-screen headroom读取。确定4.2只实现完整能力probe与transactional layer/color基础，缺任一条件保留typed HDR-to-SDR；actual scene revision/AppModel/UI与物理证明不在本项。
- 4.2 device public API probe直接通过；首次simulator probe错误复用device SDK并因standard library不匹配退出，改用`appletvsimulator` SDK后warnings-as-errors通过。首个source组合patch因validation上下文不匹配被原子拒绝，按真实片段拆分后完成，无部分修改残留。
- 完成4.2第一版production/test实现：独立preferred-dynamic-range/headroom capability、完整typed fallback resolver、tvOS native screen/layer/color probe、surface content-headroom identity、new-path transactional mutation/rollback和resolver EDR gate；4.3 observer/revision/AppModel未接入。
- fixed Apple TV direct Debug `/tmp/LuneX-18-4_2-compile-tv.f3NC2P`成功且零结构化诊断；固定UUID只作build destination，没有查询或操作simulator lifecycle。
- focused首轮`/tmp/LuneX-18-4_2-focused.lkIQzA`通过`53/53`后，审计新增preferred headroom mutation failure rollback用例，故降为中间证据；fresh `/tmp/LuneX-18-4_2-focused-r2.c7E7yZ`通过`54/54`且零结构化诊断。下一步related matrix。
- 系统更新后续接4.2：重新确认active goal、`HEAD == origin/main == 69832a2`、OpenSpec `20/50 next 4.2`、Xcode 26.4/Swift 6.3/macOS 27.0、预期十一文件scope和两个opt-in unset；未查询或操作simulator lifecycle。
- 完整production/test diff审计确认legacy metadata路径、preferred dynamic range/headroom transaction与rollback边界成立；补充`+infinity`、超界potential及surface contract非有限值回归。此前54/209/normal/direct/five-platform结果均早于最后production normalization，不作为最终证据。
- 记录此前normal包装器的尾部grep假失败：测试与结构化结果成功，只有字面量`skipped on`未命中；fresh normal改用结构化结果与宽化skip日志匹配。首个跨三份planning组合补丁因锚点不一致被原子拒绝、无部分修改，已按真实锚点拆分。下一步fresh focused。
- fresh focused `/tmp/LuneX-18-4_2-focused-r3.uUoogT`结构化通过`54/54 passed / 0 skipped / 0 failed / 0 expected failure`且build结构化error/warning/analyzer warning为0；新增nonfinite/out-of-range回归通过。下一步fresh 13-suite related matrix。
- fresh related `/tmp/LuneX-18-4_2-related-r2.X5RkJV`结构化通过`209/209 passed / 0 skipped / 0 failed / 0 expected failure`且build/source diagnostics为0。下一步fresh normal suite，两个opt-in继续unset。
- fresh normal `/tmp/LuneX-18-4_2-normal-r2.q9nMOC`结构化通过`1040 total / 1039 passed / 1 exact Keychain skip / 0 failed / 0 expected failure`且build/source diagnostics为0；两个opt-in保持unset。下一步fresh fixed Apple TV direct build。
- fresh fixed Apple TV direct `/tmp/LuneX-18-4_2-tvos-r2.gAirdH` unsigned Debug build成功、结构化/source diagnostics为0并有`1 AIR / 1 metallib`；固定UUID仅作destination，未操作simulator lifecycle。下一步fresh unsigned五平台Debug matrix。
- fresh unsigned五平台Debug `/tmp/LuneX-18-4_2-builds-r2.9ndfoH`中macOS、fixed iPhone/iPad/Apple TV/Vision Pro全部成功、结构化/source diagnostics为0且各有`1 AIR / 1 metallib`；UUID仅作destination，未执行simulator lifecycle。下一步完整diff审计与权威文档同步，4.2仍保持未勾选。
- 已同步OpenSpec design/spec、阶段18 runtime contract、completion roadmap和三份planning；精确pre-mark scope为15文件，OpenSpec仍为`20/50 next 4.2`。下一步fresh repository pre-gate，通过后才勾选4.2。
- fresh repository pre-gate `/tmp/LuneX-18-4_2-repository-pre.IRGscf`完整通过fixtures、strict `9/9`、pre-mark `20/50 next 4.2`、四次稳定generator、精确15文件scope、membership/current semantics、全部retained tests/builds及privacy/clean-room/reference/opt-in/process/diff边界。
- OpenSpec 4.2已勾选，预期为`21/50 ready`、next 4.3。下一步只读post-mark final-state，禁止重复test/build/generator/simulator操作。
- 首次post-mark final-state包装器在进入shell前因外层JavaScript template literal中的Markdown反引号抛出`SyntaxError: Unexpected number`；没有创建证据或运行任何门禁/模拟器操作。已移除敏感匹配并准备fresh重跑。
- 修正后的post-mark final-state `/tmp/LuneX-18-4_2-final-state-r2.l4fp0g`只读通过strict `9/9`、`21/50 next 4.3`、稳定project hash、精确16文件scope、current source/task/docs、全部retained evidence与privacy/clean-room/reference/opt-in/process/diff边界；未重复test/build/generator/simulator操作。下一步post-record与最终diff审计。
- post-record `/tmp/LuneX-18-4_2-post-record.YjRjuV`只读通过`21/50 next 4.3`、strict `9/9`、稳定project hash、16文件scope、五份权威记录、retained evidence及opt-in/process/reference/diff边界。下一步最终diff审计与独立提交推送。
- 首轮final audit `/tmp/LuneX-18-4_2-final-audit.J9NbmM`在diff/scope与strict通过后因包装器误匹配不存在的`contentHeadroom: normalizedHeadroom`字段退出；production真实字段为current/potential EDR headroom。未执行行为门禁，已修正匹配准备fresh重跑。
- 修正后的最终审计 `/tmp/LuneX-18-4_2-final-audit-r2.8dYwRn`完整通过16文件diff、strict `9/9`与`21/50 next 4.3`、production/regression semantics、no-4.3-scope-creep、proof boundary及reference/opt-in/process门；未发现新问题，4.2进入独立提交推送。

## 2026-08-07 阶段 18 任务 4.3 启动

- 系统更新后恢复active长期goal，确认`HEAD == origin/main == a27b90f`、工作树clean、Xcode 26.4/Swift 6.3/macOS 27.0；OpenSpec `integrate-tvos-visionos-runtime`为`21/50 ready`，next精确为4.3。
- 重新读取planning-with-files、OpenSpec apply说明、proposal/design/spec/tasks以及actual surface/coordinator/environment/AppModel/HDR数据流；4.3限定为tvOS actual display observation、semantic revision、current-generation application和bounded fallback diagnostic。
- `LUNEX_RUN_KEYCHAIN_TEST`与`LUNEX_RUN_LIVE_HOST_TEST`继续保持unset；固定UUID仅允许后续作为build destination，本项不查询、创建、启动、安装、关闭或删除simulator。
- 首个小范围命令误用无test action的`LuneX-macOS` scheme，编译前exit 66；此结果只记录为命令错误，不是源码/test失败，也没有触发Keychain或simulator。下一次改用实际test scheme。
- 正确`LuneXCoreTests` scheme进入Swift编译后只报generic `Screen`的`@Sendable`捕获；通知已按screen object注册并以observation UUID拒绝旧回调，删除重复identity捕获后准备增量重跑。
- 新增publisher/observer/coordinator测试首次编译发现两处test helper调用漏写`try`；已定向修正，未改变production语义，该失败候选不作为验收证据。
- coordinator display helper加入局部变量后需显式返回，第二次test编译准确发现unused initializer；已改为`return try`，production继续无新增编译错误。
- 系统更新后从交接点重跑两组focused：production与测试全部编译，37项中35项通过；两项失败收敛到同一partial-headroom合同不一致。已保留output-available fallback的有效potential值、继续禁止不可用输出携带headroom，并新增构造回归；下一步重跑相同focused候选。
- 修订后增量focused通过`39/39`。现已增加AppModel完整display workflow回归及可携带rebranded display/semantic-exhaustion的state helper，准备先单跑该用例收敛跨任务时序与状态断言。
- 首条AppModel display workflow单测通过。随后production审计修复application error静默吞掉和revision exhaustion未终止coordinator的缺口，并在surface invalidation时释放display handler；现需重跑两条AppModel focused及相关两组display测试。
- 修订后的41项增量display/AppModel focused全部通过。继续审计后收紧tvOS resolution与snapshot字段一致性，新增跨平台、字段不一致和invalid direct EDR负向测试；因此最终fresh验收仍未开始。
- 系统更新完成后按planning-with-files catchup恢复：确认active goal、`HEAD == origin/main == a27b90f`、预期11文件scope、OpenSpec `21/50 next 4.3`、Xcode 26.4/Swift 6.3/macOS 27.0、两个opt-in unset及`git diff --check`通过；未查询或操作simulator。下一步完整读取change context并继续4.3生产代码审计。
- 首次续接记录补丁因三份planning尾部锚点不一致被`apply_patch`原子拒绝，无部分修改；读取真实末尾后完成分文件追加。
- 读取全部OpenSpec context并开始production/test竞态审计；发现新surface scene application可能携带旧display component回流、绕过AppModel replacement clear。准备增加current source component identity gate与对应workflow回归，production变化后此前增量`41/41`只作历史推进证据。
- 已实现AppModel current-source display component identity gate：比较platform/display generation/output/headroom/layer/resolution并明确忽略coordinator重品牌revision；workflow新增surface replacement后旧display随新scene回流仍保持render/fallback关闭。下一步先单跑该用例，再继续application/terminal竞态审计。
- replacement回流单测在fresh `/tmp/LuneX-18-4_3-replacement-check`通过。随后审计修复output-unavailable resolver仍携带screen headroom、可能触发snapshot构造失败并误报revision exhaustion的问题；新增输出不可用时强制清空headroom回归，下一步重跑display focused集合。
- 审计进一步收紧source-to-coordinator窗口：新display source到达即同步关闭旧render状态，matching coordinator回流后才重开，HDR platform capability读取也受同一identity gate约束；现有AppModel用例增加异步application前立即关闭断言。下一步fresh focused必须覆盖这三处最终production变化。
- reconnect调查确认同view不变geometry的统一replay缺口属于4.5，已记录但未在4.3建立display旁路。一次推测源文件路径读取失败后已定位真实owner在`MetalStreamSurface.swift`；该只读错误无代码副作用。继续4.3 focused验收前的最后diff/合同审计。
- fresh focused `/tmp/LuneX-18-4_3-focused-final.BN6ZYp`结构化通过`190/190 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded/0 warning/0 error/0 analyzer warning`；两个真实opt-in unset且未操作simulator。下一步fresh related matrix。
- fresh related `/tmp/LuneX-18-4_3-related-final.ztmMov`结构化通过`361/361 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded/0 warning/0 error/0 analyzer warning`；未操作simulator。下一步fresh normal suite。
- fresh normal `/tmp/LuneX-18-4_3-normal-final.kN6LiU`结构化通过`1047 total / 1046 passed / 1 exact Keychain skip / 0 failed / 0 expected failure`，build为`succeeded/0 warning/0 error/0 analyzer warning`；两个真实opt-in unset，未操作simulator。下一步fresh fixed Apple TV direct build。
- fresh fixed Apple TV direct `/tmp/LuneX-18-4_3-tvos-final.UlXTWd` unsigned Debug结构化通过`succeeded/0 warning/0 error/0 analyzer warning`且有`1 AIR/1 metallib`；固定UUID仅作destination，未操作simulator lifecycle。下一步fresh unsigned五平台Debug matrix。
- 2026-08-07：macOS系统更新完成后按planning-with-files catchup恢复。读取active goal、OpenSpec context与工作树，确认`HEAD == origin/main == a27b90f`、预期11文件scope、Xcode 26.4/Swift 6.3/macOS 27.0，以及`integrate-tvos-visionos-runtime 21/50 ready, next 4.3`；未查询或操作Simulator，也未访问Keychain/live host。
- 2026-08-07：只轮询系统更新前已有的五平台串行build session `38358`，收到`visionos=0`和最终`ALL_BUILDS_SUCCEEDED`；结合保留输出，macOS/iPhone/iPad/tvOS/visionOS均exit 0。未启动第二套矩阵，下一步逐个平台解析既有`/tmp/LuneX-18-4_3-builds-final.u2xQ44`中的`.xcresult`和Metal产物。
- 2026-08-07：五个平台保留`build.xcresult`全部结构化通过`succeeded / 0 warning / 0 error / 0 analyzer warning`，每个平台各`1 AIR / 1 metallib`。raw log各自唯一文本`warning:`是无AppIntents依赖时的metadata extraction skipped提示；不计源码warning。下一步执行最终production/test diff审计并同步4.3权威文档。
- 2026-08-07：首次4.3权威文档组合补丁因`design.md`换行锚点不精确被`apply_patch`原子拒绝，无部分修改；改为读取真实片段并按文件拆分补丁，不重复原命令。
- 2026-08-07：runtime contract的4.3章节首次插入又因误把行内`Post-record`当作独立段首而被原子拒绝，无部分修改；改用稳定的`## Fixed simulator inventory`章节标题作为插入锚点。
- 2026-08-07：首轮repository pre-gate `/tmp/LuneX-18-4_3-repository-pre.P3irNL`的正向fixture/OpenSpec/generator/scope/evidence检查均运行成功，但负向扫描错误使用`! rg`并依赖`set -e`退出；Bash会豁免该上下文，且state文件合法地在`#if os(tvOS)`内导入UIKit/QuartzCore，因此该轮即使打印PASSED也不计验收。改为显式`if rg; then exit 1; fi`并验证条件编译边界后从fresh目录完整重跑。
- 2026-08-07：corrected pre-gate r2 `/tmp/LuneX-18-4_3-repository-pre-r2.3IjRdc`通过到platform header边界，随后仅因预期fixture未包含`#endif`后的空行而由`diff`退出；不是源码或边界失败。改为比较精确前7行并从fresh目录完整重跑。
- 2026-08-07：fresh repository pre-gate r3 `/tmp/LuneX-18-4_3-repository-pre-r3.FVSiWy`完整通过fixture self/tree、OpenSpec strict `9/9`与pre-mark `21/50 next 4.3`、generator三次稳定SHA-256 `ef2e3e615f1dbd84b76bfe4c8681fab7d44291176f06324acd757fa1c1008353`、精确15文件scope、membership/privacy/reference/dependency/platform/opt-in/process/diff、focused/related/normal/direct tvOS及五平台保留证据。现勾选4.3，预期`22/50 next 4.4`，随后只读final-state/post-record和最终人工diff审计。
- 2026-08-07：首个post-mark final-state包装器在shell启动前因JavaScript模板字符串内含Markdown反引号而解析失败；未执行门禁或修改仓库。移除该模式中的反引号后从fresh目录运行只读final-state。
- 2026-08-07：post-mark final-state r2 `/tmp/LuneX-18-4_3-final-state-r2.F6VGG8`确认strict、`22/50 next 4.4`、16文件scope及前三项文档状态后，在把合同中跨两行的same-MTKView/4.5边界误写成单行正则处退出；改为两个独立短语断言后fresh重跑，不重复测试/build/generator。
- 2026-08-07：post-mark final-state r3 `/tmp/LuneX-18-4_3-final-state-r3.ShiHBj`完整通过OpenSpec strict `9/9`、`22/50 next 4.4`、4.3 done、稳定generator SHA-256、精确16文件scope、权威文档、retained focused/related/normal/direct/five-platform evidence及privacy/reference/dependency/opt-in/process/diff边界。下一步只读post-record与最终人工diff审计，然后独立提交推送。
- 2026-08-07：post-record `/tmp/LuneX-18-4_3-post-record.2zqnMO`完整通过`22/50 next 4.4`、authority records、稳定generator hash、16文件scope和全部边界。最终逐文件production diff审计未发现新问题；4.3准备独立提交并推送，阶段18/长期goal保持active。
- 2026-08-07：4.3提交`045ae3d Connect tvOS display HDR runtime`已推送；fetch确认`HEAD == origin/main == 045ae3d`且工作树clean。OpenSpec为`22/50 ready`、next 4.4。
- 2026-08-07：完成4.4只读数据流盘点。复用现有actual AVAudioSession notification source、route capability reader、canonical audio runtime/graph generation、listener head-tracking readback和environment/AppModel event path；计划扩展runtime event与platform audio snapshot、增加bounded publisher，并在environment tvOS ownership激活/后续事件上应用coordinator。真实Keychain/live-host opt-in保持unset，不操作simulator。
- 2026-08-07：4.4第一版production路径已接入，但首轮focused编译候选`/tmp/LuneX-18-4_4-compile.gXpicM/compile.xcresult`因event自定义initializer漏接route/entitlement而失败；包装器还误写zsh只读变量`status`。两项均已记录，该轮不计验收，下一轮改用全新证据目录与`build_status`。
- 2026-08-07：系统更新后恢复active长期goal、OpenSpec `22/50 ready, next 4.4`与预期14文件工作树；轮询既有测试会话`35078`至exit 0，未启动第二套会话。串行读取`/tmp/LuneX-18-4_4-environment-r1.fhwxMz/environment.xcresult`确认新增三项SessionMediaEnvironment audio runtime用例全部通过，`0 skipped / 0 failed`且build为`succeeded / 0 warning / 0 error / 0 analyzer warning`。下一步审计错误传播并补AppModel/coordinator状态合同。
- 2026-08-07：扩展现有AppModel tvOS current/reconnect/replacement/remote termination/local stop workflow，使合成current coordinator snapshot携带一致scene/input/display/audio完整presentation并验证公开state/snapshot。首个定向包装器误用`analyze test`导致编译前destination exit 70；已记录并改回保留成功命令的单一`test` action，不重复失败形式。
- 2026-08-07：AppModel fresh专项`/tmp/LuneX-18-4_4-appmodel-r2.FpHLzs`结构化通过`2/2`且build四类diagnostics为0。随后在既有coordinator complete/audio-action-failure/stop测试中补充独立`audioRoute` active存在与terminal清空断言；下一步从fresh目录运行4.4最终focused集合。
- 2026-08-07：4.4 fresh focused `/tmp/LuneX-18-4_4-focused-final.RfLgmT`结构化通过`248/248 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`。两个真实opt-in unset，未操作Simulator；下一步fresh related regression。
- 2026-08-07：fresh related `/tmp/LuneX-18-4_4-related-final.dg14Fj`结构化通过`332/332 passed / 0 skipped / 0 failed / 0 expected failure`，build四类diagnostics为0；下一步fresh normal suite，继续禁止真实Keychain/live host与Simulator操作。
- 2026-08-07：fresh normal `/tmp/LuneX-18-4_4-normal-final.NH3JbN`结构化通过`1054 total / 1053 passed / 1 exact Keychain skip / 0 failed / 0 expected failure`，build四类diagnostics为0；唯一skip由xcresult test tree精确确认。下一步fixed Apple TV direct unsigned build。
- 2026-08-07：fresh fixed Apple TV direct `/tmp/LuneX-18-4_4-tvos-final.3bnJ39` unsigned Debug结构化为`succeeded / 0 warning / 0 error / 0 analyzer warning`且有`1 AIR / 1 metallib`；UUID只作destination，未操作Simulator lifecycle。下一步fresh unsigned五平台Debug矩阵。
- 2026-08-07：fresh unsigned五平台Debug `/tmp/LuneX-18-4_4-builds-final.OmDAeS`串行完成；macOS、fixed iPhone/iPad/Apple TV/Vision Pro均exit 0，逐个xcresult为`succeeded / 0 warning / 0 error / 0 analyzer warning`且各有`1 AIR / 1 metallib`。没有查询或操作Simulator lifecycle；下一步diff审计与权威文档同步，4.4保持pre-mark。
- 2026-08-07：首个四文档组合补丁因一行缺少patch前缀被原子拒绝、无部分写入；拆分后已同步OpenSpec design/tvOS media spec、阶段18 runtime contract、roadmap和三份planning。OpenSpec仍为pre-mark `22/50 next 4.4`；下一步fresh repository pre-gate。
- 2026-08-07：系统更新后启动4.4 repository pre-gate；首轮`/tmp/LuneX-18-4_4-repository-pre.vZGSsL`的fixture self/tree和strict `9/9`均通过，但包装器错误读取`.summary.total`而非当前`.summary.totals.items`，在apply/generator前退出且不计验收。首次三文件记录补丁的旧锚点不匹配并被原子拒绝、无部分修改；已改为真实尾部锚点，下一轮使用fresh evidence目录和当前OpenSpec JSON schema。
- 2026-08-07：corrected repository gate r2 `/tmp/LuneX-18-4_4-repository-pre-r2.VnUq13`通过fixtures、strict/apply、三次稳定generator、18文件scope、membership、production/test semantics、privacy/reference/dependency/opt-in/process、focused `248/248`、related `332/332`并读到normal `1054/1053/1/0`；随后因`rg -c`把唯一skip标识在同一JSON节点的三项字段出现误计为3而退出。下一轮改用JSON test-case节点统计并从fresh目录完整重跑。
- 2026-08-07：fresh repository pre-gate r3 `/tmp/LuneX-18-4_4-repository-pre-r3.FrvzgU`完整通过fixture self/tree、strict `9/9`、pre-mark `22/50 next 4.4`、三次稳定generator、精确18文件scope、source/test membership、current-generation/replay/failure/terminal semantics、privacy/clean-room/reference/dependency/opt-in/process/diff，以及retained `248/248` focused、`332/332` related、`1054/1053/1/0` normal、direct tvOS与五平台build证据。4.4已勾选，预期权威进度`23/50 next 4.5`；下一步只读post-mark final-state，不重复test/build/generator/Simulator操作。
- 2026-08-07：post-mark final-state `/tmp/LuneX-18-4_4-final-state.gObCd6`只读通过strict `9/9`、apply `23/50 next 4.5`、4.4 done、稳定project SHA-256、精确19文件scope、五份authority记录、全部retained evidence与opt-in/process/reference/diff边界；未重复test/build/generator/Simulator。下一步只读post-record和最终production/test/docs diff审计。
- 2026-08-07：post-record `/tmp/LuneX-18-4_4-post-record.yYoKIN`通过`23/50 next 4.5`、task done、稳定project hash、19文件scope、五份authority pre/final记录与proof/opt-in/process/reference/diff边界。最终审计 `/tmp/LuneX-18-4_4-final-audit.Q802vi`继续通过production data flow、no-second-observer/graph、no-new-audio-application-`try?`、terminal contract、test matrix、no removed contract和文档proof boundary；未发现新问题，4.4进入独立提交推送。
- 2026-08-07：首次精确staging编排在执行任何Git命令前因工具JavaScript参数引号拼写错误未解析；index未变化。下一次调用修正参数并继续精确19文件staging。
- 2026-08-07：4.4已提交推送为`89316e9 Connect tvOS audio route runtime`；fetch确认`HEAD == origin/main == 89316e9`且工作树clean，OpenSpec为`23/50 next 4.5`。开始4.5只读追踪shared generation lifecycle，确认same-view reconnect缺少geometry/display current snapshot replay；下一步在既有owner/observer增加不推进revision的显式replay并补确定性测试。
- 2026-08-07：系统更新后恢复active长期goal、OpenSpec `23/50 ready, next 4.5`和预期7文件工作树；`git diff --check`通过。fresh最小验证`/tmp/LuneX-18-4_5-minimal.Jo7NGA`使用macOS destination通过geometry/display replay两个用例，`TEST SUCCEEDED / 2 passed`；真实Keychain/live-host opt-in均unset，未查询或操作Simulator。下一步扩展existing AppModel tvOS reconnect/remote/local terminal workflow与environment shared teardown证据。
- 2026-08-07：首次三文件记录补丁因共享锚点假设不成立被`apply_patch`原子拒绝，无部分修改；读取真实尾部后按文件稳定锚点追加，不重复失败形式。
- 2026-08-07：新增native environment remote-termination/stop竞态测试的首轮fresh候选`/tmp/LuneX-18-4_5-remote.eNXp51`在测试编译期失败：Swift禁止在`XCTUnwrap`同步autoclosure内`await` actor snapshot/task value。生产代码未失败、测试未执行；改为分别await到局部optional后unwrap，并使用fresh证据目录重跑。
- 2026-08-07：AppModel跨层reconnect专项`/tmp/LuneX-18-4_5-reconnect.fzySX5`通过，证明同surface/current geometry+display在media generation 2重新形成`activate/scene/input/display`，旧代状态不变异replacement，remote termination清空并恢复overlay。native environment remote竞态修正版`/tmp/LuneX-18-4_5-remote-r2.MSafes`通过，证明remote stop与environment stop共享一次terminal/coordinator/resource teardown并逐项清理5个资源；两个真实opt-in继续unset，未操作Simulator。
- 2026-08-07：fresh focused `/tmp/LuneX-18-4_5-focused-final.EhLafe`结构化通过`248/248 passed / 0 skipped / 0 failed / 0 expected failure`；fresh related `/tmp/LuneX-18-4_5-related-final.C3tjgy`结构化通过`474/474`。两者build均`succeeded / 0 warning / 0 error / 0 analyzer warning`；下一步fresh normal，真实opt-in继续unset且不操作Simulator。
- 2026-08-07：fresh normal `/tmp/LuneX-18-4_5-normal-final.1mF6gc`结构化通过`1055 total / 1054 passed / 1 skipped / 0 failed / 0 expected failure`，build四类diagnostics为0。首次并行解析同一xcresult时test-tree读取因内部`database.sqlite3`冲突失败；随后一个含不必要`rm -f`的串行命令在进程启动前被安全规则拒绝。改用新文件名串行读取后，唯一skip精确为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`；未访问真实Keychain/live host或操作Simulator。下一步fixed Apple TV unsigned Debug。
- 2026-08-07：fresh fixed Apple TV direct `/tmp/LuneX-18-4_5-tvos-final.UNpi51` unsigned Debug结构化为`succeeded / 0 warning / 0 error / 0 analyzer warning`，生成`1 AIR / 1 metallib`；固定UUID只作destination，未查询/启动/安装/关闭Simulator。下一步fresh unsigned五平台Debug矩阵。
- 2026-08-07：fresh unsigned五平台Debug `/tmp/LuneX-18-4_5-builds-final.13Nwur`串行完成；macOS、fixed iPhone/iPad/Apple TV/Vision Pro均exit 0，逐个xcresult为`succeeded / 0 warning / 0 error / 0 analyzer warning`且各有`1 AIR / 1 metallib`。未启动第二套矩阵，未操作Simulator lifecycle。
- 2026-08-07：系统更新完成后恢复active goal与4.5现场；确认`HEAD == origin/main == 89316e9`、9个预期实现/测试/planning文件、`git diff --check`通过、OpenSpec `23/50 next 4.5`，工具链为Xcode 26.4/Swift 6.3/macOS 27.0。完整重读OpenSpec context并审计生产diff，未发现第二surface owner/display observer/decoder/audio graph或跨visionOS范围变化。
- 2026-08-07：首个OpenSpec/docs/planning组合补丁因`findings.md`尾部锚点不一致被`apply_patch`原子拒绝且无部分修改；改为按文件与稳定章节锚点拆分应用。现已同步OpenSpec design/tvOS media spec、阶段18 runtime contract、completion roadmap及三份planning，记录same-view current-value replay、revision不推进、geometry后display、replacement generation application、single audio publisher、remote/local shared terminal/resource teardown和proof boundaries。4.5仍为pre-mark `23/50 next 4.5`，下一步fresh repository pre-gate。
- 2026-08-07：fresh repository pre-gate `/tmp/LuneX-18-4_5-repository-pre.4s9qBy`完整通过fixture self/tree、strict `9/9`、pre-mark `23/50 next 4.5`、三次稳定generator、精确13文件scope、source/test membership、current-value replay/order/current-generation/shared teardown、privacy/clean-room/reference/dependency/opt-in/process/diff，以及retained focused `248/248`、related `474/474`、normal `1055/1054/1/0`、direct tvOS与五平台build证据。现已勾选4.5，预期`24/50 next 4.6`；下一步只读post-mark final-state。
- 2026-08-07：勾选后OpenSpec strict仍为`9/9`，apply精确为`24/50 ready`、4.5 done、next 4.6；runtime contract、roadmap与三份planning已同步final checkpoint及repository gate路径。下一步只读post-mark final-state，不重复测试、构建、generator或Simulator操作。
- 2026-08-07：post-mark final-state `/tmp/LuneX-18-4_5-final-state.5ZgeJt`只读通过strict `9/9`、`24/50 next 4.6`、4.5 done、稳定project SHA-256、精确14文件scope、final authority records、retained evidence及privacy/reference/dependency/opt-in/process/diff边界；未重复test/build/generator/Simulator。下一步post-record和最终production/test/docs diff审计。
- 2026-08-07：post-record `/tmp/LuneX-18-4_5-post-record.5B9rw1`与最终审计 `/tmp/LuneX-18-4_5-final-audit.ASK927`完整通过：OpenSpec `24/50 next 4.6`、14文件authority scope、2个production/4个test文件、replay identity/generation/revision/order、replacement terminal/resource teardown、无第二runtime/裸`try?`/隐私sink、retained evidence及proof boundary均成立。未发现新问题，4.5进入独立提交推送。
- 2026-08-07：4.5已提交推送为`8295ae7 Coordinate tvOS generation teardown`；fetch确认`HEAD == origin/main == 8295ae7`且工作树clean，OpenSpec为`24/50 ready`、next 4.6。开始盘点4.6 tvOS媒体综合回归，真实Keychain/live-host opt-in继续禁用，不查询或操作Simulator。
- 2026-08-07：4.6新增coordinator综合矩阵首轮`/tmp/LuneX-18-4_6-matrix.AoREWO`在测试编译期失败：Swift禁止在`XCTAssertEqual`同步autoclosure内直接`await coordinator.receiveVideo`。生产代码未修改/失败，测试未执行；现先await局部结果再断言，并从fresh evidence目录重跑。
- 2026-08-07：修正后的coordinator矩阵 `/tmp/LuneX-18-4_6-matrix-r2.v9KJoh`结构化通过`1/1`且build四类diagnostics为0，覆盖fallback/direct display、geometry frame resubmit、old decoder stale frame、interruption、media loss、graph generation 2 reset/recovery和一次clean local stop。现补AppModel公开render/audio current/reconnect/replacement/termination断言。
- 2026-08-07：cross-layer专项 `/tmp/LuneX-18-4_6-cross-layer.NGWR17`结构化通过`2/2`且build四类diagnostics为0；AppModel公开状态确认direct HDR headroom、head-tracked route、replacement graph generation 2/fixed-spatial route，以及reconnect/remote termination时render display/fallback清空。
- 2026-08-07：系统更新完成后重新读取active goal、OpenSpec全部context与工作树，确认长期goal仍active、OpenSpec `24/50 ready`且next 4.6、`HEAD == origin/main == 8295ae7`，未提交范围仍为两份test与三份planning。只等待更新前已有focused会话`3940`，未启动第二套。
- 2026-08-07：fresh focused `/tmp/LuneX-18-4_6-focused-final.snkyaA/focused.xcresult`串行解析为`249/249 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`。真实Keychain/live-host opt-in继续禁用，未查询或操作Simulator；下一步fresh related regression。
- 2026-08-07：首个related候选`/tmp/LuneX-18-4_6-related-final.BLZFvk`因复用4.5命令行时把字面双引号保留进`-only-testing`数组，Xcode在编译/测试前报unknown build action并exit 65；该轮不计验收。下一轮逐行去引号并使用fresh evidence目录。
- 2026-08-07：修正版fresh related `/tmp/LuneX-18-4_6-related-final-r2.gN1qLv/related.xcresult`结构化通过`474/474 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`。新增coordinator综合用例不属于这40个selector，故计数不变；下一步fresh normal。
- 2026-08-07：fresh normal `/tmp/LuneX-18-4_6-normal-final.FweI69/normal.xcresult`结构化通过`1056 total / 1055 passed / 1 skipped / 0 failed / 0 expected failure`，build四类diagnostics为0。串行test-tree读取确认唯一skip精确为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`；真实Keychain/live host未启用，下一步fixed Apple TV unsigned Debug。
- 2026-08-07：fresh fixed Apple TV direct `/tmp/LuneX-18-4_6-tvos-final.bVvyiw/tvos.xcresult` unsigned Debug结构化为`succeeded / 0 warning / 0 error / 0 analyzer warning`且生成`1 AIR / 1 metallib`；固定UUID仅作destination，没有操作Simulator lifecycle。下一步fresh unsigned五平台Debug矩阵。
- 2026-08-07：fresh unsigned五平台Debug `/tmp/LuneX-18-4_6-builds-final.njC11Q`串行完成；macOS、fixed iPhone/iPad/Apple TV/Vision Pro逐一结构化为`succeeded / 0 warning / 0 error / 0 analyzer warning`且各有`1 AIR / 1 metallib`。未创建或操作Simulator，下一步test-only diff审计与OpenSpec/runtime/roadmap同步，4.6保持pre-mark。
- 2026-08-07：完成4.6 test-only diff审计并同步OpenSpec design/tvOS media spec、阶段18runtime contract、completion roadmap及三份planning。综合序列、AppModel公开actual-state、完整fresh证据和physical/live proof boundary均已记录；OpenSpec保持pre-mark `24/50 next 4.6`，下一步fresh repository pre-gate。
- 2026-08-07：首次repository pre-gate工具包装因外层JavaScript字符串未正确转义长shell命令中的引号而在shell启动前报`SyntaxError`；没有创建证据目录、运行generator/test/build/simulator或改变仓库。下一轮改用raw模板从fresh目录完整执行。
- 2026-08-07：第二次repository pre-gate包装仍在shell启动前失败，原因是raw模板中的shell `${VAR:-}`被JavaScript当作模板插值并报`Missing } in template expression`；仍未产生任何仓库/证据副作用。改用`printenv`后重跑。
- 2026-08-07：fresh repository pre-gate `/tmp/LuneX-18-4_6-repository-pre.jpqOgA`完整通过fixture self/tree、OpenSpec strict `9/9`、pre-mark `24/50 next 4.6`、四次稳定generator SHA-256 `ef2e3e615f1dbd84b76bfe4c8681fab7d44291176f06324acd757fa1c1008353`、精确9文件test/authority scope、组合语义、privacy/clean-room/reference/dependency/opt-in/process/diff，以及matrix `1/1`、cross-layer `2/2`、focused `249/249`、related `474/474`、normal `1056/1055/1/0`、direct/five-platform build证据。现已勾选4.6，预期`25/50 next 5.1`；下一步只读post-mark final-state。
- 2026-08-07：暂停前首次post-mark final-state包装器仍在shell启动前因raw template内的Markdown反引号报`SyntaxError: Unexpected number`；没有创建final-state目录、执行门禁、修改仓库、访问Keychain或操作Simulator。修正版将完全移除template中的反引号与`${...}`，从fresh目录只读验证。
- 2026-08-07：post-mark预检的两个辅助`jq`分别误用`.result.metrics`和数组路径；首个formal目录`/tmp/LuneX-18-4_6-final-state.lmIpMr`随后通过OpenSpec、10文件scope、hash与前七项authority断言，但在不存在的spec标题`Current decoded frame survives geometry revision`处退出。实际summary字段在根对象，真实场景标题为`Connected media regression sequence completes`；这些均为只读包装错误，未重跑test/build/generator或操作Keychain/Simulator，下一轮fresh完整执行。
- 2026-08-07：修正后的post-mark final-state `/tmp/LuneX-18-4_6-final-state-r2.0Oe6dd`只读完整通过：strict `9/9`、OpenSpec `25/50 next 5.1`、4.6 done、稳定project SHA-256、精确10文件scope、production/project graph零diff、matrix/cross-layer/focused/related/normal/direct/five-platform保留证据、唯一Keychain skip以及privacy/reference/dependency/opt-in/process/diff边界均成立。未重复test、build、generator或Simulator操作；下一步post-record与最终diff审计。
- 2026-08-07：post-record `/tmp/LuneX-18-4_6-post-record.4dFTZB`与final audit `/tmp/LuneX-18-4_6-final-audit.mNUBR2`完整通过：10文件scope、2 test/8 authority、helper默认兼容、组合序列/public actual-state、无异步XCTest autoclosure、无production/project graph变化、无合同删除及proof boundary均成立，未发现阻止提交的问题。4.6进入独立提交推送，阶段18与长期goal保持active。
- 2026-08-07：4.6已提交推送为`00b2cf5 Verify tvOS media regression matrix`；fetch确认`HEAD == origin/main == 00b2cf5`且工作树clean，OpenSpec为`25/50 ready`、next 5.1。开始5.1 actual visionOS windowed surface observation盘点，继续禁用真实Keychain/live host且不查询或操作Simulator。
- 2026-08-07：5.1盘点确认既有actual view/generation/geometry owner已覆盖attachment/layout/scene/scale/drawable；缺口为同scene window replacement没有重绑notification、visionOS默认`canBecomeFocused == false`导致focus eligibility恒false，以及没有window visible/hidden/key/resign观察。XROS 26.4 public header确认`isKeyWindow`及四类UIWindow notification可用；实现将复用单一owner并保持tvOS语义，不提前进入5.2/5.3/6.x。
- 2026-08-07：调查时误读不存在的`Sources/LuneXCore/TVVisionPlatformPresentationState.swift`，随后改读真实`Sources/LuneXPlatform`路径；跨父目录`find`过慢被中止并改用`rg --files`确认无仓库AGENTS约束。均为只读且无设备副作用。
- 2026-08-07：5.1第一版已接入generation-owned window/scene observer：八类公开window/scene notification、弱identity、observation UUID、replacement token更换、late event拒绝、detach/invalidate；actual visionOS focus eligibility使用visible+interactive+key window，tvOS语义不变。新增generic observer与AppModel visionOS activate→scene/replacement/stale/detach测试，当前6文件scope且`git diff --check`通过；下一步fresh最小定向测试。
- 2026-08-07：首轮最小候选`/tmp/LuneX-18-5_1-minimal.tqUVIG`只在测试编译期失败：Swift无法推断`TVVisionUIKitWindowObservation`的两个generic class参数，后续outcome枚举错误为连锁诊断；production无诊断、测试未执行。现显式标注fake window/scene类型并从fresh目录重跑。
- 2026-08-07：修正版最小 `/tmp/LuneX-18-5_1-minimal-r2.rTbf7R`结构化通过`2/2`且build diagnostics为0；fixed Vision Pro `/tmp/LuneX-18-5_1-visionos-compile.8NsiO6` unsigned Debug结构化成功、diagnostics全零、`1 AIR/1 metallib`。UUID只作destination，未查询或操作Simulator lifecycle；下一步fresh focused affected classes。
- 2026-08-07：fresh focused `/tmp/LuneX-18-5_1-focused.2cR6CT/focused.xcresult`结构化通过`219/219`，fresh related `/tmp/LuneX-18-5_1-related.52fA7X/related.xcresult`结构化通过`121/121`；均`0 skipped / 0 failed / 0 expected failure`且build四类diagnostics为0。生产diff审计确认observer弱所有权、observation-ID late admission、visionOS key-window eligibility、tvOS focus-engine语义和geometry single-writer均成立，未提前进入5.2/5.3/6.x。下一步fresh normal suite。
- 2026-08-07：fresh normal `/tmp/LuneX-18-5_1-normal.CJi9Ut/normal.xcresult`结构化通过`1058 total / 1057 passed / 1 skipped / 0 failed / 0 expected failure`且build四类diagnostics为0；串行test tree确认唯一skip精确为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，真实Keychain/live-host opt-in均unset。下一步fixed Apple TV direct unsigned Debug。
- 2026-08-07：fixed Apple TV direct `/tmp/LuneX-18-5_1-tvos.r5KL4H/tvos.xcresult` unsigned Debug结构化为`succeeded / 0 warning / 0 error / 0 analyzer warning`且有`1 AIR/1 metallib`；与既有fixed Vision Pro `/tmp/LuneX-18-5_1-visionos-compile.8NsiO6`配套。fresh五平台 `/tmp/LuneX-18-5_1-builds.K3hUMY`中macOS、fixed iPhone/iPad/Apple TV/Vision Pro也全部同样通过。固定UUID只作destination，未操作Simulator lifecycle。
- 2026-08-07：完成production/test diff审计并同步OpenSpec design/visionOS window-input spec、阶段18runtime contract、completion roadmap及三份planning，记录八类window/scene notification、同scene replacement、observation-ID late admission、visionOS key-window focus、tvOS语义不变、geometry single-writer、fresh证据与proof boundary。OpenSpec保持pre-mark `25/50 next 5.1`，下一步fresh repository pre-gate。
- 2026-08-07：门禁准备时误以为generator支持`--help`，实际执行了一次生成；project文件未产生diff，其他仓库文件和设备状态未变化。该调用不计验收，正式repository pre-gate将从fresh目录重新执行fixture、strict/apply、生成前后及连续hash、scope/static/evidence/opt-in/process/diff全部检查。
- 2026-08-07：fresh repository pre-gate `/tmp/LuneX-18-5_1-repository-pre.v1iwKK`完整通过fixture self/tree、OpenSpec strict `9/9`、pre-mark `25/50 next 5.1`、生成前后及连续三次稳定project SHA-256 `ef2e3e615f1dbd84b76bfe4c8681fab7d44291176f06324acd757fa1c1008353`、精确10文件scope、membership、observer/generation/focus/single-writer语义、全部retained test/build、唯一Keychain skip以及privacy/clean-room/reference/dependency/opt-in/process/diff边界。现已勾选5.1，预期`26/50 next 5.2`；下一步只读post-mark final-state。
- 2026-08-07：首个post-mark final-state包装器在shell启动前因JavaScript raw template含Markdown反引号而报`SyntaxError: Unexpected identifier 'complete'`；没有证据目录、门禁、测试/build/generator、仓库或设备副作用。移除该匹配中的反引号后从fresh目录重跑。
- 2026-08-07：修正版post-mark final-state `/tmp/LuneX-18-5_1-final-state.BQG3yQ`只读完整通过OpenSpec strict `9/9`、`26/50 ready`、5.1 done、next 5.2、稳定project SHA-256、精确11文件scope、observer/focus/owner边界、全部retained test/build、唯一Keychain skip及opt-in/process/reference/dependency/diff检查；未重复test/build/generator或Simulator。下一步post-record与最终diff审计。
- 2026-08-07：首轮post-record `/tmp/LuneX-18-5_1-post-record.GmR0z6`在OpenSpec、11文件scope和authority计数通过后，因类名前缀同时匹配observer与预期token manager而把合法计数2误写为1并退出；不是实现缺陷或第二runtime。改用带泛型尖括号的精确observer声明后从fresh目录重跑。
- 2026-08-07：第二轮post-record `/tmp/LuneX-18-5_1-post-record-r2.Edevk9`因新增行筛选仍保留`+`、精确正则却未包含该前缀而把两个合法声明都计为0并退出。只读诊断确认observer泛型声明与token manager声明各1；修正行首后fresh重跑。
- 2026-08-07：修正后的post-record `/tmp/LuneX-18-5_1-post-record-r3.jAEfZ5`与final audit `/tmp/LuneX-18-5_1-final-audit.U5fWgQ`完整通过：OpenSpec `26/50 next 5.2`、11文件scope、1 production/2 test/8 authority、generation/weak identity/token replacement/observation UUID/platform focus/single geometry writer、无异步XCTest autoclosure、无越界input/media runtime、无删除合同及proof boundary。未发现阻止提交的问题，5.1进入独立提交推送。
- 2026-08-07：5.1已提交推送为`ea9d9fd Observe visionOS window surface state`；fetch确认`HEAD == origin/main == ea9d9fd`且工作树clean，OpenSpec为`26/50 ready`、next 5.2。5.2盘点确认2.3已有single geometry/drawable/fit-fill/input mapping owner，5.1已把actual visionOS window接入；本项将补visionOS综合回归，不复制production mapper或提前实现5.3 adapters。
- 2026-08-07：新增5.2 visionOS geometry综合测试草案；首轮静态检查发现把现有coordinator return type误写为不存在的`TVVisionSurfaceGeometryApplicationOutcome`，实际为`TVVisionStreamGeometryApplicationOutcome`。production未改且测试未运行，已修正后进入fresh最小验证。
- 2026-08-07：首轮fresh最小 `/tmp/LuneX-18-5_2-minimal.u2mOoj`编译成功但唯一测试失败两项：未先同步render transform的`.fill`导致coordinator按设计fail-closed，以及remote x为`240.00000000000006`的浮点exact比较。已按actual SwiftUI先render state后geometry update顺序修正，并改用有限精度断言；production未改。
- 2026-08-07：第二轮fresh最小 `/tmp/LuneX-18-5_2-minimal-r2.WAcxmT`在测试编译期因补丁宽锚点把render mode更新插入较早既有测试作用域而失败，新综合测试未执行。已移除误插并用fit input断言作为新测试唯一锚点精确加入，下一轮使用fresh证据。
- 2026-08-07：修正后的fresh最小 `/tmp/LuneX-18-5_2-minimal-r3.luBq4W`结构化通过`1/1`且build四类diagnostics为0；同一visionOS场景已串联fit/fill render snapshot、absolute mapping revision/coordinate、detach与invalid geometry对drawable/render/input的共同清理。下一步fresh affected回归。
- 2026-08-07：fresh完整presenter `/tmp/LuneX-18-5_2-presenter.7h2rAT`通过`71/71`，跨层focused `/tmp/LuneX-18-5_2-focused.wM0NK4`通过`220/220`，related `/tmp/LuneX-18-5_2-related.slZmgu`通过`121/121`；均无skip/failure/expected failure且build四类diagnostics为0。下一步fresh normal。
- 2026-08-07：fresh normal `/tmp/LuneX-18-5_2-normal.TjccHx`结构化通过`1059 total / 1058 passed / 1 skipped / 0 failed / 0 expected failure`，build四类diagnostics为0；唯一skip精确为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`。下一步fixed Vision Pro direct。
- 2026-08-07：fixed Vision Pro direct `/tmp/LuneX-18-5_2-visionos.ags3s2`成功且结构化diagnostics为0、`1 AIR/1 metallib`；fresh五平台 `/tmp/LuneX-18-5_2-builds.gqJzlP`中macOS、fixed iPhone/iPad/Apple TV/Vision Pro也全部同样通过。固定UUID只作destination，未查询或操作Simulator lifecycle。
- 2026-08-07：系统更新后恢复active goal并运行planning catch-up，确认`HEAD == origin/main == ea9d9fd`、OpenSpec `26/50 next 5.2`、未提交范围仍为1 test+3 planning。首个上一轮组合权威补丁因runtime contract锚点不精确被原子拒绝且无部分修改。
- 2026-08-07：续接后的runtime+roadmap组合补丁再次因把句中`Task 5.1 is ready for`误作独立行而原子拒绝，两文件均无部分修改；读取真实文本后使用稳定`## Fixed simulator inventory`标题并分文件成功应用。
- 2026-08-07：已同步OpenSpec design/visionOS window-input spec、阶段18runtime contract、completion roadmap及三份planning，记录2.3 shared production owner、actual SwiftUI update顺序、fit/fill render与absolute mapping同revision、detach/invalid共同关闭、5.3边界、完整fresh test/build证据及proof tiers。5.2保持pre-mark `26/50 next 5.2`，下一步fresh repository pre-gate。
- 2026-08-07：首轮repository pre-gate `/tmp/LuneX-18-5_2-repository-pre.oL1RlR`通过fixture、strict `9/9`、pre-mark `26/50 next 5.2`、三次稳定generator与精确8文件scope后，在静态测试断言处因包装器使用不存在的摘要示意变量`fitMapping/fitRenderCoordinates`而退出；真实源码为`fitInput.revision == fit.revision`。project hash稳定，未重跑test/build或操作Keychain/Simulator，下一轮使用真实变量并增加step marker。
- 2026-08-07：修正后的fresh repository pre-gate `/tmp/LuneX-18-5_2-repository-pre-r2.Jwvbum`完整通过fixture self/tree、strict `9/9`、pre-mark `26/50 next 5.2`、三次稳定project SHA-256 `ef2e3e615f1dbd84b76bfe4c8681fab7d44291176f06324acd757fa1c1008353`、精确8文件scope、零production/reference/dependency diff、test membership、fit/fill shared revision、detach/invalid共同关闭、全部retained test/build/Metal、唯一Keychain skip及disabled opt-in/no-process/diff边界。
- 2026-08-07：5.2现已勾选为complete，预期OpenSpec `27/50 ready`、next 5.3；下一步只读post-mark final-state，不重复test/build/generator/Keychain或Simulator操作。
- 2026-08-07：首轮post-mark final-state `/tmp/LuneX-18-5_2-final-state.AKfJyU`通过strict、OpenSpec `27/50 next 5.3`、task done、稳定project hash、精确9文件scope、零production diff与retained evidence后，因runtime合同自动换行导致单行短语断言未命中而退出；这是只读包装错误，未运行test/build/generator、访问Keychain或操作Simulator。下一轮使用真实稳定短语与step marker。
- 2026-08-07：修正后的post-mark final-state `/tmp/LuneX-18-5_2-final-state-r2.0VX1j5`只读完整通过strict `9/9`、`27/50 ready`、5.2 done、next 5.3、稳定project SHA-256、精确9文件scope、零production/reference/dependency diff、全部retained evidence、唯一Keychain skip及disabled opt-in/no-process/diff边界；未重复test/build/generator、Keychain或Simulator。下一步post-record与最终diff审计。
- 2026-08-07：首轮post-record `/tmp/LuneX-18-5_2-post-record.0BJeCj`通过OpenSpec和精确9文件/1 test/8 authority/0 production计数后，因包装器错误要求包括tasks checkbox替换在内的所有numstat deletion均为0而退出；真实结果仅`tasks.md`为预期`1 add/1 delete`，其余文件纯新增。无test/build/generator/Keychain/Simulator副作用，修正规则后fresh重跑。
- 2026-08-07：修正后的post-record `/tmp/LuneX-18-5_2-post-record-r2.d3bpX7`与final audit `/tmp/LuneX-18-5_2-final-audit.YC6Bfa`完整通过：OpenSpec `27/50 next 5.3`、9文件scope为1 test/8 authority/0 production、mode-before-geometry、fit/fill shared revision、detach/invalid共同清理、唯一tasks checkbox替换、无第二mapper/project/dependency/reference变化及全部proof boundary。未发现阻止提交的问题，5.2进入独立提交推送。
- 2026-08-07：5.2已提交推送为`8ed4ef9 Verify visionOS geometry mapping`；fetch确认`HEAD == origin/main == 8ed4ef9515bbe06bb3750ce12dbb9f51c10a954a`且工作树clean，OpenSpec为`27/50 ready`、next 5.3，长期goal保持active。
- 2026-08-07：启动5.3 public visionOS controller/keyboard/pointer/indirect input inventory与实现；边界为typed capability + current-generation/focus admission并复用既有canonical input transport，不提前处理5.4 reserved gaze/hand/system gesture或5.5 ordered release/local restoration。真实opt-in继续unset且不操作Simulator lifecycle。
- 2026-08-07：XROS 26.4三份direct warnings-as-errors typecheck探针 `/tmp/LuneX-18-5_3-probe.fbbrpe`、`/tmp/LuneX-18-5_3-input-probe.fcZdCe`、`/tmp/LuneX-18-5_3-scroll-probe.R0lyHz`全部RC 0，确认hardware key、indirect hover、scroll pan、GCMouse与GCController handler可公开编译；没有launch或操作Simulator。
- 2026-08-07：5.3实现确定为纯Vision adapter/surface event合同 + actual Metal view明确hardware/indirect过滤 + AppModel current-generation/focus/capability serial admission + 现有GameController slot/owner平台参数化；不接收direct/gaze/hand，不完成5.5 held release/local restoration。
- 2026-08-07：macOS更新后恢复长期active goal；planning catch-up、Git与OpenSpec确认未提交范围和`27/50 next 5.3`无漂移。开始为纯Vision adapter补HID/reserved/unknown、absolute mapping/button release/nonfinite scroll/path mismatch测试，并将controller slot/runtime owner以默认tvOS方式参数化支持visionOS。
- 2026-08-07：第一次搜索既有only-testing命令因pattern以`-`开头且遗漏`--`而被`rg`当作flag，改用`rg -n --`解决；只读且无设备副作用。首轮最小 `/tmp/LuneX-18-5_3-adapter.cNulZg`在测试编译期失败，根因为新adapter仅加入主sources、遗漏test support sources；已补generator双target membership，未执行任何测试方法或访问Keychain/Simulator。
- 2026-08-07：第二轮最小 `/tmp/LuneX-18-5_3-adapter-r2.wfPNcg`确认adapter membership生效，唯一编译错误为测试helper调用漏写`try`；production无diagnostic且测试未运行。已精确修正后从fresh目录重跑。
- 2026-08-07：第三轮最小 `/tmp/LuneX-18-5_3-adapter-r3.uDaGKa`成功执行21项并为20 passed/1 failed；唯一失败揭示共享controller snapshot/feedback仍有tvOS-only guard。保留`TVPlatformInputReleasePlan`的tvOS guard，只把共享registry snapshot与feedback request扩展到visionOS后fresh重跑。
- 2026-08-07：修正后的纯adapter/controller最小验收 `/tmp/LuneX-18-5_3-adapter-r4.UYHFT3`完整通过`21/21`；未启用Keychain/live-host opt-in，未操作Simulator。XROS探针另确认`UIPress`不存在`isRepeat`，production按公开API只构造成对down/up并使用`isRepeat: false`。
- 2026-08-07：系统更新后再次恢复5.3；session catch-up、Git与OpenSpec确认当前未提交范围和`27/50 next 5.3`一致。actual Metal surface/SwiftUI/AppModel补丁已存在但尚未验证，先进行结构/API审计和fresh XROS direct build，再补应用层回归。
- 2026-08-07：fixed Vision Pro unsigned Debug `/tmp/LuneX-18-5_3-xros-direct.afR9u2`在XROS 26.4以Swift/Clang/Metal warnings-as-errors完整BUILD SUCCEEDED，未启动Simulator。首轮AppModel focused `/tmp/LuneX-18-5_3-appmodel-focused.7mnumU`中纯合同`21/21`通过，新跨层用例因错误硬编码latest-operation可能合并的中间presentation总数而超时；已改为等待最终restored scene，production无失败或修改。
- 2026-08-07：修正后的fresh focused `/tmp/LuneX-18-5_3-appmodel-focused-r2.MwWxeV`完整通过`22/22`；current focused send、surface replacement queued-drop、stale/hidden/inactive/unfocused local、visionOS versus tvOS controller lease/routing均成立，opt-in unset且无Simulator操作。
- 2026-08-07：扩大相关矩阵 `/tmp/LuneX-18-5_3-related.KAKJGt/Tests.xcresult`串行结构化通过`99/99 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`；覆盖vision window/input、tvOS remote/focus、controller、platform presentation及5个相关AppModel workflow。下一步production竞态审计与fresh normal suite。
- 2026-08-07：production审计发现actual window key/resign通知未同步first responder，及controller roster await完成后缺少focus/operation二次admission。已新增纯first-responder策略并在window/visibility/interaction变化接线，同时收紧controller write-back并扩展确定性测试。production已变化，既有focused/related/direct build降为中间证据，下一步从fresh目录重跑。
- 2026-08-07：修订后fresh focused `/tmp/LuneX-18-5_3-focused-r3.73l4R8/Focused.xcresult`串行结构化通过`23/23 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`；下一步fresh related矩阵。
- 2026-08-07：fresh related r2 `/tmp/LuneX-18-5_3-related-r2.gpV78p`为`100/99/0 skip/1 failed`；唯一tvOS roster序列失败揭示完成侧operation/exact-roster检查错误丢弃已成功送达的中间host state。已改为只在cancel/generation/release/focus失效时拒绝回写，保留visionOS focus-loss保护，下一步fresh focused+related重跑。
- 2026-08-07：routing修复定向 `/tmp/LuneX-18-5_3-routing-fix.w0dfTC/Routing.xcresult`结构化通过`2/2`；tvOS host-visible roster差异链与visionOS focus-loss迟到完成保护均成立。
- 2026-08-07：fresh related r3 `/tmp/LuneX-18-5_3-related-r3.OSGzhI/Related.xcresult`串行结构化通过`100/100 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`。5.3保持pre-mark，下一步最终production diff审计和fresh normal/build矩阵。
- 2026-08-07：最终production diff审计未发现阻止5.3的问题：first-responder通知接线、indirect-pointer-only过滤、direct/gaze/hand无synthetic路径、capture/send双重admission、host-visible controller roster串行语义、handler teardown及tvOS release guard均保持；5.4/5.5未提前宣称完成。
- 2026-08-07：fresh normal `/tmp/LuneX-18-5_3-normal.d3en1d/Normal.xcresult`结构化通过`1065 total / 1064 passed / 1 skipped / 0 failed / 0 expected failure`且build四类diagnostics为0；唯一skip精确为显式禁用的真实Keychain用例，两个opt-in均unset且未访问Keychain。下一步fresh fixed Vision Pro direct和五平台unsigned Debug。
- 2026-08-07：盘点上一轮五平台build命令时只读glob误指向证据根目录而非平台子目录，zsh在任何build前以no matches退出；改从`find`确认的精确日志路径读取，未操作Simulator或修改仓库。
- 2026-08-07：fresh fixed Vision Pro direct `/tmp/LuneX-18-5_3-visionos-direct.kJobJV/VisionOS.xcresult`在XROS 26.4 unsigned Debug成功，结构化四类diagnostics为0且有`1 AIR/1 metallib`；固定UUID只作destination，未启动Simulator。
- 2026-08-07：fresh五平台 `/tmp/LuneX-18-5_3-builds.BSj3P1`中macOS、fixed iPhone/iPad/Apple TV/Vision Pro unsigned Debug全部成功，结构化四类diagnostics为0，每项均有`1 AIR/1 metallib`。下一步权威文档同步与fresh repository pre-gate，5.3保持pre-mark。
- 2026-08-07：repository gate盘点的两个只读`rg --files`命令误包含不存在的`Scripts/`与`Documentation/`，确认真实路径为`Tools/`与`docs/`后停止使用错误路径；没有文件或设备副作用。
- 2026-08-07：首次OpenSpec/runtime/roadmap组合补丁因runtime contract的5.2结论锚点不精确被原子拒绝，确认无任何部分写入；改按文件与稳定章节标题拆分同步。
- 2026-08-07：权威同步后的只读`rg`验证因双引号模式含Markdown反引号而触发shell命令替换，zsh误尝试执行`27/50`；文件未变化，改用单引号稳定模式。
- 2026-08-07：已同步OpenSpec design/visionOS input spec、阶段18runtime contract、completion roadmap和三份planning，覆盖5.3实现、host-visible controller语义、fresh test/build证据及5.4/5.5/simulator/signed/physical/live证明边界。当前精确17文件pre-mark scope且`git diff --check`通过，下一步fresh repository pre-gate。
- 2026-08-07：首轮repository pre-gate `/tmp/LuneX-18-5_3-repository-pre.2TEasI`通过fixture、OpenSpec、三次稳定generator、精确17文件scope和membership后，在semantics段因`$0`多转义导致tvOS guard文本断言未命中；另预先修正会把`handler`误作`hand`的负向scan。不是源码/test/build失败，下一轮fresh完整重跑。
- 2026-08-07：第二轮repository pre-gate `/tmp/LuneX-18-5_3-repository-pre-r2.g1bb9N`仍在semantics段退出；诊断为两个精确Swift字符串中的`?`被`rg`按正则解释，fixed-string均正确命中。源码与前置门无失败，第三轮统一使用`rg -F`。
- 2026-08-07：fresh repository pre-gate `/tmp/LuneX-18-5_3-repository-pre-r3.K2qbMj`完整通过fixture self/tree、strict `9/9`、pre-mark `27/50 next 5.3`、三次稳定generator、精确17文件scope、current semantics与全部retained test/build/Metal及privacy/reference/dependency/opt-in/process/diff边界。5.3已勾选，预期`28/50 next 5.4`；下一步只读post-mark final-state。
- 2026-08-07：fresh只读post-mark final-state `/tmp/LuneX-18-5_3-final-state.bsTiTn`完整通过，确认OpenSpec `28/50 ready`、5.3 done、next 5.4与精确18文件scope；未重复test/build/generator、访问Keychain或操作Simulator lifecycle。下一步post-record和最终diff审计。
- 2026-08-07：首轮post-record `/tmp/LuneX-18-5_3-post-record.ApejcY`通过OpenSpec、精确18文件scope、稳定project hash与五份权威引用后，因包装器按首字母大写检查实际小写的五平台build证据目录而退出；不是实现、测试或构建失败。修正为`macos/iphone/ipad/tvos/visionos`并增加步骤标记后fresh重跑。
- 2026-08-07：第二轮post-record `/tmp/LuneX-18-5_3-post-record-r2.2d1Bht`通过OpenSpec与18文件scope，在authority步骤发现`findings.md`只记录pre-gate结论而缺精确路径；其余四份权威记录均已有pre-gate/final-state路径。补齐findings证据索引后fresh重跑，无行为验收或设备副作用。
- 2026-08-07：修正后的fresh post-record `/tmp/LuneX-18-5_3-post-record-r3.HJheG4`完整通过strict `9/9`、OpenSpec `28/50 next 5.4`、精确18文件scope、稳定project hash、五份authority、retained test/build/Metal、唯一Keychain skip、disabled opt-ins、no-process、dependency/reference和`git diff --check`边界。下一步最终diff审计。
- 2026-08-07：最终逐文件与静态审计 `/tmp/LuneX-18-5_3-final-audit.TNi2hb`完整通过public key/indirect-pointer事件源、first-responder/teardown、capture/send双重admission、host-visible controller routing、tvOS-only release guard、测试/membership、5.4/5.5 pending和全部仓库边界；未发现阻止5.3独立提交的问题。
- 2026-08-07：5.3已提交推送为`aaeb18d Implement visionOS native input adapters`；fetch确认`HEAD == origin/main == aaeb18da0e3b111828500a2b3457ee8c6e692e24`且工作树clean。进入5.4，OpenSpec为`28/50 ready`、next 5.4。
- 2026-08-07：5.4盘点确认1.4已有typed system interaction decision和测试，production缺口是actual reserved hardware key到current surface-owned state的接线。XROS public header确认Print Screen/volume HID usage；recenter/safety/gaze/hand无选定应用事件源，禁止新增synthetic/ARKit/direct spatial路径。一次只读检索误猜RuntimeDiagnostics在LuneXCore，真实路径为`Sources/LuneXDiagnostics/RuntimeDiagnostics.swift`，无副作用。
- 2026-08-07：首个5.4多文件组合补丁因AppModel多行锚点不精确被原子拒绝，确认无部分production写入；按文件与真实行号拆分后完成adapter/surface/RootView/AppModel typed local reservation接线及值/AppModel测试。当前`git diff --check`通过，下一步fresh focused编译行为验收。
- 2026-08-07：首轮focused包装器因命令数组用空格拼接导致root赋值失效，在`xcodebuild`前报只读`/xcodebuild.log`；无行为或设备副作用。修正后的fresh `/tmp/LuneX-18-5_4-focused-r2.oBJfvC/Focused.xcresult`结构化通过`24/24`、零skip/failure/expected failure，build succeeded且三类diagnostics为0。
- 2026-08-07：fresh fixed Vision Pro direct `/tmp/LuneX-18-5_4-visionos-direct.CsJwFj/VisionOS.xcresult`在XROS 26.4 unsigned Debug通过，结构化三类diagnostics为0且有`1 AIR/1 metallib`；固定UUID只作build destination，未操作Simulator lifecycle。
- 2026-08-07：fresh related `/tmp/LuneX-18-5_4-related.KdKMLz/Related.xcresult`结构化通过`101/101`、零skip/failure/expected failure且build三类diagnostics为0；共享tvOS/controller/platform/AppModel回归未受影响。
- 2026-08-07：fresh normal `/tmp/LuneX-18-5_4-normal.2eEluq/Normal.xcresult`结构化通过`1066/1065/1/0`、零expected failure且build三类diagnostics为0；唯一skip精确为显式真实Keychain opt-in用例，两个真实opt-in均unset。
- 2026-08-07：fresh五平台 `/tmp/LuneX-18-5_4-builds.pGfMJ3`已串行完成；首次结构化汇总因zsh只读特殊变量`status`在读取首份xcresult时退出，改用`build_status`后只重读已有结果。macOS、fixed iPhone/iPad/Apple TV/Vision Pro全部succeeded、三类diagnostics为0且各有`1 AIR/1 metallib`；未操作Simulator lifecycle。
- 2026-08-07：系统更新后继续5.4，planning catch-up、Git、环境与OpenSpec确认`HEAD == origin/main == aaeb18d`、精确13文件pre-mark scope、macOS 27.0/Xcode 26.4、`28/50 next 5.4`及两个真实opt-in unset，暂停期间无状态漂移。
- 2026-08-07：fresh repository pre-gate `/tmp/LuneX-18-5_4-repository-pre.sSXJDF`完整通过fixture self/tree、strict `9/9`、pre-mark `28/50 next 5.4`、三次稳定generator、精确13文件scope、current semantics、全部retained test/build/Metal、唯一Keychain skip及privacy/reference/dependency/opt-in/process/diff边界。5.4随后勾选为complete。
- 2026-08-07：勾选后的fresh只读final-state `/tmp/LuneX-18-5_4-final-state.GcQmvO`完整通过，确认OpenSpec `29/50 ready`、5.4 done、next 5.5、稳定project hash与精确14文件scope；未重复generator/test/build、访问Keychain或操作Simulator lifecycle。下一步post-record与最终diff审计。
- 2026-08-07：fresh post-record `/tmp/LuneX-18-5_4-post-record.7WByk7`完整通过五份authority双门索引、OpenSpec/current scope、实现测试语义、retained evidence、稳定project/reference/dependency、opt-in/process与diff边界。
- 2026-08-07：最终diff审计 `/tmp/LuneX-18-5_4-final-audit.CbmtKb`完整通过14文件4 production/2 test/8 authority分类、唯一5.4 checkbox替换、public key began/current surface/零remote event、teardown、indirect-pointer-only、tvOS不变、测试、5.5 pending及repository边界；无阻止独立提交的问题。
- 2026-08-07：最终记录门 `/tmp/LuneX-18-5_4-final-record.fPlISb`通过strict `9/9`、OpenSpec `29/50 next 5.5`、精确14文件分类、五份authority证据索引及全部稳定仓库边界；5.4进入精确stage、独立提交与推送。
- 2026-08-07：5.4已提交推送为`9e4744e Reserve visionOS system interactions locally`；fetch确认`HEAD == origin/main == 9e4744e1e55ed701ff11f8faf4d752b52f993e8c`且工作树clean，OpenSpec为`29/50 ready`、next 5.5。
- 2026-08-07：启动5.5盘点，确认1.4已有完整typed ordered release合同；production缺口是visionOS AppModel未实例化ownership/reconciliation、terminal只释放tvOS、失焦未等待FIFO input/controller后执行held release，actual surface也未在capture关闭时清active key/button与recognizer。下一步按现有合同最小接线并补跨层顺序/幂等测试。
- 2026-08-07：首个RootView capture参数补丁因tvOS/visionOS构造器相同锚点误命中tvOS分支；读回后在任何build/test前移除并精确加入visionOS分支，无设备或运行时副作用。
- 2026-08-07：terminal latch组合补丁因begin函数锚点顺序不符被原子拒绝且无部分写入；按真实位置加入后，provider/stop terminal release会锁住vision target直到新media runtime begin，late geometry不能重开capture。
- 2026-08-07：5.5 production共享分支warnings-as-errors编译 `/tmp/LuneX-18-5_5-compile.EkXXnC`通过，零warning/error/analyzer warning。fresh focused `/tmp/LuneX-18-5_5-focused.oVV88l`为`25 total / 23 passed / 0 skipped / 2 failed`，全部vision纯合同测试通过；两个失败仅为release次数各多1次。
- 2026-08-07：定位重复release来自vision ordered barrier之后又进入`MacSessionInputCoordinator.terminate`的默认release barrier。下一步为该协调器增加外部已释放的无屏障终止语义及直接测试，AppModel仅在平台有序释放已完成后使用；macOS默认合同保持不变。
- 2026-08-07：首轮修订focused `/tmp/LuneX-18-5_5-focused-r2.BuvIrO`在warnings-as-errors编译阶段因一个未消费的`Bool`返回值退出，测试未执行；已在仅触发平台release的presentation failure分支显式忽略返回值，将从fresh目录重跑。
- 2026-08-07：修正后的fresh focused `/tmp/LuneX-18-5_5-focused-r3.31aHqT/Focused.xcresult`结构化通过`41/41`、零skip/failure/expected failure，build四类diagnostics为0；两个原vision AppModel失败与新增Mac no-barrier termination均通过。下一步fresh related矩阵。
- 2026-08-07：fresh related `/tmp/LuneX-18-5_5-related.zRgqSq/Related.xcresult`结构化通过`188/188`且build四类diagnostics为0，完整AppModel、tvOS/visionOS input、Mac coordinator、controller和presentation相关回归均未受损。下一步fixed Vision Pro direct build。
- 2026-08-07：fresh fixed Vision Pro direct `/tmp/LuneX-18-5_5-visionos-direct.qUpUfu/VisionOS.xcresult`结构化通过，零warning/error/analyzer warning且有`1 AIR/1 metallib`；固定UUID仅作build destination，未操作Simulator lifecycle。下一步fresh normal。
- 2026-08-07：fresh normal `/tmp/LuneX-18-5_5-normal.5KOh5Z/Normal.xcresult`结构化通过`1068/1067/1/0`、零expected failure且build四类diagnostics为0；唯一skip精确为显式真实Keychain用例，两个真实opt-in均unset。下一步五平台unsigned Debug。
- 2026-08-07：fresh五平台 `/tmp/LuneX-18-5_5-builds.5FTkic`中macOS、fixed iPhone/iPad/Apple TV/Vision Pro unsigned Debug全部succeeded、四类diagnostics为0且各有`1 AIR/1 metallib`；未操作Simulator lifecycle。下一步权威同步、diff审计与repository pre-gate。
- 2026-08-07：首个5.5权威多文件组合补丁因OpenSpec design换行锚点不精确被原子拒绝，无部分写入；改为按文件和稳定标题拆分同步。
- 2026-08-07：已同步OpenSpec design/visionOS input spec、阶段18runtime contract、completion roadmap与三份planning，覆盖5.5实现、fresh test/build证据及明确proof boundary；5.5保持pre-mark `29/50 next 5.5`，下一步diff审计和repository pre-gate。
- 2026-08-07：macOS/Xcode更新后恢复5.5，goal仍active、HEAD仍为`9e4744e`、13文件scope无额外漂移，OpenSpec为`29/50 next 5.5`；未操作Simulator lifecycle或启用真实Keychain/live-host opt-in。
- 2026-08-07：暂停后production审计发现release合同构造fallback遗漏input FIFO/host release，且held release provider失败会被静默吞掉并允许后续capture恢复。已修订为fallback仍drain controller和keyboard/pointer后尝试一次release；release失败terminal-latch为`inputUnavailable`并拒绝late eligible geometry，新增`testVisionReleaseFailureLatchesCaptureWithoutSecondRelease`。旧focused/related/normal/build证据因production变更降为历史证据，下一步从fresh目录重跑受影响门。
- 2026-08-07：post-audit focused `/tmp/LuneX-18-5_5-audit-focused.7SdLvE/Focused.xcresult`结构化通过`42/42`且四类build diagnostics为0；新增release failure回归与既有vision/Mac release合同全部通过。
- 2026-08-07：post-audit related `/tmp/LuneX-18-5_5-audit-related.hmvlgf/Related.xcresult`结构化通过`189/189`且四类build diagnostics为0，完整AppModel及tvOS/visionOS/controller/presentation回归未受损。
- 2026-08-07：post-audit normal `/tmp/LuneX-18-5_5-audit-normal.4HpgIt/Normal.xcresult`通过`1069/1068/1/0`且四类build diagnostics为0；并行读取bundle时一次`xcresulttool database.sqlite3`临时文件冲突，串行复读现有bundle确认唯一skip为显式真实Keychain测试，未重跑测试，两个真实opt-in unset。
- 2026-08-07：post-audit五平台 `/tmp/LuneX-18-5_5-audit-builds.ccZsdc`中macOS、fixed iPhone/iPad/Apple TV/Vision Pro unsigned Debug全部succeeded、四类diagnostics为0且各有`1 AIR/1 metallib`；未查询或操作Simulator lifecycle。
- 2026-08-07：审计修订OpenSpec/docs首个组合脚本在JavaScript解析阶段被Markdown反引号截断，未调用任何补丁；改为逐文件行数组后成功同步release-failure fail-closed语义与新证据。5.5仍为pre-mark `29/50 next 5.5`，下一步repository pre-gate。
- 2026-08-07：首轮post-audit repository pre-gate `/tmp/LuneX-18-5_5-repository-pre.cRQudv`通过fixtures、strict/apply、三次稳定generator和13文件scope，在membership处因误把generator中`RootView.swift`真实1次清单出现断言为2而退出；project hash保持`e6a88cd00f4364b7e3a8011841abba9344a9ae3ac1c411e18d1ce426b9b739cb`，未重跑test/build或操作Simulator。修正计数后fresh完整重跑。
- 2026-08-07：第二轮repository pre-gate再次在membership处退出，根因为匹配路径外层双引号的shell quoting表达式错误；直接无引号fixed-string计数全部符合预期。诊断过程中一次JavaScript模板误解析shell参数展开而未启动命令。最终fresh `/tmp/LuneX-18-5_5-repository-pre-r3.GP0fhH`从头完整通过fixtures、strict `9/9`、pre-mark `29/50 next 5.5`、三次稳定generator、13文件scope、membership/语义、全部retained evidence、唯一Keychain skip和全部仓库边界。
- 2026-08-07：repository pre-gate通过后已仅勾选OpenSpec 5.5；5.6保持pending。下一步只读post-mark final-state，预期`30/50 next 5.6`，不重复test/build/generator或设备操作。
- 2026-08-07：fresh只读post-mark final-state `/tmp/LuneX-18-5_5-final-state.QP2qUU`完整通过，确认strict `9/9`、OpenSpec `30/50 ready`、5.5 done、next 5.6、精确14文件scope与唯一checkbox替换；未重复test/build/generator、访问Keychain或操作Simulator lifecycle。下一步post-record、最终diff审计和独立提交推送。
- 2026-08-07：fresh post-record `/tmp/LuneX-18-5_5-post-record.xbp4eR`通过OpenSpec `30/50 next 5.6`、精确14文件scope、五份authority、实现/测试语义、retained evidence及稳定仓库边界。最终审计 `/tmp/LuneX-18-5_5-final-audit.7fk9HU`通过4 production/2 test/8 authority分类、typed effect顺序、release-failure fail-closed、无第二barrier、surface capture撤销恢复与5.6 pending；无阻止独立提交的问题。
- 2026-08-07：最终记录门 `/tmp/LuneX-18-5_5-final-record.vfC7Fa`通过strict `9/9`、OpenSpec `30/50 next 5.6`、精确14文件分类、五份authority证据索引及全部稳定仓库边界；5.5进入精确stage、独立提交与推送。
- 2026-08-07：5.5已提交推送为`2ae0e19 Complete ordered visionOS input release`；fetch确认`HEAD == origin/main == 2ae0e19f3a278642af033b12b7e3e27fe0d80218`且工作树clean，OpenSpec为`30/50 ready`、next 5.6。
- 2026-08-07：启动5.6并重读全部OpenSpec contextFiles；确认本任务仅补5.1–5.5既有production行为的multiwindow/resize/focus/capability/reserved interaction/input mapping/held release/stale/replacement/teardown综合矩阵，不提前实现6.x媒体或7.x UI。下一步盘点现有测试覆盖与缺口。
- 2026-08-07：测试盘点确认AppModel既有长序列已覆盖replacement/stale/reserved/FIFO/controller/focus/release/termination，geometry既有用例已覆盖fit/fill/mapping/close；5.6新增用例将聚焦multiwindow identity filtering、连续resize同revision、capability admission与旧window/mapping在replacement/teardown后保持inert，不修改production。
- 2026-08-07：审计`VisionWindowInputOwnershipState`确认resize只改变snapshot revision/geometry，不改变generation-owned input identity，因此不会触发replacement release；5.6将以显式回归锁定resize期间capture持续且release计数不变，production无需修订。
- 2026-08-07：首轮5.6 focused `/tmp/LuneX-18-5_6-focused.AsL7EU`在测试执行前因新增合同断言的三个throwing generation调用未移出XCTest autoclosure而编译失败；0 tests，build除4个error外无warning/analyzer warning。已预构造generation，下一步fresh重跑，不复用失败xcresult。
- 2026-08-07：修正后的fresh 5.6 focused `/tmp/LuneX-18-5_6-focused-r2.Es1RDS/Focused.xcresult`结构化通过`3/3`、零skip/failure/expected failure，build四类diagnostics为0；新增resize/multiwindow/capability三条综合矩阵全部成立。下一步完整相关类回归。
- 2026-08-07：fresh 5.6 related `/tmp/LuneX-18-5_6-related.yIYDyZ/Related.xcresult`结构化通过`213/213`且build四类diagnostics为0；完整Vision合同、surface/presenter、AppModel、TVVision state、controller与Mac coordinator回归未受损。下一步normal。
- 2026-08-07：fresh 5.6 normal `/tmp/LuneX-18-5_6-normal.4E7C3M/Normal.xcresult`结构化通过`1072/1071/1/0`且build四类diagnostics为0；一次辅助jq因null name节点退出，类型过滤复读同一tests JSON确认唯一skip为显式真实Keychain用例，未重跑测试。下一步五平台unsigned Debug。
- 2026-08-07：fresh五平台 `/tmp/LuneX-18-5_6-builds.ijxOfl`中macOS、fixed iPhone/iPad/Apple TV/Vision Pro unsigned Debug全部succeeded、四类diagnostics为0且各有`1 AIR/1 metallib`；固定UUID仅作destination，未查询或操作Simulator lifecycle。
- 2026-08-07：已同步5.6 OpenSpec design/spec、阶段18runtime contract、completion roadmap和三份planning，记录三条连接矩阵、全部fresh证据及6.x/7.x/Simulator/signed/physical/live边界；OpenSpec保持pre-mark `30/50 next 5.6`。下一步repository pre-gate。
- 2026-08-07：首轮5.6 repository pre-gate `/tmp/LuneX-18-5_6-repository-pre.j564sL`已通过fixtures、strict/apply、三次稳定generator、精确10文件scope、membership与三条矩阵语义，随后因循环变量使用zsh特殊名`path`覆盖`PATH`而找不到`xcrun`；不是源码/test/build失败，project hash未变化且未操作Simulator。改用`result_path`后从fresh目录完整重跑。
- 2026-08-07：第二轮5.6 repository pre-gate `/tmp/LuneX-18-5_6-repository-pre-r2.SPvLNa`已进一步通过focused/related/normal结构化读回、唯一Keychain skip及五平台build/Metal证据，在authority检查因错误要求visionOS capability spec含字面任务号`5.6`退出；spec实际按场景语义写作。改为真实场景/关键行为断言后fresh完整重跑，不重跑test/build或操作Simulator。
- 2026-08-07：fresh 5.6 repository pre-gate `/tmp/LuneX-18-5_6-repository-pre-r3.FltJEs`完整通过fixture self/tree、strict `9/9`、pre-mark `30/50 next 5.6`、三次稳定generator、精确10文件scope、test membership/三条连接矩阵、retained focused/related/normal/五平台build与Metal、唯一Keychain skip及privacy/reference/dependency/opt-in/process/diff边界；随后仅勾选5.6。
- 2026-08-07：首个post-mark final-state `/tmp/LuneX-18-5_6-final-state.dfywG2`已确认strict `9/9`、OpenSpec `31/50 next 6.1`、精确11文件scope和唯一tasks文件变更，随后因辅助正则遗漏Markdown列表连字符退出；只读包装错误，无test/build/generator/Keychain/Simulator副作用。改用tasks diff精确两行后fresh重跑。
- 2026-08-07：修正后的fresh post-mark final-state `/tmp/LuneX-18-5_6-final-state-r2.ZtO9JF`只读完整通过strict `9/9`、OpenSpec `31/50 ready`、5.6 done、next 6.1、稳定project hash、精确11文件scope、唯一5.6 checkbox、retained evidence及proof/opt-in/process/diff边界；未重复test/build/generator、Keychain/live host或Simulator操作。
- 2026-08-07：首轮post-record `/tmp/LuneX-18-5_6-post-record.BFxsJz`已通过OpenSpec `31/50 next 6.1`、11文件3 test/8 authority分类及五份authority双门索引，随后因使用不存在的design摘要句退出；真实design写作three connected regression matrices。改用实际语义后fresh重跑，无test/build/Simulator副作用。
- 2026-08-07：修正后的fresh post-record `/tmp/LuneX-18-5_6-post-record-r2.omtl07`完整通过OpenSpec `31/50 next 6.1`、精确11文件3 test/8 authority、五份双门索引、OpenSpec/test语义、retained evidence、proof tier、稳定project、opt-in/process/diff边界。
- 2026-08-07：最终diff审计 `/tmp/LuneX-18-5_6-final-audit.cNq2is`完整通过三条矩阵的resize/replacement/terminal、multiwindow/revision/stale/invalidate、capability/reserved/mapping/ordered idempotent release语义，并确认无弱化测试、敏感网络字面量、production/reference/dependency漂移或第二checkbox；无阻止5.6独立提交的问题。
- 2026-08-07：最终记录门 `/tmp/LuneX-18-5_6-final-record.qI7nfQ`通过strict `9/9`、OpenSpec `31/50 next 6.1`、精确11文件3 test/8 authority分类、五份authority四门索引、稳定project、全部retained evidence及privacy/proof/opt-in/process/diff边界；5.6进入精确stage、独立提交与推送。
- 2026-08-07：5.6已提交推送为`6c8d629 Complete visionOS input regression matrix`；push/fetch确认`HEAD == origin/main == 6c8d629c894258597109eb4518a6e3413b9db9f8`且工作树clean，OpenSpec为`31/50 ready`、next 6.1。
- 2026-08-07：启动6.1并重新读取全部OpenSpec contextFiles。盘点确认typed windowed/unavailable值合同已存在于1.4，但只被私有vision input snapshot临时使用；shared coordinator snapshot与AppModel未报告actual current-generation windowed mode。下一步将从actual attached scene派生并投影该状态，补replacement/stale/closed/stop和tvOS隔离测试，不创建immersive runtime或提前实现6.2–7.x。
- 2026-08-07：首个6.1 production/test组合补丁因`AppModelWorkflowTests`长函数名真实换行与锚点不一致被`apply_patch`原子拒绝，确认无部分测试或production写入；改为按文件和稳定标题拆分应用。
- 2026-08-07：恢复后先把coordinator测试的async调用移出XCTest autoclosure，再运行fresh focused `/tmp/LuneX-18-6_1-focused.XQEqfy/Focused.xcresult`；结构化通过`4/4`、零skip/failure/expected failure，build四类diagnostics为0。两个真实opt-in保持unset，未访问Keychain、live host或操作Simulator lifecycle。下一步完整相关类矩阵。
- 2026-08-07：fresh related `/tmp/LuneX-18-6_1-related.dmWvOh/Related.xcresult`结构化通过`251/251`、零skip/failure/expected failure，build四类diagnostics为0；完整AppModel、platform coordinator/state、session media environment、vision input与Metal presenter回归未受损。下一步fresh normal。
- 2026-08-07：fresh normal `/tmp/LuneX-18-6_1-normal.pJMQ2K/Normal.xcresult`结构化通过`1074/1073/1/0`、零expected failure且build四类diagnostics为0；唯一skip精确为显式真实Keychain用例，两个真实opt-in均unset。下一步五平台unsigned Debug。
- 2026-08-07：fresh五平台 `/tmp/LuneX-18-6_1-builds.APF2yT`中macOS、fixed iPhone/iPad/Apple TV/Vision Pro unsigned Debug全部succeeded、四类diagnostics为0且各有`1 AIR/1 metallib`；固定UUID仅作destination，未查询或操作Simulator lifecycle。
- 2026-08-07：production审计确认windowed state通过helper随非scene组件的coordinator semantic revision重标，但原新增测试未锁定该未来6.2-6.4关键边界；已扩展coordinator回归并让vision fixture使用合法keyboard/pointer capabilities，production不变。
- 2026-08-07：审计后fresh focused `/tmp/LuneX-18-6_1-audit-focused.u9HXzp/Focused.xcresult`结构化通过`1/1`；related `/tmp/LuneX-18-6_1-audit-related.3Whib6/Related.xcresult`通过`251/251`；normal `/tmp/LuneX-18-6_1-audit-normal.VXSI3H/Normal.xcresult`通过`1074/1073/1/0`且唯一skip为显式真实Keychain用例。三份build四类diagnostics均为0，两个真实opt-in仍unset。
- 2026-08-07：已同步OpenSpec design/visionOS media spec、阶段18runtime contract、completion roadmap与三份planning，覆盖actual attached scene、完整typed unavailable、跨组件revision、replacement/terminal、fresh证据与proof boundary；6.1保持pre-mark `31/50 next 6.1`。下一步repository pre-gate。
- 2026-08-07：首轮6.1 repository pre-gate `/tmp/LuneX-18-6_1-repository-pre.a54Ef7`通过fixture/OpenSpec/generator/scope/membership/语义/test/build后，边界检查因误要求权威文本使用小写`do not prove`与大写`Tasks`前缀而退出；无production/test/build/Keychain/Simulator副作用。按实际`SHALL NOT prove`与`6.2-8.x`修正后fresh重跑。
- 2026-08-07：fresh repository pre-gate `/tmp/LuneX-18-6_1-repository-pre-r2.nZ4iKX`完整通过fixture self/tree、strict `9/9`、pre-mark `31/50 next 6.1`、三次稳定generator、精确11文件scope、membership、windowed/current ownership/revision/replacement/terminal/tvOS nil语义、retained focused/related/normal/五平台Metal证据、唯一Keychain skip及全部仓库边界；随后仅勾选6.1。
- 2026-08-07：只读post-mark final-state `/tmp/LuneX-18-6_1-final-state.D3kVOH`确认strict `9/9`、OpenSpec `32/50 ready`、6.1 done、next 6.2、精确12文件scope及唯一checkbox替换；未重复test/build/generator、Keychain/live host或Simulator操作。下一步post-record、最终diff审计与独立提交推送。
- 2026-08-07：首个6.1 post-record命令因Markdown反引号截断JavaScript模板，在shell启动前报`SyntaxError: Unexpected number`；无文件、测试、build、Git或设备副作用。移除该字面依赖后fresh `/tmp/LuneX-18-6_1-post-record-r2.aMya2c`完整通过strict `9/9`、`32/50 next 6.2`、精确12文件`2 production / 2 test / 8 authority`分类、authority证据索引、retained evidence及稳定仓库边界。
- 2026-08-07：首个6.1 final audit命令又因stage行的Markdown反引号截断JavaScript模板，在shell启动前报`SyntaxError: Unexpected identifier 'in_progress'`，无副作用；改为字段组合检查后fresh `/tmp/LuneX-18-6_1-final-audit-r2.nVb6kC`完整通过12文件2/2/8分类、production/test/authority语义、无弱化/6.2提前实现/第二checkbox/敏感字面量及稳定reference/dependency/project边界。无阻止6.1独立提交的问题。
- 2026-08-07：最终记录门 `/tmp/LuneX-18-6_1-final-record.cA8Upm`通过strict `9/9`、OpenSpec `32/50 next 6.2`、精确12文件分类、五份authority四门索引、retained test/build、稳定project及privacy/proof/opt-in/process/diff边界；6.1进入精确stage、独立提交与推送。
- 2026-08-07：6.1已提交推送为`8ba0e33 Report current visionOS windowed presentation`；push/fetch确认`HEAD == origin/main == 8ba0e336db4f11d3355c772e036b692d9be3f10d`且工作树clean，OpenSpec为`32/50 ready`、next 6.2。
- 2026-08-07：启动6.2并盘点task 4.1既有生产链；确认RootView visionOS实际surface、共享`TVVisionMetalPresentationOwner`、platform-admitted presenter和SessionMediaEnvironment single decoded-frame subscription已经接线，现有执行级frame测试helper仅固定tvOS ownership。下一步先补visionOS专属windowed/frame/revision/replacement/clear-resume/stale连接矩阵，不提前实现6.3–7.x。
- 2026-08-07：首轮6.2 focused `/tmp/LuneX-18-6_2-focused.Q4t2CR`短yield后仍在运行，过早读未封口xcresult出现`root ID is missing`；未启动第二个LuneX测试，等待原PID 465完成后读回`1/0/0/1`且build diagnostics全零。失败为replacement frame 44未在第一笔draw取代43。
- 2026-08-07：focused r2 `/tmp/LuneX-18-6_2-focused-r2.bZ5mco`用显式guard/snapshot定位到coordinator与owner均已接受frame 44/current surface/eligible scene，失败只在presenter draw；根因为replacement activation留下强制clear fence，测试漏掉先清旧drawable的draw。加入显式clear顺序后r3 `/tmp/LuneX-18-6_2-focused-r3.WZuCgw`通过`1/1`且四类build diagnostics为0，production无需修订。
- 2026-08-07：新增visionOS SessionMediaEnvironment single frame subscription replacement用例后，fresh focused `/tmp/LuneX-18-6_2-focused-r4.5amuAx`结构化通过`2/2`、零skip/failure/expected failure且build四类diagnostics为0；两条连接矩阵共同覆盖source/environment/coordinator/owner/presenter、windowed revision、surface/ownership replacement、clear/resume和stale rejection。下一步related矩阵。
- 2026-08-07：恢复后的异步审计发现subscription handler每笔delivery各建一个unstructured `Task`，可能重排decoder/frame/clear且无界增长；已改为ownership-scoped可取消FIFO pump。首版`.unbounded`实现经资源审计改成64笔pending上限，overflow由同一consumer触发matching current typed video failure，replacement/stop同时取消pump与subscription。
- 2026-08-07：首轮新pump focused `/tmp/LuneX-18-6_2-audit-focused.NMa6W9`通过`3/3`；有界版 `/tmp/LuneX-18-6_2-audit-focused-r2.1D3aNi`也通过`3/3`。新增environment overflow用例的首个4-test组合在异步等待中被定向中止；isolated pump通过，isolated environment r2用2秒门定位为测试错误等待decoder-start产生video effect。修正为先送frame 0后isolated r3通过；这些中止/失败bundle不作为最终证据。
- 2026-08-07：fresh最终focused `/tmp/LuneX-18-6_2-audit-focused-r4.vj6AKw/Focused.xcresult`结构化通过`4/4`，related `/tmp/LuneX-18-6_2-audit-related.xqXKjd/Related.xcresult`通过`255/255`；两者零skip/failure/expected failure且build四类diagnostics为0。
- 2026-08-07：fresh normal `/tmp/LuneX-18-6_2-audit-normal.rwmq84/Normal.xcresult`结构化通过`1078/1077/1/0`且build四类diagnostics为0；并行读取同一bundle一次触发临时`database.sqlite3`冲突，串行复读确认唯一skip为显式真实Keychain测试，未重跑测试，两个真实opt-in unset。
- 2026-08-07：fresh五平台 `/tmp/LuneX-18-6_2-audit-builds.jvlO3v`中macOS、fixed iPhone/iPad/Apple TV/Vision Pro unsigned Debug全部succeeded、四类diagnostics为0且各有`1 CompileMetalFile/1 MetalLink`；固定UUID只作destination，未查询或操作Simulator lifecycle。下一步权威同步与repository pre-gate，6.2保持pre-mark。
- 2026-08-07：macOS更新后恢复阶段18；session catchup、长期goal、Git、OpenSpec和toolchain复核完成。当前仍为`main`精确10文件dirty、`32/50 ready`且next 6.2，`git diff --check`通过，`LUNEX_RUN_KEYCHAIN_TEST`与`LUNEX_RUN_LIVE_HOST_TEST`均unset；环境为macOS 27.0、Xcode 26.4、Swift 6.3。继续执行6.2源码终审与repository pre-gate，不查询或操作Simulator lifecycle。
- 2026-08-07：6.2最终源码审计通过：真实queue与单槽signal的顺序排除lost wakeup；cancel清pending并结束consumer；overflow只排入一次terminal work；matching pump UUID隔离replacement；replacement/failure/stop/teardown均取消pump/subscription。同步subscribe replay因environment actor在安装提交前无suspension point而不能提前执行；没有unbounded queue、第二decoder/frame source/presenter/media owner或需追加production修复的问题。
- 2026-08-07：首个恢复后repository命令因外层JavaScript误解析shell环境变量展开式，在进入shell前报`SyntaxError: Unexpected token '}'`，无任何副作用。改用`printenv`后fresh `/tmp/LuneX-18-6_2-repository-pre.NSD4Ky`通过fixture/OpenSpec/scope/三次generator/membership，但包装器只计4个active-state pump cancel、漏计teardown局部变量cancel而错误退出；修正断言后从fresh目录完整重跑，不重复test/build或操作Simulator。
- 2026-08-07：fresh repository pre-gate `/tmp/LuneX-18-6_2-repository-pre-r2.qw8ka9`完整通过fixture self/tree、strict `9/9`、pre-mark `32/50 next 6.2`、三次稳定generator、精确10文件scope、membership、pump/clear-fence语义、retained focused `4/4`、related `255/255`、normal `1078/1077/1/0`、五平台Metal build及privacy/reference/dependency/opt-in/process/diff边界；现在只勾选6.2。
- 2026-08-07：首个五文件post-mark authority记录补丁因roadmap现有句与预期锚点不完全一致而被原子拒绝，无部分写入；按真实锚点拆分。只读final-state `/tmp/LuneX-18-6_2-final-state.Dx3op0`通过strict `9/9`、OpenSpec `33/50 ready`且next 6.3、精确11文件scope、tasks唯一6.2 checkbox替换、稳定project hash、retained test/build及source/docs/opt-in/process/proof边界；未重复test/build/generator或Simulator操作。
- 2026-08-07：post-record `/tmp/LuneX-18-6_2-post-record.cDfHFy`通过`33/50 next 6.3`、11文件`1 production / 2 test / 8 authority`分类、五份authority pre/final索引、稳定project/retained evidence和仓库边界；final diff audit `/tmp/LuneX-18-6_2-final-audit.k3rz0Z`通过FIFO/current-ID、cancel/overflow、四条focused无skip/弱化、唯一checkbox、proof/privacy/reference/dependency/opt-in边界。下一步final-record后提交推送。
- 2026-08-07：final-record `/tmp/LuneX-18-6_2-final-record.Q9ZZvx`通过strict `9/9`、`33/50 next 6.3`、11文件`1/2/8`分类、五份authority四门索引、稳定project/全部retained evidence及implementation/task/proof/privacy/opt-in/process/dependency/diff边界；6.2进入精确stage、提交与推送。
- 2026-08-07：6.2提交推送为`fb9449d Order visionOS window frame delivery`；push/fetch确认`HEAD == origin/main == fb9449d0af781d96d9565e76646ab8e63049e807`且工作树clean，OpenSpec为`33/50 ready`、next 6.3。
- 2026-08-07：启动6.3并完成首轮SDK/架构盘点。visionOS 26.4 public layer dynamic-range/content-headroom属性可编译，但`UIScreen`/scene screen unavailable，不能从layer intent推断current output headroom；下一步复用4.2/4.3 shared resolver/transaction/coordinator链，缺finite current source时保持typed SDR fallback，不提前实现6.4-6.5。
- 2026-08-07：系统更新后继续6.3；session catchup、长期goal、OpenSpec和工作树恢复完成。当前`HEAD == origin/main == fb9449d`、OpenSpec `33/50 next 6.3`、`git diff --check`通过；环境实测为macOS 27.0 build `26A5388g`、Xcode/XROS SDK 26.4、Swift 6.3，两个真实opt-in均unset。下一步补测试并fresh编译，不查询或操作Simulator lifecycle。
- 2026-08-07：首个新增6.3 focused `/tmp/LuneX-18-6_3-focused.sDtycY`在0 tests阶段因两处测试把`await`放入XCTest同步autoclosure而编译失败；production未报错。已改为断言前取异步outcome，下一轮fresh执行。
- 2026-08-07：fresh focused `/tmp/LuneX-18-6_3-focused-r2.nLEOjb/Focused.xcresult`结构化通过`31/31`、零skip/failure/expected failure，build succeeded且warning/error/analyzer warning全零。下一步XROS public API正负probe和fixed Vision Pro unsigned Debug。
- 2026-08-07：XROS public API probe `/tmp/LuneX-18-6_3-xros-probe.KqmYxE`正向7组layer/color符号零诊断、负向精确确认`UIScreen`与`UIWindowScene.screen` unavailable；fixed Vision Pro `/tmp/LuneX-18-6_3-visionos-direct.1gbruA/VisionOS.xcresult`为succeeded/四类diagnostics零/`1 AIR + 1 metallib`。未操作Simulator lifecycle；下一步related。
- 2026-08-07：fresh related `/tmp/LuneX-18-6_3-related.sM3JhP/Related.xcresult`结构化通过`258/258`、0 skip/failure/expected failure且build四类diagnostics为0；下一步normal完整suite，真实opt-in继续unset。
- 2026-08-07：fresh normal `/tmp/LuneX-18-6_3-normal.culXSh/Normal.xcresult`结构化通过`1082/1081/1/0`，唯一skip精确为显式真实Keychain测试，build四类diagnostics为0；下一步五平台unsigned Debug。
- 2026-08-07：fresh五平台 `/tmp/LuneX-18-6_3-builds.O6tTU8`中macOS、fixed iPhone/iPad/Apple TV/Vision Pro unsigned Debug全部succeeded、四类diagnostics为0且各有`1 AIR/1 metallib`；固定UUID只作destination，未查询或操作Simulator lifecycle。
- 2026-08-07：同步OpenSpec design/spec、阶段18runtime contract、roadmap与三份planning，记录6.3 layer-only observer、typed fallback、fresh evidence和6.4/6.5/7.x/physical/live边界；OpenSpec保持pre-mark `33/50 next 6.3`。下一步repository pre-gate。
- 2026-08-07：fresh repository pre-gate `/tmp/LuneX-18-6_3-repository-pre.ioYbts`完整通过fixtures、strict `9/9`、pre-mark `33/50 next 6.3`、精确12文件scope、三次稳定generator、membership/语义、全部retained evidence、唯一Keychain skip和privacy/reference/dependency/opt-in/process/diff/proof边界；现只勾选6.3。
- 2026-08-07：只读post-mark final-state `/tmp/LuneX-18-6_3-final-state.dySg9y`通过strict `9/9`、OpenSpec `34/50 ready`且next 6.4、精确13文件scope、唯一6.3 checkbox、稳定project及仓库边界；未重复test/build/generator/Keychain/live-host/Simulator。下一步最终diff审计后提交推送。
- 2026-08-07：final diff audit `/tmp/LuneX-18-6_3-final-audit.c5MAQz`通过最终13文件`3/2/8`分类、layer-only/native-fallback/replacement/invalidation语义、四条focused无弱化、唯一checkbox及全部仓库边界；下一步final-record后提交推送。
- 2026-08-07：final-record `/tmp/LuneX-18-6_3-final-record.7lzi44`通过strict `9/9`、`34/50 next 6.4`、13文件`3/2/8`分类、五份authority索引、稳定project/retained evidence及全部实现/任务/仓库边界；6.3进入提交推送。
- 2026-08-07：系统更新后恢复阶段18；session catchup、长期goal、Git、OpenSpec和全部change contextFiles已重新核对。当前`HEAD == origin/main == 2cb4f95fe855fa6d73bd928f185cfd9253666d21`、工作树clean、OpenSpec `34/50 ready`且next 6.4；真实Keychain/live-host opt-in保持unset，未查询或操作Simulator lifecycle。
- 2026-08-07：启动6.4只读盘点。范围限定为在单一canonical audio graph/notification源上泛化current tvOS/visionOS ownership，接入visionOS公开intended spatial experience、实际route capability、interruption/media reset recovery、graph replacement与current-generation state；6.5组合协调、6.6综合回归、7.x UI和physical/live证明继续pending。
- 2026-08-07：首轮6.4 focused `/tmp/LuneX-18-6_4-focused.Yh6dWV/Focused.xcresult`在0 tests阶段因新增optional断言中的`.none`被Swift解释为`Optional.none`而构建失败；production无编译诊断。改为显式`SpatialAudioPlatformStrategy.none`后fresh重跑，不操作Simulator或启用真实opt-in。
- 2026-08-07：fresh 6.4 focused `/tmp/LuneX-18-6_4-focused-r2.BZF9w4/Focused.xcresult`结构化通过`5/5`、零skip/failure/expected failure且build warning/error/analyzer warning全零；visionOS intended experience、route counts、interruption/loss/reset、graph与presentation replacement、stale和stop路径及tvOS回归成立。下一步源码审计与related矩阵。
- 2026-08-07：fresh related `/tmp/LuneX-18-6_4-related.YQ4rA2/Related.xcresult`结构化通过`182/182`、零skip/failure/expected failure且build三类diagnostics为0；完整audio/presentation/environment相关矩阵无回归。
- 2026-08-07：XROS public API probe `/tmp/LuneX-18-6_4-xros-probe.2UK3No`正向intended fixed/head-tracked/bypassed零诊断，负向精确确认listener head-tracking property在visionOS unavailable；fixed Vision Pro `/tmp/LuneX-18-6_4-visionos-direct.6wtjPE/VisionOS.xcresult` unsigned Debug通过、diagnostics全零且有`1 AIR/1 metallib`。没有运行应用或操作Simulator lifecycle。
- 2026-08-07：fresh normal `/tmp/LuneX-18-6_4-normal.9YKcpI/Normal.xcresult`结构化通过`1084/1083/1/0`，唯一skip精确为显式真实Keychain测试；文件fallback用例通过，两个真实opt-in均unset。
- 2026-08-07：fresh五平台 `/tmp/LuneX-18-6_4-builds.Vi0CJb`中macOS、fixed iPhone/iPad/Apple TV/Vision Pro unsigned Debug全部succeeded、warning/error/analyzer warning全零且各有`1 AIR/1 metallib`；固定UUID只作destination，未运行app或操作Simulator lifecycle。
- 2026-08-07：开始同步OpenSpec design/spec、阶段18runtime contract、roadmap与三份planning；6.4保持pre-mark `34/50 next 6.4`，6.5组合协调、6.6综合回归、7.2 UI及signed/physical/live证明继续pending。
- 2026-08-07：6.4 repository pre-gate前三轮分别因包装器误断言源码一致性表达式、xcresult skip字段名和自匹配进程正则退出；每轮保留的前置结果均通过，无production/test/build/Keychain/Simulator副作用。已逐项修正并从fresh目录重跑。
- 2026-08-07：fresh `/tmp/LuneX-18-6_4-repository-pre-r4.8oI8VY`完整通过fixture self/tree、strict `9/9`、pre-mark `34/50 next 6.4`、三次稳定generator、精确11文件scope、membership/实现语义、retained `5/182/1084`、API probe、direct Vision Pro/五平台Metal build及全部仓库边界；现只勾选6.4。
- 2026-08-07：只读post-mark final-state `/tmp/LuneX-18-6_4-final-state.1Gh0gg`通过strict `9/9`、OpenSpec `35/50 ready`且next 6.5、精确12文件scope、唯一6.4 checkbox、稳定project及仓库边界；未重复test/build/generator/Keychain/live-host/Simulator。下一步post-record、final audit和独立提交推送。
- 2026-08-07：post-record前三轮分别因跨行6.5/8.7短语和`pipefail`下`git diff | rg -q` SIGPIPE包装假设退出，均为只读且无test/build/Keychain/Simulator副作用；corrected `/tmp/LuneX-18-6_4-post-record-r4.onEV9k`通过`35/50 next 6.5`、12文件`2/2/8`分类、五份authority双门索引及仓库边界。
- 2026-08-07：final diff audit `/tmp/LuneX-18-6_4-final-audit.ZathRe`通过fixed-platform publisher、策略/route/current ownership/recovery/replacement/terminal语义、两条测试无弱化、唯一6.4 checkbox及全部边界；下一步final-record后提交推送。
- 2026-08-07：final-record `/tmp/LuneX-18-6_4-final-record.0FZsJc`通过strict `9/9`、`35/50 next 6.5`、12文件`2/2/8`分类、五份authority完整门索引、稳定project/retained evidence及全部实现/任务/仓库边界；6.4进入提交推送。
- 2026-08-07：6.4提交推送为`7cea28d Connect visionOS audio route runtime`；push/fetch确认`HEAD == origin/main == 7cea28d6dce479f881e32bb27bc65d5ab8e5b045`且工作树clean，OpenSpec为`35/50 ready`、next 6.5。
- 2026-08-07：启动6.5，范围限定为用现有单一presentation coordinator组合visionOS scene/video/HDR/audio/input/diagnostics及failure/reconnect/remote termination/stop；6.6综合回归、7.2 UI及physical/live证明继续pending，真实opt-in保持unset且不操作Simulator lifecycle。
- 2026-08-07：系统更新后恢复6.5，重新核对active goal、全部OpenSpec context、Git与planning；完成RootView visionOS layer HDR事件到通用AppModel入口接线，并让测试状态重建保留visionOS typed HDR resolution。首轮fresh smoke `/tmp/LuneX-18-6_5-smoke.AHz6bu/Smoke.xcresult`中production以warnings-as-errors编译，3项中2项通过，唯一失败是既有window测试仍按旧两动作geometry序列索引replacement；已改为完整`activate -> scene -> input`顺序与ownership断言，下一步fresh重跑。
- 2026-08-07：修正后smoke `/tmp/LuneX-18-6_5-smoke-r2.sgFzVq/Smoke.xcresult`通过`3/3`；新增current/reconnect/remote、local stop和display failure三项组合用例后，fresh focused `/tmp/LuneX-18-6_5-focused.4NFpPx/Focused.xcresult`结构化通过`6/6 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`。下一步fresh related矩阵、normal、fixed Vision Pro和五平台unsigned Debug。
- 2026-08-07：系统更新后串行读取既有related `/tmp/LuneX-18-6_5-related.ftZGW6/Related.xcresult`，结构化确认`323/323 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`；没有重跑矩阵。Git仍为预期6文件diff，`HEAD == origin/main == 7cea28d`，OpenSpec保持`35/50 ready`且next 6.5。下一步逐函数diff审计后运行fresh normal和五平台build。
- 2026-08-07：逐函数并发审计发现同surface resize可使已排队display task因旧admission被正确拒绝，但current display source不会自动对新geometry重排。已在geometry schedule后仅对同platform/current source调用同一serialized display application，并新增阻塞activation的visionOS race回归；新surface仍先清source。production已变化，因此既有`6/323`证据降为中间证据，下一步fresh focused/related。
- 2026-08-07：修订后fresh focused `/tmp/LuneX-18-6_5-focused-r3.6pazwk/Focused.xcresult`结构化通过`7/7 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`；新增race最终只提交latest geometry/input和current display。下一步fresh 10类related矩阵。
- 2026-08-07：修订后fresh related `/tmp/LuneX-18-6_5-related-r2.lmoqpY/Related.xcresult`结构化通过`324/324 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`；逐函数并发/terminal审计无其他问题。下一步显式关闭两个真实opt-in运行fresh normal。
- 2026-08-07：fresh normal `/tmp/LuneX-18-6_5-normal.CV3Nzw/Normal.xcresult`结构化通过`1088 total / 1087 passed / 1 skipped / 0 failed / 0 expected failure`，build结构化diagnostics全零；唯一skip精确为显式真实Keychain round-trip，文件fallback继续使用，两个真实opt-in均unset。下一步fixed Vision Pro和五平台unsigned Debug。
- 2026-08-07：fixed Vision Pro direct `/tmp/LuneX-18-6_5-visionos-direct.vMBJUC/VisionOS.xcresult` unsigned Debug成功、结构化diagnostics全零且有`1 AIR/1 metallib`；fresh五平台 `/tmp/LuneX-18-6_5-builds.1uxfoD`中macOS、fixed iPhone/iPad/Apple TV/Vision Pro也全部`succeeded/0/0/0`、各有`1 AIR/1 metallib`且Metal含`-Werror`。固定UUID仅作destination，未操作Simulator lifecycle。下一步authority同步与repository pre-gate。
- 2026-08-07：首个四文件authority补丁因误假设design的4.5段与proof-tier标题相邻而被`apply_patch`原子拒绝，无部分写入；改用稳定章节标题后成功同步OpenSpec design/visionOS media spec、阶段18runtime contract和completion roadmap。6.5仍保持pre-mark `35/50 next 6.5`，下一步repository pre-gate。
- 2026-08-07：fresh repository pre-gate `/tmp/LuneX-18-6_5-repository-pre.QOi58Z`一次完整通过fixture self/tree、strict `9/9`、pre-mark `35/50 next 6.5`、三次稳定generator、精确10文件scope、membership/实现语义、retained `7/324/1088`、direct/five-platform Metal、唯一Keychain skip及privacy/reference/dependency/opt-in/process/diff/proof边界；随后仅勾选6.5。下一步只读post-mark final-state。
- 2026-08-07：只读post-mark final-state `/tmp/LuneX-18-6_5-final-state.UppBOq`完整通过strict `9/9`、OpenSpec `36/50 ready`、6.5 done、next 6.6、精确11文件scope、唯一6.5 checkbox、稳定project/retained evidence和全部仓库边界；未重复test/build/generator、Keychain、live host或Simulator操作。下一步final diff audit与final-record。
- 2026-08-07：final diff audit `/tmp/LuneX-18-6_5-final-audit.B4HJVK`通过最终11文件`2 production / 1 test / 8 authority`分类、RootView/AppModel current-platform/display replay/terminal语义、四条连接测试无弱化、唯一6.5 checkbox及全部仓库边界；下一步final-record后独立提交推送。
- 2026-08-07：final-record `/tmp/LuneX-18-6_5-final-record.7HghDO`通过strict `9/9`、`36/50 next 6.6`、最终11文件`2/1/8`分类、五份authority完整门索引、稳定project/retained evidence及全部实现/任务/仓库边界；6.5进入精确stage、独立提交与推送。
- 2026-08-07：系统更新结束后恢复阶段18。session catchup、active goal、Git、OpenSpec与工具链核对完成：6.5已以`33cc6fd Coordinate visionOS presentation runtime`提交推送，`HEAD == origin/main`且工作树clean；OpenSpec为`36/50 ready`、next 6.6；macOS 27.0/Xcode 26.4/Swift 6.3，两个真实opt-in均unset。
- 2026-08-07：启动6.6，范围限定为windowed/immersive-unavailable、frame/render、HDR fallback、spatial route/recovery、AppModel、replacement、resource release与teardown综合回归。环境已有非本轮创建的iOS Simulator会话，本任务不查询或改变它，8.5/8.6前不执行Simulator inventory/lifecycle操作。
- 2026-08-07：完成6.6覆盖与源码资源审计。独立能力测试齐全，但缺visionOS对称全链路coordinator序列和subscription replacement到五资源释放的连接门；production ownership/cancel/teardown路径未发现缺陷。已做test-only增量，下一步运行fresh focused编译与三条目标测试。
- 2026-08-08：首轮focused `/tmp/LuneX-18-6_6-focused.6ahsDg/Focused.xcresult`为2 passed/1 failed；AppModel和五资源释放通过，coordinator仅因测试期望`.none`被推断为`Optional.none`失败。已改为`SpatialAudioPlatformStrategy.none`，下一步只重跑该失败用例。
- 2026-08-08：修正后coordinator单项通过，fresh最终focused `/tmp/LuneX-18-6_6-focused-final.0pDNP0/Focused.xcresult`结构化为`3/3 passed / 0 skipped / 0 failed / 0 expected failure`，build `succeeded`且warning/error/analyzer warning全零。下一步完整related矩阵。
- 2026-08-08：系统更新后再次恢复并完成session catchup、active goal、Git、OpenSpec和Xcode对账；`HEAD == origin/main == 33cc6fd`、精确6文件dirty、`git diff --check`通过、OpenSpec仍为pre-mark `36/50 next 6.6`，未操作Simulator或真实Keychain/live host。
- 2026-08-08：用当前Xcode 26.4重新结构化读取保留的related `/tmp/LuneX-18-6_6-related.PwaltL/Related.xcresult`，10个相关测试类合计`325/325 passed / 0 skipped / 0 failed / 0 expected failure`，build `succeeded / 0 warning / 0 error / 0 analyzer warning`。下一步fresh normal suite。
- 2026-08-08：fresh normal `/tmp/LuneX-18-6_6-normal.dnnNlV/Normal.xcresult`结构化通过`1089 total / 1088 passed / 1 skipped / 0 failed / 0 expected failure`，唯一skip精确为真实Keychain opt-in；build四类diagnostics全零，两个真实opt-in仍unset。下一步fixed Vision Pro direct及五平台unsigned Debug。
- 2026-08-08：fixed Vision Pro direct `/tmp/LuneX-18-6_6-visionos-direct.8Muuwq/VisionOS.xcresult`成功；fresh五平台 `/tmp/LuneX-18-6_6-builds.SOVzea`中macOS、fixed iPhone/iPad/Apple TV/Vision Pro全部结构化零诊断成功并各有`1 AIR/1 metallib`。固定UUID只作build destination，未操作Simulator lifecycle。
- 2026-08-08：已同步OpenSpec design/visionOS media spec、阶段18 runtime contract、completion roadmap及三份planning，记录6.6单coordinator连接矩阵、subscription/pump与五资源释放、fresh证据和proof boundary。OpenSpec保持pre-mark `36/50 next 6.6`，下一步test/diff审计和repository pre-gate。
- 2026-08-08：首轮repository wrapper `/tmp/LuneX-18-6_6-repository-pre.WhdVje`在fixture、OpenSpec和三次generator通过后，因expected scope的shell续行漏失把`task_plan.md`当作命令而exit 127；无项目哈希、源码、task、test、Keychain或设备副作用。改用单行参数数组从fresh目录重跑完整门。
- 2026-08-08：repository r2 `/tmp/LuneX-18-6_6-repository-pre-r2.0x59Vj`已通过全部实质检查，最终仅因design内`simulator`与`runtime`跨行而未命中单行证明边界短语；该轮不计最终证据。改为独立关键词断言后从fresh目录完整运行r3。
- 2026-08-08：repository r3 `/tmp/LuneX-18-6_6-repository-pre-r3.rkuqeN`在fixture/OpenSpec后因`eval`内awk双重转义错误退出，generator结果仍稳定。停止重试一体化wrapper，切换为无`eval`的离散逐门检查并汇总final evidence。
- 2026-08-08：最终离散repository pre-gate `/tmp/LuneX-18-6_6-repository-pre-final.f72jUk`完整通过fixture、strict `9/9`、pre-mark `36/50 next 6.6`、三次稳定generator、精确10文件`3 test/7 authority`、membership/语义、全部retained test/build/Metal、唯一Keychain skip及仓库/proof边界；现在只勾选6.6。
- 2026-08-08：仅勾选6.6后首个post-mark `/tmp/LuneX-18-6_6-final-state.En3lJW`读取到正确`37/50 next 7.1`，但任务diff断言遗漏Markdown列表符号导致只读退出；tasks实际只含6.6一删一增。改用固定完整行fresh运行r2。
- 2026-08-08：corrected post-mark final-state `/tmp/LuneX-18-6_6-final-state-r2.3WfaIK`完整通过strict `9/9`、OpenSpec `37/50 next 7.1`、精确11文件`3 test/8 authority`、唯一6.6 checkbox、稳定project/retained evidence及opt-in/process/diff边界；未重跑测试/build/generator或操作Keychain/live host/Simulator。下一步final diff audit与final-record。
- 2026-08-08：final diff audit `/tmp/LuneX-18-6_6-final-audit.4WLAtW`通过最终11文件`3 test/8 authority/0 production`、测试声明`+2/-1`且无弱化、coordinator/resource/AppModel语义、唯一6.6 checkbox、稳定project/retained evidence和proof边界。下一步final-record后独立提交推送。
- 2026-08-08：final-record `/tmp/LuneX-18-6_6-final-record.35cIbj`通过基线`HEAD == origin/main == 33cc6fd`、strict `9/9`、OpenSpec `37/50 next 7.1`、最终11文件`3 test/8 authority/0 production`、唯一6.6 checkbox、稳定project、三道final gate、retained evidence与proof边界；进入精确stage、提交与push/fetch。
- 2026-08-07：系统更新后恢复阶段18任务7.1；session catchup、active goal、Git、全部OpenSpec context files和现有tvOS UI/runtime状态源已核对。当前`HEAD == origin/main == 1cf40c3`、工作树clean、OpenSpec `37/50 ready next 7.1`，真实Keychain/live-host opt-in保持unset且未操作Simulator。
- 2026-08-07：7.1调查确认surface focus/overlay handoff已实现，但tvOS overlay缺actual focus/capture/controller/surface/render/HDR/audio/failure统一投影与显式焦点顺序。实现将新增只读纯值projection、tvOS-only accessible controls、focused value/source-contract tests和generator membership，不提前实现7.2-8.x。
- 2026-08-07：恢复时过宽的只读`find .. -name AGENTS.md`被主动中止；改用仓库内`rg --files`后确认无AGENTS文件，未修改仓库或设备状态。
- 2026-08-08：暂停前focused `/tmp/LuneX-18-7_1-focused.A0mQ3g/Focused.xcresult`最终结构化为`8/7/1/0`、零expected failure，build四类diagnostics全零；唯一失败来自测试切片未包含已存在的focus enum。已将source-contract起点前移到`TVStreamControlFocusTarget`，production不变，下一步fresh重跑8项。
- 2026-08-08：fresh focused `/tmp/LuneX-18-7_1-focused-r2.w2xsDG/Focused.xcresult`结构化通过`8/8 passed / 0 skipped / 0 failed / 0 expected failure`，build四类diagnostics全零；下一步fixed Apple TV direct unsigned Debug验证tvOS-only SwiftUI编译。
- 2026-08-08：fixed Apple TV direct `/tmp/LuneX-18-7_1-tvos-direct.Zs7dNK/tvos.xcresult` unsigned Debug结构化为`succeeded / 0 warning / 0 error / 0 analyzer warning`且有`1 AIR/1 metallib`；UUID仅作destination，未操作Simulator lifecycle。下一步12类related矩阵。
- 2026-08-08：fresh 12类related `/tmp/LuneX-18-7_1-related.xgCDkd/Related.xcresult`结构化通过`241/241 passed / 0 skipped / 0 failed / 0 expected failure`且build四类diagnostics全零；下一步fresh normal suite。
- 2026-08-08：fresh normal `/tmp/LuneX-18-7_1-normal.e5qCg3/Normal.xcresult`结构化通过`1097 total / 1096 passed / 1 skipped / 0 failed / 0 expected failure`且build四类diagnostics全零；唯一skip精确为显式真实Keychain round-trip，两个opt-in均unset。下一步五平台unsigned Debug。
- 2026-08-08：首轮五平台包装器 `/tmp/LuneX-18-7_1-builds.bFWCcA`在任何build前因zsh 1-based数组与Bash 0-based索引不兼容退出；未启动xcodebuild、未修改仓库或Simulator。改用显式`/bin/bash`从fresh目录执行。
- 2026-08-08：fresh五平台 `/tmp/LuneX-18-7_1-builds-r2.KWXQQF`中macOS、fixed iPhone/iPad/Apple TV/Vision Pro unsigned Debug全部结构化零诊断成功且各有`1 AIR/1 metallib`；固定UUID只作destination，未操作Simulator lifecycle。
- 2026-08-08：已同步OpenSpec design/tvOS media/remote spec、阶段18runtime contract、completion roadmap与三份planning，记录7.1单一actual-state projection、固定row/command顺序、accessibility/privacy/HDR语义、fresh证据和proof boundary；7.1保持pre-mark `37/50 next 7.1`，下一步repository pre-gate。
- 2026-08-08：fresh repository pre-gate `/tmp/LuneX-18-7_1-repository-pre.xR5mQD`完整通过fixture、strict `9/9`、pre-mark `37/50 next 7.1`、三次稳定generator、精确14文件scope、membership/实现/privacy、全部retained test/direct/five-platform Metal及仓库/proof边界；现在只勾选7.1。
- 2026-08-08：仅勾选7.1后，post-mark `/tmp/LuneX-18-7_1-final-state.1FO4Sy`只读通过strict `9/9`、`38/50 next 7.2`、精确15文件scope、唯一checkbox、稳定project/retained evidence及仓库边界；未重跑测试/build或操作Keychain/live host/Simulator。
- 2026-08-08：final diff audit确认最终15文件为`3 production/1 test/2 project-generator/9 authority`，projection/focus/HDR/audio/privacy/accessibility实现与测试无弱化、唯一7.1 checkbox及proof tier一致；下一步final-record后独立提交推送。
- 2026-08-08：final-record `/tmp/LuneX-18-7_1-final-record.8piyUo`通过基线remote parity、strict `9/9`、`38/50 next 7.2`、15文件分类、唯一7.1 checkbox、稳定project、retained evidence、disabled opt-ins与仓库边界；进入精确stage、提交和push/fetch。
- 2026-08-08：7.1已以`8551620 Add accessible tvOS stream controls`提交推送，fetch确认`HEAD == origin/main`且工作树clean；OpenSpec为`38/50 next 7.2`。启动7.2，只组合现有visionOS window/input/controller/coordinator/render/HDR/spatial owner，不新增runtime或提前完成7.3+。
- 2026-08-08：系统更新后继续既有五平台build会话，没有重新启动构建或操作Simulator；`/tmp/LuneX-18-7_2-builds.ewkEpO`中的macOS、fixed iPhone/iPad/Apple TV/Vision Pro五个`.xcresult`均为`succeeded`、warning/error/analyzer warning全零且各有`1 AIR/1 metallib`。
- 2026-08-08：长期goal仍为active；工作树保持7.2预期范围，`git diff --check`通过，OpenSpec仍为pre-mark `38/50 ready`、next 7.2。已记录focused错误修复、replacement revision一致性防护及严格proof boundary，下一步执行final diff、generator、authority与repository门。
- 2026-08-08：同步OpenSpec design/visionOS media/input specs、阶段18runtime contract、completion roadmap与三份planning，记录7.2单一current projection、固定八行/单Disconnect命令、revision/generation/platform fail-closed、accessibility/privacy、fresh证据和proof boundary；7.2保持未勾选，下一步repository pre-gate。
- 2026-08-08：fresh repository pre-gate `/tmp/LuneX-18-7_2-repository-pre-r3.kVhSoZ`完整通过fixture、strict、pre-mark `38/50 next 7.2`、稳定generator、精确14文件scope、membership/current ownership/accessibility/privacy、retained test/build/Metal及仓库/proof边界；现在仅勾选7.2，7.3+保持pending。
- 2026-08-08：仅勾选7.2后，post-mark `/tmp/LuneX-18-7_2-final-state.McIoFj`只读通过strict、`39/50 next 7.3`、精确15文件scope、唯一checkbox、稳定project/retained evidence及仓库边界；未重跑generator/test/build或操作Keychain、live host、Simulator。
- 2026-08-08：corrected final diff audit `/tmp/LuneX-18-7_2-final-audit-r2.BWKb1R`确认最终15文件为`3 production/1 test/2 project-generator/9 authority`，production零删除、10项新测试无弱化、current replacement coherence、八行/accessibility/privacy、唯一7.2 checkbox及proof tier一致；下一步final-record。
- 2026-08-08：final-record `/tmp/LuneX-18-7_2-final-record.ucyqir`通过基线remote parity、strict、`39/50 next 7.3`、15文件分类、唯一7.2 checkbox、稳定project、三道gate、retained evidence、disabled opt-ins与proof boundary；进入精确stage、提交和push/fetch。
- 2026-08-08：7.2已以`534c68a Add accessible visionOS stream controls`提交推送，fetch确认`HEAD == origin/main`且工作树clean；OpenSpec为`39/50 next 7.3`。启动7.3，限定为现有偏好与actual state的platform Settings投影，不新增无法执行的input/controller开关或提前实现7.4+。
- 2026-08-08：新增`TVVisionPlatformSettingsPresentationState`、AppModel接线、tvOS/visionOS Settings条件UI及8项focused测试；Input/Controllers为自动行为+actual，Render/HDR/Spatial复用现有可编辑偏好+actual，macOS/iOS控件保持原路径。下一步生成工程与focused编译。
- 2026-08-08：首轮focused `/tmp/LuneX-18-7_3-focused.C9Bsu5`在测试运行前因fixture使用不存在的`.publicAPIUnavailable`编译失败；production无诊断。已改用现有`.stage18WindowedOnly`，下一步fresh重跑。
- 2026-08-08：fresh focused `/tmp/LuneX-18-7_3-focused-r2.bz5JHc/Focused.xcresult`结构化通过`8/8`且build四类diagnostics全零；fixed Apple TV与Vision Pro direct `/tmp/LuneX-18-7_3-direct.J396Zs`均零诊断成功并各有`1 AIR/1 metallib`，UUID仅作destination且未操作Simulator lifecycle。下一步related。
- 2026-08-08：fresh related `/tmp/LuneX-18-7_3-related.borVj3/Related.xcresult`结构化为`164 total/163 passed/1 skipped/0 failed`且build diagnostics全零；唯一skip精确为显式真实Keychain测试，设置迁移和其余7类相关矩阵均通过。下一步fresh normal。
- 2026-08-08：fresh normal `/tmp/LuneX-18-7_3-normal.nbTbVF/Normal.xcresult`结构化通过`1115/1114/1/0`且build diagnostics全零；唯一skip为显式真实Keychain round-trip，两个真实opt-in unset。下一步五平台unsigned Debug。
- 2026-08-08：fresh五平台 `/tmp/LuneX-18-7_3-builds.1DhVeP`中macOS、fixed iPhone/iPad/Apple TV/Vision Pro unsigned Debug全部零结构化diagnostics成功且各有`1 AIR/1 metallib`；UUID仅作destination，未操作Simulator lifecycle。下一步authority/repository门。
- 2026-08-08：同步OpenSpec design及tvOS/visionOS四份spec、阶段18runtime contract、completion roadmap与三份planning，记录automatic input/controller、existing editable preference、desired/actual、fixed rows/accessibility/privacy、fresh evidence与proof boundary；7.3保持pre-mark `39/50 next 7.3`。
- 2026-08-08：fresh repository pre-gate `/tmp/LuneX-18-7_3-repository-pre.gu3Wdy`完整通过fixture、strict、pre-mark `39/50 next 7.3`、稳定generator、精确16文件scope、membership/desired-actual/platform/accessibility/privacy、retained test/direct/five-platform Metal及仓库/proof边界；现仅勾选7.3。
- 2026-08-08：仅勾选7.3后，post-mark `/tmp/LuneX-18-7_3-final-state.8JTYco`只读通过strict、`40/50 next 7.4`、精确17文件scope、唯一checkbox、稳定project/retained evidence及仓库边界；未重跑generator/test/build或操作Keychain、live host、Simulator。
- 2026-08-08：final diff audit `/tmp/LuneX-18-7_3-final-audit.MXE9J2`确认最终17文件为`3 production/1 test/2 project-generator/11 authority`，production零删除、8项测试无弱化、AppSettings schema不变、platform/desired-actual/accessibility与唯一checkbox/proof tier一致；下一步final-record。
- 2026-08-08：final-record `/tmp/LuneX-18-7_3-final-record.oIJ6c8`通过基线remote parity、strict、`40/50 next 7.4`、17文件分类、唯一7.3 checkbox、稳定project、三道gate、retained evidence、disabled opt-ins与proof boundary；进入精确stage、提交和push/fetch。
- 2026-08-08：系统更新后恢复7.4；确认`HEAD == origin/main == 7d4452f`、工作树clean、macOS 27.0/Xcode 26.4/Swift 6.3，Keychain/live-host opt-in均unset，OpenSpec `40/50 next 7.4`。完成只读设计盘点：扩展单一`DiagnosticsStore`的opaque lease、semantic revision dedup、owned recovery、bounded history和二次脱敏export，并从AppModel current coordinator apply/clear接线；8.5/8.6前不操作Simulator。
- 2026-08-08：7.4首轮focused `/tmp/LuneX-18-7_4-focused.j34RyA`编译成功，RuntimeDiagnostics新增行为`5/5`通过；唯一失败为source-contract三条断言未容忍Swift换行，且AppModel only-testing误用了不存在的旧方法名。已改为稳定token并选用真实`testVisionPresentationCoordinatesCurrentMediaReconnectAndRemoteStop`，从fresh目录重跑；production无需因该失败修改。
- 2026-08-08：第二轮focused `/tmp/LuneX-18-7_4-focused-r2.XeVLuB`中30项里29项通过，AppModel current media/reconnect/remote-stop测试已命中并通过；唯一source-contract失败确认首个宽泛`List`补丁把Export toolbar误挂到Host Library。现将toolbar精确移动到`DiagnosticsView`并从fresh目录第三次重跑；store/AppModel行为不变。
- 2026-08-08：系统更新后再次恢复7.4；session catchup、active goal、Git、OpenSpec全部context和工具链对账完成，`HEAD == origin/main == 7d4452f`、八文件dirty、`40/50 next 7.4`，两个真实opt-in unset且未操作Simulator。fresh focused r3 `/tmp/LuneX-18-7_4-focused-r3.Dyv0SO/Focused.xcresult`已通过`31/31`，下一步结构化核对该bundle并审计production diff后运行related矩阵。
- 2026-08-08：结构化确认focused r3为`31/31`且build diagnostics全零、`1 AIR/1 metallib`；随后逐函数审计发现相同非平台action重申不会撤销旧平台lease ownership。已做最小ownership修复并新增精确回归，r3作为修复前辅助证据，下一步fresh focused r4。
- 2026-08-08：修复后fresh focused r4 `/tmp/LuneX-18-7_4-focused-r4.1USmAU/Focused.xcresult`结构化通过`32/32`、零skip/failure/expected failure，build diagnostics全零且有`1 AIR/1 metallib`。下一步8类related矩阵。
- 2026-08-08：fresh related `/tmp/LuneX-18-7_4-related.9efE6X/Related.xcresult`结构化通过`152/152`、零skip/failure/expected failure，build diagnostics全零且有`1 AIR/1 metallib`；下一步fresh normal suite。
- 2026-08-08：fresh normal `/tmp/LuneX-18-7_4-normal.AHM4Rr/Normal.xcresult`通过`1122/1121/1/0`且build diagnostics全零、`1 AIR/1 metallib`。并行读取同一bundle的skipped nodes时`xcresulttool`出现内部数据库移动冲突，bundle测试结果不受影响；首个记录补丁又因错误表锚点不相邻被原子拒绝。现改为串行只读确认唯一skip，不重跑测试。
- 2026-08-08：串行tests-tree确认normal唯一skip精确为显式真实Keychain round-trip；两个真实opt-in仍unset，文件fallback继续使用。下一步fixed Apple TV/Vision Pro direct unsigned Debug。
- 2026-08-08：首轮fixed Apple TV direct `/tmp/LuneX-18-7_4-direct.VH3uKS/tvOS.xcresult`以2个Swift error失败：`ShareLink`及initializer在tvOS unavailable；脚本未开始Vision Pro。两次记录/源码补丁因格式或文本锚点不精确被原子拒绝后，已按真实toolbar完成平台分支：tvOS显示可访问disabled unavailable状态，其他平台保留真实ShareLink，并补source-contract。下一步fresh focused和direct重跑。
- 2026-08-08：平台分支修复后的fresh focused r5 `/tmp/LuneX-18-7_4-focused-r5.wyn9qr/Focused.xcresult`结构化通过`32/32`且build diagnostics全零、`1 AIR/1 metallib`；下一步fresh fixed Apple TV/Vision Pro direct。
- 2026-08-08：系统更新后续接并结构化确认fresh direct r2 `/tmp/LuneX-18-7_4-direct-r2.2mQR5s`：fixed Apple TV与Vision Pro均`succeeded/0 warning/0 error/0 analyzer warning`且各有`1 AIR/1 metallib`。首次计数使用错误DerivedData后缀导致只读`find`失败，改用实际`*-DerivedData`后通过；未重跑build或操作Simulator。下一步fresh五平台unsigned Debug。
- 2026-08-08：fresh五平台 `/tmp/LuneX-18-7_4-builds.HlcDxq`中的macOS、fixed iPhone/iPad/Apple TV/Vision Pro unsigned Debug全部结构化为`succeeded/0 warning/0 error/0 analyzer warning`且各有`1 AIR/1 metallib`；固定UUID仅作destination，未操作Simulator lifecycle。下一步final diff审计与authority/repository门。
- 2026-08-08：同步OpenSpec design/四份tvOS与visionOS specs、阶段18runtime contract、completion roadmap及三份planning，记录7.4 single-store lease/dedup/replacement/recovery/export/tvOS availability合同、全部fresh证据和严格proof boundary；OpenSpec仍保持pre-mark `40/50 next 7.4`。下一步repository pre-gate。
- 2026-08-08：首个repository工具编排在进入shell前因JavaScript保留字变量失败；partial `/tmp/LuneX-18-7_4-repository-pre.0bdh5m`已通过fixtures、OpenSpec与三次稳定generator，但scope使用Bash 3.2不支持的`mapfile`退出。均无项目或设备副作用，改用兼容数组语法从fresh目录完整重跑。
- 2026-08-08：corrected repository r2 `/tmp/LuneX-18-7_4-repository-pre-r2.UzOB0F`已通过全部实质fixture/OpenSpec/generator/scope/static/retained test/direct/five-platform门；只读final boundary因Markdown反引号被shell解释为命令替换而退出。去掉格式依赖后仅重跑收尾，不重复generator/test/build。
- 2026-08-08：只读repository收尾再次在license固定短语断言处退出；真实`ThirdParty/ENet/LICENSE`为MIT正文并含`Permission is hereby granted`，reference/dependency/changed-scope前置检查均通过。改用真实文本继续同目录收尾。
- 2026-08-08：corrected repository pre-gate `/tmp/LuneX-18-7_4-repository-pre-r2.UzOB0F`完整通过fixtures、strict `9/9`、pre-mark `40/50 next 7.4`、三次稳定generator、精确15文件scope、membership/diagnostic/export语义、retained focused/related/normal/direct/五平台Metal及全部仓库/proof边界；现只勾选7.4。
- 2026-08-08：仅勾选7.4后，post-mark `/tmp/LuneX-18-7_4-final-state.VaTcq9`只读通过strict、`41/50 next 7.5`、精确16文件scope、唯一checkbox、稳定project/retained evidence及opt-in/process/diff边界；未重跑generator/test/build或操作Keychain/live host/Simulator。下一步final audit/record。
- 2026-08-08：final diff audit `/tmp/LuneX-18-7_4-final-audit.p2Anhn`通过最终16文件`3 production/2 test/11 authority`、单一store/AppModel/UI实现、7项新增测试+现有workflow扩展无弱化、唯一7.4 checkbox及全部仓库/proof边界。下一步final-record后提交推送。
- 2026-08-08：final-record `/tmp/LuneX-18-7_4-final-record.k0tqwb`通过基线remote parity、strict、`41/50 next 7.5`、16文件分类、唯一7.4 checkbox、稳定project、三道gate、retained evidence、disabled opt-ins与proof boundary；进入精确stage、提交和push/fetch。
- 2026-08-08：7.4已以`cbf2a28 Add privacy-bounded platform diagnostics`提交推送，fetch确认`HEAD == origin/main`且工作树clean；OpenSpec为`41/50 next 7.5`。启动7.5应用层综合测试审计，真实opt-in保持unset且不操作Simulator lifecycle。
- 2026-08-08：系统更新后恢复7.5，确认`HEAD == origin/main == cbf2a28`、macOS 27.0/Xcode 26.4/Swift 6.3、OpenSpec `41/50 next 7.5`及长期goal active。源码审计确认平台actual-state/Settings动态String路径不具可靠本地化提取语义，且visionOS可调整窗口/辅助功能字号缺compact状态行回退；开始最小production修复与连接式应用测试，不执行8.1+或Simulator lifecycle。
- 2026-08-08：首个focused `/tmp/LuneX-18-7_5-focused.EeIfNy`在编译前因命令使用不存在的`LuneX` scheme退出65；无测试、Keychain、live host或Simulator副作用。改为读取工程真实scheme后从fresh目录运行。
- 2026-08-08：focused r2 `/tmp/LuneX-18-7_5-focused-r2.j3Ye40/Focused.xcresult`完成编译并通过31/32；唯一失败为新增visionOS UI投影断言，确认AppModel以旧geometry-source revision比较coordinator重标后的window presentation，完整current状态被错误显示为window/input unavailable。已做最小current coordinator projection修复，下一步fresh重跑。
- 2026-08-08：修复后focused r3 `/tmp/LuneX-18-7_5-focused-r3.WqRDU9/Focused.xcresult`结构化通过`32/32`、零skip/failure/expected failure，build diagnostics全零且有`1 AIR/1 metallib`。继续强化tvOS命令顺序、compact/wide接线与vision replacement/stale UI fail-closed后再做fresh focused。
- 2026-08-08：focused r4 `/tmp/LuneX-18-7_5-focused-r4.66EBzs/Focused.xcresult`中原32项继续通过，新增的partial-window fixture断言失败；fixture无同步presentation，UI unavailable符合actual-state合同。已把断言改为部分状态不得冒充visible/captured，production不变，下一步fresh focused r5。
- 2026-08-08：fresh focused r5 `/tmp/LuneX-18-7_5-focused-r5.2Nrx3l/Focused.xcresult`结构化通过`33/33`、零skip/failure/expected failure，build diagnostics全零且有`1 AIR/1 metallib`；下一步fixed Apple TV/Vision Pro direct unsigned Debug编译。
- 2026-08-08：首轮direct `/tmp/LuneX-18-7_5-direct.z0BcBh/tvOS.xcresult`在RootView编译时因`LabeledContent(_:value:)`要求StringProtocol而拒绝LocalizedStringResource，以1个Swift error退出，Vision未开始。已改用content closure与显式本地化Text并补source-contract，下一步fresh focused与direct重跑。
- 2026-08-08：closure修复后fresh focused r6 `/tmp/LuneX-18-7_5-focused-r6.MlK4I5/Focused.xcresult`结构化通过`33/33`且build diagnostics全零、`1 AIR/1 metallib`；fresh direct r2 `/tmp/LuneX-18-7_5-direct-r2.l0qZ4X`中fixed Apple TV与Vision Pro均零诊断成功且各有`1 AIR/1 metallib`。生产diff审计确认本地化字段、current coordinator同步projection、compact/wide与privacy边界，下一步related矩阵。
- 2026-08-08：fresh related `/tmp/LuneX-18-7_5-related.UQqYF6/Related.xcresult`结构化通过`217 total/216 passed/1 skipped/0 failed/0 expected failure`，build diagnostics全零且有`1 AIR/1 metallib`；唯一skip精确为显式真实Keychain round-trip，两个opt-in均unset。下一步fresh normal suite，不提前勾选8.1。
- 2026-08-08：fresh normal `/tmp/LuneX-18-7_5-normal.9MVpwm/Normal.xcresult`结构化通过`1123 total/1122 passed/1 skipped/0 failed/0 expected failure`，build diagnostics全零且有`1 AIR/1 metallib`；下一步串行确认唯一skip、generator稳定性和fresh五平台unsigned Debug，7.5验证不提前完成8.1。
- 2026-08-08：串行确认related与normal唯一skip均为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`；`LUNEX_RUN_KEYCHAIN_TEST`与`LUNEX_RUN_LIVE_HOST_TEST`均unset，正常测试继续使用文件fallback。
- 2026-08-08：fresh五平台 `/tmp/LuneX-18-7_5-builds.g4vZQT`中的macOS、fixed iPhone/iPad/Apple TV/Vision Pro unsigned Debug全部结构化为`succeeded/0 warning/0 error/0 analyzer warning`且各有`1 AIR/1 metallib`；固定UUID仅作destination，未操作Simulator lifecycle。
- 2026-08-08：generator before/after均为SHA-256 `aee5f8cb55fffe616537d30eb933012a068658cea6e67ac48d06c3b236d8ed5e`；同步OpenSpec design/四份spec、阶段18runtime contract、completion roadmap与三份planning，记录7.5本地化/布局/focus/window-input/actual-state/migration/clean-stop、真实缺陷修复、retained evidence及proof boundary。OpenSpec仍保持pre-mark`41/50 next 7.5`，下一步repository pre-gate。
- 2026-08-08：首个7.5 repository gate编排因JavaScript模板内shell brace expansion被误解析，在任何shell命令前以`SyntaxError`退出；无证据目录、仓库、测试/build、Keychain/live host或Simulator副作用。改用不含`${...}`的`env`检查从fresh目录完整重跑。
- 2026-08-08：第二轮repository `/tmp/LuneX-18-7_5-repository-pre.4pgNSf`通过fixtures、strict/apply、三次稳定generator、精确20文件scope和diff-check后，在retained证据读取前因静态门使用不存在的`legacyAudioSettings` token退出；真实迁移fixture使用`legacyObject.removeValue(forKey: "audio")`。只修gate并从fresh目录重跑，不改实现/测试或重复已通过测试/build。
- 2026-08-08：repository r2 `/tmp/LuneX-18-7_5-repository-pre-r2.rWu1dV`同样完成前置门后，因把具体`/tmp`证据路径强制要求在只记录语义/proof tier的`design.md`中而退出；实际路径已在runtime contract、roadmap和planning索引。此前跨行proof短语只是候选并非真实退出点；修正authority索引范围与稳定token后fresh重跑。
- 2026-08-08：corrected repository pre-gate `/tmp/LuneX-18-7_5-repository-pre-r3.1O8JBJ`完整通过fixtures、strict `9/9`、pre-mark `41/50 next 7.5`、三次稳定generator、精确20文件scope、membership/static、retained `33/217/1123`测试、direct/五平台build与Metal、唯一Keychain skip和全部仓库/proof边界；现仅勾选7.5，8.1+保持pending。
- 2026-08-08：仅勾选7.5后，post-mark `/tmp/LuneX-18-7_5-final-state.cb0UO9`只读通过strict `9/9`、`42/50 next 8.1`、精确21文件scope、唯一checkbox、稳定project/retained evidence、disabled opt-ins及仓库/proof边界；未重跑generator/test/build或操作Keychain、live host、Simulator。下一步final audit/record。
- 2026-08-08：首轮final-audit `/tmp/LuneX-18-7_5-final-audit.L2aaaO`把localized等价断言替换误判为弱化并退出；真实diff有69条新增断言、37条删除的旧String断言、1个新增测试函数、0个删除测试函数且无skip/disable。修正为断言总量/测试函数/禁用检查后fresh重跑。
- 2026-08-08：corrected final diff audit `/tmp/LuneX-18-7_5-final-audit-r2.7dsVBW`通过最终21文件`5 production/5 test/6 OpenSpec/2 docs/3 planning`、69新增/37迁移删除断言、1新增/0删除测试函数、无skip/disable、production合同、唯一7.5 checkbox和全部仓库/proof边界；下一步final-record。
- 2026-08-08：final-record `/tmp/LuneX-18-7_5-final-record.fepytG`通过基线remote parity、strict、`42/50 next 8.1`、21文件分类、唯一7.5 checkbox、稳定project、pre/post/audit三道门、retained evidence、disabled opt-ins和proof boundary；进入精确stage、提交与push/fetch。
- 2026-08-08：7.5已以`9ca6c12 Add adaptive localized TV and Vision controls`提交推送，fetch确认`HEAD == origin/main == 9ca6c120c2de3fc2e0598281246d86403a5dfa77`且工作树clean；OpenSpec为`42/50 next 8.1`。启动8.1 fresh normal verification，显式移除真实opt-in并继续文件fallback，不操作Simulator lifecycle。
- 2026-08-08：8.1 fresh `/tmp/LuneX-18-8_1-normal.GjIqrj/Normal.xcresult`通过`1123 total/1122 passed/1 skipped/0 failed/0 expected failure`；唯一skip精确为显式真实Keychain round-trip，build diagnostics全零且有`1 AIR/1 metallib`。两个真实opt-in由命令显式移除、文件fallback生效且未操作Simulator。
- 2026-08-08：同步OpenSpec design、阶段18runtime contract、completion roadmap与三份planning，记录8.1 fresh normal、唯一skip、零diagnostics/Metal、disabled opt-ins/file fallback及proof boundary；OpenSpec保持pre-mark`42/50 next 8.1`，下一步repository pre-gate。
- 2026-08-08：8.1 repository首轮 `/tmp/LuneX-18-8_1-repository-pre.qbRDTl`通过全部前置与retained normal结构化检查后，因强制`design.md`使用固定`fresh normal`短语而退出；design实际使用等价`new complete macOS normal-suite run`并保留正确fallback/proof边界。缩小具体路径断言到证据索引文件，fresh重跑完整门但不重复normal。
- 2026-08-08：corrected 8.1 repository pre-gate `/tmp/LuneX-18-8_1-repository-pre-r2.gPOMhm`完整通过fixtures、strict `9/9`、pre-mark`42/50 next 8.1`、三次稳定generator、6文件scope、fresh normal/唯一skip/build/Metal、disabled opt-ins/file fallback及仓库/proof边界；现仅勾选8.1，8.2+保持pending。
- 2026-08-08：仅勾选8.1后，post-mark `/tmp/LuneX-18-8_1-final-state.uybdfA`只读通过strict、`43/50 next 8.2`、7个authority文件、唯一checkbox、稳定project/normal/pre-gate和disabled opt-ins；未重复generator/normal或操作Simulator。下一步final audit/record。
- 2026-08-08：final audit `/tmp/LuneX-18-8_1-final-audit.fk0oho`通过7个authority文件/零production-test、唯一8.1 checkbox、strict `9/9`、`43/50 next 8.2`、normal/pre/post、project/reference/dependency与全部proof边界；下一步final-record。
- 2026-08-08：final-record `/tmp/LuneX-18-8_1-final-record.w4fV2U`通过基线remote parity、strict、`43/50 next 8.2`、7个authority文件、唯一8.1 checkbox、fresh normal/pre/post/audit、稳定project/reference/dependency、disabled opt-ins与proof boundary；进入独立提交推送。
- 2026-08-08：8.1已以`97e932a Verify complete normal test suite`提交推送，fetch确认`HEAD == origin/main == 97e932af8857022f9df653536dd5b5981445e1f9`且工作树clean；OpenSpec为`43/50 next 8.2`。启动十项五平台Debug/Release isolated unsigned warnings-as-errors build，固定UUID仅作destination且不操作Simulator lifecycle。
- 2026-08-08：fresh `/tmp/LuneX-18-8_2-builds.Dvqg9S`顺序完成macOS、fixed iPhone/iPad/Apple TV/Vision Pro Debug/Release十项isolated unsigned warnings-as-errors build；结构化逐项均为`succeeded/0 warning/0 error/0 analyzer warning/1 AIR/1 metallib`，未操作Simulator lifecycle。
- 2026-08-08：同步OpenSpec design、阶段18runtime contract、completion roadmap与三份planning，记录8.2十项矩阵、独立证据、固定destination、Metal及unsigned/proof boundary；OpenSpec保持pre-mark`43/50 next 8.2`，下一步repository pre-gate。
- 2026-08-08：8.2 repository pre-gate `/tmp/LuneX-18-8_2-repository-pre.GRQL3w`完整通过fixtures、strict `9/9`、pre-mark`43/50 next 8.2`、三次稳定generator、6文件scope、十项structured build、`10 AIR/10 metallib`、disabled opt-ins/process及仓库/proof边界；现仅勾选8.2，8.3+保持pending。
- 2026-08-08：仅勾选8.2后，post-mark `/tmp/LuneX-18-8_2-final-state.tVJVek`只读通过strict、`44/50 next 8.3`、7个authority文件、唯一checkbox、稳定project/build/pre-gate与disabled opt-ins；未重复generator/build或操作Simulator。下一步final audit/record。
- 2026-08-08：8.2 final audit `/tmp/LuneX-18-8_2-final-audit.WMG1HZ`通过7个authority文件/零production-test、唯一checkbox、strict `9/9`、`44/50 next 8.3`、十项build/pre/post及全部仓库/proof边界；下一步final-record。
- 2026-08-08：8.2 final-record `/tmp/LuneX-18-8_2-final-record.hv5iVY`通过基线remote parity、strict、`44/50 next 8.3`、7个authority文件、唯一checkbox、十项build/pre/post/audit、稳定project/reference/dependency、disabled opt-ins及proof boundary；进入独立提交推送。
- 2026-08-08：8.2已以`390db08 Verify five-platform build matrix`提交推送，fetch确认`HEAD == origin/main == 390db08989669c703b3a6fb47ed1384b13da5158`且工作树clean；OpenSpec为`44/50 next 8.3`。启动fresh repository/analyzer gate盘点与执行，不操作Simulator lifecycle。
- 2026-08-08：8.3 fresh analyzer `/tmp/LuneX-18-8_3-analyzer.1Edacz`顺序完成macOS Debug/Release Analyze；两项均`succeeded/0 error/0 compiler warning/4 fixed ENet findings`，first-party/bridge为0，opt-ins未设置。结构化汇总首次JS模板被shell `${...}`外层解析阻断、第二次`awk`转义失败；均未重跑Analyze，改为从已保留xcresult/JSON用`jq`修正汇总。
- 2026-08-08：8.3 generator pre-gate `/tmp/LuneX-18-8_3-repository-pre.1yCWep`确认baseline加连续三次生成的四个project哈希完全一致且无工程diff；task 1.6 API probe仍可读。继续完整repository pre-gate，8.3保持未勾选。
- 2026-08-08：8.3验收编排另记录两项无实现副作用的shell修正：entitlement只读展示中的`echo ===...`触发zsh等号展开，四SDK compile首轮依赖Bash式`set -- $ROW`但zsh不自动word-split，API工具链捕获首轮遗漏`swift --version` stderr且静态token应为公开API真实名称`isListenerHeadTrackingEnabled`。均改为明确参数/case、`2>&1`及真实token，只重跑未完成的只读子门。
- 2026-08-08：完整repository pre-gate `/tmp/LuneX-18-8_3-repository-pre.1yCWep`通过fixtures、strict `9/9`、`44/50 next 8.3`、generator/membership、clean-room/reference/ENet pin-license、entitlement/configuration、privacy/API、四SDK strict compile、fresh analyzer及Git/process/opt-in/proof边界；未操作Simulator lifecycle。
- 2026-08-08：同步OpenSpec design、阶段18runtime contract、completion roadmap与三份planning，记录8.3 offline repository/static/API/analyzer结果及4项固定ENet风险；OpenSpec仍保持pre-mark`44/50 next 8.3`。下一步pre-mark authority gate，通过后只勾选8.3，预期`45/50 next 8.4`。
- 2026-08-08：pre-mark authority gate `/tmp/LuneX-18-8_3-authority-pre.Q34BIA`首轮通过scope/strict/evidence后，因对跨行`Tasks 8.4-8.8 remain`使用单行全文正则退出；改查稳定`8.4-8.8`与proof token后只读收尾通过`44/50 next 8.3`、6 authority、零production/test及全部边界，未重复analyzer/generator/compile。现仅勾选8.3，下一步post-mark final-state。
- 2026-08-08：仅勾选8.3后，post-mark `/tmp/LuneX-18-8_3-final-state.9FJ4uY`只读通过strict `9/9`、`45/50 next 8.4`、7 authority、零production/test、唯一checkbox、稳定project/retained gates及disabled opt-ins/process/proof边界；未重复analyzer/generator/compile或操作Simulator。下一步final audit/record。
- 2026-08-08：8.3 final audit `/tmp/LuneX-18-8_3-final-audit.n2fBD4`通过最终7文件authority-only scope、零production/test、唯一8.3 checkbox、strict `9/9`、`45/50 next 8.4`及全部project/reference/artifact/opt-in/process/proof边界；下一步final-record后独立提交推送。
- 2026-08-08：8.3 final-record `/tmp/LuneX-18-8_3-final-record.bYIj8N`通过基线remote parity、strict `9/9`、`45/50 next 8.4`、7 authority、唯一checkbox、稳定project/reference/dependency/artifacts、retained analyzer/pre/post/audit与proof boundary；进入精确stage、提交、push/fetch。
- 2026-08-08：8.3已以`1f7884c Verify repository and analyzer gates`提交推送，fetch确认`HEAD == origin/main == 1f7884c791432fcaba3512d16e61563ed77c7d44`且工作树clean；OpenSpec为`45/50 next 8.4`。启动fresh完整ASan/TSan与malloc resource集合，真实opt-in unset且不操作Simulator lifecycle。
- 2026-08-08：8.4首轮fresh完整ASan `/tmp/LuneX-18-8_4-asan.x8oZgs`结构化为`1123 total/1121 passed/1 explicit Keychain skip/1 failed/0 expected failure`，build diagnostics全零且无ASan/LeakSanitizer报告。唯一失败为空间音频replacement/clean-stop应用集成测试在仅100次`Task.yield()`的`waitUntil`内未等到首个audio runtime；先做isolated ASan和事件路径诊断，不重复完整suite，不勾选8.4。
- 2026-08-08：fresh isolated ASan `/tmp/LuneX-18-8_4-asan-isolated.bEFRLG/Isolated-ASan.xcresult`中目标用例`1/1 passed`、`0.027s`，build diagnostics与sanitizer报告均为零，两个真实opt-in unset；确认是完整suite调度压力下的测试等待缺陷。下一步只修该integration初始就绪等待的有界wall-clock与分项诊断，再跑targeted ASan和fresh complete ASan。
- 2026-08-08：已最小修改`AppModelWorkflowTests`：仅目标integration测试的初始四条件等待改为2秒`ContinuousClock`有界轮询，失败时报告video/audio starts、audio engine、audio runtime与session phase并停止该测试，避免二次unwrap噪声；production与全局199处`waitUntil`合同不变。下一步fresh targeted ASan验收。
- 2026-08-08：修复后fresh targeted ASan `/tmp/LuneX-18-8_4-asan-targeted.Cgh65F/Targeted-ASan.xcresult`结构化通过`1/1`、`0.028s`，build diagnostics与ASan/LeakSanitizer报告全零，真实opt-in unset。下一步从fresh DerivedData重跑完整1123项ASan并串行确认唯一Keychain skip。
- 2026-08-08：修复后fresh complete ASan `/tmp/LuneX-18-8_4-asan-complete.kglBGp/Complete-ASan.xcresult`结构化通过`1123 total/1122 passed/1 explicit Keychain skip/0 failed/0 expected failure`，build及ASan/LeakSanitizer diagnostics全零，真实opt-in unset；该结果仅为offline macOS sanitizer证据。下一步fresh complete TSan。
- 2026-08-08：fresh complete TSan `/tmp/LuneX-18-8_4-tsan-complete.SlgWeu/Complete-TSan.xcresult`结构化通过`1123 total/1122 passed/1 explicit Keychain skip/0 failed/0 expected failure`，build diagnostics与ThreadSanitizer/data-race报告全零，真实opt-in unset。下一步fresh malloc resource 13-suite选择集。
- 2026-08-08：首轮malloc选择集 `/tmp/LuneX-18-8_4-malloc-resource.qymDw4/Malloc-Resource.xcresult`的13个精确suite结构化通过`413/413`、build与crash/corruption diagnostics全零；但日志只确认build工具启用stack logging，未直接确认`xctest`继承四个malloc变量。该结果不完成gate，下一步通过`.xctestrun` EnvironmentVariables显式注入后fresh复跑。
- 2026-08-08：corrected explicit malloc `/tmp/LuneX-18-8_4-malloc-explicit.DYbtJZ`先fresh build-for-testing，再以SHA-256 `e7b6593d35cc29e65cba00edd8a7776d08a9699208960610cffe2807cc6ccd81`的`.xctestrun`显式注入四个malloc变量并关闭并行；actual `xctest`确认guard/scribble/stack logging，13 suite `413/413 passed`且零corruption/crash，226项identifier覆盖task 8.4资源目标。下一步同步authority并运行repository pre-gate，8.4仍pending。
- 2026-08-08：已同步OpenSpec design、阶段18runtime contract、completion roadmap与三份planning，完整记录8.4失败分流/最小修复/ASan/TSan/显式malloc资源证据和proof boundary；OpenSpec仍为pre-mark `45/50 next 8.4`。下一步repository pre-gate，通过后才勾选8.4。
- 2026-08-08：首个8.4 repository pre-gate在进入shell前因JavaScript模板误解析shell opt-in参数展开而以`ReferenceError`退出；无证据目录、generator/test/build、仓库或设备副作用。改用`env | rg`后从fresh目录完整重跑。
- 2026-08-08：repository pre-gate r2 `/tmp/LuneX-18-8_4-repository-pre-r2.rLthZx`通过fixture self/tree后，因OpenSpec CLI逐项列表不在旧`.results[]`路径而由jq退出；generator和后续retained evidence门均未执行。读取真实schema后fresh r3重跑。
- 2026-08-08：macOS更新后恢复阶段18/8.4，确认goal active、`HEAD == origin/main == 1f7884c`、OpenSpec `45/50 next 8.4`、精确7文件dirty、真实opt-in unset且无残留build/test进程；未查询或操作Simulator lifecycle。
- 2026-08-08：首次恢复记录patch因使用摘要近似句而非文件逐字锚点，在写入前被`apply_patch`拒绝且无部分修改；改用精确EOF锚点后完成记录。
- 2026-08-08：只读审计`/tmp/LuneX-18-8_4-repository-pre-r3.E85mP1`确认其已生成fixture/OpenSpec/scope/test diff/generator/diff-check以及targeted ASan、complete ASan/TSan和explicit malloc全部抽取文件，但没有step marker或最终success record，无法唯一定位最后失败断言，故不计完整gate。下一步fresh r4加入逐步marker并复用retained证据，不重复测试。
- 2026-08-08：marker化r4 `/tmp/LuneX-18-8_4-repository-pre-r4.Uj9ifm`通过fixture/OpenSpec/scope/generator/diff、四个retained xcresult串行抽取、sanitizer日志、explicit malloc、authority及绝大多数repository边界，line 99仅因过宽`find`命中被忽略且mtime为7月10日的既有`build/DerivedData`退出。无实现/测试/build/Simulator副作用；fresh r5改用Git可见artifact漂移断言。
- 2026-08-08：fresh r5 `/tmp/LuneX-18-8_4-repository-pre-r5.6JDUhc`完成前两组门和四个retained xcresult串行抽取后，jq因压缩表达式中的非法`?//`token在skip断言前退出；无测试/build/Simulator副作用。fresh r6改回`.nodeIdentifier? // empty`。
- 2026-08-08：corrected fresh repository pre-gate `/tmp/LuneX-18-8_4-repository-pre-r6.KP5QaD`完整通过10个marker组并写入`SUCCESS`，覆盖fixture、strict/apply、scope、稳定generator、test-only diff、retained targeted/complete ASan与TSan、唯一Keychain skip、explicit malloc、authority及全部repository边界；现只勾选8.4。
- 2026-08-08：仅勾选8.4后，首次post-mark `/tmp/LuneX-18-8_4-final-state.3lQKRT`确认OpenSpec已为`46/50 next 8.5`，但checkbox只读正则少计算Markdown列表自身的`-`而退出；实际tasks diff只有`-- [ ] 8.4`到`+- [x] 8.4`，8.5-8.8保持pending。修正wrapper后fresh重跑。
- 2026-08-08：corrected post-mark `/tmp/LuneX-18-8_4-final-state-r2.Q4kKuv`只读通过strict `9/9`、`46/50 next 8.5`、8文件scope、唯一checkbox、稳定project/retained evidence及disabled opt-ins/process/repository边界；下一步final diff audit与final-record。
- 2026-08-08：首轮final audit `/tmp/LuneX-18-8_4-final-audit.FMHcPD`通过scope，在test review中因`rg -c`零匹配不输出`0`而把“0个测试函数增删”误判失败；逐项复核其他helper/timeout/diagnostic/skip断言均成立。规范化零计数后fresh重跑。
- 2026-08-08：corrected final audit `/tmp/LuneX-18-8_4-final-audit-r2.5OLJiU`通过最终8文件`0 production/1 test/7 authority`、局部等待修复无测试函数或skip弱化、唯一8.4 checkbox、strict `9/9`、`46/50 next 8.5`及全部repository/proof边界；下一步final-record与提交推送。
- 2026-08-08：final-record `/tmp/LuneX-18-8_4-final-record.8Ps0cQ`通过`46/50 next 8.5`、最终8文件、三道final gate、retained sanitizer/malloc、稳定project及全部repository/proof边界；8.4进入精确stage、提交与push/fetch。
- 2026-08-08：8.4已以`82ccd30 Verify sanitizer and resource gates`提交推送，fetch确认`HEAD == origin/main == 82ccd305e1b75cf182a9b934b6b8bfbd7ea6d08d`且工作树clean；OpenSpec为`46/50 next 8.5`。启动固定tvOS/visionOS Simulator只读identity/state/single-instance盘点，不执行泛化`simctl list`或任何生命周期操作。
- 2026-08-08：直接读取固定device/runtime metadata确认Apple TV与Vision Pro仍为26.4正确UUID/name、未删除且state=1；全局51份device plist仅iOS 26.4 iPhone 17 `1864B6E2-2C29-4E4C-97AA-F1E137096F8D`为state=3，保留该用户现有Booted实例，不关闭或接管。
- 2026-08-08：首轮结构化inventory `/tmp/LuneX-18-8_5-inventory.0E7yIY`在`xcodebuild`查询前因Apple TV plist的`NSDate lastUsedAt`无法整体转JSON而退出；未修改源文件或操作Simulator。改为逐字段plist解析后fresh重跑。
- 2026-08-08：corrected bounded inventory `/tmp/LuneX-18-8_5-inventory-r2.VXUoDR`通过固定26.4 Apple TV/Vision Pro UUID/runtime/name/device/default mapping、installed runtime profile、单实例、27.0同名隔离、scheme destination availability、全局state与pre/post metadata不变检查；两个固定设备均Shutdown且唯一，现有Booted iPhone保持不变，lifecycle命令为空。
- 2026-08-08：已同步OpenSpec design、阶段18runtime contract、completion roadmap与三份planning，记录8.5方法、当前identity/state、不同runtime隔离、现有iPhone保留和严格proof boundary。8.5仍保持pre-mark`46/50 next 8.5`，下一步repository pre-gate。
- 2026-08-08：8.5 repository pre-gate `/tmp/LuneX-18-8_5-repository-pre.azHeo5`一次通过fixture、strict/apply、6 authority scope、稳定generator、retained inventory/metadata/destination、disabled opt-ins及全部repository/proof边界；现仅勾选8.5。
- 2026-08-08：仅勾选8.5后，post-mark `/tmp/LuneX-18-8_5-final-state.E5JkFk`只读通过strict、`47/50 next 8.6`、7 authority scope、唯一checkbox、retained inventory/pre-gate、稳定project及repository边界；未重复inventory或操作Simulator。下一步final audit/record。
- 2026-08-08：8.5 final audit `/tmp/LuneX-18-8_5-final-audit.YnuqwB`通过7文件authority-only scope、唯一checkbox、current inventory/identity/preservation语义、strict `9/9`、`47/50 next 8.6`及全部仓库/proof边界；下一步final-record与提交推送。
- 2026-08-08：8.5 final-record `/tmp/LuneX-18-8_5-final-record.fy4DMG`通过`47/50 next 8.6`、最终7文件、四道成功门、retained inventory、稳定project及全部repository/proof边界；进入精确stage、提交与push/fetch。
- 2026-08-08：macOS更新后恢复阶段18/8.6，确认Xcode 26.4、macOS 27.0、`HEAD == origin/main == 5a58549d7e614f5884cc5a5b67f45d6229806682`、Git clean、OpenSpec `47/50 next 8.6`且真实Keychain/live-host opt-in unset。
- 2026-08-08：8.6只读初查确认工程为4个application target加1个macOS unit-test bundle、UI-testing product type为0且无UI-test/navigation-harness命名文件；继续从generator/shared scheme/XCUITest scan交叉确认现有bounded target集合，不操作Simulator lifecycle。
- 2026-08-08：首轮bounded audit `/tmp/LuneX-18-8_6-bounded-target.VBJhZV`在baseline因错误要求工作树clean而退出；实际三份planning已按计划dirty。该轮未进入target/xcresult/device检查且无Simulator副作用；corrected轮改为锁定三文件scope与pre/post diff hash。
- 2026-08-08：bounded audit r2 `/tmp/LuneX-18-8_6-bounded-target-r2.4hDm4n`通过前三组，在Ruby模板product-type过窄引号匹配处退出；项目事实未失败，未读取retained xcresult或执行Simulator target。r3按稳定token计数完整重跑只读门。
- 2026-08-08：corrected 8.6 bounded audit `/tmp/LuneX-18-8_6-bounded-target-r3.VTe8DU`七组全部通过：existing/executed tvOS/visionOS Simulator UI target为`0/0`，retained 7.5/8.1 offline tests结构化可读且唯一skip为真实Keychain opt-in，固定Apple TV/Vision Pro plist hash前后相同并继续Shutdown；无Simulator lifecycle/build/test/install/launch操作。
- 2026-08-08：首个authority组合补丁因`design.md`换行锚点不精确被原子拒绝；按稳定章节标题拆分后已同步OpenSpec design、阶段18runtime contract、completion roadmap与三份planning，明确8.6是现有target空集合边界而非Simulator App runtime通过。8.7 signed physical/live与8.8最终同步保持pending，下一步repository pre-gate。
- 2026-08-08：首个8.6 repository pre-gate编排因JavaScript模板内Markdown反引号在shell前以SyntaxError退出；无证据目录、fixture/generator、仓库或设备副作用。改用无反引号稳定token从fresh目录完整重跑。
- 2026-08-08：8.6 repository pre-gate `/tmp/LuneX-18-8_6-repository-pre-r2.iN3qYB`通过fixture、strict `9/9`、pre-mark `47/50 next 8.6`、精确6 authority scope、三次稳定generator、retained bounded audit及全部repository/proof边界；随后仅勾选8.6。
- 2026-08-08：首轮post-mark `/tmp/LuneX-18-8_6-final-state.cJUFIH`确认`48/50 next 8.7`与7文件scope后，在转义过度的checkbox正则处退出；tasks diff实际精确只有8.6一对变化，改用固定前缀解析fresh重跑。
- 2026-08-08：corrected post-mark `/tmp/LuneX-18-8_6-final-state-r2.MqvuzZ`只读通过strict `9/9`、`48/50 next 8.7`、7文件authority-only scope、唯一8.6 checkbox、retained audit/pre-gate与全部repository边界；8.7/8.8保持pending，下一步final audit/record。
- 2026-08-08：首个8.6 final audit编排再次因JavaScript模板内Markdown反引号在shell前SyntaxError退出；无证据目录或副作用。corrected轮移除全部反引号字符并从fresh目录完整运行。
- 2026-08-08：corrected final audit `/tmp/LuneX-18-8_6-final-audit-r2.c9Anqw`通过最终7文件authority/tasks scope、零production/test/project/config/vendor/reference、唯一8.6 checkbox、strict `9/9`、`48/50 next 8.7`及retained evidence/repository/proof边界；下一步final-record。
- 2026-08-08：final-record `/tmp/LuneX-18-8_6-final-record.eWNhuu`通过authority、四道retained gate、空集合结果、固定设备、唯一checkbox、稳定project与repository边界；补入索引后运行final-record r2再提交。
- 2026-08-08：8.6以`339b71a Record bounded simulator UI target boundary`提交推送，fetch确认`HEAD == origin/main`且工作树clean；OpenSpec为`48/50`，进入8.7 readiness盘点。
- 2026-08-08：privacy-minimized `/tmp/LuneX-18-8_7-readiness.nLhQfT`确认物理Apple TV类1台且paired/booted/developer-mode-capable，物理Vision Pro为0，live-host/真实Keychain opt-in均unset，无signed physical/live receipt；未探测signing identity、安装/启动App或打开stream。
- 2026-08-08：首个脱敏清理命令因`rm -f`风格被策略执行前拒绝；corrected命令验证summary后精确删除raw identity JSON与中间projection，最终只保留类别计数/布尔/blocking classes且SUCCESS。
- 2026-08-08：8.7条件不成立并保持pending；开始8.8同步五级proof boundary，明确change不archive、阶段18不complete且阶段19/20不得替代物理/live receipt。下一步repository pre-gate，通过前8.8不勾选。
- 2026-08-08：8.8 repository pre-gate `/tmp/LuneX-18-8_8-repository-pre.U0WN6n`通过fixture、strict `9/9`、pre-mark `48/50`、6 authority scope、三次稳定generator、脱敏readiness、五级矩阵与repository边界；随后只勾选8.8。
- 2026-08-08：post-mark `/tmp/LuneX-18-8_8-final-state.r8HNJn`通过strict `9/9`、`49/50`、唯一pending 8.7、7文件scope、唯一8.8 checkbox、retained evidence与repository边界；change仍active且不可archive，下一步final audit/record。
- 2026-08-08：首轮8.8 final audit `/tmp/LuneX-18-8_8-final-audit.Yi4ckM`通过scope/OpenSpec/checkbox后，因contract关键句跨行而被单行全文断言误判；无实现或设备副作用，改为两段稳定token fresh重跑。
- 2026-08-08：corrected final audit `/tmp/LuneX-18-8_8-final-audit-r2.Kma7ZH`通过最终7文件authority/tasks、唯一8.8 checkbox、strict `9/9`、`49/50 only 8.7 pending`、脱敏readiness、五级矩阵与repository边界；下一步final-record。
- 2026-08-08：final-record `/tmp/LuneX-18-8_8-final-record.xuo5aN`通过authority、完整retained chain、8.7 not-ready脱敏状态、唯一checkbox、稳定project与repository边界；补入索引后运行r2再提交。
- 2026-08-07：用户完成macOS更新后恢复长期goal；确认goal仍active，`HEAD == origin/main == f51eb0e`，工作树仅含阶段19新OpenSpec目录。
- 2026-08-07：只读复核系统为macOS 27.0/Xcode 26.4，并确认iOS/tvOS/visionOS 26.4与27.0 runtime可用；未创建、启动或改变任何Simulator lifecycle。
- 2026-08-07：阶段19 `complete-native-product-workflows`进入`in_progress`，先生成proposal/spec/design/tasks，再按任务逐项实现与自验收；阶段13–18 live/signed/physical pending边界保持不变。
- 2026-08-07：完成阶段19 proposal、五份ADDED capability specs与design草案；合同覆盖host/pairing、session recovery/overlay、checked multiwindow workspace、accessibility和privacy-bounded diagnostics，明确复用现有runtime owner及五级proof boundary。
- 2026-08-07：生成阶段19 `tasks.md`共48项，按8组覆盖基础、host/pairing/catalog、session、multiwindow、accessibility、diagnostics、集成验证和阶段证明；strict `1/1`与apply `0/48 ready`通过，路线图同步为in_progress，下一步建立独立OpenSpec checkpoint。
- 2026-08-08：task 1.1完成只读产品状态/target/test/proof审计并写入`docs/runtime/native-product-workflow-contract.md`；确认单一全局AppModel产品状态、4 App + 1 macOS unit-test、Swift 6.0、65 workflow/1123 total tests、0 UI-test harness及关键workflow缺口。未运行build/test/Keychain/live host/Simulator lifecycle。
- 2026-08-08：task 1.1首个验收编排因`git diff --name-only`不列未跟踪合同文档而在scope comparison退出；strict通过且无运行时副作用。改用porcelain status纳入untracked文件后fresh重跑。
- 2026-08-08：task 1.1 corrected gate的scope已通过，随后因proof关键句在Markdown跨行而被单行全文断言误判；逐项诊断确认其他边界成立，final gate改用稳定短token和显式marker。
- 2026-08-08：task 1.1 final gate `/tmp/LuneX-19-1_1-audit-final.F3Muuj`通过strict、`1/48`、五文件scope、唯一checkbox、零production/test/project diff、opt-ins unset与无Simulator/build/test边界；准备独立提交推送。
- 2026-08-08：开始task 1.2，新增closed ProductIssue/domain/severity/presentation、checked ProductActionToken/scope及聚焦测试；通过generator纳入所有App与macOS test target，不接线现有UI/runtime。
- 2026-08-08：task 1.2 generator双次hash稳定，focused `ProductIssueTests`为`5/5`；真实Keychain/live-host opt-in均unset，未操作Simulator。Xcode自动外接设备枚举警告不作为设备验收且不保留identity-bearing raw output。
- 2026-08-08：task 1.2 final gate `/tmp/LuneX-19-1_2-product-issue.rXdSpM`通过strict、`2/48`、9文件scope、generator/membership、focused `5/5`与privacy/opt-in边界；准备独立提交推送。
- 2026-08-08：开始task 1.3，收紧HostEndpointParser并新增ManualHostDraft typed validation；补齐normalization、URL/credential/path/query、IP/hostname/port/control-character矩阵，不在本任务改Add Host UI。
- 2026-08-08：task 1.3首个focused wrapper因zsh只读`status`变量在测试后退出；xcresult为`11/1/0`，唯一失败是`[not-ipv6]`被当作hostname接受。修复bracketed IPv6入口并改用`test_exit` fresh重跑，identity-bearing raw log删除。
- 2026-08-08：task 1.3 corrected focused `/tmp/LuneX-19-1_3-focused-r2.Oxw4ZF`为`12/12`；typed draft/parser矩阵通过，raw日志删除。勾选1.3后运行final scope/privacy/OpenSpec gate。
- 2026-08-08：task 1.3 final gate `/tmp/LuneX-19-1_3-host-validation-final.vF8FAE`通过strict、`3/48`、8文件scope、stable project、failure privacy shape、focused `12/12`与proof boundary；准备独立提交推送。
- 2026-08-08：开始task 1.4，新增typed workspace ID/nonzero generation/reference及workspace-local navigation/selection/presentation value state；action token scope迁移为typed reference，不接线registry或AppModel。
- 2026-08-08：task 1.4 focused `/tmp/LuneX-19-1_4-focused.3BlrWl`为`14/14`；raw日志删除，勾选1.4后运行strict/scope/ownership-shape final gate。
- 2026-08-08：task 1.4 final gate `/tmp/LuneX-19-1_4-workspace-values-final.FogMa1`通过strict、`4/48`、8文件scope、typed action/no-runtime-owner、focused `14/14`与proof boundary；准备独立提交推送。
- 2026-08-08：开始task 1.5，新增main-actor observable workspace registry、generation tombstone、checked create/restore/replace/update/reconcile/close与独立测试；不接线AppModel/scene/runtime。
- 2026-08-08：task 1.5 generator双次hash稳定，focused `/tmp/LuneX-19-1_5-focused.Ojn852`为`22/22`；raw日志删除，勾选1.5后运行strict/scope/no-runtime-owner final gate。
- 2026-08-08：task 1.5 final gate `/tmp/LuneX-19-1_5-workspace-registry-final.HLgR72`通过strict、`5/48`、9文件scope、generator/test membership、registry fail-closed/no-owner、focused `22/22`与proof boundary；准备独立提交推送。
- 2026-08-08：开始task 1.6，仅扩充issue/action privacy、endpoint边界、workspace identity/replacement/reconciliation/close adversarial tests；focused通过后运行完整normal suite，预期真实Keychain仍为唯一skip。
- 2026-08-08：task 1.6 focused `/tmp/LuneX-19-1_6-focused.ubhIb2`为`30/30`；normal `/tmp/LuneX-19-1_6-normal.ZIvjnw`为`1150/1149/1 exact Keychain skip/0`，raw日志删除。勾选1.6后运行foundation final gate。
- 2026-08-08：task 1.6 final gate `/tmp/LuneX-19-1_6-foundation-final.TDfp4H`通过strict、`6/48`、8文件scope、no production/project/config diff、adversarial matrix、focused `30/30`与normal `1150/1149/1/0`；准备独立提交推送。
- 2026-08-08：task 2.1首轮focused因test中actor `await`误放XCTest autoclosure而编译退出、0 tests；改为await局部saveCount后断言，清理raw identity-bearing evidence并fresh重跑。
- 2026-08-08：恢复task 2.1，corrected focused `/tmp/LuneX-19-2_1-focused-r2.0XSIyi`确认`37/37`；发现旧bundle及device字段残留后完成补清理，目录现仅保留纯计数JSON。related `/tmp/LuneX-19-2_1-related.HWEDpq`为`102/102`，raw与xcresult均删除。
- 2026-08-08：补充pending host load `isRefreshing`及manual save期间workspace replacement的stale-result adversarial test；fresh focused `/tmp/LuneX-19-2_1-focused-r3.LMQhRz`为`38/38`。
- 2026-08-08：首轮完整normal `/tmp/LuneX-19-2_1-normal.43ml8N`为`1158/1156/1/1`，失败为既有mac drawable geometry时序测试；单独诊断 `/tmp/LuneX-19-2_1-diagnose-input.W5toVj`为`1/1`，下一步运行禁用parallel testing的fresh normal gate。
- 2026-08-08：serial normal `/tmp/LuneX-19-2_1-normal-serial.7iMpFx`测试本体通过`1158/1157/1/0`，wrapper仅因Xcode 27 skip日志格式不匹配退出；精确选择Keychain用例的 `/tmp/LuneX-19-2_1-keychain-skip-proof.nEMMlR`在opt-in unset下为`1 skipped / 0 failed`，确认完整套件唯一skip。两轮raw/xcresult均删除。
- 2026-08-08：task 2.1实现与合同同步完成，勾选OpenSpec至`7/48`；下一步运行generator/strict/scope/final evidence gate后独立提交推送，再进入2.2 Add Host awaited presentation。
- 2026-08-08：final review移除manual add找不到normalized address时选择首个无关host的fallback；final related `/tmp/LuneX-19-2_1-related-final.onnIaL`为`103/103`，final serial normal `/tmp/LuneX-19-2_1-normal-final.OmNZLt`为`1158/1157/1/0`，两个opt-in unset且raw/xcresult均删除。
- 2026-08-08：首个final scope gate仅因generated pbxproj membership精确计数预期3、实际4而退出；诊断确认其余断言通过，修正gate后继续，不重跑已成功测试。
- 2026-08-08：task 2.1 corrected final gate `/tmp/LuneX-19-2_1-final-r2.asqNYj`通过11文件scope、generator稳定SHA-256、strict、`7/48 next 2.2`、related `103/103`、normal `1158/1157/1/0`、exact Keychain skip、opt-in unset及raw/xcresult absent；准备独立提交推送。
- 2026-08-08：task 2.1提交`c039fca Migrate host library state to workspaces`并推送；fetch与ls-remote确认HEAD/origin/main/remote三方一致，工作树clean，进入2.2。
- 2026-08-08：task 2.2将Add Host sheet改为owner workspace draft binding，await typed result，仅success dismiss；failure显示field-safe footer并回焦Address，validating/saving禁用字段/按钮/interactive dismiss，AppModel拒绝duplicate in-flight save。
- 2026-08-08：2.2 focused `/tmp/LuneX-19-2_2-focused.WQaZkZ`为`41/41`，related `/tmp/LuneX-19-2_2-related.Pr0grt`为`106/106`，normal `/tmp/LuneX-19-2_2-normal.5tr9B2`为`1161/1160/1/0`；opt-in unset，raw/xcresult删除。
- 2026-08-08：2.2 unsigned generic Debug builds `/tmp/LuneX-19-2_2-platform-builds.ySNAZ1`的macOS、iOS/iPadOS、tvOS、visionOS均通过；未调用Simulator lifecycle，不构成signed/physical/live proof。勾选OpenSpec至`8/48`，下一项2.3。
- 2026-08-08：task 2.2 final gate `/tmp/LuneX-19-2_2-final.Q47MFp`通过9文件scope、strict、`8/48 next 2.3`、generator no drift、focused/related/normal、4/4 generic Debug build、opt-in unset及raw identity artifacts absent；准备独立提交推送。
- 2026-08-08：恢复task 2.3并接回唯一normal session，确认候选实现为`1170/1169/1/0`且两个opt-in unset；未重复启动xcodebuild，raw/xcresult已删除。
- 2026-08-08：final review将primary `selectedAppID` projection收紧为只读，并新增duplicate snapshot newest-wins与cache load期间workspace replacement stale rejection测试。
- 2026-08-08：首个新增focused wrapper误用`LuneX-macOS` scheme，以exit 66、0 tests结束；通过project scheme元数据定位后改用`LuneXCoreTests` fresh运行，不原样重复错误命令。
- 2026-08-08：corrected focused `/tmp/LuneX-19-2_3-focused-final-r2.qoZFcB`为`44/44`，related `/tmp/LuneX-19-2_3-related-final-r2.P2U0aA`为`117/117`，final serial normal `/tmp/LuneX-19-2_3-normal-final-r2.Q0xvUU`为`1172/1171/1/0`；Keychain/live-host opt-in均unset，raw/xcresult删除。
- 2026-08-08：同步catalog generation ownership合同并勾选2.3至`9/48`；下一步复验generator、strict、四平台generic Debug、scope与最终证据门，再独立提交推送并进入2.4。
- 2026-08-08：static final `/tmp/LuneX-19-2_3-static-final.lRAYqQ`通过generator双次稳定SHA-256、diff check、strict与apply精确`9/48 next 2.4`。
- 2026-08-08：final generic Debug build `/tmp/LuneX-19-2_3-platform-builds-final-r2.hEc7xM`的macOS、iOS/iPadOS、tvOS、visionOS均通过；signing disabled、两个opt-in unset、未调用Simulator lifecycle，raw log和临时DerivedData删除。
- 2026-08-08：task 2.3 final audit `/tmp/LuneX-19-2_3-final-audit.4wCcwh`通过精确11文件scope、diff check、strict/apply `9/48 next 2.4`、stable generator、focused/related/normal、4/4 generic Debug及artifact/opt-in/process/proof边界；准备final-record与独立提交推送。
- 2026-08-08：task 2.3以`5ce492c Bind app catalog to workspace generations`提交推送，fetch与ls-remote确认HEAD/origin/main/remote三方一致且工作树clean；OpenSpec进入`9/48 next 2.4`。
- 2026-08-08：开始task 2.4，审计现有global PairingUIState、identity preparation、provider stream、PIN/cancel/retry UI与late-event tests；确定复用单一provider，以workspace+host-selection+attempt generation作为checked product owner。
- 2026-08-08：2.4首轮focused `/tmp/LuneX-19-2_4-focused.zS6AM7`为`6 total / 5 passed / 1 failed`；唯一失败是测试误要求无默认action的`pairingCancelled` issue携带action scope，production已编译且其余owner/retry/replacement测试通过。修正为terminal state owner + nil action后fresh重跑，不原样重复。
- 2026-08-08：2.4 corrected focused `/tmp/LuneX-19-2_4-focused-r2.X9h9Nm`为`6/6`；final review随后把global pairing projection收紧为read-only、PIN统一走checked API，并在无效begin前增加workspace/host预校验。
- 2026-08-08：expanded focused `/tmp/LuneX-19-2_4-focused-r3.KwsLsn`为`71/71`，related `/tmp/LuneX-19-2_4-related.XTst2Q`为`135/135`，serial normal `/tmp/LuneX-19-2_4-normal.LWChiM`为`1178/1177/1/0`；唯一skip是opt-in unset真实Keychain测试。
- 2026-08-08：2.4 final generic Debug build `/tmp/LuneX-19-2_4-platform-builds.CeubCP`四application target `4/4`通过，signing disabled、未调用Simulator lifecycle；raw logs与临时DerivedData删除。
- 2026-08-08：static pre-mark `/tmp/LuneX-19-2_4-static-pre.rPZV4d`通过generator双次稳定SHA-256、diff check、strict与OpenSpec精确`9/48 next 2.4`；同步合同后仅勾选2.4至`10/48`，下一项2.5。
- 2026-08-08：task 2.4 final audit `/tmp/LuneX-19-2_4-final-audit.8zFRm5`通过精确12文件scope、diff check、strict/apply `10/48 next 2.5`、stable generator、focused/related/normal、4/4 generic Debug及artifact/opt-in/process/proof边界；准备final-record与独立提交推送。
- 2026-08-08：task 2.4以`fe83a85 Bind pairing attempts to workspace owners`提交推送，fetch与ls-remote确认HEAD/origin/main/remote三方一致且工作树clean；OpenSpec进入`10/48 next 2.5`。
- 2026-08-08：开始task 2.5，审计现有immediate remove、HostLibraryManager replace/remove、catalog snapshot repository和stopStream；确定以checked host-action owner + explicit confirmation + clean-stop-before-mutation实现remove/trust reset。
- 2026-08-08：系统更新后恢复2.5，确认`HEAD == origin/main == fe83a85`、长期goal active、OpenSpec `10/48 next 2.5`、macOS 27.0/Xcode 26.4和四文件候选diff完整；未触发Keychain、live host或Simulator lifecycle。
- 2026-08-08：首轮warnings-as-errors build-for-testing `/tmp/LuneX-19-2_5-compile.9GHhKz`在0 tests时只报`AppModel.swift`成功回写误用未定义`workspace`；改为confirmation携带的checked workspace，并把missing-host从无关pairing error拆成内部host-destructive error，下一轮使用fresh evidence而不复用失败bundle。
- 2026-08-08：第二轮compile `/tmp/LuneX-19-2_5-compile-r2.LGMg0w`已通过production，随后在0 tests时精确报4处旧测试仍构造`.removeHost(hostID:)`；更新为完整`ProductHostDestructiveConfirmation`及workspace/host-selection owner，保持presentation/replacement断言语义。
- 2026-08-08：第三轮compile `/tmp/LuneX-19-2_5-compile-r3.hbwTTC`只剩Xcode 26.4 warnings-as-errors将未修改的测试局部`var second`诊断为错误；改为`let`，production与typed dialog签名已无诊断。
- 2026-08-08：final compile `/tmp/LuneX-19-2_5-compile-final.o4XNPt`成功；Swift/Clang warnings-as-errors通过，唯一文本warning为测试bundle无AppIntents依赖时metadata工具的预期skip，不是源码诊断。
- 2026-08-08：2.5并发审计发现performing可被重复request/cancel覆盖、无stop consent会先取消pairing、repository await边界缺少owner复验；首次组合补丁因现有字段类型/位置锚点不匹配被`apply_patch`原子拒绝且无部分写入，随后按精确片段拆分完成single-operation admission、目标launch/pairing阻断、await后复验与best-effort rollback。
- 2026-08-08：新增`ProductHostDestructiveWorkspaceTests.swift`的12项确定性矩阵并经权威Ruby生成器纳入pbxproj；首轮tests compile `/tmp/LuneX-19-2_5-tests-compile.awrl6q`仅报3处XCTest autoclosure内直接`await`，0 tests executed。改为先await局部值再断言，production与测试替身无其他编译诊断。
- 2026-08-08：corrected tests compile `/tmp/LuneX-19-2_5-tests-compile-r2.AcsTnw`成功。首轮focused `/tmp/LuneX-19-2_5-focused.ph7OwH`为`12 total / 11 passed / 1 failed`；唯一失败是测试误要求第二次retry再次返回confirmation，实际首次retry已进入awaiting、第二次按幂等合同返回nil且不创建新操作。修正为断言nil及原state不变，production无需修改。
- 2026-08-08：fresh corrected focused `/tmp/LuneX-19-2_5-focused-r2.JG3oGI`通过`12/12`、0 failed/skip/expected failure；显式unset Keychain/live-host opt-in，覆盖确认/取消、target-only remove、trust reset、cache rollback、stale/non-owner、late session、stop/pairing teardown ordering与幂等。
- 2026-08-08：related `/tmp/LuneX-19-2_5-related.SVlXIR`通过`127/127`、0 failed/skip/expected failure，覆盖全部product workspace/host/catalog/pairing/destructive与AppModel workflow；macOS 27日志中的`linkd.autoShortcut`连接失败为系统服务噪声，结构化测试无失败。
- 2026-08-08：serial normal `/tmp/LuneX-19-2_5-normal.AopzR5`通过`1190 total / 1189 passed / 1 skipped / 0 failed / 0 expected failure`；唯一skip精确为opt-in unset真实Keychain测试，live-host opt-in同样unset。
- 2026-08-08：四平台unsigned generic Debug `/tmp/LuneX-19-2_5-platform-builds.EzxuT3`的macOS、iOS/iPadOS、tvOS、visionOS均`succeeded`，每份structured errors/warnings/analyzer warnings全零；未查询/创建/启动Simulator，不构成signed/physical/live proof。
- 2026-08-08：同步host destructive workflow合同、best-effort非原子rollback与3.1 session-workspace边界；勾选2.5至`11/48`，下一项2.6 host/pairing/catalog surface recomposition。
- 2026-08-08：final UI eligibility审读发现`.staleAction`无retry token但Host panel仍无条件显示Retry；改为仅`issue.action != nil`时显示，避免呈现必然被checked API拒绝的命令，并补source contract后重跑最终门。
- 2026-08-08：最终代码focused `/tmp/LuneX-19-2_5-focused-final.ZiO7rc`为`12/12`；serial normal `/tmp/LuneX-19-2_5-normal-final.wJz01Y`为`1190/1189/1/0`且唯一skip仍为opt-in unset真实Keychain。
- 2026-08-08：最终build wrapper在macOS成功后因再次使用zsh只读变量`status`退出；read-only确认macOS structured success后改用`build_state`只补跑其余三平台，不重复macOS。最终 `/private/tmp/LuneX-19-2_5-platform-builds-final.MdqHEC` 四平台均`succeeded/0 errors/0 warnings/0 analyzer warnings`，Simulator lifecycle未调用。
- 2026-08-08：首个UI eligibility组合`apply_patch`因多余hunk header被原子拒绝且无文件变化，改用合法单hunk补丁完成。首个artifact cleanup循环误用zsh特殊参数`path`覆盖`PATH`而未删除任何目录；改用`artifact_dir`和绝对命令后精确清除全部`/private/tmp/LuneX-19-2_5-*`，remaining 0、active xcodebuild 0。
- 2026-08-08：仓库内仍有7个`build/`下的既有DerivedData/xcresult，时间与路径属于7月10/21的历史验证而非2.5；按不删除既有产物边界保留。本轮raw logs、xcresult和临时DerivedData已全部删除。
- 2026-08-08：task 2.5 final audit通过精确13文件scope、diff check、OpenSpec strict/apply `11/48 next 2.6`、generator双跑稳定SHA-256 `6857df90a77d0ce008c940051fe15731998ad9966cfc4cb969d6b55e1755d6a8`、最终focused/normal、四平台generic Debug、typed teardown/rollback/UI eligibility及privacy/artifact/process边界；准备独立提交推送。
- 2026-08-08：系统更新后恢复阶段19 task 2.6；确认goal active、`HEAD == origin/main == 23ac6a2`、工作树clean、macOS 27.0/Xcode 26.4及OpenSpec `11/48 next 2.6`，未调用Keychain/live host/Simulator lifecycle。
- 2026-08-08：2.6首轮warnings-as-errors compile `/private/tmp/LuneX-19-2_6-compile.6K3FgB`在0 tests前仅报`ProductWorkflowSurface.swift`将switch expression直接置于`&&`右侧；拆为局部布尔值后使用fresh DerivedData重跑，失败raw log与DerivedData删除。
- 2026-08-08：corrected warnings-as-errors compile `/private/tmp/LuneX-19-2_6-compile-r2.9bWFwC`成功，唯一文本warning为无AppIntents依赖时metadata extraction预期skip；首轮focused surface/host/catalog为`30/30`。状态复核后补Host/Pairing/Catalog无typed issue时的fail-closed稳定占位，再重跑同一门。
- 2026-08-08：2.6最终warnings-as-errors增量compile通过；focused surface/host/catalog为`30/30`，related product/workspace/AppModel为`135/135`，serial normal为`1198/1197/1/0`。唯一skip精确为opt-in unset真实Keychain round-trip，live-host opt-in同样unset；系统`linkd`/CoreData XPC文本不改变结构化0 failure结果。
- 2026-08-08：2.6最终四平台unsigned generic Debug `/private/tmp/LuneX-19-2_6-platform-builds.E0GuY9`为macOS、iOS/iPadOS、tvOS、visionOS `4/4`成功；warnings-as-errors无源码诊断，唯一文本warning均为无AppIntents依赖的metadata skip。未调用Simulator lifecycle，不证明signed/physical/live行为。
- 2026-08-08：同步native workflow contract与planning，勾选OpenSpec 2.6至`12/48 next 2.7`；下一步运行strict、generator stability、精确scope/privacy/artifact/process final gate后独立提交推送。
- 2026-08-08：首轮final audit `/private/tmp/LuneX-19-2_6-final-audit.lS7Mv6`通过strict、`12/48 next 2.7`、13文件scope、stable generator、focused/related/normal和4/4 build；随后最终源码审读发现Catalog retry还应显式要求current phase为failed，补production/surface/adversarial test后重新运行最终证据，不复用该audit作为最终验收。
- 2026-08-08：Catalog retry final收紧后，fresh `/private/tmp/LuneX-19-2_6-final-verification.dSaXJR`再次通过warnings-as-errors、focused `30/30`、related `135/135`、serial normal `1198/1197/1/0`；fresh `/private/tmp/LuneX-19-2_6-platform-builds-final.OOUc0K`四平台generic Debug `4/4`成功。下一步final audit r2与raw identity-bearing artifact清理。
- 2026-08-08：task 2.6 final audit r2 `/private/tmp/LuneX-19-2_6-final-audit-r2.eAKjE9`通过最终13文件scope、diff check、strict/apply `12/48 next 2.7`、generator双跑稳定SHA-256 `60e6966fc42bbe0facbb8adfdf66794746948039ba1f190ac13dc0438a9d2224`、最终测试/四平台build、Catalog failed-phase admission及opt-in/process/proof边界；下一步清理全部本轮raw evidence并运行final record。
- 2026-08-08：首次raw cleanup因工具策略在执行前拒绝`rm -rf`而未删除任何目录；改用精确限定`/private/tmp/LuneX-19-2_6-*`的`find -depth -delete`，不触碰仓库内历史build产物。
- 2026-08-08：task 2.6 cleanup后final record通过最终13文件、strict/apply `12/48 next 2.7`、稳定project SHA-256、raw artifact 0、opt-in unset及无xcodebuild/xctest残留；准备精确stage、独立commit/push/fetch对齐。
- 2026-08-08：task 2.6以`7bbb1a9 Recompose native workflow surfaces`提交推送，fetch与ls-remote确认HEAD/origin/main/remote三方一致且工作树clean；OpenSpec进入`12/48 next 2.7`。
- 2026-08-08：开始task 2.7，审计现有Host/Catalog/Pairing/Destructive/AppModel测试后新增四条跨状态application workflow，覆盖要求中的八类行为；仅修改测试与planning，下一步warnings-as-errors compile与focused验收。
- 2026-08-08：2.7 warnings-as-errors compile `/private/tmp/LuneX-19-2_7-compile.aLQkF0`成功；首轮focused为`4 total / 3 passed / 1 failed`，唯一失败是测试误要求identity preparation失败也调用尚未启动的provider cancellation。改为断言不取消未启动provider，production无需修改，删除失败bundle后fresh重跑。
- 2026-08-08：2.7 corrected focused为`4/4`，related Product/AppModel为`139/139`，serial normal为`1202/1201/1/0`；唯一skip精确为opt-in unset真实Keychain，live-host opt-in同样unset。同步application matrix合同并勾选2.7至`13/48 next 3.1`。
- 2026-08-08：2.7四平台unsigned generic Debug `/private/tmp/LuneX-19-2_7-platform-builds.BzEjDZ`为macOS、iOS/iPadOS、tvOS、visionOS `4/4`成功；无源码warning/error，未调用Simulator lifecycle。下一步strict/generator/test-only scope/proof final gate。
- 2026-08-08：首轮2.7 final audit `/private/tmp/LuneX-19-2_7-final-audit.tYseFx`在production/scope/OpenSpec/generator后因`rg -c`零个removed tests返回空字符串而退出；只读诊断确认其余test/build证据完整。corrected gate用`wc -l`规范化零计数，不重复test/build。
- 2026-08-08：corrected task 2.7 final audit `/private/tmp/LuneX-19-2_7-final-audit-r2.ifVIFd`通过9文件scope、production/project/config零diff、strict/apply `13/48 next 3.1`、stable generator、focused/related/normal、4/4 build及opt-in/process/proof边界；下一步清理raw evidence并final record。
- 2026-08-08：task 2.7 raw evidence清理后final record确认9文件test/authority scope、production diff 0、strict `13/48 next 3.1`、project hash稳定、raw artifact 0及无xcodebuild/xctest残留；准备独立提交推送。
- 2026-08-08：macOS更新完成后恢复阶段19 task 3.1；确认长期goal仍为active、OpenSpec `complete-native-product-workflows`为`13/48 next 3.1`，工作树仅有`AppModel.swift`、`ProductWorkflowState.swift`和`AppModelWorkflowTests.swift`的owner实现检查点。当前先完成代码审读、权威文档同步与fresh验收；不重复真实Keychain/live-host测试，也不创建或启动Simulator。
- 2026-08-08：3.1代码审读发现workspace replacement后若控制流沉默而只有media event到达，旧实现只丢弃event但不收敛仍占用的session；`failFromMediaEnvironment`首个await期间owner失效也会直接返回。新增active reservation与current workspace两层检查，media-only stale检测和media failure await后失效均走checked internal teardown，并补一条media-only replacement回归；未引入3.2 command reducer或3.4并发stop合同。
- 2026-08-08：3.1 fresh warnings-as-errors focused通过`5/5`：primary compatibility owner、explicit owner/non-owner stop、workspace replacement control cleanup、workspace replacement media-only cleanup、remote termination/media release；唯一文本warning为无AppIntents依赖时metadata extraction预期skip。证据位于临时`/tmp/LuneX-19-3_1-focused`，最终验收后定向清理。
- 2026-08-08：3.1 related回归以warnings-as-errors和serial执行通过`143/143`、0 failure/skip，覆盖`AppModelWorkflowTests`、`ProductHostDestructiveWorkspaceTests`、`SessionMediaEnvironmentTests`、`SessionCancellationTests`。同步native product workflow合同，明确reservation/current workspace两层owner、prepare前占位、host/app selection generation复验、non-owner/replacement拒绝、control/media stale cleanup及3.2/3.4/4.4边界。
- 2026-08-08：3.1 serial normal在`LUNEX_RUN_KEYCHAIN_TEST`与`LUNEX_RUN_LIVE_HOST_TEST`均unset时通过`1207 total / 1206 passed / 1 skipped / 0 failed`；唯一skip精确为`testRealKeychainIdentityRoundTripWhenExplicitlyEnabled`，未再次访问真实Keychain，普通测试继续使用Debug文件fallback。
- 2026-08-08：3.1权威生成器双跑稳定，`LuneX.xcodeproj/project.pbxproj`两次SHA-256均为`60e6966fc42bbe0facbb8adfdf66794746948039ba1f190ac13dc0438a9d2224`且project无diff。四平台unsigned generic Debug build为macOS、iOS/iPadOS、tvOS、visionOS `4/4`成功；未调用Simulator lifecycle，不构成signed、physical、assistive-technology或live Sunshine证明。
- 2026-08-08：完成3.1实现、合同与计划同步并勾选OpenSpec至`14/48 next 3.2`；下一步运行strict OpenSpec、最终scope/privacy/artifact/process审计、定向清理临时证据，再独立commit/push/fetch确认远端对齐。
- 2026-08-08：3.1 strict OpenSpec validation通过`1/1`且apply精确报告`14/48 next 3.2`；`git diff --check`通过，生成器后project保持零diff。下一步清理本任务raw logs/xcresult/DerivedData并完成final record。
- 2026-08-08：3.1 cleanup后final record通过：精确8文件scope，owner/session set与5处clear均成对，task diff仅3.1一行checkbox，project/config/reference/dependency零diff，privacy扫描无真实PIN/endpoint/key/certificate/device identity，临时artifact 0，两个opt-in unset，active xcodebuild/xctest 0。准备独立commit/push/fetch对齐后进入3.2。
- 2026-08-08：task 3.1以`e91b755 Bind stream sessions to workspace owners`提交推送，fetch与`git ls-remote`确认HEAD/origin/main/remote三方一致且工作树clean；OpenSpec进入`14/48 next 3.2`。
- 2026-08-08：开始3.2审计，确认底层有`StreamSessionSnapshot.stage/reconnectAttempt/terminationReason/failure`及provider inventory，但产品层仍由`StreamLaunchUIState`与`StreamingPhase`零散字符串/布尔值表达，缺少launch/reconnect/resume/stop的穷举actual-state reducer。范围限定为纯值command state及AppModel投影，不提前实现3.3 typed actions、3.4并发幂等协调或3.5 overlay接线。
- 2026-08-08：3.2首个production组合`apply_patch`因`AppModel`字段锚点不完全匹配被原子拒绝，无部分production/test修改；改为按Product state、surface reducer、AppModel投影与transition逐文件拆分。当前候选新增idle/launching/waiting/streaming/reconnecting/stopping/remote-terminated/reconnect-exhausted/failed actual phase，四命令available/in-progress/closed-reason disposition及owner/provider/selection fail-closed矩阵。
- 2026-08-08：3.2 warnings-as-errors compile通过。首轮focused为`14 total / 13 passed / 1 failed`，纯reducer `11/11`与owner/reconnect-exhaustion application均通过；唯一失败定位为remote-termination origin参数误加在reconnecting分支，导致terminated默认归约为idle。修正两个精确调用点后用fresh evidence重跑，不复用失败bundle。
- 2026-08-08：系统更新后恢复3.2，确认`HEAD == origin/main == e91b755`、OpenSpec `14/48 next 3.2`、长期goal active，环境为macOS 27.0/Xcode 26.4/Swift 6.3；未发现交接范围外修改。人工审读确认launch投影使用完整actual provider inventory，stop只要求session-control provider，workspace/owner/reservation不一致均fail closed，terminal分类仅对typed reconnect exhaustion特殊化。
- 2026-08-08：在既有每类required stream provider缺失测试中增加AppModel command-state投影断言，不扩张到3.7完整provider-absence矩阵。fresh warnings-as-errors focused `/tmp/LuneX-19-3_2-focused-final.T2VINr`结构化通过`16/16`、0 skip/failure，覆盖11项surface/reducer、4项owner/terminal/stopping应用路径和1项actual inventory投影；唯一源码外文本warning为无AppIntents依赖的metadata skip。Xcode枚举锁定物理设备产生的临时身份文本将在final gate后随artifact定向删除，未操作设备或Simulator。
- 2026-08-08：复用同一fresh build串行通过related五簇`157/157`及normal `1214 total / 1213 passed / 1 skipped / 0 failed`；唯一skip精确为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，Keychain/live-host opt-in均unset。normal bundle首次并行结构化读取触发SQLite reader conflict，测试未受影响；改为串行读回同一bundle成功，未重跑suite。
- 2026-08-08：final四平台unsigned generic Debug `/tmp/LuneX-19-3_2-platform-builds-final.QwnahS`顺序通过macOS universal、iOS/iPadOS、tvOS、visionOS `4/4`；每份xcresult均`succeeded/0 errors/0 warnings/0 analyzer warnings`且日志各一次`BUILD SUCCEEDED`。只使用generic destination，未操作Simulator；Xcode自动枚举的物理设备身份文本将在final gate后随临时artifact定向删除。
- 2026-08-08：同步native product workflow contract、completion roadmap、findings与planning，记录actual phase、四命令reducer、workspace/owner/provider/selection admission、terminal分类、unowned stopping及3.3/3.4/3.5/4.4边界。OpenSpec仍保持pre-mark `14/48 next 3.2`，下一步运行generator/strict/scope/privacy/process/artifact repository pre-gate。
- 2026-08-08：3.2 repository pre-gate通过protocol fixture self/full、OpenSpec strict `1/1`与pre-mark `14/48 next 3.2`、generator双次稳定SHA-256 `60e6966fc42bbe0facbb8adfdf66794746948039ba1f190ac13dc0438a9d2224`、精确10文件scope、0 untracked、project/config/vendor/reference零diff、privacy零命中、opt-in unset、无活动xcodebuild/xctest。已只勾选3.2并同步为预期`15/48 next 3.3`；下一步只读final-state，不重复tests/builds/generator或Simulator操作。
- 2026-08-08：3.2只读final-state确认OpenSpec `15/48 next 3.3`、strict `1/1`、精确11文件scope、仅3.2 checkbox变化及project hash稳定；retained focused/related/normal与四平台xcresult串行读回保持`16/16`、`157/157`、`1214/1213/1/0`和`4/4`。随后用逐路径`find -depth -delete`清理全部成功/失败raw evidence、DerivedData、xcresult及身份枚举日志，最终task artifact 0、active xcodebuild/xctest 0、opt-in unset。准备独立commit/push/fetch远端对齐后进入3.3。
- 2026-08-08：task 3.2以`1eef386 Model actual session command state`独立提交并推送；fetch后本地HEAD、`origin/main`与`git ls-remote origin refs/heads/main`三方均为`1eef386ebe9c21aa97ec324ecfcf6b2c9a3df844`，工作树clean。开始3.3，范围限定为launch/recovery的typed product issue与checked action invocation-time workspace/session ownership revalidation；不提前实现3.4并发幂等协调、3.5 overlay、3.7完整应用矩阵或6.x全局字符串迁移。
- 2026-08-08：3.3 production候选移除`StreamLaunchUIState.errorMessage/actionMessage`，将selection/provider/reconnecting/remote-terminated/reconnect-exhausted及stream failure映射为owning workspace中的closed `ProductIssue`。checked dispatcher要求当前workspace generation、当前展示的同一token、active或terminal session identity及3.2 command disposition同时成立；旧session token replay与replaced workspace均fail closed为`staleAction`，未引入3.4共享in-flight结果。
- 2026-08-08：3.3 fresh warnings-as-errors focused `/private/tmp/LuneX-19-3_3-focused.5JNvFD`通过`30/30`、0 skip/failure，覆盖ProductIssue/action title与无自由文本shape、RootView typed invocation、provider/selection/failure映射、local clear、remote termination relaunch、旧session token replay拒绝及workspace generation replacement拒绝。唯一源码外warning是无AppIntents依赖的metadata skip；Keychain/live-host opt-in unset，未操作Simulator。
- 2026-08-08：复用同一fresh build缓存顺序通过3.3 related五簇`139/139`与normal `1216 total / 1215 passed / 1 skipped / 0 failed`；唯一skip精确为`testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，normal日志0 warning/error，两个opt-in均unset。
- 2026-08-08：3.3四平台unsigned generic Debug `/private/tmp/LuneX-19-3_3-platform-builds.fzTsOq`顺序通过macOS universal、iOS/iPadOS、tvOS、visionOS `4/4`，四份structured result均`succeeded/0 errors/0 warnings/0 analyzer warnings`。只使用generic destination，未操作Simulator，不能代表signed/physical/live证明。
- 2026-08-08：production审读发现selection-required issue仍位于已有host/app分支内，缺少selection时不可见；将typed issue/action提升到launch panel公共区域，并补`chooseHostAndApp` checked workspace action回归。UI修正后focused `14/14`及四平台增量generic Debug `4/4`再次通过且均0结构化诊断；未重复已通过normal suite。
- 2026-08-08：同步native product workflow contract、completion roadmap、findings与task plan，记录workspace/session issue scope、exact displayed-token admission、active/terminal identity、command reducer、old-token replay、typed rejection及3.4/3.5/3.6/4.4/6.x边界。OpenSpec保持pre-mark `15/48 next 3.3`，进入repository pre-gate。
- 2026-08-08：pre-gate人工审读补强selection staleness：`selectedAppID`变化清除session-domain issue，host变化经既有app清除路径同样失效旧terminal token；unrelated issue不受影响。session-scoped `chooseHostAndApp`仅允许导航Library。补强后focused `12/12`与四平台incremental generic Debug `4/4`通过，四份structured result继续为`succeeded/0/0/0`。
- 2026-08-08：由于selection invalidation修改共享`ProductWorkspaceState` production，追加当前最终源码normal而不沿用补强前结果；fresh `NormalFinal.xcresult`通过`1218 total / 1217 passed / 1 skipped / 0 failed`，唯一skip仍为显式禁用的real-Keychain round trip，日志0 warning/error。
- 2026-08-08：3.3 final pre-mark repository gate `/private/tmp/LuneX-19-3_3-repository-final-pre.JeI8wN`通过fixture self/tree、OpenSpec strict `1/1`与`15/48 next 3.3`、generator双次稳定SHA-256 `60e6966fc42bbe0facbb8adfdf66794746948039ba1f190ac13dc0438a9d2224`、精确11文件scope、0 untracked、project/config/vendor/reference零diff、privacy零命中、opt-in unset、无活动xcodebuild/xctest，并读回最终normal `1218/1217/1/0`与四平台build `4/4`。现只勾选3.3并同步预期`16/48 next 3.4`。
- 2026-08-08：3.3 post-mark final-state确认OpenSpec `16/48 next 3.4`、strict `1/1`、精确12文件scope、仅3.3 checkbox变化、project SHA-256稳定及无活动xcodebuild/xctest。随后用逐路径`find -depth -delete`清除focused/normal/platform/generator/repository raw evidence、DerivedData与xcresult，`find /private/tmp -maxdepth 1 -name 'LuneX-19-3_3-*'`确认task artifact 0；准备独立commit/push/fetch后进入3.4。
- 2026-08-08：task 3.3以`81814d5 Add checked session recovery actions`独立提交并推送；fetch后本地HEAD、`origin/main`与`git ls-remote origin refs/heads/main`三方均为`81814d5cd2d9f68a076cc3bd294354b6fcbb7ed6`，工作树clean。开始3.4，审计cancel/retry/reconnect/repeated-stop在overlay、window close、scene transition和replacement completion路径的幂等ownership/result合同。
- 2026-08-08：3.4新增MainActor owner-keyed共享stop operation：同一session的exact checked action与direct/window/scene-style caller加入同一task/result，teardown期间阻止replacement launch，replaced/non-owner/post-completion调用fail closed；remote/media terminal路径不与已接管的local stop重复清理。fresh warnings-as-errors focused `/private/tmp/LuneX-19-3_4-focused.hifT6L`通过`2/2`，media/control各一次stop且旧teardown完成后replacement session可正常建立。Keychain/live-host opt-in均unset，未操作Simulator lifecycle；Xcode自动枚举的locked physical device身份raw evidence将在final gate后定向删除。
- 2026-08-08：3.4补强pairing/catalog/reconnect/destructive幂等矩阵：pairing重复cancel只产生一次provider cancellation、identity-await中的第二retry拒绝且replacement late completion不发布，catalog loading中的第二retry拒绝且只发一个current-owner请求，terminal reconnect旧token不创建第二session，host destructive duplicate保持单次mutation。expanded warnings-as-errors `/private/tmp/LuneX-19-3_4-expanded.2xWW6l`结构化通过`7/7`、0 skip/failure。
- 2026-08-08：系统更新后恢复3.4并串行读回保留normal：`1221 total / 1220 passed / 1 skipped / 0 failed`，唯一skip精确为显式opt-in真实Keychain round-trip。最终源码审读把checked stop action的visible issue清理由dispatcher移到已注册共享operation的task内，消除依赖MainActor调用调度的pre-registration间隔；因此将以修改后源码重跑focused/related/normal，不沿用修改前normal作最终证据。
- 2026-08-08：最终源码fresh warnings-as-errors focused `/private/tmp/LuneX-19-3_4-final-focused`通过`7/7`，八簇related `/private/tmp/LuneX-19-3_4-final-related`通过`192/192`；串行normal `/private/tmp/LuneX-19-3_4-final-normal`通过`1221 total / 1220 passed / 1 skipped / 0 failed`。唯一skip精确为真实Keychain opt-in测试，两个真实opt-in均unset；未操作Simulator，Xcode自动枚举物理设备产生的raw身份文本将在final gate后随artifact定向删除。
- 2026-08-08：3.4最终四平台warnings-as-errors unsigned generic Debug `/private/tmp/LuneX-19-3_4-final-platform-builds`顺序完成；macOS universal、iOS/iPadOS、tvOS、visionOS均为`succeeded / 0 error / 0 warning / 0 analyzer warning`且日志各一次`BUILD SUCCEEDED`，macOS二进制含`x86_64 arm64`。仅使用generic destination，未操作Simulator，不构成signed/physical/live证明。
- 2026-08-08：首个build收尾脚本已读出四项零diagnostic与四个成功marker，但把实际`LuneX-macOS.app/LuneX-macOS`误写为`LuneX.app/LuneX`，仅`lipo`路径检查退出；构建本身不受影响。改读实际产物路径后校验universal archs成功，未重复四平台build。
- 2026-08-08：3.4 repository pre-gate `/private/tmp/LuneX-19-3_4-final-repository-pre`一次通过fixture self/tree、OpenSpec strict与pre-mark `16/48 next 3.4`、generator双跑稳定、精确8文件scope、0 untracked、project/config/vendor/reference零diff、privacy零命中、两个opt-in unset及无活动xcodebuild/xctest。现只勾选3.4并同步task plan，预期`17/48 next 3.5`。
- 2026-08-08：3.4 post-mark final-state只读通过OpenSpec strict、`17/48 next 3.5`、最终精确10文件scope、唯一3.4 checkbox、稳定project SHA-256、retained focused/related/normal `7/192/1221`与四平台build `4/4`，两个opt-in unset且无活动构建/测试进程；未重复tests/builds/generator或操作Simulator。下一步定向清理全部3.4 raw evidence后运行final record。
- 2026-08-08：3.4 raw evidence已用九个明确路径逐项`find -depth -delete`清理，artifact count为0。首个cleanup final-record在strict/OpenSpec后因finding断言写成小写`final-source`而实际标题为大写`Final-source`退出；只读诊断确认10文件scope、0 untracked/drift/artifact、project hash、证据索引、opt-in和process均正常。修正大小写后重跑final record，不重复其他门。
- 2026-08-08：第二次cleanup final-record通过前置门后，focused/normal索引正则错误要求同一记录行重复包含`3.4`前缀而退出；实际最终记录以“最终源码fresh”开头且计数完整。改用该稳定前缀进行第三次检查，未修改production/test/OpenSpec或重跑任何验收。
- 2026-08-08：第三次cleanup final-record通过OpenSpec strict、`17/48 next 3.5`、最终10文件scope、0 untracked/drift/raw artifact、稳定project、最终测试/build索引、两个opt-in unset及无活动xcodebuild/xctest。Task 3.4准备精确stage、独立commit/push/fetch后立即进入3.5。
- 2026-08-18：恢复阶段19 task 3.5；确认`HEAD == origin/main == c74b4f0adfcff13d76a3937cfd9fec5379bb2403`、工作树clean、OpenSpec `17/48 next 3.5`，两个真实opt-in unset且未操作Simulator。session catchup仅发现对话未同步记录，没有代码漂移。
- 2026-08-18：按用户此前“重新创建目标”及本轮“继续下一步”调用`create_goal`，接口因旧unfinished blocked goal存在而拒绝且无resume操作；已将其限定为目标跟踪异常，继续3.5实现。发现另一个workspace的TamaSwift watchOS build正在运行，保持完全不干预且不计入LuneX进程证据。
- 2026-08-18：完整读取`complete-native-product-workflows` proposal/design/tasks与5份spec。3.5要求overlay/local command只改变owning workspace presentation、stop confirmation加入3.4共享teardown、non-owner/replaced generation fail closed、system-reserved command不进入remote serialization；3.6布局、3.7完整矩阵、4.4窗口关闭和5.x无障碍收尾继续保持边界。
- 2026-08-18：初步源码审计确认workspace已有`presentation.streamOverlay`，但AppModel/RootView仍以全局`tvStreamOverlayVisible`接线；现有tvOS/visionOS focus handoff、capture ownership与reserved-command合同可直接复用。下一步读取精确AppModel/RootView/reducer/test区域并设计最小owner-scoped API与stop confirmation状态。
- 2026-08-18：精读AppModel/RootView/Mac input后确认macOS和visionOS远端input admission均未检查workspace overlay；`ProductWorkspaceDialog.stopStream`尚未接API/UI。确定3.5最小合同为owner-scoped overlay getter/mutation、overlay参与macOS/visionOS input eligibility、tvOS现有release/fresh-focus链路接workspace状态、Escape/remote reserved command只触发local overlay、stop confirmation cancel/confirm严格重验workspace+session并复用3.4 stop operation。
- 2026-08-18：首个五区域AppModel组合补丁因`applyInputLifecycle`锚点不精确被原子拒绝，确认无部分修改；已重新读取精确区域，后续拆为tv restore、runtime begin、mac admission、vision eligibility和navigation五个小补丁。
- 2026-08-18：完成首轮AppModel/RootView production接线；diff check通过。历史命令搜索因zsh `Makefile*`无匹配退出，generator `--help`实际生成工程；核对project仍无diff且SHA-256为稳定`60e6966fc42bbe0facbb8adfdf66794746948039ba1f190ac13dc0438a9d2224`。已给SwiftUI action中的Bool返回显式`_ =`，下一步macOS warnings-as-errors compile。
- 2026-08-18：macOS warnings-as-errors `compile-1`失败，日志精确仅1个源码错误：workspace overload的tvOS surface press结果缺`return`。已精确修复，不复用失败DerivedData；下一步fresh compile-2。
- 2026-08-18：fresh macOS warnings-as-errors `/private/tmp/LuneX-19-3_5-compile-2`通过，generic macOS Debug unsigned构建产出`arm64 + x86_64`；唯一日志warning为既有AppIntents metadata extraction skip。现进入3.5 focused行为测试，不将失败的compile-1或成功compile-2误作行为验收。
- 2026-08-18：首次focused命令误用无test action的`LuneX-macOS` scheme，在源码编译前exit 66；`xcodebuild -list -json`确认应使用`LuneXCoreTests`。已记录为命令编排错误，下一轮使用fresh evidence且不重复错误scheme。
- 2026-08-18：focused-2 warnings-as-errors编译通过，owner overlay、remote cleanup、confirmation并发、tvOS reserved command、RootView contract等6项通过；唯一vision长流程因新增Escape release改变后续固定计数而失败。已拆出独立vision Escape回归，失败bundle不作通过证据，下一步fresh focused-3。
- 2026-08-18：fresh warnings-as-errors focused-3结构化通过`8/8`、0 skip/failure；owner/non-owner/replacement、mac focus、terminal cleanup、stop confirmation共享teardown、tvOS/visionOS reserved command与RootView contract均通过。下一步运行related ownership/input/presentation suites。
- 2026-08-18：related八簇warnings-as-errors回归结构化通过`219/219`、0 skip/failure，既有generation、focus/release barrier、input adapter、control presentation及destructive stop合同未回归。下一步fresh serial normal，继续unset真实Keychain/live-host opt-in。
- 2026-08-18：fresh serial normal结构化通过`1224/1223/1/0`；唯一skip精确为显式禁用的真实Keychain round-trip，两个真实opt-in均unset，普通测试继续文件fallback。下一步四平台generic unsigned warnings-as-errors Debug build。
- 2026-08-18：3.5最终四平台warnings-as-errors unsigned generic Debug顺序完成；macOS universal、iOS/iPadOS、tvOS、visionOS均为`succeeded / 0 error / 0 warning / 0 analyzer warning`，macOS产物含`x86_64 arm64`。仅使用generic destination，未操作Simulator，不构成signed/physical/live证明。
- 2026-08-18：首个结构化build读回脚本误把zsh特殊变量`path`用作bundle路径，导致该shell的`PATH`被覆盖并报`xcrun: command not found`；构建和xcresult未受影响。改名`bundle_path`后只读同一四份bundle与三份测试bundle成功，未重复build/test。
- 2026-08-18：文档范围搜索中的`openspec/.../specs/*.md`因实际文件位于子目录且zsh启用`nomatch`而在命令启动前退出；无文件或运行时副作用，后续使用明确spec路径与稳定关键词读取。
- 2026-08-18：最终代码审计确认owner/generation重验、requested/actual overlay分离、mac/tv/vision focus与input handoff、reserved-command本地化、全部可见stop confirmation入口及terminal双重transient cleanup一致；未发现需要追加production修改。现同步OpenSpec/design/spec、roadmap与planning，随后运行generator/strict/repository pre-gate，通过前保持3.5未勾选。
- 2026-08-18：generator保持SHA-256 `60e6966fc42bbe0facbb8adfdf66794746948039ba1f190ac13dc0438a9d2224`且project零diff；OpenSpec strict `1/1`通过。首轮pre-gate因`.overlayVisible`正则过度转义退出，第二轮因jq未引用`next`关键字退出；两者均为只读wrapper错误，未重复fixture/test/build或操作runtime。
- 2026-08-18：corrected repository pre-gate通过fixture self/tree、pre-mark `17/48 next 3.5`、精确10文件scope、owner/local-command/confirmation语义、retained `8/219/1224`与四平台`4/4`、privacy/reference/dependency/opt-in/process/diff边界。已仅勾选3.5并同步planning，预期`18/48 next 3.6`。
- 2026-08-18：post-mark final-state只读通过strict `1/1`、OpenSpec `18/48 next 3.6`、精确11文件scope、唯一3.5 checkbox、稳定project与全部retained evidence；未重复test/build/generator或操作Keychain、live host、Simulator。
- 2026-08-18：八个明确`/private/tmp/LuneX-19-3_5-*`证据路径已用`find -depth -delete`逐项清理，失败/成功DerivedData、xcresult及Xcode自动设备枚举文本均不再保留；零残留检查通过。下一步final record与独立commit/push/fetch。
- 2026-08-18：final record通过基线`HEAD == origin/main == c74b4f0`、strict、`18/48 next 3.6`、最终11文件scope、唯一3.5 checkbox、稳定project、零task artifact、disabled opt-ins及repository/process/proof边界。准备精确stage、独立commit/push/fetch。
- 2026-08-18：启动阶段19 task 3.6；恢复确认OpenSpec `18/48 next 3.6`，工作树仅有`RootView.swift`、`ProductWorkflowSurface.swift`和`ProductWorkflowSurfaceTests.swift`三个候选修改，`git diff --check`通过。Xcode 26.4/Swift 6.3，Keychain/live-host opt-in unset，无活动LuneX build/test进程且未操作Simulator。
- 2026-08-18：3.6候选建立compact/wide纯值布局合同；compact controls位于底部安全区、最大约48%高度且可滚动，wide位于顶左、最大宽度1040且最大约82%高度。controls显示时virtual controller不再同时显示，command headers可重排，show/hide仍不依赖hover。
- 2026-08-18：全文件`xcrun swift-format lint --strict`产生大量既有默认两空格、line length及既有规则诊断，不作为局部3.6门禁且不批量format；改用fresh warnings-as-errors编译、结构化xcresult、`git diff --check`和人工审读。下一步fresh macOS compile。
- 2026-08-18：历史命令搜索因不存在的`Makefile*`触发zsh `nomatch`，在搜索启动前退出且无副作用；直接读取工程scheme后继续。
- 2026-08-18：fresh `/private/tmp/LuneX-19-3_6-compile-1.hkeJQH` generic macOS Debug warnings-as-errors编译一次通过；xcresult为`succeeded/0 error/0 warning/0 analyzer warning`，日志只有AppIntents metadata skip，universal产物含`x86_64 arm64`。下一步focused布局与RootView合同测试。
- 2026-08-18：fresh focused结构化通过`4/4`、零skip/failure及零build diagnostics；覆盖layout reducer、RootView adaptive/non-hover/virtual-controller合同和tvOS/visionOS source/focus合同。
- 2026-08-18：related八簇复用fresh build缓存并结构化通过`176/176`、零skip/failure及零build diagnostics；owner/session、workspace、mac input、mobile、tvOS和visionOS presentation均无回归。下一步独立fresh serial normal。
- 2026-08-18：独立fresh serial normal结构化通过`1225 total / 1224 passed / 1 skipped / 0 failed`，build diagnostics全零；唯一skip精确为显式禁用的real-Keychain round-trip，Keychain/live-host opt-in均unset，继续文件fallback。下一步四平台generic Debug build。
- 2026-08-18：首版四平台generic Debug顺序通过`4/4`且每份xcresult为`succeeded/0/0/0`，macOS为`x86_64 arm64`；随后人工UI审计发现actual resized macOS width未参与compact判定，故此前compile/test/build全部降为修订前中间证据。
- 2026-08-18：修订`ProductStreamWorkspaceLayout`以900pt阈值消费GeometryReader actual width，并让tvOS/visionOS内部controls继承outer compact判定；非有限width fail closed。compact max height由带96pt floor改为严格48%，wide height82%、宽度约68%并夹在640...1040pt。下一步从fresh目录重新编译与测试。
- 2026-08-18：修订后fresh focused `/private/tmp/LuneX-19-3_6-focused-final.cO86i1`结构化通过`4/4`，related `/private/tmp/LuneX-19-3_6-related-final.Sqk1fr`通过`176/176`；两者均零skip/failure且build diagnostics全零。tvOS compact header补用`ViewThatFits`后重新纳入最终证据。
- 2026-08-18：最终fresh serial normal `/private/tmp/LuneX-19-3_6-normal-final.F3zbOj`通过`1225/1224/1/0`，唯一skip为显式禁用的真实Keychain round-trip；真实Keychain/live-host opt-in均unset，普通测试继续文件fallback。
- 2026-08-18：最终四平台目录`/private/tmp/LuneX-19-3_6-platform-builds-final.c62DaX`中macOS universal、iOS/iPadOS、tvOS、visionOS unsigned generic Debug `4/4`均`succeeded/0 error/0 warning/0 analyzer warning`，macOS为`x86_64 arm64`。未操作Simulator lifecycle。
- 2026-08-18：已开始同步3.6 authority：OpenSpec design/spec、runtime contract、completion roadmap与三份planning记录actual width、900pt、48%/82%、virtual-controller排他、non-hover restore、tvOS/visionOS reflow及最终证据；task仍保持pre-mark `18/48 next 3.6`，下一步静态/generator/strict/repository pre-gate。
- 2026-08-18：首轮静态语义wrapper通过layout/geometry/reachability/reflow四组后，在ownership组因错误要求不含平台controls的通用源码切片出现三次stop confirmation而退出；无production/test/build/device副作用。修正为通用、tvOS、visionOS三段各一次后继续，不把该轮计作完整门。
- 2026-08-18：corrected静态语义门完整通过actual-width、48%/82%、command reflow、non-hover restore、virtual-controller排他、tvOS focus顺序、三平台workspace confirmation、3.5 reserved/input合同、source tests、pre-mark与diff-check。后续skip提取器因错误JSON字段无匹配退出；将按实际schema只读补验，不重复静态门。
- 2026-08-18：按实际test-tree `result`字段确认normal唯一skip为真实Keychain round-trip；四平台最终build逐份结构化确认`succeeded/0/0/0`。wrapper仅在末尾固定`file`短语/路径的universal断言无匹配，改用实际路径加`lipo -archs`补验，不重复前述证据。
- 2026-08-18：`lipo -archs`确认最终macOS可执行文件为`x86_64 arm64`；generator运行前及连续两次运行后project SHA-256均为`60e6966fc42bbe0facbb8adfdf66794746948039ba1f190ac13dc0438a9d2224`，工程无diff且diff-check通过。下一步strict/apply与repository pre-gate。
- 2026-08-18：首个repository pre-gate在任何shell启动前因外层JavaScript误解析Bash `${spec%%:*}`而以SyntaxError拒绝；无evidence或项目/运行时副作用。将用`IFS=:`替代参数展开并从fresh目录完整执行。
- 2026-08-18：repository pre-gate r1 `/private/tmp/LuneX-19-3_6-repository-pre.CibDgd`通过01-08全部门，在09的process检查因wrapper命令行含`xcodebuild.log`而自匹配误报；未运行真实build/test。改用`pgrep -x`并从fresh r2完整重跑，r1只保留诊断。
- 2026-08-18：r2 `/private/tmp/LuneX-19-3_6-repository-pre-r2.OOerd5`通过01-08及opt-in/process检查，随后过宽禁止所有ignored `DerivedData`/log的断言退出。将只读确认命中并收窄到Git可见与task-specific artifact，不删除既有cache；r2不计最终门。
- 2026-08-18：fresh repository pre-gate r3 `/private/tmp/LuneX-19-3_6-repository-pre-r3.98Tnh5`完整通过10组门：baseline/精确10文件、strict与`18/48 next 3.6`、稳定generator、source/authority、最终tests/builds、privacy/test integrity、disabled opt-ins、零build/test process、Git-visible artifact及diff边界；未操作Simulator。
- 2026-08-18：OpenSpec 3.6已勾选，预期权威进度`19/48 ready`、next 3.7。下一步仅运行post-mark只读final-state，不重复generator/test/build或操作Keychain/live host/Simulator。
- 2026-08-18：post-mark `/private/tmp/LuneX-19-3_6-final-state.aAzzoV`只读通过strict、`19/48 next 3.7`、11文件scope、唯一3.6 checkbox、稳定project、最终evidence/pre-gate、disabled opt-ins和零build/test process。下一步逐个定向清理所有3.6临时证据。
- 2026-08-18：首个cleanup脚本在shell启动前因外层JavaScript误解析Bash数组展开而拒绝，32个已枚举路径均未删除；改用here-doc逐行精确路径执行，不使用宽泛删除。
- 2026-08-18：32个已枚举`/private/tmp/LuneX-19-3_6-*`路径已逐个`find <exact> -depth -delete`，task prefix零残留；仓库既有ignored `build/DerivedData`未触碰。下一步final diff audit与record。
- 2026-08-18：首轮final audit确认product hunk全在stream UI、tests无删除/skip、OpenSpec `19/48 next 3.7`，并发现roadmap一句“3.6仍负责”的stale时态；已精确改为3.6完成、3.7仍负责完整矩阵，不重跑test/build。下一步重跑只读final audit。
- 2026-08-18：corrected final audit通过11文件scope、RootView stream-only hunk范围、core `21+/0-`、1新增/0删除测试函数、无skip/disable、唯一3.6 checkbox、strict `19/48 next 3.7`、零stale authority wording及privacy/opt-in/process/artifact/project/diff边界。下一步final record后提交推送。
- 2026-08-18：3.6已以`fec4ec5 Adapt stream controls to window size`提交推送，fetch与ls-remote确认三方SHA一致、工作树clean。启动3.7 application session矩阵审计，真实opt-in继续unset且不操作Simulator。
- 2026-08-18：3.7覆盖审计确认九项中八项已有明确application tests，唯一缺口是旧session termination在replacement streaming后到达。已仅修改`AppModelWorkflowTests.swift`：测试provider可选保留stopped continuation，并新增stale termination不改写/停止第二代及最终clean stop回归；production零修改。下一步warnings-as-errors compile与focused测试。
- 2026-08-18：fresh focused `/private/tmp/LuneX-19-3_7-focused.MMLiAG`结构化通过新增竞态`1/1`，零skip/failure且build diagnostics全零。下一步将九类合同对应的10个application tests作为expanded focused统一执行。
- 2026-08-18：首个expanded wrapper在shell启动前因外层JavaScript误解析Bash数组展开而拒绝，无evidence/build/test副作用；改用10个显式only-testing参数后继续。
- 2026-08-18：fresh expanded `/private/tmp/LuneX-19-3_7-expanded.iCdzYN`结构化通过九类合同对应的`10/10` application tests，零skip/failure且build diagnostics全零；production无需修改。下一步独立fresh serial normal。
- 2026-08-18：fresh serial normal `/private/tmp/LuneX-19-3_7-normal.NxftSs`结构化通过`1226/1225/1/0`，build diagnostics全零；唯一skip精确为真实Keychain round-trip，两个真实opt-in unset、文件fallback继续。工作树仅test与三份planning，3.7仍未勾选；下一步authority与pre-gate。
- 2026-08-22：恢复确认`fec4ec5` remote parity、OpenSpec `19/48 next 3.7`及精确4文件工作树不变；`/private/tmp/LuneX-19-3_7-*`已被系统清理。为最终pre-gate重建当前源码的focused/expanded/normal retained证据，继续unset真实opt-in且不操作Simulator。
- 2026-08-22：当前未变源码的fresh final focused `/private/tmp/LuneX-19-3_7-focused-final.wADFi6`通过`1/1`，expanded `/private/tmp/LuneX-19-3_7-expanded-final.GOhNqB`通过九类矩阵`10/10`，normal `/private/tmp/LuneX-19-3_7-normal-final.0qbP0I`通过`1226/1225/1/0`；三份build diagnostics全零，唯一skip仍为真实Keychain opt-in测试，文件fallback继续。
- 2026-08-22：已同步3.7 OpenSpec design/session spec、runtime contract、completion roadmap与三份planning，记录test-only stale-generation竞态、production零diff、九类application合同和offline proof boundary。task仍保持pre-mark `19/48 next 3.7`，下一步静态/generator/strict/repository pre-gate。
- 2026-08-22：首轮静态wrapper在确认新增测试/default false各一次及新增skip零匹配后，因`rg`零结果与`pipefail`组合提前退出；属于只读编排错误且无项目/runtime副作用。下一轮改用显式零计数后完整重跑。
- 2026-08-22：corrected静态门与三份structured build复读通过；generator前后双跑SHA-256稳定为`60e6966f...d2224`，strict通过。repository pre-gate `/private/tmp/LuneX-19-3_7-repository-pre.CvoM5e`完成10组scope/source/evidence/privacy/opt-in/process/diff检查后，已仅勾选3.7并同步planning，预期OpenSpec `20/48 next 4.1`。
- 2026-08-22：post-mark `/private/tmp/LuneX-19-3_7-final-state.TnfZO2`只读确认strict、`20/48 next 4.1`、最终9文件scope、唯一3.7 checkbox、稳定project、retained `1/10/1226` evidence、disabled opt-ins及零build/test进程；未重复generator/test/build或操作Simulator。下一步逐路径清理3.7 evidence。
- 2026-08-22：12个明确`/private/tmp/LuneX-19-3_7-*`路径已逐项以`find <exact> -depth -delete`清理，task prefix零残留；未使用宽泛删除或触碰仓库既有cache。下一步final diff audit与record后独立提交推送。
- 2026-08-22：final diff audit通过最终9文件分类、test double默认行为、replacement session全部断言、1新增/0删除测试函数、0新增skip、唯一3.7 checkbox、authority/proof边界、稳定project及零task artifact；未发现需要追加修改。下一步final record后精确stage、commit、push、fetch。
- 2026-08-22：cleanup final record通过`fec4ec5`三方基线、strict、OpenSpec `20/48 next 4.1`、最终9文件、稳定project、source/authority、artifact/opt-in/process/diff边界。准备精确stage并以独立提交推送3.7。
- 2026-08-22：Task 3.7以`8fcb737 Cover stale session termination`提交推送，fetch与ls-remote确认三方一致且工作树clean。进入4.1，OpenSpec `20/48 next 4.1`；初步确认现有`WindowGroup`没有把scene identity接到workspace创建/恢复，范围保持scene wiring与unsupported single-workspace fallback，不提前做4.2/4.4。
- 2026-08-22：4.1设计确定为`WindowGroup(for:)`可恢复workspace ID + MainActor scene attachment coordinator；supported首次primary/后续distinct/reconnect generation replacement/duplicate fail closed，unsupported始终primary。scene detach不close/stop，RootView只接顶层scene workspace，完整字段迁移留给4.2。
- 2026-08-22：4.1首轮production/test实现完成；fresh macOS generic Debug warnings-as-errors `/private/tmp/LuneX-19-4_1-compile.aXHxvO`一次通过，structured build diagnostics全零且产物为`x86_64 arm64`。下一步focused scene/coordinator/source tests。
- 2026-08-22：4.1 focused scene/coordinator/source合同`7/7`通过、0 skip/failure且build diagnostics全零。下一步iOS/iPadOS generic warnings-as-errors build验证iOS条件分支与Info manifest，不操作Simulator。
- 2026-08-22：iOS/iPadOS generic Debug warnings-as-errors build通过且structured diagnostics全零，实际app Info读回multiple scenes为true、background audio仍为audio；未操作Simulator。下一步六簇workspace related回归。
- 2026-08-22：六簇workspace related `77/77`通过且build diagnostics全零。审计后新增AppModel wrapper application test覆盖restored primary、generation reconnect与unsupported fallback，并删除未使用failure枚举项；下一步fresh focused复验，既有证据降为补强前辅助证据。
- 2026-08-22：补强后fresh focused `/private/tmp/LuneX-19-4_1-focused-final.wXwWF7`通过`8/8`、0 skip/failure且build diagnostics全零。下一步加入完整AppModelWorkflowTests运行七簇related矩阵。
- 2026-08-22：七簇related结构化通过`160/160`、0 skip/failure且build diagnostics全零。下一步独立fresh serial normal，Keychain/live-host opt-in继续unset并使用文件fallback。
- 2026-08-22：独立fresh serial normal `/private/tmp/LuneX-19-4_1-normal-final.MHuuST`通过`1233/1232/1/0`且build diagnostics全零；唯一skip为真实Keychain opt-in测试。下一步最终四平台generic Debug builds，不操作Simulator。
- 2026-08-22：最终四平台generic Debug `/private/tmp/LuneX-19-4_1-platform-builds-final.RFvm5d`顺序通过macOS、iOS/iPadOS、tvOS、visionOS `4/4`且每份structured diagnostics全零；macOS universal，iOS actual Info保留multiple scenes true与background audio。下一步authority同步与repository门禁。
- 2026-08-22：续接时`create_goal`因旧goal同时被报告为`blocked`与“unfinished”而拒绝重建，无仓库/runtime副作用；继续以OpenSpec `20/48 next 4.1`为执行权威。
- 2026-08-22：已同步4.1 OpenSpec design/multiwindow spec、runtime contract、completion roadmap与三份planning，记录typed scene ID、runtime fallback、primary/distinct/reconnect/duplicate语义、detach不close/stop、最终`8/160/1233/4`证据及真实窗口/Stage Manager/signed physical proof边界。task保持pre-mark，下一步静态/generator/strict/repository门禁。
- 2026-08-22：首轮repository pre-gate通过15文件scope与coordinator语义后，因`rg -c`零匹配输出为空而非`0`误判顶层RootView断言并退出；源码实际零命中，未重复test/build/generator或设备操作。改用`awk`显式零计数后从fresh目录完整重跑。
- 2026-08-22：fresh repository pre-gate `/private/tmp/LuneX-19-4_1-repository-pre-r2.03qeW4`完整通过11组scope、coordinator、scene root、Info、test integrity、authority、strict pre-mark、stable generator、retained tests、四平台build及opt-in门。现已仅勾选4.1并同步planning，预期OpenSpec `21/48 next 4.2`。
- 2026-08-22：post-mark `/private/tmp/LuneX-19-4_1-final-state.HvXjF0`只读确认strict、`21/48 next 4.2`、最终16文件scope、唯一4.1 checkbox、稳定project、retained evidence及disabled opt-ins；未重复generator/test/build或操作Simulator。下一步逐路径清理4.1 evidence。
- 2026-08-22：13个明确`/private/tmp/LuneX-19-4_1-*`路径已逐项以`find <exact> -depth -delete`清理，task prefix零残留；未使用宽泛删除或触碰仓库既有cache。下一步final diff audit与cleanup final record。
- 2026-08-22：final diff audit通过最终16文件scope、scene attachment/generation/detach语义、RootView 4.1/4.2边界、7新增/0删除/0 skip测试、唯一4.1 checkbox、strict `21/48 next 4.2`、稳定project、零task artifact与proof边界；未发现需追加修改。下一步cleanup final record后精确stage、commit、push、fetch。
- 2026-08-22：cleanup final record通过`8fcb737`三方基线、strict `21/48 next 4.2`、最终16文件scope、稳定project、零4.1 artifact、两个opt-in unset及source/authority/diff/proof边界。准备精确stage并独立提交推送4.1。
- 2026-08-22：Task 4.1以`74faaba Wire workspaces to native scenes`提交推送，fetch与ls-remote确认`HEAD == origin/main == remote`且工作树clean；OpenSpec `21/48 next 4.2`。
- 2026-08-22：4.2审计确认navigation/tab、selected host/app、Add Host sheet、host dialog及四个library workflow panel仍回退primary；底层validation/retry/pairing/catalog/overlay状态已workspace-scoped。下一步增加checked AppModel binding/sheet APIs并把scene workspace贯穿RootView子树，不提前实现4.3/4.4/4.6。
- 2026-08-22：4.2首轮production/test实现完成；macOS generic warnings-as-errors `/private/tmp/LuneX-19-4_2-compile.yIqgzB`一次通过且universal/structured diagnostics全零。fresh focused `/private/tmp/LuneX-19-4_2-focused.HVX1et`中5项binding/compatibility/sheet/source合同`5/5`通过、零skip/failure且build diagnostics全零。下一步related矩阵。
- 2026-08-22：首轮related结构化为`161/159/0/2`且build diagnostics全零；失败为catalog source test仍期待旧primary选中字符串，以及既有visionOS长流程等待session state超时。已更新陈旧source断言，下一步单独复验vision以判断时序，不把失败bundle计作验收或原样重跑。
- 2026-08-22：catalog source修正与vision timeout针对性复验`2/2`通过；fresh最终related `/private/tmp/LuneX-19-4_2-related-final.YjENtl`通过`161/161`、零skip/failure且build diagnostics全零。独立fresh serial normal `/private/tmp/LuneX-19-4_2-normal-final.MmYrfq`通过`1234/1233/1/0`，唯一skip为真实Keychain opt-in，文件fallback继续。下一步四平台generic Debug。
- 2026-08-22：原会话四平台generic Debug `/private/tmp/LuneX-19-4_2-platform-builds-final.bWTC1q`完成macOS、iOS/iPadOS、tvOS、visionOS `4/4`，四份structured summary均`succeeded/0/0/0`且macOS executable为`x86_64 arm64`；未操作Simulator lifecycle。
- 2026-08-22：最终源码审计确认RootView中`primaryWorkspaceReference`零命中，navigation/selection/sheet/dialog/validation/retry/overlay均沿传入scene workspace；legacy primary只保留compatibility，4.3/4.4/4.6边界未提前实现。
- 2026-08-22：已同步4.2 OpenSpec design/multiwindow spec、runtime contract、completion roadmap与三份planning，记录checked binding、stale fail-closed、`5/161/1234/4`最终证据和未证明的真实窗口/Stage Manager/signed/live边界。task保持pre-mark，下一步generator稳定性、strict和repository pre-gate。
- 2026-08-22：authority后一次generator历史命令搜索因zsh对不存在的`Makefile*`裸glob触发`nomatch`而在搜索前退出，无项目/runtime副作用；已直接定位仓库`Tools/generate_xcodeproj.rb`继续。
- 2026-08-22：generator前、连续两次运行后project SHA-256均稳定为`60e6966f...d2224`且工程零diff；OpenSpec strict通过。repository pre-gate `/private/tmp/LuneX-19-4_2-repository-pre.xJWEX2`完成10组remote/scope/source/test/authority/pre-mark/evidence/privacy/process/diff检查，现已仅勾选4.2，预期OpenSpec `22/48 next 4.3`。
- 2026-08-22：首轮post-mark final-state已确认strict、`22/48 next 4.3`与13文件scope，随后因checkbox diff正则漏写Markdown `-`后的空格而误判退出；没有重复generator/test/build或设备操作，改用精确行格式从fresh目录只读重跑。
- 2026-08-22：第二轮post-mark再次只在checkbox diff索引退出；Git unified diff中的实际行前缀为`-- [ ]`与`+- [x]`，独立只读awk已确认`1:1`。第三轮使用该实际格式，不重复任何production验证或设备操作。
- 2026-08-22：fresh post-mark r3 `/private/tmp/LuneX-19-4_2-final-state-r3.VHGzxH`只读确认strict、OpenSpec `22/48 next 4.3`、最终13文件scope、唯一4.2 checkbox、稳定project、retained evidence、disabled opt-ins与零build/test进程；未重复generator/test/build或操作Simulator。下一步精确枚举清理全部4.2临时证据。
- 2026-08-22：首次cleanup因循环变量名`path`触发zsh特殊变量并覆盖`PATH`，在首个`find`执行前退出；22个精确目标全部仍存在。将改用`target`与绝对`/usr/bin/find`逐项清理，不扩大路径范围。
- 2026-08-22：22个明确`/private/tmp/LuneX-19-4_2-*`路径已逐项以绝对`/usr/bin/find <exact> -depth -delete`清理，task prefix零残留；未使用宽泛删除或触碰仓库既有cache。
- 2026-08-22：cleanup后authority audit发现runtime contract仍有5处4.2前的primary/pending旧时态及design一处迁移时态；已精确改为Add Host/catalog/pairing/host panel/per-scene injection完成，并保留4.3/4.4/5.x/6.x边界。production/test不变，下一步重跑只读final audit。
- 2026-08-22：corrected final audit通过最终13文件scope、RootView primary fallback零命中、authority旧时态零残留、1新增/0删除/0 skip测试、唯一4.2 checkbox、strict `22/48 next 4.3`、稳定project、零task artifact、disabled opt-ins与`74faaba`三方基线；准备cleanup final record后精确stage、commit、push、fetch。
- 2026-08-22：cleanup final record通过`74faaba`三方基线、最终13文件、strict `22/48 next 4.3`、稳定project、source/authority/diff、零task artifact、disabled opt-ins与零build/test进程。准备精确stage并独立提交推送4.2。
- 2026-08-22：Task 4.2以`a6af2c8 Bind scenes to local workspace state`提交推送，fetch与ls-remote确认`HEAD == origin/main == remote`且工作树clean；OpenSpec `22/48 next 4.3`。
- 2026-08-22：4.3审计确认catalog已有all-workspace publish、settings本来就是process-level shared observable；host load/add/remove的library phase广播以及trust reset/pairing completion对其他同host workspace陈旧pairing presentation的清理是production缺口。下一步增加受限shared-host reconciliation helper与two-workspace application tests，禁止session ownership transfer。
- 2026-08-22：4.3 production/test首轮完成；fresh macOS warnings-as-errors `/private/tmp/LuneX-19-4_3-compile.FrCx2H`通过且universal/structured diagnostics全零。fresh focused `/private/tmp/LuneX-19-4_3-focused.TFO9o2`中host add、settings、catalog、pairing、trust reset和inactive removal/session owner `6/6`通过、零skip/failure且build diagnostics全零。下一步七簇related。
- 2026-08-22：fresh七簇related `/private/tmp/LuneX-19-4_3-related.bKIZsI`通过`167/167`，零skip/failure且build diagnostics全零。独立fresh serial normal `/private/tmp/LuneX-19-4_3-normal.6n51ND`通过`1240/1239/1/0`，唯一skip为真实Keychain opt-in，文件fallback继续。下一步四平台generic Debug。
- 2026-08-22：四平台generic Debug `/private/tmp/LuneX-19-4_3-platform-builds.zXQVKQ`顺序通过macOS、iOS/iPadOS、tvOS、visionOS `4/4`且四份structured diagnostics全零，macOS为`x86_64 arm64`；未操作Simulator。
- 2026-08-22：实现审计确认PersistingPairingProvider在completion前持久化trust，AppModel helper只做all-workspace projection；helper对scene/session/media/input owner零写入。已同步4.3 design/spec/runtime contract/roadmap与三份planning，task保持pre-mark，下一步generator/strict/repository pre-gate。
- 2026-08-22：generator前后双跑project SHA-256稳定为`60e6966f...d2224`且strict通过；repository pre-gate `/private/tmp/LuneX-19-4_3-repository-pre.XNCvB0`完成10组remote/scope/source/test/authority/pre-mark/evidence/privacy/process/diff检查。现已仅勾选4.3，预期OpenSpec `23/48 next 4.4`。
- 2026-08-22：post-mark `/private/tmp/LuneX-19-4_3-final-state.mhqgr1`只读确认strict、`23/48 next 4.4`、最终13文件scope、唯一4.3 checkbox、稳定project、retained evidence、disabled opt-ins与零build/test进程；未重复generator/test/build或操作Simulator。下一步精确清理4.3 evidence。
- 2026-08-22：16个明确`/private/tmp/LuneX-19-4_3-*`路径已逐项用绝对`/usr/bin/find <exact> -depth -delete`清理，task prefix零残留；未使用宽泛删除或触碰仓库既有cache。下一步final diff/authority audit。
- 2026-08-22：cleanup后final authority audit发现runtime contract两处和roadmap一处仍把4.3写为later/pending；首个组合补丁因换行锚点不匹配整体拒绝且无部分修改，已按实际行内容改为shared reconciliation完成、4.4 owning-window close仍pending，并同步三份planning。production/test不变，下一步只读final audit与cleanup final record。
- 2026-08-22：首轮只读final audit通过精确13文件、helper owner零写入与OpenSpec strict，随后zsh因变量名`status`只读而在apply进度断言前退出；临时strict JSON已先精确删除，无仓库/runtime副作用。改用`apply_json`完整重跑，不复用该轮作为最终门。
- 2026-08-22：corrected完整final audit通过13文件scope、helper `1+5`与owner写入0、测试`6新增/0删除/0 skip`、strict `23/48 next 4.4`、稳定project、零4.3 artifact、disabled opt-ins、零build/test进程与`a6af2c8`三方基线。cleanup final record已同步，下一步精确stage、独立commit/push/fetch。
- 2026-08-22：Task 4.3以`1c9d348 Reconcile shared workspace repositories`提交推送，fetch/ls-remote确认三方一致且工作树clean。已按OpenSpec apply读取全部context并启动4.4；确定纯close reducer、同步stop reservation、actual retained presentation、stale token与already-stopping共享teardown设计，下一步production/test编辑。
- 2026-08-22：4.4 production首轮完成：新增pure close policy与typed outcome，AppModel依据current attachment/owner/phase/actual continuity执行detach/retain/共享clean stop，stop reservation在detach前同步安装，LuneXApp onDisappear改为异步await close。下一步定向测试覆盖全部任务phase。
- 2026-08-22：4.4首轮macOS compile在进入Swift编译前因遗漏`CODE_SIGNING_ALLOWED=NO`被entitlement signing gate拒绝，RC 65；无源码诊断/test/Keychain/live-host/Simulator副作用。该bundle不计验收，改用fresh unsigned命令。
- 2026-08-22：corrected unsigned macOS compile通过且universal。首轮focused为6/7；唯一失败精确证明reconnecting已stop media后close再次stop同一environment。已按active media owner收紧底层stop并校正phase期望，失败bundle不计最终验收，下一步fresh 7项focused。
- 2026-08-22：focused r2仍为6/7同一reconnect重复environment stop；owner布尔在首次await前未撤销reservation。已改为`stopMediaEnvironment`入口同步take active media ID/generation，后续使用local generation，重复调用立即no-op；r2不计最终证据。
- 2026-08-22：fresh focused r3通过close policy与六项application合同`7/7`，零skip/failure且structured build diagnostics全零；corrected macOS compile也为全零diagnostic和universal。下一步related session/workspace回归。
- 2026-08-22：related首轮出现8项pending media/tvOS/visionOS回归，结构化失败均由active-media early return跳过既有完整cleanup导致。已恢复原`stopMediaEnvironment`语义，并明确reconnect是旧generation cleanup加terminal cleanup两次、control provider仍一次；related失败bundle不计验收。
- 2026-08-22：恢复既有media cleanup后的fresh focused final通过`7/7`，related final通过`150/150`，两份structured build diagnostics全零；全部pending-start、recovery/cancellation和tvOS/visionOS teardown回归闭合。下一步fresh serial normal。
- 2026-08-22：fresh serial normal通过`1246/1245/1/0`且build diagnostics全零，唯一skip为真实Keychain opt-in测试；文件fallback与两个unset opt-in保持。下一步四平台unsigned generic Debug。
- 2026-08-22：四平台unsigned generic Debug `/private/tmp/LuneX-19-4_4-platform-builds.4oV89T`顺序通过macOS、iOS/iPadOS、tvOS、visionOS `4/4`且四份structured diagnostics全零，macOS为`x86_64 arm64`；未操作Simulator。
- 2026-08-22：已同步4.4 OpenSpec design/multiwindow spec、runtime contract、completion roadmap与三份planning，记录纯close reducer、retained presentation、同步stop reservation、stale/replacement/already-stopping语义、media cleanup generation边界、最终`7/150/1246/4`证据及真实窗口/Stage Manager/signed/live proof boundary。task保持pre-mark `23/48 next 4.4`，下一步generator双跑、strict与repository pre-gate。
- 2026-08-22：generator前后双跑project SHA-256稳定为`60e6966f...d2224`且strict通过；repository pre-gate `/private/tmp/LuneX-19-4_4-repository-pre.ih2WRB`完成remote/scope/source/test/authority/pre-mark/evidence/opt-in/process/diff检查。现已仅勾选4.4并同步planning，OpenSpec权威为`24/48 next 4.5`。
- 2026-08-22：post-mark `/private/tmp/LuneX-19-4_4-final-state.T71IuP`只读确认strict、`24/48 next 4.5`、最终13文件scope、唯一4.4 checkbox、稳定project、retained evidence、disabled opt-ins与零build/test进程；未重复generator/test/build或操作Simulator。下一步逐路径清理4.4 evidence。
- 2026-08-22：首次cleanup使用系统Bash 3.2不支持的`mapfile`，在任何删除前退出；只读确认14个精确目标全部仍存在。改用硬编码白名单和绝对`/usr/bin/find`逐项清理，不扩大路径范围。
- 2026-08-22：14个明确`/private/tmp/LuneX-19-4_4-*`目录与generator log已逐项以绝对`/usr/bin/find <exact-path> -depth -delete`清理，task prefix零残留；未使用宽泛删除或触碰仓库既有cache。下一步final diff/authority audit。
- 2026-08-22：首轮cleanup-final audit在旧时态扫描中把同一行“4.4完成；4.5/4.6 pending”误判为4.4 pending并退出；此前scope/OpenSpec/checkbox/test/source断言已通过，未修改仓库或运行任何行为门。改为精确旧短语后完整重跑。
- 2026-08-22：corrected cleanup-final audit通过最终13文件scope、source close/stop顺序、6新增/0删除/0 skip测试、唯一4.4 checkbox、strict `24/48 next 4.5`、稳定project、零task artifact、disabled opt-ins、零build/test进程与`1c9d348`三方基线。cleanup final record已同步，下一步精确stage、独立commit/push/fetch。
- 2026-08-22：Task 4.4以`b60779b Apply owning window close policy`提交推送，fetch/ls-remote确认三方一致且工作树clean；OpenSpec为`24/48 next 4.5`。启动4.5审计，确认无自定义window command且tvOS/visionOS使用普通single-workspace WindowGroup，下一步追踪focus/input adapter的checked workspace owner。
- 2026-08-22：4.5首轮只读盘点最后一个裸glob因无匹配触发zsh `nomatch`；已读取的App/Root/TV/Vision presentation内容有效，仓库无变化。后续改用`rg --files`定位输入owner文件。

- 2026-08-22：阶段19 Task 4.5续接确认工作树仅有预期7文件，`HEAD=b60779b`、OpenSpec `24/48 next 4.5`。补记首个组合补丁原子拒绝与focused 0-test测试编译错误；已将不存在的`.pointerMove`改为合法`.pointer(.absoluteMove(...))`，production未为测试错误改变。
- 2026-08-22：尝试按用户既有要求重建长期goal时，goal服务因旧目标同时为`blocked`和unfinished而拒绝；未误标旧目标complete，继续以OpenSpec/planning推进。真实Keychain与live-host opt-in继续unset，当前任务不操作Simulator lifecycle。
- 2026-08-22：4.5 focused第二轮为`2/1/1`；active non-primary workspace的TV/Vision adapter fail-closed用例通过，唯一source-test失败因`#else`搜索误匹配`#elseif os(iOS)`。已收紧到完整directive行，production不变；失败bundle不计验收。
- 2026-08-22：fresh最终focused `/private/tmp/LuneX-19-4_5-focused-r2.Cav4yU`结构化通过`2/2`且build diagnostics全零。下一步运行AppModel、Product workspace/workflow、TV focus/control与Vision input/presentation related矩阵。
- 2026-08-22：fresh related `/private/tmp/LuneX-19-4_5-related.Ag1mod`结构化通过`310/310`、零skip/failure且build diagnostics全零；下一步独立serial normal，真实Keychain/live-host opt-in继续unset。
- 2026-08-22：fresh serial normal `/private/tmp/LuneX-19-4_5-normal.SJ9MHO`通过`1248/1247/1/0`且build diagnostics全零；唯一skip为真实Keychain opt-in测试，文件fallback继续。下一步四平台unsigned generic Debug，不操作Simulator。
- 2026-08-22：四平台unsigned generic Debug `/private/tmp/LuneX-19-4_5-platform-builds.hEsR0g`顺序通过macOS、iOS/iPadOS、tvOS、visionOS `4/4`，structured diagnostics全零且macOS universal；未操作Simulator。下一步同步authority并运行generator/strict/repository pre-gate。
- 2026-08-22：已同步4.5 OpenSpec design/multiwindow spec、runtime contract、roadmap与三份planning，记录single-scene visibility、primary-only adapter ownership、`2/310/1248/4`证据及proof boundary。Task仍未勾选，下一步generator/strict/repository pre-gate。
- 2026-08-22：generator前后双跑project SHA-256稳定为`60e6966f...d2224`且OpenSpec strict `1/1` valid；工程零diff。下一步repository pre-gate，通过前保持`24/48 next 4.5`。
- 2026-08-22：首轮repository pre-gate包装器因JavaScript模板中未转义Markdown反引号在shell前SyntaxError退出，任何子命令均未运行。已记录并将用无反引号模板从fresh目录完整重跑。
- 2026-08-22：corrected repository gate超过10秒yield后因上层仅转发output而丢失session ID；检查到strict/apply与全部test/build JSON已生成且无残留进程，但缺最终marker，不计验收。下一轮用30秒yield从fresh目录完整执行。
- 2026-08-22：fresh repository pre-gate `/private/tmp/LuneX-19-4_5-repository-pre-final.cLDETj`完整通过7组remote/scope/source+test/authority+OpenSpec/project+retained evidence/privacy+process+diff检查。现已仅勾选4.5，预期`25/48 next 4.6`。
- 2026-08-22：post-mark `/private/tmp/LuneX-19-4_5-final-state.wYwO7N`只读通过strict、`25/48 next 4.6`、12文件scope、唯一4.5 checkbox、稳定project、retained evidence与disabled opt-ins；下一步精确清理4.5临时证据。
- 2026-08-22：12个明确`/private/tmp/LuneX-19-4_5-*`目录/log已逐项用绝对`find <exact> -depth -delete`清理，prefix零残留；未使用宽泛删除或触碰仓库cache。下一步final diff/authority audit。
- 2026-08-22：cleanup final audit通过12文件scope、scene/adapter source、2新增/0删除/0 skip测试、唯一4.5 checkbox、strict `25/48 next 4.6`、稳定project、零artifact、disabled opt-ins、零进程与`b60779b`三方基线；准备精确stage、commit、push、fetch。
- 2026-08-22：Task 4.5以`4ffdd43 Enforce single workspace platform ownership`提交推送，三方SHA一致且工作树clean；OpenSpec `25/48 next 4.6`。启动4.6，确认缺口是同一AppModel双live-workspace组合矩阵，而非新的runtime owner或production UI能力。
- 2026-08-22：4.6 focused首轮两项中1项通过；唯一失败是测试直接registry replacement仍保留scene attachment token，旧close实际`.detached`。已改为真实scene disconnect/reconnect replacement路径并补replacement detach断言；production不变，下一步从fresh evidence重跑focused。
- 2026-08-22：fresh 4.6 focused r2结构化通过`2/2`且build diagnostics全零；双workspace local/shared/replacement与non-owner/owner-close组合均闭合，production零修改。下一步相关workspace/workflow/session/scene-close矩阵。
- 2026-08-22：fresh related矩阵结构化通过`259/259`且build diagnostics全零，覆盖11个workspace/workflow/session/scene-close完整测试类。下一步独立serial normal，真实Keychain/live-host opt-in继续unset。
- 2026-08-22：fresh serial normal通过`1250/1249/1/0`且structured build diagnostics全零；唯一skip为真实Keychain opt-in，文件fallback继续。下一步四平台unsigned generic Debug，不操作Simulator lifecycle。
- 2026-08-22：四平台unsigned generic Debug顺序通过`4/4`且structured diagnostics全零，macOS为`x86_64 arm64`；未操作Simulator。覆盖审计确认两条application timeline闭合4.6五类要求且production/project graph零修改；已同步OpenSpec design/spec、runtime contract、roadmap与三份planning，task保持pre-mark。下一步generator/strict/repository pre-gate。
- 2026-08-22：generator前后双跑project SHA-256稳定为`60e6966f...d2224`且工程零diff，OpenSpec strict `1/1` valid；4.6仍未勾选。下一步fresh repository pre-gate。
- 2026-08-22：fresh repository pre-gate `/private/tmp/LuneX-19-4_6-repository-pre.4lEziF`完整通过十组检查；现已只勾选4.6，预期OpenSpec `26/48 next 5.1`。下一步只读post-mark，不重复test/build/generator或操作Simulator。
- 2026-08-22：post-mark `/private/tmp/LuneX-19-4_6-final-state.B018Gb`只读通过strict、`26/48 next 5.1`、9文件scope、唯一4.6 checkbox、稳定project、retained evidence与disabled opt-ins；下一步精确清理4.6临时证据。
- 2026-08-22：15个明确`/private/tmp/LuneX-19-4_6-*`路径已逐项用绝对`find <exact> -depth -delete`清理，prefix零残留；未使用宽泛删除或触碰仓库cache。下一步cleanup后final diff/authority audit。
- 2026-08-22：cleanup后authority复读发现runtime contract仍把multiwindow close列作later work；已精确改为4.4 close和4.6 matrix均完成offline evidence，只保留5.x/7.x后续。production/test不变，下一步完整只读final audit。
- 2026-08-22：corrected cleanup final audit通过最终9文件、production/project零diff、2新增/0删除/0 skip测试、authority current-state、strict `26/48 next 5.1`、稳定project、零artifact/opt-in/process及`4ffdd43`三方基线。准备精确stage、commit、push、fetch。
- 2026-08-22：Task 4.6以`a2386ea Cover two workspace application matrix`提交推送，fetch/ls-remote确认三方SHA一致且工作树clean；OpenSpec `26/48 next 5.1`。已启动5.1 semantic descriptor审计，先定义typed/localized role/value/eligibility/destructive合同，不提前做5.2-5.6。
- 2026-08-22：5.1首轮focused `/private/tmp/LuneX-19-5_1-focused.JABMVl`在测试编译阶段因`PairingUIState`参数顺序错误退出65，0项测试执行；production零Swift诊断。失败bundle不计最终证据，已仅重排测试参数，下一步从fresh目录重跑5项focused。
- 2026-08-22：fresh focused r2通过`5/5`且build diagnostics全零；审计后将805行semantic实现拆入独立源文件，并收紧destructive status与non-owner/stale/no-session stream-control eligibility，新增对应focused断言。下一步运行generator并从fresh evidence重跑focused。
- 2026-08-22：generator纳入独立语义文件后的fresh focused r3通过`5/5`；destructive status与non-owner controls断言通过。下一步运行12类related回归矩阵。
- 2026-08-22：fresh 5.1 related通过`238/238`，零skip/failure且build diagnostics全零；下一步独立fresh serial normal，两个真实opt-in继续unset。
- 2026-08-22：fresh serial normal通过`1255/1254/1/0`且build diagnostics全零，唯一skip为真实Keychain opt-in测试；文件fallback继续。下一步四平台unsigned generic Debug，不操作Simulator。
- 2026-08-22：串行读回`Normal.xcresult` tests tree，确认唯一skip精确为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`；上轮summary/build-result与tests tree并发读取同一bundle触发内部`database.sqlite3`移动竞争，测试本身不受影响，本轮未重跑suite。
- 2026-08-22：四平台unsigned generic Debug `/private/tmp/LuneX-19-5_1-platform-builds.Om075Y`顺序通过`4/4`；四份structured build result串行确认`succeeded / 0 error / 0 warning / 0 analyzer warning`。首次universal定位脚本错误假定`LuneX.app`而未找到产物；修正为实际`LuneX-macOS.app/Contents/MacOS/LuneX-macOS`后确认`x86_64 arm64`，没有重复build或操作Simulator。
- 2026-08-22：已同步Task 5.1 OpenSpec design/accessibility spec、native product workflow contract、completion roadmap与三份planning，记录typed/localized semantic descriptor、稳定ID、role/value/hint/eligibility/destructive、PIN/endpoint隐私、`5/238/1255/4`证据与physical VoiceOver/Voice Control边界。Task仍保持pre-mark `26/48 next 5.1`，下一步generator双跑、strict与repository pre-gate。
- 2026-08-22：generator前后连续两次`project.pbxproj` SHA-256稳定为`4214a283c9e353456098dba5504f2cef3cf7cabd78ff2d4c51a2d34060b2f04f`，OpenSpec strict validation通过；5.1仍未勾选，下一步fresh repository pre-gate。
- 2026-08-22：fresh repository pre-gate `/private/tmp/LuneX-19-5_1-repository-pre.2vaeVN`完整通过remote baseline、11文件scope、source membership、semantic completeness/privacy、authority、strict pre-mark `26/48 next 5.1`、stable project、retained `5/238/1255/4`、唯一Keychain skip、disabled opt-ins、零LuneX build/test进程与diff检查。现已仅勾选5.1，预期`27/48 next 5.2`。
- 2026-08-22：fresh post-mark `/private/tmp/LuneX-19-5_1-final-state.cLptxe`只读通过strict、`27/48 next 5.2`、12文件scope、唯一5.1 checkbox、稳定project、retained evidence与disabled opt-ins；下一步精确清理5.1临时证据。
- 2026-08-22：19个明确`/private/tmp/LuneX-19-5_1-*`路径已逐项用绝对`find <exact> -depth -delete`清理，prefix零残留；未使用宽泛删除或触碰仓库cache。下一步cleanup后final diff/authority audit。
- 2026-08-22：cleanup后authority复读发现runtime contract两处和roadmap一处仍把整个5.x列作later/pending；已精确改为5.1 typed semantic descriptor完成、5.2至5.6与physical gate仍pending。production/test不变，下一步完整只读final audit。
- 2026-08-22：cleanup final audit通过最终12文件、846行semantic source、六类ID/surface、5新增/0删除/0 skip测试、privacy/destructive/eligibility、唯一5.1 checkbox、strict `27/48 next 5.2`、稳定project、零artifact/opt-in/process及`a2386ea`三方基线；准备精确stage、commit、push、fetch。
- 2026-08-22：Task 5.1以`6a94c68 Define localized product semantics`提交推送，fetch/ls-remote确认三方SHA一致且工作树clean；OpenSpec `27/48 next 5.2`。启动5.2审计，确认dashboard仅iOS compact单列，macOS/iPad窄窗口与host/pairing/apps固定HStack是当前缺口；下一步production/test编辑。
- 2026-08-22：5.2 production/test首轮完成；fresh macOS focused `/private/tmp/LuneX-19-5_2-focused.jmRbGA`通过pure layout与adaptive source合同`2/2`，structured build diagnostics全零。下一步related UI/runtime矩阵。
- 2026-08-22：5.2首轮13类并行related `/private/tmp/LuneX-19-5_2-related.bWtX3d`结构化完成`240/238/0/2`且build diagnostics全零；两个时序失败分别为pairing `requestTimeout`和already-stopping状态仍为`streaming`。该轮不计最终验收，下一步分别从fresh evidence串行定向复验，禁止直接重复原并行命令。
- 2026-08-22：两个首轮失败项在fresh独立DerivedData、禁用parallel testing下分别结构化`1/1`通过且build diagnostics全零，确认没有5.2 production路径回归证据；下一步完整13类related改为fresh串行运行。
- 2026-08-22：fresh完整串行related `/private/tmp/LuneX-19-5_2-related-serial.CmIwbs`结构化通过`240/240`且build diagnostics全零，首轮并行失败已闭合。下一步独立fresh serial normal，Keychain/live-host opt-in保持unset。
- 2026-08-22：fresh serial normal `/private/tmp/LuneX-19-5_2-normal.KP9sEP`结构化通过`1257/1256/1/0`且build diagnostics全零；唯一skip精确为真实Keychain opt-in测试，文件fallback继续。下一步四平台unsigned generic Debug，不操作Simulator lifecycle。
- 2026-08-22：四平台unsigned generic Debug `/private/tmp/LuneX-19-5_2-platform-builds.ilPh0L`顺序通过`4/4`，四份structured diagnostics全零且macOS为`x86_64 arm64`；未操作Simulator。已同步5.2 OpenSpec design/spec、runtime contract、roadmap与planning边界，下一步generator双跑、strict与repository pre-gate。
- 2026-08-22：generator前后双跑project SHA-256稳定为`4214a283...b04f`且工程零diff，OpenSpec strict valid；5.2仍为pre-mark `27/48 next 5.2`，下一步fresh repository pre-gate。
- 2026-08-22：首个repository pre-gate包装器因JavaScript将shell `${name+x}`误作模板插值，在shell前`ReferenceError`退出且零子命令/副作用；已记录并将用无`${...}`环境检查从fresh目录完整重跑。
- 2026-08-22：corrected repository gate前8组及final opt-in/process通过，但最后多文件`rg -c`计数被误作单整数而退出；未修改仓库或checkbox，本轮不计验收，下一轮改用汇总计数从fresh目录完整重跑。
- 2026-08-22：fresh repository pre-gate `/private/tmp/LuneX-19-5_2-repository-pre-final-r2.d1gUM3`完整通过九组检查；现只勾选5.2，预期OpenSpec `28/48 next 5.3`，不重复test/build/generator或操作Simulator。
- 2026-08-22：post-mark `/private/tmp/LuneX-19-5_2-final-state.eVCutC`只读通过strict、`28/48 next 5.3`、11文件scope、唯一5.2 checkbox、稳定project、retained evidence与disabled opt-ins；下一步精确清理5.2临时证据。
- 2026-08-22：5.2 cleanup的25个绝对删除调用已执行，但helper变量`path`覆盖zsh PATH，末尾非绝对`find`验证失败；删除范围未扩张，下一步用绝对`/usr/bin/find`核对并只补清明确残留。
- 2026-08-22：绝对`/usr/bin/find`确认全部25个5.2临时证据路径已清理且prefix零残留；未使用宽泛删除或触碰仓库cache。下一步cleanup后final diff/authority audit。
- 2026-08-22：cleanup后UI合同复读发现Apps header首选HStack未固定整体intrinsic width，无法保证超长本地化文本触发vertical fallback；首个补丁因空hunk格式被原子拒绝，corrected补丁已补HStack fixedSize、强化精确source test并暂时取消5.2勾选。下一步从fresh证据重跑全部最终门。
- 2026-08-22：修正后fresh `/private/tmp/LuneX-19-5_2-final-verification.h7O9Rb`再次通过focused `2/2`、serial related `240/240`、serial normal `1257/1256/1/0`与四平台generic Debug `4/4`，structured diagnostics全零、唯一Keychain skip、macOS universal。下一步generator/strict/repository pre-gate。
- 2026-08-22：修正后generator/strict及最终repository pre-gate完整通过，包含Apps header整体fixedSize精确锚点与fresh `2/240/1257/4` evidence；现重新只勾选5.2，下一步只读post-mark。
- 2026-08-22：修正后最终post-mark只读通过strict、`28/48 next 5.3`、11文件scope、唯一5.2 checkbox、stable project、disabled opt-ins与零进程；下一步清理single fresh evidence root。
- 2026-08-22：修正后single fresh evidence root及path已逐项精确清理，5.2 prefix零残留且未触碰仓库cache；下一步cleanup final audit，通过后提交推送。
- 2026-08-22：cleanup final audit通过最终11文件、adaptive/App header fallback、94新增/0删除测试行、authority、strict `28/48 next 5.3`、stable project、零artifact/opt-in/process及`6a94c68`三方基线；准备提交推送。
- 2026-08-22：Task 5.2以`82fd471 Adapt workflow layouts to narrow windows`提交推送，三方SHA一致且工作树clean；OpenSpec `28/48 next 5.3`。5.3审计确认Add Host/Pairing/stream缺typed hardware-keyboard focus/default/cancel合同，且当前默认forward Command-Q/Tab/H违反system-reserved-local要求；下一步production/test编辑。
- 2026-08-22：Task 5.3 production与focused测试接线：新增typed Add Host/Pairing/stream focus policy、native default/cancel/Command-S、显式Voice Control名称；legacy shortcut字段保留但新默认/runtime/lower adapter/UI语义均固定Always local。首轮测试定位裸glob错误已记入计划且无副作用；下一步编译与focused测试。
- 2026-08-22：fresh macOS focused `/private/tmp/LuneX-19-5_3-focused.kHW6Tc`通过7个新增/受影响合同，structured `7/7`且build diagnostics全零；SwiftUI focus modifier链完成warnings-as-errors编译。下一步fresh串行related矩阵。
- 2026-08-22：首轮fresh串行related `/private/tmp/LuneX-19-5_3-related-serial.dOPeTZ`结构化`218/216/1/1`、build diagnostics全零；唯一失败为Add Host source测试仍期待旧`.address`。已更新为typed `.manualHostAddress`，下一步fresh完整重跑，不复用失败轮验收。
- 2026-08-22：修正后fresh串行related `/private/tmp/LuneX-19-5_3-related-serial-r2.B0WeOQ`完整通过`218/217/1/0`且build diagnostics全零，唯一skip为真实Keychain opt-in；下一步独立fresh serial normal。
- 2026-08-22：独立fresh serial normal `/private/tmp/LuneX-19-5_3-normal-serial.lUkIxy`结构化通过`1259/1258/1/0`且build diagnostics全零，唯一skip为真实Keychain opt-in；下一步四平台unsigned generic Debug，不操作Simulator。
- 2026-08-22：四平台build首轮 `/private/tmp/LuneX-19-5_3-platform-builds.FSXIpy`的macOS universal与iOS/iPadOS成功，tvOS精确失败于10处SDK unavailable `keyboardShortcut`，visionOS因fail-fast未运行。首个条件编译补丁上下文不匹配被原子拒绝；corrected补丁已将shortcut modifier限制到macOS/iOS，不改变其他平台accessibility/focus。下一步fresh完整4平台重跑。
- 2026-08-22：corrected fresh四平台 `/private/tmp/LuneX-19-5_3-platform-builds-r2.bF0V1U`顺序通过`4/4`，四份structured diagnostics全零且macOS为`x86_64 arm64`；未操作Simulator。authority大补丁因换行假设被原子拒绝后已拆分同步5.3 OpenSpec design/spec、两份runtime contract、roadmap与planning边界，下一步generator双跑、strict与repository pre-gate，checkbox仍未勾选。
- 2026-08-22：条件编译修正后的single fresh最终候选 `/private/tmp/LuneX-19-5_3-final-verification.gvmj1Y` 重新通过focused `7/7`、serial related `218/217/1/0`与serial normal `1259/1258/1/0`；三份structured build diagnostics全零，唯一skip精确为显式opt-in真实Keychain round-trip。两个真实opt-in均unset、无残留xcodebuild/xctest且未操作Simulator；下一步generator双跑、strict与repository pre-gate。
- 2026-08-22：generator双跑与strict通过；首个repository pre-gate在scope/remote等前置检查后因条件编译正则把任意`#if os(tvOS)`误作shortcut泄漏而提前退出，且后续BSD `find -perm +111`可执行文件定位同样不可靠。本轮没有production/test/OpenSpec checkbox或runtime副作用；corrected gate改为逐个shortcut向前检查最近平台guard并直接定位`.app/Contents/MacOS/LuneX`，从fresh目录完整重跑。
- 2026-08-22：记录上述门禁错误时的跨`progress.md`/`task_plan.md`补丁因task plan上下文取自错误文件而被`apply_patch`原子拒绝，零文件修改；已读取精确当前段落并拆分修正，不重复旧上下文。
- 2026-08-22：corrected repository gate r2在scope/remote/shortcut guard通过后因静态断言错误要求focus常量使用显式类型与点语法而退出；实际源码为等价的`ProductKeyboardFocusTarget.manualHostAddress/streamHideControls`且focused测试已通过。定位helper首轮又因zsh只读变量名`status`在任何断言前退出，改用`rc`后精确确认仅这两个source pattern过窄。两轮均无仓库/checkbox/runtime副作用；r3按实际格式从fresh目录完整重跑。
- 2026-08-22：fresh repository pre-gate r3 `/private/tmp/LuneX-19-5_3-repository-pre-r3.DyVGzn`完整通过20文件scope、remote baseline、focus/shortcut/reserved-local/test/authority、stable generator、最终`7/218/1259/4` evidence、唯一Keychain skip、disabled opt-ins与零process；现只勾选5.3并推进到`29/48 next 5.4`，下一步只读post-mark。
- 2026-08-22：fresh post-mark `/private/tmp/LuneX-19-5_3-final-state.1Yy8NN`只读通过strict、OpenSpec `29/48 next 5.4`、21文件scope、唯一5.3 checkbox、stable project、retained `7/218/1259/4`、disabled opt-ins与零process；未重复行为门。最终逐层diff审计未发现阻断项，5.4/5.5命中仅为pending边界；下一步精确清理全部5.3临时证据。
- 2026-08-22：受限枚举并逐路径删除25个`/private/tmp/LuneX-19-5_3*` task path及2个辅助test-tree JSON；prefix与辅助路径残留均为0，未触碰仓库cache、Keychain或Simulator。下一步cleanup final audit，通过后独立提交推送。
- 2026-08-22：首轮cleanup final audit在测试完整性断言处退出：它把`testForwardedCommandKeyEquivalentIsCapturedWithoutLocalHandling`语义重命名为`testCommandKeyEquivalentAlwaysRemainsLocalWithoutRemoteSamples`误作无替代测试删除。新测试已由focused/related/normal直接执行通过且完整suite总数从1257增至1259；仓库/checkbox/runtime无副作用。r2改为精确要求旧名删除、新名新增且禁止其他test function删除/XCTSkip新增。
- 2026-08-22：corrected cleanup final audit r2 `/private/tmp/LuneX-19-5_3-cleanup-final-audit-r2.ydYwap`完整通过21文件scope、OpenSpec `29/48 next 5.4`、stable project、focus/shortcut/reserved-local合同、精确一对test rename、零新增skip、disabled opt-ins、零process和remote baseline。下一步删除两轮audit临时路径并做提交前零残留检查。
- 2026-08-22：Task 5.3以`43802f1 Add native keyboard workflow focus`提交推送并确认三方SHA一致、工作树clean；进入5.4审计。缺口为零Reduce Motion接线、PiP `36x32`及custom action无统一44pt target、RemoteAppTile color-only selection/两行截断与diagnostic severity颜色依赖；下一步pure policy、SwiftUI modifier/state marker及focused测试。
- 2026-08-22：5.4首轮测试检索重复使用不存在的`*Accessibility*`裸glob，zsh在该子命令执行前退出；其他并行只读结果有效、仓库无变化。后续仅使用明确路径或`rg --files`，不再使用可空裸glob。
- 2026-08-22：5.4首个core/RootView大补丁因多段上下文不匹配被原子拒绝、零修改；拆分后完成44pt/motion pure policy、38处action target调用、PiP尺寸修正、app selected与diagnostic severity非颜色文本、overlay Reduce Motion接线及2条focused测试。下一步fresh macOS warnings-as-errors focused。
- 2026-08-22：首轮fresh focused结构化通过`2/2`且build diagnostics全零；随即复读发现非macOS Sidebar的custom NavigationRow仍只用accent color表达选择。已补显式checkmark与Selected/Not selected accessibility value并扩展source test，首轮证据降为补强前辅助证据，下一步fresh focused r2。
- 2026-08-22：补强后fresh focused r2 `2/2`、13类serial related `244/244`、serial normal `1261/1260/1/0`和四平台generic Debug `4/4`全部结构化零diagnostic且macOS universal；唯一skip为真实Keychain opt-in，两个真实opt-in unset、未操作Simulator。已同步OpenSpec/runtime/roadmap/planning authority，下一步generator/strict/repository pre-gate，checkbox仍未勾选。
- 2026-08-22：本轮`create_goal`因旧`blocked`目标仍被工具视为unfinished而拒绝重建；无仓库或runtime副作用，继续以OpenSpec和planning为权威。generator双跑hash稳定为`4214a283c9e353456098dba5504f2cef3cf7cabd78ff2d4c51a2d34060b2f04f`且strict validation通过。
- 2026-08-22：5.4 repository gate首轮因零匹配`rg -c`返回空字符串退出；r2修正后又因宽泛进程检索匹配脚本自身报告文本退出。两轮均只读；r3 `/private/tmp/LuneX-19-5_4-repository-pre-r3.84UClZ`改用`awk`与`pgrep -x`后完整通过remote/scope/source/OpenSpec/project/evidence/Keychain/process边界。
- 2026-08-22：已在pre-gate后只勾选OpenSpec Task 5.4；未重复test/build/generator。下一步只读post-mark确认`30/48 next 5.5`，随后精确清理`/private/tmp/LuneX-19-5_4*`并完成提交前审计。
- 2026-08-22：post-mark final-state `/private/tmp/LuneX-19-5_4-final-state.mwPuZ4`通过，确认`30/48 next 5.5 ready`、strict valid、11文件且tasks只有5.4 checkbox变化；stable project、38处modifier、无5.5 focus新增、opt-in/process边界均成立。未重复行为门。
- 2026-08-22：首个cleanup脚本因`rm -f`被策略在启动前拒绝，零删除与零副作用；改用逐项精确`find -depth -delete`后清理17个`/private/tmp/LuneX-19-5_4*`路径，prefix残留0且未触碰仓库cache。下一步cleanup final audit与提交推送。
- 2026-08-22：cleanup final audit `/private/tmp/LuneX-19-5_4-cleanup-final-audit.8vAuuY`完整通过11文件、`30/48 next 5.5`、strict/stable project、production/5.5隔离、测试`2 add / 0 delete / 0 new skip`、authority、安全与remote baseline；下一步删除当前audit路径、零残留检查并提交推送。
- 2026-08-22：Task 5.4以`9992ede Enforce accessible workflow interaction`提交推送并确认三方SHA一致、工作树clean；进入5.5。审计确认tvOS surface/overlay使用两个FocusState，visionOS Hide Controls未从actual input eligibility禁用；下一步pure policy/reachability、共享focus wiring与focused tests。
- 2026-08-22：5.5测试组合补丁因helper锚点不匹配被原子拒绝、零修改，拆分后完成production/test接线。首轮focused在0 tests编译阶段因既有直接initializer缺少新增reachability参数失败，production无诊断；增加fail-closed默认值的显式initializer后将从fresh证据目录重跑。
- 2026-08-22：focused r2结构化通过`5/5`且build diagnostics全零；审读补强空capability语义为明确“No current remote input path is available.”并保持按钮disabled，r2不计最终候选。首个组合补强patch因hunk格式在解析阶段拒绝、零修改，拆分后成功；下一步fresh focused r3。
- 2026-08-22：补强后fresh focused r3结构化通过`5/5`且build diagnostics全零，覆盖tv focus policy/shared binding和vision actual reachability/source wiring；下一步serial related平台ownership/input矩阵。
- 2026-08-22：首轮serial related为`316/315/0/1`，唯一失败是既有RootView source test仍以删除的private focus enum划分片段；production与其他315项通过、structured diagnostics全零。已更新为TVStreamControls边界和共享binding断言；同bundle并行辅助查询触发一次xcresult sqlite移动竞争，后续严格串行读取。下一步先单项验证修正，再fresh完整related。
- 2026-08-22：source修正单项fresh `1/1`通过；related r2唯一vision AppModel session等待超时也在独立fresh `1/1`通过。第三个完整fresh serial related最终`316/316`且structured diagnostics全零，闭合两轮干扰；下一步fresh serial normal。
- 2026-08-22：fresh serial normal通过`1263/1262/1/0`且唯一skip精确为真实Keychain opt-in；首个四平台gate在macOS app编译发现conditional overlay initializer后链式modifier语法错误。已以`Group`统一包裹分支；先前focused/related/normal降为修正前辅助证据，下一步从fresh根重跑全部门。
- 2026-08-22：Group修正后focused `6/6`、related `316/316`、normal `1263/1262/1/0`通过；四平台中macOS/iOS通过后tvOS暴露conditional binding的memberwise参数顺序错误。已把binding声明移到workspace/layout之后，行为与调用文本不变；下一步再次fresh闭合全部最终门。
- 2026-08-22：参数顺序修复后的最终fresh候选已闭合：focused `/private/tmp/LuneX-19-5_5-focused-final2.TGLWJI`为`6/6`，11类serial related `/private/tmp/LuneX-19-5_5-related-final2.GCMCDW`为`316/316`，serial normal `/private/tmp/LuneX-19-5_5-normal-final2.NHyDRv`为`1263/1262/1/0`且唯一skip为显式真实Keychain测试，四平台generic Debug `/private/tmp/LuneX-19-5_5-platform-builds-final2.B5qORm`为`4/4`并全部structured diagnostics为0、macOS universal。两个真实opt-in unset且未操作Simulator；下一步authority、generator、strict与repository pre-gate，checkbox仍未勾选。
- 2026-08-22：Task 5.5 authority已同步；generator前及连续两次运行后的project SHA-256均为`4214a283c9e353456098dba5504f2cef3cf7cabd78ff2d4c51a2d34060b2f04f`、工程零drift，`openspec validate complete-native-product-workflows --strict`通过。当前仍为pre-mark `30/48 next 5.5`，下一步fresh repository pre-gate。
- 2026-08-22：fresh repository pre-gate `/private/tmp/LuneX-19-5_5-repository-pre.Vn4xjX`完整通过remote/13文件scope、tv focus/vision reachability、test delta、authority、pre-mark strict、stable project、最终`6/316/1263/4` evidence、唯一Keychain skip、disabled opt-ins、零process与diff边界；现仅勾选5.5，下一步只读确认`31/48 next 5.6`。
- 2026-08-22：首个post-mark wrapper因checkbox diff正则遗漏Markdown bullet而在只读断言退出；诊断确认`31/48 next 5.6`、14文件、唯一5.5替换、stable project、opt-ins unset与零process均正确。无production/test/runtime副作用，下一步用修正正则从fresh目录完整重跑。
- 2026-08-22：corrected post-mark `/private/tmp/LuneX-19-5_5-final-state-r2.6HIYOJ`只读通过strict、`31/48 next 5.6`、14文件、唯一5.5 checkbox、stable project、disabled opt-ins与零process；未重复行为门。下一步精确清理5.5 evidence并执行cleanup final audit。
- 2026-08-22：已逐项精确清理41个`/private/tmp/LuneX-19-5_5*`路径，prefix残留0；未使用宽泛删除或触碰仓库cache。下一步cleanup final audit与独立提交推送。
- 2026-08-22：cleanup final audit `/private/tmp/LuneX-19-5_5-cleanup-final-audit.qbQpIM`完整通过14文件、`31/48 next 5.6`、source/test/authority、stable project、唯一5.5 checkbox、disabled opt-ins、零process、remote baseline与diff边界；下一步删除audit路径、零残留检查并提交推送。
- 2026-08-22：Task 5.5以`cb7ce3b Complete TV and Vision focus semantics`提交推送并确认三方SHA一致、工作树clean；OpenSpec进入`31/48 next 5.6`。开始九维accessibility application matrix覆盖审计，不提前实现6.x/7.x或操作Simulator。
- 2026-08-22：5.6新增两条真实AppModel application accessibility矩阵，production零修改；首轮fresh focused在0 tests编译阶段因两处`XCTAssertTrue(await stopStream(...))`触发async XCTest autoclosure错误。现已改为先await局部Bool再断言，失败bundle不计验收；下一步fresh focused重跑。重新创建goal仍被旧blocked记录拒绝，无仓库/runtime副作用。
- 2026-08-22：编译修正后的5.6 focused r2为`2/1/0/1`，第一条通过；第二条在tvOS首个surface focus得到默认overlay对应的`.localControls`。已按既有application合同在geometry前用checked workspace API显式隐藏overlay，不扩大timeout；该失败轮不计验收，下一步fresh focused r3。
- 2026-08-22：5.6 focused r3仍为`2/1/0/1`，tvOS已通过，visionOS暴露真实投影缺口：overlay release完成后presentation仍为input unavailable。现测试显式建立/回灌actual coordinator snapshot；AppModel在保持window/scene/ownership/revision/capability集合一致性检查下，改用当前vision input snapshot反映`.local(.overlayVisible)`，并复用同一geometry恢复capture。下一步fresh focused验证。
- 2026-08-22：focused r4仍为`2/1/0/1`，编译全零；测试构造的vision coordinator缺display/audio，snapshot未进入active，AppModel正确fail closed。已补齐同revision display/audio组件，不调整production或timeout；下一步fresh focused r5。
- 2026-08-22：focused r5仍为`2/1/0/1`；确认coordinator component应用会推进并重标semantic revision，geometry admission保留source revision，先前production直接revision相等检查过严。现字段级验证owner/surface/geometry/input generation/capability set后，以coordinator revision和runtime actual focus eligibility构造投影，保持stale fail-closed；下一步fresh focused r6。
- 2026-08-22：5.6 fresh focused r6结构化通过`2/2`且build diagnostics全零，闭合九维application accessibility矩阵与vision实际投影修复；两个真实opt-in unset、零残留test/build进程、未操作Simulator。下一步fresh serial related矩阵。
- 2026-08-22：5.6 fresh serial related结构化通过`335/335`且build diagnostics全零，既有AppModel/workflow/tvOS/visionOS/input/HDR/audio/mobile合同未回归。下一步独立fresh serial normal，仍只允许真实Keychain opt-in一项skip。
- 2026-08-22：5.6 fresh serial normal `/private/tmp/LuneX-19-5_6-normal-serial.pfqPxf/Normal.xcresult`结构化通过`1265/1264/1/0`、0 expected failure，build `succeeded`且error/warning/analyzer warning全零；唯一skip精确为`testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`。普通测试保持文件identity fallback且两个真实opt-in均未启用；下一步fresh四平台unsigned generic Debug build，不操作Simulator。
- 2026-08-22：5.6 fresh四平台 `/private/tmp/LuneX-19-5_6-platform-builds.Tujmy9`顺序通过macOS、iOS/iPadOS、tvOS、visionOS unsigned generic Debug `4/4`，每份structured build均`succeeded/0/0/0`；macOS executable为`x86_64 arm64` universal。两个真实opt-in unset且未操作Simulator lifecycle；下一步authority、generator、strict与repository pre-gate。
- 2026-08-22：5.6 authority已同步九维application matrix、vision source/coordinator revision域与current runtime focus eligibility投影；generator三次hash均为`4214a283c9e353456098dba5504f2cef3cf7cabd78ff2d4c51a2d34060b2f04f`且project零drift，OpenSpec strict valid。当前保持pre-mark `31/48 next 5.6`，下一步fresh repository pre-gate。
- 2026-08-22：fresh repository pre-gate `/private/tmp/LuneX-19-5_6-repository-pre.VRUkYi`通过remote baseline、9文件scope、production/test/authority、pre-mark `31/48 next 5.6` strict、stable project、最终`2/335/1265/4` evidence、唯一Keychain skip、disabled opt-ins、零process与diff边界。已只勾选5.6，当前应为`32/48 next 6.1`；下一步只读post-mark，不重复行为门。
- 2026-08-22：post-mark `/private/tmp/LuneX-19-5_6-final-state.d65lHB`只读通过strict、`32/48 next 6.1`、10文件scope、唯一5.6 checkbox、stable project、authority、disabled opt-ins、零process与diff边界；未重复行为门或操作Simulator。下一步精确清理5.6 evidence并做cleanup final audit。
- 2026-08-22：已逐项精确清理20个`/private/tmp/LuneX-19-5_6*`路径，包含失败/最终xcresult、marker、generator log与门禁报告，prefix残留0；未触碰其他task evidence或仓库cache。下一步cleanup final audit与提交推送。
- 2026-08-22：cleanup final audit `/private/tmp/LuneX-19-5_6-cleanup-final-audit.ORsfpF`完整通过10文件scope、`32/48 next 6.1` strict、唯一5.6 checkbox、production/test/authority、stable project、disabled opt-ins、零process、remote baseline与diff边界；删除audit路径并做提交前零残留检查后独立提交推送。
- 2026-08-22：Task 5.6以`c022846 Complete accessibility application matrix`提交推送并确认三方SHA一致、工作树clean；进入6.1。审计定位launch-unpaired、decoder/media与unknown application/platform三类typed issue mapping缺口，下一步closed code/pure mapper/AppModel terminal mapping与focused tests。
- 2026-08-22：6.1首轮focused在补强前通过`13/13`且build零诊断；补强r2因新增测试在media continuation建立前finish导致错误丢失并挂起，已终止xcodebuild/xctest。现改用control provider test-only arbitrary-error finish并在streaming后注入，不改production或timeout；挂起轮不计验收。
- 2026-08-22：修正后6.1 fresh focused r3结构化通过`14/14`且build diagnostics全零，闭合closed code/category/action、adversarial diagnostic隔离、真实media映射和checked launch-pairing recovery；下一步serial related矩阵。
- 2026-08-22：6.1 fresh serial related通过`237/237`且build diagnostics全零；独立serial normal通过`1268/1267/1/0`、0 expected failure且build diagnostics全零，唯一skip为显式真实Keychain round-trip。下一步四平台generic Debug，不操作Simulator。
- 2026-08-22：6.1 fresh四平台generic Debug通过`4/4`且structured diagnostics全零，macOS为`x86_64 arm64` universal；已同步closed mapper、`14/237/1268/4`证据与后续proof边界。下一步generator双跑、strict与repository pre-gate。
- 2026-08-22：6.1 generator稳定、strict valid，repository pre-gate `/private/tmp/LuneX-19-6_1-repository-pre.LXuj3u`完整通过11文件scope、mapper/AppModel/test/authority、pre-mark `32/48`、`14/237/1268/4` evidence、唯一Keychain skip与安全边界。已只勾选6.1，当前应为`33/48 next 6.2`；下一步只读post-mark。
- 2026-08-22：6.1 post-mark通过`33/48 next 6.2`、12文件scope、唯一checkbox与安全边界；随后逐项精确清理9个`/private/tmp/LuneX-19-6_1*`路径且prefix残留0。下一步提交前final audit，不重复test/build。
- 2026-08-22：6.1 cleanup-final audit通过三方baseline、`33/48 next 6.2`、12文件、28-code mapper、3新增/0删除/0 skip测试、authority、stable project与零artifact/opt-in/process/diff边界；准备独立提交推送。
- 2026-08-26：恢复现场确认`main == origin/main == remote 74dda0593f58190650b9b8fcc045bf60393bb9dd`且工作树clean；OpenSpec当前10个change、`complete-native-product-workflows 33/48`。本轮未启用Keychain/live-host opt-in，未查询、创建、启动或关闭Simulator，也未操作host、签名或物理设备。
- 2026-08-26：完成macOS-first只读审计。确认120个source、90个Swift test；pairing/control/input有具体production provider，但default inventory缺video/audio receive provider并被`SessionMediaEnvironment`显式fail closed。窗口occlusion/focus/screen、EDR headroom和listener head tracking已实际接线但仍缺physical/live/signed证明。
- 2026-08-26：创建OpenSpec `prioritize-macos-product-completion`，已生成proposal、design、`macos-first-delivery-governance` spec与27项M0-M9 tasks；没有改写其他change的历史checkbox或archive任何active change。
- 2026-08-26：新增`docs/macos-first-completion-plan.md`，发布proof-tier定义、15区macOS gap matrix、M0-M9 critical path、每阶段exit gate、existing-change sequencing与rollback；同步`openspec/config.yaml`、`task_plan.md`和`docs/runtime-completion-roadmap.md`，将非macOS产品工作改为maintenance freeze。
- 2026-08-26：M0最终自验通过：新change strict valid，`openspec validate --all --strict`为`11/11`，旧七个active change进度保持`54/61`、`28/29`、`32/33`、`34/35`、`35/36`、`49/50`、`33/48`；cross-reference、diff check、production scope zero、两个真实opt-in unset、`HEAD == origin/main == remote 74dda05`全部通过。已勾选M0 tasks 1.1-1.5；下一实现点为M1具体production video/audio receive provider，而不是旧阶段19 task 6.2。
- 2026-08-26：M0收口首个`apply_patch`因同一请求包含两个针对`task_plan.md`的update block而在验证阶段原子拒绝，零文件修改；合并为单一block后成功，不重复任何测试、runtime或设备操作。
- 2026-08-26：M0完成后尝试把旧blocked全平台goal替换为M1-M9 macOS-first目标，`create_goal`仍以`cannot create a new goal because this thread has an unfinished goal`拒绝；`get_goal`同时报告旧goal为`blocked`。该控制面矛盾无仓库/runtime副作用，无法在本轮从agent侧修复或声称已重建。
- 2026-08-26：用户指示进入M1；恢复检查确认`main == origin/main 422ad55c54c6bb43f83bdc399d624c9b2304ade5`且工作树clean，OpenSpec `prioritize-macos-product-completion`为`5/27`、next Task 2.1。普通验证继续保持`LUNEX_RUN_KEYCHAIN_TEST`和`LUNEX_RUN_LIVE_HOST_TEST` unset，不操作Simulator、Keychain、host、签名或物理设备。
- 2026-08-26：M1 Task 2.1只读接线审计确认两个关联阻塞：default inventory缺少具体video/audio receiver；RTSP bootstrap不发布negotiated configuration，导致media environment即使有provider也不会启动。已把receiver wire、ping、取消/teardown、FEC显式降级及media-encryption fail-closed边界同步到planning authority；下一步审读现有configuration/preferences/tests后开始production实现。
- 2026-08-26：Task 2.1首轮production实现新增共享UDP receive runtime、严格audio RTP parser、video/audio provider、RTSP negotiated configuration和default inventory接线。首轮warnings-as-errors `build-for-testing`只在新增文件报两处access-level错误：internal provider typealias引用private generic runtime；其他编译输出无诊断。已改为独立internal channel/time typealias，失败轮不计验收且没有执行测试、Keychain、live host或Simulator。
- 2026-08-26：access-level修复后warnings-as-errors编译通过；首轮focused执行25项、24通过、1失败。唯一失败是replacement测试丢弃返回stream后按合同立即触发consumer cancellation，尚未进入stub blocked receive；production cancellation、其他5项media receiver、14项RTSP bootstrap、4项description和default inventory均通过。已改为保留并消费两代stream，不放宽等待或修改production；该失败轮不计最终验收。
- 2026-08-26：修正fixture并补周期custom ping与consumer-cancel传播后focused为`26/26`。首轮fresh related串行执行`251`项、`248`通过、`3`失败；三项均为`SessionRecoveryTests`仍按旧control-only事件序列断言，实际新增的每代`.negotiated`均携带正确session/endpoints/input key。已更新恢复断言验证初始/新鲜key配置、事件顺序与replacement隔离，不修改production；失败矩阵不计最终验收。
- 2026-08-26：Task 2.1最终相关矩阵闭合为fresh recovery `13/13`、fresh related `251/251`、fresh normal macOS `1276/1275/1/0`，唯一skip为显式真实Keychain round-trip；macOS Debug/Release与iOS/tvOS/visionOS unsigned generic Debug全部通过。普通验证保持两个真实opt-in unset，未操作Simulator、host、签名或物理设备。
- 2026-08-26：最终人工审阅补充video/audio非16-byte ping payload拒绝与旧JSON缺失可选`pingPayload`兼容合同。fresh warnings-as-errors focused为`127/127/0/0`且build diagnostics `0/0/0`；没有重复全量或平台build。
- 2026-08-26：Task 2.1 pre-mark自验收通过。generator连续两次及生成前project SHA-256均为`f254e17979512f0ece95326565035e6b02cbc31935c3ea64bdf9490895dc9bd0`；保留产物确认macOS Debug/Release均为`x86_64 arm64` universal；change strict valid、全仓OpenSpec `11/11`、`git diff --check`、opt-in unset和零LuneX xcodebuild/xctest进程均通过。下一步同步authority并只勾选Task 2.1。
- 2026-08-26：authority同步后的辅助旧时态检索因zsh双引号内反引号触发`unmatched quote`，在检索前退出且无文件/runtime副作用；改用不含反引号的单引号固定模式重查为零当前态命中。pre-mark保持`5/27 next 2.1`后只勾选Task 2.1，下一步只读确认`6/27 next 2.2`。
- 2026-08-26：Task 2.1 post-mark只读验收通过：change与全仓strict为`11/11`、OpenSpec为`6/27 next 2.2`、tasks diff唯一checkbox变更为2.1、`git diff --check`通过、两个真实opt-in unset且零LuneX xcodebuild/xctest进程。M1仍为`in_progress`，live Sunshine与physical evidence没有被离线结果替代。
- 2026-08-26：Task 2.1以`11a9b85 Implement production media receivers`独立提交推送；fetch/ls-remote确认`HEAD == origin/main == remote 11a9b8502d52f5d9a6c2cee86b32c238e6380621`。首个cleanup wrapper因zsh特殊变量`path`覆盖`PATH`导致末尾clean检查未执行，第二个corrected wrapper又使用只读`status`退出；第三轮显式Bash使用`git_state`完成三方SHA、clean、零process和定向cleanup复核。
- 2026-08-26：进入Task 2.2，只读盘点现有3个imported paired/pinned host；当时本来只有`tanmy-white`在线，因此`PC-20260610OBZH`和`tanmy-deck`的2个timeout是预期离线结果。`tanmy-white`的configured GameStream endpoint为200，Web TLS证书与imported pin匹配，广告协议`7.1.431.-1`、兼容字段`3.23.0.74`、codec mask `0x00070301`；host报告busy，未执行任何session或host mutation。
- 2026-08-26：用户纠正Task 2.2口径：LuneX不得按Sunshine package version限制用户，package version最多是诊断/复现元数据，兼容性必须按服务端广告协议/codec能力和实际行为判定。缓存catalog已明确包含`Desktop`，因此它直接指定为`tanmy-white`的无破坏测试app；host/app名不做无意义脱敏，仍保护private key、certificate bytes、credentials、token和raw payload。
- 2026-08-26：已同步两个OpenSpec change、macOS-first/live matrix/runtime路线图、HDR/mobile/tvOS/visionOS验收合同和三份planning files。`implement-moonlight-session-runtime` 1.1改为server-advertised protocol/codec inventory并勾选，当前`55/61`；其他6字段若可获得只做可选诊断元数据。Task 2.2仍保持pre-mark `6/27`，等待strict/diff/process/opt-in自验。
- 2026-08-26：live matrix整文件首次delete/add组合patch以及后续跨文件大patch均在写入前验证失败，零部分修改。已改为小范围分组patch，没有重复host inventory、build、test、Simulator、Keychain或live session操作。
- 2026-08-26：Task 2.2 pre-mark自验通过：`prioritize-macos-product-completion`和`implement-moonlight-session-runtime`两个change均strict valid，全仓OpenSpec `11/11`，`git diff --check`通过，production/test/project零修改，两个真实opt-in unset，零LuneX xcodebuild/xctest进程。已只勾选Task 2.2，下一执行点为Task 2.3。
- 2026-08-26：Task 2.2 post-mark与人工diff审阅通过：新change `7/27 next 2.3`，旧runtime change `55/61`且剩余6项均为live/hardware任务；全仓strict `11/11`，tracked与新matrix均零whitespace error，源码/测试/工程零修改，opt-in unset，零xcodebuild/xctest进程。本项未执行build/test、Simulator、Keychain、live catalog/session或host mutation。
- 2026-08-26：继续Task 2.3。单次有界只读`/serverinfo`确认`tanmy-white`仍为`SUNSHINE_SERVER_BUSY`，`currentgame=881448767`(`Desktop`)；没有执行launch/resume/cancel/stop/catalog/input或host mutation。当前先审计可并行闭合的identity continuity和显式live harness，等现有会话自然结束。
- 2026-08-26：确认仓库尚无`LUNEX_RUN_LIVE_HOST_TEST`实现，Debug文件identity fallback当前不存在，且`AppModel` production默认`clientUniqueID`是随机UUID。下一步追踪identity/pairing数据模型与启动恢复路径，确认并修复真实连续性缺口。
- 2026-08-26：Task 2.3续接完成上游identity语义核对。Moonlight iOS与Moonlight-qt的全部HTTP命令均统一发送16字符`0123456789ABCDEF`；Qt另发每请求随机`uuid`，其settings中的lazy `uniqueid`当前无调用点。由此确认Qt证书/私钥可复用，但LuneX importer必须显式复现该wire ID，不能从证书猜测。下一步审计LuneX请求构造点，统一协议ID并补向后兼容、跨请求与Qt导入测试。
- 2026-08-26：identity相关测试定位的一条只读命令因不存在的`Tests/LuneXCoreTests/*Application*`裸glob被zsh拒绝；指定源文件读取已完成，仓库/runtime零副作用。后续仅用`rg --files`解析实际测试路径。
- 2026-08-26：Sunshine源码确认`uniqueid`只键控进行中的pairing临时状态；paired HTTPS授权和session归属按client certificate，当前`/cancel`不比较该值。由此修正实现方向：`ClientIdentityMaterial.protocolUniqueID`直接采用上游共享常量`0123456789ABCDEF`，本地UUID保持内部标识，现有JSON/Keychain无需schema迁移且已配证书不失效。
- 2026-08-26：identity store编码定位误用不存在的`Sources/LuneXCore/Persistence.swift`并只读失败；仓库/runtime零副作用。后续以实际source清单定位定义，确保importer写入的UUID/Data/Date格式与Swift synthesized Codable完全一致。
- 2026-08-26：确认Debug identity使用Swift默认Codable：UUID字符串、Data Base64、Date为2001 reference-date秒数；目录/文件权限分别要求0700/0600。准备修改`ClientIdentityMaterial`、PairingTransport、AppModel、Qt importer及focused tests，不触发Keychain、host或Simulator。
- 2026-08-26：已实现共享`0123456789ABCDEF` protocol ID并统一pairing与AppModel identity恢复/创建路径；Qt importer新增显式`--include-client-identity`、内存内PKCS#8转PKCS#1、Swift Codable格式和0700/0600权限，默认仍不复制private key。新增material/pairing/catalog/launch-resume-cancel及Python importer focused tests，下一步先做语法、隐私与warnings-as-errors验证。
- 2026-08-26：Python importer `2/2`通过，py_compile、diff check、隐私扫描和两个opt-in unset均通过。首轮Swift build-for-testing误用不存在的`LuneX` scheme并在编译前退出，0 source/test；下一步读取scheme清单后fresh重跑。
- 2026-08-26：实际`LuneXCoreTests` warnings-as-errors build-for-testing通过；focused xcresult结构化为`4/4/0/0`，覆盖material旧Codable、pairing五阶段、AppModel restart catalog与launch/resume/cancel同一wire ID。新增importer写入前certificate/private-key公钥匹配及CN检查；下一步重跑Python测试后执行本机显式Qt identity导入。
- 2026-08-26：importer证书/私钥匹配正负矩阵扩展后Python为`3/3`。真实写入前再加入`--identity-only`最小副作用模式与同目录0600临时文件原子替换，避免重写当前hosts/settings/catalog或留下半写private identity；下一步通过focused工具测试后仅写Debug identity。
- 2026-08-26：identity-only矩阵`4/4`通过后，已从本机Qt plist仅写`client_identity.debug.json`，没有重写hosts/settings/catalog；目录0700、文件0600、2662 bytes。首个Swift Security内存验证脚本仅因输出字符串转义编译失败，验证尚未执行且未打印材料；下一步修正脚本后只读复核。
- 2026-08-26：同一真实fallback通过Foundation/Security内存验收：707-byte cert、1193-byte RSA key、公钥匹配、签名验签成功、CN正确，未访问Keychain。随后host命令因`plutil || curl`结构可能发出2次相同有界只读`/serverinfo`，保守按2次记录；`tanmy-white`仍busy/current Desktop，停止本轮host查询且不执行catalog/launch/resume/cancel/stop/input。
- 2026-08-26：已更新live matrix identity precondition与Debug复用流程，明确显式identity-only命令、默认不复制private key、PKCS#8转换/匹配验证、原子写入与0700/0600权限；pairing/identity row仅记录local material verified，live mTLS/catalog仍pending，未勾选Task 2.3。
- 2026-08-26：identity修复full macOS normal结构化通过`1280/1279/1/0`、0 expected failure；唯一skip精确为`testRealKeychainIdentityRoundTripWhenExplicitlyEnabled`，普通测试继续只用file fallback。Python importer为`4/4`，Swift focused为`4/4`；下一步generator/strict/generic compatibility与repository audit。
- 2026-08-26：generator双跑project SHA稳定`f254e179...bd0`，OpenSpec strict全仓`11/11`；macOS Debug/Release及iOS/tvOS/visionOS generic Debug共`5/5` build通过、source error 0，每项唯一warning均为Xcode AppIntents metadata skip。universal检查因系统Bash 3.2不支持`${var,,}`而在读取前退出；将从现有产物用显式路径复核，不重复build。
- 2026-08-26：universal复核第二个只读路径假设错误：实际产物不叫`LuneX.app`，find为空且lipo只报空路径；不影响已成功build。下一步先枚举Products实际文件再单次lipo。
- 2026-08-26：从实际`LuneX-macOS.app/Contents/MacOS/LuneX-macOS`复核Debug/Release均为`x86_64 arm64` universal。已把16字符wire ID全流程一致、本地UUID不得上wire、显式Qt identity复用与restart continuity写入当前OpenSpec spec；Task 2.3仍因host busy及live矩阵未执行保持pending。
- 2026-08-26：首轮repository wrapper在验收脚本层发现cache删除predicate、合法PEM标签隐私pattern和当前shell进程自匹配三处问题；OpenSpec/protocol/fallback权限已通过，production/runtime无回归或副作用。下一轮使用精确cache路径、Base64材料pattern和process executable筛选从头复核。
- 2026-08-26：恢复工作后读取planning-with-files catchup、当前OpenSpec全部context与`7/27 next 2.3`状态。再次调用`create_goal`仍被控制面以旧blocked目标unfinished拒绝；零仓库/runtime副作用，已记入Task 2.3错误记录。
- 2026-08-26：identity continuity最终人工审阅发现production `PinnedHTTPSRequestExecutor`仅处理server pin，未提供客户端证书，因此Qt identity不会进入catalog/launch mTLS。已扩展executor从当前identity store读取并用`SecurityClientIdentityValidator`验证材料，missing/invalid在网络前fail closed，delegate同时响应server-trust和client-certificate challenge；补credential级、缺失与损坏identity回归，并收紧importer CN边界和`--identity-only` legacy删除说明。Task 2.3仍pending，下一步从fresh evidence执行Python、focused Swift与warnings-as-errors验证。
- 2026-08-26：mTLS首轮warnings-as-errors focused编译和`AppCatalogTests 11/11`通过；结构化结果揭示另外4个selector名称不对应实际方法，Xcode静默执行0项。该轮不计完整identity focused，下一步从新目录使用源码实际方法名执行4项，不重复错误selector。
- 2026-08-26：corrected identity focused从新目录通过`4/4`，完整macOS normal通过`1283/1282/1/0`，唯一skip为显式真实Keychain；五个隔离generic build全部成功且macOS两配置仍为`x86_64 arm64`，非macOS结果只计共享兼容。最终diff复核又将`AppModel`默认wire ID从随机值改为规范常量，避免初始identity load前的边角路径；因此将在最终门前重跑受影响focused与normal，不沿用变更前计数。
- 2026-08-26：精确最终实现上的warnings-as-errors identity/mTLS focused为`15/15`，macOS normal为`1283/1282/1/0`，唯一skip仍是显式真实Keychain；importer扩展exact CN与失败不覆盖后为`5/5`。AppModel默认wire ID修正后的macOS Debug/Release及iOS/tvOS/visionOS generic Debug重新`5/5`通过、source error 0，每项唯一warning为Xcode AppIntents metadata skip；非macOS结果不推进冻结平台状态。下一步执行repository final gate、定向清理、独立提交与推送，Task 2.3保持pending。
- 2026-08-26：最终定向清理首个zsh wrapper重复使用特殊变量`path`覆盖`PATH`，在任何删除前退出；仓库/evidence/runtime零变化。已记入错误记录，改用显式Bash、`evidence_path`和绝对find执行，不再重复该模式。
- 2026-08-26：corrected Bash清理删除了指定test evidence，但`__pycache__` predicate仍只匹配非空目录，重复了已有cache清理错误并留下两个目录；零源码/runtime副作用。改为逐个枚举cache目录后整棵depth-delete并断言零残留，同时定向清理交接列出的旧identity evidence/marker，保留最终platform build供后续启动。
- 2026-08-26：final repository gate先确认OpenSpec strict `11/11`，随后jq next-task表达式因缺少括号发生boolean/string `contains`类型错误并在其余门前退出；零仓库/runtime副作用。已记入错误记录，将从头以括号修正后的完整gate重跑，不把部分通过当最终结果。
- 2026-08-26：第二轮完整gate确认strict `11/11`、`7/27 next 2.3 pending`，随后`login:false` Bash因PATH不含Homebrew而在generator前找不到`xcodegen`；零仓库/runtime副作用。下一轮固定绝对xcodegen路径从头重跑。
- 2026-08-26：generator authority复核确认项目无`project.yml`，权威工具是`/usr/bin/ruby Tools/generate_xcodeproj.rb`而非XcodeGen；不安装无关工具。最终gate将以该Ruby生成器双跑和project SHA稳定为准并从头执行。
- 2026-08-26：identity/mTLS最终repository gate完整通过：OpenSpec strict全仓`11/11`，当前change`7/27 next 2.3 pending`；权威Ruby generator双跑及生成前project SHA均为`f254e179...bd0`；精确16文件scope、diff hygiene、Base64-like隐私扫描、identity文件未跟踪、fallback`0700/0600`、五build、macOS两配置`x86_64 arm64`、两个真实opt-in unset、零xcodebuild/xctest与零cache全部通过。fetch/ls-remote确认提交前基线`HEAD == origin/main == remote d5bc6b6`。下一步独立提交推送，不勾选Task 2.3。
- 2026-08-26：恢复Task 2.3执行。catchup、Git与OpenSpec重新核验：`HEAD == origin/main == 3b1c1a9`、工作树clean、当前change仍为`7/27 next 2.3 pending`、零LuneX xcodebuild/xctest进程。读取全部OpenSpec context后开始构建显式live harness；当前未访问host、Keychain或Simulator。
- 2026-08-26：live harness依赖审阅确认默认catalog repository会写本地缓存；决定仅替换为`InMemoryAppCatalogSnapshotRepository`，其余production网络/mTLS/launch/runtime/media/input路径保持不变。入口将固定host/app且由两层精确环境变量控制，busy在任何catalog/session操作前skip。
- 2026-08-26：live harness warnings-as-errors build通过；新增scope focused为`1 passed`，live入口在opt-in unset时为`1 expected skip`，四个本地数据文件SHA/权限前后相同，未访问host/Keychain/Simulator。首次catalog-only wrapper因`env`选项顺序错误在xcodebuild前退出，0 host请求且文件仍不变；将用修正顺序执行。
- 2026-08-26：修正wrapper后发现`xcodebuild test-without-building`的独立runner不会继承自定义live变量，结构化结果仍为明确的disabled skip，0 host请求且文件不变。保留环境变量契约，后续以已构建bundle的direct `xctest`精确运行selector，不修改scheme。
- 2026-08-26：direct xctest离线scope先以`1/1`验证selector与runner；随后catalog-only gate正确读到host opt-in，只发一次`GET /serverinfo`但5秒timeout，因而0 catalog/session/input/stop请求。四个本地数据文件SHA/权限不变；本轮不重试host，Task 2.3继续pending。
- 2026-08-26：live harness完整macOS normal为`1285 total / 1283 passed / 2 explicit skips / 0 failed`；skip精确为真实Keychain与live host两项。direct runner生成的未跟踪`default.profraw`已精确删除，后续文档命令固定coverage到`/private/tmp`。已同步live matrix，记录单次preflight timeout且不把缓存catalog当live结果。
- 2026-08-26：安全门收紧后的fresh最终证据通过：warnings-as-errors build成功，focused `2 total / 1 passed / 1 live skip / 0 failed`，normal `1285/1283/2/0`。repository gate首个OpenSpec jq误用旧`.results`结构在generator前退出；原始JSON已显示`.items`为`11/11`，将修正后继续剩余门而不重跑测试。
- 2026-08-26：live harness最终repository gate完整通过：OpenSpec strict全仓`11/11`、当前change仍为`7/27 next 2.3 pending`；权威Ruby generator双跑与生成前project SHA均为`f254e179...bd0`；diff hygiene、Debug fallback目录/文件`0700/0600`、三个真实opt-in unset、零xcodebuild/xctest进程和零coverage残留均通过。本批只修改macOS测试与文档，不触及产品共享源码或工程成员，因此按macOS-first冻结规则不重复非macOS generic build，也不推进冻结平台状态。
- 2026-08-26：用户确认`tanmy-white`本身网络可达后分层复核。正确的`:47989/serverinfo`单次终端请求返回HTTP 200且host仍busy/current `Desktop`；17:41 direct xctest错误日志则明确显示请求URL遗漏`:47989`并落到TCP 80。已撤回“host unreachable”结论，定位`HostEndpoint.serverInfoURL`端口组装缺陷；同时发现macOS产品缺少Local Network用途说明和`_nvstream._tcp` Bonjour声明。当前开始修复endpoint、产品Info.plist与回归，Task 2.3继续pending且不干扰现有session。
- 2026-08-26：已修复`serverInfoURL`默认/显式port及IPv6 scope编码，新增macOS Info.plist并由权威Ruby generator接入产品。fresh focused `36/36`、macOS normal `1287/1285/2/0`均通过且build diagnostics全零；两个skip精确为Keychain/live opt-in。macOS Debug/Release产品均构建成功、Info.plist实包读回两项Local Network/Bonjour声明、binary均为`x86_64 arm64` universal。
- 2026-08-26：18:03 CST只执行一次corrected catalog-only preflight；production URL在`:47989`于0.020秒内返回busy/current `Desktop`并在catalog前skip，四个本地文件SHA/权限不变，0 catalog/session/input/stop。该结果排除本轮direct XCTest TCC阻断，但actual signed-App TCC与live catalog/session仍pending。
- 2026-08-26：共享endpoint/工程变更后的iOS/iPadOS、tvOS、visionOS unsigned generic Debug compatibility build顺序`3/3`通过；未查询、创建、启动或关闭Simulator，结果不推进冻结平台产品状态。下一步执行最终OpenSpec/generator/diff/privacy/process审计并提交推送本轮修复，Task 2.3继续pending。
- 2026-08-26：endpoint/privacy批次最终repository gate通过：OpenSpec strict全仓`11/11`；generator前及双跑SHA稳定`f9a54a2e...6000de`；focused `36/36`、normal `1287/1285/2/0`与两份structured build diagnostics全零；macOS Debug/Release及三冻结平台generic build `5/5`；实包plist、universal binary、单次busy preflight、本地state不变、旧unreachable时态、opt-in、process、artifact和diff hygiene全部通过。Task 2.3保持`7/27 next`，准备独立提交推送。
