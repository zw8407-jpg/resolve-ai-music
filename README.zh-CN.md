# Resolve AI Music

<p align="center">
  <img src="Assets/AppIconSource.png" width="128" height="128" alt="Resolve AI Music 图标">
</p>

**通过文字或文稿生成音乐，并直接放入 DaVinci Resolve 时间线。**

[English](README.md)

Resolve AI Music 是一款原生 macOS 菜单栏工具，面向剪辑师与内容创作者。它可读取
Resolve 当前的 In-Out 区间或播放头位置，通过 TokenHub MiniMax Music 生成纯音乐，
将结果统一处理为 48 kHz 双声道 WAV，并写入应用管理的主版本与备选版本轨道。

> 当前为公开预览版本。在确认符合你的 Resolve 环境前，请使用复制工程或专用测试时间线。

## 主要功能

- 优先使用当前 In-Out；未设置时从播放头按输入时长生成。
- 支持音乐描述、文稿分析和设备端语音输入。
- 内置十种音乐风格和不联网的描述变体。
- 自动管理主版本与默认静音的备选版本。
- 写入前检查重叠和外来素材，并创建时间线备份。
- 支持简体中文、繁體中文、English、日本語、한국어和 Español，默认简体中文。
- TokenHub API Key 仅保存在 macOS 钥匙串。
- 支持历史记录、下载恢复和已有音频重新采用。

## 系统要求

- macOS 13 或更高版本
- Apple Silicon Mac（当前版本在 arm64 环境开发和测试）
- 默认路径安装的 DaVinci Resolve Studio 21.1
- Resolve 已启用外部脚本，并随 Resolve 安装 ResolveMCP
- `/opt/homebrew/bin` 或 `/usr/local/bin` 中可用的 FFmpeg 与 FFprobe
- 用户自己的 TokenHub API Key，并已启用所需语言模型和音乐模型

使用 Homebrew 安装 FFmpeg：

```bash
brew install ffmpeg
```

## 从源码构建

```bash
git clone https://github.com/zw8407-jpg/resolve-ai-music.git
cd resolve-ai-music
bash scripts/test.sh
bash scripts/build-app.sh
open "dist/Resolve AI Music.app"
```

本机构建使用 ad-hoc 临时签名，只用于开发。公开安装包必须经过 Developer ID 签名、
Hardened Runtime 和 Apple 公证，详见 [`docs/releasing.md`](docs/releasing.md)。

## 使用步骤

1. 打开 Resolve 项目和目标时间线。
2. 启动 Resolve AI Music，进入“设置”。
3. 粘贴 TokenHub `sk-…` 密钥并保存到钥匙串。
4. 如需使用鼠标中键双击快捷方式，请授予辅助功能权限；未授权时仍可使用菜单栏图标。
5. 设置 In-Out 或播放头，选择时长、风格并编辑音乐描述。
6. 选择主版本或备选版本，然后生成一首音乐。

应用默认优先使用 A3/A4。如果轨道存在外来素材或被锁定，会建议另一组连续空轨，不会
覆盖用户素材。轨道颜色不通过自动化修改；如有需要，可在 Resolve 中手动将主轨设为
紫色、备选轨设为蓝色。

## 数据、费用与恢复

- 音乐和语言模型调用可能产生 TokenHub 费用。应用每次只提交一首，不盲目重试付费请求。
- 只有明确点击文稿分析、优化描述或生成时，相应文字才会发送至 TokenHub。详见
  [`PRIVACY.md`](PRIVACY.md)。
- 应用数据保存在 `~/Library/Application Support/ResolveAIMusic/`。
- Resolve 仍引用生成音频时，请勿移动或删除相关文件。
- 所有受管理的时间线写入均包含归属标记、冲突检测和写入前备份。

## 开发与测试

标准测试使用模拟云端响应，不会发起真实付费请求：

```bash
bash scripts/test.sh
```

真实 Resolve 集成测试默认跳过。开发说明见
[`docs/development.md`](docs/development.md) 和 [`CONTRIBUTING.md`](CONTRIBUTING.md)。

## 分发与第三方声明

本仓库不分发 Resolve、ResolveMCP、FFmpeg、MiniMax 或 TokenHub 的二进制文件。用户须按
第三方服务条款自行安装软件并开通服务。

DaVinci Resolve 是 Blackmagic Design Pty Ltd. 的商标；MiniMax、TokenHub、腾讯云、
Apple 和 macOS 等名称及标识归各自权利人所有。本项目为独立开源项目，不代表获得上述
公司的赞助、认可或关联。

## 开源许可证

源代码和文档采用 [Apache License 2.0](LICENSE)。产品名称与品牌视觉另见
[`TRADEMARKS.md`](TRADEMARKS.md)。
