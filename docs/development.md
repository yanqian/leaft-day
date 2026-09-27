# 开发环境与 Provider

## 当前能力状态

项目 Git 已初始化，无提交。Harness 0.3.9 已安装。既有 `app-screenshot/` 保留；产品工程尚未创建。

最近现场证据（2026-09-26）：`xcode-select -p` 为 `/Library/Developer/CommandLineTools`，`xcodebuild -version` 因非完整 Xcode 失败。尚未穷尽查找本机所有 Xcode，不能据此断言机器没有安装 Xcode。F001 负责 SDK/模拟器能力与可重现检查；不擅自切换全局开发目录或安装大型工具。

## Provider

`.agent-harness/agent-provider.json` 按用户指定 Codex 命令保存；隐藏布局 cwd 从用户原始 `.` 适配为 `..`，指向项目根。此本机配置被根 `.gitignore` 排除；不包含密钥。未运行真实模型 preflight，不声称已验证账户/网络/模型执行。

指定 executable：`/Applications/ChatGPT.app/Contents/Resources/codex`；model：`gpt-6-astra`；stdin 为 `-`；runtime check 多加 `--ephemeral`。本地 CLI 先前报告 `0.155.0-alpha.16`，与用户 2026-09-05 的历史验证版本不同。原历史说明作为配置 provenance 保留，不复制不存在的旧 run 文件冒充本项目证据。

实际执行前按 `.agent-harness/docs/agent-provider-configuration.md` 做 runtime preflight；若有权限/网络问题，按真实错误处理，不自动改模型、不绕过审批或沙箱。

## 实施入口

收到开始实现指令后，先恢复 `.agent-harness/progress.md`。交互模式用 `make -C .agent-harness work-fast`，每次仅一个 Feature；coding 不能自己写 evaluator pass。无人值守双子进程模式才使用 `make -C .agent-harness work`。

当前不执行任何工作入口。任务依赖是规划元数据，不假设 orchestrator 自动理解；启动每项前检查依赖已通过。

## F001 环境检查（2026-09-27 更新）

执行 `./scripts/doctor.sh`。依次验证完整 Xcode、iphoneos / iphonesimulator SDK >=26、simctl、可用 iOS 26+ runtime 和可用 iPhone 设备。显式 `DEVELOPER_DIR` 优先且无效时失败；未指定时使用 active developer directory，只有它缺少 iPhoneOS platform 时回退到 `/Applications/Xcode.app/Contents/Developer`。仅影响本命令，不运行 sudo xcode-select。

可用 `DEVELOPER_DIR=/custom/Xcode.app/Contents/Developer ./scripts/doctor.sh` 或 `SWIPE_SIMULATOR_UDID=<真实设备ID> ./scripts/doctor.sh` 指定。不存在、不可用、iPad 或版本不匹配的设备不会被选择。默认按 runtime 版本降序、设备名称/ID 排序选定，输出机器可读 JSON。脚本只盘点，不创建/启动/擦除模拟器。

真实验证：Xcode 26.6 (17F113)，两个 SDK 均 26.5，iOS 26.5 runtime (23F77) 可用。READY 仅代表盘点成功，模拟器实际启动及 App 构建 smoke 属于 F002。模拟器不要求开发签名团队；真机需要有效签名、设备配对/开发者模式以及适用的 provisioning。账户和分发能力未验证。

CoreSimulator 需要访问用户级服务；受限沙箱可能报 XPC/日志权限错误。这时脚本非零退出，应通过外层权限批准重跑，不修改系统安全设置。Codex provider 已完成 runtime preflight；实际 evaluator 同样需要适当权限。

测试：`python3 -m unittest discover -s tests -v`。`tests/fixtures/simctl-ios26.json` 来自本机真实 `xcrun simctl list -j`（2026-09-27），裁去路径和不用字段；派生负例只验证解析/失败逻辑，不证明真实环境就绪。真实 doctor 结果必须单独记录。

2026-09-27 用户明确批准独立 Evaluator 加入 `--approve-for-me`：保留 workspace-write 沙箱，通过自动审批处理 CoreSimulator 权限。仅 evaluator_command 增加该选项，模型与其他命令不变；不使用 bypass 或 danger-full-access。
