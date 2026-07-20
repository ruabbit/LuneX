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
| 5. macOS 核心体验 | partial | window lifecycle 与 Metal pause/throttle 已接线；真实 cursor capture、输入发送、HDR 和音频待完成 |
| 6. iOS/iPadOS 核心体验 | partial | policy/model 与原生 UI 已有；scene/resize、PiP、后台 session、移动 EDR 未接线 |
| 7. 流媒体协议与会话核心 | partial | host/app HTTPS 与状态骨架已有；真实 pairing、RTSP/control、解码和输入 transport 未实现 |
| 8. tvOS/visionOS 适配 | partial | target、UI 和 adapter 骨架可构建；真实媒体、输入、HDR/空间音频未验证 |
| 9. 验证与迭代 | partial | build/unit gates 已有；缺少真实 Sunshine 和真机端到端、性能、功耗与长时验证 |
| 10. 本地真实测试数据导入 | complete | 从本机 Moonlight-qt 偏好导入 paired hosts、cached apps 和本地 identity 到 LuneX Application Support；验证 macOS App 可读取 |
| 11. 审计关键问题修复 | complete | OpenSpec `remediate-critical-audit-findings`：移除伪配对/伪 Streaming/明文私钥副本，修复 compact iPhone 导航并补回归验证 |
| 12. 身份/TLS/macOS 生命周期接线 | complete | OpenSpec `integrate-identity-trust-macos-lifecycle`：一次 Keychain 验证、Debug 文件 fallback、pinned TLS、macOS window/EDR runtime wiring |
| 13. 真实 Moonlight session runtime | pending | OpenSpec `implement-moonlight-session-runtime`：identity/pairing、RTSP/control、视频、音频、输入和互操作验证 |
| 14. macOS 原生输入与生命周期闭环 | pending | `NSEvent`、cursor capture、焦点释放、统一 transform、decoder/renderer 后台节流 |
| 15. 原生 HDR/EDR 管线 | pending | 10-bit、BT.2020/PQ、MDCV/CLL、EDR metadata、tone mapping 与跨屏验证 |
| 16. 空间音频运行接线 | pending | session audio graph、route、`isListenerHeadTrackingEnabled`、entitlement 与降级 |
| 17. iOS/iPadOS scene、PiP 与连续性 | pending | scenePhase、Stage Manager resize、PiP、后台 audio、移动 EDR 和真机验证 |
| 18. tvOS/visionOS 运行适配 | pending | remote/focus、媒体输出、平台 HDR、空间音频和窗口/input 模型 |
| 19. 原生产品工作流与无障碍 | pending | pairing/recovery/stream control、错误 UX、多窗口、VoiceOver、键盘与触控回归 |
| 20. Release 性能与质量验证 | pending | 延迟、功耗、内存、热状态、弱网、长时运行、签名和发布构建 |

## 当前焦点

后续从阶段 13 开始，当前第一优先级为 OpenSpec `implement-moonlight-session-runtime`。完成口径改为生产路径接线 + 确定性测试 + 授权 live Sunshine 端到端证据；策略类型、编译成功、launch response 或首帧都不能单独标记产品功能完成。完整依赖与验收门见 `docs/runtime-completion-roadmap.md`。

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
| Swift 6 XCTest 在 `XCTAssertEqual(try await repository.loadSnapshots(), [])` 报 async autoclosure 错误 | 1 | 先 `try await` 到局部变量 `emptySnapshots`，再传给 XCTest autoclosure |
| GameController notification 误用 `GCController.didConnectNotification` | 1 | 用 Xcode 26.4 SDK typecheck 确认应使用 `Notification.Name.GCControllerDidConnect` 和 `Notification.Name.GCControllerDidDisconnect` |
| `LuneXCoreTests` 新增空间音频测试找不到 `AudioRouteState` | 1 | 将 `Sources/LuneXAudio/AudioRouteState.swift` 纳入测试支持源码并重新生成 Xcode project |
| iOS/tvOS build 中使用 `List(selection:)`、tvOS `TextField.roundedBorder`、tvOS `Stepper` 失败 | 1 | 将 sidebar selection 按平台分支；tvOS 避免 roundedBorder，并用 plus/minus button 替代 Stepper |
| 并发跑多个 simulator build 触发 Xcode build database lock | 1 | 改为按固定 simulator ID 串行验证，避免共享 DerivedData build.db 锁冲突 |
| 运行态日志检查误调用 zsh `log` 内建并假设 `hosts.json` 顶层为数组 | 1 | 改用 `/usr/bin/log show`，并用 `jq` 按实际 `{hosts:[...]}` 结构读取仅主机摘要 |
| 跟踪文件合并补丁使用了不存在的 `findings.md` 标题上下文 | 1 | 读取实际文件尾部后按现有章节定位，分块更新 OpenSpec 与跟踪记录 |
| 手工汇报 OpenSpec 新 change 任务数为 57，CLI 实际解析为 61 | 1 | 以 `openspec instructions apply` 的 `progress.total` 为权威并修正 `progress.md` |
