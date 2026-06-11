# Prevent Double Tap and Add Button Loaders on Submit/Transfer Buttons

## Goal
Improve user experience and prevent duplicate API transactions by disabling form submission buttons during active requests, and showing a loader inside the buttons across all target screens in both `white_label` and `crmapp`.

## Approach
We will track the loading state (e.g. `_isSubmitting`, `isOtpLoading`, `isLoading`, etc.) reactively using Obx, GetX controller variables, or local reactive state variables. We will:
1. Set the button's `onPressed` handler to `null` when loading is active. This automatically disables the button and prevents double taps in Flutter.
2. Replace or overlay the button text with a `ButtonLoadingWidget(size: 20.0, color: AppColors.whiteColor)` while loading is true.
3. Update both `white_label` and `crmapp` workspaces.

---

## Steps

### Step 1: Internal Transfer Screen
- [x] **Files**:
  - `white_label/lib/screens/finance/presentation/pages/internal_transfer_screen.dart`
  - `crmapp/lib/screens/home/more/finance/internal_transfer_screen.dart`
- [x] **Action**: Verified that `onPressed` is set to `_isSubmitting.value ? null : _onActionButtonPressed` and displays `ButtonLoadingWidget` when submitting.

### Step 2: Withdrawal Screen
- [x] **Files**:
  - `white_label/lib/screens/finance/presentation/pages/withdrawal_screen.dart`
  - `crmapp/lib/screens/home/more/finance/withdrawal_screen.dart`
- [x] **Action**: Updated `_buildSendOtpButton()` to check `controller.isOtpLoading.value || controller.isLoading` to disable the button (`null`) and render `ButtonLoadingWidget`.

### Step 3: Deposit Instruction Screen
- [x] **Files**:
  - `white_label/lib/screens/finance/presentation/pages/deposit_instruction_screen.dart`
  - `crmapp/lib/screens/home/more/finance/deposit_instruction_screen.dart`
- [x] **Action**: Verified that the submit/confirm receipt button handles loading. Wrapped in `Obx`, disables `onPressed` when loading, and renders `ButtonLoadingWidget` during active submissions.

### Step 4: KYC Verification Details Screen
- [x] **Files**:
  - `white_label/lib/screens/kyc/presentation/pages/kyc_details_screen.dart`
  - `crmapp/lib/screens/home/kyc/kyc_details_screen.dart`
- [x] **Action**: Wrapped the "Save" button in `Obx`, setting `onPressed` to `authController.isLoading ? null : () => _handleSave()`, and rendering `ButtonLoadingWidget` if loading.

### Step 5: KYC Verification Documents Screen
- [x] **Files**:
  - `white_label/lib/screens/kyc/presentation/pages/kyc_docs_screen.dart`
  - `crmapp/lib/screens/home/kyc/kyc_docs_screen.dart`
- [x] **Action**: Verified that the submit documents button is wrapped in `Obx`, disabling click during upload and showing a loading indicator with "Uploading..." text.

### Step 6: KYC Verification Bank Screen
- [x] **Files**:
  - `white_label/lib/screens/kyc/presentation/pages/kyc_bank_screen.dart`
  - `crmapp/lib/screens/home/kyc/kyc_bank_screen.dart`
- [x] **Action**: Verified that the submit button is wrapped in `Obx`, disabling click during save and showing `ButtonLoadingWidget`.

---

## Files
- `white_label/lib/screens/finance/presentation/pages/withdrawal_screen.dart` — Modify `_buildSendOtpButton` to disable `onPressed` and show loading.
- `crmapp/lib/screens/home/more/finance/withdrawal_screen.dart` — Sync same loading check changes.
- `white_label/lib/screens/kyc/presentation/pages/kyc_details_screen.dart` — Wrap save button in Obx, disable on loading, show ButtonLoadingWidget.
- `crmapp/lib/screens/home/kyc/kyc_details_screen.dart` — Sync kyc details button loading changes.
- `white_label/lib/screens/kyc/presentation/pages/kyc_docs_screen.dart` — Prevent double click on document upload submission.
- `crmapp/lib/screens/home/kyc/kyc_docs_screen.dart` — Sync document upload button double-click logic.
- `white_label/lib/screens/kyc/presentation/pages/kyc_bank_screen.dart` — Disable button click during bank details submit.
- `crmapp/lib/screens/home/kyc/kyc_bank_screen.dart` — Sync bank details button disable logic.

## Risks / Open questions
- Ensure all relevant GetX controllers are imported and accessed cleanly on each view.
- Confirm if loading flags exist on all corresponding controllers (e.g. `KycDocsController`, `KycBankController`). If not, add/track them.
