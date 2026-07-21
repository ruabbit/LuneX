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
