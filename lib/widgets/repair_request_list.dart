import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/repair_request.dart';

class RepairRequestList extends StatelessWidget {
  final List<RepairRequest> requests;
  final void Function(RepairRequest) onEdit;
  final void Function(String) onDelete;
  final void Function(String) onCancel;
  final void Function(String) onActivate;
  final void Function(Timestamp, String) onAcceptOffer;
  final void Function(RepairRequest, Timestamp)
      onUserAcceptOffer; // Dodaj ovaj parametar
  final void Function(RepairRequest) onSendOffer;

  const RepairRequestList({
    super.key,
    required this.requests,
    required this.onEdit,
    required this.onDelete,
    required this.onCancel,
    required this.onActivate,
    required this.onAcceptOffer,
    required this.onUserAcceptOffer, // Dodaj ovaj parametar
    required this.onSendOffer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: requests.map((request) {
        return ListTile(
          title: Text(request.description),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Status: ${request.status}'),
              Text('Datum prijave: ${_formatDateTime(request.requestedDate)}'),
              if (request.selectedTimeSlot != null)
                Text(
                  'Potvrđeni termin: ${_formatDateTime(request.selectedTimeSlot!.toDate())}',
                  style: const TextStyle(color: Colors.green),
                )
              else
                const Text('Nema potvrđenog termina'),
              const SizedBox(height: 10),
              const Text('Ponuđeni termini:'),
              ...request.offeredTimeSlots
                  .where((slot) => slot != null)
                  .map((slot) => ListTile(
                        title: Text(_formatDateTime(slot!.toDate())),
                        trailing: ElevatedButton(
                          onPressed: () {
                            onAcceptOffer(slot, request.id);
                          },
                          child: const Text('Prihvati'),
                        ),
                      )),
              const SizedBox(height: 10),
              const Text('Ponude servisera:'),
              ...request.servicerOffers.map((offer) => ListTile(
                    title: Text('Serviser ID: ${offer.servicerId}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: offer.timeSlots.map((slot) {
                        return Text(_formatDateTime(slot.toDate()));
                      }).toList(),
                    ),
                  )),
            ],
          ),
          isThreeLine: true,
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  onEdit(request);
                  break;
                case 'delete':
                  onDelete(request.id);
                  break;
                case 'cancel':
                  onCancel(request.id);
                  break;
                case 'activate':
                  onActivate(request.id);
                  break;
                case 'sendOffer':
                  onSendOffer(request);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Text('Uredi'),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Obriši'),
              ),
              const PopupMenuItem(
                value: 'cancel',
                child: Text('Otkazi'),
              ),
              const PopupMenuItem(
                value: 'activate',
                child: Text('Aktiviraj'),
              ),
              const PopupMenuItem(
                value: 'sendOffer',
                child: Text('Pošalji ponudu'),
              ),
            ],
          ),
        );
      }).toList(),
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
}
