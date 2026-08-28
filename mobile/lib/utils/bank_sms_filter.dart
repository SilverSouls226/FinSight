/// Heuristic allowlist of common Indian bank/payment SMS sender IDs.
/// Real bank sender IDs are usually 6-char alphanumeric DLT codes (often
/// prefixed like "AD-HDFCBK-S" or "VM-SBIBNK"), so this matches by
/// substring rather than exact equality.
///
/// This is intentionally a client-side triage step only — it decides
/// whether to bother calling Skandan's `/ingest` at all. The actual
/// parsing/validation (and the real decision of what counts as a
/// financial event) happens entirely server-side; a message that slips
/// through this filter but fails to parse just gets a 422 from his
/// service, which is treated as a routine non-event, not an error.
const List<String> knownBankSenderFragments = [
  'HDFCBK',
  'SBIBNK',
  'SBIINB',
  'SBIUPI',
  'ICICIB',
  'ICICIT',
  'ICICIU',
  'AXISBK',
  'AXISUP',
  'KOTAKB',
  'KOTUPI',
  'YESBNK',
  'PAYTM',
  'PNBSMS',
  'INDBNK',
  'IDBIBK',
  'CANBNK',
  'UNIONB',
  'BOIIND',
  'CBSSBI',
];

bool looksLikeBankSms(String? sender) {
  if (sender == null || sender.isEmpty) return false;
  final upper = sender.toUpperCase();
  return knownBankSenderFragments.any((fragment) => upper.contains(fragment));
}
