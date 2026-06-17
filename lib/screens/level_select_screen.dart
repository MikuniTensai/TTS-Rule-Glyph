import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../audio/audio_manager.dart';
import '../data/levels_data.dart';
import '../engine/local_network_controller.dart';
import 'game_screen.dart';

class LevelSelectScreen extends StatefulWidget {
  final String mode; // '1', '2', '3', '4'

  const LevelSelectScreen({
    Key? key,
    required this.mode,
  }) : super(key: key);

  @override
  _LevelSelectScreenState createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  int _maxUnlockedIdx = 0;
  int _selectedChapterIdx = 0;
  bool _isLoading = true;

  late List<LevelData> _levelList;
  late String _progressKey;

  // Chapter classification for Single Player
  // Bab 1 has index 0-21 (22 levels).
  // Chapters 2-9 are defined in EXTRA_CHAPTERS. Each has 12 levels (ADVANCED_LEVELS.length = 12).
  final List<String> _chapterNames = [
    "Bab 1: Langkah Pertama",
    "Bab 2: Rute Lanjutan",
    "Bab 3: Rute Padat",
    "Bab 4: Jalur Tajam",
    "Bab 5: Audit Cepat",
    "Bab 6: Hampir Presisi",
    "Bab 7: Presisi",
    "Bab 8: Master",
    "Finale",
  ];

  @override
  void initState() {
    super.initState();
    
    _levelList = LEVELS_BY_MODE[widget.mode] ?? LEVELS;
    _progressKey = "max_unlocked_level_idx_${widget.mode}";
    
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _maxUnlockedIdx = prefs.getInt(_progressKey) ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<int> _getLevelIndicesForChapter(int chapIdx) {
    if (widget.mode != '1') {
      // For coop modes, display all levels in one single chapter
      return List.generate(_levelList.length, (i) => i);
    }

    if (chapIdx == 0) {
      // Bab 1: Base Levels (index 0 to 21)
      return List.generate(BASE_LEVELS.length, (i) => i);
    } else {
      // Advanced chapters (each has 12 levels)
      final int startIdx = BASE_LEVELS.length + (chapIdx - 1) * ADVANCED_LEVELS.length;
      return List.generate(ADVANCED_LEVELS.length, (i) => startIdx + i);
    }
  }

  void _onLevelTapped(int levelIdx) {
    if (levelIdx > _maxUnlockedIdx) {
      AudioManager.instance.playFail();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Level ini masih terkunci! Selesaikan level sebelumnya."),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    AudioManager.instance.playRuleChange();
    
    // Navigate to gameplay screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GameScreen(
          mode: widget.mode,
          networkRole: NetworkRole.none,
          startLevelIdx: levelIdx,
        ),
      ),
    ).then((_) => _loadProgress());
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF09090C),
        body: Center(
          child: CircularProgressIndicator(color: Colors.cyanAccent),
        ),
      );
    }

    final String titleStr = widget.mode == '1' 
        ? "SURVIVAL MODE - PILIH LEVEL" 
        : "COOP LOCAL NET - PILIH LEVEL";

    // For coop mode, we only have 1 chapter
    final chaptersCount = widget.mode == '1' ? _chapterNames.length : 1;

    return Scaffold(
      backgroundColor: const Color(0xFF09090C),
      body: Stack(
        children: [
          // Background Glows
          Positioned(
            left: -100,
            top: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyanAccent.withOpacity(0.02),
                    blurRadius: 120,
                    spreadRadius: 60,
                  )
                ],
              ),
            ),
          ),
          Positioned(
            right: -100,
            bottom: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.pinkAccent.withOpacity(0.02),
                    blurRadius: 120,
                    spreadRadius: 60,
                  )
                ],
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Header Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          AudioManager.instance.playRuleChange();
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        titleStr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Chapter & Level Selector Body
                Expanded(
                  child: Row(
                    children: [
                      // 1. Sidebar - Chapter List
                      Container(
                        width: 220,
                        padding: const EdgeInsets.only(left: 24, right: 8, bottom: 16),
                        child: ListView.builder(
                          itemCount: chaptersCount,
                          itemBuilder: (context, index) {
                            final bool isSelected = index == _selectedChapterIdx;
                            final String chapName = widget.mode == '1' 
                                ? _chapterNames[index] 
                                : "Level Utama";
                                
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: InkWell(
                                onTap: () {
                                  AudioManager.instance.playRuleChange();
                                  setState(() {
                                    _selectedChapterIdx = index;
                                  });
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected 
                                        ? Colors.cyanAccent.withOpacity(0.08) 
                                        : Colors.white.withOpacity(0.02),
                                    border: Border.all(
                                      color: isSelected 
                                          ? Colors.cyanAccent.withOpacity(0.4) 
                                          : Colors.white.withOpacity(0.05),
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    chapName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isSelected ? Colors.cyanAccent : Colors.white70,
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      
                      // 2. Main Area - Grid of Level buttons
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 24, bottom: 16, left: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.25),
                                  border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.all(16),
                                child: _buildLevelsGrid(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelsGrid() {
    final List<int> levelIndices = _getLevelIndicesForChapter(_selectedChapterIdx);
    
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 64,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.0,
      ),
      itemCount: levelIndices.length,
      itemBuilder: (context, index) {
        final int levelIdx = levelIndices[index];
        final level = _levelList[levelIdx];
        
        final bool isUnlocked = levelIdx <= _maxUnlockedIdx;
        final bool isCompleted = levelIdx < _maxUnlockedIdx;
        
        Color buttonColor = Colors.white.withOpacity(0.03);
        Color borderColor = Colors.white.withOpacity(0.1);
        Color textColor = Colors.white38;
        
        if (isUnlocked) {
          if (isCompleted) {
            buttonColor = Colors.greenAccent.withOpacity(0.06);
            borderColor = Colors.greenAccent.withOpacity(0.4);
            textColor = Colors.greenAccent;
          } else {
            // Unlocked but not cleared yet (current level)
            buttonColor = Colors.cyanAccent.withOpacity(0.08);
            borderColor = Colors.cyanAccent.withOpacity(0.6);
            textColor = Colors.cyanAccent;
          }
        }
        
        return InkWell(
          onTap: () => _onLevelTapped(levelIdx),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              color: buttonColor,
              border: Border.all(color: borderColor, width: 1.2),
              borderRadius: BorderRadius.circular(10),
              boxShadow: (isUnlocked && !isCompleted) ? [
                BoxShadow(
                  color: Colors.cyanAccent.withOpacity(0.08),
                  blurRadius: 4,
                )
              ] : null,
            ),
            child: Center(
              child: isUnlocked 
                  ? Text(
                      "${level.id}",
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    )
                  : Icon(
                      Icons.lock_outline,
                      color: Colors.white.withOpacity(0.2),
                      size: 16,
                    ),
            ),
          ),
        );
      },
    );
  }
}
