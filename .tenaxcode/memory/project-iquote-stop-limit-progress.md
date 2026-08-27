---
name: project-iquote-stop-limit-progress
description: "DONE: iQuote (1) double-click duplicate-order fixed via onPressed: !isLoading guard on Market+Pending buttons; (2) TP/SL stuck-after-edit fixed via text-_lastAutoTp/Sl diff detection. analyze clean."
type: project
createdAt: 1787817206845
updatedAt: 1787821240784
---

DONE 2026-08-27: iQuote double-click + TP/SL stuck bugs both fixed in `lib/screens/home/brands/iquote/iquote_chart_screen.dart`. analyze: 0 errors, 8 pre-existing warnings.

BUG 1 (double-click duplicate order) FIX:
- Market button onPressed: `onPressed: widget.ctrl.isLoading.value ? null : () => _submit(side),`
- Pending button onPressed: `onPressed: widget.ctrl.isLoading.value ? null : () => _submit(sideForSubmit),`
- Loader UI (Obx child) already there — now the button is also DISABLED at the framework level so a second tap during the in-flight call does nothing.

BUG 2 (TP/SL stuck after manual edit) FIX — text-diff detection:
- Removed sticky `bool _isTpCustom; bool _isSlCustom;` flags (focus-based, never reset).
- Replaced with `String? _lastAutoTp; String? _lastAutoSl;` — cache of the last auto-computed formatted strings.
- Removed the two focus listeners (_tpCtl/_slCtl.addListener) — no longer needed.
- New logic in `_updateTpSlFromMarketPrice()`: only auto-overwrite the field when it's empty OR it currently matches `_lastAutoTp` (the value we last wrote). If user typed something different, the diff keeps us out of the way. If they delete back to our value (or ±-step lands on it), we resume auto-updating on the next bid/ask tick. Still skips write while a field has focus (avoid clobbering in-progress edit).
- `_lastAutoTp = tpStr; _lastAutoSl = slStr;` at the end of update fn so cache stays current.
- `_onOrderTypeChanged` + TP/SL toggle ON handler both reset `_lastAutoTp/Sl = null` to force fresh auto-fill.

Replaces [[project-iquote-stop-limit-progress]] (which had the loader/dropdown work). flutter bin `~/development/flutter/bin/flutter`.
