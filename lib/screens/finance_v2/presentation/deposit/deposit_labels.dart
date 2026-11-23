import 'package:crm_app/services/language_service.dart';

const Map<String, String> _payLineLabelKeys = <String, String>{
  'holder_name': 'deposit_instruction_screen_bank_holder_name',
  'ifsc_code': 'deposit_instruction_screen_ifsc_code',
  'network': 'deposit_instruction_screen_network',
  'crypto_address': 'deposit_instruction_screen_deposit_address',
};

/// "Reference", taken from the existing "Reference: {reference}" string
/// because there is no key for the bare word.
String depositReferenceLabel() {
  return TranslationUtils.tr('cregis_address_screen_reference_number')
      .replaceAll('{reference}', '')
      .replaceAll(':', '')
      .trim();
}

/// Label of a pay-detail line. Keys without a translation are shown as
/// readable text (`bank_account_no` gives "Bank account no").
String depositPayLineLabel(String key) {
  final translationKey = _payLineLabelKeys[key];
  if (translationKey != null) return TranslationUtils.tr(translationKey);

  final words = key.replaceAll('_', ' ').trim();
  if (words.isEmpty) return key;
  return words[0].toUpperCase() + words.substring(1);
}
