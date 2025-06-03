class Question {
  final String question;
  final List<String> options;
  final int correctOption;

  Question({
    required this.question,
    required this.options,
    required this.correctOption,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      question: json['question'],
      options: List<String>.from(json['options']),
      correctOption: json['correct_option'],
    );
  }

  get explanation => null;
}
