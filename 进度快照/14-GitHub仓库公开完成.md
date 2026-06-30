# 14-GitHub仓库公开完成

## 已完成内容
- 读取最新接力基线：`进度快照/13-GitHub仓库与发布完成.md`。
- 公开前检查 GitHub 当前状态：
  - 主仓库：`luojiang419/rustdesk2.0`，原状态 `PRIVATE`。
  - 子模块仓库：`luojiang419/rustdesk2.0-hbb-common`，原状态 `PRIVATE`。
- 发现 `docs/远程服务器.md` 已被 Git 跟踪，且私有发布历史中包含真实服务器地址和 key。
- 公开前已脱敏 `docs/远程服务器.md`，真实服务器地址和 key 不再保留在当前公开分支内容中。
- 创建本阶段备份说明：
  - `backup/7-GitHub公开脱敏阶段/备份说明.md`
  - 备份说明中的原始 key 已脱敏，避免二次泄露。
- 重写主仓库私有发布历史：
  - 新脱敏提交：`9be6ffb39`
  - `master` 已强制更新到 `9be6ffb39`
  - `v2.0-test-20260630-1405` 标签已强制更新到 `9be6ffb39`
- 验证远程 `master` 和 Release 标签均搜不到原始 key。
- 已将两个 GitHub 仓库调整为公开：
  - 主仓库：`https://github.com/luojiang419/rustdesk2.0`
  - 子模块仓库：`https://github.com/luojiang419/rustdesk2.0-hbb-common`
- Release 保持可用：
  - `https://github.com/luojiang419/rustdesk2.0/releases/tag/v2.0-test-20260630-1405`
  - 附件：`rustdesk2.0-windows-x64-portable.zip`
  - SHA256：`26ae1c90c07302db725314be20d4564c32a76325c4387502b34d999ad2c4113e`

## 当前修改到哪个模块
- 当前模块：GitHub 仓库公开与公开前脱敏。
- 当前状态：主仓库和子模块仓库均已公开，Release 标签已指向脱敏提交。

## 具体修改的代码前后对比

修改文件：`docs/远程服务器.md`

修改前：

```text
<真实服务器地址 1>
key：<已脱敏>

<真实服务器地址 2>
key：<已脱敏>
```

修改后：

```text
# 远程服务器配置

公开仓库不保存真实服务器地址和 key。

本地测试时请在私有文档或本机配置中记录：

ID Server: <your-id-server>
Relay Server: <your-relay-server>
Key: <your-server-public-key>
```

## 已验证结果
- `gh repo view luojiang419/rustdesk2.0 --json visibility,url`：`PUBLIC`。
- `gh repo view luojiang419/rustdesk2.0-hbb-common --json visibility,url`：`PUBLIC`。
- `git ls-remote github-publish refs/heads/master refs/tags/v2.0-test-20260630-1405`：两个引用均指向 `9be6ffb39`。
- `git grep` 检查远程 `master` 引用：未匹配原始 key。
- `git grep` 检查 Release 标签引用：未匹配原始 key。

## 待办清单（未完成）
- 如需要正式 MSI 安装包，需要继续补 Windows MSI 打包链的 rustdesk2.0 命名隔离后再构建 MSI。
- 如果原始服务器 key 已用于生产环境，建议在服务端轮换 key，公开前私有历史曾短暂推送过原始值。

## 下一步要做什么
1. 在浏览器打开公开主仓库确认页面可访问。
2. 在 Release 页面下载 `rustdesk2.0-windows-x64-portable.zip` 继续测试。
3. 如需正式安装包，继续处理 MSI 打包。
