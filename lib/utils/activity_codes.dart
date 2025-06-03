import 'package:flutter/material.dart';
import '../services/localization_service.dart'; // 👈 dodano

class ActivityCodes {
  // Stalni kodovi (ključevi) djelatnosti
  static final List<String> _keys = [
    '001',
    '002',
    '003',
    '004',
    '005',
    '006',
    '007',
    '008',
    '009',
    '010',
    '999'
  ];

  // Mapiranje kategorija s ikonama
  static final Map<String, IconData> categoryIcons = {
    '001': Icons.plumbing,
    '002': Icons.electrical_services,
    '003': Icons.format_paint,
    '004': Icons.directions_car,
    '005': Icons.brush,
    '006': Icons.computer,
    '007': Icons.tv,
    '008': Icons.carpenter,
    '009': Icons.construction,
    '010': Icons.kitchen,
    '999': Icons.category,
  };

  /// 🟢 Vraća lokalizirani naziv za određeni kod
  static String getName(String code, LocalizationService loc) {
    return loc.translate('activity_$code');
  }

  /// 🔵 Vraća sve kategorije kao lista mapa s lokaliziranim imenima
  static List<Map<String, String>> getAllCategories(LocalizationService loc) {
    return _keys
        .map((code) => {
              'type': code,
              'name': getName(code, loc),
            })
        .toList();
  }
}
