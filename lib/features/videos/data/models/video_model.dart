class VideoModel {
  final String id;
  final String title;
  final String youtubeVideoId;
  final String? description;
  final int viewCount;
  final String? subjectName;
  final String? topic;
  final List<String> tags;
  final String createdAt;

  const VideoModel({
    required this.id,
    required this.title,
    required this.youtubeVideoId,
    this.description,
    this.viewCount = 0,
    this.subjectName,
    this.topic,
    this.tags = const [],
    required this.createdAt,
  });

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      id: json['_id']?.toString() ?? '',
      title: json['title'] ?? '',
      youtubeVideoId: json['youtubeVideoId'] ?? '',
      description: json['description'],
      viewCount: json['viewCount'] ?? 0,
      subjectName: json['subject']?['name'],
      topic: json['topic'],
      tags: List<String>.from(json['tags'] ?? []),
      createdAt: json['createdAt'] ?? '',
    );
  }

  String get thumbnailUrl =>
      'https://img.youtube.com/vi/$youtubeVideoId/hqdefault.jpg';
}
