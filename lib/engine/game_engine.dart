import 'dart:math';
import '../data/levels_data.dart';

class BoardCell {
  bool isWall = false;
  bool hasPortal = false;
  bool hasSpikes = false;
  String? plateColor; // 'red', 'blue', 'green'
  String? gateColor;  // 'red', 'blue', 'green'
  String? teleportType; // 'in', 'out'
  bool isChasm = false;
  String? laserType; // 'L', 'l', 'P', 'p'
  String? conveyorDir; // 'L', 'R', 'U', 'D'
  String? identityPortalPlayer; // 'p1', 'p2', 'p3', 'p4'
  bool isJammer = false;
  bool isSensor = false;

  BoardCell();

  BoardCell clone() {
    final cell = BoardCell();
    cell.isWall = isWall;
    cell.hasPortal = hasPortal;
    cell.hasSpikes = hasSpikes;
    cell.plateColor = plateColor;
    cell.gateColor = gateColor;
    cell.teleportType = teleportType;
    cell.isChasm = isChasm;
    cell.laserType = laserType;
    cell.conveyorDir = conveyorDir;
    cell.identityPortalPlayer = identityPortalPlayer;
    cell.isJammer = isJammer;
    cell.isSensor = isSensor;
    return cell;
  }
}

class Player {
  final String id;
  final String label;
  int x;
  int y;
  bool dead;
  bool finished;

  Player({
    required this.id,
    required this.label,
    required this.x,
    required this.y,
    this.dead = false,
    this.finished = false,
  });

  Player clone() {
    return Player(
      id: id,
      label: label,
      x: x,
      y: y,
      dead: dead,
      finished: finished,
    );
  }
}

class Glyph {
  final int id;
  final String type; // 'red', 'blue', 'green', 'heavy-2', 'heavy-3'
  int x;
  int y;

  Glyph({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
  });

  Glyph clone() {
    return Glyph(
      id: id,
      type: type,
      x: x,
      y: y,
    );
  }
}

class MoveResult {
  final bool moved;
  final bool won;
  final bool merged;
  final bool dead;
  final List<String> deadPlayerIds;
  final bool playerFinished;
  final String playerId;

  MoveResult({
    required this.moved,
    required this.won,
    required this.merged,
    required this.dead,
    List<String>? deadPlayerIds,
    required this.playerFinished,
    required this.playerId,
  }) : deadPlayerIds = deadPlayerIds ?? const [];
}

class GameEngine {
  int width = 0;
  int height = 0;
  List<List<BoardCell>> cells = [];
  List<Player> players = [];
  List<Glyph> glyphs = [];
  int stepCount = 0;
  int glyphIdCounter = 0;

  // Active state
  Player? activePlayer;
  Set<String> activeLaserBeams = {}; // Set of "x,y" coordinates
  Map<String, String> activeLaserBeamAxes = {}; // "x,y" -> "horizontal" or "vertical"
  
  // Game loops
  bool isGameActive = true;

  GameEngine();

  void loadLevel(LevelData levelData) {
    width = levelData.width;
    height = levelData.height;
    stepCount = 0;
    glyphIdCounter = 0;
    activeLaserBeams.clear();
    activeLaserBeamAxes.clear();

    players = [
      Player(id: 'p1', label: 'P1', x: -1, y: -1),
      Player(id: 'p2', label: 'P2', x: -1, y: -1),
      Player(id: 'p3', label: 'P3', x: -1, y: -1),
      Player(id: 'p4', label: 'P4', x: -1, y: -1),
    ];
    activePlayer = players[0];
    glyphs = [];

    // Initialize cells grid
    cells = List.generate(
      width,
      (_) => List.generate(height, (_) => BoardCell()),
    );

    // Parse level map
    for (int y = 0; y < height; y++) {
      if (y >= levelData.map.length) continue;
      final rowStr = levelData.map[y];
      for (int x = 0; x < width; x++) {
        if (x >= rowStr.length) continue;
        final char = rowStr[x];
        final cell = cells[x][y];

        switch (char) {
          case '#':
            cell.isWall = true;
            break;
          case 'X':
            cell.hasPortal = true;
            break;
          case '^':
            cell.hasSpikes = true;
            break;
          case 'a':
            cell.plateColor = 'red';
            break;
          case 'b':
            cell.plateColor = 'blue';
            break;
          case 'c':
            cell.plateColor = 'green';
            break;
          case '1':
            cell.gateColor = 'red';
            break;
          case '2':
            cell.gateColor = 'blue';
            break;
          case '3':
            cell.gateColor = 'green';
            break;
          case '@':
            placePlayer('p1', x, y);
            break;
          case '&':
          case '%':
            placePlayer('p2', x, y);
            break;
          case '*':
            placePlayer('p3', x, y);
            break;
          case '\$':
            placePlayer('p4', x, y);
            break;
          case 'A':
            spawnGlyph('red', x, y);
            break;
          case 'B':
            spawnGlyph('blue', x, y);
            break;
          case 'C':
            spawnGlyph('green', x, y);
            break;
          case 'H':
            spawnGlyph('heavy-2', x, y);
            break;
          case 'K':
            spawnGlyph('heavy-3', x, y);
            break;
          case '[':
            cell.teleportType = 'in';
            break;
          case ']':
            cell.teleportType = 'out';
            break;
          case '_':
            cell.isChasm = true;
            break;
          case 'L':
            cell.laserType = 'L';
            break;
          case 'l':
            cell.laserType = 'l';
            break;
          case 'P':
            cell.laserType = 'P';
            break;
          case 'p':
            cell.laserType = 'p';
            break;
          case '(':
            cell.conveyorDir = 'L';
            break;
          case ')':
            cell.conveyorDir = 'R';
            break;
          case '{':
            cell.conveyorDir = 'U';
            break;
          case '}':
            cell.conveyorDir = 'D';
            break;
          case 'I':
            cell.identityPortalPlayer = 'p1';
            break;
          case 'O':
            cell.identityPortalPlayer = 'p2';
            break;
          case 'U':
            cell.identityPortalPlayer = 'p3';
            break;
          case 'V':
            cell.identityPortalPlayer = 'p4';
            break;
          case 'J':
            cell.isJammer = true;
            break;
          case 'S':
            cell.isSensor = true;
            break;
        }
      }
    }

    // Set first active player
    for (var p in players) {
      if (p.x != -1) {
        activePlayer = p;
        break;
      }
    }

    updateTriggers();
  }

  void placePlayer(String id, int x, int y) {
    for (var p in players) {
      if (p.id == id) {
        p.x = x;
        p.y = y;
        break;
      }
    }
  }

  void spawnGlyph(String type, int x, int y) {
    glyphIdCounter++;
    glyphs.add(Glyph(id: glyphIdCounter, type: type, x: x, y: y));
  }

  Player getPlayer(String id) {
    return players.firstWhere((p) => p.id == id);
  }

  bool isPlayerActive(Player p) {
    return p.x != -1 && !p.dead && !p.finished;
  }

  Player? getPlayerAt(int x, int y, [String? skipId]) {
    for (var p in players) {
      if (isPlayerActive(p) && p.x == x && p.y == y && p.id != skipId) {
        return p;
      }
    }
    return null;
  }

  MoveResult tryMove(int dx, int dy, Map<String, String> activeRules, {String playerId = 'p1'}) {
    final player = getPlayer(playerId);
    if (!isPlayerActive(player)) {
      return MoveResult(moved: false, won: false, merged: false, dead: false, playerFinished: false, playerId: playerId);
    }

    final nextX = player.x + dx;
    final nextY = player.y + dy;

    // Boundary check
    if (nextX < 0 || nextX >= width || nextY < 0 || nextY >= height) {
      return MoveResult(moved: false, won: false, merged: false, dead: false, playerFinished: false, playerId: playerId);
    }

    final targetCell = cells[nextX][nextY];

    // Wall check
    if (targetCell.isWall) {
      return MoveResult(moved: false, won: false, merged: false, dead: false, playerFinished: false, playerId: playerId);
    }

    // Gate check
    if (targetCell.gateColor != null) {
      if (!isGateColorOpen(targetCell.gateColor!)) {
        return MoveResult(moved: false, won: false, merged: false, dead: false, playerFinished: false, playerId: playerId);
      }
    }

    // Identity portal check
    if (targetCell.identityPortalPlayer != null && targetCell.identityPortalPlayer != player.id) {
      return MoveResult(moved: false, won: false, merged: false, dead: false, playerFinished: false, playerId: playerId);
    }

    if (getPlayerAt(nextX, nextY, player.id) != null) {
      return MoveResult(moved: false, won: false, merged: false, dead: false, playerFinished: false, playerId: playerId);
    }

    final glyphIndex = glyphs.indexWhere((g) => g.x == nextX && g.y == nextY);
    bool didMerge = false;

    if (glyphIndex != -1) {
      final glyph = glyphs[glyphIndex];
      final effectiveRules = getEffectiveRules(activeRules);
      String rule = effectiveRules[glyph.type] ?? 'STOP';

      if (cells[glyph.x][glyph.y].isJammer) {
        rule = 'STOP';
      }

      // Heavy block check
      if (glyph.type == 'heavy-2' || glyph.type == 'heavy-3') {
        final reqPlayers = glyph.type == 'heavy-2' ? 2 : 3;
        bool lineOk = true;
        for (int i = 1; i < reqPlayers; i++) {
          final checkX = player.x - i * dx;
          final checkY = player.y - i * dy;
          if (getPlayerAt(checkX, checkY) == null) {
            lineOk = false;
            break;
          }
        }
        if (!lineOk) {
          return MoveResult(moved: false, won: false, merged: false, dead: false, playerFinished: false, playerId: playerId);
        }
        rule = 'PUSH';
      }

      if (rule == 'STOP') {
        return MoveResult(moved: false, won: false, merged: false, dead: false, playerFinished: false, playerId: playerId);
      }

      if (rule == 'PUSH' || rule == 'MERGE') {
        final behindX = nextX + dx;
        final behindY = nextY + dy;

        if (behindX < 0 || behindX >= width || behindY < 0 || behindY >= height) {
          return MoveResult(moved: false, won: false, merged: false, dead: false, playerFinished: false, playerId: playerId);
        }

        final behindCell = cells[behindX][behindY];

        if (behindCell.isWall) {
          return MoveResult(moved: false, won: false, merged: false, dead: false, playerFinished: false, playerId: playerId);
        }
        if (behindCell.gateColor != null && !isGateColorOpen(behindCell.gateColor!)) {
          return MoveResult(moved: false, won: false, merged: false, dead: false, playerFinished: false, playerId: playerId);
        }
        if (behindCell.identityPortalPlayer != null) {
          return MoveResult(moved: false, won: false, merged: false, dead: false, playerFinished: false, playerId: playerId);
        }
        if (getPlayerAt(behindX, behindY, player.id) != null) {
          return MoveResult(moved: false, won: false, merged: false, dead: false, playerFinished: false, playerId: playerId);
        }

        final secondGlyphIndex = glyphs.indexWhere((g) => g.x == behindX && g.y == behindY);

        if (secondGlyphIndex != -1) {
          final secondGlyph = glyphs[secondGlyphIndex];
          if (rule == 'MERGE' && glyph.type == secondGlyph.type && glyph.type != 'heavy-2' && glyph.type != 'heavy-3') {
            // Merge
            glyph.x = behindX;
            glyph.y = behindY;

            glyphs.removeAt(glyphIndex);
            didMerge = true;

            int playerDestX = nextX;
            int playerDestY = nextY;
            final pTele = getTeleportDestination(playerDestX, playerDestY);
            if (pTele != null) {
              playerDestX = pTele.x;
              playerDestY = pTele.y;
            }
            player.x = playerDestX;
            player.y = playerDestY;
          } else {
            return MoveResult(moved: false, won: false, merged: false, dead: false, playerFinished: false, playerId: playerId);
          }
        } else {
          // Push normally
          int glyphDestX = behindX;
          int glyphDestY = behindY;

          final gTele = getTeleportDestination(glyphDestX, glyphDestY);
          if (gTele != null) {
            glyphDestX = gTele.x;
            glyphDestY = gTele.y;
          }

          final destCell = cells[glyphDestX][glyphDestY];
          if (destCell.isChasm) {
            destCell.isChasm = false;
            glyphs.removeAt(glyphIndex);
            didMerge = true; // behaves like merge visually
          } else {
            glyph.x = glyphDestX;
            glyph.y = glyphDestY;
          }

          int playerDestX = nextX;
          int playerDestY = nextY;
          final pTele = getTeleportDestination(playerDestX, playerDestY);
          if (pTele != null) {
            playerDestX = pTele.x;
            playerDestY = pTele.y;
          }
          player.x = playerDestX;
          player.y = playerDestY;
        }
      } else if (rule == 'SWAP') {
        final originalPlayerX = player.x;
        final originalPlayerY = player.y;

        int playerDestX = nextX;
        int playerDestY = nextY;
        int glyphDestX = originalPlayerX;
        int glyphDestY = originalPlayerY;

        final pTele = getTeleportDestination(playerDestX, playerDestY);
        if (pTele != null) {
          playerDestX = pTele.x;
          playerDestY = pTele.y;
        }

        final gTele = getTeleportDestination(glyphDestX, glyphDestY);
        if (gTele != null) {
          glyphDestX = gTele.x;
          glyphDestY = gTele.y;
        }

        final gCell = cells[glyphDestX][glyphDestY];
        if (gCell.isChasm) {
          gCell.isChasm = false;
          glyphs.removeAt(glyphIndex);
          didMerge = true;
        } else {
          glyph.x = glyphDestX;
          glyph.y = glyphDestY;
        }

        player.x = playerDestX;
        player.y = playerDestY;
      }
    } else {
      int playerDestX = nextX;
      int playerDestY = nextY;
      final pTele = getTeleportDestination(playerDestX, playerDestY);
      if (pTele != null) {
        playerDestX = pTele.x;
        playerDestY = pTele.y;
      }
      player.x = playerDestX;
      player.y = playerDestY;
    }

    stepCount++;

    // Process Conveyors
    processConveyors();

    // Scan Triggers (Plates, Spikes, Lasers)
    updateTriggers();

    // Check spikes death
    final currentCell = cells[player.x][player.y];
    if (currentCell.hasSpikes) {
      final isCovered = glyphs.any((g) => g.x == player.x && g.y == player.y);
      if (!isCovered) {
        player.dead = true;
        return MoveResult(
          moved: true,
          won: false,
          merged: didMerge,
          dead: true,
          deadPlayerIds: [player.id],
          playerFinished: false,
          playerId: playerId,
        );
      }
    }

    // Check chasm death
    if (currentCell.isChasm) {
      player.dead = true;
      return MoveResult(
        moved: true,
        won: false,
        merged: didMerge,
        dead: true,
        deadPlayerIds: [player.id],
        playerFinished: false,
        playerId: playerId,
      );
    }

    // Check Exit portal
    final reachedPortal = currentCell.hasPortal || (currentCell.identityPortalPlayer == player.id);
    if (reachedPortal) {
      player.finished = true;
      updateTriggers();
    }

    final deadPlayerIds = players
        .where((p) => p.x != -1 && p.dead)
        .map((p) => p.id)
        .toList(growable: false);
    if (deadPlayerIds.isNotEmpty) {
      return MoveResult(
        moved: true,
        won: false,
        merged: didMerge,
        dead: true,
        deadPlayerIds: deadPlayerIds,
        playerFinished: false,
        playerId: playerId,
      );
    }

    final allFinished = areAllPlayersFinished();
    return MoveResult(
      moved: true,
      won: allFinished,
      merged: didMerge,
      dead: false,
      playerFinished: reachedPortal,
      playerId: player.id,
    );
  }

  bool isPlateActive(String color) {
    final playerOnPlate = players.any((p) => isPlayerActive(p) && cells[p.x][p.y].plateColor == color);
    if (playerOnPlate) return true;

    final glyphOnPlate = glyphs.any((g) => cells[g.x][g.y].plateColor == color);
    return glyphOnPlate;
  }

  bool isGateColorOpen(String color) {
    return isPlateActive(color);
  }

  Map<String, String> getEffectiveRules(Map<String, String> baseRules) {
    final rules = Map<String, String>.from(baseRules);
    for (var g in glyphs) {
      if (g.x >= 0 && g.x < width && g.y >= 0 && g.y < height) {
        if (cells[g.x][g.y].isSensor) {
          final overrideRule = baseRules[g.type] ?? 'STOP';
          for (final color in ['red', 'blue', 'green']) {
            rules[color] = overrideRule;
          }
          break;
        }
      }
    }
    return rules;
  }

  Point<int>? getTeleportDestination(int x, int y) {
    final cell = cells[x][y];
    if (cell.teleportType != 'in') return null;

    Point<int>? bestOut;
    int minDist = 99999;

    for (int tx = 0; tx < width; tx++) {
      for (int ty = 0; ty < height; ty++) {
        if (cells[tx][ty].teleportType == 'out') {
          final hasPlayer = players.any((p) => isPlayerActive(p) && p.x == tx && p.y == ty);
          final hasGlyph = glyphs.any((g) => g.x == tx && g.y == ty);
          if (!hasPlayer && !hasGlyph) {
            final dist = (tx - x).abs() + (ty - y).abs();
            if (dist < minDist) {
              minDist = dist;
              bestOut = Point(tx, ty);
            }
          }
        }
      }
    }
    return bestOut;
  }

  void updateTriggers() {
    updateLasers(stepCount);
  }

  void updateLasers(int currentStepCount) {
    activeLaserBeams.clear();
    activeLaserBeamAxes.clear();
    final pulsingActive = (currentStepCount ~/ 2) % 2 == 0;

    for (int x = 0; x < width; x++) {
      for (int y = 0; y < height; y++) {
        final cell = cells[x][y];
        if (cell.laserType == null) continue;

        bool active = false;
        bool isHorizontal = false;

        if (cell.laserType == 'L') {
          active = true;
          isHorizontal = true;
        } else if (cell.laserType == 'l') {
          active = true;
          isHorizontal = false;
        } else if (cell.laserType == 'P') {
          active = pulsingActive;
          isHorizontal = true;
        } else if (cell.laserType == 'p') {
          active = pulsingActive;
          isHorizontal = false;
        }

        if (!active) continue;

        if (isHorizontal) {
          for (int tx = x - 1; tx >= 0; tx--) {
            if (cells[tx][y].isWall) break;
            _addLaserBeam(tx, y, 'horizontal');
            if (isLaserBlocked(tx, y)) break;
          }
          for (int tx = x + 1; tx < width; tx++) {
            if (cells[tx][y].isWall) break;
            _addLaserBeam(tx, y, 'horizontal');
            if (isLaserBlocked(tx, y)) break;
          }
        } else {
          for (int ty = y - 1; ty >= 0; ty--) {
            if (cells[x][ty].isWall) break;
            _addLaserBeam(x, ty, 'vertical');
            if (isLaserBlocked(x, ty)) break;
          }
          for (int ty = y + 1; ty < height; ty++) {
            if (cells[x][ty].isWall) break;
            _addLaserBeam(x, ty, 'vertical');
            if (isLaserBlocked(x, ty)) break;
          }
        }
      }
    }

    // Kill players on laser paths
    for (var p in players) {
      if (isPlayerActive(p)) {
        if (activeLaserBeams.contains("${p.x},${p.y}")) {
          p.dead = true;
        }
      }
    }
  }

  void _addLaserBeam(int x, int y, String axis) {
    final coord = "$x,$y";
    activeLaserBeams.add(coord);
    activeLaserBeamAxes[coord] = axis;
  }

  bool isLaserBlocked(int x, int y) {
    final cell = cells[x][y];
    if (cell.isWall) return true;
    if (cell.gateColor != null && !isGateColorOpen(cell.gateColor!)) return true;
    if (glyphs.any((g) => g.x == x && g.y == y)) return true;
    return false;
  }

  void processConveyors() {
    bool movedAny = false;
    final Set<String> slidEntities = {};

    for (int pass = 0; pass < 3; pass++) {
      bool passMoved = false;

      // Players conveyor slides
      for (var player in players) {
        if (!isPlayerActive(player) || slidEntities.contains(player.id)) continue;
        final cell = cells[player.x][player.y];
        if (cell.conveyorDir == null) continue;

        final offset = getConveyorOffset(cell.conveyorDir!);
        final targetX = player.x + offset.x;
        final targetY = player.y + offset.y;

        if (isValidSlideTarget(targetX, targetY, player.id)) {
          int finalX = targetX;
          int finalY = targetY;
          final tele = getTeleportDestination(finalX, finalY);
          if (tele != null) {
            finalX = tele.x;
            finalY = tele.y;
          }

          player.x = finalX;
          player.y = finalY;
          slidEntities.add(player.id);
          passMoved = true;
          movedAny = true;

          if (cells[player.x][player.y].isChasm) {
            player.dead = true;
          }
        }
      }

      // Glyphs conveyor slides
      for (int i = 0; i < glyphs.length; i++) {
        final glyph = glyphs[i];
        final glyphKey = "g_${glyph.id}";
        if (slidEntities.contains(glyphKey)) continue;

        final cell = cells[glyph.x][glyph.y];
        if (cell.conveyorDir == null) continue;

        final offset = getConveyorOffset(cell.conveyorDir!);
        final targetX = glyph.x + offset.x;
        final targetY = glyph.y + offset.y;

        if (isValidSlideTarget(targetX, targetY, glyphKey)) {
          int finalX = targetX;
          int finalY = targetY;
          final tele = getTeleportDestination(finalX, finalY);
          if (tele != null) {
            finalX = tele.x;
            finalY = tele.y;
          }

          final destCell = cells[finalX][finalY];
          if (destCell.isChasm) {
            destCell.isChasm = false;
            glyphs.removeAt(i);
            i--;
          } else {
            glyph.x = finalX;
            glyph.y = finalY;
          }
          slidEntities.add(glyphKey);
          passMoved = true;
          movedAny = true;
        }
      }

      if (!passMoved) break;
    }

    if (movedAny) {
      for (var player in players) {
        if (isPlayerActive(player)) {
          final destCell = cells[player.x][player.y];
          if (destCell.hasPortal || (destCell.identityPortalPlayer == player.id)) {
            player.finished = true;
          }
        }
      }
    }
  }

  Point<int> getConveyorOffset(String dir) {
    if (dir == 'L') return const Point(-1, 0);
    if (dir == 'R') return const Point(1, 0);
    if (dir == 'U') return const Point(0, -1);
    if (dir == 'D') return const Point(0, 1);
    return const Point(0, 0);
  }

  bool isValidSlideTarget(int x, int y, String movingEntityKey) {
    if (x < 0 || x >= width || y < 0 || y >= height) return false;
    final cell = cells[x][y];
    if (cell.isWall) return false;
    if (cell.gateColor != null && !isGateColorOpen(cell.gateColor!)) return false;

    // Identity portal check
    if (cell.identityPortalPlayer != null) {
      if (movingEntityKey.startsWith("g_")) return false;
      if (cell.identityPortalPlayer != movingEntityKey) return false;
    }

    final playerAt = players.firstWhere(
      (p) => isPlayerActive(p) && p.x == x && p.y == y,
      orElse: () => Player(id: '', label: '', x: -1, y: -1),
    );
    if (playerAt.id.isNotEmpty && playerAt.id != movingEntityKey) {
      if (cells[playerAt.x][playerAt.y].conveyorDir == null) return false;
    }

    final glyphAt = glyphs.firstWhere(
      (g) => g.x == x && g.y == y,
      orElse: () => Glyph(id: -1, type: '', x: -1, y: -1),
    );
    if (glyphAt.id != -1 && "g_${glyphAt.id}" != movingEntityKey) {
      if (cells[glyphAt.x][glyphAt.y].conveyorDir == null) return false;
    }

    return true;
  }

  bool areAllPlayersFinished() {
    int activeCount = 0;
    int finishedCount = 0;
    for (var p in players) {
      if (p.x != -1) {
        activeCount++;
        if (p.finished) {
          finishedCount++;
        }
      }
    }
    return activeCount > 0 && activeCount == finishedCount;
  }

  bool hasAnyPlayerDead() {
    return players.any((p) => p.x != -1 && p.dead);
  }

  Map<String, dynamic> getStateSnapshot() {
    return {
      'players': players.map((p) => {
        'id': p.id,
        'x': p.x,
        'y': p.y,
        'dead': p.dead,
        'finished': p.finished,
      }).toList(),
      'glyphs': glyphs.map((g) => {
        'id': g.id,
        'type': g.type,
        'x': g.x,
        'y': g.y,
      }).toList(),
      'stepCount': stepCount,
      'chasms': cells.map((row) => row.map((c) => c.isChasm).toList()).toList(),
    };
  }

  void restoreState(Map<String, dynamic> snapshot) {
    stepCount = snapshot['stepCount'] as int;

    final playersList = snapshot['players'] as List;
    for (var pSnap in playersList) {
      final pMap = pSnap as Map<String, dynamic>;
      final pObj = getPlayer(pMap['id'] as String);
      pObj.x = pMap['x'] as int;
      pObj.y = pMap['y'] as int;
      pObj.dead = pMap['dead'] as bool;
      pObj.finished = pMap['finished'] as bool;
    }

    final glyphsList = snapshot['glyphs'] as List;
    glyphs = glyphsList.map((gSnap) {
      final gMap = gSnap as Map<String, dynamic>;
      return Glyph(
        id: gMap['id'] as int,
        type: gMap['type'] as String,
        x: gMap['x'] as int,
        y: gMap['y'] as int,
      );
    }).toList();

    final chasmsMatrix = snapshot['chasms'] as List;
    for (int x = 0; x < width; x++) {
      final colList = chasmsMatrix[x] as List;
      for (int y = 0; y < height; y++) {
        cells[x][y].isChasm = colList[y] as bool;
      }
    }

    updateTriggers();
  }
}
