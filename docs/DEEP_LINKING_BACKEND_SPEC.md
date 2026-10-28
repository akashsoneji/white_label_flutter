# Deep Linking & Referral Attribution: Web / Server Specification

Audience: backend and web team. Owner of the mobile side: mobile team.
**Phase 1 scope: Tenax and PipPro only.** Other brands follow later with the same steps.

## 1. Overview

We are adding **Android App Links** and **iOS Universal Links** to our white-label trading apps. When a user opens an `https://<brand-domain>/...` link:

- **App installed:** the app opens directly on the right screen. A referral code in the link is saved automatically.
- **App NOT installed:** the link opens your web landing page. The page sends the user to the Play Store or App Store. After install, the app recovers the referral code on its first launch.

Each brand has its own domain and its own app, so everything below is done **per brand**. Section 2 has the exact values for Phase 1.

The server side needs these deliverables, per brand:
1. Two verification files under `/.well-known/` (ready-to-host versions are in §3).
2. Web landing pages for the app paths (§4).
3. A `referral_clicks` table that records clicks (§5).
4. A public API, `POST /api/deeplink/deferred/claim` (§6).
5. An optional attribution API (§7).
6. Two optional fields on the registration API (§8).

## 2. Brands in scope (Phase 1)

### 2.1 Tenax
- Brand key (used in APIs and DB): `tenax`
- Deep-link domain: `dev.tenaxcodecrm.com`. This is the CRM domain the app uses today, and it is the DEV environment. **Backend: confirm the production domain.** The same files must be hosted there before the store release.
- API base used by the app: `https://dev.tenaxcodecrm.com/api/`
- Android package name (application ID): `com.tenax.app`
- iOS bundle ID: `com.tenax.app`
- Apple Team ID: `8WXRXCSTK2` (from the Xcode project; the mobile team will reconfirm it against the App Store Connect account that publishes Tenax)
- iOS App ID used in the AASA file: `8WXRXCSTK2.com.tenax.app`
- Play Store URL: `https://play.google.com/store/apps/details?id=com.tenax.app`
- App Store URL: `https://apps.apple.com/app/id<TENAX_APP_STORE_ID>` (the mobile team sends the numeric ID)
- Example referral link: `https://dev.tenaxcodecrm.com/ref/ABC123`

### 2.2 PipPro
- Brand key: `pippro`
- Deep-link domain: `my.pipze.com`. This is the CRM domain the PipPro app uses today.
- API base used by the app: `https://my.pipze.com/api/`
- Android package name (application ID): `com.pippro.app`
- iOS bundle ID: `com.pippro.app`
- Apple Team ID: `8WXRXCSTK2` (mobile team to reconfirm, same as Tenax)
- iOS App ID used in the AASA file: `8WXRXCSTK2.com.pippro.app`
- Play Store URL: `https://play.google.com/store/apps/details?id=com.pippro.app`
- App Store URL: `https://apps.apple.com/app/id<PIPPRO_APP_STORE_ID>` (the mobile team sends the numeric ID)
- Example referral link: `https://my.pipze.com/ref/ABC123`

Note on `my.pipze.com`: other brands (Pipze, iQuote, Vantage) also run on the Pipze CRM. If any of their apps later claims `my.pipze.com`, both files on this domain must be **merged** to contain both apps (§3.5). Do not replace the file.

### 2.3 SHA-256 certificate fingerprints (Android)
The mobile team fills these in. Each Android app needs two values:
- **Upload / release key** fingerprint, read from the brand's keystore: `keytool -list -v -keystore <brand keystore>.jks -alias <alias>`
- **Google Play App Signing key** fingerprint: Play Console → the app → Test and release → App integrity → App signing → "App signing key certificate" → SHA-256.

Placeholders used below: `<TENAX_UPLOAD_SHA256>`, `<TENAX_PLAY_SIGNING_SHA256>`, `<PIPPRO_UPLOAD_SHA256>`, `<PIPPRO_PLAY_SIGNING_SHA256>`. Format: colon-separated uppercase hex, e.g. `14:6D:E9:...:A5`.

## 3. Verification files (mandatory, per domain)

### 3.1 Tenax: files for `dev.tenaxcodecrm.com` (and the production domain)

`https://dev.tenaxcodecrm.com/.well-known/assetlinks.json`
```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.tenax.app",
      "sha256_cert_fingerprints": [
        "<TENAX_UPLOAD_SHA256>",
        "<TENAX_PLAY_SIGNING_SHA256>"
      ]
    }
  }
]
```

`https://dev.tenaxcodecrm.com/.well-known/apple-app-site-association` (no file extension)
```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["8WXRXCSTK2.com.tenax.app"],
        "components": [
          { "/": "/ref/*" },
          { "/": "/register*" },
          { "/": "/reset-password*" },
          { "/": "/verify-email*" },
          { "/": "/app/*" }
        ]
      }
    ]
  }
}
```

### 3.2 PipPro: files for `my.pipze.com`

`https://my.pipze.com/.well-known/assetlinks.json`
```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.pippro.app",
      "sha256_cert_fingerprints": [
        "<PIPPRO_UPLOAD_SHA256>",
        "<PIPPRO_PLAY_SIGNING_SHA256>"
      ]
    }
  }
]
```

`https://my.pipze.com/.well-known/apple-app-site-association` (no file extension)
```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["8WXRXCSTK2.com.pippro.app"],
        "components": [
          { "/": "/ref/*" },
          { "/": "/register*" },
          { "/": "/reset-password*" },
          { "/": "/verify-email*" },
          { "/": "/app/*" }
        ]
      }
    ]
  }
}
```

The mobile team also generates these files from the app config with `scripts/generate_well_known.dart`, with the real SHA-256 values filled in, and sends them over. The generated files take precedence over the snippets above.

### 3.3 Hosting requirements (both files, every domain)

Apple and Google crawlers fail silently if any of these is wrong:
- URL: exactly `https://<domain>/.well-known/<file>`.
- HTTPS with a valid public certificate.
- HTTP status `200`.
- **No redirects at all.** That includes http→https, apex→www, locale and trailing-slash redirects on these two URLs.
- Header `Content-Type: application/json`.
- No auth, cookies, IP or geo blocking, or bot challenges. Exclude `/.well-known/*` from Cloudflare Bot Fight Mode, WAF challenges and login middleware.
- File size under 128 KB.

### 3.4 Server config examples

nginx:
```nginx
location = /.well-known/apple-app-site-association {
    default_type application/json;
    try_files $uri =404;
}
location = /.well-known/assetlinks.json {
    default_type application/json;
    try_files $uri =404;
}
```

Apache (`.htaccess` inside `public/.well-known/`):
```apache
<Files "apple-app-site-association">
    ForceType application/json
</Files>
```

Laravel: put both files in `public/.well-known/`. If routing is preferred instead:
```php
Route::get('/.well-known/apple-app-site-association', fn () =>
    response()->file(public_path('.well-known/apple-app-site-association'), ['Content-Type' => 'application/json']));
Route::get('/.well-known/assetlinks.json', fn () =>
    response()->file(public_path('.well-known/assetlinks.json'), ['Content-Type' => 'application/json']));
```
These routes must not pass through `auth`, locale or `www`-redirect middleware.

If one Laravel app serves several brand domains, return the file that matches the request host. For example, keep `storage/well-known/<host>/assetlinks.json` and pick it by `request()->getHost()`.

### 3.5 Shared domain for several apps
If a domain must serve more than one app (for example `my.pipze.com` for PipPro and later Pipze), keep ONE file per type:
- Add another object to the `assetlinks.json` array, one per package name.
- Add another `details` entry (or another value in `appIDs`) in the AASA file.

## 4. Landing pages (when the app is NOT installed)

When the app is installed, the OS opens the app and your server never sees the request. When it is not installed, the browser loads your page. So each app path needs a real web page on `dev.tenaxcodecrm.com` (Tenax) and `my.pipze.com` (PipPro).

Important for `my.pipze.com` and `dev.tenaxcodecrm.com`: these are the existing CRM portals. Once the app is installed on a phone, any URL under `/ref`, `/register`, `/reset-password`, `/verify-email` or `/app` opens the app instead of the web portal. Confirm that no existing web-only page lives under these prefixes. If one does, tell the mobile team and we will narrow the paths.

### 4.1 `GET /ref/{code}`: main flow
1. Resolve the brand from the request host (`dev.tenaxcodecrm.com` → `tenax`, `my.pipze.com` → `pippro`).
2. Validate the code with the logic behind `GET /api/ibm/referral-registration/check/{code}`. Invalid or expired code: show a friendly page and continue without a referral.
3. Insert a `referral_clicks` row (§5) with the server-side data: `click_id` (UUID), brand, code, IP, user agent, parsed OS version and device family.
4. A JS snippet on the page POSTs extra device data to `POST /api/deeplink/click/{click_id}/enrich`:
   - `timezone`: `Intl.DateTimeFormat().resolvedOptions().timeZone`
   - `language`: `navigator.language`
   - `screen_w`, `screen_h`: `screen.width`, `screen.height`
   - `pixel_ratio`: `window.devicePixelRatio`
5. Branch on the user agent. Do the redirect after the enrich call, or after a 1.5 s timeout.
   - **Android:**
     - Tenax: `https://play.google.com/store/apps/details?id=com.tenax.app&referrer=<ENCODED>`
     - PipPro: `https://play.google.com/store/apps/details?id=com.pippro.app&referrer=<ENCODED>`
     - `<ENCODED>` is the URL-encoded `ref_code=<code>&click_id=<click_id>`. Example: `ref_code%3DABC123%26click_id%3D7f3c2a10-...`. Keep the decoded value short (under 200 chars).
   - **iOS:** show the page with a "Download on the App Store" button.
     - Tenax button: `https://apps.apple.com/app/id<TENAX_APP_STORE_ID>`. PipPro button: `https://apps.apple.com/app/id<PIPPRO_APP_STORE_ID>`.
     - Optional clipboard fallback (needs product sign-off). In the button's click handler, before navigating, run `navigator.clipboard.writeText("tenax-ref:<code>")` or `navigator.clipboard.writeText("pippro-ref:<code>")`.
     - Smart App Banner in `<head>`:
       ```html
       <meta name="apple-itunes-app" content="app-id=<APP_STORE_ID>, app-argument=https://<domain>/ref/<code>">
       ```
   - **Desktop or other:** redirect to the existing web registration page with `?ref=<code>`.
6. Also show an "Open in app" button that links to the same `https://<domain>/ref/<code>`. It helps users who already have the app but whose in-app browser did not hand the link to the app.

### 4.2 Other paths
- `/register?ref=<code>`: the existing web register page, with `ref` prefilled.
- `/reset-password?token=&email=` and `/verify-email?token=`: the existing web pages keep working. When the app is installed, the app opens instead and calls the same backend APIs with the token.
- `/app/*`: a simple "Open the app / Get the app" page with the store button for the user's platform.

### 4.3 Host → brand config table
Keep one config entry per brand. Phase 1 values:
```php
'deeplink_brands' => [
    'dev.tenaxcodecrm.com' => [
        'brand'          => 'tenax',
        'android_app_id' => 'com.tenax.app',
        'ios_bundle_id'  => 'com.tenax.app',
        'apple_team_id'  => '8WXRXCSTK2',
        'app_store_id'   => '<TENAX_APP_STORE_ID>',
        'play_url'       => 'https://play.google.com/store/apps/details?id=com.tenax.app',
        'clipboard_tag'  => 'tenax-ref',
    ],
    'my.pipze.com' => [
        'brand'          => 'pippro',
        'android_app_id' => 'com.pippro.app',
        'ios_bundle_id'  => 'com.pippro.app',
        'apple_team_id'  => '8WXRXCSTK2',
        'app_store_id'   => '<PIPPRO_APP_STORE_ID>',
        'play_url'       => 'https://play.google.com/store/apps/details?id=com.pippro.app',
        'clipboard_tag'  => 'pippro-ref',
    ],
],
```

## 5. Database: `referral_clicks`

```sql
CREATE TABLE referral_clicks (
  id            BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  click_id      CHAR(36)     NOT NULL UNIQUE,
  brand         VARCHAR(50)  NOT NULL,          -- 'tenax' | 'pippro'
  code          VARCHAR(64)  NOT NULL,
  platform      ENUM('ios','android','desktop','other') NOT NULL,
  ip            VARCHAR(45)  NOT NULL,          -- full IPv4/IPv6
  ip_prefix     VARCHAR(45)  NOT NULL,          -- IPv4 as-is, IPv6 normalised to /64
  user_agent    VARCHAR(512) NULL,
  os_version    VARCHAR(20)  NULL,
  device_family VARCHAR(50)  NULL,
  language      VARCHAR(20)  NULL,
  timezone      VARCHAR(64)  NULL,
  screen_w      SMALLINT     NULL,
  screen_h      SMALLINT     NULL,
  pixel_ratio   DECIMAL(3,1) NULL,
  created_at    DATETIME     NOT NULL,
  claimed_at    DATETIME     NULL,
  claimed_via   ENUM('play_referrer','server_match','clipboard','link') NULL,
  user_id       BIGINT UNSIGNED NULL,
  INDEX idx_match (brand, platform, ip_prefix, created_at),
  INDEX idx_code (code)
);
```
Retention: delete unclaimed rows older than 30 days (scheduled job).

If Tenax and PipPro run on separate CRM installs (`dev.tenaxcodecrm.com` vs `my.pipze.com`), each install gets its own table, and `brand` simply holds that install's value.

## 6. API: deferred referral claim

Endpoints, on each brand's own API base:
- Tenax: `POST https://dev.tenaxcodecrm.com/api/deeplink/deferred/claim`
- PipPro: `POST https://my.pipze.com/api/deeplink/deferred/claim`

Public (no auth). The app calls it **once**, on the first launch after install, only when the user is logged out and no referral is already known.

Request:
```json
{
  "brand": "pippro",
  "platform": "ios",
  "os_version": "17.5",
  "device_model": "iPhone15,2",
  "language": "en-IN",
  "timezone": "Asia/Kolkata",
  "screen_w": 393,
  "screen_h": 852,
  "pixel_ratio": 3.0
}
```
The client IP comes from the request. Behind a proxy or CDN, use the trusted `X-Forwarded-For` / `CF-Connecting-IP`.

Response (existing envelope):
```json
{ "success": true, "message": "", "data": { "code": "ABC123", "click_id": "7f3c...", "label": "Summer promo" } }
```
No match:
```json
{ "success": true, "message": "", "data": { "code": null } }
```

Matching:
1. Candidates: `brand` = req.brand AND `platform` = req.platform AND `claimed_at IS NULL` AND `created_at` ≥ now() − 24h (configurable) AND `ip_prefix` = normalise(request IP).
2. Score each: +3 `os_version` equal, +2 `timezone` equal, +2 screen width/height equal, +1 `language` equal (prefix match is fine), +1 `pixel_ratio` equal.
3. Pick the highest score, then the newest. Accept only if score ≥ 3 (configurable).
4. In one transaction, set `claimed_at = now()` and `claimed_via = 'server_match'`.
5. Re-check that the code is still active before returning it.

Security: rate-limit per IP (e.g. 10/min). Return at most one code. The code only pre-fills the signup form, and registration validates it again.

Known limitation: a network change between the click and the first launch (WiFi ↔ mobile data) changes the IP, so the match fails. The app then falls back to manual entry. Android mostly uses the Play referrer instead.

## 7. API: attribution (optional, recommended)

`POST <api base>/deeplink/attribution`. Public, rate-limited.
```json
{ "brand": "tenax", "click_id": "7f3c...", "code": "ABC123", "source": "play_referrer" }
```
`source` is one of `link`, `play_referrer`, `server_match`, `clipboard`, `manual`. When the row is unclaimed, set `claimed_at` and `claimed_via`.

Response: `{ "success": true, "message": "", "data": null }`.

## 8. Registration API change

The existing registration endpoints already accept `ib_affiliate_refcode` / `refer_code`. Add these optional fields:
- `referral_source`: one of `link`, `play_referrer`, `server_match`, `clipboard`, `manual`
- `referral_click_id`

On success, set `referral_clicks.user_id` for that `click_id`.

## 9. Pending items

From mobile to backend:
- [ ] Tenax: upload-key SHA-256, Play App Signing SHA-256, App Store numeric ID, reconfirmed Team ID
- [ ] PipPro: upload-key SHA-256, Play App Signing SHA-256, App Store numeric ID, reconfirmed Team ID
- [ ] Generated `.well-known` files for both domains

From backend to mobile:
- [ ] Production domain for Tenax, if it is not `dev.tenaxcodecrm.com`
- [ ] Confirmation that no web-only pages live under `/ref`, `/register`, `/reset-password`, `/verify-email` or `/app` on either domain
- [ ] Confirmation that both `.well-known` URLs are live (200 + JSON, no redirect) on both domains
- [ ] Landing pages and claim API live, with the final URLs

## 10. Testing checklist (backend)

- [ ] `curl -sI https://dev.tenaxcodecrm.com/.well-known/assetlinks.json` returns 200 and `application/json`, no `Location` header.
- [ ] `curl -sI https://dev.tenaxcodecrm.com/.well-known/apple-app-site-association`: same.
- [ ] `curl -sI https://my.pipze.com/.well-known/assetlinks.json`: same.
- [ ] `curl -sI https://my.pipze.com/.well-known/apple-app-site-association`: same.
- [ ] Google validator lists the right package:
  - `https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://dev.tenaxcodecrm.com&relation=delegate_permission/common.handle_all_urls` (`com.tenax.app`)
  - `https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://my.pipze.com&relation=delegate_permission/common.handle_all_urls` (`com.pippro.app`)
- [ ] Apple CDN returns our file. Apple caches it, so updates can take up to about 24 hours.
  - `https://app-site-association.cdn-apple.com/a/v1/dev.tenaxcodecrm.com`
  - `https://app-site-association.cdn-apple.com/a/v1/my.pipze.com`
- [ ] `https://my.pipze.com/ref/TEST123` on Android redirects to `...details?id=com.pippro.app&referrer=ref_code%3DTEST123%26click_id%3D...`
- [ ] `https://dev.tenaxcodecrm.com/ref/TEST123` on Android redirects to `...details?id=com.tenax.app&referrer=...`
- [ ] The same links on iPhone Safari show the App Store page, and a click row is stored with timezone/screen data.
- [ ] Claim API from the same network within 24h returns `TEST123`. A second call returns `null`.
- [ ] An invalid code shows the friendly page and stores no claimable row.
- [ ] The claim API rate limit works.

## 11. Rollout order
1. Mobile sends the §9 values and the generated files.
2. Backend hosts the `.well-known` files on `dev.tenaxcodecrm.com` and `my.pipze.com` (plus the Tenax production domain), then verifies them (§10).
3. Backend ships the landing pages, `referral_clicks`, the claim API and the registration fields.
4. Mobile releases Tenax and PipPro builds with deep linking to Play internal testing and TestFlight.
5. Joint end-to-end test: install from link (Android + iOS), then open the link with the app installed. Then go to production.
