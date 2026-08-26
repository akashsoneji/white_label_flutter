---
name: project-ibm-datefilter-fullwidth-pills
description: "IBM date-filter pills → full-width rounded design on Dashboard+profile (both apps); white_label done, crmapp pending; profile also got 2-showDatePicker swap"
type: project
createdAt: 1787748788089
updatedAt: 1787748788089
---

TASK (2026-08-26): Make IBM date-filter pill rows FULL-WIDTH (rounded pill, like My Clients tab design) on Dashboard + client-profile. ALSO the profile screen still had blank-dialog `showIbmDateRangeDialog` → swapped to two native showDatePicker (same fix as [[project-ibm-dashboard-custom-datepicker-blank]]).

**WHITE_LABEL — DONE (analyze pending):**
1. `ibm_manager_portal_screen.dart` `_buildToggleGroup`: added `bool fillWidth=false` param. When true: Container width=double.infinity, padding EdgeInsets.all(3.w), Row mainAxisSize.max with each item wrapped in `Expanded`; item padding vertical 8.h, alignment center, selected bg AppColors.primary else transparent. Period row (`_buildHeaderRow`, was wrapped in SingleChildScrollView horizontal) replaced: removed scroll wrapper, now `SizedBox(height:10.h)` + `_buildToggleGroup(...options today/7d/30d/this_month(MTD)/all/custom..., fillWidth:true)`. The scope toggle (Total/Network/Direct) still uses default fillWidth:false (unchanged).
2. `ibm_client_profile_screen.dart` `_buildDateFilters()` (~L503): rewrote — Container width double.infinity + padding all(3.w), Row of `Expanded` items (was SingleChildScrollView+min Row). Each item center-aligned, vertical 8.h, pill radius 20, selected AppColors.primary. Custom branch now two showDatePicker (start/end, helpText, ColorScheme.light primary=AppColors.primary) → setState _customStartDate/_customEndDate + _fetchDataForTab(_tabController.index). Removed unused import `ibm_date_range_dialog.dart` (was L9).

**CRMAPP — NOT DONE YET.** Apply IDENTICAL changes to same two files under `/Users/admin/Desktop/Project/crmapp/app/crmapp/lib/screens/ibm/presentation/pages/`:
- `ibm_manager_portal_screen.dart`: same `_buildToggleGroup` fillWidth param + period row fillWidth:true (remove SingleChildScrollView wrapper). NOTE crmapp period row earlier already had the two-showDatePicker custom fix applied.
- `ibm_client_profile_screen.dart`: same `_buildDateFilters` full-width rewrite + two-showDatePicker swap + remove `ibm_date_range_dialog.dart` import. Verify crmapp profile still uses showIbmDateRangeDialog (it should, wasn't touched before).

flutter bin `~/development/flutter/bin/flutter`. analyze both files per app after edits (expect 0 errors; stale unused-import warnings clear on real analyze).

NOTE: My Clients tab (`ibm_clients_screen.dart`) date row is ALREADY the reference full-width design (bordered container + SingleChildScrollView) — user wants Dashboard+profile to MATCH it. Left as-is.
