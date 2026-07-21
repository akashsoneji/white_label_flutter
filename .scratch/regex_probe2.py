import re
lookback = "        Text(\n          'Create Account',\n          style: TextStyle(\n"
pat = r"\bText(?:\.rich)?\s*\(\s*$"
print("DOTALL no :", bool(re.search(pat, lookback)))
print("DOTALL yes:", bool(re.search(pat, lookback, flags=re.DOTALL)))
