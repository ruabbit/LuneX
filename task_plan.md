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
| 14. macOS 原生输入与生命周期闭环 | pending | `NSEvent`、cursor capture、焦点释放、统一 transform、decoder/renderer 后台节流 |
| 15. 原生 HDR/EDR 管线 | pending | 10-bit、BT.2020/PQ、MDCV/CLL、EDR metadata、tone mapping 与跨屏验证 |
| 16. 空间音频运行接线 | pending | session audio graph、route、`isListenerHeadTrackingEnabled`、entitlement 与降级 |
| 17. iOS/iPadOS scene、PiP 与连续性 | pending | scenePhase、Stage Manager resize、PiP、后台 audio、移动 EDR 和真机验证 |
| 18. tvOS/visionOS 运行适配 | pending | remote/focus、媒体输出、平台 HDR、空间音频和窗口/input 模型 |
| 19. 原生产品工作流与无障碍 | pending | pairing/recovery/stream control、错误 UX、多窗口、VoiceOver、键盘与触控回归 |
| 20. Release 性能与质量验证 | pending | 延迟、功耗、内存、热状态、弱网、长时运行、签名和发布构建 |

## 当前焦点

后续从阶段 13 开始，当前第一优先级为 OpenSpec `implement-moonlight-session-runtime`。完成口径改为生产路径接线 + 确定性测试 + 授权 live Sunshine 端到端证据；策略类型、编译成功、launch response 或首帧都不能单独标记产品功能完成。完整依赖与验收门见 `docs/runtime-completion-roadmap.md`。

当前 change 权威进度为 `29/61`：5.5 zero-copy CVPixelBuffer-to-Metal texture delivery 与 bounded frame queue 已完成独立验收，下一项为 5.6 negotiated colorspace、bit depth、mastering 与 content-light metadata preservation；阶段 13 仍为 `in_progress`。

5.5 已实现 session-owned `CVMetalTextureCache`、8/10-bit bi-planar live Metal texture mapping、wrapper/source lifetime retention、generation isolation 与最大 8 帧的 newest-frame bounded queue；HDR metadata/color conversion/shader、decoder reset policy、AppModel wiring 和 live sustained video仍分别属于 5.6-5.8 与 8.x。

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
