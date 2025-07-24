import SwiftUI
import AppKit
import Cocoa
import ApplicationServices

// MARK: - Main App
@main
struct clipboardMGRApp: App {
    @StateObject private var clipboardManager = ClipboardManager()
    
    var body: some Scene {
        MenuBarExtra("剪贴板管理器", systemImage: "doc.on.clipboard") {
            CumulativeClipboardMenuView()
                .environmentObject(clipboardManager)
        }
        .menuBarExtraStyle(.menu)
    }
}

// MARK: - ClipboardManager
class ClipboardManager: ObservableObject {
    // Published properties for UI binding
    @Published var isAppendingEnabled: Bool = true {
        didSet {
            if isAppendingEnabled {
                startMonitoring()
            } else {
                stopMonitoring()
                // 禁用时清除累积文本，恢复正常剪贴板行为
                cumulativeText = ""
            }
        }
    }
    
    @Published var isClearOnPasteEnabled: Bool = false
    @Published var isNewlineEnabled: Bool = true
    @Published var cumulativeText: String = ""
    
    // Internal properties
    private var clipboardTimer: Timer?
    private var lastChangeCount: Int = 0
    private var keyDownMonitor: Any?
    private let pasteboard = NSPasteboard.general
    
    // 窗口管理
    internal var mainWindow: NSWindow?
    internal weak var windowDelegate: MainWindowDelegate?
    
    init() {
        // 初始化时获取当前剪贴板状态
        lastChangeCount = pasteboard.changeCount
        setupKeyDownMonitor()
        startMonitoring()
        
        print("✅ ClipboardManager 初始化完成")
        
        // 延迟启动主界面，避免启动时的资源竞争
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.openMainWindow()
        }
    }
    
    deinit {
        print("🧹 ClipboardManager 正在清理资源")
        stopMonitoring()
        removeKeyDownMonitor()
        
        // 清理窗口引用
        if let window = mainWindow {
            window.close()
            mainWindow = nil
        }
        windowDelegate = nil
        
        print("✅ ClipboardManager 资源清理完成")
    }
    
    // MARK: - Clipboard Monitoring
    
    /// 开始监控剪贴板变化
    func startMonitoring() {
        guard isAppendingEnabled else { return }
        
        // 停止之前的定时器（如果存在）
        stopMonitoring()
        
        // 创建新的定时器，每0.5秒检查一次剪贴板
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
        
        print("剪贴板监控已启动")
    }
    
    /// 停止监控剪贴板变化
    func stopMonitoring() {
        clipboardTimer?.invalidate()
        clipboardTimer = nil
        print("剪贴板监控已停止")
    }
    
    /// 检查剪贴板是否有变化
    private func checkPasteboard() {
        // 1. 检查是否有变化
        guard pasteboard.changeCount != lastChangeCount else { return }
        
        print("--- 检测到变化! 当前 changeCount: \(pasteboard.changeCount), 上次处理: \(lastChangeCount) ---")
        
        // 2. 尝试读取字符串
        guard let newString = pasteboard.string(forType: .string), !newString.isEmpty else {
            print("剪贴板内容不是字符串或为空，忽略")
            lastChangeCount = pasteboard.changeCount
            return
        }
        
        print("剪贴板内容: \"\(newString.prefix(50))\(newString.count > 50 ? "..." : "")\"")
        print("内部缓冲区: \"\(cumulativeText.prefix(50))\(cumulativeText.count > 50 ? "..." : "")\"")
        
        // 3. 🔑 核心防护：如果剪贴板内容与我们的累积内容完全相同，说明是自己写入的，直接忽略
        if newString == cumulativeText {
            print("❗️ 检测到循环并已阻止。内容是自生成的，忽略处理")
            lastChangeCount = pasteboard.changeCount
            return
        }
        
        // 4. 如果功能开启，则执行累加
        if isAppendingEnabled {
            print("✅ 追加新内容")
            
            if cumulativeText.isEmpty {
                cumulativeText = newString
            } else {
                // 根据换行设置决定如何连接文本
                if isNewlineEnabled {
                    cumulativeText += "\n" + newString
                } else {
                    cumulativeText += newString
                }
            }
            
            // 更新剪贴板
            pasteboard.clearContents()
            pasteboard.setString(cumulativeText, forType: .string)
            
            print("🚀 已写入剪贴板 (长度: \(cumulativeText.count))")
        } else {
            print("累积功能已禁用，忽略")
        }
        
        // 5. 关键：在所有操作完成后，将 changeCount 更新为最新值
        lastChangeCount = pasteboard.changeCount
        print("--- 循环结束。已更新 lastChangeCount 为: \(lastChangeCount) ---\n")
    }
    
    // MARK: - Key Event Monitoring
    
    /// 设置全局键盘事件监控（监听 Cmd+V）
    private func setupKeyDownMonitor() {
        // 检查是否有辅助功能权限
        let trusted = AXIsProcessTrusted()
        if !trusted {
            print("⚠️ 警告：需要辅助功能权限才能监听全局键盘事件")
            print("请在 系统偏好设置 > 安全性与隐私 > 隐私 > 辅助功能 中添加此应用")
        }
        
        keyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // 检查是否按下了 Command+V
            // 'v' 键的键码是 9
            if event.modifierFlags.contains(.command) && event.keyCode == 9 {
                print("🎯 检测到 Cmd+V 粘贴操作")
                self?.handlePasteEvent()
            }
        }
        
        if trusted {
            print("✅ 全局键盘监控已设置（有辅助功能权限）")
        } else {
            print("⚠️ 全局键盘监控已设置（但缺少辅助功能权限，可能无法正常工作）")
        }
    }
    
    /// 移除全局键盘事件监控
    private func removeKeyDownMonitor() {
        if let monitor = keyDownMonitor {
            NSEvent.removeMonitor(monitor)
            keyDownMonitor = nil
            print("全局键盘监控已移除")
        }
    }
    
    /// 处理粘贴事件
    func handlePasteEvent() {
        print("🔍 粘贴事件触发 - 检查条件:")
        print("   - isClearOnPasteEnabled: \(isClearOnPasteEnabled)")
        print("   - isAppendingEnabled: \(isAppendingEnabled)")
        
        guard isClearOnPasteEnabled && isAppendingEnabled else { 
            print("❌ 粘贴后清除条件不满足，跳过清除")
            return 
        }
        
        print("✅ 条件满足，将在0.2秒后清除累积文本")
        // 延迟清除，确保粘贴操作完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self else { return }
            print("🧹 执行粘贴后清除操作")
            self.clear()
        }
    }
    
    /// 打开主界面
    func openMainWindow() {
        // 如果窗口已存在且有效，直接显示
        if let existingWindow = mainWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            print("✅ 显示已存在的窗口")
            return
        }
        
        // 创建新窗口
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            print("🪟 创建新的主界面窗口")
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            
            window.title = "剪贴板管理器设置"
            window.center()
            
            // 创建窗口委托来管理窗口生命周期
            let delegate = MainWindowDelegate(clipboardManager: self)
            self.windowDelegate = delegate
            window.delegate = delegate
            
            // 设置窗口内容
            window.contentView = NSHostingView(rootView: MainWindowView().environmentObject(self))
            
            // 保存窗口引用
            self.mainWindow = window
            
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            
            print("✅ 新窗口创建完成")
        }
    }
    
    // MARK: - Public Methods
    
    /// 清除累积文本和系统剪贴板
    func clear() {
        cumulativeText = ""
        pasteboard.clearContents()
        lastChangeCount = pasteboard.changeCount
        print("累积文本和剪贴板已清除")
    }
}

// MARK: - SwiftUI Menu View
struct CumulativeClipboardMenuView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 累积功能开关
            Button(action: {
                clipboardManager.isAppendingEnabled.toggle()
            }) {
                HStack {
                    Image(systemName: clipboardManager.isAppendingEnabled ? "checkmark" : "")
                        .frame(width: 16)
                    Text("启用累积复制")
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // 粘贴后清除开关
            Button(action: {
                clipboardManager.isClearOnPasteEnabled.toggle()
            }) {
                HStack {
                    Image(systemName: clipboardManager.isClearOnPasteEnabled ? "checkmark" : "")
                        .frame(width: 16)
                    Text("粘贴后清除")
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!clipboardManager.isAppendingEnabled)
            
            // 换行开关
            Button(action: {
                clipboardManager.isNewlineEnabled.toggle()
            }) {
                HStack {
                    Image(systemName: clipboardManager.isNewlineEnabled ? "checkmark" : "")
                        .frame(width: 16)
                    Text("内容间添加换行")
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!clipboardManager.isAppendingEnabled)
            
            Divider()
            
            // 打开主界面按钮
            Button("打开设置界面") {
                clipboardManager.openMainWindow()
            }
            
            // 手动清除按钮
            Button("清除累积文本") {
                clipboardManager.clear()
            }
            .disabled(!clipboardManager.isAppendingEnabled || clipboardManager.cumulativeText.isEmpty)
            
            Divider()
            
            // 显示当前累积文本状态（仅用于调试，可选）
            if !clipboardManager.cumulativeText.isEmpty {
                Text("当前累积: \(clipboardManager.cumulativeText.prefix(50))\(clipboardManager.cumulativeText.count > 50 ? "..." : "")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                Divider()
            }
            
            // 退出按钮
            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Main Window View
struct MainWindowView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 标题
            HStack {
                Image(systemName: "doc.on.clipboard")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("剪贴板管理器")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.bottom, 10)
            
            // 设置选项
            VStack(alignment: .leading, spacing: 15) {
                Text("设置选项")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 12) {
                    // 累积功能开关
                    Toggle("启用累积复制", isOn: $clipboardManager.isAppendingEnabled)
                        .toggleStyle(SwitchToggleStyle())
                    
                    if clipboardManager.isAppendingEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            // 粘贴后清除开关
                            Toggle("粘贴后清除", isOn: $clipboardManager.isClearOnPasteEnabled)
                                .toggleStyle(SwitchToggleStyle())
                                .padding(.leading, 20)
                            
                            // 换行开关
                            Toggle("内容间添加换行", isOn: $clipboardManager.isNewlineEnabled)
                                .toggleStyle(SwitchToggleStyle())
                                .padding(.leading, 20)
                        }
                        .transition(.opacity)
                    }
                }
            }
            
            Divider()
            
            // 当前状态
            VStack(alignment: .leading, spacing: 10) {
                Text("当前状态")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: clipboardManager.isAppendingEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(clipboardManager.isAppendingEnabled ? .green : .red)
                    Text(clipboardManager.isAppendingEnabled ? "累积模式已启用" : "累积模式已禁用")
                        .font(.body)
                }
                
                if clipboardManager.isAppendingEnabled && !clipboardManager.cumulativeText.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("当前累积内容:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ScrollView {
                            Text(clipboardManager.cumulativeText)
                                .font(.system(.body, design: .monospaced))
                                .padding(8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 100)
                    }
                }
            }
            
            Divider()
            
            // 操作按钮
            VStack(spacing: 8) {
                HStack {
                    Button("清除累积文本") {
                        clipboardManager.clear()
                    }
                    .disabled(!clipboardManager.isAppendingEnabled || clipboardManager.cumulativeText.isEmpty)
                    
                    Button("测试粘贴清除") {
                        // 手动触发粘贴后清除逻辑
                        clipboardManager.handlePasteEvent()
                    }
                    .disabled(!clipboardManager.isAppendingEnabled || !clipboardManager.isClearOnPasteEnabled)
                }
                
                HStack {
                    Spacer()
                    Button("关闭") {
                        if let window = NSApplication.shared.keyWindow {
                            window.close()
                        }
                    }
                    .keyboardShortcut(.cancelAction)
                }
            }
            
            Spacer()
        }
        .padding(20)
        .frame(width: 400, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Preview
#Preview {
    CumulativeClipboardMenuView()
        .environmentObject(ClipboardManager())
}

#Preview("Main Window") {
    MainWindowView()
        .environmentObject(ClipboardManager())
}

// MARK: - Window Delegate
class MainWindowDelegate: NSObject, NSWindowDelegate {
    private weak var clipboardManager: ClipboardManager?
    
    init(clipboardManager: ClipboardManager) {
        self.clipboardManager = clipboardManager
        super.init()
    }
    
    func windowWillClose(_ notification: Notification) {
        print("🗂️ 主界面窗口即将关闭，清理资源")
        
        // 清理窗口引用，防止内存泄漏
        clipboardManager?.mainWindow = nil
        clipboardManager?.windowDelegate = nil
        
        // 清理引用
        clipboardManager = nil
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        print("🔑 主界面窗口获得焦点")
    }
    
    func windowDidResignKey(_ notification: Notification) {
        print("🔓 主界面窗口失去焦点")
    }
}
