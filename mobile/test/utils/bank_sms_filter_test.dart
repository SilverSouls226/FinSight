import 'package:flutter_test/flutter_test.dart';

import 'package:finsentinel/utils/bank_sms_filter.dart';

void main() {
  group('looksLikeBankSms', () {
    test('matches known bank sender fragments regardless of DLT prefix/suffix', () {
      expect(looksLikeBankSms('HDFCBK'), isTrue);
      expect(looksLikeBankSms('AD-HDFCBK-S'), isTrue);
      expect(looksLikeBankSms('VM-SBIBNK'), isTrue);
      expect(looksLikeBankSms('icicib'), isTrue); // case-insensitive
    });

    test('rejects unrelated senders', () {
      expect(looksLikeBankSms('MOM'), isFalse);
      expect(looksLikeBankSms('+919876543210'), isFalse);
      expect(looksLikeBankSms('AMAZON'), isFalse);
    });

    test('handles null/empty sender without throwing', () {
      expect(looksLikeBankSms(null), isFalse);
      expect(looksLikeBankSms(''), isFalse);
    });
  });
}
