import 'karaoke_model.dart';
import 'dart:convert';

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
  final String? audioUrl;
  final double duration;
  final KaraokeStory? karaokeData;

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
    this.audioUrl,
    this.duration = 0.0,
    this.karaokeData,
  });

  bool get isKaraoke => contentType == 'karaoke' || karaokeData != null;

  factory NoteModel.fromJson(Map<String, dynamic> json) {
    KaraokeStory? parsedKaraoke;
    if (json['karaokeData'] != null) {
      try {
        if (json['karaokeData'] is Map) {
          parsedKaraoke = KaraokeStory.fromJson(Map<String, dynamic>.from(json['karaokeData']));
        } else if (json['karaokeData'] is String && json['karaokeData'].toString().trim().isNotEmpty) {
          parsedKaraoke = KaraokeStory.fromJson(jsonDecode(json['karaokeData']));
        }
      } catch (e) {
        parsedKaraoke = null;
      }
    }

    return NoteModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
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
      audioUrl: json['audioUrl']?.toString(),
      duration: (json['duration'] is num) ? (json['duration'] as num).toDouble() : 0.0,
      karaokeData: parsedKaraoke,
    );
  }
}
