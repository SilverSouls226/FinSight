import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finsentinel/models/user_profile.dart';
import 'package:finsentinel/services/user_profile_storage.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('UserProfile.fromJson / toJson', () {
    test('round-trips every field', () {
      const profile = UserProfile(
        name: 'Kalyan',
        riskTolerance: RiskTolerance.aggressive,
        priorities: [FinancialPriority.buildEmergencyFund, FinancialPriority.payDownDebt],
        primaryGoalName: 'Emergency Fund',
        primaryGoalTarget: 10000.0,
      );

      final restored = UserProfile.fromJson(profile.toJson());

      expect(restored.name, 'Kalyan');
      expect(restored.riskTolerance, RiskTolerance.aggressive);
      expect(restored.priorities, [FinancialPriority.buildEmergencyFund, FinancialPriority.payDownDebt]);
      expect(restored.primaryGoalName, 'Emergency Fund');
      expect(restored.primaryGoalTarget, 10000.0);
    });

    test('handles a profile with no optional goal fields', () {
      const profile = UserProfile(
        name: 'Sam',
        riskTolerance: RiskTolerance.conservative,
        priorities: [],
      );

      final restored = UserProfile.fromJson(profile.toJson());

      expect(restored.name, 'Sam');
      expect(restored.primaryGoalName, isNull);
      expect(restored.primaryGoalTarget, isNull);
    });

    test('falls back gracefully on missing/malformed fields', () {
      final restored = UserProfile.fromJson(const {});
      expect(restored.name, '');
      expect(restored.riskTolerance, RiskTolerance.moderate);
      expect(restored.priorities, isEmpty);
    });
  });

  group('UserProfileStorage', () {
    test('load() returns null when nothing has been saved', () async {
      final storage = UserProfileStorage();
      expect(await storage.load(), isNull);
    });

    test('save() then load() returns an equivalent profile', () async {
      final storage = UserProfileStorage();
      const profile = UserProfile(
        name: 'Kalyan',
        riskTolerance: RiskTolerance.moderate,
        priorities: [FinancialPriority.stabilizeCashFlow],
      );

      await storage.save(profile);
      final loaded = await storage.load();

      expect(loaded, isNotNull);
      expect(loaded!.name, 'Kalyan');
      expect(loaded.riskTolerance, RiskTolerance.moderate);
      expect(loaded.priorities, [FinancialPriority.stabilizeCashFlow]);
    });

    test('clear() removes the saved profile', () async {
      final storage = UserProfileStorage();
      await storage.save(const UserProfile(name: 'Kalyan', riskTolerance: RiskTolerance.moderate, priorities: []));

      await storage.clear();

      expect(await storage.load(), isNull);
    });

    test('load() returns null (not a throw) for corrupted stored data', () async {
      SharedPreferences.setMockInitialValues({'user_profile_v1': 'not valid json'});
      final storage = UserProfileStorage();

      expect(await storage.load(), isNull);
    });
  });
}
