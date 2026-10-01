# LeafDay 品牌接入

用户于2026-10-01选择英文名 **LeafDay**，随后确认叶片翻页玻璃相片图标并授权按此实施。图标内无文字，桌面名称使用LeafDay。叶片表示翻开回忆，太阳表示日常时光；保持薄荷绿和柔和日光色。

![批准原稿](leafday/approved-icon.png)

## 素材来源与打包

- 内置imagegen生成，参考早期A款Dayleaf草图；正式批准的是后续LeafDay无字满幅稿，不采用带展示边框和旧名字的候选图。
- 原输出文件：`exec-1454f845-3a0e-4202-a671-fb13275a6080.png`；仓库副本`leafday/approved-icon.png`，1254×1254，不透明。
- 仅用`sips -z 1024 1024`等比转换作资源打包，无裁切、重绘、加字或外部圆角。AppIcon和授权页LeafDayMark使用同一转换图像。
- 使用标准asset catalog，由Xcode编译图标尺寸；静态图像呈现玻璃质感，不宣称具备Icon Composer分层动态效果。其他系统外观使用平台默认处理。
- Apple参考：[Configuring your app icon using an asset catalog](https://developer.apple.com/documentation/xcode/configuring-your-app-icon)。名称未作商标或商店唯一性承诺，本轮不发布商店。

## 接入边界

系统显示名及首次授权品牌标题改为LeafDay。保持`dev.armstrong.swipego`、Swift模块/target/scheme和`SwipeGo`/`SwipeGoMedia`持久化目录。普通中文“回顾时光”等文案保留，不迁移或清除原数据。

## 验证

F030目标验证已通过：1项配置单元测试、3项原生UI测试；核验实际桌面显示/点击启动、授权页及最大字号权限操作。独立Evaluator已通过：完整root85单元/44UI零失败，结果`.build/test-run.g3T45E/Tests.xcresult`，验收`.agent-harness/runs/20261001-F030-reevaluation.md`。首轮桌面定位失败已修复，失败证据保留。F018真实图库/iCloud仍单独待验，2026-10-01用户随后授权提交和真机更新，LeafDay已原位安装并启动，设备显示名确认正确；提交前85单元/44UI再次通过。未推送。

[桌面截图](leafday/F030-LeafDay-home-screen.png) · [首次授权](leafday/F025-welcome-glass.png) · [最大字号](leafday/F025-welcome-large-opaque.png)

原稿SHA256：`0cd6a7115d3836ac1398480335a18bf9257554182f494754c4d7ea9a35078312`

打包图SHA256：`7cc472cfd2b2f9b063f831aecb0fa4914ddc7d01762b1d97a58fe244fab59e53`

[标准尺寸桌面截图](leafday/F030-LeafDay-home-screen-standard.png)。实际图标点击启动和冷重启均独立通过。
