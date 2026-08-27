---
name: project-kyc-intro-redesign
description: "KYC intro screen redesign task: match new design screenshot with theme + dark mode support"
type: project
createdAt: 1787832642498
updatedAt: 1787832642498
---

TASK (2026-08-27, IN PROGRESS): Redesign `lib/screens/kyc/presentation/pages/kyc_intro_screen.dart` to match a NEW design the user provided (screenshot). Must use OUR theme colors (AppColors.primary is red/maroon in this whitelabel) AND support dark mode.

**NEW DESIGN (screenshot 1) elements:**
- Back arrow top-left.
- Header: shield icon (with checkmark) inside a soft circular glow badge on the LEFT, next to bold title "Let's get you verified" + grey subtitle "Complete these simple steps to unlock all features and start trading".
- 3 white step cards, each with: a colored rounded-square (16r) gradient icon box on the LEFT (person / id-card / briefcase), a small "Step N" pill label, bold step title (Profile Setup / Verification / Trading Account), and a pill "Incomplete ○" status on the RIGHT (rounded, tinted bg).
- A VERTICAL TIMELINE connector runs down the left edge linking the cards (filled dot on active step, hollow circle on locked steps, dashed/solid line between).
- Each card has 3 feature rows, EACH with its own small circular tinted icon: Step1 = person(Complete your personal information), mail(Verify your email & phone number), home(Add your residential address); Step2 = cloud-upload(Upload your KYC documents), shield(Verify your identity), card(Add & verify your withdrawal method); Step3 = trend-up(Choose Live or Demo), plus(Create your trading account), check-circle(You're ready to trade).
- Big gradient primary button "Start Your Verification Journey" with → arrow, glowing shadow.
- Footer: lock icon + grey "Your information is secure and encrypted".

**CURRENT FILE:** StatelessWidget `KycIntroScreen({StageCompletion? stageCompletion})`. Has `_buildStepCard({stepNumber,title,status,backgroundColor,iconColor,textColor,features:List<String>,isActive})`. Uses AppColors.backgroundLight, AppColors.kycStageComplete/kycStageActive/kycFeatureBorder/surface/primary/icongrey/whiteColor/grey. SVGs used: assets/svg/kyc/profile-circle.svg, personalcard.svg, tick-circle.svg. Nav logic: onTap/onPressed → if !personalDetails Get.toNamed(KYC_DETAILS); elif !identity/!addressProof KYC_DOCS; else KYC_BANK (args screen_name 'Add Withdrawal Method', isFromKYC true). Localization via `languageService.tr('kyc_intro_personal_details'/'kyc_intro_id_verification'/'kyc_intro_address_verification')` — Get.find<LanguageService>().

**KEEP:** StageCompletion status logic (personalDetails/identityVerified/addressProofVerified/mobileVerified/emailVerified), navigation targets, AppBackButton, language keys. Preserve real status → map to Incomplete/Completed/Locked pills.

**MUST VERIFY BEFORE EDIT:** (1) how this app does DARK MODE — check AppColors (lib/constants/color.dart): is it static consts or theme-aware? Is there a ThemeController/Get.isDarkMode? Look for AppColors.backgroundLight vs a dark equivalent, or Theme.of(context). (2) available SVG icons under assets/svg/ (flags of person, mail/email, home, cloud-upload, shield, card, trend-up, add-square, tick-circle already exist per files_overview: assets/svg/more/ has email.svg, home.svg, mobile.svg; assets/svg/deshboard/ has add-square.svg, empty-wallet-add.svg; assets/svg/kyc/ has profile-circle/personalcard/tick-circle; assets/svg/trade/ has green_up_icon/trade_arrow_icon). May need Icons.* material fallback for missing ones.

flutter bin `~/development/flutter/bin/flutter`. analyze after: `~/development/flutter/bin/flutter analyze lib/screens/kyc/presentation/pages/kyc_intro_screen.dart`.
