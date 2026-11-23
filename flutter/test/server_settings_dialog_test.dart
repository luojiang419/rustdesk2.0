import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/mobile/widgets/dialog.dart';

void main() {
  test('server profile json roundtrip keeps independent server key', () {
    final profile = ServerProfileConfig(
      id: 'server-a',
      name: 'Primary',
      idServer: ' 192.0.2.10 ',
      relayServer: '192.0.2.10',
      apiServer: 'https://api.example.test',
      key: 'AbCdR1c1E=',
      enabled: true,
      preferred: true,
    );

    final decoded = serverProfilesFromJson(serverProfilesToJson([profile]));

    expect(decoded, hasLength(1));
    expect(decoded.first.id, 'server-a');
    expect(decoded.first.idServer, '192.0.2.10');
    expect(decoded.first.key, 'AbCdR1c1E=');
    expect(decoded.first.enabled, isTrue);
    expect(decoded.first.preferred, isTrue);
  });

  test('server profile json defaults first enabled profile to preferred', () {
    final decoded = serverProfilesFromJson('''
      [
        {"id":"server-a","idServer":"a.example.test","enabled":true},
        {"id":"server-b","idServer":"b.example.test","enabled":true}
      ]
    ''');

    expect(decoded, hasLength(2));
    expect(decoded[0].preferred, isTrue);
    expect(decoded[1].preferred, isFalse);
  });

  test('server profile preferences keep only one enabled preferred', () {
    final normalized = normalizeServerProfilePreferences([
      ServerProfileConfig(
        id: 'server-a',
        idServer: 'a.example.test',
        enabled: true,
        preferred: true,
      ),
      ServerProfileConfig(
        id: 'server-b',
        idServer: 'b.example.test',
        enabled: true,
        preferred: true,
      ),
    ]);

    expect(normalized[0].preferred, isTrue);
    expect(normalized[1].preferred, isFalse);
  });

  test('server profile preferences fall back when preferred is disabled', () {
    final normalized = normalizeServerProfilePreferences([
      ServerProfileConfig(
        id: 'server-a',
        idServer: 'a.example.test',
        enabled: false,
        preferred: true,
      ),
      ServerProfileConfig(
        id: 'server-b',
        idServer: 'b.example.test',
        enabled: true,
      ),
    ]);

    expect(normalized[0].preferred, isFalse);
    expect(normalized[1].preferred, isTrue);
  });

  test('server profile latency parses relay result', () {
    final latency = ServerProfileLatency.fromJson({
      'id': 'server-a',
      'idServer': 'id.example.test',
      'relayServer': 'relay.example.test',
      'latencyMs': 42,
      'error': '',
      'relayLatencyMs': 51,
      'relayError': '',
    });

    expect(latency.id, 'server-a');
    expect(latency.idServer, 'id.example.test');
    expect(latency.relayServer, 'relay.example.test');
    expect(latency.latencyMs, 42);
    expect(latency.relayLatencyMs, 51);
    expect(latency.relayError, '');
  });

  testWidgets('server settings text fields preserve literal input',
      (tester) async {
    final controller = TextEditingController(text: 'AbCdR1c1E=');
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: serverSettingsTextFormField(
          label: 'Key',
          controller: controller,
          errorMsg: '',
          autofocus: true,
        ),
      ),
    ));

    final textField = tester.widget<TextField>(find.byType(TextField));

    expect(textField.controller, controller);
    expect(textField.autofocus, isTrue);
    expect(textField.keyboardType, TextInputType.visiblePassword);
    expect(textField.textCapitalization, TextCapitalization.none);
    expect(textField.autocorrect, isFalse);
    expect(textField.enableSuggestions, isFalse);
    expect(textField.smartDashesType, SmartDashesType.disabled);
    expect(textField.smartQuotesType, SmartQuotesType.disabled);
    expect(textField.enableIMEPersonalizedLearning, isFalse);
    expect(
      textField.spellCheckConfiguration,
      const SpellCheckConfiguration.disabled(),
    );
  });
}
