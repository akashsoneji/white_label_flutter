import 'package:flutter/services.dart';

/// Rejects any edit that would leave more than one '.' in the field.
///
/// Decimal keyboards on Android/iOS let the user type '.' repeatedly, which
/// produced values like "41....32" in price and amount fields. Rejecting the
/// edit (instead of rewriting the text) keeps the cursor where the user left it.
class SingleDecimalPointFormatter extends TextInputFormatter {
  const SingleDecimalPointFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final newDots = '.'.allMatches(newValue.text).length;
    if (newDots <= 1) return newValue;
    // Text that already holds several dots (set before this guard existed)
    // must stay editable, so only block edits that add another dot.
    final oldDots = '.'.allMatches(oldValue.text).length;
    return newDots > oldDots ? oldValue : newValue;
  }
}
