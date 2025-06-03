import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/localization_service.dart';
import 'package:http/http.dart' as http;

// Definicije boja
const Color gold = Color(0xFFFFD700);
const Color silver = Color(0xFFC0C0C0);
const Color bronze = Color(0xFFCD7F32);

/// Widget za prikaz profilne slike korisnika.
class ProfileAvatar extends StatelessWidget {
  final String userId;
  final double radius;

  const ProfileAvatar({
    super.key,
    required this.userId,
    required this.radius,
  });

  Future<String> _fetchProfileUrl() async {
    DocumentSnapshot userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (userDoc.exists) {
      final data = userDoc.data() as Map<String, dynamic>;
      return data['profileImageUrl'] ?? '';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _fetchProfileUrl(),
      builder: (context, snapshot) {
        String url = snapshot.data ?? '';
        if (url.isNotEmpty) {
          return CircleAvatar(
            radius: radius,
            backgroundImage: url.startsWith('http')
                ? NetworkImage(url)
                : AssetImage(url) as ImageProvider,
          );
        }
        return CircleAvatar(
          radius: radius,
          child: Icon(Icons.person, size: radius, color: Colors.grey),
        );
      },
    );
  }
}

/// Glavni ekran s kvizom – prikazuje odbrojavanje, kviz ili leaderboard.
class GamesScreen extends StatefulWidget {
  final String username;
  final String countryId;
  final String cityId;
  final String locationId;

  const GamesScreen({
    super.key,
    required this.username,
    required this.countryId,
    required this.cityId,
    required this.locationId,
  });

  @override
  _GamesScreenState createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  late Future<List<Widget>> futurePlayersWhoPlayedToday;
  late Future<Map<String, dynamic>?> futureYesterdayWinner;
  bool hasPlayedToday = false;
  final Random _random = Random();
  String randomMessage = '';

  @override
  void initState() {
    super.initState();
    futurePlayersWhoPlayedToday = _loadPlayersWhoPlayedToday();
    futureYesterdayWinner = _getYesterdayWinner();
    _checkIfPlayedToday();
    _setRandomMessage();
  }

  void _setRandomMessage() {
    final localization =
        Provider.of<LocalizationService>(context, listen: false);
    List<String> messageKeys = [
      'already_played_msg1',
      'already_played_msg2',
      'already_played_msg3',
      'already_played_msg4',
      'already_played_msg5',
      'already_played_msg6',
      'already_played_msg7',
      'already_played_msg8',
      'already_played_msg9',
      'already_played_msg10',
    ];
    String randomKey = messageKeys[_random.nextInt(messageKeys.length)];
    setState(() {
      randomMessage = localization.translate(randomKey) ??
          'Već ste odigrali današnji kviz, pokušajte sutra!';
    });
  }

  Future<void> _checkIfPlayedToday() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    final String todayDate = DateTime.now().toIso8601String().substring(0, 10);
    final resultDoc = await FirebaseFirestore.instance
        .collection('countries')
        .doc(widget.countryId)
        .collection('cities')
        .doc(widget.cityId)
        .collection('locations')
        .doc(widget.locationId)
        .collection('quizz')
        .doc(todayDate)
        .collection('results')
        .doc(userId)
        .get();
    setState(() {
      hasPlayedToday = resultDoc.exists;
    });
  }

  Future<Map<String, dynamic>?> _getYesterdayWinner() async {
    final String yesterdayDate = DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);
    final firestore = FirebaseFirestore.instance;
    final leaderboardSnapshot = await firestore
        .collection('countries')
        .doc(widget.countryId)
        .collection('cities')
        .doc(widget.cityId)
        .collection('locations')
        .doc(widget.locationId)
        .collection('quizz')
        .doc(yesterdayDate)
        .collection('results')
        .orderBy('score', descending: true)
        .limit(1)
        .get();
    if (leaderboardSnapshot.docs.isNotEmpty) {
      return leaderboardSnapshot.docs.first.data();
    }
    return null;
  }

  Future<List<Widget>> _loadPlayersWhoPlayedToday() async {
    final localization =
        Provider.of<LocalizationService>(context, listen: false);
    final String todayDate = DateTime.now().toIso8601String().substring(0, 10);
    final firestore = FirebaseFirestore.instance;
    final playersSnapshot = await firestore
        .collection('countries')
        .doc(widget.countryId)
        .collection('cities')
        .doc(widget.cityId)
        .collection('locations')
        .doc(widget.locationId)
        .collection('quizz')
        .doc(todayDate)
        .collection('results')
        .orderBy('score', descending: true)
        .get();
    if (playersSnapshot.docs.isEmpty) {
      return [
        Text(localization.translate('no_players_played_today') ??
            'Nema igrača danas.')
      ];
    }
    List<Widget> playerWidgets = [];
    List<DocumentSnapshot> topPlayers = playersSnapshot.docs.take(3).toList();
    playerWidgets.add(Text(
      localization.translate('top_3_players') ?? 'Top 3 igrača',
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    ));
    playerWidgets.add(const SizedBox(height: 10));
    playerWidgets.add(_buildPodium(topPlayers));
    if (playersSnapshot.docs.length > 3) {
      List<DocumentSnapshot> remainingPlayers = playersSnapshot.docs.sublist(3);
      playerWidgets.add(const SizedBox(height: 20));
      playerWidgets.add(Text(
        localization.translate('other_players') ?? 'Ostali igrači',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ));
      playerWidgets.add(const SizedBox(height: 10));
      playerWidgets.addAll(remainingPlayers.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final username = data['username'] ?? 'Nepoznati korisnik';
        final score = data['score']?.toString() ?? '0';
        final userId = data['user_id'] ?? '';
        return ListTile(
          leading: ProfileAvatar(
            userId: userId,
            radius: 20,
          ),
          title: Text(username),
          trailing:
              Text('$score ${localization.translate('points') ?? 'bodova'}'),
        );
      }).toList());
    }
    return playerWidgets;
  }

  Widget _buildPodium(List<DocumentSnapshot> topPlayers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (topPlayers.length > 1)
          _buildPodiumPlayer(topPlayers[1], '2', silver),
        if (topPlayers.isNotEmpty)
          _buildPodiumPlayer(topPlayers[0], '1', gold, isCenter: true),
        if (topPlayers.length > 2)
          _buildPodiumPlayer(topPlayers[2], '3', bronze),
      ],
    );
  }

  Widget _buildPodiumPlayer(
      DocumentSnapshot player, String position, Color medalColor,
      {bool isCenter = false}) {
    final data = player.data() as Map<String, dynamic>;
    final userId = data['user_id'] ?? '';
    final username = data['username'] ?? 'Nepoznati korisnik';
    final score = data['score']?.toString() ?? '0';
    double avatarRadius = isCenter ? 30.0 : 20.0;
    double fontSize = isCenter ? 16.0 : 14.0;
    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            position,
            style: TextStyle(
              fontSize: isCenter ? 24 : 20,
              fontWeight: FontWeight.bold,
              color: medalColor,
            ),
          ),
          const SizedBox(height: 5),
          Container(
            width: isCenter ? 100 : 80,
            height: isCenter ? 140 : 100,
            decoration: BoxDecoration(
              color: medalColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: medalColor, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ProfileAvatar(
                  userId: userId,
                  radius: avatarRadius,
                ),
                const SizedBox(height: 5),
                Flexible(
                  child: Text(
                    username,
                    style: TextStyle(fontSize: fontSize),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                Flexible(
                  child: Text(
                    '$score ${Provider.of<LocalizationService>(context, listen: false).translate('points') ?? 'bodova'}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localization = Provider.of<LocalizationService>(context);
    return ChangeNotifierProvider(
      create: (_) => CountdownTimer(), // 5-sekundno odbrojavanje
      child: Scaffold(
        appBar: AppBar(
          title: Text(
              localization.translate('back_to_start') ?? 'Povratak na početnu'),
        ),
        body: Consumer<CountdownTimer>(
          builder: (context, timer, child) {
            if (hasPlayedToday) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      randomMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'WorkSans',
                      ),
                    ),
                    const SizedBox(height: 20),
                    FutureBuilder<Map<String, dynamic>?>(
                      future: futureYesterdayWinner,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        }
                        if (!snapshot.hasData || snapshot.data == null) {
                          return Text(
                              localization.translate('no_yesterday_winner') ??
                                  'Nema pobjednika jučer.');
                        }
                        final winnerData = snapshot.data!;
                        final userId = winnerData['user_id'] ?? '';
                        final username =
                            winnerData['username'] ?? 'Nepoznati korisnik';
                        final score = winnerData['score']?.toString() ?? '0';
                        return Column(
                          children: [
                            Text(
                              localization.translate('yesterday_winner') ??
                                  'Jučerašnji pobjednik',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Image.asset(
                                  'assets/images/frame.png',
                                  width: 220,
                                  height: 220,
                                ),
                                Positioned(
                                  top: 65,
                                  child: ProfileAvatar(
                                    userId: userId,
                                    radius: 50,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              username,
                              style: const TextStyle(fontSize: 16),
                            ),
                            Text(
                              '$score ${localization.translate('points') ?? 'bodova'}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 30),
                    FutureBuilder<List<Widget>>(
                      future: futurePlayersWhoPlayedToday,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Text(localization
                                  .translate('no_players_played_today') ??
                              'Nema igrača danas.');
                        }
                        return Column(
                          children: snapshot.data!,
                        );
                      },
                    ),
                  ],
                ),
              );
            } else if (timer.timeRemaining.inSeconds <= 0) {
              return QuizWidget(
                username: widget.username,
                countryId: widget.countryId,
                cityId: widget.cityId,
                locationId: widget.locationId,
              );
            } else {
              // Cool 5-sekundno odbrojavanje – stilizirano
              return Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.deepPurple, Colors.indigo],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        localization.translate('quiz_starts_in') ??
                            'Kviz počinje za',
                        style: const TextStyle(
                          fontSize: 28,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '${timer.timeRemaining.inSeconds}',
                        style: const TextStyle(
                          fontSize: 80,
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }
}

/// Timer koji počinje od 5 sekundi.
class CountdownTimer extends ChangeNotifier {
  DateTime quizTime;
  Duration timeRemaining;
  Timer? _timer;

  CountdownTimer()
      : quizTime = DateTime.now().add(const Duration(seconds: 5)),
        timeRemaining = Duration.zero {
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      timeRemaining = quizTime.difference(DateTime.now());
      if (timeRemaining.isNegative) {
        timeRemaining = Duration.zero;
        _timer?.cancel();
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Kviz widget – sada s običnim pitanjima i vraćenim opisom odgovora nakon izbora.
class QuizWidget extends StatefulWidget {
  final String username;
  final String countryId;
  final String cityId;
  final String locationId;

  const QuizWidget({
    super.key,
    required this.username,
    required this.countryId,
    required this.cityId,
    required this.locationId,
  });

  @override
  QuizWidgetState createState() => QuizWidgetState();
}

class QuizWidgetState extends State<QuizWidget> {
  late Future<List<Question>> futureQuestions;
  int currentQuestionIndex = 0;
  int score = 0;
  List<int?> userAnswers = [];
  List<Question> questions = [];
  bool quizCompleted = false;

  // Za prikaz objašnjenja nakon odgovora
  bool answerSelected = false;
  bool isCorrect = false;
  String explanation = '';

  // Za konačni pregled rezultata
  List<Widget> resultsWidgets = [];

  @override
  void initState() {
    super.initState();
    futureQuestions = fetchQuestions();
    futureQuestions.then((fetchedQuestions) {
      questions = fetchedQuestions;
    });
  }

  Future<String> _getUserProfileImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        return data['profileImageUrl'] ?? '';
      }
    }
    return '';
  }

  Future<List<Question>> fetchQuestions() async {
    final localization =
        Provider.of<LocalizationService>(context, listen: false);
    final String languageCode = localization.currentLanguage;
    final String url = 'https://conexa.life/quizz/quiz_$languageCode.json';

    try {
      final response = await http.get(Uri.parse(url));
      // Ispravno dekodiramo tijelo odgovora koristeći UTF-8
      final String jsonString = utf8.decode(response.bodyBytes);
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList.map((json) => Question.fromJson(json)).toList();
    } catch (e) {
      throw Exception(
        '${localization.translate('error_loading_questions') ?? 'Greška pri učitavanju pitanja'}: $e',
      );
    }
  }

  void _handleAnswerSelection(int selectedIndex) {
    if (answerSelected) return;
    final currentQuestion = questions[currentQuestionIndex];
    isCorrect = currentQuestion.correctOption == selectedIndex;
    explanation = currentQuestion.explanation;
    if (isCorrect) {
      score += 10;
    } else {
      score -= 10;
    }
    setState(() {
      answerSelected = true;
      if (userAnswers.length > currentQuestionIndex) {
        userAnswers[currentQuestionIndex] = selectedIndex;
      } else {
        userAnswers.add(selectedIndex);
      }
    });
  }

  /// Prilikom prelaska na sljedeće pitanje resetiramo zastavice.
  void _nextQuestion() {
    if (currentQuestionIndex >= questions.length - 1) {
      _saveQuizResults().then((_) => _showResults());
    } else {
      setState(() {
        currentQuestionIndex++;
        answerSelected = false;
        isCorrect = false;
        explanation = '';
      });
    }
  }

  Future<void> _saveQuizResults() async {
    final localization =
        Provider.of<LocalizationService>(context, listen: false);
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      String latestProfileUrl = await _getUserProfileImage();
      final firestore = FirebaseFirestore.instance;
      final String todayDate =
          DateTime.now().toIso8601String().substring(0, 10);
      final quizResultsRef = firestore
          .collection('countries')
          .doc(widget.countryId)
          .collection('cities')
          .doc(widget.cityId)
          .collection('locations')
          .doc(widget.locationId)
          .collection('quizz')
          .doc(todayDate)
          .collection('results');
      try {
        await firestore.runTransaction((transaction) async {
          final userDoc =
              await transaction.get(quizResultsRef.doc(currentUser.uid));
          if (userDoc.exists) {
            transaction.update(quizResultsRef.doc(currentUser.uid), {
              'score': score,
            });
          } else {
            transaction.set(quizResultsRef.doc(currentUser.uid), {
              'user_id': currentUser.uid,
              'username': widget.username,
              'score': score,
              'completed_at': FieldValue.serverTimestamp(),
              'profile_image_url': latestProfileUrl,
            });
          }
        });
      } catch (e) {
        _showSnackBar(
            context, '${localization.translate('error_saving_results')}: $e');
      }
    }
  }

  Future<void> _showResults() async {
    final localization =
        Provider.of<LocalizationService>(context, listen: false);
    int totalScore = score;
    String latestProfileUrl = await _getUserProfileImage();
    resultsWidgets.add(
      Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundImage: latestProfileUrl.isNotEmpty
                ? (latestProfileUrl.startsWith('http')
                    ? NetworkImage(latestProfileUrl)
                    : AssetImage(latestProfileUrl) as ImageProvider)
                : null,
            child: latestProfileUrl.isEmpty
                ? const Icon(Icons.person, size: 30, color: Colors.grey)
                : null,
          ),
          const SizedBox(height: 10),
          Text(
            widget.username,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(
            '${localization.translate('your_score')}: $totalScore',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
    for (int i = 0; i < userAnswers.length; i++) {
      bool questionIsCorrect = questions[i].correctOption == userAnswers[i];
      resultsWidgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                questions[i].question,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                questionIsCorrect
                    ? '${localization.translate('correct_answer')}: ${questions[i].options[questions[i].correctOption]}'
                    : '${localization.translate('your_answer')}: ${userAnswers[i] != null ? questions[i].options[userAnswers[i]!] : localization.translate('no_answer')}\n${localization.translate('correct_answer')}: ${questions[i].options[questions[i].correctOption]}',
                style: TextStyle(
                  fontSize: 16,
                  color:
                      questionIsCorrect ? Colors.green[700] : Colors.red[700],
                ),
              ),
              const SizedBox(height: 5),
              Text(
                questions[i].explanation,
                style:
                    const TextStyle(fontStyle: FontStyle.italic, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }
    await _showLeaderboard();
    setState(() {
      quizCompleted = true;
    });
  }

  Future<void> _showLeaderboard() async {
    final localization =
        Provider.of<LocalizationService>(context, listen: false);
    final firestore = FirebaseFirestore.instance;
    final String todayDate = DateTime.now().toIso8601String().substring(0, 10);
    final quizResultsRef = firestore
        .collection('countries')
        .doc(widget.countryId)
        .collection('cities')
        .doc(widget.cityId)
        .collection('locations')
        .doc(widget.locationId)
        .collection('quizz')
        .doc(todayDate)
        .collection('results')
        .orderBy('score', descending: true);
    final querySnapshot = await quizResultsRef.get();
    List<Widget> leaderboardWidgets = querySnapshot.docs.map((doc) {
      final data = doc.data();
      final userId = data['user_id'] ?? '';
      final username = data['username'] ?? 'Nepoznati korisnik';
      final scoreStr = data['score']?.toString() ?? '0';
      return ListTile(
        leading: ProfileAvatar(
          userId: userId,
          radius: 20,
        ),
        title: Text(username),
        trailing:
            Text('$scoreStr ${localization.translate('points') ?? 'bodova'}'),
      );
    }).toList();
    resultsWidgets.add(const SizedBox(height: 20));
    resultsWidgets.add(
      Text(
        localization.translate('leaderboard_today') ?? 'Leaderboard danas',
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
    resultsWidgets.addAll(leaderboardWidgets);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localization = Provider.of<LocalizationService>(context);
    if (quizCompleted) {
      return Scaffold(
        appBar: AppBar(
          title:
              Text(localization.translate('quiz_results') ?? 'Rezultati kviza'),
          automaticallyImplyLeading: false,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: resultsWidgets,
        ),
      );
    } else {
      return FutureBuilder<List<Question>>(
        future: futureQuestions,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          } else if (snapshot.hasError) {
            return Scaffold(
              appBar: AppBar(
                title: Text(localization.translate('error') ?? 'Greška'),
                automaticallyImplyLeading: false,
              ),
              body: Center(
                child: Text(localization.translate('error_loading_questions') ??
                    'Greška pri učitavanju pitanja.'),
              ),
            );
          } else {
            final currentQuestion = questions[currentQuestionIndex];
            final bool isLastQuestion =
                currentQuestionIndex == questions.length - 1;
            return Scaffold(
              appBar: AppBar(
                title: Text(localization.translate('quiz') ?? 'Kviz'),
                automaticallyImplyLeading: false,
              ),
              body: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      '${localization.translate('question')} ${currentQuestionIndex + 1}/${questions.length}',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      currentQuestion.question,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    if (!answerSelected)
                      Expanded(
                        child: ListView.builder(
                          itemCount: currentQuestion.options.length,
                          itemBuilder: (context, index) {
                            return Card(
                              child: ListTile(
                                title: Text(currentQuestion.options[index]),
                                onTap: () => _handleAnswerSelection(index),
                              ),
                            );
                          },
                        ),
                      )
                    else
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              child: ListView.builder(
                                itemCount: currentQuestion.options.length,
                                itemBuilder: (context, index) {
                                  return Card(
                                    color: index ==
                                            currentQuestion.correctOption
                                        ? Colors.green[100]
                                        : (userAnswers[currentQuestionIndex] ==
                                                index
                                            ? Colors.red[100]
                                            : null),
                                    child: ListTile(
                                      title:
                                          Text(currentQuestion.options[index]),
                                    ),
                                  );
                                },
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isCorrect
                                      ? (localization.translate('correct') ??
                                          'Točno!')
                                      : (localization.translate('incorrect') ??
                                          'Netočno!'),
                                  style: TextStyle(
                                    fontSize: 18,
                                    color:
                                        isCorrect ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  explanation,
                                  style: const TextStyle(
                                      fontStyle: FontStyle.italic,
                                      fontSize: 16),
                                ),
                                const SizedBox(height: 20),
                                // Na zadnjem pitanju prikazujemo strelicu
                                isLastQuestion
                                    ? IconButton(
                                        icon: const Icon(Icons.arrow_forward),
                                        iconSize: 36,
                                        onPressed: _nextQuestion,
                                        tooltip: localization
                                                .translate('view_results') ??
                                            'Prikaži rezultate',
                                      )
                                    : ElevatedButton(
                                        onPressed: _nextQuestion,
                                        child: Text(localization
                                                .translate('next_question') ??
                                            'Sljedeće pitanje'),
                                      ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          }
        },
      );
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
}

/// Klasa pitanja – sada s pitanjem, opcijama, indeksom točnog odgovora i objašnjenjem.
class Question {
  final String question;
  final List<String> options;
  final int correctOption;
  final String explanation;

  Question({
    required this.question,
    required this.options,
    required this.correctOption,
    required this.explanation,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      question: json['question'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      correctOption: json['correct_option'] ?? -1,
      explanation: json['explanation'] ?? '',
    );
  }
}
