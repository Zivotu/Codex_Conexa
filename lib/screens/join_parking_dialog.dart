import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/parking_service.dart';
import '../models/parking_slot.dart';
import 'package:uuid/uuid.dart';

class JoinParkingDialog extends StatefulWidget {
  final String countryId;
  final String cityId;
  final String locationId;
  final VoidCallback onJoinSuccess;

  const JoinParkingDialog({
    super.key,
    required this.countryId,
    required this.cityId,
    required this.locationId,
    required this.onJoinSuccess,
  });

  @override
  _JoinParkingDialogState createState() => _JoinParkingDialogState();
}

class _JoinParkingDialogState extends State<JoinParkingDialog> {
  final _formKey = GlobalKey<FormState>();
  final ParkingService _parkingService = ParkingService();

  final List<ParkingSlotInput> _parkingSlots = [];

  void _addParkingSlot() {
    setState(() {
      _parkingSlots.add(ParkingSlotInput());
    });
  }

  void _removeParkingSlot(int index) {
    setState(() {
      _parkingSlots.removeAt(index);
    });
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      for (var slotInput in _parkingSlots) {
        slotInput.slotName = slotInput.slotNameController.text.trim();
      }

      String userId = FirebaseAuth.instance.currentUser!.uid;
      List<ParkingSlot> slots = _parkingSlots
          .map((input) => ParkingSlot(
                id: const Uuid().v4(),
                name: input.slotName,
                ownerId: userId,
                locationId: widget.locationId, // Dodano
                permanentAvailability: null,
                vacation: null,
              ))
          .toList();

      try {
        await _parkingService.joinParkingCommunity(
          userId: userId,
          countryId: widget.countryId,
          cityId: widget.cityId,
          locationId: widget.locationId,
          parkingSlots: slots,
        );

        widget.onJoinSuccess();
      } catch (e) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Greška'),
            content: Text('Došlo je do greške prilikom pridruživanja: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pridruži se parking zajednici'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                children: _parkingSlots.asMap().entries.map((entry) {
                  int index = entry.key;
                  ParkingSlotInput slotInput = entry.value;
                  return Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: slotInput.slotNameController,
                          decoration: const InputDecoration(
                              labelText: 'Naziv parkirnog mjesta'),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Unesite naziv';
                            }
                            return null;
                          },
                        ),
                      ),
                      IconButton(
                        icon:
                            const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () => _removeParkingSlot(index),
                      ),
                    ],
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _addParkingSlot,
                icon: const Icon(Icons.add),
                label: const Text('Dodaj parkirno mjesto'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Odustani'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Pridruži se'),
        ),
      ],
    );
  }
}

class ParkingSlotInput {
  final TextEditingController slotNameController = TextEditingController();
  String slotName = '';
}
