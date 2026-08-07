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
| 5. macOS 核心体验 | partial | window lifecycle 与 Metal pause/throttle 已接线；balanced cursor owner已实现，真实capture接线、输入发送、HDR和音频待完成 |
| 6. iOS/iPadOS 核心体验 | partial | policy/model 与原生 UI 已有；scene/resize、PiP、后台 session、移动 EDR 未接线 |
| 7. 流媒体协议与会话核心 | partial | host/app HTTPS 与状态骨架已有；真实 pairing、RTSP/control、解码和输入 transport 未实现 |
| 8. tvOS/visionOS 适配 | partial | target、UI 和 adapter 骨架可构建；真实媒体、输入、HDR/空间音频未验证 |
| 9. 验证与迭代 | partial | build/unit gates 已有；缺少真实 Sunshine 和真机端到端、性能、功耗与长时验证 |
| 10. 本地真实测试数据导入 | complete | 从本机 Moonlight-qt 偏好导入 paired hosts、cached apps 和本地 identity 到 LuneX Application Support；验证 macOS App 可读取 |
| 11. 审计关键问题修复 | complete | OpenSpec `remediate-critical-audit-findings`：移除伪配对/伪 Streaming/明文私钥副本，修复 compact iPhone 导航并补回归验证 |
| 12. 身份/TLS/macOS 生命周期接线 | complete | OpenSpec `integrate-identity-trust-macos-lifecycle`：一次 Keychain 验证、Debug 文件 fallback、pinned TLS、macOS window/EDR runtime wiring |
| 13. 真实 Moonlight session runtime | in_progress | OpenSpec `implement-moonlight-session-runtime`：identity/pairing、RTSP/control、视频、音频、输入和互操作验证 |
| 14. macOS 原生输入与生命周期闭环 | in_progress | OpenSpec `integrate-macos-native-input-lifecycle`进度`28/29`；确定性实现、验证和跟踪完成，6.5等待授权Sunshine/物理输入/多显示器；继续阶段15 |
| 15. 原生 HDR/EDR 管线 | in_progress | OpenSpec `implement-native-hdr-edr-pipeline`进度`32/33`；离线实现、质量、simulator与跟踪封版完成，唯一剩余6.5等待授权Sunshine和物理HDR/SDR显示器 |
| 16. 空间音频运行接线 | in_progress | OpenSpec `integrate-spatial-audio-runtime`进度`34/35`；离线实现、质量、simulator、合同和阶段自验封版完成，唯一剩余6.6等待授权物理音频硬件 |
| 17. iOS/iPadOS scene、PiP 与连续性 | in_progress | OpenSpec `integrate-mobile-scene-pip-continuity`进度`35/36`；离线实现、质量、fixed-simulator与6.7证明边界封版完成，唯一剩余6.6 signed physical acceptance |
| 18. tvOS/visionOS 运行适配 | in_progress | OpenSpec `32/50 ready`；6.1 current visionOS windowed actual state已实现并通过fresh test/build/repository/final-state验收，下一项6.2 actual window surface frame/Metal绑定 |
| 19. 原生产品工作流与无障碍 | pending | pairing/recovery/stream control、错误 UX、多窗口、VoiceOver、键盘与触控回归 |
| 20. Release 性能与质量验证 | pending | 延迟、功耗、内存、热状态、弱网、长时运行、签名和发布构建 |

## 当前焦点

后续从阶段 13 开始，当前第一优先级为 OpenSpec `implement-moonlight-session-runtime`。完成口径改为生产路径接线 + 确定性测试 + 授权 live Sunshine 端到端证据；策略类型、编译成功、launch response 或首帧都不能单独标记产品功能完成。完整依赖与验收门见 `docs/runtime-completion-roadmap.md`。

当前 change 权威进度为 `54/61`：9.7已同步计划、证据与阶段14–20路线图，阶段13的离线/runtime foundation阶段级自验收通过，但production仍缺具体video/audio network receiver与9.2 live-host XCTest。1.1、3.7、5.8、6.7、7.7、9.2与9.3保持未完成，因此阶段13仍为`in_progress`；等待授权host/hardware期间，下一可执行工作为创建并实施阶段14 `integrate-macos-native-input-lifecycle` OpenSpec change，不用后续离线工作替代阶段13 live证据。

阶段14 OpenSpec `integrate-macos-native-input-lifecycle`权威进度`28/29`。确定性production integration、normal/五平台Debug+Release、strict/generator/analyzer/ASan/TSan/malloc和独立simulator门均通过，且已推送HEAD上的阶段级离线自验再次通过`470 total / 469 passed / 1 Keychain skip / 0 failed`。6.5仍需授权Sunshine host、物理键盘/鼠标和多显示器，change保持`in_progress`且不可archive；下一可执行工作为创建阶段15 `implement-native-hdr-edr-pipeline`，不以阶段15证据替代6.5。

阶段15 OpenSpec `implement-native-hdr-edr-pipeline`权威进度`32/33 in_progress`。1.1至6.4与6.6的production、确定性测试、normal/五平台Debug+Release、strict/generator/dependency/Metal/analyzer/ASan/TSan/malloc/resource、simulator与跟踪证据均完成并逐项提交推送；已推送`372ca60`上的阶段级离线自验再次通过`616 total / 615 passed / 1 Keychain skip / 0 failed`、strict `6/6`、generator与固定simulator门。唯一剩余6.5要求授权Sunshine HDR源、代表性HDR/SDR物理显示器和可审计参考图或测量。没有live compositor EDR signaling、物理亮度/颜色、动态headroom和跨显示器证据时，change不可archive、阶段不可标记`complete`；下一可执行阶段为16空间音频，不以其证据替代6.5。

阶段16已在macOS 27.0/Xcode 26.4更新后恢复并进入`in_progress`。OpenSpec `integrate-spatial-audio-runtime`权威进度`34/35`：1.x至3.x的channel-layout、session-owned graph、平台策略、entitlement、route/capability adapter和observer矩阵已完成；4.1至4.6完成runtime到AppModel的generation-owned接线、恢复/replacement矩阵与合法WAVE 7.1 application gate；5.1至5.5完成设置、诊断、actual-runtime UI及responsive/localization/accessibility矩阵；6.1至6.5完成normal、十配置五平台build、strict/API/analyzer、完整ASan/TSan、11类malloc/resource与独立simulator门。6.7新增权威空间音频合同并同步路线图、entitlement/hardware说明和proof boundary；阶段级fresh normal再次通过`721 total / 720 passed / 1 Keychain skip / 0 failed`，strict/generator/sanitizer/resource/simulator组合门通过。唯一剩余6.6等待授权signed entitlement、AirPods、built-in/wired/HDMI、多声道识别、route transition、听感同步和live Sunshine物理证据；change不可archive、阶段不可标记complete。实现和测试继续显式移除`LUNEX_RUN_KEYCHAIN_TEST`并使用Debug文件fallback；离线测试、属性赋值、编译或模拟器不能替代6.6。

阶段17 OpenSpec `integrate-mobile-scene-pip-continuity`保持`in_progress`，权威进度`35/36`。1.x至5.6、6.1–6.5与6.7的actual runtime/UI、normal/build/repository/API/analyzer/sanitizer/resource/fixed-simulator和五级proof boundary封版均完成；已推送`c7c9089`上的阶段级fresh normal `909/908/1/0`与组合门再次通过。唯一剩余6.6需要signed physical iPhone/iPad、system PiP、Stage Manager、external display、visible EDR、空间音频、power/thermal与live Sunshine receipt；change不可archive。

阶段18 OpenSpec `integrate-tvos-visionos-runtime`保持`31/50 ready`、next 6.1。1.1至4.6的platform ownership与tvOS input/focus/controller/media runtime，以及5.1至5.6的visionOS actual window observation、geometry/input mapping、public input adapters、system interaction reservation、ordered held-state release和三条连接回归矩阵均已完成task级验收。5.6 focused `3/3`、related `213/213`、normal `1072/1071/1/0`、unsigned五平台Debug、repository pre-gate `/tmp/LuneX-18-5_6-repository-pre-r3.FltJEs`与post-mark final-state `/tmp/LuneX-18-5_6-final-state-r2.ZtO9JF`均通过；下一步为6.1显式current-generation windowed presentation mode和typed immersive/stereoscopic/volumetric unavailable states。当前证据仍不是Simulator runtime、signed artifact、physical HDR/input/spatial、live Sunshine或性能证明。

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

- 阶段13 / OpenSpec `implement-moonlight-session-runtime` 当前权威进度为`54/61`；9.7已完成。阶段级离线/runtime foundation验收通过，但7项live/hardware证据仍未通过，阶段保持`in_progress`；下一可执行项为阶段14 OpenSpec提案与实现。
- production inventory继续因缺video/audio receiver而truthfully unavailable；3.7/5.8/6.7/7.7/9.2/9.3所需授权host或硬件证据保持未完成，不用fixture、编译或离线测试替代。
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
