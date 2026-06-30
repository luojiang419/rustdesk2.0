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
    );

    final decoded = serverProfilesFromJson(serverProfilesToJson([profile]));

    expect(decoded, hasLength(1));
    expect(decoded.first.id, 'server-a');
    expect(decoded.first.idServer, '192.0.2.10');
    expect(decoded.first.key, 'AbCdR1c1E=');
    expect(decoded.first.enabled, isTrue);
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
