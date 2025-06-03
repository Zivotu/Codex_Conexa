// lib/screens/edit_parking_slots_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/parking_service.dart';
import '../models/parking_slot.dart';
import '../services/localization_service.dart';
import 'login_screen.dart'; // Pretpostavljam da postoji LoginScreen

class EditParkingSlotsScreen extends StatefulWidget {
  final String countryId;
  final String cityId;
  final String locationId;

  const EditParkingSlotsScreen({
    super.key,
    required this.countryId,
    required this.cityId,
    required this.locationId,
  });

  @override
  _EditParkingSlotsScreenState createState() => _EditParkingSlotsScreenState();
}

class _EditParkingSlotsScreenState extends State<EditParkingSlotsScreen> {
  final ParkingService _parkingService = ParkingService();
  bool _isLoading = true;
  List<ParkingSlot> _parkingSlots = [];
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  void _initializeUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Ako korisnik nije prijavljen, preusmjeri ga na login ekran
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      });
    } else {
      currentUserId = user.uid;
      _loadParkingSlots();
    }
  }

  Future<void> _loadParkingSlots() async {
    setState(() {
      _isLoading = true;
    });
    try {
      _parkingSlots = await _parkingService.getUserParkingSlots(
        userId: currentUserId!,
        countryId: widget.countryId,
        cityId: widget.cityId,
        locationId: widget.locationId,
      );
    } catch (e) {
      _showSnackBar(context, 'loadError', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addParkingSlot() async {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    String slotName = '';
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(localizationService.translate('addParkingSlot') ??
                  'Dodaj parkirno mjesto'),
              content: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  labelText: localizationService.translate('parkingSlotName') ??
                      'Naziv',
                ),
                onChanged: (value) {
                  setStateDialog(() {
                    slotName = value;
                  });
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                      localizationService.translate('cancel') ?? 'Odustani'),
                ),
                ElevatedButton(
                  onPressed: slotName.trim().isEmpty
                      ? null
                      : () async {
                          Navigator.of(context).pop();
                          try {
                            await _parkingService.addParkingSlot(
                              userId: currentUserId!,
                              countryId: widget.countryId,
                              cityId: widget.cityId,
                              locationId: widget.locationId,
                              slotName: slotName.trim(),
                            );
                            _showSnackBar(context, 'slotAdded');
                            await _loadParkingSlots();
                          } catch (e) {
                            _showSnackBar(context, 'addError', isError: true);
                          }
                        },
                  child: Text(localizationService.translate('add') ?? 'Dodaj'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _editParkingSlot(ParkingSlot slot) async {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    String slotName = slot.name;
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(localizationService.translate('editParkingSlot') ??
                  'Uredi parkirno mjesto'),
              content: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  labelText: localizationService.translate('parkingSlotName') ??
                      'Naziv',
                ),
                controller: TextEditingController(text: slot.name),
                onChanged: (value) {
                  setStateDialog(() {
                    slotName = value;
                  });
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                      localizationService.translate('cancel') ?? 'Odustani'),
                ),
                ElevatedButton(
                  onPressed: slotName.trim().isEmpty
                      ? null
                      : () async {
                          Navigator.of(context).pop();
                          try {
                            await _parkingService.updateParkingSlot(
                              userId: currentUserId!,
                              countryId: widget.countryId,
                              cityId: widget.cityId,
                              locationId: widget.locationId,
                              slotId: slot.id,
                              newName: slotName.trim(),
                            );
                            _showSnackBar(context, 'slotUpdated');
                            await _loadParkingSlots();
                          } catch (e) {
                            _showSnackBar(context, 'updateError',
                                isError: true);
                          }
                        },
                  child:
                      Text(localizationService.translate('save') ?? 'Spremi'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteParkingSlot(ParkingSlot slot) async {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizationService.translate('confirmDeletion') ??
            'Potvrda brisanja'),
        content: Text(localizationService.translate('confirmDeletionContent') ??
            'Jeste li sigurni da želite izbrisati ovo parkirno mjesto?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(localizationService.translate('cancel') ?? 'Odustani'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(localizationService.translate('delete') ?? 'Izbriši'),
          ),
        ],
      ),
    );

    if (confirm) {
      try {
        await _parkingService.deleteParkingSlot(
          userId: currentUserId!,
          countryId: widget.countryId,
          cityId: widget.cityId,
          locationId: widget.locationId,
          slotId: slot.id,
        );
        _showSnackBar(context, 'slotDeleted');
        await _loadParkingSlots();
      } catch (e) {
        _showSnackBar(context, 'deleteError', isError: true);
      }
    }
  }

  void _showSnackBar(BuildContext context, String key, {bool isError = false}) {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    String message;
    switch (key) {
      case 'loadError':
        message = localizationService.translate('loadError') ??
            'Greška pri učitavanju parkirnih mjesta.';
        break;
      case 'slotAdded':
        message = localizationService.translate('slotAdded') ??
            'Parkirno mjesto dodano.';
        break;
      case 'slotUpdated':
        message = localizationService.translate('slotUpdated') ??
            'Parkirno mjesto ažurirano.';
        break;
      case 'slotDeleted':
        message = localizationService.translate('slotDeleted') ??
            'Parkirno mjesto izbrisano.';
        break;
      case 'deleteError':
        message = localizationService.translate('deleteError') ??
            'Greška pri brisanju parkirnog mjesta.';
        break;
      case 'addError':
        message = localizationService.translate('addError') ??
            'Greška pri dodavanju parkirnog mjesta.';
        break;
      case 'updateError':
        message = localizationService.translate('updateError') ??
            'Greška pri ažuriranju parkirnog mjesta.';
        break;
      default:
        message = key;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizationService = Provider.of<LocalizationService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizationService.translate('editParkingSlots') ??
              'Uredi parking mjesta',
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _parkingSlots.isEmpty
              ? Center(
                  child: Text(
                    localizationService.translate('noParkingSlots') ??
                        'Nemate dodijeljenih parkirnih mjesta.',
                    style: const TextStyle(fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _parkingSlots.length,
                  itemBuilder: (context, index) {
                    final slot = _parkingSlots[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        title: Text(
                          slot.name,
                          style: const TextStyle(fontSize: 18),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editParkingSlot(slot),
                              tooltip: localizationService.translate('edit') ??
                                  'Uredi',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteParkingSlot(slot),
                              tooltip:
                                  localizationService.translate('delete') ??
                                      'Izbriši',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addParkingSlot,
        tooltip: localizationService.translate('addParkingSlot') ??
            'Dodaj parkirno mjesto',
        child: const Icon(Icons.add),
      ),
    );
  }
}
