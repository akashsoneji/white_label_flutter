import re

with open('lib/services/trading_websocket_service.dart', 'r') as f:
    content = f.read()

def robust_parser():
    return """
          final swap = item.length > offset + 8 ? (double.tryParse(item[offset + 8].toString()) ?? 0.0) : 0.0;
          final priceSLStr = item.length > offset + 9 ? item[offset + 9].toString().trim() : '0';
          final priceTPStr = item.length > offset + 10 ? item[offset + 10].toString().trim() : '0';

          double _parsePrice(String s) {
            if (s.isEmpty || s == '0' || s == 'null' || s == '-') return 0.0;
            final v = double.tryParse(s) ?? 0.0;
            return (v.isNaN || v.isInfinite) ? 0.0 : v;
          }

          final priceSL = _parsePrice(priceSLStr);
          final priceTP = _parsePrice(priceTPStr);

          bool hasServerField = item.length > offset + 11 && item[offset + 11] is String && !RegExp(r'^\\d+$').hasMatch(item[offset + 11].toString());
          int serverOffset = hasServerField ? 1 : 0;

          final openedAt = item.length > offset + 11 + serverOffset
              ? (int.tryParse(item[offset + 11 + serverOffset].toString()) ?? 0)
              : 0;
          final digits = item.length > offset + 12 + serverOffset
              ? (int.tryParse(item[offset + 12 + serverOffset].toString()) ?? 5)
              : 5;
"""

# Replace in _handleBatchPositions
batch_pattern = r'// Detect 17-element self-hosted format.*?(?=\s*// ✅ FIX: Handle "zombie" positions)'
content = re.sub(batch_pattern, lambda m: robust_parser().strip() + '\n', content, flags=re.DOTALL)

# Replace in _handleSinglePositionOpFormat
single_pattern = r'// Detect 17-element self-hosted format.*?(?=\s*// ✅ FIX: Handle "zombie" positions)'
content = re.sub(single_pattern, lambda m: robust_parser().strip() + '\n', content, flags=re.DOTALL)

# Replace in _handlePositionsOpFormat
op_pattern = r'// Parse swap \(index 10\) - NEW position.*?(?=\s*final position = TradingPosition)'
content = re.sub(op_pattern, lambda m: robust_parser().strip() + '\n', content, flags=re.DOTALL)

with open('lib/services/trading_websocket_service.dart', 'w') as f:
    f.write(content)
