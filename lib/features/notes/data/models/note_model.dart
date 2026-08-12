class NoteModel {
  final String id;
  final String title;
  final String content;
  final String contentType;
  final String? subjectId;
  final String? topic;
  final List<String> tags;
  final String? color;
  final bool isPinned;
  final String? subjectName;
  final String createdAt;

  const NoteModel({
    required this.id,
    required this.title,
    required this.content,
    required this.contentType,
    this.subjectId,
    this.topic,
    this.tags = const [],
    this.color,
    this.isPinned = false,
    this.subjectName,
    required this.createdAt,
  });

  factory NoteModel.fromJson(Map<String, dynamic> json) {
    return NoteModel(
      id: json['_id']?.toString() ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      contentType: json['contentType'] ?? 'richtext',
      subjectId: json['subjectId']?.toString(),
      topic: json['topic'],
      tags: List<String>.from(json['tags'] ?? []),
      color: json['color'],
      isPinned: json['isPinned'] ?? false,
      subjectName: json['subject']?['name'],
      createdAt: json['createdAt'] ?? '',
    );
  }
}
