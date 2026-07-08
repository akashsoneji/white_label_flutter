p = '/Users/admin/Desktop/Project/white_label/app/white_label/lib/brands/meta/meta_new_order_screen.dart'
with open(p) as f:
    s = f.read()

# Find unbalanced braces by scanning
depth = 0
in_string = False
in_comment = False
i = 0
while i < len(s):
    c = s[i]
    if in_comment:
        if c == '\n':
            in_comment = False
    elif in_string:
        if c == '\\' and i+1 < len(s):
            i += 2
            continue
        if c == in_string:
            in_string = False
    else:
        if c == '/' and i+1 < len(s) and s[i+1] == '/':
            in_comment = True
            i += 1
        elif c == "'" or c == '"':
            in_string = c
        elif c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth < 0:
                print(f"Extra }} at offset {i}")
                print(s[max(0, i-50):i+50])
                break
    i += 1

print(f"Final depth: {depth}")
if depth > 0:
    # Find the last open brace
    # Show the last 200 chars
    print("Last 500 chars:")
    print(repr(s[-500:]))