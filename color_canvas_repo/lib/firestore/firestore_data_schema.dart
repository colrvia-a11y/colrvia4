import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:color_canvas/utils/color_utils.dart';

// Brand model
class Brand {
  final String id;
  final String name;
  final String slug;
  final String? website;

  Brand({
    required this.id,
    required this.name,
    required this.slug,
    this.website,
  });

  factory Brand.fromJson(Map<String, dynamic> json, String id) {
    return Brand(
      id: id,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      website: json['website'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'slug': slug,
      'website': website,
    };
  }
}

// Paint model with CIELAB values
class Paint {
  final String id;
  final String brandId;
  final String brandName;
  final String name;
  final String code;
  final String hex;
  final List<int> rgb;
  final List<double> lab;
  final List<double> lch;
  final String? collection;
  final String? finish;
  final Map<String, dynamic>? metadata;

  Paint({
    required this.id,
    required this.brandId,
    required this.brandName,
    required this.name,
    required this.code,
    required this.hex,
    required this.rgb,
    required this.lab,
    required this.lch,
    this.collection,
    this.finish,
    this.metadata,
  });

  factory Paint.fromJson(Map<String, dynamic> json, String id) {
    return Paint(
      id: id,
      brandId: json['brandId'] ?? '',
      brandName: json['brandName'] ?? '',
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      hex: json['hex'] ?? '#000000',
      rgb: List<int>.from(json['rgb'] ?? [0, 0, 0]),
      lab: List<double>.from(json['lab'] ?? [0.0, 0.0, 0.0]),
      lch: List<double>.from(json['lch'] ?? [0.0, 0.0, 0.0]),
      collection: json['collection'],
      finish: json['finish'],
      metadata: json['metadata'],
    );
  }

  // Computed LRV (Light Reflectance Value) using LAB lightness or hex fallback
  double get computedLrv => lrvForPaint(paintLrv: null, hex: hex);

  Map<String, dynamic> toJson() {
    return {
      'brandId': brandId,
      'brandName': brandName,
      'name': name,
      'code': code,
      'hex': hex,
      'rgb': rgb,
      'lab': lab,
      'lch': lch,
      'collection': collection,
      'finish': finish,
      'metadata': metadata,
    };
  }
}

// Palette color with lock state
class PaletteColor {
  final String paintId;
  final bool locked;
  final int position;
  final String? brand;
  final String name;
  final String code;
  final String hex;

  PaletteColor({
    required this.paintId,
    required this.locked,
    required this.position,
    this.brand,
    required this.name,
    required this.code,
    required this.hex,
  });

  factory PaletteColor.fromJson(Map<String, dynamic> json) {
    return PaletteColor(
      paintId: json['paintId'] ?? '',
      locked: json['locked'] ?? false,
      position: json['position'] ?? 0,
      brand: json['brand'],
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      hex: json['hex'] ?? '#000000',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'paintId': paintId,
      'locked': locked,
      'position': position,
      'brand': brand,
      'name': name,
      'code': code,
      'hex': hex,
    };
  }

  Paint toPaint() {
    return Paint(
      id: paintId,
      brandId: brand ?? '',
      brandName: brand ?? '',
      name: name,
      code: code,
      hex: hex,
      rgb: ColorUtils.hexToRgb(hex),
      lab: ColorUtils.rgbToLab(
        ColorUtils.hexToRgb(hex)[0],
        ColorUtils.hexToRgb(hex)[1],
        ColorUtils.hexToRgb(hex)[2],
      ),
      lch: [0.0, 0.0, 0.0],
    );
  }
}

// User palette
class UserPalette {
  final String id;
  final String userId;
  final String name;
  final List<PaletteColor> colors;
  final List<String> tags;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserPalette({
    required this.id,
    required this.userId,
    required this.name,
    required this.colors,
    required this.tags,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserPalette.fromJson(Map<String, dynamic> json, String id) {
    return UserPalette(
      id: id,
      userId: json['userId'] ?? '',
      name: json['name'] ?? '',
      colors: (json['colors'] as List? ?? [])
          .map((color) => PaletteColor.fromJson(color))
          .toList(),
      tags: List<String>.from(json['tags'] ?? []),
      notes: json['notes'] ?? '',
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'colors': colors.map((color) => color.toJson()).toList(),
      'tags': tags,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  UserPalette copyWith({
    String? id,
    String? userId,
    String? name,
    List<PaletteColor>? colors,
    List<String>? tags,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserPalette(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      colors: colors ?? this.colors,
      tags: tags ?? this.tags,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// Share link
class ShareLink {
  final String id;
  final String paletteId;
  final String visibility; // 'private', 'unlisted', 'public'

  ShareLink({
    required this.id,
    required this.paletteId,
    required this.visibility,
  });

  factory ShareLink.fromJson(Map<String, dynamic> json, String id) {
    return ShareLink(
      id: id,
      paletteId: json['paletteId'] ?? '',
      visibility: json['visibility'] ?? 'private',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'paletteId': paletteId,
      'visibility': visibility,
    };
  }
}

// User favorite paint
class FavoritePaint {
  final String id;
  final String userId;
  final String paintId;
  final DateTime createdAt;

  FavoritePaint({
    required this.id,
    required this.userId,
    required this.paintId,
    required this.createdAt,
  });

  factory FavoritePaint.fromJson(Map<String, dynamic> json, String id) {
    return FavoritePaint(
      id: id,
      userId: json['userId'] ?? '',
      paintId: json['paintId'] ?? '',
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'paintId': paintId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

// User copied paint data
class CopiedPaint {
  final String id;
  final String userId;
  final Paint paint;
  final DateTime createdAt;

  CopiedPaint({
    required this.id,
    required this.userId,
    required this.paint,
    required this.createdAt,
  });

  factory CopiedPaint.fromJson(Map<String, dynamic> json, String id) {
    return CopiedPaint(
      id: id,
      userId: json['userId'] ?? '',
      paint: Paint.fromJson(json['paint'], json['paint']['id'] ?? ''),
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'paint': paint.toJson(),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

// Visualizer saved scene document
class VisualizerDoc {
  final String id;
  final String userId;
  final String roomId;
  final Map<String, dynamic> assignments; // surfaceType.name -> { paintId, finish }
  final double brightness; // -1..+1
  final double whiteBalanceK; // 2700..6500
  final String? style; // optional tag
  final DateTime createdAt;
  final DateTime updatedAt;

  VisualizerDoc({
    required this.id,
    required this.userId,
    required this.roomId,
    required this.assignments,
    required this.brightness,
    required this.whiteBalanceK,
    this.style,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VisualizerDoc.fromJson(Map<String, dynamic> json, String id) {
    return VisualizerDoc(
      id: id,
      userId: json['userId'] ?? '',
      roomId: json['roomId'] ?? 'living_room',
      assignments: Map<String, dynamic>.from(json['assignments'] ?? {}),
      brightness: (json['brightness'] ?? 0.0).toDouble(),
      whiteBalanceK: (json['whiteBalanceK'] ?? 4000.0).toDouble(),
      style: json['style'],
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'roomId': roomId,
      'assignments': assignments,
      'brightness': brightness,
      'whiteBalanceK': whiteBalanceK,
      'style': style,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

// User profile
class UserProfile {
  final String id;
  final String email;
  final String displayName;
  final String plan;
  final int paletteCount;
  final int generationsThisMonth;
  final DateTime lastGenerationResetDate;
  final bool isAdmin;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    required this.plan,
    required this.paletteCount,
    this.generationsThisMonth = 0,
    DateTime? lastGenerationResetDate,
    this.isAdmin = false,
    required this.createdAt,
  }) : lastGenerationResetDate = lastGenerationResetDate ?? DateTime.now();

  factory UserProfile.fromJson(Map<String, dynamic> json, String id) {
    return UserProfile(
      id: id,
      email: json['email'] ?? '',
      displayName: json['displayName'] ?? '',
      plan: json['plan'] ?? 'free',
      paletteCount: json['paletteCount'] ?? 0,
      generationsThisMonth: json['generationsThisMonth'] ?? 0,
      lastGenerationResetDate: json['lastGenerationResetDate'] != null
          ? (json['lastGenerationResetDate'] as Timestamp).toDate()
          : DateTime.now(),
      isAdmin: json['isAdmin'] ?? false,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'displayName': displayName,
      'plan': plan,
      'paletteCount': paletteCount,
      'generationsThisMonth': generationsThisMonth,
      'lastGenerationResetDate': Timestamp.fromDate(lastGenerationResetDate),
      'isAdmin': isAdmin,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  UserProfile copyWith({
    String? email,
    String? displayName,
    String? plan,
    int? paletteCount,
    int? generationsThisMonth,
    DateTime? lastGenerationResetDate,
    bool? isAdmin,
  }) {
    return UserProfile(
      id: id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      plan: plan ?? this.plan,
      paletteCount: paletteCount ?? this.paletteCount,
      generationsThisMonth: generationsThisMonth ?? this.generationsThisMonth,
      lastGenerationResetDate: lastGenerationResetDate ?? this.lastGenerationResetDate,
      isAdmin: isAdmin ?? this.isAdmin,
      createdAt: createdAt,
    );
  }

  bool get isPro => true; // Always allow pro features for testing
  bool get canGenerateStories => true; // Always allow story generation
  bool get canSavePalettes => true; // Always allow palette saves
}

// Color Story palette item
class ColorStoryPalette {
  final String role; // main, accent, trim, ceiling, door, cabinet
  final String hex;
  final String? paintId;
  final String? brandName;
  final String? name;
  final String? code;
  final String? psychology;
  final String? usageTips;

  ColorStoryPalette({
    required this.role,
    required this.hex,
    this.paintId,
    this.brandName,
    this.name,
    this.code,
    this.psychology,
    this.usageTips,
  });

  factory ColorStoryPalette.fromJson(Map<String, dynamic> json) {
    return ColorStoryPalette(
      role: json['role'] ?? 'main',
      hex: json['hex'] ?? '#000000',
      paintId: json['paintId'],
      brandName: json['brandName'],
      name: json['name'],
      code: json['code'],
      psychology: json['psychology'],
      usageTips: json['usageTips'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'hex': hex,
      'paintId': paintId,
      'brandName': brandName,
      'name': name,
      'code': code,
      'psychology': psychology,
      'usageTips': usageTips,
    };
  }
}

// Color Story Usage Guide per color
class ColorStoryUsageGuide {
  final String role;
  final String howToUse;
  final String finishRecommendation;
  final String sheen;
  final String surface;

  ColorStoryUsageGuide({
    required this.role,
    required this.howToUse,
    required this.finishRecommendation,
    required this.sheen,
    required this.surface,
  });

  factory ColorStoryUsageGuide.fromJson(Map<String, dynamic> json) {
    return ColorStoryUsageGuide(
      role: json['role'] ?? '',
      howToUse: json['howToUse'] ?? '',
      finishRecommendation: json['finishRecommendation'] ?? '',
      sheen: json['sheen'] ?? '',
      surface: json['surface'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'howToUse': howToUse,
      'finishRecommendation': finishRecommendation,
      'sheen': sheen,
      'surface': surface,
    };
  }
}

// New Color Usage Guide Item (as specified in patch set v2)
class ColorUsageGuideItem {
  final String role;
  final String hex;
  final String name;
  final String brandName;
  final String code;
  final String howToUse;
  final String finishRecommendation;
  final String sheen;
  final String surface;

  ColorUsageGuideItem({
    required this.role,
    required this.hex,
    required this.name,
    required this.brandName,
    required this.code,
    required this.howToUse,
    required this.finishRecommendation,
    required this.sheen,
    required this.surface,
  });

  factory ColorUsageGuideItem.fromJson(Map<String, dynamic> json) {
    return ColorUsageGuideItem(
      role: json['role'] ?? '',
      hex: json['hex'] ?? '#000000',
      name: json['name'] ?? '',
      brandName: json['brandName'] ?? '',
      code: json['code'] ?? '',
      howToUse: json['howToUse'] ?? '',
      finishRecommendation: json['finishRecommendation'] ?? '',
      sheen: json['sheen'] ?? '',
      surface: json['surface'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'hex': hex,
      'name': name,
      'brandName': brandName,
      'code': code,
      'howToUse': howToUse,
      'finishRecommendation': finishRecommendation,
      'sheen': sheen,
      'surface': surface,
    };
  }
}

// AI Job for async processing
class AiJob {
  final String id;
  final String type; // "colorStory", "imageRegenerate", "audioRegenerate", etc.
  final String storyId;
  final String status; // "queued", "processing", "complete", "error"
  final double progress; // 0.0 - 1.0
  final String message;
  final DateTime createdAt;
  final DateTime updatedAt;

  AiJob({
    required this.id,
    required this.type,
    required this.storyId,
    required this.status,
    required this.progress,
    required this.message,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AiJob.fromJson(Map<String, dynamic> json, String id) {
    return AiJob(
      id: id,
      type: json['type'] ?? 'colorStory',
      storyId: json['storyId'] ?? '',
      status: json['status'] ?? 'queued',
      progress: (json['progress'] ?? 0.0).toDouble(),
      message: json['message'] ?? '',
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'storyId': storyId,
      'status': status,
      'progress': progress,
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

// Attribution metadata for AI-generated content
class AiAttribution {
  final String provider;
  final String model;
  final String? promptVersion;
  final int? seed;

  AiAttribution({
    required this.provider,
    required this.model,
    this.promptVersion,
    this.seed,
  });

  factory AiAttribution.fromJson(Map<String, dynamic>? json) {
    if (json == null) return AiAttribution(provider: 'Unknown', model: 'Unknown');
    return AiAttribution(
      provider: json['provider'] ?? 'Unknown',
      model: json['model'] ?? 'Unknown',
      promptVersion: json['promptVersion'],
      seed: json['seed'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'provider': provider,
      'model': model,
      if (promptVersion != null) 'promptVersion': promptVersion,
      if (seed != null) 'seed': seed,
    };
  }
}

// Color Story document (extended for AI features)
class ColorStory {
  final String id;
  final String userId; // User who created this story
  final String title;
  final String slug;
  final String? heroImageUrl;
  final List<String> themes;
  final List<String> families;
  final List<String> rooms;
  final List<String> tags;
  final String description;
  final bool isFeatured;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ColorStoryPalette> palette;
  final List<String> facets; // Denormalized filter array for efficient ANDed queries
  
  // AI-powered fields
  final String status; // "draft" | "queued" | "processing" | "complete" | "error"
  final double progress; // 0.0 - 1.0
  final String? progressMessage;
  final Map<String, dynamic>? processing; // Step-level progress data
  final String? sourcePaletteId; // links to palettes/{id}
  final String? narration; // AI-written color story body; 300–600 words
  final String? storyText; // Backward compatibility
  final List<ColorUsageGuideItem> usageGuide; // per-color how-to
  final String? audioUrl; // TTS or ambient audio
  final String? heroPrompt; // the final image generation prompt used
  final String access; // "private" | "unlisted" | "public"
  final String fallbackHero; // Gradient SVG data URI for instant fallback
  final int likeCount; // default 0
  final int playCount; // default 0
  final bool spotlight; // Featured in spotlight rail
  
  // Attribution metadata
  final AiAttribution? modelAttribution;
  final AiAttribution? heroImageAttribution;
  final AiAttribution? audioAttribution;
  
  // Enhanced wizard inputs
  final String? styleTag;
  final String? roomType;
  final List<String>? vibeWords;
  final List<String>? brandHints;
  final List<String>? colors; // Hex colors from original palette
  final String? paletteName;
  
  // Variant support
  final String? variantOf; // Parent story ID
  final String? emphasis; // Variant emphasis
  final List<String>? vibeTweaks; // Adjusted vibe words
  
  // Generation metadata
  final int? generationTimeMs;
  final String? version;

  ColorStory({
    required this.id,
    required this.userId,
    required this.title,
    required this.slug,
    this.heroImageUrl,
    required this.themes,
    required this.families,
    required this.rooms,
    required this.tags,
    required this.description,
    this.isFeatured = false,
    required this.createdAt,
    required this.updatedAt,
    required this.palette,
    required this.facets,
    // AI-powered fields
    this.status = "draft",
    this.progress = 0.0,
    this.progressMessage,
    this.processing,
    this.sourcePaletteId,
    this.narration,
    this.storyText,
    this.usageGuide = const [],
    this.audioUrl,
    this.heroPrompt,
    this.access = "private",
    String? fallbackHero,
    this.likeCount = 0,
    this.playCount = 0,
    this.spotlight = false,
    // Attribution metadata
    this.modelAttribution,
    this.heroImageAttribution,
    this.audioAttribution,
    // Enhanced wizard inputs
    this.styleTag,
    this.roomType,
    this.vibeWords,
    this.brandHints,
    this.colors,
    this.paletteName,
    // Variant support
    this.variantOf,
    this.emphasis,
    this.vibeTweaks,
    // Generation metadata
    this.generationTimeMs,
    this.version,
  }) : fallbackHero = fallbackHero ?? _generateFallbackFromUsageGuide({
    'usageGuide': usageGuide.map((item) => item.toJson()).toList(),
  });

  factory ColorStory.fromJson(Map<String, dynamic> json, String id) {
    return ColorStory(
      id: id,
      userId: json['userId'] ?? '',
      title: json['title'] ?? json['paletteName'] ?? '',
      slug: json['slug'] ?? '',
      heroImageUrl: json['heroImageUrl'],
      themes: List<String>.from(json['themes'] ?? []),
      families: List<String>.from(json['families'] ?? []),
      rooms: List<String>.from(json['rooms'] ?? []),
      tags: List<String>.from(json['tags'] ?? []),
      description: json['description'] ?? '',
      isFeatured: json['isFeatured'] ?? false,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
      palette: (json['palette'] as List? ?? [])
          .map((item) => ColorStoryPalette.fromJson(item))
          .toList(),
      facets: List<String>.from(json['facets'] ?? []),
      // AI-powered fields
      status: json['status'] ?? 'draft',
      progress: (json['progress'] ?? 0.0).toDouble(),
      progressMessage: json['progressMessage'],
      processing: json['processing'] as Map<String, dynamic>?,
      sourcePaletteId: json['sourcePaletteId'],
      narration: json['narration'] ?? json['storyText'], // Support both field names
      storyText: json['storyText'],
      usageGuide: (json['usageGuide'] as List? ?? [])
          .map((item) => ColorUsageGuideItem.fromJson(item))
          .toList(),
      audioUrl: json['audioUrl'],
      heroPrompt: json['heroPrompt'],
      access: json['access'] ?? 'private',
      fallbackHero: json['fallbackHero'],
      likeCount: json['likeCount'] ?? 0,
      playCount: json['playCount'] ?? 0,
      spotlight: json['spotlight'] ?? false,
      // Attribution metadata
      modelAttribution: AiAttribution.fromJson(json['modelAttribution']),
      heroImageAttribution: AiAttribution.fromJson(json['heroImageAttribution']),
      audioAttribution: AiAttribution.fromJson(json['audioAttribution']),
      // Enhanced wizard inputs
      styleTag: json['styleTag'],
      roomType: json['roomType'],
      vibeWords: json['vibeWords'] != null ? List<String>.from(json['vibeWords']) : null,
      brandHints: json['brandHints'] != null ? List<String>.from(json['brandHints']) : null,
      colors: json['colors'] != null ? List<String>.from(json['colors']) : null,
      paletteName: json['paletteName'],
      // Variant support
      variantOf: json['variantOf'],
      emphasis: json['emphasis'],
      vibeTweaks: json['vibeTweaks'] != null ? List<String>.from(json['vibeTweaks']) : null,
      // Generation metadata
      generationTimeMs: json['generationTimeMs'],
      version: json['version'],
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'userId': userId,
      'title': title,
      'slug': slug,
      'themes': themes,
      'families': families,
      'rooms': rooms,
      'tags': tags,
      'description': description,
      'isFeatured': isFeatured,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'palette': palette.map((item) => item.toJson()).toList(),
      'facets': facets,
      // AI-powered fields
      'status': status,
      'progress': progress,
      'usageGuide': usageGuide.map((item) => item.toJson()).toList(),
      'access': access,
      'fallbackHero': fallbackHero,
      'likeCount': likeCount,
      'playCount': playCount,
      'spotlight': spotlight,
    };

    // Add optional fields if they exist
    if (heroImageUrl != null) json['heroImageUrl'] = heroImageUrl;
    if (progressMessage != null) json['progressMessage'] = progressMessage;
    if (processing != null) json['processing'] = processing;
    if (sourcePaletteId != null) json['sourcePaletteId'] = sourcePaletteId;
    if (narration != null) json['narration'] = narration;
    if (storyText != null) json['storyText'] = storyText;
    if (audioUrl != null) json['audioUrl'] = audioUrl;
    if (heroPrompt != null) json['heroPrompt'] = heroPrompt;
    
    // Attribution metadata
    if (modelAttribution != null) json['modelAttribution'] = modelAttribution!.toJson();
    if (heroImageAttribution != null) json['heroImageAttribution'] = heroImageAttribution!.toJson();
    if (audioAttribution != null) json['audioAttribution'] = audioAttribution!.toJson();
    
    // Enhanced wizard inputs
    if (styleTag != null) json['styleTag'] = styleTag;
    if (roomType != null) json['roomType'] = roomType;
    if (vibeWords != null) json['vibeWords'] = vibeWords;
    if (brandHints != null) json['brandHints'] = brandHints;
    if (colors != null) json['colors'] = colors;
    if (paletteName != null) json['paletteName'] = paletteName;
    
    // Variant support
    if (variantOf != null) json['variantOf'] = variantOf;
    if (emphasis != null) json['emphasis'] = emphasis;
    if (vibeTweaks != null) json['vibeTweaks'] = vibeTweaks;
    
    // Generation metadata
    if (generationTimeMs != null) json['generationTimeMs'] = generationTimeMs;
    if (version != null) json['version'] = version;

    return json;
  }

  ColorStory copyWith({
    String? id,
    String? userId,
    String? title,
    String? slug,
    String? heroImageUrl,
    List<String>? themes,
    List<String>? families,
    List<String>? rooms,
    List<String>? tags,
    String? description,
    bool? isFeatured,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ColorStoryPalette>? palette,
    List<String>? facets,
    // AI-powered fields
    String? status,
    double? progress,
    String? progressMessage,
    String? sourcePaletteId,
    String? narration,
    String? storyText,
    List<ColorUsageGuideItem>? usageGuide,
    String? audioUrl,
    String? heroPrompt,
    String? access,
    String? fallbackHero,
    int? likeCount,
    int? playCount,
    // Attribution metadata
    AiAttribution? modelAttribution,
    AiAttribution? heroImageAttribution,
    AiAttribution? audioAttribution,
    // Enhanced wizard inputs
    String? styleTag,
    String? roomType,
    List<String>? vibeWords,
    List<String>? brandHints,
    List<String>? colors,
    String? paletteName,
    // Variant support
    String? variantOf,
    String? emphasis,
    List<String>? vibeTweaks,
    // Generation metadata
    int? generationTimeMs,
    String? version,
  }) {
    return ColorStory(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      slug: slug ?? this.slug,
      heroImageUrl: heroImageUrl ?? this.heroImageUrl,
      themes: themes ?? this.themes,
      families: families ?? this.families,
      rooms: rooms ?? this.rooms,
      tags: tags ?? this.tags,
      description: description ?? this.description,
      isFeatured: isFeatured ?? this.isFeatured,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      palette: palette ?? this.palette,
      facets: facets ?? this.facets,
      // AI-powered fields
      status: status ?? this.status,
      progress: progress ?? this.progress,
      progressMessage: progressMessage ?? this.progressMessage,
      sourcePaletteId: sourcePaletteId ?? this.sourcePaletteId,
      narration: narration ?? this.narration,
      storyText: storyText ?? this.storyText,
      usageGuide: usageGuide ?? this.usageGuide,
      audioUrl: audioUrl ?? this.audioUrl,
      heroPrompt: heroPrompt ?? this.heroPrompt,
      access: access ?? this.access,
      fallbackHero: fallbackHero ?? this.fallbackHero,
      likeCount: likeCount ?? this.likeCount,
      playCount: playCount ?? this.playCount,
      // Attribution metadata
      modelAttribution: modelAttribution ?? this.modelAttribution,
      heroImageAttribution: heroImageAttribution ?? this.heroImageAttribution,
      audioAttribution: audioAttribution ?? this.audioAttribution,
      // Enhanced wizard inputs
      styleTag: styleTag ?? this.styleTag,
      roomType: roomType ?? this.roomType,
      vibeWords: vibeWords ?? this.vibeWords,
      brandHints: brandHints ?? this.brandHints,
      colors: colors ?? this.colors,
      paletteName: paletteName ?? this.paletteName,
      // Variant support
      variantOf: variantOf ?? this.variantOf,
      emphasis: emphasis ?? this.emphasis,
      vibeTweaks: vibeTweaks ?? this.vibeTweaks,
      // Generation metadata
      generationTimeMs: generationTimeMs ?? this.generationTimeMs,
      version: version ?? this.version,
    );
  }
  
  /// Generate fallback hero from usage guide colors
  static String _generateFallbackFromUsageGuide(Map<String, dynamic> data) {
    final usageGuide = data['usageGuide'] as List<dynamic>? ?? [];
    final colors = <String>[];
    
    // Extract first two valid colors from usage guide
    for (final item in usageGuide) {
      if (item is Map<String, dynamic> && item['hex'] is String) {
        final hex = item['hex'] as String;
        if (hex.isNotEmpty && _isValidHex(hex)) {
          colors.add(hex);
          if (colors.length >= 2) break;
        }
      }
    }
    
    // Use default colors if not enough found
    if (colors.isEmpty) colors.add('#6366F1');
    if (colors.length == 1) colors.add('#8B5CF6');
    
    return _generateGradientDataUri(colors[0], colors[1]);
  }
  
  /// Validate hex color format
  static bool _isValidHex(String hex) {
    final cleanHex = hex.replaceAll('#', '');
    return RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(cleanHex);
  }
  
  /// Generate gradient SVG data URI
  static String _generateGradientDataUri(String colorA, String colorB) {
    final hexA = colorA.startsWith('#') ? colorA : '#$colorA';
    final hexB = colorB.startsWith('#') ? colorB : '#$colorB';
    
    final svgContent = '''<svg width="1200" height="800" xmlns="http://www.w3.org/2000/svg">
  <defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0%" stop-color="$hexA"/>
    <stop offset="100%" stop-color="$hexB"/>
  </linearGradient></defs>
  <rect width="100%" height="100%" fill="url(#g)"/>
</svg>''';
    
    final encoded = base64Encode(utf8.encode(svgContent));
    return 'data:image/svg+xml;base64,$encoded';
  }

  /// Builds facets array from themes, families, and rooms for efficient querying
  static List<String> buildFacets({
    required List<String> themes,
    required List<String> families,
    required List<String> rooms,
  }) {
    final facets = <String>[];
    
    // Add theme facets
    for (final theme in themes) {
      facets.add('theme:$theme');
    }
    
    // Add family facets
    for (final family in families) {
      facets.add('family:$family');
    }
    
    // Add room facets
    for (final room in rooms) {
      facets.add('room:$room');
    }
    
    return facets;
  }
}