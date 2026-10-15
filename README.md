# 右键小匣

右键，少一步。macOS 原生精简右键工具：进入 iTerm、新建 TXT、新建 Markdown、复制绝对路径、回到上级目录、剪切和粘贴移动。Finder 右键菜单中的 TXT 和 Markdown 操作统一放在「新建文件」二级菜单内。使用 Swift 6、AppKit 和 Finder Sync，无第三方依赖。

主程序采用薄荷绿品牌侧栏与卡片式详情页，集中展示扩展状态、操作目录、三个快捷入口及其他右键能力，并随系统适配深浅色外观。对外名称为「右键小匣」，内部工程名、构建产物路径、Bundle ID 和动作协议仍保留 FinderMenu。

## 构建与验证

需要 Apple Command Line Tools、Swift 6 和 macOS SDK，无需完整 Xcode。目标系统 macOS 13 及以上，构建产物使用运行构建脚本的 Mac 架构。

```bash
cd /Users/Admin/workspace/project/my/FinderMenu
bash Scripts/build.sh
bash Scripts/verify.sh
```

生成 `build/FinderMenu.app`，内含 `FinderMenuExtension.appex`。脚本使用 ad hoc 本地签名，不需要创建证书，不安装应用、不注册或启用扩展、不重启 Finder。

主程序与扩展通过 `Resources/zh-Hans.lproj/InfoPlist.strings` 显示「右键小匣」。未本地化的 `CFBundleDisplayName` 必须与包文件名匹配，不能直接改成中文，否则 Finder 会忽略本地化并显示英文文件名。`Scripts/generate-icon.swift` 使用 AppKit 绘制自有薄荷绿小匣子图标，构建时生成 16–1024 像素的标准及 Retina 图像，经系统 `iconutil` 打包为 `AppIcon.icns`，同时放入主程序和扩展。

当前产物面向本机自用，未公证，未做其他 Mac 或其他系统版本的运行验证。签名检查通过不代表 Finder 已加载扩展。

## 使用

安装和扩展启用需用户确认后进行：

1. 把 `build/FinderMenu.app` 放到 Applications，打开应用。
2. 点击主窗口的「管理扩展…」，在系统界面启用「右键小匣」。系统版本不同，扩展设置的位置可能不同。
3. 在访达文件夹空白处或文件、文件夹上右键，使用「进入终端」，或在「新建文件」二级菜单中选择 TXT、Markdown。

主程序窗口可通过原生文件夹选择面板选定目录，并使用「进入 iTerm」「新建 TXT」「新建 Markdown」三个快捷卡片。路径过长时居中省略，悬停可查看完整路径；下方展示其余右键功能的使用说明。关闭窗口后仍可从菜单栏重新打开；菜单栏提供退出入口。

- 右键空白处：操作当前文件夹。
- 右键单个文件夹：操作该文件夹。
- 右键单个文件或应用包：操作其父文件夹。
- 选择多个同级项目：操作共同的父文件夹。
- 新建文件：默认名称为「新建文件.txt」或「新建文件.md」，重名依次使用「新建文件 2.txt」等；保留已有文件、目录和符号链接。
- 文件创建成功后在访达中选中，便于继续重命名。
- 复制绝对路径：文件或文件夹右键复制所选项目自身的完整路径，空白处复制当前目录；多选同级项目时每行一个路径，保留中文、空格及特殊字符，不添加引号或转义。
- 回到上级目录：在 Finder 中打开右键目标绝对路径的父目录并选中原项目；空白处返回当前目录的上一层，多选同级项目时打开共同的父目录，根目录下不显示该菜单项。
- 剪切：选择文件或文件夹后右键，支持多选同级项目；点击时只记录路径，原项目保持原位，空白处和根目录不显示此项。
- 粘贴（移动）：剪切后，在目标文件夹上或目标目录空白处右键选择此项，成功后选中移动结果并清除记录。使用「右键小匣」的此菜单操作，普通系统粘贴不会执行移动。
- 移动前检查整批项目；同名项目（包括符号链接）、缺失源项目、原目录或目录自身及其子目录会阻止移动，不覆盖已有内容。移动途中发生错误会提示已完成数量，并保留未完成项目供重试。
- 复制其他内容（包括「复制绝对路径」）会取消待移动记录；再次剪切会替换记录。

「进入终端」使用本机安装的 iTerm，调用 `New iTerm2 Window Here` 系统服务，将目标目录作为文件路径列表传入。若未安装 iTerm 或系统禁用了服务，应用会提示安装或到键盘快捷键的服务设置中手动开启；工具不自动修改系统服务设置。

Finder 扩展声明监控根目录，以覆盖普通本地目录及挂载磁盘。系统是否对 iCloud 或受保护目录显示扩展菜单，需要在目标系统实测。没有权限的目录会报告错误。

## 实现

```text
Finder Sync 菜单
  → findermenu-local://action（动作＋编码后的目录路径）
  → 主程序验证请求与目录
    → iTerm：临时剪贴板文件路径列表＋NSPerformService
    → 新建文件：复制自有空白模板＋无覆盖重名编号
```

扩展启用 App Sandbox 和用户选择文件只读权限，主程序负责落盘；主程序为本地非沙盒应用。两者通过 URL 传递请求，不需要 App Groups 或共享容器。

剪切路径存入系统剪贴板的 FinderMenu 专用类型；粘贴通过 `findermenu-local://move` 携带记录 ID 和目标目录，主程序校验当前记录后使用 `FileManager.moveItem` 执行。移动整批项目并非事务操作，预检查通过后的中途错误可能留下部分完成结果，不自动回滚。

不执行拼接的 shell 命令，不使用辅助功能权限，不修改或依赖超级右键的安装包。

## 验证边界

自动验证覆盖 URL 请求、目录定位、中文与特殊字符路径、文件模板、重名保护、并发创建、剪切记录、批量移动、符号链接、目录关系、部分失败重试、bundle 声明和代码签名。名称与图标检查包含 FileManager 显示名、URL 本地化名称、图标声明、AppKit 解码、多分辨率完整性和资源一致性，不以单独读取 plist 代替系统名称检查。剪贴板测试使用独立测试剪贴板；测试文件保留在 `work/verification-*`，脚本不会删除目录。

此前本机安装版本已实测 Finder 文件、文件夹、空白处右键操作、二级菜单文件创建和重名文件保护；切换 iTerm 后已实测空白处「进入终端」，确认新会话工作目录正确。剪切移动已实测单选、多选、目标空白处及文件夹右键、同名冲突保护和复制取消。

2026-10-15 的中文命名与详情页改版已通过本地构建、74 项行为检查和 55 项原生界面检查：深浅色截图、长路径、省略布局、窗口缩放、键盘焦点、TXT/Markdown 实际创建、文件夹面板打开与取消、关闭后重新打开。界面验证使用项目内不含扩展的独立测试应用，没有安装或注册扩展。随后已按用户确认备份旧版并替换 Applications 中的应用；新版主程序与扩展已启动，中文显示名与签名检查通过，扩展仍为单份注册且启用，未重启 Finder 或更改系统设置。系统文件夹面板的真实点击确认、主窗口扩展状态展示及管理入口仍待人工实测。跨卷移动、iCloud 和受保护目录尚未实测。最新真实进度见 `ROADMAP.md`。

后续用户反馈系统管理扩展仍显示英文且无图标：此前仅验证 Bundle 名称不足以覆盖系统显示。现已补齐标准名称本地化及主包、扩展图标，90 项检查通过；构建号为 2，安装路径和内部标识不变。用户明确要求重新替换安装后，已备份旧版、更新并启动新版，安装版的 FileManager 中文名称、NSWorkspace 主程序及扩展图标、文件一致性和签名均已核验，扩展保持单份启用。仅刷新本应用及扩展进程，并发送安装包文件变更通知；未重启 Finder、清理系统缓存或修改系统设置。系统扩展管理页最终外观仍需用户重新打开后目视确认。

实现参考：

- [Apple Finder Sync 文档](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Finder.html) 。
- [Apple NSPerformService 文档](https://developer.apple.com/documentation/appkit/nsperformservice(_:_:)) 。
- [Apple 显示 Finder 项目文档](https://developer.apple.com/documentation/appkit/nsworkspace/activatefileviewerselecting(_:)) 。
- [Apple FileManager 移动文档](https://developer.apple.com/documentation/foundation/filemanager/moveitem(at:to:)) 。
