# To-Learn

SwiftUI iOS 学习助手，完整功能说明见 [LearnFlowApp/README.md](LearnFlowApp/README.md)。

## 云端生成未签名 IPA

[![Build unsigned iOS IPA](https://github.com/aaa455/To-Learn/actions/workflows/unsigned-ios.yml/badge.svg)](https://github.com/aaa455/To-Learn/actions/workflows/unsigned-ios.yml)

推送应用源码到 `main` 时，GitHub Actions 会在 macOS 运行器上使用 Xcode 构建 iPhone/iPad 真机 Release 版本。也可以在 **Actions → Build unsigned iOS IPA → Run workflow** 手动触发。

构建完成后，在对应运行页面的 **Artifacts** 下载 `LearnFlowApp-unsigned`，解压后得到：

- `LearnFlowApp-unsigned.ipa`
- `LearnFlowApp-unsigned.ipa.sha256`（SHA-256 校验值）

构建关闭代码签名，不需要 Apple 开发者证书或描述文件。工作流会检查 arm64 架构、未签名状态和 IPA ZIP 完整性。产物保留 30 天，构建日志保留 7 天。

未签名 IPA 需要自行签名后才能安装到普通 iPhone/iPad。应用锁定功能依赖 Family Controls 授权及相应的 Apple entitlement，构建成功不代表该功能已通过真机验证。

## 本地开发

在 macOS 上用 Xcode 打开 `LearnFlowApp/LearnFlowApp.xcodeproj`。最低系统版本为 iOS 16.0。

运行 `bash tests/run-regressions.sh` 可验证历史数据兼容、AI 方案校验、逾期复习、暂停与跳过、后台跨阶段计时以及计时恢复。脚本直接编译生产模型和服务代码，不访问实际 AI 接口；云端 IPA 工作流会先执行这些检查。

## 1.0.1 修复与验证范围

- 专注页共用一个计时器，按截止时间恢复锁屏期间的进度，并保存暂停、阶段和实际专注时长。
- 兼容旧专注历史与 AI 配置；无法读取的历史保留备份，避免其他保存操作覆盖原数据。
- API Key 迁移到本机钥匙串，模型选择使用独立草稿；网络错误回到主线程显示。
- 逾期复习可补记，记录对应计划日期及实际完成时间；统计统一使用实际专注秒数。
- AI 生成的空方案、异常时长、未知节点、错误顺序和超时方案不会进入计时流程。

本仓库包含 Family Controls entitlement，但签名账户和描述文件仍必须具有对应权限。应用目前没有 Device Activity 扩展：锁屏后的倒计时会继续，到期可收到通知（需要通知授权），应用屏蔽须返回本应用后才解除。不要将构建与模型测试通过视为屏幕使用时间、通知或钥匙串已经过真机测试。
