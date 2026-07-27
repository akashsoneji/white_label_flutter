import 'dart:io';
void main() {
  final f = File('lib/screens/home/brands/iquote/iquote_chart_screen.dart');
  print('LINES=${f.readAsLinesSync().length}');
}
