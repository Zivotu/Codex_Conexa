import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/localization_service.dart';
import '../models/repair_request.dart'; // Ako je potrebno za RepairRequest

class StatusHelper {
  static Map<String, dynamic> getStatusDetails({
    required RepairRequest? repairRequest,
    required LocalizationService localizationService,
  }) {
    String status = repairRequest?.status ?? 'unknown';
    List<dynamic> servicerOffers = repairRequest?.servicerOffers ?? [];
    Timestamp? selectedTimeSlot = repairRequest?.selectedTimeSlot;
    Timestamp? servicerConfirmedTimeSlot =
        repairRequest?.servicerConfirmedTimeSlot;

    String statusMessage = '';
    IconData statusIcon = Icons.info;
    Color iconColor = Colors.blue;

    if (status == 'waitingforconfirmation') {
      statusMessage = localizationService.translate('waitingForConfirmation') ??
          'Čekamo potvrdu termina.';
      statusIcon = Icons.hourglass_empty;
      iconColor = Colors.orangeAccent;
    } else if (servicerOffers.isNotEmpty && selectedTimeSlot == null) {
      if (status == 'Published_2') {
        statusMessage =
            localizationService.translate('chooseServicerArrivalTime') ??
                'Odaberite termin dolaska servisera.';
      } else {
        statusMessage = localizationService.translate('selectTimeSlot') ??
            'Odaberite termin.';
      }
      statusIcon = Icons.schedule;
      iconColor = Colors.orange;
    } else if (selectedTimeSlot != null && servicerConfirmedTimeSlot == null) {
      DateTime selectedDate = selectedTimeSlot.toDate();
      // Formatiranje datuma i vremena
      String formattedDate =
          '${selectedDate.day}.${selectedDate.month}.${selectedDate.year}';
      statusMessage = localizationService.translate('waitingForConfirmation') ??
          'Čekamo potvrdu servisera za $formattedDate.';
      statusIcon = Icons.hourglass_empty;
      iconColor = Colors.orangeAccent;
    } else if (servicerConfirmedTimeSlot != null && status != 'completed') {
      statusMessage = localizationService.translate('serviceConfirmed') ??
          'Servis je dogovoren!';
      statusIcon = Icons.check_circle;
      iconColor = Colors.green;
    } else if (status == 'completed') {
      statusMessage = localizationService.translate('jobCompleted') ??
          'Posao je uspješno obavljen!';
      statusIcon = Icons.done_all;
      iconColor = Colors.green;
    } else if (servicerOffers.isEmpty) {
      statusMessage = localizationService.translate('searchingForServicer') ??
          'Tražimo servisera!';
      statusIcon = Icons.search;
      iconColor = Colors.blue;
    } else {
      statusMessage =
          localizationService.translate('unknownStatus') ?? 'Nepoznat status';
      statusIcon = Icons.help;
      iconColor = Colors.grey;
    }

    return {
      'message': statusMessage,
      'icon': statusIcon,
      'color': iconColor,
    };
  }
}
