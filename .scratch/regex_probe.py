# Simulate what the scanner does for 'Create Account'
lookback = """
        Text(
          'Create Account',
          style: TextStyle(
"""
pat = r"\bText(?:\.rich)?\s*\(\s*$"
print("DOTALL no:", bool(re.search(pat, lookback)))
print("DOTALL yes:", bool(re.search(pat, lookback, flags=re.DOTALL)))
