// lib/models/time_frame.dart

class TimeFrame {
  final String label;
  final int startHour;
  final int endHour;

  TimeFrame({
    required this.label,
    required this.startHour,
    required this.endHour,
  });

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'startHour': startHour,
      'endHour': endHour,
    };
  }

  factory TimeFrame.fromMap(Map<String, dynamic> map) {
    return TimeFrame(
      label: map['label'] ?? 'N/A',
      startHour: map['startHour'] ?? 0,
      endHour: map['endHour'] ?? 23,
    );
  }

  /// Provjera je li zadani datum unutar vremenskog okvira
  bool isWithinTimeFrame(DateTime dateTime) {
    final hour = dateTime.hour;
    return hour >= startHour && hour < endHour;
  }
}
