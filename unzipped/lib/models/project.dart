// lib/models/project.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum FunnelStage { build, story, visualize, share }

FunnelStage funnelStageFromString(String s) {
  switch (s) {
    case 'build': return FunnelStage.build;
    case 'story': return FunnelStage.story;
    case 'visualize': return FunnelStage.visualize;
    case 'share': return FunnelStage.share;
    default: return FunnelStage.build;
  }
}

String funnelStageToString(FunnelStage s) {
  switch (s) {
    case FunnelStage.build: return 'build';
    case FunnelStage.story: return 'story';
    case FunnelStage.visualize: return 'visualize';
    case FunnelStage.share: return 'share';
  }
}

class ProjectDoc {
  final String id;
  final String ownerId;
  final String title;
  final String? activePaletteId;
  final List<String> paletteIds;
  final String? colorStoryId; // links to colorStories/{id} once generated
  final String? roomType;
  final String? styleTag;
  final List<String> vibeWords;
  final FunnelStage funnelStage;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProjectDoc({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.paletteIds,
    required this.funnelStage,
    required this.createdAt,
    required this.updatedAt,
    this.activePaletteId,
    this.colorStoryId,
    this.roomType,
    this.styleTag,
    this.vibeWords = const [],
  });

  factory ProjectDoc.fromSnap(DocumentSnapshot snap) {
    final d = snap.data() as Map<String, dynamic>? ?? {};
    return ProjectDoc(
      id: snap.id,
      ownerId: d['ownerId'] ?? '',
      title: d['title'] ?? 'Untitled Story',
      activePaletteId: d['activePaletteId'],
      paletteIds: List<String>.from(d['paletteIds'] ?? const []),
      colorStoryId: d['colorStoryId'],
      roomType: d['roomType'],
      styleTag: d['styleTag'],
      vibeWords: List<String>.from(d['vibeWords'] ?? const []),
      funnelStage: funnelStageFromString((d['funnelStage'] ?? 'build') as String),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'ownerId': ownerId,
    'title': title,
    'activePaletteId': activePaletteId,
    'paletteIds': paletteIds,
    'colorStoryId': colorStoryId,
    'roomType': roomType,
    'styleTag': styleTag,
    'vibeWords': vibeWords,
    'funnelStage': funnelStageToString(funnelStage),
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  ProjectDoc copyWith({
    String? title,
    String? activePaletteId,
    List<String>? paletteIds,
    String? colorStoryId,
    String? roomType,
    String? styleTag,
    List<String>? vibeWords,
    FunnelStage? funnelStage,
    DateTime? updatedAt,
  }) => ProjectDoc(
    id: id,
    ownerId: ownerId,
    title: title ?? this.title,
    activePaletteId: activePaletteId ?? this.activePaletteId,
    paletteIds: paletteIds ?? this.paletteIds,
    colorStoryId: colorStoryId ?? this.colorStoryId,
    roomType: roomType ?? this.roomType,
    styleTag: styleTag ?? this.styleTag,
    vibeWords: vibeWords ?? this.vibeWords,
    funnelStage: funnelStage ?? this.funnelStage,
    createdAt: createdAt,
    updatedAt: updatedAt ?? DateTime.now(),
  );
}