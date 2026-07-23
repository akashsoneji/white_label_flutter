# Riyadex Registration Implementation Plan

## Goal
Implement a custom dynamic registration screen for the `riyadex` brand, governed by the remote configuration at `https://register.riyadex.com/countries.php`. The registration UI dynamically adapts based on the `required_fields` array from the selected country. 

## Approach
Currently, `riyadex` inherits the `vantage` UI parent in `UiRegistry`. We will intercept the `createAccount()` method in `UiRegistry` to return a `RiyadexCreateAccountScreen` exclusively when `FlavorConfig.isRiyadex()` is true.
To drive the screen, we'll implement a GetX controller (`RiyadexRegistrationController`) that fetches the country configuration and the IP geolocation on startup.

The UI will match the mockups and react strictly to the `required_fields` array of the selected country:
1. **Minimal Form:** If `required_fields` contains ONLY `["email", "password"]`, the UI will show exactly: Country Dropdown, Email, Password, Partner Code, and US tax checkbox.
2. **Full Form (Current Design):** If `required_fields` contains `first_name`, `last_name`, `mobile`, etc., the UI will show the full current layout (Country, First Name, Last Name, Email, Phone Number, Password, etc.).
3. **Restricted:** If `tier == "restricted"` and the user's IP (`geo.php`) does not match the selected country, the registration form is blocked and shows the restricted error message.

## Steps

- [ ] **Step 1: Domain/Models for API responses**
  - Create `lib/screens/auth/data/models/riyadex_country_config.dart`.
  - Add models for the Country data (`RiyadexCountry`), parsing `required_fields` as a `List<String>`.
  - Add models for the top-level config (`RiyadexConfigData`) and GeoIP response (`RiyadexGeoLocation`).

- [ ] **Step 2: Service / Controller**
  - Create `lib/screens/auth/view_models/riyadex_registration_controller.dart`.
  - Add API calls to `GET https://register.riyadex.com/countries.php` and `GET https://register.riyadex.com/geo.php`.
  - Expose Rx variables: `isLoading`, `countries`, `selectedCountry`, `geoCountry`, `allowedToRegister`.
  - Add a helper `bool get isMinimal => selectedCountry.value?.required_fields.length == 2 && selectedCountry.value!.required_fields.contains('email');` (or similar logic to check for the exact minimal array).
  - Implement form submission payload construction. Delegate to the existing `AuthController.register(data: ...)` and omit `first_name`, `last_name`, `mobile`, `country_code` when the form is minimal.

- [ ] **Step 3: UI Widget Creation**
  - Create `lib/screens/auth/presentation/brands/riyadex/pages/riyadex_create_account_screen.dart`.
  - Build the screen matching the design:
    - Tab-like header ("Sign in" / "Create an account").
    - Country Selection dropdown using a bottom sheet or a styled dropdown menu.
    - **Dynamic Form Section:**
      - If `controller.isMinimal` is true: show ONLY Email and Password.
      - Else: show First Name, Last Name, Phone Number, Email, and Password.
    - Password rules indicator (8-15 characters, uppercase/lowercase, number, special char).
    - Partner code expansion tile.
    - US citizen checkbox.
    - Submit button ("Register").

- [ ] **Step 4: Update Routing / UiRegistry**
  - Edit `lib/app/ui_registry.dart`.
  - In `createAccount()`, add:
    ```dart
    if (FlavorConfig.isRiyadex()) {
      return const riyadex.RiyadexCreateAccountScreen();
    }
    ```
  - Ensure the `riyadex` import is added at the top.

## Files
- `lib/screens/auth/data/models/riyadex_country_config.dart` (New)
- `lib/screens/auth/view_models/riyadex_registration_controller.dart` (New)
- `lib/screens/auth/presentation/brands/riyadex/pages/riyadex_create_account_screen.dart` (New)
- `lib/app/ui_registry.dart` (Modify to inject the Riyadex specific screen)

## Risks / Open questions
- The existing backend CRM registration payload might fail if `mobile` or `first_name` are missing, even for Riyadex. The backend handling Riyadex MUST be configured to accept these minimal payloads without returning 400 Validation Errors.
- Google Auth integration must still be triggered if the user chooses the Google option at the bottom of the screen.