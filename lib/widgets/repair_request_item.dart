import 'package:flutter/material.dart';
import '../models/repair_request.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RepairRequestItem extends StatelessWidget {
  final RepairRequest request;
  final Function(RepairRequest) onEdit;
  final Function(String) onDelete;
  final Function(String) onCancel;
  final Function(String) onActivate;
  final Function(Timestamp, String) onAcceptOffer;

  const RepairRequestItem({
    super.key,
    required this.request,
    required this.onEdit,
    required this.onDelete,
    required this.onCancel,
    required this.onActivate,
    required this.onAcceptOffer,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(request.issueType,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text(request.description),
            const SizedBox(height: 10),
            if (request.imagePaths.isNotEmpty) _buildImageGallery(),
            if (request.videoPath != null && request.videoPath!.isNotEmpty) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () {
                  // Implementirajte logiku za otvaranje videa
                },
                child: const Row(
                  children: [
                    Icon(Icons.videocam, color: Colors.blue),
                    SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'Video',
                        style: TextStyle(color: Colors.blue),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text('Status: ${_capitalize(request.status)}'),
            const SizedBox(height: 5),
            Text('Datum prijave: ${_formatDateTime(request.requestedDate)}'),
            const SizedBox(height: 5),
            if (request.selectedTimeSlot != null)
              Text(
                'Potvrđeni termin: ${_formatDateTime(request.selectedTimeSlot!.toDate())}',
                style: const TextStyle(color: Colors.green),
              )
            else
              const Text(
                'Nema potvrđenog termina',
                style: TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 5),
            if (request.selectedTimeSlot == null &&
                request.offeredTimeSlots.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ponuđeni termini:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...request.offeredTimeSlots
                      .where((slot) => slot != null)
                      .map((slot) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(_formatDateTime(slot!.toDate())),
                            trailing: ElevatedButton(
                              onPressed: () {
                                onAcceptOffer(slot, request.id);
                              },
                              child: const Text('Prihvati'),
                            ),
                          )),
                ],
              ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () {
                    onEdit(request);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    onDelete(request.id);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.orange),
                  onPressed: () {
                    onCancel(request.id);
                  },
                ),
                if (_isCancelled(request.status))
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () {
                      onActivate(request.id);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Widget za prikazivanje galerije slika
  Widget _buildImageGallery() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: request.imagePaths.length,
        itemBuilder: (context, index) {
          final imageUrl = request.imagePaths[index];
          return Container(
            margin: const EdgeInsets.only(right: 10),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey[300],
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              errorWidget: (context, url, error) =>
                  const Icon(Icons.broken_image, size: 50, color: Colors.grey),
            ),
          );
        },
      ),
    );
  }

  /// Metoda za formatiranje DateTime objekta u string
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.year} - ${_dayOfWeek(dateTime.weekday)} - ${_formatTime(dateTime)}';
  }

  /// Metoda za formatiranje vremena u HH:MM formatu
  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Metoda za dobivanje naziva dana u tjednu
  String _dayOfWeek(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Ponedjeljak';
      case DateTime.tuesday:
        return 'Utorak';
      case DateTime.wednesday:
        return 'Srijeda';
      case DateTime.thursday:
        return 'Četvrtak';
      case DateTime.friday:
        return 'Petak';
      case DateTime.saturday:
        return 'Subota';
      case DateTime.sunday:
        return 'Nedjelja';
      default:
        return '';
    }
  }

  /// Metoda za provjeru je li status 'Cancelled'
  bool _isCancelled(String status) {
    return status.toLowerCase() == 'cancelled';
  }

  /// Metoda za kapitalizaciju prvog slova
  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
