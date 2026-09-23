# 按需开发与验证

贡献规范与安全边界见 [CONTRIBUTING.md](../CONTRIBUTING.md) 和 [SECURITY.md](../SECURITY.md)。

## 选择验证范围

| 变更 | 验证 |
| --- | --- |
| 指导文档 | 检查引用路径、适用范围、重复或矛盾规则；无需云端调用或改写时间线 |
| 文稿分析及请求构造 | `bash scripts/test.sh --filter ComposerTests`；模拟响应只能证明接口处理，不能证明模型输出质量 |
| 时间码和区间模型 | `bash scripts/test.sh --filter CoreTests` |
| Python 时间线桥接 | `python3 -m unittest discover -s Tests -p 'test_*.py' -v`；必要时追加下述实机验证 |
| 跨模块实现 | `bash scripts/test.sh` |
| 原生 UI / 应用包 | `bash scripts/build-app.sh`，再启动并操作受影响控件；UI 无法读取时记录验证缺口 |

Swift 过滤参数传给 `swift test`；`scripts/test.sh` 随后仍运行 Python 测试。准确区分通过、失败和跳过，不将已跳过的实机测试计为通过。

## Resolve 实机验证

修改时间线写入或版本管理时，使用独立 QA 时间线和已有本地 WAV 验证端到端结果。该流程会在当前项目留下 QA 时间线与备份；用户已经授权此类集成验证时直接执行。仅文档或 Prompt 修改不需要运行。

```bash
RESOLVE_LIVE_SMOKE=1 bash scripts/test.sh --filter LiveResolveTests
```

前提是 Resolve 已有打开的项目与时间线，并且本机已安装 FFmpeg。测试会在临时目录生成 20 秒测试音频，结束后删除该音频并恢复原时间线；不要为获得绿色结果删除用户项目或备份。涉及帧边界时检查实际 GetStart/GetEnd/GetDuration；不要从其他媒体类型的 endFrame 语义推测音频插入行为。

## 打包与启动排障

```bash
bash scripts/build-app.sh
codesign --verify --deep --strict 'dist/Resolve AI Music.app'
open 'dist/Resolve AI Music.app'
```

产物使用本机 ad-hoc 签名。系统接受签名、进程存在和窗口可用是不同证据；启动问题需要检查窗口或实际错误，不能仅凭后台进程判定已修好。避免用 `open -n` 反复产生多个实例。更换运行版本时先确认任务状态，通过应用正常退出再启动。

## Prompt 与服务

开发流程与产品内 TokenHub Prompt 相互独立；开发工具或测试设置不得自动切换产品模型、端点、密钥或计费方式。

`Composer.swift` 维护两个短任务指令及共用素材边界；`Services.swift` 的纯音乐、目标时长和完整结尾约束属于产品输出契约；`Models.swift` 的十个预设是用户可编辑的创作素材。维持长度保护、纯音乐要求与可编辑结果；编写配乐指令时描述需要的结果，避免把每首音乐强制分为固定段落。

请求的 300 秒超时是当前云端生成/分析实现的设置，不是所有 Agent 工具或 HTTP 请求的全局要求。一次付费 POST 不盲目重试；下载和本地转码失败优先恢复已有结果。测试使用模拟服务不需要真实密钥。真实模型质量验证应使用用户授权的样本及调用范围。
