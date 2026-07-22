#!/usr/bin/env python3
"""Patch trading_main_screen.dart to push IquoteChartScreen for iQuote."""
import sys

p = "lib/screens/home/trading_main_screen.dart"
s = open(p).read()

OLD = (
    "  // Tenax/default: switch to chart tab and set symbol.\n"
    "  void _switchToChartTab(String symbol) {\n"
    "    try {\n"
    "      _onTabChanged(1);\n"
    "      ChartScreen.setSelectedSymbol(symbol);\n"
    "    } catch (e) {\n"
    "      print('ERROR_PLACEHOLDER');\n"
    "    }\n"
    "  }\n"
)

NEW = (
    "  // Tenax/default: switch to chart tab and set symbol.\n"
    "  // For iQuote UI, tab 1 is the Markets screen (not Chart), so we push\n"
    "  // the iQuote chart screen on top so the live websocket feed actually\n"
    "  // renders.\n"
    "  void _switchToChartTab(String symbol) {\n"
    "    try {\n"
    "      if (FlavorConfig.usesIquoteUi()) {\n"
    "        Get.to(() => IquoteChartScreen(initialSymbol: symbol));\n"
    "        return;\n"
    "      }\n"
    "      _onTabChanged(1);\n"
    "      ChartScreen.setSelectedSymbol(symbol);\n"
    "    } catch (e) {\n"
    "      print('ERROR_PLACEHOLDER');\n"
    "    }\n"
    "  }\n"
)

# Original error message contains an emoji siren + dollar-sign-e
ORIG_ERR = "print('\U0001F6A8 TradingMainScreen: Error switching to chart tab: $e');"
NEW_ERR = ORIG_ERR  # keep as-is

# Replace one occurrence at a time
if OLD.replace("ERROR_PLACEHOLDER", ORIG_ERR) not in s:
    print("ABORT: original block not found verbatim")
    sys.exit(1)

old_block = OLD.replace("ERROR_PLACEHOLDER", ORIG_ERR)
new_block = NEW.replace("ERROR_PLACEHOLDER", ORIG_ERR)

assert s.count(old_block) == 1, f"expected 1 match, got {s.count(old_block)}"
s2 = s.replace(old_block, new_block, 1)
open(p, "w").write(s2)
print("OK")