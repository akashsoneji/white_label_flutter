# Card Withdrawal Method — Flutter Mobile

## Goal
Add credit/debit card (Visa / Mastercard) as a fourth withdrawal-method type. Users can save a card (holder name + brand + last-4) and pick it when withdrawing. Card is opt-in per broker — it only appears when the backend master-method row is marked `active`. No PAN, CVV, or expiry ever touches the app.

## Approach
Follow the existing bank / crypto / UPI patterns verbatim. Key decisions:

- The 2026-07-09 restructure already moved KYC into `lib/screens/kyc/...` (feature folders). The 5 file paths in the original spec all need to be corrected.
- The controller uses `selectedAccountType.value.toLowerCase()` as its category switch — NOT the spec's `accountTypeCategory`. Every branch site in the plan uses that actual field.
- The Vantage `WithdrawalScreen` (`lib/screens/finance/presentation/brands/vantage/pages/withdrawal_screen.dart`) is a 10-line wrapper that calls `base.WithdrawalScreen(...)`. No Vantage-brand override exists, so the card logic only needs to land in the base screen.
- `_getProofFieldName` is not a separate helper in this code — proof gating is inline in `_validateRequiredFields()`. The card branch short-circuits proof before reaching that gate.
- No new API endpoints; no dart-define changes; the master-methods list already surfaces `card` once the admin flips it on.

## Steps

- [ ] **1 — Model** `lib/models/bank_withdralList_model.dart`
  - Add three optional fields to `WithdrawalMethods` — `cardHolderName`, `cardBrand`, `cardLast4` — between `cryptoNetwork` and `proofImg` (to mirror the order described in the backend contract).
  - Wire them in the constructor, `fromJson` (`json['card_holder_name']`, `json['card_brand']`, `json['card_last4']`) and `toJson` (snake_case → camelCase, matching the existing `cryptoAddress` pattern).
  - `cardLast4` stays a `String` so leading zeros like `"0012"` round-trip correctly.

- [ ] **2 — Controller observables** `lib/screens/kyc/view_models/kyc_bank_controller.dart`
  - Add `final RxString cardBrand = ''.obs;` and `final RxString cardLast4 = ''.obs;` alongside the existing `cryptoAddress` / `upiAddress` observables.
  - `accountHolderName` is reused for the cardholder name — no new observable needed. Mirrors how bank and UPI share it.

- [ ] **3 — Category switch** (same controller)
  - In `setAccountType`, update `_applyAccountTypeDefaults` to also short-circuit when category is `card` (no USDT default, no crypto-network default).
  - In `clearFormFields`, add `cardBrand.value = ''; cardLast4.value = '';` alongside the existing per-type clears.
  - In `_validateRequiredFields`: add an `else if (selectedAccountType.value.toLowerCase() == "card")` branch between the `crypto` branch and the `else` (UPI) branch that validates: holder name non-empty + allowed-chars regex, brand non-empty, last4 matches `^\d{4}$`. Uses the same `_isValidCryptoHolderName` regex (letters, spaces, `-` `'` `.`).
  - Add a proof short-circuit near the top of `_validateRequiredFields` — before the existing `if (proofFile.value == null)` block:
    ```
    if (selectedAccountType.value.toLowerCase() == 'card' || selectedAccountType.value.toLowerCase() == 'local') {
      // skip proof gate for card / local — backend also accepts without proof
    } else if (proofFile.value == null) { ... }
    ```
    (The `local` short-circuit is an observation: the current code has no `local` category, but the same backend rule exists for it. Kept as-is to avoid scope creep; see Risks.)
  - In `_buildOtpRequestParams`: add an `else if (selectedAccountType.value.toLowerCase() == "card")` branch **before** the `else` (UPI case) that returns:
    ```
    'withdrawal_method': 'card',
    'currency': selectedCurrency.value,
    'card_holder_name': accountHolderName.value.trim(),
    'card_brand': cardBrand.value.toLowerCase(),
    'card_last4': cardLast4.value,
    'holder_name': accountHolderName.value.trim(),
    ```
    (No `relationship` — the backend's store endpoint doesn't require it for card. `belongs_to` is intentionally omitted; backend treats it as optional.)
  - In `_getProofFieldName`: add a `case 'card': return 'card_proof_img';` (defensive — proof is skipped by validation, but the multipart uploader would otherwise crash with the default `deposit_proof` field name if it were ever invoked).

- [ ] **4 — KYC Bank screen** `lib/screens/kyc/presentation/pages/kyc_bank_screen.dart`
  - Add `final TextEditingController _cardLast4Controller = TextEditingController();` next to the existing `_cryptoAddressController`. Dispose it in `dispose()`.
  - In the "clear on method-type switch" block (where `_cryptoAddressController.clear()` and `_upiAddressController.clear()` live), add `controller.cardBrand.value = ''; controller.cardLast4.value = ''; _cardLast4Controller.clear();`.
  - In the field-builder switch (the one that renders holder name / address / network per method type), add a `case 'card':` block that renders:
    1. **Cardholder name** — reuse the existing shared holder-name input (same widget used by bank / UPI, wired to `controller.accountHolderName`).
    2. **Card brand** — `DropdownButtonFormField<String>` with two items (`visa` / `mastercard`), `onChanged` writes `controller.cardBrand.value`.
    3. **Last 4 digits** — `TextField` with `keyboardType: number`, `maxLength: 4`, `FilteringTextInputFormatter.digitsOnly`, wired to `_cardLast4Controller` and `controller.cardLast4.value`. Label = `languageService.tr('kyc_card_last4')`.
  - In the proof-upload section, extend the existing skip condition so card hides it: change the crypto-only check to `final skipProof = ['crypto', 'card'].contains(controller.selectedAccountType.value.toLowerCase()); if (skipProof) return const SizedBox.shrink();`.

- [ ] **5 — Saved-methods list** `lib/screens/kyc/presentation/pages/bank_list_screen.dart`
  - In the detail-row builder (~line 322 region), add an `else if (methodType == 'card')` branch that appends two rows if populated: `cardBrand` → "Card Brand" label uppercased (`VISA` / `MASTERCARD`), and `cardLast4` → "Card Number" label formatted `•••• •••• •••• <last4>`. The existing `holderName` block below already covers the name — no duplication.
  - In `_buildTitle`, add a `case 'card':` that returns `'${(method.cardBrand ?? 'Card').toUpperCase()} •••• ${method.cardLast4 ?? '••••'}'`. Fall back to the literal "Card" if brand is empty (e.g. pending row).

- [ ] **6 — Withdrawal payout picker** `lib/screens/finance/presentation/pages/withdrawal_screen.dart`
  - In the `Obx` that branches on method type (~line 225), add `} else if (method == 'card') { return SizedBox.shrink(); }` (no extra "crypto type" selector for cards — they're picked directly).
  - In the payout-picker section, add a card branch alongside the existing bank/crypto branches:
    - Read `controller.bankWithdrawalList` (the same list that feeds the bank picker) and filter to `method.withdrawalMethod.toLowerCase() == 'card'`.
    - Render a list tile per saved card: `${card.cardBrand!.toUpperCase()} •••• ${card.cardLast4} — ${card.holderName ?? ''}`.
    - Track selection in a new `final selectedCardMethodId = Rxn<int?>();` local to the screen (or promote to the controller if it already owns `selectedPaymentMethod`). Use the row's `id` as the value.
    - Empty state: show the same empty-state widget used by bank/crypto, with CTA navigating to `bank_list_screen` to add a card.
  - In the submit-validation block (~line 965), add:
    ```
    if (controller.selectedPaymentMethod.value.toLowerCase() == 'card') {
      if (selectedCardMethodId.value == null) {
        _validationMessage.value = 'Please select a card';
        return false;
      }
    }
    ```
    (Only if the submit flow actually needs the card id — see Risks.)
  - The Vantage wrapper (`lib/screens/finance/presentation/brands/vantage/pages/withdrawal_screen.dart`) is untouched — it delegates to the base, so the card picker appears there automatically.

- [ ] **7 — Translations** `assets/translations/en.json` and `assets/translations/ar.json`
  - Add these keys to both files:
    ```
    "kyc_card_holder_name": "Cardholder name",
    "kyc_card_holder_name_hint": "Name as printed on the card",
    "kyc_card_brand": "Card brand",
    "kyc_card_last4": "Last 4 digits",
    "kyc_card_last4_hint": "e.g. 1234",
    "kyc_card_no_proof_helper": "No proof image needed — the last 4 digits identify the card.",
    "withdrawal_saved_cards_empty": "No cards saved. Add a card to proceed."
    ```
  - Arabic values: `card_holder_name` → "اسم حامل البطاقة", `card_brand` → "نوع البطاقة", `card_last4` → "آخر 4 أرقام", etc. (Confirm with the existing `ar.json` style — the current file uses short phrases, not full sentences.)

## Files

- **Modified** `lib/models/bank_withdralList_model.dart` — three new optional fields on `WithdrawalMethods`.
- **Modified** `lib/screens/kyc/view_models/kyc_bank_controller.dart` — card observables, category branches, validators, OTP payload, proof-field-name case.
- **Modified** `lib/screens/kyc/presentation/pages/kyc_bank_screen.dart` — card brand dropdown + last-4 input, proof skip, dispose.
- **Modified** `lib/screens/kyc/presentation/pages/bank_list_screen.dart` — card detail rows + title formatter.
- **Modified** `lib/screens/finance/presentation/pages/withdrawal_screen.dart` — card branch in method gate, saved-card picker, submit validation. Vantage wrapper untouched.
- **Modified** `assets/translations/en.json` — 7 new `kyc_card_*` / `withdrawal_saved_cards_*` keys.
- **Modified** `assets/translations/ar.json` — Arabic equivalents.

## Verification

- [ ] `flutter analyze` clean on the 5 touched dart files (model, controller, kyc screen, bank list, withdrawal screen).
- [ ] Add-card flow: submit brand=Visa, last4=`0012` → row created, list renders `VISA •••• 0012` (leading zeros preserved).
- [ ] Client-side guard: `12`, `123`, `12345`, `12ab` are all rejected with the right toast before the OTP step.
- [ ] No proof-upload section is visible on the Card tab; submit with no proof image succeeds.
- [ ] Withdrawal-submit picker: Card tab is **absent** on a broker where admin has the master row `inactive`. Verify it appears after flipping active (no app restart needed — the picker reads the same master-methods list every build).
- [ ] Submit payload: `withdrawal_method=card`, `card_brand=visa|mastercard`, `card_last4=XXXX`, no `relationship`/`belongs_to`/proof field.
- [ ] Arabic build: card number with bullet characters renders correctly in RTL (`••••` is LTR-neutral; last4 stays LTR because it's rendered inside a `Text` widget which Flutter handles per-direction).

## Risks / Open questions

- **`local` category missing** — the proof short-circuit also checks `local`, but `selectedAccountType` is initialized to `'Crypto'` and the only categories that reach `_validateRequiredFields` are `Bank`, `Crypto`, `UPI`, and now `Card`. There is no `local` category in the current code. The `local` branch in the proof short-circuit is defensive parity with the backend — harmless but unreachable today. Removing it keeps the change minimal; keeping it protects against the day `local` is added.
- **`_buildWithdrawalRequestParams` proof-field-name call** — the method calls `_getProofFieldName()` unconditionally but only uses the result when `proofFile != null`. After adding the card case, a card submit with `proofFile == null` returns `card_proof_img` but never inserts it into params. If a future change removes the null-guard, the multipart uploader would use the correct field. No behavior change today.
- **`selectedCardMethodId` scope** — the spec mentions adding it to the controller. After inspecting, `selectedPaymentMethod` is the only selection state the controller owns; the bank/crypto picker IDs appear to be tracked locally in the screen. I'm introducing `selectedCardMethodId` as a local `Rxn<int?>` in the screen, matching that pattern. If the submit flow actually needs the ID in the controller's payload, promote it. Confirm by reading the submit path — see question for implementer.
- **`UserWithdrawalMethod` missing card fields** — `lib/screens/finance/view_models/withdrawal_controller.dart` has a `UserWithdrawalMethod` model (the per-user saved methods list) that doesn't yet expose `cardBrand` / `cardLast4`. The card picker in the payout screen reads from `WithdrawalMethods` (the master list). If the payout endpoint returns saved cards under a different key shape than what `WithdrawalMethods` already parses, this model may also need card fields. The spec assumes the same row shape; verify against the actual API response before promoting the fix.
