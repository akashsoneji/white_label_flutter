import json
d = json.load(open('assets/translations/en.json', encoding='utf-8'))
for v in ['Sign Up', 'Don\u2019t have an account?', 'Market execution', 'L:', 'H:']:
    matches = [k for k, val in d.items() if val == v]
    print(f"value {v!r} -> keys {matches}")
