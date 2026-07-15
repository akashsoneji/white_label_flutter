Meta `_DetailSheet` close-position sheet pill row MT5 style on 2026-07-14.

**Reference (MT5):** The 7 volume pills (−0.50 −0.10 −0.01 0.02 +0.01 +0.10 +0.50) live inside ONE thin-bordered rectangle that reads as a single segmented control. Active pill = bold black text + black underline below. Enabled negative pill (−0.01) = blue text. Disabled positive pills = greyed out.

**Old Meta impl:** Each pill was an `Expanded` with `Border(bottom: blue)` only on the active one — no outer rectangle, no dividers between pills, blue active color. The underline looked like a stray line because nothing framed the row.

**New Meta impl (matching MT5):**
1. Outer `Container` around the pill `Row` with `Border.all(color: subText.withValues(alpha: 0.35), width: 0.8)`, `BorderRadius.circular(6.r)`, and `clipBehavior: Clip.hardEdge`.
2. Each pill draws its own LEFT divider (except i=0): `border: Border(left: BorderSide(color: subText.withValues(alpha: 0.25), width: 0.6))`. No individual top/bottom/right borders.
3. Active pill = bold `mainText(c)` text + bottom border in the SAME color so it reads as a single underline accent. Width 1.6.
4. Enabled −pill = `MetaTheme.buy(c)` (brand blue) text.
5. Disabled +pill = `subText(c).withValues(alpha: 0.55)` (grey).

**Why:** User compared against the MT5 reference and pointed out the underline "circulating unline" (extending across the row). The fix is the outer rectangle frame so the row reads as one component.

**Files:** `lib/brands/meta/meta_trade_screen.dart` — `_volumePill` method (~line 1576) and the pill `Row` container (~line 1767).

**Gotcha:** When editing `_volumePill`, the edit_file `ORIGINAL` block must match the EXACT method body once. If the match includes the closing `}` but the `UPDATED` block also includes a closing `}`, you can end up with a duplicate method declaration and the file won't compile. Always grep `^  Widget _volumePill` after the edit to confirm only one match.

**Verification:** `flutter analyze lib/brands/meta/meta_trade_screen.dart` → No issues found.

Related: [[project-meta-close-sheet-bidask-profit-partial-2026-07-14]].