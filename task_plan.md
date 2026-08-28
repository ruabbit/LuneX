# LuneX Moonlight macOS-First 客户端计划

## 目标

从空项目开始开发一个完全原生 SwiftUI 的 Moonlight Apple 客户端。当前唯一产品完成目标为 macOS 26+：先完成生产会话、原生媒体/输入/窗口生命周期、产品工作流、正式验收和可复现冻结；iOS 26+、iPadOS 26+、tvOS 26+、visionOS 26+保留已有实现与target，但在macOS冻结前暂停产品功能推进。

## 工作原则

- `moonlight-stream/moonlight-ios` 与 Moonlight-qt 只作为协议、功能边界和体验差距参考；不直接复制源码。
- 外部网页、源码和文档内容只写入 `findings.md`，不写入本计划文件。
- OpenSpec 是需求变更的权威契约；实现状态需要同步到 `openspec/`、`task_plan.md`、`findings.md`、`progress.md`。
- `docs/macos-first-completion-plan.md`与OpenSpec `prioritize-macos-product-completion`共同覆盖旧阶段轮转顺序：macOS为唯一P0，其他平台标记`deferred/frozen pending macOS freeze`。
- macOS冻结前，非macOS改动只允许保持受共享改动影响的target可编译，或修复已在任务记录中明确说明的macOS共享核心阻塞；generic build不计为其他平台产品进度。
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
| 5. macOS 核心体验 | partial | window/input/Metal/HDR/audio及默认video/audio network receiver已完成确定性production接线；仍缺physical/live验收 |
| 6. iOS/iPadOS 核心体验 | deferred/frozen | 保留已有policy/model、原生UI与历史证明；macOS冻结前不推进移动产品功能 |
| 7. 流媒体协议与会话核心 | partial | pairing、RTSP/control、production video/audio receive、decode/audio/input runtime已有；live E2E未验收 |
| 8. tvOS/visionOS 适配 | deferred/frozen | 保留target、UI、adapter和历史证明；macOS冻结前只接受必要兼容构建 |
| 9. 验证与迭代 | partial | build/unit gates 已有；缺少真实 Sunshine 和真机端到端、性能、功耗与长时验证 |
| 10. 本地真实测试数据导入 | complete | 从本机 Moonlight-qt 偏好导入 paired hosts、cached apps 和本地 identity 到 LuneX Application Support；验证 macOS App 可读取 |
| 11. 审计关键问题修复 | complete | OpenSpec `remediate-critical-audit-findings`：移除伪配对/伪 Streaming/明文私钥副本，修复 compact iPhone 导航并补回归验证 |
| 12. 身份/TLS/macOS 生命周期接线 | complete | OpenSpec `integrate-identity-trust-macos-lifecycle`：一次 Keychain 验证、Debug 文件 fallback、pinned TLS、macOS window/EDR runtime wiring |
| 13. 真实 Moonlight session runtime | P0 / in_progress | OpenSpec `55/61`；production video/audio receive与negotiated configuration已完成确定性验收，服务端广告协议/codec能力已登记，下一步执行live全链路 |
| 14. macOS 原生输入与生命周期闭环 | P0 / in_progress | OpenSpec `28/29`；确定性实现已完成，M2-M3等待授权Sunshine/物理输入/窗口/多显示器验收 |
| 15. 原生 HDR/EDR 管线 | P0 / in_progress | OpenSpec `32/33`；确定性实现已完成，M3等待物理HDR/SDR与live compositor验收 |
| 16. 空间音频运行接线 | P0 macOS subset / in_progress | OpenSpec `34/35`；M3先完成macOS签名、物理route、可听同步与head-tracking验收，其他平台子集冻结 |
| 17. iOS/iPadOS scene、PiP 与连续性 | deferred/frozen | OpenSpec `35/36`保持原样；6.6 signed physical acceptance等待macOS冻结后重评 |
| 18. tvOS/visionOS 运行适配 | deferred/frozen | OpenSpec `49/50`保持原样；8.7 signed physical/live acceptance等待macOS冻结后重评 |
| 19. 原生产品工作流与无障碍 | P0 macOS subset / in_progress | OpenSpec `33/48`；M4-M5只推进macOS适用的diagnostics、workflow和accessibility，跨平台扩展冻结 |
| 20. macOS Release 性能与质量验证 | P0 / pending | M6-M9覆盖签名、公证、Gatekeeper、物理/live、延迟/功耗/内存/热/弱网/长时与冻结manifest |

## 当前焦点

2026-08-26起由OpenSpec `prioritize-macos-product-completion`和`docs/macos-first-completion-plan.md`覆盖旧的阶段轮转顺序。M0已完成权威审计与计划迁移；M1 Task 2.1已完成production `VideoReceiveProvider`/`AudioReceiveProvider`、RTSP negotiated configuration、默认runtime接线及取消/teardown的确定性验收。Task 2.2已通过严格自验：登记`tanmy-white`广告的协议/codec能力，将`Desktop`指定为无破坏测试app，不使用Sunshine package-version allowlist，并将另外两个已知离线host的timeout记为预期状态。Task 2.3的Qt identity导入、wire ID continuity、production pinned mTLS与严格双重opt-in live harness均已完成确定性验收；production pinned-mTLS `/applist`取得唯一`Desktop`，同一运行app按`/resume`连接，其余free、missing、unknown、inconsistent或different-app状态不作客户端容量门而尝试`/launch`，由认证服务器响应决定结果；普通断开、失败、取消、replacement与reconnect cleanup保持零`/cancel`。exact SHA `df76fa5`已live验证解码生命周期死锁修复：自动门观察到decoded frame、30帧持续增长、audio runtime running、相对指针往返、input release、一次local stop、重复stop幂等与model teardown；coverage显示`NativeSessionVideoProcessor.consume()` 2109次、`VideoDecodePipeline.consume()` 38次、`requestIDR()` 1次。Task 2.3仍保持pending，因为物理可听同步音频、host可见输入反馈、真实reconnect、host-side remote termination、实际AppKit window/TCC与完整资源/重启矩阵尚未验收。

阶段19当前历史进度仍为`33/48`，其Group 1–5与6.1证据全部保留；6.2-6.5中macOS适用的diagnostics工作进入M4，跨平台专用矩阵与UI扩展冻结。阶段13–18所有未完成physical/live checkbox继续保持pending，任何确定性测试、generic build、Simulator或后续工作均不得回填。

### macOS-First 串行里程碑

| 里程碑 | 状态 | 完成门 |
|---|---|---|
| M0 权威审计与优先级迁移 | complete | gap matrix、OpenSpec、四份planning authority、strict与Git审计一致 |
| M1 Production session与live transport | in_progress (Task 2.3; automated media gate passed, physical/manual rows pending) | exact SHA `df76fa5`已证明pinned-mTLS catalog、matching-running-app `/resume`、RTSP/control、decoded frame增长、audio runtime、input serialization、重复local stop和model teardown；仍需物理可听同步、host可见输入、真实reconnect/remote termination、实际AppKit window/TCC及完整资源/重启验收 |
| M2 macOS原生媒体与输入 | pending | live receiver到VideoToolbox/Metal/AVAudioEngine单owner接线；物理键鼠/控制器/坐标/cursor通过 |
| M3 window/display/HDR/audio lifecycle | pending | occlusion/focus/screen/resize/fullscreen、多显示器、HDR/SDR、head tracking/route物理验收 |
| M4 macOS原生SwiftUI工作流 | pending | host/pairing/catalog/session/multiwindow/diagnostics/export/accessibility完整；macOS shell信息架构以OpenSpec `redesign-macos-library-shell`为准（host侧栏+目录直启、上下文配对、会话独占窗口、原生Settings/按需Diagnostics） |
| M5 macOS确定性全回归 | pending | tests、Debug/Release、strict、analyzer、sanitizer、resource、privacy全门通过 |
| M6 signed/notarized candidate | pending | exact-SHA签名、公证、staple、Gatekeeper、clean-machine launch |
| M7 physical/live acceptance | pending | exact candidate的live Sunshine、窗口/显示/音频/输入/无障碍/teardown矩阵通过 |
| M8 performance/endurance | pending | 预先记录阈值；延迟、内存、功耗、热、弱网、长时运行通过 |
| M9 freeze baseline | pending | manifest、artifact/toolchain/dependency hash、receipt、known limits与用户确认的freeze ref |

### M0 错误记录

- M0收口首个`apply_patch`在文件写入前拒绝同一patch中两个独立`task_plan.md` update block；仓库零部分修改。修正为单一合并block后成功，不重复验证或runtime操作。
- 新macOS-first计划完成后按用户先前要求调用`create_goal`，但控制面仍把已有`blocked`旧目标视为unfinished并拒绝替换；仓库和runtime零副作用。继续以新OpenSpec与planning files为执行权威，不伪造goal已重建。

### M1 Task 2.1 错误记录

- 首轮warnings-as-errors编译因新增文件两个internal typealias引用private generic runtime而失败；拆出独立internal channel/time typealias后从fresh evidence重跑通过。
- 首轮focused的replacement fixture丢弃stream并触发合法consumer cancellation；测试改为保留消费两代stream，不放宽production。首轮related还有3个旧control-only恢复序列断言；更新为验证每代negotiated configuration后fresh矩阵通过。
- authority同步后的辅助旧时态`rg`把含反引号模式放入zsh双引号，命令在检索前以`unmatched quote`退出且零副作用；改用不含反引号的单引号模式完成pre-mark复核。
- Task 2.1提交后的首个cleanup wrapper以`path`作为zsh循环变量，覆盖`PATH`并使末尾`git status`未执行；第二个wrapper又使用只读变量`status`而提前退出。两轮SHA读取或定向cleanup没有仓库副作用；第三轮改用显式Bash、绝对工具路径和`git_state`，确认三方SHA一致、工作树clean。

### M1 Task 2.2 错误记录

- 首次整文件替换`docs/macos-sunshine-live-matrix.md`的`apply_patch`在写入前因同一请求对同一路径同时delete/add而被拒绝，仓库零部分修改。拆成两个明确patch后完成，未重复任何host查询或runtime操作。
- 后续路线图/合同/计划组合patch因`task_plan.md`大范围锚点不匹配而整体拒绝，零文件写入。改为路线图、合同、计划三组小patch后继续，不重复只读host inventory。

### M1 Task 2.3 错误记录

- 2026-08-28：真实 App 最新连接停在 `Waiting for Audio` 后断开，Diagnostics 暂只暴露 `media_session_state_invalid`。已定位为 media event consumer 安装晚于 startup spatial/lifecycle application 的终止结果竞争；当前修复目标是让同一 generation 的原始有限 media terminal error 优先，且不放宽真实 lifecycle effect failure。Task 2.3 保持 pending，修复与确定性门通过后必须立即提交推送，再以单一新构建做 live 复验并依据解蔽后的有限错误继续处理。
- 首轮 focused 的既有 lifecycle failure control 通过，新 terminal-ownership 回归仍发现历史 `media_session_state_invalid`，但 `audio_stream_ended` 已成为当前音频诊断。失败 bundle 保留，不伪称通过；下一步以有限 diagnostics code 序列定位第二记录来源，并从 fresh result bundle 重跑目标门。
- ownership snapshot 修复首轮编译因 `guard !await` 语法错误在测试前失败；改为 `guard !(await ...)`，不改变语义。失败 bundle 不计通过，下一轮使用新的 `.xcresult`。

- 2026-08-28：终审后首个final repository gate在读取第一个xcresult时使用zsh特殊变量`path`保存result路径，意外改写shell `PATH`并导致后续`awk: command not found`；此前仅完成只读scope/OpenSpec断言并创建临时目录，无源码、测试、build、host、Keychain、Simulator或runtime副作用。改名`result_path`后完整重跑门禁通过，不重复test/build。
- 2026-08-28：multi-FEC repository gate首轮在进入shell前因JavaScript模板把shell `${tuple% *}`当成插值而语法失败；第二轮虽转义JavaScript，却让zsh整段预解析在反斜杠参数展开处失败。两轮均未执行命令、未创建证据目录，也没有fetch、仓库、测试、build、host、Keychain、Simulator或runtime副作用。第三轮改用`sed`/`awk`拆分tuple并完整通过，不重复已有test/build。
- 2026-08-28：用户再次要求持续推进后，`create_goal`仍以旧阶段13-20 goal为unfinished而拒绝创建当前M1窄目标；未错误地把旧目标标记complete，也没有仓库、host、Keychain、Simulator或runtime副作用。OpenSpec `prioritize-macos-product-completion`与三份planning authority继续作为执行状态源。
- 2026-08-28：exact SHA `9d4cabe12ea5a55dd847916e0fc9bd735bb5e7cf`的唯一live gate已消费且不得重跑。音频backpressure修复已获live直接证据：`audioStage=running`，audio `13500 datagrams / 9000 parser events`，且无control/media typed failure；不再出现`audio_pipeline_schedule_capacity`。新阻塞为video `304531 datagrams / 247604 parser events`但`frames=0`，AppModel保持`waitingForTransport`。下一个有限分析面是video parser事件到assembly/VideoToolbox/presentation首帧发布，不回到audio容量、host free/busy或媒体UDP到达猜测。
- 2026-08-28：`9d4cabe`的live wrapper本身在direct `xctest`后生成了Git未跟踪`default.profraw`（2162880 bytes，SHA-256 `9485e497...e84e`），这是coverage runtime产物而非产品状态。已在确认唯一路径/哈希后用`unlink`删除自己生成的未跟踪文件，Git恢复clean；不因证据编排副作用重跑live。下一live bundle必须设置`LLVM_PROFILE_FILE`到受限临时目录。
- 2026-08-28：音频backpressure首轮focused证据目录`/private/tmp/LuneX-audio-backpressure-focused.YXYpo4`在测试执行前以exit `65`结束，structured result为`0 tests / 2 errors / 0 warnings`。唯一源码错误为`AudioSessionPipeline.swift:895 Generic parameter 'T' could not be inferred`，根因是`withCheckedThrowingContinuation`的`Void` continuation无法从上下文推断；修复限于显式声明`CheckedContinuation<Void, Error>`，不改变容量等待语义。该失败bundle仅作编译证据，后续从fresh目录重跑focused，不复用失败bundle。
- 2026-08-28：第二轮focused `/private/tmp/LuneX-audio-backpressure-focused-r2.FrkRDb`已越过产品源码编译，但在测试执行前以exit `65`结束；summary为`0 tests / 0 failed / 0 skipped`，build diagnostics为`5 errors / 0 warnings / 0 analyzer warnings`，其中4个源码错误均是新增`Task` closure通过`makePCM`捕获非Sendable XCTest `self`，另一个为build-cancelled汇总。修复为在当前测试隔离域预先构建`DecodedPCMBuffer`，Task只捕获actor和Sendable value；不改变产品实现，下一轮从fresh目录运行。
- 2026-08-28：第三轮focused `/private/tmp/LuneX-audio-backpressure-focused-r3.cSHy9c/Focused.xcresult`完整通过`30/30/0/0`，structured build为`succeeded / 0 errors / 0 warnings / 0 analyzer warnings`。外层zsh wrapper在`xcodebuild` 成功后给只读特殊变量`status`赋值而退出；该错误发生在result bundle完整写入之后，不影响Xcode测试证据，不重跑该bundle。后续wrapper使用`exit_code`。
- 2026-08-28：首轮repository wrapper已确认generator双跑hash稳定，且`openspec validate --all --strict --json`已产生实际`11/11`成功结果，但jq读取器误用不存在的`.results`而非当前`.items`，在后续apply/test/build/privacy断言前退出。该错误仅属证据wrapper schema，无产品、host或runtime副作用；改用`.items`后从头运行完整门禁，不重跑test/build。

- RTSP lifecycle repository gate的OpenSpec汇总jq再次缺少子表达式括号；`.items | length`改变了后续array-constructor的输入，因而在验证命令已成功并保存JSON后报`Cannot index array with string items`。没有重复OpenSpec验证；对已保存对象使用三个独立括号表达式后确认`11/11`。仓库/runtime无副作用。
- RTSP lifecycle修复首轮warnings-as-errors focused在测试执行前被Swift 6并发检查拒绝：取消测试的`Task`闭包通过实例helper构造request并间接捕获了`XCTestCase self`。production源码无诊断、0 tests执行且未访问Keychain/host/Simulator；改为在Task外构造独立`Sendable RTSPRequest`并从fresh DerivedData完整重跑同组测试。
- live harness final repository gate已解析focused与normal xcresult以及build diagnostics，随后错误假设当前`openspec validate --all --strict --json`顶层为`.results`，`jq`因实际`.items`结构而在generator前退出；OpenSpec原始输出本身为`11 passed / 0 failed`，仓库/runtime零变化。修正为`.items`后从OpenSpec开始完整重跑剩余gate，不重复测试。
- normal回归后direct xctest在仓库根生成未跟踪coverage文件`default.profraw`；首个精确`rm -f`清理命令被工具安全层在执行前拒绝且文件仍在。随后仅对`./default.profraw`使用精确`find -delete`成功，后续direct runner固定`LLVM_PROFILE_FILE`到`/private/tmp` evidence路径，避免再次污染仓库。
- direct catalog-only live gate正确继承opt-in后只发送一次请求并在5秒边界timeout；后续读取原始NSError确认失败URL为`http://10.1.100.69/serverinfo`，即`HostEndpoint.serverInfoURL`把用于持久化显示的无端口地址误当网络authority，实际连接TCP 80而非Sunshine `47989`。因此该轮只能证明错误endpoint超时，不能证明host不可达或TCC拒绝；测试未进入pinned mTLS catalog、launch/resume/cancel/stop/input，四个本地数据文件SHA/权限前后相同。修复必须使默认/显式端口及IPv6 URL都保留真实port，并为macOS产品声明Local Network用途与`_nvstream._tcp` Bonjour service。
- 端口修复前的临时Swift URLComponents probe尝试向`percentEncodedHost`写入非法IPv6文本并触发独立`swift-frontend`进程fatal error；该一次性probe未读取host、未修改仓库或runtime。实现改用经过测试的显式IPv6 bracket和zone percent encoding，不重复非法setter调用。
- 修正`env`顺序后的catalog-only `xcodebuild test-without-building`启动了XCTest，但Xcode独立test runner过滤了自定义shell环境变量，结构化结果仍以“host opt-in未设置”在0.002秒skip；因此没有发出host请求或触发Keychain，四个本地文件仍不变。后续用已构建bundle的`xcrun xctest -XCTest <exact-selector>`直接运行，显式环境由该进程继承，不修改scheme或扩大接口。
- live harness首个catalog-only运行命令将`LUNEX_RUN_LIVE_HOST_TEST=1`赋值放在`env -u`选项之前，macOS `env`以`-u: No such file or directory`在`xcodebuild`和任何host请求前退出；本地四个数据文件前后不变。改为所有`-u`选项在前、赋值在后后执行，不把该轮计为preflight。
- 用户恢复工作后再次按先前明确要求调用`create_goal`，控制面仍以已有`blocked`目标为unfinished拒绝创建；仓库、Keychain、host、Simulator和runtime零副作用。继续以当前OpenSpec和planning files为执行权威，不伪造目标已重建。
- identity相关测试定位命令包含不存在的`Tests/LuneXCoreTests/*Application*`裸glob，zsh在该并行只读命令末尾以`no matches found`退出；同一命令此前的指定文件读取已完成，仓库和runtime无副作用。后续改用`rg --files`过滤实际文件，不重复裸glob。
- identity store编码定位沿用不存在的`Sources/LuneXCore/Persistence.swift`假设路径并返回`No such file or directory`；零文件/runtime副作用。后续先用`rg --files Sources/LuneXCore`取得实际定义文件，不重复错误路径。
- identity修复首轮warnings-as-errors命令误用不存在的`LuneX` scheme，xcodebuild在编译前退出且0 source/test执行；仓库、Keychain、host和Simulator零副作用。后续先读`xcodebuild -list`并用实际scheme从fresh evidence重跑。
- importer文档定位包含不存在的根`README.md`，rg报告`No such file or directory`但仍完成其余现有文档检索；仓库/runtime零副作用。后续在现有`docs/macos-sunshine-live-matrix.md`记录显式导入流程，不创建无关README。
- 真实Qt identity写入后的首个只读Security验证脚本因Swift字符串插值内转义引号报`unterminated string literal`，在脚本编译阶段退出且未读取/打印identity材料；文件已按0700/0600成功写入。后续先计算subject布尔值再打印，从同一文件验证而不重复导入。
- identity验收后的host状态命令使用`curl ... | plutil ... || curl ...`，由于XML提取分支失败可能执行了两次相同的有界只读`GET /serverinfo`；结果均无host mutation，但请求计数不可证明为1。已保守记为2次并停止本轮host查询，后续先将单次响应保存到受限临时文件再离线解析，禁止网络fallback。
- generic build后的universal binary只读检查误用Bash 4小写展开`${var,,}`，系统Bash 3.2以`bad substitution`在`find/lipo`前退出；5个build结果和日志不受影响。后续使用显式Debug/Release tag/path读取现有产物，不重复构建。
- 修正Bash展开后仍假设app产物名为`LuneX.app`，实际`find`返回空且两个`lipo`对空路径报`No such file`；build与产物未修改。后续先枚举现有Products文件名，再对实际binary执行一次lipo，不重复空路径命令。
- identity repository首轮wrapper的cache删除只匹配目录，非空`__pycache__`未删除；隐私扫描命中importer/fixture合法PEM标签字面量；进程扫描匹配当前shell参数中的`xctest`。OpenSpec、protocol、fallback权限与diff此前已通过，产品/runtime无副作用。后续精确删除已枚举cache路径、扫描疑似Base64材料而非标签、按process executable筛选并从头重跑gate。
- identity continuity最终人工审阅发现`PinnedHTTPSRequestExecutor`只处理server-trust pin而未加载客户端identity或响应client-certificate challenge；因此先前Qt导入、wire ID和URL断言不能证明production catalog/launch会使用mTLS。Task 2.3未勾选；已补production双向TLS、missing/invalid identity网络前fail-closed和credential级测试，必须从fresh evidence重新验证后再提交。
- mTLS修复首轮focused命令中的4个跨类`-only-testing` selector使用了交接摘要中的描述性名称而非源码实际XCTest方法名；Xcode不报错但结构化结果仅执行`AppCatalogTests 11/11`。该轮只计executor focused，不计完整identity矩阵；后续先以`rg`读取实际方法名并从新evidence目录补跑，不重复错误selector。
- 最终定向清理wrapper再次误用zsh特殊数组名`path`作为循环变量并覆盖`PATH`，在首个`find`执行前以`command not found`退出；这是计划中已有同类错误，属于不应重复的脚本失误。仓库/evidence/runtime零变化；修正为显式`/bin/bash`、`evidence_path`和绝对`/usr/bin/find`，不再使用zsh特殊变量名。
- corrected Bash清理虽删除本轮指定evidence，却再次沿用“只匹配非空`__pycache__`目录再`-delete`”的旧错误predicate，因此两个cache目录和其`.pyc`仍存在；源码/runtime无变化。这同样是不应重复的已知错误；最终改为先枚举`cache_dir`，再对每个目录整棵`-depth -delete`并立即断言零残留。
- 最终repository gate的OpenSpec严格验证先通过`11/11`，随后jq断言缺少括号，因运算符优先级把布尔值传给`contains("2.3")`并在generator/Git/权限/远程步骤前退出；仓库/runtime零变化。修正为对`.tasks[7].description | contains(...)`单独加括号并从头重跑完整gate，不拼接部分结果。
- 第二轮repository gate确认OpenSpec `11/11`与`7/27 next 2.3 pending`后，在`login:false` Bash中因PATH不含Homebrew而找不到`xcodegen`，generator尚未运行且仓库/runtime零变化。后续先只读确认绝对binary路径并在完整gate中固定使用，不依赖shell profile。
- 继续只读核对确认仓库没有`project.yml`且Homebrew也未实际安装XcodeGen；文档明确`Tools/generate_xcodeproj.rb`才是唯一project-membership authority。最终gate改用绝对`/usr/bin/ruby Tools/generate_xcodeproj.rb`双跑并比较project SHA，不再寻找或安装无关`xcodegen`。

### 阶段19错误记录

- Task 4.5首轮文件盘点使用不存在的`Sources/LuneXCore/*Vision*Input*.swift`裸glob，zsh在该并行只读命令末尾以`no matches found`退出；其他文件读取已完成且仓库无变化。后续用`rg --files | rg`定位实际文件，不重复裸glob。
- Task 4.4 cleanup-final audit的旧时态正则跨过同一行分号，把“4.4已完成；4.5/4.6 pending”误判为“4.4 pending”并退出；此前scope/OpenSpec/checkbox/test/source断言已通过，无仓库或runtime副作用。改用精确旧短语列表后从完整只读门重跑。
- Task 4.4首次evidence cleanup在任何删除前退出：系统`/bin/bash`为3.2且不提供`mapfile` builtin，14个已枚举目标全部仍存在。改用显式路径列表与绝对`/usr/bin/find <exact-path> -depth -delete`逐项清理，不扩大匹配范围。
- Task 4.2首次evidence cleanup在任何删除前退出：zsh的特殊数组变量`path`会联动覆盖`PATH`，循环赋值后无法解析`find`。只读复核确认22个已枚举目标全数仍存在；改用普通变量`target`与绝对`/usr/bin/find`逐项删除，不使用宽泛匹配删除。
- Task 4.2第二轮post-mark仍只在checkbox diff索引退出：Git unified diff会在原Markdown列表前再加diff标记，实际行为`-- [ ]`与`+- [x]`。已用只读`od`和独立awk确认精确计数`1:1`，第三轮改用该已验证表达式；前两轮均已先通过strict/status/scope且无runtime副作用。
- Task 4.2首轮post-mark final-state已通过strict、`22/48 next 4.3`与13文件scope，随后checkbox diff断言因正则漏写Markdown `-`后的空格而误判退出；未运行generator/test/build或产生设备副作用。修正为精确`^- \[ \]`/`^\+ \[x\]`后从fresh目录只读复核。
- Task 4.2 authority后检索generator历史命令时，zsh因不存在的`Makefile*` glob触发`nomatch`并在`rg`前退出；没有写入、generator、test、build或设备副作用。已直接使用仓库确认存在的`Tools/generate_xcodeproj.rb`，不再传裸glob。
- Task 4.2首轮related为`161/159/0/2`且build diagnostics全零：一项catalog source contract仍期待旧primary `selectedAppID`字符串，另一项既有visionOS长流程等待application session超时。先更新source断言，再单独复验vision用例区分时序抖动与真实回归，不原样重复失败矩阵；失败证据不计验收。
- Task 4.1首轮repository pre-gate通过精确15文件scope与coordinator detach-only语义后，在scene-root零命中断言退出：`rg -c ... || true`对顶层`primaryWorkspaceReference`零匹配输出空字符串而不是字符`0`。源码实际满足零命中，未运行测试/build/generator或设备操作；下一轮用`awk`显式计数并从fresh目录完整重跑。
- 2026-08-22续接时再次调用`create_goal`，接口在`get_goal`报告旧goal为`blocked`的同时以“unfinished goal”拒绝重建；该控制面状态矛盾没有修改仓库或运行任何测试/设备操作，执行继续以OpenSpec与三份planning为权威，不错误地完成旧goal。
- Task 3.3 final pre-gate的scope包装器在functions JavaScript解析阶段把shell环境变量展开误作模板表达式，以`Missing } in template expression`拒绝；shell未启动，仓库、测试、设备与evidence无副作用。后续改用无模板插值的`env | rg`断言，不重复原包装器。
- Task 3.2定向cleanup已删除全部显式artifact后，零残留验证使用zsh unmatched glob并因`nomatch`返回1；删除已完成且没有项目/设备副作用。后续改用`find /private/tmp -maxdepth 1 -name`验证零残留，不重复glob。
- Task 3.2 repository pre-gate首个隐私扫描把包含反引号的长正则放入双引号，zsh在命令启动前以`unmatched \"`退出；没有项目、测试、设备或artifact副作用。后续改用多个固定单引号pattern，不重复该包装器。
- Task 3.2完整suite后把同一个`Normal.xcresult`的summary与test-tree读取并行执行，触发已知`database.sqlite3` reader conflict；测试本身已成功且bundle未损坏。停止并行读取后对同一bundle串行读回`1214/1213/1/0`及唯一Keychain skip，不重复测试。
- Task 3.2首轮只读审计用于压缩OpenSpec JSON的`jq`表达式错误地把string当array索引而退出；OpenSpec CLI本身成功、工作树无修改、未运行测试或runtime。后续直接读取明确的`14/48 next 3.2`结果，不重复该表达式。
- Task 2.6首轮warnings-as-errors compile在0 tests前发现Swift不接受将switch expression直接放在`&&`右侧；改为局部`cancellablePhase`后fresh compile及全部测试通过，失败raw evidence已删除。
- Task 2.7首轮focused为`3/4`，唯一失败是测试错误要求identity preparation失败取消尚未启动的pairing provider；改为明确不产生伪cancellation后fresh `4/4`，production无需修改。

- Task 1.1首轮项目元数据读取假设存在`project.yml`，命令返回`No such file or directory`；无文件或运行时副作用。已确认本仓库权威生成器为`Tools/generate_xcodeproj.rb`，后续直接审计生成器与pbxproj，不重复错误路径。
- Task 1.1首个验收编排使用`git diff --name-only`比较范围，未包含未跟踪的新合同文档而退出；OpenSpec strict已通过，无production/test/device/Keychain副作用。corrected gate改用`git status --porcelain`解析tracked与untracked精确集合，并从fresh evidence目录完整重跑。
- Task 1.1 corrected scope gate通过后，单行全文断言因合同中的proof句跨两行而退出；逐项诊断确认production diff为0、checkbox精确2行、opt-in unset，其余token均通过。final gate改为两个稳定短token并给每项断言显式marker。
- Task 1.3首个focused编排在xcodebuild结束后尝试写zsh只读特殊变量`status`而退出；fresh xcresult仍可读，确认实际测试`11 passed / 1 failed`。后续编排使用`test_exit`，不重复该shell错误。
- Task 1.3唯一测试失败为`[not-ipv6]`未抛错：bracketed parser剥离方括号后误走通用hostname校验。修复在bracketed入口强制IPv6语义，继续复用统一normalization；原始含自动设备枚举的Xcode日志已删除。
- Task 2.1首轮focused在编译期因两处`await repository.saveCount()`位于XCTest同步autoclosure而退出，0 tests executed；production未报告编译错误。修复为先await局部值再断言，清除identity-bearing raw/xcresult后fresh重跑。
- Task 2.1恢复时发现上轮focused evidence仍保留identity-bearing `xcresult`和device字段；首个清理命令因`rm -rf`安全策略被拒绝且无副作用，改为结构化`jq`脱敏并以定向`find -depth -delete`清除bundle，最终仅保留纯计数摘要。
- Task 2.1首轮完整normal为`1158/1156/1/1`，唯一失败是既有`testMacPlatformInputFailsClosedWithoutCurrentDrawableGeometry`；该测试单独fresh复现`1/1`通过，未发现host/workspace稳定回归。下一门改为禁用parallel testing的fresh normal，不原样重复失败命令，并适配Xcode 27日志格式核对唯一Keychain skip。
- Task 2.1串行normal测试本体通过`1158/1157/1/0`，但Xcode 27 skip日志提取器未匹配而使wrapper非零；未重复完整套件，改为仅选择`testRealKeychainIdentityRoundTripWhenExplicitlyEnabled`且保持opt-in unset，结构化结果`1 skipped / 0 failed`，与完整套件唯一skip计数闭合。
- Task 2.1 final review发现manual add异常返回缺少normalized address时会fallback选择首个无关host；移除fallback并改走typed `hostAddFailed`。修正后expanded related `103/103`及完整serial normal `1158/1157/1/0`通过。
- Task 2.1首个final scope gate把新测试文件在generated pbxproj中的引用数假设为3，实际稳定结构为4而提前退出；其余scope/OpenSpec/generator/test/artifact断言均通过。corrected gate只修正精确计数，不重复测试或运行时操作。
- Task 2.3新增回归后的首个focused wrapper误用无test action的`LuneX-macOS` scheme并以退出码66、0 tests结束，同时过早删除失败raw log；通过`xcodebuild -list`确认scheme后改用`LuneXCoreTests`，保留结构化失败摘要的corrected wrapper从fresh目录通过，不原样重试。
- Task 2.4首轮新focused为`6/5/0/1`，唯一失败是测试误要求无默认action的`pairingCancelled` issue携带action scope；terminal state已保留checked owner，修正断言为nil action后fresh focused通过`6/6`，production无需回退。
- Task 2.5恢复后的前三轮compile分别定位未定义workspace回写、旧dialog测试签名和Xcode 26.4未修改`var`诊断；均在0 tests阶段逐项修复，final warnings-as-errors compile通过。
- Task 2.5首轮新测试compile仅报3处XCTest autoclosure内直接`await`；改为局部值后通过。首轮focused为`12/11/0/1`，唯一失败是测试误把第二次retry的nil拒绝当作应返回同一confirmation；按“不创建第二操作”的幂等合同修正断言后fresh `12/12`通过。
- Task 2.5最终四平台build wrapper在macOS成功后再次误用zsh只读变量`status`而退出；读回macOS structured success后改用`build_state`，只补跑缺失的iOS/tvOS/visionOS三项并全部通过，没有重复已成功build。

后续从阶段 13 开始，当前第一优先级为 OpenSpec `implement-moonlight-session-runtime`。完成口径改为生产路径接线 + 确定性测试 + 授权 live Sunshine 端到端证据；策略类型、编译成功、launch response 或首帧都不能单独标记产品功能完成。完整依赖与验收门见 `docs/runtime-completion-roadmap.md`。

当前 change 权威进度为 `55/61`：9.7已同步计划、证据与阶段14–20路线图，阶段13的离线/runtime foundation、production video/audio network receiver及`tanmy-white`服务端广告协议/codec inventory已完成。3.7、5.8、6.7、7.7、9.2与9.3保持未完成，因此阶段13仍为`in_progress`；下一执行点为macOS-first M1 Task 2.3，不用后续离线工作替代阶段13 live证据。

阶段14 OpenSpec `integrate-macos-native-input-lifecycle`权威进度`28/29`。确定性production integration、normal/五平台Debug+Release、strict/generator/analyzer/ASan/TSan/malloc和独立simulator门均通过，且已推送HEAD上的阶段级离线自验再次通过`470 total / 469 passed / 1 Keychain skip / 0 failed`。6.5仍需授权Sunshine host、物理键盘/鼠标和多显示器，change保持`in_progress`且不可archive；下一可执行工作为创建阶段15 `implement-native-hdr-edr-pipeline`，不以阶段15证据替代6.5。

阶段15 OpenSpec `implement-native-hdr-edr-pipeline`权威进度`32/33 in_progress`。1.1至6.4与6.6的production、确定性测试、normal/五平台Debug+Release、strict/generator/dependency/Metal/analyzer/ASan/TSan/malloc/resource、simulator与跟踪证据均完成并逐项提交推送；已推送`372ca60`上的阶段级离线自验再次通过`616 total / 615 passed / 1 Keychain skip / 0 failed`、strict `6/6`、generator与固定simulator门。唯一剩余6.5要求授权Sunshine HDR源、代表性HDR/SDR物理显示器和可审计参考图或测量。没有live compositor EDR signaling、物理亮度/颜色、动态headroom和跨显示器证据时，change不可archive、阶段不可标记`complete`；下一可执行阶段为16空间音频，不以其证据替代6.5。

阶段16已在macOS 27.0/Xcode 26.4更新后恢复并进入`in_progress`。OpenSpec `integrate-spatial-audio-runtime`权威进度`34/35`：1.x至3.x的channel-layout、session-owned graph、平台策略、entitlement、route/capability adapter和observer矩阵已完成；4.1至4.6完成runtime到AppModel的generation-owned接线、恢复/replacement矩阵与合法WAVE 7.1 application gate；5.1至5.5完成设置、诊断、actual-runtime UI及responsive/localization/accessibility矩阵；6.1至6.5完成normal、十配置五平台build、strict/API/analyzer、完整ASan/TSan、11类malloc/resource与独立simulator门。6.7新增权威空间音频合同并同步路线图、entitlement/hardware说明和proof boundary；阶段级fresh normal再次通过`721 total / 720 passed / 1 Keychain skip / 0 failed`，strict/generator/sanitizer/resource/simulator组合门通过。唯一剩余6.6等待授权signed entitlement、AirPods、built-in/wired/HDMI、多声道识别、route transition、听感同步和live Sunshine物理证据；change不可archive、阶段不可标记complete。实现和测试继续显式移除`LUNEX_RUN_KEYCHAIN_TEST`并使用Debug文件fallback；离线测试、属性赋值、编译或模拟器不能替代6.6。

阶段17 OpenSpec `integrate-mobile-scene-pip-continuity`保持`in_progress`，权威进度`35/36`。1.x至5.6、6.1–6.5与6.7的actual runtime/UI、normal/build/repository/API/analyzer/sanitizer/resource/fixed-simulator和五级proof boundary封版均完成；已推送`c7c9089`上的阶段级fresh normal `909/908/1/0`与组合门再次通过。唯一剩余6.6需要signed physical iPhone/iPad、system PiP、Stage Manager、external display、visible EDR、空间音频、power/thermal与live Sunshine receipt；change不可archive。

阶段18 OpenSpec `integrate-tvos-visionos-runtime`为`49/50 ready`，唯一pending 8.7。离线实现、测试、build、repository与bounded Simulator target审计已按任务记录成立；signed physical Apple TV/Vision Pro与live Sunshine仍无完整receipt，因此change不可archive且阶段保持`in_progress`。阶段19/20不得替代或回填8.7的physical/live proof。

5.6 post-record `/tmp/LuneX-18-5_6-post-record-r2.omtl07`与final audit `/tmp/LuneX-18-5_6-final-audit.cNq2is`确认五份authority含pre/final双门索引、精确11文件3 test/8 authority分类、三条矩阵断言未弱化或禁用、tasks仅5.6 checkbox变化、production/reference/dependency零diff及证明分层准确；无阻止独立提交的问题。

5.6 final-record `/tmp/LuneX-18-5_6-final-record.qI7nfQ`再次确认strict `9/9`、OpenSpec `31/50 next 6.1`、精确11文件分类、五份authority四门索引、稳定project、retained evidence、disabled opt-ins、no-process与diff边界；可精确stage并独立提交推送。

6.1进入`in_progress`。1.4已有`VisionWindowedPresentationState`、唯一`.windowed`模式及immersive/passthrough/stereoscopic/volumetric全量typed unavailable值合同，但production仅在私有vision input snapshot中临时构造，shared coordinator snapshot与AppModel尚无显式actual windowed状态。6.1将把actual attached scene派生的状态纳入当前coordinator snapshot，按ownership/revision/surface replacement/closed/stop fail-closed，并由AppModel只读投影；不创建`ImmersiveSpace`、`RealityView`、第二decoder/frame queue或7.x UI。

6.1首个production/test组合补丁因AppModel长测试函数名的换行锚点不精确被`apply_patch`原子拒绝，无部分写入；改为按文件与稳定相邻标题拆分，不重复错误锚点。

4.3 post-mark final-state `/tmp/LuneX-18-4_3-final-state-r3.ShiHBj`只读确认OpenSpec strict `9/9`、`22/50 next 4.4`、task done、稳定generator SHA-256、精确16文件scope、权威文档、retained evidence及privacy/reference/dependency/opt-in/process/diff边界。4.3可独立提交推送，阶段18和长期goal继续保持`in_progress`。

4.3 post-record `/tmp/LuneX-18-4_3-post-record.2zqnMO`和最终人工production/test/docs diff审计均通过；observer ownership、source identity、fallback/exhaustion/terminal state、proof tiers与4.4/4.5边界无新问题。提交只包含精确16文件scope。

4.4现为`complete`并已勾选。实现复用`NativeSessionAudioProcessor`、`SpatialAudioRouteMonitor`、canonical `SessionAudioRuntime`/`AVAudioEngineClient`和既有platform coordinator：runtime event携带actual route capability/entitlement，纯值publisher生成bounded tvOS audio revision，`NativeSessionMediaEnvironment`在tvOS ownership activate/replacement时回放latest并持续应用current event；typed invalid/action/revision terminal清理成立。下一项4.5不得创建第二AVAudioSession observer/graph或把离线/unsigned证据当作AirPods、电视audio route、listener head tracking、signed或live Sunshine证明。

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
| 18.7.4 normal `.xcresult`的summary/build/tests三项并行读取时，tests子命令报告内部`database.sqlite3`同名移动冲突 | 1 | summary与build读取已完成且测试成功；停止并行访问同一bundle，串行只读skipped节点，不重跑测试 |
| 18.7.4记录normal结果的首个组合补丁误判错误表与7.4段落相邻 | 1 | `apply_patch`原子拒绝且无部分写入；读取真实锚点后拆分精确补丁 |
| 18.7.4记录tvOS修复的首个多文件补丁含无效空hunk标记，第二个补丁又沿用不精确toolbar文本 | 2 | 两次`apply_patch`均原子拒绝且无部分写入；读取真实toolbar后使用精确上下文拆分补丁 |
| 18.7.4首轮fixed Apple TV direct编译发现SwiftUI `ShareLink`在tvOS unavailable | 1 | 保留非tvOS原生ShareLink；tvOS使用可访问的typed unavailable toolbar状态，不伪造分享通道，补source-contract后fresh重跑 |
| 18.7.1首轮五平台build包装器在zsh中用Bash的0-based数组索引 | 1 | 在首个`xcodebuild`前因`names[$i]`未设置退出，仓库/设备无副作用；改用显式`/bin/bash`和fresh目录执行相同矩阵 |
| 18.7.1首轮focused源码合同从`TVStreamControls` struct起截取，却断言其前方focus enum的`hideControls`/`disconnect` cases | 1 | production焦点enum和按钮接线均存在；将测试切片起点前移到`TVStreamControlFocusTarget`，从fresh bundle重跑8项focused |
| 18.7.1恢复时使用`find .. -name AGENTS.md`导致仓库父目录遍历超出必要范围 | 1 | 主动中止只读进程；改用仓库内`rg --files -g 'AGENTS.md'`，确认没有额外AGENTS约束且无仓库副作用 |
| 18.6.5首轮smoke仍按visionOS旧`activate -> scene`两动作序列断言replacement位置 | 1 | production已按目标编译为`activate -> scene -> input`；更新三个既有测试为完整动作、ownership和输入能力断言，并从fresh目录重跑 |
| 18.4.3首次权威文档组合补丁的`design.md`换行锚点不精确 | 1 | `apply_patch`原子拒绝且无部分修改；读取真实片段后按文件拆分同步 |
| 18.4.3 runtime contract章节插入误把行内`Post-record`当作段首 | 1 | `apply_patch`原子拒绝且无部分修改；改用稳定的下一章节标题作为插入锚点 |
| 18.4.3首轮repository pre-gate以`! rg`配合`set -e`实现负向断言 | 1 | Bash不会在`!`上下文按预期退出，且一项平台import假设不成立；该轮不计验收，改用显式条件失败和真实`#if os(tvOS)`边界 |
| 18.4.3 repository pre-gate r2平台header fixture遗漏`#endif`后的空行 | 1 | 门在diff处正确退出；改为比较精确前7行语义内容并fresh重跑 |
| 18.4.3首个post-mark final-state包装器含未转义Markdown反引号 | 1 | JavaScript在shell启动前退出且无副作用；移除反引号模式并fresh运行只读门 |
| 18.4.3 post-mark final-state r2把跨两行的same-MTKView/4.5合同写成单行正则 | 1 | 前置状态通过后退出；拆成两个独立短语断言并fresh只读重跑 |
| 18.4.2首个`HDRRenderContract.swift`组合补丁假设了不精确的surface validation上下文 | 1 | `apply_patch`原子拒绝且无部分修改；读取实际短片段后把capability matrix与contract hunk按精确上下文应用 |
| 18.4.2 API probe把device `appletvos` SDK用于`-simulator` target | 1 | device target先通过，simulator因标准库SDK不匹配退出；改用`appletvsimulator` SDK后同一public API source warnings-as-errors通过，未操作simulator生命周期 |
| 18.4.1首轮post-record误用只验证当前change的`openspec validate integrate-tvos-visionos-runtime --strict --json`并期望仓库级`9/9` | 1 | `/tmp/LuneX-18-4_1-post-record.mkvGtQ`合法返回current change `1/1`后在首个断言退出；改用`openspec validate --all --strict --json`从fresh只读目录完整通过，不重复test/build/generator或simulator操作 |
| 18.3.6首轮repository pre-gate静态断言使用不存在的`.restoreLocalNavigation` case名 | 1 | fixtures、strict、generator与scope通过后退出，未读retained evidence且不计最终门；按实际`.restoreLocalFocus(reason)`修正后从fresh evidence目录完整通过 |
| 18.3.3首个跨文件planning记录补丁使用了不匹配的runtime contract换行锚点 | 1 | `apply_patch`原子拒绝且无部分写入；改用稳定章节标题拆分文档补丁，并读取各文件真实EOF后分别追加 |
| 18.3.3上轮跨文件planning补丁使用了不匹配的`findings.md`尾部锚点 | 1 | `apply_patch`原子拒绝且无部分写入；读取各文件真实EOF后分别追加，保留现有实现与证据不变 |
| 18.2.5首轮final-state的`jq`管道优先级让第二个`.items`作用于数组 | 1 | 在任何xcresult读回前退出；为两个子表达式加括号后从fresh只读目录完整通过，不重复test/build/generator |
| 18.2.5首轮repository pre-gate误把fixture根设为仓库`.` | 1 | validator按设计报告既有build/reference/docs内容；改用默认`Tests/Fixtures/Moonlight`后从fresh目录完整通过 |
| 18.2.5首轮normal误用不存在的`LuneX` scheme | 1 | 在测试与编译前退出；从`xcodebuild -list`确认`LuneXCoreTests`并用fresh DerivedData/result bundle重跑 |
| 18.2.5合同/planning组合patch使用不精确跨行锚点 | 1 | `apply_patch`原子拒绝且无部分写入；改用稳定章节标题和精确单行锚点拆分补丁 |
| 18.2.5首轮environment focused测试在两处XCTest autoclosure内直接`await` | 1 | 测试未执行；先捕获actor snapshot再同步断言，从fresh focused目录重跑 |
| 18.2.5第二轮warnings-as-errors编译发现既有media event switch未覆盖新增presentation event | 1 | production和其余测试源已编译；在只关心readiness/feedback的旧测试中显式忽略新event，从第三个fresh evidence目录复编 |
| 18.2.5首轮warnings-as-errors编译在`ApplicationDiagnostics.swift`因新增`SessionMediaEnvironmentError`未穷尽 | 1 | task 2.5 runtime类型已进入编译；补充两个privacy-bounded typed diagnostic映射后从fresh evidence目录重跑，不复用首轮结果 |
| 18.2.4首轮post-record强制高层roadmap保存临时final-gate路径 | 1 | roadmap已记录final gate结论，具体临时路径按层级保存在runtime contract和三份planning文件；收窄只读断言后r2通过，不重复test/build/generator |
| 18.2.4修订final wrapper把Xcode build-file声明与build-phase引用按单次membership计数 | 1 | fixture/OpenSpec/generator/scope已通过且未重复test/build；按五个production target和一个test target修正为工程文本`10/2`，从fresh目录重跑 |
| 18.2.4修订final wrapper隐私正则把普通scene/audioRoute/controller lease状态误当身份字段 | 1 | 所有证据门已通过至build读回；收窄为明确禁止的host/window/scene/controller/route identity字段，从fresh目录完整通过且未重复test/build |
| 18.2.4 display修复首轮focused的unavailable fixture仍携带platform headroom | 1 | production与其余12项均通过；helper按display合同改为unavailable source、nil headroom和unavailable layer capability，从fresh bundle复验 |
| 18.2.4首轮勾选后final-state通过后，人工diff发现display unavailable未参与render/input eligibility | 1 | 不使用该final-state作为最终证据；将display availability纳入input/video fail-closed，新增unavailable/suppressed/recovery replay回归并从fresh focused重跑全部受影响门 |
| 18.2.4第二轮focused的FIFO测试把scene transition自身先行的`.input(nil)`误判为并发input callback越过gate | 1 | production与其余11项均通过；改为在scene effect挂起点记录effect count，并断言并发callback启动后数量不变，从fresh目录复验 |
| 18.2.3修订final gate把zsh特殊数组`path`用作循环变量，覆盖`PATH`后找不到`jq` | 1 | `/tmp/LuneX-18-2_3-final-amend.18u1Sh`仅执行只读检查且未改仓库；改名为`evidence_path`并从新目录完整通过，不重复test/build |
| 18.2.3最终复核验证前发现外部TamaSwift Release xcodebuild正在运行 | 1 | 未启动LuneX build、未终止或干扰外部进程；等待PID 93371自行结束后再用隔离DerivedData并行验证 |
| 18.2.3首轮focused进程预检匹配到包含xcodebuild文本的wrapper自身 | 1 | 在任何build前退出；改用`pgrep -x xcodebuild`精确进程名并从新目录运行 |
| 18.2.3第二轮focused的invalid-geometry helper把NaN view width转换为Int而trap | 1 | production与其余13项已编译执行；helper改用generation层有限drawable reading并从fresh bundle通过14/14 |
| 18.2.3并发读取同一focused xcresult触发SQLite bundle冲突 | 1 | 已成功取得test summary且bundle未损坏；后续对同一xcresult只串行读取 |
| 18.2.2记录final-state包装器错误的首个补丁假设了四横线表格分隔符 | 1 | `apply_patch`原子拒绝且无部分写入；读取真实三横线分隔符后使用精确锚点 |
| 18.2.2勾选后final-state将合同中跨行的`authoritative`与`next task is 2.3`写成单行`rg`断言 | 1 | OpenSpec、generator与scope已通过且未重复test/build/simulator；改为分别匹配两行并从新证据目录重跑只读final-state |
| 18.1.6 repository pre-gate首轮把18个临时probe源误断言为19 | 1 | 在API/entitlement/doc检查前退出；修正精确源数量并用`plistlib`读取带点号entitlement key，从新目录完整重跑 |
| 18.1.5勾选后final-state首轮误用不存在的`Fixtures/Protocol`根 | 1 | 在generator和结果读取前退出；读取validator默认根后改用`Tests/Fixtures/Moonlight`并从新证据目录完整重跑 |
| 18.1.5文档同步组合patch使用不精确换行锚点 | 1 | `apply_patch`原子拒绝且无部分写入；改用各文件稳定标题拆分补丁 |
| 18.1.5首轮focused中controller adapter加入guard后缺少显式return | 1 | production修复逻辑不变；为成功分支补充显式`return`，从全新DerivedData/result bundle重跑 |
| 18.1.4首轮focused测试helper的throwing nil-coalescing缺少`try` | 1 | production合同已完成编译；在surface generation fallback表达式显式标记`try`，从全新DerivedData/result bundle重跑 |
| 18.1.3首轮focused编译把测试helper的`Int` slot直接传给`UInt8` | 1 | production合同已完成编译；helper在既有checked slot构造后显式转为`UInt8`，并用全新DerivedData/result bundle重跑 |
| 18.1.3首个code/test/planning组合patch使用了错误的`findings.md`尾部锚点 | 1 | `apply_patch`在写入前整体拒绝且没有部分状态；拆分code/test与两份planning精确patch |
| 18.1.3记录上述patch错误的首个表格补丁假设了错误的首行错误项 | 1 | 补丁在写入前整体拒绝；只使用稳定表格分隔行作为插入锚点 |
| 18.1.3对新文件运行无仓库配置的`swift-format lint --strict` | 1 | 工具默认2-space规则与仓库既有4-space风格冲突，产生大量非权威格式报告；不批量重写，继续使用warnings-as-errors编译、结构化xcresult、`git diff --check`和人工diff审计 |
| 18.1.3勾选后首个OpenSpec摘要使用错误的Python单行f-string转义 | 1 | `openspec`只读JSON已写入临时文件但解析器在仓库外退出；改用heredoc从文件解析并确认`3/50 ready next 1.4`，未重复build/test或设备操作 |
| 18.1.3首个final-state包装器含未转义Markdown反引号 | 1 | JavaScript在shell启动前退出，没有创建证据或执行门禁；移除包装器中的反引号固定匹配后从头运行，不重复build/test |
| 18.1.3第二个final-state文档断言大小写不匹配 | 1 | OpenSpec、generator和全部保留结果已通过后在`Actual stream-surface`句首大小写处退出；改为大小写不敏感匹配并从新目录完整重跑 |
| 17.6.4首轮final-state的精确进程名门命中另一个工作区TamaCore正在运行的xctest | 1 | 未终止或干扰外部进程；进程门收紧为只匹配comm为xcodebuild/xctest且args属于LuneX仓库或本阶段证据路径，再从新目录完成final-state |
| 17.6.4第二轮pre-gate的`pgrep -f`误匹配包装器自身命令行内`xcodebuild.log`路径 | 1 | checkpoints证明前六组全通过，按进程名连续5秒查询为零；改用`pgrep -x xcodebuild`和`pgrep -x xctest`精确进程名完成组合门，不重跑测试 |
| 17.6.4首轮repository pre-gate在generator后无结果退出 | 1 | 三份xcresult、skip、报告扫描、suite、环境、diff与当前进程只读复核均通过，未能从该轮保留文件确认具体断言；不重跑测试，下一轮为检查组写标记并对测试进程回收使用有界等待后从新目录完整组合验收 |
| 17.6.4盘点命令对test-only scheme执行`-showBuildSettings -destination platform=macOS`无法解析destination | 1 | `-showTestPlans`已成功且没有运行测试；不重复该非验收查询，直接使用历次验证过的test action与macOS destination运行sanitizer |
| 17.6.3查询历史strict C命令的`rg`模式以`-W`开头被解析为选项 | 1 | 只读搜索在执行前退出；使用`rg --`终止选项解析后重查，不影响任何编译或仓库状态 |
| 17.6.2首轮final-state包装器含Markdown反引号导致JavaScript解析失败 | 1 | 失败发生在shell启动前，没有执行门禁或改变仓库/设备；改用不含反引号的固定语义匹配从头运行 |
| 17.6.2首轮xcresult串行读回在zsh中把`status`用作局部变量 | 1 | 包装器在读取第一份结果时被zsh只读变量保护终止，未重跑或修改任何build；改用`/bin/bash`和`build_status`从原十份bundle重新验收 |
| 17.5.1并行读取同一个full xcresult的summary/build/tests明细触发Xcode临时`database.sqlite3`同名冲突 | 1 | 测试与前两项结构化读回已成功且bundle未损坏；tests明细改为串行读取并精确确认唯一Keychain skip，后续同一bundle只串行访问 |
| 17.4.7首轮repository pre-gate用`rg -c ... || true`断言零decoder匹配时得到空输出 | 1 | 前置fixtures/strict/apply/generator已通过但组合门不计验收；改用始终输出整数的`grep -Ec`并从全新目录完整重跑 |
| 17.4.7首轮focused草案在`compactMap` Optional lease推断和只读`weak var`上被Swift 6.3 warnings-as-errors拒绝 | 1 | 显式标注`MobilePictureInPictureRestorationLease?` closure返回类型，并把释放观察改为`weak let`；production未报错，使用全新DerivedData/result bundle重跑 |
| 17.4.6首轮focused测试helper使用不存在的`VideoTransferFunction.smpte2084` | 1 | 改用仓库合法`.smpteST2084PQ`并从全新DerivedData/result bundle重跑 |
| 17.4.6第二轮focused的4个`withLock` Optional closure无法从`nil`推断返回类型 | 1 | 显式标注`StreamVideoPresentationEvent?`，不改变锁或状态语义，并从全新证据重跑 |
| 17.4.6首轮repository pre-gate把production source在App/test-support两个generator清单中的合法出现次数误写为1 | 1 | 核对清单与四平台Swift file list后改为精确2，使用全新目录完整重跑 |
| 17.4.5四平台generic Debug包装器在build前以zsh执行0-based数组并触发`parameter not set` | 1 | 未启动任何build或设备操作；改用显式`/bin/bash`执行同一数组矩阵 |
| 17.4.5首轮focused把`prepare()`返回的request snapshot与同步client callback后的current snapshot混为一项断言 | 1 | production事件顺序已正确为`preparing -> ready`；测试拆分验证返回`.preparing`和最终`.ready`，从全新DerivedData/result bundle重跑 |
| 17.3.3首轮focused的新display binding fixture未发布geometry，drawable保持不可用并正确fail closed | 1 | 补充同一surface generation的geometry binding后从全新DerivedData/result bundle重跑；production逻辑不放宽，最终focused为`4/4` |
| 17.2.5完整suite后`xcresulttool get test-results tests`尝试移动内部`database.sqlite3`时命中同名项 | 1 | 测试本身已成功且summary/build-results可读；不重跑suite，使用同一bundle的结构化总数与原始日志精确确认唯一Keychain skip |
| 17.2.5收紧stale render-input后focused coordinator fixture仍期待旧binding覆盖不匹配的source/mode | 1 | production正确fail closed到zero drawable；fixture首次使用匹配source/mode验证应用，replacement继续验证不匹配时归零，并从全新DerivedData/result bundle重跑 |
| 17.1.3首轮focused编译把实例转移调用的`replacing` helper声明为`static` | 1 | 改为实例私有helper；失败发生在编译期、测试未启动，使用全新DerivedData/result bundle重跑 |
| 17.1.2 final组合门用文本计数断言唯一Keychain test名称出现一次 | 1 | tests JSON中name/nodeIdentifier/URL会重复同一名称；改为结构化选择`result == Skipped`节点并精确断言唯一nodeIdentifier，不重跑已成功test/build |
| 17.1.2跨平台build包装器被JavaScript模板解析Bash`${!names[@]}` | 1 | 命令在进入shell前失败且没有启动build或设备操作；改用直接`/bin/bash`执行相同数组循环 |
| 17.1.2 focused结构化读回沿用旧`statistics`对象schema | 1 | 当前Xcode26.4 summary的计数位于顶层、`statistics`为空数组；按顶层`totalTestCount/passedTests/failedTests/skippedTests`及build-results count字段复核，不重复已通过focused suite |
| 17.1.2首个源码/测试/generator大补丁使用了错误的测试列表相邻锚点 | 1 | `apply_patch`整体拒绝且没有部分文件；读取generator真实三处membership后拆分新增源码与精确列表补丁 |
| 17.1.1首轮iOS26 strict API probe使用class级`@MainActor` delegate和deprecated display-layer queue API | 1 | PiP delegate改用显式`@MainActor` isolated conformance；frame sink改用`AVSampleBufferDisplayLayer.sampleBufferRenderer`的ready/enqueue/flush API，最终warnings-as-errors probe零诊断通过 |
| 17阶段首轮OpenSpec strict把四个换行到第二行的`SHALL`描述判为无规范词 | 1 | 将scene ownership、geometry、PiP lifecycle和display ownership描述首行改为显式`SHALL`，用全新证据目录重跑完整artifact门 |
| 16.6.3 analyzer最终TSV期望值在含单引号description后把分隔符写成字面量反斜杠`t` | 1 | Debug/Release analyzer与xcresult均已成功且plist完整；不重跑分析，用字段化`printf`从同一bundle重建expected并复核8项精确相等 |
| 16.6.3首轮repository包装器把每个entitlement路径在pbxproj中的file reference与Debug/Release settings误断言为2处 | 1 | 实际生成器稳定且每个平台精确为3处；修正为file reference加两配置的3处，从全新证据目录重跑完整repository/API gate |
| 16.6.2第二轮repository gate用`! rg`检查Keychain opt-in，说明文档中的否定示例仍被打印且反向条件未显式计数 | 1 | 移除文档中的赋值字面量，改为先捕获匹配结果并显式断言为空，从全新目录重跑完整最终门 |
| 16.6.2首轮repository gate沿用旧OpenSpec strict摘要字段`.summary.failed/.passed/.total` | 1 | strict实际已通过`7/7`但包装器在生成器前退出；按当前schema改读`.summary.totals`并从全新证据目录重跑完整提交前门 |
| 16.6.1结构化验收包装器使用macOS `/bin/bash` 3.2不支持的`mapfile` | 1 | xcresult已成功生成且测试通过；不重跑suite，改用POSIX兼容的换行计数与精确字符串比较，从同一只读bundle完成全部断言 |
| 16.5.5记录macOS universal失败的首个跨文件补丁误判`findings.md`现有调查文本 | 1 | `apply_patch`整体拒绝且未产生部分修改；读取真实尾部后按现有四条调查记录精确追加 |
| 16.5.5首轮四平台build在macOS universal的x86_64批次将`Text + Text`弃用诊断提升为错误 | 1 | arm64 focused/full均通过但该跨平台轮不计验收；按macOS 26 SwiftUI合同改为可本地化`Text`插值，更新接线回归后从全新证据目录重跑 |
| 16.5.5首轮focused在8项测试全部通过后由zsh读取不存在的`PIPESTATUS[0]`而退出1 | 1 | xcresult结构化确认测试成功且零诊断，但该包装器不计最终组合证据；改用显式`/bin/bash`和全新DerivedData/result bundle重跑 |
| 16.5.5记录focused包装器错误的首个补丁误写表格分隔列宽 | 1 | `apply_patch`整体拒绝且未产生部分修改；读取实际锚点后按现有`|------|---------|---------|`精确重试 |
| 16.5.5本地化API编译探针同时要求`LocalizedStringResource: Hashable` | 1 | 探针确认`Text`/`Label`/accessibility可直接消费resource，但resource不满足Hashable；presentation content只保留所需`Sendable`，不人为包装或字符串化 |
| 16.5.4首轮focused测试以无类型`nil`调用两个Optional presentation initializer | 1 | production源码已编译；把nil fixture显式标注为`SessionMediaAudioRuntimeState?.none`，失败bundle不计验收并从全新DerivedData重跑 |
| 16.5.3只读repository检索把含反引号的pattern放进zsh双引号 | 1 | 该子命令在检索前发生命令替换且未改仓库；后续含Markdown反引号的pattern使用单引号，不重复该命令 |
| 16.5.3首轮focused包装器在测试成功后读取zsh中不存在的`PIPESTATUS[0]` | 1 | 保留已成功生成的xcresult并结构化确认23/23通过、零诊断；其余管线显式使用`/bin/bash`，不重复该包装器 |
| 16.5.2并行读取同一xcresult的summary/tests/build明细触发Xcode临时`database.sqlite3`同名冲突 | 1 | summary与build结果已成功且bundle未损坏；tests明细改为串行只读，确认唯一skip为显式真实Keychain用例 |
| 16.5.2首轮focused包装器在zsh下用`PIPESTATUS[0]`读到空字符串 | 1 | `xcodebuild`与xcresult已结构化确认21/21通过；收紧语义后改用显式Bash、普通`$?`和全新DerivedData/result bundle完整重跑最终focused gate |
| 17.5.2首轮focused并发测试Task捕获非Sendable `XCTestCase self` | 1 | 在Task创建前构造不可变Sendable input，保留真实FIFO并发覆盖并以全新证据目录重跑通过 |
| 17.5.2误并行读取同一个full xcresult再次触发临时`database.sqlite3`冲突 | 1 | bundle和测试未损坏；不重跑测试，严格串行读取summary、build-results与tests明细并确认881/880/1/0及唯一Keychain skip |
| 17.5.2首轮repository final gate在zsh函数中使用局部变量`path` | 1 | fixture/OpenSpec/generator/静态边界后、xcresult读回前因覆盖`PATH`退出；该轮不计验收，改用显式Bash和`result_path`从全新目录完整重跑 |
| 17.5.3五构建矩阵统一假设app根目录存在`Info.plist` | 1 | 五个平台构建、结构化诊断和Metal产物均已成功；macOS plist实际位于`Contents/Info.plist`，保留完成产物并用bundle内结构化搜索重新执行全矩阵plist/签名断言 |
| 17.5.3配置矩阵r2用`rg -c ... || true`统计零匹配 | 1 | 验证在任何built plist读回前因空字符串整数比较退出；改用始终输出数字的`grep -Ec`，继续只读同一批完整build产物 |
| 17.5.3首轮repository pre-gate把iOS plist生成器出现数断言为1 | 1 | 正确结构为Configuration membership和iOS `INFOPLIST_FILE`各1处；门在build证据读回前退出，修正为2并从全新目录完整重跑 |
| 16.3.6首轮expanded包装器由zsh给退出码变量命名为只读`status`，在xcodebuild完成后报错 | 1 | xcresult已独立确认77/77通过且无残留进程；为消除包装器歧义，改用显式Bash和变量`rc`在新隔离目录完整重跑最终扩大门 |
| 16.3.6首轮focused包装器把字面量`$(inherited)`放在双引号中，Bash执行了不存在的`inherited`命令 | 1 | 该轮虽以双重`-warnings-as-errors`通过24/24但不作为最终证据；后续命令移除有歧义的override，只使用显式warnings-as-errors build settings并从全新DerivedData重跑 |
| 16.3.5首轮编译对`event.refreshesRouteCapability ? value : nil`的`nil`缺少显式Optional上下文，Swift无法推断 | 1 | 改为带显式类型的`let refreshedRoute: SpatialAudioRouteCapabilityState?`，随后用全新DerivedData完整重跑聚焦与扩大测试 |
| 16.3.5首轮macOS最终构建误用不存在的`LuneX` scheme | 1 | 失败发生在进入构建前且不计证据；改用实际`LuneX-macOS` scheme和全新隔离目录完整重跑并从xcresult确认成功及零诊断 |
| 16.3.3最终静态门把类型推断的`.sharedInstance()`误写成只匹配显式`AVAudioSession.sharedInstance()`并断言计数为1 | 1 | 实现、测试和build未失败；改为分别断言旧显式调用为0、新adapter内`.sharedInstance()`为1后重跑剩余repository gate |
| 16.3.2首个entitlement/generator大补丁假设main group字符串上下文可直接匹配 | 1 | `apply_patch`整体拒绝且工作树保持clean；读取实际generator段落后拆分为文件/target配置与group两次精确补丁 |
| 16.2.6首轮focused测试把`await`写入XCTest同步autoclosure，并以未重新赋值的局部`weak var`触发warnings-as-errors | 1 | 先await actor readback到局部纯值，再以通用`WeakReference`容器验证释放；新隔离DerivedData focused gate通过 |
| 16.2.6首个visionOS build经外层编排cell提前结束，日志停在Swift依赖生成且没有形成xcresult | 1 | 不把包装器退出视为build通过；改用直接`exec_command`和全新隔离目录完整重跑，随后从xcresult确认succeeded与零结构化诊断 |
| 16.1.5四平台构建包装器由zsh解释Bash数组索引并报`bad substitution` | 1 | 失败发生在任何build前；保留测试证据，改用显式`/bin/bash`和新证据目录完整重跑 |
| 16.1.5首轮focused编译因新增`makeInput`参数调用顺序错误而失败 | 1 | 失败发生在测试运行前；按Swift声明顺序移动`userEnablesSpatialAudio`并用全新DerivedData重跑 |
| 16.2.2首个只读Swift buffer探针使用不存在的`UnsafeAudioBufferListPointer` | 1 | 编译前失败且未创建音频graph；按已知单一interleaved buffer改读`audioBufferList.pointee.mBuffers`，随后四layout探针通过 |
| 16.2.2四平台构建包装器使用zsh只读变量`status` | 1 | 四个xcodebuild均已启动；macOS/iOS/tvOS先完成，visionOS继续到终态。没有重跑成功构建，改为等待进程结束并直接从四份xcresult读回succeeded与零结构化诊断 |
| 16.2.3首次临时probe命令提交了空`apply_patch`占位hunk | 1 | patch在任何文件写入前整体拒绝；不重试该路径，改用`xcrun swift`标准输入运行只读AVFAudio probe |
| 2.1 repository gate用裸`references/`正则把`Library/Preferences/`中的字符子串误报为reference路径 | 1 | 保留已通过的OpenSpec/generator证据，将production扫描收紧为路径token边界后仅重跑未完成门 |
| 2.1边界门恢复时按最新mtime选择到并发验收流的不同证据布局，找不到`project-before.sha256` | 1 | 停止推断最新目录，按`D3aZxd`与`4udJFX`固定路径分别核对并合并证据 |
| 2.1 final2构建目录未保留其记录的simulator before/after JSON，读回脚本无法复证该哈希 | 1 | 不将缺失artifact算作通过；使用本轮`bEQNit`中已保留并`cmp`相同的快照作为simulator证据 |
| 2.1证据读回误按顶层`.valid`检查OpenSpec JSON，实际schema为`.items[].valid` | 1 | simulator复证已完成；按真实JSON schema只重跑剩余repository/OpenSpec检查 |
| 15.2.2 mapper大补丁与同范围并发实现发生上下文碰撞 | 1 | `apply_patch`整体拒绝且无部分写入；审计并沿用已出现的shared validator/mapper/tests，不创建第二套合同 |
| 15.2.3五平台Bash包装器在同一`local`声明中提前引用`n`，`set -u`报unbound variable | 1 | 失败发生在任何build前；改为分行赋值并用新目录完整重跑 |
| 15.3.1四个平台`xcrun metal`均报告缺少Metal Toolchain | 1 | 使用Xcode官方`xcodebuild -downloadComponent MetalToolchain`安装后重新验证各SDK，不以普通Swift build替代 |
| 15.3.1首次macOS Metal warnings-as-errors编译发现两个默认分支常量未使用 | 1 | 删除未引用的Rec.709 selector常量；保留else默认语义并从新目录重跑全部四SDK |
| 15.3.1 focused后共享shader改动新增两个未引用mapping常量，full build被`-Werror`拒绝 | 1 | 保留HDR-to-SDR headroom=1语义，删除两个残留selector；废弃旧focused证据并全门从新目录重跑 |
| 15.2.4只读`rg`命令中的反引号进入双引号导致zsh unmatched quote | 1 | 命令未执行且无文件/设备变化；改用单引号固定pattern后成功读回 |
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
| 18.5.6 repository pre-gate 使用 zsh 特殊变量名 `path`，覆盖 `PATH` 后找不到 `xcrun` | 1 | `/tmp/LuneX-18-5_6-repository-pre.j564sL`前六项通过但不计最终验收；改用`result_path`并从fresh目录完整重跑，未重复test/build或操作Simulator |
| 18.5.6 repository pre-gate 要求capability spec包含字面任务号`5.6` | 1 | `/tmp/LuneX-18-5_6-repository-pre-r2.SPvLNa`已通过前九项；spec按场景语义写作而不含任务号，改为断言实际矩阵场景与关键行为后fresh重跑 |
| 18.5.6 post-mark final-state 的checkbox diff正则遗漏Markdown列表连字符 | 1 | `/tmp/LuneX-18-5_6-final-state.dfywG2`已确认`31/50`与11文件scope；改为精确匹配`-- - [ ]`/`+- [x]`两行后fresh只读重跑 |
| 18.5.6 post-record 使用不存在的design摘要句 | 1 | `/tmp/LuneX-18-5_6-post-record.BFxsJz`已通过OpenSpec、scope与五份索引；改为匹配design实际的three connected regression matrices句子后fresh重跑 |
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
| 18.7.2首轮focused使用不存在的`LuneX` scheme | 1 | 读取`xcodebuild -list`后改用`LuneXCoreTests`，从fresh DerivedData/result bundle重跑 |
| 18.7.2首轮正确scheme编译时fixture使用不存在的`SpatialAudioPresentationMode.visionHeadTracked` | 1 | route snapshot改用`.headTracked`，actual visionOS mode继续由`SpatialAudioPresentationStatus.Mode.visionHeadTracked`表达，并从fresh bundle重跑 |
| 18.7.2续接检索命令中的反引号被zsh解析为glob | 1 | 命令只读且无仓库副作用；后续固定使用单引号模式或转义反引号，不重复该写法 |
| 18.7.2首次跟踪文件补丁使用过期`progress.md`尾部上下文 | 1 | `apply_patch`整体拒绝且工作树未变化；读取当前真实尾部后拆成精确补丁 |
| 18.7.2首次authority组合补丁使用跨行design锚点 | 1 | `apply_patch`整体拒绝且没有部分文件；改为按稳定Markdown标题拆分单文件补丁 |
| 18.7.2首轮repository pre-gate对换行表达式与测试函数名使用过窄文本模式 | 1 | fixture/strict/generator/scope均已通过且测试读取尚未开始；改用源码真实稳定符号，从fresh证据目录完整复核 |
| 18.7.2 repository pre-gate r2在zsh中使用特殊变量名`path` | 1 | 赋值覆盖zsh绑定的`PATH`数组并导致`xcrun`不可见；无测试/build重跑或设备副作用，r3显式使用Bash及`result_path` |
| 18.7.2首轮final diff audit把unified diff的`---`文件头计为删除行 | 1 | 分类和任务门已通过且实现语义尚未检查；删除断言改为`^-[^-]`排除header，从fresh目录完整重跑 |
| 18.7.3首轮focused fixture使用不存在的`VisionPresentationUnavailableReason.publicAPIUnavailable` | 1 | production无诊断；改用现有typed `.stage18WindowedOnly`，从fresh DerivedData/result bundle重跑 |
| 18.7.3首次authority组合补丁假定tvOS media requirement的旧措辞 | 1 | `apply_patch`整体拒绝且无部分修改；读取四份spec真实场景后按稳定标题拆分补丁 |
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
| 14.1.2/14.2.3 simulator只读审计在对象literal内使用`as`绑定 | 2 | 两次均为`jq`编译失败且未修改设备；固定写法为先将输入绑定为`$root`、UUID数组绑定为`$ids`再构造结果，后续直接复用脚本而不手写对象内绑定 |
| 14.1.3首轮focused gate有fill浮点exact断言且AppModel测试缺source geometry | 1 | production按合同保持不变；fill改为accuracy断言，AppModel测试先建立有效source再验证lifecycle drawable发布snapshot |
| 14.1.3首次五平台build误用不存在的`LuneX` scheme | 1 | 编译启动前即失败且未启动simulator；用`xcodebuild -list`确认后分别改用`LuneX-macOS`、`LuneX-iOS`、`LuneX-tvOS`与`LuneX-visionOS`，新隔离目录重跑 |
| 15.4.1恢复记录补丁两次假设了不存在的`findings.md`精确标题 | 2 | 两次`apply_patch`均整体拒绝且未修改文件；读取真实尾部后按现有`验收结论`二级标题和progress实际结尾精确追加 |
| 15.4.1首个Swift SDK探针用zsh `set -- $spec`拆分`SDK target` | 1 | zsh未启用SH_WORD_SPLIT，整行被当成SDK名且编译未启动；改为`while read -r sdk target`显式逐字段读取 |
| 14.2.2首轮focused compile发现新增media error未同步diagnostic穷尽分类 | 1 | 不添加default掩盖；将stale lifecycle收敛为稳定`media_lifecycle_stale` transport诊断并补无秘密分类回归，新隔离目录重跑 |
| 14.2.3首轮focused命令误用无test action的App scheme，且尾部使用zsh只读变量`status` | 1 | 测试与编译均未开始；通过`xcodebuild -list`确认改用`LuneXCoreTests`，退出码变量改为`rc`并在新隔离目录重跑 |
| 14.2.3第二轮focused compile发现新测试在XCTest autoclosure内直接`await` actor属性 | 1 | production源码无编译错误；先await到局部值再做同步断言，以新隔离目录重跑 |
| 14.2.4五平台构建前后原始simulator JSON的`cmp`失败 | 1 | 差异仅为三个runtime的`lastUsage`时间；改为规范化设备身份/状态字段后逐字节一致，并独立验证固定名称/UUID唯一、全部`Shutdown`且全局`Booted=0` |
| 14.3.1首轮focused唯一失败把通用input诊断中的`session`单词视为泄漏 | 1 | 文案无UUID或generation值且沿用既有安全input摘要；删除过严断言，保留category/code/action和无generation检查后以新目录重跑 |
| 14.3.2恢复时误用不存在的`LuneX` scheme枚举destination | 1 | 命令在编译前失败且未触及simulator；沿用工程实际四个App scheme执行五平台构建 |
| 14.3.2首次production/reference扫描包含不存在的`Apps`目录并让`references/`匹配`Preferences/` | 1 | 改为只扫描实际production目录，并使用路径边界模式，避免缺目录与子串假阳性 |
| 14.3.3第二轮focused gate在warnings-as-errors下发现新race测试有未使用局部值 | 1 | 删除不参与断言的`firstSession`局部值，以新隔离DerivedData重跑并通过`11/11` |
| 14.4.3首轮focused gate的既有FIFO测试使用`absolute button-down + nil point` | 1 | 按新fail-closed合同改用有效absolute点并断言映射坐标，以新隔离DerivedData重跑 |
| 14.4.4首轮focused继承`MTKView`后沿用failable `init?(coder:)` | 1 | 按Xcode 26.4 `MTKView`真实签名改为unavailable non-failable `init(coder:)`并以新目录重跑 |
| 14.4.4第二轮focused的test target缺少surface/monitor production sources且断言形成`NSWindow??` | 1 | 同步generator test-support列表并显式unwrap window，以新隔离DerivedData重跑 |
| 14.5.1首轮focused包装器误用zsh只读`status`且新monitor调用传入weak optional view | 1 | 从保留日志定位真实Swift错误，在observe边界guard当前view，并改用`exit_code`后以新目录重跑 |
| 14.3.3首次从工具缓存读取full xcresult路径时混入截断警告前缀 | 1 | 不重跑测试，直接使用已输出的明确证据目录读取结构化summary，确认`408/407/1/0` |
| 14.3.3最终focused复核命令尝试先删除可能存在的result bundle而被本地安全策略拒绝 | 1 | 不删除任何路径，改用全新的`FinalCoordinator2.xcresult`执行并通过`8/8` |
| 14.4.2首轮focused测试factory把optional characters传给`NSEvent.keyEvent` | 1 | production无编译错误；测试对无字符的`flagsChanged`事件传空字符串，并在新隔离目录重跑 |
| 14.5.2首轮快速编译误用`LuneXCoreTests`的`build` action | 1 | 该scheme只提供test action；App继续用App scheme build，测试改用`LuneXCoreTests test`并以新隔离DerivedData运行 |
| 14.5.2 lifecycle pump弱引用闭包推导为`Task<Void?, Never>` | 1 | 显式`guard let self`后调用drain，使Task成功类型稳定为`Void`并重跑warnings-as-errors |
| 14.5.2扩大focused门出现两个中间状态断言竞态 | 1 | 分别等待session进入streaming与coordinator完成release计数，不用fake environment的提前记录替代最终AppModel状态 |
| 14.5.3跟踪补丁误把`progress.md`验收句当作`findings.md`上下文 | 1 | `apply_patch`整体拒绝且生产代码未改；读取两个文件真实尾部后分别按现有末行精确追加 |
| 14.5.3首轮focused两项旧surface测试仍依赖默认开启admission | 1 | 新production默认fail closed正确且新增policy测试通过；旧fixture改为附着window并显式应用direct active policy后重跑，不放宽production默认值 |
| 14.5.3封版审阅发现旧dismantle的attachment回调可能重取cursor lease | 1 | 未附着路径改为只释放匹配lease且不apply inactive claim；新增真实双coordinator replacement后旧dismantle回归，全部最终门禁重新执行 |
| 14.5.3竞态修复首个补丁跨错production/test文件上下文 | 1 | `apply_patch`整体拒绝且无修改；拆为Metal surface生产补丁和测试/跟踪补丁后精确应用 |
| 14.5.4启动跟踪补丁误把`progress.md`末句当作`findings.md`上下文 | 1 | `apply_patch`整体拒绝且无修改；读取两个文件真实尾部后分别按精确末行追加，并继续保持生产代码未触及 |
| 14.5.4首个生产大补丁的AppModel尾部上下文不匹配 | 1 | `apply_patch`整体拒绝且无源码修改；精确读取`refreshMacInputSurfacePolicy`尾部后拆为诊断模型、store、UI与AppModel小补丁应用 |
| 14.5.4首轮focused唯一失败在input activation中间态提前断言action已清理 | 1 | production先创建coordinator generation、await返回后才登记App generation并清input action；测试等待完整恢复事务而非仅等待coordinator内部generation非空 |
| 14.5.4五平台构建前simulator只读校验再次误用`all(generator; condition)`且尾部printf掩盖jq退出码 | 1 | 未修改任何设备；复用`. as $root`后生成固定设备校验数组再`map(...) | all`，并以`&&`确保失败立即向外传播 |
| 14.5.4仓库门禁调查误假设生成器位于复数`scripts/` | 1 | 命令在只读列目录阶段失败；仓库实际为`Tools/generate_xcodeproj.rb`和单数`script/`，读取现有进度记录后使用真实路径执行 |
| 14.5.4 provider失败夹具的无上下文替换命中较早同名初始化 | 1 | diff复核在测试前发现；恢复lifecycle缓存测试默认值，并用测试函数名上下文把`failsInputSend`只放到目标诊断测试 |
| 14.5.5首轮单一集成门假设fake media environment会启动native presentation source | 1 | fake environment按设计绕过`NativeSessionVideoProcessor`；改为显式注入并播入受控decoder generation，只验证AppModel的occlusion/resume/stop presentation清理，不声称fake environment产出真实帧 |
| 14.6.2首次构建矩阵包装器由外层zsh破坏bash/jq引号 | 1 | 失败在任何xcodebuild/simulator操作前；改由执行工具直接选择bash。后续两轮发现AppIntents skip warning，最终以SwiftBuild公开`LM_SKIP_METADATA_EXTRACTION=YES`验证并取得十构建零诊断证据 |
| 14.6.3 ASan日志扫描匹配命令行参数，汇总脚本用zsh保留`path`覆盖`PATH` | 2 | 不重跑已成功suite；日志扫描收紧到实际sanitizer报告前缀，汇总改为直接bash与`evidence_path`，结构化结果和所有证据重新核对通过 |
| 15.1.1源码盘点误用已不存在的`Sources/LuneXCore/StreamRenderState.swift`与错误的media/UI路径 | 1 | 用`rg --files Sources`定位真实`PlatformLifecycle.swift`、`SessionMediaEnvironment.swift`与`LuneXApp/RootView.swift`后继续只读盘点 |
| 15.1.1首次Swift stdin typecheck把换行作为字面`\\n`传入 | 1 | 改用`printf '%b'`向`swiftc -typecheck -`传递真实换行；macOS/iOS/visionOS成功，tvOS得到预期的EDR API unavailable诊断 |
| 15.1.1首个跨平台API probe把CAMetalLayer EDR和UIScreen统一视为UIKit能力 | 1 | probe在tvOS编译前明确失败并证明layer/CAEDRMetadata unavailable；拆分验证确认tvOS有UIScreen headroom/颜色空间但无layer EDR，visionOS有layer EDR但UIScreen unavailable，写入平台矩阵 |
| 15.1.2首个focused命令把变量赋值和xcodebuild续行错误拼成单一shell命令 | 1 | 失败发生在xcodebuild启动前并尝试重定向到只读根路径；改为变量赋值独立一行、xcodebuild参数单行，在新证据目录通过`10/10` |
| 15.1.2初始大补丁遇到共享执行流已创建同名contract/test文件 | 1 | `apply_patch`上下文校验整体拒绝且没有覆盖；改为审计现有实现，仅补metadata-mode、source/mapping与active ownership不变量 |
| 15.1.2仓库门把xcresult tests节点字段误写为`testStatus` | 1 | 前置OpenSpec/generator/reference门均通过；读取真实JSON确认字段为`result: Skipped`，改用该字段和精确测试名在新证据目录从头复验 |
| 15.1.3首轮focused编译发现validator error关联的metadata error缺`Hashable` | 1 | 既有closed `VideoColorMetadataError`的关联值均可哈希，补值语义conformance后用新隔离DerivedData重跑 |
| 15.1.3大补丁与共享执行流同名decoded contract实现发生上下文碰撞 | 1 | `apply_patch`整体拒绝且没有留下新文件；审计并沿用已出现的`HDRDecodedVideoContract`，不创建第二套validator |
| 15.1.3首次focused命令误用无test action的`LuneX-macOS` scheme | 1 | xcodebuild在测试启动前失败且xcresult为`0 tests / unknown`；从`xcodebuild -list`确认改用`LuneXCoreTests` scheme和全新DerivedData |
| 15.1.3首次五平台包装器在bash中使用zsh式1-based数组索引 | 1 | 只完成iPhone/iPad build且未启动设备后主动中止；改用`${!names[@]}`与0-based索引，在新证据目录从macOS开始完整重跑 |
| 15.1.3仓库门的`references/`扫描误命中`Preferences/`子串 | 1 | 实际命中仅为Moonlight plist路径；规则收紧为单词边界`\breferences/`后在新证据目录重跑全部门 |
| 15.1.4首轮Rec.709 breakpoint测试把`0.081`误按线性分支期望`0.018` | 1 | 规范条件为`E' < 0.081`，边界应走幂函数并得到`0.0179450234`；修正known vector后用新DerivedData重跑 |
| 15.1.5首轮focused编译被相等source-peak分支的未使用`content`绑定阻止 | 1 | warnings-as-errors在测试前失败；等值分支改为两值平均以明确双metadata来源，并用新DerivedData重跑 |
| 15.1.6首轮focused编译对error existential数组使用了无法推断类型的简写case | 1 | 测试未运行；为每个case补完整enum类型限定后用新DerivedData重跑，不缩减网格 |
| 15.1.6 monotonicity网格发现rounded BT.709 inverse transfer在`0.081`附近向下跳变 | 1 | 不放宽断言；改用连续BT.709精确`alpha/beta`与`4.5*beta`切点，并重跑1.4/1.6 focused和完整门 |
| 15.1.6计算BT.709舍入公式交点时本机Python缺少SciPy | 1 | 不安装新依赖；改用stdlib确定性bisection确认双交点，最终采用规范连续精确常数而非移动舍入公式cut |
| 15.1.6精确BT.709修复补丁遇到共享执行流已应用相同修改 | 1 | `apply_patch`上下文校验拒绝且未覆盖；审计现有alpha/beta/breakpoint与known-vector一致后沿用当前文件 |
| 15.3.3恢复调查误用不存在的`HDRRenderConfiguration.swift` | 1 | `rg --files`确认真实合同文件为`HDRRenderContract.swift`，记录后改读正确文件且不重复失败命令 |
| 15.3.3首个跨文件大补丁假设vertex shader仍为单行旧签名 | 1 | `apply_patch`整体拒绝；检查发现共享执行流已并发加入同名renderer/shader/tests并启动focused test，等待其完成后保留、审计并只补ownership缺口 |
| 15.4.5恢复后的五平台包装误用不存在的`LuneX` scheme | 1 | 失败发生在编译前且未触及simulator；读取`xcodebuild -list`后使用四个真实App scheme和全新证据目录重跑 |
| 15.4.5 repository预扫的reference正则含嵌套引号并被zsh拒绝 | 1 | 命令未执行且无文件变化；改用不含嵌套引号的精确`references/`路径token并完成全门 |
| 15.4.5 repository工具发现命令同时查询不存在的复数`scripts/` | 1 | 只读`find`返回错误；沿用仓库真实`Tools/`和单数`script/`布局，不重复该路径假设 |
| 15.4.6 SDK swiftinterface搜索使用未引用的多层glob | 1 | zsh在读取前以`no matches found`拒绝；改为逐平台QuartzCore/UIKit SDK header路径并取得精确availability宏 |
| 15.3.3测试直接调用不存在的raw shader-uniform initializer | 1 | 不开放测试后门；改用合法HDR contract/configuration/mapping构造与active SDR不匹配的uniforms验证fail-closed |
| 15.3.3测试helper加入局部`isHDR`后缺少显式`return` | 1 | 补上显式返回并用全新DerivedData重跑，失败证据不计入验收 |
| 15.3.3共享completion合同落盘后recording stub仍实现旧submit签名 | 1 | 保留ownership revision补强，更新stub和延迟completion回归，并修正同步wait回调避免锁互等 |
| 15.3.4首轮focused构建期间读到早期1x1 chroma零尺寸版本并导致4个测试进程崩溃 | 1 | 不复用失败证据；保留共享流已落盘的`max(half, 1)`修正，增加private-target blit readback和fit letterbox覆盖后从全新DerivedData重跑 |
| 15.3.4只读simulator快照命令含`rm -rf`而被执行策略拒绝 | 1 | 不请求放宽权限；改用`mktemp -d`创建全新证据目录并成功完成相同只读清单比较 |
| 15.3.6首次恢复focused包装误把shell脚本直接传给JavaScript orchestration入口 | 1 | shell未启动且未修改工作区；改由`tools.exec_command`执行同一命令并使用全新DerivedData |
| 15.3.6 Xcode 26.4在macOS 27 beta上枚举xcresult tests时内部database move冲突 | 1 | 不重复失败子命令；用xcresult summary/build-results证明总数与零诊断，并从原始xcodebuild日志精确确认唯一Keychain skip |
| 15.4.2首轮focused的既有AppKit通知测试仍期待`localizedName` | 1 | production已改用可区分同名屏幕的内部`NSScreenNumber`；测试改为计算同一编号，并锁定重复通知/resize不增加display revision |
| 15.4.2 focused包装器使用zsh只读变量名`status` | 1 | 测试已经完成且xcresult可读；后续新目录包装器改用`build_status`，不复用该失败退出码 |
| 15.5.2 reconnect回归跨control/media stream并发发送metadata与decoded events | 1 | xcresult精确定位EDR等待；测试先等待negotiated metadata生效再发送decoder/frame，保留production reconnect时序修复并从新目录重跑 |
| 15.5.2 repository包装器的strict-valid变量行混入无意义字符串 | 1 | fixture/strict后、generator前退出且未改代码/设备；修正赋值并从全新证据目录完整重跑，不复用部分结果 |
| 15.4.2首轮完整suite发现另一项geometry测试仍期待`localizedName` | 1 | 失败suite为`569 passed / 1 Keychain skip / 1 failed`且不计验收；抽取共享screen-number helper更新全部旧断言后从新DerivedData重跑 |
| 15.4.2五平台包装器把`rg -c`零匹配解析为空字符串 | 1 | macOS build本身成功但包装器证据不计；计数改用显式`|| printf 0`，从新证据目录和全新DerivedData完整重跑五平台 |
| 15.4.2提交后GitHub直连超时 | 2 | `github.com:22`、`ssh.github.com:443`与HTTPS 443均超时而DNS正常；检查现有Surge系统代理后用SOCKS5恢复GitHub连接。fetch确认首次无输出push实际已成功发布`d37aed8`，不强推或重复提交4.2 |
| 15.4.3首轮focused误用app-only scheme | 1 | `LuneX-macOS`未配置test action，命令在编译前退出；改用已有`LuneXCoreTests` scheme，并从全新DerivedData/xcresult重跑 |
| 15.4.3第二轮focused的resolver input误声明`Hashable` | 1 | `HDRDisplaySnapshot`只需保持自定义NaN语义的`Equatable`；移除无用途的input hash要求，resolved output仍为`Hashable`，使用新DerivedData重跑 |
| 15.4.3第三轮focused的invalid-metadata fixture同时制造bit-depth mismatch | 1 | validator正确先返回incompatible layout；fixture改为NV12配8-bit伪HDR，只保留metadata缺陷后用全新路径重跑 |
| 15.4.3第四轮fixture仍以8-bit HDR触发layout优先级 | 1 | 8-bit HDR按合同必然先失败layout；改用合法HDR10/P010结构加全零content-light，只隔离nested metadata validation |
| 15.4.3首轮repository组合门的reference正则嵌套引号被zsh截断 | 1 | 命令在创建临时目录后、任何generator/OpenSpec/fixture执行前以`unmatched "`退出；拆分为不含嵌套引号的路径与token扫描，并用新证据目录完整重跑 |
| 15.4.3第二轮repository门按旧schema断言OpenSpec summary | 1 | 原始JSON实际为`summary.totals`且6项均valid；该轮部分结果不计最终验收，改按当前schema和`.items[].valid`断言并从新目录完整重跑 |
| 15.4.4启动时远端核对漏加Surge代理 | 1 | `git fetch origin main`无输出挂起后主动中止且工作树未变；改用既有SOCKS5命令成功确认`HEAD == origin/main == e0a4cee`，后续GitHub操作固定带代理 |
| 15.4.4首轮focused编译找不到`surface`局部值 | 1 | SDR contract声明在`do`块内却在后续锁中记录ownership；将局部声明提升到`do`之前并用全新DerivedData/xcresult重跑 |
| 15.4.4第三轮closed恢复测试错误假设默认策略active | 1 | `StreamRenderState()`默认`.idle`，实现正确保持view paused；测试显式设`.active`以验证按当前策略恢复，并从全新证据路径重跑 |
| 15.4.4首轮五平台包装器误在zsh使用Bash数组索引 | 1 | 首个build前以`bad substitution`退出且未触碰设备；改用显式Bash、新证据目录和新前置清单完整重跑 |
| 15.4.4首轮repository whitespace口径误纳入vendor | 1 | 172处命中全部来自固定上游`ThirdParty/ENet`，自有文件/current diff clean；排除vendor后从全新目录完整重跑既有门禁 |
| 15.5.1 presentation revision exhaustion首轮保留了调用方刚写入的decoder generation | 1 | 将首次overflow与后续exhausted发布统一经过`clearRevisionOwnedPresentation()`，四项ownership/exhaustion focused门从全新证据路径通过 |
| 15.5.1路线图搜索包含不存在的`README.md`并以`rg`退出码2结束 | 1 | 命令只读且已返回所需匹配；后续只读取仓库中实际存在的HDR合同、roadmap和三份跟踪文件 |
| 15.5.3 presenter replacement回归误用不存在的`sdrVideoRange()` fixture | 1 | production源码已通过编译；测试改用既有`rec709VideoRange()`，失败xcresult不计验收并从全新DerivedData重跑 |
| 15.5.3 repository包装器最终摘要的`jq`嵌套引号编译失败 | 1 | 实质门禁和生成器稳定性已先通过，但该轮不作最终证据；摘要改用数组/TSV表达式并在全新目录完整重跑 |
| 15.5.3最终构建证据读回使用zsh只读变量`status` | 1 | simulator快照和归一化比较已完成但该包装器不计完整验收；改用`build_status`，只重跑尚未完成的五平台结果/Metal产物读回并通过 |
| 15.5.5恢复记录补丁假设`findings.md`存在`任务 5.4 完成`标题 | 1 | `findings.md`实际使用`任务 5.4 调查`标题；补丁在写入前整体拒绝且工作树仍clean，改按真实尾部上下文分别追加 |
| 15.5.5首轮focused测试引用其他文件的`private` stubs | 1 | production源码未报错、测试未运行；改用无副作用默认依赖并注入`.unavailable` provider与内存identity store，从全新DerivedData重跑 |
| 15.6.3两个bash包装器的`${...}`被外层JavaScript模板解释 | 2 | 命令在shell启动前失败且没有执行门禁；仓库门改用`sed`派生相对路径，resource门改为显式列出24个test selector |
| 15.6.3 analyzer expected TSV与ASan skip复核沿用不匹配的文本口径 | 2 | analyzer改为逐字段和行号断言；ASan按当前Xcode日志中的唯一skipped case精确校验，不重跑已经成功的suite |
| 15.6.3首轮resource xcresult含`llvm-profdata`继承MallocStackLogging的工具warning | 1 | 测试本身`343/343`且零malloc错误，但该bundle不计最终零诊断证据；关闭无关code coverage后用全新DerivedData重跑同一24类与全部malloc强化参数 |
| 15.6.4首轮只读审计把跨runtime同名设备误当作固定identity重复 | 1 | 三份快照与固定UUID/state实际均通过；改为按`runtime + name + UUID`验证四个固定26.4 identity，并单独披露iOS/xrOS 27 runtime的系统同名实例与全局`Booted=0` |
| 16阶段首轮跨平台Swift API probe在双引号中使用`$0` | 1 | zsh把closure参数展开为shell路径，probe在iOS typecheck阶段失败且未改仓库；改用显式`port in`闭包参数后从四平台重新执行 |
| 16.1.1提交前OpenSpec摘要的`jq`把generator与对象构造混用 | 1 | strict本身已通过但摘要命令在diff前退出；改为先把JSON绑定为`$root`再从tasks数组取首个pending，随后重跑完整提交前门 |
| 16.1.2 focused结果摘要沿用旧字段`testsPassed/testsFailed` | 1 | xcresult实际字段为`passedTests/failedTests/skippedTests`；build structured diagnostics已正确为0，按当前schema重新读回`2/2` |
| 16.1.3首轮focused包装器误用zsh只读变量`status` | 1 | 测试实际`8/8`通过但外层退出1，不计干净验收；改用`exit_code`和全新DerivedData重跑，外层与xcresult均通过 |
| 16.1.3首轮跨平台typecheck按bash规则拆分zsh循环项 | 1 | 在任何编译前因`set -u`退出且未改仓库；改用bash数组和显式分隔字段后四平台从头通过 |
| 16.1.4首轮平台门因iOS target缺launch screen产生1条工程warning | 1 | iOS build本身succeeded但不计零诊断验收；probe确认后由generator添加`INFOPLIST_KEY_UILaunchScreen_Generation=YES`，重新生成并从新目录通过iOS/tvOS/visionOS，最终macOS复核也通过 |
| 16.2.5 repository gate把listener赋值、读回、reset三处引用误断言为两处 | 1 | strict与generator稳定性已通过且仓库未漂移；修正静态门预期为3，仅执行未完成的API branch、clean-room与diff扫描后通过 |
| 16.4.2首次调查记录补丁假设`findings.md`已有4.2标题 | 1 | `apply_patch`在写入前整体拒绝且无文件变化；读取真实尾部后改为追加完整4.2调查小节 |
| 16.4.2只读`rg`命令在双引号内包含Markdown反引号 | 1 | zsh只执行了不存在的命令替换且仍返回目标行；后续对含反引号pattern使用单引号或转义，不重复该命令 |
| 16.4.2首轮processor focused测试在XCTest autoclosure内直接`await` | 1 | case未执行且production无新增编译错误；先读actor值/iterator结果到局部常量、修正静态helper限定和多余Task await，再用全新DerivedData重跑 |
| 16.4.2第二轮consumer-cancellation测试读取`Task.result`产生相反异步诊断 | 1 | 该读取不属于行为证明；取消后只yield一次，再由后续成功reconfigure证明consumer cancellation未停止processor |
| 16.4.2系统更新恢复后的首轮focused命令误用无test action的`LuneX-macOS` scheme | 1 | 命令在编译前退出且不计验收；已核对工程scheme，改用`LuneXCoreTests`和全新DerivedData/result bundle重跑 |
| 17.4.3恢复后的首轮focused误用无test action的`LuneX-macOS` scheme | 1 | 命令在编译前退出且不计验收；再次确认测试入口固定为`LuneXCoreTests`，从全新DerivedData/result bundle重跑 |
| 17.4.3第二次focused使用ObjC通知常量名导致Swift importer编译失败 | 1 | 改用Xcode 26.4现代Swift名称`AVSampleBufferVideoRenderer.didFailToDecodeNotification`与`.requiresFlushToResumeDecodingDidChangeNotification`，从全新证据目录重跑 |
| 16.4.2恢复后的首次有效focused运行中graph-failure case等待`.failed`事件超时 | 1 | 定位为route observation task在失败收敛中取消自身，导致后续runtime snapshot命中cancellation check；移除自取消，以monitor finish自然结束observer，并从全新目录重跑 |
| 16.4.2批量读取OpenSpec上下文的编排脚本把纯路径输出误传给`JSON.parse` | 1 | 只读脚本在文件读取前退出且未改仓库；直接使用已返回的六个context path并行读取，不再解析纯文本为JSON |
| 16.6.4首轮完整ASan以裸`ENABLE_ADDRESS_SANITIZER=YES`启动 | 1 | XCTest在执行测试前于`VerifyInterceptorsWorking`中abort，属于sanitizer runtime bootstrap失败而非源码finding；不重复该命令，改用阶段15已验证的`-enableAddressSanitizer YES`与显式`ASAN_OPTIONS`先跑最小启动探针 |
| 16.6.4最终门调查误以为generator支持`--help` | 1 | 脚本忽略参数并重生成工程；Git确认输出字节一致且无额外diff，正式门不再传帮助参数，显式比较生成前及连续两次SHA-256 |
| 16.6.5固定identity的jq断言在`all()`内丢失inventory作用域 | 1 | 当前只读快照、三份cmp/hash和Booted=0已先通过；不重复`simctl`查询，对已保存JSON先绑定`$inventory`再逐项验证runtime/name/UUID/availability/state唯一性 |
| 17阶段AVKit/UIKit SDK probe沿用旧Swift标签/通知及deprecated screen连接通知 | 2 | PiP改为`completion:`且controller initializer非optional，scene通知取`UIScene.*Notification`；iOS 26禁止`UIScreen.didConnect/didDisconnect`，换屏改由actual view/windowScene attachment驱动，只保留brightness/mode/trait/layout触发 |
| 17.1.5首轮focused的coordinate boundary样本使用默认safe-area | 1 | `1 x 1` view会因默认top/bottom inset超界而正确关闭；boundary用例显式使用`.zero` safe-area，分别隔离rect端点验证 |
| 17.1.5首轮focused把unprepared `.startRequested`归类为普通invalid transition | 1 | 保留其更精确的`.pictureInPictureUnavailable`拒绝预期；其余未准备controller事件继续断言`.invalidTransition`，全部验证snapshot/revision不变 |
| 17.1.5仓库盘点再次对无参数解析的generator传入`--help` | 1 | 脚本按既有行为重生成工程且输出哈希未变化；正式门只无参数运行并比较初始及连续两次SHA-256，后续不再对该脚本传帮助参数 |
| 17.2.1首轮focused的局部弱观察引用声明为`weak var` | 1 | Swift 6.3 warnings-as-errors判定局部变量从未赋值修改；按诊断改为`weak let`，production无编译错误，使用全新DerivedData/result bundle重跑 |
| 17.2.1更新后组合验收包装器在zsh中使用Bash数组索引 | 1 | 完整macOS测试已独立成功，四平台build均未启动；保留该测试xcresult，build改用显式Bash和全新证据目录运行 |
| 17.2.1首轮repository gate误断言OpenSpec `.summary.totals.invalid` | 1 | 当前CLI schema使用`.summary.totals.failed`且`.items[].valid`真实为true；该轮在generator前退出，按真实schema从全新目录完整重跑 |
| 17.2.1第二轮repository gate对整个Metal surface文件禁用`ObjectIdentifier` | 1 | 命中仅为既有decoded-frame identity，current diff新增代码零命中；禁词检查收紧到新增行并从全新目录完整重跑 |
| 17.2.2完整xcresult case枚举触发Xcode数据库move冲突 | 1 | summary/build-results已成功证明`777/776/1/0`及零诊断；不重复失败子命令，改从原始xcodebuild日志精确确认唯一Keychain skip |
| 17.2.3首个production/tests/tracking组合补丁hunk边界无效 | 1 | `apply_patch`整体拒绝且工作树保持clean；拆为production、tests和tracking三个精确补丁继续 |
| 17.2.3首轮focused在测试启动前触发Swift 6.3 nonisolated deinit诊断 | 1 | `MobileStreamSceneLifecycleObserver`的`deinit`直接访问非Sendable `[NSObjectProtocol]`；该证据不计验收，改为窄作用域token store负责幂等移除和deinit兜底，再从全新DerivedData/result bundle重跑 |
| 17.2.4首轮iOS build命中iOS 26 deprecated scene orientation API | 1 | `UIWindowScene.interfaceOrientation`被warnings-as-errors拒绝；按当前UIKit文档改用`effectiveGeometry.interfaceOrientation`，失败bundle不计验收并从全新目录重跑 |
| 17.2.4只读simulator包装器的jq布尔链丢失根输入 | 1 | `simctl`只调用一次且原始JSON已保存；使用`.devices as $devices`绑定后从同一文件完成唯一性、available、Shutdown和全局无Booted复核 |
| 17.2.4最终仓库门的JavaScript模板误解析Bash参数展开 | 1 | 命令未进入shell且没有文件或Git改动；改用`printenv`避免`${...}`跨层插值后从全新证据目录通过 |
| 17.3.4首次iOS generic build使用不存在的`LuneX` scheme | 1 | 命令在编译前退出65且未触及Keychain或simulator；读取真实scheme后用`LuneX-iOS`和全新DerivedData/result bundle重跑并通过 |
| 17.3.4首次repository pre-gate把`.`误传为fixture root | 1 | validator按参数扫描整个仓库并命中build/reference/计划文档中的预期数据；失败发生在OpenSpec与generator前且不计验收，改用默认`Tests/Fixtures/Moonlight`根从头通过 |
| 17.3.5首轮presenter竞态夹具假设离屏MTKView transition内draw同步调用delegate | 1 | 三个observer回归通过且production零诊断；每次配置后显式执行mandatory clear与present两次draw，从全新DerivedData/result bundle重跑 |
| 17.3.5首轮repository pre-gate读取旧OpenSpec摘要字段`.summary.invalid` | 1 | fixture与8/8 strict-valid已通过但包装器在generator前主动退出；按当前`.summary.totals.failed`和`.items[].valid` schema从全新目录完整重跑 |
| 17.3.5跟踪补丁假设`findings.md`中调查小节措辞与交接摘要一致 | 1 | `apply_patch`整体拒绝且无文件变化；读取各文件真实尾部后按独立上下文拆分补丁 |
| 17.4.1对既有Swift文件运行默认`swift-format lint --strict` | 1 | 默认2-space格式与仓库既有4-space风格冲突并产生大量纯格式诊断；不批量改写，继续以warnings-as-errors编译、`git diff --check`和局部审阅作为门禁 |
| 17.4.1收紧补丁复用已变化的callback断言上下文 | 1 | `apply_patch`整体拒绝且无文件变化；用`rg -C`读取真实位置后拆分source/plan/test补丁 |
| 17.4.1首个AVKit Swift 6.3 probe让整个`@MainActor`类直接conform nonisolated ObjC protocols | 1 | 编译器以conformance-isolation拒绝；按诊断在继承列表使用`@MainActor AVPictureInPictureControllerDelegate`与`@MainActor AVPictureInPictureSampleBufferPlaybackDelegate`，四SDK warnings-as-errors均通过 |
| 17.4.4直接调用Swift nonoptional PiP controller initializer在ObjC返回nil时trap | 1 | 新增极窄Objective-C `_Nullable` content-source/controller factory；Swift bridge分两步unwrap并把support true但构造失败收敛为typed `.controllerUnavailable` |
| 17.4.4 nullable bridge首轮focused测试把IUO属性复制为未展开Optional | 1 | production已编译到测试文件；用`XCTUnwrap`明确成功构造分支的ownership不变量，并从全新DerivedData/result bundle重跑 |
| 17.4.4 macOS 27全新编译暴露display-layer client非隔离deinit读取非Sendable token | 1 | 复用私有`@unchecked Sendable` RAII token owner；显式invalidate仍立即移除，owner deinit兜底，主类deinit不再跨隔离访问数组 |
| 18.4.4首轮focused编译发现扩展`SessionAudioRuntimeEvent`后自定义initializer未接收route/entitlement | 1 | 在initializer中加入并存储两个不可变参数，以全新DerivedData/xcresult重跑 |
| 18.4.4首轮focused包装器在zsh写入只读变量`status` | 1 | 后续包装器统一改用`build_status=${pipestatus[1]}`，本轮不计验收 |
| 17.4.5系统更新后四平台结果汇总在zsh中使用只读变量`status` | 1 | 四个build会话和产物均已完成；该包装器退出不计完整验收，改用显式Bash与`build_status`从四份既有xcresult完整重读 |
| 17.4.5首轮repository pre-gate把pbxproj双重文本出现数当成target数 | 1 | fixtures/OpenSpec/generator已通过但在结果读回前退出；membership改由generator清单、四平台实际Swift file list和focused已执行测试联合证明，从全新证据目录重跑 |
| 17.4.5封版组合补丁假设`findings.md`存在交接摘要中的尾句 | 1 | `apply_patch`整体拒绝且4.5尚未勾选；拆分OpenSpec/plan/roadmap与findings/progress补丁，按各文件当前真实上下文更新 |
| 17.5.3系统更新后iOS再认证脚本查找旧产物名`LuneX.app` | 1 | Debug build和xcresult实际已成功；从真实`LuneX-iOS.app`只读验证plist与零结构化诊断，仅从全新目录补跑尚未开始的Release，不重复Debug |
| 17.5.4前两轮expanded中spatial application integration尾部清理失败 | 2 | 两轮均为`292 passed / 1 failed`且不计验收；隔离重跑通过但提高测试grace后并行矩阵仍失败，排除单纯超时。根因是environment `stop()`在清active前await mobile owner造成actor重入，consumer cancellation与显式stop可同时认领同一generation；改为原子登记共享的mobile-stop+tracker teardown operation后再结束stream，测试grace恢复1秒 |
| 17.5.4确定性并发stop回归在系统更新后永久挂起 | 1 | `/tmp/LuneX-17-5_4-stop-race-regression-1/Regression.xcresult`经265秒手动中断；线程样本确认XCTest等待异步case。测试第二阻塞点位于tracker最多1秒grace之后，而旧helper只做200次`Task.yield()`，超时仅`XCTFail`后继续并提前空恢复；改为ContinuousClock两秒等待、Bool guard及失败时release-all收敛，原production修复不撤销 |
| 17.5.4首次tracking组合补丁假设不存在的error行措辞 | 1 | `apply_patch`整体拒绝且code/planning均未写入；先独立落盘test修复，再读取三份planning真实尾部并用精确上下文更新 |
| 17.5.4确定性并发stop回归r2停止后读取到queued mobile event | 1 | `/tmp/LuneX-17-5_4-stop-race-regression-2/Regression.xcresult`为`0 passed / 1 failed`、零结构化诊断且0.941秒正常退出，证明防自锁修复生效；夹具在apply后未消费`.mobileRuntime`事件，停止后首个iterator值自然非nil。启动stop前显式读取并验证该事件，从全新目录重跑 |
| 17.5.4恢复原focused selector时预期文本日志不存在 | 1 | 只读`rg`返回ENOENT且无工作区变化；改由保留的`Focused.xcresult`测试树精确枚举9项identifier，不猜测名称、不重复旧测试 |
| 17.5.4跨平台build结果汇总复用zsh只读变量`status` | 1 | macOS/tvOS/visionOS三个build均已独立成功且结果JSON已生成；只读汇总在打印前退出，不计组合验收。变量改为`build_status`后只读既有xcresult/产物，不重复构建 |
| 17.5.4首轮repository gate的嵌套shell引用把jq `.state`拼成`..state` | 1 | fixture与OpenSpec strict已通过，但在generator前退出且无代码/工程变化；不复用部分门，改用直接jq表达式并从全新证据目录完整重跑 |
| 17.5.4第二轮repository gate把reference快照的`Package.resolved`计为production依赖 | 1 | fixtures/OpenSpec/generator/privacy已通过，但`references/moonlight-ios`未跟踪上游快照合法自带SwiftPM锁文件；reference tree不进Git/工程且production无路径引用。依赖门排除整个`references/`后检查自有树，从全新目录重跑 |
| 17.5.4 action最终repository gate以`set -u`直接展开未定义Keychain变量 | 1 | `/tmp/LuneX-17-5_4-action-repository-final.tepjpV`在全部实质检查后因`LUNEX_RUN_KEYCHAIN_TEST: unbound variable`退出且不计验收；改用`env`精确检查变量是否存在，从全新证据目录重跑完整门 |
| 17.5.4勾选后final-state包装器包含未转义Markdown反引号 | 2 | 两次均在shell启动前报`SyntaxError: Unexpected number`，第二次遗漏了三条结果匹配中的反引号；未创建证据目录且仓库无额外变化。第三次彻底移除模板中的全部反引号再启动最终门 |
| 17.5.4记录第二次final-state错误时补丁含空hunk | 1 | `apply_patch`校验拒绝且未修改文件；移除无内容的hunk并重新应用精确两文件补丁 |
| 17.5.5首轮fixture tree门把root误传为仓库根 | 1 | validator按设计命中未跟踪build、docs与references；改用默认`Tests/Fixtures/Moonlight`根，源码与fixture未修改 |
| 17.5.5 corrected reference隔离正则匹配合法Moonlight-qt导入工具 | 1 | 三处均在用户要求保留的本地数据导入工具且不进production graph；只禁止实际`references/`路径进入Sources/工程/generator |
| 17.5.5 repository r2函数局部`path`覆盖zsh PATH | 1 | 已完成的实质门不计最终验收；改用显式Bash和`result_path`，从新目录完整重跑且不重复build/test |
| 17.5.5续接只读门禁编排局部变量覆盖工具命名空间 | 1 | JavaScript在任何shell命令执行前以`ReferenceError`退出且仓库未改；变量改名后继续，不重复该编排 |
| 17.5.5勾选后final-state文档断言再次包含Markdown反引号 | 1 | fixture、OpenSpec与generator已通过后静态断言无输出退出，未运行或重复test/build；改为不含反引号的固定语义匹配，从全新目录重跑完整门 |
| 17.5.5 final-state r2命令所有权断言使用不存在的字段名 | 1 | 实现实际使用`mobilePictureInPictureCoordinator`且generation检查完整；修正只读断言，先逐项预检剩余静态/plist门再完整重跑 |
| 17.5.6首次test/tracking组合补丁使用不存在的findings尾句 | 1 | `apply_patch`整体拒绝且仓库仍clean；拆分test与tracking补丁，按三个文件真实尾部追加，不重复错误上下文 |
| 17.5.6勾选后final-state文档断言包含Markdown反引号 | 1 | JavaScript在shell启动前报`SyntaxError: Unexpected number`；没有创建证据目录、执行门禁或修改仓库。改用不含反引号的固定语义匹配，从全新目录重跑且不重复build/test |
| 17.6.5项目scheme只读枚举输出空build-number DVTDeviceOperation warning | 1 | 命令成功但该环境warning不作为质量证据；改用工程product-type与测试源码静态扫描确认没有UI-test target，不重复枚举、不启动simulator |
| 17.6.5首轮final-state把中文UI边界文档误断言为英文固定短语 | 1 | fixture、strict、apply、generator、inventory/build读回与空UI target扫描均已通过；只修正文档语义匹配并从新目录重跑，不重复simulator查询、build或test |
| 17.6.7首轮final-state读取不存在的`skipped-identifiers.txt` | 1 | 其余门虽通过但该轮不计干净最终证据；从保留`tests.json`精确断言唯一Skipped节点为真实Keychain用例，并从新目录重跑全部只读门，不重复test/build/simulator |
| 18提案首轮OpenSpec strict未识别5个requirement的换行规范词 | 1 | 标题或后续行虽含`SHALL`但validator要求首段明确规范句；改为`LuneX SHALL ...`首句后strict `9/9`，未修改runtime行为 |
| 18.1.1读取两个不存在的合同文件名 | 1 | `mobile-continuity-runtime-contract.md`和`spatial-audio-runtime-contract.md`不是仓库文件；改读实际`mobile-scene-pip-continuity-contract.md`与`spatial-audio-contract.md`，未修改源码或重复任何平台操作 |
| 18.1.1辅助搜索包含不存在的根`README.md` | 1 | `rg`同时返回目标文档证据和单个缺文件诊断；后续只搜索实际存在的`docs/`、`Tools/`与规划文件，不影响验收事实 |
| 18.1.2第二次focused测试的Optional `.none`歧义被warnings-as-errors拒绝 | 1 | 显式写成`SpatialAudioPlatformStrategy.none`，从全新DerivedData/result bundle重跑并通过`13/13` |
| 18.1.2首轮repository gate按旧OpenSpec summary schema取值 | 1 | fixtures与strict已通过但不计最终门；改用`.summary.totals`并从新目录完整重跑 |
| 18.1.2第二轮repository gate把PBXBuildFile定义与phase引用按单份计数 | 1 | generator四次稳定且实际membership正确；修正精确文本计数为source 10/test 2并从新目录完整重跑 |

## 当前执行点（2026-07-30）

- 阶段13 / OpenSpec `implement-moonlight-session-runtime` 当前权威进度为`55/61`；1.1已按server-advertised protocol/capability inventory完成，不使用Sunshine package-version allowlist。6项live/hardware证据仍未通过，阶段保持`in_progress`；下一执行项为macOS-first M1 Task 2.3。
- production inventory已安装具体video/audio receiver并通过确定性取消/teardown验收；3.7/5.8/6.7/7.7/9.2/9.3所需授权host或硬件证据保持未完成，不用fixture、编译或离线测试替代。
- 阶段14 `integrate-macos-native-input-lifecycle` 当前权威进度`28/29`；阶段级离线自验通过，唯一剩余6.5为授权Sunshine/物理输入/多显示器，不得archive。
- 阶段15 `implement-native-hdr-edr-pipeline` 权威进度`32/33 in_progress`；1.1至6.4与6.6均完成并封版，已推送HEAD上的阶段级离线自验通过，唯一剩余6.5为授权Sunshine与物理HDR/SDR显示器验收，change不可archive。
- production graph现在以session/media/decoder generation和presentation revision连接negotiated/decoded metadata、真实lifecycle display snapshot/current headroom、user preference、resolver与actual Metal surface transition，并以presenter UUID lease隔离diagnostic replacement ownership；实际HDR状态也已进入可访问的stream overlay和Settings。该离线证据不证明compositor实际进入EDR、live Sunshine HDR、物理亮度/颜色或跨显示器视觉一致性；6.5物理显示器验收保持未完成。
- 阶段16 `integrate-spatial-audio-runtime`权威进度`34/35 in_progress`；1.1至6.5与6.7的production、normal/build、strict/API/analyzer、sanitizer/resource、simulator、合同和阶段级离线自验均完成并封版。唯一剩余6.6保持未完成；当前证据仍不证明AirPods head tracking、visionOS硬件可听行为、signed entitlement、真实route transition、物理声道输出或live Sunshine播放。
- 阶段17 `integrate-mobile-scene-pip-continuity`权威进度`35/36 in_progress`；1.x至5.6、6.1–6.5与6.7 normal/build/repository/API/analyzer/sanitizer/resource/fixed-simulator/跟踪封版及阶段级fresh normal自验已完成。唯一剩余6.6 signed physical acceptance；unsigned/macOS/simulator证据仍不证明provisioning接受、live Stage Manager、系统PiP、background duration、visible mobile EDR、physical设备或live Sunshine。
- 阶段18 `integrate-tvos-visionos-runtime`权威进度`2/50 ready`；1.2 immutable checked presentation foundation完成并通过focused、normal、五平台Debug和repository门，下一项1.3 tvOS focus/capture effect合同；actual platform runtime仍未接线。
- macOS 27.0更新后已重新认证5.3：Xcode 26.4/macOS SDK 26.4下macOS全量`881/880/1/0`且唯一skip为禁用的真实Keychain用例，iOS Debug/Release generic build与built plist读回均通过；没有启动或修改simulator。
- 阶段17任务5.4已于2026-08-06恢复并进入`in_progress`：先建立current session/media generation的scene/geometry/EDR/PiP/audio纯值application与serialized continuity action边界，再接入AppModel和iOS actual surface回调；stop/failure/replacement必须清空actual current state，UIKit/AVKit对象不得跨actor。5.5 UI与6.6物理证明保持在后续任务。
- macOS 27.0更新结束后再次恢复5.4；当前第一门为串行结构化读回`/tmp/LuneX-17-5_4-action-expanded-final-r2.U2uuha/Expanded.xcresult`。只有expanded、fresh full macOS、generic platform builds及repository gates全部通过后才允许勾选5.4并提交。
- 阶段17任务5.4已完成实现与阶段内自验并勾选：focused `18/18`、expanded `301/301`、fresh full `898/897/1/0`唯一显式Keychain skip、四generic Debug和repository gate均通过。权威进度应为`27/36`、next 5.5；最终状态门、提交与推送完成前仍不进入5.5实现。
## 2026-08-06 阶段 17 任务 5.5 启动

- **状态：** `complete`，OpenSpec已勾选为`4/50 ready`、next 1.5，等待勾选后final-state与独立提交推送。
- **基线：** 5.4 已以 `77cac48 Integrate mobile runtime application state` 提交并推送，`HEAD == origin/main`，工作树 clean。
- **范围：** accessible native PiP start/stop commands、actual scene/PiP/background/HDR status、continuity settings、compact/wide SwiftUI layouts、localization-safe copy 和 preference migration。
- **验收：** 先运行设置迁移、UI value/command/accessibility focused tests，再运行扩大 UI/AppModel/PiP/continuity 回归、完整 normal suite、四平台 generic build 与 repository/OpenSpec 门；普通测试继续显式移除 `LUNEX_RUN_KEYCHAIN_TEST`，不查询或操作 simulator。

## 2026-08-06 阶段 17 任务 5.5 完成

- **状态：** `complete`
- **实现：** typed actual-state projection、current-generation PiP command bridge、stream/Settings actual scene/PiP/continuity/mobile-EDR状态、compact/wide和accessibility/localization-safe UI、missing/partial continuity migration。
- **自验：** focused `9/9`、expanded `220/219/1/0`、fresh full `906/905/1/0`、四generic Debug零结构化诊断、repository pre-gate `/tmp/LuneX-17-5_5-repository-pre-r3.CQDfTT`全部通过。
- **证明边界：** 未操作simulator、未访问真实Keychain；system PiP、signed background、background duration、Stage Manager、external display、visible EDR、物理输入/空间音频、power/thermal与live Sunshine仍未证明。下一项5.6。

## 2026-08-06 阶段 17 任务 5.6 启动

- **状态：** `complete`（待独立提交与推送）
- **基线：** 5.5已以`6792840 Expose mobile continuity runtime state`提交并推送，`HEAD == origin/main`，工作树clean。
- **范围：** AppModel policy-loss/audio-only/active-PiP/foreground-restore/replacement/diagnostic ownership/clean-stop联合回归，RootView actual-state/accessibility/localization合同，以及continuity migration fail-closed回归。
- **验收：** 先运行三类新增focused tests，再扩大到owner/environment/AppModel/UI/persistence矩阵；之后fresh full macOS、四平台generic Debug与repository/OpenSpec门。测试继续显式移除`LUNEX_RUN_KEYCHAIN_TEST`且不操作simulator。
- **expanded 状态：** `/tmp/LuneX-17-5_6-expanded.rMzx7g/Expanded.xcresult` 已通过 `246/245/1/0`，唯一skip为显式真实Keychain测试，结构化build diagnostics为0；下一门为fresh full macOS normal suite。
- **full 状态：** `/tmp/LuneX-17-5_6-full.vIdYY6/Full.xcresult` 已通过 `909/908/1/0`，唯一skip仍为显式真实Keychain测试且结构化build diagnostics为0；下一门为四平台generic Debug build。

## 2026-08-06 阶段 17 任务 5.6 完成

- **状态：** `complete`
- **实现：** AppModel连续跨层sequence、replacement diagnostic re-ownership、actual-state clean-stop、RootView responsive/accessibility/localization静态合同，以及malformed continuity migration fail-closed回归；production runtime零修改。
- **自验：** focused `3/3`、expanded `246/245/1/0`、fresh full `909/908/1/0`、四generic Debug零结构化诊断及repository pre-gate `/tmp/LuneX-17-5_6-repository-pre.yLerRh`全部通过。
- **最终状态门：** `/tmp/LuneX-17-5_6-final-state-r2.RXA6yF`通过`29/36 next 6.1`、generator稳定、production diff clean、精确九文件scope、全部保留证据与diff检查。
- **证明边界：** 未查询或操作simulator、未访问真实Keychain；system PiP、signed background、background duration、Stage Manager、external display、visible EDR、物理输入/空间音频、power/thermal与live Sunshine仍属于6.x。下一项6.1。

## 2026-08-06 阶段 17 任务 6.1 启动

- **状态：** `complete`（待勾选后final-state与独立提交推送）
- **基线：** 5.6已以`d88533f Expand mobile continuity regression coverage`提交并推送，`HEAD == origin/main`且工作树clean；OpenSpec为`29/36 ready`、next 6.1。
- **范围：** 从提交态运行完整macOS normal suite，显式移除真实Keychain与任何live-host opt-in，精确验证唯一skip仍为真实Keychain round-trip，并串行读回test/build结果。
- **边界：** 继续使用文件/内存fallback；不查询或操作simulator，不把macOS normal suite冒充iOS system PiP或物理设备证明。

## 2026-08-06 阶段 17 任务 6.1 完成

- **状态：** `complete`
- **自验：** `/tmp/LuneX-17-6_1-normal.8bwnco/Normal.xcresult`为`909/908/1/0`，唯一skip精确为显式真实Keychain round-trip，结构化build diagnostics为0；pre-gate `/tmp/LuneX-17-6_1-repository-pre.QcX64y`全部通过。
- **最终状态门：** `/tmp/LuneX-17-6_1-final-state.p8fbkL`通过`30/36 next 6.2`、strict、generator、docs、normal、唯一skip、opt-in与diff检查。
- **证明边界：** 真实Keychain/live-host opt-in均未设置，未查询或操作simulator；下一项6.2。

## 2026-08-06 阶段 17 任务 6.2 启动

- **状态：** `complete`
- **基线：** 6.1已以`90fefbd Verify normal mobile continuity regression gate`提交并推送，`HEAD == origin/main`且工作树clean；OpenSpec为`30/36 ready`、next 6.2。
- **矩阵：** macOS、固定iPhone 17 Pro、固定iPad Pro 13-inch (M5)、tvOS、visionOS各运行Debug/Release，共10个isolated DerivedData/result bundle；Swift/Clang/Metal warnings-as-errors且禁用签名。
- **simulator约束：** 固定iPhone UUID `23A27088-C19F-4F77-A455-4E50E393167E`，固定iPad UUID `409A5908-8C39-4797-A41C-04503A05FA3D`；只作build destination，保存单次pre/post inventory并验证完全一致，不执行create/clone/boot/install/launch/shutdown/delete。
- **自验：** `/tmp/LuneX-17-6_2-builds.ORyQlN`内十份xcresult均为`succeeded/0 errors/0 warnings/0 analyzer warnings`且各有AIR/metallib；iPhone/iPad为`iphonesimulator`、`UIDeviceFamily [1,2]`和单一`audio`后台模式，其余平台无`UIBackgroundModes`。
- **simulator结果：** pre/post规范化清单逐字一致，SHA-256均为`0470edc00aea815358b4bed51fa43b73b79a5cbc61f80856f9630c6128568d41`；固定iPhone/iPad各唯一、available、`Shutdown`，全局`Booted=0`。
- **pre-gate：** `/tmp/LuneX-17-6_2-repository-pre.MR2Y1N`通过fixture、strict `8/8`、apply `30/36 next 6.2`、generator稳定、十build/Metal/plist/simulator、Keychain opt-in与diff检查；勾选后预期`31/36 next 6.3`。
- **最终状态门：** `/tmp/LuneX-17-6_2-final-state.lP9mOL`通过fixture、strict `8/8`、apply精确`31/36 next 6.3`、generator/docs、十build/Metal、simulator不变、Keychain opt-in与diff检查。
- **证明边界：** 构建禁用签名且未安装/运行，不能证明system PiP、background duration、Stage Manager、visible EDR、物理输入/空间音频、功耗/热状态或live Sunshine。

## 2026-08-06 阶段 17 任务 6.3 启动

- **状态：** `complete`
- **基线：** 6.2已以`db4255c Verify mobile continuity platform builds`提交并推送，`HEAD == origin/main`且工作树clean；OpenSpec为`31/36 ready`、next 6.3。
- **范围：** fixture/OpenSpec/generator与source/test membership、clean-room/reference/dependency/ENet license、source plist、privacy/forbidden API、iOS mobile scene/PiP/EDR public API probe、四SDK bridge strict compile，以及macOS Debug/Release static analyzer。
- **边界：** 不运行normal/sanitizer/resource或simulator，不访问真实Keychain；自有源码要求零analyzer finding，固定ENet finding如存在必须逐项在Debug/Release一致并明确归属。
- **repository/API自验：** `/tmp/LuneX-17-6_3-repository.NHQpyc`通过fixture self/tree、strict `8/8`、apply `31/36 next 6.3`、generator、全部membership、reference/package隔离、ENet pin/license/逐文件一致、plist/privacy、iOS 26.4 public API probe、四SDK AVKit/ENet strict compile、Keychain opt-in与diff检查。
- **analyzer自验：** `/tmp/LuneX-17-6_3-analyzer.ZbHqMU`的Debug/Release均`succeeded`、0 error、0 compiler warning、4 analyzer finding；两配置finding逐项一致且全部位于固定ENet，自有Sources/bridge为0。`unix.c`潜在nullable finding的唯一production调用同时传入peer/local address，但仍作为第三方残余风险保留。
- **预期状态：** OpenSpec 6.3勾选后为`32/36`、next 6.4；final-state通过后独立提交推送。
- **最终状态门：** `/tmp/LuneX-17-6_3-final-state.U9aRrJ`通过fixture、strict `8/8`、apply精确`32/36 next 6.4`、generator、repository/API保留证据、analyzer归属、docs、Keychain opt-in与diff检查。

## 2026-08-06 阶段 17 任务 6.4 启动

- **状态：** `complete`
- **基线：** 6.3已以`ef0168c Verify mobile continuity repository gates`提交并推送，`HEAD == origin/main`且工作树clean；OpenSpec为`32/36 ready`、next 6.4。
- **sanitizer：** 从提交态用全新DerivedData/result bundle串行运行完整ASan与完整TSan，显式Xcode sanitizer action开关、关闭coverage、测试串行、真实Keychain opt-in移除，并精确验证唯一skip及零sanitizer report。
- **resource：** 选择全部mobile scene/EDR/PiP/continuity owner，加SessionMediaEnvironment、AppModel、runtime diagnostics与StreamMetalPresenter共16个suite，在scribble/pre-scribble/guard edges/stack logging/逐分配heap check/error abort下运行。
- **边界：** 只用macOS test destination，不查询或操作simulator；sanitizer/resource通过不证明物理iOS系统PiP、后台持续、EDR、Stage Manager、功耗或live Sunshine长时资源行为。
- **ASan/TSan自验：** `/tmp/LuneX-17-6_4-asan.wtKUhx`与`/tmp/LuneX-17-6_4-tsan.7v8bx9`各通过`909 total / 908 passed / 1 explicit Keychain skip / 0 failed`、零结构化diagnostics和零sanitizer report。
- **resource自验：** `/tmp/LuneX-17-6_4-resource.6jwPh7`精确16-suite通过`320/320`、0 skip、零结构化diagnostics和零allocator report，覆盖PiP frame/backpressure release、scene/screen cancellation、generation replacement、restore completion与clean stop。
- **pre-gate：** `/tmp/LuneX-17-6_4-repository-pre-r3.M8A6Ib`通过fixture、strict `8/8`、apply `32/36 next 6.4`、generator、三份结果/报告、无残留进程、Keychain opt-in和diff检查；勾选后预期`33/36 next 6.5`。
- **最终状态门：** `/tmp/LuneX-17-6_4-final-state-r2.LbWI04`通过fixture、strict `8/8`、apply精确`33/36 next 6.5`、generator、三份证据、docs、LuneX进程、Keychain opt-in与diff检查；未干扰外部TamaCore xctest。

## 2026-08-06 阶段 17 任务 6.5 完成

- **状态：** `complete`
- **基线：** 6.4已以`81b656e Verify mobile continuity memory safety`提交并推送，`HEAD == origin/main`且起始工作树clean；OpenSpec为`33/36 ready`、next 6.5。
- **identity自验：** `/tmp/LuneX-17-6_5-simulator-audit.wNPE0P`内6.2 pre/post/current三份规范化清单逐字一致且SHA-256同为`0470edc00aea815358b4bed51fa43b73b79a5cbc61f80856f9630c6128568d41`；固定iOS 26.4 iPhone/iPad identity和UUID各唯一、available、`Shutdown`且全局`Booted=0`。
- **build/UI边界：** 只读复核6.2固定iPhone/iPad Debug/Release四份build均`succeeded/0/0/0`、destination/Metal/plist正确且未重复构建。工程没有UI-test product target或XCUIApplication harness，因此不制造launch-only UI门，也未安装或启动App。
- **simulator约束：** iOS 27.0系统同名默认identity按不同runtime披露且均`Shutdown`；本项只执行一次inventory读取，没有create、clone、boot、bootstatus、install、launch、run、shutdown或delete。
- **证明边界：** OpenSpec勾选后为`34/36`、next 6.6；simulator identity/build不证明signed provisioning、system PiP、background duration、Stage Manager、external display、visible EDR、物理输入/空间音频、power/thermal或live Sunshine。
- **最终状态门：** `/tmp/LuneX-17-6_5-final-state-r2.GDMtqY`通过fixture、strict `8/8`、apply精确`34/36 next 6.6`、generator、三份inventory、固定identity、四build/Metal/plist、UI target absent/no launch、无simulator mutation、Keychain opt-in、LuneX进程与diff检查。

## 2026-08-06 阶段 17 任务 6.7 封版

- **状态：** `complete`
- **基线：** 6.5已以`4ebfbc7 Verify mobile continuity simulator inventory`提交并推送，`HEAD == origin/main`且工作树clean；6.6因缺授权signed physical receipt保持pending。
- **同步：** 权威合同、runtime roadmap、OpenSpec、`task_plan.md`、`findings.md`、`progress.md`统一到`35/36 in_progress`，唯一pending为6.6。
- **证明边界：** 五级proof matrix明确当前仅完成contract/static、unsigned build与fixed simulator；signed artifact和physical/live仍未完成。没有6.6 receipt时不archive、不标记阶段complete，后续阶段证据不得回填。
- **下一门：** 运行strict/generator/docs/retained evidence final-state并独立提交推送，再在已推送HEAD执行阶段17 fresh normal离线自验；真实Keychain opt-in保持移除，simulator不操作。
- **最终状态门：** `/tmp/LuneX-17-6_7-final-state-r2.3enrxA`通过fixture、strict `8/8`、apply精确`35/36 only 6.6 pending`、generator、normal唯一Keychain skip、十build、analyzer、ASan/TSan/resource、fixed simulator、proof docs、Keychain opt-in、LuneX进程与diff检查。

## 2026-08-07 阶段 17 离线阶段级自验

- **状态：** `complete`（offline tier）；阶段17整体仍因6.6为`in_progress`。
- **基线：** 6.7已以`c7c9089 Document mobile continuity acceptance boundary`提交并推送，`HEAD == origin/main`且工作树clean。
- **fresh normal：** `/tmp/LuneX-17-stage-acceptance.xnt9je`为`909/908/1 exact Keychain skip/0`、0 expected failure、结构化诊断0且无failure marker；命令显式移除真实Keychain opt-in。
- **组合门：** `/tmp/LuneX-17-stage-acceptance-final.k8BdmF`通过remote parity、fixture、strict `8/8`、apply `35/36 only 6.6 pending`、generator、fresh normal、fixed simulator no-launch/no-mutation、Keychain opt-in、LuneX进程与diff检查。
- **边界/下一步：** 未访问真实Keychain、未操作simulator；6.6继续pending且change不可archive。自验记录提交推送后进入阶段18，后续证据不得回填6.6。

## 2026-08-07 阶段 18 OpenSpec 提案

- **状态：** `complete`；implementation `in_progress`。
- **change：** `integrate-tvos-visionos-runtime`，50项任务，next 1.1。
- **能力：** tvOS remote/focus/controller、tvOS scene/Metal/HDR/audio、visionOS window/input/system reservation、visionOS explicit windowed Metal/HDR/spatial audio。
- **边界：** 平台对象只在main actor，shared层只接immutable generation snapshot；复用单decoder/Metal/audio/session graph；system commands本地保留，unsupported能力typed fail closed，physical/live任务独立。
- **自验：** artifacts全部done，OpenSpec strict `9/9`，`git diff --check`通过；没有production/test/generator改动、Keychain访问或simulator操作。
- **下一步：** 提案独立提交推送后执行1.1只读inventory和Xcode 26.4 public API probe，再定义1.2 immutable platform contract。

## 2026-08-07 阶段 18 任务 1.1

- **状态：** `complete`，final-state通过，等待独立提交与推送。
- **合同：** 新增`docs/runtime/tvos-visionos-runtime-contract.md`，记录五级proof、target/membership/config、product ownership、tvOS remote/focus/controller与media、visionOS window/input与media、Xcode 26.4 API、固定simulator和physical/live边界。
- **关键结论：** tvOS/visionOS当前使用generic `MTKView`且没有actual scene/surface generation owner；tvOS controller monitor只有连接清单；visionOS没有window/input owner。tvOS旧EDR layer属性不可用，但SDK 26新增`preferredDynamicRange`/`contentsHeadroom`候选路径；visionOS没有`UIScreen`/current headroom。
- **固定identity：** tvOS 26.4 `6C0EC809-4C15-4AEC-9470-00F91480CAA7`、visionOS 26.4 `9BF41D0C-B423-4B3F-B75D-00B31E85FE18`均available/Shutdown，全局Booted为0；27.0同名设备已披露，后续只按固定UUID选择。
- **边界：** 没有production/test/generator/config改动，没有真实Keychain访问，没有simulator生命周期操作；SDK/header/build/simulator层均不证明物理HDR、空间音频、remote手感、live Sunshine或性能。
- **自验：** `/tmp/LuneX-18-1_1-final-state.H9NGtH`通过fixture、OpenSpec strict `9/9`、apply `1/50 next 1.2`、generator稳定4次、target/config/API/doc/privacy/clean-room、runtime behavior diff 0、Keychain/live opt-in和diff检查；没有重复simulator inventory或生命周期操作。
- **下一步：** 独立提交推送后进入1.2 immutable platform presentation contract。

## 2026-08-07 阶段 18 任务 1.2

- **状态：** `complete`，勾选后final-state通过，等待独立提交与推送。
- **实现：** 新增`TVVisionPlatformPresentationState.swift`和13项测试，定义平台、branded generation/domain、semantic revision、ownership、finite geometry/drawable、scene/surface attachment、typed focus、平台input capability、16-slot controller lease、display/headroom source、audio route/strategy与aggregate consistency合同；shared层不持有UIKit/GameController/AVFoundation/Metal对象。
- **语义审计：** tvOS pointer按Xcode 26.4 unavailable边界拒绝；visionOS当前headroom使用`.unavailable`，但合同不把当前无公开来源硬编码成永久平台禁止；`.none` audio strategy必须搭配unavailable head tracking。
- **自验：** focused最终`13/13`，fresh normal`922/921/1 exact Keychain skip/0`，macOS与固定iPhone/iPad/Apple TV/Vision Pro Debug全部`succeeded/0 error/0 warning/0 analyzer warning`；repository pre-gate `/tmp/LuneX-18-1_2-repository-pre-r3.QwpaS0`通过fixtures、strict`9/9`、generator四次稳定、membership、platform-object/privacy/reference和diff边界。
- **边界：** Keychain/live opt-in未设置；固定UUID只作build destination，没有重复inventory或任何simulator生命周期操作。本项不证明actual surface/input/media接线、signed/physical HDR/空间音频、live Sunshine或性能。
- **final-state：** `/tmp/LuneX-18-1_2-final-state.215ooC`通过strict`9/9`、apply`2/50 next 1.3`、focused/normal/五build retained evidence、generator四次稳定、精确变更范围、Keychain/live opt-in、无LuneX残留进程和diff检查。
- **下一步：** final-state通过并提交推送后进入1.3 tvOS local-focus versus stream-capture effect合同。

## 2026-08-07 阶段 18 任务 1.3

- **状态：** `complete`，OpenSpec已勾选为`3/50 ready`、next 1.4，等待勾选后final-state与独立提交推送。
- **实现：** 新增framework-object-free `TVRemoteFocusCaptureContract.swift`与16项测试，定义local SwiftUI focus/stream capture分权、reserved command、generation-branded balanced press、16-slot complete controller roster、lease-aware feedback及ordered release effect；不安装actual `UIPress`/`GCController` handler。
- **语义审计：** stream只接收select、play/pause和四方向；Menu及Home/volume/capture/power/unsupported始终本地。single snapshot验证自己的slot bit，roster验证exact shared bitmap；release plan独立拒绝stale/duplicate/reserved/cross-platform ownership。
- **自验：** focused final `/tmp/LuneX-18-1_3-focused-final.vfmkpn`为`16/16`；fresh normal `/tmp/LuneX-18-1_3-normal.X2XdFh`为`938/937/1 exact Keychain skip/0`；五平台Debug `/tmp/LuneX-18-1_3-builds.H78vE4`全部`succeeded/0 error/0 warning/0 analyzer warning`且有AIR/metallib。
- **工具边界：** 仓库没有`.swift-format`，默认lint的2-space规则与既有4-space风格冲突，不作为权威门也不据此重写；使用warnings-as-errors、结构化xcresult、`git diff --check`和人工审阅。
- **证明边界：** 未再次访问真实Keychain，未查询或操作simulator；actual surface/controller handler、remote delivery、signed/physical HDR/空间音频、live Sunshine与性能仍未证明。
- **repository pre-gate：** `/tmp/LuneX-18-1_3-repository-pre.cR5mnp`通过fixtures、OpenSpec strict `9/9`、apply `2/50 next 1.3`、generator SHA-256 `755323bf392b901cb0443bf5b2fc116a69b740b67f7e2930dd3c10c601c26779`连续4次一致、五target/test membership、framework-object/privacy/reference、Keychain/live opt-in、进程与diff检查。
- **final-state：** `/tmp/LuneX-18-1_3-final-state-r2.piTqXW`完整通过strict `9/9`、apply `3/50 next 1.4`、generator同一SHA-256、retained focused/normal/五build、唯一Keychain skip、五平台AIR/metallib、精确十文件scope、docs、reference、opt-in、进程与diff检查。
- **下一步：** 轻量post-record门通过后独立提交推送，再进入1.4 visionOS windowed/system-reserved/focus-release/immersive-unavailable合同。

## 2026-08-07 阶段 18 任务 1.4 启动

- **状态：** `in_progress`
- **基线：** 1.3已以`d55d08c Define tvOS remote focus capture effects`提交并推送，`HEAD == origin/main`且工作树clean；OpenSpec为`3/50 ready`、next 1.4。
- **范围：** 定义framework-object-free visionOS windowed presentation、四类explicit unavailable presentation feature、system-reserved interaction、五类capability-gated input admission，以及focus-loss/teardown ordered release与重复release幂等状态。
- **关键边界：** generation/revision/actual scene/focus/capability必须同时成立；gaze/hand/system gesture不得合成Moonlight event；focus loss先release held input再恢复本地导航；immersive/stereoscopic/volumetric/passthrough均不创建runtime。
- **验收：** 新增production contract与focused tests，加入四app target/test-support membership；随后fresh focused、normal、五平台Debug、repository/OpenSpec门。继续移除真实Keychain/live opt-in，不查询或操作simulator。
- **实现：** 新增`VisionWindowInputContract.swift`与15项测试，覆盖fixed windowed、四类exact typed unavailable、五类input path/generation/scene/focus/capability admission、system interaction local reserve/drop、focus/teardown ordered release、重复release和controller lease边界。
- **自验：** focused final `/tmp/LuneX-18-1_4-focused-final.nm9d5D`为`15/15`；fresh normal `/tmp/LuneX-18-1_4-normal.9HxEOi`为`953/952/1 exact Keychain skip/0`；五平台Debug `/tmp/LuneX-18-1_4-builds.9dNTC6`全部`succeeded/0 error/0 warning/0 analyzer warning`且有AIR/metallib。
- **证明边界：** 未再次访问真实Keychain，固定UUID只作build destination且未查询/操作simulator；actual window/input handler、多窗口/resize、immersive runtime、signed/physical Vision Pro、live Sunshine/HDR/空间音频/性能仍未证明。
- **repository pre-gate：** `/tmp/LuneX-18-1_4-repository-pre.y4G7Md`通过fixtures、strict `9/9`、apply `3/50 next 1.4`、generator SHA-256 `4b641128ba2139552abc2319671e0e4749b818167b5f9151ada3ac16c80774b0`连续4次一致、五target/test membership、framework-object/remote-effect/privacy/reference、retained evidence、opt-in、进程与diff检查。
- **final-state：** `/tmp/LuneX-18-1_4-final-state.Hjcn6D`一次通过strict `9/9`、apply `4/50 next 1.5`、generator同一SHA-256、retained focused/normal/五build、唯一Keychain skip、五平台AIR/metallib、精确十文件scope、docs/framework/reference/opt-in/进程与diff检查。
- **下一步：** 轻量post-record门和人工diff通过后独立提交推送，再进入1.5扩展边界测试。

## 2026-08-07 阶段 18 任务 1.5 启动

- **状态：** `complete`
- **基线：** 1.4已以`165e0f6 Define visionOS window input effects`提交并推送，`HEAD == origin/main`且工作树clean；OpenSpec为`4/50 ready`、next 1.5。
- **覆盖审计：** generation/revision exhaustion、部分invalid geometry、stale admission、reserved command、held release与16-slot capacity已有单点测试；缺口是nonfinite controller adapter仍deliver、全平台capability枚举矩阵、完整geometry failure class和aggregate non-Encodable隐私门。
- **实现范围：** `GameControllerInputAdapter`对NaN/Infinity固定typed drop；在既有Controller、TVVision foundation、tvOS capture和visionOS window test class补finite clamp/drop、全generation domain、geometry error grid、capability grid、max controller release、reserved no-remote与privacy serialization边界。
- **验收：** 先运行四类focused tests，再fresh normal、五平台Debug和repository/final-state；继续使用文件/内存Keychain fallback且不查询或操作simulator。
- **实现：** `GameControllerInputAdapter`在normalize前拒绝NaN/Infinity并返回固定无identity的drop reason；没有新增可持久化或框架对象边界。
- **测试：** 新增8项，覆盖所有generation zero/exhaustion、geometry failure class、两平台exact capability set、finite clamp、nonfinite drop、所有reserved no-remote、最大16-slot release和七个runtime aggregate non-Encodable边界。
- **focused：** `/tmp/LuneX-18-1_5-focused-final.TwI9GK`通过`58/58`且结构化diagnostics为0；首轮仅因production成功分支缺显式`return`在测试前失败，已记录并从全新证据重跑。
- **normal：** `/tmp/LuneX-18-1_5-normal.Ii5uKb`通过`961 total / 960 passed / 1 exact Keychain skip / 0 failed`，结构化diagnostics为0，Keychain/live-host opt-in均显式移除。
- **五平台Debug：** `/tmp/LuneX-18-1_5-builds.epxn6e`中macOS、固定iPhone/iPad/Apple TV/Vision Pro全部`succeeded/0 error/0 warning/0 analyzer warning`，各有1份AIR和1份metallib；仅使用UUID作为build destination，没有simulator inventory或生命周期操作。
- **repository pre-gate：** `/tmp/LuneX-18-1_5-repository-pre.35UmDy`完整通过fixtures、strict `9/9`、apply `4/50 next 1.5`、generator SHA-256 `4b641128ba2139552abc2319671e0e4749b818167b5f9151ada3ac16c80774b0`连续4次一致、五target/test membership、nonfinite固定drop reason、8项新增测试、七类aggregate non-Encodable隐私边界、retained focused/normal/五build、精确十文件scope、reference/opt-in/进程与diff检查。
- **OpenSpec：** pre-gate通过后勾选1.5，权威进度`5/50 ready`、next 1.6；actual handler/runtime、physical device与live Sunshine仍未证明。
- **final-state：** `/tmp/LuneX-18-1_5-final-state-r2.bBdtCr`完整通过fixtures、strict `9/9`、apply `5/50 next 1.6`、generator四次同一SHA-256、retained focused `58/58`、normal `961/960/1 exact Keychain/0`、五build `succeeded/0/0/0`、五平台AIR/metallib、精确十一文件scope、docs/privacy/reference/opt-in/进程与diff门。首轮仅因使用不存在的fixture根在任何generator或结果读取前退出。
- **下一步：** 人工审阅完整diff并运行轻量post-record门；通过后独立提交推送，再进入1.6 public API probes。

## 2026-08-07 阶段 18 任务 1.6 启动

- **状态：** `complete`
- **基线：** 1.5已以`eb0ecc1 Expand tvOS visionOS contract boundaries`提交推送，`HEAD == origin/main == eb0ecc18b35f653444d6204f20592cfbd77d76de`且工作树clean；OpenSpec为`5/50 ready`、next 1.6。
- **范围：** 使用仓库外临时Swift源对tvOS/visionOS 26.4 SDK分别执行warnings-as-errors正向typecheck和预期失败的unavailable/deprecated probes；覆盖actual window/effective geometry、press/focus、controller/keyboard/mouse边界、CALayer/CAMetalLayer动态范围、screen headroom、空间音频与route/recovery通知。
- **边界：** header存在不等于可调用；compile success不等于entitlement、simulator runtime、signed artifact、physical HDR/head tracking或live Sunshine。probe不加入production target，不查询或操作simulator，不访问真实Keychain。
- **验收：** 保存source、命令、SDK/build identity、stdout/stderr/exit与稳定摘要到`/tmp`；同步runtime contract、roadmap和三份planning文件，执行strict/generator/reference/privacy/repository门后再勾选1.6。
- **API证据：** `/tmp/LuneX-18-1_6-api.ZD2a58`使用Xcode 26.4/Swift 6.3、tvOS SDK `23L236`与visionOS SDK `23O238`；12类正向源在simulator/device SDK共`24/24`零诊断，6类unavailable/deprecated源在两种SDK共`12/12`按预期失败，机器摘要门通过。
- **关键结论：** 两平台effective geometry/press/focus/controller/新CALayer动态范围/audio recovery可编译；tvOS actual screen headroom与listener head tracking可编译但旧Metal EDR和intended spatial不可用；visionOS旧/新layer动态范围与intended spatial可编译但screen/headroom及listener property不可用。keyboard/mouse/pointer符号可编译不等于设备支持。
- **entitlement/运行边界：** tvOS源码与Debug/Release build setting声明head-pose entitlement；visionOS无entitlement文件/设置。probe未调用simctl、runtime、签名、设备、Keychain或live host，不证明HDR、head tracking、input delivery或物理行为。
- **repository pre-gate：** `/tmp/LuneX-18-1_6-repository-pre-r2.WVVlEP`完整通过fixtures、strict `9/9`、apply `5/50 next 1.6`、generator四次稳定同哈希、API `24/24 + 12/12`、诊断分类、toolchain/SDK、tvOS/visionOS entitlement差异、精确五文件scope、reference/production/opt-in/进程与diff门。首轮仅因把18个临时源误计为19而在后续检查前退出。
- **OpenSpec：** pre-gate通过后勾选1.6，权威进度`6/50 ready`、next 2.1；当前仍无actual runtime、simulator interaction、signed artifact、physical或live-host证明。
- **final-state：** `/tmp/LuneX-18-1_6-final-state.e4uqxq`一次完整通过fixtures、strict `9/9`、apply `6/50 next 2.1`、generator四次同一SHA-256、API `24/24 + 12/12`及诊断分类、entitlement差异、精确六文件scope、reference/production/opt-in/进程与diff门。
- **下一步：** 人工审阅完整diff并运行轻量post-record门；通过后独立提交推送，再进入2.1 actual surface bridge callbacks。

## 2026-08-07 阶段 18 任务 2.1 启动

- **状态：** `complete`（待独立提交与推送）
- **基线：** 1.6已以`cfee986 Document tvOS visionOS API boundaries`提交推送，`HEAD == origin/main == cfee986c14c622c36448b3b735e9f2aa4e20b55c`且工作树clean；OpenSpec为`6/50 ready`、next 2.1。
- **范围：** 为tvOS/visionOS的non-iOS UIKit `MTKView` bridge新增独立main-actor callback relay和actual view subclass，发布attachment/layout trigger及view-local `UIWindowScene?`、visibility、scale、drawable size和focus eligibility原始reading；支持handler replacement、弱持有和幂等失效。
- **边界：** 不复用或改变阶段17的iOS/iPadOS `MobileStreamMetalView` pipeline；本项不创建2.2 generation owner、不做2.3 finite normalization/semantic revision、不接AppModel、输入或媒体coordinator。
- **验收：** 新增relay replacement/late-callback/weak-retention/idempotent teardown focused tests，生成工程后运行fresh focused、normal、五平台Debug及repository/OpenSpec门；继续显式移除Keychain/live-host opt-in，不查询或操作simulator。
- **实现：** 新增七类callback、generic raw state与弱持有main-actor relay；tvOS/visionOS actual `TVVisionStreamMetalView`从自身window/view读取状态，SwiftUI update替换handler，dismantle先失效callback再停止presenter。iOS/iPadOS `MobileStreamMetalView`分支没有改变。
- **focused：** `/tmp/LuneX-18-2_1-focused-final.Dn6Ogw`为`2/2 passed / 0 skipped / 0 failed`，覆盖callback顺序、每批单次读取、handler replacement、actual scene identity、weak ownership、empty/late callback、exact enum matrix与重复invalidate。
- **normal：** `/tmp/LuneX-18-2_1-normal.qH028K`为`963 total / 962 passed / 1 skipped / 0 failed`；唯一skip精确为显式真实Keychain round trip，Keychain/live-host opt-in均unset。
- **五平台build：** `/tmp/LuneX-18-2_1-builds.mherO0`中macOS与固定iPhone/iPad/Apple TV/Vision Pro Debug全部`succeeded/0 error/0 warning/0 analyzer warning`，每份各有AIR和metallib；UUID仅作build destination，没有查询或操作simulator。
- **下一步：** 运行repository pre-gate；通过后才勾选2.1并确认`7/50 ready`、next 2.2，随后运行只读final-state、独立commit/push。
- **repository pre-gate：** `/tmp/LuneX-18-2_1-repository-pre.raFP1x`从头通过fixture self/tree、OpenSpec strict `9/9`与勾选前`6/50 next 2.1`、generator四次稳定SHA-256 `4b641128ba2139552abc2319671e0e4749b818167b5f9151ada3ac16c80774b0`、精确七文件scope、callback/weak ownership/iOS isolation/privacy/reference、retained test/build、opt-in/进程及diff门。
- **OpenSpec：** pre-gate通过后已勾选2.1，权威进度预期为`7/50 ready`、next 2.2；下一步运行勾选后final-state，不重复test/build或simulator inventory。
- **final-state：** `/tmp/LuneX-18-2_1-final-state.dAGCFP`从头通过fixture、strict `9/9`、apply精确`7/50 next 2.2`、generator四次稳定同哈希、retained focused/normal/五build、精确八文件scope、docs/privacy/reference/opt-in/进程与diff门；2.1可独立提交推送。

## 2026-08-07 阶段 18 任务 2.2 启动

- **状态：** `in_progress`
- **基线：** 2.1已提交推送为`4069cc2 Add tvOS visionOS surface callbacks`，`HEAD == origin/main == 4069cc2fc769f5c30afebb574390e335b5f34c56`且工作树clean；OpenSpec为`7/50 ready`、next 2.2。
- **范围：** 新增main-actor、弱引用的tvOS/visionOS surface generation owner，从callback所属actual surface解析window/scene、scene activity及平台可用screen，产出不含framework对象的checked state；验证generation domain/identity、attachment/scene一致性、tvOS screen、finite scale/drawable及focus visibility。
- **失败边界：** stale generation/surface与late callback不触发handler；detach与current invalid callback清空window/scene/screen并发布fail-closed状态；visionOS按公开API边界允许screen absent，不扫描`connectedScenes`或读取global screen。
- **后置边界：** 2.2不实现2.3 bounds/safe-area geometry normalization、semantic dedup/revision、drawable/render/input mapping，也不提前接2.4 coordinator或2.5 AppModel。
- **验收：** actual identity/activity/tvOS screen、visionOS no-screen、detach/invalid recovery、stale/late/invalidation/weak ownership focused tests；随后fresh normal、五平台Debug与repository/OpenSpec门。继续禁用真实Keychain/live-host，不查询或操作simulator。
- **实现：** generic main-actor owner弱持有surface/window/scene/optional screen并发布framework-object-free checked state；actual view生成branded surface generation，只观察当前window scene lifecycle，replacement/dismantle移除token。tvOS要求actual scene screen，visionOS明确screen absent。
- **focused：** 首轮条件编译argument syntax与第二轮test-only infinity歧义均在0 tests时修正；最终`/tmp/LuneX-18-2_2-focused-final2.VLhqfP`通过`8/8`，覆盖全部identity/activity/platform/invalid/stale/weak/invalidation边界。
- **normal：** `/tmp/LuneX-18-2_2-normal-final.jGEblk`通过`969 total / 968 passed / 1 skipped / 0 failed`，唯一skip精确为显式真实Keychain round trip，Keychain/live-host opt-in均unset。
- **五平台build：** `/tmp/LuneX-18-2_2-builds-final.5K2Eqp`中macOS与固定iPhone/iPad/Apple TV/Vision Pro Debug全部`succeeded/0 error/0 warning/0 analyzer warning`；UUID仅作build destination，没有查询或操作simulator。
- **系统更新后复验：** macOS 27.0/Xcode 26.4下`/tmp/LuneX-18-2_2-focused-macos27.5VXuwb`保持`8/8`，`/tmp/LuneX-18-2_2-normal-macos27.APoh6b`保持`969/968/1/0`且唯一skip为真实Keychain opt-in，`/tmp/LuneX-18-2_2-builds-macos27.IgW5lP`五平台Debug全部`succeeded/0/0/0`并各有AIR/metallib；未查询或操作simulator。
- **repository pre-gate：** `/tmp/LuneX-18-2_2-repository-pre-macos27.NmlEN1`从头通过fixtures、OpenSpec strict `9/9`与勾选前`7/50 next 2.2`、generator四次稳定同哈希、精确七文件scope、owner/membership/privacy/clean-room、retained focused/normal/五build、opt-in/进程及diff门。
- **OpenSpec：** pre-gate通过后已勾选2.2，权威进度预期为`8/50 ready`、next 2.3；下一步运行只读final-state，不重复test/build或simulator inventory。
- **final-state：** `/tmp/LuneX-18-2_2-final-state-macos27-r2.zjXtZr`通过fixtures、strict `9/9`、apply精确`8/50 next 2.3`、generator四次同哈希、八文件scope、docs/owner/privacy/reference/opt-in/进程及全部保留证据读回；2.2可独立提交推送。

## 2026-08-07 阶段 18 任务 2.3 启动

- **状态：** `complete`，勾选后final-state通过，等待独立提交与推送。
- **基线：** 2.2已提交推送为`488d99f Add tvOS visionOS surface generation owner`，`HEAD == origin/main == 488d99f4e08435b0f71018830d3d806a925f7431`且工作树clean；OpenSpec为`8/50 ready`、next 2.3。
- **范围：** 新增generation-scoped actual-view geometry binding owner，从view/window bounds、safe area和scale计算checked `TVVisionSurfaceGeometry`，以同一`TVVisionSemanticRevision`发布scene snapshot、fit/fill `StreamCoordinateSnapshot`与absolute/indirect input reference mapping，并驱动actual drawable。
- **去重：** callback类别不进入语义输入；只有activity/visibility/focus、finite normalized geometry、source size或fit/fill mode变化才推进revision，等价layout/trait/scene callback保持unchanged。
- **失败边界：** stale generation/surface静默；detached、invalid geometry、drawable apply failure、coordinate unavailable、revision exhaustion与invalidation均fail closed并清除render/input mapping。不得扫描global scene/screen或使用requested stream resolution作为window geometry。
- **后置边界：** 2.3只实现surface-local geometry/render/input-reference binding，不提前实现2.4全presentation coordinator、2.5 media/AppModel application或平台actual input adapters。
- **验收：** focused覆盖actual normalization、同revision drawable/render/input、semantic dedup、fit/fill、resize、invalid/detach/recovery、stale/late/invalidation和revision exhaustion；随后fresh normal、五平台Debug及repository gate。真实Keychain/live-host继续禁用，不查询或操作simulator。
- **实现进度：** 已完成surface-local geometry owner、actual view/SwiftUI bridge与presenter exact-coordinate接线，并新增6项focused测试；审计时修正coordinate unavailable只关input却可能保留drawable的缺口，使该路径同时清零presentation。下一步生成工程并从fresh evidence目录编译运行2.1–2.3 focused集合。
- **验收错误 1：** `/tmp/LuneX-18-2_3-focused-first.Lf0vbb`在启动build前由进程预检退出；`ps`命令行匹配到了包含`xcodebuild`文本的当前wrapper自身。未产生xcresult、未编译或执行测试；后续改用精确可执行名`pgrep -x xcodebuild`并从新目录运行。
- **验收错误 2：** `/tmp/LuneX-18-2_3-focused-second.R6XNb6`完成production/test编译后为`13 passed / 1 failed`；唯一失败是test helper把故意注入的NaN view width转换为`Int`而trap，尚未进入被测invalid-geometry路径。helper改为使用generation层有限drawable reading；同时一次并发读取同一xcresult触发SQLite bundle冲突，后续所有xcresult读取保持串行。
- **focused：** 修正helper后fresh `/tmp/LuneX-18-2_3-focused-final.3ydyxX`结构化通过`14/14 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded/0 error/0 warning/0 analyzer warning`；下一步分别编译actual tvOS与visionOS条件分支。
- **actual分支编译：** `/tmp/LuneX-18-2_3-tvos.z5gn3n`与`/tmp/LuneX-18-2_3-vision.vvrgyu`均为`succeeded/0 error/0 warning/0 analyzer warning`，各有一份AIR/metallib；固定UUID仅作build destination，没有读取或操作simulator。下一步fresh normal。
- **normal：** `/tmp/LuneX-18-2_3-normal.LQmuaL`结构化通过`975 total / 974 passed / 1 skipped / 0 failed`，唯一skip精确为显式真实Keychain round trip，build诊断为0。
- **五平台build：** `/tmp/LuneX-18-2_3-builds.a3spj2`中macOS及固定iPhone/iPad/Apple TV/Vision Pro Debug全部`succeeded/0 error/0 warning/0 analyzer warning`且各有一份AIR/metallib；未查询或操作simulator。
- **文档与人工审计：** 已同步阶段18 runtime contract、roadmap和三份planning文件；完整diff确认actual view/window geometry正向驱动、single revision、fail-closed、stale/invalidation、无global scene/screen/requested-resolution fallback且未越过2.4/2.5。下一步repository pre-gate。
- **repository pre-gate：** `/tmp/LuneX-18-2_3-repository-pre.z6jCCO`从头通过fixtures、OpenSpec strict `9/9`与勾选前`8/50 next 2.3`、generator四次稳定同哈希、精确九文件scope、geometry/revision/fail-closed/clean-room、retained focused/normal/五build、opt-in/进程与diff门。
- **OpenSpec：** pre-gate通过后已勾选2.3，权威进度预期为`9/50 ready`、next 2.4；下一步只读final-state，不重复test/build或simulator inventory。
- **final-state：** `/tmp/LuneX-18-2_3-final-state.LZtrAB`完整通过fixtures、OpenSpec strict `9/9`与apply精确`9/50 next 2.4`、generator SHA-256 `4b641128ba2139552abc2319671e0e4749b818167b5f9151ada3ac16c80774b0`、精确十文件scope、retained focused `14/14`、normal `975/974/1/0`、五平台build与Metal产物、privacy/opt-in/进程及diff检查；2.3可独立提交推送。
- **post-record：** `/tmp/LuneX-18-2_3-post-record.zzaiMr`通过OpenSpec `9/50 next 2.4`、精确十文件scope、project generator哈希、四处final-state记录、retained focused/normal/五build、空LuneX测试进程及`git diff --check`；未重跑test/build或查询simulator。
- **最终diff修复：** 人工复核发现tvOS/visionOS actual view仍保留`MTKView.autoResizeDrawable`默认写入，破坏geometry owner唯一drawable writer边界；已在`TVVisionStreamMetalView`初始化显式关闭auto resize。修复后focused `/tmp/LuneX-18-2_3-owner-fix-focused.kY6Oxo`通过`14/14`，direct tvOS `/tmp/LuneX-18-2_3-owner-fix-tvos.FCNNmM`与visionOS `/tmp/LuneX-18-2_3-owner-fix-vision.1Feeyo`均零诊断成功并各有AIR/metallib；未查询或操作simulator。
- **修订final gate：** `/tmp/LuneX-18-2_3-final-amend-r2.0HXOJm`完整通过OpenSpec `9/50 next 2.4`、精确十文件scope、generator哈希、single explicit drawable writer、新focused/tvOS/visionOS证据、retained normal/五平台build、opt-in/进程和diff检查。首轮只读包装器因覆盖zsh特殊`path`变量退出，未重复test/build。

## 2026-08-07 阶段 18 任务 2.4 完成

- **状态：** `complete`，已勾选OpenSpec且修订final repository gate通过，等待独立提交推送。
- **基线：** 2.3已提交推送为`f4b34ed Add tvOS visionOS geometry binding`，fetch后`HEAD == origin/main == f4b34ed2435f361f5fffaf1773e965a4024213a1`且工作树clean；OpenSpec为`9/50 ready`、next 2.4。
- **范围：** 实现shared、serialized、generation-scoped platform presentation coordinator，统一归约scene/geometry、input eligibility、decoded frame、display/HDR、audio route、bounded diagnostics、replacement和shared teardown，并拒绝stale generation/revision。
- **后置边界：** 2.4只建立可测试的协调owner与effect合同；`NativeSessionMediaEnvironment`和`AppModel` application属于2.5，actual platform input adapters及完整tvOS/visionOS media wiring属于后续3.x–6.x。
- **验收计划：** 先盘点并复用现有frame source/presenter、HDR/audio snapshot、diagnostic与resource teardown owner；新增ordering/replacement/late callback/failure/idempotent teardown focused tests，再运行fresh normal、actual tvOS/visionOS与五平台Debug、repository/final-state。真实Keychain/live-host继续禁用，不查询或操作simulator生命周期。
- **首轮实现与审计：** 已新增serialized actor coordinator、typed action/snapshot/failure、component rebranding、single latest video delivery、bounded diagnostics与single shared teardown；人工审计修复scene-close sequence、terminal snapshot failure真实性、component错误归因及XCTest async autoclosure。首轮fresh focused `/tmp/LuneX-18-2_4-focused.aQS6ye`通过`8/8`。
- **补强中：** 增加suspended action下FIFO、incomplete input fail-closed、foreign session、sequence exhaustion和decoder-generation watermark回归；完成fresh focused前不进入normal/平台验收，也不勾选2.4。
- **focused：** 最终fresh `/tmp/LuneX-18-2_4-focused-r3.FG8Ckv`结构化通过`12/12`且零诊断；第二轮唯一失败是测试误判同transition的`.input(nil)`，已记录并从新bundle修正验证。
- **actual分支编译：** tvOS `/tmp/LuneX-18-2_4-tvos.AJeL2v`与visionOS `/tmp/LuneX-18-2_4-vision.B2ikcX`均`succeeded/0 error/0 warning/0 analyzer warning`且各有AIR/metallib；固定UUID仅作build destination，下一步fresh normal。
- **normal：** `/tmp/LuneX-18-2_4-normal.p2HGpE`结构化通过`987 total / 986 passed / 1 exact Keychain skip / 0 failed`且build零诊断；下一步补其余三平台app builds。
- **五平台Debug：** macOS、固定iPhone/iPad位于`/tmp/LuneX-18-2_4-builds.qtsQKa`，固定Apple TV/Vision Pro分别位于`/tmp/LuneX-18-2_4-tvos.AJeL2v`与`/tmp/LuneX-18-2_4-vision.B2ikcX`；全部`succeeded/0 error/0 warning/0 analyzer warning`且有AIR/metallib，固定UUID仅作build destination。
- **repository pre-gate：** `/tmp/LuneX-18-2_4-repository-pre.YGBLze`通过fixture self/tree、OpenSpec strict `9/9`与勾选前`9/50 next 2.4`、generator四次稳定SHA-256 `ef2e3e615f1dbd84b76bfe4c8681fab7d44291176f06324acd757fa1c1008353`、精确九文件scope、membership/ownership/privacy/clean-room、全部retained证据、opt-in/进程/reference与diff门。
- **OpenSpec：** pre-gate通过后已勾选2.4，权威进度预期为`10/50 ready`、next 2.5；下一步只读final-state，不重复test/build或simulator inventory。
- **display fail-closed修订：** 提交前复核修正display unavailable仍可render/input的缺口；fresh focused `/tmp/LuneX-18-2_4-display-fix-focused-r2.cp7W6C`通过`13/13`且零诊断，旧normal/五build/final-state不再作为最终证据，下一步fresh重跑。
- **修订normal：** `/tmp/LuneX-18-2_4-display-fix-normal.HPUEMu`结构化通过`988 total / 987 passed / 1 exact Keychain skip / 0 failed`且build零诊断。
- **修订五平台Debug：** `/tmp/LuneX-18-2_4-display-fix-builds.Zcj3Gg`中macOS及固定iPhone/iPad/Apple TV/Vision Pro全部`succeeded/0 error/0 warning/0 analyzer warning`且各有AIR/metallib；未查询或操作simulator。下一步修订final repository gate。
- **修订final repository gate：** `/tmp/LuneX-18-2_4-display-fix-final-r3-cXPKxC`完整通过fixture self/tree、OpenSpec strict `9/9`与apply精确`10/50 next 2.5`、generator四次稳定SHA-256 `ef2e3e615f1dbd84b76bfe4c8681fab7d44291176f06324acd757fa1c1008353`、精确十文件scope、source/test membership、FIFO/single-current-delivery/display fail-closed/ordered teardown、privacy/clean-room、修订focused/normal/五build/Metal、opt-in、进程与diff门。前两轮仅修正membership文本计数和过宽隐私正则，没有重复test/build或操作simulator。
- **post-record：** `/tmp/LuneX-18-2_4-post-record-r2-vJDin3`通过OpenSpec `10/50 next 2.5`、十文件scope、project哈希、分层final-gate记录与`git diff --check`；首轮仅因错误要求高层roadmap重复临时路径退出，未重复test/build/generator。
- **证明边界：** 2.4只证明确定性coordinator ownership和unsigned SDK branch compatibility；不证明2.5 AppModel application、actual platform adapters、signed artifact、物理HDR/input/spatial、live Sunshine、延迟、功耗、热状态或舒适度。

## 2026-08-07 阶段 18 任务 2.5 完成

- **状态：** `complete`，OpenSpec已勾选2.5，预期`11/50 ready`、next 2.6；等待只读final-state和独立提交推送。
- **基线：** 2.4已以`a2e04df Add tvOS visionOS presentation coordinator`提交推送，fetch后`HEAD == origin/main == a2e04df187d36bae4eea695a29fb8c8270eb75df`且工作树clean。
- **范围：** 让`NativeSessionMediaEnvironment`每个media generation持有一个platform presentation coordinator，generation-check application并订阅现有单一`StreamVideoPresentationSource`；通过typed environment state把current snapshot和bounded terminal failure送入`AppModel`。
- **application边界：** tvOS/visionOS actual geometry callback可建立/替换presentation ownership并提交scene update；input/display/audio actual adapters继续留给3.x–6.x，不在2.5伪造完整平台状态。
- **清理边界：** coordinator failure、media provider failure、reconnect、remote termination和local stop均先使current actual presentation为空，再隔离late old callbacks；terminal typed state可用于bounded UI/diagnostic，不能保留framework/host/window/route/payload identity。
- **验收计划：** 新增窄environment/AppModel current/stale/failure/replacement/stop测试，再运行fresh focused、normal、五平台Debug和repository/final-state；真实Keychain/live-host保持禁用，不查询或操作simulator生命周期。
- **focused：** `/tmp/LuneX-18-2_5-focused-third.ILQdlM`结构化通过`8/8`且build为`succeeded/0 error/0 warning/0 analyzer warning`。
- **normal：** `/tmp/LuneX-18-2_5-normal-r2.6qYfC2`结构化通过`996 total / 995 passed / 1 exact Keychain skip / 0 failed`且build零诊断；首轮仅因误用不存在的`LuneX` scheme在测试前退出，修正为`LuneXCoreTests`后从fresh目录运行。
- **五平台Debug：** `/tmp/LuneX-18-2_5-builds.zPlpja`中macOS、固定iPhone/iPad/Apple TV/Vision Pro全部`succeeded/0/0/0`并各有AIR/metallib；固定UUID仅作build destination，未读取或操作simulator inventory/lifecycle。
- **repository pre-gate：** 首轮误把fixture根设为仓库`.`，工具按设计报告既有build/reference/docs内容并退出；修正为默认`Tests/Fixtures/Moonlight`后，`/tmp/LuneX-18-2_5-repository-pre-r2.27GQDW`通过fixture self/tree、OpenSpec strict`9/9`、勾选前`10/50 next 2.5`、generator四次稳定哈希、精确scope、ownership/privacy/reference/opt-in/process和diff门。
- **语义审计：** coordinator terminal后的teardown二次stop只返回unchanged，不增加teardown count或覆盖首个reason；AppModel task operation ID与current session/media/ownership检查阻止排队geometry application污染replacement；非tvOS/visionOS production默认platform为`nil`。
- **证明边界：** 2.5未实现3.x–6.x actual input/display/HDR/audio adapter；unsigned build和deterministic tests不证明signed artifact、物理设备、live Sunshine、性能或功耗。
- **final-state：** 首轮只因`jq`管道优先级在OpenSpec JSON处退出且未读xcresult；修正后的`/tmp/LuneX-18-2_5-final-state-r2.6tknnX`只读通过fixtures、strict`9/9`、apply`11/50 next 2.6`、13/13 scope、稳定project hash、focused`8/8`、normal`996/995/1/0`、五平台/Metal、reference/opt-in/process和diff门，未重复test/build/generator或simulator操作。

## 2026-08-07 阶段 18 任务 2.6 完成

- **状态：** `complete`，OpenSpec已勾选2.6，预期`12/50 ready`、next 3.1；等待只读final-state和独立提交推送。
- **基线：** 2.5已提交推送为`2157eb7 Connect tvOS visionOS presentation runtime`，fetch后`HEAD == origin/main == 2157eb7faaae177dc58694d07af4e4c944ecbc0d`且工作树clean。
- **既有覆盖：** 2.2/2.3 surface tests已覆盖attachment、actual lifecycle、geometry normalize/dedup/resize/detach/stale/revision exhaustion；2.4 coordinator tests已覆盖focus eligibility、FIFO effects、replacement/late callback、failure和idempotent stop。
- **新增缺口：** 补AppModel排队geometry application的coalescing、surface replacement和late old callback跨层测试；补激活platform owner后的concurrent stop/provider failure共享teardown测试。
- **风险：** 2.5在`NativeSessionMediaEnvironment.stop/fail`清空active前新增coordinator `await`，actor可重入；两个terminal caller可能同时越过active guard。先以确定性挂起点复现，再用单一current termination operation最小修复。
- **边界：** 本项只强化shared presentation ownership/application测试和被测试暴露的串行化缺口，不提前实现3.x–6.x actual input/display/HDR/audio adapters。
- **实现中：** 已加入generation-scoped terminal reservation、测试coordinator factory和geometry admission水位；已补active platform双stop、provider-failure/stop与挂起activation下coalescing/replacement/late callback用例。尚未编译或验收，不得勾选2.6。
- **验收错误 1：** 首轮focused预检发现外部TamaSwift `xcodebuild` PID 32408后以90退出，未生成工程或执行LuneX编译/测试；不终止外部任务，空闲后必须使用fresh evidence目录。
- **验收错误 2：** `/tmp/LuneX-18-2_6-focused-second.MJ0oOv`在0 tests时因两处terminal closure被推断为`Task<Void?, Never>`编译失败；已显式定型`Task<Void, Never>`并内部解包weak self，下一轮使用fresh bundle。
- **验收错误 3：** `/tmp/LuneX-18-2_6-focused-third.1wPd3H`在production编译通过后，新增测试因8处XCTest同步autoclosure包含async访问而在0 tests失败；已先捕获async结果再断言，下一轮使用fresh bundle。
- **验收错误 4：** `/tmp/LuneX-18-2_6-focused-fourth.EdK5uu`为`3/2/1`；唯一失败是双stop测试把正确的terminal-before-end事件误判为应立即EOF。已改为先断言`.stopped(.localStop)`再断言EOF，下一轮fresh复验。
- **验收错误 5：** `/tmp/LuneX-18-2_6-focused-final.L6uHOF`仍为`3/2/1`；原因是修正补丁命中错误的同名EOF片段，目标断言未变。已恢复被误改的旧测试并用唯一资源计数上下文精确修改目标，必须fresh复验。
- **新增focused：** `/tmp/LuneX-18-2_6-focused-final-r2.jlY8sf`结构化通过`3/3`且warnings-as-errors零诊断；下一步运行既有surface/coordinator相关矩阵并完成人工竞态审计，尚不进入normal或勾选2.6。
- **审计修订：** replacement geometry已排队但activation未完成时，late old platform state也必须按geometry admission拒绝；已补source guard与排队前后双late-event断言，需fresh focused后才能进入扩大矩阵。
- **focused/相关矩阵：** 修订fresh `/tmp/LuneX-18-2_6-focused-final-r3.VB6cr5`通过`3/3`；扩大`/tmp/LuneX-18-2_6-related-final.OQl0xr`通过`88/88`且零诊断。人工竞态审计完成，下一步fresh normal和五平台Debug。
- **normal：** `/tmp/LuneX-18-2_6-normal.rKKWHh`通过`999/998/1 exact Keychain skip/0`且零诊断。
- **五平台Debug：** `/tmp/LuneX-18-2_6-builds.k6M12b`中macOS及固定iPhone/iPad/Apple TV/Vision Pro全部`succeeded/0/0/0`并各有AIR/metallib；未查询或操作simulator。下一步同步合同/roadmap并运行repository pre-gate。
- **repository pre-gate错误：** 首轮`/tmp/LuneX-18-2_6-repository-pre.2PfeAN`的fixture通过，但OpenSpec断言在已切换到`.items`数组后再次访问`.items[]`，对实际`9/9 valid`的保存JSON错误退出；这不是源码或OpenSpec失败。修正断言为在根对象上分别检查`(.items | length) == 9`与`all(.items[]; .valid)`，从fresh目录继续未完成门禁，不重复已通过的test/build或simulator操作。
- **repository pre-gate：** 修正后的`/tmp/LuneX-18-2_6-repository-pre-r2.MNeROJ`完整通过fixtures、OpenSpec strict `9/9`与勾选前`11/50 next 2.6`、generator四次稳定SHA-256 `ef2e3e615f1dbd84b76bfe4c8681fab7d44291176f06324acd757fa1c1008353`、精确九文件scope、source/test semantics、retained focused/related/normal/五平台build、opt-in/reference/process和diff门。
- **final-state：** 勾选后的`/tmp/LuneX-18-2_6-final-state.Opv4SF`只读通过OpenSpec strict `9/9`、apply精确`12/50 next 3.1`、稳定project hash、精确十文件scope、source/test semantics、retained `3/3`、`88/88`、`999/998/1/0`、五平台build/Metal、opt-in/reference/process和diff门；未重复test/build/generator或simulator操作。

## 2026-08-07 阶段 18 任务 3.1 启动

- **状态：** `complete`，OpenSpec已勾选3.1，当前为`13/50 ready`、next 3.2；等待只读final-state和独立提交推送。
- **基线：** 2.6已提交推送为`46f027b Harden tvOS visionOS presentation races`，fetch后`HEAD == origin/main == 46f027b526c505ca40bfd9c7d254db9e32d7f8cf`且工作树clean。
- **范围：** 在actual tvOS `TVVisionStreamMetalView`接收`pressesBegan`、`pressesEnded`与`pressesCancelled`，由main-actor current-generation owner把actual press identity映射为`TVRemotePressToken`，通过既有`TVRemoteCaptureState`生成balanced `TVRemoteInputEvent`并交给AppModel现有input application路径。
- **边界：** 3.1只实现eligible stream surface的actual press capture/admission与balanced delivery；overlay/local focus协调、系统reserved command完整策略、controller runtime、held release barrier分别属于3.2–3.6，不提前完成。
- **验收计划：** focused覆盖actual mapper、begin/end/cancel、duplicate/stale/replacement、unsupported/local-reserved、send failure及dismantle invalidation；随后fresh normal、五平台Debug与repository/final-state。真实Keychain/live-host保持禁用，不查询或操作simulator lifecycle。
- **验收错误 1：** `/tmp/LuneX-18-3_1-focused.KLHNd8`在测试执行前因命令额外设置`MTLLINKER_FLAGS=-warnings-as-errors`而失败；当前Metal linker不接受该参数，compiler已由工程设置使用`-Werror`。移除错误linker参数并从fresh evidence目录重跑，不复用该bundle。
- **验收错误 2：** `/tmp/LuneX-18-3_1-focused-r2.b7SIpC`执行`4 total / 3 passed / 1 failed`；三个surface owner用例通过，唯一AppModel组合用例在controlled environment先记录第三个application、AppModel尚未从`await`恢复更新press owner的窗口内发送事件，导致四次`.local`、input application超时，closed geometry同样在owner切换前读到`.captured`。增加无副作用current-surface admission查询并让测试等待真实owner状态，不重复发送began或使用任意yield次数；下一轮使用fresh bundle。
- **focused：** fresh `/tmp/LuneX-18-3_1-focused-r3.tXpOru`结构化通过`4/4 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded`且`0 error / 0 warning / 0 analyzer warning`；证明owner balanced/replacement/failure和AppModel current geometry/input application。下一步仅构建fixed tvOS与visionOS actual条件分支。
- **审计修订：** tvOS `/tmp/LuneX-18-3_1-tvos.54OJ6K`与visionOS `/tmp/LuneX-18-3_1-vision.22Jxk6`均结构化`succeeded/0/0/0`且各有AIR/metallib；随后delivery审计发现button-up失败缺少自身retry且queued down仍会发送。已增加failed-button best-effort release、失败generation queued-down suppression及确定性测试；旧`4/4`只作中间证据，需fresh focused复验。
- **修订focused：** `/tmp/LuneX-18-3_1-focused-r4.e1UeNI`结构化通过`5/5 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded/0 error/0 warning/0 analyzer warning`；下一步运行41项remote contract、surface lifecycle与AppModel相关矩阵。
- **相关矩阵：** `/tmp/LuneX-18-3_1-related.SpHKnV`结构化通过`41/41 passed / 0 skipped / 0 failed / 0 expected failure`且build零诊断，覆盖完整remote contract/owner、14项surface geometry lifecycle及6项AppModel presentation/input路径。下一步fresh normal。
- **normal：** `/tmp/LuneX-18-3_1-normal.nIpesJ`结构化通过`1004 total / 1003 passed / 1 exact Keychain skip / 0 failed / 0 expected failure`，build为`succeeded/0/0/0`；Keychain/live-host opt-in均unset。下一步五平台Debug。
- **五平台Debug：** `/tmp/LuneX-18-3_1-builds.hQ7AVJ`中macOS、固定iPhone/iPad/Apple TV/Vision Pro全部结构化`succeeded/0 error/0 warning/0 analyzer warning`且各有一份AIR/metallib；固定UUID仅作build destination，未查询或操作simulator。已同步runtime contract、roadmap和planning，下一步repository pre-gate。
- **repository pre-gate：** `/tmp/LuneX-18-3_1-repository-pre.nYAHpJ`完整通过fixture self/tree、OpenSpec strict `9/9`与pre-mark `12/50 next 3.1`、generator四次稳定SHA-256 `ef2e3e615f1dbd84b76bfe4c8681fab7d44291176f06324acd757fa1c1008353`、精确11文件scope、membership/source semantics、retained focused/related/normal/五平台build、privacy/clean-room/reference、opt-in/process和diff门。3.1已勾选，下一步只读final-state，不重复test/build/generator或simulator操作。
- **记录错误：** 首个跨文件记录补丁因错误假设`findings.md`存在与`progress.md`相同的五平台末尾锚点而被`apply_patch`原子拒绝，无文件发生部分写入；改为稳定文件补丁与各自EOF追加，不重复该失败方式。
- **final-state错误：** 首轮`/tmp/LuneX-18-3_1-final-state.IrtwNB`已通过OpenSpec strict、`13/50 next 3.2`、工程哈希和精确12文件scope，但在读取retained test/build前因包装器误断言不存在的复数内部标识符`failedInputGenerations`而退出；源码实际为单一`failedInputGeneration`并以`prependingEvents`补发failed-button up。后续从fresh目录执行尚未完成的合同级source/retained/boundary门，不重复已通过检查。
- **final-state：** 修正后的`/tmp/LuneX-18-3_1-final-state-r2.f0WIxl`复用首轮保存的strict `9/9`、apply `13/50 next 3.2`并重新确认current project hash/scope，随后只读通过source/task semantics、retained `5/5`、`41/41`、`1004/1003/1/0`、五平台build/Metal、privacy/reference/opt-in/process/diff门；未重复test/build/generator或simulator操作。3.1可独立提交推送。
- **post-record：** `/tmp/LuneX-18-3_1-post-record.XZcSS0`通过`13/50 next 3.2`、稳定project hash、精确12文件scope、pre/final证据记录、opt-in/process/reference和diff检查；下一步最终diff审计后独立提交推送。

## 2026-08-07 阶段 18 任务 3.2 启动

- **状态：** `complete`；终态UI修订后的repository pre-gate通过，3.2已重新勾选，OpenSpec预期为`14/50 ready`、next 3.3；等待修订后只读final-state。
- **基线：** 3.1已提交推送为`e3abab8 Capture tvOS stream surface presses`，fetch后`HEAD == origin/main == e3abab8a38d12dd9d9689d233da1eb7824e6f134`且工作树clean。
- **缺口：** tvOS `StreamStatusOverlay`当前永久显示并包含可聚焦按钮，AppModel只由actual UIKit geometry/focus推导input eligibility；SwiftUI overlay显示或导航离开Stream时没有先于view focus callback关闭remote admission的显式状态，因此存在同一按键被本地UI与remote capture竞态消费的窗口。
- **实现范围：** 增加framework-free workspace/overlay focus handoff状态与current AppModel application；remote admission仅在Stream workspace可见、overlay隐藏、actual scene/surface可见且focus eligible时开放。显示overlay或离开Stream先同步切为`.overlayVisible`/`.notFocused`并释放active presses；隐藏overlay后等待actual surface focus callback再开放。tvOS SwiftUI overlay获得明确focus target和Hide Controls命令。
- **边界：** Back/Menu/Home/volume/capture/power完整reserved command与native escape属于3.3；controller、feedback及stop/focus-loss ordered provider release分别属于3.4–3.6。3.2不把默认UIKit local behavior或unsigned build描述为物理Siri Remote/focus证明。
- **验收计划：** 纯值handoff矩阵、owner overlay release/reopen、AppModel navigation/overlay/current-generation组合与tvOS SwiftUI compile；随后fresh normal、五平台Debug、repository/final-state。真实Keychain/live-host保持禁用，不查询或操作simulator inventory/lifecycle。
- **实现：** `TVRemoteFocusHandoffState`以navigation/workspace/overlay与fresh-focus geometry revision边界归约local/stream eligibility；AppModel在意图变化时同步更新press owner，actual geometry只在更高revision且surface eligible时清除等待门。tvOS workspace按overlay显示条件渲染controls、用`FocusState`请求surface focus，并提供Hide Controls命令。
- **测试：** 新增纯值fresh-focus/local-navigation矩阵和owner overlay release/reopen；扩展AppModel组合用例验证初始overlay、隐藏后旧geometry仍local、fresh geometry才capture、held press在overlay显示时balanced release、settings/navigation返回local及closed geometry。
- **实现错误 1：** 首个AppModel跨距离组合补丁未匹配geometry admission锚点而被`apply_patch`原子拒绝，contract文件此前的独立补丁不受影响且AppModel无部分写入；改为属性/API、begin、geometry、snapshot/helper四个局部补丁，不重复大锚点补丁。
- **系统更新后恢复：** 唯一遗留focused `xcodebuild` session 29733已等待到明确`exit 0`；`/tmp/LuneX-18-3_2-focused.xA2quo`结构化通过`4/4 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded/0 error/0 warning/0 analyzer warning`。OpenSpec仍保持`13/50 next 3.2`，未操作simulator或Keychain/live-host。
- **下一步：** 仅构建fixed Apple TV与Vision Pro destination以覆盖actual tvOS SwiftUI focus/conditional-overlay分支和visionOS隔离分支；随后完成人工竞态审计、扩大相关矩阵、fresh normal、五平台Debug与repository/final-state。
- **人工审计修订：** 首轮direct tvOS `/tmp/LuneX-18-3_2-tvos.2CvZrC`与visionOS `/tmp/LuneX-18-3_2-vision.XBsmrc`均零诊断成功，但随后发现overlay已隐藏时重复设置`false`会无实际focus变化地重新关闭capture并等待可能永不到达的geometry。setter已改为同值严格no-op并新增回归；首轮focused/direct build仅作中间证据，必须fresh复验。
- **修订focused/direct：** `/tmp/LuneX-18-3_2-focused-r2.KTjwGJ`通过`4/4`且零诊断；fixed tvOS `/tmp/LuneX-18-3_2-tvos-r2.aq89tz`与visionOS `/tmp/LuneX-18-3_2-vision-r2.qU9HtD`均`succeeded/0/0/0`并有AIR/metallib。
- **相关矩阵：** `/tmp/LuneX-18-3_2-related.kbZRhO`结构化通过`43/43`且零诊断，覆盖complete remote reducer/owner、surface/geometry lifecycle和相关AppModel replacement/terminal路径。
- **normal：** `/tmp/LuneX-18-3_2-normal.KIqw0B`通过`1006 total / 1005 passed / 1 exact Keychain skip / 0 failed / 0 expected failure`且零诊断；真实Keychain/live-host opt-in均unset。
- **五平台Debug：** `/tmp/LuneX-18-3_2-builds.AwsH8s`中macOS、固定iPhone/iPad/Apple TV/Vision Pro全部`succeeded/0 error/0 warning/0 analyzer warning`且各有AIR/metallib；未查询或操作simulator。已同步runtime contract、roadmap和planning，下一步repository pre-gate，3.2仍未勾选。
- **记录错误 2：** 首个跨五文件文档补丁错误假设runtime contract中3.1末句的换行方式，`apply_patch`原子拒绝且没有部分写入；随后以稳定`## Fixed simulator inventory`标题插入3.2章节，并单独更新roadmap/planning。
- **repository pre-gate：** `/tmp/LuneX-18-3_2-repository-pre.CmABju`完整通过fixture self/tree、OpenSpec strict `9/9`与pre-mark `13/50 next 3.2`、generator四次稳定SHA-256 `ef2e3e615f1dbd84b76bfe4c8681fab7d44291176f06324acd757fa1c1008353`、精确十文件scope、source/test semantics、retained focused/direct/related/normal/五平台build、privacy/clean-room/reference、opt-in、process和diff门。3.2已勾选，下一步只读final-state。
- **final-state：** `/tmp/LuneX-18-3_2-final-state.HzeLfq`只读通过OpenSpec strict `9/9`、apply精确`14/50 next 3.3`、稳定project hash、精确十一文件scope、current source/task semantics、全部retained focused/direct/related/normal/五平台build及privacy/reference/opt-in/process/diff边界；没有重复test/build/generator或simulator操作。3.2可独立提交推送。
- **post-record：** `/tmp/LuneX-18-3_2-post-record.K9dE1v`通过`14/50 next 3.3`、稳定project hash、十一文件scope、pre/final证据引用、retained test counts、opt-in/process/reference和diff门；下一步最终diff审计与独立提交推送。
- **终态UI审计修订：** post-record后的最终diff复核发现remote termination/provider failure若发生在overlay隐藏时，统一platform clear只清owner/geometry而不会恢复controls，Stream导航可停在无控制项黑屏。clear路径现直接恢复overlay state后再清runtime，并扩展reconnect/remote-termination组合测试；此前focused/related/normal/direct/build/pre/final证据全部失效，OpenSpec checkbox已回退，必须从fresh evidence链复验后才可重新勾选或提交。
- **终态修订fresh证据：** focused `/tmp/LuneX-18-3_2-focused-r3.b9ciW0`通过`5/5`，相关矩阵`/tmp/LuneX-18-3_2-related-r2.FdIxGY`通过`43/43`，normal `/tmp/LuneX-18-3_2-normal-r2.7WhDLh`通过`1006/1005/1 exact Keychain skip/0`；三份build均零结构化诊断。
- **修订五平台Debug：** `/tmp/LuneX-18-3_2-builds-r2.huymlz`中macOS、固定iPhone/iPad/Apple TV/Vision Pro全部`succeeded/0/0/0`且各有AIR/metallib；Apple TV覆盖actual tvOS SwiftUI分支，Vision Pro确认terminal修订后的隔离。未查询或操作simulator，下一步修订repository pre-gate。
- **修订repository gate错误：** `/tmp/LuneX-18-3_2-repository-pre-r2.*`已通过fixtures、strict/pre-mark、四次generator与scope，随后验证器错误地用单行`rg`跨行匹配`settingOverlayVisible(\n true`并退出；这是source assertion错误而非源码或证据失败。改为函数上下文检查并从fresh目录完整重跑。
- **修订repository pre-gate：** `/tmp/LuneX-18-3_2-repository-pre-r3.rICtus`完整通过fixtures、strict `9/9`、pre-mark `13/50 next 3.2`、generator四次稳定、精确十文件scope、terminal/current source/test semantics、修订retained tests/五平台build、privacy/reference/opt-in/process/diff门。3.2已重新勾选，下一步只读final-state。
- **修订final-state：** `/tmp/LuneX-18-3_2-final-state-r2.dFJcBe`只读通过strict `9/9`、apply `14/50 next 3.3`、稳定project hash、十一文件scope、current terminal/focus semantics、修订`5/5`、`43/43`、`1006/1005/1/0`与五平台build及全部边界；没有重复test/build/generator/simulator操作。3.2可提交推送。
- **修订post-record：** `/tmp/LuneX-18-3_2-post-record-r2.CzhtnJ`通过`14/50 next 3.3`、project hash、十一文件scope、修订pre/final引用、retained counts、opt-in/process/reference和diff门；进入最终diff审计与独立提交推送。

## 2026-08-07 阶段 18 任务 3.3 收口

- **状态：** `complete`；repository pre-gate通过后OpenSpec已勾选3.3，预期`15/50 ready`、next 3.4，等待只读final-state与独立提交推送。
- **实现：** actual tvOS surface把Menu映射为`backMenu`，把公开但不支持的Page Up/Down、123、Four Colors及未来未知press映射为`unsupported`；reserved/local begin/change/end/cancel完整返回UIKit，captured changed留在Moonlight owner。AppModel只在expected tvOS应用typed command state，Back/Menu显示overlay并复用3.2 handoff释放held press，其他reserved命令不进入Moonlight delivery。
- **公开API边界：** tvOS 26.4 app responder没有Home、volume、system capture或power的公开`UIPressType`，因此不伪造runtime callback；finite state仅报告`.deferToSystem/.systemOwned`。状态和诊断不保存`UIPress`、focus item、controller、host或payload identity。
- **修订证据：** focused `/tmp/LuneX-18-3_3-focused-r2.BKpneI`为`3/3`；direct tvOS `/tmp/LuneX-18-3_3-tvos-r2.m8QkzS`与visionOS `/tmp/LuneX-18-3_3-vision-r2.fmO2Sl`均`succeeded/0/0/0`；相关矩阵`/tmp/LuneX-18-3_3-related.PgiNcV`为`44/44`；normal `/tmp/LuneX-18-3_3-normal.5ChBp1`为`1007/1006/1 exact Keychain skip/0`；五平台Debug `/tmp/LuneX-18-3_3-builds.K29Tfl`全部`succeeded/0/0/0`且各有AIR/metallib。
- **失效证据：** 补`pressesChanged` ownership分流前的首轮focused/direct证据只作为中间记录，不作为最终验收。
- **证明边界：** 只证明finite contract、AppModel application、检查路径无synthetic Moonlight delivery和unsigned SDK branch compatibility；不证明物理Siri Remote、Home/volume/capture/power、focus engine、signed Apple TV/Vision Pro、live Sunshine、HDR/空间音频、延迟、性能、功耗或热状态。
- **恢复约束：** 系统更新后未查询simulator inventory，也未执行create/clone/boot/install/launch/run/shutdown/delete；固定UUID仅用于已完成build destination。真实Keychain与live-host opt-in继续禁用。
- **repository pre-gate：** `/tmp/LuneX-18-3_3-repository-pre.y7lh71`完整通过fixture self/tree、OpenSpec strict `9/9`与pre-mark `14/50 next 3.3`、generator四次稳定SHA-256 `ef2e3e615f1dbd84b76bfe4c8681fab7d44291176f06324acd757fa1c1008353`、精确十二文件scope、source/membership/no-delivery semantics、全部retained tests/builds、privacy/clean-room/reference、opt-in、process和diff门。
- **final-state：** `/tmp/LuneX-18-3_3-final-state.ZREyZa`只读通过OpenSpec strict `9/9`、apply `15/50 next 3.4`、稳定project hash、精确十三文件scope、current source/task semantics、修订`3/3`、`44/44`、`1007/1006/1/0`、direct/五平台build与全部边界；没有重复test/build/generator/simulator操作。
- **post-record：** `/tmp/LuneX-18-3_3-post-record.igbLBj`通过`15/50 next 3.4`、稳定project hash、十三文件scope、pre/final记录、retained counts、opt-in/process/reference和diff门。
- **最终审计：** Menu/unsupported每个press identity只发布一次local intent且完整交回UIKit，captured lifecycle保持Moonlight ownership；Back/Menu无input transport调用，typed state无raw identity，Home/volume/capture/power没有伪造callback。Task 3.3可独立提交推送。

## 2026-08-07 阶段 18 任务 3.4 启动

- **状态：** `in_progress`；3.3已提交推送为`e600f6d Keep tvOS system commands local`，fetch确认`HEAD == origin/main`且工作树clean，OpenSpec为`15/50 ready`、next 3.4。
- **现有缺口：** `GameControllerPlatformMonitor`只读取`GCController.controllers()`并发布vendor/player/profile连接列表，没有安装extended/micro value handlers，没有session/input generation、slot lease、complete state、stale callback或disconnect replacement ownership；AppModel向platform coordinator固定发送空controller leases。
- **复用合同：** 现有`TVVisionControllerSlot/Lease`、`TVControllerInputSnapshot/RosterSnapshot`已经验证16-slot、input generation、profile、mask、supported buttons、完整state与stable slot ordering；3.4不复制remote registry。
- **实现范围：** 新增framework-free generation-owned slot runtime与finite normalized complete state；actual tvOS main-actor owner使用`GCControllerDidConnect/Disconnect`、extended/micro `valueChangedHandler`和main handler queue，最低空闲slot、单调lease generation、旧token拒绝、断开释放slot和新lease replacement。AppModel保存current roster并把leases应用到current presentation input。
- **coordinator修订：** 同一geometry/input source revision下，仅当input snapshot相同而controller leases变化时允许component更新；同revision capability/focus变化继续conflicting fail-closed，避免为controller变化伪造geometry revision。
- **边界：** 3.4只建立actual handler/roster/lease/state ownership，不向host发送controller events，不应用rumble/LED/motion feedback，也不提前完成3.5 registry routing或3.6 focus/scene/provider ordered release。unsigned build不证明物理controller mapping。
- **验收计划：** pure normalizer/slot/capacity/disconnect replacement/stale token；coordinator lease-only same-revision；AppModel current-generation roster application/clear；actual tvOS和visionOS隔离build；扩大相关矩阵、fresh normal、五平台Debug、repository/final-state。
- **验收错误 1：** 首轮focused `/tmp/LuneX-18-3_4-focused.hyTeNM`在0 tests时仅因测试对临时`TVGameControllerSlotRuntime(...)`调用mutating helper而编译失败；production macOS分支没有报告编译错误。已改为局部`var` runtime，失败bundle不作为验收证据，下一轮使用fresh DerivedData和result bundle。
- **focused：** fresh `/tmp/LuneX-18-3_4-focused-r2.MyATKc`结构化通过`5/5 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded/0 warning/0 error/0 analyzer warning`；下一步编译fixed Apple TV actual GameController分支。
- **验收错误 2：** 首轮fixed Apple TV `/tmp/LuneX-18-3_4-tvos.Czp0Ks`结构化失败为`2 errors / 0 warnings`；两个错误都是NotificationCenter block把task-isolated`Notification`直接捕获进main-actor closure，Swift 6报告`Sending 'notification' risks causing data races`。保持`queue: .main`并检查主线程，在隔离边界内通过私有unchecked controller reference传递framework对象，不跨层发布identity；下一轮使用fresh tvOS bundle。
- **actual tvOS编译：** 修订fresh `/tmp/LuneX-18-3_4-tvos-r2.9WJTuS`结构化为`succeeded/0 warning/0 error/0 analyzer warning`且有一份AIR和一份metallib；固定UUID只作build destination，下一步构建Vision Pro隔离分支。
- **visionOS隔离编译：** fresh `/tmp/LuneX-18-3_4-vision.uUQVaS`结构化为`succeeded/0 warning/0 error/0 analyzer warning`且有一份AIR和一份metallib；下一步人工审计handler cleanup、replacement、roster application竞态和3.4 no-delivery边界。
- **人工审计：** actual owner仅在main queue/main actor内持有`GCController` identity，stop/disconnect先清value handler并恢复原`handlerQueue`；slot最低空闲、lease单调且replacement取得新lease；AppModel只保存完整roster并向presentation提交leases，没有调用controller input transport；same-revision仅放行完全相同input snapshot的lease变化，capability/focus冲突继续fail closed。
- **相关矩阵：** fresh `/tmp/LuneX-18-3_4-related.USzkjv`结构化通过`85/85 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded/0 warning/0 error/0 analyzer warning`；下一步fresh normal suite。
- **normal：** fresh `/tmp/LuneX-18-3_4-normal.PblBXf`结构化通过`1011 total / 1010 passed / 1 skipped / 0 failed / 0 expected failure`，唯一skip精确为`testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，build零诊断；真实Keychain/live-host opt-in均unset，下一步五平台Debug。
- **五平台Debug：** `/tmp/LuneX-18-3_4-builds.ygHyOW`中的macOS、fixed iPhone、fixed iPad、fixed Apple TV和fixed Vision Pro均串行结构化读回为`succeeded / 0 warning / 0 error / 0 analyzer warning`，每个平台各有一份AIR和一份metallib。固定UUID仅作build destination，本任务未查询、创建、启动或运行simulator。
- **待完成：** 已同步runtime contract、roadmap和三份planning；下一步从fresh目录运行repository pre-gate。只有该门通过后才允许勾选3.4并进入只读post-mark final-state。
- **验收错误 3：** 首轮repository pre-gate `/tmp/LuneX-18-3_4-repository-pre.IydUi3`在fixture self/tree通过后，因包装器误断言不存在的`summary.totals.total`而退出；保存的strict JSON实际为`items 9 / passed 9 / failed 0`且每项`valid=true`。该轮未进入generator、retained evidence或后续门禁，不作最终验收；改用`summary.totals.items`并从fresh目录完整重跑。
- **repository pre-gate：** 修正后的fresh `/tmp/LuneX-18-3_4-repository-pre-r2.cKwJoH`从头通过fixture self/tree、OpenSpec strict `9/9`、pre-mark `15/50 next 3.4`、四次稳定generator hash、精确十一文件scope、source/test/no-delivery semantics、全部retained test/build证据、privacy/reference/opt-in/process与diff门。3.4已勾选，预期为`16/50 next 3.5`。
- **状态：** `complete`；下一步只读post-mark final-state，不重复test/build/generator/simulator操作。
- **post-mark final-state：** `/tmp/LuneX-18-3_4-final-state.0GVsGm`只读通过strict `9/9`、OpenSpec `16/50 next 3.5`、稳定project hash、精确十二文件scope、current semantics、全部retained evidence及privacy/reference/opt-in/process/diff边界；没有重复test/build/generator/simulator操作。下一步post-record和最终diff审计。
- **post-record：** `/tmp/LuneX-18-3_4-post-record.8PiBxS`通过`16/50 next 3.5`、稳定project hash、十二文件scope、pre/final记录、retained evidence、opt-in/process/reference和diff门。
- **最终审计：** slot candidate commit、active mask重建、handler清理与queue恢复、replacement fresh lease、current roster application及no-delivery边界均成立；未发现新的正确性、隐私或跨平台隔离问题。Task 3.4可独立提交推送。

## 2026-08-07 阶段 18 任务 3.5 启动

- **状态：** `in_progress`；3.4已提交推送为`da295bb Own tvOS controller runtime`，fetch确认`HEAD == origin/main`且工作树clean，OpenSpec为`16/50 ready`、next 3.5。
- **现有路径：** `MoonlightRemoteInputProvider`已拥有唯一`RemoteControllerRegistry`、arrival/state/disconnect wire输出、held controller state、feedback source/stream和capability admission；`SessionMediaEnvironment`把current-generation feedback送到AppModel。3.5必须复用该registry，不能在tvOS另建wire ownership。
- **关键缺口：** 3.4 roster目前只进入platform presentation leases，不发送controller connection/state；低级`.controllerState`会绕过registry内部state，因此不能作为complete roster接线，否则feedback lookup与后续release会观察空状态。现有`playerIndex`只偏好1...4，也不足以显式承载16-slot lease。
- **实现方向：** 增加framework-free、opaque controller routing identity与高层complete-snapshot input；registry以lease slot作为checked preferred index，保存完整state后产生现有wire event。AppModel串行reconcile current roster的disconnect/connect/snapshot，并把provider feedback只交给匹配current input/controller lease的actual owner。
- **边界：** controller ID由generation/slot/lease组成且不含vendor/framework identity；3.5只应用公开且实际声明支持的rumble/trigger/LED/motion-rate能力。focus/scene/provider/replacement/stop的完整ordered release barrier仍归3.6，3.5不得把unsigned编译或合成feedback描述为物理手柄证明。
- **验收计划：** registry preferred 16-slot与complete state、disconnect/stale lease、AppModel FIFO reconcile/current generation、actual owner capability/feedback admission与handler cleanup、反馈映射no-stale、tvOS/visionOS隔离、focused/related/normal/五平台/repository/final-state。
- **首次编译：** fresh macOS `/tmp/LuneX-18-3_5-compile-mac.c0RbId`与fixed Apple TV `/tmp/LuneX-18-3_5-compile-tv.qFXSAB`均结构化为`succeeded/0 warning/0 error/0 analyzer warning`；Apple TV固定UUID仅作build destination，没有查询或操作simulator lifecycle。
- **验收错误 1：** 首轮focused `/tmp/LuneX-18-3_5-focused-first.UpxyQa`在0 tests时因三处测试源码编译错误退出：既有`ParsedControllerState`未暴露`leftTrigger`，两处`await iterator.next()`不能位于XCTest autoclosure。production/shared source没有编译错误；改为直接检查packet bytes并先await局部变量，从fresh bundle重跑。
- **验收错误 2：** 第二轮focused `/tmp/LuneX-18-3_5-focused-r2.QlwjMx`结构化为`5 total / 4 passed / 1 failed`且build零诊断；四项registry/router/motion测试通过，唯一AppModel失败是测试在controlled environment记录send后、routing Task写回routed state前立即断言。扩展wait到send与state双完成屏障后用fresh bundle重跑。
- **focused：** fresh `/tmp/LuneX-18-3_5-focused-r3.vWrygN`结构化通过`5/5 passed / 0 skipped / 0 failed / 0 expected failure`且build为`succeeded/0 warning/0 error/0 analyzer warning`。后续审计把多controller同批arrival fallback统一到final mask、haptic部分失败改为stop-all，并增加complete snapshot进入existing releaseAll的断言；需以修订后fresh focused为最终证据。
- **实现完成：** complete roster现在先在candidate `RemoteControllerRegistry`原子校验exact `0...15` preferred slots，再用final active mask产生arrival/complete state；invalid replacement回滚且existing held state供`releaseAllControllerStates()`使用。opaque ID固定为`tv:<input generation>:<lease generation>:<slot>`，不含vendor或framework identity。
- **actual cleanup：** tvOS owner保存并在disconnect/stop恢复原extended/micro `valueChangedHandler`；Core Haptics engine启动后若player启动失败会立即停止该player/engine，stop/replacement也stop-all。AppModel feedback/motion同时匹配current input generation、slot与lease，motion按lease/type保留latest finite sample。
- **竞态验收：** 新增受控阻塞A→B→C roster replacement，证明provider routing严格串行，旧lease feedback/motion inert，只有current C lease继续接收；测试double增加一次性send阻塞、blocked状态和显式恢复。
- **最终focused：** `/tmp/LuneX-18-3_5-focused-final-r2.qj3Kuj`为`5/5`且build `succeeded/0 error/0 warning/0 analyzer warning`。较早final candidate为`4/5`仅因测试在增加两次roster application后仍硬编码旧presentation counts；改为geometry前基数`+2/+3`后fresh通过，不保留失败run为最终证据。
- **related/normal：** `/tmp/LuneX-18-3_5-related-final.xOsmvX`为`170/170`且零结构化诊断；`/tmp/LuneX-18-3_5-normal-final.fFbr02`为`1015 total / 1014 passed / 1 skipped / 0 failed`且零结构化诊断，唯一skip仍是显式禁用的真实Keychain round-trip。
- **平台build：** direct tvOS `/tmp/LuneX-18-3_5-tvos-final.Tnldhb`为`succeeded/0/0/0`并有`1 AIR / 1 metallib`；五平台Debug `/tmp/LuneX-18-3_5-builds-final.10FtDl`全部`succeeded/0 error/0 warning/0 analyzer warning`且各有`1 AIR / 1 metallib`。固定UUID仅作build destination，未执行任何simulator lifecycle操作。
- **验收错误 3：** focused最终xcresult的首次只读diagnostics包装命令因`jq`表达式`.errors?//empty`缺少`//`两侧空格而parser error；用正确表达式只读同一xcresult确认四类diagnostic均为0，没有重跑test。
- **当前门：** runtime contract、roadmap与三份planning已同步，但OpenSpec仍保持`16/50 next 3.5`。下一步从fresh目录运行repository pre-gate；通过前不得勾选3.5。3.6完整ordered held-state release/local navigation restoration、物理controller/host/signed/HDR/spatial/performance证据均未完成。
- **repository pre-gate：** fresh `/tmp/LuneX-18-3_5-repository-pre.qGGaan`从头通过fixture self/tree、OpenSpec strict `9/9`、pre-mark `16/50 next 3.5`、四次稳定generator hash、精确十三文件scope、source/test/membership semantics、focused `5/5`、related `170/170`、normal `1015/1014/1/0`、direct tvOS、五平台build及privacy/clean-room/reference/opt-in/process/diff边界。
- **状态：** `complete`；3.5已勾选，预期权威状态为`17/50 ready`、next 3.6。下一步只读post-mark final-state，不重复test/build/generator/simulator操作。
- **post-mark final-state：** `/tmp/LuneX-18-3_5-final-state.efZjqf`只读通过strict `9/9`、OpenSpec `17/50 next 3.6`、稳定project hash、精确十四文件scope、current routing/feedback/cleanup semantics、全部retained evidence及privacy/clean-room/reference/opt-in/process/diff边界；没有重复test/build/generator/simulator操作。下一步post-record和最终diff审计。
- **验收错误 4：** 首轮post-record `/tmp/LuneX-18-3_5-post-record.*`在OpenSpec与scope通过后，把zsh特殊数组变量`path`误用为循环变量，覆盖命令搜索路径并导致后续`rg: command not found`；代码与retained evidence没有失败。改用`evidence_path`并从fresh目录完整重跑。
- **post-record：** 修正后的 `/tmp/LuneX-18-3_5-post-record-r2.BNqR7l`通过`17/50 next 3.6`、稳定project hash、十四文件scope、pre/final记录、retained evidence、opt-in/process/reference和diff门。
- **最终审计：** candidate registry只在完整slot/mask/state校验后提交；routing FIFO、current generation/lease feedback、motion gate、original handler/queue恢复和haptic partial-failure stop均成立。Xcode 26.4 header确认default/all haptic locality保证支持；trigger仍按双locality实际探测。未发现新的正确性、隐私或跨平台隔离问题，Task 3.5可独立提交推送。

## 2026-08-07 阶段 18 任务 3.6 启动

- **状态：** `in_progress`；3.5已提交推送为`d372f06 Route tvOS controller feedback`，fetch确认`HEAD == origin/main`且工作树clean，OpenSpec为`17/50 ready`、next 3.6。
- **现有基础：** `SessionMediaEnvironment.releaseInput()`已按session/media generation进入唯一provider `releaseAll`；`TVPlatformInputReleasePlan`已定义close admission、remove handlers、reverse remote-up、await barrier、restore focus顺序；provider自身合并同代并发release并在accepted delivery之后追加neutral state。
- **production缺口：** actual `TVRemoteSurfacePressCaptureOwner`当前只执行`.sendRemote`，忽略close/open、controller handler removal、barrier和focus restoration effects。overlay/focus/scene loss仅同步改变local disposition，terminal clear会直接取消routing/停止owner；本地SwiftUI focus可能先于provider release恢复。
- **实现方向：** owner串行执行完整effect，另设实际admission generation，使surface replacement/local-to-stream在barrier完成前仍不可capture；AppModel用current-generation effect handler停止并等待controller roster/routing/motion、调用existing release、最后恢复overlay/local focus，fresh eligible geometry再重启actual controller owner取得fresh leases。
- **terminal与失败：** stop/reconnect/remote termination/media failure在清runtime前join同一owner release task；provider send/release failure保持fail-closed并仍完成本地恢复。重复local update、并发terminal和已经进行中的focus release不得产生第二个barrier。
- **验收计划：** owner effect order/admission fence/surface replacement/provider failure，AppModel overlay/scene loss、controller held neutral、blocked release、本地focus时序、replacement/remote termination/stop idempotency，随后focused/related/normal、direct tvOS、五平台Debug和repository/final-state。
- **实现错误 1：** 首轮静态检查直接调用独立`swift-format`，系统更新后的shell中该命令不存在并在lint前退出；源码与测试均未执行。后续固定使用Xcode toolchain中的`xcrun swift-format`，不重复该失败命令。
- **实现错误 2：** `xcrun swift-format lint --strict`使用Xcode默认两空格规则扫描两个完整既有大文件，产生数千条与仓库四空格风格冲突的基线缩进诊断，不能作为本项门禁；不对整文件format，仅修本次新增局部pattern并以warnings-as-errors编译、`git diff --check`和人工diff验收。
- **实现错误 3：** 首版AppModel把所有`restoreLocalFocus`都解释为显示overlay；reducer的local-to-local reason变化也会发该effect，导致用户关闭overlay等待fresh focus时被异步重新打开。修为仅真实close/release pending完成时公开local UI，且`.replacing`在随后open前不闪回overlay。
- **实现错误 4：** macOS测试宿主配置tvOS workflow时，通用Mac input termination先占用controlled“next release”，blocked-stop断言观察到tvOS owner尚未关闭；真实tvOS不编译Mac输入，但共享AppModel终态次序仍应明确。修为先执行tvOS terminal close/release，再做通用Mac termination，后续platform stop只幂等join。
- **实现错误 5：** 调整内部`stopMediaEnvironment`后blocked-stop仍先观察到Mac release；继续追踪发现`stopStream`入口本身还有一次早期Mac termination。已在最外层stop入口先执行同一tvOS terminal release，内部stop/platform stop仅幂等join，不新增barrier。
- **竞态收紧：** 人工审计发现单一release-pending布尔值会被较早排队序列的`restore`提前清零，且replacement后已排队的旧`open`可能在terminal release前短暂重启controller handlers。owner现按每个含`closeRemoteAdmission`的FIFO操作计数，并在执行`open`副作用前重新验证current input/state/surface；新增replacement与terminal重叠双barrier回归。
- **fail-closed收紧：** AppModel两处理论上的owner update合同异常不再直接invalidate；owner使用内部已验证的current state/leases转为`.inputUnavailable`，执行close、handler removal、held up、existing provider barrier与local restoration。AppModel完整workflow另加入blocked replacement、duplicate replacement、blocked scene loss、duplicate scene loss和provider release failure后同代不可重开。
- **修订focused：** `/tmp/LuneX-18-3_6-focused-r3.ycXtoF`结构化通过`33/33 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded/0 warning/0 error/0 analyzer warning`；覆盖完整owner合同与五项AppModel current/reconnect/application/provider/replacement/scene/stop路径。
- **direct tvOS：** fixed Apple TV build `/tmp/LuneX-18-3_6-tvos-r2.5BXadt`结构化为`succeeded/0 warning/0 error/0 analyzer warning`，生成`1 HDRVideoShaders.air / 1 default.metallib`；固定UUID仅作build destination，没有查询、启动或运行simulator。
- **related matrix：** `/tmp/LuneX-18-3_6-related.kUZxE4`串行结构化读回为`229/229 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded/0 warning/0 error/0 analyzer warning`。下一步完成production diff审计，再运行fresh normal与五平台Debug门禁。
- **跟踪错误 1：** 首个三文件证据补丁使用了只存在于`progress.md`的统一尾部锚点，`apply_patch`原子拒绝且无部分写入；读取每个文件真实末尾后分别使用精确锚点完成记录。
- **最终审计修订：** 发现A→B→C同input generation连续replacement时，旧`open(B)`只校验input generation，可能在`release(B)`前短暂重开；跨input generation的release+open也会把新open错误绑定旧delivery generation。owner新增只在surface或ownership意图变化时推进的admission intent revision，open必须匹配最新意图；补连续replacement与generation replacement两项回归。此前focused/related/direct build保留为中间证据，修订后必须fresh重跑。
- **修订后focused：** `/tmp/LuneX-18-3_6-focused-r4.MH3aFT`结构化通过`35/35 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded/0 warning/0 error/0 analyzer warning`；新增连续replacement与跨input generation回归通过。该结果替代此前33项focused，下一步fresh related matrix。
- **related验收错误：** 首轮修订related `/tmp/LuneX-18-3_6-related-r2.Bn31c8`为`231 total / 230 passed / 1 failed`且build零诊断，唯一失败是既有macOS输入测试只等待actor snapshot可输入、未等待AppModel从`activate()`恢复并写回active generation，submit偶发得到`.inactiveGeneration`。收紧为snapshot与`macInputSurfacePolicy.admitsInput`同时成立后从fresh目录重跑；这不是3.6 production失败，失败bundle不作最终证据。
- **修订后related：** fresh `/tmp/LuneX-18-3_6-related-r3.U316bz`结构化通过`231/231 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded/0 warning/0 error/0 analyzer warning`；下一步fresh fixed Apple TV direct build。
- **修订后direct tvOS：** fresh `/tmp/LuneX-18-3_6-tvos-r3.z7MzTk`结构化为`succeeded/0 warning/0 error/0 analyzer warning`并生成`1 HDRVideoShaders.air / 1 default.metallib`；固定UUID仅作build destination，没有查询或操作simulator lifecycle。下一步fresh normal suite。
- **normal：** fresh `/tmp/LuneX-18-3_6-normal.dt203K`结构化通过`1022 total / 1021 passed / 1 skipped / 0 failed / 0 expected failure`，唯一skip精确为`testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，build为`succeeded/0 warning/0 error/0 analyzer warning`；Keychain/live-host opt-in保持unset。下一步五平台fresh Debug builds。
- **续接审计修订：** macOS更新后确认Xcode 26.4/Swift 6.3与Git基线不变。人工竞态审计发现跨generation open failure误标old generation，以及`invalidate()`后复用owner时旧defer可能扣除新pending release；已修为effect-generation fail-closed、per-operation UUID release accounting与无回绕UUID admission intent token，并新增两项回归。此前35/231/1022及build证据降为中间证据，下一步fresh focused。
- **续接focused/related：** fresh focused `/tmp/LuneX-18-3_6-focused-r5.I6eHeU`结构化通过`37/37`，fresh related `/tmp/LuneX-18-3_6-related-r4.B4s4Tw`通过`233/233`；两者均`0 skipped / 0 failed / 0 expected failure`且build四类diagnostic为0。下一步fresh fixed tvOS direct build。
- **续接direct/normal：** fixed tvOS `/tmp/LuneX-18-3_6-tvos-r4.wGNQq9`为`succeeded/0/0/0`且`1 AIR/1 metallib`；fresh normal `/tmp/LuneX-18-3_6-normal-r2.fzHNaM`为`1024/1023/1 exact Keychain skip/0`且build四类diagnostic为0。下一步五平台fresh Debug builds。
- **五平台build：** fresh `/tmp/LuneX-18-3_6-builds-r2.cEhpxR`中macOS、fixed iPhone/iPad/Apple TV/Vision Pro均`succeeded/0 warning/0 error/0 analyzer warning`且各有`1 AIR/1 metallib`；UUID仅作build destination，未执行simulator lifecycle。
- **当前门：** runtime contract、roadmap与三份planning已同步最终实现、证据与proof boundary；OpenSpec仍保持pre-mark `17/50 next 3.6`。下一步从fresh目录运行repository pre-gate，通过前不得勾选3.6。
- **repository pre-gate：** 首轮静态包装器误用不存在的`.restoreLocalNavigation` case名，在retained evidence前退出且不计验收；修正后的fresh `/tmp/LuneX-18-3_6-repository-pre.w3TVP6`完整通过fixture self/tree、strict `9/9`、pre-mark `17/50 next 3.6`、四次稳定generator hash、精确九文件scope、source/test membership与时序语义、focused `37/37`、related `233/233`、normal `1024/1023/1/0`、direct tvOS、五平台build及privacy/clean-room/reference/opt-in/process/diff边界。
- **状态：** `complete`；3.6已勾选，预期权威状态为`18/50 ready`、next 3.7。下一步只读post-mark final-state，不重复test/build/generator/simulator操作。
- **post-mark final-state：** `/tmp/LuneX-18-3_6-final-state.a7qNA6`只读通过strict `9/9`、OpenSpec `18/50 next 3.7`、稳定project hash、精确十文件scope、current ordered-release语义、全部retained evidence及privacy/clean-room/reference/opt-in/process/diff边界；未重复test/build/generator/simulator操作。下一步post-record和最终diff审计。
- **post-record：** `/tmp/LuneX-18-3_6-post-record.dHIyHe`通过`18/50 next 3.7`、稳定project hash、十文件scope、pre/final记录、retained evidence、opt-in/process/reference和diff门。
- **最终审计：** per-operation UUID accounting、actual admission generation、effect FIFO、controller task quiesce、existing provider barrier、local restoration、A→B→C intent fence、provider failure同代fail-closed及terminal idempotent join均成立；未发现新的正确性、隐私或跨平台隔离问题，Task 3.6可独立提交推送。
- **提交：** 3.6已提交推送为`bfe4e10 Order tvOS held input release`；fetch确认`HEAD == origin/main`且工作树clean，OpenSpec为`18/50 ready`、next 3.7。

## 2026-08-07 阶段 18 任务 3.7 启动

- **状态：** `complete`；OpenSpec已勾选3.7，权威进度为`19/50 ready`、next 4.1，post-record与最终diff审计已通过，等待独立提交推送。
- **范围：** remote event order、local focus、overlay handoff、reserved command、controller profile/slot/capacity、feedback、disconnect、stale callback、release、replacement与teardown；不借3.7新增display/HDR/audio production，也不把编译或注入测试表述为物理remote/controller证明。
- **验收：** focused 3.7新增/关键回归、完整tvOS input相关矩阵、fresh normal、direct fixed tvOS与五平台Debug，随后repository pre-gate、post-mark final-state、post-record和独立提交推送。
- **wire修复：** `.tvRemote`不得直接进入不支持它的wire codec；provider将方向键映射Win32 arrows、Select映射Return、Play/Pause映射media Play/Pause，并让归约事件进入既有held-key registry与ordered release barrier。Menu/focus继续fail closed。
- **最终证据：** focused `/tmp/LuneX-18-3_7-focused-r3.g0X36e`为`7/7`，related `/tmp/LuneX-18-3_7-related-r2.2QaiwN`为`236/236`，normal `/tmp/LuneX-18-3_7-normal.WCovl0`为`1027/1026/1 exact Keychain skip/0`；direct fixed tvOS与五平台Debug均零结构化诊断且各有AIR/metallib。
- **repository/final-state：** `/tmp/LuneX-18-3_7-repository-pre-r3.QRSRb6`完整通过pre-mark门；勾选后的只读`/tmp/LuneX-18-3_7-final-state.fKKBFH`确认strict `9/9`、`19/50 next 4.1`、稳定project hash、13文件scope、current semantics、retained evidence与全部boundary，未重复test/build/generator/simulator操作。
- **post-record/final audit：** `/tmp/LuneX-18-3_7-post-record.RaWllz`确认五份权威文档、pre/final路径、13文件scope、project hash与repository boundary；最终生产/测试/规范diff审计未发现新问题。
- **下一步：** 运行只读post-record和最终diff审计，独立提交推送3.7后进入4.1 actual tvOS scene/surface/decoded-frame到`StreamMetalPresenter`接线。

## 2026-08-07 阶段 18 任务 4.1 启动

- **状态：** `in_progress`；3.7已提交推送为`685487d Complete tvOS input regression`，fetch确认`HEAD == origin/main`且工作树clean，OpenSpec为`19/50 ready`、next 4.1。
- **范围：** 把actual tvOS scene/surface lifecycle与single normalized geometry绑定到既有`StreamMetalPresenter`和current decoded-frame source，确保旧generation/revision frame无效，并在detach/invalid/hidden/replacement/stop时清屏、恢复时只呈现current frame。
- **边界：** 复用现有decoder、`StreamVideoPresentationSource`、Metal presenter和platform presentation coordinator；不在4.1提前完成4.2 HDR capability、4.3 AppModel HDR state、4.4 audio route或4.5 shared media teardown。
- **验收计划：** 先盘点actual tvOS view/presenter/frame source现有接线，补focused lifecycle/geometry/frame/stale/clear-resume tests，再执行related、normal、fixed tvOS、五平台Debug和repository/final-state分层验收。
- **续接实现审计：** owner此前未记录admitted frame所属surface generation与scene/display eligibility，A→B scene切换可在新`.video`准入前恢复A帧，防御性late video也可能绕过closed scene；presenter接受新platform frame时未推进presentation revision，进行中的旧draw缺少fence。已补frame-surface/scene/display状态、stale delivery守卫、present revision和幂等clear语义，并开始增加actual presenter执行级测试；4.1仍未勾选。
- **focused命令错误：** `/tmp/LuneX-18-4_1-focused.U0uUni`误用没有test action的`LuneX-macOS` app scheme，Xcode在编译前以exit 66退出；该目录不计证据。已通过`xcodebuild -list`确认测试入口为`LuneXCoreTests`，从fresh DerivedData/result bundle重跑，app scheme仍只用于build。
- **focused harness错误：** `/tmp/LuneX-18-4_1-focused-r2.4AqAen`中3/5通过，两个actual presenter断言因离屏`MTKView.draw()`未自动调用delegate而观察到`present/clear == 0`；xcresult精确定位后，在测试调度点显式驱动`presenter.draw(in:)`，不修改production调度，必须fresh重跑。
- **stale测试预期错误：** `/tmp/LuneX-18-4_1-focused-r4.Dx4SoW`为6/7通过；唯一失败因测试主动draw后presenter合法重绘current frame 50，实际`[50,50]`中没有任何stale frame。断言改为保留两次current提交且display unavailable后不再增加，从fresh目录重跑。
- **focused：** fresh `/tmp/LuneX-18-4_1-focused-r5.1gdLMC`结构化通过`7/7 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded/0 warning/0 error/0 analyzer warning`；覆盖shared-source防绕过、actual presenter frame/clear、surface与ownership replacement、stale frame维度、display unavailable、decoder-start与geometry resubmit。下一步related matrix。
- **related matrix：** 系统更新前已完成的fresh `/tmp/LuneX-18-4_1-related.hqr5RJ`在macOS 27.0/Xcode 26.4下串行结构化读回为`240/240 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded/0 warning/0 error/0 analyzer warning`；覆盖presenter、platform coordinator/state、environment、AppModel、frame delivery及HDR renderer/surface既有回归。该门无需重跑，下一步完成production/test diff竞态审计。
- **更新后恢复：** 重新确认Xcode `26.4` build `17E192`、Swift `6.3`、宿主macOS `27.0` build `26A5388g`、Keychain/live-host opt-in unset、`HEAD == origin/main == 685487d`及预期九文件scope；未查询或操作simulator。4.1仍为`in_progress`且未勾选、未提交、未推送。
- **production diff审计修订：** owner的replacement比较在session ID前接受更大media generation，且遗漏input generation；不同session的高generation可错误接管，同session仅input replacement会被拒绝。现与coordinator顺序统一为exact platform/session后依次比较media/presentation/input，并补双向回归；此前focused/related降为中间证据，必须fresh重跑。
- **修订后focused：** fresh `/tmp/LuneX-18-4_1-focused-r6.EoFPrA`结构化通过`8/8 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded/0 warning/0 error/0 analyzer warning`；包含foreign-session takeover inert与同session input-only replacement accepted。下一步fresh related matrix。
- **修订后related：** fresh `/tmp/LuneX-18-4_1-related-r2.ymJCRP`结构化通过`241/241 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded/0 warning/0 error/0 analyzer warning`；production/test diff复核未再发现revision、clear/resume、geometry重交、unbind/rebind、stop或replacement问题。下一步fresh normal。
- **normal：** fresh `/tmp/LuneX-18-4_1-normal.nHnZZj`结构化通过`1035 total / 1034 passed / 1 skipped / 0 failed / 0 expected failure`，build为`succeeded/0 warning/0 error/0 analyzer warning`；原始日志精确确认唯一skip为`HostAndPersistenceTests/testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，Keychain/live-host opt-in保持unset。
- **normal只读解析错误：** Xcode 26.4对同一normal xcresult读取test-tree时再次出现已知`database.sqlite3` move冲突；未重复该失败子命令，改用结构化summary/build-results加retained原始日志确认唯一skip，测试本身无需重跑。下一步fixed Apple TV direct Debug build。
- **direct tvOS：** fixed Apple TV `/tmp/LuneX-18-4_1-tvos.4dvUQ4`结构化为`succeeded/0 warning/0 error/0 analyzer warning`并生成`1 HDRVideoShaders.air / 1 default.metallib`；固定UUID仅作build destination，未执行simulator lifecycle。下一步fresh五平台Debug。
- **五平台build错误 1：** 首轮`/tmp/LuneX-18-4_1-builds.nhyiEK`在macOS源码编译前因entitlement要求development certificate以exit 65停止，其余四平台未开始；该目录不计验收。离线编译门不应伪造signed artifact，改用`CODE_SIGNING_ALLOWED=NO`从fresh矩阵重跑。
- **五平台build：** fresh unsigned `/tmp/LuneX-18-4_1-builds-r2.Pl3YcW`中macOS、fixed iPhone/iPad/Apple TV/Vision Pro均`succeeded/0 warning/0 error/0 analyzer warning`且各有`1 AIR/1 metallib`；UUID仅作build destination，未执行simulator lifecycle。下一步同步权威文档并运行repository pre-gate。
- **repository pre-gate：** fresh `/tmp/LuneX-18-4_1-repository-pre.cIhA16`完整通过fixture self/tree、strict `9/9`、pre-mark `19/50 next 4.1`、四次稳定generator SHA-256 `ef2e3e615f1dbd84b76bfe4c8681fab7d44291176f06324acd757fa1c1008353`、精确13文件scope、membership与current owner/admission/revision/clear/replacement语义、全部retained tests/builds及privacy/clean-room/reference/opt-in/process/diff边界。
- **状态：** `complete`；4.1已勾选，预期权威状态为`20/50 ready`、next 4.2。下一步只读post-mark final-state，不重复test/build/generator/simulator操作。
- **final-state包装错误 1：** 首次调用在进入shell前被外层JavaScript template literal中的Markdown反引号截断并抛出`SyntaxError: Unexpected number`；未创建gate、未执行OpenSpec/xcresult/generator/test/build/simulator或修改工作区。移除命令内反引号后从fresh目录运行。
- **post-mark final-state：** 修正后的fresh `/tmp/LuneX-18-4_1-final-state-r2.BFSidM`只读通过strict `9/9`、apply `20/50 next 4.2`、稳定project hash、精确14文件scope、current task/source/test/docs、全部retained evidence及privacy/clean-room/reference/opt-in/process/diff边界；未重复test/build/generator/simulator操作。下一步post-record与最终diff审计。
- **post-record：** 首轮 `/tmp/LuneX-18-4_1-post-record.mkvGtQ` 因把current-change strict `1/1`误断言为repository strict `9/9`而提前退出；修正后的fresh `/tmp/LuneX-18-4_1-post-record-r2.AmeJ3m`通过`20/50 next 4.2`、repository strict `9/9`、稳定project hash、精确14文件scope、五份权威记录、retained evidence、opt-in/process/reference和diff门，未重复test/build/generator/simulator操作。下一步最终人工diff审计与独立提交推送。
- **最终审计：** production coordinator与actual presenter共享同一个main-actor owner，platform admission关闭shared-latest bypass；platform/session与media/presentation/input replacement顺序、sequence/platform/delivery/decoder/frame/surface fence、scene/display关闭、clear、geometry重交、unbind/rebind、presenter stop及old teardown/application均成立。unknown display仅允许baseline SDR，4.2–4.4未提前完成；未发现新问题，4.1可独立提交推送。

## 2026-08-07 阶段 18 任务 4.2 启动

- **状态：** `in_progress`；4.1已提交推送为`69832a2 Bind tvOS frame presentation`，fetch确认`HEAD == origin/main`且工作树clean，OpenSpec为`20/50 ready`、next 4.2。
- **范围：** 直接核对tvOS 26.4 public SDK并实现可注入、可回滚的actual display/layer/color capability probe；只有public layer dynamic-range path、可用color space与有限current/potential headroom组成完整合同才允许direct EDR，否则保留typed HDR-to-SDR。
- **现状：** 旧`HDRPlatformOutputCapabilityAdapter`把tvOS extended-range surface固定为unavailable，`AppleMetalSurfaceAdapter`的旧`wantsExtendedDynamicRangeContent`/`edrMetadata`路径也排除tvOS；SDK已公开`CALayer.preferredDynamicRange`、`contentsHeadroom`、`toneMapMode`且actual tvOS `UIScreen` headroom可读。
- **边界：** 4.2只完成public capability与surface mutation/rollback基础，不在本项增加scene observer、coordinator/AppModel display revision、actual HDR UI或物理电视声明；这些分别保留给4.3、7.x与8.7。
- **验收计划：** 先编译最小public API probes并锁定enum/availability，再扩展纯值resolver、native layer backend和focused rollback/fallback测试；随后运行related、normal、fixed tvOS、五平台Debug与repository/final-state分层门禁。
- **实现：** 新增`preferredDynamicRangeAndHeadroom`能力与tvOS pure/native capability probe；direct EDR要求output、preferred dynamic range、tone-map control、contents headroom、extended-linear gamut和有限`1 < current <= potential <= 64`全部成立。`HDRSurfaceContract`携带optional content headroom，tvOS transaction按顺序设置/恢复dynamic range、tone map、headroom、pixel format和color space；旧metadata路径保持不变。
- **API/compile：** `/tmp/LuneX-18-4_2-api-probe.swift`对device与正确simulator SDK均warnings-as-errors typecheck；fixed Apple TV direct Debug `/tmp/LuneX-18-4_2-compile-tv.f3NC2P`成功且零结构化诊断，UUID仅作build destination。
- **focused：** 首轮`/tmp/LuneX-18-4_2-focused.lkIQzA`为`53/53`，因审计后新增preferred-headroom mutation failure rollback用例而降为中间证据；fresh `/tmp/LuneX-18-4_2-focused-r2.c7E7yZ`为`54/54`且零结构化诊断。下一步related HDR/presenter/platform matrix。

## 2026-08-07 阶段 18 任务 4.2 更新后续接

- **状态：** `in_progress`；系统更新后确认active goal、OpenSpec `20/50 next 4.2`、`HEAD == origin/main == 69832a2`、Xcode 26.4/Swift 6.3/macOS 27.0、预期十一文件scope及Keychain/live-host opt-in unset；未查询或操作simulator lifecycle。
- **证据失效边界：** 最后一处production headroom normalization发生在此前focused/related/normal/direct/five-platform证据之后，因此这些结果只保留为中间证据，必须从fresh evidence目录重新分层验收。
- **人工审计：** missing headroom继续映射`.headroomUnavailable`，nonfinite/超界/倒置headroom映射`.invalidHeadroom`且stored capabilities归一化为`nil`，`current == 1`映射`.insufficientHeadroom`，有效值保持不变；新增`NaN/+infinity/out-of-range`存储归一化与surface contract非有限值回归。
- **验收错误 1：** 既有normal包装器在测试与结构化结果成功后，最后因只匹配字面量`skipped on`的`grep`未命中而exit 1；这不是测试失败。fresh normal将使用结构化xcresult结果，并以`rg -n -i 'keychain|skipped on|skip'`核对唯一允许的显式Keychain skip。
- **跟踪错误 1：** 首个测试与三份planning组合补丁使用了只存在于`progress.md`的尾部锚点，`apply_patch`原子拒绝且无部分修改；读取各文件真实锚点后拆分完成。
- **下一步：** fresh focused、13-suite related、normal、fixed Apple TV direct和unsigned五平台Debug；全部通过后同步OpenSpec/runtime contract/roadmap，再运行repository pre-gate，之前不得勾选4.2。
- **fresh focused：** `/tmp/LuneX-18-4_2-focused-r3.uUoogT`结构化通过`54/54 passed / 0 skipped / 0 failed / 0 expected failure`，build结构化error/warning/analyzer warning为0；新增nonfinite/out-of-range归一化断言已执行。下一步fresh 13-suite related matrix。
- **fresh related：** `/tmp/LuneX-18-4_2-related-r2.X5RkJV`结构化通过`209/209 passed / 0 skipped / 0 failed / 0 expected failure`，build/source error、warning和analyzer warning均为0。下一步fresh normal suite。
- **fresh normal：** `/tmp/LuneX-18-4_2-normal-r2.q9nMOC`结构化通过`1040 total / 1039 passed / 1 skipped / 0 failed / 0 expected failure`，build/source diagnostics为0；唯一skip精确为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，Keychain/live-host opt-in均unset。下一步fresh fixed Apple TV direct build。
- **fresh direct tvOS：** `/tmp/LuneX-18-4_2-tvos-r2.gAirdH`为unsigned fixed-destination Debug `BUILD SUCCEEDED`，结构化/source diagnostics为0并生成`1 AIR / 1 metallib`；UUID仅作build destination，未查询或操作simulator lifecycle。下一步fresh unsigned五平台Debug matrix。
- **fresh五平台build：** `/tmp/LuneX-18-4_2-builds-r2.9ndfoH`中macOS、fixed iPhone/iPad/Apple TV/Vision Pro全部unsigned Debug `BUILD SUCCEEDED`，每个平台结构化/source error、warning、analyzer warning为0且各有`1 AIR / 1 metallib`；UUID仅作destination，未执行simulator lifecycle。下一步完整diff审计与OpenSpec/runtime/roadmap同步。
- **权威同步：** OpenSpec design/tvOS media spec、阶段18 runtime contract、completion roadmap与三份planning已同步public capability、typed fallback、transaction/rollback、fresh evidence和proof boundary；OpenSpec保持pre-mark `20/50 next 4.2`，当前精确15文件scope。下一步fresh repository pre-gate，通过前不得勾选。
- **repository pre-gate：** fresh `/tmp/LuneX-18-4_2-repository-pre.IRGscf`完整通过fixture self/tree、OpenSpec strict `9/9`、pre-mark `20/50 next 4.2`、四次稳定generator hash、精确15文件scope、generator/project membership、current capability/fallback/transaction/rollback语义、全部retained test/build证据及privacy/clean-room/reference/opt-in/process/diff边界。
- **状态：** `complete`；4.2已勾选，预期权威状态为`21/50 ready`、next 4.3。下一步只读post-mark final-state，不重复test/build/generator/simulator操作。
- **final-state错误 1：** 首次post-mark包装器在进入shell前因外层JavaScript template literal包含Markdown反引号而抛出`SyntaxError: Unexpected number`；没有创建证据或执行OpenSpec/test/build/generator/simulator操作。移除反引号敏感匹配后从fresh目录重跑。
- **post-mark final-state：** 修正后的fresh `/tmp/LuneX-18-4_2-final-state-r2.l4fp0g`只读通过strict `9/9`、`21/50 next 4.3`、稳定project hash、精确16文件scope、current source/task/docs与retained evidence及privacy/clean-room/reference/opt-in/process/diff边界；未重复test/build/generator/simulator操作。下一步post-record和最终diff审计。
- **post-record：** `/tmp/LuneX-18-4_2-post-record.YjRjuV`只读通过`21/50 next 4.3`、strict `9/9`、稳定project hash、16文件scope、五份权威记录、retained evidence及opt-in/process/reference/diff边界。下一步最终diff审计与独立提交推送。
- **final audit错误 1：** 首轮`/tmp/LuneX-18-4_2-final-audit.J9NbmM`通过diff/scope和strict状态后，静态包装器误匹配不存在的`contentHeadroom: normalizedHeadroom`字段而退出；production实际为`currentEDRHeadroom`/`potentialEDRHeadroom`。未运行test/build/generator/simulator，改用真实字段名fresh重跑。
- **最终审计：** 修正后的fresh `/tmp/LuneX-18-4_2-final-audit-r2.8dYwRn`完整通过16文件diff、strict `9/9`与`21/50 next 4.3`、production/regression semantics、no-4.3-scope-creep、proof boundary及reference/opt-in/process门；未发现新问题，4.2进入独立提交推送。

## 2026-08-07 阶段 18 任务 4.3 启动

- **状态：** `in_progress`；系统更新后确认active goal、`HEAD == origin/main == a27b90f`、工作树clean、OpenSpec `21/50 ready`且next为4.3，工具链为Xcode 26.4、Swift 6.3、macOS 27.0。
- **目标：** 从actual tvOS `TVVisionStreamMetalView`绑定的`UIScreen`和`CAMetalLayer`发布有限、可比较、current-generation的display/HDR semantic revision，经platform presentation coordinator串行应用到AppModel render state，并发布有界typed fallback diagnostic。
- **实施顺序：** 先建立纯值observation/event/revision publisher及normalization/dedup/stale/exhaustion测试；再增加main-actor actual surface observer和identity-filtered notification；然后通过`MetalStreamSurface`/`RootView`接入AppModel FIFO；最后连接`renderState.displaySnapshot`、HDR resolver和diagnostic并做分层验收。
- **边界：** 不实现4.4 AVAudioSession/spatial audio，不实现7.x UI/Settings，不操作simulator lifecycle，不触发真实Keychain/live host；unsigned build与注入测试不证明物理Apple TV、电视/compositor/HDMI HDR、signed install、live Sunshine、功耗或性能。
- **编译检查错误 1：** 首次focused命令误用没有test action的`LuneX-macOS` scheme，`xcodebuild`在进入编译前以exit 66退出；没有源码诊断、测试执行、Keychain或simulator操作。改为读取scheme列表并使用仓库测试scheme。
- **编译检查错误 2：** 正确test scheme首次Swift编译发现generic `Screen`被重复捕获进`@Sendable` notification closure；object-filtered observer与observation UUID已经提供identity/stale过滤，移除闭包内重复screen capture后重试。
- **测试编译错误 1：** 新增publisher/observer回归首次编译只发现两处throwing generation helper漏写`try`；production和其余测试源码已编译，补上显式传播后继续，此候选不计最终证据。
- **测试编译错误 2：** coordinator helper加入局部归一化变量后不再支持隐式单表达式返回，编译指出snapshot initializer结果未使用；改为显式`return try`，不涉及production。
- **focused行为错误 1：** 恢复后增量focused已成功编译并执行37项，但publisher fallback与coordinator fallback测试各失败一次。根因是resolver正确保留有效potential headroom时，旧display snapshot合同仍要求`.unavailable`同时清空current/potential，导致合法invalid-current fallback被误判为revision exhaustion或直接抛出`invalidDisplaySnapshot`；修订为current必须为空、仅在output unavailable时potential也必须为空，并补合同回归后重跑。
- **增量focused：** partial-headroom修订后相同两组测试通过`39/39`，该结果只用于推进AppModel测试，不作为最终fresh验收。新增AppModel跨层用例将锁定geometry先于display、direct/fallback实际状态、旧revision/generation/surface拒绝、replacement清理、revision exhaustion与stop复位。
- **审计缺口 1：** AppModel对display application使用`try?`，异常时可能静默保留旧actual display；display revision exhaustion也没有取消pending application或终止current coordinator。修订为current admission/operation guard下清空本地render状态并发送typed `.fail(.actionFailed(.display))`或`.fail(.semanticRevisionExhausted)`，同时保证exhaustion期间任何late coordinator display仍保持closed；新增两条workflow路径验证。
- **审计缺口 2：** `TVVisionDisplaySnapshot`原可携带跨平台或与自身output/headroom/layer字段不一致的tvOS resolution，导致AppModel平台能力与实际快照分叉；现从值对象入口拒绝不一致字段和不满足direct EDR完整条件的手工resolution，并补三类负向合同测试。
- **系统更新后续接：** active长期goal仍在，`HEAD == origin/main == a27b90f`，预期11文件工作树修改完整，OpenSpec仍为`21/50 ready`、next 4.3；Xcode 26.4/Swift 6.3/macOS 27.0与暂停前一致，两个真实opt-in均为unset，`git diff --check`通过。下一步读取全部change context并完成production/test竞态审计，再从全新目录开始最终分层验收；未查询或操作simulator。
- **跟踪错误 1：** 首次续接记录补丁假设三份planning尾部措辞一致，被`apply_patch`原子拒绝且无部分修改；已按各文件真实锚点分别追加。
- **续接审计缺口 3：** surface replacement会先在AppModel清空display，但coordinator应用新scene时仍可能把旧display component按新coordinator revision回流；当前AppModel只校验ownership/sequence，可能在新surface actual observation前错误重开旧HDR/fallback。修复要求将回流display component identity与当前`tvOSDisplayHDRSourceSnapshot`绑定，并补旧component随新scene回流仍保持关闭的workflow测试。
- **续接审计缺口 4：** capability resolver在output unavailable时仍可保留调用方传入的screen headroom，形成与snapshot合同冲突的`.outputUnavailable`并被误升为revision exhaustion。现将output-unavailable capabilities强制归一化为nil current/potential并增加回归，符合“输出本身不可用时禁止任何headroom”的合同。
- **续接审计缺口 5：** 同surface的新display source被接受后，异步coordinator application完成前仍会保留旧render display/capability。现接受新source时立即关闭旧render display并清旧fallback，只有current-source component identity匹配的coordinator回流才能重开；HDR platform capabilities使用同一gate，避免旧component参与解析。
- **4.5保留边界：** 同一actual view跨media reconnect时，platform runtime会清空AppModel geometry admission，而现有geometry owner对不变semantic state不重交；display单独replay也会因缺少current geometry admission被拒绝。该video/input/display共同的coordinator重建与replay属于4.5 shared-generation reconnect协调，4.3不建立display旁路或提前完成4.5。
- **调查命令错误 1：** 审计时尝试读取推测路径`Sources/LuneXPlatform/TVVisionUIKitStreamSurface.swift`得到file not found；实际geometry owner位于`Sources/LuneXRendering/MetalStreamSurface.swift`，随后从真实路径读取，没有修改文件或重复错误命令。
- **fresh focused：** `/tmp/LuneX-18-4_3-focused-final.BN6ZYp/focused.xcresult`结构化通过`190/190 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded/0 warning/0 error/0 analyzer warning`；覆盖两条AppModel display workflow、完整state/coordinator、presenter、HDR resolver/render contract/surface adapter和SessionMediaEnvironment。AppIntents metadata extraction skip仅为工具提示。下一步fresh related matrix。
- **fresh related：** `/tmp/LuneX-18-4_3-related-final.ztmMov/related.xcresult`结构化通过`361/361 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded/0 warning/0 error/0 analyzer warning`；完整AppModel、tvOS focus/controller、共享HDR/Metal与SessionMediaEnvironment均通过。下一步fresh normal suite。
- **fresh normal：** `/tmp/LuneX-18-4_3-normal-final.kN6LiU/normal.xcresult`结构化通过`1047 total / 1046 passed / 1 skipped / 0 failed / 0 expected failure`，build为`succeeded/0 warning/0 error/0 analyzer warning`；唯一skip精确为显式禁用的`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，两个真实opt-in unset。下一步fresh fixed Apple TV direct build。
- **fresh direct tvOS：** `/tmp/LuneX-18-4_3-tvos-final.UlXTWd/tvos.xcresult`为fixed Apple TV UUID unsigned Debug `succeeded/0 warning/0 error/0 analyzer warning`，生成`1 AIR/1 metallib`；UUID仅作build destination，未查询、启动或操作simulator。下一步fresh unsigned五平台Debug。

## 2026-08-07 阶段 18 任务 4.4 系统更新后续接

- **状态：** `in_progress`；active长期goal与OpenSpec `22/50 ready`、next 4.4均已恢复，`HEAD == origin/main == 045ae3d`，工作树为预期14文件未提交scope；未查询或操作Simulator，未访问真实Keychain或live host。
- **environment专项：** 系统更新前会话`35078`已正常退出；保留`/tmp/LuneX-18-4_4-environment-r1.fhwxMz/environment.xcresult`结构化通过`3/3 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`。覆盖activate前回放、replacement回放、interruption/media lost/reset恢复、旧graph拒绝、invalid runtime失败、audio action failure传播与stop清理。
- **下一步：** 审计`SessionMediaEnvironment` current audio action failure是否存在裸`try?`吞错，补AppModel current-generation audioRoute application/replacement/failure/stop测试和coordinator独立optional/terminal clearing合同；production/test稳定后从fresh证据目录执行focused、related、normal、fixed Apple TV与unsigned五平台Debug门禁。
- **AppModel命令错误 1：** 首个定向候选`/tmp/LuneX-18-4_4-appmodel-r1.TwxspW`误将`analyze test`合并到`LuneXCoreTests` scheme，Xcode在编译前以destination unavailable、exit 70退出；未执行测试或访问Keychain/Simulator。后续复用已成功4.4命令的单一`test` action、`CODE_SIGNING_ALLOWED=NO`与相同macOS destination。
- **AppModel专项：** fresh `/tmp/LuneX-18-4_4-appmodel-r2.FpHLzs/appmodel.xcresult`结构化通过`2/2 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`；current与replacement coordinator状态均携带完整scene/input/display/audio presentation并进入AppModel公开state/snapshot，reconnect、remote termination与local stop均清空。下一步运行包含新增coordinator terminal断言的最终focused。
- **fresh focused：** `/tmp/LuneX-18-4_4-focused-final.RfLgmT/focused.xcresult`结构化通过`248/248 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`；覆盖state/coordinator/environment/AppModel/diagnostics及canonical audio processor、route、recovery、integration、pipeline。下一步fresh related regression。
- **fresh related：** `/tmp/LuneX-18-4_4-related-final.dg14Fj/related.xcresult`结构化通过`332/332 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`；tvOS geometry/focus/controller/remote input、Metal/HDR surface/presenter与共享audio能力均未回归。下一步fresh normal suite。
- **fresh normal：** `/tmp/LuneX-18-4_4-normal-final.NH3JbN/normal.xcresult`结构化通过`1054 total / 1053 passed / 1 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`；唯一skip精确为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，真实Keychain/live-host opt-in均unset。下一步fixed Apple TV direct unsigned build。
- **fresh direct tvOS：** `/tmp/LuneX-18-4_4-tvos-final.3bnJ39/tvos.xcresult`为fixed Apple TV UUID unsigned Debug `succeeded / 0 warning / 0 error / 0 analyzer warning`，生成`1 AIR / 1 metallib`；固定UUID仅作build destination，未查询或操作Simulator lifecycle。下一步fresh unsigned五平台Debug。
- **fresh五平台build：** `/tmp/LuneX-18-4_4-builds-final.OmDAeS`中macOS、fixed iPhone/iPad/Apple TV/Vision Pro全部unsigned Debug `succeeded / 0 warning / 0 error / 0 analyzer warning`，各有`1 AIR / 1 metallib`；固定UUID只作destination，未执行Simulator lifecycle。下一步production/test diff审计与OpenSpec/runtime/roadmap同步，4.4仍未勾选。
- **文档补丁错误 1：** 首个design/spec/runtime/roadmap组合补丁因runtime contract新增段落一行缺少patch前缀而被`apply_patch`原子拒绝，无部分写入；随后按文件与稳定章节锚点拆分应用，不重复失败形式。
- **权威同步：** OpenSpec design/tvOS media spec、阶段18 runtime contract、completion roadmap与三份planning已同步actual route/capability、canonical graph、publisher、replacement replay、interruption/loss/reset/recovery、AppModel/terminal clearing、fresh evidence和proof boundary；当前保持pre-mark `22/50 next 4.4`。下一步fresh repository pre-gate，通过前不得勾选。
- **repository gate错误 1：** 系统更新后首轮`/tmp/LuneX-18-4_4-repository-pre.vZGSsL`的fixture self/tree与OpenSpec strict实际通过`9/9`，但包装器沿用错误JSON路径`.summary.total`，当前CLI结构为`.summary.totals.items/passed/failed`，因此在apply/generator前退出；该轮不计验收。首次记录补丁又错误假设三份planning共享旧锚点而被原子拒绝、无部分写入；现按真实尾部分别记录并从fresh evidence目录改用当前schema。
- **repository gate错误 2：** corrected r2 `/tmp/LuneX-18-4_4-repository-pre-r2.VnUq13`已通过到normal结构化结果`1054/1053/1/0`，但包装器用纯文本出现次数验证唯一skip；同一test在`name/nodeIdentifier/nodeIdentifierURL`中合法出现3次，因而错误退出。改为用`jq`按`nodeType == "Test Case" && result == "Skipped"`精确统计一个节点及其名称，再从fresh目录完整重跑。
- **repository pre-gate：** fresh r3 `/tmp/LuneX-18-4_4-repository-pre-r3.FrvzgU`完整通过fixture self/tree、OpenSpec strict `9/9`与pre-mark `22/50 next 4.4`、三次稳定generator SHA-256 `ef2e3e615f1dbd84b76bfe4c8681fab7d44291176f06324acd757fa1c1008353`、精确18文件scope、membership、current-generation/replay/failure/terminal语义、retained focused/related/normal/direct/five-platform证据及privacy/clean-room/reference/dependency/opt-in/process/diff边界。4.4已勾选，预期`23/50 next 4.5`；阶段18与长期goal保持`in_progress`。
- **post-mark final-state：** `/tmp/LuneX-18-4_4-final-state.gObCd6`只读通过strict `9/9`、`23/50 next 4.5`、4.4 done、稳定project SHA-256、精确19文件scope、五份权威记录、retained evidence及opt-in/process/reference/diff边界；未重复test/build/generator/Simulator。4.4等待post-record、最终diff审计与独立提交推送。
- **post-record与最终审计：** `/tmp/LuneX-18-4_4-post-record.yYoKIN`确认`23/50 next 4.5`、五份authority pre/final记录、19文件scope、稳定project hash和proof boundaries；`/tmp/LuneX-18-4_4-final-audit.Q802vi`确认production数据流、无第二observer/graph、无新增裸`try?`、terminal contract、测试矩阵、文档边界和diff均通过。4.4可独立提交推送，阶段18/长期goal保持active。
- **提交编排错误 1：** 首次精确staging工具调用因JavaScript参数字符串引号拼写错误在执行前解析失败；没有运行`git add`或改变index。修正工具参数后重新执行精确19文件staging。

## 2026-08-07 阶段 18 任务 4.5 启动

- **状态：** `in_progress`；4.4已提交推送为`89316e9 Connect tvOS audio route runtime`，fetch确认`HEAD == origin/main`且工作树clean，OpenSpec为`23/50 ready`、next 4.5。
- **首个缺口：** same `MTKView`跨media reconnect时，AppModel正确清除旧ownership，但geometry owner与tvOS display observer因实际语义不变返回unchanged且不向新generation重放current snapshot，导致scene/input/display无法重建，video/audio完整presentation也无法恢复。
- **实现边界：** 在既有owner/observer增加不推进revision的current-value replay，view按geometry后display顺序重放；AppModel继续执行current session/media/ownership admission。不得创建第二surface/display observer，不改变visionOS 5.x/6.x功能，不把replay单项提前表述为完整4.5完成。
- **恢复与最小验证：** 系统更新后active goal与OpenSpec仍为`23/50 ready, next 4.5`。fresh macOS证据`/tmp/LuneX-18-4_5-minimal.Jo7NGA`通过geometry/display replay两个定向用例；4.5保持pre-mark，下一步补同surface reconnect与shared terminal teardown跨层合同。
- **记录错误 1：** 首次三文件记录补丁误假设三份planning共享同一尾部锚点，被`apply_patch`原子拒绝且无部分写入；改为读取真实尾部并按文件稳定锚点追加。
- **remote teardown测试错误 1：** fresh候选`/tmp/LuneX-18-4_5-remote.eNXp51`因两个`await`被放入`XCTUnwrap`同步autoclosure而在测试编译期失败，未运行测试且不计验收；改为先await局部optional再unwrap，并从fresh目录重跑。
- **跨层验证：** `/tmp/LuneX-18-4_5-reconnect.fzySX5`通过同surface/current geometry+display在media generation 2的`activate → scene → input → display`重建、旧代拒绝与remote clearing；`/tmp/LuneX-18-4_5-remote-r2.MSafes`通过remote termination与environment stop共享一次terminal/resource teardown。下一步最终diff审计与fresh focused集合。
- **fresh focused/related：** `/tmp/LuneX-18-4_5-focused-final.EhLafe`结构化`248/248`，`/tmp/LuneX-18-4_5-related-final.C3tjgy`结构化`474/474`；两者均`0 skipped/failed/expected failure`且build四类diagnostics为0。下一步fresh normal suite。
- **fresh normal：** `/tmp/LuneX-18-4_5-normal-final.1mF6gc`结构化`1055 total / 1054 passed / 1 skipped / 0 failed`且build四类diagnostics为0；唯一skip精确为真实Keychain opt-in用例。证据读取曾因并行`xcresulttool`临时数据库冲突及一次含`rm -f`的命令被安全规则拒绝，均无仓库/结果包副作用；串行`tests-r2.json`已确认唯一skip。下一步fixed Apple TV build。
- **fresh direct tvOS：** `/tmp/LuneX-18-4_5-tvos-final.UNpi51`对固定Apple TV UUID的unsigned Debug构建结构化`succeeded / 0 warning / 0 error / 0 analyzer warning`，生成`1 AIR / 1 metallib`；UUID仅作destination，未操作Simulator。下一步fresh五平台Debug矩阵。
- **fresh五平台build：** `/tmp/LuneX-18-4_5-builds-final.13Nwur`中macOS、fixed iPhone/iPad/Apple TV/Vision Pro全部unsigned Debug `succeeded / 0 warning / 0 error / 0 analyzer warning`，各有`1 AIR / 1 metallib`；没有启动第二套矩阵，固定UUID仅作destination，未操作Simulator lifecycle。
- **文档补丁错误 1：** 首个OpenSpec/docs/planning组合补丁因`findings.md`尾部锚点与实际文本不一致而被`apply_patch`原子拒绝，无部分修改；随后按文件与稳定章节锚点拆分应用，不重复失败形式。
- **权威同步：** 已同步OpenSpec design/tvOS media spec、阶段18 runtime contract、completion roadmap与三份planning，记录current-value replay不推进revision、geometry后display、AppModel replacement generation admission、latest audio单一publisher、shared terminal/resource teardown及offline/unsigned proof boundary。OpenSpec保持pre-mark `23/50 next 4.5`；fresh repository pre-gate通过前不得勾选。
- **repository pre-gate：** fresh `/tmp/LuneX-18-4_5-repository-pre.4s9qBy`完整通过fixture self/tree、OpenSpec strict `9/9`与pre-mark `23/50 next 4.5`、三次稳定generator SHA-256 `ef2e3e615f1dbd84b76bfe4c8681fab7d44291176f06324acd757fa1c1008353`、精确13文件scope、membership、current-value replay/order/generation/shared teardown、privacy/clean-room/reference/dependency/opt-in/process/diff，以及retained `248/248` focused、`474/474` related、`1055/1054/1/0` normal、direct tvOS与五平台build证据。4.5已勾选，预期`24/50 next 4.6`。
- **勾选后状态：** OpenSpec strict保持`9/9`，apply精确为`24/50 ready`、next 4.6且4.5 done；权威runtime/roadmap/planning已更新为final checkpoint。下一步只读post-mark final-state、post-record与最终production/test/docs diff审计，不重复test/build/generator或Simulator操作。
- **post-mark final-state：** `/tmp/LuneX-18-4_5-final-state.5ZgeJt`只读通过strict `9/9`、`24/50 next 4.6`、4.5 done、稳定project SHA-256、精确14文件scope、最终authority records、全部retained evidence及privacy/reference/dependency/opt-in/process/diff边界。下一步post-record与最终diff审计。
- **post-record与最终审计：** `/tmp/LuneX-18-4_5-post-record.5B9rw1`确认`24/50 next 4.6`、pre/final authority records、稳定project hash、14文件scope与全部边界；`/tmp/LuneX-18-4_5-final-audit.ASK927`确认2个production/4个test文件、replay identity/revision/order、replacement terminal/resource、无第二runtime/裸`try?`/隐私sink、retained evidence及proof boundary。4.5可独立提交推送，阶段18/长期goal保持active。

## 2026-08-07 阶段 18 任务 4.6 启动

- **状态：** `in_progress`；4.5已提交推送为`8295ae7 Coordinate tvOS generation teardown`，fetch确认`HEAD == origin/main`且工作树clean，OpenSpec为`24/50 ready`、next 4.6。
- **范围：** 盘点并补齐SDR/HDR fallback、geometry/display change、stale frame、route/interruption/reset、graph replacement、AppModel application与clean teardown的tvOS媒体组合回归；优先复用既有production seam与测试helper，不提前实现visionOS 5.x/6.x或新增第二runtime。
- **首轮定向错误 1：** `/tmp/LuneX-18-4_6-matrix.AoREWO`在测试编译期因把异步`receiveVideo`放入`XCTAssertEqual`同步autoclosure而失败，生产源码未失败、测试未执行且不计验收；改为先await局部结果再同步断言，并从fresh目录重跑。
- **综合矩阵专项：** 修正版 `/tmp/LuneX-18-4_6-matrix-r2.v9KJoh`结构化通过`1/1 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`。现补AppModel current/reconnect/replacement/termination对public render HDR与platform audio route/head-tracked状态的直接断言，再运行两项fresh定向验证。
- **系统更新后恢复与cross-layer专项：** active长期goal保持`active`，OpenSpec仍为`24/50 ready`、next 4.6，`HEAD == origin/main == 8295ae7`且仅有预期两份test与三份planning改动。`/tmp/LuneX-18-4_6-cross-layer.NGWR17`结构化通过`2/2`且build四类diagnostics为0；current direct EDR headroom、head-tracked route、replacement graph generation 2/fixed-spatial route及reconnect/termination清空均从AppModel公开状态可见。
- **fresh focused：** 恢复并只收口系统更新前已启动的唯一focused会话，`/tmp/LuneX-18-4_6-focused-final.snkyaA/focused.xcresult`结构化通过`249/249 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`。未启动第二套focused，未访问真实Keychain/live host或操作Simulator；下一步fresh related regression。
- **related包装错误 1：** 首个fresh候选`/tmp/LuneX-18-4_6-related-final.BLZFvk`从4.5日志提取`-only-testing`参数时保留了字面双引号，Xcode在编译/测试前以unknown build action、exit 65退出；该候选不计验收。改为逐行提取并去除引号，从全新目录重跑。
- **fresh related：** 修正包装后的`/tmp/LuneX-18-4_6-related-final-r2.gN1qLv/related.xcresult`结构化通过`474/474 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`。新增综合用例属于focused coordinator class，因此40个related selector计数与4.5相同；下一步fresh normal suite。
- **fresh normal：** `/tmp/LuneX-18-4_6-normal-final.FweI69/normal.xcresult`结构化通过`1056 total / 1055 passed / 1 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`；test tree唯一skip精确为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`。两个真实opt-in均unset，下一步fixed Apple TV unsigned Debug build。
- **fresh direct tvOS：** `/tmp/LuneX-18-4_6-tvos-final.bVvyiw/tvos.xcresult`对固定Apple TV UUID的unsigned Debug构建结构化为`succeeded / 0 warning / 0 error / 0 analyzer warning`，生成`1 AIR / 1 metallib`；UUID仅作为build destination，未查询、启动或操作Simulator。下一步fresh unsigned五平台Debug矩阵。
- **fresh五平台build：** `/tmp/LuneX-18-4_6-builds-final.njC11Q`中macOS、fixed iPhone/iPad/Apple TV/Vision Pro全部unsigned Debug `succeeded / 0 warning / 0 error / 0 analyzer warning`，各有`1 AIR / 1 metallib`；固定UUID仅作destination，未执行Simulator lifecycle。下一步最终test diff审计与权威文档同步，4.6仍保持pre-mark。
- **diff审计与权威同步：** 两份test-only diff逐行审计未发现新问题；综合用例复用现有coordinator API，AppModel断言只读公开actual state，helper旧默认值保持一致。已同步OpenSpec design/spec、阶段18runtime contract、roadmap与三份planning，并明确offline/unsigned证明边界；当前仍为`24/50 next 4.6`，fresh repository pre-gate通过前不得勾选。
- **repository gate包装错误 1：** 首次工具调用因长shell命令中的未转义引号导致外层JavaScript在shell启动前`SyntaxError`；未创建gate目录、运行generator或改变工作区。改用`String.raw`模板并移除模板反引号内容，从fresh目录完整重跑。
- **repository gate包装错误 2：** raw模板内的shell `${VAR:-}`仍被外层JavaScript识别为模板插值并在shell前报`Missing } in template expression`；同样无副作用。环境变量检查改用`printenv`，完全移除`${...}`后再执行。
- **repository pre-gate与勾选：** fresh `/tmp/LuneX-18-4_6-repository-pre.jpqOgA`完整通过fixtures、strict `9/9`、pre-mark `24/50 next 4.6`、四次稳定generator SHA-256 `ef2e3e615f1dbd84b76bfe4c8681fab7d44291176f06324acd757fa1c1008353`、精确9文件test/authority scope、组合语义、全部retained evidence及privacy/clean-room/reference/dependency/opt-in/process/diff边界。4.6已勾选，预期OpenSpec为`25/50 ready`、next 5.1；阶段18与长期goal保持`in_progress/active`。
- **post-mark包装错误 1：** 暂停前首次final-state工具调用在shell启动前因外层JavaScript raw template仍含Markdown反引号而抛出`SyntaxError: Unexpected number`；没有创建final-state目录、运行任何门禁、修改仓库、访问Keychain或操作Simulator。后续命令完全移除模板反引号与`${...}`，从fresh目录只读重跑。
- **post-mark预检/门禁错误 2：** 两个辅助`jq`先后把xcresult summary根对象误按`.result.metrics`和数组路径读取，随后首个formal目录`/tmp/LuneX-18-4_6-final-state.lmIpMr`在OpenSpec、scope、hash和权威状态均通过后，因静态断言使用不存在的spec标题`Current decoded frame survives geometry revision`而退出；实际场景标题为`Connected media regression sequence completes`。三次均只读，无test/build/generator/Keychain/Simulator副作用；改用真实root summary字段和场景标题从fresh目录完整重跑。
- **post-mark final-state：** 修正后的fresh `/tmp/LuneX-18-4_6-final-state-r2.0Oe6dd`只读通过strict `9/9`、`25/50 next 5.1`、4.6 done、稳定project SHA-256、精确10文件scope、production/project graph零diff、全部retained test/build证据、唯一Keychain skip及privacy/reference/dependency/opt-in/process/diff边界。未重复test、build、generator或Simulator操作；下一步post-record与最终test/docs diff审计。
- **post-record与最终审计：** `/tmp/LuneX-18-4_6-post-record.4dFTZB`和`/tmp/LuneX-18-4_6-final-audit.mNUBR2`确认相同10文件scope、两份test/八份authority、helper默认兼容、组合序列与公开actual-state断言、无异步XCTest autoclosure、无production/project graph变化、无删除合同及全部proof boundary。4.6为`complete`，可独立提交推送；阶段18和长期goal继续`in_progress/active`。

## 2026-08-07 阶段 18 任务 5.1 启动

- **状态：** `in_progress`；4.6已提交推送为`00b2cf5 Verify tvOS media regression matrix`，fetch确认`HEAD == origin/main`且工作树clean，OpenSpec为`25/50 ready`、next 5.1。
- **范围：** 复用既有`TVVisionStreamMetalView`、surface generation owner与geometry binding owner，补actual visionOS window visible/hidden/key/resign和同scene window replacement observation，以current key window形成focus eligibility；不提前实现5.2输入映射、5.3输入adapter或6.x visionOS media/HDR/audio。
- **调查错误 1：** 首轮只读命令误猜platform state位于`Sources/LuneXCore/TVVisionPlatformPresentationState.swift`而得到file not found；真实路径为`Sources/LuneXPlatform/TVVisionPlatformPresentationState.swift`。随后从真实模块读取；另一个跨父目录`find`运行过慢后被主动中止，改用`rg --files -g AGENTS.md`确认本仓库无适用AGENTS文件。两项均无工作区或设备副作用。
- **第一版实现：** 新增可注入`TVVisionUIKitWindowObservation`，以surface generation、window/scene弱引用和observation UUID管理八类公开UIWindow/UIScene notification；actual view在每次callback前按当前window identity attach/detach，同scene replacement会换token，旧任务被ID拒绝。visionOS focus eligibility改为visible+interactive+current key window，tvOS仍用既有focus engine。新增generic replacement/late/invalidate测试与AppModel visionOS activate/scene/replacement/stale/detach测试；`git diff --check`通过，下一步最小编译/行为验证。
- **最小编译错误 1：** 首轮fresh `/tmp/LuneX-18-5_1-minimal.tqUVIG`在测试编译期因observer initializer只通过closure和后续attach提供类型、Swift未从该语境推断`Window/WindowScene`而失败，枚举成员错误均为连锁诊断；production未报错、测试未执行。给测试变量显式指定两个fake class generic参数后从fresh目录重跑。
- **最小验证：** 修正版 `/tmp/LuneX-18-5_1-minimal-r2.rTbf7R`结构化`2/2 passed / 0 skipped / 0 failed`且build diagnostics为0；fixed Vision Pro unsigned Debug `/tmp/LuneX-18-5_1-visionos-compile.8NsiO6`结构化`succeeded / 0 warning / 0 error / 0 analyzer warning`并生成`1 AIR/1 metallib`。UUID仅作build destination，未操作Simulator；下一步fresh focused affected-class regression。
- **扩大回归：** fresh focused `/tmp/LuneX-18-5_1-focused.2cR6CT/focused.xcresult`通过`219/219`，fresh related `/tmp/LuneX-18-5_1-related.52fA7X/related.xcresult`通过`121/121`；两者均`0 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`。覆盖surface/presentation/AppModel/media环境、visionOS window contract、tvOS remote/focus/controller、Metal/HDR、input/lifecycle/mobile边界。
- **实现审计：** observer只把实际window/scene通知映射到既有surface callback；geometry binding owner继续独占drawable application与semantic revision，tvOS仍以`canBecomeFocused`判定，visionOS仅用visible+interactive+current key window。NotificationCenter closure弱持有observer，token replacement与observation UUID共同拒绝旧window/scene已排队事件；未发现retain cycle、第二owner或5.2/5.3/6.x越界。
- **下一步：** fresh完整normal suite，显式移除真实Keychain/live-host opt-in并串行确认唯一允许skip；随后fixed Apple TV/Vision Pro direct及五平台unsigned Debug、权威文档、repository pre-gate、勾选和独立提交推送。
- **normal suite：** fresh `/tmp/LuneX-18-5_1-normal.CJi9Ut/normal.xcresult`结构化通过`1058 total / 1057 passed / 1 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`；test tree精确确认唯一skip为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，两个真实opt-in均unset，未访问Keychain或Simulator。
- **build矩阵：** fixed Apple TV direct `/tmp/LuneX-18-5_1-tvos.r5KL4H`与既有fixed Vision Pro direct `/tmp/LuneX-18-5_1-visionos-compile.8NsiO6`均unsigned Debug成功、四类diagnostics为0且有`1 AIR/1 metallib`。fresh五平台 `/tmp/LuneX-18-5_1-builds.K3hUMY`中macOS、fixed iPhone/iPad/Apple TV/Vision Pro全部同样通过；固定UUID仅作destination，未操作Simulator lifecycle。
- **权威同步：** 已同步OpenSpec design/visionOS window-input spec、阶段18runtime contract、completion roadmap和三份planning，记录actual window identity、八类notification、replacement/late-event barrier、key-window focus、single geometry writer、完整fresh evidence与physical/live proof boundary；5.1仍保持pre-mark `25/50 next 5.1`。
- **下一步：** fresh repository pre-gate通过后才勾选5.1；随后只读post-mark final-state/post-record、最终diff审计、精确stage、独立提交并push。
- **门禁准备错误 1：** 为确认generator参数误调用`ruby Tools/generate_xcodeproj.rb --help`；该脚本没有help分支而实际执行了一次生成。`LuneX.xcodeproj/project.pbxproj`未进入工作树diff，未改变source/test/docs或设备状态；正式门禁将从fresh目录重新验证生成前后及连续生成hash，不把本次调用计入验收。
- **repository pre-gate：** fresh `/tmp/LuneX-18-5_1-repository-pre.v1iwKK`完整通过fixture self/tree、OpenSpec strict `9/9`、pre-mark `25/50 next 5.1`、生成前后及连续三次稳定project SHA-256 `ef2e3e615f1dbd84b76bfe4c8681fab7d44291176f06324acd757fa1c1008353`、精确10文件scope、membership、observer/replacement/focus/single-writer静态语义、全部retained test/build、唯一Keychain skip及privacy/clean-room/reference/dependency/opt-in/process/diff边界。
- **状态：** 5.1已勾选为`complete`；预期权威进度`26/50 ready`、next 5.2。下一步只读post-mark final-state，不重复test/build/generator或Simulator操作。
- **post-mark包装错误 1：** 首个只读final-state命令在shell启动前因JavaScript raw template内包含Markdown反引号而报`SyntaxError: Unexpected identifier 'complete'`；未创建证据目录、运行OpenSpec/测试/构建/generator、修改仓库或操作设备。移除命令字符串中的反引号匹配后从fresh目录重跑。
- **post-mark final-state：** 修正版fresh `/tmp/LuneX-18-5_1-final-state.BQG3yQ`只读通过strict `9/9`、OpenSpec `26/50 ready`、5.1 done、next 5.2、稳定project SHA-256、精确11文件scope、observer/focus/owner边界、全部retained evidence、唯一Keychain skip及opt-in/process/reference/dependency/diff检查；未重复test/build/generator或Simulator。
- **下一步：** 运行只读post-record与最终production/test/docs diff审计；通过后精确stage 11文件，以`Observe visionOS window surface state`独立提交并push，然后进入5.2。
- **post-record静态断言错误 1：** 首轮 `/tmp/LuneX-18-5_1-post-record.GmR0z6`在OpenSpec `26/50 next 5.2`、11文件scope与authority计数通过后，把`final class TVVisionUIKitWindowObservation`前缀同时匹配observer本体和预期token manager，误期望计数1而退出；不是第二runtime。收紧为带泛型声明的精确模式后从fresh目录完整重跑。
- **post-record静态断言错误 2：** 第二轮 `/tmp/LuneX-18-5_1-post-record-r2.Edevk9`同样在前置状态通过后退出，因为`awk`筛选新增行时保留行首`+`，精确正则却没有该前缀，导致合法observer/token声明计数为0。只读诊断确认带`+`的两个精确声明各恰好1处；修正前缀后fresh重跑。
- **post-record与最终审计：** 修正后的 `/tmp/LuneX-18-5_1-post-record-r3.jAEfZ5`和 `/tmp/LuneX-18-5_1-final-audit.U5fWgQ`完整通过：OpenSpec `26/50 next 5.2`、11文件scope、1 production/2 test/8 authority、generation/weak identity/token replacement/observation UUID/platform focus/single geometry writer、无异步XCTest autoclosure、无越界input/media runtime、无删除合同及全部proof boundary。未发现阻止提交的问题。
- **提交状态：** 5.1为`complete`，准备精确stage 11文件、以`Observe visionOS window surface state`独立提交并push；长期阶段18/goal继续`in_progress/active`，下一任务5.2。

## 2026-08-07 阶段 18 任务 5.2 启动

- **状态：** `in_progress`；5.1已提交推送为`ea9d9fd Observe visionOS window surface state`，fetch确认`HEAD == origin/main == ea9d9fd2ad6ae8f5d0f32783f99a21127b7609ee`且工作树clean。OpenSpec为`26/50 ready`、next 5.2。
- **复用审计：** 2.3已有唯一`TVVisionUIKitStreamGeometryBindingOwner`，从actual view bounds/scale生成drawable、fit/fill `StreamCoordinateSnapshot`与absolute input mapping并共享同一semantic revision；`MobileStreamSurfaceCoordinator`应用exact snapshot，closed/invalid路径清零drawable、render coordinate和mapping。5.1使该owner由actual visionOS window notification/geometry驱动。
- **范围决定：** 不复制第二geometry/input mapper或提前安装5.3 keyboard/pointer/controller adapter；新增一条visionOS综合回归，把resize、fit→fill、presenter exact coordinate、absolute mapping revision与detach/invalid suppression串成同一场景，证明已有生产路径满足5.2。
- **验收：** 先fresh最小/affected回归，再normal、fixed Vision Pro direct与五平台unsigned Debug、OpenSpec/docs/repository门；真实Keychain/live-host opt-in继续unset，不查询或操作Simulator lifecycle。
- **测试草案错误 1：** 首轮静态检查发现综合测试把既有coordinator outcome误写为不存在的`TVVisionSurfaceGeometryApplicationOutcome`；真实类型为`TVVisionStreamGeometryApplicationOutcome`。production未改、测试未运行，已按现有API修正后再启动fresh最小验证。
- **最小测试错误 1：** `/tmp/LuneX-18-5_2-minimal.u2mOoj`完成编译并执行唯一用例，失败两处：草案未按actual `updateUIView`顺序先把`renderState.transform.mode`更新为`.fill`，coordinator因此正确清除不一致fill snapshot；另一个是`240.00000000000006`与`240`的exact浮点比较。production无失败；测试补实际顺序并用bounded accuracy后fresh重跑。
- **最小测试错误 2：** `/tmp/LuneX-18-5_2-minimal-r2.WAcxmT`在测试编译期失败：补丁锚点命中了较早既有dedup测试的相同`updateRenderInputs(.fill)`片段，把`renderState`更新插错作用域；新测试未执行。移除误插行并在新测试fit断言后的精确锚点加入actual顺序，再用fresh bundle重跑。
- **最小验证：** 修正后的fresh `/tmp/LuneX-18-5_2-minimal-r3.luBq4W`结构化通过`1/1 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`。综合用例覆盖fit/fill exact render snapshot、同revision absolute mapping、fill remote coordinate变化、detach与invalid geometry同时清理drawable/render/input。
- **下一步：** fresh完整`StreamMetalPresenterTests`与vision/input相关类回归，再运行normal与平台build矩阵；继续保持真实opt-in unset且不操作Simulator lifecycle。
- **affected回归：** fresh presenter `/tmp/LuneX-18-5_2-presenter.7h2rAT`通过`71/71`，跨层focused `/tmp/LuneX-18-5_2-focused.wM0NK4`通过`220/220`，related `/tmp/LuneX-18-5_2-related.slZmgu`通过`121/121`；三者均`0 skipped / 0 failed / 0 expected failure`且build四类diagnostics为0。
- **下一步：** fresh完整normal suite并串行确认唯一真实Keychain skip；随后fixed Vision Pro direct和五平台unsigned Debug。测试继续显式移除两个真实opt-in且不操作Simulator lifecycle。
- **normal suite：** fresh `/tmp/LuneX-18-5_2-normal.TjccHx`结构化通过`1059 total / 1058 passed / 1 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`；test tree精确确认唯一skip为真实Keychain opt-in用例。
- **下一步：** fixed Vision Pro direct与五平台unsigned Debug，固定UUID只作build destination，不执行Simulator inventory/lifecycle。
- **build矩阵：** fixed Vision Pro direct `/tmp/LuneX-18-5_2-visionos.ags3s2`与fresh五平台unsigned Debug `/tmp/LuneX-18-5_2-builds.gqJzlP`全部`succeeded / 0 warning / 0 error / 0 analyzer warning`且各生成`1 AIR/1 metallib`；固定iPhone/iPad/Apple TV/Vision Pro UUID只作destination，未查询或操作Simulator lifecycle。
- **续接与权威同步错误 1：** 系统更新后planning catch-up确认23条未同步上下文；Git/OpenSpec/goal与续接摘要一致。首个OpenSpec/docs/planning组合补丁因runtime contract章节锚点不精确被原子拒绝，无部分修改。续接后的第二个runtime+roadmap补丁又因误把同一句中的`Task 5.1 is ready for`当作独立行而被原子拒绝，roadmap同样未部分写入；随后改用稳定`## Fixed simulator inventory`标题并拆分应用。
- **权威同步：** 已同步OpenSpec design、visionOS window-input spec、阶段18runtime contract、completion roadmap与三份planning，记录复用2.3 single owner、actual SwiftUI source/mode先行顺序、render/mapping同revision、detach/invalid共同清理、5.3 adapter边界、全部fresh证据与physical/live proof boundary。5.2仍保持pre-mark `26/50 next 5.2`。
- **下一步：** 运行fresh repository pre-gate；通过后才勾选5.2并推进到`27/50 next 5.3`，再做只读post-mark/post-record与最终diff审计、精确提交推送。
- **repository pre-gate错误 1：** 首轮fresh `/tmp/LuneX-18-5_2-repository-pre.oL1RlR`已通过fixture、strict/apply、三次稳定generator、精确8文件scope与前置静态检查，但门禁把测试真实变量`fitInput/fit`、`fillInput/fill`误写为摘要示意名`fitMapping/fitRenderCoordinates`而退出；实现与证据无失败，project hash不变，未重跑test/build或操作Keychain/Simulator。下一轮改用真实断言并输出step marker。
- **repository pre-gate：** 修正后的fresh `/tmp/LuneX-18-5_2-repository-pre-r2.Jwvbum`完整通过fixture self/tree、OpenSpec strict `9/9`、pre-mark `26/50 next 5.2`、连续三次稳定project SHA-256、精确8文件scope、零production/reference/dependency diff、test membership、fit/fill shared revision与detach/invalid共同关闭语义、全部retained test/build/Metal、唯一Keychain skip及disabled opt-in/no-process/diff边界。
- **状态：** 5.2已具备独立完成证据，现勾选为`complete`；预期OpenSpec为`27/50 ready`、next 5.3。下一步只读post-mark final-state，不重复test/build/generator/Keychain/Simulator。
- **post-mark final-state错误 1：** 首轮只读 `/tmp/LuneX-18-5_2-final-state.AKfJyU`已通过strict、`27/50 next 5.3`、task状态、project hash、9文件scope、零production diff与retained evidence后，因runtime合同将`Task 5.2`和`is ready to mark complete`换行而使单行`rg`断言退出；无test/build/generator/Keychain/Simulator副作用。改用稳定短语并增加step marker重跑。
- **post-mark final-state：** 修正后的fresh `/tmp/LuneX-18-5_2-final-state-r2.0VX1j5`只读完整通过strict `9/9`、OpenSpec `27/50 ready`、5.2 done、next 5.3、稳定project SHA-256、精确9文件scope、零production/reference/dependency diff、全部retained test/build、唯一Keychain skip及disabled opt-in/no-process/diff边界；未重复test/build/generator/Keychain/Simulator。
- **下一步：** 只读post-record与最终test/docs diff审计；通过后精确stage 9文件，以`Verify visionOS geometry mapping`独立提交并push，然后进入5.3。
- **post-record错误 1：** 首轮 `/tmp/LuneX-18-5_2-post-record.0BJeCj`通过OpenSpec与精确9文件/1 test/8 authority/0 production计数后，包装器把tasks checkbox的预期`1 add / 1 delete`替换也纳入“所有文件零删除”而退出；真实numstat显示其余8文件全部纯新增。只读错误无行为副作用，下一轮仅允许tasks这一行替换并增加step marker。
- **post-record与最终审计：** 修正后的 `/tmp/LuneX-18-5_2-post-record-r2.d3bpX7`和 `/tmp/LuneX-18-5_2-final-audit.YC6Bfa`完整通过：9文件scope为1 test/8 authority/0 production，actual render-mode-before-geometry、fit/fill shared revision、detach/invalid共同关闭、tasks唯一checkbox替换、无async XCTest autoclosure/`try?`、无第二mapper/project/dependency/reference变化及全部proof boundary。未发现阻止提交的问题。
- **提交状态：** 5.2为`complete`，准备精确stage 9文件、以`Verify visionOS geometry mapping`独立提交并push；阶段18与长期goal继续`in_progress/active`，下一任务5.3。

## 2026-08-07 阶段 18 任务 5.3 启动

- **状态：** `in_progress`；5.2已提交推送为`8ed4ef9 Verify visionOS geometry mapping`，fetch确认`HEAD == origin/main == 8ed4ef9515bbe06bb3750ce12dbb9f51c10a954a`且工作树clean。OpenSpec为`27/50 ready`、next 5.3，长期goal保持active。
- **范围：** 盘点并实现visionOS 26.4公开支持的controller、keyboard、pointer与indirect input adapter，所有实际事件必须经过typed capability和current session/media/input/surface generation/focus admission；复用既有remote input registry/transport，不合成gaze/hand/system gesture，不提前完成5.4 reserved interaction、5.5 release/local restoration或6.x media。
- **约束：** 先以XROS SDK公开header和现有data flow取证，再最小实现；普通测试继续移除real-Keychain/live-host opt-in，不查询、创建、启动或操作Simulator lifecycle。
- **API取证：** XROS 26.4 direct `swiftc -target arm64-apple-xros26.0 -warnings-as-errors`探针 `/tmp/LuneX-18-5_3-probe.fbbrpe`通过`UIPress.key/UIKey`、`UIHoverGestureRecognizer`、`GCController.controllers()`与`GCKeyboard.coalesced`；`/tmp/LuneX-18-5_3-input-probe.fcZdCe`通过indirect-pointer hover、GCMouse movement/button与extended gamepad handler；`/tmp/LuneX-18-5_3-scroll-probe.R0lyHz`通过scroll-type pan配置。均仅typecheck，未运行或操作Simulator。
- **实现计划：** 新增纯vision native input adapter与surface event合同；actual Metal view只接hardware key、`.indirectPointer` hover/button及public scroll，不转发direct/gaze/hand；AppModel以现有`VisionInputAdmissionResolver`复核presentation/surface/input generation、focus/capability并串行发送；GameController slot/runtime owner参数化tvOS/visionOS并复用既有roster/transport。5.4/5.5边界保持。
- **系统更新后恢复：** planning catch-up确认未同步上下文仅为5.3启动实现及本轮续接消息；OpenSpec CLI仍为`27/50 ready`、next 5.3，长期goal保持active。当前先固定纯adapter测试并参数化现有controller runtime，随后接actual view/AppModel。
- **工具错误 1：** 为查找既有测试命令执行`rg -n "-only-testing..."`时未使用`--`，pattern被当作flag并报`unrecognized flag -y`；改用`rg -n --`后正常，无仓库或设备副作用。
- **最小测试失败 1：** `/tmp/LuneX-18-5_3-adapter.cNulZg`在测试编译期找不到`VisionNativeInputAdapter`及其类型；根因为generator只更新主`source`清单，遗漏独立`test_support_sources`清单，其他diagnostic均为连锁错误。已补测试target membership，将从fresh目录重跑。
- **最小测试失败 2：** `/tmp/LuneX-18-5_3-adapter-r2.wfPNcg`已确认新adapter进入test target，编译仅剩测试第598行`generation(.surface, 7)`漏写`try`；production无诊断、测试未执行。已精确补`try`，下一轮fresh验证。
- **最小测试失败 3：** `/tmp/LuneX-18-5_3-adapter-r3.uDaGKa`成功编译并运行21项，20 passed/1 failed；vision controller在构造现有`TVControllerInputSnapshot`时被其tvOS-only guard拒绝为`controllerPlatformMismatch`。该snapshot/feedback本就是共享controller registry合同，tvOS-specific release plan另有独立平台guard；现将controller snapshot与feedback request允许tvOS/visionOS，保持tvOS release语义不变。
- **纯合同最小验收：** fresh `/tmp/LuneX-18-5_3-adapter-r4.UYHFT3`完整通过`21/21`；覆盖HID映射、本地保留/未知键、absolute pointer、button/scroll validation、surface generation/path一致性，以及visionOS controller lease/routing/motion。该证据尚不证明actual UIKit surface或AppModel transport接线。
- **XROS API修正：** direct probe确认`UIPress`没有`isRepeat`；production只从`UIPress.key`构造成对down/up，显式使用`isRepeat: false`，不推断或合成键盘重复语义。
- **恢复断点：** actual `TVVisionStreamMetalView`、SwiftUI bridge与`AppModel` current-generation串行admission补丁已应用但尚未编译/测试；恢复后先审计diff并运行fresh XROS direct build，再补应用层回归，不提前勾选5.3。
- **跨层测试失败 1：** fresh `/tmp/LuneX-18-5_3-appmodel-focused.7mnumU`中纯合同`21/21`通过，新AppModel用例在等待presentation application总数恰好为8时超时；连续hidden/inactive/unfocused/restored更新按既有latest-operation语义允许合并，硬编码中间应用数量错误。改为等待最终`.scene(restoredGeometry)`，不改变production。
- **跨层focused验收：** 修正后的fresh `/tmp/LuneX-18-5_3-appmodel-focused-r2.MwWxeV`完整通过`22/22`；证明current focused vision surface发送、stale/hidden/inactive/unfocused local、replacement后queued old event不发送、visionOS controller roster/routing通过且tvOS lease被拒绝。下一步扩大tvOS/controller/AppModel回归。
- **扩大相关回归：** `/tmp/LuneX-18-5_3-related.KAKJGt/Tests.xcresult`串行解析为`99/99 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`。覆盖vision window/input、tvOS remote/focus、controller、platform presentation及5个相关AppModel workflow；下一步完成production竞态审计并运行fresh normal suite。
- **production审计修正：** window key/resign-key observer原先只发布focus snapshot，没有重新计算view first-responder ownership；controller roster发送完成后也只复核media generation，focus loss期间的迟到完成可能回写routed roster。现以纯`VisionFirstResponderPolicy`统一key/interactive/visible条件，在window notification和view visibility/interaction变化时同步responder；controller write-back新增operation/roster/generation/release/focus二次admission，并补两条回归。production变化后，上述focused/related/direct build降为中间证据，下一步全部fresh重跑。
- **修订后focused：** fresh `/tmp/LuneX-18-5_3-focused-r3.73l4R8/Focused.xcresult`结构化通过`23/23 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`；下一步fresh related矩阵。
- **related失败 1：** fresh `/tmp/LuneX-18-5_3-related-r2.gpV78p`结构化为`100 total / 99 passed / 1 failed`；唯一tvOS workflow显示同generation内第二roster已成功发送后，完成侧因第三roster已排队而拒绝记录host-visible routed state，使第三差异错误地从第一roster计算。二次admission应防focus/generation失效，不应抹去已成功送达的中间host state；现保留cancel/generation/release/focus检查，移除operation/exact-current-roster限制后fresh重跑。
- **routing定向修复验收：** fresh `/tmp/LuneX-18-5_3-routing-fix.w0dfTC/Routing.xcresult`结构化通过`2/2`；tvOS连续roster继续以host-visible成功状态串行计算差异，visionOS focus loss期间blocked send完成后不回写stale routed state。
- **fresh related最终验收：** `/tmp/LuneX-18-5_3-related-r3.OSGzhI/Related.xcresult`串行结构化通过`100/100 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`。下一步最终production diff审计，再运行fresh normal和编译矩阵；5.3仍保持pre-mark。
- **fresh normal验收：** `/tmp/LuneX-18-5_3-normal.d3en1d/Normal.xcresult`串行结构化通过`1065 total / 1064 passed / 1 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`；唯一skip精确为显式禁用的`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`。真实Keychain/live-host opt-in均unset；下一步fresh fixed Vision Pro direct和五平台unsigned Debug。
- **构建命令盘点错误 1：** 只读命令误用`/tmp/LuneX-18-5_2-builds.gqJzlP/*.log`，实际日志位于平台子目录；zsh因no matches在任何build前退出，无仓库或设备副作用。改用`find`得到的精确子目录路径读取，不重复错误glob。
- **fresh fixed Vision Pro direct：** `/tmp/LuneX-18-5_3-visionos-direct.kJobJV/VisionOS.xcresult`在XROS 26.4 unsigned Debug结构化为`succeeded / 0 warning / 0 error / 0 analyzer warning`，并生成`1 AIR / 1 metallib`；UUID只作destination，未启动或操作Simulator。
- **fresh五平台build：** `/tmp/LuneX-18-5_3-builds.BSj3P1`中macOS、fixed iPhone/iPad/Apple TV/Vision Pro unsigned Debug全部结构化为`succeeded / 0 warning / 0 error / 0 analyzer warning`，每项均有`1 AIR / 1 metallib`。下一步同步权威文档并运行fresh repository pre-gate；5.3仍保持pre-mark。
- **门禁盘点路径错误 1：** 只读`rg --files Tools Scripts ...`和`rg --files Documentation docs ...`分别遇到不存在的`Scripts/`、`Documentation/`；真实仓库目录为`Tools/`与`docs/`。无文件或设备副作用，后续命令只使用已确认路径。
- **权威同步补丁错误 1：** 首个四文件组合补丁误把runtime contract中的5.2结论句当作精确独立锚点，`apply_patch`原子拒绝且四文件均无部分写入。改用各文件真实稳定段落或`## Fixed simulator inventory`标题拆分应用。
- **权威同步验证错误 1：** 只读`rg`搜索模式以shell双引号包住Markdown反引号，zsh误执行字面量`27/50`并报no such file；无文件修改。后续用单引号或无反引号稳定短语验证。
- **权威同步：** 已同步OpenSpec design/visionOS window-input spec、阶段18runtime contract、completion roadmap及三份planning，记录public XROS事件来源、key-window first responder、indirect-pointer-only过滤、capture/send双重admission、共享controller registry与host-visible routed state、完整fresh证据及5.4/5.5/physical/live边界。pre-mark scope为精确17文件，OpenSpec仍为`27/50 next 5.3`；下一步fresh repository pre-gate。
- **repository pre-gate错误 1：** `/tmp/LuneX-18-5_3-repository-pre.2TEasI`已通过fixtures、strict/apply、三次generator、17文件scope与membership，在semantics段因tvOS guard的`$0`静态pattern多转义一层而无提示退出；诊断还发现后续负向pattern中的泛词`hand`会误匹配合法`handler`。源码语义无失败，改用fixed-string guard和具体spatial API token后从fresh目录完整重跑。
- **repository pre-gate错误 2：** `/tmp/LuneX-18-5_3-repository-pre-r2.g1bb9N`再次通过同一前置门后在semantics段退出；逐项确认`window?.isKeyWindow`与三元表达式中的`?`被普通`rg`当正则量词，fixed-string读取均存在。统一把Swift精确文本断言改为`rg -F`后fresh完整重跑。
- **repository pre-gate：** fresh `/tmp/LuneX-18-5_3-repository-pre-r3.K2qbMj`完整通过fixture self/tree、OpenSpec strict `9/9`、pre-mark `27/50 next 5.3`、三次稳定generator SHA-256 `e6a88cd00f4364b7e3a8011841abba9344a9ae3ac1c411e18d1ce426b9b739cb`、精确17文件scope、membership/semantics/privacy/clean-room/reference/dependency/API/platform/opt-in/process/diff及全部retained test/build/Metal证据。
- **状态：** 5.3已有独立完成证据，现勾选为`complete`；预期OpenSpec为`28/50 ready`、next 5.4。下一步只读post-mark final-state，不重复test/build/generator、Keychain或Simulator操作。
- **post-mark final-state：** fresh只读门禁`/tmp/LuneX-18-5_3-final-state.bsTiTn`完整通过，确认OpenSpec `28/50 ready`、5.3 done、next 5.4与精确18文件scope；未重复test/build/generator、访问Keychain或操作Simulator lifecycle。下一步只读post-record与最终diff审计，通过后独立提交推送5.3，再进入5.4；阶段18与长期goal继续`in_progress/active`。
- **post-record包装错误 1：** 首轮`/tmp/LuneX-18-5_3-post-record.ApejcY`已通过OpenSpec、18文件scope、稳定project hash及五份权威引用后，因包装器把实际小写build证据目录`macos/iphone/ipad/tvos/visionos`误写为首字母大写而退出；不是源码/test/build失败。改用真实目录名并增加步骤标记后从fresh目录重跑，不重复行为验收。
- **post-record包装错误 2：** 修正版`/tmp/LuneX-18-5_3-post-record-r2.2d1Bht`通过OpenSpec与18文件scope后，在authority步骤发现`findings.md`已有pre-gate结论但没有精确证据路径；其余四份记录两条路径齐全。已补该可复用调查路径后fresh重跑，未运行test/build/generator或操作Keychain/Simulator。
- **post-record：** 修正后的fresh `/tmp/LuneX-18-5_3-post-record-r3.HJheG4`完整通过OpenSpec strict `9/9`、`28/50 next 5.4`、精确18文件scope、稳定project hash、五份authority、retained test/build/Metal、唯一Keychain skip、disabled opt-ins、no-process、dependency/reference和diff边界。下一步最终逐文件diff审计；通过后精确stage、独立提交推送5.3并进入5.4。
- **最终审计：** `/tmp/LuneX-18-5_3-final-audit.TNi2hb`完整通过18文件scope、public key/indirect-pointer事件源、first-responder/teardown、capture/send双重admission、host-visible controller routing、tvOS-only release guard、测试/membership、5.4/5.5 pending及opt-in/process/dependency/reference边界；未发现阻止提交的问题。5.3准备精确stage并独立提交推送，阶段18/goal保持`in_progress/active`。

## 2026-08-07 阶段 18 任务 5.4 启动

- **状态：** `in_progress`；5.3已提交推送为`aaeb18d Implement visionOS native input adapters`，fetch确认`HEAD == origin/main == aaeb18da0e3b111828500a2b3457ee8c6e692e24`且工作树clean。OpenSpec为`28/50 ready`、next 5.4，阶段18与长期goal保持`in_progress/active`。
- **合同复用：** 1.4已定义完整`VisionSystemReservedInteraction`、typed disposition/decision和all-cases测试；5.3 actual surface只把non-deliver统一留在本地，尚未将公开可观察的reserved hardware key映射到该typed actual state。
- **实现边界：** 复用现有decision合同，为`UIPress.key`可观察的Escape、keyboard volume/mute、Print Screen与Command-Shift-3/4/5 capture、Command-Q/H/Tab系统快捷键建立精确resolver；surface只发布current surface generation的typed local decision，AppModel拒绝stale surface并清理replacement/stop状态。recenter/safety/system-owned gesture及gaze/hand不安装应用事件源、direct/spatial recognizer或synthetic Moonlight event。
- **非目标：** 不拦截系统级Digital Crown/recenter/safety/capture/volume机制，不引入ARKit/hand/gaze API，不实现5.5 ordered held-state release/local UI restoration或5.6综合矩阵；physical Vision Pro行为继续pending。
- **调查错误 1：** AppModel actual-state检索误猜`Sources/LuneXCore/RuntimeDiagnostics.swift`并得到file not found；真实路径是`Sources/LuneXDiagnostics/RuntimeDiagnostics.swift`。同一命令其余只读结果有效，无工作区或设备副作用。
- **验收计划：** 先补纯resolver/event/AppModel current-vs-stale测试并运行fresh最小/focused回归，再做XROS direct warnings-as-errors、相关矩阵、normal和五平台unsigned build；真实Keychain/live-host opt-in继续unset，固定Simulator UUID仅作build destination且不操作lifecycle。
- **实现补丁错误 1：** 首个adapter/AppModel/Metal/RootView组合补丁因`AppModel` surface replacement段的多行锚点未精确匹配而被`apply_patch`原子拒绝；`git status`确认无部分production写入。随后按真实行号拆分文件成功应用。
- **第一版实现：** adapter新增canonical current-surface system-interaction event与hardware-key reservation resolver；actual Metal view只在`UIPress.key`入口发布typed local decision，RootView转交AppModel，AppModel只接受current surface并在replacement/stop清空。测试覆盖Escape/Print Screen/volume/Command capture/system shortcut、伪造decision、current/stale/stop与零remote delivery；`git diff --check`通过。
- **focused包装错误 1：** 首轮命令数组被空格而非换行拼接，`root`赋值未成为独立shell语句，重定向在任何`xcodebuild`前报只读`/xcodebuild.log`；无编译、测试、Keychain或设备副作用。改为逐行脚本并使用fresh目录。
- **focused验收：** 修正后的fresh `/tmp/LuneX-18-5_4-focused-r2.oBJfvC/Focused.xcresult`串行结构化通过`24/24 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`。下一步fixed Vision Pro direct编译actual UIKit分支。
- **XROS direct：** fresh fixed Vision Pro `/tmp/LuneX-18-5_4-visionos-direct.CsJwFj/VisionOS.xcresult`在XROS 26.4 unsigned Debug完整通过，结构化`succeeded / 0 warning / 0 error / 0 analyzer warning`并有`1 AIR / 1 metallib`；固定UUID只作destination，未启动或操作Simulator。下一步fresh related矩阵。
- **related验收：** fresh `/tmp/LuneX-18-5_4-related.KdKMLz/Related.xcresult`串行结构化通过`101/101 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`；覆盖vision reservation/window/input、tvOS remote/release、controller/diagnostics、platform presentation与五个AppModel workflow。下一步fresh normal。
- **normal验收：** fresh `/tmp/LuneX-18-5_4-normal.2eEluq/Normal.xcresult`串行结构化通过`1066 total / 1065 passed / 1 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`；唯一skip精确为显式禁用的真实Keychain用例。下一步五平台unsigned Debug。
- **build汇总错误 1：** 五平台build均已完成后，首轮xcresult读取包装器把zsh只读特殊变量`status`用于赋值，在首个平台汇总时退出；不是build失败且未重跑build。改为`build_status`后串行读取已有五份xcresult。
- **五平台build：** fresh `/tmp/LuneX-18-5_4-builds.pGfMJ3`中macOS、fixed iPhone/iPad/Apple TV/Vision Pro unsigned Debug全部结构化为`succeeded / 0 warning / 0 error / 0 analyzer warning`，每项均有`1 AIR / 1 metallib`。固定UUID只作destination，未执行Simulator lifecycle；下一步权威同步与repository pre-gate。
- **repository pre-gate：** fresh `/tmp/LuneX-18-5_4-repository-pre.sSXJDF`完整通过fixture self/tree、OpenSpec strict `9/9`、pre-mark `28/50 next 5.4`、三次generator稳定SHA-256 `e6a88cd00f4364b7e3a8011841abba9344a9ae3ac1c411e18d1ce426b9b739cb`、精确13文件scope、canonical local reservation/current-surface ownership/无synthetic source语义、全部retained test/build/Metal、唯一Keychain skip及privacy/reference/dependency/opt-in/process/diff边界。
- **状态：** 5.4已有独立实现、行为、build和repository证据，现已勾选`complete`；OpenSpec为`29/50 ready`、next 5.5。阶段18与长期goal继续`in_progress/active`，不得把5.4证据提升为Simulator runtime、signed/physical或live证明。
- **post-mark final-state：** fresh只读门禁`/tmp/LuneX-18-5_4-final-state.GcQmvO`确认strict `9/9`、`29/50 ready`、5.4 done、next 5.5、稳定project hash与精确14文件scope；未重复generator/test/build、访问Keychain或操作Simulator lifecycle。下一步post-record与最终diff审计，通过后独立提交推送5.4并进入5.5。
- **post-record：** fresh只读门禁`/tmp/LuneX-18-5_4-post-record.7WByk7`确认五份authority均记录pre-gate/final-state路径、OpenSpec `29/50 next 5.5`、精确14文件scope、当前实现/测试语义、全部retained evidence及稳定repository边界。
- **最终审计：** `/tmp/LuneX-18-5_4-final-audit.CbmtKb`通过14文件精确分类4 production/2 test/8 authority、唯一5.4 checkbox替换、public key began事件源、canonical current-surface local decision、零remote event、replacement/stop清理、indirect-pointer-only、tvOS不变、测试与5.5 pending边界；未发现阻止5.4独立提交的问题。
- **final-record：** `/tmp/LuneX-18-5_4-final-record.fPlISb`再次确认strict `9/9`、`29/50 next 5.5`、14文件4/2/8分类、五份authority包含pre/final/post/audit证据索引、稳定project/reference/dependency及opt-in/process/diff边界；5.4可精确stage、独立提交并推送。

## 2026-08-07 阶段 18 任务 5.5 启动

- **状态：** `in_progress`；5.4已提交推送为`9e4744e Reserve visionOS system interactions locally`，fetch确认`HEAD == origin/main == 9e4744e1e55ed701ff11f8faf4d752b52f993e8c`且工作树clean。OpenSpec为`29/50 ready`、next 5.5，阶段18与长期goal保持`in_progress/active`。
- **现有合同：** 1.4的`VisionWindowInputOwnershipState.releasing`已严格给出`close admission -> cancel system observers -> remove controller handlers -> cancel keyboard/pointer monitors -> await held-input release -> optional surface lease release -> restore local navigation`顺序和幂等语义；5.5必须接入该合同，不能再造一套release顺序。
- **生产缺口：** AppModel当前visionOS路径只按snapshot拒绝新事件并在失焦时直接停止controller/清空roster，没有等待已排队keyboard/pointer/controller发送后调用共享`releaseRemoteInput()`；terminal helper仍有tvOS guard。actual Metal view失焦只resign first responder，active key/button与recognizer没有作为本地capture lease一起撤销，provider failure时key window仍可能继续占有responder。
- **实现计划：** 新增main-actor串行vision input target/reconciliation状态，任何focus/scene/input loss或surface replacement先同步关闭admission，再按纯合同等待所有已接收输入和controller任务，执行一次held-state release，最后发布privacy-bounded local restore reason；provider failure/reconnect/remote termination/stop走teardown scope且幂等。RootView把actual capture-enabled状态传给Metal surface，surface在false时清active press/button、resign responder并移除recognizer，重新eligible后再安装。
- **边界：** 不新增第二remote input runtime、不改变tvOS release owner、不提前完成5.6综合矩阵或7.x UI；不把macOS注入测试/unsigned build描述为物理Vision Pro focus、controller、gaze/hand或live Sunshine证明。真实Keychain/live-host opt-in继续unset，固定UUID只作build destination且不操作Simulator lifecycle。
- **实现锚点错误 1：** 首个RootView单点补丁因tvOS与visionOS构造器具有相同`platformPresentationOwner`锚点，暂时把`visionInputCaptureEnabled`加入tvOS分支；在任何编译/测试前读回发现并精确移至visionOS `#else`分支，没有设备、Keychain或运行时副作用。
- **terminal latch补丁错误 1：** 首个terminal latch三位置组合补丁因`beginTVVisionPlatformPresentationRuntime`真实上下文顺序与锚点不符被`apply_patch`原子拒绝，无部分写入；读回实际行后拆分成功。latch只在新media runtime begin复位，terminal release后的late geometry不得重新开放capture。
- **共享分支编译：** production共享分支macOS warnings-as-errors build `/tmp/LuneX-18-5_5-compile.EkXXnC`通过，结果为`succeeded / 0 warning / 0 error / 0 analyzer warning`。
- **focused失败 1：** fresh `/tmp/LuneX-18-5_5-focused.oVV88l`完成编译且四类diagnostics为0，结构化结果为`25 total / 23 passed / 0 skipped / 2 failed / 0 expected failure`；全部`VisionWindowInputContractTests`通过。两项失败仅为最终release次数：`testVisionInputRequiresCurrentFocusedSurfaceAndMatchingControllerLease`实际5、预期4，`testVisionInputProviderFailureRunsTerminalReleaseBeforeLocalRestore`实际2、预期1。
- **失败根因：** visionOS ordered release已经在等待keyboard/pointer FIFO与controller链后调用一次`releaseRemoteInput()`，terminal teardown随后仍调用`MacSessionInputCoordinator.terminate`，而该协调器默认再执行一次release barrier。正确修复是让协调器支持“外部有序屏障已完成”的无屏障终止：仍关闭generation/capture并保持幂等，但不重复调用sink release；macOS既有调用继续默认执行屏障。
- **focused修订错误 1：** fresh `/tmp/LuneX-18-5_5-focused-r2.BuvIrO`在warnings-as-errors编译阶段退出，唯一诊断是platform presentation failure分支忽略了新`releasePlatformInputForTerminal`的`Bool`返回值；测试未执行。该分支只触发平台release而不终止Mac generation，已改为显式`_ = await`，下一轮使用fresh目录。
- **focused修订验收：** fresh `/tmp/LuneX-18-5_5-focused-r3.31aHqT/Focused.xcresult`结构化通过`41/41 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`。覆盖全部vision input合同、两个原失败AppModel场景及完整Mac coordinator回归；新增测试证明外部已释放终止仍drain in-flight、丢弃queue、关闭admission/generation、capture cleanup恰好一次、重复终止幂等且sink release为0。
- **下一步：** fresh related tvOS/visionOS/controller/AppModel/Mac input矩阵，随后normal、fixed Vision Pro direct和五平台unsigned Debug；两个真实opt-in继续unset，不操作Simulator lifecycle。
- **related验收：** fresh `/tmp/LuneX-18-5_5-related.zRgqSq/Related.xcresult`结构化通过`188/188 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`；覆盖完整AppModel workflows、tvOS remote release、vision input、Mac coordinator、controller与TV/Vision presentation state/coordinator。
- **下一步：** fixed Vision Pro direct warnings-as-errors build actual UIKit分支，再运行fresh normal与五平台unsigned Debug。
- **XROS direct验收：** fresh fixed Vision Pro `/tmp/LuneX-18-5_5-visionos-direct.qUpUfu/VisionOS.xcresult`在XROS 26.4 unsigned Debug结构化通过`succeeded / 0 warning / 0 error / 0 analyzer warning`，并生成`1 AIR / 1 metallib`；固定UUID仅作build destination，没有运行应用或操作Simulator lifecycle。
- **下一步：** fresh完整normal suite，精确确认唯一允许的真实Keychain skip；随后五平台unsigned Debug与repository/doc gates。
- **normal验收：** fresh `/tmp/LuneX-18-5_5-normal.5KOh5Z/Normal.xcresult`结构化通过`1068 total / 1067 passed / 1 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`；test tree精确确认唯一skip为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，两个真实opt-in均unset。
- **下一步：** fresh五平台unsigned Debug串行build，再同步OpenSpec/docs/planning并运行repository pre-gate。
- **五平台build：** fresh `/tmp/LuneX-18-5_5-builds.5FTkic`中macOS、fixed iPhone/iPad/Apple TV/Vision Pro unsigned Debug全部结构化为`succeeded / 0 warning / 0 error / 0 analyzer warning`，每项均有`1 AIR / 1 metallib`；固定UUID仅作build destination，未操作Simulator lifecycle。
- **下一步：** 同步OpenSpec design/spec、阶段18runtime contract、completion roadmap与三份planning，完成逐文件代码审计和fresh repository pre-gate；5.5保持pre-mark pending直到门禁通过。
- **权威同步错误 1：** 首个design/spec/runtime/roadmap组合补丁因OpenSpec design中`The only installed pointer recognizers`实际接在上一行句尾、与补丁换行锚点不一致而被`apply_patch`原子拒绝；无任何文件部分写入。改用稳定章节标题并按文件拆分应用。
- **权威同步：** 已同步OpenSpec design/visionOS input spec、阶段18runtime contract、completion roadmap及三份planning，记录serial target/reconciliation、terminal latch、FIFO/controller drain、canonical effect顺序、surface capture撤销恢复、Mac coordinator默认兼容barrier、完整fresh证据和5.6/6.x/7.x/physical/live边界。OpenSpec仍保持pre-mark `29/50 next 5.5`。
- **下一步：** 逐文件production/test/docs diff审计、fixture/OpenSpec/generator/membership/privacy/reference/dependency/retained-evidence repository pre-gate；通过后才勾选5.5。
- **暂停后审计发现 1：** `performVisionInputRelease()`正常合同路径完整，但合同构造/transition不一致的保底分支只停止controller并恢复本地状态，未等待keyboard/pointer FIFO或尝试host held release；同时正常effect application静默忽略`releaseRemoteInput()`失败，可能让后续eligible geometry重新开放capture。已改为保底路径仍按controller drain、input FIFO、单次release、最后restore执行；release provider失败会latch terminal input-unavailable并拒绝late geometry。新增AppModel workflow回归后必须重跑受影响focused/related/normal与build证据，旧证据不再作为最终5.5实现证据。
- **跟踪补丁错误 1：** 首个源码语法清理与三份planning组合补丁因`findings.md`锚点句子不完全匹配被`apply_patch`原子拒绝，无部分写入；随后按真实文件尾部拆分应用。
- **审计修订focused：** fresh `/tmp/LuneX-18-5_5-audit-focused.7SdLvE/Focused.xcresult`结构化通过`42/42 passed / 0 skipped / 0 failed / 0 expected failure`，build succeeded且warning/error/analyzer warning全零；新增release provider失败用例证明单次尝试、terminal `inputUnavailable`、late geometry不重开及后续终止不重复release。
- **审计修订related：** fresh `/tmp/LuneX-18-5_5-audit-related.hmvlgf/Related.xcresult`结构化通过`189/189 passed / 0 skipped / 0 failed / 0 expected failure`，build四类diagnostics为0；完整AppModel、tvOS/visionOS input、Mac coordinator、controller与presentation回归未受损。
- **normal证据读取错误 1：** normal本身成功后并行对同一xcresult执行summary/build/tests读取，`tests`导出因`xcresulttool`内部`database.sqlite3`临时重命名冲突退出；不是测试或源码失败。未重跑测试，改为串行读取同一bundle并确认唯一Keychain skip。
- **审计修订normal：** fresh `/tmp/LuneX-18-5_5-audit-normal.4HpgIt/Normal.xcresult`结构化通过`1069 total / 1068 passed / 1 skipped / 0 failed / 0 expected failure`，build四类diagnostics为0；唯一skip精确为真实Keychain显式opt-in测试，两个真实opt-in均unset。
- **审计修订五平台build：** fresh `/tmp/LuneX-18-5_5-audit-builds.ccZsdc`中macOS、fixed iPhone/iPad/Apple TV/Vision Pro unsigned Debug全部succeeded、warning/error/analyzer warning为0且各有`1 AIR/1 metallib`；固定UUID仅作destination，未查询或操作Simulator lifecycle。
- **权威同步包装错误 2：** 首个审计修订OpenSpec/docs组合脚本在JavaScript解析阶段被Markdown内联反引号截断，任何`apply_patch`调用前即退出；随后改为逐文件行数组成功应用，无部分文件漂移。
- **当前状态：** 修订后的OpenSpec design/spec、runtime contract、roadmap与三份planning已同步，5.5继续保持pre-mark `29/50 next 5.5`。下一步fresh repository pre-gate；通过前不得勾选。
- **repository pre-gate错误 1：** `/tmp/LuneX-18-5_5-repository-pre.cRQudv`已通过fixture self/tree、strict `9/9`、pre-mark `29/50 next 5.5`、三次稳定generator和精确13文件scope，随后因membership断言把`RootView.swift`在generator中的真实单一清单出现误写为2而退出；其他三个production文件因分别属于共享清单而出现2次，两个测试各1次。project hash稳定，无测试/build/Simulator副作用；修正RootView计数后从fresh目录完整重跑。
- **repository pre-gate错误 2：** `/tmp/LuneX-18-5_5-repository-pre-r2.*`再次通过fixtures、strict/apply、三次generator和scope后，在membership处因用于匹配路径两侧双引号的shell quoting表达式错误退出；直接固定字符串计数确认真实次数正确。一次诊断命令又因JavaScript模板把shell参数展开误作插值而在shell启动前报SyntaxError，无副作用。改用行数组与无引号路径匹配后fresh完整重跑。
- **repository pre-gate：** fresh `/tmp/LuneX-18-5_5-repository-pre-r3.GP0fhH`完整通过fixture self/tree、strict `9/9`、pre-mark `29/50 next 5.5`、三次稳定project SHA-256 `e6a88cd00f4364b7e3a8011841abba9344a9ae3ac1c411e18d1ce426b9b739cb`、精确13文件scope、membership、terminal/release-failure/no-second-barrier/surface capture语义、全部post-audit test/build/Metal证据、唯一Keychain skip及privacy/clean-room/reference/dependency/opt-in/process/diff边界。
- **状态：** 5.5已有独立实现、审计、行为、build和repository证据，现已勾选为`complete`。只读post-mark final-state `/tmp/LuneX-18-5_5-final-state.QP2qUU`确认OpenSpec `30/50 ready`、next 5.6、精确14文件scope、唯一5.5 checkbox替换与全部仓库边界；未重复test/build/generator、Keychain或Simulator操作。post-record `/tmp/LuneX-18-5_5-post-record.xbp4eR`与最终审计 `/tmp/LuneX-18-5_5-final-audit.7fk9HU`继续确认14文件4 production/2 test/8 authority分类、五份authority索引、typed release顺序、release-failure fail-closed、无第二barrier、surface capture撤销恢复与5.6 pending边界；无阻止独立提交的问题。
- **final-record：** `/tmp/LuneX-18-5_5-final-record.vfC7Fa`再次确认strict `9/9`、OpenSpec `30/50 next 5.6`、精确14文件4/2/8分类、五份authority证据索引、全部retained evidence及稳定opt-in/process/reference/dependency/diff边界；5.5可精确stage、独立提交并推送。

## 2026-08-07 阶段 18 任务 5.6 启动

- **状态：** `in_progress`；5.5已提交推送为`2ae0e19 Complete ordered visionOS input release`，fetch确认`HEAD == origin/main == 2ae0e19f3a278642af033b12b7e3e27fe0d80218`且工作树clean。OpenSpec为`30/50 ready`、next 5.6，阶段18与长期goal保持`in_progress/active`。
- **合同边界：** 5.6只补齐1.4与5.1–5.5既有production行为的连接回归矩阵，覆盖multiwindow filtering、resize sequence、focus、capability matrix、reserved interaction、input mapping、held release、stale callback、replacement和teardown；不得借测试任务提前实现6.x visionOS媒体或7.x产品UI。
- **验收计划：** 先盘点现有value、surface、AppModel与coordinator测试，按每个合同维度建立覆盖表；只新增缺失的确定性测试与必要fixture，随后运行focused、related、normal和五平台unsigned Debug，最后同步权威文档并执行repository/final gates。
- **证明边界：** macOS注入测试与unsigned build只证明确定性合同和SDK编译；不证明Simulator runtime、signed安装、物理Vision Pro窗口/输入、HDR、空间音频、live Sunshine、延迟、comfort、性能、功耗或温度。真实Keychain/live-host opt-in继续unset，不操作Simulator lifecycle。
- **覆盖盘点：** 既有AppModel综合用例已连接replacement/stale surface、reserved decision、keyboard FIFO、controller lease、focus/scene loss、held release和remote termination；既有geometry用例已连接fit/fill、absolute mapping与close。5.6新增测试应聚焦multiwindow identity filtering、连续resize共享revision、capability admission和旧window/mapping在replacement/teardown后保持inert，不复制5.1–5.5单项测试。
- **resize审计：** 初看`updateVisionInputRuntimeTarget`的snapshot变化分支疑似会把resize当replacement；读回`VisionWindowInputOwnershipState`后确认identity只含presentation/surface/input generation与phase，不含semantic revision/geometry，因此同generation resize不会触发release。5.6仍需显式锁定“resize更新snapshot/mapping但release计数不变”。
- **focused失败 1：** fresh `/tmp/LuneX-18-5_6-focused.AsL7EU`在测试执行前编译失败，唯一源码问题是新增合同测试在`XCTAssertEqual` autoclosure内三次调用throwing `generation(...)`而未标`try`；结构化结果0 tests、build failed、0 warnings/analyzer warnings。已改为断言外预构造generation，下一轮使用fresh目录。
- **focused验收：** fresh `/tmp/LuneX-18-5_6-focused-r2.Es1RDS/Focused.xcresult`结构化通过`3/3 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`。三条新增矩阵分别覆盖resize不释放held state、多窗口通知过滤与mapping replacement/teardown、capability/reserved/mapping/release顺序。
- **下一步：** 运行完整VisionWindowInput、StreamMetalPresenter、AppModel、TVVision state、controller与Mac coordinator相关类矩阵；两个真实opt-in继续unset，不操作Simulator lifecycle。
- **related验收：** fresh `/tmp/LuneX-18-5_6-related.yIYDyZ/Related.xcresult`结构化通过`213/213 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`；完整Vision合同、surface/presenter、AppModel、TVVision state、controller与Mac coordinator相关类无回归。
- **下一步：** fresh normal完整suite并精确确认唯一Keychain skip，随后fixed Vision Pro direct与五平台unsigned Debug；真实opt-in继续unset且不操作Simulator lifecycle。
- **normal验收：** fresh `/tmp/LuneX-18-5_6-normal.4E7C3M/Normal.xcresult`结构化通过`1072 total / 1071 passed / 1 skipped / 0 failed / 0 expected failure`，build四类diagnostics为0；唯一skip精确为显式真实Keychain用例，两个真实opt-in均unset。
- **normal读取错误 1：** 一次辅助`jq`在遍历test tree时对`name == null`节点调用`contains`而退出；不是测试或源码失败。使用类型过滤串行复读同一`tests.json`后确认唯一Keychain skip，未重跑测试。
- **下一步：** 串行五平台unsigned Debug build，再同步OpenSpec/docs/planning并运行repository pre-gate；固定UUID仅作destination，不操作Simulator lifecycle。
- **五平台build：** fresh `/tmp/LuneX-18-5_6-builds.ijxOfl`中macOS、fixed iPhone/iPad/Apple TV/Vision Pro unsigned Debug全部结构化为`succeeded / 0 warning / 0 error / 0 analyzer warning`且各有`1 AIR/1 metallib`；固定UUID仅作destination，未查询或操作Simulator lifecycle。
- **权威同步：** 已同步OpenSpec design/visionOS input spec、阶段18runtime contract、completion roadmap与三份planning，记录三条连接矩阵、fresh focused/related/normal/五平台证据和6.x/7.x/physical/live边界。5.6继续保持pre-mark `30/50 next 5.6`。
- **下一步：** 逐文件test/docs diff审计、fixture/OpenSpec/generator/membership/privacy/reference/dependency/retained-evidence repository pre-gate；通过后才勾选5.6。

## 2026-08-07 阶段 18 任务 6.1 推进

- **状态：** `in_progress`；OpenSpec保持pre-mark `31/50 ready`、next 6.1。已将1.4既有typed windowed/unavailable值合同接入current platform presentation coordinator snapshot与AppModel actual-state投影，不创建immersive runtime，也不提前实现6.2 frame、6.3 HDR、6.4 audio或7.x UI。
- **focused验收：** fresh `/tmp/LuneX-18-6_1-focused.XQEqfy/Focused.xcresult`结构化通过`4/4 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`。覆盖coordinator scene/replacement/stale/detach/stop、AppModel current ownership和两个既有windowed/unavailable值合同。
- **related验收：** fresh `/tmp/LuneX-18-6_1-related.dmWvOh/Related.xcresult`结构化通过`251/251 passed / 0 skipped / 0 failed / 0 expected failure`，build四类diagnostics为0；完整AppModel、coordinator/state、session media environment、vision input合同与Metal presenter无回归。
- **normal验收：** fresh `/tmp/LuneX-18-6_1-normal.pJMQ2K/Normal.xcresult`结构化通过`1074 total / 1073 passed / 1 skipped / 0 failed / 0 expected failure`，build四类diagnostics为0；唯一skip精确为显式真实Keychain round-trip，两个真实opt-in均unset。
- **五平台build：** fresh `/tmp/LuneX-18-6_1-builds.APF2yT`中macOS、fixed iPhone/iPad/Apple TV/Vision Pro unsigned Debug全部结构化为`succeeded / 0 warning / 0 error / 0 analyzer warning`且各有`1 AIR/1 metallib`；固定UUID只作destination，未操作Simulator lifecycle。
- **审计补强：** production复核确认windowed state会随input/display/audio/video更新重标到coordinator current revision；新增跨组件revision回归，visionOS测试fixture使用平台合法keyboard/pointer capability。production无需修订。
- **审计后验收：** fresh focused `/tmp/LuneX-18-6_1-audit-focused.u9HXzp`为`1/1`，related `/tmp/LuneX-18-6_1-audit-related.3Whib6`为`251/251`，normal `/tmp/LuneX-18-6_1-audit-normal.VXSI3H`为`1074/1073/1 exact Keychain skip/0`；全部build diagnostics为0。
- **权威同步：** 已同步OpenSpec design/visionOS media spec、阶段18runtime contract、completion roadmap与三份planning；记录actual scene派生、跨组件revision、replacement/terminal清理、fresh证据和proof boundary。6.1仍为pre-mark pending。
- **下一步：** 逐文件production/test/docs diff审计并运行fresh repository pre-gate；通过后才勾选6.1。固定UUID只作build destination，不操作Simulator lifecycle。
- **repository pre-gate包装错误 1：** `/tmp/LuneX-18-6_1-repository-pre.a54Ef7`已通过fixture/OpenSpec/generator/scope/membership/语义/test/build部分，最后因边界断言误要求小写`do not prove`和大写`Tasks`字面量而退出；真实spec/contract分别为`SHALL NOT prove`和`6.2-8.x`。这是检查器字面假设，不是源码、测试或边界失败；修正为真实权威文本后从fresh目录完整重跑。
- **repository pre-gate：** fresh `/tmp/LuneX-18-6_1-repository-pre-r2.nZ4iKX`完整通过fixture self/tree、strict `9/9`、pre-mark `31/50 next 6.1`、三次稳定project SHA-256、精确11文件scope、membership、windowed/current ownership/revision/replacement/terminal/tvOS nil语义、全部retained test/build/Metal证据、唯一Keychain skip及privacy/clean-room/reference/dependency/opt-in/process/diff/proof边界。
- **状态：** 6.1已有独立实现、审计、行为、build和repository证据，现已勾选为`complete`。只读post-mark final-state `/tmp/LuneX-18-6_1-final-state.D3kVOH`确认OpenSpec `32/50 ready`、next 6.2、精确12文件scope及唯一6.1 checkbox替换；没有重复test/build/generator、访问Keychain/live host或操作Simulator lifecycle。阶段18与长期目标保持`in_progress/active`。
- **post-record包装错误 1：** 首个post-record命令中的Markdown反引号截断JavaScript模板，脚本在解析阶段以`SyntaxError: Unexpected number`退出，shell和任何仓库/测试/build/设备操作均未启动；移除反引号字面依赖后从fresh目录重跑。
- **post-record：** fresh `/tmp/LuneX-18-6_1-post-record-r2.aMya2c`通过strict `9/9`、OpenSpec `32/50 next 6.2`、精确12文件`2 production / 2 test / 8 authority`分类、五份authority证据索引、retained test/build、稳定project及opt-in/process/reference/dependency/diff边界。下一步最终diff审计与final-record。
- **final audit包装错误 1：** 首个最终审计命令再次因stage行中的Markdown反引号截断JavaScript模板，以`SyntaxError: Unexpected identifier 'in_progress'`在shell启动前退出；无副作用。改为按无反引号字段组合检查后从fresh目录重跑。
- **final diff audit：** fresh `/tmp/LuneX-18-6_1-final-audit-r2.nVb6kC`通过精确12文件`2 production / 2 test / 8 authority`分类、actual scene/current ownership/revision/surface/replacement/terminal/tvOS nil语义、完整typed unavailable与AppModel current投影；确认无弱化测试、并行media owner、6.2提前实现、第二checkbox、敏感字面量或reference/dependency/project漂移。无阻止6.1独立提交的问题。
- **final-record：** `/tmp/LuneX-18-6_1-final-record.cA8Upm`确认strict `9/9`、OpenSpec `32/50 next 6.2`、精确12文件分类、五份authority各四道门索引、retained test/build、稳定project及全部仓库边界；6.1进入精确stage、独立提交与推送。

## 2026-08-07 阶段 18 任务 6.2 启动

- **状态：** `in_progress`；6.1已提交推送为`8ba0e33 Report current visionOS windowed presentation`，fetch确认`HEAD == origin/main == 8ba0e336db4f11d3355c772e036b692d9be3f10d`且工作树clean。OpenSpec为`32/50 ready`、next 6.2。
- **范围：** 把visionOS decoded frames、actual `TVVisionStreamMetalView`/`StreamMetalPresenter`、coordinator presentation revision、surface replacement、clear/resume和stale-frame rejection作为一条current windowed ownership链验收；不提前实现6.3 HDR、6.4 audio、6.5组合teardown或7.x UI。
- **盘点：** task 4.1已把`TVVisionMetalPresentationOwner`、platform-admitted frame模式、single `StreamVideoPresentationSource` subscription及RootView tvOS/visionOS两分支实际surface绑定做成共享production路径；现有执行级frame测试helper仍把ownership固定为tvOS，缺少visionOS专属连接矩阵。先让fixture支持平台并补连接测试；只有测试暴露平台identity/fence缺口时才最小修订production。
- **验收计划：** 新增visionOS focused矩阵覆盖shared latest-frame bypass、windowed state、decoded frame呈现、geometry revision同帧重交、surface replacement、old surface/ownership stale、clear/new decoder resume、detach/stop；随后执行related、normal、fixed Vision Pro与五平台unsigned Debug，再走repository/final-state门。
- **证明边界：** 受控macOS Metal执行测试和unsigned XROS build不证明Simulator runtime、signed install、物理Vision Pro窗口/compositor、HDR、空间音频、live Sunshine、延迟、comfort、性能、功耗或温度。真实Keychain/live-host opt-in继续unset，不操作Simulator lifecycle。
- **focused执行误判 1：** 首轮fresh `/tmp/LuneX-18-6_2-focused.Q4t2CR`以短yield返回后，过早读取尚未封口的xcresult并看到`root ID is missing`；实际LuneX `xcodebuild`仍在PID 465运行。没有启动第二个LuneX测试，等待原进程结束后结构化读回为`1 test / 1 failed`、build四类diagnostics为0；失败精确是replacement frame期望44而runtime仍为43。
- **focused定位：** r2 `/tmp/LuneX-18-6_2-focused-r2.bZ5mco`加入replacement scene/decoder/frame outcome与owner snapshot断言后仍在同一最终呈现断言失败，但证明coordinator均`.applied`、owner已经持有frame 44/current surface/eligible scene。根因是测试在replacement activation设置强制clear fence后未先执行clear draw；第一笔draw按设计只清旧drawable，不能同时呈现新ownership。
- **focused owner矩阵：** 显式验证replacement activation先清屏后，fresh `/tmp/LuneX-18-6_2-focused-r3.WZuCgw`通过`1/1`且build四类diagnostics为0；production无需修订。
- **focused完整矩阵：** 新增SessionMediaEnvironment visionOS single subscription replacement用例后，fresh `/tmp/LuneX-18-6_2-focused-r4.5amuAx`通过`2/2 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`。覆盖coordinator→owner→presenter及source→environment→replacement coordinator两条生产链。
- **production审计修复：** `StreamVideoPresentationSource`按revision同步回调，但environment原实现为每笔delivery各建一个unstructured `Task`，Task进入actor的顺序无保证，可能让frame越过decoder-start/clear并形成无界Task增长。已新增ownership-scoped `SessionTVVisionPlatformVideoDeliveryPump`：单consumer FIFO、最多64笔pending、replacement/failure/stop/teardown与subscription共同取消；overflow清空pending并经同一consumer只对matching pump ID发布typed video failure。
- **审计测试诊断：** 首个有界overflow组合运行在异步等待中被定向中止；隔离证明pump单测通过，environment用例失败是测试错误地等待decoder-start产生`.video` effect，而coordinator只为decoded frame创建video application。修正为先送frame 0并用2秒状态轮询后，isolated overflow用例通过。中止/失败bundle不作为通过证据。
- **审计后focused：** fresh `/tmp/LuneX-18-6_2-audit-focused-r4.vj6AKw/Focused.xcresult`结构化通过`4/4`且build四类diagnostics为0；覆盖owner/presenter、single subscription replacement、FIFO/cancel/overflow及environment typed overflow failure。
- **审计后related：** fresh `/tmp/LuneX-18-6_2-audit-related.xqXKjd/Related.xcresult`结构化通过`255/255`，零skip/failure/expected failure且build四类diagnostics为0。
- **审计后normal：** fresh `/tmp/LuneX-18-6_2-audit-normal.rwmq84/Normal.xcresult`结构化通过`1078 total / 1077 passed / 1 skipped / 0 failed / 0 expected failure`且build四类diagnostics为0；并行明细读取一次触发xcresult临时数据库冲突，串行复读同一bundle确认唯一skip精确为显式真实Keychain用例，未重跑测试。
- **审计后五平台：** fresh `/tmp/LuneX-18-6_2-audit-builds.jvlO3v`中macOS、fixed iPhone/iPad/Apple TV/Vision Pro unsigned Debug全部`succeeded / 0 warning / 0 error / 0 analyzer warning`，各有`1 CompileMetalFile/1 MetalLink`；固定UUID只作destination，未调用Simulator lifecycle。
- **下一步：** 同步OpenSpec/runtime/roadmap/planning并运行pre-mark repository gate；OpenSpec在门前保持`32/50 next 6.2`，通过后才勾选6.2。6.3 HDR、6.4 audio、6.5-8.x与physical/live证明继续pending。
- **repository包装错误 1：** macOS更新后的首个pre-gate命令在进入shell前因外层JavaScript把shell环境变量展开式误解析为模板插值而报`SyntaxError: Unexpected token '}'`；没有创建证据目录、运行generator/test/build、修改工作区或操作设备。改用`printenv`避免模板语法。
- **repository包装错误 2：** fresh `/tmp/LuneX-18-6_2-repository-pre.NSD4Ky`通过fixture、OpenSpec、scope、三次generator和membership后，包装器只统计4个`current`属性取消点，漏掉teardown捕获局部变量的第5个pump cancel并错误退出；源码实际覆盖replacement、failure、stop和teardown。修正为4个active-state路径加1个teardown路径后从fresh目录完整重跑。
- **repository pre-gate：** fresh `/tmp/LuneX-18-6_2-repository-pre-r2.qw8ka9`从头通过fixture self/tree、OpenSpec strict `9/9`与pre-mark `32/50 next 6.2`、三次稳定generator SHA-256 `e6a88cd00f4364b7e3a8011841abba9344a9ae3ac1c411e18d1ce426b9b739cb`、精确10文件scope、membership、bounded FIFO/cancel/overflow/current-ID/clear-fence语义、retained `4/255/1078`及五平台Metal build、privacy/reference/dependency/opt-in/process/diff边界。现仅勾选6.2，随后只读post-mark门。
- **authority记录补丁错误：** 首个五文件post-mark记录补丁因roadmap现有证据句比预期锚点多出opt-in/Simulator说明而被`apply_patch`原子拒绝，无部分写入；按真实稳定锚点拆分追加。
- **post-mark final-state：** `/tmp/LuneX-18-6_2-final-state.Dx3op0`只读通过OpenSpec strict `9/9`、`33/50 next 6.3`、精确11文件scope、tasks唯一6.2 checkbox变化、稳定project hash、retained test/build及source/docs/opt-in/process/proof边界；没有重复test/build/generator或Simulator操作。下一步post-record、最终diff审计和独立提交推送。
- **post-record/final audit：** `/tmp/LuneX-18-6_2-post-record.cDfHFy`通过`33/50 next 6.3`、精确`1 production / 2 test / 8 authority`分类、五份authority双门索引、稳定project与retained evidence；`/tmp/LuneX-18-6_2-final-audit.k3rz0Z`确认single bounded FIFO/current-ID、完整cancel/overflow mechanics、四条focused语义无skip/弱化、唯一checkbox及privacy/reference/dependency/opt-in边界。下一步final-record后精确提交推送。
- **final-record：** `/tmp/LuneX-18-6_2-final-record.Q9ZZvx`通过strict `9/9`、OpenSpec `33/50 next 6.3`、最终11文件`1/2/8`分类、五份authority四门索引、稳定project/全部retained evidence及implementation/task/proof/privacy/opt-in/process/dependency/diff边界；6.2进入精确stage、提交与推送。

## 2026-08-07 阶段 18 任务 6.3 启动

- **状态：** `in_progress`；6.2已提交推送为`fb9449d Order visionOS window frame delivery`，fetch确认`HEAD == origin/main == fb9449d0af781d96d9565e76646ab8e63049e807`且工作树clean。OpenSpec为`33/50 ready`、next 6.3。
- **范围：** 探测并接入public visionOS layer/color/headroom capability；只有current finite headroom有实际来源且合同完整时才允许direct EDR，否则继续复用typed HDR-to-SDR。不得创建第二HDR resolver/pipeline、伪造display headroom、提前实现6.4 audio或6.5组合teardown。
- **SDK边界：** XROS 26.4中`CALayer.preferredDynamicRange`、`toneMapMode`、`contentsHeadroom`及legacy CAMetalLayer EDR属性可编译，但`UIScreen`和`UIWindowScene.screen`明确unavailable；layer intent/metadata可用不等于current output headroom有证据。
- **下一步：** 对照4.2/4.3 tvOS实现审计actual visionOS surface owner、capability resolver、HDR surface transaction与coordinator display snapshot注入点，形成最小production/test增量和direct SDK probe证据。
- **系统更新后恢复：** session catchup、长期goal、Git、OpenSpec和工具链已重新核对；当前`HEAD == origin/main == fb9449d0af781d96d9565e76646ab8e63049e807`，工作树仍为6.3的3个production与3个planning文件，`git diff --check`通过，OpenSpec保持`33/50 next 6.3`。实测环境为macOS 27.0 build `26A5388g`、Xcode 26.4 build `17E192`、XROS SDK 26.4、Swift 6.3；两个真实opt-in均unset，继续不查询或操作Simulator lifecycle。
- **恢复后执行顺序：** 先补齐visionOS resolver/snapshot/layer-only observer/coordinator确定性测试并运行fresh focused编译，随后执行direct XROS public API正负probe、fixed Vision Pro unsigned Debug、related、normal和五平台unsigned Debug；全部通过后才同步authority、运行repository gate并勾选6.3。
- **focused失败 1：** fresh `/tmp/LuneX-18-6_3-focused.sDtycY`在测试执行前编译失败；唯一项目错误是两处新增coordinator断言把`await applyDisplay`放入不支持并发的`XCTAssertEqual` autoclosure。production无编译错误、0 tests执行；改为先获取异步outcome再断言，下一轮使用fresh目录。
- **focused验收：** fresh `/tmp/LuneX-18-6_3-focused-r2.nLEOjb/Focused.xcresult`结构化通过`31/31 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`。覆盖visionOS无current headroom fallback、injected finite checked contract、snapshot平台互斥、publisher cross-platform rejection、layer-only observer replacement/detach/invalidate，以及coordinator rebrand/stale/replacement/stop。
- **下一步：** 运行XROS 26.4 public API正负probe与fixed Vision Pro unsigned Debug，确认actual visionOS条件编译和native layer probe；随后related/normal/五平台矩阵。
- **XROS public API probe：** fresh `/tmp/LuneX-18-6_3-xros-probe.KqmYxE`中`preferredDynamicRange`、`toneMapMode`、`contentsHeadroom`、legacy `wantsExtendedDynamicRangeContent`/`edrMetadata`及extended-linear Display P3/ITU-R 2020均warnings-as-errors零诊断；预期负向probe精确确认`UIScreen`与`UIWindowScene.screen`在visionOS unavailable。SDK可用性不等于current compositor headroom或物理HDR证明。
- **fixed Vision Pro build：** fresh `/tmp/LuneX-18-6_3-visionos-direct.1gbruA/VisionOS.xcresult`在固定UUID上unsigned Debug结构化为`succeeded / 0 warning / 0 error / 0 analyzer warning`，生成`1 AIR / 1 metallib`；UUID只作build destination，未操作Simulator lifecycle。
- **源码复核：** actual view在attachment/layout/trait callback统一重采样；visionOS仅以当前window和actual `CAMetalLayer`建立layer-only observer，不注册screen notification，detach/invalidate清owner。native probe的current/potential始终nil，因此实际路径不能产生`.directEDR`；injected finite值只验证共享checked contract。下一步related矩阵。
- **related验收：** fresh `/tmp/LuneX-18-6_3-related.sM3JhP/Related.xcresult`结构化通过`258/258 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`；完整AppModel、SessionMediaEnvironment、TV/Vision state/coordinator、HDR resolver/surface adapter、Metal presenter与vision window/frame回归无损。
- **下一步：** fresh normal完整suite并串行确认唯一允许的显式真实Keychain skip；之后五平台unsigned Debug、authority同步与repository gate。
- **normal验收：** fresh `/tmp/LuneX-18-6_3-normal.culXSh/Normal.xcresult`结构化通过`1082 total / 1081 passed / 1 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`；唯一skip精确为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，两个真实opt-in均unset。
- **下一步：** fresh五平台unsigned Debug串行build；固定UUID只作destination，不查询或操作Simulator lifecycle。
- **五平台build：** fresh `/tmp/LuneX-18-6_3-builds.O6tTU8`中macOS、fixed iPhone/iPad/Apple TV/Vision Pro unsigned Debug全部结构化为`succeeded / 0 warning / 0 error / 0 analyzer warning`且各有`1 AIR / 1 metallib`；固定UUID只作destination，未查询或操作Simulator lifecycle。
- **权威同步：** 已同步OpenSpec design/visionOS media spec、阶段18runtime contract、completion roadmap及三份planning，记录layer-only observer、screen/current-headroom unavailable、平台互斥resolution、typed fallback、fresh测试/probe/build证据和6.4/6.5/7.x/physical/live边界。6.3继续保持pre-mark `33/50 next 6.3`。
- **下一步：** 逐文件production/test/docs diff审计，运行fixture/OpenSpec/generator/membership/privacy/reference/dependency/retained-evidence repository pre-gate；通过后才勾选6.3。
- **repository pre-gate：** fresh `/tmp/LuneX-18-6_3-repository-pre.ioYbts`完整通过fixture self/tree、OpenSpec strict `9/9`、pre-mark `33/50 next 6.3`、三次稳定project SHA-256 `e6a88cd00f4364b7e3a8011841abba9344a9ae3ac1c411e18d1ce426b9b739cb`、精确12文件scope、generator/project membership、layer-only/current-headroom-nil/typed fallback/replacement/invalidation语义、全部retained test/probe/build证据、唯一Keychain skip及privacy/clean-room/reference/dependency/opt-in/process/diff/proof边界。现仅勾选6.3，随后只读post-mark门。
- **状态：** 6.3已有独立实现、审计、行为、SDK和build证据，现已勾选为`complete`。只读post-mark final-state `/tmp/LuneX-18-6_3-final-state.dySg9y`确认strict `9/9`、OpenSpec `34/50 ready`、next 6.4、精确13文件scope、唯一6.3 checkbox替换、稳定project及reference/dependency/config/diff边界；未重复test/build/generator、Keychain、live host或Simulator操作。
- **下一步：** post-record与最终production/test/docs diff审计，通过后精确stage、独立提交并push/fetch核对；阶段18保持`in_progress`，随后启动6.4 visionOS audio。
- **final audit：** `/tmp/LuneX-18-6_3-final-audit.c5MAQz`通过13文件`3 production / 2 test / 8 authority`分类、mutually-exclusive resolution、layer-only observer、native nil-headroom、replacement/stale/detach/invalidate语义、四条focused测试无弱化、唯一6.3 checkbox、OpenSpec `34/50 next 6.4`及privacy/reference/dependency/opt-in/process/project/proof边界。下一步final-record后精确提交推送。
- **final-record：** `/tmp/LuneX-18-6_3-final-record.7lzi44`通过strict `9/9`、`34/50 next 6.4`、最终13文件`3/2/8`分类、五份authority pre/final索引、稳定project/全部retained evidence及implementation/task/privacy/dependency/opt-in/process/proof边界；6.3进入精确stage、提交与推送。

## 2026-08-07 阶段 18 任务 6.4 启动

- **状态：** `in_progress`；系统更新后重新核对长期goal、session catchup、Git与OpenSpec，确认`HEAD == origin/main == 2cb4f95fe855fa6d73bd928f185cfd9253666d21`、工作树clean、OpenSpec为`34/50 ready`且next 6.4，阶段18与长期goal继续`in_progress/active`。
- **范围：** 在既有canonical session-owned audio graph和单一通知源上接入visionOS current-generation ownership、公开`intendedSpatialExperience`读回、实际route capability、interruption、media-services lost/reset recovery、graph replacement与stale rejection；保留tvOS默认兼容行为，不声称不可用的listener head-tracking属性或物理空间音频证明。
- **边界：** 6.5才负责scene/video/HDR/audio/input/diagnostics的完整组合协调，6.6负责综合回归，7.2负责actual-state UI。本任务不创建第二audio graph/notification source，不操作Simulator lifecycle，真实Keychain与live-host opt-in保持unset。
- **首轮focused构建错误：** `/tmp/LuneX-18-6_4-focused.Yh6dWV/Focused.xcresult`在0 tests阶段因新增测试把optional `platformStrategy`与缩写`.none`比较，Swift将其解释为`Optional.none`并以warnings-as-errors拒绝；production没有诊断。已改为显式`SpatialAudioPlatformStrategy.none`，从fresh目录重跑。
- **focused验收：** fresh `/tmp/LuneX-18-6_4-focused-r2.BZF9w4/Focused.xcresult`结构化通过`5/5 passed / 0 skipped / 0 failed / 0 expected failure`，build为`0 warning / 0 error / 0 analyzer warning`。覆盖visionOS fixed/head-tracked intended experience、实际route counts、interruption、media loss/reset、graph/presentation replacement、stale rejection、stop清理及tvOS回归。
- **下一步：** 审计固定平台publisher、platform replacement、event/graph sequence和coordinator application边界，随后运行完整相关类矩阵；两个真实opt-in继续unset且不操作Simulator lifecycle。
- **related验收：** fresh `/tmp/LuneX-18-6_4-related.YQ4rA2/Related.xcresult`结构化通过`182/182 passed / 0 skipped / 0 failed / 0 expected failure`，build warning/error/analyzer warning全零；覆盖完整audio graph/resolver/monitor/processor/recovery与TV/Vision presentation/environment矩阵。
- **XROS/API与direct build：** `/tmp/LuneX-18-6_4-xros-probe.2UK3No`正向确认public intended fixed/head-tracked/bypassed experience零诊断，负向确认listener head-tracking property在visionOS明确unavailable；fixed Vision Pro `/tmp/LuneX-18-6_4-visionos-direct.6wtjPE/VisionOS.xcresult` unsigned Debug通过、结构化diagnostics为0并生成`1 AIR / 1 metallib`。均未运行app或形成物理空间音频证明。
- **normal验收：** fresh `/tmp/LuneX-18-6_4-normal.9YKcpI/Normal.xcresult`结构化通过`1084 total / 1083 passed / 1 skipped / 0 failed / 0 expected failure`，build warnings/errors/analyzer warnings全零；唯一skip精确为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，文件fallback用例通过，两个真实opt-in均unset。
- **五平台build：** fresh `/tmp/LuneX-18-6_4-builds.Vi0CJb`中macOS、fixed iPhone/iPad/Apple TV/Vision Pro unsigned Debug全部`succeeded / 0 warning / 0 error / 0 analyzer warning`且各有`1 AIR / 1 metallib`；固定UUID只作destination，未运行app、查询或操作Simulator lifecycle。
- **权威同步：** 正在同步OpenSpec design/visionOS media spec、阶段18runtime contract、completion roadmap及三份planning，记录共享fixed-platform publisher、单一graph/notification source、public intended experience、actual route counts/support、recovery/replacement/current ownership语义及6.5/6.6/7.2/physical-live边界。6.4保持pre-mark `34/50 next 6.4`。
- **repository包装错误 1：** 首轮 `/tmp/LuneX-18-6_4-repository-pre.xhB4Et` 已通过fixture、strict/apply、三次generator和scope，随后包装器误要求源码使用相等式而实际一致性guard以不等式拒绝不匹配，静态断言退出；未运行或修改test/build/设备，源码无问题。
- **repository包装错误 2：** r2 `/tmp/LuneX-18-6_4-repository-pre-r2.iG7AJG`已进一步通过production/test/docs语义与三份xcresult summary，随后把Xcode 26.4 test tree的skip字段误写成`testStatus`；实际唯一字段为`result: Skipped`且对应真实Keychain用例。修正后fresh重跑。
- **repository包装错误 3：** r3 `/tmp/LuneX-18-6_4-repository-pre-r3.E0P4hK`已通过全部retained test/build/API/Metal检查，残留进程门却自匹配当前shell命令行中的`xcodebuild`字面量并只报告当前PID；没有真实LuneX test/build进程。改用`[x]codebuild`后fresh重跑。
- **repository pre-gate：** fresh `/tmp/LuneX-18-6_4-repository-pre-r4.8oI8VY`完整通过fixture self/tree、OpenSpec strict `9/9`、pre-mark `34/50 next 6.4`、三次稳定project SHA-256 `e6a88cd00f4364b7e3a8011841abba9344a9ae3ac1c411e18d1ce426b9b739cb`、精确11文件scope、membership、平台策略/route-runtime一致性/current ownership/replay/terminal语义、全部retained test/probe/build/Metal、唯一Keychain skip及privacy/reference/dependency/opt-in/process/diff/proof边界。现只勾选6.4。
- **post-mark final-state：** `/tmp/LuneX-18-6_4-final-state.1Gh0gg`只读通过strict `9/9`、OpenSpec `35/50 ready`、6.4 done、next 6.5、稳定project hash、精确12文件scope、唯一6.4 checkbox、retained evidence、disabled opt-ins、无LuneX build进程及reference/dependency/config/diff/proof边界；未重复test/build/generator、Keychain、live host或Simulator操作。
- **post-record包装错误：** 首轮因单行正则跨不过6.5边界换行退出；r2又受`pipefail`下`git diff | rg -q`的预期SIGPIPE影响；r3最后把跨行`task 8.7`当作单行。三轮均只读且未重复test/build/generator/Keychain/Simulator，按实际文本和先落临时diff后fresh重跑。
- **post-record：** corrected fresh `/tmp/LuneX-18-6_4-post-record-r4.onEV9k`通过strict `9/9`、OpenSpec `35/50 next 6.5`、精确12文件`2 production / 2 test / 8 authority`分类、五份authority双门索引、稳定project/retained evidence及opt-in/process/reference/dependency/diff边界。
- **final diff audit：** fresh `/tmp/LuneX-18-6_4-final-audit.ZathRe`通过fixed-platform publisher、tvOS/visionOS策略互斥、route/runtime revision/support一致性、activation/replacement replay、interruption/loss/reset/graph replacement、stale和terminal清理、两条新增测试无弱化、唯一6.4 checkbox及privacy/reference/dependency/opt-in/proof边界。无阻止独立提交的问题。
- **final-record：** `/tmp/LuneX-18-6_4-final-record.0FZsJc`通过strict `9/9`、OpenSpec `35/50 next 6.5`、最终12文件`2/2/8`分类、五份authority四门索引、稳定project/全部retained evidence及implementation/task/privacy/dependency/opt-in/process/proof边界；6.4进入精确stage、独立提交与推送。
- **下一步：** 精确stage、独立提交、push/fetch核对，然后启动6.5。阶段18保持`in_progress`。

## 2026-08-07 阶段 18 任务 6.5 启动

- **状态：** 6.4已提交推送为`7cea28d Connect visionOS audio route runtime`；fetch确认`HEAD == origin/main == 7cea28d6dce479f881e32bb27bc65d5ab8e5b045`且工作树clean，OpenSpec为`35/50 ready`、next 6.5。
- **范围：** 让visionOS actual scene、decoded video、typed HDR fallback、canonical audio、input eligibility、privacy-bounded diagnostics、failure、reconnect、remote termination与clean stop通过同一个current presentation coordinator和共享teardown组合运行；不创建第二surface/decoder/HDR resolver/audio graph/input owner，也不提前实现6.6综合回归或7.2 UI。
- **验收顺序：** 先盘点RootView/AppModel/NativeSessionMediaEnvironment与coordinator当前连接和缺口，再做最小production/test增量；随后fresh focused、related、normal、fixed Vision Pro和五平台unsigned Debug，最后authority/repository/post-mark/commit独立门。
- **证明边界：** 离线组合测试和unsigned build不证明Simulator runtime、signed install、物理Vision Pro窗口/HDR/空间音频/输入、live Sunshine、延迟、comfort、性能、功耗或温度。真实Keychain/live-host opt-in保持unset，不查询或操作Simulator lifecycle。
- **focused验收：** 修正既有window测试的完整`activate -> scene -> input`序列后，smoke `/tmp/LuneX-18-6_5-smoke-r2.sgFzVq/Smoke.xcresult`通过`3/3`；fresh `/tmp/LuneX-18-6_5-focused.4NFpPx/Focused.xcresult`结构化通过`6/6 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`。
- **related验收：** 已串行读取 `/tmp/LuneX-18-6_5-related.ftZGW6/Related.xcresult`，结构化结果为`323/323 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`；覆盖完整AppModel、SessionMediaEnvironment、TV/Vision coordinator/state、vision input、Metal frame/presenter、HDR与空间音频恢复相关类。
- **下一步：** 完成production/test diff并发与teardown审计，然后显式关闭真实Keychain/live-host opt-in运行fresh normal suite、fixed Vision Pro及五平台unsigned Debug；固定UUID只作build destination，不查询或操作Simulator lifecycle。
- **审计修订：** 同surface的display application若在resize/geometry replacement前已排队，旧task会因admission变化正确拒绝，但此前不会把仍有效的display source重排到新geometry。现于新geometry task后按current operation/admission replay同一source，并增加阻塞首个activation的确定性回归；surface generation变化仍先清source。此前focused/related证据降为production修订前中间证据，下一步fresh focused与related。
- **修订后focused：** fresh `/tmp/LuneX-18-6_5-focused-r3.6pazwk/Focused.xcresult`结构化通过`7/7 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`；新增阻塞activation用例确认只有latest geometry/input与current display被提交。下一步fresh related。
- **修订后related：** fresh `/tmp/LuneX-18-6_5-related-r2.lmoqpY/Related.xcresult`结构化通过`324/324 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`。逐函数审计确认replacement、stale platform/source/generation、reconnect replay、display failure、remote/local stop均在current ownership和共享clear路径内。下一步fresh normal。
- **normal验收：** fresh `/tmp/LuneX-18-6_5-normal.CV3Nzw/Normal.xcresult`结构化通过`1088 total / 1087 passed / 1 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`；唯一skip精确为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，两个真实opt-in显式unset，文件fallback继续使用。
- **下一步：** 从既有authority/retained logs读取固定UUID，不查询Simulator；随后fixed Vision Pro direct build与macOS/fixed iPhone/iPad/Apple TV/Vision Pro五平台unsigned Debug。
- **fixed Vision Pro build：** fresh `/tmp/LuneX-18-6_5-visionos-direct.vMBJUC/VisionOS.xcresult`在既有固定UUID上unsigned Debug结构化为`succeeded / 0 warning / 0 error / 0 analyzer warning`，生成`1 AIR / 1 metallib`；仅作build destination，未查询、启动或运行Simulator。
- **五平台build：** fresh `/tmp/LuneX-18-6_5-builds.1uxfoD`中macOS、fixed iPhone/iPad/Apple TV/Vision Pro unsigned Debug全部结构化为`succeeded / 0 warning / 0 error / 0 analyzer warning`，各有`1 AIR / 1 metallib`且Metal日志含`-Werror`；未操作Simulator lifecycle。
- **下一步：** 同步OpenSpec design/spec、阶段18runtime contract、completion roadmap与三份planning，保持pre-mark `35/50 next 6.5`，随后运行repository pre-gate。
- **权威同步：** 已同步OpenSpec design/visionOS media spec、阶段18runtime contract、completion roadmap及三份planning，记录单coordinator组合顺序、same-surface display replay审计修订、fresh `7/324/1088`测试与direct/five-platform build证据，以及6.6/7.2/8.5-8.7与physical/live边界。6.5继续保持pre-mark `35/50 next 6.5`。
- **下一步：** 逐文件final diff审计并运行fixture、OpenSpec strict/apply、三次generator稳定性、membership、实现语义、retained evidence、privacy/reference/dependency/opt-in/process/diff/proof repository pre-gate；通过后才勾选6.5。
- **repository pre-gate：** fresh `/tmp/LuneX-18-6_5-repository-pre.QOi58Z`一次完整通过fixture self/tree、OpenSpec strict `9/9`、pre-mark `35/50 next 6.5`、三次稳定project、精确10文件scope、membership、current platform/input/display/replay/terminal语义、retained `7/324/1088`、direct/five-platform Metal、唯一Keychain skip及privacy/reference/dependency/opt-in/process/diff/proof边界。
- **状态：** 6.5已有独立实现、并发审计、fresh行为/完整回归/跨平台build与repository gate证据，现已仅勾选6.5。下一步只读post-mark final-state，预期`36/50 next 6.6`，不重复test/build/generator、Keychain、live host或Simulator操作。
- **post-mark final-state：** `/tmp/LuneX-18-6_5-final-state.UppBOq`只读通过strict `9/9`、OpenSpec `36/50 ready`、6.5 done、next 6.6、精确11文件scope、唯一6.5 checkbox、稳定project/retained evidence、disabled opt-ins及reference/dependency/process/diff/proof边界；未重复test/build/generator、Keychain、live host或Simulator操作。
- **下一步：** 运行最终`2 production / 1 test / 8 authority` diff审计与final-record；通过后精确stage、独立提交、push/fetch并确认`HEAD == origin/main`和OpenSpec仍为`36/50 next 6.6`。阶段18保持`in_progress`。
- **final diff audit：** `/tmp/LuneX-18-6_5-final-audit.B4HJVK`通过最终11文件`2 production / 1 test / 8 authority`分类、RootView/AppModel平台隔离、input/display顺序、same-surface replay/new-surface clear、reconnect/failure/terminal语义、四条连接测试无弱化、唯一6.5 checkbox及privacy/reference/dependency/opt-in/process/project/proof边界。下一步final-record。
- **final-record：** `/tmp/LuneX-18-6_5-final-record.7HghDO`通过strict `9/9`、`36/50 next 6.6`、最终11文件`2/1/8`分类、五份authority三门索引、稳定project/全部retained evidence及implementation/task/privacy/dependency/opt-in/process/proof边界；6.5进入精确stage、独立提交与推送。

## 2026-08-07 阶段 18 任务 6.6 启动

- **恢复状态：** 6.5已提交并推送为`33cc6fd Coordinate visionOS presentation runtime`；fetch核对`HEAD == origin/main == 33cc6fd7ad0dd4af64a98f46dfd1eec22c69de28`且工作树clean。长期goal保持active，OpenSpec `integrate-tvos-visionos-runtime`为spec-driven `36/50 ready`、next精确为6.6。
- **工具链：** 系统更新后实测macOS 27.0 build `26A5388g`、Xcode 26.4 build `17E192`、Swift 6.3；`LUNEX_RUN_KEYCHAIN_TEST`与`LUNEX_RUN_LIVE_HOST_TEST`均unset，继续使用文件fallback且不再次触发真实Keychain授权。
- **范围：** 盘点并补齐windowed mode、immersive unavailable、frame/render、HDR fallback、spatial route/recovery、AppModel application、replacement、resource release与teardown的连接矩阵。优先test-only增量；只有确定性测试或源码审计暴露production缺陷时才做最小生产修复。
- **验收顺序：** 复读全部OpenSpec context，建立现有覆盖与缺口表；完成focused与相关类矩阵后运行fresh normal、fixed Vision Pro及五平台unsigned Debug；再同步authority，执行repository pre/post-mark/final gates，独立提交、push/fetch核对。
- **设备边界：** 进程只读检查显示环境已有一台非本轮创建的iOS Simulator会话；本任务不查询其identity/state，不创建、启动、安装、运行、关闭或删除任何Simulator。fixed UUID仅在既有证据允许时作build destination，8.5/8.6前不进行Simulator清点或lifecycle操作。
- **证明边界：** 本项只建立离线行为、资源释放与unsigned跨平台构建证据，不替代7.x产品UI/settings/diagnostics、8.4 sanitizer/resource工具门、8.5/8.6 Simulator门、8.7 signed物理Apple TV/Vision Pro与live Sunshine/HDR/空间音频/延迟/功耗/温度证明。
- **覆盖盘点：** 6.1-6.5已有windowed/unavailable值合同、actual Metal owner、bounded FIFO、HDR resolver/observer、vision intended-spatial publisher和AppModel组合接线，但缺少与tvOS 4.6对称的visionOS coordinator全链路序列，以及把同媒体代的visionOS subscription replacement与五项resource tracker释放合并验证的明确门。
- **实现：** 采用test-only增量：新增visionOS window/frame/HDR/spatial/replacement/teardown coordinator矩阵；增强AppModel对完整immersive-unavailable集合、vision HDR fallback和audio graph generation的actual-state断言；扩展vision subscription replacement用例以验证pump/subscription取消、五资源一次释放、terminal state及零active resource。源码审计未发现需修改production的问题。
- **首轮focused：** `/tmp/LuneX-18-6_6-focused.6ahsDg/Focused.xcresult`完成warnings-as-errors编译，AppModel与resource两项通过；coordinator唯一失败是断言期望值`.none`被Swift推断为`Optional.none`，而实际正确为`Optional(SpatialAudioPlatformStrategy.none)`。改为显式类型，只重跑失败用例；该bundle保留为中间诊断，不作最终证据。
- **focused验收：** 修正后单项 `/tmp/LuneX-18-6_6-coordinator-r2.lRMBgb/Coordinator.xcresult`通过；fresh最终 `/tmp/LuneX-18-6_6-focused-final.0pDNP0/Focused.xcresult`结构化通过`3/3 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`。下一步运行完整相关类矩阵。
- **恢复对账：** macOS更新完成后的session catchup、长期goal、Git与OpenSpec复核仍一致：`HEAD == origin/main == 33cc6fd7ad0dd4af64a98f46dfd1eec22c69de28`，精确6文件dirty且`git diff --check`通过；OpenSpec仍为pre-mark `36/50 ready`、next 6.6。没有操作Simulator或访问真实Keychain/live host。
- **related验收：** 保留bundle `/tmp/LuneX-18-6_6-related.PwaltL/Related.xcresult`经当前Xcode 26.4 `xcresulttool`重新结构化读取，10个相关测试类合计`325/325 passed / 0 skipped / 0 failed / 0 expected failure`；build为`succeeded / 0 warning / 0 error / 0 analyzer warning`。下一步运行fresh normal suite。
- **normal验收：** fresh `/tmp/LuneX-18-6_6-normal.dnnNlV/Normal.xcresult`结构化通过`1089 total / 1088 passed / 1 skipped / 0 failed / 0 expected failure`，唯一skip精确为`testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`；build为`succeeded / 0 warning / 0 error / 0 analyzer warning`。两个真实opt-in保持unset，文件fallback路径继续通过；下一步fixed Vision Pro direct及五平台unsigned Debug。
- **build验收：** fixed Vision Pro direct `/tmp/LuneX-18-6_6-visionos-direct.8Muuwq/VisionOS.xcresult`成功；fresh五平台 `/tmp/LuneX-18-6_6-builds.SOVzea`的macOS、fixed iPhone/iPad/Apple TV/Vision Pro全部`succeeded / 0 warning / 0 error / 0 analyzer warning`，每项各有`1 AIR / 1 metallib`。固定UUID只作build destination，未执行Simulator inventory、boot、install或launch。
- **authority同步：** OpenSpec design/visionOS media spec、阶段18 runtime contract、completion roadmap及三份planning记录单coordinator连接序列、subscription/pump/resource释放、fresh evidence和严格proof tier；OpenSpec仍保持pre-mark `36/50 next 6.6`。下一步完整test/diff审计与repository pre-gate，通过后才勾选6.6。
- **repository wrapper错误 1：** 首轮 `/tmp/LuneX-18-6_6-repository-pre.WhdVje`已通过fixture、strict/apply和三次generator后，在生成expected scope时因shell续行漏失把`task_plan.md`当成命令并以127退出；该轮不计验收。项目哈希保持稳定且无源码、任务、测试、Keychain或设备副作用；改用单行参数数组从fresh目录完整重跑。
- **repository wrapper错误 2：** r2 `/tmp/LuneX-18-6_6-repository-pre-r2.0x59Vj`已通过fixture、strict/apply、generator、精确scope、membership/语义、全部retained test/build及隐私/进程边界，最后因design中的`simulator`与`runtime`跨行而未命中单行短语断言；该轮不计最终验收。改为分别断言两个稳定词并从fresh目录完整运行r3。
- **repository wrapper错误 3：** r3 `/tmp/LuneX-18-6_6-repository-pre-r3.rkuqeN`在fixture/OpenSpec后因`eval`包裹的awk双重转义错误退出，generator生成结果仍与基线一致。停止继续修补一体化wrapper；后续改为无`eval`的离散原生命令逐门验收并汇总final evidence，避免第四次重复同类脚本风险。
- **repository pre-gate：** 离散无`eval`门汇总 `/tmp/LuneX-18-6_6-repository-pre-final.f72jUk`完整通过fixture self/tree、strict `9/9`、pre-mark `36/50 next 6.6`、三次稳定generator、精确10文件`3 test / 7 authority`scope、membership/语义、retained `3/325/1089`测试、direct+五平台Metal、唯一Keychain skip及privacy/reference/dependency/opt-in/process/diff/proof边界。现在只勾选6.6。
- **post-mark wrapper错误 1：** `/tmp/LuneX-18-6_6-final-state.En3lJW`已读到`37/50 next 7.1`，但任务diff断言忘记Markdown列表自身的`-`，错误匹配`-[ ]`而实际为`-- [ ]`/`+- [x]`，只读退出且无额外副作用。改为固定完整行匹配后fresh运行r2。
- **post-mark final-state：** corrected `/tmp/LuneX-18-6_6-final-state-r2.3WfaIK`只读通过strict `9/9`、OpenSpec `37/50 ready`、6.6 done、next 7.1、精确11文件`3 test / 8 authority`scope、唯一6.6 checkbox、稳定project/retained evidence、disabled opt-ins及无xcodebuild/xctest进程；未重复test/build/generator、Keychain、live host或Simulator操作。下一步final diff audit与final-record。
- **final diff audit：** `/tmp/LuneX-18-6_6-final-audit.4WLAtW`通过OpenSpec `37/50 next 7.1`、最终11文件`3 test / 8 authority / 0 production`分类、测试声明`+2/-1`（一项重命名加一项新矩阵）、无skip/disable弱化、coordinator/resource/AppModel语义、唯一6.6 checkbox、稳定project/全部retained evidence及proof边界。下一步final-record后独立提交推送。
- **final-record：** `/tmp/LuneX-18-6_6-final-record.35cIbj`通过基线`HEAD == origin/main == 33cc6fd`、strict `9/9`、OpenSpec `37/50 next 7.1`、最终11文件`3/8/0`分类、唯一6.6 checkbox、稳定project、pre/final/audit三门与全部retained evidence及proof边界。6.6进入精确stage、独立提交与推送；阶段18保持`in_progress`。

## 2026-08-07 阶段 18 任务 7.1 启动

- **恢复状态：** session catchup、长期goal、Git与全部OpenSpec context files已复核；`HEAD == origin/main == 1cf40c3c51dad18aca3f77d1f84e025b3b4dbe03`、工作树clean，change为`spec-driven 37/50 ready`且next精确为7.1。
- **缺口：** 当前tvOS stream surface已通过`@FocusState`在overlay隐藏时获得焦点，overlay显示会归还本地导航；但overlay只有Hide Controls、Disconnect、通用pointer/HDR/spatial badge和一条diagnostic，没有统一呈现actual focus/capture/controller/render/HDR/audio与typed bounded failure，也没有显式固定tvOS命令焦点顺序。
- **实现边界：** 新增一个只读纯值`TVStreamControlPresentationState`，只组合现有focus handoff、surface capture owner、controller rosters、platform coordinator video/scene/failure、render policy、HDR fallback和audio route/spatial state；不创建第二session、decoder、renderer、input owner、HDR resolver、audio graph或diagnostics owner。
- **UI合同：** tvOS专用overlay按固定Hide Controls -> Disconnect顺序提供原生可聚焦按钮，并以非嵌套状态行公开Focus、Capture、Controllers、Surface、Render、HDR、Audio、Failure的privacy-bounded value/detail和accessibility label/value；不依赖hover，HDR偏好与actual输出分离。
- **验收顺序：** 先补纯值矩阵、AppModel projection和RootView source contract，运行fresh focused；再运行related、normal、fixed Apple TV direct及五平台unsigned Debug，最后同步authority并执行repository pre/post-mark/final gates，7.1独立提交推送。
- **证明边界：** 本项只证明离线projection/application/source contract与unsigned构建；不提前完成7.2 visionOS controls、7.3 Settings、7.4 diagnostics、7.5 UI总矩阵或8.x Simulator/signed/physical/live/性能证明。真实Keychain/live-host opt-in保持unset，8.5/8.6前不查询或操作Simulator lifecycle。
- **首轮focused：** 保留`/tmp/LuneX-18-7_1-focused.A0mQ3g/Focused.xcresult`结构化结果为`8 total / 7 passed / 1 failed / 0 skipped / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`。唯一失败是source-contract切片从controls struct开始，却检查定义在其前方focus enum内的`case hideControls`；production实现存在且无需修改，测试边界前移后从fresh目录重跑。
- **focused验收：** fresh `/tmp/LuneX-18-7_1-focused-r2.w2xsDG/Focused.xcresult`结构化通过`8/8 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`。日志唯一文本warning为无AppIntents依赖时metadata extraction skipped工具提示，不是Swift/Clang/Metal源码诊断；下一步fixed Apple TV direct unsigned Debug。
- **tvOS编译验收：** fixed Apple TV direct `/tmp/LuneX-18-7_1-tvos-direct.Zs7dNK/tvos.xcresult`对tvOS 26.4 simulator SDK unsigned Debug编译链接成功，结构化为`succeeded / 0 warning / 0 error / 0 analyzer warning`并产出`1 AIR / 1 metallib`；确认tvOS-only Grid/focus/defaultFocus/focusSection API可编译。固定UUID仅作destination，未查询或改变Simulator lifecycle。
- **related验收：** fresh `/tmp/LuneX-18-7_1-related.xgCDkd/Related.xcresult`覆盖12类projection/AppModel/focus/controller/coordinator/render/HDR/spatial/recovery测试，结构化通过`241/241 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`；下一步fresh normal suite。
- **normal验收：** fresh `/tmp/LuneX-18-7_1-normal.e5qCg3/Normal.xcresult`结构化通过`1097 total / 1096 passed / 1 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`；唯一skip精确为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，真实Keychain/live-host opt-in均unset且文件fallback继续通过。下一步五平台unsigned Debug。
- **build验收：** fresh `/tmp/LuneX-18-7_1-builds-r2.KWXQQF`中macOS、fixed iPhone/iPad/Apple TV/Vision Pro unsigned Debug全部结构化为`succeeded / 0 warning / 0 error / 0 analyzer warning`且各有`1 AIR / 1 metallib`；固定UUID仅作build destination，未查询、启动、安装、运行、关闭或删除Simulator。
- **authority同步：** OpenSpec design/tvOS media/tvOS remote、阶段18runtime contract、completion roadmap及三份planning已记录单一actual-state projection、固定row/command顺序、accessibility/privacy/HDR语义、fresh证据与严格proof boundary。OpenSpec保持pre-mark `37/50 next 7.1`，7.2-8.x继续pending；下一步repository pre-gate，通过前不得勾选7.1。
- **repository pre-gate：** fresh `/tmp/LuneX-18-7_1-repository-pre.xR5mQD`完整通过fixture self/tree、strict `9/9`、pre-mark `37/50 next 7.1`、三次稳定project SHA-256 `2c834919e0aebf1b55e4dc7cc764e285753eff32d7d226898e2a1ea8733e2b6e`、精确14文件scope、membership/实现/privacy、retained `8/241/1097`、direct/five-platform Metal及reference/dependency/opt-in/process/diff/proof边界。现在只勾选7.1。
- **post-mark final-state：** `/tmp/LuneX-18-7_1-final-state.1FO4Sy`只读通过strict `9/9`、OpenSpec `38/50 ready`、next 7.2、精确15文件scope、唯一7.1 checkbox、稳定project与全部retained evidence；未重跑test/build/generator或操作Keychain/live host/Simulator。
- **final diff audit：** 最终15文件精确分为`3 production / 1 test / 2 project-generator / 9 authority`；projection current ownership、八行顺序、focus命令顺序、actual HDR fallback、audio/controller/platform fail-closed、accessibility/privacy、无hover、测试无skip/disable弱化、唯一7.1 checkbox及reference/dependency/proof边界均一致。下一步final-record后独立提交推送。
- **final-record：** `/tmp/LuneX-18-7_1-final-record.8piyUo`通过基线`HEAD == origin/main == 1cf40c3`、strict `9/9`、OpenSpec `38/50 next 7.2`、最终15文件分类、唯一7.1 checkbox、稳定project、全部retained evidence、disabled opt-ins与仓库/proof边界。7.1进入精确stage、独立提交与push/fetch。

## 2026-08-08 阶段 18 任务 7.2 启动

- **恢复状态：** 7.1已以`8551620 Add accessible tvOS stream controls`独立提交推送，`HEAD == origin/main == 85516207c7b7d343d2b0ab414bb41953faf368f9`且工作树clean；OpenSpec为`38/50 ready`、next精确7.2，长期goal保持active。
- **现有owner：** visionOS已有current `VisionWindowedPresentationState`、`VisionWindowInputSnapshot`/ownership/release、controller rosters、platform coordinator video/audio/failure、render/HDR/spatial actual state；7.2只读组合这些值，不创建`ImmersiveSpace`、第二surface/decoder/renderer/input owner/HDR resolver/audio graph/coordinator。
- **UI合同：** visionOS overlay固定公开Window、Input、Controllers、Render、HDR、Spatial、Immersive、Failure八行及原生Disconnect命令；actual state、typed immersive-unavailable和desired设置分离，逐行提供accessibility label/value，不依赖hover或原始identity/reason。
- **验收顺序：** 新增纯值projection、AppModel接线、visionOS-only controls、focused value/source-contract tests和generator membership；随后fresh focused、related、normal、fixed Vision Pro direct、五平台unsigned Debug、authority/repository门，7.2独立提交推送。
- **证明边界：** 本项不证明Simulator窗口/输入运行、物理Vision Pro、immersive runtime、HDR亮度、可听空间音频、signed install、live Sunshine、comfort、性能、功耗或温度；7.3-8.x保持pending，真实opt-in继续unset且8.5/8.6前不操作Simulator lifecycle。
- **审计修订：** coordinator windowed state与最新geometry/input admission在replacement窗口可能属于不同代；actual UI projection现要求presentation/surface/input revision、surface generation、input generation和vision controller roster generation/platform一致，否则相关行fail closed，避免拼接两代状态。
- **测试验收：** fresh focused `/tmp/LuneX-18-7_2-focused-r4.TEoRbz/Focused.xcresult`为`10/10 passed`，related `/tmp/LuneX-18-7_2-related.uFebig/Related.xcresult`为`235/235 passed`，fresh normal `/tmp/LuneX-18-7_2-normal.NqSJtS/Normal.xcresult`为`1107 total / 1106 passed / 1 skipped / 0 failed`；三者build diagnostics全零，唯一skip精确为显式opt-in真实Keychain测试，真实Keychain/live-host变量保持unset。
- **五平台build验收：** 系统更新后续接既有会话并完成 `/tmp/LuneX-18-7_2-builds.ewkEpO`；macOS、fixed iPhone/iPad/Apple TV/Vision Pro五个unsigned Debug `.xcresult`分别为`succeeded / 0 warning / 0 error / 0 analyzer warning`且各有`1 AIR / 1 metallib`。未重复启动构建，固定UUID仅作build destination，没有查询或操作Simulator lifecycle。
- **下一步：** 完成最终diff与generator稳定性审计，同步authority并执行OpenSpec strict/repository pre-gate；通过前7.2继续保持未勾选。当前证据不构成Simulator runtime、signed artifact、physical Vision Pro HDR/空间音频/输入、live Sunshine或性能/功耗/comfort证明。
- **authority同步：** OpenSpec design/visionOS media/input specs、阶段18runtime contract、completion roadmap及三份planning已记录单一current projection、八行顺序、revision/generation/platform fail-closed、accessibility/privacy语义、fresh evidence与严格proof boundary。OpenSpec保持pre-mark `38/50 next 7.2`，7.3-8.x继续pending；下一步repository pre-gate，通过前不得勾选7.2。
- **repository pre-gate：** fresh `/tmp/LuneX-18-7_2-repository-pre-r3.kVhSoZ`完整通过fixture self/tree、strict、pre-mark `38/50 next 7.2`、两次稳定project SHA-256 `5a601000c3310b872063caf13122baa82f8da85a310ff39ccb27f5265c0db47e`、精确14文件scope、membership/current ownership/accessibility/privacy语义、retained `10/235/1107`测试、五平台Metal及reference/dependency/opt-in/process/diff/proof边界。现仅勾选7.2。
- **post-mark final-state：** `/tmp/LuneX-18-7_2-final-state.McIoFj`只读通过strict、OpenSpec `39/50 ready`、next 7.3、精确15文件scope、唯一7.2 checkbox、稳定project/retained evidence、disabled opt-ins及仓库/proof边界；未重跑generator/test/build或操作Keychain、live host、Simulator。
- **final diff audit：** corrected `/tmp/LuneX-18-7_2-final-audit-r2.BWKb1R`通过最终15文件`3 production / 1 test / 2 project-generator / 9 authority`分类、production零删除、10项新增测试无skip/disable、current ownership/revision/platform fail-closed、八行顺序、accessibility/privacy、唯一7.2 checkbox及reference/dependency/opt-in/process/project/proof边界。下一步final-record。
- **final-record：** `/tmp/LuneX-18-7_2-final-record.ucyqir`通过基线`HEAD == origin/main == 8551620`、strict、OpenSpec `39/50 next 7.3`、最终15文件分类、唯一7.2 checkbox、稳定project、pre/final/audit三门、全部retained evidence及disabled opt-in/proof边界。7.2进入精确stage、独立提交与push/fetch；阶段18保持`in_progress`。

## 2026-08-08 阶段 18 任务 7.3 启动

- **恢复状态：** 7.2已以`534c68a Add accessible visionOS stream controls`独立提交推送，fetch确认`HEAD == origin/main == 534c68ae45ef3ac7587872ce86ff897ae39c8634`且工作树clean；OpenSpec为`39/50 ready`、next精确7.3。
- **盘点结论：** 现有Settings已持久化render fit/fill、HDR enabled、spatial enabled/head tracking及macOS/iOS专用input选项，并显示通用actual HDR/spatial；tvOS/visionOS缺平台能力投影，且不能新增runtime不执行的input/controller伪开关。
- **实现边界：** 新增只读`TVVisionPlatformSettingsPresentationState`固定投影Input、Controllers、Render、HDR、Spatial五项。Input/Controllers显示现有自动current-generation行为与actual state，Render/HDR/Spatial复用已有可编辑偏好并并列实际状态；不新增runtime owner、设置字段、诊断owner或7.4/7.5行为。
- **UI合同：** tvOS/visionOS Settings使用`Desired behavior`与`Current state`分栏语义、逐项accessibility label/value和平台actual row；不显示unsupported relative-mouse/system-shortcut/virtual-controller开关。macOS/iOS路径保持现有控件。
- **验收顺序：** 纯值/AppModel/source-contract focused测试，随后related、normal、fixed tvOS/visionOS direct及五平台unsigned Debug，再同步authority与repository pre/post-mark/final gates。真实opt-in保持unset，8.5/8.6前不操作Simulator lifecycle。
- **首轮focused：** `/tmp/LuneX-18-7_3-focused.C9Bsu5`在测试执行前因fixture引用不存在的`VisionPresentationUnavailableReason.publicAPIUnavailable`编译失败；production无诊断。改为已有typed `.stage18WindowedOnly`并从fresh bundle重跑，该失败bundle不计验收。
- **focused验收：** fresh `/tmp/LuneX-18-7_3-focused-r2.bz5JHc/Focused.xcresult`结构化通过`8/8 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`。
- **平台编译：** fixed Apple TV与Vision Pro direct `/tmp/LuneX-18-7_3-direct.J396Zs`两个unsigned Debug均结构化零诊断成功且各有`1 AIR / 1 metallib`；固定UUID仅作build destination，未查询或操作Simulator lifecycle。下一步related矩阵。
- **related验收：** fresh `/tmp/LuneX-18-7_3-related.borVj3/Related.xcresult`覆盖8类platform settings、tv/vision actual controls、AppModel、设置迁移、HDR、spatial与media preference测试，结构化为`164 total / 163 passed / 1 skipped / 0 failed / 0 expected failure`且build四类diagnostics为0；唯一skip精确为显式真实Keychain round-trip。下一步fresh normal。
- **normal验收：** fresh `/tmp/LuneX-18-7_3-normal.nbTbVF/Normal.xcresult`结构化通过`1115 total / 1114 passed / 1 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`；唯一skip精确为显式真实Keychain round-trip，两个真实opt-in均unset。下一步五平台unsigned Debug。
- **五平台build：** fresh `/tmp/LuneX-18-7_3-builds.1DhVeP`中macOS、fixed iPhone/iPad/Apple TV/Vision Pro unsigned Debug全部结构化为`succeeded / 0 warning / 0 error / 0 analyzer warning`且各有`1 AIR / 1 metallib`；固定UUID仅作destination，未查询或操作Simulator lifecycle。下一步authority与repository门。
- **authority同步：** OpenSpec design及tvOS/visionOS四份media/input specs、阶段18runtime contract、completion roadmap与三份planning已记录automatic input/controller policy、现有editable preference复用、desired/actual分离、五项固定顺序、accessibility/privacy、fresh evidence与proof boundary。OpenSpec保持pre-mark `39/50 next 7.3`，7.4-8.x继续pending。
- **repository pre-gate：** fresh `/tmp/LuneX-18-7_3-repository-pre.gu3Wdy`一次完整通过fixture self/tree、strict、pre-mark `39/50 next 7.3`、稳定project SHA-256 `aee5f8cb55fffe616537d30eb933012a068658cea6e67ac48d06c3b236d8ed5e`、精确16文件scope、membership/desired-actual/platform/accessibility/privacy语义、retained `8/164/1115`测试、direct+五平台Metal及reference/dependency/opt-in/process/diff/proof边界。现仅勾选7.3。
- **post-mark final-state：** `/tmp/LuneX-18-7_3-final-state.8JTYco`只读通过strict、OpenSpec `40/50 ready`、next 7.4、精确17文件scope、唯一7.3 checkbox、稳定project/retained evidence、disabled opt-ins及仓库/proof边界；未重跑generator/test/build或操作Keychain、live host、Simulator。
- **final diff audit：** `/tmp/LuneX-18-7_3-final-audit.MXE9J2`一次通过最终17文件`3 production / 1 test / 2 project-generator / 11 authority`分类、production零删除、8项测试无弱化、AppSettings schema不变、mixed-platform fail-closed、automatic policy/desired-actual/UI accessibility、唯一7.3 checkbox及全部仓库/proof边界。下一步final-record。
- **final-record：** `/tmp/LuneX-18-7_3-final-record.oIJ6c8`通过基线`HEAD == origin/main == 534c68a`、strict、OpenSpec `40/50 next 7.4`、最终17文件分类、唯一7.3 checkbox、稳定project、三道gate、retained evidence及disabled opt-in/proof边界。7.3进入精确stage、独立提交与push/fetch。

## 2026-08-08 阶段 18 任务 7.4 启动

- **恢复状态：** 7.3已以`7d4452f Add platform-aware stream settings`独立提交推送，当前`HEAD == origin/main`且工作树clean；系统更新后工具链为macOS 27.0、Xcode 26.4、Swift 6.3，OpenSpec为`40/50 ready`、next精确7.4。
- **实现边界：** 复用唯一`DiagnosticsStore`，增加opaque replacement lease、单调revision与语义去重、同revision冲突/低revision/旧owner fail-closed、lease-owned actionable recovery、全局有限history及安全export；不复制coordinator、session UUID或generation ownership。
- **接线路径：** `AppModel`只在current coordinator state通过既有session/media/platform/ownership检查后记录固定platform diagnostic，并在replacement/failure/stop runtime clear时失效lease；Diagnostics页面只导出二次脱敏文本。
- **验收顺序：** 先补store值合同、AppModel/application与UI source测试并跑fresh focused，再跑related、normal、fixed Apple TV/Vision Pro direct和五平台unsigned Debug，随后同步authority与repository pre/post-mark/final gates；通过前不得勾选7.4或实现7.5+。
- **证明边界：** 本项只证明确定性diagnostic ownership/dedup/redaction、应用接线、SwiftUI条件编译和unsigned build；不证明Simulator runtime、signed artifact、物理输入/HDR/空间音频、live Sunshine、性能、功耗或温度。真实opt-in保持unset且不操作Simulator lifecycle。
- **首轮focused错误：** `/tmp/LuneX-18-7_4-focused.j34RyA`编译成功并通过全部新增行为测试，唯一失败是source-contract三条完整字符串不容忍Swift自动换行；同时指定的AppModel测试名不存在，因此未执行。修正为稳定token及真实`testVisionPresentationCoordinatesCurrentMediaReconnectAndRemoteStop`后必须从fresh evidence目录重跑，失败bundle不作为验收证据。
- **第二轮focused错误：** `/tmp/LuneX-18-7_4-focused-r2.XeVLuB`为`30 total / 29 passed / 1 failed`；实际AppModel测试和全部行为测试通过，唯一source-contract失败发现Export toolbar因宽泛`List`锚点误挂Host Library。精确移到`DiagnosticsView`后第三次fresh重跑，前两份bundle均不作为最终验收。
- **focused验收：** 修正toolbar归属后的fresh `/tmp/LuneX-18-7_4-focused-r3.Dyv0SO/Focused.xcresult`由当前Xcode结构化确认`31/31 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`。下一步逐函数审计production ownership/redaction，再运行related矩阵。
- **审计修复：** production审计发现非平台runtime后来重申完全相同action时，current事件虽正确去重但平台lease ownership未撤销，后续平台recovery可能误清该action。增量修复仅撤销相同非平台重申事件的lease ownership并补精确回归；修复后需fresh重跑focused，r3降为修复前辅助证据。
- **最终focused：** fresh `/tmp/LuneX-18-7_4-focused-r4.1USmAU/Focused.xcresult`结构化通过`32/32 passed / 0 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`且生成`1 AIR / 1 metallib`。修复后的store/AppModel/UI合同成立，下一步8类related矩阵。
- **related验收：** fresh `/tmp/LuneX-18-7_4-related.9efE6X/Related.xcresult`覆盖diagnostics、完整AppModel workflow、platform coordinator/control/settings、HDR与spatial八类，结构化通过`152/152 passed / 0 skipped / 0 failed / 0 expected failure`，build diagnostics全零且有`1 AIR / 1 metallib`。下一步fresh normal suite。
- **normal验收：** fresh `/tmp/LuneX-18-7_4-normal.AHM4Rr/Normal.xcresult`结构化通过`1122 total / 1121 passed / 1 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`且有`1 AIR / 1 metallib`。并行读取skipped节点时`xcresulttool`发生内部临时数据库同名移动冲突；测试bundle本身完整，改为串行只读确认唯一skip，不重跑测试。
- **Keychain边界：** 串行读取normal tests tree确认唯一skip精确为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，failure message要求显式`LUNEX_RUN_KEYCHAIN_TEST=1`；本轮保持unset并继续使用文件fallback，live-host opt-in同样unset。
- **tvOS API修复：** 首轮fixed Apple TV direct `/tmp/LuneX-18-7_4-direct.VH3uKS/tvOS.xcresult`在RootView以2个Swift error失败，精确为`ShareLink`和initializer在tvOS unavailable；Metal已生成但该bundle不作验收，串行脚本因此未开始visionOS。修复为tvOS可访问disabled unavailable状态，其他平台保留真实ShareLink，并补source-contract后从fresh目录重跑focused与direct。
- **修复后focused：** fresh `/tmp/LuneX-18-7_4-focused-r5.wyn9qr/Focused.xcresult`结构化通过`32/32`、零skip/failure/expected failure，build diagnostics全零且有`1 AIR/1 metallib`；source contract现同时锁定tvOS unavailable状态和非tvOS真实ShareLink。下一步fresh direct双平台。
- **direct验收：** fresh `/tmp/LuneX-18-7_4-direct-r2.2mQR5s`中的fixed Apple TV与Vision Pro unsigned Debug均结构化为`succeeded / 0 warning / 0 error / 0 analyzer warning`且各生成`1 AIR / 1 metallib`；固定UUID只作build destination，未查询或操作Simulator lifecycle。首次Metal计数误用了不存在的`tvOS-derived`/`visionOS-derived`路径，随后改读实际`*-DerivedData`目录并确认产物，无需重跑成功构建。下一步fresh五平台unsigned Debug。
- **五平台build：** fresh `/tmp/LuneX-18-7_4-builds.HlcDxq`中的macOS、fixed iPhone/iPad/Apple TV/Vision Pro unsigned Debug全部结构化为`succeeded / 0 warning / 0 error / 0 analyzer warning`且各生成`1 AIR / 1 metallib`；固定UUID只作destination，未查询或操作Simulator lifecycle。下一步最终production/test diff审计、authority同步与repository pre-gate。
- **authority同步：** OpenSpec design及tvOS/visionOS四份media/input specs、阶段18runtime contract、completion roadmap与三份planning已记录单store、opaque lease、revision/semantic dedup、replacement、non-platform ownership preservation、finite history、二次脱敏export、tvOS unavailable状态、fresh证据与严格proof boundary。7.4保持pre-mark `40/50 next 7.4`，下一步repository pre-gate，通过前不得勾选。
- **repository包装错误：** 首个编排脚本在shell执行前因JavaScript局部变量使用严格模式保留字`package`而拒绝；随后partial `/tmp/LuneX-18-7_4-repository-pre.0bdh5m`通过fixture、strict/apply与三次稳定generator，但scope门使用macOS Bash 3.2不支持的`mapfile`而退出。两次均无源码、测试、构建、Keychain或Simulator副作用；改用兼容数组语法从fresh目录完整重跑，partial不计最终验收。
- **repository收尾错误：** corrected r2 `/tmp/LuneX-18-7_4-repository-pre-r2.UzOB0F`已通过fixtures、strict/apply、三次稳定generator、15文件scope、membership/static、retained test/build/Metal/固定UUID；最终文档边界断言因Markdown反引号在shell双引号内触发命令替换而退出。不是实现或证据失败；改为不依赖格式字符的只读收尾，不重复generator/test/build。
- **repository收尾错误 2：** 修正格式断言后的只读收尾通过parity/opt-in/process并确认changed reference/dependency边界为空，随后因使用不存在的ENet许可摘要短语退出；实际vendored MIT文件包含`Permission is hereby granted`。改为校验真实license文本继续收尾，不重复已通过门。
- **repository pre-gate：** corrected `/tmp/LuneX-18-7_4-repository-pre-r2.UzOB0F`完整通过fixture self/tree、OpenSpec strict `9/9`、pre-mark `40/50 next 7.4`、三次稳定generator SHA-256 `aee5f8cb55fffe616537d30eb933012a068658cea6e67ac48d06c3b236d8ed5e`、精确15文件scope、membership/lease/dedup/recovery/export/tvOS availability语义、retained `32/152/1122`测试、direct/五平台build与Metal、唯一Keychain skip及privacy/reference/dependency/opt-in/process/diff/proof边界。现在仅勾选7.4，7.5+继续pending。
- **post-mark final-state：** `/tmp/LuneX-18-7_4-final-state.VaTcq9`只读通过strict、OpenSpec `41/50 ready`、next 7.5、精确16文件scope、唯一7.4 checkbox、稳定project/retained evidence、disabled opt-ins与无LuneX残留构建进程；未重跑generator/test/build或操作Keychain、live host、Simulator。下一步final diff audit与final-record。
- **final diff audit：** `/tmp/LuneX-18-7_4-final-audit.p2Anhn`通过最终16文件`3 production / 2 test / 11 authority`分类、production唯一删除仅为原`append`签名替换、7项新增测试及AppModel现有workflow扩展无弱化、lease/revision/non-platform ownership/history/export/tvOS availability语义、唯一7.4 checkbox及仓库/proof边界。下一步final-record后精确stage、提交和push/fetch。
- **final-record：** `/tmp/LuneX-18-7_4-final-record.k0tqwb`通过基线`HEAD == origin/main == 7d4452f`、strict、OpenSpec `41/50 next 7.5`、最终16文件分类、唯一7.4 checkbox、稳定project、三道final gate、全部retained evidence及disabled opt-in/process/proof边界。7.4进入精确stage、独立提交与push/fetch。

## 2026-08-08 阶段 18 任务 7.5 启动

- **恢复状态：** 7.4已以`cbf2a28 Add privacy-bounded platform diagnostics`独立提交推送，fetch确认`HEAD == origin/main == cbf2a2828fed0422719622dde74a6729861c4d0a`且工作树clean；OpenSpec为`41/50 ready`、next精确7.5。
- **范围：** 审计并补齐tvOS focus/navigation、visionOS window/input、compact/wide layout、localization、accessibility、actual-state、command、migration与clean-stop的应用层连接回归；优先test-only，只有测试暴露真实缺陷才做最小production修复，不提前执行8.1+。
- **边界：** 真实Keychain/live-host opt-in继续unset，正常测试使用文件fallback；8.5/8.6前不查询、创建、启动、关闭或删除Simulator，固定UUID仅可作build destination。unsigned/offline证据不构成signed、physical、live或性能证明。
- **错误记录：** 首个focused目录`/tmp/LuneX-18-7_5-focused.EeIfNy`在编译前因命令误用不存在的`LuneX` scheme退出65；未运行测试、Keychain、live host或Simulator。后续先读取工程scheme并改用真实名称，不重复该命令。
- **focused r2发现：** `/tmp/LuneX-18-7_5-focused-r2.j3Ye40`完成编译，32项中31项通过；唯一失败证明`AppModel.visionStreamControlPresentationState`把coordinator重标后的current window presentation与旧geometry-source revision做整对象相等，导致完整current状态错误投影为window/input unavailable。应从已验证current coordinator的同步presentation组装UI snapshot，同时继续由实际input owner决定capture并保持replacement/stale fail-closed。
- **focused r4断言修正：** `/tmp/LuneX-18-7_5-focused-r4.66EBzs`中既有32项继续通过，新增`testVisionWindowedPresentationReportsOnlyCurrentOwnership`失败；该fixture故意只有windowed contract、没有同步scene/input/display/audio presentation，UI保持unavailable才正确。将断言改为部分状态不得冒充actual visible/captured，不修改production。
- **direct编译错误：** 首轮`/tmp/LuneX-18-7_5-direct.z0BcBh`的tvOS在`LabeledContent(_:value:)`拒绝`LocalizedStringResource`时以1个Swift error退出，Vision未开始；改用label/content closure内`Text(content.desiredValue)`，不改变展示语义，从fresh目录重跑。
- **实现与真实缺陷修复：** tvOS/visionOS controls及平台Settings的固定展示字段改为`LocalizedStringResource`，数量插值保留在资源路径；SwiftUI改用本地化`Text`/`Label`和显式accessibility值。新增`TVVisionStreamControlsLayout`，compact size class或accessibility Dynamic Type使用纵向布局，其他使用wide grid并由`ViewThatFits`回退。visionOS UI只从已验证current coordinator取得同步scene/input presentation，要求matching ownership/revision/surface generation，capture仍来自实际input owner，partial/stale/replacement仍fail closed。
- **retained focused/direct：** `/tmp/LuneX-18-7_5-focused-r6.MlK4I5/Focused.xcresult`为`33/33 passed / 0 skipped / 0 failed / 0 expected failure`，build diagnostics全零且有`1 AIR/1 metallib`；`/tmp/LuneX-18-7_5-direct-r2.l0qZ4X`中fixed Apple TV与Vision Pro均unsigned Debug零结构化diagnostics成功并各有`1 AIR/1 metallib`。
- **retained related/normal：** `/tmp/LuneX-18-7_5-related.UQqYF6/Related.xcresult`为`217/216/1/0`，`/tmp/LuneX-18-7_5-normal.9MVpwm/Normal.xcresult`为`1123/1122/1/0`；两者唯一skip均精确是显式真实Keychain round-trip，两个真实opt-in unset且文件fallback继续使用。normal只计7.5回归，不提前勾选8.1。
- **retained五平台与generator：** `/tmp/LuneX-18-7_5-builds.g4vZQT`中macOS、fixed iPhone/iPad/Apple TV/Vision Pro unsigned Debug均`succeeded / 0 warning / 0 error / 0 analyzer warning`并各有`1 AIR/1 metallib`；generator before/after SHA-256均为`aee5f8cb55fffe616537d30eb933012a068658cea6e67ac48d06c3b236d8ed5e`。固定UUID只作destination，未查询或操作Simulator lifecycle。
- **authority同步：** design、四份platform spec、阶段18runtime contract、completion roadmap及三份planning已记录本地化资源、compact/wide、tvOS focus/command、visionOS synchronized projection、partial/replacement/stale fail-closed、migration/clean-stop、retained evidence和proof boundary；OpenSpec仍保持pre-mark`41/50 next 7.5`，下一步运行repository pre-gate。
- **repository编排错误：** 首个7.5 pre-gate的JavaScript模板包含shell `${...}`环境变量展开，工具在任何shell启动前以`SyntaxError: Unexpected token '}'`退出；未创建证据目录、运行测试/build、修改仓库或操作Simulator。改为`env`管道检查并从fresh证据目录启动完整门。
- **repository静态断言错误：** 第二轮`/tmp/LuneX-18-7_5-repository-pre.4pgNSf`已通过fixture、OpenSpec `9/9`/`41/50`、三次稳定generator、20文件scope与diff-check，随后在测试证据读取前因迁移测试断言使用不存在的token `legacyAudioSettings`无输出退出；真实测试以`legacyObject.removeValue(forKey: "audio")`构造旧schema。修正只读断言并从fresh目录完整重跑，不修改production/test或重复测试/build。
- **repository authority断言错误：** r2 `/tmp/LuneX-18-7_5-repository-pre-r2.rWu1dV`再次通过全部前置门后，在retained证据读取前因循环要求`design.md`包含具体`/tmp`证据路径而退出；design按既有模式记录语义和proof tier，具体路径由runtime contract、roadmap与planning索引。此前对跨行proof短语的初步判断不是实际退出点。缩小路径断言到真实证据索引文件，并把proof检查拆成稳定token后从fresh目录完整重跑。
- **repository pre-gate：** corrected `/tmp/LuneX-18-7_5-repository-pre-r3.1O8JBJ`完整通过fixture self/tree、OpenSpec strict `9/9`、pre-mark `41/50 next 7.5`、三次稳定generator、精确20文件scope、membership/localization/layout/focus/current projection/migration/privacy静态合同、retained focused/related/normal/direct/五平台build与Metal、唯一Keychain skip及reference/dependency/opt-in/process/diff/proof边界；现在只勾选7.5，8.1+保持pending。
- **post-mark final-state：** `/tmp/LuneX-18-7_5-final-state.cb0UO9`只读通过OpenSpec strict `9/9`、`42/50 next 8.1`、精确21文件scope、唯一7.5 checkbox、稳定project/retained evidence、disabled opt-ins与无残留构建进程；未重跑generator/test/build或操作Keychain、live host、Simulator。下一步final diff audit与final-record。
- **final-audit断言错误：** 首轮`/tmp/LuneX-18-7_5-final-audit.L2aaaO`因把所有删除的`XCTAssert`视为测试弱化而退出；本次`String`到`LocalizedStringResource`迁移必然以删除旧直接断言、增加`localized(resource)`等价断言呈现。实际为69条新增断言对37条删除断言、1个新增测试函数、0个删除测试函数且无skip/disable。改为无测试函数删除、断言总量不下降和无skip/disable门，从fresh目录重跑。
- **final diff audit：** corrected `/tmp/LuneX-18-7_5-final-audit-r2.7dsVBW`通过最终21文件`5 production / 5 test / 6 OpenSpec / 2 docs / 3 planning`分类、69新增/37迁移删除断言、1新增/0删除测试函数、无skip/disable、localization/layout/current coordinator projection实现、唯一7.5 checkbox及project/reference/dependency/opt-in/process/proof边界。下一步final-record后精确stage、提交和push/fetch。
- **final-record：** `/tmp/LuneX-18-7_5-final-record.fepytG`通过基线remote parity、strict `9/9`、`42/50 next 8.1`、最终21文件分类、唯一7.5 checkbox、稳定project、三道final gate、全部retained evidence、disabled opt-ins与proof boundary。7.5进入精确stage、独立提交与push/fetch。
- **提交与8.1启动：** 7.5已以`9ca6c12 Add adaptive localized TV and Vision controls`提交推送，fetch确认`HEAD == origin/main == 9ca6c120c2de3fc2e0598281246d86403a5dfa77`且工作树clean；OpenSpec为`42/50 next 8.1`。8.1将从fresh目录运行完整normal suite，显式移除真实Keychain/live-host opt-in并验证唯一skip，不复用7.5 normal作为8.1完成证据，也不操作Simulator lifecycle。
- **fresh normal：** `/tmp/LuneX-18-8_1-normal.GjIqrj/Normal.xcresult`结构化通过`1123 total / 1122 passed / 1 skipped / 0 failed / 0 expected failure`；唯一skip精确为`testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，build为`succeeded / 0 warning / 0 error / 0 analyzer warning`并有`1 AIR/1 metallib`。命令显式移除两个真实opt-in、继续文件fallback且未操作Simulator。
- **authority同步：** design、阶段18runtime contract、completion roadmap与三份planning已记录8.1必须使用fresh normal、唯一Keychain skip、文件fallback、零diagnostics/Metal及严格proof boundary；OpenSpec仍保持pre-mark`42/50 next 8.1`，下一步repository pre-gate。
- **repository authority断言错误：** 首轮`/tmp/LuneX-18-8_1-repository-pre.qbRDTl`已通过fixtures、strict/apply、三次稳定generator、精确6文件scope及fresh normal test/skip/build/Metal结构化读取，随后因循环要求`design.md`出现固定`fresh normal`短语而退出；design使用等价`new complete macOS normal-suite run`并正确记录file fallback/proof tier，具体路径由runtime contract、roadmap与planning索引。按职责拆分语义与路径断言后fresh完整重跑，不重复normal。
- **repository pre-gate：** corrected `/tmp/LuneX-18-8_1-repository-pre-r2.gPOMhm`完整通过fixtures、strict `9/9`、pre-mark `42/50 next 8.1`、三次稳定generator、精确6个authority文件、fresh normal `1123/1122/1/0`、唯一Keychain skip、build `succeeded/0/0/0`与`1 AIR/1 metallib`、disabled opt-ins/file fallback及全部仓库/proof边界；现在只勾选8.1，8.2+保持pending。
- **post-mark final-state：** `/tmp/LuneX-18-8_1-final-state.uybdfA`只读通过strict `9/9`、`43/50 next 8.2`、精确7个authority文件、唯一8.1 checkbox、稳定project/normal/pre-gate、disabled opt-ins与无残留构建进程；未重复generator/normal或操作Simulator。下一步final audit/record。
- **final audit：** `/tmp/LuneX-18-8_1-final-audit.fk0oho`通过7个authority文件/零production-test diff、唯一8.1 checkbox、strict `9/9`、`43/50 next 8.2`、normal/pre/post证据、project/reference/dependency、disabled opt-ins/process及proof边界；下一步final-record。
- **final-record：** `/tmp/LuneX-18-8_1-final-record.w4fV2U`通过基线remote parity、strict `9/9`、`43/50 next 8.2`、7个authority文件、唯一8.1 checkbox、fresh normal/pre/post/audit、稳定project/reference/dependency、disabled opt-ins和proof boundary；8.1进入独立提交推送。
- **提交与8.2启动：** 8.1已以`97e932a Verify complete normal test suite`提交推送，fetch确认`HEAD == origin/main == 97e932af8857022f9df653536dd5b5981445e1f9`且工作树clean；OpenSpec为`43/50 next 8.2`。8.2顺序执行macOS、fixed iPhone/iPad/Apple TV/Vision Pro的Debug/Release十项isolated unsigned warnings-as-errors build，固定UUID只作destination，不查询或操作Simulator lifecycle。
- **fresh十项矩阵：** `/tmp/LuneX-18-8_2-builds.Dvqg9S`中macOS、fixed iPhone/iPad/Apple TV/Vision Pro的Debug/Release全部结构化为`succeeded / 0 warning / 0 error / 0 analyzer warning`并各有`1 AIR/1 metallib`；每项独立DerivedData/log/xcresult，固定UUID只作destination，未执行Simulator lifecycle。
- **authority同步：** design、阶段18runtime contract、completion roadmap与三份planning已记录十项isolated warnings-as-errors构建、当前commit、Metal工件和unsigned/proof边界；OpenSpec仍保持pre-mark`43/50 next 8.2`，下一步repository pre-gate。
- **repository pre-gate：** `/tmp/LuneX-18-8_2-repository-pre.GRQL3w`完整通过fixtures、strict `9/9`、pre-mark`43/50 next 8.2`、三次稳定generator、精确6个authority文件、十项`succeeded/0/0/0`、`10 AIR/10 metallib`、disabled opt-ins/process及全部仓库/proof边界；现只勾选8.2，8.3+保持pending。
- **post-mark final-state：** `/tmp/LuneX-18-8_2-final-state.tVJVek`只读通过strict `9/9`、`44/50 next 8.3`、7个authority文件、唯一8.2 checkbox、稳定project/build/pre-gate、disabled opt-ins与无残留构建进程；未重复generator/build或操作Simulator。下一步final audit/record。
- **final audit：** `/tmp/LuneX-18-8_2-final-audit.WMG1HZ`通过7个authority文件/零production-test、唯一8.2 checkbox、strict `9/9`、`44/50 next 8.3`、十项build/pre/post、稳定project/reference/dependency、disabled opt-ins/process及proof边界；下一步final-record。
- **final-record：** `/tmp/LuneX-18-8_2-final-record.hv5iVY`通过基线remote parity、strict `9/9`、`44/50 next 8.3`、7个authority文件、唯一8.2 checkbox、十项build/pre/post/audit、稳定project/reference/dependency、disabled opt-ins与proof boundary；8.2进入独立提交推送。
- **提交与8.3启动：** 8.2已以`390db08 Verify five-platform build matrix`提交推送，fetch确认`HEAD == origin/main == 390db08989669c703b3a6fb47ed1384b13da5158`且工作树clean；OpenSpec为`44/50 next 8.3`。8.3执行fresh strict、fixture、generator、membership、clean-room/reference/license、entitlement/configuration、privacy、API availability、analyzer与repository boundary gates，不操作Simulator lifecycle。
- **8.3 analyzer/generator进行中：** fresh `/tmp/LuneX-18-8_3-analyzer.1Edacz`的macOS Debug/Release Analyze均`succeeded/0 error/0 compiler warning/4 identical fixed ENet findings`且first-party/bridge为0；`/tmp/LuneX-18-8_3-repository-pre.1yCWep`的生成前及三次generator哈希均为`aee5f8c...d5e`且无工程diff。验收包装器发生一次JS模板`${...}`预解析和一次`awk`转义错误，均只修正已保留证据汇总、未重跑成功action。下一步完成8.3 repository pre-gate；task仍未勾选。
- **8.3 repository pre-gate：** `/tmp/LuneX-18-8_3-repository-pre.1yCWep`完整通过fixtures、strict `9/9`、pre-mark `44/50 next 8.3`、generator/membership、clean-room/reference/18-file ENet pin/license、entitlement/configuration、privacy/forbidden API、retained public API probe、四SDK strict bridge/vendor compile、fresh analyzer与全部Git/process/opt-in/proof边界；未操作Simulator lifecycle。
- **8.3 authority同步：** design、阶段18runtime contract、completion roadmap与三份planning已记录repository/static/API/analyzer结果、4项固定ENet风险与first-party零finding，并保持Simulator/signed/physical/live/performance/power分层。下一步只读pre-mark authority gate；通过后仅勾选8.3，预期`45/50 next 8.4`。
- **8.3 pre-mark authority gate：** corrected `/tmp/LuneX-18-8_3-authority-pre.Q34BIA`通过strict `9/9`、`44/50 next 8.3`、精确6个authority文件、零production/test、稳定project及retained repository/analyzer/opt-in/process/proof边界。首轮只因对跨行`Tasks 8.4-8.8 remain`使用单行全文正则退出，改为稳定token后只读收尾通过；现已仅勾选8.3，下一步post-mark final-state。
- **8.3 post-mark final-state：** `/tmp/LuneX-18-8_3-final-state.9FJ4uY`只读通过strict `9/9`、`45/50 next 8.4`、精确7个authority文件、零production/test、唯一8.3 checkbox、稳定project及retained三道pre-gate/disabled opt-ins/process/proof边界；未重复analyzer/generator/compile或操作Simulator。下一步final audit/record。
- **8.3 final audit：** `/tmp/LuneX-18-8_3-final-audit.n2fBD4`通过最终7文件authority-only scope、零production/test、唯一8.3 checkbox、strict `9/9`与`45/50 next 8.4`、design/contract/roadmap/planning证据语义及全部project/reference/artifact/opt-in/process/proof边界。下一步final-record后独立提交推送。
- **8.3 final-record：** `/tmp/LuneX-18-8_3-final-record.bYIj8N`确认基线`HEAD == origin/main == 390db08`、strict `9/9`、`45/50 next 8.4`、最终7文件、唯一8.3 checkbox、稳定project/reference/dependency/artifacts、五道retained gate与disabled opt-ins/process/proof boundary；8.3进入独立提交推送。
- **8.3提交与8.4启动：** 8.3已以`1f7884c Verify repository and analyzer gates`提交推送，fetch确认`HEAD == origin/main == 1f7884c791432fcaba3512d16e61563ed77c7d44`且工作树clean；OpenSpec为`45/50 next 8.4`。8.4运行fresh完整ASan/TSan及覆盖平台observer/controller/held-release/frame/audio/replacement/teardown的malloc resource集合，真实opt-in保持unset且不操作Simulator lifecycle。
- **8.4首轮完整ASan未通过：** fresh证据`/tmp/LuneX-18-8_4-asan.x8oZgs`结构化为`1123 total / 1121 passed / 1 explicit Keychain skip / 1 failed`，build为`succeeded/0 error/0 warning/0 analyzer warning`，且日志无`ERROR: AddressSanitizer`、`ERROR: LeakSanitizer`或sanitizer summary。唯一失败`AppModelWorkflowTests.testNativeApplicationIntegrationCoversSpatialAudioReplacementAndCleanStop()`在等待video/audio start、首个audio engine及`model.audioRuntimeState`时耗尽仅包含`100`次`Task.yield()`的helper，随后`XCTUnwrap`失败。该结果不得记为ASan通过；下一步先做fresh isolated ASan并审计事件完成路径，优先建立有界确定性等待与失败状态诊断，不无诊断重跑完整suite。
- **8.4 isolated ASan分流：** `/tmp/LuneX-18-8_4-asan-isolated.bEFRLG/Isolated-ASan.xcresult`中该唯一失败用例在fresh isolated ASan下`1/1 passed`、耗时`0.027s`，build为`succeeded/0 warning/0 error/0 analyzer warning`，日志无ASan/LeakSanitizer error或summary，两个真实opt-in仍unset。由此排除该路径稳定卡死，最小修复限定为该integration初始就绪等待的可靠wall-clock边界与四子状态诊断；随后必须targeted ASan及fresh完整ASan复验。
- **8.4最小修复与targeted ASan：** 仅`AppModelWorkflowTests`目标integration的初始四条件等待改为2秒`ContinuousClock`有界轮询，超时诊断video/audio starts、audio engine、audio runtime及session phase并避免二次unwrap；production和全局helper不变。fresh `/tmp/LuneX-18-8_4-asan-targeted.Cgh65F/Targeted-ASan.xcresult`为`1/1 passed`、`0.028s`、build与sanitizer diagnostics全零。下一步fresh complete ASan复验1123项与唯一Keychain skip。
- **8.4 fresh complete ASan通过：** `/tmp/LuneX-18-8_4-asan-complete.kglBGp/Complete-ASan.xcresult`结构化为`1123 total/1122 passed/1 skipped/0 failed/0 expected failure`，唯一skip精确为显式真实Keychain round-trip；build `succeeded/0 warning/0 error/0 analyzer warning`，日志`0 ASan error/0 LeakSanitizer error/0 sanitizer summary`，真实opt-in unset。该证据为macOS sanitizer测试，不是Simulator、signed artifact、真机、HDR/空间音频听感、live Sunshine或性能功耗证明。下一步fresh complete TSan。
- **8.4 fresh complete TSan通过：** `/tmp/LuneX-18-8_4-tsan-complete.SlgWeu/Complete-TSan.xcresult`结构化为`1123 total/1122 passed/1 skipped/0 failed/0 expected failure`，唯一skip同为显式真实Keychain round-trip；build `succeeded/0 warning/0 error/0 analyzer warning`，日志`0 ThreadSanitizer warning/error/summary`且`0 data race` mention，真实opt-in unset。下一步fresh malloc scribble/pre-scribble/guard edges/stack logging资源选择集。
- **8.4首轮malloc选择集不可作为最终环境证明：** `/tmp/LuneX-18-8_4-malloc-resource.qymDw4/Malloc-Resource.xcresult`的13个精确suite结构化为`413/413 passed`、零skip/failure且build diagnostics全零，无malloc corruption或crash；但日志中的204条stack-recording仅来自`xcodebuild`及编译子进程，未出现实际`xctest`进程继承四个malloc变量的直接证据。因此保留选择集结果但不完成resource gate；改用`.xctestrun` `EnvironmentVariables`显式注入后fresh复跑。
- **8.4显式malloc resource gate通过：** `/tmp/LuneX-18-8_4-malloc-explicit.DYbtJZ`先fresh `build-for-testing`成功，再在生成`.xctestrun`中显式注入`MallocScribble/PreScribble/GuardEdges/StackLogging=1`并关闭parallelization；清单及留存副本SHA-256均为`e7b6593d35cc29e65cba00edd8a7776d08a9699208960610cffe2807cc6ccd81`。实际`xctest`日志确认guard pages、scribble及stack logging生效，13个精确suite在`Explicit-Malloc.xcresult`中`413/413 passed`、零skip/failure，test-without-building为`0 warning/0 error/0 analyzer warning`且日志无malloc corruption/double-free/crash。226个匹配test identifier覆盖observer/handler cancellation、held release、frame/audio completion、replacement、late callback、resource与teardown；下一步同步authority并执行repository pre-gate，8.4尚不勾选。
- **8.4 authority pre-mark同步：** 已更新OpenSpec design、阶段18runtime contract、completion roadmap及三份planning，记录首轮ASan失败分流、局部测试同步修复、targeted/complete ASan、complete TSan、显式malloc resource证据和严格proof boundary；OpenSpec仍保持`45/50 next 8.4`。下一步运行repository pre-gate，通过后才仅勾选8.4。
- **8.4 repository pre-gate编排错误1：** 首个组合门在进入shell前因JavaScript模板把shell的opt-in参数展开误解析为JavaScript变量而以`ReferenceError`退出；没有证据目录、generator、测试/build、仓库、Keychain、live host或Simulator副作用。改用无外层插值的`env | rg`检查，从fresh目录完整重跑。
- **8.4 repository pre-gate编排错误2：** `/tmp/LuneX-18-8_4-repository-pre-r2.rLthZx`已通过fixture self/tree，随后OpenSpec断言因当前CLI逐项列表不在旧`.results[]`路径而以jq null iteration退出；generator、retained evidence读取与后续门未执行。读取真实schema后从fresh r3完整重跑，该轮不计验收。
- **planning恢复patch错误：** 系统升级后的首次跟踪更新使用了交接摘要中的近似句作为`apply_patch`锚点，因与文件原文不完全一致而在写入前被拒绝；无部分文件修改。已改用精确EOF锚点，不重复失败写法。
- **系统升级后恢复：** 2026-08-08恢复时确认长期goal仍为`active`，`HEAD == origin/main == 1f7884c791432fcaba3512d16e61563ed77c7d44`，工作树仍精确为1个test与6个authority文件；OpenSpec保持`45/50 ready`、next 8.4，两个真实opt-in unset且无`xcodebuild`/`xctest`残留进程。
- **repository pre-gate r3诊断：** `/tmp/LuneX-18-8_4-repository-pre-r3.E85mP1`实际已完成fixture、strict/apply、精确scope、test-only diff、三次稳定generator、diff-check及targeted/complete ASan、complete TSan、explicit malloc retained JSON抽取和13-suite一致性文件。目录没有逐步marker或最终success record，因此只能把退出点界定为上述证据生成之后、最终仓库边界断言完成之前，不能唯一归因到某条断言，也不能计为完整gate。
- **下一步：** 使用fresh r4和逐步marker完整运行repository pre-gate；只读复用已通过的sanitizer/malloc证据，不重跑8.1-8.4测试，不查询或操作Simulator lifecycle。r4通过后才勾选8.4并执行post-mark、final audit/record、独立commit/push/fetch。
- **repository pre-gate r4错误：** `/tmp/LuneX-18-8_4-repository-pre-r4.Uj9ifm`带marker通过01-10全部门及11中的remote parity、opt-in、process、project/config/vendor/reference drift，随后line 99的过宽artifact断言命中`.gitignore`明确排除且mtime为2026-07-10的既有`build/DerivedData`。它不是本轮产物或Git漂移；r4不计完整gate。fresh r5改为Git可见untracked/staged/artifact漂移与本轮输出目录检查，不否定既有ignored cache，也不重复任何测试/build/Simulator操作。
- **repository pre-gate r5错误：** `/tmp/LuneX-18-8_4-repository-pre-r5.6JDUhc`通过fixture/OpenSpec/scope/generator/diff并串行抽取四个retained xcresult后，压缩jq表达式把`.nodeIdentifier? // empty`误写为无空格的`?//`，由jq parser在结果断言前退出。没有测试/build/Simulator副作用；fresh r6恢复合法jq语法完整重跑wrapper。
- **repository pre-gate通过：** fresh marker化 `/tmp/LuneX-18-8_4-repository-pre-r6.KP5QaD`一次通过fixture self/tree、OpenSpec strict `9/9`与pre-mark `45/50 next 8.4`、精确1 test + 6 authority scope、三次稳定project generator、最小test-only同步diff、串行retained targeted/complete ASan与complete TSan、唯一Keychain skip、显式malloc manifest/13 suites/actual xctest日志、authority/proof及Git/remote/opt-in/process/artifact边界；`SUCCESS`已存在。现在只勾选8.4，预期`46/50 next 8.5`。
- **post-mark wrapper错误：** `/tmp/LuneX-18-8_4-final-state.3lQKRT`已通过strict与`46/50 next 8.5`，随后checkbox正则把unified diff前缀与Markdown列表前缀合并成一个字符而未匹配实际`-- [ ]`/`+- [x]`行。checkbox内容正确且8.5-8.8仍pending；修正只读正则后fresh重跑final-state，不重复实质action。
- **post-mark final-state通过：** corrected `/tmp/LuneX-18-8_4-final-state-r2.Q4kKuv`只读通过strict `9/9`、`46/50 next 8.5`、精确8文件scope、唯一8.4 checkbox、retained pre-gate/sanitizer/malloc、稳定project及Git/remote/opt-in/process边界；未重跑generator/test/build或操作Simulator。下一步final diff audit与final-record。
- **final audit wrapper错误：** `/tmp/LuneX-18-8_4-final-audit.FMHcPD`通过scope后，`rg -c`对零个测试函数增删返回exit 1且不打印`0`，使空字符串与`0`比较误退出；helper声明/引用、唯一旧wait替换、timeout/sleep/XCTFail/return、零skip新增均已逐项确认。规范化零计数后fresh重跑完整audit。
- **final diff audit通过：** corrected `/tmp/LuneX-18-8_4-final-audit-r2.5OLJiU`通过最终8文件`0 production / 1 test / 7 authority`、1个局部helper/1处等待替换/0测试函数增删/0 skip-disable、唯一8.4 checkbox、strict `9/9`与`46/50 next 8.5`、稳定project、retained pre/post gates及全部仓库/proof边界。下一步final-record后精确stage、独立commit/push/fetch。
- **final-record通过：** `/tmp/LuneX-18-8_4-final-record.8Ps0cQ`通过strict `9/9`、`46/50 next 8.5`、8文件`0 production/1 test/7 authority`、pre/post/audit三道成功marker、全部retained sanitizer/malloc、稳定project及remote/opt-in/process/repository边界。8.4进入精确stage、独立提交与push/fetch。

## 2026-08-08 阶段 18 任务 8.5 启动

- **状态：** `in_progress`；8.4已以`82ccd30 Verify sanitizer and resource gates`提交推送，fetch确认`HEAD == origin/main == 82ccd305e1b75cf182a9b934b6b8bfbd7ea6d08d`且工作树clean。OpenSpec为`46/50 ready`、next 8.5。
- **固定身份：** tvOS 26.4 Apple TV `6C0EC809-4C15-4AEC-9470-00F91480CAA7`；visionOS/xrOS 26.4 Apple Vision Pro `9BF41D0C-B423-4B3F-B75D-00B31E85FE18`。只按UUID+runtime+name核验，27.0同名设备不替代固定identity。
- **执行边界：** 不执行泛化`simctl list`，不创建、克隆、启动、bootstatus、安装、launch、关闭、删除、升级或接管设备；直接只读`device.plist`、`device_set.plist`和固定26.4 runtime bundle metadata，验证存在、未删除、runtime可用、state=1 Shutdown及runtime/name单实例。
- **现有实例：** 全局直接plist盘点为50个state=1与1个state=3；唯一Booted是iOS 26.4 `iPhone 17` `1864B6E2-2C29-4E4C-97AA-F1E137096F8D`，与tvOS/visionOS类别不冲突且必须保持原状。
- **inventory wrapper错误1：** `/tmp/LuneX-18-8_5-inventory.0E7yIY`在首个固定device JSON转换处退出，因为Apple TV `device.plist`含`NSDate lastUsedAt`而`plutil -convert json`拒绝非JSON对象；尚未执行两项`xcodebuild -showdestinations`。源plist未修改、无Simulator/Xcode lifecycle副作用；改用逐字段`plutil -extract raw`与`jq -n`组装结构化记录。
- **inventory验收：** corrected `/tmp/LuneX-18-8_5-inventory-r2.VXUoDR`通过固定device/default mapping/runtime profile、26.4 runtime/name唯一性、27.0同名隔离、两项scheme-bounded `showdestinations`、全局state及pre/post hash/normalized snapshot一致性；两个固定设备均available/non-deleted/state=1 Shutdown且各唯一。没有lifecycle命令，现有Booted iPhone保持不变。
- **证明边界：** 8.5只证明identity/runtime availability/Shutdown/single-instance inventory，不完成8.6 App运行导航、8.7 signed physical/live或8.8最终同步。下一步运行authority/repository pre-gate，通过前不勾选8.5。
- **repository pre-gate：** `/tmp/LuneX-18-8_5-repository-pre.azHeo5`一次通过fixture self/tree、strict `9/9`与pre-mark `46/50 next 8.5`、6文件authority-only scope、三次稳定generator、retained inventory/metadata/destination、authority及Git/remote/opt-in/process边界。现在只勾选8.5，预期`47/50 next 8.6`。
- **post-mark final-state：** `/tmp/LuneX-18-8_5-final-state.E5JkFk`只读通过strict `9/9`、`47/50 next 8.6`、7文件authority-only scope、唯一8.5 checkbox、retained inventory/pre-gate、稳定project及repository/opt-in/process边界；未重复inventory/generator或操作Simulator。下一步final audit/record。
- **final audit：** `/tmp/LuneX-18-8_5-final-audit.YnuqwB`通过最终7文件authority-only、唯一8.5 checkbox、current/historical inventory区分、existing iPhone preservation、27.0 identity隔离、strict `9/9`与`47/50 next 8.6`及全部仓库/proof边界。下一步final-record后精确stage、提交与push/fetch。
- **final-record：** `/tmp/LuneX-18-8_5-final-record.fy4DMG`通过`47/50 next 8.6`、最终7文件、inventory/pre/post/audit四道成功marker、稳定project、零lifecycle mutation及remote/opt-in/process/repository边界。8.5进入独立提交推送。

## 2026-08-08 阶段 18 任务 8.6 启动

- **恢复基线：** macOS更新后确认Xcode仍为`26.4 (17E192)`、系统为macOS 27.0，`HEAD == origin/main == 5a58549d7e614f5884cc5a5b67f45d6229806682`且工作树clean；真实Keychain/live-host opt-in均unset，正常测试继续使用文件fallback。
- **bounded target初查：** 当前工程精确只有4个application target与1个macOS unit-test bundle；UI-testing product type为0，仓库没有UI-test/navigation-harness命名文件。`xcodebuild -list -json`只列出5个对应scheme/target；当前正在从generator、shared scheme与XCUITest API scan完成交叉验收。
- **执行边界：** 只运行本change现有且可重复断言结果的tvOS/visionOS Simulator UI/navigation target。若集合为空，记录`0 existing target / 0 executed`并复用7.5/8.1的offline deterministic application evidence；不得新增launch-only伪gate，也不得boot/install/launch/create/clone/shutdown/delete任何Simulator或改变用户现有Booted iPhone。
- **验收编排修正：** 首轮`/tmp/LuneX-18-8_6-bounded-target.VBJhZV`在首组baseline因仍要求工作树clean而退出；本轮已按计划修改三份planning，所以该断言过期。该轮只写入baseline marker和三文件Git状态，未进入target、xcresult或设备检查。corrected轮固定三文件scope并要求pre/post diff hash一致。
- **第二轮门禁修正：** `/tmp/LuneX-18-8_6-bounded-target-r2.4hDm4n`通过baseline、固定设备和权威target扫描，在生成器字符串检查处退出；Ruby模板内product type带转义引号，过窄`grep`得到0行。该轮未读取retained xcresult或执行任何Simulator target。r3改为统计稳定product-type token并继续完整审计。
- **authority补丁修正：** 首个6文件组合补丁因`design.md`的Task 8.5段落换行锚点不精确被`apply_patch`原子拒绝，无部分修改；改为使用稳定章节标题拆分单文件补丁。
- **bounded audit通过：** corrected `/tmp/LuneX-18-8_6-bounded-target-r3.VTe8DU`七组marker全部通过：4个App + 1个macOS unit-test、0 UI-testing/shared scheme/XCUITest/tvOS或visionOS test bundle，因此`existing=0 / executed=0`；retained 7.5 focused/related/normal与8.1 normal全部可读且唯一skip仍为真实Keychain opt-in。固定Apple TV/Vision Pro plist前后hash一致、继续Shutdown，未执行任何Simulator lifecycle/build/test/install/launch操作。
- **证明边界：** 8.6完成的是“只运行既有bounded target”的空集合审计，不是Simulator App runtime通过。offline application结果不替代signed artifact、physical remote/input/HDR/空间音频、live Sunshine、comfort、延迟、性能、功耗或温度；8.7和8.8必须保持pending。下一步repository pre-gate，通过前不得勾选8.6。
- **repository编排修正：** 首个pre-gate在shell启动前因JavaScript模板中含Markdown反引号而以`SyntaxError: Unexpected number`退出；无证据目录、fixture/generator、仓库或设备副作用。移除包装器反引号后从fresh目录完整执行。
- **post-mark正则修正：** 首轮`/tmp/LuneX-18-8_6-final-state.cJUFIH`已确认strict `9/9`、`48/50 next 8.7`和精确7文件scope，随后在转义过度的checkbox正则处退出；保存diff精确只有8.6的`-- [ ]`到`+- [x]`。改用Python固定前缀计数从fresh目录重跑只读final-state。
- **post-mark通过：** corrected `/tmp/LuneX-18-8_6-final-state-r2.MqvuzZ`通过strict `9/9`、`48/50 next 8.7`、精确7文件scope、唯一8.6 checkbox、retained audit/pre-gate、稳定project及remote/opt-in/process边界；8.7和8.8继续pending。下一步final diff audit与final-record后独立提交推送。
- **final-audit编排修正：** 首个final audit再次因JavaScript模板中的Markdown反引号在shell前SyntaxError退出，无证据目录或仓库/设备副作用；corrected轮禁止wrapper出现反引号并使用纯文本稳定token。
- **final audit通过：** corrected `/tmp/LuneX-18-8_6-final-audit-r2.c9Anqw`通过最终7文件authority/tasks scope、零production/test/project/config/vendor/reference diff、唯一8.6 checkbox、strict `9/9`、`48/50 next 8.7`、retained audit/pre/post gates及全部repository/proof边界。下一步final-record后独立提交推送。
- **final-record：** `/tmp/LuneX-18-8_6-final-record.eWNhuu`通过最终authority状态、四道retained gate、`existing/executed=0/0`、固定设备无变化、唯一checkbox、稳定project及全部repository边界；补入本索引后运行r2确认最终diff，再独立提交推送。

## 2026-08-08 阶段 18 任务 8.7 readiness 与 8.8 同步

- **8.6提交：** `339b71a Record bounded simulator UI target boundary`已推送并fetch确认`HEAD == origin/main == 339b71a4ba8175d2b8d8c8702f0df4c23a4286e8`、工作树clean；OpenSpec为`48/50`，pending仅8.7与8.8。
- **8.7 readiness：** `/tmp/LuneX-18-8_7-readiness.nLhQfT`脱敏摘要记录1台paired/booted/developer-mode-capable物理Apple TV类设备、0台物理Vision Pro，live-host/真实Keychain opt-in均unset且无signed physical/live receipt。未探测signing identity、安装/启动App或打开stream；原始identity-bearing JSON已删除。
- **8.7判定：** device discovery不是任务授权或验收，且Vision Pro与live Sunshine receipt缺失，所以8.7必须保持未勾选。当前不是同一阻塞条件连续三次goal turn，长期goal继续active而不标记blocked。
- **8.8范围：** 同步offline、Simulator、signed artifact、physical device、live host五级证据边界。8.8可记录8.7 pending，但不得archive change或把阶段18标记complete；阶段19/20证据不得替代8.7。
- **8.8 gates：** repository pre-gate `/tmp/LuneX-18-8_8-repository-pre.U0WN6n`通过fixture、strict `9/9`、pre-mark `48/50`、6 authority scope、三次稳定generator、脱敏readiness、五级矩阵与repository边界；只勾选8.8后，post-mark `/tmp/LuneX-18-8_8-final-state.r8HNJn`确认`49/50`、唯一pending 8.7、精确7文件scope及唯一checkbox。下一步final audit/record后独立提交推送。
- **final-audit断言修正：** 首轮`/tmp/LuneX-18-8_8-final-audit.Yi4ckM`通过scope/OpenSpec/checkbox后，对contract中跨两行的Task 8.7唯一physical/live语义使用单行全文匹配而退出；改查两段稳定token后fresh重跑只读audit。
- **final audit通过：** corrected `/tmp/LuneX-18-8_8-final-audit-r2.Kma7ZH`通过最终7文件authority/tasks scope、唯一8.8 checkbox、strict `9/9`、`49/50 only 8.7 pending`、五级proof matrix、脱敏readiness、稳定project及全部repository边界；下一步final-record后独立提交推送。
- **final-record：** `/tmp/LuneX-18-8_8-final-record.xuo5aN`通过最终authority、完整retained chain、8.7 not-ready脱敏状态、唯一8.8 checkbox、稳定project及repository边界；补入索引后运行r2，再独立提交推送。

## 2026-08-18 阶段 19 任务 3.5 恢复

- **状态：** `in_progress`；`HEAD == origin/main == c74b4f0adfcff13d76a3937cfd9fec5379bb2403`且工作树clean，OpenSpec `complete-native-product-workflows`保持`17/48 ready`、next 3.5。
- **当前任务：** 将stream overlay可见性、focus handoff、本地命令和stop confirmation绑定到完整`ProductWorkspaceReference`与current `ProductSessionOwner`，non-owner/replaced workspace fail closed，并继续阻止system-reserved command进入remote input。
- **执行边界：** 本任务不提前实现3.6 compact/wide重排、3.7完整应用矩阵、4.4 owning-window close policy或5.x无障碍收尾；真实Keychain/live-host opt-in保持unset，普通测试继续使用文件fallback，不查询或改变Simulator lifecycle。
- **恢复异常：** 用户已明确要求继续并曾要求重建目标，但`create_goal`因旧记录仍是unfinished `blocked`而拒绝，且目标接口没有resume状态操作；该限制只记录为跟踪层异常，不作为代码/OpenSpec阻塞，也不停止3.5实施。
- **production补丁修正：** 首个tvOS restore/runtime begin/mac admission/vision eligibility/navigation组合补丁因`applyInputLifecycle`锚点与当前格式不完全一致而被`apply_patch`原子拒绝，没有部分写入；改用最新精确行拆成独立小补丁，不重复组合失败方式。
- **只读/生成器编排修正：** 查历史命令时`Makefile*`无匹配被zsh提前拒绝；随后`generate_xcodeproj.rb --help`因脚本无help分支而实际运行生成器。生成后project SHA-256仍为稳定`60e6966f...d2224`且零project diff；不重复这两条命令，后续使用已确认的scheme直接build。
- **compile-1失败：** fresh macOS warnings-as-errors在`AppModel.swift`唯一报错：新增workspace版`receiveTVRemoteSurfacePressEvent`末尾缺少显式`return`，导致nil-coalescing表达式结果未使用。已精确补`return`，失败bundle保留到最终审计后定向清理，下一轮使用fresh DerivedData。
- **compile-2通过：** fresh `/private/tmp/LuneX-19-3_5-compile-2`以`LuneX-macOS` generic macOS、Debug、unsigned、warnings-as-errors完成universal `arm64 + x86_64`构建；唯一日志warning是工程既有的无AppIntents依赖metadata extraction skip。该结果仅证明当前production/API条件编译，下一步补owner/non-owner/replacement、mac focus、tvOS/visionOS reserved command和stop confirmation focused回归。
- **focused-1编排失败：** `/private/tmp/LuneX-19-3_5-focused-1`在编译前以exit 66退出，因为误用只配置build的`LuneX-macOS` scheme执行test action；工程权威列表确认专用测试scheme为`LuneXCoreTests`。不复用该结果或重复错误scheme，focused-2改用`LuneXCoreTests`与fresh DerivedData。
- **focused-2单测设计失败：** warnings-as-errors编译通过，7个selected中6个通过；唯一失败是将Escape overlay release插入既有visionOS长流程后，使后续精确release/application计数合法增加1并连锁超时。保持原generation测试使用不改变capture的本地interaction，另建隔离Escape测试；focused-3使用fresh evidence，不复用失败结果。
- **focused-3通过：** fresh `/private/tmp/LuneX-19-3_5-focused-3`结构化`8/8`、0 skip/failure，覆盖owner/non-owner/replaced workspace overlay、mac focus、remote cleanup、confirmation cancel/confirm与direct stop共享、tvOS Menu、visionOS Escape和RootView显式workspace contract；两个真实opt-in unset且未操作Simulator。
- **related通过：** 复用focused-3编译缓存但使用独立`/private/tmp/LuneX-19-3_5-related-1/Related.xcresult`，8个相关suite结构化`219/219`、0 skip/failure；覆盖AppModel、mac input、tvOS focus、vision input、两平台control presentation与destructive stop协调。
- **normal通过：** fresh serial `/private/tmp/LuneX-19-3_5-normal-final/Normal.xcresult`结构化`1224 total / 1223 passed / 1 skipped / 0 failed`；唯一skip精确为`testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，真实Keychain/live-host opt-in均unset，继续文件fallback。
- **四平台build通过：** `/private/tmp/LuneX-19-3_5-platform-builds-final`中的macOS universal、iOS/iPadOS、tvOS、visionOS warnings-as-errors unsigned generic Debug均结构化`succeeded / 0 error / 0 warning / 0 analyzer warning`；macOS产物含`x86_64 arm64`。未调用Simulator lifecycle，不代表signed、physical、assistive-technology或live Sunshine证明。
- **结构化读回脚本修正：** 首轮给zsh特殊变量`path`赋bundle路径，意外覆盖该shell的`PATH`并使`xcrun`不可见；构建与xcresult未受影响。改用`bundle_path`只读同一证据成功，不重复build/test。
- **文档搜索修正：** 广泛搜索使用不存在的`openspec/.../specs/*.md`层级，zsh `nomatch`在命令启动前退出；改为明确spec路径后完成读取，无文件、测试、Keychain或设备副作用。
- **最终源码审计：** owner/generation、requested/actual overlay、macOS/tvOS/visionOS focus/input handoff、system-reserved local command、全部可见stop confirmation及terminal双重transient cleanup均一致；没有新增production修复。下一步generator稳定性、OpenSpec strict与repository pre-gate，通过前3.5保持未勾选。
- **pre-gate编排修正 1：** 首轮repository组合门在fixture通过后因`.overlayVisible`静态正则过度转义而退出；拆分固定字符串/语义断言后均通过，未重复fixture、test或build。
- **pre-gate编排修正 2：** 第二轮组合门把`jq`对象键`next`写成未加引号的控制关键字，OpenSpec读取阶段提前退出；改为直接断言progress与首个pending description，不改变仓库或运行时。
- **repository pre-gate：** corrected门通过protocol fixture self/tree、strict `1/1`、pre-mark `17/48 next 3.5`、稳定generator SHA-256、精确10文件scope、owner/reserved-command/confirmation语义、retained `8/219/1224`测试、四平台build、privacy/reference/dependency/opt-in/process/diff边界。
- **状态：** `complete`；3.5已勾选，预期权威状态为`18/48 ready`、next 3.6。下一步仅运行post-mark只读final-state，不重复test/build/generator、Keychain、live host或Simulator操作。
- **post-mark final-state：** 只读门通过OpenSpec strict `1/1`、`18/48 next 3.6`、精确11文件scope、唯一3.5 checkbox、稳定project hash、全部retained test/build、disabled opt-ins及零LuneX build/test process；未重复任何验收或Simulator操作。
- **evidence cleanup：** 八个明确`/private/tmp/LuneX-19-3_5-*`路径已逐项`find -depth -delete`，包含失败/成功DerivedData、raw logs与xcresult；定向零残留检查通过。下一步final record后精确stage、独立commit/push/fetch。
- **final record：** 通过基线`HEAD == origin/main == c74b4f0`、strict `1/1`、OpenSpec `18/48 next 3.6`、最终11文件scope、唯一3.5 checkbox、稳定project、计划内retained证据索引、零task artifact、disabled opt-ins及repository/process/proof边界。3.5进入精确stage与独立commit/push/fetch。

## 2026-08-18 阶段 19 任务 3.6 启动

- **状态：** `in_progress`；3.5已以`84b35d8 Bind stream controls to workspace owners`提交推送，OpenSpec为`18/48 ready`、next 3.6。当前只保留`RootView.swift`、`ProductWorkflowSurface.swift`和`ProductWorkflowSurfaceTests.swift`三个未验收候选修改。
- **目标：** compact horizontal size class或accessibility Dynamic Type使用底部、可滚动且最高约占窗口48%的controls；wide使用顶左、自然尺寸优先且最高约占82%的controls。所有primary commands必须可达、可重排、不依赖hover，controls可见时不得与virtual controller重叠，tvOS/visionOS保留既有focus与owner-scoped stop合同。
- **恢复门：** session catchup只发现尚未落盘的对话记录；`git diff --check`通过，Xcode 26.4/Swift 6.3，真实Keychain/live-host opt-in均unset，无活动LuneX `xcodebuild`/`xctest`，未操作Simulator lifecycle。
- **lint边界：** `xcrun swift-format lint --strict`对三个完整文件报告大量既有两空格缩进、line length、`UseLetInEveryBoundCaseVariable`与`NoAccessLevelOnExtensionDeclaration`诊断；仓库没有匹配既有四空格风格的配置，因此该全文件结果不是局部3.6门禁且不据此批量format。权威门为fresh warnings-as-errors编译、结构化tests/build、`git diff --check`和人工diff/UI语义审计。
- **下一步：** 从fresh DerivedData运行macOS warnings-as-errors compile；失败时仅精确修复当前候选并废弃失败证据，不复用失败DerivedData。
- **命令检索错误：** 首轮历史命令搜索包含不存在的`Makefile*`，zsh在命令启动前因`nomatch`报告错误；无文件、构建或设备副作用。已直接用`xcodebuild -list -json`确认scheme，不重复该glob。
- **fresh compile：** `/private/tmp/LuneX-19-3_6-compile-1.hkeJQH` unsigned generic macOS Debug warnings-as-errors一次通过；xcresult为`status succeeded / 0 error / 0 warning / 0 analyzer warning`，日志唯一warning为无AppIntents依赖的metadata skip，产物含`x86_64 arm64`。下一步focused测试。
- **focused通过：** fresh `/private/tmp/LuneX-19-3_6-focused.GqDNRx/Focused.xcresult`结构化通过`4/4`、0 skip/failure；覆盖pure layout矩阵、RootView adaptive/virtual-controller/non-hover合同及tvOS/visionOS source/focus合同，build diagnostics全零。
- **related通过：** 复用同一fresh build缓存的`/private/tmp/LuneX-19-3_6-related.HrWyOS/Related.xcresult`结构化通过`176/176`、0 skip/failure；覆盖Product surface/workspace、AppModel owner/session、macOS input、mobile presentation、tvOS/visionOS controls/settings，build diagnostics全零。下一步独立fresh serial normal。
- **normal通过：** 独立fresh `/private/tmp/LuneX-19-3_6-normal.Rd9rKL/Normal.xcresult`串行通过`1225 total / 1224 passed / 1 skipped / 0 failed / 0 expected failure`，build diagnostics全零；唯一skip精确为`testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，两个真实opt-in保持unset，普通测试继续JSON文件store。下一步四平台generic Debug build。
- **中间四平台build：** 首版候选在`/private/tmp/LuneX-19-3_6-platform-builds.IkwJPZ`通过macOS universal、iOS/iPadOS、tvOS、visionOS generic Debug `4/4`且四份xcresult均零diagnostic；随后人工UI审计发现实际窗口宽度未参与layout选择，因此该结果降为修订前中间证据，不能作为最终3.6验收。
- **UI审计修复：** macOS resized window通常没有compact size class，首版会错误保持wide；`ProductStreamWorkspaceLayout`现以900pt阈值同时消费actual `GeometryReader` width，非有限宽度fail closed为compact，并把outer result传给tvOS/visionOS controls。compact高度严格限制为实际容器48%，wide保持82%且宽度约68%、640...1040pt，避免无意义占满窗口。
- **审计搜索错误：** 两个只读`rg`分别包含不存在的`project.yml`和`Documentation`路径并报告file-not-found；其余明确路径读取完成，无文件、构建或设备副作用。后续只搜索已确认路径。
- **证据失效：** 因production与test均在UI审计后变化，修订前compile/focused/related/normal/四平台结果仅作诊断历史；最终证据必须从fresh目录重跑。
- **最终focused：** `/private/tmp/LuneX-19-3_6-focused-final.cO86i1/Focused.xcresult`结构化通过`4 total / 4 passed / 0 skipped / 0 failed`，build为`succeeded / 0 error / 0 warning / 0 analyzer warning`；覆盖actual-width layout reducer、RootView compact/wide/virtual-controller/non-hover合同及tvOS/visionOS内部reflow/focus语义。
- **最终related：** `/private/tmp/LuneX-19-3_6-related-final.Sqk1fr/Related.xcresult`结构化通过`176/176`、零skip/failure，build四类diagnostic全零；覆盖Product surface/workspace registry、AppModel owner/session、tvOS/visionOS presentation、macOS input与mobile状态，确认3.5 owner/input/reserved-command合同未回归。
- **最终normal：** `/private/tmp/LuneX-19-3_6-normal-final.F3zbOj/Normal.xcresult`串行通过`1225 total / 1224 passed / 1 skipped / 0 failed / 0 expected failure`，build diagnostics全零；唯一skip精确为显式关闭的真实Keychain round-trip，两个真实opt-in保持unset并继续JSON文件fallback。
- **最终四平台build：** `/private/tmp/LuneX-19-3_6-platform-builds-final.c62DaX`中macOS universal、iOS/iPadOS、tvOS、visionOS unsigned generic Debug全部`succeeded / 0 error / 0 warning / 0 analyzer warning`；macOS executable为`x86_64 arm64`，每份raw log只有既有AppIntents metadata extraction skip。
- **当前门：** 产品代码冻结。下一步同步OpenSpec/design/runtime authority并运行静态语义、generator稳定性、strict validation与repository pre-gate；全部通过前保持`18/48 next 3.6`且不得勾选task。最终证据只证明offline deterministic source/test与unsigned build，不证明signed、physical UI/focus、assistive technology、live Sunshine或性能功耗。
- **静态门包装器错误：** 首轮语义门前四组已通过，在stop ownership组把截止于`TVStreamControlFocusTarget`之前的通用stream切片错误地当作包含tvOS/visionOS controls，并要求其中出现三次confirmation，因此无输出退出；实际通用、tvOS、visionOS各有一个入口。该轮只读、未修改源码或运行build/test/Keychain/Simulator；修正为三段分别精确断言后继续。
- **静态门与skip读取：** corrected源码语义门已通过全部layout/geometry/reachability/reflow/focus/owner/test/pre-mark/diff断言。随后同一只读wrapper的skip名称提取错误假设test-tree节点使用`testStatus/status`字段，在`SKIP_IDENTITY`后无匹配退出；normal summary仍已结构化确认1 skip/0 failure。下一步按实际Xcode 26.4 JSON字段只补读唯一skip和四平台build，不重复静态门。
- **最终证据复读尾部错误：** 按实际`.result == "Skipped"`已精确确认唯一Keychain测试，四个平台build也逐份确认`succeeded/0/0/0`；wrapper最后用`find`路径加`file`固定英文短语检查universal binary时无匹配退出。该退出发生在四份build已通过之后，只需以实际可执行路径和`lipo -archs`补验架构，不重复结构化读取。
- **最终静态与generator门：** corrected源码语义门、唯一Keychain skip、四平台build复读及`lipo -archs == x86_64 arm64`全部通过。工程生成前、第一次及第二次`ruby Tools/generate_xcodeproj.rb`后的project SHA-256均为`60e6966fc42bbe0facbb8adfdf66794746948039ba1f190ac13dc0438a9d2224`，无工程diff且`git diff --check`通过；下一步strict/apply与repository pre-gate。
- **repository pre-gate编排错误：** 首个组合门在shell启动前被functions JavaScript解析器把Bash的`${spec%%:*}`误作模板表达式，以`SyntaxError: Unexpected token '%'`拒绝；未创建evidence、运行命令、修改仓库或触发test/build/Keychain/live host/Simulator。改为`IFS=:`读取字段后从fresh目录完整执行，不重复该写法。
- **repository pre-gate r1进程误判：** `/private/tmp/LuneX-19-3_6-repository-pre.CibDgd`已通过01-08的scope/OpenSpec/generator/source/authority/tests/builds/privacy门；09用整行`ps`匹配时命中wrapper自身命令文本中的文件名`xcodebuild.log`，误报活动进程并退出。没有真实xcodebuild/xctest或runtime副作用；改用`pgrep -x`精确进程名后从fresh r2完整执行，r1不计最终门。
- **repository pre-gate r2过宽artifact门：** `/private/tmp/LuneX-19-3_6-repository-pre-r2.OOerd5`再次通过01-08且09未发现真实opt-in或build/test进程，随后“工作区不得存在任何`DerivedData`/log”断言无输出退出；这会把`.gitignore`排除的既有cache与task漂移混同。只读确认来源后，r3收窄为Git可见staged/untracked与task-specific workspace artifact，不删除既有或用户cache。
- **repository pre-gate：** fresh `/private/tmp/LuneX-19-3_6-repository-pre-r3.98Tnh5`完整通过基线与精确10文件scope、strict/OpenSpec `18/48 next 3.6`、稳定project、源码/authority语义、focused `4/4`、related `176/176`、normal `1225/1224/1/0`、四平台build `4/4`、privacy/test integrity、disabled opt-ins、零build/test进程、Git-visible artifact及diff边界；未操作Simulator lifecycle。
- **状态：** `complete`；3.6已勾选，权威状态应为`19/48 ready`、next 3.7。下一步仅运行post-mark只读final-state，确认唯一checkbox和11文件scope；不重复generator/test/build或操作Keychain/live host/Simulator。
- **post-mark final-state：** `/private/tmp/LuneX-19-3_6-final-state.aAzzoV`只读通过strict、OpenSpec `19/48 next 3.7`、精确11文件scope、唯一3.6 checkbox、稳定project hash、最终evidence/pre-gate可读、disabled opt-ins及零build/test process；未重复generator/test/build或操作Simulator。下一步定向清理task evidence。
- **cleanup编排错误：** 首个32路径定向清理脚本在shell启动前因functions JavaScript误解析Bash数组`${paths[@]}`而以SyntaxError拒绝；没有任何路径被删除。改用无数组展开的here-doc逐行读取同一组绝对路径，再逐项`find <exact> -depth -delete`。
- **evidence cleanup：** 已枚举的32个`/private/tmp/LuneX-19-3_6-*`目录/路径文件全部逐项以`find <exact-path> -depth -delete`清理，task prefix零残留；未使用宽泛删除，也未触碰仓库既有ignored `build/DerivedData`。下一步最终diff audit与final record。
- **final audit文档修复：** 首轮最终审计确认product diff只涉及stream workspace/overlay/tvOS/visionOS controls、tests只新增且OpenSpec为`19/48 next 3.7`，同时发现roadmap在3.6完成记录前仍写“3.6仍负责compact/wide”。已精确改为3.6现已完成、3.7仍负责完整矩阵；只改文档时态，不重跑test/build。
- **final audit：** corrected只读审计通过最终11文件scope、RootView hunk仅1224...1710 stream范围、layout core `21+/0-`、tests新增1函数且无函数删除/skip/disable、唯一3.6 checkbox、strict `19/48 next 3.7`、零stale authority wording、privacy/opt-in/process/artifact/project/reference/diff边界。下一步final record与精确stage/commit/push/fetch。
- **提交：** 3.6已以`fec4ec5 Adapt stream controls to window size`提交推送，fetch与`git ls-remote`确认`HEAD == origin/main == fec4ec58588a9f6ba962c981aad5bd244894e5fe`且工作树clean；OpenSpec为`19/48 ready`、next 3.7。

## 2026-08-18 阶段 19 任务 3.7 启动

- **状态：** `complete`；九类application session矩阵已闭合并通过当前源码的focused、expanded、normal与repository门禁，OpenSpec 3.7已勾选。
- **边界：** 3.7只补确定性application tests及测试暴露的最小正确性修复；不提前实现4.4 owning-window close policy、5.x无障碍收尾或7.x完整跨产品workflow。真实Keychain/live-host opt-in保持unset，不操作Simulator lifecycle。
- **覆盖审计：** 现有application tests已覆盖required provider absence、duplicate launch、owner/non-owner command、recoverable reconnect、remote termination、reconnect exhaustion、concurrent repeated stop与clean teardown；缺口是旧session terminal event在replacement已streaming后到达的明确回归。
- **候选修改：** 仅测试provider新增默认关闭的`retainsStoppedContinuation`能力，并新增`testStaleTerminationCannotRelabelOrStopReplacementSession`：先clean stop第一代、启动第二代到streaming，再投递第一代termination，要求第二代owner/phase/UI不变且最终仍能clean stop。production未修改。
- **新增用例focused：** fresh `/private/tmp/LuneX-19-3_7-focused.MMLiAG/Focused.xcresult`在warnings-as-errors下结构化通过`1/1`、零skip/failure且build `succeeded/0 error/0 warning/0 analyzer warning`；证明测试double与新竞态用例编译运行成立。下一步九类合同expanded focused。
- **expanded编排错误：** 首个10测试命令在shell启动前因functions JavaScript误解析Bash `${args[@]}`数组展开而拒绝；未创建evidence或运行xcodebuild。改为10个显式`-only-testing:`参数后从fresh目录执行，不重复数组写法。
- **expanded focused：** fresh `/private/tmp/LuneX-19-3_7-expanded.iCdzYN/Expanded.xcresult`在warnings-as-errors下结构化通过`10/10`、零skip/failure/expected failure，build `succeeded/0 error/0 warning/0 analyzer warning`；九类3.7合同全部在当前AppModel application path闭合且production无需修改。下一步独立fresh serial normal。
- **serial normal：** fresh `/private/tmp/LuneX-19-3_7-normal.NxftSs/Normal.xcresult`结构化通过`1226 total / 1225 passed / 1 skipped / 0 failed / 0 expected failure`，build `succeeded/0 error/0 warning/0 analyzer warning`；唯一skip精确为显式关闭的真实Keychain round-trip，两个真实opt-in unset且继续文件fallback。当前工作树精确4文件、production零修改；下一步同步3.7 authority并运行generator/strict/repository pre-gate，未通过前不勾选。
- **2026-08-22恢复：** `HEAD == origin/main == fec4ec5`、OpenSpec仍为`19/48 next 3.7`、工作树仍精确test+三份planning且源码未漂移；两个真实opt-in unset、无活动build/test进程、未操作Simulator。四天后全部`/private/tmp/LuneX-19-3_7-*`被系统清理，上一轮计数只保留为历史记录，最终pre-gate前必须从当前源码重建retained focused/expanded/normal证据。
- **最终focused重建：** `/private/tmp/LuneX-19-3_7-focused-final.wADFi6/Focused.xcresult`结构化通过`1/1`、零skip/failure，build为`succeeded / 0 error / 0 warning / 0 analyzer warning`。
- **最终expanded重建：** `/private/tmp/LuneX-19-3_7-expanded-final.GOhNqB/Expanded.xcresult`结构化通过九类合同的`10/10`、零skip/failure，build diagnostics全零。
- **最终normal重建：** `/private/tmp/LuneX-19-3_7-normal-final.0qbP0I/Normal.xcresult`串行通过`1226/1225/1/0`且build diagnostics全零；唯一skip为显式关闭的真实Keychain round-trip，两个真实opt-in unset并继续JSON文件fallback。
- **当前门：** production/project/config/dependency/vendor/reference零修改；已同步3.7 design/spec/runtime contract/roadmap与planning。下一步运行静态语义、generator稳定性、strict validation和repository pre-gate，通过前保持`19/48 next 3.7`。
- **静态wrapper错误：** 首轮脚本确认stale测试和provider默认值各精确一次，并得到新增skip为零；随后`rg`的预期零匹配在`pipefail`下提前退出，未完成后续只读断言。没有源码、测试、构建、Keychain、live host或Simulator副作用；改用`awk`/显式容错计数从头重跑完整静态门。
- **repository pre-gate：** `/private/tmp/LuneX-19-3_7-repository-pre.CvoM5e`完整通过remote baseline、精确8文件pre-mark scope、strict `19/48 next 3.7`、稳定generator、10-test identifier/source integrity、retained `1/10/1226` evidence、唯一Keychain skip、privacy/proof、disabled opt-ins、零build/test process与diff/artifact边界。现已勾选3.7，预期`20/48 next 4.1`。
- **post-mark final-state：** `/private/tmp/LuneX-19-3_7-final-state.TnfZO2`只读通过strict、OpenSpec `20/48 next 4.1`、精确9文件scope、唯一3.7 checkbox、稳定project与retained `1/10/1226`证据；未重复generator/test/build或操作Keychain、live host、Simulator。下一步定向清理3.7 raw evidence。
- **evidence cleanup：** 12个明确`/private/tmp/LuneX-19-3_7-*`目录、marker与generator log已逐项用`find <exact-path> -depth -delete`清理，task prefix零残留；未触碰仓库既有ignored `build/DerivedData`。下一步final diff audit与cleanup final record。
- **final audit：** 完整审读确认test double默认仍移除并finish continuation，只有新竞态显式保留旧generation；replacement owner/phase/active/issue与两代clean stop断言闭合。最终9文件scope中production/project/config/dependency/vendor/reference零diff，1个新增/0删除测试函数、0新增skip、唯一3.7 checkbox、authority时态与4.4/5.x/7.x边界正确，task artifact零残留。下一步final record与独立commit/push/fetch。
- **final record：** cleanup后只读门确认`HEAD == origin/main == remote == fec4ec5`、strict、OpenSpec `20/48 next 4.1`、最终9文件、稳定project、test/authority完整性、零task artifact、两个opt-in unset及零build/test进程。Task 3.7准备精确stage、独立commit/push/fetch。

## 2026-08-22 阶段 19 任务 4.1 启动

- **状态：** `in_progress`；为macOS与iPadOS添加真实scene/workspace创建和恢复接线，在不支持的配置继续单一checked workspace。
- **基线：** Task 3.7已以`8fcb737 Cover stale session termination`提交推送，`HEAD == origin/main == remote`且工作树clean；OpenSpec为`20/48 next 4.1`。
- **初步缺口：** 当前所有平台`WindowGroup`都复用同一个无参数`rootView`，没有在SwiftUI scene identity边界创建/恢复独立workspace；底层registry和checked generation合同已存在。
- **范围：** 4.1只接scene identity、workspace creation/restoration与unsupported single-workspace fallback；不提前迁移4.2全部workspace-local bindings、不实现4.4 owning-window close policy，也不暴露tvOS/visionOS非功能窗口命令。
- **下一步：** 精读`LuneXApp.swift`、`RootView` workspace输入、`ProductWorkspaceRegistry`/`AppModel` create/restore API与现有tests，设计可确定性测试的scene binding值合同。
- **既有能力：** registry的`restore(id:restoration:)`会为已存在或tombstoned ID推进generation，以明确restoration values重建workspace并清空transient presentation；`close`保留generation tombstone，stale reference fail closed。
- **实现设计：** 在现有product state中增加Codable scene identity、attachment与MainActor coordinator。supported scene首次使用primary、后续nil scene创建distinct ID、恢复scene按ID推进generation；active duplicate identity fail closed。unsupported配置忽略scene identity并始终附着primary。
- **SwiftUI接线：** macOS/iOS使用`WindowGroup(id:for:)`的可恢复optional binding，scene root读取`supportsMultipleWindows`并在appear/disappear成对attach/detach；tvOS/visionOS保留普通`WindowGroup`与primary。断开只撤销scene attachment，不close workspace或stop session，保持4.4边界。
- **Root边界：** `RootView`接收scene workspace并将顶层stop/add-host/stream命令路由到它；navigation/selection与子surface的完整workspace binding迁移仍属于4.2。
- **首轮实现：** 已在现有文件加入scene identity/coordinator、AppModel attach API、macOS/iOS typed `WindowGroup`、RootView顶层workspace路由与iOS multiple-scene manifest；registry/surface tests覆盖distinct、restore generation、duplicate、unsupported primary、first restored primary、Codable和source wiring。
- **macOS compile：** fresh `/private/tmp/LuneX-19-4_1-compile.aXHxvO` generic Debug warnings-as-errors一次通过，structured build为`succeeded / 0 error / 0 warning / 0 analyzer warning`，universal executable为`x86_64 arm64`。
- **focused：** 同一fresh evidence中的scene/coordinator/source合同`7/7`通过、零skip/failure，structured build diagnostics全零。覆盖distinct/restore generation/duplicate/single fallback/first restored primary/Codable及Root/App/Info wiring。
- **下一门：** 先运行iOS/iPadOS generic warnings-as-errors build，直接编译`#if os(iOS)` typed WindowGroup分支并检查生成Info中的multiple-scene声明，再扩展related矩阵。
- **iOS/iPadOS build：** generic Debug warnings-as-errors结构化通过`succeeded / 0 error / 0 warning / 0 analyzer warning`；从实际app Info读回`UIApplicationSupportsMultipleScenes = true`与既有`UIBackgroundModes[0] = audio`，没有操作Simulator。
- **下一门：** workspace registry、Product surface、host/catalog/pairing/destructive六簇related回归，随后审计scene lifecycle竞态与AppModel application边界。
- **related：** workspace registry、Product surface、host/catalog/pairing/destructive六簇`77/77`通过，零skip/failure且build diagnostics全零。
- **审计补强：** coordinator行为正确但AppModel wrapper尚无直接application test；新增一条composition-root回归覆盖restored primary采用、disconnect/reconnect generation推进与unsupported primary fallback，并移除未使用failure case。production行为不变，下一步fresh focused复验。
- **最终focused：** 补强后fresh `/private/tmp/LuneX-19-4_1-focused-final.wXwWF7/Focused.xcresult`结构化通过`8/8`、零skip/failure，build diagnostics全零；早先`7/7`作为补强前辅助证据。
- **下一门：** 六簇workspace suites加完整`AppModelWorkflowTests`的七簇related矩阵，验证scene wrapper与既有session/pairing/catalog/overlay owner guards共同工作。
- **最终related：** 七簇`160/160`通过、零skip/failure且build diagnostics全零，scene wrapper未破坏session/overlay/host/catalog/pairing/destructive owner guards。
- **下一门：** 独立fresh serial normal，两个真实opt-in保持unset并继续文件identity fallback；相对3.7预期新增7项至`1233` total。
- **最终normal：** `/private/tmp/LuneX-19-4_1-normal-final.MHuuST/Normal.xcresult`通过`1233 total / 1232 passed / 1 skipped / 0 failed / 0 expected failure`，build diagnostics全零；唯一skip精确为真实Keychain round-trip，普通测试继续文件fallback。
- **下一门：** 当前最终源码的macOS、iOS/iPadOS、tvOS、visionOS四平台generic Debug warnings-as-errors顺序build；不操作Simulator，检查unsupported targets仍只编译single workspace root。
- **最终四平台build：** `/private/tmp/LuneX-19-4_1-platform-builds-final.RFvm5d`中macOS、iOS/iPadOS、tvOS、visionOS全部`succeeded / 0 error / 0 warning / 0 analyzer warning`；macOS为`x86_64 arm64`，iOS实际Info为multiple scenes true且background audio保留。
- **authority同步：** OpenSpec design/multiwindow spec、runtime contract、roadmap与planning现已记录typed scene ID、runtime fallback、primary/distinct/reconnect/duplicate语义、detach边界、最终证据与未证明的真实窗口/Stage Manager层级。
- **repository pre-gate：** 首轮零命中编排错误后，fresh `/private/tmp/LuneX-19-4_1-repository-pre-r2.03qeW4`完整通过精确15文件scope、scene/coordinator/RootView/Info语义、7新增/0删除/0 skip测试、authority、strict pre-mark `20/48 next 4.1`、稳定generator、retained `8/160/1233`测试、四平台`4/4`及opt-in/diff边界。
- **状态：** `complete`；4.1已勾选，预期权威状态`21/48 ready`、next `4.2`。下一步只读post-mark final-state，不重复generator/test/build或操作Simulator。
- **post-mark final-state：** `/private/tmp/LuneX-19-4_1-final-state.HvXjF0`只读通过strict、`21/48 next 4.2`、最终16文件scope、唯一4.1 checkbox、稳定project、retained evidence及disabled opt-ins；未重复generator/test/build或操作Simulator。下一步精确清理全部4.1临时证据。
- **evidence cleanup：** 13个明确`/private/tmp/LuneX-19-4_1-*`目录与marker已逐项用`find <exact-path> -depth -delete`清理，task prefix零残留；未使用宽泛删除或触碰仓库既有`build/DerivedData`。下一步final diff audit与cleanup final record。
- **final audit：** 完整审读确认coordinator只管理scene attachment与registry generation，disconnect没有close/stop/ownership transfer；RootView仅迁移顶层scene workspace命令，4.2 global navigation/host/panel bindings仍清晰可见且未提前实现4.4。最终16文件scope、7新增/0删除/0 skip测试、唯一4.1 checkbox、strict `21/48 next 4.2`、稳定project、零task artifact和proof boundary全部一致。下一步cleanup final record与独立commit/push/fetch。
- **cleanup final record：** 通过基线`HEAD == origin/main == remote == 8fcb737`、strict `21/48 next 4.2`、最终16文件scope、唯一4.1 checkbox、稳定project、零task artifact、disabled opt-ins及diff/proof边界。准备精确stage并以独立提交推送4.1。

## 2026-08-22 阶段 19 任务 4.2 启动

- **状态：** `complete`；Task 4.2已通过实现、focused/related/normal、四平台build、authority、generator、strict与repository门禁并勾选；OpenSpec预期为`22/48 next 4.3`。
- **审计缺口：** scene workspace已到达`RootView`，但navigation/tab selection、selected host/app、Add Host sheet、host destructive dialog和host/pairing/catalog/launch panels仍读取primary compatibility projection，第二窗口会显示或修改首窗口状态。
- **已有基础：** manual-host validation/submission、host destructive action、pairing attempt、catalog retry、stream issue/dialog/overlay均已存于`ProductWorkspaceState`并带checked owner/generation；4.2应迁移SwiftUI bindings，不复制runtime/repository或另建presentation owner。
- **实现范围：** 为AppModel增加workspace-scoped navigation、host/app selection、selected values、sheet presentation及initial-load overload；`RootView`移除局部Add Host Boolean并以`ProductWorkspaceSheet.addHost`驱动native sheet，把workspace显式传到LibraryDashboard和四个workflow panel，host dialog从该workspace presentation读取。
- **边界：** stream overlay已由3.5/4.1按workspace接线，本项只保证RootView全链路不回退primary。共享repository mutation reconciliation仍属4.3，owning-window close属4.4，tvOS/visionOS command visibility属4.5，完整双workspace应用矩阵属4.6。
- **验收计划：** 新增focused AppModel binding isolation与RootView source contracts，运行workspace/workflow related矩阵、serial normal及四平台generic Debug；真实opt-in保持unset，不操作Simulator，离线结果不宣称真实窗口/Stage Manager交互。
- **首轮实现：** AppModel新增checked workspace navigation、host/app selection、derived selected values、Add Host sheet present/dismiss与`loadInitialState(in:)`；legacy属性只投影primary。RootView移除局部sheet Boolean并把workspace显式传到LibraryDashboard及host/pairing/catalog/launch panels，host dialog同时核对workspace presentation。
- **macOS compile：** fresh `/private/tmp/LuneX-19-4_2-compile.yIqgzB` generic Debug warnings-as-errors一次通过，structured build为`succeeded / 0 error / 0 warning / 0 analyzer warning`，universal executable为`x86_64 arm64`。
- **focused：** fresh `/private/tmp/LuneX-19-4_2-focused.HVX1et/Focused.xcresult`中workspace binding isolation、legacy compatibility、Add Host sheet、RootView和scene source合同`5/5`通过，零skip/failure且build diagnostics全零。下一步运行workspace/host/catalog/pairing/destructive/session/surface related矩阵。
- **related修复：** 首轮`161/159/0/2`中的catalog失败是source test仍期待旧primary字符串；更新为workspace getter。既有visionOS长流程session等待超时在与修正source test合并的针对性复验中`2/2`通过，确认是时序抖动而非4.2回归。
- **最终related：** fresh `/private/tmp/LuneX-19-4_2-related-final.YjENtl/Related.xcresult`七簇矩阵`161/161`通过、零skip/failure且build diagnostics全零；失败首轮和`2/2`仅保留诊断，不作为最终矩阵证据。
- **最终normal：** 独立fresh `/private/tmp/LuneX-19-4_2-normal-final.MmYrfq/Normal.xcresult`通过`1234 total / 1233 passed / 1 skipped / 0 failed / 0 expected failure`且build diagnostics全零；唯一skip精确为真实Keychain round-trip，两个真实opt-in unset并继续文件fallback。下一步四平台generic Debug。
- **四平台build：** 原会话`/private/tmp/LuneX-19-4_2-platform-builds-final.bWTC1q`顺序完成macOS、iOS/iPadOS、tvOS、visionOS unsigned generic Debug `4/4`；四份structured summary均为`succeeded / 0 error / 0 warning / 0 analyzer warning`，macOS executable为`x86_64 arm64`。未创建、启动、关闭或接管Simulator。
- **源码审计：** RootView全文件`primaryWorkspaceReference`零命中；navigation、host/app selection/derivation、sheet、host dialog、validation/retry panels和既有overlay均消费传入scene workspace。legacy primary属性仅保留compatibility，未提前实现4.3 shared repository reconciliation、4.4 close policy或4.6完整双窗口矩阵。
- **authority同步：** 已更新OpenSpec design/multiwindow spec、runtime contract、completion roadmap与三份planning，记录workspace-local binding语义、stale fail-closed、最终`5/161/1234/4`证据和真实窗口/Stage Manager/signed/live proof边界。task保持pre-mark `21/48 next 4.2`，下一步generator双跑、strict与repository pre-gate。
- **generator/strict：** project在运行generator前、第一次与第二次后SHA-256均为`60e6966fc42bbe0facbb8adfdf66794746948039ba1f190ac13dc0438a9d2224`，工程零diff且OpenSpec strict通过。
- **repository pre-gate：** `/private/tmp/LuneX-19-4_2-repository-pre.xJWEX2`完整通过remote baseline、精确12文件scope、source/test/authority、strict `21/48 next 4.2`、stable project、retained `5/2/161/1234/4` evidence、唯一Keychain skip、disabled opt-ins、零build/test process与diff/artifact边界。现已仅勾选4.2，预期`22/48 next 4.3`。
- **post-mark final-state：** 两轮只读wrapper因checkbox unified-diff前缀索引错误退出后，fresh r3 `/private/tmp/LuneX-19-4_2-final-state-r3.VHGzxH`完整确认strict、OpenSpec `22/48 next 4.3`、最终13文件scope、唯一4.2 checkbox、稳定project、retained evidence、disabled opt-ins与零build/test process；未重复generator/test/build或操作Simulator。下一步逐路径清理4.2 evidence。
- **evidence cleanup：** 首轮因zsh特殊`path`变量在删除前退出后，22个明确`/private/tmp/LuneX-19-4_2-*`目录、marker与generator log已用普通`target`变量和绝对`/usr/bin/find <exact-path> -depth -delete`逐项清理，task prefix零残留；未使用宽泛删除或触碰仓库`build/DerivedData`。
- **authority final audit：** 清理后审计发现runtime contract仍有5处把Add Host/catalog/pairing/host panel/per-scene injection写成4.2 pending，并有一处design迁移时态。已精确更新为explicit scene workspace已完成，同时保留4.3 shared reconcile、4.4 close、5.x accessibility与6.x strings边界；production/test不变，不重复test/build/generator。
- **final audit：** 修正旧时态后完整只读门通过最终13文件scope、RootView primary fallback零命中、authority 4.2 pending零残留、1新增/0删除/0 skip测试、唯一4.2 checkbox、strict `22/48 next 4.3`、稳定project、零task artifact、disabled opt-ins与`74faaba`三方基线；未发现需追加production/test修改。下一步cleanup final record与独立commit/push/fetch。
- **cleanup final record：** 通过`HEAD == origin/main == remote == 74faaba`、最终13文件、strict `22/48 next 4.3`、稳定project、source/authority/diff边界、零4.2 artifact、disabled opt-ins与零build/test进程。Task 4.2准备精确stage并以独立提交推送。

## 2026-08-22 阶段 19 任务 4.3 启动

- **状态：** `complete`；Task 4.3已通过实现、focused/related/normal、四平台build、authority、generator、strict与repository门禁并勾选；OpenSpec预期为`23/48 next 4.4`。
- **审计结论：** cached catalog load和catalog refresh已调用`publishCatalogStateToWorkspaces`，所有live workspace按各自owner得到current或cached状态；settings是AppModel唯一process-level observable值，不复制进workspace。真实缺口在shared hosts/trust：load/add/remove只完整更新发起workspace的host-library phase，trust reset/pairing completion不会清理其他选择同一host的陈旧pairing presentation。
- **实现范围：** 增加一个只同步shared host-derived presentation的reconciliation helper，在host load/add/remove/reset与pairing completion成功后遍历live workspace；统一更新first-use/available phase，并仅在明确trust mutation时清理选择目标host的非owner pairing state。保留navigation、sheet/dialog、draft/submission、local retry及unrelated destructive state。
- **ownership边界：** reconciliation不得写`productSessionOwner`、media/input owner或scene attachment；catalog沿用现有owner-keyed publish，settings保持单一process value。测试必须证明inactive workspace mutation不转移另一workspace的active session owner。
- **验收计划：** 补host add/remove/trust/pairing、catalog与settings的two-workspace application tests，先运行fresh warnings-as-errors compile与focused，再运行workspace/workflow related、serial normal和四平台generic Debug；真实Keychain/live-host opt-in保持unset，不操作Simulator。
- **首轮实现：** `reconcileSharedHostRepositoryState`先运行既有selection/catalog owner reconcile，再向每个live workspace只发布`.firstUse`/`.available`；可选trust host只清理匹配workspace pairing，并可保留当前pairing owner。host load/add/remove/reset与authenticated completion接入，catalog/settings路径保持原架构。
- **macOS compile：** fresh `/private/tmp/LuneX-19-4_3-compile.FrCx2H` generic Debug warnings-as-errors一次通过，structured build为`succeeded / 0 error / 0 warning / 0 analyzer warning`且universal executable为`x86_64 arm64`。
- **focused：** fresh `/private/tmp/LuneX-19-4_3-focused.TFO9o2/Focused.xcresult`中shared host add、settings、catalog、pairing completion、trust reset和inactive remove/session owner六项application tests `6/6`通过，零skip/failure且build diagnostics全零。下一步七簇related。
- **related：** fresh `/private/tmp/LuneX-19-4_3-related.bKIZsI/Related.xcresult`覆盖registry、host、catalog、pairing、destructive、AppModel workflow与surface七簇`167/167`通过，零skip/failure且build diagnostics全零。
- **normal：** 独立fresh serial `/private/tmp/LuneX-19-4_3-normal.6n51ND/Normal.xcresult`通过`1240 total / 1239 passed / 1 skipped / 0 failed / 0 expected failure`，唯一skip精确为显式禁用的真实Keychain round-trip；两个真实opt-in unset、文件fallback继续。下一步四平台generic Debug。
- **四平台build：** `/private/tmp/LuneX-19-4_3-platform-builds.zXQVKQ`顺序完成macOS、iOS/iPadOS、tvOS、visionOS unsigned generic Debug `4/4`；四份structured summary均`succeeded / 0 error / 0 warning / 0 analyzer warning`且macOS executable为`x86_64 arm64`。未操作Simulator lifecycle。
- **实现审计：** production pairing trust由`PersistingPairingProvider`在completion前提交；AppModel只发布已提交shared record。helper内scene/session/media/input owner写入零处，新增6项/删除0项测试且无skip。catalog/settings保持既有shared架构，不创建workspace副本。
- **authority同步：** 已更新OpenSpec design/multiwindow spec、runtime contract、completion roadmap与三份planning，记录host/trust/catalog/settings publish、local presentation保留、owner零transfer、最终`6/167/1240/4`证据和真实窗口/live proof边界。task保持pre-mark `22/48 next 4.3`，下一步generator双跑、strict与repository pre-gate。
- **generator/strict：** project在generator前、第一次与第二次后SHA-256均为`60e6966fc42bbe0facbb8adfdf66794746948039ba1f190ac13dc0438a9d2224`且工程零diff，OpenSpec strict通过。
- **repository pre-gate：** `/private/tmp/LuneX-19-4_3-repository-pre.XNCvB0`完整通过remote baseline、精确12文件scope、helper/5 calls/owner零写入、6新增/0删除/0 skip测试、authority、strict `22/48 next 4.3`、stable project、retained `6/167/1240/4`证据、唯一Keychain skip、disabled opt-ins、零build/test process与diff/artifact边界。现已仅勾选4.3，预期`23/48 next 4.4`。
- **post-mark final-state：** `/private/tmp/LuneX-19-4_3-final-state.mhqgr1`只读确认strict、OpenSpec `23/48 next 4.4`、最终13文件scope、唯一4.3 checkbox、稳定project、retained evidence、disabled opt-ins与零build/test process；未重复generator/test/build或操作Simulator。下一步逐路径清理4.3 evidence。
- **evidence cleanup：** 16个明确`/private/tmp/LuneX-19-4_3-*`目录、marker与generator log已逐项以绝对`/usr/bin/find <exact-path> -depth -delete`清理，task prefix零残留；未使用宽泛删除或触碰仓库`build/DerivedData`。下一步final diff/authority audit。
- **authority final audit：** cleanup后发现runtime contract两处仍把shared reconciliation写成later/pending task，roadmap一处仍把4.3列入pending。已精确同步为4.3当前实现语义，只保留4.4 close、4.5窗口命令与4.6双workspace矩阵pending；production/test不变，不重复generator/test/build。首个组合补丁因换行锚点不匹配被整体拒绝且无部分修改，随后按实际行内容应用。
- **final audit编排修正：** 首轮只读门已通过13文件scope、helper owner零写入和OpenSpec strict，随后在读取apply进度时因zsh只读变量名`status`退出；未改仓库、未运行generator/test/build或操作设备。改用`apply_json`并从完整只读门重跑。
- **final audit：** corrected完整只读门通过最终13文件scope、helper 1定义/5 calls/0 owner writes、6新增/0删除/0 skip测试、唯一4.3 checkbox、strict与`23/48 next 4.4`、稳定project、零4.3 artifact、disabled opt-ins、零build/test进程及`a6af2c8`三方基线。下一步cleanup final record与独立commit/push/fetch。
- **cleanup final record：** Task 4.3最终状态保持上述全部门禁，production/test未在cleanup后变化，文档旧时态已归零；准备精确stage 13文件并提交`Reconcile shared workspace repositories`，提交后直接进入4.4且不archive change。

## 2026-08-22 阶段 19 任务 4.4 启动

- **状态：** `in_progress`；Task 4.3已以`1c9d348 Reconcile shared workspace repositories`提交推送并确认三方SHA一致、工作树clean，OpenSpec为`23/48 next 4.4`。
- **合同：** owning scene close先验证attachment token；inactive/non-owner只detach，current owner在另一声明式presentation仍存在时保留原owner，否则launching/waiting/streaming/reconnecting执行既有幂等clean stop，already-stopping加入同一stop operation，replaced/stale attachment fail closed。任何分支都不隐式transfer owner。
- **实现设计：** 在`ProductWorkflowState`增加纯close reducer与typed outcome，scene coordinator增加只读attachment查询；AppModel把stop operation reservation提取为同步begin helper，使close能先保留唯一teardown、再detach并await。mobile retention仅接受同一active session的actual PiP/audio-only continuity，另一attachment也必须属于同一workspace。
- **验收计划：** 纯policy矩阵加AppModel inactive、launching、streaming、reconnecting、retained presentation、replaced attachment、already-stopping应用测试；随后warnings-as-errors compile、focused、相关scene/session矩阵、serial normal与四平台generic Debug。两个真实opt-in保持unset，不操作Simulator lifecycle。
- **production首轮：** 已增加typed close disposition/outcome、纯policy、scene attachment只读查询；AppModel close同步保留或建立唯一stop operation后detach并await，PiP/audio-only只在active owner/media generation一致时允许retain；SwiftUI onDisappear启动MainActor unstructured close task。下一步补全phase/application tests后首次编译。
- **compile gate修正：** 首轮fresh macOS generic Debug在Swift编译前因命令漏传`CODE_SIGNING_ALLOWED=NO`而被development entitlement signing要求拒绝；没有源码诊断、测试或设备副作用，该轮不计验收。按既有unsigned gate补齐设置并从新目录重跑。
- **focused首轮：** 7项中6项通过；active-phase组合用例在reconnecting发现environment stop记录为同一session两次。根因是reconnect事件已teardown media generation，terminal close又无条件调用environment stop；provider仍只stop一次。已收紧`stopMediaEnvironment`只对仍匹配`activeMediaSessionID`的session调用环境stop，launching预期0次、streaming/reconnecting各1次，fresh focused从头复验。
- **focused第二轮：** 仍为6/7且同一reconnect断言，证明仅捕获owner布尔值不能关闭首次suspension前的并发窗口。现改为函数进入时先guard并原子撤销active media ID/generation reservation，再以本地generation完成清理；并发close的第二调用在任何await前no-op。下一轮fresh focused验证真正的single-owner teardown。
- **最终focused：** fresh r3结构化通过`7/7`、0 skip/failure/expected failure，build为`succeeded / 0 error / 0 warning / 0 analyzer warning`；compile r2同样diagnostics全零且macOS executable为`x86_64 arm64`。下一步运行scene/session/recovery/teardown相关扩大矩阵。
- **related首轮修正：** 扩大矩阵发现8项pending-start/tvOS/visionOS回归，证明active-media early return破坏既有平台stop/input/presentation清理；pending media start合同也需要取消与late-start cleanup两次幂等environment stop。已完整恢复既有media cleanup，close唯一性继续由single `ProductSessionStopOperation`和control-provider stop证明；focused reconnect预期两次generation cleanup但provider仍精确一次。首轮related不计验收。
- **final focused/related：** 恢复原media cleanup后的fresh focused为`7/7`，六簇related为`150/150`；两份build均`succeeded / 0 error / 0 warning / 0 analyzer warning`且零skip/failure。pending startup、cancellation/recovery及tvOS/visionOS presentation/input teardown全部回归通过。下一步独立serial normal。
- **serial normal：** fresh suite结构化通过`1246 total / 1245 passed / 1 skipped / 0 failed / 0 expected failure`，build diagnostics全零；唯一skip精确为显式关闭的真实Keychain round-trip，两个opt-in unset且文件fallback继续。下一步四平台generic Debug。
- **四平台build：** `/private/tmp/LuneX-19-4_4-platform-builds.4oV89T`顺序完成macOS、iOS/iPadOS、tvOS、visionOS unsigned generic Debug `4/4`；四份structured summary均为`succeeded / 0 error / 0 warning / 0 analyzer warning`，macOS executable为`x86_64 arm64`。未操作Simulator lifecycle。
- **authority同步：** 已更新OpenSpec design/multiwindow spec、runtime contract、completion roadmap与三份planning，记录close reducer、stale/non-owner detach、actual retained presentation、同步stop reservation、already-stopping共享teardown、media cleanup generation边界、最终`7/150/1246/4`证据和未证明的真实窗口/Stage Manager/signed/live层级。task保持pre-mark `23/48 next 4.4`，下一步generator双跑、strict与repository pre-gate。
- **repository pre-gate：** `/private/tmp/LuneX-19-4_4-repository-pre.ih2WRB`完整通过三方baseline、精确12文件scope、source close语义、6新增/0删除/0 skip测试、authority、strict `23/48 next 4.4` pre-mark、稳定project、retained `7/150/1246/4` evidence、唯一Keychain skip、disabled opt-ins、零build/test process与diff/artifact边界。现已仅勾选4.4并同步planning，权威进度为`24/48 next 4.5`。
- **post-mark final-state：** `/private/tmp/LuneX-19-4_4-final-state.T71IuP`只读确认strict、OpenSpec `24/48 next 4.5`、最终13文件scope、唯一4.4 checkbox、稳定project、retained evidence、disabled opt-ins与零build/test process；未重复generator/test/build或操作Simulator。下一步精确清理全部4.4临时证据。
- **evidence cleanup：** 首轮`mapfile`兼容性错误后，14个明确`/private/tmp/LuneX-19-4_4-*`目录与generator log已逐项以绝对`/usr/bin/find <exact-path> -depth -delete`清理，task prefix零残留；未使用宽泛删除或触碰仓库`build/DerivedData`。下一步final diff/authority audit。
- **final audit：** corrected完整只读门通过最终13文件scope、begin-stop-before-detach、actual continuity/attachment retention、stale/already-stopping语义、media cleanup基线、6新增/0删除/0 skip测试、唯一4.4 checkbox、strict `24/48 next 4.5`、稳定project、零task artifact、disabled opt-ins、零build/test进程及`1c9d348`三方基线。未发现需追加production/test修改，准备cleanup final record后独立提交推送。
- **cleanup final record：** Task 4.4最终状态保持上述全部门禁，production/test在行为验收后未变化，authority旧时态与task artifact均归零；准备精确stage 13文件并提交`Apply owning window close policy`，提交后直接进入4.5且不archive change。

## 2026-08-22 阶段 19 任务 4.5 启动

- **状态：** `in_progress`；Task 4.4已以`b60779b Apply owning window close policy`提交推送，fetch/ls-remote确认三方SHA一致且工作树clean，OpenSpec为`24/48 next 4.5`。
- **初步窗口审计：** App没有自定义`openWindow`/`dismissWindow`或窗口command menu；macOS/iOS使用typed workspace `WindowGroup`，tvOS与visionOS由编译分支保留普通single-workspace `WindowGroup`并直接注入checked primary。4.5需以显式产品能力合同与source/application tests证明不暴露unsupported command，而非增加无功能按钮。
- **ownership审计方向：** 继续追踪tvOS remote focus与visionOS input capture从`RootView(workspace:)`到AppModel/session/media generation的调用，确认current `ProductSessionOwner.workspace`参与admission；若仅按process session判断，则补typed single-workspace policy与checked adapter入口，不提前实现4.6双workspace矩阵。

## 2026-08-22 阶段 19 任务 4.5 续接

- **状态：** `in_progress`；OpenSpec权威为`24/48 ready`、next `4.5`。继续验证tvOS/visionOS不暴露不支持的窗口命令，并让platform focus/input adapter只接受checked primary workspace owner。
- **补丁编排错误：** 首个production+test组合补丁因`ProductWorkflowSurfaceTests`锚点不匹配被`apply_patch`原子拒绝，无部分修改；随后已按真实锚点拆分成功。
- **focused首轮错误：** `/private/tmp/LuneX-19-4_5-focused.AR0hPZ`在0 tests的测试编译阶段失败，新测试误用了不存在的`RemoteInputEvent.pointerMove`；production编译没有诊断。已改用合法的`.pointer(.absoluteMove(...))`事件并将从fresh evidence目录重跑，该失败bundle不计验收。
- **目标工具状态：** 续接时旧长期goal被报告为`blocked`但同时被视为unfinished，`create_goal`因此拒绝按用户要求重建；没有仓库、Keychain、live host、Simulator或runtime副作用。继续以OpenSpec和三份planning为执行权威，不把未完成旧目标误标complete。
- **focused第二轮错误：** fresh `/private/tmp/LuneX-19-4_5-focused-final.30wDff`执行`2 total / 1 passed / 1 failed`；non-primary platform ownership application test通过，唯一失败是source test用`range(of: "#else")`误匹配`#elseif os(iOS)`前缀，导致vision切片包含iOS `WindowGroup`。production scene正确；测试已改为匹配完整缩进`#else`行并将从新目录重跑，该bundle不计验收。
- **最终focused：** fresh `/private/tmp/LuneX-19-4_5-focused-r2.Cav4yU/Focused.xcresult`结构化通过`2/2`、0 skip/failure/expected failure，build为`succeeded / 0 error / 0 warning / 0 analyzer warning`。source scene与active non-primary TV/Vision adapter fail-closed合同均闭合，下一步related矩阵。
- **related：** fresh `/private/tmp/LuneX-19-4_5-related.Ag1mod/Related.xcresult`结构化通过`310/310`、0 skip/failure/expected failure，build diagnostics全零。矩阵覆盖AppModel、Product workspace/workflow、tvOS focus/control/presentation及visionOS input/presentation；下一步独立fresh serial normal。
- **serial normal：** fresh `/private/tmp/LuneX-19-4_5-normal.SJ9MHO/Normal.xcresult`结构化通过`1248 total / 1247 passed / 1 skipped / 0 failed / 0 expected failure`，build diagnostics全零。唯一skip精确为显式关闭的真实Keychain round-trip，两个真实opt-in unset且普通identity继续文件fallback；下一步四平台unsigned generic Debug。
- **四平台build：** `/private/tmp/LuneX-19-4_5-platform-builds.hEsR0g`顺序完成macOS、iOS/iPadOS、tvOS、visionOS unsigned generic Debug `4/4`；四份structured build均`succeeded / 0 error / 0 warning / 0 analyzer warning`，macOS executable为`x86_64 arm64`。未操作Simulator lifecycle；下一步authority同步与repository门禁。
- **authority同步：** 已更新OpenSpec design/multiwindow spec、native product runtime contract、completion roadmap与三份planning，记录tvOS单一`WindowGroup`、visionOS显式单实例`Window`、无application window commands、primary-owner-only adapter admission、最终`2/310/1248/4`证据及signed/physical/live边界。Task保持pre-mark，下一步generator双跑、strict与repository pre-gate。
- **generator/strict：** `project.pbxproj`在generator前、连续两次运行后SHA-256均为`60e6966fc42bbe0facbb8adfdf66794746948039ba1f190ac13dc0438a9d2224`且工程零diff；OpenSpec strict为`1/1` valid。下一步repository pre-gate，通过前不勾选4.5。
- **repository包装器错误：** 首轮命令在shell启动前因functions JavaScript模板中的Markdown反引号触发`SyntaxError: Unexpected number`；没有运行fetch/OpenSpec/xcresult门禁，没有仓库、Keychain、live host或Simulator副作用。改用不含反引号的静态匹配并从fresh gate目录完整执行。
- **repository输出编排错误：** corrected gate运行超过10秒首个yield后，上层只输出嵌套结果的`output`而没有保留`session_id`；目录内strict/apply及全部test/build JSON均已生成且进程已结束，但最终marker不可读，因此该轮不计最终门禁。改用30秒yield从fresh目录完整重跑，避免丢失session状态。
- **repository pre-gate：** fresh `/private/tmp/LuneX-19-4_5-repository-pre-final.cLDETj`完整通过三方remote基线、精确11文件pre-mark scope、scene/owner/test语义、authority、strict `24/48 next 4.5`、稳定project、retained `2/310/1248/4`证据、唯一Keychain skip、disabled opt-ins、零build/test进程与diff边界。
- **状态：** `complete`；现已仅勾选4.5，预期OpenSpec为`25/48 next 4.6`。下一步只读post-mark final-state，不重复generator/test/build或操作Simulator。
- **post-mark final-state：** fresh `/private/tmp/LuneX-19-4_5-final-state.wYwO7N`只读确认strict、OpenSpec `25/48 next 4.6`、最终12文件scope、唯一4.5 checkbox、稳定project、retained `2/310/1248/4`证据、disabled opt-ins与零build/test进程；未重复test/build/generator或操作Simulator。下一步逐路径清理4.5 evidence。
- **evidence cleanup：** 12个明确`/private/tmp/LuneX-19-4_5-*`目录/log已逐项用绝对`/usr/bin/find <exact-path> -depth -delete`清理，task prefix零残留；未使用宽泛删除或触碰仓库既有`build/DerivedData`。下一步cleanup后final diff/authority audit。
- **cleanup final audit：** 完整只读门通过最终12文件scope、visionOS/tvOS scene与primary-only adapter source语义、2新增/0删除/0 skip测试、唯一4.5 checkbox、strict `25/48 next 4.6`、稳定project、零task artifact、disabled opt-ins、零build/test进程及`b60779b`三方基线。未发现需追加修改，准备精确stage并独立提交推送。

## 2026-08-22 阶段 19 任务 4.6 启动

- **状态：** `in_progress`；Task 4.5已以`4ffdd43 Enforce single workspace platform ownership`提交推送，`HEAD == origin/main == remote`且工作树clean，OpenSpec为`25/48 next 4.6`。
- **覆盖盘点：** registry、host/pairing/catalog/destructive与AppModel现有用例分别覆盖局部isolation、shared publication、stale generation、non-owner command和close policy，但缺少同一AppModel、同一双live-workspace时间线的完整application matrix。
- **实现边界：** 4.6优先新增一条确定性组合测试，串联navigation/selection/presentation isolation、shared host/catalog/settings updates、generation replacement stale rejection、non-owner overlay/stop及owning/non-owning close；不改并行session架构、不提前做5.x accessibility或7.x end-to-end product flow。
- **验收计划：** focused组合测试，workspace/session/close related矩阵，独立serial normal和四平台unsigned generic Debug；真实Keychain/live-host opt-in保持unset，不操作Simulator lifecycle。
- **focused首轮：** 两条新application test中non-owner/owner-close用例通过，local/shared/stale用例唯一失败为测试直接调用registry replacement后仍保留scene attachment token，close按该非产品时序正确返回`.detached`而非预期`.rejectedStaleAttachment`。不修改production；改用真实scene disconnect后按serialized identity reconnect生成replacement，再验证旧attachment fail closed，并从fresh evidence重跑。
- **最终focused：** fresh `/private/tmp/LuneX-19-4_6-focused-r2.32vX2N`结构化通过`2/2`、0 skip/failure/expected failure，build为`succeeded / 0 error / 0 warning / 0 analyzer warning`；production零修改。下一步运行workspace、workflow、session与scene-close相关扩大矩阵。
- **related：** fresh `/private/tmp/LuneX-19-4_6-related.fgO1cz`覆盖AppModel、workspace registry、host/pairing/catalog/destructive/surface及session state/cancellation/recovery/media environment共`259/259`通过，0 skip/failure且structured build diagnostics全零。下一步独立fresh serial normal。
- **serial normal：** fresh `/private/tmp/LuneX-19-4_6-normal.ypbWie`结构化通过`1250 total / 1249 passed / 1 skipped / 0 failed / 0 expected failure`，build diagnostics全零；唯一skip仍为显式真实Keychain round-trip，普通identity文件fallback与两个unset opt-in保持。下一步四平台unsigned generic Debug。
- **四平台build：** `/private/tmp/LuneX-19-4_6-platform-builds.kxDePH`顺序完成macOS、iOS/iPadOS、tvOS、visionOS unsigned generic Debug `4/4`；四份structured build均`succeeded / 0 error / 0 warning / 0 analyzer warning`，macOS executable为`x86_64 arm64`。未操作Simulator lifecycle。
- **覆盖审计与authority同步：** 两条application timeline完整覆盖local navigation/selection/presentation、shared catalog/settings/host update、真实scene replacement后的stale generation、non-owner overlay/stop及non-owner/owner close policy；production/project graph零修改。已同步design、multiwindow spec、runtime contract与roadmap，并保留signed/physical/live证明边界。Task仍保持pre-mark，下一步generator、strict与repository pre-gate。
- **generator/strict：** `project.pbxproj`在generator前及连续两次运行后SHA-256均为`60e6966fc42bbe0facbb8adfdf66794746948039ba1f190ac13dc0438a9d2224`且工程零diff；OpenSpec strict `1/1` valid。下一步fresh repository pre-gate，通过前保持`25/48 next 4.6`。
- **repository pre-gate：** fresh `/private/tmp/LuneX-19-4_6-repository-pre.4lEziF`通过remote baseline、8文件精确scope、production/project零diff、test/authority、OpenSpec pre-mark `25/48 next 4.6`、stable generator、`2/259/1250`与四平台`4/4` retained evidence、disabled opt-ins、零process/artifact及final diff十组门。现已只勾选4.6，预期推进至`26/48 next 5.1`；下一步只读post-mark，不重复行为门。
- **post-mark final-state：** fresh `/private/tmp/LuneX-19-4_6-final-state.B018Gb`只读确认strict、OpenSpec `26/48 next 5.1`、最终9文件scope、唯一4.6 checkbox、稳定project、retained evidence、disabled opt-ins与零build/test process；未重复test/build/generator或操作Simulator。下一步逐路径精确清理4.6 evidence。
- **evidence cleanup：** 15个明确`/private/tmp/LuneX-19-4_6-*`目录、path文件与generator log已逐项用绝对`/usr/bin/find <exact-path> -depth -delete`清理，task prefix零残留；未使用宽泛删除或触碰仓库既有`build/DerivedData`。下一步cleanup后final diff/authority audit。
- **authority时态修正：** cleanup后复读发现runtime contract的3.7历史段落仍把multiwindow close列为later work；已同步为4.4 close与4.6 two-workspace matrix均已提供offline evidence，只保留5.x accessibility与7.x cross-product pending。production/test不变，下一步从完整只读final audit重跑。
- **cleanup final audit：** 完整只读门通过最终9文件scope、production/project零diff、2新增/0删除/0 skip测试、authority旧时态零残留、唯一4.6 checkbox、strict `26/48 next 5.1`、稳定project、零task artifact、disabled opt-ins、零build/test进程与`4ffdd43`三方基线。未发现需追加实现修改，准备精确stage并独立提交推送。
- **提交推送：** Task 4.6已以`a2386ea Cover two workspace application matrix`提交并推送，fetch/ls-remote确认`HEAD == origin/main == remote`且工作树clean；OpenSpec为`26/48 next 5.1`。

## 2026-08-22 阶段 19 任务 5.1 启动

- **状态：** `in_progress`；目标是为host、pairing、catalog、stream、settings、diagnostics的全部状态与动作定义可本地化semantic descriptor，包含role、value、eligibility和destructive属性。
- **边界：** 本项建立typed descriptor与现有surface映射，不提前实现5.2 adaptive layout、5.3 keyboard focus/default/cancel、5.4 touch/reduced-motion、5.5 tvOS/visionOS focus或5.6完整accessibility matrix；物理VoiceOver/Voice Control继续属于独立证明层级。
- **focused编译错误：** 首轮`/private/tmp/LuneX-19-5_1-focused.JABMVl`在测试编译阶段以exit 65结束；structured build result仅报告`PairingUIState`调用参数顺序错误（`isRunning`必须位于`issue`之前），0项测试执行、production零诊断。该bundle不计最终证据；已仅调整测试调用顺序，下一步从fresh evidence重跑5项focused。
- **focused r2与审计：** fresh `/private/tmp/LuneX-19-5_1-focused-r2.iAshJw`通过`5/5`且structured build diagnostics全零。API审计决定把805行语义实现拆入独立`ProductAccessibilitySemantics.swift`，并修正status不继承destructive action标记及non-owner/stale/no-session controls eligibility；下一步generator后从fresh evidence重跑focused。
- **focused final：** generator纳入独立语义文件后的fresh `/private/tmp/LuneX-19-5_1-focused-r3.yt3TUo`通过`5/5`，新增destructive-status与non-owner controls断言均闭合；下一步运行12类related回归矩阵。
- **related：** fresh `/private/tmp/LuneX-19-5_1-related.c5kD2C`覆盖13个完整测试类并通过`238/238`，零skip/failure且structured build diagnostics全零；下一步独立fresh serial normal。
- **normal：** fresh serial `/private/tmp/LuneX-19-5_1-normal.uHOeSU`通过`1255 total / 1254 passed / 1 skipped / 0 failed`且structured build diagnostics全零；唯一skip为显式真实Keychain测试，两个真实opt-in继续unset并使用文件fallback。下一步四平台unsigned generic Debug。
- **xcresult串行读回：** 上轮同时读取同一`Normal.xcresult`时，`xcresulttool`曾因内部`database.sqlite3`移动竞争报错；测试与已成功的summary/build result不受影响。本轮没有重跑suite，改为单独串行读取tests tree，确认唯一skip精确为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`。
- **四平台build：** `/private/tmp/LuneX-19-5_1-platform-builds.Om075Y`已顺序完成macOS、iOS/iPadOS、tvOS、visionOS unsigned generic Debug `4/4`。四份`Build.xcresult`串行读回均为`succeeded / 0 error / 0 warning / 0 analyzer warning`；macOS产物首次按错误的`LuneX.app`名称定位未找到文件，随后按工程实际`LuneX-macOS.app/Contents/MacOS/LuneX-macOS`核验为`x86_64 arm64`。没有重复build，也没有操作Simulator。
- **authority同步：** 已更新OpenSpec design/accessibility spec、native product workflow contract、completion roadmap与三份planning，记录typed/localized role/value/hint/eligibility/destructive合同、PIN与endpoint隐私边界、最终`5/238/1255/4`证据及physical assistive-technology证明边界。Task保持pre-mark `26/48 next 5.1`，下一步generator双跑、strict与repository pre-gate。
- **generator/strict：** `project.pbxproj`在generator前及连续两次运行后SHA-256均为`4214a283c9e353456098dba5504f2cef3cf7cabd78ff2d4c51a2d34060b2f04f`；OpenSpec strict validation通过。5.1仍未勾选，下一步fresh repository pre-gate。
- **repository pre-gate：** fresh `/private/tmp/LuneX-19-5_1-repository-pre.2vaeVN`完整通过remote baseline、11文件pre-mark scope、source membership、六类semantic completeness/privacy、authority、strict `26/48 next 5.1`、稳定project、retained `5/238/1255/4` evidence、唯一Keychain skip、disabled opt-ins、零LuneX build/test进程与diff检查。现仅勾选5.1并将状态推进到`27/48 next 5.2`；下一步只读post-mark，不重复test/build/generator或操作Simulator。
- **状态：** `complete`；Task 5.1仅完成typed/localized semantic descriptor合同，5.2至5.6与physical assistive-technology验收仍pending，整个change不可archive。
- **post-mark final-state：** fresh `/private/tmp/LuneX-19-5_1-final-state.cLptxe`只读确认strict、OpenSpec `27/48 next 5.2`、最终12文件scope、唯一5.1 checkbox、稳定project、retained evidence、disabled opt-ins与零LuneX build/test进程；未重复test/build/generator或操作Simulator。下一步逐路径精确清理5.1 evidence。
- **evidence cleanup：** 19个明确`/private/tmp/LuneX-19-5_1-*`目录、path、JSON与generator log已逐项用绝对`/usr/bin/find <exact-path> -depth -delete`清理，task prefix零残留；未使用宽泛删除或触碰仓库既有`build/DerivedData`。下一步cleanup后final diff/authority audit。
- **authority时态修正：** cleanup后复读发现runtime contract两处及roadmap一处仍把整个5.x描述为later/pending；已收紧为5.1 typed semantic descriptor完成、5.2至5.6与physical gate仍pending。production/test不变，下一步完整只读final audit。
- **cleanup final audit：** 完整只读门通过最终12文件scope、846行独立semantic source、六类ID/surface、5项新增/0删除/0 skip测试、隐私与destructive/eligibility合同、唯一5.1 checkbox、strict `27/48 next 5.2`、稳定project、零task artifact、disabled opt-ins、零LuneX build/test进程及`a2386ea`三方基线。未发现需追加修改，准备精确stage并独立提交推送。

## 2026-08-22 阶段 19 任务 5.2 启动

- **状态：** `in_progress`；Task 5.1已以`6a94c68 Define localized product semantics`提交推送，fetch/ls-remote确认三方SHA一致且工作树clean；OpenSpec为`27/48 next 5.2`。
- **布局审计：** `LibraryDashboardView`只在iOS compact size class使用单列，macOS窄detail和iPad窗口在size class未切换时仍强制两列`Grid`；Host四动作、pairing PIN/submit/cancel、pairing progress与Apps header均为固定`HStack`。Settings和stream overlay已有Dynamic Type/`ViewThatFits`合同，可直接复用模式。
- **实现边界：** 新增actual available width + size class + accessibility Dynamic Type驱动的pure dashboard layout reducer；dashboard在所有平台窄宽度/无效宽度下fail closed单列，命令组用horizontal-first/vertical-fallback reflow。只完成5.2 layout，不提前实现5.3 focus/default/cancel、5.4 touch/reduced-motion或5.5平台focus。
- **focused：** fresh `/private/tmp/LuneX-19-5_2-focused.jmRbGA`通过layout reducer与RootView adaptive source合同`2/2`，0 skip/failure且structured build为`succeeded / 0 error / 0 warning / 0 analyzer warning`。下一步运行workflow/settings/platform presentation related矩阵。
- **related首轮异常：** `/private/tmp/LuneX-19-5_2-related.bWtX3d`最终可结构化读取为`240 total / 238 passed / 2 failed`且build diagnostics全零；失败为pairing authenticated trust用例的`requestTimeout`与already-stopping close用例在断言时仍为`streaming`。本轮并行矩阵不计最终验收；production布局改动未触及两条时序路径，下一步从两个fresh目录分别串行定向复验，再决定是否需要修复或改用完整串行related矩阵。
- **失败项隔离复验：** pairing `/private/tmp/LuneX-19-5_2-pairing-isolated.FbBddD`与already-stopping close `/private/tmp/LuneX-19-5_2-stop-isolated.xSummF`在各自fresh DerivedData、`-parallel-testing-enabled NO`下均结构化`1/1`通过且build diagnostics全零；耗时分别恢复为0.009秒与0.015秒。判定首轮为并行调度/资源干扰，不修改无关production；下一步用fresh完整串行13类矩阵取得最终related证据。
- **最终related：** fresh串行 `/private/tmp/LuneX-19-5_2-related-serial.CmIwbs`覆盖相同13个完整测试类并结构化通过`240/240`，0 skip/failure/expected failure，build为`succeeded / 0 error / 0 warning / 0 analyzer warning`。下一步运行独立fresh serial normal suite，真实Keychain/live-host opt-in继续unset。
- **serial normal：** fresh `/private/tmp/LuneX-19-5_2-normal.KP9sEP`结构化通过`1257 total / 1256 passed / 1 skipped / 0 failed / 0 expected failure`，build diagnostics全零；唯一skip精确为`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`，普通测试继续文件identity fallback且两个真实opt-in unset。下一步四平台unsigned generic Debug。
- **四平台build：** `/private/tmp/LuneX-19-5_2-platform-builds.ilPh0L`顺序完成macOS、iOS/iPadOS、tvOS、visionOS unsigned generic Debug `4/4`；四份structured build均`succeeded / 0 error / 0 warning / 0 analyzer warning`，macOS executable为`x86_64 arm64`。未操作Simulator lifecycle；下一步authority同步、generator双跑、strict与repository pre-gate。
- **authority/generator/strict：** 已同步design、accessibility spec、native product workflow contract、roadmap与planning，记录actual-width/Dynamic-Type/reflow合同、最终`2/240/1257/4`证据和physical resize/accessibility边界。generator前后连续两次project SHA-256均为`4214a283c9e353456098dba5504f2cef3cf7cabd78ff2d4c51a2d34060b2f04f`且工程零diff，OpenSpec strict valid；5.2仍保持pre-mark `27/48 next 5.2`，下一步fresh repository pre-gate。
- **repository gate包装失败：** 首个JavaScript包装器在进入shell前把`${LUNEX_RUN_KEYCHAIN_TEST+x}`解析为模板插值并以`ReferenceError`退出；没有执行任何门禁子命令、产生临时目录或项目副作用。下一轮改用不含`${...}`的`env`精确匹配，从fresh目录完整运行且不复用本轮。
- **repository gate计数失败：** corrected fresh `/private/tmp/LuneX-19-5_2-repository-pre-final.*`已通过前8组及第9组opt-in/process，但最后把多文件`rg -c`的`filename:count`输出交给整数`test`而退出；仓库未修改且checkbox仍未勾选，本轮不计最终门禁。下一轮用`awk`汇总计数并从另一fresh目录完整重跑九组。
- **repository pre-gate：** fresh `/private/tmp/LuneX-19-5_2-repository-pre-final-r2.d1gUM3`完整通过remote baseline、10文件精确scope、implementation/test/authority、OpenSpec pre-mark `27/48 next 5.2`、stable generator、retained `2/240/1257/4` evidence、唯一Keychain skip、disabled opt-ins、零build/test process与final diff九组检查。现只勾选5.2，预期推进至`28/48 next 5.3`；下一步只读post-mark，不重复行为门。
- **状态：** `complete`；fresh post-mark `/private/tmp/LuneX-19-5_2-final-state.eVCutC`只读确认strict、OpenSpec `28/48 next 5.3`、最终11文件scope、唯一5.2 checkbox、稳定project、retained evidence、disabled opt-ins与零build/test process。未重复test/build/generator或操作Simulator；下一步逐路径精确清理5.2 evidence。
- **cleanup验证编排错误：** 25个显式绝对`/usr/bin/find <exact-path> -depth -delete`调用已执行，但zsh函数把变量命名为特殊`path`并覆盖PATH，导致最后一个非绝对`find`零残留检查报`command not found`。删除范围没有扩张；下一步用绝对`/usr/bin/find`只读核对，若有残留仅补清明确路径。
- **evidence cleanup：** 绝对`/usr/bin/find /private/tmp -maxdepth 1 -name 'LuneX-19-5_2*'`确认task prefix零残留；25个明确目录/path/hash/log均已逐项清理，未使用宽泛删除或触碰仓库既有`build/DerivedData`。下一步cleanup后final diff/authority audit。
- **cleanup后UI合同修正：** final源码复读发现Apps header首选`HStack`未固定整体intrinsic width，超长本地化标题可能被压缩/换行而不触发已声明的vertical fallback。首个跨文件补丁因多余空hunk被`apply_patch`原子拒绝且零文件修改；corrected补丁已暂时取消5.2 checkbox，给该`HStack`补`.fixedSize(horizontal: true, vertical: false)`并把source test锁定到Refresh结构。下一步从fresh evidence重跑focused、serial related、serial normal与四平台build，旧已清理证据不复用。
- **修正后fresh行为门：** `/private/tmp/LuneX-19-5_2-final-verification.h7O9Rb`结构化通过focused `2/2`、相同13类serial related `240/240`、serial normal `1257/1256/1/0`及四平台unsigned generic Debug `4/4`；所有test/build structured diagnostics全零，唯一skip仍为真实Keychain opt-in，macOS为`x86_64 arm64`。下一步generator双跑、strict与fresh repository pre-gate。
- **修正后repository pre-gate：** 同一fresh root完整通过remote/10文件scope、adaptive实现、Apps HStack精确fallback、authority/OpenSpec pre-mark、stable generator、fresh `2/240/1257/4`、safety/privacy与final diff九组检查。现重新只勾选5.2；下一步只读post-mark确认`28/48 next 5.3`。
- **最终post-mark：** 修正后只读门确认strict、`28/48 next 5.3`、最终11文件scope、唯一5.2 checkbox、稳定project、disabled opt-ins与零build/test process；Task 5.2最终状态`complete`，整个change仍有20项且不可archive。下一步精确清理single fresh evidence root。
- **最终evidence cleanup：** 修正后的single fresh root及path文件已分别用绝对`/usr/bin/find <exact-path> -depth -delete`清理，`/private/tmp`下5.2 prefix再次为零；未触碰仓库cache。下一步只读cleanup final audit，通过后提交推送。
- **cleanup final audit：** 完整只读门通过最终11文件scope、pure layout与Apps整体fallback、94新增/0删除测试行、authority current-state、strict `28/48 next 5.3`、稳定project、零task artifact、disabled opt-ins、零process与`6a94c68`三方基线。准备精确stage并独立提交推送。

## 2026-08-22 阶段 19 任务 5.3 启动

- **状态：** `in_progress`；Task 5.2已以`82fd471 Adapt workflow layouts to narrow windows`提交推送，三方SHA一致且工作树clean，OpenSpec为`28/48 next 5.3`。
- **审计缺口：** Add Host虽有局部FocusState但没有initial/default/cancel合同；Pairing没有PIN到progress/result的focus handoff；主要键盘命令依赖隐式visible-label Voice Control名称。stream overlay在macOS/iPadOS也没有明确initial hardware-keyboard focus。
- **system shortcut冲突：** `captureSystemShortcuts`默认true且AppModel把它传入macOS input surface，Command-Q/Tab/H可被远端捕获；这违反当前5.3 OpenSpec“preserving system-reserved shortcuts locally”和阶段14“initial implementation keeps them local”合同。字段需保留持久化兼容，但production admission、UI和semantic状态必须改为Always local。
- **实现边界：** 新增pure focus policy并接线Add Host、Pairing、stream overlay，补default/cancel/Command-S与明确accessibility labels；system-reserved shortcuts无条件local。5.4 touch/reduced-motion、5.5 tvOS/visionOS focus restoration和5.6完整矩阵不提前完成。
- **工具错误：** 首轮测试定位命令末尾使用不存在的`Tests/LuneXCoreTests/*Accessibility*`裸glob，zsh以`no matches found`退出；此前明确文件读取已完成且仓库无变化。后续改用`rg --files`或明确文件名，不重复裸glob。
- **focused：** fresh `/private/tmp/LuneX-19-5_3-focused.kHW6Tc`在macOS、串行、warnings-as-errors和两个真实opt-in unset下通过7个focus/settings/default/reserved-shortcut受影响测试；structured为`7/7`、0 skip/failure且build `succeeded / 0 error / 0 warning / 0 analyzer warning`。下一步fresh serial related矩阵。
- **related首轮失败：** fresh串行 `/private/tmp/LuneX-19-5_3-related-serial.dOPeTZ`结构化为`218 total / 216 passed / 1 skipped / 1 failed`且build diagnostics全零；唯一失败是`ProductHostWorkspaceTests`旧source-contract仍期待局部focus枚举`.address`，production已迁移typed `.manualHostAddress`。更新该断言后从fresh目录完整重跑相同8类矩阵，本轮不计验收。
- **最终related：** fresh串行 `/private/tmp/LuneX-19-5_3-related-serial-r2.B0WeOQ`覆盖相同8个完整测试类并结构化通过`218 total / 217 passed / 1 skipped / 0 failed`，build `succeeded / 0 error / 0 warning / 0 analyzer warning`；唯一skip精确为显式真实Keychain测试。下一步独立fresh serial normal。
- **serial normal：** fresh `/private/tmp/LuneX-19-5_3-normal-serial.lUkIxy`结构化通过`1259 total / 1258 passed / 1 skipped / 0 failed / 0 expected failure`，build diagnostics全零；唯一skip仍为显式真实Keychain测试，两个真实opt-in unset并继续使用文件identity fallback。下一步四平台unsigned generic Debug。
- **四平台build首轮失败：** `/private/tmp/LuneX-19-5_3-platform-builds.FSXIpy`中macOS universal和iOS/iPadOS generic成功且structured diagnostics全零；tvOS因10处新`keyboardShortcut` modifier在SDK上明确unavailable而编译失败，structured为10 errors/0 warnings，fail-fast下visionOS未运行。本轮不计最终验收；将native shortcut modifier精确限制为macOS/iOS，保留全平台accessibility label并从fresh根完整重跑4平台。
- **修复补丁首轮错误：** 首个跨文件条件编译补丁假设Add Host Cancel使用`role: .cancel`，实际源码没有该参数，`apply_patch`校验失败并原子拒绝全部修改。随后读取精确行块并按当前modifier顺序重建补丁，不重复旧上下文。
- **最终四平台build：** fresh `/private/tmp/LuneX-19-5_3-platform-builds-r2.bF0V1U`顺序通过macOS universal、iOS/iPadOS、tvOS、visionOS unsigned generic Debug `4/4`；四份structured build均`succeeded / 0 error / 0 warning / 0 analyzer warning`，macOS executable为`x86_64 arm64`。未操作Simulator lifecycle；下一步authority、generator、strict与repository pre-gate。
- **权威补丁错误：** 首个跨六份authority/tracking文件的大补丁因native workflow合同的实际换行与预期不同被`apply_patch`原子拒绝，零文件修改；已拆成按文件小补丁并以精确当前段落同步，不重复旧换行假设。
- **权威同步：** 已同步OpenSpec design/accessibility spec、native product workflow contract、macOS input lifecycle contract、completion roadmap与三份planning，记录typed focus/shortcut/name策略、legacy JSON兼容、三层system shortcut fail-closed、完整fresh证据及physical assistive-technology/live边界。5.3仍保持pre-mark `28/48 next 5.3`。
- **最终macOS候选：** tvOS条件编译修正后的single fresh root `/private/tmp/LuneX-19-5_3-final-verification.gvmj1Y`重新通过focused `7/7`、related `218/217/1/0`和normal `1259/1258/1/0`；三份structured diagnostics全零且唯一skip精确为真实Keychain opt-in。未复用修正前测试证据，两个真实opt-in unset且未操作Simulator。
- **repository gate首轮错误：** 首个包装器的条件正则未对alternation分组，把任意`#if os(tvOS)`误作shortcut modifier泄漏并在只读断言退出；后续BSD `find -perm +111`也不能可靠定位旧四平台证据的macOS executable。仓库、checkbox、测试与runtime均无副作用；corrected gate改为逐个shortcut检查最近平台guard及直接app executable路径。记录错误的首个跨planning补丁又因task plan上下文错误被原子拒绝，随后按精确当前段落修正。
- **repository gate r2错误：** corrected包装器在scope/remote/shortcut guard后，仍用显式类型与点语法匹配focus常量，未接受实际等价的`ProductKeyboardFocusTarget.manualHostAddress/streamHideControls`而退出。逐项诊断首轮使用zsh只读变量`status`也在任何产品断言前退出；改为`rc`后确认只有这两个pattern过窄。r3按实际源码格式完整重跑，不重复旧表达式。
- **repository pre-gate：** fresh r3 `/private/tmp/LuneX-19-5_3-repository-pre-r3.DyVGzn`完整通过remote baseline、20文件精确scope、typed focus与10处macOS/iOS shortcut guard、三层reserved-local、测试/authority、stable generator、最终`7/218/1259/4` evidence、唯一Keychain skip、disabled opt-ins、零build/test process与diff边界。现只勾选5.3并推进至`29/48 next 5.4`；下一步只读post-mark，不重复行为门。
- **post-mark与最终审计：** fresh `/private/tmp/LuneX-19-5_3-final-state.1Yy8NN`只读确认strict、`29/48 next 5.4`、最终21文件、唯一5.3 checkbox、stable project、retained evidence、disabled opt-ins与零process。逐层diff审计确认focus lifecycle、10处平台guard、legacy decode/runtime fail-closed、测试增量和authority一致，5.4/5.5只有pending边界；下一步定向清理task evidence，不重复test/build/generator。
- **evidence cleanup：** 先枚举再用绝对`find <exact-path> -depth -delete`逐项清理25个5.3 task-specific路径，并显式清理2个辅助test-tree JSON；prefix与辅助路径均为0，未扩大删除范围或触碰仓库cache。下一步cleanup final audit，通过后独立提交推送。
- **cleanup final audit首轮错误：** 测试完整性正则把`testForwardedCommandKeyEquivalentIsCapturedWithoutLocalHandling`到`testCommandKeyEquivalentAlwaysRemainsLocalWithoutRemoteSamples`的语义重命名误作无替代删除并退出；新测试已在三层行为门通过且normal总数增加2。r2精确验证这一对rename并拒绝其他测试删除或新增skip，不重复过宽断言。
- **cleanup final audit：** corrected r2 `/private/tmp/LuneX-19-5_3-cleanup-final-audit-r2.ydYwap`完整通过最终21文件、strict/OpenSpec `29/48 next 5.4`、stable project、10处平台guard、focus/reserved-local合同、精确test rename、零skip新增、disabled opt-ins、零process与remote baseline。删除audit临时路径并做零残留检查后即可独立提交推送。

## 2026-08-22 阶段 19 任务 5.4 启动

- **状态：** `in_progress`；Task 5.3已以`43802f1 Add native keyboard workflow focus`提交推送，`HEAD == origin/main == remote`且工作树clean，OpenSpec为`29/48 next 5.4`。
- **审计缺口：** product UI没有`accessibilityReduceMotion`接线；`MobilePictureInPictureCommandButton`明确固定为`36x32`，其他custom/plain workflow buttons也没有统一44pt touch target；RemoteAppTile selection只靠accent background/border且app name限制两行；diagnostic severity主要靠颜色。
- **实现边界：** 新增pure touch/motion policy、统一SwiftUI action target/text expansion modifier、non-color selection/severity marker及stream overlay reduced-motion transition。5.5 tvOS/visionOS focus order/restoration与5.6完整矩阵保持pending，不把离线source/behavior证据描述为物理touch、contrast或assistive-technology验收。
- **重复glob错误：** 5.4首轮并行检索再次传入不存在的`Tests/LuneXCoreTests/*Accessibility*`裸glob，zsh在该子命令执行前以`no matches found`退出；其他明确路径读取成功且仓库无变化。后续只用`rg --files`或明确文件名，不再传任何可空裸glob。
- **实现补丁首轮错误：** 首个core/RootView组合补丁在RootView多段上下文匹配失败，`apply_patch`原子拒绝且两个production文件均未修改。随后拆为pure policy、stream motion、tile、diagnostics、PiP、modifier和action groups的小补丁，不重复大上下文。
- **首轮实现：** `ProductInteractionAccessibilityPolicy`固定44pt并纯值选择opacity/immediate；RootView在iOS custom actions使用统一target modifier，PiP从`36x32`改为策略最小值，RemoteAppTile移除两行截断并显示Selected/checkmark/accessibility value，diagnostics显示severity文本，stream overlay按Reduce Motion选择无动画或0.18秒opacity。5.5 focus未改；新增pure/source focused测试，下一步fresh warnings-as-errors编译与执行。
- **focused首轮与补强：** fresh macOS focused `2/2`、零structured diagnostics；审读发现非macOS Sidebar NavigationRow的custom selection仍只改变accent color。新增可见checkmark和Selected/Not selected accessibility value并扩展source合同，首轮证据不作为最终候选，下一步fresh r2。
- **最终行为门：** 补强后fresh focused r2 `2/2`、13类serial related `244/244`、serial normal `1261/1260/1/0`及macOS universal、iOS/iPadOS、tvOS、visionOS generic Debug `4/4`全部结构化零diagnostic，macOS为`x86_64 arm64`；唯一skip精确为真实Keychain opt-in，两个真实opt-in unset且未操作Simulator。
- **authority同步：** 已同步design/accessibility spec、native product workflow contract、completion roadmap与三份planning，记录44pt/action text、non-color state、Reduce Motion接线、最终`2/244/1261/4`证据和physical touch/contrast/assistive-technology边界。5.4仍保持pre-mark `29/48 next 5.4`；下一步generator双跑、strict与repository pre-gate。
- **目标工具限制：** 本轮按用户既有“重新创建目标”要求调用`create_goal`，但工具仍把旧`blocked`目标视为unfinished且拒绝替换；仓库、Keychain、live host、Simulator和runtime均无副作用。继续以OpenSpec与三份planning为执行权威，不误标旧目标complete。
- **generator/strict：** generator连续两次运行后`project.pbxproj` SHA-256稳定为`4214a283c9e353456098dba5504f2cef3cf7cabd78ff2d4c51a2d34060b2f04f`且工程零drift；`openspec validate complete-native-product-workflows --strict`通过。
- **repository gate错误与修正：** 首轮fresh gate在零focus新增时使用`rg -c`得到空字符串而非`0`并退出；r2改为`awk`后通过该组，但宽泛进程检索匹配脚本自身报告文本而误判。两轮均只读且无仓库/runtime副作用；r3改为确定性`awk`计数和`pgrep -x`精确进程名，从fresh目录完整重跑。
- **repository pre-gate：** r3 `/private/tmp/LuneX-19-5_4-repository-pre-r3.84UClZ`完整通过三方remote基线、10文件pre-mark scope、44pt/38处modifier/PiP、selection/severity/text、Reduce Motion、5.5隔离、OpenSpec `29/48 next 5.4` strict、stable project、retained `2/244/1261/4`证据、唯一Keychain skip、disabled opt-ins与零active build/test process。5.4可单独勾选，5.5以后保持pending且change不得archive。
- **post-mark final-state：** `/private/tmp/LuneX-19-5_4-final-state.mwPuZ4`只读确认OpenSpec `30/48 next 5.5 ready`、strict valid、最终11文件、tasks仅5.4 checkbox变化、stable project、38处modifier、5.5隔离与安全边界；不为记录更新重复test/build/generator。下一步精确清理全部5.4 task artifact并做cleanup final audit。
- **cleanup命令拒绝：** 首个清理脚本因末尾使用`rm -f`删除临时清单而在进程创建前被策略拒绝，零路径删除、零仓库/runtime副作用；改用受限`find <exact-path> -delete`后执行。
- **evidence cleanup：** 受限枚举并逐路径删除17个`/private/tmp/LuneX-19-5_4*` task artifact，变量使用`target_path`且每项校验精确前缀；prefix残留为0，未触碰仓库`build/DerivedData`。下一步cleanup final audit，通过后独立提交推送。
- **cleanup final audit：** `/private/tmp/LuneX-19-5_4-cleanup-final-audit.8vAuuY`完整通过最终11文件、OpenSpec `30/48 next 5.5` strict、stable project、touch/text/non-color/motion合同、5.5 focus隔离、测试`2 add / 0 delete / 0 new skip`、authority、零其他artifact、disabled opt-ins、零active process与三方baseline。删除当前audit路径并完成提交前零残留检查后即可独立提交推送。

## 2026-08-22 阶段 19 任务 5.5 启动

- **状态：** `in_progress`；Task 5.4已以`9992ede Enforce accessible workflow interaction`提交推送，`HEAD == origin/main == remote`且工作树clean，OpenSpec为`30/48 next 5.5 ready`。
- **tvOS审计：** stream surface在`StreamWorkspaceView`持有Bool `FocusState`，overlay controls在`TVStreamControls`另持enum `FocusState`；打开时default到Hide Controls、关闭时父view赋surface focus没有共享focus scope，不能形成确定性order/restoration合同。
- **visionOS审计：** actual input projection已区分`.local(.overlayVisible)`、其他ineligible、releasing、captured与unavailable，但`Hide Controls`按钮始终enabled/focusable。该命令会间接请求remote input，必须只在当前window visible、overlay是唯一ineligibility且至少一个current capability存在时可达。
- **实现边界：** 复用checked single-workspace owner、现有tv focus handoff和vision presentation reducer；新增pure tv focus policy、共享SwiftUI FocusState、vision command reachability/accessibility value与focused tests。不得新增第二focus/input owner，不提前完成5.6完整accessibility matrix，也不把generic/offline证据表述为物理remote/gaze/hand/VoiceOver验收。
- **测试补丁错误：** 首个三测试文件组合补丁因`ProductWorkflowSurfaceTests`底部helper锚点名称不匹配被`apply_patch`原子拒绝、零测试文件修改；随后按真实锚点逐文件应用成功。
- **focused首轮错误：** `/private/tmp/LuneX-19-5_5-focused.EKMaNk`在0 tests的测试编译阶段失败，唯一源码诊断是既有settings presentation测试直接构造`VisionStreamControlPresentationState`时缺少新增`reachability`参数；production编译无诊断。已为state增加fail-closed默认reachability的显式initializer以保持旧构造兼容，失败bundle不计验收。
- **focused r2与审读补强：** fresh r2通过`5/5`且structured build diagnostics全零；日志只有未链接AppIntents时的metadata-skip工具提示。审读发现overlayVisible但capability set为空时value仍只描述controls ownership，未明确remote path不可用；已增加独立fail-closed copy并更新测试，r2降为补强前辅助证据，下一步fresh focused r3。
- **补强补丁格式错误：** 首个production/test/planning组合补丁因hunk边界格式错误在解析阶段被`apply_patch`拒绝，零文件修改；随后拆为三个小补丁应用，不重复错误格式。
- **最终focused：** fresh `/private/tmp/LuneX-19-5_5-focused-r3.9QNu16/Focused.xcresult`结构化通过`5/5`、0 skip/failure/expected failure，build为`succeeded / 0 error / 0 warning / 0 analyzer warning`。闭合pure tv focus target/restoration、shared RootView binding、vision overlay/release/ineligible/empty-capability reachability与source wiring；下一步serial related矩阵。
- **related首轮错误：** fresh serial矩阵执行`316 total / 315 passed / 1 failed`且structured build diagnostics全零；唯一失败是`ProductWorkflowSurfaceTests.testRootViewConsumesSurfaceContractsAndNativeAppButtons`仍用已删除的private focus enum作为overlay源码切片终点。已改用`private struct TVStreamControls`并验证共享focus initializer，失败bundle不计验收。并行读取同一xcresult的辅助tests tree还复现`database.sqlite3`移动竞争，只影响该读取；后续同一bundle全部串行查询。
- **related r2时序错误：** source修正单项fresh `1/1`通过后，完整r2为`316/315/0/1`，唯一失败是vision AppModel application test等待session state超时；其余315项与structured build全零。该测试在独立fresh串行`1/1`通过，未修改production；必须再以完整fresh矩阵闭合。
- **最终related：** 第三个fresh serial `/private/tmp/LuneX-19-5_5-related-r3.XFomsH/Related.xcresult`结构化通过`316/316`、0 skip/failure/expected failure，build diagnostics全零，闭合source test和AppModel时序干扰。下一步独立fresh serial normal。
- **normal首轮：** fresh serial `/private/tmp/LuneX-19-5_5-normal.bBLNk0/Normal.xcresult`结构化通过`1263 total / 1262 passed / 1 skipped / 0 failed`且build diagnostics全零；唯一skip串行读回为真实Keychain opt-in，普通文件fallback保持。该证据在后续RootView compile修正前，降为辅助证据。
- **四平台首轮错误：** fresh四平台root在首个macOS app build编译RootView时退出，唯一Swift诊断为conditional `StreamStatusOverlay`分支后的`.transition`被解析成type member；core/test先前不编译app RootView。已用`Group`包住条件initializer后统一应用modifier，行为不变。由于production变化，必须从fresh目录重跑focused/related/normal/四平台，先前成功门不作最终候选。
- **Group修正后门与tvOS错误：** 修正后fresh focused `6/6`、related `316/316`、normal `1263/1262/1/0`全部结构化零diagnostic且唯一skip为真实Keychain；四平台重跑中macOS与iOS/iPadOS通过，tvOS编译发现`StreamStatusOverlay`条件binding属性声明在workspace/layout之前，memberwise initializer要求`tvFocusedControl`先传。已把属性移到workspace/layout之后以保持跨平台调用顺序；visionOS尚未在该轮执行。最终门必须再次fresh闭合。
- **最终行为门：** 参数顺序修复后的fresh候选分别位于`/private/tmp/LuneX-19-5_5-focused-final2.TGLWJI`、`/private/tmp/LuneX-19-5_5-related-final2.GCMCDW`、`/private/tmp/LuneX-19-5_5-normal-final2.NHyDRv`与`/private/tmp/LuneX-19-5_5-platform-builds-final2.B5qORm`。focused结构化`6/6`、11类serial related `316/316`、serial normal `1263/1262/1/0`，唯一skip串行精确读回为`testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`；四平台unsigned generic Debug `4/4`且macOS executable为`x86_64 arm64`。所有structured error/warning/analyzer warning均为0，两个真实opt-in保持unset，未查询、创建、启动或关闭Simulator。下一步同步OpenSpec/runtime authority，再运行generator双跑、strict与fresh repository pre-gate；5.5仍保持未勾选。
- **authority/generator/strict：** 已同步OpenSpec design/accessibility spec、native product workflow contract、completion roadmap与三份planning，记录shared tv focus、actual vision reachability、最终`6/316/1263/4`证据及physical remote/gaze/hand/VoiceOver/signed/live边界。generator前、第一次和第二次后的`project.pbxproj` SHA-256均为`4214a283c9e353456098dba5504f2cef3cf7cabd78ff2d4c51a2d34060b2f04f`且工程零diff；OpenSpec strict valid。5.5仍保持pre-mark `30/48 next 5.5`，下一步fresh repository pre-gate。
- **repository pre-gate：** fresh `/private/tmp/LuneX-19-5_5-repository-pre.Vn4xjX`完整通过三方remote基线、13文件精确scope、shared focus与actual reachability source合同、2新增/0删除/0 skip测试、authority、OpenSpec pre-mark `30/48 next 5.5` strict、stable project、最终`6/316/1263/4` retained evidence、唯一Keychain skip、disabled opt-ins、零build/test process及final diff。现只勾选5.5，预期推进至`31/48 next 5.6`；下一步只读post-mark，不重复行为门。
- **post-mark包装器错误：** 首个fresh final-state在OpenSpec读取后因checkbox正则错误假设diff sign后直接是`[ ]/[x]`，未考虑Markdown bullet `- `而无输出退出；逐项诊断确认实际已为`31/48 next 5.6`、14文件、唯一5.5替换、stable project、disabled opt-ins与零process。仓库/runtime无额外副作用；修正为匹配`^[+-]- \[[ x]\]`后从另一fresh目录完整重跑只读门。
- **状态：** `complete`；corrected post-mark `/private/tmp/LuneX-19-5_5-final-state-r2.6HIYOJ`只读确认strict、OpenSpec `31/48 next 5.6 ready`、最终14文件、唯一5.5 checkbox、stable project、disabled opt-ins与零build/test process。未重复test/build/generator或操作Simulator；下一步精确清理全部5.5临时证据并做cleanup final audit。
- **evidence cleanup：** 受限枚举的41个`/private/tmp/LuneX-19-5_5*`目录、root marker与门禁报告已逐项用绝对`/usr/bin/find <exact-path> -depth -delete`清理，task prefix残留为0；变量使用`target_path`，未使用宽泛删除或触碰仓库`build/DerivedData`。下一步cleanup final audit，通过后独立提交推送。
- **cleanup final audit：** `/private/tmp/LuneX-19-5_5-cleanup-final-audit.qbQpIM`完整通过最终14文件、OpenSpec `31/48 next 5.6` strict、shared tv focus/vision reachability、测试`2 add / 0 delete / 0 new skip`、authority current-state、stable project、唯一5.5 checkbox、disabled opt-ins、零process、三方`9992ede`基线与diff边界。删除当前audit路径并确认prefix零残留后即可独立提交推送。
## 2026-08-22 阶段 19 任务 5.6 启动

- **状态：** `in_progress`；Task 5.5已以`cb7ce3b Complete TV and Vision focus semantics`提交推送，fetch/ls-remote确认`HEAD == origin/main == remote`且工作树clean；OpenSpec为`31/48 next 5.6 ready`。
- **任务边界：** 5.6只补齐5.1至5.5既有descriptor/focus/motion/layout/target/tvOS/visionOS production合同的确定性application连接矩阵；优先复用真实`AppModel`、workspace/session generation与actual presentation reducers，不为计数复制单元测试，不提前实现6.x diagnostics或7.x端到端/物理验收。
- **下一步：** 按九个要求维度盘点现有测试标识、跨层输入与source-only断言，记录缺口后实施最小测试变更；普通测试继续文件identity fallback，两个真实opt-in unset且不操作Simulator lifecycle。
- **application矩阵实现：** 新增两条真实`AppModel`应用测试：第一条连接六类semantic surface、最长动态本地化文本、keyboard focus、Dynamic Type、compact/wide、44pt target与Reduce Motion；第二条驱动tvOS/visionOS实际session、geometry、overlay release/restore、共享focus和actual reachability。production零修改。
- **focused首轮编译错误：** `/private/tmp/LuneX-19-5_6-focused.LkYhnd`在0 tests的测试编译阶段失败，只有两处`'async' call in an autoclosure that does not support concurrency`；根因是把`await stopStream`直接传给`XCTAssertTrue`。已先await到局部Bool再断言，失败bundle不计验收，下一步从fresh DerivedData重跑两条focused。
- **focused第二轮状态错误：** 修复编译后的fresh `/private/tmp/LuneX-19-5_6-focused-r2.9OHdIu`执行`2 total / 1 passed / 1 failed`；descriptor/application matrix通过，tvOS/visionOS matrix在首个surface-focus等待处得到`focus=localControls release=false`。根因是session启动默认overlay visible，而新测试未像既有application时间线一样先通过checked workspace API隐藏overlay。现已在geometry前显式请求`.hidden`，不扩大timeout；失败bundle不计验收，下一步fresh完整focused重跑。
- **focused第三轮发现production投影缺口：** fresh `/private/tmp/LuneX-19-5_6-focused-r3.GGBkf5`仍为`2/1/0/1`，tvOS时间线已通过，visionOS在overlay完成release后为`overlay=visible input=unavailable release=false`。审计确认测试先前只建立capture admission、没有回灌实际platform coordinator state；同时production投影始终复用geometry时的旧coordinator input capability，无法反映同revision下当前overlay eligibility。现测试显式构造并回灌当前coordinator snapshot，production继续要求实际window/scene/ownership/revision/capability set匹配，但以当前vision input snapshot投影实际eligibility；隐藏overlay复用同一geometry恢复capture，不伪造revision推进。下一步fresh focused验证该窄修复。
- **focused第四轮夹具不完整：** fresh `/private/tmp/LuneX-19-5_6-focused-r4.3FDdff`仍为`2/1/0/1`且编译诊断全零；新vision coordinator只应用scene/input，snapshot未满足active phase所需完整component，因此AppModel按合同报告`window=unavailable input=unavailable`。现为同revision coordinator补齐visionOS display与audio route再回灌，不改production规则或timeout；失败bundle不计验收。
- **focused第五轮revision域发现：** fresh `/private/tmp/LuneX-19-5_6-focused-r5.t7DklH`仍为`2/1/0/1`，完整coordinator snapshot已回灌但window/input仍fail closed。读取reducer确认coordinator每个component推进并重标内部semantic revision，而geometry admission保留source revision，直接比较两者revision永远过严。现改为逐字段验证同owner/surface/scene geometry/input generation/capability set，再用coordinator当前revision与实际runtime focus eligibility重建只读input投影；stale/current和capability边界保持fail closed。
- **focused通过：** fresh `/private/tmp/LuneX-19-5_6-focused-r6.VscYQb/Focused.xcresult`结构化通过`2/2`、0 skip/failure/expected failure，build为`succeeded / 0 error / 0 warning / 0 analyzer warning`。覆盖六类semantic application连接、最长动态本地化、focus/layout/target/motion，以及tvOS与visionOS actual overlay eligibility完整时间线；下一步fresh serial related矩阵。
- **serial related：** fresh `/private/tmp/LuneX-19-5_6-related-serial.CADZPr/Related.xcresult`结构化通过`335/335`、0 skip/failure/expected failure，build diagnostics全零；覆盖AppModel、workflow surface、tvOS/visionOS focus/input/presentation、HDR、spatial audio、mobile continuity和remote input。下一步独立fresh serial normal。
- **目标工具限制：** 续接时按用户此前要求尝试重新创建长期目标，但工具仍将旧`blocked`目标视为unfinished并拒绝创建；仓库/runtime无副作用，继续使用既有目标、OpenSpec与三份planning作为权威，不把该元数据限制视为实现阻塞。
- **serial normal：** fresh `/private/tmp/LuneX-19-5_6-normal-serial.pfqPxf/Normal.xcresult`结构化通过`1265 total / 1264 passed / 1 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 error / 0 warning / 0 analyzer warning`；唯一skip精确为`testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`。普通测试继续Debug文件identity fallback，未重新触发真实Keychain或live host；下一步fresh四平台unsigned generic Debug build。
- **四平台build：** fresh `/private/tmp/LuneX-19-5_6-platform-builds.Tujmy9`顺序完成macOS、iOS/iPadOS、tvOS、visionOS unsigned generic Debug `4/4`；四份structured build均为`succeeded / 0 error / 0 warning / 0 analyzer warning`，macOS executable确认为`x86_64 arm64` universal。两个真实opt-in unset，未查询、创建、启动或关闭Simulator；下一步同步authority、generator双跑、strict与repository pre-gate。
- **authority/generator/strict：** 已同步OpenSpec design/accessibility spec、native product workflow contract、completion roadmap与三份planning，记录九维application matrix、vision source/coordinator revision域、current runtime focus eligibility投影、最终`2/335/1265/4`证据与physical proof边界。generator前及连续两次运行后`project.pbxproj` SHA-256均为`4214a283c9e353456098dba5504f2cef3cf7cabd78ff2d4c51a2d34060b2f04f`且零drift；OpenSpec strict valid。5.6仍为pre-mark `31/48 next 5.6`，下一步fresh repository pre-gate。
- **状态：** `complete`；fresh repository pre-gate `/private/tmp/LuneX-19-5_6-repository-pre.VRUkYi`完整通过三方baseline、9文件scope、vision current/fail-closed投影、测试`2 add / 0 delete / 0 new skip`、authority、pre-mark strict、stable project、最终`2/335/1265/4` evidence、唯一Keychain skip、disabled opt-ins、零process与diff边界。现只勾选5.6并推进至`32/48 next 6.1`；下一步只读post-mark，不重复行为门。
- **post-mark final-state：** `/private/tmp/LuneX-19-5_6-final-state.d65lHB`只读确认strict、OpenSpec `32/48 next 6.1 ready`、最终10文件scope、唯一5.6 checkbox、stable project、authority、disabled opt-ins、零build/test process与diff边界；未重复test/build/generator或操作Simulator。下一步精确清理全部5.6 task evidence并做cleanup final audit。
- **evidence cleanup：** 已枚举并逐项精确删除20个`/private/tmp/LuneX-19-5_6*`失败/最终bundle、marker、generator log和门禁路径，prefix残留为0；未使用宽泛删除或触碰其他task evidence与仓库cache。下一步cleanup final audit与独立提交推送。
- **cleanup final audit：** `/private/tmp/LuneX-19-5_6-cleanup-final-audit.ORsfpF`完整通过最终10文件scope、OpenSpec `32/48 next 6.1` strict、唯一5.6 checkbox、vision current/fail-closed production投影、测试`2 add / 0 delete / 0 new skip`、authority current-state、stable project、disabled opt-ins、零process、remote baseline与diff边界。删除audit路径并确认prefix零残留后即可独立提交推送。

## 2026-08-22 阶段 19 任务 6.1 启动

- **状态：** `in_progress`；Task 5.6已以`c022846 Complete accessibility application matrix`提交推送，fetch/ls-remote确认`HEAD == origin/main == remote`且工作树clean；OpenSpec为`32/48 next 6.1 ready`。
- **映射审计：** closed issue已覆盖host/pairing/catalog/launch/recovery/HDR/audio/input，但`hostNotPaired`错误映射为`launchSelectionRequired`、decoder/media failure被diagnostic action映射为`streamSettingsInvalid`、unknown application/platform failure退化为`streamInterrupted`。现有product mapper还以private AppModel switch散落，缺少可枚举的privacy-bounded application contract。
- **实现边界：** 新增closed stream-pairing/media/platform issue code和typed diagnostic category/action mapper；AppModel terminal failure边界消费mapper，mapper不得读取diagnostic code/summary或任意Error文本。6.2才负责全面移除workflow-facing strings，6.3以后retention/export保持pending，不提前改变diagnostic store或UI。
- **focused补强轮夹具挂起：** r2在编译完成后停在新增launch-pairing application用例；测试在media continuation建立前调用`finish`导致错误丢失，随后`await launchTask`持续等待。已终止该轮xcodebuild/xctest，改由control provider test double在确认streaming后注入arbitrary terminal error，不增加timeout或修改production；挂起轮不计验收。
- **focused通过：** 修正后的fresh `/private/tmp/LuneX-19-6_1-focused-r3.tpsbeI/Focused.xcresult`结构化通过`14/14`、0 skip/failure/expected failure，build为`succeeded / 0 error / 0 warning / 0 analyzer warning`；覆盖28个closed code、host/pairing/catalog/runtime category/action矩阵、adversarial arbitrary diagnostic隔离、真实media failure和checked launch-pairing recovery。下一步serial related矩阵。
- **related/normal：** fresh serial related `/private/tmp/LuneX-19-6_1-related-serial.2OOn1d`结构化通过`237/237`且build diagnostics全零；独立serial normal `/private/tmp/LuneX-19-6_1-normal-serial.VcX74U`通过`1268/1267/1/0`、0 expected failure且build diagnostics全零，唯一skip精确为真实Keychain opt-in。下一步四平台fresh unsigned generic Debug。
- **四平台/authority：** fresh `/private/tmp/LuneX-19-6_1-platform-builds.kcyAlD`顺序通过macOS、iOS/iPadOS、tvOS、visionOS unsigned generic Debug `4/4`且每份structured diagnostics全零，macOS executable为`x86_64 arm64` universal；两个真实opt-in unset且未操作Simulator。已同步OpenSpec design/privacy spec、runtime contract、roadmap与三份planning，6.2-6.5及physical/live边界保持pending；下一步generator、strict与repository pre-gate。
- **状态：** `complete`；generator三次hash稳定为`4214a283c9e353456098dba5504f2cef3cf7cabd78ff2d4c51a2d34060b2f04f`且strict valid。fresh repository pre-gate `/private/tmp/LuneX-19-6_1-repository-pre.LXuj3u`通过remote baseline、11文件scope、closed mapper/AppModel/test/authority、pre-mark `32/48 next 6.1`、最终`14/237/1268/4` evidence、唯一Keychain skip、disabled opt-ins、零process与diff边界；现只勾选6.1并推进至`33/48 next 6.2`。
- **post-mark/cleanup：** 只读final-state通过strict、OpenSpec `33/48 next 6.2`、12文件scope、唯一6.1 checkbox、零process与diff边界；未重复行为门。随后逐项精确清理9个`/private/tmp/LuneX-19-6_1*`失败/最终evidence、generator log和pre-gate路径，prefix残留0且未触碰其他task evidence或仓库cache；下一步提交前final audit。
- **cleanup final audit：** 提交前只读门完整通过三方baseline、`33/48 next 6.2` strict、12文件scope、28-code mapper、测试`3 add / 0 delete / 0 new skip`、authority、stable project、零task artifact/opt-in/process与diff边界；无阻止6.1独立提交的问题。

## 2026-08-26 M1 Task 2.3 RTSP close-delimited 修复

- **状态：** `in_progress`；基线为已推送精确SHA `92e9d9e7fb19ecda0361f6d0fd5d2253a0ae7b16`，OpenSpec仍为`7/27`且Task 2.3未勾选。
- **live回执：** 双重opt-in尝试记录`launch=0/resume=1/cancel=0`、`controlEvents=launch_accepted`、`controlFailure=SunshineRTSPNegotiationError.descriptionTooLarge`；这证明上一批per-request connection修复已跨过首笔`ENODATA(96)`并完成OPTIONS/DESCRIBE传输，不是busy/free或Sunshine并发能力问题。
- **包装器错误：** 上轮live命令使用`xctest ... | tee`却未启用`pipefail`，因此shell exit `0`来自`tee`，不能代表XCTest通过。该次XCTest从明确failure回执记录；后续所有live wrapper必须`set -o pipefail`或显式保留上游exit status，且不重跑这一精确尝试。
- **根因：** Sunshine DESCRIBE响应缺少`Content-Length`并以peer close界定SDP正文；`decodePrefix()`合理地把通用RTSP缺失长度视为零body，但`NetworkRTSPConnection`错误地在header到达时立即发布响应，丢弃后续close-delimited SDP。
- **实现边界：** 不放宽通用RTSP parser；明文响应如有`Content-Length`则严格按长度完成，缺失则累积到terminal close并将delimiter后全部数据作为body。加密RTSP仍由24-byte frame长度界定，取消token仍在terminal解析阶段fail closed。
- **验收顺序：** 先新增close-delimited、fragmentation、empty/incomplete、explicit-length/trailing、encrypted和cancellation确定性测试；再fresh related warnings-as-errors、serial macOS normal、macOS Debug/Release、三冻结平台generic compatibility build、OpenSpec/generator/repository gates；独立提交推送后才执行一次正确传播exit status的exact-SHA live gate。不运行真实Keychain测试，不操作Simulator。
- **focused：** fresh `/private/tmp/LuneX-M1-2_3-close-focused.lFtjqS/Focused.xcresult`在warnings-as-errors、三个真实opt-in unset下结构化通过`56/56`，0 skip/failure/expected failure，build diagnostics为`0 error / 0 warning / 0 analyzer warning`。覆盖close-delimited codec、terminal/nonterminal fragments、empty/incomplete、explicit length、encrypted framing、graceful ENODATA、SDP empty/oversized与cancellation finish-token；未访问Keychain/live host/Simulator。下一步fresh related矩阵。
- **共享影响收窄：** 首轮focused `56/56`和related `78/78`后人工审阅发现无条件`ENODATA -> closed`会把UDP datagram也当作stream close。已让`NWConnectionDriver`仅在TCP endpoint上启用该映射，UDP继续返回`.posixFailure(96)`；首轮成功证据降为收窄前辅助证据。
- **最终focused/related：** 收窄后fresh `/private/tmp/LuneX-M1-2_3-close-focused-final.1TAKhK`与`/private/tmp/LuneX-M1-2_3-close-related-final.mXwgn3`分别结构化通过`56/56`和`78/78`，均0 skip/failure/expected failure且build diagnostics全零。related包含SessionCancellation、SessionRecovery及live exact-opt-in config；三opt-in unset，零active xcodebuild/xctest，未访问Keychain/live host/Simulator。下一步fresh serial macOS normal。
- **serial normal：** fresh `/private/tmp/LuneX-M1-2_3-close-normal.JM3Uh0/Normal.xcresult`结构化通过`1306 total / 1304 passed / 2 skipped / 0 failed / 0 expected failure`，build diagnostics全零。两个skip精确为一次性真实Keychain和live Sunshine opt-in；普通Debug identity继续文件fallback，未访问Keychain/host/Simulator。
- **产品build：** fresh `/private/tmp/LuneX-M1-2_3-close-builds.D1b2bL`串行通过macOS Debug/Release、iOS/iPadOS generic Debug、tvOS generic Debug和visionOS generic Debug `5/5`；五份structured build均`0 error / 0 warning / 0 analyzer warning`，两个macOS executable均为`x86_64 arm64`。非macOS只证明共享networking编译兼容，不推进冻结平台状态；未操作Simulator。下一步OpenSpec/generator/repository gate。
- **repository wrapper解析错误：** 首轮OpenSpec/generator门已实际通过strict `11/11`与generator三次稳定SHA `f9a54a2e...6000de`，但next-task打印错用`.status != "done"`，而apply JSON的权威字段是boolean `.done`，因此误把已完成1.1打印为next。零源码/runtime/Keychain/host/Simulator副作用；最终repository gate将使用`select(.done == false)`并从头复核状态。
- **repository零匹配包装器错误：** 修正next-task后的首轮最终门在privacy扫描处使用`rg -c ... || true`，零匹配时得到空字符串而非`0`，令`set -e`提前退出。已独立诊断确认实际privacy匹配为0、三opt-in unset、fallback目录/文件为`0700/0600`且零build/test进程；不把部分门当最终通过，改用`awk`count从头重跑。
- **repository输出编排错误：** 改用`awk`后的第二轮wrapper超过10秒首个yield，上层调用只输出嵌套结果的`output`而未保留`session_id`，最终marker不可读。已确认当前零git/OpenSpec/build/test进程，但该轮不计最终门；改用30秒yield与分段checkpoint从头重跑。
- **最终repository gate：** 30秒yield的完整门输出`FINAL_CLOSE_DELIMITED_REPOSITORY_GATE_OK`；随后将plaintext missing/explicit `Content-Length`与encrypted frame三种定界规则补入OpenSpec spec，post-spec完整门再输出`FINAL_POST_SPEC_CLOSE_DELIMITED_GATE_OK`。最终strict `11/11`、apply `7/27 next 2.3 pending`、generator三次稳定`f9a54a2e...6000de`、13文件scope、privacy 0、`56/56`、`78/78`、`1306/1304/2/0`、5/5 builds、三opt-in unset、零build/test process及三方Git基线一致全部通过。Task 2.3保持pending，准备独立提交推送。
- **提交推送：** close-delimited修复已以`c105414288ce3b2978f839ecf697c7d9b81a52da`提交推送，`HEAD == origin/main`且工作树clean。精确SHA fresh warnings-as-errors `build-for-testing`为`0 error / 0 warning / 0 analyzer warning`。
- **exact-SHA live回执：** 仅一次双重opt-in gate以正确`pipefail`传播xctest exit `1`；11.507秒后记录`launch=0/resume=1/cancel=0`、`controlEvents=launch_accepted,rtsp_ready`、`controlFailure=ENetTransportError.connectionFailed`。这证明close-delimited DESCRIBE已修复且OPTIONS/DESCRIBE/三SETUP全部协商完成；新失败在control ENet connect，不是busy/free、RTSP或remote cancel问题。四个state文件的mode/size/SHA前后完全不变，active xctest收敛为0。不重跑本尝试；当前转入ENet bridge/endpoint/handshake对照审计。
- **ENet根因：** 对照Moonlight和Sunshine后确认LuneX遗漏RTSP `ANNOUNCE`与`PLAY`，在三次SETUP后过早连接ENet。Sunshine直到ANNOUNCE才创建/register stream session，因此当前connect-data无法命中并被control server拒绝；修复顺序为SETUP audio/video/control -> ANNOUNCE -> PLAY -> ENet。同步补test-only真实ENet loopback，验证48 channels、connect-data、首包丢弃后的握手重传、可靠收发和teardown；Task 2.3仍保持pending直到完整live矩阵验收。

## 2026-08-27 M1 Task 2.3 ANNOUNCE/PLAY 修复

- **状态：** `in_progress`；OpenSpec保持`7/27`且Task 2.3未勾选。生产RTSP顺序已修复为OPTIONS、DESCRIBE、三次SETUP、ANNOUNCE、PLAY，随后才连接ENet；任何required control-v2缺失或ANNOUNCE/PLAY拒绝都会在ENet前fail closed。
- **能力真实性：** bounded Sunshine-compatible SDP包含negotiated codec/HDR/resolution/FPS/bitrate/packet/FEC/audio/CSC/video-port与control encryption参数；`x-ml-general.featureFlags`只声明实际实现的session-ID位`2`，不冒充尚未发送的frame-FEC status。
- **ENet确定性验收：** test-only IPv4 loopback server通过production C bridge与vendored ENet故意丢弃首个UDP握手datagram，验证内部重传、exact connect-data、48 negotiated channels、channel 47 reliable echo及服务端观察到disconnect。最终focused结构化通过`32/32`。
- **related验收：** 首轮related的16项失败均来自cancellation/recovery旧五事务fixture，production正确拒绝缺control-v2且未继续。只将成功helper更新为七事务后，fresh串行related结构化通过`74/74`，build diagnostics全零，既有零`/cancel`和teardown断言未改变。
- **serial normal：** fresh `/private/tmp/LuneX-M1-2_3-announce-normal.x0FG3C/Normal.xcresult`结构化通过`1310 total / 1308 passed / 2 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 error / 0 warning / 0 analyzer warning`。两个skip精确为显式live Sunshine gate和一次性真实Keychain gate；普通测试继续使用Debug文件fallback，未访问Keychain/live host或操作Simulator。
- **下一门：** 串行执行macOS Debug/Release与共享工程变化要求的iOS/iPadOS、tvOS、visionOS generic Debug兼容构建，验证macOS universal binary；随后完成OpenSpec strict、generator稳定性、diff/privacy/opt-in/process/scope审计与独立提交推送，精确SHA后才运行一次bounded双opt-in live gate。
- **产品build：** fresh `/private/tmp/LuneX-M1-2_3-announce-builds.1rnyR3`串行通过macOS Debug/Release、iOS/iPadOS generic Debug、tvOS generic Debug与visionOS generic Debug `5/5`；五份structured build均为`succeeded / 0 error / 0 warning / 0 analyzer warning`，两个macOS executable均为`x86_64 arm64` universal。非macOS结果只证明共享源码和工程membership兼容，不推进冻结平台状态；未操作Simulator。下一步执行权威generator、OpenSpec strict与repository gate。
- **repository pre-gate：** 权威Ruby generator执行前与连续两次运行后`project.pbxproj` SHA-256均为`783a7494...5944`且零drift；OpenSpec strict全仓`11/11`，当前change保持`7/27 next 2.3 pending`。`git diff --check`、16文件scope、隐私材料扫描、三个真实opt-in unset、零active xcodebuild/xctest均通过。人工差异审阅确认`ANNOUNCE -> PLAY -> ENet`、required control-v2、session token、bounded SDP、feature mask真实性、test-only ENet membership和普通teardown零remote cancel边界。下一步fetch/remote基线、最终只读门与独立提交推送。
- **final wrapper编排中断：** 首轮最终只读脚本已通过remote baseline、OpenSpec、project hash、normal summary/build及两个精确skip并随后提前退出，未输出final marker；逐项只读诊断确认剩余五build、两universal、零process、零remote-cancel-true、16文件scope和untracked whitespace实际全部符合。该轮不计完整最终门，不重复build/test/generator/live；改用显式JSON文件与checkpoint从头复核。
- **final wrapper零匹配错误：** 第二轮已再次通过baseline、OpenSpec、diff/project、normal、五build和universal checkpoint，却在boundary使用`rg`统计零`cancelRemoteSession:true`时因`pipefail`把“零匹配”的exit 1当失败提前退出。这重复了计划中已有的零匹配包装器错误，必须停止该模式；本轮不计完整门，最终轮改为纯`awk`扫描所有source文件并从头复核。
- **最终repository gate：** 改用纯`awk`零匹配扫描后，完整门输出`FINAL_ANNOUNCE_REPOSITORY_GATE_OK`。最终确认remote baseline `c105414`、OpenSpec strict `11/11`、apply `7/27 next 2.3 pending`、project稳定hash `783a7494...5944`、normal `1310/1308/2/0`、五build全零structured diagnostics、macOS双universal、三个opt-in unset、零process、零普通remote cancel、隐私`0/0`和16文件scope全部通过。Task 2.3不勾选，准备独立提交推送。
- **提交与exact-SHA live：** ANNOUNCE/PLAY批次已提交推送为`05aa8771a15446ae82d925782fc6947b9dc4901b`且三方SHA一致。精确SHA fresh bundle build为`succeeded/0/0/0`；唯一双opt-in gate以4.703秒失败回执跨过ANNOUNCE/PLAY与ENet，记录`launch/resume/cancel=0/1/0`、`launch_accepted,rtsp_ready,negotiated,channels_1,video_color_metadata`和零control failure。四state文件mode/size/SHA不变且零xctest残留；不重复本尝试。

## 2026-08-27 M1 Task 2.3 Sunshine parity envelope 修复

- **状态：** `in_progress`；UDP lifecycle修复已以精确SHA `f7c059bda4765923c8b67ebbf71ffa9a249356f3`提交推送，OpenSpec保持`7/27 next 2.3 pending`。
- **exact-SHA live回执：** fresh warnings-as-errors bundle build为`succeeded/0/0/0`；唯一双opt-in gate在1.981秒后以xctest exit `1`返回`media_presentation_failed / video_pipeline_failed / stream.video`。recorder为`launch/resume/cancel=0/1/0`、`launch_accepted,rtsp_ready,negotiated,channels_1,video_color_metadata`且零control failure；四state文件`0600`且mode/size/SHA不变，零process残留。本精确尝试不重跑。
- **根因：** Sunshine仅在FEC编码前给data shard写`multiFecFlags=0x10`；Reed-Solomon生成parity shard后只重写RTP、`fecInfo`、`multiFecBlocks`和`frameIndex`等字段，不重写parity的该字节。LuneX对所有shard强制`0x10`会错误拒绝真实parity datagram；moonlight-common-c也不对parity强制该字段。
- **实现边界：** 继续fail closed验证data shard的`multiFecFlags=0x10`、block次序、data/total shard上限、FEC索引和frame flags；只允许已由有效`fecInfo`判定为parity的shard忽略该生成字节。新增非`0x10` Sunshine-faithful parity成功回归和同字节data shard失败回归。
- **验收顺序：** fresh focused、related、serial macOS normal、macOS Debug/Release与三冻结平台generic compatibility build、generator/OpenSpec/repository gate；独立提交推送后最多一次新的exact-SHA bounded live gate。普通测试继续Debug文件identity fallback，不运行真实Keychain测试，不操作Simulator，Task 2.3在完整live矩阵前不勾选。
- **focused：** fresh `/private/tmp/LuneX-M1-2_3-parity-focused.HsLPvH/Focused.xcresult`在warnings-as-errors下结构化通过`10/10/0/0`，build为`succeeded / 0 error / 0 warning / 0 analyzer warning`。新增回归证明非`0x10` parity envelope被接受而同样marker的data shard仍以`invalidFECEnvelope`拒绝；三个真实opt-in unset，未访问Keychain/live host或Simulator。下一步fresh串行媒体相关矩阵。
- **related：** fresh串行 `/private/tmp/LuneX-M1-2_3-parity-related.5SDTlR/Related.xcresult`结构化通过`260 total / 259 passed / 1 skipped / 0 failed / 0 expected failure`，唯一skip精确为显式live Sunshine gate；build为`succeeded / 0 error / 0 warning / 0 analyzer warning`。覆盖packet receive/assembly、session media、VideoToolbox/Metal、media clock、diagnostics与AppModel；下一步fresh串行macOS normal。
- **serial normal：** fresh `/private/tmp/LuneX-M1-2_3-parity-normal.1OEYxw/Normal.xcresult`结构化通过`1312 total / 1310 passed / 2 skipped / 0 failed / 0 expected failure`，build为`succeeded / 0 error / 0 warning / 0 analyzer warning`；两个skip精确为live Sunshine与真实Keychain opt-in。并行读取同一xcresult的辅助tests tree触发一次`database.sqlite3`移动竞争；随后串行读回成功，不重复测试。下一步五产品兼容build。
- **产品build：** fresh `/private/tmp/LuneX-M1-2_3-parity-builds.lVi5xX`串行通过macOS Debug/Release、iOS/iPadOS generic Debug、tvOS generic Debug和visionOS generic Debug `5/5`；五份xcresult均为`succeeded / 0 error / 0 warning / 0 analyzer warning`，两个macOS executable均为`x86_64 arm64` universal。未查询、创建、启动或操作Simulator，冻结平台仅记录共享兼容；下一步generator/OpenSpec/repository gate。
- **generator/OpenSpec：** generator前与连续两次运行后`project.pbxproj` SHA-256均为`783a7494...5944`且零drift。strict命令已生成有效JSON，但首个汇总器错误地把顶层对象当数组并以jq exit `5`退出；只修正解析已保存JSON后确认全仓`11/11`，change为`7/27 next 2.3 pending`。已补OpenSpec parity/data marker协议边界；最终门需重跑post-spec strict，不重复测试/build/generator。
- **repository wrapper错误：** 首轮post-spec final gate已通过三方remote与OpenSpec `11/11`、`7/27 next 2.3 pending`，但macOS `awk`不接受隐私扫描正则中的空alternation并在source boundary退出。零仓库/runtime副作用且不计完整门；改为四个显式PEM marker后从头重跑只读门，不重复test/build/generator/live。
- **最终repository gate：** 修正后的完整门输出`FINAL_PARITY_REPOSITORY_GATE_OK`：三方基线`f7c059b`、OpenSpec strict `11/11`与`7/27 next 2.3 pending`、精确7文件、stable project、隐私与普通remote-cancel均0、retained `10/10`、`260/259/1/0`、`1312/1310/2/0`、五build全零structured diagnostics、macOS双universal、三opt-in unset、fallback `0700/0600`及零process全部通过。下一步人工diff审阅与独立提交推送，不勾选2.3。
- **提交推送：** parity修复已以`3533b8078fe9c4eef634d3e840a2dc8dc3f1d28d`提交推送，三方SHA一致且工作树clean；fresh exact-SHA live bundle build为`succeeded/0/0/0`。
- **live wrapper预检错误：** 首个wrapper在状态快照时以zsh local `path`覆盖命令搜索数组，未生成`LIVE_START`、未启动xctest、未访问host/session，故不计live尝试。改名`state_path`后保持同一精确SHA执行唯一实际gate。
- **exact-SHA live回执：** 唯一双opt-in gate在6.571测试秒后以xctest exit `1`返回`stream_interrupted / transport_failed / stream.transport`；`launch/resume/cancel=0/1/0`、control events仍到`video_color_metadata`且零control failure。四state文件`0600`且mode/size/SHA不变，零build/test残留。本精确尝试不重跑。
- **下一诊断边界：** 当前聚合transport回执不能区分video receive、audio receive、ping/send或其他session-media resource。先审计typed error汇聚并新增privacy-bounded media failure stage recorder及确定性映射测试，之后才允许新提交上的下一次live；Task 2.3继续pending。

## 2026-08-27 M1 Task 2.3 UDP complete-message 修复

- **状态：** `in_progress`；精确SHA `05aa877`证明当前最深阶段已到negotiated media startup，但未到streaming。Task 2.3仍为`7/27 next`且不勾选。
- **根因：** `NWConnection.receive`的`isComplete`在TCP表示terminal stream chunk，在UDP表示一个完整datagram。`NetworkByteChannel`此前无transport语义，统一把任何complete chunk变为`.closed`；媒体channel收到首包后下一次receive因state不是ready而失败。
- **实现边界：** endpoint构造的channel由`RuntimeTransportKind`决定complete语义；TCP保持既有empty/nonempty terminal处理，UDP返回完整datagram后保持`.ready`。不修改ping payload、RTSP端口、Sunshine状态、超时、重试或remote cancel行为。
- **验收顺序：** 先运行新增连续complete datagram与真实UDP loopback state focused，再扩大NetworkChannel/MoonlightMediaReceive/SessionMediaEnvironment/AppModel/RTSP/cancellation/recovery矩阵；通过后执行fresh normal、受共享源码影响的五产品build、generator/OpenSpec/repository gate，提交精确SHA后最多再做一次bounded live gate。
- **focused首次失败：** fresh `NetworkChannelTests` build为`succeeded/0 errors/0 warnings/0 analyzer warnings`，执行`17 total / 16 passed / 1 failed`。唯一失败是新增真实TCP loopback断言错误地要求echo payload和EOF必须同一回调到达；Network.framework允许payload先返回且channel暂时`.ready`，随后独立peer-close回调才进入`.closed`。修复只放宽测试时序，不改变TCP terminal或UDP datagram生产语义；源码变化后使用全新证据目录重跑。
- **focused修正轮：** 全新目录的warnings-as-errors `NetworkChannelTests`通过`17/17/0/0`，build为`succeeded/0 errors/0 warnings/0 analyzer warnings`。连续两个complete UDP datagram和真实UDP echo后state均保持`.ready`；TCP nonempty terminal、empty terminal与独立peer-close路径均最终进入`.closed`。
- **related矩阵：** fresh warnings-as-errors扩大矩阵覆盖`NetworkChannelTests`、`MoonlightMediaReceiveTests`、`SessionMediaEnvironmentTests`、`AppModelWorkflowTests`、`RTSPBootstrapTests`、`SessionCancellationTests`与`SessionRecoveryTests`，通过`225 total / 224 passed / 1 skipped / 0 failed`；唯一skip精确为双重opt-in live acceptance，build为`succeeded/0/0/0`。
- **macOS normal：** fresh serial warnings-as-errors normal通过`1311 total / 1309 passed / 2 skipped / 0 failed`；两个skip精确为一次性Keychain与live-host opt-in，build structured diagnostics为`succeeded/0 errors/0 warnings/0 analyzer warnings`。
- **产品build：** 共享源码变化后的macOS Debug/Release、iOS/iPadOS generic Debug、tvOS generic Debug与visionOS generic Debug全部通过`5/5`，五份xcresult均为`succeeded/0 errors/0 warnings/0 analyzer warnings`；两个macOS executable均为`x86_64 arm64`。冻结平台结果只证明共享编译兼容。
- **generator：** 权威`Tools/generate_xcodeproj.rb`连续两次返回`0`，生成前、第一次和第二次后的`project.pbxproj` SHA-256均为`783a749484d0dc173a1296f7a573dfc0a7e9f5a3292fccf08046c0fa54035944`，工程零diff。
- **repository gate：** 完整只读门输出`FINAL_UDP_REPOSITORY_GATE_OK`：retained focused/related/normal与五build全部匹配权威xcresult，OpenSpec strict `11/11`且apply为`7/27 next 2.3 pending`，generator hash稳定，精确六文件scope，零untracked/diff error/新增skip/secret material/普通`cancelRemoteSession:true`/opt-in/process；`HEAD/origin/remote`基线均为`05aa877`。人工diff复核确认production媒体endpoint为UDP、RTSP为TCP、test-driver默认行为无遗漏。Task 2.3继续不勾选，准备独立提交推送。

## 2026-08-27 M1 Task 2.3 typed media failure receipt

- **状态：** `in_progress`；exact-SHA `3533b807`的唯一live gate聚合为`transport_failed`且不得重跑，Task 2.3继续`7/27 next`且不勾选。
- **实现：** live XCTest以test-only forwarding provider包装production video/audio receive，保留事件、原错、stop与consumer-termination语义，只记录`video_receive`/`audio_receive`和有限cause。production timeout固定`connect/send/receive`分别映射，任意operation、数值transport detail和未知错误文本不进入receipt；cancellation不记failure。
- **当前验收：** focused最终`3/3/0/0`；related为`159/158/1 live skip/0`；pre-final normal为`1315/1313/2 exact skips/0`，successful xcresult均structured `succeeded/0/0/0`。需在timeout cause细分后再跑最终normal、OpenSpec strict与repository门；尚未执行新live。
- **最终receipt回归：** consumer-termination直接回归加入后focused为`4/4/0/0`；final normal为`1316/1314/2 exact skips/0`，skips精确为live Sunshine与real Keychain opt-in，structured build为`succeeded/0/0/0`。
- **host-state纠正：** 用户再次明确free/busy不代表Sunshine客户端容量。审计确认production `initialSessionOperation`仍对different busy和missing state做客户端拒绝；当前修复改为同一运行app选择`/resume`，其他所有状态尝试`/launch`并以认证服务器响应为准，不用`/cancel`制造free状态。该共享源码变化需重跑focused、normal、受影响generic build与repository gate；Task 2.3继续pending。
- **host-state focused：** fresh warnings-as-errors focused通过`35/35/0/0`，structured build `succeeded/0/0/0`；覆盖新准入规则、provider resume路由与4项typed receipt合同。下一步final normal和五build；未执行live、Keychain或Simulator。
- **验收编排偏差：** final normal已通过`1316/1314/2/0`且structured `succeeded/0/0/0`；随后为确认generic destination误运行`xcodebuild -showdestinations`，只读列出了destination但违反本轮“不查询Simulator”的更严格约束。没有create/boot/install/launch/shutdown/delete或状态修改；后续只用`generic/platform=...` placeholder执行五build，不再读取Simulator inventory。
- **host-state build门：** generic placeholder五build均`succeeded/0/0/0`并各有Metal AIR/metallib；macOS Debug/Release均为`x86_64 arm64` universal，iOS+iPadOS/tvOS/visionOS结果只记冻结平台compile compatibility。进入OpenSpec strict、privacy/cancel/opt-in/process、project hash、scope与人工diff终审。
- **repository wrapper错误：** 首轮final gate的strict命令成功生成11项有效JSON，但汇总器沿用不存在的`.results/.summary.total`路径，在任何后续检查前以jq error退出。实际schema为`.items`与`.summary.totals`；仓库/runtime零副作用，不重复test/build/generator，修正解析后从头运行只读gate。
- **最终repository gate：** 修正汇总器后输出`FINAL_HOST_ADMISSION_REPOSITORY_GATE_OK`：OpenSpec strict `11/11`、apply `7/27 next 2.3 pending`、精确8文件、focused `35/35`、normal `1316/1314/2/0`、五build `5/5`与Metal `5/5`、双macOS universal、stable project、零privacy/普通remote-cancel/opt-in/process均通过。Task 2.3继续不勾选，准备独立提交推送。
- **exact-SHA live回执：** host-state批次已以`5a4d1e650ef7cce87bb40b427037acf68c5f86fa`提交推送并三方一致。该SHA唯一双opt-in gate在6.472秒后以xctest exit `1`返回`stream_interrupted / transport_failed / stream.transport`；`launch/resume/cancel=0/1/0`、control events到`video_color_metadata`且无control failure，typed media receipt精确为`audio_receive:network_receive_timed_out`。这证明Sunshine接受并发`/resume`，故不是free/busy或客户端容量问题；四state文件`0600`且mode/size/SHA不变，零process残留，本SHA不重跑。

## 2026-08-27 M1 Task 2.3 media receive idle semantics 修复

- **状态：** `in_progress`；OpenSpec保持`7/27 next 2.3 pending`。对照`moonlight-common-c`确认audio/video UDP receive timeout只是非致命poll结果，上游会继续等待显式停止或真实socket错误；LuneX却把每次5秒无包升级为永久transport failure并取消整个Network.framework channel。
- **实现边界：** 只移除长生命周期video/audio UDP receive loop的人为deadline；connect/send timeout、真实Network.framework错误、packet bounds、buffer overflow、consumer termination、显式取消与TCP/RTSP超时/EOF语义保持fail closed。不能靠延长5秒掩盖协议或网络空闲，也不改变ping payload wire format。
- **验收顺序：** 先补确定性测试证明无deadline媒体receive可跨越等价空闲后接收数据、显式stop仍有界取消、TCP deadline仍失败；再运行focused、related、serial normal、共享源码要求的五build、generator/OpenSpec/repository gate，独立提交推送后新SHA最多一次live gate。真实Keychain和Simulator保持不操作，Task 2.3继续不勾选。
- **当前测试验收：** 最终显式API上的focused为`25/25/0/0`，related为`230/229/1 live skip/0`，serial normal为`1317/1315/2 exact opt-in skips/0`；三份structured build均`succeeded/0/0/0`。下一步五产品generic compatibility build与repository gates，不运行live/Keychain或操作Simulator。
- **产品build：** fresh五build全部`succeeded/0/0/0`并生成Metal AIR/metallib；macOS Debug/Release均为`x86_64 arm64` universal，iOS+iPadOS/tvOS/visionOS generic Debug只证明共享兼容。下一步generator、OpenSpec strict、privacy/scope/teardown/process与人工diff终审。
- **取消终审与normal波动：** pre-gate审阅补齐typed `.cancelled`状态归类后，最终focused为`26/26`、related为`231/230/1 live skip/0`。首个final normal唯一失败是Vision resize用例在固定1秒test helper等待超时，同用例fresh隔离`0.020s`通过且build diagnostics全零；该轮不计验收，执行一次fresh full normal复核，再现才修改夹具。
- **final normal：** fresh full normal复核通过`1318/1316/2 exact opt-in skips/0`，Vision resize同轮正常通过；focused/related/normal structured build均`succeeded/0/0/0`。开始最终源码的五build与repository gates。
- **final build：** 最终源码五build均`succeeded/0/0/0`，每项生成AIR/metallib；macOS Debug/Release均为`x86_64 arm64` universal。下一步只读repository final gate与人工diff终审。
- **最终repository gate：** 输出`FINAL_MEDIA_IDLE_REPOSITORY_GATE_OK`，确认三方`5a4d1e65`基线、stable project `783a7494...5944`、OpenSpec `11/11`与`7/27 next 2.3 pending`、精确9文件、最终`26/26`、`231/230/1/0`、`1318/1316/2/0`、五build/Metal、双universal及零privacy/普通remote-cancel/opt-in/process。Task 2.3继续pending，准备独立提交推送。

## 2026-08-27 M1 Task 2.3 control application keepalive 修复

- **状态：** `in_progress`；修复已提交推送为精确SHA `9516a557de2ebe03ff32ecc5c74d42f49a3afeb9`，其唯一live gate在45.829秒内持续保持`channels_1`，不再出现旧SHA的`channels_0/reconnecting/input_stream_ended`。当前阻塞为video/audio readiness没有到达；Task 2.3继续保持`7/27 next`且不勾选。
- **根因：** Sunshine默认control `ping_timeout`为10秒且只在收到客户端应用层control数据时续期；ENet协议级peer ping不产生该应用层receive event。`moonlight-common-c`在START A/B后立即并每100 ms可靠发送`0x0200` periodic ping，LuneX此前遗漏。
- **实现边界：** `MoonlightControlChannel`在START A/B后立即发送8-byte确定性periodic ping，并在既有100 ms ENet service循环前按deadline续发；ping使用generic channel 0和reliable flag，与IDR及remote input共用同一AES-GCM client sequence。stop清除deadline、sequence、key、input context与feedback streams，不新增第二个常驻Task或远端`/cancel`。
- **确定性验收：** lifecycle focused `/private/tmp/LuneX-M1-control-keepalive-lifecycle.iKCxAp/Lifecycle.xcresult`通过`11/11`；related `/private/tmp/LuneX-M1-control-keepalive-related.2Y2Ebj/Related.xcresult`通过`318/317/1 live skip/0`；normal `/private/tmp/LuneX-M1-control-keepalive-normal.Rwo9gd/Normal.xcresult`通过`1321/1319/2 exact opt-in skips/0`。三份structured build均`succeeded/0/0/0`。
- **产品build：** `/private/tmp/LuneX-M1-control-keepalive-builds.SF1yHZ`五项build均`succeeded/0/0/0`，每项有AIR/metallib；macOS Debug/Release executable均为`x86_64 arm64` universal。未查询或操作Simulator，冻结平台只计共享编译兼容。
- **generator：** 权威Ruby generator前与连续两次运行后project SHA-256均为`783a749484d0dc173a1296f7a573dfc0a7e9f5a3292fccf08046c0fa54035944`且零drift。
- **repository wrapper错误：** 首轮只读门已确认OpenSpec strict `11/11`、retained test/build结果、精确8文件、fallback权限与零普通remote cancel，但隐私扫描再次使用macOS awk不接受的复合正则并在最终marker前退出；skip提取同时误用不存在的`testStatus`字段。产品、仓库与runtime无副作用，本轮不计完整门；改用四个显式PEM marker、当前`.result`字段和实际`LuneX-macOS`产品路径从头重跑，不重复test/build/generator/live。
- **最终repository gate：** 修正后的完整只读门输出`FINAL_CONTROL_KEEPALIVE_REPOSITORY_GATE_OK`：三方`edb75bf`基线、OpenSpec strict `11/11`与`7/27 next 2.3 pending`、精确8文件、stable project、最终`11/11`、`318/317/1/0`、`1321/1319/2/0`、五build/Metal、双universal、精确skip、fallback `0700/0600`及零privacy/普通remote-cancel/opt-in/process全部通过。人工审阅未发现新问题；Task 2.3继续pending，准备独立提交推送。
- **exact-SHA live验收：** fresh bundle `/private/tmp/LuneX-M1-control-keepalive-live-build.6klv5l`为`succeeded/0/0/0`；唯一双opt-in gate为`launch/resume/cancel=0/1/0`、control events到持续`channels_1`和`video_color_metadata`、control/media failure均为空。45.829秒后因video/audio readiness始终未到达而由harness本地stop，cleanup后的idle不是自行完成证据。四state文件不变、零process残留、log SHA为`d237e828...a73`；该SHA不得重跑，下一步增加privacy-bounded媒体首包观测并定位UDP握手/receive路径。

## 2026-08-27 M1 Task 2.3 media activity receipt harness

- **状态：** `in_progress`；Task 2.3继续保持`7/27 next`且不勾选。本批只增强下一exact-SHA live receipt，不宣称媒体根因或行为修复。
- **实现：** test-only channel wrapper原样转发production `NetworkByteChannel` connect/send/receive/cancel；`NSLock`保护的同步bounded recorder避免每个高包率datagram发生actor hop，按video/audio记录endpoint kind、UDP port、custom/legacy ping、connect/ping/datagram/parser-event饱和计数，并在local cleanup前记录AppModel phase、frame count与finite audio stage。地址、payload、key、credential、certificate、identity和任意错误文本不进入receipt。
- **确定性验收：** final focused `5/5`、完整AppModel workflow `102/101/1 exact live skip/0`、macOS normal `1322/1320/2 exact opt-in skips/0`；三份structured build均`succeeded/0/0/0`。live、real Keychain和Simulator均未运行；仅test/OpenSpec/planning/docs变化，不需要冻结平台generic build。
- **下一门：** 完成OpenSpec strict、generator/diff/privacy/Git审计并提交推送新exact SHA，之后才允许一次新的bounded live gate；`9516a557`不得重跑。
- **最终repository gate：** 输出`FINAL_MEDIA_ACTIVITY_LOCK_REPOSITORY_GATE_OK`，确认基线`9516a557`、stable project `783a7494...5944`、OpenSpec `11/11`与`7/27 next 2.3 pending`、精确6文件且零product source/pbx drift、最终三层证据、fallback权限、receipt privacy及零process。下一步提交推送新exact SHA，再执行该SHA唯一bounded live gate。

## 2026-08-27 M1 Task 2.3 encrypted audio live follow-up

- **实现状态：** `3889cfb` 已实现 Sunshine control-v2 + audio encryption 协商、AES-128-CBC Opus payload 解密、内存态 key material 和音频域 typed diagnostics；focused `82/82`、normal `1327/1325/2`、OpenSpec strict `11/11` 均通过。
- **唯一 live gate：** 新源码 SHA `3889cfb` 的双 opt-in macOS 运行完成 RTSP/ANNOUNCE/PLAY/ENet；视频通道收到 `10058` 个 datagram，音频通道连接并发送 `86` 个 custom ping，但收到 `0` 个 datagram，因此没有进入音频 parser/decryptor，也没有 decoded audio readiness。该 SHA 已按约束消耗唯一 live gate，不得重跑。
- **根因边界：** Sunshine 与 `moonlight-common-c` 的 custom `SS_PING` 形状、audio server port `48000`、client ping sequence 和 audioThread 等待逻辑与 LuneX 当前实现一致；视频同会话可收包，当前证据更支持主机音频 capture/stream 配置或主机到音频 UDP 发送路径未产生包，而不是客户端 AES、端口解析或 readiness 代码错误。
- **后续门：** 保持 `Task 2.3` pending，不把视频 datagram 或 control readiness 视为完整 streaming；下一次源码变更前先取得不改变 host 状态的主机音频配置/日志证据，或在新的 exact SHA 上增加明确的音频发送路径验证。不得通过移除 audio readiness 要求来掩盖音频缺失。

## 2026-08-27 M2 FEC parity-gap assembly hardening

- **状态：** `in_progress`；本轮在未触发 live、Keychain、Simulator 或 host 操作的前提下继续修复生产视频 access-unit 组装。工作树仅含 `ReceivedVideoPacket` FEC 元数据、production video provider 透传、`NormalizedVideoAccessUnitAssembler` 及对应测试改动；OpenSpec Task 2.3 继续保持 `7/27` pending。
- **已确认：** Sunshine data shard 的 stream sequence 会因丢弃 parity shard 产生空洞；normalized assembler 已按 FEC block/shard 组装，不再错误要求原始 sequence 连续。当前补强还要求帧内 data/parity/FEC 百分比一致、block index 不超过 last block 且采用 2-bit 合法范围、同一 FEC shard 的冲突重复立即 fail closed；legacy/no-FEC 路径保持原有连续 sequence 合同。
- **下一步：** 新增 metadata-drift/conflicting-shard 回归，执行 fresh focused、media/session related、macOS normal、必要的五产品构建及 generator/OpenSpec/repository gate；最终源码提交新 SHA 后才允许一次双 opt-in live gate。不得重跑任何旧 SHA live gate。
- **focused/related/normal：** fresh focused `/private/tmp/LuneX-M2-video-fec-focused-final.fpj07t/Focused.xcresult` 通过 `3/3`；视频媒体相关矩阵 `/private/tmp/LuneX-M2-video-fec-related-final.bQkVXL/Related.xcresult` 通过 `94/94`；完整 macOS normal `/private/tmp/LuneX-M2-video-fec-normal-final.wOFT9w/Normal.xcresult` 通过 `1330 total / 1328 passed / 2 exact skips / 0 failed`，skip 为 live Sunshine 与 real Keychain。三份 structured diagnostics 均为 `succeeded / 0 error / 0 warning / 0 analyzer warning`，无残留 build/test 进程。
- **兼容 build/generator/OpenSpec：** fresh 五产品 generic build `/private/tmp/LuneX-M2-video-fec-builds-final.q1a74B` 全部 `succeeded / 0 / 0 / 0`，macOS Debug/Release 为 `x86_64 arm64` universal，Metal 输出 `10` 个；generator 连续两次生成前后 `project.pbxproj` SHA-256 均为 `783a7494...5944`；OpenSpec strict 为 `11/11`。下一步执行最终只读 repository gate，提交推送后才允许本新 SHA 唯一一次双 opt-in live gate。

## 2026-08-27 M2 FEC exact-SHA live result

- **提交：** FEC hardening 已以 `212958ffd2bf7cfdd50a3cf281ef8661f1446c94` 提交并推送，三方 `HEAD == origin/main`，工作树干净。
- **live gate：** 新 SHA 仅执行一次双 opt-in macOS gate。arm64 live bundle 构建成功；`tanmy-white/Desktop` 的匹配运行应用走 `/resume`，`launch=0`、`resume=1`、`cancel=0`，control/RTSP/ENet readiness 到达 `channels_1` 和 video color metadata。视频在 46 秒窗口收到 `26578` 个 datagram 并产生 `20144` 个 parser event，证明本轮 FEC 组装修复未阻断视频到达。
- **阻塞：** 音频通道连接且发送 `87` 个 custom ping，但收到 `0` 个 datagram、`0` 个 parser event；没有 decoded audio readiness，模型停留 `waitingForTransport`，harness 执行有界本地 stop 并以 `stream.video` 失败退出。`spatial_audio_missing_entitlement` 仅表示当前运行环境的空间音频能力缺失，不作为音频 UDP 根因。该 SHA 不重跑，不能以视频活动或 control readiness 替代可听同步音频。
- **清理与边界：** 四个 LuneX 状态文件仍为 `0600` 且 SHA 未变化，未发送 remote `/cancel`，xcodebuild/xctest 残留为零；Task 2.3 继续保持 `7/27 next 2.3 pending`。下一步先取得不改变 host 状态的音频发送/配置证据，再决定新的源码修复和后续验收门。

## 2026-08-28 M1 Task 2.3 audio UDP resolution

- **状态：** `in_progress`；使用 OpenSpec change `prioritize-macos-product-completion`，schema 为 `spec-driven`，当前 `7/27` 且唯一执行项仍为 2.3。目标是持续解决音频 UDP 零 datagram，直到完整 live session 验收通过；不得重跑 `212958f` 或任何旧 SHA。
- **当前证据：** 同一 production session 的 video custom ping 被 Sunshine 接受并收到持续视频，而 audio custom ping 发送 87 次仍收到零 datagram。Sunshine 的 `recv_ping()`按 socket 类型与16-byte session payload匹配，moonlight-common-c的 audio ping sequence 从1开始且音频 ping socket在RTSP握手期间即建立；LuneX当前 video/audio共用的receiver在完整RTSP/PLAY/control negotiation之后才启动，sequence从0开始。sequence不是当前首要嫌疑，因为Sunshine只查找16-byte payload，但启动时序是明确的生产差异，必须用确定性合同和主机证据区分。
- **执行门：** 1) 对照RTSP SETUP/PLAY和media environment启动顺序，建立失败的offline时序回归；2) 仅在证据支持时把audio UDP owner提前到SETUP后/PLAY前，保持单owner、取消、replacement和零remote cancel；3) fresh focused/related/normal、五产品generic build、generator/OpenSpec/repository gate；4) 提交新SHA后一次双opt-in live gate，继续迭代直到audio arrival、decode、同步和完整2.3矩阵通过。
- **编排错误：** `212958f`提交后的首次universal `build-for-testing`在任何test/host访问前因既有HDR test的x86_64 `Double(Float16(bitPattern:))` SDK兼容编译错误退出；arm64 live bundle随后fresh成功。该错误不属于FEC/audio源码，不计live尝试，但需要在后续macOS确定性回归修复以恢复universal test build。
- **主机只读入口：** 既有SSH host key与agent允许以`tanmy-white\\tanmy`读取Windows主机；系统为Windows `10.0.26200.9168`，Sunshine PID与`SunshineService`均在运行，安装目录为`C:\\Program Files\\Sunshine`。只用于日志/配置/状态取证，不修改配置、不重启服务、不安装driver。
- **远端命令错误：** 首条PowerShell命令的嵌套单引号被SSH/CMD层剥离，第二条`foreach {...} | ConvertTo-Json`触发Windows PowerShell空管道解析错误；两次都在读取目标数据前退出且远端零变化。后续固定将脚本UTF-16LE Base64后用`-EncodedCommand`执行，并先汇总数组再输出JSON。
- **新主机证据：** Windows Application Event 1000/1001证明`Sunshine.exe`在`2026-08-27 04:20:44 +08:00`以`APPCRASH`/`KERNELBASE.dll`/`0x80000003`失败，并于`04:21:28`重建进程；但`212958f` gate实际为`04:43:20–04:44:06`，故该崩溃与当次audio零包无直接时序因果。继续判断host audio capture、audio peer登记、wrong endpoint和client handshake时序；没有因果证据前不进入production audio priming修改。
- **实现设计：** production inventory向session-control与audio-receive注入同一audio reservation actor。audio SETUP后立即以真实channel连接并发sequence 0 ping；media environment启动audio provider时按`sessionID + endpoint + ping payload`原子claim该channel，从sequence 1继续现有ping/receive loop。未claim reservation在replacement、bootstrap failure、reconnect及stop中取消；claim后由现有media generation teardown负责，不增加临时socket或remote `/cancel`。
- **当前实现：** reservation、RTSP时序、production/live harness注入及HDR x86_64 test conversion已进入工作树；未执行live gate。首次focused build编排在源码编译前因错用不存在的`LuneX` scheme失败，随后zsh脚本赋值只读`status`变量；后续用`xcodebuild -list`确认实scheme并改用非保留变量，不重复该命令。
- **focused验收：** 最终`43/43`通过，确认audio SETUP后的sequence 0、PLAY前sequence 1、audio runtime同socket sequence 2、replacement/unclaimed cancel、claimed ownership及missing reservation fail-closed；structured diagnostics为`0/0/0`。下一门为session/reconnect/AppModel related matrix、fresh macOS normal、universal Debug/Release和冻结平台generic compatibility，仍不运行live或Keychain gate。
- **universal编译错误：** related matrix已通过`282/281/1 live skip/0`，但fresh universal test build证明x86_64对`Float16(bitPattern:)`与`Float(Float16)`都无可用initializer，前一层转换假设无效。改为test-only IEEE-754 binary16显式解码，覆盖subnormal/finite/infinity/NaN，不改shader或product HDR管线；下一次用fresh universal build验证。
- **offline总验收：** universal test bundle已恢复`x86_64 arm64`；macOS normal为`1333/1331/2 exact opt-in skips/0`且structured diagnostics全零。macOS Debug/Release universal及iOS/iPadOS、tvOS、visionOS generic build全通过，Metal artifacts共10个。剩余pre-commit gate为generator双跑hash、OpenSpec strict、源码/隐私/remote-cancel/diff审阅；通过后提交推送新SHA并只运行一次live gate。
- **pre-commit隐私审阅：** 发现live control wrapper仍保存`type + String(describing:)`，可能把任意transport错误描述带入XCTest回执。已改为封闭的control failure cause枚举，consumer cancellation与显式network cancellation不记为失败，并增加带secret/endpoint/payload/certificate/operation文本的对抗测试；必须先通过fresh focused/related门禁才能提交。
- **隐私修订回归：** fresh warnings-as-errors `AppModelWorkflowTests`在`/private/tmp/LuneX-audio-privacy-related.mb8bXV/Related.xcresult`通过`103 total / 102 passed / 1 live opt-in skip / 0 failed`，structured build为`succeeded / 0 error / 0 warning / 0 analyzer warning`；三个真实opt-in均由命令移除，未访问host或Keychain。
- **最终repository生成门：** 当前源码的fresh universal test bundle `/private/tmp/LuneX-audio-precommit-universal.psNLhP`构建成功且为`x86_64 arm64`。权威generator双跑前/后hash均为`783a7494...5944`且project零diff；OpenSpec strict为`11/11`，apply仍为`7/27 ready`、next 2.3 pending。
- **pre-commit repository gate：** `git diff --check`通过；HEAD与`origin/main`均为`a1647b1`；修改精确为7个source/test文件和3份planning authority。当前修改中无remote-cancel true、无任意error description/`localizedDescription`、无identity/certificate/key/payload/address材料新增，双opt-in与real Keychain仍默认关闭，`xcodebuild`/`xctest`残留为零。可以提交并推送新的唯一live candidate。
- **exact candidate：** audio reservation修复以`0b803c3eb1c5a1a2cd2c3c8680da0c7f0fa35c8f`提交并推送，live前HEAD、origin/main与工作树一致；fresh arm64 bundle位于`/private/tmp/LuneX-live-0b803c3e.GP9JrU`并绑定该SHA。
- **唯一live gate结果：** `0b803c3`在`2026-08-28 01:34:26 +08:00`执行一次double-opt-in gate且不得重跑。matching Desktop走`/resume`，`launch/resume/cancel=0/1/0`；control到达`launch_accepted,rtsp_ready,negotiated,channels_1,video_color_metadata`且无control/media receive failure。provider启动时才建立live recorder stage，因此`connections=0,pings=1`只直接记录handoff后的runtime sequence 2 ping，不记录更早的SETUP/PLAY前sequence 0/1；后两者由确定性测试证明。live随后收到`87`个datagram并产生`58`个parser event，证明该候选成功取得真实Sunshine音频流并关闭audio零包问题。
- **新阻塞：** 首批audio packet进入本地管线后，AppModel在1.125秒内以`audio_pipeline_failed` / `audio_output_unavailable`失败，audio runtime未发布，视频仅收到1个datagram且尚未产生parser event；因此持续decoded video、可听同步audio和后续input/reconnect/termination/stop矩阵均未执行。下一候选必须定位有限的Opus decode/AVAudioEngine输出失败原因，不重跑`0b803c3`。
- **live清理：** Sunshine PID/start time与Event 1000/1001列表前后相同；四个LuneX状态文件mode/size/SHA-256前后完全相同；Git clean、零xcodebuild/xctest残留、零remote `/cancel`。Task 2.3继续pending。
- **下一候选诊断（进行中）：** 产品诊断已将Opus、jitter、pipeline和runtime错误映射为有限cause，关联OSStatus/sequence/graph文本一律丢弃。首轮focused编译通过但新隐私测试错误地禁止了合法枚举词`payload`，导致`32/33`；已拆分有限分类与secret-bearing graph文本断言，失败bundle不计成功证据，等待fresh复核。
- **下一候选离线状态：** 修正测试断言后的fresh focused为`33/33`，相关音频/runtime/AppModel矩阵为`268/267/1 live skip/0`，完整macOS normal为`1335/1333/2 exact opt-in skips/0`，三份structured build均为`succeeded/0 errors/0 warnings/0 analyzer warnings`。下一步完成universal test build、五产品generic compatibility、generator/OpenSpec/privacy/remote-cancel/opt-in/process/diff门，提交推送新exact SHA后只执行一次双opt-in live gate；Task 2.3在完整live矩阵前保持pending。
- **通用构建门：** fresh universal test bundle为`x86_64 arm64`且structured diagnostics全零；macOS Debug/Release及iOS/iPadOS、tvOS、visionOS generic build五份全部`succeeded/0/0/0`。首次只读架构脚本沿用错误产物名`LuneX.app`而在`find`断言退出，构建无失败且未重跑；已枚举实际`LuneX-macOS.app`路径，等待完成双macOS架构、Metal和repository门复核。
- **repository gate错误记录：** 首轮完整wrapper的分段诊断证明除coverage hygiene外均已通过；过宽全树扫描命中mtime为2026-07-10且被`build/`规则忽略的既有IdentityLifecycle `.profraw`，并非本轮生成。保留既有证据且不删除，最终门只拒绝Git可见未跟踪coverage与仓库根`default.profraw`，复用既有test/build/generator结果。
- **pre-commit验收：** corrected repository gate输出`FINAL_AUDIO_CAUSE_REPOSITORY_GATE_OK`；精确5文件、三方`0b803c3`基线、stable project、OpenSpec `11/11`与`7/27 next 2.3 pending`、最终test/build/Metal/universal证据、精确opt-in skips、fallback权限及零privacy/remote-cancel/opt-in/process/coverage污染均通过。Task 2.3保持pending，等待人工diff终审、提交推送与新SHA唯一live gate。
- **exact diagnostic candidate：** `838e5b56543c2e4127e286b652a8b614e218179f`已提交推送并从clean SHA构建fresh arm64 bundle `/private/tmp/LuneX-live-838e5b5.mQT1aK`；本地/origin/remote一致。
- **唯一live结果：** `838e5b5`仅运行一次双opt-in gate且已消费，不得重跑。Desktop走`/resume`，`launch/resume/cancel=0/1/0`，control到`channels_1`和video metadata；audio真实流为`93 datagram / 62 parser event`，随后1.176秒明确以`audio_pipeline_schedule_capacity`失败。该结果排除本轮decrypt、Opus decode、PCM shape与clock分类，下一修复点为AudioSessionPipeline容量/backpressure及AVAudioPlayerNode completion合同。
- **live清理与边界：** 四状态文件和Sunshine PID/start/event前后完全一致，Git clean、零remote `/cancel`、零build/test进程；video仅1 datagram/0 event是audio早停截面，不能标记视频回归。Task 2.3仍pending。
## 2026-08-28 M1 Task 2.3 exact-SHA video-processing live gate

- **状态：** `in_progress`；恢复后的权威 OpenSpec 状态为 `spec-driven / 7 of 27 / ready`，下一项仍为 2.3，完整真实 Sunshine 验收矩阵通过前不得勾选。
- **候选：** clean pushed exact SHA `80055846be96b3f0ea7ddacf6a0cab5d6dbf52b7`。只允许从该 SHA fresh 构建一个 arm64 test bundle，并消费一次 `LUNEX_RUN_LIVE_HOST_TEST=1` + `LUNEX_RUN_LIVE_DESKTOP_SESSION=1` gate；不重跑任何旧 SHA。
- **本轮判定：** 读取有限 `videoProcessing` 回执，将阻塞分到 access-unit assembly、production decode submission 或 VideoToolbox callback/presentation publication；不记录 payload、endpoint、frame/sequence/timestamp、identity、certificate、key 或任意错误文本。
- **环境边界：** Sunshine 仅做运行前后只读 PID/start/service/crash-event 快照，不修改、重启或重新配置；不操作 Simulator；真实 Keychain gate 保持关闭；local stop/failure/reconnect/replacement 不调用 remote `/cancel`。
- **控制面错误：** 用户此前已明确要求重新创建目标，但 `create_goal` 再次因旧 `blocked` goal 被服务端视作 unfinished 而拒绝。该错误没有仓库、host、Keychain、Simulator 或 runtime 副作用；继续以 OpenSpec 与三份 planning files 为执行权威。
- **唯一 live 结果：** `8005584` gate 已消费且不得重跑。production parser 的 `251588` events 由 shadow assembler 无损组为 `4628` access units，全部有限 frame-loss/discard reason 为 `0`，但 production submission 为 `0` 且 published frame 为 `0`；audio 为 `running`，control/media failure 均为 none，`launch/resume/cancel=0/1/0`。
- **下一修复门：** `accessUnits > 0 && submitted == 0` 将根因边界移到 VideoToolbox submission 前。下一候选先增加有限 `VideoDecodePipelineSnapshot` 回执，区分 awaiting-IDR、IDR request、format/decoder readiness 与有限 decoder drop/failure，不存参数集、payload、timestamp、frame index、OSStatus 或任意错误描述；随后实施证据支持的最小产品修复并重走离线门。
- **清理验收：** live log SHA-256 `4c4ffdf...843266`；四个本地状态文件 mode/size/hash 前后相同，Sunshine PID/start/service/Event 1001 快照前后相同，零 remote cancel，零 xcodebuild/xctest 残留，coverage 仅在本轮临时目录生成一份。主工作树只有本轮 planning 记录，detached exact-SHA source 保持 clean。
- **coverage 根因：** exact binary 与保留的 profraw 经 `llvm-cov` 证明 `NativeSessionVideoProcessor.consume()` 被调用约 251k 次，但 `VideoDecodePipeline.consume()` 与 `MoonlightControlChannel.requestIDR()` 均为 0 次。production processor 由一次 `.inactive` lifecycle 将 `isDrainingTransport` 设为 true，随后所有媒体事件在 decoder 前返回；这不是 FEC、参数集、VideoToolbox 或 IDR 失败。
- **产品修复：** macOS `RootView` 现在以 `hasActiveStreamSession` 的只读投影驱动平台 stream lifecycle，而不再等待首个 decoded frame 才令 lifecycle active，从而解除 `isStreaming -> active lifecycle -> decode -> isStreaming` 循环依赖。session stop/teardown 清除 active session 后仍恢复 inactive，真实 occlusion/minimize/drawable/focus resolver 未放宽。
- **direct XCTest 边界：** live XCTest 没有 AppKit window，故在 launch 前显式应用 test-owned active/visible/focused/nonzero-drawable lifecycle，并通过同一 production resolver 进入媒体 generation。该行为只修复 harness 环境缺口；实际 `NSWindow` occlusion、minimize、focus、resize、screen change 与 drawable-loss 验收仍属于独立 AppKit/physical evidence。
- **fresh focused：** `/private/tmp/LuneX-lifecycle-decode-focused.t0Vl6g/Focused.xcresult` 结构化通过 `3 total / 3 passed / 0 skipped / 0 failed`，build 为 `succeeded / 0 error / 0 warning / 0 analyzer warning`。覆盖 lifecycle 缓存/回放、有限 decode receipt 隐私边界与 production wrapper 原样转发；Task 2.3 继续 pending，下一步为 fresh related 与完整离线门。
- **fresh related：** `/private/tmp/LuneX-lifecycle-related.qhdiEV/Related.xcresult` 结构化通过 `218 total / 217 passed / 1 live opt-in skip / 0 failed / 0 expected failure`，build 为 `succeeded / 0 error / 0 warning / 0 analyzer warning`。覆盖 AppModel、lifecycle render policy、session media environment、VideoDecodePipeline、VideoToolbox decompression、packet assembly 与 Moonlight media receive。Xcode 仅在枚举锁定的外接 iOS 设备时输出非结构化 notification-proxy 信息，macOS destination 未操作该设备；下一步 fresh serial macOS normal。
- **fresh normal：** `/private/tmp/LuneX-lifecycle-normal.9dckfG/Normal.xcresult` 结构化通过 `1341 total / 1339 passed / 2 skipped / 0 failed / 0 expected failure`，build 为 `succeeded / 0 error / 0 warning / 0 analyzer warning`。两个 skip 精确为 live Sunshine 与 real Keychain 显式 opt-in；普通测试继续使用 Debug 文件 fallback，未访问 host/Keychain 或操作 Simulator。下一步 universal test build 与五产品 generic build gate。
- **universal/product builds：** `/private/tmp/LuneX-lifecycle-universal.Eow0DM/Universal.xcresult` 为 `succeeded/0/0/0`，test bundle 精确 `x86_64 arm64`。`/private/tmp/LuneX-lifecycle-builds.ansDKS` 中 macOS Debug/Release、iOS+iPadOS generic Debug、tvOS generic Debug、visionOS generic Debug 共 `5/5` 均为 `succeeded / 0 error / 0 warning / 0 analyzer warning`，两个 macOS executable 均为 `x86_64 arm64`。冻结平台只记录共享兼容，未启动 Simulator；下一步 generator/OpenSpec/repository gate。
- **generator/OpenSpec：** 权威 Ruby generator 连续两次运行前后 `project.pbxproj` SHA-256 均为 `783a749484d0dc173a1296f7a573dfc0a7e9f5a3292fccf08046c0fa54035944` 且零 drift。OpenSpec strict 为 `11/11`，当前 change 保持 `7/27 ready`、next 2.3 pending。
- **pre-commit repository gate：** 精确 10 文件 scope、`git diff --check`、零 untracked/coverage drift、零 secret PEM marker、零 production `cancelRemoteSession: true`、三个真实 opt-in unset、fallback `0700/0600`、零 xcodebuild/xctest、HEAD/origin `8005584` 基线、focused `3/3`、related `218/217/1/0`、normal `1341/1339/2/0`、universal 与五 build 全部通过。人工逐行审阅未发现 actor isolation、activity ownership、饱和计数或 receipt 隐私问题；Task 2.3 不勾选，下一步 post-record 只读复核与独立提交推送。

## 2026-08-28 M1 actual macOS product window continuation

- **状态：** `in_progress`；OpenSpec `prioritize-macos-product-completion` 为 `spec-driven / 7 of 27 / ready`，Task 2.3 继续 pending。当前 pushed baseline 为 `ce4aa1259600d13b99e1ef27e5585123a43c325b`。
- **窗口缺陷与修复：** 实际 SwiftUI 产品初始 AppKit window 曾因 `.windowResizability(.contentSize)` 和 loading view intrinsic size 塌缩为 `220x104`。工作树已引入 `ProductWorkspaceWindowSizingPolicy`，将 macOS 默认尺寸定为 `1280x800`、最小 content 尺寸定为 `960x640`，scene 改用 `.contentMinSize`，并覆盖 loading/error/normal 三种根视图。
- **当前证据：** focused `/private/tmp/LuneX-window-sizing-focused/Focused.xcresult` 为 `1/1` 且 structured diagnostics 全零。基于当前源码的 test-only ad-hoc 产品 `/private/tmp/LuneX-window-sizing-product` 在 1 秒和 5 秒实际 AppKit window 都为 `960x692`，三台保存主机与 cached apps 完整可见；该产品 build-time 清空 entitlements，只能证明 UI/AppKit 行为，不能替代稳定开发签名、head tracking entitlement、notarization 或稳定 signed-App TCC。
- **当前运行约束：** 仅有一个 `LuneX-macOS` 实例 PID `67334` 和一个 structured log stream PID `67289`；不得再启动第二个 App。下一步通过 AX 精确选择在线 `tanmy-white`，重新读取 Host 字段确认后，才允许在当前产品中对 `Desktop` 执行一次受控 launch；启动前后只读记录本地状态和 Sunshine PID/start/service/event，不以 host busy/free 或 Sunshine package version 设门。
- **完成边界：** 本轮产品级 gate 仍需证明真实 window surface attach/drawable、视频呈现、audio runtime、输入、occlusion/key/screen/resize 生命周期与清理；物理可听同步、host 可见输入、真实 reconnect、host-side termination、稳定 signed-App TCC 和完整 teardown/relaunch 仍是独立 pending 行，未满足前不勾选 Task 2.3。
- **UI 编排错误：** 初次切换 Computer Use 时错误使用显示名 `LuneX-macOS`，其自动解析并启动了 DerivedData 中同名 bundle，产生第二实例 PID `70982`。立即按 executable path/start time 区分并以 `SIGTERM` 终止新实例，确认仅原 PID `67334` 留存；误实例上的 `tanmy-white` 选择随进程退出，未启动串流。后续 Computer Use 必须以原 test-only bundle 的绝对路径为 app 标识，并在每个动作前后核对唯一 PID。

## 2026-08-28 macOS product information architecture correction (active)

- **Status:** in progress; this is an admitted prerequisite to the current M1 Task 2.3 product gate and does not complete Task 2.3 or M4 Task 5.1.
- **Observed failure:** the product exposes `Library`, `Stream`, `Diagnostics`, and `Settings` as equal, persistent sidebar destinations even though only host/app selection and launch are high-frequency; the empty Stream destination is a black shell; Settings mixes preferences with runtime diagnostics in an unbounded layout; host reachability and pairing are visually conflated, all saved hosts can remain `Unknown`, and normal use exposes manual refresh controls.
- **Target macOS flow:** one Library workbench for automatic host presence, host selection, app catalog, pairing when needed, and direct launch; an active session temporarily owns the full content surface; Settings opens as a native low-frequency window; Diagnostics is an on-demand support surface; no permanent screen-category sidebar remains on macOS.
- **Acceptance slice:** online/offline/checking and paired/unpaired are separately encoded; green means reachable only; saved-host reachability and selected-host catalog update automatically while the window is alive; normal Library UI has no manual refresh requirement; cached offline apps remain recognizable but cannot masquerade as launch-ready; settings use bounded native sections and auto-save; stop returns to Library; focused source/model tests, full macOS normal tests, product build, and actual Computer Use screenshots pass with exactly one LuneX process and no Simulator.
- **Execution order:** (1) model and discovery/reachability contract; (2) macOS Library/session navigation; (3) native Settings/Diagnostics presentation; (4) deterministic regression; (5) one-instance Computer Use visual acceptance. Non-macOS product UI remains frozen except compilation-preserving conditional branches.
- **Spec reload merge:** Claude's latest shell authority has been reread and reconciled with the user's frequency/state feedback. Initial selection now has an explicit contract: preserve a valid user choice; otherwise prefer online+paired and allow only provisional automatic choices to promote after reachability. Focused shell/discovery verification passed; remaining gates are full macOS tests, generic frozen-platform builds, one-instance keyboard/visual Computer Use acceptance, and final strict/planning synchronization.
- **Shell redesign final gate:** OpenSpec `redesign-macos-library-shell` 的最终源码已通过 fresh macOS warnings-as-errors 全量测试 `/tmp/LuneX-Redesign-FinalTests-E78AD5A3-4C27-428C-BB68-984BC28FFA92/Full.xcresult`：`1355 total / 1353 passed / 2 exact opt-in skips / 0 failed / 0 expected failure`，structured build diagnostics 为 `0/0/0`。两个 skip 精确为 live Sunshine 与 real Keychain；普通 Debug identity 继续使用文件 fallback。
- **Release/compatibility gate:** fresh macOS Release `/tmp/LuneX-Redesign-FinalRelease-74913118-7E91-425A-86AC-14E8A1A9DEF8` 构建成功，`lipo` 与 `file` 均确认 executable 为 `x86_64 arm64`。iOS/iPadOS、tvOS、visionOS 三个独立 generic Debug build 位于 `/tmp/LuneX-Redesign-FinalGeneric-82150B74-70A9-4C69-B8CC-B0507C5065DE`，均为 `BUILD SUCCEEDED / 0 structured diagnostics`；该证据只证明冻结平台共享代码兼容，不推进其产品状态，也未启动或查询 Simulator。
- **Generator/strict gate:** 权威 `/usr/bin/ruby Tools/generate_xcodeproj.rb` 双跑前/后 `project.pbxproj` SHA-256 均为 `e412926e1036f7ebda429dfffb4b5a2705cf01dccba65c08cdccbb74da7524bf`；最终 `openspec validate redesign-macos-library-shell --strict --no-interactive` 与 `git diff --check` 均通过，change 为 `18/18 / all_done`。原始 build log 的唯一 `warning:` 是 AppIntents metadata processor 对未依赖 framework 的跳过提示，xcresult 的 Swift/Clang/Metal/analyzer diagnostics 均为零。
- **Final flaky-test resolution:** 首轮完整矩阵暴露 stop teardown 期间迟到 `.streaming` snapshot 覆盖 `.stopping`，已在 `applySessionSnapshot()` 拒绝当前 stop owner 的 snapshot；第二轮暴露 Vision resize 测试错误依赖整个 action history 的瞬时 `last`，已改为检查最后一个 `.scene` action。曾尝试 2 秒 sleep 型公共等待器会稳定错过瞬时 scene action，已完整撤回；targeted final `5/5` 和上述 full final 全部通过。对同一 xcresult 的并行读取曾触发 Xcode 26.4 `database.sqlite3` 临时文件竞争，最终证据均改为串行读取，不重复成功 suite。
- **Scope boundary:** 本次 host-centric shell 子变更已满足实现、Computer Use、完整测试、Release/generic build、generator 与 strict 收口条件；M4 总里程碑仍包含更广的 macOS workflow/export/accessibility 冻结边界，M1 Task 2.3 的物理可听同步、host 可见输入、真实 reconnect/remote termination、稳定签名/TCC 与资源/重启验收继续 pending，不由 UI shell 的完成代替。
- **Archive/commit gate:** 用户人工双击 `Desktop` 已确认真实 AppKit 双击能够启动；Computer Use 的 AX `click_count: 2` 未触发 SwiftUI `TapGesture(count: 2)`，因此自动化无响应不能作为产品连接缺陷，未修改 launch 代码。`redesign-macos-library-shell` 已同步为主 spec `openspec/specs/macos-product-shell/spec.md`，并归档到 `openspec/changes/archive/2026-08-28-redesign-macos-library-shell/`；归档后全仓 OpenSpec strict 为 `12/12`。
