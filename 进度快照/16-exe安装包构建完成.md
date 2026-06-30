# 16-exe安装包构建完成

## 已完成内容
- 读取最新接力基线：`进度快照/15-dist安装包整理完成.md`。
- 确认本机已有 Inno Setup 编译器：
  - `ISCC.exe`
- 新增 Windows EXE 安装器脚本：
  - `res/installer/windows/rustdesk2.0.iss`
- 安装器打包来源：
  - `flutter/build/windows/x64/runner/Release`
- 已成功生成 EXE 安装包：
  - `dist/rustdesk2.0-windows-x64-setup.exe`
- 已上传 EXE 安装包到 GitHub Release：
  - `https://github.com/luojiang419/rustdesk2.0/releases/download/v2.0-test-20260630-1405/rustdesk2.0-windows-x64-setup.exe`
- 创建本阶段备份说明：
  - `backup/9-exe安装包构建阶段/备份说明.md`

## 当前修改到哪个模块
- 当前模块：Windows EXE 安装包构建。
- 当前状态：EXE 安装包已在本地 `dist` 文件夹，同时已上传到 GitHub Release。

## 具体修改的代码前后对比

修改前：

```text
无独立 exe 安装器脚本，仅有便携 ZIP 包。
```

修改后：

```text
res/installer/windows/rustdesk2.0.iss
```

关键配置：

```ini
AppName=RustDesk2.0
DefaultDirName={autopf}\RustDesk2.0
OutputDir=..\..\..\dist
OutputBaseFilename=rustdesk2.0-windows-x64-setup
Source: "..\..\..\flutter\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
```

安装器行为：
- 默认安装到 `Program Files/RustDesk2.0`。
- 创建开始菜单快捷方式。
- 可选创建桌面快捷方式。
- 安装完成后可选择启动 `rustdesk2.0.exe`。

## 已验证结果
- Inno Setup 编译成功。
- 本地 EXE 安装包存在：
  - `dist/rustdesk2.0-windows-x64-setup.exe`
- 文件大小：`21322895` 字节。
- SHA256：`557D08341E2DA054E064853BF15BE668E5C3B36EA6B279B31B8B992BC820C6CA`。
- Release 目录源文件统计：
  - 文件数：`91`
  - 总大小：`71103434` 字节。
- GitHub Release 已出现两个附件：
  - `rustdesk2.0-windows-x64-portable.zip`
  - `rustdesk2.0-windows-x64-setup.exe`

## 待办清单（未完成）
- 当前 EXE 安装器未做代码签名，Windows 可能显示未知发布者提示。
- 如后续需要中文安装界面，需要修复本机 Inno Setup 的 `ChineseSimplified.isl` 语言文件后再启用。

## 下一步要做什么
1. 双击 `dist/rustdesk2.0-windows-x64-setup.exe` 测试安装流程。
2. 安装完成后启动 `RustDesk2.0`，继续检查中继服务器延迟显示。
