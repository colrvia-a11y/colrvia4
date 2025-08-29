import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/utils/palette_generator.dart';

/// Arguments passed to the isolate. All data must be simple/serializable.
class _RollArgs {
  final List<Map<String, dynamic>> available; // Paint.toJson() + 'id'
  final List<Map<String, dynamic>?> anchors;  // nullable Paint maps
  final int modeIndex;
  final bool diversify;
  final List<List<double>>? slotLrvHints;

  _RollArgs({
    required this.available,
    required this.anchors,
    required this.modeIndex,
    required this.diversify,
    this.slotLrvHints,
  });

  Map<String, dynamic> toMap() => {
    'available': available,
    'anchors': anchors,
    'modeIndex': modeIndex,
    'diversify': diversify,
    'slotLrvHints': slotLrvHints,
  };

  static _RollArgs fromMap(Map<String, dynamic> m) => _RollArgs(
    available: List<Map<String, dynamic>>.from(m['available'] as List),
    anchors: List<Map<String, dynamic>?>.from(m['anchors'] as List),
    modeIndex: m['modeIndex'] as int,
    diversify: m['diversify'] as bool,
    slotLrvHints: m['slotLrvHints'] != null 
        ? List<List<double>>.from((m['slotLrvHints'] as List).map((e) => List<double>.from(e)))
        : null,
  );
}

/// Top-level function for compute(). Returns a List<Map> (Paint.toJson + id).
List<Map<String, dynamic>> rollPaletteInIsolate(Map<String, dynamic> raw) {
  final args = _RollArgs.fromMap(raw);

  // Rehydrate Paint objects inside the isolate
  final available = [
    for (final j in args.available)
      Paint.fromJson(j, j['id'] as String),
  ];
  final anchors = [
    for (final j in args.anchors)
      (j == null ? null : Paint.fromJson(j, j['id'] as String))
  ];

  final rolled = PaletteGenerator.rollPalette(
    availablePaints: available,
    anchors: anchors,
    mode: HarmonyMode.values[args.modeIndex],
    diversifyBrands: args.diversify,
    slotLrvHints: args.slotLrvHints,
  );

  // Send back serializable maps (we'll map to Paint on the main isolate)
  return [
    for (final p in rolled) (p.toJson()..['id'] = p.id),
  ];
}