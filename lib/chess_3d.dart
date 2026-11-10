import 'package:flutter_cube/flutter_cube.dart';

/// Shareable vertex/index data for one piece part (body or trim). Two Mesh
/// wrappers (e.g. white/black) can point at the same lists with different
/// Material, so the geometry itself is only decoded from disk once.
class _Geometry {
  final List<Vector3> vertices;
  final List<Polygon> indices;
  _Geometry(this.vertices, this.indices);
  Mesh toMesh(Material material) => Mesh(vertices: vertices, indices: indices, material: material);
}

/// A simple box from y=0 (base) up to y=height, centered on X/Z. Used for
/// the board tiles and highlight markers (the pieces themselves are now
/// real 3D models, loaded separately — see [preloadPieces]).
_Geometry _box(double width, double height, double depth) {
  final hx = width / 2, hz = depth / 2;
  final vertices = <Vector3>[
    Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(hx, 0, hz), Vector3(-hx, 0, hz),
    Vector3(-hx, height, -hz), Vector3(hx, height, -hz), Vector3(hx, height, hz), Vector3(-hx, height, hz),
  ];
  final indices = <Polygon>[
    Polygon(0, 1, 2), Polygon(0, 2, 3),
    Polygon(4, 6, 5), Polygon(4, 7, 6),
    Polygon(0, 5, 1), Polygon(0, 4, 5),
    Polygon(1, 6, 2), Polygon(1, 5, 6),
    Polygon(2, 7, 3), Polygon(2, 6, 7),
    Polygon(3, 4, 0), Polygon(3, 7, 4),
  ];
  return _Geometry(vertices, indices);
}

final Map<String, _Geometry> _tileGeometryCache = {};

_Geometry _tileGeometryFor(String key) {
  return _tileGeometryCache.putIfAbsent(key, () {
    switch (key) {
      case 'tile':
        return _box(1.0, 0.05, 1.0);
      case 'marker':
        return _box(0.94, 0.02, 0.94);
      default:
        return _box(1.0, 0.05, 1.0);
    }
  });
}

// --- Real 3D piece models -------------------------------------------------
//
// The six piece shapes (pawn/rook/knight/bishop/queen/king) are loaded once
// from .obj files bundled as Flutter assets — see preloadPieces(). Each
// piece has a "body" part (main color) and a "trim" part (the gold/copper
// decorative detail), extracted from a CC-Attribution model by Verfassen
// (sketchfab.com/3d-models/chess-e54c2d04d4f74823b69ba4a794fb4500).
//
// IMPORTANT — CC Attribution requires crediting the creator somewhere in
// the app (e.g. a Credits/About screen): "Chess" by Verfassen, licensed
// under CC Attribution (creativecommons.org/licenses/by/4.0/).

const List<String> _pieceTypeNames = ['pawn', 'rook', 'knight', 'bishop', 'queen', 'king'];

/// Uniform scale applied to every loaded piece so a king stands roughly one
/// board-square tall. Adjust this single number if pieces look too big or
/// too small relative to the board.
const double pieceModelScale = 0.115;

final Map<String, _Geometry> _loadedGeometries = {};
bool _piecesLoaded = false;
bool get piecesLoaded => _piecesLoaded;

/// Loads all 12 piece OBJ files (6 types x body/trim) exactly once. Safe to
/// call multiple times — later calls are a no-op once loading has finished.
/// Must be awaited before [buildPieceObject3D] will return fully-shaped
/// pieces; before that, it returns an empty placeholder object. A failure
/// loading any single file is caught and logged (via debugPrint, visible in
/// `flutter run`'s terminal output) rather than left to hang the whole
/// batch forever — the other files still load normally.
Future<void> preloadPieces() async {
  if (_piecesLoaded) return;
  for (final name in _pieceTypeNames) {
    await _loadPart('${name}_body', 'assets/models3d/${name}_body.obj');
  }
  _piecesLoaded = true;
  print('[chess3d] preload finished: ${_loadedGeometries.length}/6 parts loaded');
}

Future<void> _loadPart(String key, String assetPath) async {
  try {
    // normalized=false: we already recentered these files ourselves and want
    // to keep their real relative sizes (flutter_cube's own normalization
    // would independently rescale each file to the same bounding size,
    // which would make a pawn and a king end up the same height).
    final meshes = await loadObj(assetPath, false);
    if (meshes.isNotEmpty) {
      _loadedGeometries[key] = _Geometry(meshes[0].vertices, meshes[0].indices);
      print('[chess3d] loaded $key from $assetPath (${meshes[0].vertices.length} verts)');
    } else {
      print('[chess3d] WARNING: $assetPath parsed but produced 0 meshes');
    }
  } catch (e) {
    print('[chess3d] ERROR loading $assetPath: $e');
  }
}

/// Warm, visible body colors — a light warm gray for "white" and a true
/// black (with enough ambient to still read as a solid shape, not a void)
/// for "black", independent of the source model's raw material values.
Material _pieceMaterial(bool isWhite) {
  final m = Material();
  if (isWhite) {
    m.ambient = Vector3(0.78, 0.72, 0.58);
    m.diffuse = Vector3(0.97, 0.91, 0.75);
    m.specular = Vector3(0.45, 0.42, 0.35);
    m.shininess = 32;
  } else {
    m.ambient = Vector3(0.09, 0.09, 0.10);
    m.diffuse = Vector3(0.14, 0.13, 0.14);
    m.specular = Vector3(0.55, 0.55, 0.55);
    m.shininess = 40;
  }
  m.opacity = 1.0;
  return m;
}

/// The model pairs copper trim with white pieces and gold trim with black
/// pieces. Both get a strong specular highlight to read as metallic.
Material _trimMaterial(bool isWhite) {
  final m = Material();
  if (isWhite) {
    // copper
    m.ambient = Vector3(0.55, 0.30, 0.14);
    m.diffuse = Vector3(0.82, 0.48, 0.22);
    m.specular = Vector3(0.55, 0.40, 0.25);
    m.shininess = 45;
  } else {
    // gold
    m.ambient = Vector3(0.58, 0.38, 0.12);
    m.diffuse = Vector3(0.85, 0.58, 0.20);
    m.specular = Vector3(0.60, 0.48, 0.28);
    m.shininess = 45;
  }
  m.opacity = 1.0;
  return m;
}

/// Builds the 3D Objects for a FEN piece character (uppercase = white,
/// lowercase = black; p/r/n/b/q/k) as a flat list of siblings — a body
/// object and, if available, a trim object — rather than a parent/child
/// pair. Each one carries its own scale directly, so the caller just needs
/// to set the SAME position on every object in the list and add them all
/// to the scene. Returns a single empty placeholder if called before
/// [preloadPieces] has finished.
///
/// NOTE: the "trim" (gold/copper decorative) geometry is intentionally not
/// rendered. Across several different approaches (scaled as a child of the
/// body, scaled as an independent sibling, loaded sequentially instead of
/// concurrently) it consistently rendered as a huge, chaotic shape, while
/// the body geometry alone has always rendered correctly. Body-only pieces
/// are a solid, reliable result; the trim bug can be revisited later.
List<Object> buildPieceObject3D(String fenChar) {
  final isWhite = fenChar == fenChar.toUpperCase();
  final type = fenChar.toLowerCase();
  final typeName = const {
    'p': 'pawn',
    'r': 'rook',
    'n': 'knight',
    'b': 'bishop',
    'q': 'queen',
    'k': 'king',
  }[type]!;

  final bodyGeo = _loadedGeometries['${typeName}_body'];
  final result = <Object>[];
  final s = pieceModelScale;

  result.add(Object(
    mesh: bodyGeo?.toMesh(_pieceMaterial(isWhite)) ?? Mesh(),
    lighting: true,
    backfaceCulling: false,
    scale: Vector3(s, s, s),
  ));
  return result;
}

/// A flat square tile for the board, `light` selects the ivory/walnut tone.
Object buildSquareObject3D({required bool light}) {
  return Object(
    mesh: _tileGeometryFor('tile').toMesh(_squareMaterial(light: light)),
    lighting: true,
    backfaceCulling: false,
  );
}

/// Honey-tan light squares, reddish-walnut dark squares.
Material _squareMaterial({required bool light}) {
  final m = Material();
  if (light) {
    m.ambient = Vector3(0.68, 0.60, 0.46);
    m.diffuse = Vector3(0.92, 0.84, 0.66);
  } else {
    m.ambient = Vector3(0.34, 0.18, 0.11);
    m.diffuse = Vector3(0.52, 0.27, 0.15);
  }
  m.specular = Vector3(0.08, 0.06, 0.05);
  m.shininess = 6;
  return m;
}

/// A thin, flat, semi-transparent colored plate used for the selected /
/// last-move / hint square highlights.
Object buildMarkerObject3D(Vector3 rgb, {double opacity = 0.55}) {
  final m = Material();
  m.ambient = rgb;
  m.diffuse = rgb;
  m.specular = Vector3.zero();
  m.shininess = 1;
  m.opacity = opacity;
  return Object(
    mesh: _tileGeometryFor('marker').toMesh(m),
    lighting: true,
    backfaceCulling: false,
  );
}
