#!/usr/bin/env python3
"""Smoke test: translate ~5 sample strings to each language, then verify."""
import os
import re
import sys
os.chdir('/Users/admin/Desktop/Project/white_label/app/white_label')

from deep_translator import GoogleTranslator

samples = [
    "Enter Lot Size",
    "Verify Your Account",
    "Biometric not supported on this device",
    "Your IB application has been rejected. Please contact support.",
    "Resend Code",
    "Add capital",
    "No favorites yet",
    "Master Trader",
    "Per Trade (% commission)",
    "Resend in {seconds} seconds",
]

for tgt, name in [('fr', 'French'), ('id', 'Indonesian'), ('zh-CN', 'Chinese')]:
    print(f"\n=== {name} ({tgt}) ===")
    for s in samples:
        try:
            r = GoogleTranslator(source='en', target=tgt).translate(s)
        except Exception as e:
            r = f"ERR: {e}"
        print(f"  {s!r} -> {r!r}")
