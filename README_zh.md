<p align="center">
  <img src="public/assets/openfang-logo.png" width="160" alt="OpenFang Logo" />
</p>

<h1 align="center">OpenFang</h1>
<h3 align="center">智能体操作系统</h3>

<p align="center">
  基于 Rust 构建的开源智能体操作系统。13.7万行代码。14个crate。1,767+测试。零clippy警告。<br/>
  <strong>单一二进制文件。经过实战测试。真正为您工作的智能体。</strong>
</p>

<p align="center">
  <a href="https://openfang.sh/docs">文档</a> &bull;
  <a href="https://openfang.sh/docs/getting-started">快速开始</a> &bull;
  <a href="https://x.com/openfangg">Twitter / X</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/language-Rust-orange?style=flat-square" alt="Rust" />
  <img src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" alt="MIT" />
  <img src="https://img.shields.io/badge/version-0.1.0-green?style=flat-square" alt="v0.1.0" />
  <img src="https://img.shields.io/badge/tests-1,767%2B%20passing-brightgreen?style=flat-square" alt="Tests" />
  <img src="https://img.shields.io/badge/clippy-0%20warnings-brightgreen?style=flat-square" alt="Clippy" />
  <a href="https://www.buymeacoffee.com/openfang" target="_blank"><img src="https://img.shields.io/badge/Buy%20Me%20a%20Coffee-FFDD00?style=flat-square&logo=buy-me-a-coffee&logoColor=black" alt="Buy Me A Coffee" /></a>
</p>

---

> **v0.1.0 — 首次发布（2026年2月）**
>
> OpenFang 功能完整但这是第一个公开版本。您可能会遇到不稳定性、粗糙边缘或次要版本之间的破坏性更改。我们快速发布并快速修复。在生产环境中使用请固定到特定提交，直到v1.0版本。[在此报告问题。](https://github.com/RightNow-AI/openfang/issues)

---

## 什么是 OpenFang？

OpenFang 是一个**开源智能体操作系统**——不是聊天机器人框架，不是围绕LLM的Python包装器，也不是"多智能体编排器"。它是一个为自主智能体构建的完整操作系统，从头开始用Rust编写。

传统智能体框架等待您输入内容。OpenFang 运行**为您工作的自主智能体**——按计划、24/7运行，构建知识图谱，监控目标，生成潜在客户，管理您的社交媒体，并向您的仪表板报告结果。

整个系统编译为**单个约32MB的二进制文件**。一次安装，一个命令，您的智能体即可上线。

```bash
curl -fsSL https://openfang.sh/install | sh
openfang init
openfang start
# 仪表板运行在 http://localhost:4200
```

<details>
<summary><strong>Windows</strong></summary>

```powershell
irm https://openfang.sh/install.ps1 | iex
openfang init
openfang start
```

</details>

---

## Hands：真正做事的智能体

<p align="center"><em>"传统智能体等待您输入。Hands为您工作。"</em></p>

**Hands** 是 OpenFang 的核心创新——预构建的自主能力包，独立运行，按计划执行，无需您提示它们。这不是聊天机器人。这是一个在您喝咖啡之前就醒来、研究您的竞争对手、构建知识图谱、评估发现并发送报告到您的Telegram的智能体。

每个Hand包含：
- **HAND.toml** — 声明工具、设置、要求和仪表板指标的清单
- **系统提示** — 多阶段操作手册（不是单行命令——这些是500+字的专家程序）
- **SKILL.md** — 在运行时注入上下文的领域专业知识参考
- **防护栏** — 敏感操作的批准门（例如，Browser Hand在进行任何购买前需要批准）

所有内容都编译到二进制文件中。无需下载，无需pip安装，无需Docker拉取。

### 7个捆绑的Hands

| Hand | 实际功能 |
|------|----------------------|
| **Clip** | 获取YouTube URL，下载视频，识别最佳时刻，将其剪辑成带有字幕和缩略图的垂直短片，可选添加AI语音，并发布到Telegram和WhatsApp。8阶段流水线。FFmpeg + yt-dlp + 5个STT后端。 |
| **Lead** | 每日运行。发现符合您ICP的潜在客户，通过网络研究丰富信息，评分0-100，与现有数据库去重，并以CSV/JSON/Markdown格式提供合格线索。随时间构建ICP配置文件。 |
| **Collector** | OSINT级情报。您给它一个目标（公司、人员、主题）。它持续监控——变更检测、情感跟踪、知识图谱构建，并在重要变化时发出关键警报。 |
| **Predictor** | 超级预测引擎。从多个来源收集信号，构建校准推理链，进行带有置信区间的预测，并使用Brier分数跟踪自身准确性。具有故意反对共识的逆向模式。 |
| **Researcher** | 深度自主研究员。交叉引用多个来源，使用CRAAP标准（时效性、相关性、权威性、准确性、目的性）评估可信度，生成带有APA格式引用的报告，支持多种语言。 |
| **Twitter** | 自主Twitter/X账户管理器。以7种轮换格式创建内容，为最佳参与度安排帖子，回复提及，跟踪性能指标。具有批准队列——未经您的确认不会发布任何内容。 |
| **Browser** | Web自动化智能体。导航网站，填写表单，点击按钮，处理多步骤工作流。使用具有会话持久性的Playwright桥接。**强制性购买批准门**——未经明确确认绝不会花费您的资金。 |

```bash
# 激活Researcher Hand — 它立即开始工作
openfang hand activate researcher

# 随时检查其进度
openfang hand status researcher

# 在每日计划上激活潜在客户生成
openfang hand activate lead

# 暂停而不丢失状态
openfang hand pause lead

# 查看所有可用的Hands
openfang hand list
```

**构建您自己的Hand。** 使用工具、设置和系统提示定义`HAND.toml`。发布到FangHub。

---

## OpenFang vs 竞品生态

<p align="center">
  <img src="public/assets/openfang-vs-claws.png" width="600" alt="OpenFang vs OpenClaw vs ZeroClaw" />
</p>

### 基准测试：实测而非营销

所有数据来自官方文档和公共仓库——2026年2月。

#### 冷启动时间（越低越好）

```
ZeroClaw   ██░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░   10 ms
OpenFang   ██████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  180 ms    ★
LangGraph  █████████████████░░░░░░░░░░░░░░░░░░░░░░░░░  2.5 sec
CrewAI     ████████████████████░░░░░░░░░░░░░░░░░░░░░░  3.0 sec
AutoGen    ██████████████████████████░░░░░░░░░░░░░░░░░  4.0 sec
OpenClaw   █████████████████████████████████████████░░  5.98 sec
```

#### 空闲内存使用（越低越好）

```
ZeroClaw   █░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░    5 MB
OpenFang   ████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░   40 MB    ★
LangGraph  ██████████████████░░░░░░░░░░░░░░░░░░░░░░░░░  180 MB
CrewAI     ████████████████████░░░░░░░░░░░░░░░░░░░░░░░  200 MB
AutoGen    █████████████████████████░░░░░░░░░░░░░░░░░░  250 MB
OpenClaw   ████████████████████████████████████████░░░░  394 MB
```

#### 安装大小（越低越好）

```
ZeroClaw   █░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  8.8 MB
OpenFang   ███░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░   32 MB    ★
CrewAI     ████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  100 MB
LangGraph  ████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  150 MB
AutoGen    ████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░  200 MB
OpenClaw   ████████████████████████████████████████░░░░  500 MB
```

#### 安全系统（越高越好）

```
OpenFang   ████████████████████████████████████████████   16      ★
ZeroClaw   ███████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░    6
OpenClaw   ████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░    3
AutoGen    █████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░    2
LangGraph  █████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░    2
CrewAI     ███░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░    1
```

#### 通道适配器（越高越好）

```
OpenFang   ████████████████████████████████████████████   40      ★
ZeroClaw   ███████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░   15
OpenClaw   █████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░   13
CrewAI     ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░    0
AutoGen    ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░    0
LangGraph  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░    0
```

#### LLM提供商（越高越好）

```
ZeroClaw   ████████████████████████████████████████████   28
OpenFang   ██████████████████████████████████████████░░   27      ★
LangGraph  ██████████████████████░░░░░░░░░░░░░░░░░░░░░   15
CrewAI     ██████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░   10
OpenClaw   ██████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░   10
AutoGen    ███████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░    8
```

### 功能对比

| 功能 | OpenFang | OpenClaw | ZeroClaw | CrewAI | AutoGen | LangGraph |
|---------|----------|----------|----------|--------|---------|-----------|
| **语言** | **Rust** | TypeScript | **Rust** | Python | Python | Python |
| **自主Hands** | **7个内置** | 无 | 无 | 无 | 无 | 无 |
| **安全层** | **16个独立** | 3个基础 | 6层 | 1个基础 | Docker | AES加密 |
| **智能体沙箱** | **WASM双计量** | 无 | 白名单 | 无 | Docker | 无 |
| **通道适配器** | **40个** | 13个 | 15个 | 0 | 0 | 0 |
| **内置工具** | **53个 + MCP + A2A** | 50+ | 12个 | 插件 | MCP | LC工具 |
| **内存** | **SQLite + 向量** | 基于文件 | SQLite FTS5 | 4层 | 外部 | 检查点 |
| **桌面应用** | **Tauri 2.0** | 无 | 无 | 无 | Studio | 无 |
| **审计追踪** | **Merkle哈希链** | 日志 | 日志 | 追踪 | 日志 | 检查点 |
| **冷启动** | **<200ms** | ~6s | ~10ms | ~3s | ~4s | ~2.5s |
| **安装大小** | **~32 MB** | ~500 MB | ~8.8 MB | ~100 MB | ~200 MB | ~150 MB |
| **许可证** | MIT | MIT | MIT | MIT | Apache 2.0 | MIT |

---

## 16层安全系统——深度防御

OpenFang不是事后才添加安全功能。每一层都是独立可测试的，没有单点故障。

| # | 系统 | 功能描述 |
|---|--------|-------------|
| 1 | **WASM双计量沙箱** | 工具代码在WebAssembly中运行，具有燃料计量+纪元中断。看门狗线程终止失控代码。 |
| 2 | **Merkle哈希链审计追踪** | 每个操作都与前一个操作密码学链接。篡改一个条目，整个链就会断裂。 |
| 3 | **信息流污点追踪** | 标签在执行过程中传播——秘密从源头到接收端都被跟踪。 |
| 4 | **Ed25519签名智能体清单** | 每个智能体身份和能力集都经过密码学签名。 |
| 5 | **SSRF防护** | 阻止私有IP、云元数据端点和DNS重绑定攻击。 |
| 6 | **秘密清零** | `Zeroizing<String>`在API密钥不再需要时自动从内存中擦除。 |
| 7 | **OFP相互认证** | HMAC-SHA256基于随机数的P2P网络恒定时间验证。 |
| 8 | **能力门控** | 基于角色的访问控制——智能体声明所需工具，内核强制执行。 |
| 9 | **安全头** | CSP、X-Frame-Options、HSTS、X-Content-Type-Options在每个响应上。 |
| 10 | **健康端点脱敏** | 公共健康检查返回最少信息。完整诊断需要认证。 |
| 11 | **子进程沙箱** | `env_clear()` + 选择性变量传递。跨平台终止的进程树隔离。 |
| 12 | **提示注入扫描器** | 检测覆盖尝试、数据外泄模式和技能中的shell引用注入。 |
| 13 | **循环防护** | 基于SHA256的工具调用循环检测与断路器。处理乒乓模式。 |
| 14 | **会话修复** | 7阶段消息历史验证和自动从损坏中恢复。 |
| 15 | **路径遍历防护** | 带符号链接逃逸防护的规范化。`../`在这里不起作用。 |
| 16 | **GCRA速率限制器** | 成本感知令牌桶速率限制，具有每IP跟踪和过期清理。 |

---

## 架构

14个Rust crate。137,728行代码。模块化内核设计。

```
openfang-kernel      编排、工作流、计量、RBAC、调度器、预算跟踪
openfang-runtime    智能体循环、3个LLM驱动、53个工具、WASM沙箱、MCP、A2A
openfang-api        140+ REST/WS/SSE端点、OpenAI兼容API、仪表板
openfang-channels   40个消息适配器，带速率限制、DM/组策略
openfang-memory     SQLite持久化、向量嵌入、规范会话、压缩
openfang-types      核心类型、污点追踪、Ed25519清单签名、模型目录
openfang-skills     60个捆绑技能、SKILL.md解析器、FangHub市场
openfang-hands      7个自主Hands、HAND.toml解析器、生命周期管理
openfang-extensions 25个MCP模板、AES-256-GCM凭保险库、OAuth2 PKCE
openfang-wire       OFP P2P协议，带HMAC-SHA256相互认证
openfang-cli        带守护进程管理的CLI、TUI仪表板、MCP服务器模式
openfang-desktop    Tauri 2.0原生应用（系统托盘、通知、全局快捷键）
openfang-migrate    OpenClaw、LangChain、AutoGPT迁移引擎
xtask               构建自动化
```

---

## 40个通道适配器

将您的智能体连接到用户所在的每个平台。

**核心：** Telegram、Discord、Slack、WhatsApp、Signal、Matrix、Email（IMAP/SMTP）
**企业：** Microsoft Teams、Mattermost、Google Chat、Webex、飞书/Lark、Zulip
**社交：** LINE、Viber、Facebook Messenger、Mastodon、Bluesky、Reddit、LinkedIn、Twitch
**社区：** IRC、XMPP、Guilded、Revolt、Keybase、Discourse、Gitter
**隐私：** Threema、Nostr、Mumble、Nextcloud Talk、Rocket.Chat、Ntfy、Gotify
**工作场所：** Pumble、Flock、Twist、钉钉、Zalo、Webhooks

每个适配器支持每通道模型覆盖、DM/组策略、速率限制和输出格式化。

---

## 27个LLM提供商 — 123+模型

3个原生驱动（Anthropic、Gemini、OpenAI兼容）路由到27个提供商：

Anthropic、Gemini、OpenAI、Groq、DeepSeek、OpenRouter、Together、Mistral、Fireworks、Cohere、Perplexity、xAI、AI21、Cerebras、SambaNova、HuggingFace、Replicate、Ollama、vLLM、LM Studio、Qwen、MiniMax、智谱AI、Moonshot、千帆、Bedrock等。

智能路由，具有任务复杂度评分、自动回退、成本跟踪和每模型定价。

---

## 从OpenClaw迁移

已经在运行OpenClaw？一个命令：

```bash
# 迁移所有内容 — 智能体、内存、技能、配置
openfang migrate --from openclaw

# 从特定路径迁移
openfang migrate --from openclaw --path ~/.openclaw

# 先进行试运行查看将更改的内容
openfang migrate --from openclaw --dry-run
```

迁移引擎导入您的智能体、对话历史、技能和配置。OpenFang原生读取SKILL.md并与ClawHub市场兼容。

---

## OpenAI兼容API

直接替代。将您现有的工具指向OpenFang：

```bash
curl -X POST localhost:4200/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "researcher",
    "messages": [{"role": "user", "content": "分析Q4市场趋势"}],
    "stream": true
  }'
```

140+ REST/WS/SSE端点，涵盖智能体、内存、工作流、通道、模型、技能、A2A、Hands等。

---

## 快速开始

```bash
# 1. 安装（macOS/Linux）
curl -fsSL https://openfang.sh/install | sh

# 2. 初始化 — 引导您完成提供商设置
openfang init

# 3. 启动守护进程
openfang start

# 4. 仪表板运行在 http://localhost:4200

# 5. 激活一个Hand — 它开始为您工作
openfang hand activate researcher

# 6. 与智能体聊天
openfang chat researcher
> "AI智能体框架有哪些新兴趋势？"

# 7. 生成预构建智能体
openfang agent spawn coder
```

<details>
<summary><strong>Windows (PowerShell)</strong></summary>

```powershell
irm https://openfang.sh/install.ps1 | iex
openfang init
openfang start
```

</details>

---

## 开发

```bash
# 构建工作区
cargo build --workspace --lib

# 运行所有测试（1,767+）
cargo test --workspace

# 代码检查（必须为0警告）
cargo clippy --workspace --all-targets -- -D warnings

# 格式化
cargo fmt --all -- --check
```

---

## 稳定性说明

OpenFang v0.1.0是第一个公开版本。架构稳固，测试套件全面，安全模型完善。但请注意：

- **破坏性更改**可能在v1.0之前的次要版本之间发生
- **某些Hands**比其他更成熟（Browser和Researcher是经过最多实战测试的）
- **边缘情况**存在——如果您发现一个，[请提交问题](https://github.com/RightNow-AI/openfang/issues)
- **固定到特定提交**用于生产部署，直到v1.0

我们快速发布并快速修复。目标是在2026年中期实现坚如磐石的v1.0。

---

## 许可证

MIT — 随意使用。

---

## 链接

- [网站与文档](https://openfang.sh)
- [快速开始指南](https://openfang.sh/docs/getting-started)
- [GitHub](https://github.com/RightNow-AI/openfang)
- [Discord](https://discord.gg/sSJqgNnq6X)
- [Twitter / X](https://x.com/openfangg)

---

## 由RightNow构建

<p align="center">
  <a href="https://www.rightnowai.co/">
    <img src="public/assets/rightnow-logo.webp" width="60" alt="RightNow Logo" />
  </a>
</p>

<p align="center">
  OpenFang由<a href="https://x.com/Akashi203"><strong>Jaber</strong></a>构建和维护，他是<a href="https://www.rightnowai.co/"><strong>RightNow</strong></a>的创始人。
</p>

<p align="center">
  <a href="https://www.rightnowai.co/">网站</a> &bull;
  <a href="https://x.com/Akashi203">Twitter / X</a> &bull;
  <a href="https://www.buymeacoffee.com/openfang" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 60px !important;width: 217px !important;" ></a>
</p>

---

<p align="center">
  <strong>用Rust构建。16层安全保障。真正为您工作的智能体。</strong>
</p>