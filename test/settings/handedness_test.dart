// Tests for the Handedness setting used to mirror the keypad.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:klator/settings/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to rightHanded when nothing is stored', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = await SettingsProvider.create();
    expect(provider.handedness, Handedness.rightHanded);
  });

  test('setHandedness persists and reloads', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = await SettingsProvider.create();

    await provider.setHandedness(Handedness.leftHanded);
    expect(provider.handedness, Handedness.leftHanded);

    final reloaded = await SettingsProvider.create();
    expect(reloaded.handedness, Handedness.leftHanded);
  });

  test('unknown stored value falls back to rightHanded', () async {
    SharedPreferences.setMockInitialValues({'handedness': 'sideways'});
    final provider = await SettingsProvider.create();
    expect(provider.handedness, Handedness.rightHanded);
  });

  test('notifies listeners on change', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = await SettingsProvider.create();
    int notifications = 0;
    provider.addListener(() => notifications++);

    await provider.setHandedness(Handedness.leftHanded);
    expect(notifications, greaterThan(0));
  });
}
