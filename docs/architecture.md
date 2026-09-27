# Swipe-go 架构设计

状态：2026-09-26 规划基线；尚未实现。需求以 [SPEC](../.agent-harness/SPEC.md) 为准，建议细节见其 A01–A09。

## 选型与边界

iPhone / iOS 26+ 原生单体应用。SwiftUI + 原生 Liquid Glass；PhotoKit 访问图库；AVKit/AVFoundation 播放视频；SwiftData 保存本地状态；Vision 做设备端相似分析；Swift Concurrency 负责可取消任务与受控并发。必要时局部 UIKit 承载缩放/手势，先验证再决定。模块先以目录和接口分隔，无需微服务或多个 package。

```mermaid
flowchart TB
 UI[SwiftUI / Liquid Glass] --> Session[ReviewSession / 回顾状态]
 UI --> Compare[Similarity / 比较]
 UI --> Delete[DeletionCoordinator / 删除]
 Session --> Store[LocalStore / SwiftData]
 Session --> Media[PhotoLibraryGateway / MediaLoader]
 Compare --> Analysis[AnalysisWorker / Vision]
 Analysis --> Store
 Analysis --> Media
 Delete --> Store
 Delete --> Media
 Media <--> Photos[系统照片库 / iCloud 照片]
```

## 模块职责

| 模块 | 职责与边界 |
|---|---|
| App / DesignSystem | 组合依赖、导航、玻璃按钮/工具栏/提示；不直接执行图库删除 |
| ReviewSession | 稳定资产顺序、游标、看过记录、手势意图；会话内不每次重新随机 |
| PhotoLibraryGateway | 授权、查询资产、收藏/删除系统请求、图库变化事件；统一处理 SDK 对象 |
| MediaLoader | 浏览尺寸、缓存、邻近预取、云端下载、取消、过期结果丢弃；不会复制全图库 |
| Similarity | 候选生成、特征/算法版本、组结果与建议理由；不拥有删除权限 |
| LocalStore | 显式持久化回顾、待删、操作记录；写失败向上报告，不假成功 |
| DeletionCoordinator | 固定确认集合、执行前校验、系统结果、崩溃后核对；唯一实际删除入口 |

UI 在 MainActor 更新；存储与分析通过明确 actor/执行边界隔离，重计算不留在 UI 路径。任务必须绑定 asset ID、资源版本与请求代次；仅声明 async 不等于重计算自动离开主线程。

## 数据归属与模型

| 数据 | 归属 / 建议模型 |
|---|---|
| 原片、视频、Live Photo、收藏 | 系统图库权威；不复制原片，不以本地 favorite 字段覆盖系统事实 |
| 资产索引 | AssetSnapshot：本机资产 ID、拍摄/修改时间、类型、尺寸、授权范围；可重建 |
| 回顾 | ReviewSession：会话 ID、已选资产 ID 顺序、当前位置、起止时间、浏览历史 |
| 待删 | PendingDeletion：asset ID 唯一、来源会话/组、标记时间；收藏与待删是独立维度 |
| 相似缓存 | FeatureCache：asset ID、内容版本、算法 revision、特征；SimilarityGroup 记录候选与人工决定 |
| 系统操作 | OperationRecord：操作 ID、类型、固定目标 ID、确认时版本、状态、错误和结果 |

本机资产 ID 只作为本机引用，不假定跨设备/重新导入/重装后稳定。缓存不与持久用户意图混在一起；缓存可逐出，待删与会话不可随缓存清理丢失。数据库从第一版记录 schema 版本。

## 媒体与回顾

启动先处理权限，获取足够的元信息即可展示回顾；按需建立索引。先可浏览，再增量分析，后台调度只是优化。只预加载当前项和有限邻近项；切换会话取消过期请求。快速滑动后迟到的结果不得替换当前照片；视频离屏停止并释放多余播放资源。缩略图、显示尺寸图与原片请求分开，云端进度/离线/失败有明确状态。

时间段用于组织回忆，相似组用于比较，两者独立。候选先按时间/尺寸等筛选，再生成 Vision 特征；特征距离不是重复概率。相似链 A~B、B~C 不足以断言 A~C；分组需保守阈值和反例。缓存随照片编辑或算法版本失效。不要承诺表达/清晰度推荐，除非检测器已经验证。

## 删除一致性

```mermaid
stateDiagram-v2
 [*] --> 待删标记: 本地显式保存
 待删标记 --> [*]: 撤回标记
 待删标记 --> 已确认集合: 用户复核
 已确认集合 --> 待删标记: 取消或集合失效
 已确认集合 --> 执行中: 保存操作记录后请求系统
 执行中 --> 已确认成功: 系统成功回执
 执行中 --> 失败待处理: 系统明确失败
 执行中 --> 待核对: App退出或回执未知
 待核对 --> 已确认成功: 有充分成功证据
 待核对 --> 需要重新复核: 结果仍不明确
```

本地数据库与 PhotoKit 无共同事务。执行前保存固定集合及上下文，检查权限、目标与组内保留项；失效时重新复核。资产不可见可能是权限变化，不可直接归因为本次删除。未知操作不自动重试；再次删除必须重新确认。系统取消/失败保留有效待删意图；成功后只清除已确认处理的记录。不可假定 Photos SDK 支持逐项回执，按实际批次回执记录。

上滑与撤销标记完全本地；收藏写系统，错误时回滚显示。收藏撤销需要确认当前状态未被外部改动，不能无条件覆盖其他设备的修改。删除恢复入口由系统提供，App 不提供永久可恢复承诺。

## 图库变化与权限

注册系统图库变化观察并在前台恢复时重新核对，不能仅依赖观察回调。权限变少、资产不可见、资产已编辑分别处理；保留待核对操作，不清空全部本地状态。部分授权下说明范围，无权限时展示可理解空态和管理入口。隐藏/共享内容处理按 SPEC A08 验证，不以假设当作 SDK 能力。

## 外部依赖依据

这些文档说明 API 能力，不替代真机验证：

- [Liquid Glass](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)：统一原生控件与容器，限制玻璃数量；支持辅助功能降级。
- [PhotoKit](https://developer.apple.com/documentation/photokit)：读取系统照片库，包括 iCloud 内容。
- [图片联网请求](https://developer.apple.com/documentation/photos/phimagerequestoptions/isnetworkaccessallowed)：按需请求云端内容。
- [图库变更](https://developer.apple.com/documentation/photokit/requesting-changes-to-the-photo-library)：系统写入与确认边界。
- [Vision 图像相似](https://developer.apple.com/documentation/vision/analyzing-image-similarity-with-feature-print)：候选视觉比较。
- [后台策略](https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app)：调度由系统控制，不作为回顾可用性前提。

后续 App 进度同步、云端模型与跨平台属于新需求，不预先引入后端或 CloudKit 数据同步。
