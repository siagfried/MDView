import Cocoa
import WebKit

// MARK: - 渲染：完全在进程内完成（WebKit + markdown-it + highlight.js）
// 不启动任何子进程 —— 因此不触发 macOS 的「访问其他 App 的数据」授权。

var assetCache: [String: String] = [:]

func asset(_ name: String) -> String {
    if let hit = assetCache[name] { return hit }
    let value = loadAsset(name)
    assetCache[name] = value
    return value
}

func loadAsset(_ name: String) -> String {
    guard let url = Bundle.main.resourceURL?.appendingPathComponent(name),
          let text = try? String(contentsOf: url, encoding: .utf8) else { return "" }
    return text
}

func readMarkdown(_ url: URL) -> String {
    if let s = try? String(contentsOf: url, encoding: .utf8) { return s }
    var enc: UInt = 0
    if let s = try? NSString(contentsOf: url, usedEncoding: &enc) { return s as String }
    return ""
}

func escapeHTML(_ s: String) -> String {
    return s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
}

func buildPage(markdown: String, title: String) -> String {
    let baseCSS = asset("default.css")                  // QLMarkdown 样式（含明暗两套变量）
    let hlLight = asset("hljs-github.min.css")
    let hlDark  = asset("hljs-github-dark.min.css")
    let mditJS  = asset("markdown-it.min.js")
    let hljsJS  = asset("highlight.min.js")
    let b64     = Data(markdown.utf8).base64EncodedString()

    // 按需装载重库：没有公式/图表就不加载，保持常规文档轻快
    let needsMath    = markdown.contains("$") || markdown.contains("\\(") || markdown.contains("\\[")
    let needsMermaid = markdown.contains("```mermaid") || markdown.contains("~~~mermaid")

    var heavyLibs = ""
    if needsMath {
        heavyLibs += """
        <script>
        window.MathJax = {
          tex: { inlineMath: [['$','$']], displayMath: [['$$','$$']], processEscapes: true },
          svg: { fontCache: 'global' },
          options: { skipHtmlTags: ['script','noscript','style','textarea','pre','code'] }
        };
        </script>
        <script>\(asset("mathjax-tex-svg.js"))</script>
        """
    }
    if needsMermaid {
        heavyLibs += "<script>\(asset("mermaid.min.js"))</script>\n"
    }

    return """
    <!doctype html>
    <html><head><meta charset='utf-8'>
    <meta name='viewport' content='width=device-width, initial-scale=1.0'>
    <title>\(escapeHTML(title))</title>
    <style>\(baseCSS)</style>
    <style>\(hlLight)</style>
    <style>@media (prefers-color-scheme: dark) { \(hlDark) }</style>
    <style>
      html, body { margin: 0; padding: 0; background: var(--background); }
      article.markdown-body { padding: 28px 34px 64px; }
      pre.hljs, pre { background: var(--hl_Background); border-radius: 6px; padding: 16px; overflow: auto; }
      pre code.hljs { padding: 0; background: transparent; }
      article.markdown-body :not(pre) > code { background: var(--code-background); border-radius: 6px; padding: .2rem .4rem; font-size: 85%; }
      img { max-width: 100%; }
      .mermaid { text-align: center; margin: 16px 0; }
      .mermaid svg { max-width: 100%; height: auto; }
    </style>
    </head>
    <body>
    <article class='markdown-body' id='mdview-content'></article>
    <script>\(mditJS)</script>
    <script>\(hljsJS)</script>
    \(heavyLibs)
    <script>
    (function () {
      var bytes = Uint8Array.from(atob('\(b64)'), function (c) { return c.charCodeAt(0); });
      var text  = new TextDecoder('utf-8').decode(bytes);
      var md = markdownit({ html: true, linkify: true, breaks: false,
        highlight: function (str, lang) {
          if (lang === 'mermaid') {
            return '<div class="mermaid">' + md.utils.escapeHtml(str) + '</div>';
          }
          if (lang && hljs.getLanguage(lang)) {
            try { return '<pre class="hljs"><code>' + hljs.highlight(str, { language: lang, ignoreIllegals: true }).value + '</code></pre>'; } catch (e) {}
          }
          return '<pre class="hljs"><code>' + md.utils.escapeHtml(str) + '</code></pre>';
        }
      });
      var el = document.getElementById('mdview-content');
      el.innerHTML = md.render(text);

      // Mermaid 图
      try {
        if (window.mermaid) {
          mermaid.initialize({ startOnLoad: false, securityLevel: 'strict',
            theme: window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'default' });
          var nodes = document.querySelectorAll('.mermaid');
          if (nodes.length) { mermaid.run({ nodes: nodes }); }
        }
      } catch (e) { console.error('mermaid error: ' + e); }

      // LaTeX 公式（MathJax，SVG 输出，无需字体文件）
      try {
        if (window.MathJax && MathJax.startup) {
          MathJax.startup.promise
            .then(function () { return MathJax.typesetPromise([el]); })
            .catch(function (e) { console.error('mathjax error: ' + e); });
        }
      } catch (e) { console.error('mathjax error: ' + e); }
    })();
    </script>
    </body></html>
    """
}

// MARK: - 单窗口阅读器（多文件 ←/→ 切换 · ⌘F 查找 · 失焦即关 / ⌘L 钉住）
final class ViewerWindowController: NSWindowController, NSSearchFieldDelegate {
    private let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
    private let findBar = NSView()
    private let searchField = NSSearchField()
    private let statusLabel = NSTextField(labelWithString: "")
    private var findBarHeight: NSLayoutConstraint!
    private var files: [URL] = []
    private var index = 0
    private var watchSource: DispatchSourceFileSystemObject?
    private var watchFD: Int32 = -1
    private var lastNavTime = Date.distantPast
    private let navMinInterval: TimeInterval = 0.25
    var isPinned = false

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 800),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.setFrameAutosaveName("MDViewWindow")
        window.center()
        window.isReleasedWhenClosed = false
        window.title = "MDView"
        super.init(window: window)
        buildUI()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        guard let content = window?.contentView else { return }
        webView.allowsMagnification = true
        webView.translatesAutoresizingMaskIntoConstraints = false

        findBar.translatesAutoresizingMaskIntoConstraints = false
        findBar.wantsLayer = true
        findBar.layer?.masksToBounds = true
        findBar.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "查找…"
        searchField.delegate = self
        searchField.target = self
        searchField.action = #selector(findNext(_:))
        searchField.sendsSearchStringImmediately = true
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = .systemFont(ofSize: 11)

        let prevBtn = NSButton(title: "‹", target: self, action: #selector(findPrev(_:)))
        let nextBtn = NSButton(title: "›", target: self, action: #selector(findNext(_:)))
        for b in [prevBtn, nextBtn] { b.translatesAutoresizingMaskIntoConstraints = false; b.bezelStyle = .inline }
        let doneBtn = NSButton(title: "完成", target: self, action: #selector(hideFindBar))
        doneBtn.translatesAutoresizingMaskIntoConstraints = false
        doneBtn.bezelStyle = .inline

        findBar.addSubview(searchField); findBar.addSubview(prevBtn); findBar.addSubview(nextBtn)
        findBar.addSubview(statusLabel); findBar.addSubview(doneBtn)
        content.addSubview(findBar); content.addSubview(webView)

        findBarHeight = findBar.heightAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            findBarHeight,
            findBar.topAnchor.constraint(equalTo: content.topAnchor),
            findBar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            findBar.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            webView.topAnchor.constraint(equalTo: findBar.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: content.bottomAnchor),

            searchField.leadingAnchor.constraint(equalTo: findBar.leadingAnchor, constant: 10),
            searchField.centerYAnchor.constraint(equalTo: findBar.centerYAnchor),
            searchField.widthAnchor.constraint(equalToConstant: 240),
            prevBtn.leadingAnchor.constraint(equalTo: searchField.trailingAnchor, constant: 6),
            prevBtn.centerYAnchor.constraint(equalTo: findBar.centerYAnchor),
            nextBtn.leadingAnchor.constraint(equalTo: prevBtn.trailingAnchor, constant: 2),
            nextBtn.centerYAnchor.constraint(equalTo: findBar.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: nextBtn.trailingAnchor, constant: 8),
            statusLabel.centerYAnchor.constraint(equalTo: findBar.centerYAnchor),
            doneBtn.trailingAnchor.constraint(equalTo: findBar.trailingAnchor, constant: -10),
            doneBtn.centerYAnchor.constraint(equalTo: findBar.centerYAnchor)
        ])
    }

    // MARK: 文件列表与呈现
    func present(urls: [URL]) {
        files = urls; index = 0
        showCurrent()
    }
    /// 带节流的切换：250ms 内的重复请求直接丢弃，避免连跳
    func navigate(direction: Int) {
        guard files.count > 1 else { return }
        let now = Date()
        guard now.timeIntervalSince(lastNavTime) >= navMinInterval else { return }
        lastNavTime = now
        if direction > 0 { nextFile() } else { prevFile() }
    }

    @objc func nextFile() { guard files.count > 1 else { return }; index = (index + 1) % files.count; showCurrent() }
    @objc func prevFile() { guard files.count > 1 else { return }; index = (index - 1 + files.count) % files.count; showCurrent() }

    private func showCurrent() {
        guard files.indices.contains(index) else { return }
        let url = files[index]
        webView.loadHTMLString(buildPage(markdown: readMarkdown(url), title: url.lastPathComponent),
                               baseURL: url.deletingLastPathComponent())
        let n = files.count
        window?.title = n > 1 ? "\(url.lastPathComponent) — \(index + 1)/\(n)" : url.lastPathComponent
        window?.subtitle = n > 1 ? "← → 切换文件 · ⌘F 查找 · ⌘L \(isPinned ? "取消钉住" : "钉住") · Esc 关闭"
                                 : "⌘F 查找 · ⌘L \(isPinned ? "取消钉住" : "钉住") · Esc 关闭"
        restartWatch(url)
    }

    @objc func reload() {
        guard files.indices.contains(index) else { return }
        let url = files[index]
        webView.loadHTMLString(buildPage(markdown: readMarkdown(url), title: url.lastPathComponent),
                               baseURL: url.deletingLastPathComponent())
    }

    // MARK: 缩放
    @objc func zoomIn() { webView.pageZoom = min(webView.pageZoom * 1.15, 5.0) }
    @objc func zoomOut() { webView.pageZoom = max(webView.pageZoom / 1.15, 0.3) }
    @objc func zoomReset() { webView.pageZoom = 1.0 }

    // MARK: 查找
    @objc func showFindBar() {
        findBarHeight.constant = 36
        window?.makeFirstResponder(searchField)
        if !searchField.stringValue.isEmpty { runFind(backwards: false) }
    }
    @objc func hideFindBar() {
        findBarHeight.constant = 0
        statusLabel.stringValue = ""
        window?.makeFirstResponder(webView)
    }
    @objc func findNext(_ sender: Any?) { if findBarHeight.constant == 0 { showFindBar(); return }; runFind(backwards: false) }
    @objc func findPrev(_ sender: Any?) { if findBarHeight.constant == 0 { showFindBar(); return }; runFind(backwards: true) }

    private func runFind(backwards: Bool) {
        let q = searchField.stringValue
        guard !q.isEmpty else { statusLabel.stringValue = ""; return }
        let cfg = WKFindConfiguration()
        cfg.backwards = backwards
        cfg.wraps = true
        cfg.caseSensitive = false
        webView.find(q, configuration: cfg) { [weak self] result in
            self?.statusLabel.stringValue = result.matchFound ? "" : "未找到"
        }
    }
    func searchFieldDidStartSearching(_ sender: NSSearchField) { runFind(backwards: false) }

    // MARK: 钉住
    @objc func togglePin() {
        isPinned.toggle()
        if files.indices.contains(index) { showCurrent() }
    }

    /// 让窗口成为 key window 并把第一响应者交给 webView —— 打开即可全键盘操作
    func focus() {
        guard let w = window else { return }
        w.makeKeyAndOrderFront(nil)
        w.makeFirstResponder(webView)
    }

    func handleEscape() -> Bool {
        if findBarHeight.constant > 0 { hideFindBar(); return true }
        return false
    }

    // MARK: 文件变化监听
    private func restartWatch(_ url: URL) {
        watchSource?.cancel(); watchSource = nil
        if watchFD >= 0 { Darwin.close(watchFD); watchFD = -1 }
        watchFD = open(url.path, O_EVTONLY)
        guard watchFD >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: watchFD,
                                                            eventMask: [.write, .rename, .delete, .extend],
                                                            queue: .main)
        src.setEventHandler { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { self?.reload() }
        }
        src.setCancelHandler { [weak self] in
            guard let self = self, self.watchFD >= 0 else { return }
            Darwin.close(self.watchFD); self.watchFD = -1
        }
        src.resume()
        watchSource = src
    }
}

// MARK: - App
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var viewer: ViewerWindowController?
    private var hasBeenActive = false
    private var activeSince = Date.distantPast

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKey(event) ?? event
        }
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive),
                                               name: NSApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didResignActive),
                                               name: NSApplication.didResignActiveNotification, object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if self.viewer == nil {
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = true
                panel.canChooseDirectories = false
                if panel.runModal() == .OK { self.open(paths: panel.urls.map { $0.path }) }
                else { NSApp.terminate(nil) }
            }
        }
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        open(paths: filenames)
        sender.reply(toOpenOrPrint: .success)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { return true }

    private func open(paths: [String]) {
        let urls = paths.map { URL(fileURLWithPath: $0) }
        if viewer == nil { viewer = ViewerWindowController() }
        viewer?.present(urls: urls)
        viewer?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        viewer?.focus()
        // 启动早期 makeKey 有时不生效，下一轮 runloop 再补一次
        DispatchQueue.main.async { [weak self] in self?.viewer?.focus() }
    }

    @objc private func didBecomeActive() {
        hasBeenActive = true
        activeSince = Date()
        viewer?.focus()
    }

    @objc private func didResignActive() {
        guard hasBeenActive, let v = viewer, !v.isPinned else { return }
        // 豁免 1：刚获得焦点不到 1.5s —— 多半是启动瞬间的系统弹窗抢焦点
        if Date().timeIntervalSince(activeSince) < 1.5 { return }
        // 豁免 2：前台是系统授权/通知弹窗（如「访问其他 App 的数据」）
        if let bid = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           bid == "com.apple.UserNotificationCenter"
            || bid == "com.apple.securityagent"
            || bid == "com.apple.SecurityAgent"
            || bid == "com.apple.systempreferences" {
            return
        }
        v.close()
    }

    private func handleKey(_ event: NSEvent) -> NSEvent? {
        guard NSApp.isActive, NSApp.modalWindow == nil,
              let v = viewer, let win = v.window, win.isVisible else { return event }
        // 查找框内不拦截方向键
        if let fr = win.firstResponder as? NSTextView, fr.isFieldEditor { return event }
        switch event.keyCode {
        case 123, 124:                               // ← →
            if event.isARepeat { return nil }        // 长按只跳一次
            v.navigate(direction: event.keyCode == 124 ? 1 : -1)
            return nil
        case 53:                                     // Esc
            if v.handleEscape() { return nil }
            v.close(); return nil
        default: return event
        }
    }

    @objc private func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK { open(paths: panel.urls.map { $0.path }) }
    }
    @objc private func togglePin(_ sender: Any?) { viewer?.togglePin() }
    @objc private func showFind(_ sender: Any?) { viewer?.showFindBar() }
    @objc private func findNextItem(_ sender: Any?) { viewer?.findNext(nil) }
    @objc private func findPrevItem(_ sender: Any?) { viewer?.findPrev(nil) }

    @objc private func showAbout(_ sender: Any?) {
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: NSAttributedString(string: "Markdown 渲染引擎：QLMarkdown (sbarex)\n独立阅读器，不依赖 Quick Look 预览扩展。\n\n←/→ 切换文件 · ⌘F 查找 · ⌘L 钉住 · Esc 关闭",
                                         attributes: [.font: NSFont.systemFont(ofSize: 11)])
        ])
    }

    private func buildMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem(); main.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于 MDView", action: #selector(showAbout(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "隐藏 MDView", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "退出 MDView", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let fileItem = NSMenuItem(); main.addItem(fileItem)
        let fileMenu = NSMenu(title: "文件")
        fileMenu.addItem(withTitle: "打开…", action: #selector(openDocument(_:)), keyEquivalent: "o")
        fileMenu.addItem(withTitle: "重新载入", action: #selector(ViewerWindowController.reload), keyEquivalent: "r")
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileItem.submenu = fileMenu

        let editItem = NSMenuItem(); main.addItem(editItem)
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "查找…", action: #selector(showFind(_:)), keyEquivalent: "f")
        let next = editMenu.addItem(withTitle: "查找下一个", action: #selector(findNextItem(_:)), keyEquivalent: "g")
        let prev = editMenu.addItem(withTitle: "查找上一个", action: #selector(findPrevItem(_:)), keyEquivalent: "G")
        _ = next; _ = prev
        editItem.submenu = editMenu

        let viewItem = NSMenuItem(); main.addItem(viewItem)
        let viewMenu = NSMenu(title: "显示")
        viewMenu.addItem(withTitle: "放大", action: #selector(ViewerWindowController.zoomIn), keyEquivalent: "+")
        viewMenu.addItem(withTitle: "缩小", action: #selector(ViewerWindowController.zoomOut), keyEquivalent: "-")
        viewMenu.addItem(withTitle: "实际大小", action: #selector(ViewerWindowController.zoomReset), keyEquivalent: "0")
        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: "钉住窗口（失焦不关）", action: #selector(togglePin(_:)), keyEquivalent: "l")
        viewItem.submenu = viewMenu
        NSApp.mainMenu = main
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
