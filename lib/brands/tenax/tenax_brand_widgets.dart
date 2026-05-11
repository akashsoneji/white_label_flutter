import 'package:flutter/widgets.dart';

import '../../screens/auth/presentation/pages/get_started_screen.dart';
import '../../screens/auth/presentation/pages/login_screen.dart';
import '../../screens/auth/presentation/pages/create_account_screen.dart';
import '../../screens/auth/presentation/pages/forgot_password_screen.dart';
import '../../screens/auth/presentation/pages/verify_code_screen.dart';
import '../../screens/auth/presentation/pages/create_new_password_screen.dart';
import '../../screens/auth/presentation/pages/splash_screen.dart';
import '../../screens/finance/presentation/pages/finance_screen.dart';
import '../../screens/kyc/presentation/pages/kyc_intro_screen.dart';
import '../../screens/home/more/more_screen.dart';
import '../../screens/trading/presentation/pages/trading_main_screen.dart';
import '../brand_widgets.dart';

class TenaxBrandWidgets implements BrandWidgets {
  const TenaxBrandWidgets();

  @override
  Widget splash() => const SplashScreen();

  @override
  Widget getStarted() => GetStartedScreen();

  @override
  Widget login() => const LoginScreen();

  @override
  Widget createAccount() => const CreateAccountScreen();

  @override
  Widget forgotPassword() => const ForgotPasswordScreen();

  @override
  Widget verifyCode({required String email}) => VerifyCodeScreen(email: email);

  @override
  Widget createNewPassword() => const CreateNewPasswordScreen();

  @override
  Widget tradingMain() => const TradingMainScreen();

  @override
  Widget more() => const MoreScreen();

  @override
  Widget finance() => const FinanceScreen();

  @override
  Widget kycIntro() => KycIntroScreen(stageCompletion: null);
}

