class QuizModel {
  final String id;
  final String title;
  final String? description;
  final String? subjectId;
  final String? topic;
  final List<QuizQuestion> questions;
  final int passingScore;
  final int timeLimit;
  final int totalPoints;
  final String? subjectName;
  final bool shuffle;

  const QuizModel({
    required this.id,
    required this.title,
    this.description,
    this.subjectId,
    this.topic,
    this.questions = const [],
    this.passingScore = 70,
    this.timeLimit = 0,
    this.totalPoints = 0,
    this.subjectName,
    this.shuffle = false,
  });

  factory QuizModel.fromJson(Map<String, dynamic> json) {
    return QuizModel(
      id: json['_id']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      subjectId: json['subjectId']?.toString(),
      topic: json['topic'],
      questions: (json['questions'] as List? ?? [])
          .map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
          .toList(),
      passingScore: json['passingScore'] ?? 70,
      timeLimit: json['timeLimit'] ?? 0,
      totalPoints: json['totalPoints'] ?? 0,
      subjectName: json['subject']?['name'],
      shuffle: json['shuffle'] ?? false,
    );
  }

  String get difficulty {
    if (questions.length <= 5) return 'Easy';
    if (questions.length <= 15) return 'Medium';
    return 'Hard';
  }
}

class QuizPairModel {
  final String left;
  final String right;

  const QuizPairModel({required this.left, required this.right});

  factory QuizPairModel.fromJson(Map<String, dynamic> json) {
    return QuizPairModel(
      left: json['left']?.toString() ?? json['term']?.toString() ?? '',
      right: json['right']?.toString() ?? json['definition']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'left': left, 'right': right};
}

class QuizQuestion {
  final String id;
  final String text;
  final String type;
  final List<String> options;
  final String? code;
  final String? language;
  final int? correctIndex;
  final String? explanation;
  final int points;
  final List<QuizPairModel> pairs;
  final List<String> leftItems;
  final List<String> rightItems;

  const QuizQuestion({
    required this.id,
    required this.text,
    required this.type,
    this.options = const [],
    this.code,
    this.language,
    this.correctIndex,
    this.explanation,
    this.points = 1,
    this.pairs = const [],
    this.leftItems = const [],
    this.rightItems = const [],
  });

  bool get isMatchPairs => type == 'match-pairs' || type == 'match_pairs';
  bool get isCodeMcq => type == 'code-mcq';

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      text: json['text'] ?? json['question'] ?? '',
      type: json['type'] ?? 'multiple-choice',
      options: List<String>.from(json['options'] ?? []),
      code: json['code'],
      language: json['language'],
      correctIndex: json['correctIndex'] is num ? (json['correctIndex'] as num).toInt() : null,
      explanation: json['explanation'],
      points: json['points'] is num ? (json['points'] as num).toInt() : 1,
      pairs: (json['pairs'] as List? ?? [])
          .map((p) => QuizPairModel.fromJson(p as Map<String, dynamic>))
          .toList(),
      leftItems: List<String>.from(json['leftItems'] ?? []),
      rightItems: List<String>.from(json['rightItems'] ?? []),
    );
  }
}

class AttemptModel {
  final String id;
  final int score;
  final int maxScore;
  final double percentage;
  final bool passed;
  final List<AttemptAnswer> answers;
  final int timeTaken;
  final String? submittedAt;

  const AttemptModel({
    required this.id,
    required this.score,
    required this.maxScore,
    required this.percentage,
    required this.passed,
    required this.answers,
    required this.timeTaken,
    this.submittedAt,
  });

  factory AttemptModel.fromJson(Map<String, dynamic> json) {
    return AttemptModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      score: json['score'] ?? 0,
      maxScore: json['maxScore'] ?? 0,
      percentage: (json['percentage'] ?? 0).toDouble(),
      passed: json['passed'] ?? false,
      answers: (json['answers'] as List? ?? [])
          .map((a) => AttemptAnswer.fromJson(a as Map<String, dynamic>))
          .toList(),
      timeTaken: (json['timeTakenSecs'] ?? json['timeTaken'] ?? 0).toInt(),
      submittedAt: json['createdAt'] ?? json['submittedAt'],
    );
  }
}

class AttemptAnswer {
  final String questionId;
  final int selectedIndex;
  final bool correct;
  final int correctIndex;
  final String? explanation;
  final List<QuizPairModel> matches;
  final int correctCount;
  final int totalPairs;
  final int pointsEarned;

  const AttemptAnswer({
    required this.questionId,
    this.selectedIndex = -1,
    this.correct = false,
    this.correctIndex = 0,
    this.explanation,
    this.matches = const [],
    this.correctCount = 0,
    this.totalPairs = 0,
    this.pointsEarned = 0,
  });

  factory AttemptAnswer.fromJson(Map<String, dynamic> json) {
    final matchesList = (json['matches'] as List? ?? json['pairs'] as List? ?? json['submittedMatches'] as List? ?? [])
        .map((m) => QuizPairModel.fromJson(m as Map<String, dynamic>))
        .toList();

    return AttemptAnswer(
      questionId: json['questionId']?.toString() ?? json['_id']?.toString() ?? '',
      selectedIndex: json['selectedIndex'] ?? json['chosenIndex'] ?? -1,
      correct: json['correct'] ?? json['isCorrect'] ?? false,
      correctIndex: json['correctIndex'] ?? 0,
      explanation: json['explanation'],
      matches: matchesList,
      correctCount: json['correctCount'] ?? 0,
      totalPairs: json['totalPairs'] ?? matchesList.length,
      pointsEarned: json['pointsEarned'] ?? 0,
    );
  }
}

