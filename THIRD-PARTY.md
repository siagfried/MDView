# 第三方组件与许可

MDView 自身以 **GPL-3.0** 发布（见 [LICENSE](LICENSE)）。之所以选择 GPL-3.0，是因为本项目打包了 QLMarkdown 的样式表 `default.css`，而 QLMarkdown 采用 GPL-3.0。

| 组件 | 版本 | 许可 | 用途 | 来源 |
| --- | --- | --- | --- | --- |
| QLMarkdown `default.css` | 1.5.5 | **GPL-3.0** | 预览排版样式（含明暗两套 CSS 变量） | https://github.com/sbarex/QLMarkdown |
| markdown-it | 14.3.2 | MIT | Markdown → HTML | https://github.com/markdown-it/markdown-it |
| highlight.js | 11.12.0 | BSD-3-Clause | 代码块语法高亮（含 GitHub 明/暗主题） | https://github.com/highlightjs/highlight.js |
| MathJax | 3.x (`tex-svg`) | Apache-2.0 | LaTeX 公式渲染（SVG 输出，无需字体文件） | https://github.com/mathjax/MathJax |
| mermaid | 11.x | MIT | 图表渲染（` ```mermaid `） | https://github.com/mermaid-js/mermaid |

上述组件均以**原样、未修改**的方式随 App 打包，且其许可与 GPL-3.0 兼容。

## 说明

- 前端库在构建时由 `build.sh` 从 jsDelivr 拉取（版本已锁定）。
- `Resources/default.css` 直接取自 QLMarkdown 发行包，未作修改；其版权归原作者 sbarex 所有。
- App 图标由本项目作者提供（AI 生成），不适用上述第三方许可。
- 如果你要在自己的项目中复用本仓库代码，请注意 QLMarkdown 样式表带来的 GPL-3.0 传染性：可考虑自行编写等价样式以改用 MIT 等宽松许可。
