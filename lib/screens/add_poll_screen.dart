import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/localization_service.dart'; // Dodano za lokalizaciju

class AddPollScreen extends StatefulWidget {
  final String username;
  final String locationName;
  final void Function(Map<String, dynamic>) onSave;

  const AddPollScreen({
    super.key,
    required this.username,
    required this.locationName,
    required this.onSave,
  });

  @override
  AddPollScreenState createState() => AddPollScreenState();
}

class AddPollScreenState extends State<AddPollScreen> {
  final TextEditingController questionController = TextEditingController();
  final TextEditingController optionController = TextEditingController();
  List<String> options = [];

  void _addOption() {
    final option = optionController.text.trim();
    if (option.isNotEmpty) {
      setState(() {
        options.add(option);
      });
      optionController.clear();
    }
  }

  void _removeOption(int index) {
    setState(() {
      options.removeAt(index);
    });
  }

  Future<void> _submitPoll() async {
    final question = questionController.text.trim();
    if (question.isEmpty || options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LocalizationService.instance
                    .translate('add_poll_error_no_question_or_option') ??
                'Please enter a poll question and at least one option.',
          ),
        ),
      );
      return;
    }

    final newPoll = {
      'pollQuestion': question,
      'pollOptions':
          options.map((option) => {'title': option, 'votes': 0}).toList(),
      'timestamp': Timestamp.now(),
      'createdBy': widget.username,
    };

    const countryId = 'country_id'; // Zamijeniti stvarnim ID države
    const cityId = 'city_id'; // Zamijeniti stvarnim ID grada
    const locationId = 'location_id'; // Zamijeniti stvarnim ID lokacije

    await FirebaseFirestore.instance
        .collection('countries')
        .doc(countryId)
        .collection('cities')
        .doc(cityId)
        .collection('locations')
        .doc(locationId)
        .collection('polls')
        .add(newPoll);

    widget.onSave(newPoll);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizationService = LocalizationService.instance;

    return Scaffold(
      appBar: AppBar(
        title:
            Text(localizationService.translate('create_poll') ?? 'Create Poll'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: questionController,
              decoration: InputDecoration(
                labelText: localizationService.translate('poll_question') ??
                    'Poll Question',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: optionController,
              decoration: InputDecoration(
                labelText: localizationService.translate('poll_option') ??
                    'Poll Option',
              ),
              onSubmitted: (_) => _addOption(),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _addOption,
              child: Text(
                  localizationService.translate('add_option') ?? 'Add Option'),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: options.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(options[index]),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _removeOption(index),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _submitPoll,
              child: Text(localizationService.translate('submit_poll') ??
                  'Submit Poll'),
            ),
          ],
        ),
      ),
    );
  }
}
