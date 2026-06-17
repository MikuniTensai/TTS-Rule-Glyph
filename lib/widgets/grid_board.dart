import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../engine/game_engine.dart';

class GridBoard extends StatelessWidget {
  final GameEngine engine;

  const GridBoard({Key? key, required this.engine}) : super(key: key);

  Color _getColorTheme(String color) {
    if (color == 'red') return Colors.redAccent;
    if (color == 'blue') return Colors.blueAccent;
    if (color == 'green') return Colors.greenAccent;
    return Colors.white;
  }

  Color _getPlayerColor(String id) {
    if (id == 'p1') return Colors.cyanAccent;
    if (id == 'p2') return Colors.orangeAccent;
    if (id == 'p3') return Colors.pinkAccent;
    if (id == 'p4') return Colors.purpleAccent;
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    if (engine.width == 0 || engine.height == 0) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate the maximum possible size for each tile to fit the constraints
        final double tileSize = math.min(
          constraints.maxWidth / engine.width,
          constraints.maxHeight / engine.height,
        );

        final double boardWidth = tileSize * engine.width;
        final double boardHeight = tileSize * engine.height;

        return Center(
          child: Container(
            width: boardWidth,
            height: boardHeight,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              border: Border.all(color: Colors.white.withOpacity(0.08), width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              children: [
                // 1. Render Background Grid Cells
                for (int x = 0; x < engine.width; x++)
                  for (int y = 0; y < engine.height; y++)
                    Positioned(
                      left: x * tileSize,
                      top: y * tileSize,
                      width: tileSize,
                      height: tileSize,
                      child: _buildGridCell(x, y, tileSize),
                    ),

                // 2. Render Static Entities (Plates, Gates, Spikes, Chasms, Emitters, Conveyors, Portals)
                for (int x = 0; x < engine.width; x++)
                  for (int y = 0; y < engine.height; y++)
                    ..._buildCellDecorations(x, y, tileSize),

                // 3. Render Active Laser Beams
                for (final coord in engine.activeLaserBeams)
                  ..._buildLaserBeam(
                    coord,
                    tileSize,
                    engine.activeLaserBeamAxes[coord] ?? 'horizontal',
                  ),

                // 4. Render Dynamic Glyphs
                for (var glyph in engine.glyphs)
                  AnimatedPositioned(
                    key: ValueKey('glyph_${glyph.id}'),
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    left: glyph.x * tileSize,
                    top: glyph.y * tileSize,
                    width: tileSize,
                    height: tileSize,
                    child: Padding(
                      padding: EdgeInsets.all(tileSize * 0.1),
                      child: _buildGlyphWidget(glyph, tileSize),
                    ),
                  ),

                // 5. Render Players
                for (var player in engine.players)
                  if (player.x != -1)
                    AnimatedPositioned(
                      key: ValueKey('player_${player.id}'),
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOut,
                      left: player.x * tileSize,
                      top: player.y * tileSize,
                      width: tileSize,
                      height: tileSize,
                      child: Padding(
                        padding: EdgeInsets.all(tileSize * 0.08),
                        child: _buildPlayerWidget(player, tileSize),
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridCell(int x, int y, double tileSize) {
    final cell = engine.cells[x][y];
    if (cell.isWall) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF26262B),
          border: Border.all(color: Colors.black, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 4,
            )
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131317),
        border: Border.all(color: Colors.white.withOpacity(0.02), width: 0.5),
      ),
    );
  }

  List<Widget> _buildCellDecorations(int x, int y, double tileSize) {
    final List<Widget> decos = [];
    final cell = engine.cells[x][y];

    // Spikes
    if (cell.hasSpikes) {
      final isCovered = engine.glyphs.any((g) => g.x == x && g.y == y);
      decos.add(
        Positioned(
          left: x * tileSize,
          top: y * tileSize,
          width: tileSize,
          height: tileSize,
          child: Center(
            child: Icon(
              Icons.warning_amber_rounded,
              color: isCovered ? Colors.green.withOpacity(0.3) : Colors.redAccent.withOpacity(0.6),
              size: tileSize * 0.6,
            ),
          ),
        ),
      );
    }

    // Chasms
    if (cell.isChasm) {
      decos.add(
        Positioned(
          left: x * tileSize,
          top: y * tileSize,
          width: tileSize,
          height: tileSize,
          child: Container(
            margin: EdgeInsets.all(tileSize * 0.08),
            decoration: BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.purple.withOpacity(0.3), width: 1.5),
            ),
          ),
        ),
      );
    }

    // Plates
    if (cell.plateColor != null) {
      final themeColor = _getColorTheme(cell.plateColor!);
      final isActive = engine.isPlateActive(cell.plateColor!);
      decos.add(
        Positioned(
          left: x * tileSize,
          top: y * tileSize,
          width: tileSize,
          height: tileSize,
          child: Center(
            child: Container(
              width: tileSize * 0.56,
              height: tileSize * 0.56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: themeColor, width: 2),
                color: isActive ? themeColor.withOpacity(0.3) : Colors.transparent,
                boxShadow: isActive ? [
                  BoxShadow(color: themeColor, blurRadius: 10, spreadRadius: 1)
                ] : null,
              ),
              child: Center(
                child: Container(
                  width: tileSize * 0.16,
                  height: tileSize * 0.16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: themeColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Gates
    if (cell.gateColor != null) {
      final themeColor = _getColorTheme(cell.gateColor!);
      final isOpen = engine.isGateColorOpen(cell.gateColor!);
      decos.add(
        Positioned(
          left: x * tileSize,
          top: y * tileSize,
          width: tileSize,
          height: tileSize,
          child: Container(
            margin: EdgeInsets.all(tileSize * 0.06),
            decoration: BoxDecoration(
              border: Border.all(
                color: isOpen ? themeColor.withOpacity(0.25) : themeColor,
                width: 2.5,
              ),
              borderRadius: BorderRadius.circular(4),
              color: isOpen ? Colors.transparent : themeColor.withOpacity(0.12),
            ),
            child: isOpen 
                ? null 
                : Center(
                    child: Icon(Icons.lock_outline, color: themeColor, size: tileSize * 0.4),
                  ),
          ),
        ),
      );
    }

    // Portal (Exit)
    if (cell.hasPortal) {
      decos.add(
        Positioned(
          left: x * tileSize,
          top: y * tileSize,
          width: tileSize,
          height: tileSize,
          child: Center(
            child: Container(
              width: tileSize * 0.68,
              height: tileSize * 0.68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.greenAccent, width: 2),
                boxShadow: [
                  BoxShadow(color: Colors.greenAccent.withOpacity(0.3), blurRadius: 8, spreadRadius: 1)
                ],
              ),
              child: const Center(
                child: Icon(Icons.cyclone, color: Colors.greenAccent, size: 20),
              ),
            ),
          ),
        ),
      );
    }

    // Emitters
    if (cell.laserType != null) {
      decos.add(
        Positioned(
          left: x * tileSize,
          top: y * tileSize,
          width: tileSize,
          height: tileSize,
          child: Container(
            margin: EdgeInsets.all(tileSize * 0.1),
            decoration: BoxDecoration(
              color: const Color(0xFF3B3B45),
              border: Border.all(color: Colors.white30, width: 1.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Center(
              child: Icon(Icons.wb_sunny_rounded, color: Colors.yellowAccent, size: 14),
            ),
          ),
        ),
      );
    }

    // Teleports
    if (cell.teleportType != null) {
      final isIn = cell.teleportType == 'in';
      decos.add(
        Positioned(
          left: x * tileSize,
          top: y * tileSize,
          width: tileSize,
          height: tileSize,
          child: Center(
            child: Icon(
              isIn ? Icons.login_rounded : Icons.logout_rounded,
              color: isIn ? Colors.indigoAccent : Colors.tealAccent,
              size: tileSize * 0.5,
            ),
          ),
        ),
      );
    }

    // Conveyors
    if (cell.conveyorDir != null) {
      IconData arrowIcon = Icons.arrow_forward;
      if (cell.conveyorDir == 'L') arrowIcon = Icons.arrow_back;
      if (cell.conveyorDir == 'U') arrowIcon = Icons.arrow_upward;
      if (cell.conveyorDir == 'D') arrowIcon = Icons.arrow_downward;

      decos.add(
        Positioned(
          left: x * tileSize,
          top: y * tileSize,
          width: tileSize,
          height: tileSize,
          child: Center(
            child: Icon(
              arrowIcon,
              color: Colors.white12,
              size: tileSize * 0.45,
            ),
          ),
        ),
      );
    }

    // Identity Portals
    if (cell.identityPortalPlayer != null) {
      final playerColor = _getPlayerColor(cell.identityPortalPlayer!);
      decos.add(
        Positioned(
          left: x * tileSize,
          top: y * tileSize,
          width: tileSize,
          height: tileSize,
          child: Center(
            child: Container(
              width: tileSize * 0.68,
              height: tileSize * 0.68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: playerColor, width: 2),
                boxShadow: [
                  BoxShadow(color: playerColor.withOpacity(0.2), blurRadius: 6)
                ],
              ),
              child: Center(
                child: Text(
                  cell.identityPortalPlayer!.toUpperCase(),
                  style: TextStyle(color: playerColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Sensors
    if (cell.isSensor) {
      decos.add(
        Positioned(
          left: x * tileSize,
          top: y * tileSize,
          width: tileSize,
          height: tileSize,
          child: Container(
            margin: EdgeInsets.all(tileSize * 0.04),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.amberAccent.withOpacity(0.3), width: 1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Icon(Icons.developer_board, color: Colors.amberAccent.withOpacity(0.3), size: 16),
            ),
          ),
        ),
      );
    }

    // Jammers
    if (cell.isJammer) {
      decos.add(
        Positioned(
          left: x * tileSize,
          top: y * tileSize,
          width: tileSize,
          height: tileSize,
          child: Container(
            margin: EdgeInsets.all(tileSize * 0.04),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.redAccent.withOpacity(0.2), width: 1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Icon(Icons.portable_wifi_off_rounded, color: Colors.redAccent.withOpacity(0.2), size: 16),
            ),
          ),
        ),
      );
    }

    return decos;
  }

  List<Widget> _buildLaserBeam(String coordStr, double tileSize, String axis) {
    final List<int> coord = coordStr.split(',').map(int.parse).toList();
    final int x = coord[0];
    final int y = coord[1];
    final bool isVertical = axis == 'vertical';

    return [
      Positioned(
        left: x * tileSize,
        top: y * tileSize,
        width: tileSize,
        height: tileSize,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.24),
          ),
          child: Center(
            child: Container(
              width: isVertical ? 4 : tileSize,
              height: isVertical ? tileSize : 4,
              color: Colors.redAccent,
            ),
          ),
        ),
      )
    ];
  }

  Widget _buildPlayerWidget(Player player, double tileSize) {
    final playerColor = _getPlayerColor(player.id);
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        shape: BoxShape.circle,
        border: Border.all(color: playerColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: playerColor.withOpacity(0.4),
            blurRadius: 10,
            spreadRadius: 1,
          )
        ],
      ),
      child: Center(
        child: Text(
          player.label,
          style: TextStyle(
            color: playerColor,
            fontWeight: FontWeight.bold,
            fontSize: tileSize * 0.32,
          ),
        ),
      ),
    );
  }

  Widget _buildGlyphWidget(Glyph glyph, double tileSize) {
    if (glyph.type == 'heavy-2' || glyph.type == 'heavy-3') {
      final reqPlayers = glyph.type == 'heavy-2' ? 2 : 3;
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2C2F36),
          border: Border.all(color: Colors.grey, width: 2),
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
            )
          ],
        ),
        child: Center(
          child: Text(
            "H$reqPlayers",
            style: TextStyle(
              color: Colors.grey[400],
              fontWeight: FontWeight.bold,
              fontSize: tileSize * 0.28,
            ),
          ),
        ),
      );
    }

    final themeColor = _getColorTheme(glyph.type);
    String letter = "α";
    if (glyph.type == 'blue') letter = "β";
    if (glyph.type == 'green') letter = "γ";

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        border: Border.all(color: themeColor, width: 2),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.24),
            blurRadius: 8,
          )
        ],
      ),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            color: themeColor,
            fontWeight: FontWeight.bold,
            fontSize: tileSize * 0.38,
          ),
        ),
      ),
    );
  }
}
