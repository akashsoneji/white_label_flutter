import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';

/// Shared client-side validation for auth forms.
class AuthFormValidation {
  AuthFormValidation._();

  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  static bool isValidEmail(String email) => _emailRegex.hasMatch(email.trim());

  static bool isValidPassword(String password) => password.length >= 6;

  /// Shows one toast with all validation messages; returns true if valid.
  static bool showErrorsIfAny(List<String> errors) {
    if (errors.isEmpty) return true;
    CustomToastService.showError(
      title: 'Error',
      message: errors.join('\n'),
    );
    return false;
  }

  static List<String> validateLogin({
    required LanguageService languageService,
    required String email,
    required String password,
  }) {
    final errors = <String>[];
    if (email.isEmpty) {
      errors.add(languageService.tr('validation_email_required'));
    } else if (!isValidEmail(email)) {
      errors.add(languageService.tr('validation_email_invalid'));
    }
    if (password.isEmpty) {
      errors.add(languageService.tr('validation_password_required'));
    } else if (!isValidPassword(password)) {
      errors.add(languageService.tr('validation_password_min_length'));
    }
    return errors;
  }

  static List<String> validateSignUp({
    required LanguageService languageService,
    required String firstName,
    required String lastName,
    required String phone,
    required String email,
    required String password,
  }) {
    final errors = <String>[];
    if (firstName.isEmpty) {
      errors.add('${languageService.tr('validation_required')} (First Name)');
    }
    if (lastName.isEmpty) {
      errors.add('${languageService.tr('validation_required')} (Last Name)');
    }
    if (phone.isEmpty) {
      errors.add('${languageService.tr('validation_required')} (Phone)');
    }
    if (email.isEmpty) {
      errors.add(languageService.tr('validation_email_required'));
    } else if (!isValidEmail(email)) {
      errors.add(languageService.tr('validation_email_invalid'));
    }
    if (password.isEmpty) {
      errors.add(languageService.tr('validation_password_required'));
    } else if (!isValidPassword(password)) {
      errors.add(languageService.tr('validation_password_min_length'));
    }
    return errors;
  }

  static List<String> validateForgotPassword({
    required LanguageService languageService,
    required String email,
  }) {
    final errors = <String>[];
    if (email.isEmpty) {
      errors.add(languageService.tr('forgot_password_enter_your_email'));
    } else if (!isValidEmail(email)) {
      errors.add(languageService.tr('forgot_password_Please_enter_a_valid_email'));
    }
    return errors;
  }
}
