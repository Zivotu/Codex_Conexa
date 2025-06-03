// lib/widgets/status_widget.dart

import 'package:flutter/material.dart';
import '../services/localization_service.dart';

class StatusWidget extends StatelessWidget {
  final String status;
  final LocalizationService localizationService;
  final String? customMessage; // Dodan parametar za prilagođenu poruku

  const StatusWidget({
    super.key,
    required this.status,
    required this.localizationService,
    this.customMessage, // Dodan parametar
  });

  @override
  Widget build(BuildContext context) {
    String message;
    IconData iconData;
    Color color;

    // Ako postoji prilagođena poruka, koristi je umjesto automatske
    if (customMessage != null && customMessage!.isNotEmpty) {
      message = customMessage!;
      iconData = Icons.info; // Prilagodite ikonu ako je potrebno
      color = Colors.blueGrey; // Prilagodite boju ako je potrebno
    } else {
      // Automatsko određivanje poruke, ikone i boje na temelju statusa
      switch (status) {
        case 'Published':
          message = localizationService.translate('servicerRequired') ??
              'Servicer Required';
          iconData = Icons.search;
          color = Colors.blue;
          break;
        case 'In Negotiation':
          message = localizationService.translate('inNegotiation') ??
              'In Negotiation';
          iconData = Icons.hourglass_top;
          color = Colors.orange;
          break;
        case 'waitingconfirmation':
          message =
              localizationService.translate('waitingForServicerConfirmation') ??
                  'Waiting for Confirmation';
          iconData = Icons.hourglass_bottom;
          color = Colors.yellow;
          break;
        case 'Job Agreed':
          message = localizationService.translate('jobAgreed') ?? 'Job Agreed';
          iconData = Icons.check_circle;
          color = Colors.green;
          break;
        case 'Completed':
          message = localizationService.translate('completed') ?? 'Completed';
          iconData = Icons.done_all;
          color = Colors.grey;
          break;
        case 'Cancelled':
          message =
              localizationService.translate('requestCancelled') ?? 'Cancelled';
          iconData = Icons.cancel;
          color = Colors.red;
          break;
        default:
          message = localizationService.translate('unknownStatus') ??
              'Unknown Status';
          iconData = Icons.help;
          color = Colors.black;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            iconData,
            color: color,
            size: 50, // Veća ikona
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 20, // Veći font za bolju vidljivost
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
