import 'dart:ui';
import 'package:flutter/material.dart';

class RulesPanel extends StatelessWidget {
  final String levelName;
  final String levelProgress;
  final int movesLeft;
  final int movesLimit;
  final bool undoEnabled;
  final VoidCallback onBack;
  final VoidCallback onUndo;
  final VoidCallback onReset;
  final bool isLeft; // Whether it is placed on the left side of the screen

  final Map<String, String> activeRules;
  final Map<String, List<String>> allowedRules;
  final Map<String, int?> ruleExpiryCounters;
  final Function(String color, String rule) onRuleSelected;

  const RulesPanel({
    Key? key,
    required this.levelName,
    required this.levelProgress,
    required this.movesLeft,
    required this.movesLimit,
    required this.undoEnabled,
    required this.onBack,
    required this.onUndo,
    required this.onReset,
    this.isLeft = false,
    required this.activeRules,
    required this.allowedRules,
    required this.ruleExpiryCounters,
    required this.onRuleSelected,
  }) : super(key: key);

  Color _getColorTheme(String color) {
    if (color == 'red') return Colors.redAccent;
    if (color == 'blue') return Colors.blueAccent;
    if (color == 'green') return Colors.greenAccent;
    return Colors.white;
  }

  Widget _buildTopSection(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: onBack,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 14),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                levelName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                levelProgress,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMovesCounter(BuildContext context) {
    final activeExpiries = ruleExpiryCounters.entries
        .where((e) => e.value != null)
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withOpacity(0.03), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "MOVES REMAINING",
            style: TextStyle(
              color: Colors.white38,
              fontSize: 6.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            "$movesLeft / $movesLimit",
            style: TextStyle(
              color: movesLeft <= 2 
                  ? Colors.redAccent 
                  : (movesLeft <= 5 ? Colors.orangeAccent : Colors.white),
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
          if (activeExpiries.isNotEmpty) ...[
            const SizedBox(height: 4),
            Divider(color: Colors.white.withOpacity(0.08), height: 4, thickness: 0.8),
            const SizedBox(height: 2),
            Wrap(
              spacing: 6,
              runSpacing: 2,
              children: activeExpiries.map((entry) {
                final colorName = entry.key;
                final count = entry.value;
                final themeColor = _getColorTheme(colorName);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: themeColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      "${colorName.toUpperCase()}: $count",
                      style: const TextStyle(
                        color: Colors.yellowAccent,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    return Row(
      children: [
        // Undo Button
        Expanded(
          child: InkWell(
            onTap: undoEnabled ? onUndo : null,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: undoEnabled ? Colors.cyanAccent.withOpacity(0.06) : Colors.transparent,
                border: Border.all(
                  color: undoEnabled ? Colors.cyanAccent.withOpacity(0.24) : Colors.white.withOpacity(0.03),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.undo,
                    color: undoEnabled ? Colors.cyanAccent : Colors.white10,
                    size: 12,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    "UNDO",
                    style: TextStyle(
                      color: undoEnabled ? Colors.white : Colors.white24,
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Reset Button
        Expanded(
          child: InkWell(
            onTap: onReset,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withOpacity(0.06),
                border: Border.all(
                  color: Colors.orangeAccent.withOpacity(0.24),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.refresh,
                    color: Colors.orangeAccent,
                    size: 12,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    "RESET",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRuleRow(BuildContext context, String color) {
    final themeColor = _getColorTheme(color);
    final currentRule = activeRules[color] ?? 'STOP';
    final allowedList = allowedRules[color] ?? ['STOP'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Color Label (e.g. RED, BLUE, GREEN) with Indicator Dot
          Container(
            width: 42,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: themeColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: themeColor, blurRadius: 3, spreadRadius: 0.5)
                    ],
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  color.toUpperCase(),
                  style: TextStyle(
                    color: themeColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                    fontSize: 8.5,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 6),
          
          // Buttons list
          Wrap(
            spacing: 2,
            runSpacing: 2,
            children: allowedList.map((rule) {
              final isSelected = rule == currentRule;
              return InkWell(
                onTap: () => onRuleSelected(color, rule),
                borderRadius: BorderRadius.circular(5),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? themeColor.withOpacity(0.18) 
                        : Colors.white.withOpacity(0.02),
                    border: Border.all(
                      color: isSelected 
                          ? themeColor.withOpacity(0.8) 
                          : Colors.white.withOpacity(0.08),
                      width: 0.8,
                    ),
                    borderRadius: BorderRadius.circular(5),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: themeColor.withOpacity(0.12),
                        blurRadius: 3,
                      )
                    ] : null,
                  ),
                  child: Text(
                    rule,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white54,
                      fontSize: 9,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = isLeft
        ? const BorderRadius.only(
            topRight: Radius.circular(12),
            bottomRight: Radius.circular(12),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(12),
            bottomLeft: Radius.circular(12),
          );

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Container(
          height: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.36),
            border: Border(
              left: isLeft ? BorderSide.none : BorderSide(color: Colors.white.withOpacity(0.08), width: 1.2),
              right: isLeft ? BorderSide(color: Colors.white.withOpacity(0.08), width: 1.2) : BorderSide.none,
              top: BorderSide(color: Colors.white.withOpacity(0.08), width: 1.2),
              bottom: BorderSide(color: Colors.white.withOpacity(0.08), width: 1.2),
            ),
            borderRadius: borderRadius,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Section: Back button, Level name, Level progress
              _buildTopSection(context),
              
              const SizedBox(height: 12),
              
              // 2. Moves Counter
              _buildMovesCounter(context),
              
              const Spacer(),
              
              // 3. Middle Section: RED, BLUE, GREEN rules
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "ACTIVE RULES",
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 7.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildRuleRow(context, 'red'),
                  const SizedBox(height: 3),
                  _buildRuleRow(context, 'blue'),
                  const SizedBox(height: 3),
                  _buildRuleRow(context, 'green'),
                ],
              ),
              
              const Spacer(),
              
              // 4. Bottom Section: Action buttons (Undo & Reset)
              _buildBottomActions(context),
            ],
          ),
        ),
      ),
    );
  }
}
