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
