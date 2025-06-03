import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/repair_request.dart';
import 'package:provider/provider.dart';
import '../services/localization_service.dart';
import 'repair_request_detail_screen.dart';

class CompletedJobsScreen extends StatelessWidget {
  final String countryId;
  final String cityId;
  final String servicerId;

  const CompletedJobsScreen({
    super.key,
    required this.countryId,
    required this.cityId,
    required this.servicerId,
  });

  @override
  Widget build(BuildContext context) {
    final localizationService = Provider.of<LocalizationService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizationService.translate('completedJobs') ??
            'Dovršeni poslovi'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('countries')
            .doc(countryId)
            .collection('cities')
            .doc(cityId)
            .collection('repair_requests')
            .where('servicerId', isEqualTo: servicerId)
            .where('status', isEqualTo: 'Završeno')
            .orderBy('requestedDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(localizationService.translate('noCompletedJobs') ??
                  'Nema dovršenih poslova'),
            );
          }

          final completedJobs = snapshot.data!.docs
              .map((doc) => RepairRequest.fromFirestore(doc))
              .toList();

          return ListView.builder(
            itemCount: completedJobs.length,
            itemBuilder: (context, index) {
              final job = completedJobs[index];
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
                    job.description,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${localizationService.translate('status') ?? 'Status'}: ${job.status}'),
                      Text(
                          '${localizationService.translate('date') ?? 'Datum'}: ${_formatDateTime(job.requestedDate, localizationService)}'),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.chevron_right, color: Colors.blue),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RepairRequestDetailScreen(
                            repairRequest: job,
                          ),
                        ),
                      );
                    },
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RepairRequestDetailScreen(
                          repairRequest: job,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDateTime(
      DateTime dateTime, LocalizationService localizationService) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year;
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$day.$month.$year. - ${_dayOfWeek(dateTime.weekday, localizationService)} - $hour:$minute';
  }

  String _dayOfWeek(int weekday, LocalizationService localizationService) {
    switch (weekday) {
      case DateTime.monday:
        return localizationService.translate('monday') ?? 'Ponedjeljak';
      case DateTime.tuesday:
        return localizationService.translate('tuesday') ?? 'Utorak';
      case DateTime.wednesday:
        return localizationService.translate('wednesday') ?? 'Srijeda';
      case DateTime.thursday:
        return localizationService.translate('thursday') ?? 'Četvrtak';
      case DateTime.friday:
        return localizationService.translate('friday') ?? 'Petak';
      case DateTime.saturday:
        return localizationService.translate('saturday') ?? 'Subota';
      case DateTime.sunday:
        return localizationService.translate('sunday') ?? 'Nedjelja';
      default:
        return '';
    }
  }
}
