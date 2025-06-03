import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/repair_request.dart';

class RepairRequestTile extends StatefulWidget {
  final RepairRequest repairRequest;

  const RepairRequestTile({super.key, required this.repairRequest});

  @override
  RepairRequestTileState createState() => RepairRequestTileState();
}

class RepairRequestTileState extends State<RepairRequestTile> {
  bool _offerAccepted = false;

  @override
  void initState() {
    super.initState();
    _offerAccepted = widget.repairRequest.selectedTimeSlot != null;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: Text(widget.repairRequest.description),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.repairRequest.issueType),
            if (widget.repairRequest.selectedTimeSlot != null)
              Text(
                  'Termin potvrđen - ${_formatDateTime(widget.repairRequest.selectedTimeSlot!.toDate())}')
            else
              const Text('Nema potvrđenog termina'),
          ],
        ),
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('offers')
                .where('repairRequestId', isEqualTo: widget.repairRequest.id)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final offers = snapshot.data!.docs;
              if (offers.isEmpty) {
                return const Text('Traženje servisera');
              }
              if (_offerAccepted) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Serviser u dolasku!',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              }
              return Column(
                children: offers.map((offer) {
                  final offerData = offer.data() as Map<String, dynamic>;
                  final timeSlots = offerData['timeSlots'] as List<dynamic>;
                  return Column(
                    children: timeSlots.map((slot) {
                      final slotTime = (slot as Timestamp).toDate();
                      return ListTile(
                        title: Text(
                            'Offered time slot: ${_formatDateTime(slotTime)}'),
                        trailing: ElevatedButton(
                          onPressed: () => _acceptOffer(offer.id,
                              widget.repairRequest.id, slotTime, context),
                          child: const Text('Accept'),
                        ),
                      );
                    }).toList(),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}.${dateTime.month}.${dateTime.year}. - ${_dayOfWeek(dateTime.weekday)} - ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}h';
  }

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

  Future<void> _acceptOffer(String offerId, String requestId,
      DateTime acceptedSlot, BuildContext context) async {
    final offerRef =
        FirebaseFirestore.instance.collection('offers').doc(offerId);
    final repairRequestRef =
        FirebaseFirestore.instance.collection('repair_requests').doc(requestId);
    final servicerId = (await offerRef.get())['servicerId'];

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      transaction.update(offerRef, {'status': 'accepted'});
      transaction.update(repairRequestRef, {
        'status': 'in_progress',
        'selectedTimeSlot': Timestamp.fromDate(acceptedSlot),
      });

      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': servicerId,
        'message':
            'Your offer has been accepted. Please proceed to the location.',
        'createdAt': Timestamp.now(),
      });
    });

    setState(() {
      _offerAccepted = true;
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offer accepted')),
      );
    }
  }
}
