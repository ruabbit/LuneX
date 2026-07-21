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
