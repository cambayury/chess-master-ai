# Chess Master AI

A chess app for Android, built with Flutter and powered by the Stockfish chess engine. An iOS version is in progress.

- Google Play: https://play.google.com/store/apps/details?id=com.chessmasteria.chess_master_ia
- Terms of Service: https://yurycamba.com/chess-master-ai-terms

## License

Copyright (C) 2026 Yury Camba (Camba Technology)

Chess Master AI is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License, version 3, as published by the Free Software Foundation. See the `LICENSE` file.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

## Stockfish

The chess engine is [Stockfish](https://github.com/official-stockfish/Stockfish), also licensed under the GPLv3. The app uses it through the [`stockfish`](https://pub.dev/packages/stockfish) Flutter package; the exact version is pinned in `pubspec.lock`. Android builds use the package unchanged. For iOS builds, `codemagic.yaml` patches `evaluate.h` so the NNUE network files load from absolute paths.

## Assets not included

The published app uses these files, but they are not included here because their licenses don't allow redistributing them:

- `assets/pieces/`: chess piece images (`king.png`, `queen.png`, `rook.png`, `bishop.png`, `knight.png`, `pawn.png`). They are single-color silhouettes on a transparent background; the app tints them in code.
- `assets/sounds/`: background music (`background.mp3`, `background2.mp3`, `background3.mp3`, `background4.mp3`) and sound effects (`move.mp3`, `capture.mp3`, `gamestart.mp3`, `victory.mp3`, `defeat.mp3`).
- `assets/models3d/`: 3D piece models (`king_body.obj`, `king_trim.obj` and the same pair for the other pieces) for the 3D board, which is currently disabled.

To build the app, add your own files with the same names.

## Name and icon

The name "Chess Master AI" and the app icon (`icon.svg`, `icon_1024.png`, `assets/images/queen.png` and the launcher icons generated from them) are not covered by the GPL. If you distribute a modified version, please use a different name and icon.

## Building

1. Install Flutter (stable channel).
2. Add the assets listed above.
3. Run `flutter pub get`.
4. Run `flutter run`.

Release builds are signed with a key that is not part of this repository. To sign your own builds, create `android/key.properties` with `storePassword`, `keyPassword`, `keyAlias` and `storeFile`.

## Releases

Every version published on Google Play is tagged here with its version number (for example, `v1.0.19`).

## Contact

yury@yurycamba.com
