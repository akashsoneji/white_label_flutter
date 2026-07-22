import 'package:country_picker/country_picker.dart';
void main() {
  final country = CountryParser.parseCountryCode('IN');
  print(country.phoneCode);
}
