import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_polls/flutter_polls.dart';

class FullScreenArticleScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imageUrl;
  final String pollQuestion;
  final List<Map<String, dynamic>> pollOptions;
  final String documentId;
  final String username;
  final String countryId;
  final String cityId;
  final String locationId;

  const FullScreenArticleScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.pollQuestion,
    required this.pollOptions,
    required this.documentId,
    required this.username,
    required this.countryId,
    required this.cityId,
    required this.locationId,
  });

  Future<void> _vote(PollOption pollOption, int newTotalVotes) async {
    final votePath =
        'countries/$countryId/cities/$cityId/locations/$locationId/users/$username/votes/$title';
    final voteDoc = FirebaseFirestore.instance.doc(votePath);
    final voteData = await voteDoc.get();

    if (!voteData.exists) {
      // Add vote to poll options
      final optionIndex =
          pollOptions.indexWhere((option) => option['id'] == pollOption.id);
      if (optionIndex != -1) {
        pollOptions[optionIndex]['votes'] += 1;
      }

      // Update article with new votes
      final articleDoc = FirebaseFirestore.instance
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .collection('news')
          .doc(documentId);
      await articleDoc.update({'pollOptions': pollOptions});

      // Record vote in user votes collection
      await voteDoc.set({'voted': true});
    }
  }

  Future<bool> _hasVoted() async {
    final votePath =
        'countries/$countryId/cities/$cityId/locations/$locationId/users/$username/votes/$title';
    final voteDoc = FirebaseFirestore.instance.doc(votePath);
    final voteData = await voteDoc.get();

    return voteData.exists;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Image.asset(
              imageUrl,
              height: 300,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                subtitle,
                style: const TextStyle(fontSize: 18.0),
              ),
            ),
            if (pollQuestion.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pollQuestion,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    FutureBuilder<bool>(
                      future: _hasVoted(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        }

                        final hasVoted = snapshot.data ?? false;

                        return hasVoted
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: pollOptions.map((option) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 4.0),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(option['title']),
                                        Text('${option['votes']} votes'),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              )
                            : Wrap(
                                spacing: 8.0,
                                children: pollOptions.map((option) {
                                  return ElevatedButton(
                                    onPressed: () => _vote(
                                        PollOption(
                                          id: option['id'],
                                          title: Text(option['title']),
                                          votes: option['votes'],
                                        ),
                                        option['votes'] + 1),
                                    child: Text(option['title']),
                                  );
                                }).toList(),
                              );
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
