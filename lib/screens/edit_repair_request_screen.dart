import 'package:flutter/material.dart';
import '../models/repair_request.dart';
import '../services/localization_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditRepairRequestScreen extends StatefulWidget {
  final RepairRequest repairRequest;

  const EditRepairRequestScreen({
    super.key,
    required this.repairRequest,
  });

  @override
  _EditRepairRequestScreenState createState() =>
      _EditRepairRequestScreenState();
}

class _EditRepairRequestScreenState extends State<EditRepairRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _descriptionController;
  String? _selectedIssueType;
  late LocalizationService localizationService;

  @override
  void initState() {
    super.initState();
    _descriptionController =
        TextEditingController(text: widget.repairRequest.description);
    _selectedIssueType = widget.repairRequest.issueType;
    localizationService = LocalizationService();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _updateRepairRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final repairRequestRef = FirebaseFirestore.instance
          .collection('repair_requests')
          .doc(widget.repairRequest.id);

      await repairRequestRef.update({
        'description': _descriptionController.text,
        'issueType': _selectedIssueType,
        // Dodajte ostala polja koja se mogu uređivati
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizationService.translate('requestUpdatedSuccessfully') ??
                  'Zahtjev je uspješno ažuriran.',
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${localizationService.translate('errorUpdatingRequest') ?? 'Greška prilikom ažuriranja zahtjeva'}: $e',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const issueTypes = [
      {'name': 'Vodoinstalater', 'type': '001'},
      {'name': 'Elektroinstalater', 'type': '002'},
      {'name': 'Suhi radovi', 'type': '003'}
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(localizationService.translate('editRepairRequest') ??
            'Uredi zahtjev za popravak'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Dropdown za tip problema
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: localizationService.translate('issueType') ??
                      'Tip problema',
                  border: const OutlineInputBorder(),
                ),
                items: issueTypes.map((type) {
                  return DropdownMenuItem<String>(
                    value: type['type'],
                    child: Text(type['name']!),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedIssueType = value;
                  });
                },
                value: _selectedIssueType,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return localizationService
                            .translate('pleaseFillAllFields') ??
                        'Molimo popunite sva polja.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              // Tekst polje za opis problema
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText:
                      localizationService.translate('problemDescription') ??
                          'Opis problema',
                  border: const OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return localizationService
                            .translate('pleaseFillAllFields') ??
                        'Molimo popunite sva polja.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: _updateRepairRequest,
                child:
                    Text(localizationService.translate('update') ?? 'Ažuriraj'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
