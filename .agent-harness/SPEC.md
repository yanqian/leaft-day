# Swipe-go — 第一版需求规格

## Development agreement

遵循 [Agent 规则](AGENTS.md)、[质量标准](QUALITY.md)、[规范化](docs/spec-normalization.md)、[功能拆分](docs/feature-decomposition.md)和[项目恢复](docs/project-recovery-init.md)。本文件是产品需求的唯一规范来源；架构与路线图是其派生文档。

## Planning status

2026-09-26。用户已确认视觉方向、以回顾为主的定位、iPhone / iOS 26、连续时间片段回顾，并同意按此前架构整理规划。这构成第一版范围基线，不代表每项建议细节已获得单独确认。用户随后授权产品实现，并要求 work-fast 逐项独立验收、提交后继续。

已确认图：[`docs/design/ui-approved-liquid-glass-v1.png`](../docs/design/ui-approved-liquid-glass-v1.png)。早期截图中的首页「顺手整理」、整理标签栏、顶部功能面板均已被后续要求取代。图片中的人物、日期、数值和旅行标题为示例，不是实际数据或算法能力承诺。

## Goal

让用户愿意打开自己的照片和视频，回顾一段连续生活；在浏览中轻松收藏、标记冗余内容，并通过可理解、可撤销的人工复核降低误删风险。首页和成功指标均以回顾体验为主，不以删除量或空间释放量驱动。

## Scope included

- R01 平台：仅 iPhone，最低 iOS 26；SwiftUI 与原生 Liquid Glass；首版中文界面。
- R02 首页：继续回顾、去年的今天、随机时光；待删记录为低强调辅助入口，不展示「顺手整理」、大视频清理或清理排行榜。
- R03 连续片段：按拍摄日期/时间间隔选取片段；片段内时间顺序稳定，照片与视频混排；保存会话和当前位置。
- R04 沉浸回顾：默认隐藏应用控件，只展示媒体；左滑下一项、右滑上一项，上滑加入待删、下滑收藏。点按上部安全区域显示/收起底部功能栏，功能栏含收藏、待删、相似、撤销以及返回入口。顶部触发区本身不执行删除或收藏。
- R05 媒体：浏览照片、播放视频；支持云端资源加载、取消、失败和离线状态；Live Photo 至少静态展示，不破坏其资源。
- R06 收藏：建议与系统照片收藏保持一致；只有系统变更成功才显示成功，可解释错误并恢复 UI。
- R07 待删：上滑和按钮只写本地标记；持久化、去重、撤销；不可在滑动时提交实际删除。
- R08 相似照片：设备端渐进分析、候选分组；用户多选保留、放大比较、全部保留或跳过；建议不自动改变图库。
- R09 复核：按组展示待删项与保留项；支持撤回、退出稍后处理；待删数以仍有效的记录为准。
- R10 删除：用户明确确认后再校验权限/资源/保留项，通过系统请求删除；取消、失败、未知结果分开处理；重启核对未完成操作，不自动重试未知删除。
- R11 本地优先：原片归系统管理，App 保存进度、意图和可重建缓存；无自建后端、额外账号或云端 AI；系统 iCloud 照片同步照常工作。

## Scope excluded

第一版不做 Android、iPad/Mac 专用布局、纯网页版本、App 进度跨设备同步、云端图像上传/LLM、自动删除、图片/视频压缩、永久备份服务、全图库视频内容去重、自动剪辑回忆影片、订阅收费或 App Store 上架。也不直接读写 Photos 私有数据库或使用私有 iCloud 接口。不承诺一次扫描找全所有重复项，不依据封面认定视频重复。

## Core flows

1. 权限引导 → 在已授权范围读取资产元信息 → 首页可用；部分授权不是错误，不可把有限可见范围当作完整图库。
2. 继续/去年的今天/随机时光 → 创建或恢复有序会话 → 请求当前内容与邻近预取 → 滑动浏览 → 持久化游标。
3. 上滑 → 捕获当前资产标识 → 写入待删记录 → 显示短暂可撤销反馈；写入失败不显示成功。左右滑动只表示浏览，不等于已保留或已整理。
4. 下滑 → 发起系统收藏 → 成功后反馈；失败保持/恢复原状态。撤销绑定原资产而不是撤销发生时屏幕上的资产。
5. 底部相似入口 → 显示相关候选组 → 多选保留或跳过 → 明确操作后将其余项目加入待删。分析未完成允许继续回顾。
6. 待删入口 → 分组复核 → 确认固定资产集合 → 再校验 → 系统变更 → 记录结果。集合或权限变化时要求重新复核；任何时候不把缺失资产直接解释为本次删除成功。

## Constraints

- 原片只由系统图库管理；不复制全库到 App 沙盒。临时媒体与特征缓存设预算并可逐出。
- 不依赖后台调度完成才能打开回顾；重分析不在 UI 主执行路径进行，任务限并发且可取消/恢复。
- 图库是照片/收藏的事实来源，本地数据库是回顾进度/待删意图的事实来源；两者无跨系统事务。
- 系统图库变更和权限调整需要重新核对；照片编辑需使旧特征失效。
- 清晰区分收藏、看过、建议保留、待删、提交删除与系统执行结果，不用一个枚举互相覆盖这些独立维度。
- 用户复核与系统授权不可绕过；iCloud 同步删除需在确认界面说明。恢复受系统「最近删除」规则限制，不承诺永久找回，不自动清空最近删除。
- 不把媒体原始大小、候选大小或待删总量显示成已释放手机空间。
- 原生玻璃效果统一封装；减弱透明度、减弱动态效果、动态字体与 VoiceOver 有可操作替代，不能只靠手势。

## Ambiguities or assumptions

以下是**建议默认值，尚非用户逐项确认**。相关 Feature 实施前回顾这些假设，变化时同步 SPEC 与验收，不静默扩展范围。

| ID | 建议默认值 | 影响 |
|---|---|---|
| A01 | 收藏后仍停留；v4/R16已替代待删后停留规则：耐久标记后退场并自动下一项，末尾完成，可撤销。重复标记不累加，下滑不取消收藏 | F010–F012/F023 |
| A02 | 视频进入后静音播放，点击画面中部播放/暂停；控件展开时显示进度/声音；切出立即停止；具体与手势冲突用原型验证 | F007/F010 |
| A03 | 照片按原比例完整显示，必要时留深色背景；用户可放大；不为铺满屏幕默认裁掉画面 | F006/F010 |
| A04 | 日期分组起步，同一天内明显时间间隔再切段；会话不强制固定张数；阈值通过 fixture 和真实自愿样本调整 | F008 |
| A05 | 去年的今天严格取上一年同月日；无内容显示空态，不偷偷替换为其他日期；闰日规则需在实现时明确 | F008/F009 |
| A06 | 已收藏照片不默认建议待删；用户显式标记收藏项时增加提示；不自动取消收藏 | F012–F015 |
| A07 | 首版相似检测聚焦当前/邻近回顾片段，跨日期导入重复检测后置；建议保留只有经过验证的理由，否则只分组不伪造清晰度/表情解释 | F013/F014 |
| A08 | 隐藏照片、共享图库、他人共享内容不纳入首版；需用公开 API 验证可识别范围，无法区分时记录能力缺口，不能伪称已排除 | F005/F016 |
| A09 | 第一版 Live Photo 以静态照片浏览；图稿「那次海边旅行」是示例，实际无可信标题时用日期，不生成虚构事件名 | F007/F009 |

Bundle ID、签名团队、分发方式与真实测试样本来源未定；不阻塞规划和无签名模拟器构建，阻塞对应真机/分发验收。阈值与缓存容量是实现阶段的可调参数，性能未实测。

## Required capabilities

- Full Xcode、iOS 26 或更高 SDK、可运行的 iOS 26+ 模拟器及 Python/Go 等 Harness 依赖。上次检查仅激活 CommandLineTools，不能声称 iOS 环境已就绪。
- PhotoKit read/write 授权与授权说明；真机 iCloud 下载、系统收藏/删除行为的证据；测试删除仅使用可丢弃测试图库素材。
- SwiftUI / PhotoKit / AVKit / Vision / SwiftData；第一版不引入远端 AI 或服务凭据。
- 可重复安装的非私人媒体 fixture：照片、视频、相似但值得保留的反例、不同尺寸、日期空档、云端不可用替身。替身不证明真实 iCloud/授权行为。
- 明确 Codex provider：用户指定的桌面二进制和 gpt-6-astra；隐藏布局 cwd=..。历史验证不代表本项目 runtime 验证。

## Implementation paths

计划路径，尚未创建产品工程：`SwipeGo/`（App/UI/Features/Domain/Infrastructure）、`SwipeGoTests/`、`SwipeGoUITests/`、`Fixtures/`、`scripts/`、`SwipeGo.xcodeproj/`。产品文档放 `docs/`，状态放 `.agent-harness/`。不改造 Harness examples 来冒充产品。

## Verification surface

详见 [验证方案](../docs/verification.md)。领域单测覆盖会话选择、标记与撤销、删除快照/恢复；适配测试覆盖权限、过期结果、缓存和图库变更；UI 测试覆盖手势/控件/复核；真实模拟器及真机验证系统 API 行为。性能证据须包含设备/OS/图库规模/缓存状态，不以 mock 或设计图声称通过。

F002 将根 `./init.sh` 改为幂等工程恢复入口：验证依赖、启动测试模拟器、构建 App、执行真实 smoke、分阶段日志、失败非零；不要求预先手动启动服务。当前入口仍只验证 Harness，此差距已规划而未完成。

## Feature decomposition

见 [路线图](../docs/roadmap.md) 和 [任务状态](feature_list.json)。从 F001 编号，按工具链、恢复、fixtures、持久化、授权、媒体、会话、交互、系统副作用分别拆分。删除复核、执行和崩溃恢复分别可验收，因此不合并。每项最多五条验收，列出依赖、实施路径与验证面；当前完成状态以 feature_list.json 和独立验收记录为准。

## 2026-09-27 用户批准：集中真机与 iCloud 验收

- Goal：允许持续开发，同时把只能通过真实设备/账户证明的行为集中到 F018，保持证据真实。
- Scope included：F006–F017 保留代码、状态机、故障分支、真实本地模拟器和对应 UI 验收；真实真机/iCloud 未下载、离线、同步、Live Photo 及设备性能证据由 F018 统一收集。
- Scope excluded：不把模拟器或 fake 结果称为真机/iCloud 成功，不免除 F018，不更改人工确认删除、安全范围或隐私约束。
- Core flows：每项当前会话实施 → 独立 Evaluator 检查本项实现与适用模拟器证据 → 通过后提交 → 下一项；F018 补齐设备协议并回归前项，失败回到对应 Feature 修复。
- Constraints：每个 Feature 仍独立验收和提交；F018 未通过前不能声称全部功能验收完成或真实云端可靠。未提供设备时只报告缺口。
- Assumptions：用户“可以，继续”明确批准上一条建议。共享图库范围问题不是本次批准的内容，仍记录未支持能力。
- Required capabilities：当前使用 Full Xcode、模拟器及可丢弃素材；F018 需用户提供设备、签名团队和测试 iCloud 账户/素材。
- Implementation paths：既有 SwipeGo/、tests 与对应文档；feature_list.json 调整验收归属，docs/deferred-device-verification.md 跟踪未执行项。
- Verification surface：前项本地真实测试 + 受控失败测试明确区分；F018 按 docs/verification.md 真实系统矩阵取证，不允许以本地替代。


## 2026-09-28 个人图库范围确认

用户在解释“与家人共用、彼此可增删的iCloud共享照片图库”后明确回答“没有”。当前验收按个人图库执行，首版可继续实现人工复核后的实际删除。仍不支持共享照片图库，不能宣称公开API已自动排除其成员；产品在实际删除前明确个人图库适用范围。该确认不授权自动删除用户私人照片，测试只用明确可丢弃素材，系统确认和恢复边界仍保留。


## 2026-09-28：手机断开期间的验证范围

用户明确要求拔掉手机后先完成不需要手机的功能。默认 `./init.sh`（或 `SWIPE_VERIFICATION_MODE=simulator ./init.sh`）运行完整 Harness、Python、模拟器单元/UI 和启动验证，并明确输出 DEVICE_VERIFICATION_DEFERRED。`SWIPE_VERIFICATION_MODE=device ./init.sh` 另外强制运行两项真机内置 Vision 控制测试；缺少设备必须失败，不自动降级。此调整不更改 F018 验收标准，也不把模拟器 Vision 异常或历史真机通过当成当前真机证据。F015–F017可继续独立Evaluator验收和提交，F018的真实设备、iCloud、性能与体验仍须连接后补齐。

断开前曾有真机内置 Vision 通过记录；这仅覆盖生成图算法控制，不覆盖上表。2026-09-28 F015完整模拟器回归46 XCTest/14 XCUITest通过，随后真机步骤因设备断开退出失败（/private/tmp/swipe-F015-final-gate.log）；保留该失败，不称完整命令通过。

## 2026-09-28：手动验收修复与全画面/横屏浏览（用户已确认）

- Goal：实现已确认的液态玻璃视觉与可用的沉浸浏览，修复首页截断/占位与翻页问题。用户已确认 docs/design/ui-manual-review-v2-proposal.png；详见 docs/design/manual-review-v2.md。
- Scope included：F009恢复照片氛围背景与统一玻璃、低矮待删横卡、适配首屏；封面仅所属片段照片，区分加载状态、有限候选回退，无照片专用空态。F010修复真实入口照片/视频左右滑动与首尾反馈。R12全画面（含黑边）点按显隐控件，视频播放按钮独立。R13浏览页跟随左右横屏，保持当前资产/游标与完整比例、控件可达，首页竖屏。
- Scope excluded：不新增清理榜单、自动删除、整库下载、远端AI；不改变时间片段、收藏/待删/删除事实；不把静态图当运行证据，不将视频排除出回顾。
- Core flows：首页首屏可见待删卡→照片封面进入有序回顾→左右翻页→任意非控件画面点按显隐→控件执行原动作→转动手机仍停留原资产→返回首页竖屏。
- Constraints：iPhone/iOS26；公开PhotoKit/SwiftUI/UIKit；默认fit而非fill浏览；控件/缩放/滑杆优先于媒体手势；封面请求可取消并设候选数量与尺寸上限，不整库重试。减少透明度、动态字体、VoiceOver可用。保护现存F018资产白名单和未提交改动。
- Ambiguities or assumptions：横屏适用回顾中的照片与视频；比较/复核保持现有流程不独立设计新横屏。缩放后拖动平移，恢复原比例后左右翻页。首尾不循环，短暂反馈。纯视频片段显示无照片封面说明，仍可进入播放。系统旋转锁定不由App绕过。
- Required capabilities：现有Xcode/模拟器、合成可丢弃fixture、XCTest/XCUITest、独立Evaluator；真机/iCloud差异仍归F018，缺少设备不冒充实测。
- Implementation paths：SwipeGo/DesignSystem、Features/Home、Features/Review、Infrastructure/Media、App（方向策略）、project.yml、SwipeGoTests、SwipeGoUITests、docs/design、docs/verification.md；只在.agent-harness保留规范/状态/运行证据。
- Verification surface：首页常规/紧凑尺寸与辅助字号截图、无照片/错误封面、封面候选取消及上限单测；实际首页fullScreenCover照片/视频/黑边翻页与控件冲突UI测试；全画面点按测试；左右横屏尺寸/原资产/返回竖屏UI测试；root init及各项冷启动Evaluator。
- Decomposition：F009/F010为旧承诺缺陷，Human Eval重开原项，不新增repair项。新增F019（R12）只处理全画面显隐和视频点按语义，F020（R13）只处理方向与自适应，因可独立验收而拆分；F020依赖F019。F018保持未通过，调度回todo以便先修复人工反馈，不丢原证据。
- Supersession：本节R12明确替代R04“上部安全区域”及A02“点击画面中部播放/暂停”；新默认为媒体任意区域点按显隐，播放暂停在控件内。


## 2026-09-29 人工验收 v3（用户已批准统一玻璃稿）

- Goal：照片连续可看，操作层轻薄；复核以照片为主，删除后展示真实结果而非旧清单。
- Scope included：沉浸两条玻璃胶囊、顶部关闭与等价缩放入口；复核网格、说明披露、回执结果页；跨片段浏览与随机多张、周年日显式延伸。
- Scope excluded：不改相似算法、实际删除协议和系统最近删除；不宣称F018真机/iCloud验收完成；不裁切照片换取设计稿效果。
- Core flows：轻触显隐→上条左右翻页/中央日期和数量→下条四动作；待删→首次说明/后续展开→缩略图撤回与保留对照→固定清单→系统确认→真实结果/记录。成功替换旧清单；取消/未知保留意图并明确说明。
- Constraints：保留公开系统确认、精确批次CAS清除、新意图不清除、白名单scope、离线与权限状态。默认按原比例；横屏/减弱透明度/大字/VoiceOver仍可操作。照片仅有限本地缩略图作背景。
- Ambiguities or assumptions：用户批准docs/design/ui-manual-review-v3-unified-glass.png。回顾范围采用已说明的推荐规则：继续回顾可跨片段，随机优先多张，去年的今天严格当天并提供显式“继续看附近日期”。连续批次上限60项，按时间和ID稳定排序；单张随机片段扩展相邻时间资产至最多12项；不伪造同日范围。接续按时间向后，末尾可显式重新选择更早片段，不自动循环；老会话不重排已有ID。具体UI日期反映当前资产。
- Required capabilities：现有Xcode/iOS26模拟器、生成fixture、配置的独立Evaluator；真实删除测试仅现场生成素材。无需新增权限或私有API。
- Implementation paths：SwipeGo/DesignSystem、Features/Review、Features/DeletionReview、Features/Home、Domain/Review及对应Tests/UITests、docs/design。
- Verification surface：目标回归及root ./init.sh，实际截图（深浅媒体/黑边/辅助字体/横屏/不透明），真实生成资产取消/成功删除、成功后无旧清单及剩余意图；确定性时间范围与存储恢复测试。
- Decomposition：原F009玻璃承诺未满足，Human Eval重开，聚焦沉浸控件和共用材质；原F015复核清单状态与可理解性不足，重开处理复核网格/说明/结果，F016删除协议不变；新F021扩展F008原2小时片段导航，独立验证时间排序/批次和入口。每轮只实现一个特性，自动通过不等于用户真机认可。

### R14 implementation clarifications before F021 coding

- No saved session: Continue opens the most recent at-most-60 accessible assets in chronological order, starting at the beginning of that batch. At the end of a continuous session, append at most 60 subsequent IDs; do not discard/reorder existing IDs or automatically wrap. This bounds each fetch/navigation batch, not the durable history of already appended metadata IDs. Media requests remain current plus bounded neighbors.
- A legacy session without origin metadata is upgraded to continuous only when opened from Home Continue, preserving its ID list and cursor. New sessions persist continuous/anniversary/segment mode as an optional backward-compatible payload field.
- Random prefers a multi-item segment (at most60); if every segment is single-item, choose an anchor and up to12 neighboring accessible assets in stable time order. Unknown dates remain explicitly unknown. Titles reflect the true start/end dates.
- At an anniversary end, or a continuous end with other earlier assets outside the current session, show an explicit nearby-dates action. It opens at most12 nearest chronological assets outside the current session as a new continuous session; it never silently broadens an anniversary day. Sparse libraries may have large date gaps, so the displayed date range is factual rather than a claimed event.
- A genuinely one-item accessible library gets an explicit one-item message; missing permission/assets remain unavailable states. Every extension operates only on ReviewSession's already scoped snapshot, including generated-device-test whitelists.


## 2026-09-29 人工验收 v4（设置与待删退场，用户已批准）

- Goal：设置融入既有玻璃视觉；待删成功后自然接续下一项，不停留在刚标记的照片。
- Scope included：R15设置照片氛围背景、权限玻璃卡、真实可回顾数量、折叠图库说明与完成；R16上滑及等价待删按钮成功后上移淡出、下一未待删项目、剩余和待删计数、末尾完成及撤销。
- Scope excluded：不在滑动时删除原片，不改变集中复核/系统确认，不改变收藏后停留；不实现新设置选项或扩大权限、不替代F018。
- Core flows：首页设置→真实授权/数量→按需说明→完成；上滑捕获原ID→耐久保存待删→短暂上移淡出→下一未待删项→更新计数；无下一项显示本轮完成，可撤销或返回回顾。失败留在原项；已收藏须先确认。
- Constraints：复用原生RecollectionGlass；当前/邻近媒体有界；普通浏览保持原比例。事务成功前不退场，转场期间防重复和路由冲突；撤销原ID；减少动态效果改淡入淡出，透明度/大字/VoiceOver可用；仅生成素材测试。
- Ambiguities or assumptions：用户批准docs/design/ui-manual-review-v4-approved.png。“本轮剩余”指当前会话从当前位置向后的非待删项，包含当前项；完成为0，不伪称已从系统图库删除。浏览仍保留原有有序ID以支持返回/撤销，导航跳过待删；新批次按R14接续，周年当天不隐式扩大。待删计数为可复核数量，不可访问项独立提示。撤销成功可回到原照片；末尾保持可达撤销。背景用已授权照片本地缩略图，无可用图使用既有渐变。
- Required capabilities：既有Xcode/iOS26模拟器、生成fixture、独立Evaluator和已配置真机签名；无新增服务、账户或私有API。
- Implementation paths：SwipeGo/Features/Permissions、DesignSystem、Features/Review、Features/Home、Domain/Review、Domain/LocalState、SwipeGoTests、SwipeGoUITests、docs/design。
- Verification surface：设置真实首页入口/展开关闭/辅助字号和不透明截图；保存失败/重复/末尾/撤销/恢复/白名单领域测试；真实上滑自动下一项及计数/完成/撤销UI；root init和独立Evaluator。
- Decomposition：F022设置为原F009外新增页面统一；F023待删自动接续明确替换原A01停留行为，是新交互要求，分别独立验收。原F009/F012保留完成历史。A01仅收藏后仍停留；待删遵循R16。


## 2026-09-29 人工验收 v5：删除记录玻璃（R17）

- Goal：删除记录页面沿用用户已确认的沉浸回顾/设置通透液态玻璃，替换浅色厚重卡片。
- Scope included：删除结果进入记录，深色氛围背景、紧凑玻璃记录卡、真实结果/数量/时间、固定完成按钮、空/错误/加载状态。
- Scope excluded：不改变删除执行/回执含义，不加载已删除原片、不导出数据库，不扩大F018。启动页面另作独立规范化。
- Core flows：结果页→查看删除记录→读取最近20条删除操作→清晰区分成功/取消/未提交/待核对→完成返回原结果。
- Constraints：使用共享RecollectionGlass与有界本地背景；不能把已不可见资产视为删除成功；大字体/减弱透明度/小屏可滚动操作；测试只用生成素材/隔离本地记录，不在私人图库执行测试删除。
- Ambiguities or assumptions：本次直接要求“也改成液态玻璃”授权复用已批准v4材质，不另创视觉方向。记录无可靠照片背景，采用与设置无图时一致的深色氛围渐变，不伪造已删除照片。
- Required capabilities：既有SwiftUI/iOS26、Xcode、生成fixture、独立Evaluator，无新增权限/服务。
- Implementation paths：SwipeGo/Features/DeletionReview、DesignSystem及项目自有UITests/测试宿主、docs/design。
- Verification surface：真实生成素材取消/成功后的记录入口/返回；隔离记录的全部状态/顺序/空态、小屏大字与减弱透明度截图审计，root init和独立验收。
- Decomposition：F024是删除记录的独立展示面，与F015复核执行/结果刷新及后续启动授权页面可分别验收，保持独立Feature。

### v5 visual approval and scope clarification

用户澄清“两个页面”是删除记录+首次照片授权页；同时指出首页次级卡片小、待删需垃圾桶且放最底、不要底部可回顾总数。用户查看docs/design/ui-manual-review-v5-approved.png后回复“继续”，授权实施。R17背景由已批准稿明确为内置海岸氛围图（生成素材，不读取已删除原片），记录卡与固定完成按钮按该稿实现。后续首页与首次授权各自独立验收，未要求新的系统启动页。F024沿用已取得交接，前次中断startup不计通过。

## 2026-09-29 v5 首次授权（R18）与首页对齐（R02修订）

- Goal：首次打开也具备批准稿的玻璃视觉；首页保持更大的次级照片卡和最底待删入口。
- Scope included：R18首次未授权/拒绝/受限引导使用内置海岸背景、玻璃照片符号、时光标题、准确权限说明与原生请求/设置按钮；R02首页hero与双卡比例、玻璃叠图文字、底部垃圾桶待删、移除全库总数。
- Scope excluded：不修改系统照片授权弹窗，不增加额外启动页、权限要求、图库读取范围；不改回顾筛选或删除协议，不更改设置页真实可回顾数量；F018继续未完成。
- Core flows：冷启动→读取现有授权→未授权显示引导→用户点击请求→原生授权→首页；拒绝后打开系统设置、回前台刷新；首页三入口沿用原数据→复核入口保持末项、未知操作和有限授权提示位于其前。
- Constraints：未授权背景仅内置素材；不能为样式读私人图片。显示可滚动大字与不透明替代；常规字号小屏首屏完整待删入口，卡片高度按可用空间自适应而非固定设计画布；所有按钮≥44pt。基线读取权限时可显示玻璃加载，避免已授权冷启动短暂闪现“允许访问”误导。
- Ambiguities or assumptions：用户已澄清共两页（历史+首次授权），加上首页共三页。v5图稿照片/日期仅示例；实际封面仍遵守所属片段照片和有限本地请求。大字号允许滚动，不能为首屏硬缩字体。首页删除总数统计不包括hero当前片段剩余数。
- Required capabilities：既有原生SwiftUI/PhotoKit、内置批准视觉素材、Xcode模拟器/独立Evaluator，无新网络或权限能力。
- Implementation paths：SwipeGo/Features/Permissions/LibraryAccessView.swift及新授权组件，DesignSystem；HomeView.swift与HomeArtwork；SwipeGoUITests/PermissionTests、HomeTests和目标视觉测试，docs/design。
- Verification surface：真实初始授权、拒绝、部分/完整授权流程原UI回归；首次授权截图/大字/不透明；首页标准小屏geometry、无home.scope、封面与真实入口回归；完整root与独立Evaluator。
- Decomposition：F025新增首次授权的独立视觉表面，F009原首页确认稿对齐为既有承诺修复，通过human-eval重开原Feature，不为未满足承诺另建修复Feature。与F024记录展示分别编码/验收。

## 2026-09-30 v8 全页面照片取色渐变与液态玻璃（用户批准并授权开发）

- Goal：全部应用自有页面使用照片主色自然渐变与通透玻璃；清新、低饱和、文字清晰，不再固定晚霞/海岸壁纸，也不以仅按钮用了玻璃替代整页一致性。
- Scope included：R19共享有界取色、默认渐变、玻璃信息/操作/状态组件；R20首页、首次授权、设置及状态；R09修订复核/确认/全部结果状态；R21删除记录与操作核对；R22相似比较、回顾完成/无会话/不可用与媒体预览控件一致性。入口清单见 docs/design/liquid-glass-audit-v6.md，最新方向见 docs/design/liquid-glass-photo-colors-v8.md 和 liquid-glass-v8-concept.png。v6/v7壁纸方向被本节替代。
- Scope excluded：不改变收藏、待删、删除/核对协议、资源权限、媒体fit与手势、连续会话选择、相似算法；不美化/仿造系统权限和删除弹窗；不新增背景整库下载、远程服务、视频封面提取。F018真机/iCloud未完成项继续pending，不自动调度、不执行私人图库删除。不提交或推送。
- Core flows：首页取当前hero封面的颜色→进入设置沿用统一浅色玻璃；未授权/无图/不可用使用默认渐变。待删首张可用照片取色→进入确认冻结颜色→系统回执→结果→记录保持配色，成功后不重新读删除原片。比较从当前组代表照片取色；回顾仍清晰原片和默认隐藏控件，完成/无资源时显示玻璃状态卡与适当渐变。
- Constraints：iOS26公开原生玻璃；取色最多64×64 sRGB样本与固定数量色桶，最多3颜色，低饱和提亮且给深色文字留对比；只用已有图像或单张本地缩略图（network=false），无可用照片/纯视频回退默认。异步请求失效保护、资源版本变化触发更新、销毁取消；取色结果仅少量颜色值，不长期持有原图、无磁盘原片缓存。动态字体、VoiceOver、44pt点击、减弱透明度、减少动态效果和横屏均有可用布局。
- Ambiguities or assumptions：以v8方向为批准基线，图稿数据均示意。默认全应用信息页为浅色渐变+深青文字，沉浸媒体控件仍根据深/亮画面保持对比。一次流程冻结色板，离开流程可丢弃；新页面有独立授权照片可另取色。未授权或无照片不显示伪造图库封面；视频背景取色不扩展媒体能力。现有深色背景验收由本节视觉规则替代，历史证据保留。
- Required capabilities：现有Xcode/iOS26模拟器、SwiftUI/CoreGraphics/PhotoKit、生成fixture、XCTest/XCUITest与已配置冷启动Evaluator。无需新网络能力或依赖。模拟器测试串行，完整root恢复及实际截图为验收证据；不把概念图或HTML当原生通过。
- Implementation paths：SwipeGo/DesignSystem、Features/Home、Permissions、DeletionReview、Reconciliation、Review、Comparison，以及SwipeGo/App测试宿主、SwipeGoTests、SwipeGoUITests、项目scripts与docs/design。Harness目录仅存规划/状态/运行证据。
- Verification surface：确定性冷暖/暗亮/透明/单色输入取色与可读性、旧结果/取消/无图/版本更新单测；真实页面入口、生成素材删除成功与取消、未知/错误分支、前后色板连续性UI与截图；小屏/辅助字号/减弱透明度/减少动态效果/横屏；每块独立Evaluator及最终root恢复。
- Decomposition：F026独立共享能力与材质；F027首页/权限页面同一进入应用与授权导航表面；原F015待删复核/确认/结果为旧承诺缺陷，依赖新材质后通过human-eval重开，不新建repair功能；F028操作记录与核对形成同一事后事实查看表面；F029媒体回顾/比较/完成同一媒体操作体验。算法、权限页、实际删除、事后记录及媒体交互可以独立失败，故分别验收。顺序F026→F027→重开F015→F028→F029，F018不加入本次调度。

## 2026-10-01 LeafDay 品牌接入（R23，用户确认设计）

- Goal：把用户选定的英文名LeafDay和叶片翻页玻璃相片图标作为同一应用品牌正式接入。
- Scope included：1024×1024不透明满幅图标资产与AppIcon编译配置；系统应用显示名LeafDay；首次授权页品牌标题LeafDay，沿用已确认的叶片相片图标；品牌资源来源、构建产物和原生截图证据。
- Scope excluded：不改bundle identifier、target/module/scheme、持久化路径或权限/照片操作；不做商店发布、名称商标或可用性承诺、iCloud/F018验收；不重绘已批准图案、不新增付费依赖。不自行提交或推送本轮新功能。
- Core flows：构建安装→系统桌面显示LeafDay和批准图标→点击启动→未授权时显示同品牌标题和准确授权流程；已授权用户仍进入原首页，原数据位置不变。
- Constraints：使用用户批准生成稿exec-1454f845-3a0e-4202-a671-fb13275a6080.png，只为资源打包进行等比尺寸转换，不预烘焙外部圆角、不加字；图案留安全边距。保留dev.armstrong.swipego及SwipeGo/SwipeGoMedia存储路径。保持动态字体及授权按钮可达。标准asset catalog由Xcode编译；不宣称静态素材具备Icon Composer动态分层效果。
- Ambiguities or assumptions：用户明确选择LeafDay，当前任务为本地品牌接入；中文功能文案中的“时光”仍是普通语义，仅品牌标题替换。用已批准单一外观，其他系统图标样式使用平台默认处理，不额外创作未经批准的深色版本。
- Required capabilities：已批准imagegen输出、sips资源等比转换、现有XcodeGen/actool、iOS模拟器SpringBoard截图及既有独立Evaluator。
- Implementation paths：SwipeGo/Resources/Assets.xcassets、PhotoAccessWelcomeView.swift、project.yml及生成xcodeproj、AppConfigurationTests/LaunchTests/WelcomeGlassTests、docs/design/leafday-brand.md；Harness仅记录SPEC、状态与验收。
- Verification surface：PNG尺寸/不透明检查，编译产物CFBundleDisplayName/CFBundleIcons/Assets.car与原图哈希；原生桌面与授权页截图；现有启动/授权辅助功能回归、完整root与冷启动Evaluator。包标识和持久化目录保持检查。真机安装沿用原流程但不当作F018通过。
- Decomposition：新增单一F030“LeafDay应用品牌与图标”，系统显示名、图标和品牌标题构成同一身份呈现，在同一应用打包/启动表面验证；无新算法、领域流程或独立平台能力。F018继续P1暂缓，F030为P0并依赖已完成F027/F029。
- Platform reference：[Apple asset catalog app icon configuration](https://developer.apple.com/documentation/xcode/configuring-your-app-icon)，支持由1024图像生成尺寸；正式产物仍以本机actool实际编译为验证依据。

## 2026-10-01 一条命令的增量验证与结果报告（R24）

- Goal：用户只需启动一次验证并阅读最终汇总，减少全量UI重复运行和逐段日志阅读。
- Scope included：F031项目级verify.sh入口，changed/full模式、保守路径到用例映射、唯一运行目录、结构化xcresult汇总、失败日志/截图与成功视觉附件索引，可选截图基准（sips缩放到512像素、默认顶部5%状态栏mask、通道差24/变化比例1%可配置）与显式批准命令；同代码/工具链/模拟器/配置的近期完整成功记录可显式复用，root init每次仍跑Harness/Python检查并真实启动App。更新项目Agent工作约定与维护文档。
- Scope excluded：不改变产品UI/照片操作，不执行真机或F018，不提交推送；不把截图当审美自动通过；可选显式批准的像素基准比较只作为回归审阅门禁，不自动更新基准；不并行共享权限/图库的UI用例，不跨环境复用或将Coder结果冒充独立Evaluator结论。
- Core flows：verify.sh --changed计算相对HEAD的已暂存/未暂存/未跟踪改动（可指定base）→映射相关UI+全部快速单元；未知或共享核心修改回退full→构建一次→原生权限准备→串行测试→报告。verify.sh --full强制完整执行。init.sh使用full --reuse，只有指纹/时效/产物和结果完整才复用，否则完整执行；复用仍执行真实模拟器安装/启动并明确标注原始记录与时间。Evaluator首次必须使用SWIPE_VERIFY_FRESH=1 ./init.sh获取独立执行证据，后续相同内容可复用。
- Constraints：非零失败、空/无法解析测试结果不能通过；失败结果不能复用；输入运行前后变动不能通过；单进程锁防竞争；不得卸载App/清空图库。保留原生permission preflight与SwiftData告警门禁。源码/测试/脚本/配置、Xcode/XcodeGen、fixture、模拟器UDID/runtime、影响执行的环境进入指纹；HEAD仅溯源不代替内容校验。输出不持续打印完整构建/测试日志。完整记录最大24小时，复用不延长原始有效期。
- Ambiguities or assumptions：单一F031为一个CLI验证能力，选择、执行、报告和可验证复用共同定义成功契约，在同一脚本边界验证，未包含独立产品功能。视觉截图是待人工/AI审阅的附件，不宣称像素差异自动判断设计好坏。无基准明确not_configured；有基准时新增/变化或full缺图需要审阅并非零退出，显式accept合并被审阅截图，不能批准行为失败。full仍覆盖现有模拟器suite；真机维持原独立入口。
- Required capabilities：已安装Python3标准库、XcodeGen、Xcode/xcrun/xcresulttool、既有iOS26模拟器和fixture；使用实际xcresulttool JSON/help捕获契约，不添加第三方依赖。
- Implementation paths：verify.sh、init.sh、scripts/verification.py、scripts/recover-ios.sh、tests/test_verification.py与真实shape fixtures、docs/verification.md、AGENTS.md；.agent-harness仅SPEC/state/runs和项目验收策略说明。
- Verification surface：路径映射包含新增/删除/重命名与unknown fallback；结果解析成功/失败/空/畸形；缓存输入变更/过期/缺失/篡改产物拒绝、执行失败汇总、进程锁；真实全量执行和复用安装启动；changed真实目标执行；独立Evaluator冷启动fresh root及证据检查。

### R24运行失败改进补充

独立Evaluator已实际完成fresh和reuse探针，但provider进程无最终裁决而长期停留；保留失败记录，并为现有provider命令增加项目自有有界包装器（角色2400秒、runtime check120秒），保留stdin/cwd/参数与退出码，超时终止所拥有进程组且不伪造裁决。该失败改进服务同一F031端到端验证闭环，不新增产品功能或改变Evaluator独立性。PATH指纹改为实际使用工具的解析路径/二进制摘要，忽略无关provider临时前缀但捕获命令遮蔽。全部失败的原生结果仍需保留计数、错误与附件；不把无通过项等同无测试执行。新增路径scripts/run-bounded-evaluator.py、tests/test_bounded_evaluator.py及provider配置维护说明。
