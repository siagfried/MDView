<div align="center">
  <img src="screenshots/icon-1024.png" width="150" alt="MDView">
  <h1>MDView</h1>
  <p><b>macOS 上轻量的 Markdown 阅读器</b><br>双击 <code>.md</code> 即读——完全离线、零运行时依赖、不弹授权</p>
  <p>Apple 芯片 · macOS 13+ · GPL-3.0</p>
</div>

---

## 为什么做它

macOS 自带的 Quick Look 不渲染 Markdown：按空格只看到原始文本，Finder 的预览窗格更会退化成一张缩略图。市面上常见的做法是装一个「快速查看扩展」（如 QLMarkdown），但有两个绕不开的代价：

1. **窗格与空格不可兼得**——只要有一个 appex 预览扩展声明了 `.md`，Finder 的检查器窗格就不再回退到系统文本预览，而 appex 的视图又渲染不到窗格里，最终显示一张缩小的页面图；
2. **双击打开仍要另找编辑器**——预览扩展不是阅读器，不能当默认打开程序。

于是就有了 MDView：一个**双击即读**的独立阅读器，**不依赖任何 Quick Look 预览扩展**，也不启动任何子进程。

## 特性

| 能力 | 说明 |
| --- | --- |
| Markdown 渲染 | GFM：表格、任务列表、脚注、自动链接、删除线等（markdown-it） |
| 代码高亮 | highlight.js（GitHub 明/暗主题，随外观切换） |
| 公式 | LaTeX，MathJax 3 **SVG 输出**——不需要外挂字体文件，离线可用 |
| 图表 | Mermaid 11，` ```mermaid ` 代码块直接出图 |
| 外观 | 明暗自适应（`prefers-color-scheme`），跟随系统 |
| 交互 | **一次选中多个 `.md` 双击，同一个窗口里读**，`←/→` 翻页（带防抖）；`⌘F` 查找；`⌘L` 钉住；**失焦即关**；`Esc` 关闭 |
| 体验 | 文件被外部修改**自动重载**；窗口位置记忆；触控板缩放 |
| 干净 | **不联网、不启动子进程、不索要「访问其他 App 的数据」授权** |
| 体积 | App 约 7 MB；MathJax/Mermaid 只在文档确实用到时才加载 |

## 安装

### 方式一：下载压缩包（推荐）

1. 到 [Releases](https://github.com/siagfried/MDView/releases) 下载最新的 **`MDView-x.y.z.zip`**
2. 解压，把 **MDView.app** 拖进「应用程序」
3. **首次打开**：在「应用程序」里对着 MDView.app **右键 → 打开 → 再点「打开」**

   > 本项目未做 Apple 公证（需付费开发者账号），所以首次会被 Gatekeeper 拦一次。
   > 如果连右键打开也被拒：**系统设置 → 隐私与安全性 → 找到 MDView → 点「仍要打开」**。只需一次。
4. 想让它接管 `.md` 双击：运行包内的 **`首次打开助手.command`**（右键 → 打开），它会自动解除隔离并把 `.md` 关联到 MDView。
   手动做法：右键任一 `.md` → 显示简介 → 打开方式选 MDView → **更改全部…**

> ### ⚠️ 关于 DMG
> Releases 里也提供 `MDView-x.y.z.dmg`，但 **macOS 15 起会直接拦截未公证的磁盘映像**——弹窗只给「完成 / 移到废纸篓」，**没有「打开」按钮**，所以推荐用压缩包。
> 如果确实想用 DMG，先在终端解除隔离再打开：
> ```sh
> xattr -dr com.apple.quarantine ~/Downloads/MDView-1.0.0.dmg
> open ~/Downloads/MDView-1.0.0.dmg
> ```

### 方式二：从源码构建

```sh
git clone https://github.com/siagfried/MDView.git
cd MDView
./build.sh                       # 生成 MDView.app（ad-hoc 签名）
./build.sh --sign "证书名称"      # 也可用自签/开发者证书签名
open MDView.app
```

需要 Xcode Command Line Tools：`xcode-select --install`。构建时会从 CDN 拉取前端库（版本锁定，见 `build.sh`）。

## 快捷键

| 操作 | 说明 |
| --- | --- |
| 双击 `.md` | 打开（多选后双击＝同一窗口打开多个） |
| `←` / `→` | 在多文件之间切换（长按不会连跳） |
| `⌘F` | 查找；`⌘G` / `⇧⌘G` 下一个 / 上一个；`Esc` 收起查找条 |
| `⌘L` | 钉住窗口：默认**失焦即关**，钉住后保留（此时自动重载才有意义） |
| `Esc` | 关闭窗口 |
| `⌘R` | 重新载入 |
| `⌘+` / `⌘−` / `⌘0` | 放大 / 缩小 / 实际大小（触控板双指缩放同样可用） |
| `⌘C` / `⌘A` | 拷贝选中文字 / 全选 |
| `⌘O` / `⌘W` / `⌘Q` | 打开 / 关窗 / 退出 |

## 一个窗口读多个文件

MDView 把「多文件」当一等公民：**在 Finder 里选中多个 `.md`（框选 / ⌘ 点选）后双击**，它们会在**同一个窗口**里打开，
标题栏显示 `文件名 — 3/7`，用 `←` / `→` 直接翻页 —— 不必开一堆窗口，也不用反复按空格。

| 行为 | 说明 |
| --- | --- |
| 一次开一批 | 选中多个 `.md` → 双击（或右键 → 打开方式 → MDView）；`⌘O` 多选、把文件拖到 Dock 图标同样可行 |
| 翻页 | `←` / `→` 切换，标题栏显示 `当前序号/总数` |
| **防连跳** | 两次翻页之间有 **250 ms 节流**，且长按方向键**只翻一次**（一次按键＝翻一个文件），不会一按就飞到底 |
| 失焦即关 | 默认窗口在失去焦点时自动关闭（Quick Look 式的「看完就走」）；想留着就按 `⌘L` 钉住 |
| 钉住后 | 窗口保留，且**文件被外部编辑器改动时会自动重载**——适合「在编辑器里写、旁边看排版」 |
| 再次打开 | 已开着窗口时再双击另一个 `.md`，窗口会**切换为那个文件**（替换当前列表，保持「快看快关」的语义） |
| 适用场景 | 对比多份文档、按顺序读一整个目录的说明文件、写文档时逐篇检查 |

> 如果更希望「再打开一个文件就**追加**到当前窗口列表，而不是替换」，可以提 issue，改动很小。

## 渲染效果

![渲染验证](screenshots/render-verify.png)

*同一套资源在无头 Chrome 中的离线验证截图：行内/块级公式、Mermaid 流程图、表格、代码高亮。*

## 已知限制

- 仅 **arm64**（Apple 芯片）；Intel Mac 请自行用 `swiftc -target x86_64-apple-macos13.0` 编译
- 要求 **macOS 13** 及以上
- **未做 Apple 公证**，首次打开需手动放行一次
- 纯阅读器，不含编辑功能

## 许可

本项目以 **GPL-3.0** 发布 —— 因为打包了 QLMarkdown 的 `default.css`（GPL-3.0）。第三方组件与完整许可说明见 [THIRD-PARTY.md](THIRD-PARTY.md)。

## 致谢

- [QLMarkdown](https://github.com/sbarex/QLMarkdown)（sbarex）—— 样式表 `default.css` 与「用 Quick Look 看 Markdown」的先行实践
- [markdown-it](https://github.com/markdown-it/markdown-it) · [highlight.js](https://highlightjs.org/) · [MathJax](https://www.mathjax.org/) · [mermaid](https://mermaid.js.org/)

---

## English

**MDView** is a lightweight, fully-offline Markdown **reader** for macOS (Apple silicon, macOS 13+).

Double-click a `.md` file and read it rendered — GFM tables, syntax-highlighted code (highlight.js), LaTeX math (MathJax, SVG output) and Mermaid diagrams. **Select several `.md` files and double-click — they all open in one window**, with debounced `←/→` paging (long-press steps one file at a time). `⌘F` to search; `⌘L` to pin (by default the window closes when it loses focus, Quick-Look style).

It does **not** use Quick Look preview extensions and spawns **no subprocesses**, so macOS never asks for *"access data from other apps"* — a limitation that made child-process rendering unusable in earlier iterations.

Install: grab the **ZIP** from Releases (recommended — macOS 15+ blocks unnotarized DMGs), unzip, drag the app to `/Applications`, then **right-click → Open** the first time (the app is not notarized). Build from source with `./build.sh`.

Licensed under **GPL-3.0** (the bundled `default.css` comes from QLMarkdown, which is GPL-3.0). See [THIRD-PARTY.md](THIRD-PARTY.md).
