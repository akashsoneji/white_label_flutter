p = '/Users/admin/Desktop/Project/white_label/app/white_label/lib/brands/meta/meta_new_order_screen.dart'
with open(p) as f:
    s = f.read()

# Replace the state class body (state fields)
old_state = """class _MetaNewOrderScreenState extends State<MetaNewOrderScreen> {
  late final InstrumentsController _ic;

  double _volume = 0.01;
  bool _slEnabled = false;
  bool _tpEnabled = false;

  // Last N bid/ask ticks that drive the sparkline. We keep two
  // parallel lists so the painter can draw a red ASK line on top of
  // a blue BID line, both sharing the same Y-axis range so they are
  // directly comparable.
  static const int _kSparklinePoints = 80;
  final List<double> _askLine = <double>[];
  final List<double> _bidLine = <double>[];"""

new_state = """class _MetaNewOrderScreenState extends State<MetaNewOrderScreen> {
  late final InstrumentsController _ic;

  // Trading state — mirrors the MetaTrader mobile new-order screen.
  double _pips = 0.05; // currently selected pips preset (highlighted)
  double _slPips = 0; // stop-loss pip distance (0 = no SL)
  double _tpPips = 0; // take-profit pip distance (0 = no TP)
  String _execution = 'Market Execution'; // market / pending
  String _fillPolicy = 'Fill or Kill';

  // Last N bid/ask ticks that drive the sparkline.
  static const int _kSparklinePoints = 120;
  final List<double> _askLine = <double>[];
  final List<double> _bidLine = <double>[];"""

s = s.replace(old_state, new_state)

with open(p, 'w') as f:
    f.write(s)
print('done')