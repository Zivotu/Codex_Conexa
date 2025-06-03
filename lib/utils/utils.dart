// utils.dart
String normalizeCountryName(String? countryName) {
  if (countryName == null) return '';
  final mapping = {
    'Croatia': 'Croatia',
    'Hrvatska': 'Croatia',
    'HR': 'Croatia',
    'hr': 'Croatia',
    // ...
  };
  return mapping[countryName.trim()] ?? countryName;
}
