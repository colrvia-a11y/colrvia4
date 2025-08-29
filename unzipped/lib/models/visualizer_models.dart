import 'package:flutter/material.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart' as models;

enum SurfaceType {
  leftWall, rightWall, backWall, ceiling, floor, trim, door, cabinet, backsplash, counter, sofa
}

enum Finish { matte, eggshell, satin, semiGloss }

class SurfaceSpec {
  final SurfaceType type;
  final String label;
  final List<Offset> polygon; // normalized to a reference canvas size
  const SurfaceSpec({required this.type, required this.label, required this.polygon});
}

class SurfaceState {
  final models.Paint? paint;
  final Finish finish;
  const SurfaceState({this.paint, this.finish = Finish.eggshell});

  SurfaceState copyWith({models.Paint? paint, Finish? finish}) =>
      SurfaceState(paint: paint ?? this.paint, finish: finish ?? this.finish);

  Map<String, dynamic> toJson() => {
    'paintId': paint?.id,
    'finish': finish.name,
  };
  static SurfaceState fromJson(Map<String, dynamic>? json, Map<String, models.Paint> paintMapById) {
    if (json == null) return const SurfaceState();
    final fid = json['finish'] as String? ?? 'eggshell';
    final pid = json['paintId'] as String?;
    return SurfaceState(
      paint: pid != null ? paintMapById[pid] : null,
      finish: Finish.values.firstWhere((f) => f.name == fid, orElse: () => Finish.eggshell),
    );
  }
}

class RoomTemplate {
  final String id;
  final String name;
  final Size referenceSize; // the polygon coordinates are relative to this
  final List<SurfaceSpec> surfaces;
  const RoomTemplate({required this.id, required this.name, required this.referenceSize, required this.surfaces});
}

/// --- Example templates (keep polygons simple & tappable) ---
const Size _ref = Size(1000, 600);

final RoomTemplate livingRoomTemplate = RoomTemplate(
  id: 'living_room',
  name: 'Living Room',
  referenceSize: _ref,
  surfaces: [
    // backWall
    SurfaceSpec(
      type: SurfaceType.backWall,
      label: 'Back Wall',
      polygon: [
        Offset(50, 80), Offset(950, 80), Offset(900, 320), Offset(100, 320),
      ],
    ),
    // leftWall (slanted)
    SurfaceSpec(
      type: SurfaceType.leftWall,
      label: 'Left Wall',
      polygon: [
        Offset(50, 80), Offset(100, 320), Offset(100, 520), Offset(50, 360),
      ],
    ),
    // rightWall (slanted)
    SurfaceSpec(
      type: SurfaceType.rightWall,
      label: 'Right Wall',
      polygon: [
        Offset(950, 80), Offset(900, 320), Offset(900, 520), Offset(950, 360),
      ],
    ),
    // ceiling
    SurfaceSpec(
      type: SurfaceType.ceiling,
      label: 'Ceiling',
      polygon: [
        Offset(50, 80), Offset(950, 80), Offset(900, 60), Offset(100, 60),
      ],
    ),
    // floor
    SurfaceSpec(
      type: SurfaceType.floor,
      label: 'Floor',
      polygon: [
        Offset(100, 320), Offset(900, 320), Offset(900, 520), Offset(100, 520),
      ],
    ),
    // trim (as a thin inset band on back wall)
    SurfaceSpec(
      type: SurfaceType.trim,
      label: 'Trim',
      polygon: [
        Offset(100, 310), Offset(900, 310), Offset(890, 300), Offset(110, 300),
      ],
    ),
    // sofa (accent object)
    SurfaceSpec(
      type: SurfaceType.sofa,
      label: 'Sofa',
      polygon: [
        Offset(250, 400), Offset(750, 400), Offset(720, 470), Offset(280, 470),
      ],
    ),
  ],
);

final RoomTemplate bedroomTemplate = RoomTemplate(
  id: 'bedroom',
  name: 'Bedroom',
  referenceSize: _ref,
  surfaces: [
    SurfaceSpec(
      type: SurfaceType.backWall,
      label: 'Back Wall',
      polygon: [Offset(80, 100), Offset(920, 100), Offset(900, 360), Offset(100, 360)],
    ),
    SurfaceSpec(
      type: SurfaceType.ceiling,
      label: 'Ceiling',
      polygon: [Offset(80, 100), Offset(920, 100), Offset(880, 80), Offset(120, 80)],
    ),
    SurfaceSpec(
      type: SurfaceType.floor,
      label: 'Floor',
      polygon: [Offset(100, 360), Offset(900, 360), Offset(900, 520), Offset(100, 520)],
    ),
    SurfaceSpec(
      type: SurfaceType.trim,
      label: 'Trim',
      polygon: [Offset(100, 350), Offset(900, 350), Offset(890, 340), Offset(110, 340)],
    ),
    SurfaceSpec(
      type: SurfaceType.leftWall,
      label: 'Left Wall',
      polygon: [Offset(80, 100), Offset(100, 360), Offset(100, 520), Offset(80, 360)],
    ),
    SurfaceSpec(
      type: SurfaceType.rightWall,
      label: 'Right Wall',
      polygon: [Offset(920, 100), Offset(900, 360), Offset(900, 520), Offset(920, 360)],
    ),
  ],
);

final Map<String, RoomTemplate> kRoomTemplates = {
  'living_room': livingRoomTemplate,
  'bedroom': bedroomTemplate,
  // add kitchen, bathroom later by copying the pattern
};