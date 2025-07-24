# 剪贴板管理器 (ClipboardMGR)

一个强大的macOS剪贴板管理工具，支持累积复制、智能清除等功能。

## 🚀 功能特性

- **📋 累积复制**：自动将多次复制的内容累积到一起
- **🧹 智能清除**：粘贴后自动清除累积内容，恢复正常剪贴板行为
- **📝 灵活换行**：可选择在累积内容间添加换行符
- **🎯 菜单栏集成**：便捷的菜单栏访问，不占用Dock空间
- **⚡ 全局监听**：监听Cmd+V快捷键，实现粘贴后清除功能
- **🛡️ 沙盒安全**：使用App Sandbox保证系统安全

## 📱 界面预览

应用提供两种交互方式：
- **菜单栏菜单**：快速切换功能开关
- **设置界面**：详细的配置选项和状态显示

## 🔧 使用方法

### 基本操作

1. **启用累积复制**：在菜单栏中点击"启用累积复制"
2. **复制内容**：正常使用 `Cmd+C` 复制文本，每次复制的内容会自动累积
3. **粘贴内容**：使用 `Cmd+V` 粘贴所有累积的内容
4. **清除内容**：手动点击"清除累积文本"或启用"粘贴后清除"功能

### 高级功能

- **粘贴后清除**：启用后，粘贴操作完成后会自动清除累积内容
- **内容间添加换行**：在累积的文本间自动添加换行符，便于阅读
- **实时状态查看**：在设置界面查看当前累积的内容

## ⚙️ 系统要求

- macOS 10.15 或更高版本
- Xcode 12.0 或更高版本（开发环境）

## 🔐 权限说明

应用需要以下权限才能正常工作：

- **辅助功能权限**：用于监听全局快捷键（Cmd+V），实现粘贴后清除功能
  - 前往：系统偏好设置 > 安全性与隐私 > 隐私 > 辅助功能
  - 添加"剪贴板管理器"应用

## 🛠️ 开发与构建

### 环境准备

```bash
# 克隆项目
git clone <repository-url>
cd clipboardMGR

# 使用 Xcode 打开项目
open clipboardMGR.xcodeproj
```

### 构建步骤

1. 在 Xcode 中打开 `clipboardMGR.xcodeproj`
2. 选择目标设备（My Mac）
3. 点击 Run 按钮或使用 `Cmd+R` 运行

### 项目结构

```
clipboardMGR/
├── clipboardMGR/
│   ├── clipboardMGRApp.swift      # 主应用文件
│   ├── Assets.xcassets/           # 应用资源
│   └── clipboardMGR.entitlements  # 应用权限配置
├── clipboardMGRTests/             # 单元测试
├── clipboardMGRUITests/           # UI测试
└── clipboardMGR.xcodeproj/        # Xcode项目文件
```

## 🎯 核心技术

- **SwiftUI**：现代化的用户界面框架
- **AppKit**：macOS原生API集成
- **NSPasteboard**：系统剪贴板交互
- **Global Event Monitoring**：全局键盘事件监听
- **Timer**：定时检查剪贴板变化

## 🔄 工作原理

1. **监控机制**：使用Timer每0.5秒检查剪贴板的changeCount
2. **防循环机制**：通过内容比较避免处理自己生成的剪贴板内容
3. **累积逻辑**：新内容与已有内容合并，支持换行分隔
4. **清除机制**：监听全局Cmd+V事件，延迟清除累积内容

## 🐛 已知问题

- 需要手动授予辅助功能权限才能监听全局快捷键
- 在某些应用中粘贴大量文本可能会有延迟

## 📝 更新日志

### v1.0.0
- 初始版本发布
- 支持基本的累积复制功能
- 菜单栏集成
- 粘贴后清除功能

## 🤝 贡献

欢迎提交Issue和Pull Request！

1. Fork 项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 打开 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 📞 联系方式

如有问题或建议，请通过以下方式联系：

- 提交 GitHub Issue
- 发起 Pull Request

---

⭐ 如果这个项目对您有帮助，请给个Star支持！ 