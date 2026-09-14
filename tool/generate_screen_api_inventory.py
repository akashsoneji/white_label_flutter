#!/usr/bin/env python3
"""Generate exhaustive screen/API inventory artifacts for the white-label Flutter app.

Usage from repository root:
  python3 tool/generate_screen_api_inventory.py

The generator treats brand/export wrappers as aliases of their shared implementation,
extracts route registrations, API constant/literal references, and flags local-only
screens. It writes the documentation and Postman collection requested for handoff.
"""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "lib"
DOC = ROOT / "docs/WHITE_LABEL_API_SCREEN_INVENTORY.md"
COLLECTION = ROOT / "WhiteLabel_App_API_Exhaustive_Screen_Inventory.postman_collection.json"

MODULE_RULES = {
    "Auth": ("screens/auth", "auth_controller", "auth_service", "google_otp_service"),
    "Trading": ("screens/home", "screens/trading", "trading_controller", "trading_repository"),
    "Finance": ("screens/finance", "screens/wallet", "finance_repository", "wallet_repository"),
    "Copy Trading": ("screens/copy_trading", "copy_trading"),
    "IB": ("screens/ib", "screens/ibm", "ib_controller", "ibm_api_provider"),
    "KYC": ("screens/kyc", "kyc_controller", "compliance_controller"),
    "Bonus": ("screens/bonus", "scratch_card"),
    "Demo Contest": ("screens/demo_contest", "demo_contest"),
    "Trade & Win": ("screens/trade_win", "trade_win"),
    "PMAM": ("screens/home/more/pmam", "pmam"),
    "Support / Tickets": ("screens/home/more/ticket", "ticket"),
    "More / Settings": ("screens/home/more", "screens/settings", "notifications"),
    "Brand / Core": ("brands/", "screens/common", "screens/example"),
}

API_NAMES = re.compile(r"ApiConstants\.([A-Za-z0-9_]+)|(?:endpoint|url)\s*:\s*['\"]([^'\"]*(?:user/|ibm/|copytrading/|v1/user/|charthistory)[^'\"]*)")
ROUTE_TARGET = re.compile(r"name:\s*_Paths\.([A-Z0-9_]+).*?page:\s*.*?([A-Z][A-Za-z0-9_]*Screen)", re.S)

def module(path: str) -> str:
    for name, needles in MODULE_RULES.items():
        if any(n in path for n in needles):
            return name
    return "Other"

def alias_target(text: str) -> str | None:
    m = re.search(r"export\s+['\"]([^'\"]+)['\"]", text)
    return m.group(1) if m else None

def route_map() -> dict[str, str]:
    p = LIB / "routes/app_pages.dart"
    text = p.read_text(errors="ignore")
    result: dict[str, str] = {}
    for m in re.finditer(r"GetPage\(\s*name:\s*_Paths\.([A-Z0-9_]+).*?page:\s*\(.*?=>\s*(?:const\s+)?([A-Za-z][A-Za-z0-9_]*)", text, re.S):
        result[m.group(1)] = m.group(2)
    return result

def scan() -> list[dict]:
    routes = route_map()
    by_target = {v: k for k, v in routes.items()}
    rows = []
    for path in sorted(LIB.rglob("*.dart")):
        if not path.name.endswith("_screen.dart"):
            continue
        rel = path.relative_to(ROOT).as_posix()
        text = path.read_text(errors="ignore")
        apis = sorted({a or b for a, b in API_NAMES.findall(text) if a or b})
        alias = alias_target(text)
        class_match = re.search(r"class\s+([A-Za-z][A-Za-z0-9_]*)", text)
        screen = class_match.group(1) if class_match else path.stem
        route = by_target.get(screen)
        local = []
        if alias: local.append("export/wrapper; API owned by shared target")
        if not apis and not alias: local.append("no direct endpoint reference; inspect injected controller/service")
        if "WebView" in text or "webview" in text: local.append("WebView/chart or external navigation")
        if "Timer" in text or "Future.delayed" in text: local.append("timer/delayed UI or polling logic")
        if "SharedPreferences" in text: local.append("local persistent state")
        rows.append({"module": module(rel), "screen": screen, "path": rel, "route": route, "api_refs": apis, "alias": alias, "local_logic": local})
    return rows

def main() -> None:
    rows = scan()
    grouped: dict[str, list[dict]] = {}
    for row in rows: grouped.setdefault(row["module"], []).append(row)
    lines = ["# White Label App — Exhaustive Screen/API Inventory", "", f"Generated from current `lib/` source. Screen implementation files scanned: **{len(rows)}**.", "", "## Interpretation", "", "- API ownership is controller/repository/service based; screens without direct constants inherit the listed controller path.", "- Export-only brand wrappers are recorded as aliases and are not counted as independent API implementations.", "- `api_refs` are source references, not guessed endpoint paths. Resolve constants from `lib/constants/api_const.dart` and IBM provider maps.", "- Local logic flags identify wrapper, WebView, timer/polling, persistence, or no-direct-API screens.", ""]
    for name in sorted(grouped):
        lines += [f"## {name} ({len(grouped[name])} screens)", "", "| Screen | File | Route | API references | Local/API ownership |", "|---|---|---|---|---|"]
        for r in grouped[name]:
            refs = ", ".join(r["api_refs"]) or "inherited/controller-owned"
            route = r["route"] or "embedded / no GetPage"
            local = "; ".join(r["local_logic"]) or "screen-local presentation only"
            lines.append(f"| `{r['screen']}` | `{r['path']}` | `{route}` | `{refs}` | {local} |")
        lines.append("")
    lines += ["## Shared local/API logic", "", "- `ApiService` attaches bearer authentication, retries, parses errors, and handles global unauthenticated redirects.", "- Trading screens consume market-watch/symbols/open-position/pending-order WebSockets; chart history uses direct `chartBaseUrl/charthistory` REST.", "- Finance, wallet, IB, IBM, copy trading, PMAM, KYC, bonus, contest, Trade & Win, and tickets are controller/repository/service backed; UI wrappers inherit those APIs.", "- Vantage-family and Pipze screens share implementation; only `FlavorConfig` URLs and brand UI/features vary.", ""]
    DOC.write_text("\n".join(lines) + "\n")
    items = []
    for name in sorted(grouped):
        requests = []
        for r in grouped[name]:
            refs = ", ".join(r["api_refs"]) or "controller/repository inherited"
            requests.append({"name": r["screen"], "request": {"method": "GET", "url": "{{base_url}}__screen__", "description": f"File: {r['path']}\\nRoute: {r['route'] or 'embedded/no GetPage'}\\nAPI refs: {refs}\\nLocal logic: {'; '.join(r['local_logic']) or 'presentation only'}"}})
        items.append({"name": f"{name} — screens", "item": requests})
    collection = {"info": {"name": "White Label API — Exhaustive Screen Inventory", "description": f"Generated from {len(rows)} screen Dart files. Requests are inventory records; use WhiteLabel_App_API.postman_collection.json for executable endpoint bodies.", "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"}, "variable": [{"key": "base_url", "value": "https://my.pipze.com/api/", "type": "string"}, {"key": "token", "value": "", "type": "string"}], "auth": {"type": "bearer", "bearer": [{"key": "token", "value": "{{token}}", "type": "string"}]}, "item": items}
    COLLECTION.write_text(json.dumps(collection, indent=2, ensure_ascii=False) + "\n")
    print(f"generated screens={len(rows)} modules={len(grouped)} doc={DOC} collection={COLLECTION}")

if __name__ == "__main__": main()
