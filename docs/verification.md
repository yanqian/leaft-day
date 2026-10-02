# 自动验证

从项目根目录运行（也可从其他目录用绝对路径调用）：

```bash
./verify.sh --changed                 # 按相对 HEAD 的工作区改动选用例
./verify.sh --changed --base main      # 包括相对指定 ref 的已提交改动
./verify.sh --full                    # 强制完整回归
./init.sh                            # 恢复入口；允许复用严格匹配的完整测试记录
SWIPE_VERIFY_FRESH=1 ./init.sh         # 独立 Evaluator 首次必须使用
./verify.sh --full --reuse            # 显式允许复用；--fresh 优先于 --reuse
```

成功退出 0，任何门禁失败退出非零。命令只输出阶段和最终结果，不将每次点击、编译命令流刷到终端。失败不会自动无限重试。

每次运行的 `.build/verification/<时间-唯一后缀>/` 包含：

- `summary.json`：供Agent优先读取的简短结果，包含状态、模式、选择原因、真实测试计数、失败和视觉变化、复用来源与详细证据路径；不塞入所有源码哈希或正常截图。
- `report.md`：简短可读汇总，只展开失败和视觉变化。
- `receipt.json`：完整源码/配置与环境指纹、改动路径、执行步骤、用例耗时及全部附件索引。
- `evidence.md`：全部日志和截图入口，诊断或视觉审阅时按需打开。
- 独立构建/权限准备/测试等日志；新执行时保存 `PermissionSetup.xcresult`、`Tests.xcresult` 和导出附件。
- `.build/verification/latest.json` 指向最近一次运行；`latest-full.json` 仅指向可复用的原始完整成功receipt。不能仅凭文件存在声称通过。

先阅读报告，再打开失败用例日志及改动页面的截图。截图用于判断玻璃效果、布局等视觉质量；可启用像素基准比较，但它不自动认定设计美观。系统时间、照片、动态材质等会导致图片变化，不能简单把图片哈希差异等同产品缺陷。交互和无障碍要求应尽可能写成 XCTest 断言。

## 用例选择与维护

`--changed` 使用 Git 相对 ref 的 diff（同时覆盖暂存和未暂存）加未跟踪文件；重命名按旧、新两条路径处理。日常包括全部快速单元测试和启动 UI smoke，并按 `scripts/verification.py` 中 `PAGE_SUITES` 增加相关 UI 类。目前首页、权限、比较、核对有显式映射；删除、回顾、领域、共享设计系统、资源、脚本、配置以及未知路径均回退全量。文档和 Harness 的 SPEC/progress/feature状态不扩大产品用例；Harness 验证每次照常执行。

修改页面行为时一起维护对应 case 和映射；共享 helper/依赖影响不明确时保留全量，不能为省时硬缩范围。新增 UI case 类必须能从 Swift 文件发现；映射失效回退全量。全量/增量都先构建一次，再通过 `test-without-building` 执行真实权限预备及测试。权限/图库会共享状态，保持串行；只移除 XCTest runner，不卸载 App 或清空图库。模拟器选择遵循原 `SWIPE_SIMULATOR_UDID` 和 `select-simulator.py`。

## 复用边界

复用需要同时满足：原始完整成功记录距今不超过24小时、无跳过/预期失败、源码/测试/脚本/配置/fixture文件内容与模式相同、Xcode/XcodeGen/Python/macOS/模拟器UDID与runtime、实际使用工具的解析路径/二进制摘要及相关环境相同（无关PATH前缀不影响复用）；已构建App、原始xcresult、报告原始数据、构建/测试日志和截图目录仍存在且哈希匹配。Git HEAD只作溯源，因此提交但内容未变不会独自失效。运行前后源码再比较；运行中编辑导致失败而非产出通过。

每次仍执行 Harness/Python检查、依赖检查、fixture生成、项目生成和真实模拟器安装/启动；复用省去昂贵的 UI 重跑，**不是零成本恢复**。独立 Evaluator 首次强制 fresh，不使用 Coder 的测试当独立验收。成功记录不代表独立 EVAL_PASS，后者仍由 Harness Evaluator 编排产生。复用不延长原始有效期。新的执行失败会使旧指针失效；不覆盖失败证据。设备模式不使用模拟器复用记录。外部xcconfig或自定义编译器/SDK/toolchain覆盖也强制fresh，因为其外部依赖无法仅凭路径证明未变化。

同一入口用进程锁保护模拟器与构建目录；并发启动会快速失败并输出自身报告，不影响已有运行和成功记录。旧的专项脚本或 Xcode 不受此锁自动控制，运行统一入口时不要同时调用它们。超时或中断会终止本次子进程组并保存失败报告。

## 验证此工具本身

```bash
python3 -m unittest discover -s tests -v
```

`tests/fixtures/xcresult-*.json` 从本机 Xcode 26 的真实成功/失败 bundle 和附件导出采集；测试覆盖真实schema、路径选择、空结果、缺附件、过期/变更/损坏回执、超时和并发锁。fixture只证明解析契约，实际 full/changed/reuse 仍以真实命令运行报告为准。真机/iCloud/大型图库验收继续属于 F018，不包含在这里。

## 可选视觉基准

第一次没有基准时，报告明确 `not_configured`，行为测试仍正常执行。查看本次截图后，显式批准：

```bash
./verify.sh --accept-visual-baseline .build/verification/<run>/summary.json
./verify.sh --changed
```

默认基准在 `tests/visual-baselines/`，可通过 `--baseline <目录>` 指定。增量报告的批准只合并本次截图，不删其他页面；全量报告的显式批准也接受已经移除的截图；不能接受行为/构建失败的报告。不要把未审阅的截图自动批准；基准和case一起纳入版本控制。当前功能交付不自动批准全应用截图。

有基准时，报告列出新增、变化，以及全量运行没有再产出的基准截图，链接不可变的基准副本与实际图，退出非零等待审阅。增量只检查本次实际执行用例的缺失截图，不要求产出其他suite的截图。基准按用例+附件语义名匹配，去掉Xcode生成的序号/UUID；同一用例截图应使用唯一名称。外部修改基准图片导致哈希不符会失败。

`baseline.json` 的 policy 默认：最长边缩放到512px，忽略顶部5%状态栏，每像素BGR最大通道差大于24才计为变化，变化超过有效像素1%时需审阅。参数可配置并进入验证指纹。此方法捕获较明显的视觉退化，不替代文字裁剪、触控区域等XCTest断言；动态内容或材质可能仍需审阅。出现预期设计变化时，核对报告再运行同一批准命令；绝不因测试失败自动重写基准。


---

以下保留各功能的验证协议与历史证据边界；统一命令和复用策略以上文F031为准。

# 验证方案

## 当前状态

F001–F017已逐项独立验收并提交；F018真机验收进行中。当前实测范围与未执行项目见device-acceptance.md及deferred-device-verification.md；下面各项协议不可直接当成通过证据。

## 分层验证

| 层 | 关键场景 |
|---|---|
| 纯领域测试 | 固定随机种子下片段顺序；时间边界/闰日/空库；游标恢复；幂等标记；跨照片撤销；相似组反例 |
| 存储与适配 | 保存失败不假成功；重开数据库恢复；资源迟到/取消；编辑使缓存失效；权限缩减不当作删除成功 |
| UI / 模拟器 | 照片左右/上下动作；顶部只展开底部栏；按钮/缩放/视频进度不触发照片手势；复核取消；辅助功能 |
| 真实系统边界 | 部分/拒绝授权、iCloud 未下载/离线、系统收藏/删除请求取消与失败、图库外部变更 |
| 真机体验 | 连续浏览照片视频、旋转/缩放、玻璃可读性、断点恢复、内存与滑动表现 |

Fixtures 只用可丢弃、可重建素材。个人原片不作为自动删除测试目标；mock 不证明系统 API、iCloud 或删除提示行为。预置依赖与 seed 命令需进入仓库；未知工具必须先查官方接口/真实命令，不手写虚构输出。

## 性能证据

记录设备/OS、图库规模、缓存冷热、云端资源比例；测首个可浏览画面、滑动卡顿、峰值内存、缓存大小和下载量。先测真实基线再设有意义阈值，当前没有 60fps 或海量图库能力承诺。功能上要求取消过期加载、有限预取/缓存、分析不阻塞浏览。

## 完成规则

每个 Feature 由独立 Evaluator 验证，所有编号（从 F001 起）均需真实 `EVAL_PASS` run 证据才能完成。模板 evidence 脚本默认基线 F027，不意味着前 26 项可以免验收；F002 必须将项目恢复命令显式使用 `HARNESS_EVALUATOR_EVIDENCE_BASELINE=F001`。

F018 是真实设备整体验证面，不替代各 Feature 自己的测试。缺少设备/签名/云端 fixture 时报告能力缺口，不宣称通过。UI 视觉确认不替代技术验收。

## F003 素材恢复

见 `Fixtures/README.md`：九项自制素材、seed、相似标签和能力边界。根 init 生成默认 seed 并运行文件哈希/视频流合约测试。`python3 scripts/seed-fixtures.py --install` 每次新建隔离模拟器，不向既有库重复导入。导入成功仅证明系统接受媒体；图库实际元数据与授权矩阵由 F005 验证，真实 iCloud/真机由后续 Feature 验证。

### 真实系统验证操作矩阵（F003 定义步骤，后续 Feature 执行）

以下均为待执行协议，不能用本地 fixture pass 填成通过。每次记录日期、App commit、设备型号/OS、授权范围、素材清单、操作前后截图或视频、系统回执和 App 日志；缺少任一前置能力时记为未执行及具体原因。

1. **完整与拒绝授权（F005）**：前置为装有待测 App、仅使用可丢弃 fixture 的隔离图库。首次启动选择不允许，预期明确权限提示且不能把不可见库称为空库；在系统设置切换完整访问并回前台，预期仅显示测试资产且无需重装。留存两种系统设置状态、App 空态/内容截图、查询数量与错误日志。模拟器可验证的状态必须注明模拟器，不能代替真实设备权限证据。
2. **部分授权及缩减（F005/F017）**：前置为支持有限照片选择器的 iOS26+ 设备，完整导入测试集。首次选择只允许两张照片，记录它们的测试文件对应 ID；预期 App 标示有限范围且不展示其余内容。打开系统管理选择器增加一张，再撤销当前回顾项访问后返回 App；预期可更新可见范围、保留待核对意图，不把消失解释为本次已删除。证据包含每步授权截图、可见 ID 集、会话及待删记录前后值。无法操控真实选择器时记未执行，fake 只补单测。
3. **真实 iCloud 未下载资源（F006/F007）**：前置为自愿提供的测试 Apple ID、开启 iCloud Photos/优化储存的真实 iPhone、网络可控，且 App 媒体功能已接入。从另一设备向该测试账户上传可丢弃照片和视频，等待元数据在目标机可见；通过公开 PhotoKit 禁止网络请求时返回的云端状态确认资源尚未本地可用，不能仅凭缩略图猜测。开启网络后在 App 打开该项，预期显示加载进度并成功播放/显示；记录 asset ID、网络开关、请求选项、云端状态、回调时间线与屏幕录制。若系统已自动下载，换新素材重试；仍无法制造则未执行，不能用本地图片冒充。
4. **云端离线、取消和重试（F006/F007）**：延续第3步已确认未下载的新素材，先关闭 Wi-Fi 与蜂窝网络，再打开。预期可区分离线/资源不可用，不显示成功；切到另一项后，迟到的回调不得替换当前媒体。恢复网络并显式重试，预期新请求成功且旧请求不会改变当前项。记录断网前云端证据、屏幕录制、请求代次及取消/错误/重试回调；单纯注入错误只算适配单测。
5. **收藏、取消删除和受控删除（F011/F016/F018）**：前置为仅含可丢弃 fixture 的隔离图库，确认每个目标的 ID 和同组保留项，业务功能已实现。收藏一张后在系统照片核对收藏事实；标记待删时预期系统原片仍存在；进入复核先取消，再重新确认固定集合，若系统弹出确认则先取消并核对原片。最后仅对指定 fixture 同意删除，预期按系统批次回执更新，保留项仍在，系统最近删除可见被删项。证据包括固定目标清单、App/系统前后画面、真实回执和本地操作记录。绝不在个人图库批量执行或清空最近删除。
6. **iCloud 同步影响与真机性能（F018）**：前置为上述测试账户及两台自愿测试设备。第5步删除后在另一设备检查同一测试内容同步变化，记录同步等待时间，不承诺立即同步。冷/热加载各测固定路径，记录图库规模、缓存状态、设备型号/OS、加载时间、滑动与内存峰值；动态字体、减弱透明度和 VoiceOver 分别走回顾/比较/复核。无第二设备、iCloud账户或签名团队时逐项写明未执行。

测试账户登录、签名团队和设备由用户提供；脚本不处理 Apple ID 密码，不改变个人 iCloud 设置。数据删除仅限上述明确的可丢弃素材。执行协议发现问题时回到对应 Feature，不能靠调整完成状态掩盖缺口。

### F005 权限与范围证据边界

iOS26.5 公开 SDK `PHFetchOptions.includeHiddenAssets=false` 与 `.includeAssetSourceTypes=.typeUserLibrary` 排除隐藏项目及 CloudShared 类型的共享相簿；这些字段**不证明**排除了 iCloud Shared Photo Library。检查 PHAsset/PHFetchOptions/PhotosTypes 公开头文件未发现可靠的共享图库成员标识，`LibrarySnapshot.sharedLibraryMembershipVerified` 因而明确为 false。首版共享图库能力尚未完成；使用共享图库的账户不得用于当前验收或后续删除流程。用户范围选择待确认，F016 不得把此状态当成安全删除授权。

权限映射包括 notDetermined/restricted/denied/limited/authorized/unknown，读取统一使用 `.readWrite`，不使用会把 limited 当 authorized 的旧接口。系统查询只在可读权限下执行；返回 Sendable 元信息而非跨 actor 的 PHAsset，日期相同以资产ID排序。空有限范围只说所选内容为空，不说整个图库为空。授权变化和用户管理选择后重新读取系统状态。

真实弹窗验证通过 XCTest 重置**当前测试 App**的照片权限并点击系统允许/拒绝按钮；只在隔离模拟器执行。受设备管理限制的 restricted 状态当前仅映射单测，未伪造真实受管设备。真实有限授权测试选取网格项目并断言 App 查询数量随选择改变。

发现 CoreSimulator 对无签名 UI runner 复用旧测试二进制，恢复脚本在测试前只卸载本项目 `dev.armstrong.swipego.uitests.xctrunner`，保留 App 状态与图库。测试日志必须确认实际执行测试项，零项运行不算通过。

F005 后续修正：仅卸载 runner 仍不足以保证完整运行更新 App 二进制；恢复命令改为 simulator 本地 ad-hoc 签名（无需证书/团队），实际完整运行的全部权限测试通过。该变化不提供任何真机签名能力。

### F007 真实视频视图回归

Debug 启动参数 `--video-test-host` 仅用于本地测试，正常启动不进入该页。VideoTests 使用系统完整授权弹窗和图库中的可丢弃视频，操作实际 VideoReviewView：静音自动播放事件、暂停/声音按钮、真实 AVPlayer currentTime 的 seek 完成、媒体拖动计数与 Slider 隔离、会话替换的旧播放器释放、Home/activate 后释放计数、关闭/重开。

短素材只有2秒，不以“测试取快照时仍在播放”作为自动播放的唯一证据；记录实际播放事件，并由 AVPlayer 单元测试断言时间前进。宿主按钮固定布局，避免媒体消失时 XCTest 坐标过期导致漏点。每个可见会话有自己的播放器所有权；测试保留已退出控制器引用仅用于观察其 player 已清空。失败截图/录像位于 XCTest result bundle。该本地证据不覆盖真机音频、iCloud 或后续 F010 全部照片手势组合。

### F009 首页与辅助功能回归

HomeTests走真实授权、随机片段、媒体入口、进程重开及继续；PermissionTests通过真实首页设置管理范围，并在空的有限图库验证去年的今天空态。普通/减弱透明度渲染执行XCTest辅助功能审计：hitRegion、sufficientElementDescription、textClipped，未过滤审计问题。最大辅助字号采用纵排卡片并实际进入回顾。

本轮真实失败与修复：SwiftUI副标题连续报告文字边界问题，改用原生动态字号多行UILabel按可用宽度测量后审计通过。图库照片的scaledToFill内容曾在视觉裁切区域之外截获设置按钮点击；XCTest事件坐标与录像证明点击坐标正确而进入了回顾。最终为卡片设contentShape并让装饰图片/边框不接收触摸，普通及实色降级下设置导航都通过。不能只凭截图认定按钮可用。

`--reduced-transparency-test`只在DEBUG使GlassPanel走与系统偏好相同的实色分支，属于受控偏好渲染验证；没有宣称切换真实系统设置或完成真机VoiceOver测试。后者仍属于F018。

### F010 沉浸与手势回归

ReviewGestureTests验证轴锁定、阈值、模糊对角线、重复结束只提交一次、绑定原资产、变更/缩放取消及空闲取消后下一次拖动仍可用。ReviewTests实际操作Photos素材：默认控件隐藏，上部点按后底部返回按钮位于屏幕下半；左右切换，竖直动作绑定原资产且不前进，按钮等价意图，按钮放大和真实双指pinch后拖动不翻页/标记，还原后恢复滑动；进入真实视频后调整Slider不产生照片动作。测试HUD仅在DEBUG独立测试入口记录意图，没有模拟成功回执。

HomeTests从正常App首页进入、展开底部控件并重开继续，保留真实产品截图F010-review-controls.png。播放器单独生命周期覆盖继续保留。F011/F012接入前，上下动作不触发图库/待删存储，不展示成功。

### F011 收藏验证边界

FavoriteTests使用真实临时SwiftData存储验证重复收藏、撤销原目标、实际只读存储失败不触碰系统writer；受控writer验证外部版本变化和系统取消；受控完成日志保存失败验证submitted证据保留。NativeFavoriteWriter测试只在模拟器对生成的landscape.jpg执行真实收藏、重复收藏、撤销、另一原生写入后拒绝撤销，恢复原始收藏值。

FavoriteUITests使用DEBUG隔离存储和明确生成的landscape.jpg/portrait-smile.jpg，真实系统授权后下滑收藏、重复按钮收藏、翻页后撤销第一项，并检查图库快照与游标。该入口在测试前重置这两张可丢弃素材的收藏值；正常App不走测试入口。真实iCloud同步与硬件验证仍在F018。

### F012 待删验证

PendingTests使用真实临时SwiftData验证重复标记、磁盘重开、原目标撤销、已收藏的确认门槛、只读磁盘写失败不公布成功及替换记录保护。PhotoAssetReading测试记录证明这些流程未调用系统写入。PendingUITests在生成素材上走真实收藏、取消/确认收藏项待删提示、进程重开、翻页后撤销；测试宿主可保留专用Caches数据库验证重启，不读取或重建产品数据库。没有系统删除调用。

F012首次UI回归发现系统confirmationDialog把提示呈现为popover并省略cancel按钮；失败附件的真实可访问性树只含“仍加入待删”。改为双按钮原生alert以明确提供取消，保留原有完整测试断言；针对复现的PendingUITests复验通过（.build/F012-pending-retry.xcresult）。失败记录保留在.build/test-run.cxXyTN。

## F013 Vision 真机必需验证

本机 iOS26.0/26.5 模拟器的原生特征计算曾把不同图片输出为近乎相同向量。模拟器测试验证 PhotoKit 读取与运行时拒绝路径；质量正反例编译到真机测试中，不能用模拟器通过替代。2026-09-28用户明确要求断开手机继续开发。根 `./init.sh` 默认完整模拟器验证并输出 `DEVICE_VERIFICATION_DEFERRED`；`SWIPE_VERIFICATION_MODE=device ./init.sh` 在模拟器完整测试之后强制执行 `scripts/verify-device-vision.sh`，没有真机配置、连接、签名或测试失败均非零退出，不使用历史收据代替本次执行。F018仍要求真实设备/iCloud证据。

配置免费 Personal Team 即可，无需购买开发者计划。在 Xcode 登录并创建 Apple Development 证书，选择自己的团队配置自动签名，把 iPhone 连接、配对、开启开发者模式，并在设备“设置 > 通用 > VPN与设备管理”信任开发者 App。首次 profile 可由 Xcode 自动管理；脚本本身不注册账户或购买服务。设置 `SWIPE_DEVICE_UDID` 和 `SWIPE_DEVELOPMENT_TEAM`，或者在忽略的 `.build/device-test.json` 保存 `{"udid":"你的物理设备UDID","team":"10位团队ID"}`。不要提交设备/账户配置或私钥。

真机脚本只运行 `testBundledVisionNegativeControl` 和 `testBundledProductionVisionPipeline`：生成素材随 XCTest 打包，验证 Vision 原生距离、产品归一化/健康检查/归档路径及完整分组、缓存重算一致性。不读写个人图库，不运行收藏、删除或权限 UI 测试。每次保存独立 xcresult 和日志；仍需 F018 补充真实图库/iCloud/性能验收。

2026-09-28 iPhone12 Pro / iOS26.6.2：原生 exact=0、expression=0.3276948、unrelated=0.18718757；产品512px路径 exact=0、near=0.038620003、expression=0.37500426、unrelated=0.5411682。阈值0.12只基于此小型合成正反例集作保守分组，不是相似概率或真实照片泛化保证，最终必须人工比较。

## F014 比较验证

ComparisonTests使用真实磁盘SwiftData：多项保留/重开后上下文、全部保留撤回、空保留/收藏/资产变化拒绝、只读保存失败保持旧记录、旧JSON兼容。ComparisonUITests在模拟器生成素材上验证缩放、多选、零保留禁用、保存、跳过和全部保留；不声称这证明模拟器Vision可用。实际UI截图为docs/design/F014-comparison.png。比较素材仅为程序绘制的山景，不是用户照片。

## F015 复核验证

DeletionReviewTests验证不可访问目标/保留项保持原记录、保留冲突禁止确认、撤回原记录匹配和固定清单不吸收新增意图。DeletionReviewUITests使用模拟器生成素材及独立临时store，验证首页真实计数、同组保留对照、视频播放、撤回缺失标记、固定确认清单、取消返回及计数更新。测试只修改本地意图，不删除Photos素材。XCTest保留复核页及最终确认页截图附件。

## F016：模拟器真实删除边界

DeletionTests覆盖整批成功与原子清理、后来意图保留、重复/并发点击、权限与保留项变化、取消/未知回执、成功后日志失败以及旧JSON。DeletionUITests通过仅模拟器Debug入口现场创建3张纯色可丢弃图片，先取消，再重新复核并通过系统弹窗删除2张，检查保留1张和本地回执。禁止在个人真机自动运行该入口。系统行为证据是实际PhotoKit/UI；模拟writer只证明故障状态机。真机/iCloud行为仍在F018补齐。

## F017：恢复与变更验证

ReconciliationTests使用真实磁盘存储模拟submitted阶段中断并重新打开，检查缺失资产保留待删、未知操作阻止重新提交、用户核对不冒充成功、真实只读保存失败保留提示、运行中操作排除与迟到核对CAS保护。真实PhotoKit fixture收藏切换触发LibraryAccessModel通知，并恢复原值；会话权限缩减仍保留原ID。既有SimilarityTests覆盖修改版本缓存失效/取消迟到结果。ReconciliationUITests使用唯一临时测试存储，跨两次App重启验证未知提示、当前可见事实、结束提示的持久化与待删计数不变；不调用系统删除。完整回归仍包含F016的真实生成素材取消/删除。F018补齐真正杀进程与系统回执窗口、跨设备iCloud、真机权限和性能体验。

## 手动验收后的紧凑首页矩阵（F009）

默认恢复模拟器之外，必须运行 `scripts/verify-compact-home.sh`。它选择专用 SwipeGo iPhone SE3 / iOS26+ 模拟器，或接受 `SWIPE_COMPACT_SIMULATOR_UDID`；会校验设备类型，不用大屏替代。保留 HomeTests 的正常/减弱透明度完整无过滤审计、首屏待删卡框断言和辅助字号导航。每轮结果保留 `.build/compact-home.*/Tests.xcresult`。

首次配置：使用 `xcrun simctl list -j` 的真实可用 runtime，创建名为 `SwipeGo compact home` 的 `com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation`；`bootstatus <id> -b` 后只导入 `Fixtures/generated/*.jpg` 和 `Fixtures/generated/clip.mp4`。当前独立Evaluator已创建并保留对应设备（ID见F009 evaluation run）。不擦除现有图库，不在个人手机运行该脚本。

2026-09-28 F019 manual acceptance repair: `ReviewTapTests` exercises top, bottom,
left, right and center on both photo and video media (including black bars),
checks the cursor remains unchanged, video frame remains the same with controls,
and explicit playback/mute/slider interaction does not dismiss the toolbar.
Paused playback remains paused across two media taps. `ReviewTests` retains
pinch/pan versus action-routing coverage; all callers now tap the actual media.
Screenshot: `docs/design/F019-video-overlay.png`. Earlier F019 attempts caught
identifier propagation and undersized video button hit regions; the assertions
were retained, and production buttons now have explicit 44-point hit areas.

2026-09-28 F020 rotation verification: `ReviewOrientationTests` enters the real
HomeView full-screen route, rotates both ways for photo/video, verifies cursor,
fit reset, reachable controls, paused playback, slider isolation, home portrait
restoration and resuming the same item. Largest accessibility type uses the
scrolling toolbar with bounded height. The test restores simulator orientation
in `defer`. Capture landscape using `XCUIScreen.main.screenshot()`; XCUITest's
App-only crop was incorrect under the rotated coordinate system (original
attempt remains in `.build/F020-orientation.xcresult`). Correct whole-screen
captures are `docs/design/F020-photo-3.png`, `F020-video-4.png` and
`F020-accessibility-landscape.png`.

A dedicated iPhone SE3 simulator also runs these two tests. Use the compact
simulator from the F009 matrix and import only generated `landscape.jpg`,
`clip.mp4` and `portrait-smile.jpg` via `simctl addmedia` if absent; never import
fixtures into a personal device. Run `xcodebuild test` with that simulator ID and
`-only-testing:SwipeGoUITests/ReviewOrientationTests` and a fresh result bundle.
Final evidence: `.build/F020-compact-final.xcresult` (including zoom/tap interaction). Rotation-lock behavior on physical
hardware remains an F018 check; production does not force landscape or mutate
UIDevice orientation. It only permits both landscape orientations during review
and requests portrait when returning home. Rotating resets zoom/pan to fit while
preserving the session and original media.

### Simulator permission recovery

Root recovery builds the simulator test host, then executes the existing native full-access UI case as an explicit setup phase (`PermissionSetup.xcresult`) before the full unit/UI suite. That case resets authorization, clicks the real system full-access button and verifies the App has queried the library. It restores the integration-test precondition after a denied-access run. The full native denial/full/limited matrix still runs later. Only the simulator selected from validated simctl inventory is targeted; no app/library erase or personal-device permission change occurs.

A real probe found `simctl privacy grant photos` returned success but PhotoKit `.readWrite` remained notDetermined on this iOS26.5 runtime, even with photos-add. It is not used as the recovery proof. See F025 diagnostic records for raw failed probes and native setup verification.

Recovery also clean-boots only the selected simulator before tests. After interrupted XCTest sessions, four independent rotation cases stopped receiving orientation changes; the exact unchanged app/test build passed those cases after a simulator restart. No simulator erase or app uninstall is used. Run this recovery serially, not alongside another suite on the same destination.

## 独立评估进程时限

`.agent-harness/agent-provider.json` 保留现有provider、cwd与原命令，在`evaluator_command`前添加`["python3", "scripts/run-bounded-evaluator.py", "--timeout-seconds", "2400", "--"]`；runtime_check_command同样包装但使用120秒。provider cwd仍为项目根目录`..`。该本地配置按既有规则不提交，重新配置provider时保留此包装；不要替换用户已有model/参数。包装器透明转交stdin和输出、保留退出码；超时退出124并终止其子进程组，不输出伪造验收结论。故障属于本轮F031实际长期等待后的运行改进。

进程组清理由 `scripts/process_cleanup.py` 统一处理：不能将leader退出视为后代退出；短暂TERM宽限后仍对所拥有的进程组执行KILL。真实心跳回归覆盖忽略TERM的后代，包含timeout、外部中断和验证Runner三条路径。


## R25 剩余计数回归

F032将剩余定义为当前之后的本轮非待删项，当前项不计入；末页/单项显示“剩余 0 项”，不因此设置completed。ReviewSessionTests覆盖前后导航和磁盘恢复，PendingAdvanceTests及原生Pending/HomeNavigation/ReviewContinuity用例覆盖待删、撤销和边界。共享领域变更在现有verify.sh映射中回退full，无需缩减映射；首页继续卡沿用相同计数。


## R27 随机预览回归

F034在HomeModel保存预选片段，封面候选和打开共用assetIDs。HomeRandomPreviewTests覆盖打开/返回换段、普通刷新及其他入口保持、元数据更新、权限缩减、白名单、空库/单项视频、真实只读保存失败与固定种子稀疏替代。HomeNavigationTests新增真实首页→继续返回保持→随机打开对应片段→返回换段用例；仅DEBUG --random-preview-test下暴露模型ID作为可访问性value，使用4个生成媒体构成两个片段。现有首页映射已包含HomeNavigationTests；ReviewTimeline共享领域修改仍自动选择full，未缩小验证范围。
