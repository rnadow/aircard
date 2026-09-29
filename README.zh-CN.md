# AirCard-iOS 26.4

<p align="center">
  <img src="ios-app/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="128" height="128" alt="AirCard-iOS 图标" />
</p>

<p align="center">面向 iOS 26.4 的实验性适配：无需越狱，在设备端更换 Apple Wallet 本地卡面、锁屏密码键盘主题与 PosterBoard 壁纸。</p>

<p align="center">
  <strong>简体中文</strong> · <a href="README.md">English</a> ·
  <a href="https://rnadow.github.io/aircard/">项目主页</a> ·
  <a href="https://rnadow.top/posts/aircard-ios-26-4-windows-build/">构建记录</a>
</p>

> [!WARNING]
> 这是实验性研究版本，不保证兼容所有设备或 iOS 小版本。修改 Wallet 前必须先运行兼容性探针，并自行备份、承担风险。

## 这个分支增加了什么

- **安全兼容性探针**：验证回环网络、配对、AFC、AirTraffic 路径、精确字节回读和清理；探针不修改 Wallet。
- **外部配对文件导入**：开发者模式没有弹出授权提示时，可导入 `.plist`、`.mobiledevicepairing` 或 `.mobilepair`。
- **多卡精准识别**：Wallet 有 10 张卡或更多时，打开目标卡，AirCard 会将当前卡标为绿色 **CURRENT CARD**，并只选择该卡进行写入。
- **本地备注**：可用银行名和尾号四位给卡片哈希命名，备注只保存在本机。
- **Windows 构建脚本**：从 Windows 上传源码、触发 GitHub macOS Runner 构建、下载无签名 IPA，并核验 SHA-256。

当前包版本为 **v1.3.3 (2643)**，构建产物位于 `build/AirCard-iOS.ipa`。

## 主要功能

### Apple Wallet 卡面

- 替换单张 Wallet 卡片的本地图像缓存。
- 支持 PNG，以及部分交通卡使用的 PDF 卡面缓存。
- Wallet 打开时从设备日志识别卡片标识符。
- 支持单卡写入和批量写入。

### 10 张卡时如何确认目标卡

普通扫描可能一次列出多个卡片标识符，不能仅凭“最后出现”判断目标卡。

1. 在 AirCard 中开始扫描 Wallet 卡片。
2. 打开 Wallet，点进你真正想换卡面的那一张卡。
3. 等待 AirCard 中对应条目出现绿色 **CURRENT CARD** 标记。
4. 可选：用“银行名 + 尾号四位”添加本地备注，便于以后识别。
5. 只给这张已选中的卡分配图片，然后执行 Flash。

### 密码键盘与壁纸

- 密码键盘实时预览、缩放和定位，支持整图布局或单按钮裁切。
- 导入、导出 `.passthm` 主题。
- 导入并写入 `.tendies` PosterBoard 壁纸。
- 壁纸写入后通过 NeoSpring 触发 respring。

## 使用条件

- 运行已测试 iOS 26.4 环境的 iPhone。
- LocalDevVPN 或 SideStore WireGuard 等可用的回环 VPN。
- 为当前 iPhone 生成的可信 Remote Pairing 配对文件。
- 自己控制的签名和侧载方式。

> [!IMPORTANT]
> `.p12` 是签名证书，不是设备配对文件。AirCard 需要 `.plist`、`.mobiledevicepairing` 或 `.mobilepair`。配对文件、证书、UDID、卡片哈希和完整诊断日志都不应公开上传。

## 配对与首次运行

### 方式一：设备内部配对

进入 AirCard 的 **Pairing** 页面，点 **Pair This iPhone**。如果系统显示入口，再到 **设置 → 隐私与安全性 → 开发者模式** 批准配对。

### 方式二：导入现有配对文件

如果 iOS 26 没有出现配对提示，可从 Mac 或现有 SideStore/iLoader 环境导出可信配对文件，再在 AirCard 中选择 **Import Pairing Record**。iLoader 可按下面的顺序操作：

1. 执行 **Delete Stored Pairing**。
2. 重新连接 iPhone，在手机上选择 **信任**。
3. 打开 **Manage Pairing File**，选择 **Place**。
4. 将生成的配对文件导入 AirCard。

连接前先启动回环 VPN。若出现 `failed to parse raw pairing file from bytes`，通常是选错了文件类型，或者回环隧道没有启动。

### 先运行安全探针

换卡面前，进入 **iOS 26.4 Compatibility → Run iOS 26.4 Probe**。探针会在 `/var/mobile/Library/Caches` 下写入随机 canary，通过 AirTraffic 回读并逐字节校验，最后删除临时对象。它不会写入 Passbook 或 Wallet。

只有所有探针阶段都显示绿色后，才继续测试卡面写入。

## 安装

本仓库构建的是**无签名 IPA**。请使用自己控制的 SideStore、AltStore、TrollStore、LiveContainer、Xcode 或其他方式签名并安装。

## 在 Windows 上构建

Windows 无法本地运行 Apple iOS SDK，因此脚本会将编译任务交给 GitHub Actions 的 macOS Runner。

### 1. 安装并登录 GitHub CLI

```powershell
winget install --id GitHub.cli
gh auth login
```

如果安装后仍提示无法识别 `gh`，关闭并重新打开 PowerShell。

### 2. 开始构建

```powershell
Set-Location "C:\Projects\AirCard-iOS-26.4"
powershell -ExecutionPolicy Bypass -File .\build-from-windows.ps1 -Repository "rnadow/aircard"
```

这是一条完整命令，末尾不要添加 PowerShell 反引号。完成后会生成：

```text
build/AirCard-iOS.ipa
build/AirCard-iOS.ipa.sha256
```

如果 Git 提示 `detected dubious ownership`，只将当前仓库加入信任列表：

```powershell
git config --global --add safe.directory "H:/CWD/Documents/ChatGPT/个人/AirCard-iOS-26.4"
```

### 自动生成 Pre-release

维护者可以推送格式严格为 `v<MARKETING_VERSION>-ios26.4` 的 tag。GitHub Actions 会先核对 tag 与 `project.yml` 中的版本号，再只构建一次无签名 IPA，将同一个 workflow artifact 传递给发布任务，并自动生成带版本号的 IPA 与 SHA-256 附件。版本不匹配时会在发布前失败。

### 在 macOS 上构建

需要 macOS 14+、Xcode 16+ 与 XcodeGen。

```bash
brew install xcodegen
git clone https://github.com/rnadow/aircard.git
cd aircard
./build-ipa.sh
```

只有修改 `rust-core` 时才需要重新构建 Rust framework：

```bash
./build-ios.sh
```

## 目录结构

```text
AirCard-iOS-26.4/
├── ios-app/                 SwiftUI 应用
├── rust-core/               Airlift/AirTraffic Rust 核心
├── project.yml              XcodeGen 配置
├── build-ipa.sh             macOS IPA 构建脚本
├── build-ios.sh             Rust framework 构建脚本
├── build-from-windows.ps1   Windows → GitHub Actions
├── build-ipa.yml            Actions 工作流源文件
└── docs/                    GitHub Pages 项目主页
```

## 安全说明与限制

- 本仓库是独立的实验性适配，并非上游官方二进制发布。v1.3.2 与 v1.3.3 为兼容原地升级，暂时保留上游的 `com.mak5er.aircard` Bundle ID；更换 Bundle ID 属于应用身份迁移，将作为不兼容升级单独发布。
- 本项目修改的是本地视觉缓存，不会修改支付凭据、余额、发卡行数据或 Secure Element。
- 配对文件可以让特定主机认证当前设备，必须妥善保管；分享日志或压缩包前应先删除。
- 探针可以降低风险，但无法保证所有 iOS 构建上的全部写入路径都安全。
- 第一次先测试一张卡和一张可随时替换的图片；确认目标准确前不要批量写入。

## 致谢

- [@mak5er](https://github.com/mak5er)：上游 AirCard-iOS、界面、密码主题、Tendies 引擎与配对相关工作。
- [@merybist](https://github.com/merybist)：初始基础移植。
- [AirLift](https://github.com/0xjohnnydev/airlift) / [@0xjohnnydev](https://github.com/0xjohnnydev)：`AirliftFFI` 所基于的 AirTraffic 与 ATAirlock 研究。
- [NeoSpring](https://github.com/rooootdev/neospring)：respring 实现及相关研究。

## 许可证

MIT，详见 [LICENSE](LICENSE)。
