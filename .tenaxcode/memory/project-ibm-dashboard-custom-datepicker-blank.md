---
name: project-ibm-dashboard-custom-datepicker-blank
description: "RESOLVED: IBM Dashboard Custom date filter blank-dialog bug — replaced showIbmDateRangeDialog with 2 native showDatePicker (start+end) in both apps"
type: project
createdAt: 1787748281788
updatedAt: 1787748281788
---

RESOLVED 2026-08-26: IBM Dashboard "Custom" date filter opened a BLANK dialog (custom Dialog/StatefulBuilder `showIbmDateRangeDialog` does not render inside the IbmMainShell/GetX navigator context — barrier shows, no content).

**FIX:** In `lib/screens/ibm/presentation/pages/ibm_manager_portal_screen.dart` `_onPeriodChanged()` custom branch, replaced `showIbmDateRangeDialog` with TWO sequential native Material `showDatePicker` calls (start date, then end date, helpText 'Select start date'/'Select end date', firstDate DateTime(2000)/start, lastDate now, ColorScheme.light primary=AppColors.primary). Then `final picked = DateTimeRange(start: start, end: end);` and a bare `{ ... }` block (was `if(picked!=null){`). `if (start==null) return;` / `if (end==null) return;` guard cancels. Removed the now-unused `import '.../widgets/ibm_date_range_dialog.dart'`. Native showDatePicker is the proven pattern (same as `lib/screens/home/trade_screen.dart`).

**APPLIED IN BOTH APPS** (identical file path): white_label (`/Users/admin/Desktop/Project/white_label/app/white_label`) AND crmapp (`/Users/admin/Desktop/Project/crmapp/app/crmapp`). Both analyze = 0 errors.

NOTE: `showIbmDateRangeDialog` is STILL USED (and works fine) in `ibm_clients_screen.dart` (My Clients Custom, ~L823) and `ibm_client_profile_screen.dart` (~L523) — those render OK because they're pushed in a normal navigator. Only the Dashboard (inside IbmMainShell bottom-nav) had the blank-render problem. If those two ALSO show blank later, apply the same two-showDatePicker swap there.

flutter bin `~/development/flutter/bin/flutter`.
