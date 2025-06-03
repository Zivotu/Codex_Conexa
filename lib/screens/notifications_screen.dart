import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/localization_service.dart';

class NotificationsScreen extends StatefulWidget {
  final String username;
  final String countryId;
  final String cityId;
  final String locationId;

  const NotificationsScreen({
    super.key,
    required this.username,
    required this.countryId,
    required this.cityId,
    required this.locationId,
  });

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool hasVoted = false; // Kontrola za glasanje

  @override
  void initState() {
    super.initState();
    _checkIfUserVoted();
  }

  Future<void> _checkIfUserVoted() async {
    final pollRef = FirebaseFirestore.instance.collection('commute_poll');
    final userVote = await pollRef
        .where('userId',
            isEqualTo: widget.username) // Pretpostavka: username je jedinstven
        .get();
    if (userVote.docs.isNotEmpty) {
      setState(() {
        hasVoted = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization =
        Provider.of<LocalizationService>(context, listen: false);

    final List<Map<String, String>> pollOptions = [
      {
        'key': 'option1',
        'value': localization.translate('commute_poll_option1')
      },
      {
        'key': 'option2',
        'value': localization.translate('commute_poll_option2')
      },
      {
        'key': 'option3',
        'value': localization.translate('commute_poll_option3')
      },
      {
        'key': 'option4',
        'value': localization.translate('commute_poll_option4')
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(localization.translate('commute_service_title')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localization.translate('commute_service_description'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 24),
            if (!hasVoted)
              Text(
                localization.translate('commute_poll_question'),
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 16),
            if (!hasVoted)
              Expanded(
                child: ListView.builder(
                  itemCount: pollOptions.length,
                  itemBuilder: (context, index) {
                    final option = pollOptions[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: ElevatedButton(
                        onPressed: hasVoted
                            ? null
                            : () async {
                                await _submitPollResponse(option['key']!);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(localization
                                          .translate('poll_thank_you')),
                                    ),
                                  );
                                  setState(() {
                                    hasVoted = true;
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(option['value']!),
                      ),
                    );
                  },
                ),
              ),
            if (hasVoted)
              Center(
                child: Text(
                  localization.translate('poll_thank_you'),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitPollResponse(String responseKey) async {
    try {
      final pollRef = FirebaseFirestore.instance.collection('commute_poll');
      await pollRef.add({
        'response': responseKey,
        'userId': widget.username, // Pretpostavka: username je jedinstven
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error submitting poll response: $e');
    }
  }
}
