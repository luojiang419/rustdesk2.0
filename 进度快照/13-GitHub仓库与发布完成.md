# 13-GitHub仓库与发布完成

## 已完成内容
- 读取最新接力基线：`进度快照/12-ping延迟测速版重新编译完成.md`。
- 使用 GitHub 账号 `luojiang419` 创建私有主仓库：
  - `https://github.com/luojiang419/rustdesk2.0`
- 发现 `libs/hbb_common` 是 dirty 子模块，直接推主仓库会丢失子模块本地改动。
- 为保存完整源码，创建私有子模块仓库：
  - `https://github.com/luojiang419/rustdesk2.0-hbb-common`
- 子模块提交并推送：
  - 分支：`rustdesk2.0-custom`
  - 提交：`92e1b92`
  - 内容：`libs/hbb_common/src/config.rs` 的 rustdesk2.0 配置、多服务器配置与自动切换相关改动。
- 主仓库 `.gitmodules` 已改为指向自有子模块仓库：
  - `https://github.com/luojiang419/rustdesk2.0-hbb-common.git`
  - 分支：`rustdesk2.0-custom`
- 主仓库源码已提交并推送：
  - 分支：`master`
  - 提交：`1fff0c92e`
- 创建 Windows x64 便携测试包：
  - `target/release-assets/rustdesk2.0-windows-x64-portable.zip`
  - 大小：31054075 字节，约 29.62 MB
- 创建 GitHub Release：
  - Tag：`v2.0-test-20260630-1405`
  - Release：`https://github.com/luojiang419/rustdesk2.0/releases/tag/v2.0-test-20260630-1405`
  - 附件：`rustdesk2.0-windows-x64-portable.zip`
  - 下载地址：`https://github.com/luojiang419/rustdesk2.0/releases/download/v2.0-test-20260630-1405/rustdesk2.0-windows-x64-portable.zip`

## 当前修改到哪个模块
- 当前模块：GitHub 建仓、源码推送、Release 发布。
- 当前状态：仓库与 Release 已创建，发布附件已上传。

## 具体修改的代码前后对比
- 本轮没有修改业务源码。
- 本轮修改了 `.gitmodules`，用于让主仓库指向已发布的自有 `hbb_common` 子模块。

修改前：
```gitconfig
[submodule "libs/hbb_common"]
	path = libs/hbb_common
	url = https://github.com/rustdesk/hbb_common
```

修改后：
```gitconfig
[submodule "libs/hbb_common"]
	path = libs/hbb_common
	url = https://github.com/luojiang419/rustdesk2.0-hbb-common.git
	branch = rustdesk2.0-custom
```

## 已验证结果
- `gh auth status`：已登录 `luojiang419`。
- 主仓库创建成功，Visibility：`PRIVATE`。
- 子模块仓库创建成功，子模块分支已推送。
- 主仓库 `master` 已推送到 `github-publish/master`。
- Release 创建成功，附件上传成功。
- Release 附件信息：
  - 名称：`rustdesk2.0-windows-x64-portable.zip`
  - 大小：31054075
  - SHA256：`26ae1c90c07302db725314be20d4564c32a76325c4387502b34d999ad2c4113e`

## 待办清单（未完成）
- 如需要公开仓库，可后续把主仓库和子模块仓库从 `PRIVATE` 改为 `PUBLIC`。
- 如需要正式 MSI 安装包，需要继续补 Windows MSI 打包链的 rustdesk2.0 命名隔离后再构建 MSI。

## 下一步要做什么
1. 打开 Release 页面下载 ZIP 包。
2. 解压 `rustdesk2.0-windows-x64-portable.zip`。
3. 运行里面的 `rustdesk2.0.exe` 进行测试。
