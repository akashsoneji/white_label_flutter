---
name: project-ibm-detail-overview-zero-data-bug
description: "IBM detail Overview $0.00 fix in progress — rewrote _buildOverviewTab to read partnerDetail/wallet/links/clientOverview + helpers; date dialog useRootNavigator; need analyze"
type: project
createdAt: 1787639395513
updatedAt: 1787639509580
---

IBM detail Overview $0.00 bug — FIX IN PROGRESS (2026-08-25). File: `lib/screens/ibm/presentation/pages/ibm_client_profile_screen.dart`.

**DONE this session:**
1. Dynamic tabs by isClient/isIb in `_resolveTabsAndLoad` (~L77). When isIb also calls `fetchPartnerWallet`+`fetchPartnerLinks`.
2. REWROTE `_buildOverviewTab` (now ~L517): wrapped in `Obx`, extracts data from CORRECT sources then delegates to new `_buildOverviewBody({...})` which holds the original widget tree. Sources:
   - Downline 8 cards ← `controller.currentPartnerDetail` (=/network/{id}): clients.own, clients.branch, partner.sub_partners (object map → count), branch[] first-currency block (deposits/withdrawals/net_funding/equity/lots/commission).
   - Wallet ← `controller.currentPartnerWallet['wallets']` first-currency (available/pending_payout/lifetime_earned/lifetime_paid).
   - Links ← `controller.currentPartnerLinks['links']`.
   - Own trading ← `controller.currentClientOverview['totals']` first-currency; accounts ← client['accounts']; history ← client['events'] (fallback history).
   - Added helpers: `_firstCurrency(list)` (USD-first), `_parseInt(v)`, `_countSubPartners(v)`.
   - Guard: shows "No overview data" only if BOTH client & partner empty.
3. History date now reads `hMap['at']` first (events use `at`).
4. Custom date dialog: added `useRootNavigator:true` + `barrierDismissible:true` to showDialog in `lib/screens/ibm/presentation/widgets/ibm_date_range_dialog.dart` (was showing barrier-only, no dialog on mobile).

**STILL TODO:** run `flutter analyze` on the file; verify no leftover references to old vars. The old widget tree kept var names (clientsOwn/clientsTotal/subIbs/deposits/withdrawals/netFunding/equity/lots/youEarned/wallet/links/ownTrading/accounts/history) as named params of _buildOverviewBody. Also the wallet 'Available' card reads `wallet['available'] ?? wallet['balance']` and pending reads `wallet['pending'] ?? wallet['pending_payout']` — doc key is `pending_payout` ✓ present as fallback; earned_all_time uses `lifetime_earned` fallback ✓; paid_out uses `lifetime_paid` ✓. Fine.

Constructor: IbmClientProfileScreen(clientId, clientName, isYou). isMe=widget.isYou. _parseDouble helper already existed.
