import re

with open('lib/services/account_websocket_service.dart', 'r') as f:
    content = f.read()

# Fix account matching
content = re.sub(r'account != currentAccount(?!Number)', r'!_accountMatches(currentAccount, account)', content)
content = re.sub(r'account != _lastSubscribedAccount', r'!_accountMatches(_lastSubscribedAccount, account)', content)
content = re.sub(r'currentAccount != null && !_accountMatches', r'currentAccount != null && currentAccount.isNotEmpty && !_accountMatches', content)

with open('lib/services/account_websocket_service.dart', 'w') as f:
    f.write(content)
