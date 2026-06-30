# 5-设置页卡片UI完成

## 已完成内容
- 完成 Flutter 网络服务器设置弹窗从单服务器表单到多服务器卡片管理器的改造。
- `showServerSettings` 打开后会读取 `server-profiles`；如果为空，会从 `G:\data\app\rustdesk\docs\远程服务器.md` 导入服务器配置并进行延迟测试。
- 弹窗右下角新增加号按钮，可新增服务器 profile。
- 服务器以卡片展示，显示名称、ID Server、Relay Server、API Server、启用状态，以及 `xx ms` / `Offline` / `Testing` / `Disabled` 状态。
- 卡片支持双击编辑，同时保留编辑图标，便于移动端操作。
- 编辑弹窗支持保存、删除、启用/禁用，并校验 ID / Relay / API 输入。
- 保留扫码导入入口 `showServerSettingsWithValue`，导入后以 profile 方式新增或按 ID Server 更新已有卡片。
- 新增 Web bridge 占位方法，避免 Web 侧缺少 profile FFI 方法。
- 运行 `flutter_rust_bridge_codegen 1.80.1` 生成本地桥接文件：
  - `flutter/lib/generated_bridge.dart`
  - `src/bridge_generated.rs`
  - `flutter/macos/Runner/bridge_generated.h`
  这些文件被项目 `.gitignore` 忽略，但当前工作区已生成。
- 安装缺失 LLVM，用于 `ffigen` 生成桥接绑定。

## 当前修改到哪个模块
- 当前完成：模块 4「设置页 UI」。
- 主要文件：
  - `flutter/lib/common.dart`
  - `flutter/lib/mobile/widgets/dialog.dart`
  - `flutter/lib/web/bridge.dart`
  - `flutter/test/server_settings_dialog_test.dart`

## 具体修改的代码前后对比

### 1. 旧入口：单服务器表单
修改前：
```dart
void showServerSettings(OverlayDialogManager dialogManager,
    void Function(VoidCallback) setState) async {
  Map<String, dynamic> options = {};
  try {
    options = jsonDecode(await bind.mainGetOptions());
  } catch (e) {
    print("Invalid server config: $e");
  }
  showServerSettingsWithValue(
      ServerConfig.fromOptions(options), dialogManager, setState);
}
```

修改后：
```dart
void showServerSettings(
  OverlayDialogManager dialogManager,
  void Function(VoidCallback) setState,
) async {
  var profiles = <ServerProfileConfig>[];
  var latencies = <String, ServerProfileLatency>{};
  var isLoading = true;
  var isTesting = false;
  var loadError = '';
  var started = false;

  // 首次打开时读取 profiles，空配置时导入 docs/远程服务器.md，并进行延迟测试。
  // 弹窗内容改为卡片列表 + 右下角 FloatingActionButton。
}
```

### 2. 新增 profile UI 模型和 FFI 包装
修改后新增：
```dart
class ServerProfileConfig {
  late String id;
  late String name;
  late String idServer;
  late String relayServer;
  late String apiServer;
  late String key;
  late bool enabled;
}

Future<List<ServerProfileConfig>> loadServerProfiles(
    {bool importDocIfEmpty = true}) async { ... }

Future<Map<String, ServerProfileLatency>> testServerProfiles(
    List<ServerProfileConfig> profiles) async { ... }
```

### 3. 新增 Web bridge 占位
修改后新增：
```dart
Future<String> mainGetServerProfiles({dynamic hint}) {
  return Future.value('[]');
}

Future<String> mainSaveServerProfiles({required String json, dynamic hint}) {
  return Future.value(json);
}
```

### 4. 新增测试覆盖
修改后新增：
```dart
test('server profile json roundtrip keeps independent server key', () {
  final profile = ServerProfileConfig(
    id: 'server-a',
    idServer: ' 192.0.2.10 ',
    key: 'AbCdR1c1E=',
  );

  final decoded = serverProfilesFromJson(serverProfilesToJson([profile]));
  expect(decoded.first.idServer, '192.0.2.10');
  expect(decoded.first.key, 'AbCdR1c1E=');
});
```

## 验证结果
- `flutter_rust_bridge_codegen`：成功生成桥接文件。
- `D:\flutter\bin\dart.bat format --output=none ...`：通过解析检查，没有写回格式化。
- `git diff --check`：通过，无空白错误。
- `D:\flutter\bin\flutter.bat test test\server_settings_dialog_test.dart`：未通过，阻塞原因是当前 `D:\flutter` 为 Flutter 3.38.8，与仓库现有依赖/API 不兼容：
  - `extended_text 14.0.0` 缺少新版 `SelectionHandler` 成员实现。
  - `common.dart` 现有 `DialogTheme` / `TabBarTheme` 与 Flutter 3.38 期望的 `DialogThemeData` / `TabBarThemeData` 类型不匹配。
  - 该阻塞不是本模块新增 profile UI 代码导致，模块 5 需要集中处理 Flutter SDK / 依赖版本兼容。

## 待办清单（未完成）
- 模块 5：修复或规避 Flutter 3.38 依赖兼容问题，重新运行 widget test。
- 模块 5：运行 Rust 相关测试 / 编译检查。
- 模块 5：生成最终构建产物。
- 模块 5：清理不再使用的临时缓存，确认不污染项目文件夹。
- 模块 5：最终验收 docs 中两台服务器的卡片导入和延迟显示。

## 下一步
- 进入模块 5「测试、构建、清理」：
  1. 先确认项目期望 Flutter 版本或用兼容补丁处理 Flutter 3.38 API 变化。
  2. 重新运行 Flutter 单测。
  3. 运行 Rust 测试/编译检查。
  4. 生成构建产物并清理临时缓存。
