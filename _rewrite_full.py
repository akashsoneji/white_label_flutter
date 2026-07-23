import re

with open('lib/screens/auth/presentation/brands/riyadex/pages/riyadex_create_account_screen.dart', 'r') as f:
    content = f.read()

# Fix CustomToastService.showError missing title
content = content.replace('CustomToastService.showError(message:', 'CustomToastService.showError(title: "Error", message:')

# Fix AuthFormValidation validator access
content = content.replace('/*validator*/AuthFormValidation.validateName,', '')
content = content.replace('/*validator*/AuthFormValidation.validateEmail,', '')
content = content.replace('/*validator*/AuthFormValidation.validatePhone,', '')
content = content.replace('/*validator*/AuthFormValidation.validatePassword,', '')
content = content.replace('/*label*/', '')
content = content.replace('/*validator*/', '')

# Fix VantageAuthHeader
content = content.replace('VantageAuthHeader(', 'Text("Welcome to Riyadex", style: AppTextStyles.bodyText.copyWith(fontSize: 24, fontWeight: FontWeight.w800, color: VantageAuthTheme.text)); //')

# Fix showDialog / OtpModal
# Find the showDialog block
otp_regex = re.compile(r'showDialog\(\s*context: context,\s*builder: \(context\) => OtpModal\((.*?)\),\s*\);', re.DOTALL)
def otp_replacer(m):
    inner = m.group(1)
    # The inner part needs to be just OTPModal.show(context, email: ..., resendAction: ..., verifyAction: ...)
    # which we can map to the proper OTPModal signature.
    # The app actually uses `OTPModal.show(context, email: '...', resendAction: () async {}, verifyAction: (otp) async {})`
    return f'OTPModal.show(\n          context,\n          {inner}\n        );'

content = otp_regex.sub(otp_replacer, content)

# Also fix the manual one that I messed up earlier if it's there
content = content.replace('OTPModal.show(context, \n          context,', 'OTPModal.show(\n          context,')
content = content.replace('onOtpSubmitted:', 'verifyAction:')
content = content.replace('onResendOtp:', 'resendAction:')
content = re.sub(r'otpLength:\s*\d+,', '', content)

with open('lib/screens/auth/presentation/brands/riyadex/pages/riyadex_create_account_screen.dart', 'w') as f:
    f.write(content)
