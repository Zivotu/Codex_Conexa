import 'dart:math';

String generateAffiliateCode(String firstName, String lastName) {
  // 1) inicijali
  final i1 = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
  final i2 = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';

  // 2) godina
  final year = DateTime.now().year.toString();

  // 3) 3 random alfanumerička znaka
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final rnd = Random();
  final suffix =
      List.generate(3, (_) => chars[rnd.nextInt(chars.length)]).join();

  return '$i1$i2$year$suffix';
}
