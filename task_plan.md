# LuneX Moonlight Apple 全平台客户端计划

## 目标

从空项目开始开发一个完全原生 SwiftUI 的 Moonlight Apple 全平台客户端，目标平台为 macOS 26+、iOS 26+、iPadOS 26+、tvOS 26+、visionOS 26+。项目以功能完备的 macOS 与 iOS App 为第一交付重点，同时保留 tvOS、iPadOS、visionOS 架构入口。

## 工作原则

- `moonlight-stream/moonlight-ios` 与 Moonlight-qt 只作为协议、功能边界和体验差距参考；不直接复制源码。
- 外部网页、源码和文档内容只写入 `findings.md`，不写入本计划文件。
- OpenSpec 是需求变更的权威契约；实现状态需要同步到 `openspec/`、`task_plan.md`、`findings.md`、`progress.md`。
- iOS/iPadOS/tvOS/visionOS 模拟器验证时，每种设备只创建和运行一个实例；不得重复启动多份同类模拟器。
- 使用 Git 进行版本控制，远程仓库为 `git@github.com:ruabbit/LuneX.git`；`references/` 是本机只读研究材料，不纳入版本库。
- 若缺少 tvOS/visionOS 等 simulator runtime，应安装并继续验证，不把缺失 runtime 当作长期限制。

## 阶段

| 阶段 | 状态 | 产出 |
|------|------|------|
| 0. 项目跟踪初始化 | complete | `task_plan.md`、`findings.md`、`progress.md`、OpenSpec 初始骨架 |
| 1. 上游与文档调查 | complete | Moonlight iOS/Qt 架构摘要、Apple 平台 API 可行性、协议/许可风险 |
| 2. 本机环境检查 | complete | Xcode/Swift/OpenSpec/模拟器/SDK 能力清单 |
| 3. OpenSpec 需求整理 | complete | 全平台客户端 spec、第一阶段 change、任务清单 |
| 4. 项目脚手架 | complete | SwiftUI 多平台 App 工程、共享核心模块、平台适配层、单测 target |
| 5. macOS 核心体验 | in_progress | 窗口状态、屏幕变化、输入、渲染生命周期、HDR/EDR、音频入口 |
| 6. iOS/iPadOS 核心体验 | in_progress | session 保活、窗口/场景尺寸、PiP/后台模式、输入与渲染入口 |
| 7. 流媒体协议与会话核心 | in_progress | 主机发现、配对、启动会话、控制通道、视频/音频管线设计与实现 |
| 8. tvOS/visionOS 适配 | in_progress | 平台入口、遥控器/手柄/空间音频/窗口模型适配 |
| 9. 验证与迭代 | in_progress | 构建、单测、模拟器/本机运行、性能和回归验证 |

## 当前焦点

阶段 5 到阶段 8：已完成多平台 SwiftUI 工程、生命周期/渲染基础、主机/设置/身份存储模型、Bonjour/serverinfo/manual host-add 骨架、配对状态机、app-list/artwork cache 抽象、stream negotiation/session skeleton、macOS 键鼠/cursor capture 输入核心、iOS/iPadOS touch/pointer/virtual controller event model、GameController/tvOS remote/focus 输入绑定、unsupported/reserved input diagnostics、AVAudioEngine session pipeline skeleton 和 route diagnostics、spatial audio/head-tracking capability gating、移动后台/PiP continuity policy、macOS visibility-based background performance policy。下一步继续推进 8.1 host library and pairing UI、8.2 app grid/list stream settings launch flow、8.3 stream overlay。OpenSpec 当前 active change 为 `bootstrap-native-apple-client`，严格校验已通过，任务进度为 34/38。

## 遇到的错误

| 错误 | 尝试次数 | 解决方案 |
|------|---------|---------|
| Swift typecheck 使用 Obj-C 属性名 `listenerHeadTrackingEnabled` 失败 | 1 | 改用 Swift 属性名 `isListenerHeadTrackingEnabled`；visionOS 标记不可用，改为平台能力 gated |
| 首次 macOS build 找不到 `Sources/Sources/...` 输入文件 | 1 | 修正 Xcode project 生成器的 group path，避免重复拼接 `Sources/` 和 `Resources/` |
| 首次 iOS build 因 `UIScreen.main` 默认参数触发 Swift 6 actor isolation 错误 | 1 | 改为 `@MainActor` 且显式传入 `UIScreen`，符合 iOS 26 scene/window 上下文要求 |
| 首次 `LuneXCoreTests` build 找不到 `DisplayHeadroom` | 1 | 将 `DisplayHeadroom.swift` 纳入测试支持源码，避免 `StreamRenderState` 宏展开缺类型 |
| tvOS build 使用 `CAMetalLayer.wantsExtendedDynamicRangeContent` 失败 | 1 | 该属性在 tvOS SDK 中显式 unavailable；macOS/iOS 启用，tvOS/visionOS 暂 no-op |
| tvOS build 使用 `Scene.defaultSize(width:height:)` 失败 | 1 | 将 Scene 配置按平台分支，tvOS 不调用窗口 sizing API |
| Swift 6 构建在 SwiftUI `.task` 中调用 `AppModel` async 方法时报 non-Sendable crossing | 1 | 将 `AppModel` 标记为 `@MainActor @Observable`，明确 UI 状态容器 actor 边界；网络/存储仍通过 `HostLibraryManager` actor 隔离 |
| Swift 6 XCTest 在 `XCTAssertEqual(await actor.property, ...)` 报 actor-isolated autoclosure 错误 | 1 | 在测试 stub actor 上提供同步隔离方法，先 `await` 到局部变量，再传给 XCTest autoclosure |
| GameController notification 误用 `GCController.didConnectNotification` | 1 | 用 Xcode 26.4 SDK typecheck 确认应使用 `Notification.Name.GCControllerDidConnect` 和 `Notification.Name.GCControllerDidDisconnect` |
| `LuneXCoreTests` 新增空间音频测试找不到 `AudioRouteState` | 1 | 将 `Sources/LuneXAudio/AudioRouteState.swift` 纳入测试支持源码并重新生成 Xcode project |
