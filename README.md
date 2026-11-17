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
