import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common/widgets/toolbar.dart';
import 'package:get/get.dart';

import '../../common.dart';
import '../../models/platform_model.dart';

void _showSuccess() {
  showToast(translate("Successful"));
}

void setTemporaryPasswordLengthDialog(
    OverlayDialogManager dialogManager) async {
  List<String> lengths = ['6', '8', '10'];
  String length = await bind.mainGetOption(key: "temporary-password-length");
  var index = lengths.indexOf(length);
  if (index < 0) index = 0;
  length = lengths[index];
  dialogManager.show((setState, close, context) {
    setLength(newValue) {
      final oldValue = length;
      if (oldValue == newValue) return;
      setState(() {
        length = newValue;
      });
      bind.mainSetOption(key: "temporary-password-length", value: newValue);
      bind.mainUpdateTemporaryPassword();
      Future.delayed(Duration(milliseconds: 200), () {
        close();
        _showSuccess();
      });
    }

    return CustomAlertDialog(
      title: Text(translate("Set one-time password length")),
      content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: lengths
              .map(
                (value) => Row(
                  children: [
                    Text(value),
                    Radio(
                        value: value, groupValue: length, onChanged: setLength),
                  ],
                ),
              )
              .toList()),
    );
  }, backDismiss: true, clickMaskDismiss: true);
}

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

  Future<void> refresh(
    StateSetter dialogSetState, {
    bool importDocIfEmpty = false,
  }) async {
    dialogSetState(() {
      isLoading = true;
      loadError = '';
    });
    try {
      final loaded = await loadServerProfiles(
        importDocIfEmpty: importDocIfEmpty,
      );
      final tested = await testServerProfiles(loaded);
      dialogSetState(() {
        profiles = loaded;
        latencies = tested;
      });
    } catch (e) {
      dialogSetState(() {
        loadError = e.toString();
      });
    } finally {
      dialogSetState(() {
        isLoading = false;
        isTesting = false;
      });
    }
  }

  Future<void> saveAndRefresh(
    StateSetter dialogSetState,
    List<ServerProfileConfig> nextProfiles,
  ) async {
    dialogSetState(() {
      isLoading = true;
      loadError = '';
    });
    try {
      final saved = await saveServerProfiles(nextProfiles);
      final tested = await testServerProfiles(saved);
      dialogSetState(() {
        profiles = saved;
        latencies = tested;
      });
      setState(() {});
    } catch (e) {
      dialogSetState(() {
        loadError = e.toString();
      });
      rethrow;
    } finally {
      dialogSetState(() {
        isLoading = false;
      });
    }
  }

  dialogManager.show((dialogSetState, close, context) {
    if (!started) {
      started = true;
      Future.microtask(() => refresh(dialogSetState, importDocIfEmpty: true));
    }

    Future<void> retest() async {
      dialogSetState(() {
        isTesting = true;
        loadError = '';
      });
      try {
        final tested = await testServerProfiles(profiles);
        dialogSetState(() {
          latencies = tested;
        });
      } catch (e) {
        dialogSetState(() {
          loadError = e.toString();
        });
      } finally {
        dialogSetState(() {
          isTesting = false;
        });
      }
    }

    Future<void> openEditor({ServerProfileConfig? profile, int? index}) async {
      await _showServerProfileEditor(
        dialogManager: dialogManager,
        profiles: profiles,
        profile: profile,
        index: index,
        onProfilesSaved: (nextProfiles) async {
          await saveAndRefresh(dialogSetState, nextProfiles);
        },
      );
    }

    Widget content;
    if (isLoading && profiles.isEmpty) {
      content = const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    } else {
      content = SizedBox(
        width: isDesktop || isWebDesktop ? 620 : double.maxFinite,
        height: isDesktop || isWebDesktop ? 460 : 420,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 64),
              child: profiles.isEmpty
                  ? Center(child: Text(translate('No data')))
                  : ListView.separated(
                      itemCount: profiles.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final profile = profiles[index];
                        final latency = latencies[profile.id];
                        return _serverProfileCard(
                          profile: profile,
                          latency: latency,
                          onEdit: () =>
                              openEditor(profile: profile, index: index),
                        );
                      },
                    ),
            ),
            if (loadError.isNotEmpty)
              Positioned(
                left: 0,
                right: 72,
                bottom: 10,
                child: Text(
                  loadError,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.red),
                ),
              ),
            Positioned(
              right: 0,
              bottom: 0,
              child: FloatingActionButton(
                mini: true,
                onPressed: () => openEditor(),
                child: const Icon(Icons.add),
              ),
            ),
          ],
        ),
      );
    }

    return CustomAlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(translate('ID/Relay Server'))),
          Tooltip(
            message: translate('Refresh'),
            child: IconButton(
              icon: isTesting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              onPressed: isTesting || isLoading ? null : retest,
            ),
          ),
        ],
      ),
      content: content,
      contentBoxConstraints: const BoxConstraints(maxWidth: 680),
      actions: [dialogButton('Close', onPressed: close)],
    );
  });
}

void showServerSettingsWithValue(
  ServerConfig serverConfig,
  OverlayDialogManager dialogManager,
  void Function(VoidCallback)? upSetState,
) async {
  final profiles = await loadServerProfiles(importDocIfEmpty: false);
  await _showServerProfileEditor(
    dialogManager: dialogManager,
    profiles: profiles,
    profile: ServerProfileConfig.fromServerConfig(serverConfig),
    onProfilesSaved: (nextProfiles) async {
      await saveServerProfiles(nextProfiles);
      upSetState?.call(() {});
    },
  );
}

Widget _serverProfileCard({
  required ServerProfileConfig profile,
  required ServerProfileLatency? latency,
  required VoidCallback onEdit,
}) {
  final status = _serverProfileStatus(profile, latency);
  final relay = profile.relayServer.isEmpty ? '-' : profile.relayServer;
  final api = profile.apiServer.isEmpty ? '-' : profile.apiServer;
  return GestureDetector(
    onDoubleTap: onEdit,
    child: Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.withOpacity(0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              profile.enabled ? Icons.dns_outlined : Icons.block_outlined,
              color: profile.enabled ? MyTheme.accent : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          profile.name.isEmpty
                              ? profile.idServer
                              : profile.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      _serverProfileStatusChip(status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    profile.idServer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${translate('Relay Server')}: $relay',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${translate('API Server')}: $api',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: translate('Edit'),
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
          ],
        ),
      ),
    ),
  );
}

({String text, Color color}) _serverProfileStatus(
  ServerProfileConfig profile,
  ServerProfileLatency? latency,
) {
  if (!profile.enabled) {
    return (text: translate('Disabled'), color: Colors.grey);
  }
  if (latency == null) {
    return (text: translate('Testing'), color: Colors.grey);
  }
  if (latency.latencyMs >= 0) {
    final color = latency.latencyMs > 300 ? Colors.orange : Colors.green;
    return (text: '${latency.latencyMs} ms', color: color);
  }
  return (text: translate('Offline'), color: Colors.red);
}

Widget _serverProfileStatusChip(({String text, Color color}) status) {
  return Container(
    constraints: const BoxConstraints(minWidth: 64),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: status.color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: status.color.withOpacity(0.35)),
    ),
    child: Text(
      status.text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(color: status.color, fontSize: 12),
    ),
  );
}

Future<void> _showServerProfileEditor({
  required OverlayDialogManager dialogManager,
  required List<ServerProfileConfig> profiles,
  required Future<void> Function(List<ServerProfileConfig>) onProfilesSaved,
  ServerProfileConfig? profile,
  int? index,
}) async {
  var isInProgress = false;
  final editing = index != null && index >= 0 && index < profiles.length;
  final current = profile == null
      ? ServerProfileConfig()
      : ServerProfileConfig(
          id: profile.id,
          name: profile.name,
          idServer: profile.idServer,
          relayServer: profile.relayServer,
          apiServer: profile.apiServer,
          key: profile.key,
          enabled: profile.enabled,
        );
  final nameCtrl = TextEditingController(text: current.name);
  final idCtrl = TextEditingController(text: current.idServer);
  final relayCtrl = TextEditingController(text: current.relayServer);
  final apiCtrl = TextEditingController(text: current.apiServer);
  final keyCtrl = TextEditingController(text: current.key);
  var enabled = current.enabled;

  RxString idServerMsg = ''.obs;
  RxString relayServerMsg = ''.obs;
  RxString apiServerMsg = ''.obs;

  final errMsgs = [idServerMsg, relayServerMsg, apiServerMsg];

  try {
    await dialogManager.show((setState, close, context) {
    Future<bool> submit() async {
      setState(() {
        isInProgress = true;
      });
      final next = ServerProfileConfig(
        id: current.id.isEmpty ? _newServerProfileId() : current.id,
        name: nameCtrl.text.trim(),
        idServer: idCtrl.text.trim(),
        relayServer: relayCtrl.text.trim(),
        apiServer: apiCtrl.text.trim(),
        key: keyCtrl.text.trim(),
        enabled: enabled,
      );
      final ret = await _validateServerProfile(next, errMsgs);
      if (ret) {
        final nextProfiles = [...profiles];
        final targetIndex = editing
            ? index!
            : _findServerProfileIndex(nextProfiles, next);
        if (targetIndex >= 0 && targetIndex < nextProfiles.length) {
          nextProfiles[targetIndex] = next;
        } else {
          nextProfiles.add(next);
        }
        try {
          await onProfilesSaved(nextProfiles);
        } catch (e) {
          debugPrint('Failed to save server profile: $e');
          setState(() {
            isInProgress = false;
          });
          return false;
        }
      }
      setState(() {
        isInProgress = false;
      });
      return ret;
    }

    Future<bool> delete() async {
      if (index == null || index < 0 || index >= profiles.length) {
        return true;
      }
      setState(() {
        isInProgress = true;
      });
      final nextProfiles = [...profiles]..removeAt(index);
      try {
        await onProfilesSaved(nextProfiles);
      } catch (e) {
        debugPrint('Failed to delete server profile: $e');
        setState(() {
          isInProgress = false;
        });
        return false;
      }
      setState(() {
        isInProgress = false;
      });
      return true;
    }

    Widget buildField(
      String label,
      TextEditingController controller,
      String errorMsg, {
      String? Function(String?)? validator,
      bool autofocus = false,
    }) {
      if (isDesktop || isWeb) {
        return Row(
          children: [
            SizedBox(width: 120, child: Text(label)),
            SizedBox(width: 8),
            Expanded(
              child: serverSettingsTextFormField(
                label: label,
                controller: controller,
                errorMsg: errorMsg,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                showLabelText: false,
                validator: validator,
                autofocus: autofocus,
              ).workaroundFreezeLinuxMint(),
            ),
          ],
        );
      }

      return serverSettingsTextFormField(
        label: label,
        controller: controller,
        errorMsg: errorMsg,
        validator: validator,
      ).workaroundFreezeLinuxMint();
    }

    return CustomAlertDialog(
      title: Row(
        children: [Expanded(child: Text(translate(editing ? 'Edit' : 'Add')))],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 500),
        child: Form(
          child: Obx(
            () => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                buildField(translate('Name'), nameCtrl, ''),
                SizedBox(height: 8),
                buildField(
                  translate('ID Server'),
                  idCtrl,
                  idServerMsg.value,
                  autofocus: true,
                ),
                SizedBox(height: 8),
                if (!isIOS && !isWeb) ...[
                  buildField(
                    translate('Relay Server'),
                    relayCtrl,
                    relayServerMsg.value,
                  ),
                  SizedBox(height: 8),
                ],
                buildField(
                  translate('API Server'),
                  apiCtrl,
                  apiServerMsg.value,
                  validator: (v) {
                    if (v != null && v.isNotEmpty) {
                      if (!(v.startsWith('http://') ||
                          v.startsWith("https://"))) {
                        return translate("invalid_http");
                      }
                    }
                    return null;
                  },
                ),
                SizedBox(height: 8),
                buildField('Key', keyCtrl, ''),
                SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(translate('Enabled')),
                  value: enabled,
                  onChanged: (value) {
                    setState(() {
                      enabled = value;
                    });
                  },
                ),
                if (isInProgress)
                  Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (editing)
          dialogButton(
            'Delete',
            onPressed: isInProgress
                ? null
                : () async {
                    if (await delete()) {
                      close();
                      showToast(translate('Successful'));
                    }
                  },
            isOutline: true,
            style: TextStyle(color: Colors.red),
          ),
        dialogButton(
          'Cancel',
          onPressed: () {
            close();
          },
          isOutline: true,
        ),
        dialogButton(
          'OK',
          onPressed: isInProgress
              ? null
              : () async {
                  if (await submit()) {
                    close();
                    showToast(translate('Successful'));
                  } else {
                    showToast(translate('Failed'));
                  }
                },
        ),
      ],
    );
    });
  } finally {
    nameCtrl.dispose();
    idCtrl.dispose();
    relayCtrl.dispose();
    apiCtrl.dispose();
    keyCtrl.dispose();
  }
}

String _newServerProfileId() {
  return 'profile-${DateTime.now().millisecondsSinceEpoch}';
}

int _findServerProfileIndex(
  List<ServerProfileConfig> profiles,
  ServerProfileConfig profile,
) {
  final profileId = profile.id.trim();
  if (profileId.isNotEmpty) {
    final index = profiles.indexWhere((e) => e.id.trim() == profileId);
    if (index >= 0) {
      return index;
    }
  }
  final idServer = profile.idServer.trim().toLowerCase();
  if (idServer.isEmpty) {
    return -1;
  }
  return profiles.indexWhere(
    (e) => e.idServer.trim().toLowerCase() == idServer,
  );
}

Future<bool> _validateServerProfile(
  ServerProfileConfig config,
  List<RxString> errMsgs,
) async {
  String removeEndSlash(String input) {
    if (input.endsWith('/')) {
      return input.substring(0, input.length - 1);
    }
    return input;
  }

  errMsgs[0].value = '';
  errMsgs[1].value = '';
  errMsgs[2].value = '';
  config.idServer = removeEndSlash(config.idServer.trim());
  config.relayServer = removeEndSlash(config.relayServer.trim());
  config.apiServer = removeEndSlash(config.apiServer.trim());
  config.key = config.key.trim();
  config.name = config.name.trim().isEmpty
      ? config.idServer
      : config.name.trim();
  if (config.idServer.isEmpty) {
    errMsgs[0].value = translate('Invalid server configuration');
    return false;
  }
  errMsgs[0].value = translate(
    await bind.mainTestIfValidServer(
      server: config.idServer,
      testWithProxy: true,
    ),
  );
  if (errMsgs[0].isNotEmpty) {
    return false;
  }
  if (config.relayServer.isNotEmpty) {
    errMsgs[1].value = translate(
      await bind.mainTestIfValidServer(
        server: config.relayServer,
        testWithProxy: true,
      ),
    );
    if (errMsgs[1].isNotEmpty) {
      return false;
    }
  }
  if (config.apiServer.isNotEmpty &&
      !config.apiServer.startsWith('http://') &&
      !config.apiServer.startsWith('https://')) {
    errMsgs[2].value =
        '${translate("API Server")}: ${translate("invalid_http")}';
    return false;
  }
  return true;
}

TextFormField serverSettingsTextFormField({
  required String label,
  required TextEditingController controller,
  required String errorMsg,
  String? Function(String?)? validator,
  bool autofocus = false,
  bool showLabelText = true,
  EdgeInsetsGeometry? contentPadding,
}) {
  return TextFormField(
    controller: controller,
    decoration: InputDecoration(
      labelText: showLabelText ? label : null,
      errorText: errorMsg.isEmpty ? null : errorMsg,
      contentPadding: contentPadding,
    ),
    validator: validator,
    autofocus: autofocus,
    keyboardType: TextInputType.visiblePassword,
    textCapitalization: TextCapitalization.none,
    autocorrect: false,
    enableSuggestions: false,
    smartDashesType: SmartDashesType.disabled,
    smartQuotesType: SmartQuotesType.disabled,
    enableIMEPersonalizedLearning: false,
    spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
  );
}

void setPrivacyModeDialog(
  OverlayDialogManager dialogManager,
  List<TToggleMenu> privacyModeList,
  RxString privacyModeState,
) async {
  dialogManager.dismissAll();
  dialogManager.show((setState, close, context) {
    return CustomAlertDialog(
      title: Text(translate('Privacy mode')),
      content: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: privacyModeList
              .map((value) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    title: value.child,
                    value: value.value,
                    onChanged: value.onChanged,
                  ))
              .toList()),
    );
  }, backDismiss: true, clickMaskDismiss: true);
}
