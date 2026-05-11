// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:intl/intl.dart';
// import 'package:crm_app/constants/color.dart';
// import 'package:crm_app/utils/trl_helper.dart';

// class CurrencyTextField extends StatefulWidget {
//   final TextEditingController? controller;
//   final String currencySymbol;
//   final InputDecoration? decoration;
//   final String? labelText;
//   final String? hintText;

//   const CurrencyTextField({
//     Key? key,
//     this.controller,
//     this.currencySymbol = "\$",
//     this.decoration,
//     this.labelText,
//     this.hintText,
//   }) : super(key: key);

//   @override
//   _CurrencyTextFieldState createState() => _CurrencyTextFieldState();
// }

// class _CurrencyTextFieldState extends State<CurrencyTextField> {
//   late TextEditingController _controller;
//   final NumberFormat _formatter = NumberFormat.currency(
//     locale: "en_US",
//     symbol: "",
//     decimalDigits: 2,
//   );

//   @override
//   void initState() {
//     super.initState();
//     _controller = widget.controller ?? TextEditingController();
//     _controller.addListener(_formatCurrency);
//   }

//   void _formatCurrency() {
//     String text = _controller.text.replaceAll(RegExp(r'[^0-9]'), "");

//     if (text.isEmpty) {
//       _controller.value = TextEditingValue(
//         text: "${widget.currencySymbol}0.00",
//         selection: TextSelection.collapsed(offset: 1),
//       );
//       return;
//     }

//     double value = double.parse(text) / 100;
//     String newText = "${widget.currencySymbol}${_formatter.format(value)}";

//     _controller.value = TextEditingValue(
//       text: newText,
//       selection: TextSelection.collapsed(offset: newText.length),
//     );
//   }

//   @override
//   void dispose() {
//     _controller.removeListener(_formatCurrency);
//     if (widget.controller == null) {
//       _controller.dispose();
//     }
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return RTLHelper.rtlTextField(
//       controller: _controller,
//       keyboardType: TextInputType.number,
//       decoration: widget.decoration ??
//           InputDecoration(
//             labelText: widget.labelText ?? 'Amount',
//             hintText: widget.hintText,
//             contentPadding: EdgeInsets.symmetric(
//               horizontal: 16.w,
//               vertical: 16.h,
//             ),
//             border: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(12),
//               borderSide: BorderSide(color: AppColors.border),
//             ),
//             enabledBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(12),
//               borderSide: BorderSide(color: AppColors.border),
//             ),
//             focusedBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(12),
//               borderSide: BorderSide(color: AppColors.primary, width: 2),
//             ),
//             errorBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(12),
//               borderSide: BorderSide(color: AppColors.border),
//             ),
//           ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';

class CurrencyTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String currencySymbol;
  final InputDecoration? decoration;
  final String? labelText;
  final String? hintText;

  const CurrencyTextField({
    Key? key,
    this.controller,
    this.currencySymbol = "\$",
    this.decoration,
    this.labelText,
    this.hintText,
  }) : super(key: key);

  @override
  _CurrencyTextFieldState createState() => _CurrencyTextFieldState();
}

class _CurrencyTextFieldState extends State<CurrencyTextField> {
  late TextEditingController _controller;
  late TextEditingController
  _displayController; // Separate controller for display
  String _currencySymbol = "\$";

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _displayController =
        TextEditingController(); // Controller for display with $ symbol
    _currencySymbol = widget.currencySymbol;

    // Initialize display controller with currency symbol
    _displayController.text = _currencySymbol + ' ';

    // Initialize main controller with clean value
    if (_controller.text.isNotEmpty) {
      _displayController.text = _currencySymbol + ' ' + _controller.text;
    }

    _displayController.addListener(_onTextChanged);

    // Listen to main controller changes (for external updates like pasting)
    _controller.addListener(_onMainControllerChanged);
  }

  void _onMainControllerChanged() {
    // Update display controller when main controller changes externally
    String cleanValue = _sanitizeNumeric(
      _controller.text.replaceAll(_currencySymbol, '').replaceAll(' ', ''),
    );
    if (cleanValue.isNotEmpty) {
      _displayController.text = _currencySymbol + ' ' + cleanValue;
    } else {
      _displayController.text = _currencySymbol + ' ';
    }
  }

  void _onTextChanged() {
    String currentText = _displayController.text;

    // If user deletes everything, add currency symbol with space back
    if (currentText.isEmpty) {
      _displayController.text = _currencySymbol + ' ';
      _controller.text = ''; // Keep main controller clean
      _displayController.selection = TextSelection.collapsed(
        offset: _currencySymbol.length + 1,
      );
      return;
    }

    // If text doesn't start with currency symbol, add it with space
    if (!currentText.startsWith(_currencySymbol)) {
      // Remove any existing currency symbols and add at the beginning with space
      String cleanText = currentText
          .replaceAll(_currencySymbol, '')
          .replaceAll(' ', '');
      _displayController.text = _currencySymbol + ' ' + cleanText;
      _controller.text = cleanText; // Update main controller with clean value
      _displayController.selection = TextSelection.collapsed(
        offset: _displayController.text.length,
      );
      return;
    }

    // Ensure there's a space after currency symbol
    if (currentText.length > _currencySymbol.length &&
        currentText[_currencySymbol.length] != ' ') {
      String cleanText = currentText
          .substring(_currencySymbol.length)
          .replaceAll(' ', '');
      _displayController.text = _currencySymbol + ' ' + cleanText;
      _controller.text = cleanText; // Update main controller with clean value
      _displayController.selection = TextSelection.collapsed(
        offset: _displayController.text.length,
      );
      return;
    }

    // If user tries to delete the currency symbol, prevent it
    if (currentText.length < _currencySymbol.length + 1) {
      _displayController.text = _currencySymbol + ' ';
      _controller.text = ''; // Keep main controller clean
      _displayController.selection = TextSelection.collapsed(
        offset: _currencySymbol.length + 1,
      );
      return;
    }

    // Update main controller with clean value (without $ and space)
    String cleanValue = _sanitizeNumeric(
      currentText.substring(_currencySymbol.length + 1).replaceAll(' ', ''),
    );
    _controller.text = cleanValue;
  }

  @override
  void dispose() {
    _displayController.removeListener(_onTextChanged);
    _controller.removeListener(_onMainControllerChanged);
    _displayController.dispose(); // Dispose display controller
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allowedCharsPattern = RegExp(
      '[0-9\\. ${RegExp.escape(_currencySymbol)}]',
    );

    return TextField(
      controller: _displayController, // Use display controller for UI
      keyboardType: TextInputType.number,
      inputFormatters: [
        // Allow digits and a single decimal separator while keeping symbol/space
        FilteringTextInputFormatter.allow(allowedCharsPattern),
        CurrencyInputFormatter(currencySymbol: _currencySymbol),
      ],
      decoration:
          widget.decoration ??
          InputDecoration(
            labelText: widget.labelText ?? 'Amount',
            hintText: widget.hintText,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 16.h,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
          ),
    );
  }
}

// Custom input formatter to handle currency symbol
class CurrencyInputFormatter extends TextInputFormatter {
  final String currencySymbol;

  CurrencyInputFormatter({required this.currencySymbol});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String rawText = newValue.text;

    // Ensure the currency symbol is always present at the start
    if (!rawText.startsWith(currencySymbol)) {
      rawText =
          currencySymbol +
          rawText.replaceAll(RegExp(RegExp.escape(currencySymbol)), '');
    }

    // Remove symbol and spaces for cleaning
    String cleanText = _sanitizeNumeric(
      rawText.replaceFirst(currencySymbol, '').replaceAll(' ', ''),
    );

    // Build formatted text with symbol and a space
    final formattedText =
        cleanText.isEmpty ? '$currencySymbol ' : '$currencySymbol $cleanText';

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}

// Ensure only digits and a single decimal point remain
String _sanitizeNumeric(String value) {
  String clean = value.replaceAll(RegExp(r'[^0-9.]'), '');
  if (clean.contains('.')) {
    final parts = clean.split('.');
    clean =
        parts[0] + (parts.length > 1 ? '.${parts.sublist(1).join('')}' : '');
  }
  return clean;
}
