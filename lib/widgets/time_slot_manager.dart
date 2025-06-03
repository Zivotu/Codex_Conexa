import '../models/time_frame.dart';

class TimeSlotManager {
  final List<TimeFrame> availableTimeFrames;

  TimeSlotManager(this.availableTimeFrames);

  bool validateSlot(DateTime dateTime) {
    for (final frame in availableTimeFrames) {
      final start = frame.startHour;
      final end = frame.endHour;
      if (dateTime.hour >= start && dateTime.hour < end) {
        return true;
      }
    }
    return false;
  }

  void addSlot(DateTime dateTime) {
    // Implement adding a slot to your system if needed
  }
}
