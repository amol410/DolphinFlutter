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

class QuizQuestion {
  final String id;
  final String text;
  final String type;
  final List<String> options;
  final String? code;
  final String? language;

  const QuizQuestion({
    required this.id,
    required this.text,
    required this.type,
    required this.options,
    this.code,
    this.language,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      id: json['_id']?.toString() ?? '',
      text: json['text'] ?? '',
      type: json['type'] ?? 'multiple-choice',
      options: List<String>.from(json['options'] ?? []),
      code: json['code'],
      language: json['language'],
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

  const AttemptModel({
    required this.id,
    required this.score,
    required this.maxScore,
    required this.percentage,
    required this.passed,
    required this.answers,
    required this.timeTaken,
  });

  factory AttemptModel.fromJson(Map<String, dynamic> json) {
    return AttemptModel(
      id: json['_id']?.toString() ?? '',
      score: json['score'] ?? 0,
      maxScore: json['maxScore'] ?? 0,
      percentage: (json['percentage'] ?? 0).toDouble(),
      passed: json['passed'] ?? false,
      answers: (json['answers'] as List? ?? [])
          .map((a) => AttemptAnswer.fromJson(a as Map<String, dynamic>))
          .toList(),
      timeTaken: (json['timeTakenSecs'] ?? json['timeTaken'] ?? 0).toInt(),
    );
  }
}

class AttemptAnswer {
  final String questionId;
  final int selectedIndex;
  final bool correct;
  final int correctIndex;
  final String? explanation;

  const AttemptAnswer({
    required this.questionId,
    required this.selectedIndex,
    required this.correct,
    required this.correctIndex,
    this.explanation,
  });

  factory AttemptAnswer.fromJson(Map<String, dynamic> json) {
    return AttemptAnswer(
      questionId: json['questionId']?.toString() ?? '',
      selectedIndex: json['selectedIndex'] ?? -1,
      correct: json['correct'] ?? false,
      correctIndex: json['correctIndex'] ?? 0,
      explanation: json['explanation'],
    );
  }
}
