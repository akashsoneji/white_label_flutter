---
name: project-iquote-stepper-entry-anchor-2026-08-10
description: "iQuote position-detail TP/SL stepper behavior — entry-anchored blank, tick on subsequent"
type: project
createdAt: 1786357394649
updatedAt: 1786357394649
---

iQuote position-detail screen TP/SL stepper behavior (rewritten 2026-08-10):

- `_pipForSymbol(String symbol)` helper at line ~62: returns pip magnitude per symbol class
  - JPY/XAU/XAG prefix → 0.01
  - BTC/ETH prefix → 1.0
  - everything else (forex, indices, etc.) → 0.0001
- `_bump(TextEditingController c, double delta, int digits, {required int slPips})` in `_TpSlPanel`:
  - BLANK-field branch: anchor to `pos.entryPrice` (NOT mid-market) and apply `delta * slPips * pip`
    - SL buttons pass slPips=50 → entry ± 50 pips (SL distance for 1:1 risk)
    - TP buttons pass slPips=100 → entry ± 100 pips (TP distance for 1:2 reward)
    - Falls back to live mid-market ONLY if entry price is missing/zero
  - NON-BLANK branch: move by ONE tick (last-digit increment) using `pow(10, -digits)`
    - This gives a single-digit increment per press, regardless of broker pip convention
    - digits=2 (XAUUSD, JPY, BTCUSD with 2 decimals) → 0.01 step
    - digits=5 (5-digit forex) → 0.00001 step
- Focus auto-fill (_handleTpFocusChange / _handleSlFocusChange) uses the same _pipSizeFor helper and same 50-pip SL / 100-pip TP 1:2 reward logic for consistency.

**Why:** User reported stepper on blank fields was producing values far from entry (anchored to mid-market caused SL on a Buy to land below the bid, triggering immediate-close on any tick up). Also wanted subsequent presses to move by ONE digit (last-digit increment), not by another 50 pips.

**How to apply:**
- BLANK field: ALWAYS anchor to `pos.entryPrice` first, mid-market fallback only if entry is missing.
- NON-BLANK field: use `pow(10, -digits)` for tick size — this matches what the user sees as the last digit.
- TP and SL are independent; each button onPressed passes its OWN controller to _bump. NEVER share controllers.
- 50-pip SL / 100-pip TP is the unified scale for all symbols — `_pipForSymbol` handles per-symbol magnitude so XAUUSD gets 0.50/1.00 while EURUSD gets 0.0050/0.0100.
- The same `_pipForSymbol` helper is used by both auto-fill and stepper for consistency. If new symbol classes are added (e.g. indices), update the helper and both call sites will pick up the change.

Related: [[project-iquote-position-detail-no-tab-2026-08-06]], [[project-iquote-pl-multifix]]
