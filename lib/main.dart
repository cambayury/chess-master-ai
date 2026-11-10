import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart' hide Color;
import 'package:google_fonts/google_fonts.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:stockfish/stockfish.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:chess/chess.dart' as chess;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cube/flutter_cube.dart' as cube;
import 'chess_3d.dart' as c3d;

const String revenueCatApiKey = 'goog_EIqZElBewdCEdpveIGnGJFaTUQm';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Purchases.setLogLevel(LogLevel.debug);
  await Purchases.configure(PurchasesConfiguration(revenueCatApiKey));
  runApp(const ChessMasterApp());
}

class ChessMasterApp extends StatelessWidget {
  const ChessMasterApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chess Master AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20),
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

enum Difficulty { easy, medium, hard, master }

extension DifficultyExtension on Difficulty {
  String get label {
    switch (this) {
      case Difficulty.easy: return 'Easy';
      case Difficulty.medium: return 'Medium';
      case Difficulty.hard: return 'Hard';
      case Difficulty.master: return 'Master ⭐';
    }
  }
  int get skillLevel {
    switch (this) {
      case Difficulty.easy: return 3;
      case Difficulty.medium: return 10;
      case Difficulty.hard: return 15;
      case Difficulty.master: return 20;
    }
  }
  int get moveTime {
    switch (this) {
      case Difficulty.easy: return 100;
      case Difficulty.medium: return 500;
      case Difficulty.hard: return 1000;
      case Difficulty.master: return 3000;
    }
  }
  Color get color {
    switch (this) {
      case Difficulty.easy: return const Color(0xFF4CAF50);
      case Difficulty.medium: return const Color(0xFF2196F3);
      case Difficulty.hard: return const Color(0xFFFF9800);
      case Difficulty.master: return const Color(0xFFFFD700);
    }
  }
  String get rating {
    switch (this) {
      case Difficulty.easy: return '800';
      case Difficulty.medium: return '1500';
      case Difficulty.hard: return '2200';
      case Difficulty.master: return '3600';
    }
  }
  bool get requiresPremium => this == Difficulty.master;
}

const List<Map<String, dynamic>> timeOptions = [
  {'label': '1 min', 'seconds': 60},
  {'label': '2 min', 'seconds': 120},
  {'label': '3 min', 'seconds': 180},
  {'label': '5 min', 'seconds': 300},
  {'label': '10 min', 'seconds': 600},
  {'label': '15 min', 'seconds': 900},
  {'label': '30 min', 'seconds': 1800},
  {'label': '1 hora', 'seconds': 3600},
];

const List<Map<String, String>> musicTracks = [
  {'id': 'classic', 'label': 'Classic', 'file': 'sounds/background.mp3'},
  {'id': 'redwood', 'label': 'Redwood', 'file': 'sounds/background2.mp3'},
  {'id': 'firsttime', 'label': 'First Time', 'file': 'sounds/background3.mp3'},
  {'id': 'singlestep', 'label': 'Single Step', 'file': 'sounds/background4.mp3'},
];

const String musicPrefKey = 'selected_music_id';
const String boardThemePrefKey = 'selected_board_theme';
const String pieceThemePrefKey = 'selected_piece_theme';

/// Unicode glyphs for each FEN piece character. Uppercase FEN letters are
/// White's pieces (outline glyphs), lowercase are Black's (solid glyphs).
/// Used by the custom board renderer so piece color can be set freely,
/// independent of whatever glyph shape is drawn.
const Map<String, String> chessPieceGlyphs = {
  'K': '♔', 'Q': '♕', 'R': '♖', 'B': '♗', 'N': '♘', 'P': '♙',
  'k': '♚', 'q': '♛', 'r': '♜', 'b': '♝', 'n': '♞', 'p': '♟',
};

/// Maps a FEN piece letter (case-insensitive) to the matching asset file
/// name under assets/pieces/ (e.g. 'Q' and 'q' both use queen.png - the
/// same artwork is tinted a different color per side at render time).
const Map<String, String> chessPieceAssetNames = {
  'k': 'king', 'q': 'queen', 'r': 'rook', 'b': 'bishop', 'n': 'knight', 'p': 'pawn',
};

/// Degrees to rotate a given piece's artwork to counteract a tilt baked
/// into the source image itself. Empty for now - the replacement king and
/// queen images are already upright, so no correction is needed. If a
/// future piece image needs straightening, add an entry here (e.g.
/// 'bishop': -5.0) and hot-reload (press 'r' in the flutter run terminal)
/// to tune it without a rebuild.
const Map<String, double> chessPieceRotationDegrees = {};

enum BoardTheme { clasico, azul, verde, nocturno }

extension BoardThemeExtension on BoardTheme {
  String get label {
    switch (this) {
      case BoardTheme.clasico: return 'Clasico';
      case BoardTheme.azul: return 'Azul';
      case BoardTheme.verde: return 'Verde';
      case BoardTheme.nocturno: return 'Nocturno';
    }
  }
  Color get lightSquare {
    switch (this) {
      case BoardTheme.clasico: return const Color(0xFFEEEED2);
      case BoardTheme.azul: return const Color(0xFFD6DFE8);
      case BoardTheme.verde: return const Color(0xFFEDEED3);
      case BoardTheme.nocturno: return const Color(0xFF54545E);
    }
  }
  Color get darkSquare {
    switch (this) {
      case BoardTheme.clasico: return const Color(0xFF769656);
      case BoardTheme.azul: return const Color(0xFF2E6DA4);
      case BoardTheme.verde: return const Color(0xFF4B7F52);
      case BoardTheme.nocturno: return const Color(0xFF202024);
    }
  }
}

enum PieceTheme { blancoNegro, doradoPlata, turquesaCoral, neon }

extension PieceThemeExtension on PieceTheme {
  String get label {
    switch (this) {
      case PieceTheme.blancoNegro: return 'Blanco / Negro';
      case PieceTheme.doradoPlata: return 'Dorado / Plata';
      case PieceTheme.turquesaCoral: return 'Turquesa / Coral';
      case PieceTheme.neon: return 'Neon';
    }
  }
  Color get whiteColor {
    switch (this) {
      case PieceTheme.blancoNegro: return Colors.white;
      case PieceTheme.doradoPlata: return const Color(0xFFD4AF37);
      case PieceTheme.turquesaCoral: return const Color(0xFF2DD4BF);
      case PieceTheme.neon: return const Color(0xFF38BDF8);
    }
  }
  Color get blackColor {
    switch (this) {
      case PieceTheme.blancoNegro: return const Color(0xFF1A1A1A);
      case PieceTheme.doradoPlata: return const Color(0xFF9AA0A6);
      case PieceTheme.turquesaCoral: return const Color(0xFFFB7185);
      case PieceTheme.neon: return const Color(0xFFF43F5E);
    }
  }
}

/// A lightweight openings book covering the most common openings and
/// defenses amateur players encounter. Each entry's `moves` list is the
/// exact SAN move sequence (in order) that identifies that opening. When
/// matching, the longest matching prefix of the game's move history wins,
/// so more specific lines (e.g. Italian Game) override broader ones
/// (e.g. King's Pawn Opening) once enough moves have been played.
const List<Map<String, dynamic>> openingsDatabase = [
  {'name': "King's Pawn Opening", 'moves': ['e4']},
  {'name': "Queen's Pawn Opening", 'moves': ['d4']},
  {'name': 'English Opening', 'moves': ['c4']},
  {'name': 'Réti Opening', 'moves': ['Nf3']},
  {'name': "Bird's Opening", 'moves': ['f4']},
  {'name': 'Ruy Lopez (Spanish Opening)', 'moves': ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5']},
  {'name': 'Italian Game', 'moves': ['e4', 'e5', 'Nf3', 'Nc6', 'Bc4']},
  {'name': 'Giuoco Piano', 'moves': ['e4', 'e5', 'Nf3', 'Nc6', 'Bc4', 'Bc5']},
  {'name': 'Two Knights Defense', 'moves': ['e4', 'e5', 'Nf3', 'Nc6', 'Bc4', 'Nf6']},
  {'name': 'Evans Gambit', 'moves': ['e4', 'e5', 'Nf3', 'Nc6', 'Bc4', 'Bc5', 'b4']},
  {'name': 'Scotch Game', 'moves': ['e4', 'e5', 'Nf3', 'Nc6', 'd4']},
  {'name': 'Four Knights Game', 'moves': ['e4', 'e5', 'Nf3', 'Nc6', 'Nc3', 'Nf6']},
  {'name': "Petrov's Defense", 'moves': ['e4', 'e5', 'Nf3', 'Nf6']},
  {'name': 'Philidor Defense', 'moves': ['e4', 'e5', 'Nf3', 'd6']},
  {'name': "King's Gambit", 'moves': ['e4', 'e5', 'f4']},
  {'name': 'Vienna Game', 'moves': ['e4', 'e5', 'Nc3']},
  {'name': 'Center Game', 'moves': ['e4', 'e5', 'd4']},
  {'name': 'Danish Gambit', 'moves': ['e4', 'e5', 'd4', 'exd4', 'c3']},
  {'name': "Bishop's Opening", 'moves': ['e4', 'e5', 'Bc4']},
  {'name': 'Sicilian Defense', 'moves': ['e4', 'c5']},
  {'name': 'French Defense', 'moves': ['e4', 'e6']},
  {'name': 'Caro-Kann Defense', 'moves': ['e4', 'c6']},
  {'name': 'Pirc Defense', 'moves': ['e4', 'd6']},
  {'name': 'Modern Defense', 'moves': ['e4', 'g6']},
  {'name': "Alekhine's Defense", 'moves': ['e4', 'Nf6']},
  {'name': 'Scandinavian Defense', 'moves': ['e4', 'd5']},
  {'name': 'Nimzowitsch Defense', 'moves': ['e4', 'Nc6']},
  {'name': "Queen's Gambit", 'moves': ['d4', 'd5', 'c4']},
  {'name': "Queen's Gambit Declined", 'moves': ['d4', 'd5', 'c4', 'e6']},
  {'name': "Queen's Gambit Accepted", 'moves': ['d4', 'd5', 'c4', 'dxc4']},
  {'name': 'Slav Defense', 'moves': ['d4', 'd5', 'c4', 'c6']},
  {'name': "King's Indian Defense", 'moves': ['d4', 'Nf6', 'c4', 'g6']},
  {'name': 'Nimzo-Indian Defense', 'moves': ['d4', 'Nf6', 'c4', 'e6', 'Nc3', 'Bb4']},
  {'name': "Queen's Indian Defense", 'moves': ['d4', 'Nf6', 'c4', 'e6', 'Nf3', 'b6']},
  {'name': 'Grünfeld Defense', 'moves': ['d4', 'Nf6', 'c4', 'g6', 'Nc3', 'd5']},
  {'name': 'Bogo-Indian Defense', 'moves': ['d4', 'Nf6', 'c4', 'e6', 'Nf3', 'Bb4+']},
  {'name': 'Catalan Opening', 'moves': ['d4', 'Nf6', 'c4', 'e6', 'g3']},
  {'name': 'Dutch Defense', 'moves': ['d4', 'f5']},
  {'name': 'Benoni Defense', 'moves': ['d4', 'Nf6', 'c4', 'c5']},
  {'name': 'Budapest Gambit', 'moves': ['d4', 'Nf6', 'c4', 'e5']},
  {'name': 'London System', 'moves': ['d4', 'd5', 'Nf3', 'Nf6', 'Bf4']},
  {'name': 'Trompowsky Attack', 'moves': ['d4', 'Nf6', 'Bg5']},
  {'name': 'English Opening: Symmetrical', 'moves': ['c4', 'c5']},
  {'name': 'English Opening: Reversed Sicilian', 'moves': ['c4', 'e5']},
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isPremium = false;
  Difficulty _selectedDifficulty = Difficulty.medium;
  int _selectedTimeIndex = 4;
  final AudioPlayer _bgMusic = AudioPlayer();
  String _selectedMusicId = 'classic';
  BoardTheme _selectedBoardTheme = BoardTheme.azul;
  PieceTheme _selectedPieceTheme = PieceTheme.blancoNegro;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _checkPremium();
    _initMusic();
    _loadThemePrefs();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = 'Version ${info.version}';
    });
  }

  Future<void> _initMusic() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedMusicId = prefs.getString(musicPrefKey) ?? 'classic';
    });
    _playBackgroundMusic();
  }

  Future<void> _loadThemePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBoard = prefs.getString(boardThemePrefKey);
    final savedPiece = prefs.getString(pieceThemePrefKey);
    setState(() {
      _selectedBoardTheme = BoardTheme.values.firstWhere(
        (t) => t.name == savedBoard,
        orElse: () => BoardTheme.azul,
      );
      _selectedPieceTheme = PieceTheme.values.firstWhere(
        (t) => t.name == savedPiece,
        orElse: () => PieceTheme.blancoNegro,
      );
    });
  }

  Future<void> _saveThemePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(boardThemePrefKey, _selectedBoardTheme.name);
    await prefs.setString(pieceThemePrefKey, _selectedPieceTheme.name);
  }

  Future<void> _checkPremium() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      setState(() {
        _isPremium = customerInfo.entitlements.active.containsKey('Premium');
      });
    } catch (e) {
      debugPrint('Error checking premium: $e');
    }
  }

  Future<void> _purchasePremium() async {
    try {
      final offerings = await Purchases.getOfferings();
      final offering = offerings.current;
      if (offering == null || offering.availablePackages.isEmpty) {
        debugPrint('No RevenueCat offering/package available for purchase.');
        return;
      }
      final package = offering.availablePackages.first;
      final purchaseResult = await Purchases.purchasePackage(package);
      if (purchaseResult.customerInfo.entitlements.active.containsKey('Premium')) {
        setState(() => _isPremium = true);
      }
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('Purchase error: $e');
      }
    } catch (e) {
      debugPrint('Purchase error: $e');
    }
  }

  Future<void> _playBackgroundMusic() async {
    if (_selectedMusicId == 'off') {
      await _bgMusic.stop();
      return;
    }
    try {
      final track = musicTracks.firstWhere(
        (t) => t['id'] == _selectedMusicId,
        orElse: () => musicTracks.first,
      );
      await _bgMusic.setReleaseMode(ReleaseMode.loop);
      await _bgMusic.play(AssetSource(track['file']!));
    } catch (e) {
      debugPrint('Music error: $e');
    }
  }

  Future<void> _selectMusic(String musicId) async {
    setState(() => _selectedMusicId = musicId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(musicPrefKey, musicId);
    await _bgMusic.stop();
    _playBackgroundMusic();
  }

  void _showMusicPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Background Music',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...musicTracks.map((track) => _musicOption(track['label']!, track['id']!)),
            _musicOption('Off', 'off', icon: Icons.music_off),
          ],
        ),
      ),
    );
  }

  Widget _musicOption(String label, String id, {IconData icon = Icons.music_note}) {
    final isSelected = _selectedMusicId == id;
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _selectMusic(id);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4CAF50) : const Color(0xFF0F3460),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF4CAF50) : Colors.white24,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(label,
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.w500, fontSize: 15)),
            const Spacer(),
            if (isSelected) const Icon(Icons.check, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  void _showThemePicker() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF16213E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Personalizar tablero',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Tablero',
                      style: GoogleFonts.poppins(
                          color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: BoardTheme.values.map((t) {
                      return _boardThemeSwatch(
                        theme: t,
                        isSelected: _selectedBoardTheme == t,
                        onTap: () => setDialogState(() => _selectedBoardTheme = t),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 22),
                  Text('Piezas',
                      style: GoogleFonts.poppins(
                          color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: PieceTheme.values.map((t) {
                      return _pieceThemeSwatch(
                        theme: t,
                        isSelected: _selectedPieceTheme == t,
                        onTap: () => setDialogState(() => _selectedPieceTheme = t),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {});
                  _saveThemePrefs();
                },
                child: Text('Guardar',
                    style: GoogleFonts.poppins(
                        color: const Color(0xFF4CAF50), fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _boardThemeSwatch({
    required BoardTheme theme,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? const Color(0xFF4CAF50) : Colors.white24,
                width: isSelected ? 3 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Column(
                children: List.generate(4, (row) {
                  return Expanded(
                    child: Row(
                      children: List.generate(4, (col) {
                        final isLight = (row + col) % 2 == 0;
                        return Expanded(
                          child: Container(
                            color: isLight ? theme.lightSquare : theme.darkSquare,
                          ),
                        );
                      }),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 64,
            child: Text(
              theme.label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  /// A small custom "paint palette" icon with genuinely different-colored
  /// dots, used for the theme picker button. Flutter's built-in
  /// Icons.palette draws its dots as transparent holes in a single-color
  /// glyph, so a plain Icon() can't give them separate colors - this
  /// builds the shape ourselves instead.
  Widget _paletteIcon() {
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 22,
            height: 18,
            decoration: BoxDecoration(
              color: Colors.white70,
              borderRadius: BorderRadius.circular(11),
            ),
          ),
          Positioned(left: 2, top: 2, child: _paletteDot(const Color(0xFFEF5350))),
          Positioned(right: 2, top: 2, child: _paletteDot(const Color(0xFF42A5F5))),
          Positioned(left: 6, bottom: 1, child: _paletteDot(const Color(0xFFFFCA28))),
          Positioned(right: 6, bottom: 1, child: _paletteDot(const Color(0xFF66BB6A))),
        ],
      ),
    );
  }

  Widget _paletteDot(Color color) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Widget _pieceThemeSwatch({
    required PieceTheme theme,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFB8C4D0),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? const Color(0xFF4CAF50) : Colors.white24,
                width: isSelected ? 3 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(theme.whiteColor, BlendMode.srcIn),
                    child: Image.asset('assets/pieces/king.png', fit: BoxFit.contain),
                  ),
                ),
                Expanded(
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(theme.blackColor, BlendMode.srcIn),
                    child: Image.asset('assets/pieces/king.png', fit: BoxFit.contain),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 64,
            child: Text(
              theme.label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Choose Your Color',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _colorOption('♔', 'White', Colors.white, Colors.black, PlayerColor.white),
            _colorOption('🎲', 'Random', null, Colors.white, null),
            _colorOption('♚', 'Black', const Color(0xFF1A1A1A), Colors.white, PlayerColor.black),
          ],
        ),
      ),
    );
  }

  Widget _colorOption(String symbol, String label, Color? bg, Color textColor, PlayerColor? color) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _bgMusic.stop();
        final playerColor = color ?? (DateTime.now().millisecondsSinceEpoch % 2 == 0
            ? PlayerColor.white
            : PlayerColor.black);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GameScreen(
              difficulty: _selectedDifficulty,
              timeSeconds: timeOptions[_selectedTimeIndex]['seconds'],
              playerColor: playerColor,
              boardTheme: _selectedBoardTheme,
              pieceTheme: _selectedPieceTheme,
            ),
          ),
        ).then((_) => _playBackgroundMusic());
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          gradient: bg == null ? const LinearGradient(
            colors: [Colors.white, Colors.black],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ) : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white54, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(symbol, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 6),
            Text(label, style: GoogleFonts.poppins(
              color: textColor, fontWeight: FontWeight.bold, fontSize: 12,
              shadows: bg == null ? const [Shadow(color: Colors.black, blurRadius: 4)] : null,
            )),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bgMusic.stop();
    _bgMusic.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.info_outline, color: Colors.white70),
                        tooltip: 'About & licenses',
                        onPressed: () async {
                          final info = await PackageInfo.fromPlatform();
                          if (!context.mounted) return;
                          Widget link(String label, String url) => TextButton.icon(
                                icon: const Icon(Icons.open_in_new, size: 18),
                                label: Text(label),
                                onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                              );
                          showAboutDialog(
                            context: context,
                            applicationName: 'Chess Master AI',
                            applicationVersion: '${info.version} (${info.buildNumber})',
                            applicationLegalese: '\u00A9 2026 Yury Camba (Camba Technology)\n\n'
                                'Chess Master AI is free software: you can redistribute it and/or modify it '
                                'under the terms of the GNU General Public License, version 3. '
                                'It comes with ABSOLUTELY NO WARRANTY.\n\n'
                                'It includes the Stockfish chess engine, also licensed under the GPLv3.',
                            children: [
                              const SizedBox(height: 12),
                              link('Source code', 'https://github.com/cambayury/chess-master-ai'),
                              link('GNU GPLv3 license', 'https://www.gnu.org/licenses/gpl-3.0.html'),
                              link('Stockfish', 'https://github.com/official-stockfish/Stockfish'),
                              link('Terms of Service', 'https://yurycamba.com/chess-master-ai-terms'),
                            ],
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          _selectedMusicId == 'off' ? Icons.music_off : Icons.music_note,
                          color: Colors.white70,
                        ),
                        tooltip: 'Background music',
                        onPressed: _showMusicPicker,
                      ),
                      IconButton(
                        icon: _paletteIcon(),
                        tooltip: 'Personalizar tablero',
                        onPressed: _showThemePicker,
                      ),
                    ],
                  ),
                ),
                Image.asset('assets/images/queen.png', width: 100, height: 100),
                const SizedBox(height: 10),
                Text('Chess Master AI',
                    style: GoogleFonts.poppins(
                        fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                Text('Powered by Stockfish',
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.white54)),
                if (_isPremium) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('⭐ PREMIUM',
                        style: GoogleFonts.poppins(
                            fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
                  ),
                ],
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Text('Difficulty',
                          style: GoogleFonts.poppins(
                              fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Row(
                        children: Difficulty.values.map((d) {
                          final isSelected = _selectedDifficulty == d;
                          final isLocked = d.requiresPremium && !_isPremium;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                if (isLocked) {
                                  _purchasePremium();
                                } else {
                                  setState(() => _selectedDifficulty = d);
                                }
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? d.color : const Color(0xFF16213E),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected ? d.color : Colors.white24,
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    if (isLocked)
                                      const Icon(Icons.lock, color: Colors.white54, size: 14),
                                    Text(d.label,
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.poppins(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected ? Colors.white : Colors.white54)),
                                    Text('~${d.rating}',
                                        style: GoogleFonts.poppins(
                                            fontSize: 9, color: Colors.white38)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Text('Time per player',
                          style: GoogleFonts.poppins(
                              fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16213E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedTimeIndex,
                            dropdownColor: const Color(0xFF16213E),
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
                            onChanged: (val) => setState(() => _selectedTimeIndex = val!),
                            items: List.generate(timeOptions.length, (i) {
                              return DropdownMenuItem(
                                value: i,
                                child: Text(
                                  timeOptions[i]['label'],
                                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: ElevatedButton(
                    onPressed: _showColorPicker,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.play_arrow, size: 24),
                        const SizedBox(width: 12),
                        Text('Play vs AI',
                            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: ElevatedButton(
                    onPressed: _isPremium ? () {} : _purchasePremium,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star, size: 24),
                        const SizedBox(width: 12),
                        Text(_isPremium ? 'Premium ✓' : 'Get Premium - \$4.99/month',
                            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(_appVersion,
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.white30)),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One candidate-move arrow to draw on the board: a line with an
/// arrowhead from one square's center to another's.
class _ArrowSpec {
  final Offset from;
  final Offset to;
  final Color color;
  final double strokeWidth;
  _ArrowSpec({
    required this.from,
    required this.to,
    required this.color,
    required this.strokeWidth,
  });
}

/// Paints a set of [_ArrowSpec]s as straight lines with triangular
/// arrowheads, used for Coach mode's candidate-move display.
class _ArrowsPainter extends CustomPainter {
  final List<_ArrowSpec> arrows;
  _ArrowsPainter(this.arrows);

  @override
  void paint(Canvas canvas, Size size) {
    for (final arrow in arrows) {
      final linePaint = Paint()
        ..color = arrow.color
        ..strokeWidth = arrow.strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(arrow.from, arrow.to, linePaint);

      final angle = math.atan2(arrow.to.dy - arrow.from.dy, arrow.to.dx - arrow.from.dx);
      const headLength = 22.0;
      const headAngle = 0.55;
      final p1 = Offset(
        arrow.to.dx - headLength * math.cos(angle - headAngle),
        arrow.to.dy - headLength * math.sin(angle - headAngle),
      );
      final p2 = Offset(
        arrow.to.dx - headLength * math.cos(angle + headAngle),
        arrow.to.dy - headLength * math.sin(angle + headAngle),
      );
      final headPaint = Paint()
        ..color = arrow.color
        ..style = PaintingStyle.fill;
      canvas.drawPath(
        Path()
          ..moveTo(arrow.to.dx, arrow.to.dy)
          ..lineTo(p1.dx, p1.dy)
          ..lineTo(p2.dx, p2.dy)
          ..close(),
        headPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ArrowsPainter oldDelegate) => true;
}

class GameScreen extends StatefulWidget {
  final Difficulty difficulty;
  final int timeSeconds;
  final PlayerColor playerColor;
  final BoardTheme boardTheme;
  final PieceTheme pieceTheme;
  const GameScreen({
    super.key,
    required this.difficulty,
    required this.timeSeconds,
    required this.playerColor,
    required this.boardTheme,
    required this.pieceTheme,
  });
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final ChessBoardController _controller = ChessBoardController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  late Stockfish _stockfish;
  String _status = '';
  bool _aiThinking = false;
  bool _gameOver = false;
  bool _showGameOverOverlay = false;
  String _gameResult = '';
  late int _playerTime;
  late int _aiTime;
  bool _playerTurn = true;
  Timer? _timer;
  late PlayerColor _boardOrientation;

  double _evalScore = 0.0;
  String? _selectedSquare;

  List<String> _moveHistorySan = [];
  String? _openingName;
  String? _lastMoveFrom;
  String? _lastMoveTo;
  final ScrollController _moveListScrollController = ScrollController();

  bool _is3DMode = false;
  cube.Scene? _scene3d;
  bool _pieces3DReady = false;

  // Main board/piece look, chosen on the home screen and passed in here.
  late BoardTheme _boardTheme;
  late PieceTheme _pieceTheme;

  bool _coachMode = false;
  double? _coachEvalBeforeMove;
  String? _coachFeedback;
  bool _pendingCoachEvalRequest = false;
  bool _pendingBaselineEvalRequest = false;
  bool _pendingHintRequest = false;
  String? _hintFrom;
  String? _hintTo;
  bool _hintLoading = false;

  // Coach mode dual-side candidate arrows: top 2 moves for White and for
  // Black at the current position, refreshed after every move while Coach
  // mode is on. Queried in two sequential Stockfish passes (one for
  // whichever side actually has the move, one for the other side with a
  // FEN where side-to-move is flipped), each using MultiPV=2 to get both
  // the best move and a runner-up.
  bool _pendingArrowsRequest = false;
  int _arrowsQueryPhase = 0;
  final Map<int, String> _arrowsMultiPvMoves = {};
  List<String>? _whiteArrowMoves;
  List<String>? _blackArrowMoves;

  @override
  void initState() {
    super.initState();
    _boardTheme = widget.boardTheme;
    _pieceTheme = widget.pieceTheme;
    _playerTime = widget.timeSeconds;
    _aiTime = widget.timeSeconds;
    _playerTurn = widget.playerColor == PlayerColor.white;
    _boardOrientation = widget.playerColor;
    _status = widget.playerColor == PlayerColor.white
        ? 'Your turn - Play as White'
        : 'AI is thinking...';
    _initStockfish();
    _playSound('gamestart.mp3');
    _startTimer();
    if (widget.playerColor == PlayerColor.black) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _triggerAiMove();
      });
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_gameOver || _aiThinking || _coachMode) return;
      setState(() {
        if (_playerTurn) {
          _playerTime--;
          if (_playerTime <= 0) {
            _playerTime = 0;
            _endGame('GAME OVER\nTime is up!', false);
          }
        } else {
          _aiTime--;
          if (_aiTime <= 0) {
            _aiTime = 0;
            _endGame('YOU WIN!\nAI ran out of time!', true);
          }
        }
      });
    });
  }

  void _endGame(String result, bool playerWon) {
    _timer?.cancel();
    _playSound(playerWon ? 'victory.mp3' : 'defeat.mp3');
    setState(() {
      _gameOver = true;
      _gameResult = result;
      _status = result;
      _aiThinking = false;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showGameOverOverlay = true;
        });
      }
    });
  }

  Future<void> _playSound(String fileName) async {
    try {
      await _audioPlayer.play(AssetSource('sounds/$fileName'));
    } catch (e) {
      debugPrint('Sound error: $e');
    }
  }

  void _initStockfish() {
    _stockfish = Stockfish();
    _stockfish.state.addListener(() {
      if (_stockfish.state.value == StockfishState.ready) {
        _stockfish.stdin = 'uci';
        _stockfish.stdin = 'setoption name Skill Level value ${widget.difficulty.skillLevel}';
        _stockfish.stdin = 'isready';
      }
    });
    _stockfish.stdout.listen((output) {
      if (output.contains('score cp')) {
        final match = RegExp(r'score cp (-?\d+)').firstMatch(output);
        if (match != null && !_pendingArrowsRequest) {
          final cp = int.tryParse(match.group(1) ?? '0') ?? 0;
          _recordEvalReading(cp / 100.0);
        }
      } else if (output.contains('score mate')) {
        final match = RegExp(r'score mate (-?\d+)').firstMatch(output);
        if (match != null && !_pendingArrowsRequest) {
          final mate = int.tryParse(match.group(1) ?? '0') ?? 0;
          _recordEvalReading(mate > 0 ? 100.0 : -100.0);
        }
      }

      if (_pendingArrowsRequest && output.contains('multipv')) {
        final pvIndexMatch = RegExp(r'multipv (\d+) ').firstMatch(output);
        final pvMoveMatch = RegExp(r' pv (\S+)').firstMatch(output);
        final pvIndex = pvIndexMatch != null ? int.tryParse(pvIndexMatch.group(1) ?? '') : null;
        final pvMove = pvMoveMatch?.group(1);
        if (pvIndex != null && pvMove != null) {
          _arrowsMultiPvMoves[pvIndex] = pvMove;
        }
      }

      if (output.startsWith('bestmove')) {
        if (_pendingArrowsRequest) {
          _pendingArrowsRequest = false;
          final best = _arrowsMultiPvMoves[1];
          final alt = _arrowsMultiPvMoves[2];
          final movesFound = <String>[if (best != null) best, if (alt != null) alt];
          final whiteToMove = _controller.game.turn == chess.Color.WHITE;
          if (_arrowsQueryPhase == 1) {
            setState(() {
              if (whiteToMove) {
                _whiteArrowMoves = movesFound;
              } else {
                _blackArrowMoves = movesFound;
              }
            });
            if (_controller.game.in_check) {
              // Flipping side-to-move while the actual mover is in check
              // would leave that same side still in check but marked as
              // NOT to move in the flipped FEN - an illegal position.
              // Stockfish's native engine can respond to this by trying
              // to generate a king-capturing move, which trips a hard
              // C++ assertion and crashes the whole app (SIGABRT), not
              // just a catchable Dart error. Skip the other side's query
              // this time; it refreshes again after the next move once
              // nobody is in check.
              setState(() {
                if (whiteToMove) {
                  _blackArrowMoves = [];
                } else {
                  _whiteArrowMoves = [];
                }
              });
              _arrowsQueryPhase = 0;
              _pendingArrowsRequest = false;
              _stockfish.stdin = 'setoption name MultiPV value 1';
              return;
            }
            _arrowsQueryPhase = 2;
            _arrowsMultiPvMoves.clear();
            _pendingArrowsRequest = true;
            final flippedFen = _flipSideToMove(_controller.getFen());
            _stockfish.stdin = 'position fen $flippedFen';
            _stockfish.stdin = 'go movetime 500';
          } else {
            setState(() {
              if (whiteToMove) {
                _blackArrowMoves = movesFound;
              } else {
                _whiteArrowMoves = movesFound;
              }
            });
            _arrowsQueryPhase = 0;
            _stockfish.stdin = 'setoption name MultiPV value 1';
          }
          return;
        }
        if (_pendingHintRequest) {
          _pendingHintRequest = false;
          final parts = output.split(' ');
          if (parts.length >= 2 && parts[1] != '(none)' && parts[1].length >= 4) {
            setState(() {
              _hintFrom = parts[1].substring(0, 2);
              _hintTo = parts[1].substring(2, 4);
              _hintLoading = false;
            });
          } else {
            setState(() => _hintLoading = false);
          }
          return;
        }
        if (_pendingCoachEvalRequest) {
          _pendingCoachEvalRequest = false;
          _showCoachFeedbackForLastMove();
          if (_coachMode) {
            // This reading was the "after" for the move just made; it
            // becomes the "before" baseline for whichever move comes next,
            // since there's no AI move here to chain off of instead.
            _coachEvalBeforeMove = _evalScore;
            _requestCoachArrows();
          } else {
            _triggerAiMove();
          }
          return;
        }
        if (_pendingBaselineEvalRequest) {
          _pendingBaselineEvalRequest = false;
          if (_coachMode) {
            _coachEvalBeforeMove = _evalScore;
          }
          return;
        }
        if (_aiThinking) {
          final parts = output.split(' ');
          if (parts.length >= 2 && parts[1] != '(none)') {
            _applyAiMove(parts[1]);
          }
        }
      }
    });
  }

  /// Stockfish reports scores relative to whoever is to move in the position
  /// just searched. This converts every reading into a stable White-relative
  /// value, so the eval bar and Coach feedback always agree on who's ahead,
  /// no matter whose turn it was when the reading arrived.
  void _recordEvalReading(double sideToMoveRelative) {
    final whiteToMove = _controller.game.turn == chess.Color.WHITE;
    final whiteRelative = whiteToMove ? sideToMoveRelative : -sideToMoveRelative;
    setState(() => _evalScore = whiteRelative);
  }

  void _triggerAiMove() {
    if (_gameOver) return;
    if (_pendingArrowsRequest) {
      // The Coach mode arrows query is still mid-flight (can happen right
      // after a reset when playing as Black, since the AI's opening move
      // is scheduled slightly after the arrows request fires) - wait for
      // it to finish rather than sending an overlapping position/go that
      // would make Stockfish's real bestmove get misread as an arrows
      // result, silently dropping the AI's move.
      Future.delayed(const Duration(milliseconds: 300), _triggerAiMove);
      return;
    }
    setState(() {
      _aiThinking = true;
      _playerTurn = false;
      _status = 'AI is thinking...';
    });
    final fen = _controller.getFen();
    _stockfish.stdin = 'position fen $fen';
    _stockfish.stdin = 'go movetime ${widget.difficulty.moveTime}';
  }

  void _requestEval() {
    _pendingBaselineEvalRequest = true;
    final fen = _controller.getFen();
    _stockfish.stdin = 'position fen $fen';
    _stockfish.stdin = 'go movetime 100';
  }

  void _requestCoachEvalThenTriggerAi() {
    if (_pendingArrowsRequest) {
      Future.delayed(const Duration(milliseconds: 300), _requestCoachEvalThenTriggerAi);
      return;
    }
    _pendingCoachEvalRequest = true;
    final fen = _controller.getFen();
    _stockfish.stdin = 'position fen $fen';
    _stockfish.stdin = 'go movetime 200';
  }

  /// Compares the position's value for whichever side just moved, right
  /// before their move against its value for them right after, to
  /// classify move quality. In normal play the mover is always
  /// widget.playerColor; in Coach mode the learner moves both sides, so
  /// this works out who actually just moved from whose turn it is now
  /// (the other color) instead of assuming.
  void _showCoachFeedbackForLastMove() {
    if (_coachEvalBeforeMove == null) return;
    final evalAfter = _evalScore;
    final sideToMoveIsWhiteNow = _controller.game.turn == chess.Color.WHITE;
    final moverWasWhite = _coachMode ? !sideToMoveIsWhiteNow : widget.playerColor == PlayerColor.white;
    final beforeForPlayer = moverWasWhite ? _coachEvalBeforeMove! : -_coachEvalBeforeMove!;
    final afterForPlayer = moverWasWhite ? evalAfter : -evalAfter;
    final drop = beforeForPlayer - afterForPlayer;

    String feedback;
    if (drop < 0.15) {
      feedback = '✓ Excellent!';
    } else if (drop < 0.5) {
      feedback = '✓ Good move';
    } else if (drop < 1.2) {
      feedback = '⚠ Inaccuracy';
    } else if (drop < 3.0) {
      feedback = '✗ Mistake';
    } else {
      feedback = '✗✗ Blunder';
    }
    setState(() => _coachFeedback = feedback);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _coachFeedback = null);
    });
  }

  void _requestHint() {
    if (!_playerTurn || _aiThinking || _gameOver || _hintLoading) return;
    if (_pendingArrowsRequest) {
      Future.delayed(const Duration(milliseconds: 300), _requestHint);
      return;
    }
    setState(() {
      _hintLoading = true;
      _hintFrom = null;
      _hintTo = null;
    });
    _pendingHintRequest = true;
    final fen = _controller.getFen();
    _stockfish.stdin = 'position fen $fen';
    _stockfish.stdin = 'go movetime 400';
  }

  /// Returns a copy of [fen] with the side-to-move flipped (w<->b) and any
  /// en passant target cleared, used to ask Stockfish what the OTHER
  /// side's best moves would be at this same position.
  String _flipSideToMove(String fen) {
    final parts = fen.split(' ');
    if (parts.length < 2) return fen;
    parts[1] = parts[1] == 'w' ? 'b' : 'w';
    if (parts.length > 3) parts[3] = '-';
    return parts.join(' ');
  }

  /// Kicks off the two-phase Stockfish query for Coach mode's dual-side
  /// candidate arrows: phase 1 asks for the side actually to move (normal
  /// position, MultiPV=2 for best + runner-up), then once that finishes
  /// phase 2 asks the same with side-to-move flipped, covering the other
  /// side. Results land in _whiteArrowMoves / _blackArrowMoves.
  ///
  /// Stockfish only handles one search at a time, so if another request
  /// (hint, coach eval, baseline eval, or the AI's own move search) is
  /// already in flight, this defers itself briefly and retries instead of
  /// sending an overlapping position/go that would corrupt both results.
  void _requestCoachArrows() {
    if (!_coachMode || _gameOver) return;
    if (_pendingHintRequest ||
        _pendingCoachEvalRequest ||
        _pendingBaselineEvalRequest ||
        _aiThinking) {
      Future.delayed(const Duration(milliseconds: 300), _requestCoachArrows);
      return;
    }
    _pendingArrowsRequest = true;
    _arrowsQueryPhase = 1;
    _arrowsMultiPvMoves.clear();
    _stockfish.stdin = 'setoption name MultiPV value 2';
    final fen = _controller.getFen();
    _stockfish.stdin = 'position fen $fen';
    _stockfish.stdin = 'go movetime 500';
  }


  void _applyAiMove(String move) {
    if (!mounted) return;
    final fromSq = move.substring(0, 2);
    final toSq = move.substring(2, 4);
    try {
      final promo = move.length > 4 ? move.substring(4, 5).toLowerCase() : null;
      if (promo != null) {
        _controller.makeMoveWithPromotion(from: fromSq, to: toSq, pieceToPromoteTo: promo);
      } else {
        _controller.makeMove(from: fromSq, to: toSq);
      }
      _playSound('move.mp3');
      _lastMoveFrom = fromSq;
      _lastMoveTo = toSq;
      _updateGameRecord();
    } catch (e) {
        debugPrint('Error applying move: $e (movimiento: $move, fen: ${_controller.getFen()})');
    }
    setState(() {
      _aiThinking = false;
      _playerTurn = true;
      _status = 'Your turn';
      _selectedSquare = null;
    });
    _checkGameOver();
    _requestEval();
    if (_coachMode) _requestCoachArrows();
  }

  void _checkGameOver() {
    if (_controller.game.game_over) {
      final game = _controller.game;
      String result = '';
      bool playerWon = false;
      if (game.in_checkmate) {
        final aiWon =
            (game.turn == chess.Color.WHITE && widget.playerColor == PlayerColor.white) ||
                (game.turn == chess.Color.BLACK && widget.playerColor == PlayerColor.black);
        if (aiWon) {
          result = 'GAME OVER\nAI Wins!';
          playerWon = false;
        } else {
          result = 'YOU WIN!\nCheckmate!';
          playerWon = true;
        }
      } else if (game.in_draw || game.in_stalemate) {
        result = 'DRAW!';
        playerWon = false;
      } else {
        result = 'GAME OVER';
        playerWon = false;
      }
      _endGame(result, playerWon);
    }
  }

  // ---- Tap-to-move helpers ----

  String _squareFromLocalPosition(Offset localPos, double boardSize) {
    final squareSize = boardSize / 8;
    final col = (localPos.dx / squareSize).floor().clamp(0, 7);
    final row = (localPos.dy / squareSize).floor().clamp(0, 7);
    int file, rank;
    if (_boardOrientation == PlayerColor.white) {
      file = col;
      rank = 7 - row;
    } else {
      file = 7 - col;
      rank = row;
    }
    final fileChar = String.fromCharCode('a'.codeUnitAt(0) + file);
    final rankChar = String.fromCharCode('1'.codeUnitAt(0) + rank);
    return '$fileChar$rankChar';
  }

  Offset _localPositionFromSquare(String square, double boardSize) {
    final squareSize = boardSize / 8;
    final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = square.codeUnitAt(1) - '1'.codeUnitAt(0);
    int col, row;
    if (_boardOrientation == PlayerColor.white) {
      col = file;
      row = 7 - rank;
    } else {
      col = 7 - file;
      row = rank;
    }
    return Offset(col * squareSize, row * squareSize);
  }

  /// Converts the current Coach mode candidate moves into a list of
  /// arrows to paint: green for White (best move solid/thick, runner-up
  /// lighter/thinner), blue for Black the same way.
  List<_ArrowSpec> _buildCoachArrowSpecs(double boardSize) {
    final squareSize = boardSize / 8;
    final specs = <_ArrowSpec>[];

    void addSide(List<String>? moves, Color color) {
      if (moves == null) return;
      for (int i = 0; i < moves.length && i < 2; i++) {
        final move = moves[i];
        if (move.length < 4) continue;
        final fromSq = move.substring(0, 2);
        final toSq = move.substring(2, 4);
        final fromOffset = _localPositionFromSquare(fromSq, boardSize);
        final toOffset = _localPositionFromSquare(toSq, boardSize);
        final fromCenter = fromOffset + Offset(squareSize / 2, squareSize / 2);
        final toCenter = toOffset + Offset(squareSize / 2, squareSize / 2);
        final isBest = i == 0;
        specs.add(_ArrowSpec(
          from: fromCenter,
          to: toCenter,
          color: isBest ? color : color.withOpacity(0.4),
          strokeWidth: isBest ? 7 : 4,
        ));
      }
    }

    addSide(_whiteArrowMoves, const Color(0xFF16A34A));
    addSide(_blackArrowMoves, const Color(0xFF2563EB));
    return specs;
  }

  // ---- 3D scene helpers ----

  /// Maps an algebraic square to a world (x, z) position on the 3D board,
  /// respecting the current board orientation. Board is 1 world unit per
  /// square, centered at the origin.
  Offset _squareToWorldXZ(String square) {
    final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.parse(square[1]) - 1;
    double col, row;
    if (_boardOrientation == PlayerColor.white) {
      col = file.toDouble();
      row = rank.toDouble();
    } else {
      col = (7 - file).toDouble();
      row = (7 - rank).toDouble();
    }
    return Offset(col - 3.5, 3.5 - row);
  }

  /// The inverse of [_squareToWorldXZ] — given a world (x, z) point, finds
  /// the nearest algebraic square, or null if it falls outside the board.
  String? _worldXZToSquare(double x, double z) {
    final col = (x + 3.5).round();
    final row = (3.5 - z).round();
    if (col < 0 || col > 7 || row < 0 || row > 7) return null;
    int file, rank;
    if (_boardOrientation == PlayerColor.white) {
      file = col;
      rank = row;
    } else {
      file = 7 - col;
      rank = 7 - row;
    }
    return String.fromCharCode('a'.codeUnitAt(0) + file) + (rank + 1).toString();
  }

  /// Converts a tap position on the 3D scene into a board square by casting
  /// a ray from the camera through the tapped screen point and intersecting
  /// it with the board plane (y = 0).
  String? _screenPointToSquare3D(Offset localPosition, Size size) {
    final scene = _scene3d;
    if (scene == null || size.width == 0 || size.height == 0) return null;
    final camera = scene.camera;
    final ndcX = (2.0 * localPosition.dx / size.width) - 1.0;
    final ndcY = 1.0 - (2.0 * localPosition.dy / size.height);

    final combined = camera.projectionMatrix.multiplied(camera.lookAtMatrix);
    final inverse = cube.Matrix4.copy(combined)..invert();

    cube.Vector3 unproject(double ndcZ) {
      final v = cube.Vector4(ndcX, ndcY, ndcZ, 1.0);
      v.applyMatrix4(inverse);
      return cube.Vector3(v.x / v.w, v.y / v.w, v.z / v.w);
    }

    final near = unproject(0.0);
    final far = unproject(1.0);
    final direction = (far - near)..normalize();
    if (direction.y.abs() < 1e-6) return null;
    final t = -near.y / direction.y;
    final hitX = near.x + direction.x * t;
    final hitZ = near.z + direction.z * t;
    return _worldXZToSquare(hitX, hitZ);
  }

  /// Rebuilds every object in the 3D scene (squares, pieces, highlight
  /// markers) from the current game state. Cheap enough to call on every
  /// build while in 3D mode.
  void _rebuild3DScene() {
    final scene = _scene3d;
    if (scene == null) return;
    scene.world.children.clear();

    for (int rank = 0; rank < 8; rank++) {
      for (int file = 0; file < 8; file++) {
        final square = String.fromCharCode('a'.codeUnitAt(0) + file) + (rank + 1).toString();
        final isLight = (file + rank) % 2 == 1;
        final tile = c3d.buildSquareObject3D(light: isLight);
        final pos = _squareToWorldXZ(square);
        tile.position.setValues(pos.dx, -0.025, pos.dy);
        tile.updateTransform();
        scene.world.add(tile);
      }
    }

    void addMarker(String? square, cube.Vector3 color, double y) {
      if (square == null) return;
      final marker = c3d.buildMarkerObject3D(color);
      final pos = _squareToWorldXZ(square);
      marker.position.setValues(pos.dx, y, pos.dy);
      marker.updateTransform();
      scene.world.add(marker);
    }

    addMarker(_lastMoveFrom, cube.Vector3(0.31, 0.76, 0.97), 0.030);
    addMarker(_lastMoveTo, cube.Vector3(0.31, 0.76, 0.97), 0.030);
    addMarker(_hintFrom, cube.Vector3(0.30, 0.69, 0.31), 0.035);
    addMarker(_hintTo, cube.Vector3(0.30, 0.69, 0.31), 0.035);
    addMarker(_selectedSquare, cube.Vector3(1.0, 0.84, 0.0), 0.040);

    const bool debugSkipPieces = false; // pieces back on — trim scale fix applied
    if (debugSkipPieces) return;

    final fen = _controller.getFen();
    final rows = fen.split(' ')[0].split('/');
    for (int r = 0; r < 8; r++) {
      final rank = 8 - r;
      int file = 0;
      for (int i = 0; i < rows[r].length; i++) {
        final ch = rows[r][i];
        final digit = int.tryParse(ch);
        if (digit != null) {
          file += digit;
          continue;
        }
        final square = String.fromCharCode('a'.codeUnitAt(0) + file) + rank.toString();
        final pieceParts = c3d.buildPieceObject3D(ch);
        final pos = _squareToWorldXZ(square);
        for (final part in pieceParts) {
          part.position.setValues(pos.dx, 0, pos.dy);
          part.updateTransform();
          scene.world.add(part);
        }
        file += 1;
      }
    }
  }

  // ---- end 3D scene helpers ----

  Widget _highlightSquareContainer() {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFD700).withOpacity(0.35),
          border: Border.all(color: const Color(0xFFFFD700), width: 3),
        ),
      ),
    );
  }

  /// Solid (fully opaque, no transparency) toggle button used in the app bar
  /// for the Coach and 3D view toggles. Lights up solid green when active,
  /// matching the app's difficulty-button style, so it's clearly visible
  /// against any background.
  Widget _appBarToggleButton({
    required IconData icon,
    required bool active,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? const Color(0xFF4CAF50) : const Color(0xFF16213E),
              border: Border.all(
                color: active ? const Color(0xFF4CAF50) : Colors.white38,
                width: 1.5,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  /// Reads the FEN directly to find which piece (if any) sits on [square].
  /// Returns the FEN piece character (e.g. 'P', 'n', 'q') or null if empty.
  /// Uppercase = white, lowercase = black. This avoids depending on any
  /// extra methods from the chess package that may not behave as expected.
  String? _pieceCharAtSquare(String square) {
    final fen = _controller.getFen();
    final boardPart = fen.split(' ')[0];
    final rows = boardPart.split('/');
    final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0); // 0-7
    final rank = int.parse(square[1]); // 1-8
    final rowIndex = 8 - rank; // rank 8 is rows[0]
    if (rowIndex < 0 || rowIndex > 7) return null;
    final row = rows[rowIndex];
    int col = 0;
    for (int i = 0; i < row.length; i++) {
      final ch = row[i];
      final digit = int.tryParse(ch);
      if (digit != null) {
        col += digit;
      } else {
        if (col == file) return ch;
        col += 1;
      }
    }
    return null;
  }

  void _handleSquareTap(String square) {
    debugPrint('Tap detected on square: $square');
    if (_aiThinking || _gameOver) return;
    if (!_coachMode && !_playerTurn) return;

    final pieceChar = _pieceCharAtSquare(square);
    final isWhitePiece = pieceChar != null && pieceChar == pieceChar.toUpperCase();
    final myIsWhite = widget.playerColor == PlayerColor.white;
    final sideToMoveIsWhite = _controller.game.turn == chess.Color.WHITE;
    final isMyPiece = pieceChar != null &&
        (isWhitePiece == (_coachMode ? sideToMoveIsWhite : myIsWhite));
    debugPrint('Piece at $square: $pieceChar, isMyPiece: $isMyPiece');

    if (_selectedSquare == null) {
      if (isMyPiece) {
        setState(() => _selectedSquare = square);
      }
      return;
    }

    if (_selectedSquare == square) {
      setState(() => _selectedSquare = null);
      return;
    }

    final from = _selectedSquare!;
    final fenBefore = _controller.getFen();
    try {
      final movingPiece = _controller.game.get(from);
      final lastRank = movingPiece?.color == chess.Color.WHITE ? '8' : '1';
      final isPromo = movingPiece?.type == chess.PieceType.PAWN && square.endsWith(lastRank);
      if (isPromo) {
        _controller.makeMoveWithPromotion(from: from, to: square, pieceToPromoteTo: 'q');
      } else {
        _controller.makeMove(from: from, to: square);
      }
    } catch (e) {
      debugPrint('Move error: $e');
    }
    final fenAfter = _controller.getFen();
    final moveSuccess = fenBefore != fenAfter;

    if (moveSuccess) {
      setState(() {
        _selectedSquare = null;
        _hintFrom = null;
        _hintTo = null;
        if (_coachMode) {
          _status = _controller.game.turn == chess.Color.WHITE
              ? 'Turno de blancas'
              : 'Turno de negras';
        }
      });
      _playSound('capture.mp3');
      _lastMoveFrom = from;
      _lastMoveTo = square;
      _updateGameRecord();
      _checkGameOver();
      if (_gameOver) return;
      if (_coachMode) {
        // No AI auto-move in Coach mode - the learner moves both sides.
        // Still ask Stockfish to evaluate the move just made (and, via
        // that same reading, set up the baseline for the next one).
        _requestCoachEvalThenTriggerAi();
      } else {
        _triggerAiMove();
      }
    } else {
      if (isMyPiece) {
        setState(() => _selectedSquare = square);
      } else {
        setState(() => _selectedSquare = null);
      }
    }
  }

  // ---- end tap-to-move helpers ----

  // ---- move history, opening name, and last-move tracking ----

  /// Pulls the latest SAN move list from the engine and refreshes both the
  /// saved history and the detected opening name. Safe to call after every
  /// move; if the underlying package call fails for any reason, the rest of
  /// the app keeps working (history/opening simply won't update that turn).
  void _updateGameRecord() {
    try {
      final rawHistory = _controller.game.getHistory();
      final sanList = (rawHistory as List).map((e) => e.toString()).toList();
      setState(() => _moveHistorySan = sanList);
      _updateOpeningName(sanList);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_moveListScrollController.hasClients) {
          _moveListScrollController.animateTo(
            _moveListScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      debugPrint('History error: $e');
    }
  }

  /// Finds the longest known opening whose move sequence matches the start
  /// of the game's move history, and updates _openingName if found. Once a
  /// game goes past all known lines, the last matched name is kept as-is
  /// (the opening the game started with doesn't change just because the
  /// players left known theory).
  void _updateOpeningName(List<String> historySan) {
    String? bestMatch;
    int bestLength = 0;
    for (final entry in openingsDatabase) {
      final moves = entry['moves'] as List<String>;
      if (historySan.length >= moves.length) {
        bool matches = true;
        for (int i = 0; i < moves.length; i++) {
          if (historySan[i] != moves[i]) {
            matches = false;
            break;
          }
        }
        if (matches && moves.length > bestLength) {
          bestLength = moves.length;
          bestMatch = entry['name'] as String;
        }
      }
    }
    if (bestMatch != null) {
      setState(() => _openingName = bestMatch);
    }
  }

  /// Formats the recorded SAN history into standard "1. e4 e5 2. Nf3 Nc6"
  /// movetext, so it reads like any exportable chess game notation.
  String _formatMoveHistory() {
    if (_moveHistorySan.isEmpty) return 'No moves yet.';
    final buffer = StringBuffer();
    for (int i = 0; i < _moveHistorySan.length; i += 2) {
      final moveNumber = (i ~/ 2) + 1;
      final whiteMove = _moveHistorySan[i];
      final blackMove = (i + 1 < _moveHistorySan.length) ? _moveHistorySan[i + 1] : '';
      buffer.write('$moveNumber. $whiteMove ${blackMove.isNotEmpty ? blackMove : ''} ');
    }
    return buffer.toString().trim();
  }

  void _showMoveHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Move History',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(
              _formatMoveHistory(),
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14, height: 1.7),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _formatMoveHistory()));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Copied to clipboard', style: GoogleFonts.poppins())),
              );
            },
            child: Text('Copy', style: GoogleFonts.poppins(color: const Color(0xFF4CAF50), fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.poppins(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  // ---- end move history / opening tracking ----

  void _flipBoard() {
    setState(() {
      _boardOrientation = _boardOrientation == PlayerColor.white
          ? PlayerColor.black
          : PlayerColor.white;
    });
  }

  void _revertMove() {
    if (_aiThinking || _gameOver) return;
    try {
      _controller.game.undo_move();
      _controller.game.undo_move();
      setState(() {
        _playerTurn = true;
        _status = 'Your turn';
        _selectedSquare = null;
      });
    } catch (e) {
      debugPrint('Revert error: $e');
    }
  }

  void _resetGame() {
    _timer?.cancel();
    _controller.resetBoard();
    _playSound('gamestart.mp3');
    setState(() {
      _playerTime = widget.timeSeconds;
      _aiTime = widget.timeSeconds;
      _playerTurn = widget.playerColor == PlayerColor.white;
      _boardOrientation = widget.playerColor;
      _status = widget.playerColor == PlayerColor.white
          ? 'Your turn - Play as White'
          : 'AI is thinking...';
      _aiThinking = false;
      _gameOver = false;
      _showGameOverOverlay = false;
      _gameResult = '';
      _evalScore = 0.0;
      _selectedSquare = null;
      _moveHistorySan = [];
      _openingName = null;
      _lastMoveFrom = null;
      _lastMoveTo = null;
      _coachEvalBeforeMove = null;
      _coachFeedback = null;
      _hintFrom = null;
      _hintTo = null;
      _hintLoading = false;
      _pendingCoachEvalRequest = false;
      _pendingBaselineEvalRequest = false;
      _pendingHintRequest = false;
      _whiteArrowMoves = null;
      _blackArrowMoves = null;
      _pendingArrowsRequest = false;
      _arrowsQueryPhase = 0;
    });
    _startTimer();
    if (widget.playerColor == PlayerColor.black) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _triggerAiMove();
      });
    }
    if (_coachMode) _requestCoachArrows();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stockfish.dispose();
    _audioPlayer.dispose();
    _moveListScrollController.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildEvalBar() {
    final clampedEval = _evalScore.clamp(-10.0, 10.0);
    final whitePct = (clampedEval + 10.0) / 20.0;

    return Container(
      width: 20,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: Colors.black,
      ),
      child: Column(
        children: [
          Expanded(
            flex: ((1.0 - whitePct) * 100).round(),
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ),
          ),
          Expanded(
            flex: (whitePct * 100).round(),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Renders the 8x8 board and pieces ourselves (instead of the
  /// flutter_chess_board package's ChessBoard widget), reading position
  /// straight from the controller's FEN - the same approach already used
  /// by [_pieceCharAtSquare] and [_rebuild3DScene]. Everything else (tap
  /// handling, highlights, eval bar) lives in sibling widgets in the same
  /// Stack and is untouched by this change.
  ///
  /// Only used when [boardTheme] isn't BoardTheme.clasico - the classic
  /// look keeps using the package's own ChessBoard widget untouched. Piece
  /// artwork is a single solid-color PNG per piece type under
  /// assets/pieces/, tinted to whichever color the side needs via
  /// ColorFiltered, so one image works for both colors and any theme.
  /// Builds the tinted, rotation-corrected piece image for one square.
  /// White pieces get a black silhouette of the same artwork rendered
  /// slightly larger underneath, acting as an outline so they stay
  /// visible on light-colored squares (a flat white shape alone would
  /// blend into a white/cream square). Black pieces skip this since they
  /// already contrast against every square color.
  Widget _buildPieceImage(String assetName, bool isWhite, PieceTheme pieceTheme) {
    final rotationDeg = chessPieceRotationDegrees[assetName] ?? 0.0;
    final image = Transform.rotate(
      angle: rotationDeg * 3.14159265 / 180,
      child: Image.asset('assets/pieces/$assetName.png', fit: BoxFit.contain),
    );
    final fillColor = isWhite ? pieceTheme.whiteColor : pieceTheme.blackColor;
    final tintedPiece = ColorFiltered(
      colorFilter: ColorFilter.mode(fillColor, BlendMode.srcIn),
      child: image,
    );
    if (!isWhite) return tintedPiece;
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.scale(
          scale: 1.22,
          child: ColorFiltered(
            colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
            child: image,
          ),
        ),
        tintedPiece,
      ],
    );
  }

  Widget _buildCustomBoard(double boardSize, BoardTheme boardTheme, PieceTheme pieceTheme) {
    final squareSize = boardSize / 8;
    final fen = _controller.getFen();
    final boardRows = fen.split(' ')[0].split('/');

    final Map<String, String> pieceAt = {};
    for (int r = 0; r < 8; r++) {
      final rank = 8 - r;
      int file = 0;
      for (int i = 0; i < boardRows[r].length; i++) {
        final ch = boardRows[r][i];
        final digit = int.tryParse(ch);
        if (digit != null) {
          file += digit;
          continue;
        }
        final square = String.fromCharCode('a'.codeUnitAt(0) + file) + rank.toString();
        pieceAt[square] = ch;
        file += 1;
      }
    }

    return SizedBox(
      width: boardSize,
      height: boardSize,
      child: Column(
        children: List.generate(8, (row) {
          return Expanded(
            child: Row(
              children: List.generate(8, (col) {
                int file, rank;
                if (_boardOrientation == PlayerColor.white) {
                  file = col;
                  rank = 7 - row;
                } else {
                  file = 7 - col;
                  rank = row;
                }
                final square =
                    String.fromCharCode('a'.codeUnitAt(0) + file) + (rank + 1).toString();
                final isLight = (file + rank + 1) % 2 == 0;
                final pieceChar = pieceAt[square];
                final assetName = pieceChar != null
                    ? chessPieceAssetNames[pieceChar.toLowerCase()]
                    : null;
                return Expanded(
                  child: Container(
                    color: isLight ? boardTheme.lightSquare : boardTheme.darkSquare,
                    alignment: Alignment.center,
                    child: assetName != null && pieceChar != null
                        ? Padding(
                            padding: EdgeInsets.all(squareSize * 0.08),
                            child: _buildPieceImage(
                              assetName,
                              pieceChar == pieceChar.toUpperCase(),
                              pieceTheme,
                            ),
                          )
                        : null,
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F3460),
        title: Text(
          '${widget.difficulty.label} • ${timeOptions.firstWhere((t) => t['seconds'] == widget.timeSeconds)['label']}',
          style: GoogleFonts.poppins(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          _appBarToggleButton(
            icon: Icons.school,
            active: _coachMode,
            tooltip: 'Coach mode',
            onTap: () {
              setState(() {
                _coachMode = !_coachMode;
                if (!_coachMode) {
                  // Resync whose turn it is for normal mode - Coach mode
                  // may have left the game mid-sequence with either side
                  // having just moved.
                  final sideToMoveIsWhite = _controller.game.turn == chess.Color.WHITE;
                  final myIsWhite = widget.playerColor == PlayerColor.white;
                  _playerTurn = sideToMoveIsWhite == myIsWhite;
                  _status = _playerTurn ? 'Your turn' : 'AI is thinking...';
                }
              });
              if (_coachMode) {
                _requestCoachArrows();
              } else if (!_playerTurn && !_gameOver) {
                _triggerAiMove();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'Move history',
            onPressed: _showMoveHistoryDialog,
          ),
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Undo move',
            onPressed: _aiThinking || _gameOver ? null : _revertMove,
          ),
          IconButton(
            icon: const Icon(Icons.flip),
            tooltip: 'Flip board',
            onPressed: _flipBoard,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'New game',
            onPressed: _resetGame,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFF16213E),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: widget.difficulty.color,
                      child: const Icon(Icons.smart_toy, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Stockfish AI',
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        Text('Rating: ${widget.difficulty.rating}',
                            style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: !_playerTurn && !_gameOver
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFF0F3460),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: !_playerTurn && !_gameOver
                              ? const Color(0xFF4CAF50)
                              : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        _formatTime(_aiTime),
                        style: GoogleFonts.poppins(
                            color: _aiTime < 30 ? Colors.red : Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              if (_openingName != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  color: const Color(0xFF0F3460),
                  child: Text(
                    '♟ $_openingName',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        color: const Color(0xFFFFD700),
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              Expanded(
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: _buildEvalBar(),
                    ),
                    Expanded(
                      child: Center(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final availableSize =
                                constraints.maxWidth < constraints.maxHeight
                                    ? constraints.maxWidth
                                    : constraints.maxHeight;
                            final boardSize = availableSize - 8;
                            final squareSize = boardSize / 8;
                            final highlightOffset = _selectedSquare != null
                                ? _localPositionFromSquare(_selectedSquare!, boardSize)
                                : null;
                            final lastFromOffset = _lastMoveFrom != null
                                ? _localPositionFromSquare(_lastMoveFrom!, boardSize)
                                : null;
                            final lastToOffset = _lastMoveTo != null
                                ? _localPositionFromSquare(_lastMoveTo!, boardSize)
                                : null;
                            final hintFromOffset = _hintFrom != null
                                ? _localPositionFromSquare(_hintFrom!, boardSize)
                                : null;
                            final hintToOffset = _hintTo != null
                                ? _localPositionFromSquare(_hintTo!, boardSize)
                                : null;
                            final boardStack = SizedBox(
                              width: boardSize + 8,
                              height: boardSize + 8,
                              child: Stack(
                                children: [
                                  Positioned(
                                    left: 4,
                                    top: 4,
                                    width: boardSize,
                                    height: boardSize,
                                    child: _buildCustomBoard(boardSize, _boardTheme, _pieceTheme),
                                  ),
                                  if (_coachMode)
                                    Positioned(
                                      left: 4,
                                      top: 4,
                                      width: boardSize,
                                      height: boardSize,
                                      child: IgnorePointer(
                                        child: CustomPaint(
                                          painter: _ArrowsPainter(_buildCoachArrowSpecs(boardSize)),
                                        ),
                                      ),
                                    ),
                                  if (lastFromOffset != null)
                                    Positioned(
                                      left: 4 + lastFromOffset.dx,
                                      top: 4 + lastFromOffset.dy,
                                      width: squareSize,
                                      height: squareSize,
                                      child: IgnorePointer(
                                        child: Container(
                                          color: const Color(0xFF4FC3F7).withOpacity(0.28),
                                        ),
                                      ),
                                    ),
                                  if (lastToOffset != null)
                                    Positioned(
                                      left: 4 + lastToOffset.dx,
                                      top: 4 + lastToOffset.dy,
                                      width: squareSize,
                                      height: squareSize,
                                      child: IgnorePointer(
                                        child: Container(
                                          color: const Color(0xFF4FC3F7).withOpacity(0.28),
                                        ),
                                      ),
                                    ),
                                  if (hintFromOffset != null)
                                    Positioned(
                                      left: 4 + hintFromOffset.dx,
                                      top: 4 + hintFromOffset.dy,
                                      width: squareSize,
                                      height: squareSize,
                                      child: IgnorePointer(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF4CAF50).withOpacity(0.35),
                                            border: Border.all(
                                                color: const Color(0xFF4CAF50), width: 2),
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (hintToOffset != null)
                                    Positioned(
                                      left: 4 + hintToOffset.dx,
                                      top: 4 + hintToOffset.dy,
                                      width: squareSize,
                                      height: squareSize,
                                      child: IgnorePointer(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF4CAF50).withOpacity(0.35),
                                            border: Border.all(
                                                color: const Color(0xFF4CAF50), width: 2),
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (highlightOffset != null)
                                    Positioned(
                                      left: 4 + highlightOffset.dx,
                                      top: 4 + highlightOffset.dy,
                                      width: squareSize,
                                      height: squareSize,
                                      child: _highlightSquareContainer(),
                                    ),
                                  Positioned(
                                    left: 4,
                                    top: 4,
                                    width: boardSize,
                                    height: boardSize,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTapUp: (details) {
                                        debugPrint(
                                            'Board tap at local pos: ${details.localPosition}');
                                        final square = _squareFromLocalPosition(
                                            details.localPosition, boardSize);
                                        _handleSquareTap(square);
                                      },
                                    ),
                                  ),
                                  if (_aiThinking && !_gameOver)
                                    Positioned.fill(
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          child: const CircularProgressIndicator(
                                              color: Color(0xFFFFD700)),
                                        ),
                                      ),
                                    ),
                                  if (_coachFeedback != null)
                                    Positioned(
                                      top: 10,
                                      left: 0,
                                      right: 0,
                                      child: Center(
                                        child: IgnorePointer(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.75),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              _coachFeedback!,
                                              style: GoogleFonts.poppins(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                            // 3D mode temporarily disabled — always use the 2D board.
                            // (3D code below is kept in place to re-enable later.)
                            return boardStack;
                            // ignore: dead_code
                            if (!_is3DMode) return boardStack;

                            if (_pieces3DReady) {
                              _rebuild3DScene();
                            }
                            final sceneSize = Size(boardSize + 8, boardSize + 8);
                            return SizedBox(
                              width: sceneSize.width,
                              height: sceneSize.height,
                              child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Color(0xFF3A4A7A), Color(0xFF232B4D)],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.5),
                                    blurRadius: 30,
                                    spreadRadius: -10,
                                    offset: const Offset(0, 40),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTapUp: (details) {
                                      final square = _screenPointToSquare3D(details.localPosition, sceneSize);
                                      if (square != null) _handleSquareTap(square);
                                    },
                                    child: cube.Cube(
                                      interactive: false,
                                      onSceneCreated: (scene) {
                                        _scene3d = scene;
                                        scene.camera.position.setValues(0, 7.5, 12.0);
                                        scene.camera.target.setValues(0, 0, 0);
                                        scene.camera.fov = 40;
                                        scene.light.position.setValues(2, 9, 13);
                                        scene.light.setColor(Colors.white, 0.95, 1.0, 0.40);
                                        if (c3d.piecesLoaded) {
                                          setState(() => _pieces3DReady = true);
                                        } else {
                                          c3d.preloadPieces().then((_) {
                                            if (mounted) setState(() => _pieces3DReady = true);
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                  if (!_pieces3DReady)
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: Container(
                                          color: const Color(0xFF1A1A2E),
                                          child: const Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                CircularProgressIndicator(color: Color(0xFFFFD700)),
                                                SizedBox(height: 12),
                                                Text('Cargando piezas 3D...',
                                                    style: TextStyle(color: Colors.white70)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (_aiThinking && !_gameOver)
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: Center(
                                          child: Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                                color: Colors.black54,
                                                borderRadius: BorderRadius.circular(12)),
                                            child: const CircularProgressIndicator(color: Color(0xFFFFD700)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (_coachFeedback != null)
                                    Positioned(
                                      top: 10,
                                      left: 0,
                                      right: 0,
                                      child: Center(
                                        child: IgnorePointer(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.75),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              _coachFeedback!,
                                              style: GoogleFonts.poppins(
                                                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_coachMode)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: (!_playerTurn || _aiThinking || _gameOver || _hintLoading)
                          ? null
                          : _requestHint,
                      icon: _hintLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Color(0xFF4CAF50)),
                            )
                          : const Icon(Icons.lightbulb, color: Color(0xFF4CAF50), size: 18),
                      label: Text(
                        _hintLoading ? 'Thinking of a hint...' : 'Get Hint',
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF4CAF50)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ),
              if (_moveHistorySan.isNotEmpty)
                Container(
                  width: double.infinity,
                  height: 30,
                  color: const Color(0xFF16213E),
                  child: SingleChildScrollView(
                    controller: _moveListScrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text(
                      _formatMoveHistory(),
                      style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                color: const Color(0xFF0F3460),
                child: Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFF16213E),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFF2196F3),
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('You',
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        Text(
                          widget.playerColor == PlayerColor.white
                              ? 'Playing as White ♔'
                              : 'Playing as Black ♚',
                          style: GoogleFonts.poppins(
                              color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _playerTurn && !_gameOver
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFF0F3460),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _playerTurn && !_gameOver
                              ? const Color(0xFF4CAF50)
                              : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        _formatTime(_playerTime),
                        style: GoogleFonts.poppins(
                            color: _playerTime < 30 ? Colors.red : Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_showGameOverOverlay)
            Container(
              color: Colors.black87,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16213E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _gameResult.contains('WIN')
                          ? const Color(0xFFFFD700)
                          : Colors.red,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _gameResult.contains('WIN')
                            ? Icons.emoji_events
                            : Icons.sentiment_very_dissatisfied,
                        size: 80,
                        color: _gameResult.contains('WIN')
                            ? const Color(0xFFFFD700)
                            : Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _gameResult,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: _gameResult.contains('WIN')
                                ? const Color(0xFFFFD700)
                                : Colors.white),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _resetGame,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          minimumSize: const Size(200, 50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Play Again',
                            style: GoogleFonts.poppins(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Main Menu',
                            style: GoogleFonts.poppins(
                                color: Colors.white54, fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}