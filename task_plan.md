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
| 13. 真实 Moonlight session runtime | in_progress | OpenSpec `implement-moonlight-session-runtime`：identity/pairing、RTSP/control、视频、音频、输入和互操作验证 |
| 14. macOS 原生输入与生命周期闭环 | in_progress | OpenSpec `integrate-macos-native-input-lifecycle`进度`2/29`；已完成合同与revisioned fit/fill resolver，下一步让renderer/mapper共享snapshot |
| 15. 原生 HDR/EDR 管线 | pending | 10-bit、BT.2020/PQ、MDCV/CLL、EDR metadata、tone mapping 与跨屏验证 |
| 16. 空间音频运行接线 | pending | session audio graph、route、`isListenerHeadTrackingEnabled`、entitlement 与降级 |
| 17. iOS/iPadOS scene、PiP 与连续性 | pending | scenePhase、Stage Manager resize、PiP、后台 audio、移动 EDR 和真机验证 |
| 18. tvOS/visionOS 运行适配 | pending | remote/focus、媒体输出、平台 HDR、空间音频和窗口/input 模型 |
| 19. 原生产品工作流与无障碍 | pending | pairing/recovery/stream control、错误 UX、多窗口、VoiceOver、键盘与触控回归 |
| 20. Release 性能与质量验证 | pending | 延迟、功耗、内存、热状态、弱网、长时运行、签名和发布构建 |

## 当前焦点

后续从阶段 13 开始，当前第一优先级为 OpenSpec `implement-moonlight-session-runtime`。完成口径改为生产路径接线 + 确定性测试 + 授权 live Sunshine 端到端证据；策略类型、编译成功、launch response 或首帧都不能单独标记产品功能完成。完整依赖与验收门见 `docs/runtime-completion-roadmap.md`。

当前 change 权威进度为 `54/61`：9.7已同步计划、证据与阶段14–20路线图，阶段13的离线/runtime foundation阶段级自验收通过，但production仍缺具体video/audio network receiver与9.2 live-host XCTest。1.1、3.7、5.8、6.7、7.7、9.2与9.3保持未完成，因此阶段13仍为`in_progress`；等待授权host/hardware期间，下一可执行工作为创建并实施阶段14 `integrate-macos-native-input-lifecycle` OpenSpec change，不用后续离线工作替代阶段13 live证据。

阶段14 OpenSpec `integrate-macos-native-input-lifecycle`权威进度`2/29`。1.1已完成AppKit合同并禁止raw macOS keyCode passthrough；1.2新增immutable `StreamCoordinateSnapshot`、变更驱动且溢出fail-closed的publisher、共享fit/fill destination/source-crop resolver，并通过focused `6/6`与五平台Debug构建。下一项为1.3让renderer与`InputMapper`消费同一个resolved coordinate contract。每项继续独立实现、验收、提交和推送。

7.1严格限定AES-128 key、UInt32 key ID、authenticated mode与8...128-byte plaintext；input作为control type `0x0206`使用显式control-wide sequence和client `CC` nonce封装，context不拥有独立sequence。该证据只证明协商边界与byte-exact serialization，不证明transport delivery、ordering、platform mapping或live Sunshine input。

7.2将keyboard、pointer-button、双轴scroll、normalized touch与每Unicode scalar UTF-8 text通过同一control actor可靠发送；bounded provider以显式drain task保证event FIFO和clipboard原子性，sender失败会关闭input generation并失败current/pending。该证据不证明7.3 movement/coalescing、7.4 controller/feedback、7.5 held-state release、阶段14平台键码/鼠标捕获或7.7 live Sunshine到达。

7.3新增gen5 relative与absolute byte-exact codec；relative在显式16-packet上限内完整Int16分片，absolute event携带生成坐标时的reference size。provider只合并队尾兼容movement，不跨button snapshot、reference size或任何状态事件；coalesced caller有独立上限并在同一物理delivery成功、失败或stop后统一完成。该证据不证明阶段14 `NSEvent`/cursor capture接线或live Sunshine已消费movement。

7.4新增session-owned 16-slot controller registry、完整state accumulator、arrival/disconnect fallback、motion/battery wire codec及typed control feedback stream；motion必须由host按sensor type显式启用，能力不匹配的feedback与sensor/battery输入不会转发。该证据不证明真实`GCController`硬件rumble/LED/sensor接线、7.5 held-state release或7.7 live Sunshine互操作。

7.5在queue accept时事务性拥有held keyboard/pointer/controller状态，并在既有delivery之后追加不可插入的反向release batch；共享release operation合并并发focus-loss调用、阻止release在途时的新输入，stop在deactivate前等待release或accepted key-up barrier。channel failure只能清除本地ownership并truthful teardown，不声称host已收到release。该证据不证明`NSWindow`/SwiftUI lifecycle已经调用provider，也不证明Sunshine实际清除了远端状态；分别保留给8.4/阶段14和7.7。

7.6补齐unsupported/unavailable controller feedback的typed diagnostic，并以确定性回归覆盖serialization、FIFO/clipboard原子性、movement coalescing、event/packet/caller backpressure、满队列release reservation、focus-loss release、反馈latest-64容量、failure teardown与replacement generation隔离。该证据不等于diagnostics UI已经接线，不等于物理`GCController`已应用rumble/LED/motion，也不等于Sunshine实际接收输入；分别保留给8.5、阶段14/18与7.7。

8.1删除独立boolean capability开关，改为由五项实际provider注入计算availability；pairing独立要求pairing provider，stream要求control/video/audio/input完整子集。production factory当前只提供pairing/control/input并共享一个control actor，因此默认pairing可用、stream因缺真实video/audio receiver继续fail closed。该证据不代表8.2 pairing UI已执行provider，也不代表8.3-8.4 session/media路径已接线。

8.2在PIN展示前通过`ClientIdentityManager`完成identity load/create/validate/persist/reload；UI只在`.waitingForPIN`接受四位ASCII数字，并在构造runtime request后立即清除PIN。AppModel按attempt/host隔离progress和authenticated completion，取消先失效ownership再await provider，错误事件显式cancel provider，迟到identity/progress/completion不能覆盖replacement/cancelled状态。该证据不等于3.7 live Sunshine pairing/re-pair成功，也不代表8.3-8.4 session/media路径已接线。

8.3让`MoonlightSessionControlProvider`成为launch/resume/RTSP/control与transport teardown的单一owner；AppModel只调用`StreamSessionCoordinator.prepare/apply/fail`归约状态，不再通过legacy launch client发送第二次`/launch`或`/cancel`。Streaming要求validated negotiated configuration与control/video/audio/input全部ready；remote termination、reconnect、invalid order、incomplete/throwing stream、local stop、duplicate launch、late event与pre-start failure均有应用层回归。该证据不等于8.4已启动真实video/audio/input provider，也不等于5.8/6.7/7.7或9.2-9.3 live端到端已完成。

8.4新增generation-scoped `NativeSessionMediaEnvironment`，统一拥有video/audio receiver、VideoToolbox/AudioToolbox processor、remote input/feedback和3个consumer task，并以5个tracked resource逆序释放。AppModel只聚合control的`.control`与media环境的`.video/.audio/.input`；input启动后先ready，video/audio必须分别成功提交VideoToolbox和排入PCM graph后才ready。decoded frame通过有界presentation source进入Metal/CI，停止或无帧时主动清黑。该证据不等于production已有真实video/audio receiver，不等于最终HDR tone mapping或空间音频，也不等于5.8/6.7/7.7 live证据。

8.6保持既有production fail-closed逻辑不变，并补充pairing缺失与四种required stream provider逐一缺失的执行级无副作用回归；所有case均验证稳定诊断、disconnected/idle/library状态与identity/key/control/media/legacy launch计数为零。该证据只证明缺失provider不会越过应用guard，不提供缺失的video/audio receiver，也不替代3.7/5.8/6.7/7.7和9.2-9.3 live互操作证据。

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
| 初次 host inventory 假设地址在顶层 `address`，实际 schema 使用 `addresses[].rawValue` | 1 | 先检查 JSON schema，再只选 LAN address 执行只读 `serverinfo` |
| Web UI 探测命令包含临时目录 `rm` 清理而被执行策略拒绝 | 1 | 改为无落盘 curl/Python 管道，并单独管理 `dns-sd` 会话 |
| 恢复记录补丁假设 `findings.md` 含 `## 2026-07-21` 标题，实际使用三级主题标题 | 1 | 读取三个跟踪文件尾部，按现有章节精确追加 |
| Opus spike 在 `-warnings-as-errors` 下要求显式解包 magic-cookie `baseAddress` | 1 | 对非空 `OpusHead` Data 的 buffer pointer 增加 guard，空指针返回 `kAudio_ParamError` |
| magic-cookie closure 加入 guard 后不再是单表达式，缺少显式 `return` | 1 | 显式返回 `AudioConverterSetProperty` 的 `OSStatus` |
| AudioConverter 对首个 5 ms Opus packet 输出 120 frames 而非编码侧 240 frames | 1 | 识别为 2.5 ms decoder priming；验收改为正数且不超过编码帧数，并要求 API frame/byte count 一致和 PCM 非静音 |
| FFmpeg `data` muxer 不接受编码后的 audio stream，无法直接输出 raw Opus packet | 1 | 改用 Ogg + `ffprobe -show_packets -show_data` 提取合成 packet；多声道改用显式 libopus multistream 参数生成，避免 Ogg 默认 mapping 偏差 |
| zsh 中 `set -- $spec` 未按空格拆分临时 Opus profile 行 | 1 | 改为 `while read -r profile channels streams coupled bitrate` 的逐字段输入 |
| 记录 zsh 错误的首个补丁漏写 `muxer` 后的空格，导致上下文不匹配 | 1 | 读取计划尾部并按原文精确追加 |
| 7.4 源码盘点命令包含仓库中不存在的 `Project.swift` 与 `Scripts` 路径 | 1 | 保留 `rg` 已返回的真实匹配，后续先用 `rg --files` 确认生成器和脚本路径再查询 |
| 7.4 首次编译误用不含 Test action 的 `LuneX-macOS` scheme | 1 | 从 `xcodebuild -list` 与既有进度记录确认测试入口为 `LuneXCoreTests`，改用该 scheme 和 macOS destination |
| 7.4 首次 Swift 6 编译对同步 actor 调用使用多余 `await`，且两个 generic closure 无法推断 | 1 | 移除同步 `handleFeedback` 的 `await`，为 coalescing `flatMap` 和 `CheckedContinuation<Void, Error>` 增加显式类型 |
| 7.4 iPhone simulator build 后短暂显示 `Booted`，shutdown 到达时已自动变为 `Shutdown` 并返回 CoreSimulator code 405 | 1 | 不重复 shutdown；改用 `simctl list devices -j` 只读复核四台固定实例最终状态 |
| 7.4 新增并发 activation 测试的 `Task` 闭包调用 `XCTestCase` helper，Swift 6 将其判定为 sending closure 捕获 non-Sendable `self` | 1 | 在创建 `Task` 前把 endpoint/configuration 计算为 Sendable 局部值，闭包只捕获 provider、UUID 与值类型参数 |
| 7.4 visionOS strict C 门禁误用 clang 不支持的 `-mvisionos-simulator-version-min` | 1 | 改用 SDK target triple `-target arm64-apple-xros26.0-simulator`，只重跑未执行源码检查的 visionOS 门禁 |
| 7.4 最终 OpenSpec JSON 摘要的 Python `-c` 命令因嵌套 f-string 引号转义失败 | 1 | OpenSpec strict 本身已通过；改用 `jq` 直接读取 progress 和 7.5 task，避免多层 shell/Python 引号 |
| 7.5 首次恢复测试命令包含`rm -rf`清理旧`/tmp`结果，被执行策略在进程创建前拒绝 | 1 | 改用`mktemp`创建全新隔离DerivedData/xcresult路径，不执行预清理且不重复原命令 |
| 7.5 新增并发回归把跨actor `await`直接放进XCTest同步autoclosure | 1 | 先await到局部常量再断言，Swift 6 warnings-as-errors复验通过 |
| 7.6 queue-reservation测试把little-endian keyboard key code按big-endian读取 | 1 | 对照production codec改用既有little-endian helper；发送顺序本身正确，不修改生产serializer |
| 7.6 feedback容量测试在provider仍生产时开始消费，未形成静止缓冲溢出 | 1 | 等待feedback-source结束触发的sender deactivation完成标记，再读取已关闭stream并验证latest 64项 |
| 8.2首个生产补丁假设`stopStream()`后直接进入`updateRenderPreferences()` | 1 | `apply_patch`原子拒绝且未产生生产修改；读取真实尾部后按identity/state、pairing functions、helpers和UI拆分精确应用 |
| 8.2首轮定向编译的测试stub在async方法直接调用`NSLock`并修改host只读ID | 1 | 锁操作移入同步scoped helper；无效completion改为清除pinned identity，不修改模型identity字段 |
| 8.3首轮定向编译在三处XCTest同步autoclosure中直接`await` actor方法 | 1 | 先await launch count到局部值再断言；修正后`AppModelWorkflowTests + SessionStateMachineTests`通过`28/28` |
| 8.3新增重连回归错误期待partial readiness显示`Waiting` | 1 | reducer有意在fresh negotiation未恢复全部通道前保持`reconnecting`；测试改为验证Reconnecting+render idle，full readiness后才恢复Streaming |
| 8.3审计发现`prepare()`在session ownership写入前失败会静默返回 | 1 | pre-start catch现在显式fail UI且不stop未启动provider；无效分辨率回归证明provider与legacy launch client均未触发 |
| 8.4首轮定向编译中两个recording processor actor没有可调用的合成initializer | 1 | 给测试actor增加显式`init(calls:)`，不修改production ownership设计，随后重跑相同门禁 |
| 8.4 startup-cancellation回归把actor `await`放入`XCTAssertNil` autoclosure | 1 | 先await environment snapshot到局部值再断言，保持Swift 6 actor边界明确 |
| 8.2 ENet逐文件比对循环使用zsh特殊变量`path`导致后续命令无法解析 | 1 | 循环变量改为`vendor_path`并使用`/usr/bin/cmp`；18个固定revision文件重新逐字节比对通过 |
| fixture validator 把公开的 64-hex `sha256` 完整性摘要误报为 long hex secret | 1 | JSON 使用结构化解析，只放行键名精确为 `sha256` 且值精确为 64 hex 的摘要；其他字段和异常长度仍拒绝 |
| long-hex regex 以 byte-pair 重复实现，遗漏 65 等奇数长度 hex 字符串 | 1 | 改为直接匹配有边界的连续 `64+` hex 字符，并用 65 字符 self-test 锁定 |
| Xcode 26 `NWError` 新增 `.wifiAware(Int32)`，transport error switch 产生非穷尽 warning | 1 | 新增脱敏的 `wifiAwareFailure(code:)` 映射并保留 `@unknown default` |
| length-prefix decoder 在 `Data.removeFirst` 后假设 `startIndex == 0`，合并第二帧切片越界 | 1 | 从 `buffer.startIndex` 计算 payload start/end；保留 fragmented+coalesced 回归测试 |
| foundation 复验把 fixture root 误写为 `Tests/Fixtures/MoonlightProtocol` | 1 | 从 validator self-test 输出确认实际根目录为 `Tests/Fixtures/Moonlight`，改用真实路径重新扫描 |
| identity focused test 直接强转可选 `SecKeyCopyAttributes` | 1 | 用 guard 显式解包 Xcode 26 的 `CFDictionary?` 返回值，再读取 RSA key attributes |
| 显式 trust anchor 未拒绝被篡改的自签 anchor signature | 1 | 新增 bounded DER envelope parser，提取 TBS/signature 并用证书公钥显式验证 SHA256WithRSA；SecTrust 仅继续承担结构/有效期策略 |
| pairing 合成向量的冒号分隔 bytes 被 fixture validator 识别为 MAC address | 1 | 改为空格分隔 byte notation，保持向量可读且不绕过统一脱敏 validator |
| CommonCrypto output mutable borrow 内读取 `output.count` 触发 Swift exclusivity | 1 | 在 `withUnsafeMutableBytes` 前缓存 output capacity，闭包内只使用不可变局部值 |
| Xcode `build` action 未解析 test-only scheme 的 macOS destination | 3 | focused/full 验收使用 test scheme 的真实 `test` action；仅需纯编译时改用对应 App scheme |
| 3.5 新文件调用了 `PairingTransport.swift` 的 private `Data.hexString` | 1 | 在 production/test 文件内分别使用局部 SHA-256 hex 编码 helper，不扩大 transport 私有 helper 的作用域 |
| 4.3 focused tests 在 XCTest autoclosure 内直接 `await` actor 方法导致 Swift 6 编译失败 | 1 | 先把 actor 返回值 `await` 到局部变量，再传给 `XCTAssertNil`/`XCTAssertEqual` |
| 4.3 fixture gate 误用不存在的 `--root` 选项 | 1 | 读取 argparse usage，改用 positional root：`--self-test Tests/Fixtures/Moonlight` |
| ENet 四平台 strict compile 首次因上游 6 个 unused parameter warning 失败 | 1 | 仅对隔离 ENet target 使用 `-Wno-unused-parameter`，其余 C warnings 继续 `-Werror`；四个 SDK 复验通过 |
| ENet 首次 Xcode 集成触发上游 `peer.c` 的 `-Wshorten-64-to-32` | 1 | suppression 收窄到 `ThirdParty/ENet/*` PBXBuildFile，LuneX 自有 C bridge 继续接受完整 warnings-as-errors |
| ENet Xcode explicit modules 未继承 `unix.c` 内的 Apple RFC 3542 宏 | 1 | target 级定义 `__APPLE_USE_RFC_3542=1`，让预编译 Darwin headers 暴露 IPv6 packet-info API，不修改或屏蔽上游检查 |
| Swift 无法推断 ENet driver 两个 `Void` throwing continuation 的泛型 | 2 | 给 `connect`/`send` continuation 显式标注 `CheckedContinuation<Void, Error>`，focused Xcode integration 复验通过 |
| Python 缺少 `cryptography` 且本机 Ruby OpenSSL GCM wrapper 无法设置 AEAD data | 2 | 用 Node.js `crypto` 的系统 OpenSSL AES-128-GCM 独立生成 synthetic control fixture，再由 CryptoKit production codec 做 byte-exact 交叉验证 |
| staged `git diff --check` 报告 ENet upstream 原文件自带 trailing whitespace | 1 | 不改写 pinned vendor bytes；LuneX 自有文件使用排除 `ThirdParty/ENet/**` 的 staged whitespace gate，vendor 继续以固定 revision逐文件 `cmp` 和 license audit 验证 |
| 4.5 跟踪补丁错误复用了只存在于 `findings.md` 的 4.4 尾行作为 `progress.md` 上下文 | 1 | 分别读取两个文件实际尾部并按各自最后一行追加，避免跨文件假设相同上下文 |
| 清理本轮 `.derived-data` 时 `rm -rf` 被执行策略拒绝 | 1 | 改用限定根目录的 `find .derived-data -depth -delete`，确认仅删除本轮生成物后工作树无该目录 |
| 4.5 提交前 focused test 误用无 Test action 的 `LuneX-macOS` scheme | 1 | 改用仓库测试 scheme `LuneXCoreTests` 并保持 `platform=macOS` destination；App scheme 仅用于 build action |
| 4.5 生成器复验误假设 `Tools/generate_xcodeproj.rb` 支持 `--check` | 1 | 生成器实际会直接重生成 project；改为重生成后用 Git diff 与 generator/source 清单核对没有非预期变更 |
| 4.6 首次 focused tests 中既有 `/cancel` executor fixture 返回空 body | 1 | production 新增 Sunshine `status_code=200` + `cancel=1` 确认后，测试 fixture 同步为真实 XML contract 并新增拒绝 missing marker 回归 |
| 4.6 fixture gate 误用不存在的 `validate_fixture_redaction.py` | 1 | 仓库实际脚本为 `Tools/validate_protocol_fixtures.py`；读取真实 `--help` 后按 positional fixture root 重跑 self-test 与全树扫描 |
| 4.6 封版审计发现 remote termination 发布后仍有 teardown actor 重入窗口 | 1 | 在 provider actor 内同步锁定 `TerminalSession` 的 first-terminal trigger 和 remote-cancel 决策；后到 stop 只能复用该决策，新增 `cancel=0` 竞态回归 |
| 5.1 首次 focused compile 将负向 parser 断言闭包的返回值视为 unused result | 1 | 在预期抛错的闭包中显式使用 `_ = try`，保持 warnings-as-errors 并重跑相同测试门禁 |
| 5.1 generator byte-for-byte gate 使用 zsh 只读变量 `status` | 1 | 改用普通变量 `rc` 保存 `cmp` 退出码；生成器重跑后 project byte-for-byte 一致 |
| 5.2 CoreMedia factory pointer array 使用 optional inner pointer | 1 | 按 Xcode 26.4 Swift importer 的真实签名改为 `[UnsafePointer<UInt8>]`，再重跑 warnings-as-errors focused gate |
| 5.3 bootstrap codec 回归首次只观察到 H.264 host capability | 1 | 定位为 Swift 将 CRLF 视为单个字素，旧 `$0 == "\\r" || $0 == "\\n"` 不会切分；改用 `Character.isNewline` 并保留真实 CRLF bootstrap 回归 |
| 5.3 四 SDK C syntax 脚本把文件列表放入 zsh 标量 | 1 | 改用 zsh 数组 `sources=(...)` 和 `for file in $sources`，重跑同一 strict syntax gate |
| 5.4 首次 focused compile 使用了推测的 VideoToolbox Swift enum 名与错误的 static owner | 1 | 按 Xcode 26.4 importer 诊断改用 `._EnableAsynchronousDecompression`、`._1xRealTimePlayback`，并从 factory 类型读取 destination attributes |
| 5.4 既有 parameter-set fixture 的占位 IDR 被 VideoToolbox 拒绝为 bad data | 1 | 用本机 libx264/libx265 重生成 64x64 黑帧，移除 encoder SEI，仅保留参数集与 IDR，并先用 FFmpeg 独立解码验证后再更新 fixture |
| 5.5 首次 focused test 把 actor `await` 放入 XCTest autoclosure | 1 | 先把 queue actor 的返回值 await 到局部变量，再传给 `XCTAssertEqual`/`XCTUnwrap`/`XCTAssertNil`，保持 Swift 6 warnings-as-errors |
| 5.5 完整门禁命令包含 `rm -rf` 预清理而被执行策略拒绝 | 1 | 测试未启动；改用全新的唯一 DerivedData/xcresult 路径，不执行破坏性预清理命令 |
| 5.6 focused compile 的 CoreMedia extension 测试使用 `as? CFString` 触发 always-succeeds warning | 1 | 在 warnings-as-errors 下改为通过 Foundation `String` bridge 比较 CoreMedia 常量，不屏蔽 Swift 6 诊断 |
| 5.6 四 SDK C syntax 脚本再次把 vendor 文件列表放入 zsh 标量 | 1 | 改为 zsh 数组并逐文件调用 clang，避免把整串文件名作为一个路径；不修改 pinned vendor source |
| 5.6 清理脚本使用 zsh 特殊变量名 `path`，覆盖 `PATH` 后找不到 `find` | 1 | 改用普通循环变量 `artifact`，继续只删除限定的 `.derived-data/5-6-*` 产物 |
| 5.7 focused compile 在 XCTest autoclosure 内直接调用 `try await` | 1 | 先 await loss/metadata update结果到局部值，再传给同步 `XCTAssertEqual`，保持 Swift 6 warnings-as-errors |
| 5.7 封版脚本的 zsh `${...}` 被外层 JavaScript 模板误解析 | 1 | 命令在 shell 启动前失败且未改动仓库；改用 `read -r sdk triple` 避免嵌套模板插值后再执行同一门禁 |
| 5.7 staged audit发现 decoder session创建期间 stop可被迟到IDR恢复覆盖 | 1 | 在decoder replace/decode异步边界后校验pipeline lifecycle token，并增加session创建挂起时stop先锁定的确定性回归 |
| 5.7 teardown竞态回归的 `Task` 闭包捕获非Sendable XCTest `self` | 1 | 在创建并发Task前同步构造access unit，闭包只捕获Sendable value与pipeline actor后复验 |
| 6.1首轮审计发现discarded audio arrival未驱动jitter deadline | 1 | duplicate/conflict/late合法到达统一推进monotonic clock并触发drain；invalid payload/巨大gap保持transactional，并补deadline回归 |
| 6.1 checked-arithmetic补丁错误混入跨文件测试上下文 | 1 | `apply_patch` 整体拒绝且未产生修改；拆成production/test/plan精确file section后重新应用 |
| 6.1 policy由未上限的 `samplesPerFrame` 直接计算纳秒可能整数溢出 | 1 | 使用 `multipliedReportingOverflow` 计算packet cadence/target/deadline，极端negotiated配置结构化fail closed |
| 6.2 actor `deinit` 读取non-Sendable `AudioConverterRef`被Swift 6拒绝 | 1 | 用窄 `@unchecked Sendable` RAII owner封装opaque pointer并在owner deinit dispose；actor只持有/清空owner |
| 6.3 `AVAudioPCMBuffer` factory在设置`frameLength`前读取`mDataByteSize`得到0 | 1 | 先把已验证且不超过capacity的frame count写入`frameLength`，再验证mutable buffer byte capacity并拷贝样本 |
| 6.3 audit发现失败reconfigure保留旧configuration且允许再次start | 1 | configure failure停止partial graph、清空queue/configuration/route；start仅接受configured或running stage，并补replacement failure回归 |
| 6.3 final audit发现stream config和production client stop边界过宽 | 1 | pipeline/client双层只接受48 kHz、1...8 channels；client stop清空configuration，禁止停止后绕过actor直接schedule |
| 6.4首轮clock向量未形成预期drift且hard样例触发audio stale fallback | 1 | video-ahead向量让RTP媒体时间比local推进多10 ms；hard-drift专用policy延长fresh窗口，保持测试确实处于audio-master校正分支 |
| 6.4 staged audit发现hard threshold边界与后置算术错误可部分提交state | 1 | hard resync改为包含正负边界；audio/video候选写入后的snapshot/decision错误会恢复旧stream、observation time和last action |
| 6.5首轮failure-call断言多预期route，并暴露engine start失败未释放partial graph | 1 | pipeline start catch统一stop/清queue/config/route；recovery failGraph依赖该底层保证不重复stop，并让重复interruption begin推进monotonic event time |
| 6.5 audit发现interruption期间route-change被当作invalid state | 1 | 新增typed `routeChangeDeferred`，中断期间不抢先激活graph，明确resume时统一configure/start最新系统route |
| 6.5推送后OpenSpec进度打印的Python one-liner引号错误 | 1 | Git push、HEAD/origin与clean状态已先成功；改用`str.format`避免shell中的嵌套f-string转义并复核`36/61` |
| 6.6首次focused清理glob在无旧产物时触发zsh `NOMATCH` | 1 | 使用glob限定符`(N)`让空匹配得到空数组，不再把“没有旧产物”当失败 |
| 6.6集成测试把`await`直接写入XCTest同步autoclosure | 1 | 先await actor snapshot/count到局部纯值，再交给`XCTAssertEqual`，保持Swift 6 isolation边界明确 |
| 6.6初始跨层fixture把同一Opus packet重复为连续媒体，AudioToolbox只产出`[120,0,0]` frames | 1 | 扩展development-only OpusSpike按同一encoder state生成指定packet index，新增4包连续synthetic fixture；不放宽production PCM guard |
| 6.6尝试设置`kConverterPrimeMethod_None`被Opus converter以`'prop'`拒绝 | 1 | 按SDK callback契约在当前packet耗尽时返回private temporary-unavailable status与0 packets，保留converter live state；不做逐包reset |
| 6.6连续解码focused测试把decoded buffer在schedule循环中重复append | 1 | 删除测试自污染；clock继续只按实际三次decode输出累计，并以完整gate复验 |
| 7.1 staged audit发现AppModel生产默认使用固定`01...10`输入密钥 | 1 | 默认改为每次launch调用`SecureRemoteInputKeyMaterialGenerator`，仅保留显式测试override；增加连续launch新key与生成失败不触网回归 |
| 7.1新key回归首次连续launch未先结束coordinator内部已接受session | 1 | 两次独立session之间调用真实`stopStream()`路径；不放宽coordinator的duplicate-session拒绝策略 |
| 7.1构建后iPhone状态检查与shutdown命令竞态 | 1 | Xcode自动结束后device已先回到`Shutdown`，`simctl`返回405；再次按固定UUID读回，四个simulator均为`Shutdown`且未创建重复设备 |
| 7.2首次定向测试误用无Test action的`LuneX-macOS` scheme | 1 | 改用生成器提供的`LuneXCoreTests` scheme；App scheme继续只用于build action，重跑后定向测试通过 |
| 7.2新增fixture使用连续hex被脱敏validator判定为long hex secret | 1 | 改为空格分隔byte notation，测试与独立生成器只在内存中移除空白后比较，保持统一脱敏门禁不放宽 |
| 7.3首次focused compile把outbound packet数组直接传给plaintext delta decoder | 1 | 显式从每个`RemoteInputOutboundPacket.plaintext`提取后再解码，保留类型边界并重跑同一门禁 |
| 8.4首次跟踪文件补丁误用`findings.md`中不存在的二级标题 | 1 | 读取实际文件尾部，按现有三级OpenSpec主题和progress精确追加；生产与测试补丁未受影响 |
| 8.4 readiness首轮定向测试的4包5ms音频夹具在`.closed`前未越过jitter budget | 1 | 将`.closed`时成功flush并schedule的返回纳入ready断言；保留production jitter策略和4个有序buffer验证 |
| 8.4 readiness测试首个补丁因并发事件断言上下文已变化而未匹配 | 1 | 按实际行拆分补丁，将feedback与增量readiness放入同一无序事件消费循环 |
| 8.4首轮app-target平台构建发现internal `makeCoordinator()`返回private presenter | 1 | presenter改为fileprivate；中止会重复同错的后续平台，重跑脚本增加`set -e`确保首错即停 |
| 8.4 presenter改为fileprivate仍低于internal protocol witness可见级别 | 1 | 改为module-internal final class；类型仍不公开到模块外且满足SwiftUI associated type witness |
| 8.4 app-target实现编译发现`configure`访问MainActor MTKView且sRGB为optional | 1 | `configure`显式标记`@MainActor`，输出色彩空间使用sRGB或确定的device-RGB fallback |
| 8.5首轮定向编译把factory静态diagnostic简写为参数类型成员 | 1 | 三处改用完整`ApplicationDiagnosticFactory.*`限定名；首轮测试未启动，保留失败xcresult后用新隔离目录复验 |
| 8.5第二轮唯一失败仍断言错误文案包含`failed` | 1 | launch request上下文将未知key-generator错误收敛为typed `invalidInputKey`，测试改验input类别/code/action和安全摘要，不依赖任意英文子串 |
| 8.5首轮仓库门禁把fixture根目录误写为`Fixtures` | 1 | 实际根目录为`Tests/Fixtures/Moonlight`；self-test通过，后续门禁尚未执行，改正参数后用新隔离目录完整重跑 |
| 8.5最终simulator jq复核在`and`后丢失根对象上下文 | 1 | 产品/OpenSpec/generator/boundary/ENet/C门已通过；将输入保存为`$root`后重新从头执行仓库与simulator门禁 |
| 8.6 simulator复核的`jq all(generator; condition)`在本机解析失败 | 1 | 未修改任何设备状态；改为`map`生成四项计数并严格要求每个固定UUID唯一且`Shutdown` |
| 8.6仓库门禁把OpenSpec JSON顶层误当作对象数组 | 1 | CLI实际返回`items`与`summary`对象；读取真实JSON后改验`.summary.totals`和`.items | all(.valid)`，在新隔离目录从头重跑通过 |
| 9.6静态门禁把任何analyzer plist/html产物误判为issue | 1 | Xcode零问题文件也会生成plist；改为结构化读取每个plist的`diagnostics`，自有bridge为零，固定ENet四项在Debug/Release精确一致并显式披露 |
| 9.6完整TSan首轮暴露decoder-drop测试观察合法actor中间态 | 1 | 等待条件从单一drop计数改为完整recovery事务与requester计数；TSan目标测试`1/1`和完整套件随后通过，无TSan race诊断 |
| 14.1.1跟踪补丁假设`findings.md`含`当前执行点`标题 | 1 | `apply_patch`整体拒绝且无文件修改；读取真实尾部后按各文件现有结构拆分补丁 |
| 14.1.2 simulator只读审计在对象literal内使用`as`绑定 | 1 | `jq`编译失败且未修改设备；改为先将输入绑定为`$root`、UUID数组绑定为`$ids`再构造结果 |

## 当前执行点（2026-07-21）

- 阶段13 / OpenSpec `implement-moonlight-session-runtime` 当前权威进度为`54/61`；9.7已完成。阶段级离线/runtime foundation验收通过，但7项live/hardware证据仍未通过，阶段保持`in_progress`；下一可执行项为阶段14 OpenSpec提案与实现。
- production inventory继续因缺video/audio receiver而truthfully unavailable；3.7/5.8/6.7/7.7/9.2/9.3所需授权host或硬件证据保持未完成，不用fixture、编译或离线测试替代。
- 阶段14 `integrate-macos-native-input-lifecycle` 当前权威进度`2/29`；1.1合同与1.2 revisioned fit/fill resolver完成，下一项为1.3 renderer/`InputMapper`共享snapshot接线。
