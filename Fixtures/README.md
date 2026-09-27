# 可丢弃媒体素材 v1

素材完全由项目脚本绘制；无个人照片、外部授权图片或云端下载。画像为几何卡通，笑/皱眉只是不同表情的**合成反例**，不能用来证明真人表情检测准确率或相似阈值适合真实相册。

## 生成与核对

依赖 Full Xcode、Python3、ffmpeg/ffprobe（`HOMEBREW_NO_INSTALL_CLEANUP=1 brew install ffmpeg`）。

```sh
python3 scripts/seed-fixtures.py --seed 27
python3 -m unittest discover -s tests -v
```

输出在忽略的 `Fixtures/generated/`；manifest 记录 seed、版本、文件 SHA256 和关系。同一工具版本和 seed 可生成相同内容；ImageIO/编码器跨版本的字节差异不应被解释为图片内容变化，升级工具需重建基线。素材只有9项，不允许自动换入个人图库。

| 文件 | 日期 | 意图 |
|---|---|---|
| landscape / copy | 2025-09-27 10:00 | 完全相同图像、1200×800 |
| landscape-near | 2025-09-27 10:00:02 | 仅太阳位置轻微变化，候选近似图 |
| portrait-smile / frown | 2025-09-27 10:10 | 800×1200，同构图但表情不同，人工应可保留两张 |
| square | 2025-09-27 18:00 | 方图、同日时间空档 |
| leap-day | 2024-02-29 09:00 | 闰日、横图 |
| later-day | 2026-01-02 12:00 | 跨日期、竖图 |
| clip.mp4 | 2025-09-27 10:05 UTC | 2秒 600×400 H264 视频及合成440Hz声音；用于播放/静音验证 |

图片 EXIF 本地时间不带时区，视频使用 UTC；会话测试需指定时区而不是假设它们总是相差固定分钟。相似关系是人工构造标签，算法实际距离必须在 F013 测量；不按文件名宣称分析通过。

## 安全导入与重复恢复

```sh
python3 scripts/seed-fixtures.py --seed 27 --install
```

每次显式 `--install` 创建一个全新的 `SwipeGo Fixtures seed 27` 模拟器，导入同一9项。不会选择、擦除或删除任何已有设备，不读取个人图库。这样无需依赖易过期的“已导入”缓存，也不会向同一个库重复追加。脚本打印 UDID，收据 `install-<UDID>.json` 先记录 created，导入成功后才标为 imported；失败不自动删除设备或假称导入成功。

用输出的 `SWIPE_SIMULATOR_UDID=<UDID> ./init.sh` 安装 App 到该库。多次测试会产生多个隔离设备；不再需要时在 Xcode Devices and Simulators 中手动删除对应测试设备。默认不带 `--install` 只生成文件。

## 无法证明的真实行为

本地 fixture 不证明 iCloud 未下载资源、真实断网、部分授权选择器、共享图库排除、真人相似效果或真机性能。F005/F006/F007/F018 必须分别留下真实系统/真机证据。真机测试只导入自愿的可丢弃素材；不登录用户 Apple ID 或自动触碰用户照片。

具体真实系统验证前置条件、步骤、预期结果和取证要求见 [`docs/verification.md`](../docs/verification.md) 的“真实系统验证操作矩阵”。该矩阵是待执行协议，不代表本次 F003 已完成云端或真机验证。
