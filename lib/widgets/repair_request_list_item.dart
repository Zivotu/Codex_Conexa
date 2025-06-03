import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/repair_request.dart';
import '../services/localization_service.dart';
import '../screens/repair_request_detail_screen.dart';

class RepairRequestListItem extends StatelessWidget {
  final RepairRequest repairRequest;
  final VoidCallback onAccept;

  const RepairRequestListItem({
    super.key,
    required this.repairRequest,
    required this.onAccept,
  });

  String _formatDateTime(
      DateTime dateTime, LocalizationService localizationService) {
    return '${dateTime.day}.${dateTime.month}.${dateTime.year}. - ${localizationService.translate(_dayOfWeek(dateTime.weekday))} - ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}h';
  }

  String _dayOfWeek(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'monday';
      case DateTime.tuesday:
        return 'tuesday';
      case DateTime.wednesday:
        return 'wednesday';
      case DateTime.thursday:
        return 'thursday';
      case DateTime.friday:
        return 'friday';
      case DateTime.saturday:
        return 'saturday';
      case DateTime.sunday:
        return 'sunday';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizationService = Provider.of<LocalizationService>(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        title: Text(
          repairRequest.description,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '${localizationService.translate('status')}: ${repairRequest.status}'),
            if (repairRequest.selectedTimeSlot != null)
              Text(
                repairRequest.servicerConfirmedTimeSlot != null
                    ? '${localizationService.translate('servicerConfirmedTimeSlot')} ${_formatDateTime(repairRequest.selectedTimeSlot!.toDate(), localizationService)}'
                    : '${localizationService.translate('waitingForServicerConfirmation')} ${_formatDateTime(repairRequest.selectedTimeSlot!.toDate(), localizationService)}',
                style: repairRequest.servicerConfirmedTimeSlot != null
                    ? const TextStyle(color: Colors.green)
                    : null,
              ),
            if (repairRequest.servicerOffers.isNotEmpty &&
                repairRequest.selectedTimeSlot == null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(localizationService.translate('servicerOffers')),
                  ...repairRequest.servicerOffers.map((offer) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: offer.timeSlots.map((slot) {
                        return ListTile(
                          title: Text(_formatDateTime(
                              slot.toDate(), localizationService)),
                          trailing: repairRequest.selectedTimeSlot == null &&
                                  repairRequest.servicerConfirmedTimeSlot ==
                                      null
                              ? ElevatedButton(
                                  onPressed: onAccept,
                                  child: Text(
                                      localizationService.translate('accept')),
                                )
                              : null,
                        );
                      }).toList(),
                    );
                  }),
                ],
              ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RepairRequestDetailScreen(
                repairRequest: repairRequest,
              ),
            ),
          );
        },
      ),
    );
  }
}
