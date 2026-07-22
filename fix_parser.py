import re

def clean_output(filename):
    with open(filename, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
    
    # Remove all ANSI escape sequences
    ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
    clean = ansi_escape.sub('', content)
    
    lines = clean.split('\n')
    for line in lines:
        if 'error' in line.lower() or 'warning' in line.lower() or 'riyadex' in line.lower():
            if 'unused_import' not in line.lower(): # skip simple warnings to find errors
                print(line.strip())

clean_output('err_flutter.txt')
