import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../audio/audio_manager.dart';
import '../data/levels_data.dart';
import '../engine/game_engine.dart';
import '../engine/local_network_controller.dart';
import '../widgets/dpad.dart';
import '../widgets/grid_board.dart';
import '../widgets/rules_panel.dart';

class GameScreen extends StatefulWidget {
  final String mode; // '1' (Solo), '2', '3', '4' (Coop)
  final NetworkRole networkRole;
  final LocalNetworkController? networkController;
  final int startLevelIdx;

  final String localPlayerName;
  final String? localPlayerAvatar;
  final String? peerPlayerName;
  final String? peerPlayerAvatar;

  const GameScreen({
    Key? key,
    required this.mode,
    this.networkRole = NetworkRole.none,
    this.networkController,
    this.startLevelIdx = 0,
    this.localPlayerName = "Player",
    this.localPlayerAvatar,
    this.peerPlayerName,
    this.peerPlayerAvatar,
  }) : super(key: key);

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameEngine _engine;
  late List<LevelData> _levelList;
  int _currentLevelIdx = 0;

  double _dpadScale = 1.0;
  String _dpadLocation = 'left';

  // Active rules config state
  Map<String, String> _activeRules = {
    'red': 'STOP',
    'blue': 'STOP',
    'green': 'STOP',
  };
  Map<String, int?> _ruleExpiryCounters = {
    'red': null,
    'blue': null,
    'green': null,
  };

  int _movesLeft = 15;
  int _movesLimit = 15;
  final List<Map<String, dynamic>> _undoStack = [];

  StreamSubscription? _netSubscription;
  StreamSubscription? _connSubscription;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _engine = GameEngine();

    _levelList = LEVELS_BY_MODE[widget.mode] ?? LEVELS;
    _currentLevelIdx = widget.startLevelIdx;

    _loadLevel(_currentLevelIdx);
    _loadControlSettings();
    AudioManager.instance.startBackgroundMusic();

    // Setup network listener if multiplayer
    if (widget.networkRole != NetworkRole.none && widget.networkController != null) {
      _netSubscription = widget.networkController!.messageStream.listen(_handleNetworkMessage);
      _connSubscription = widget.networkController!.connectionStateStream.listen((connected) {
        if (!connected && !_isDisposed) {
          _showDisconnectDialog();
        }
      });
    }
  }

  void _loadControlSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _dpadScale = prefs.getDouble('control_scale') ?? 1.0;
      _dpadLocation = prefs.getString('control_location') ?? 'left';
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _netSubscription?.cancel();
    _connSubscription?.cancel();
    if (widget.networkController != null) {
      widget.networkController!.shutdown();
    }
    super.dispose();
  }

  void _loadLevel(int index) {
    if (index < 0 || index >= _levelList.length) return;
    
    final level = _levelList[index];
    _engine.loadLevel(level);

    _activeRules = Map<String, String>.from(level.initialRules);
    _ruleExpiryCounters = {
      'red': _activeRules['red'] != 'STOP' ? 5 : null,
      'blue': _activeRules['blue'] != 'STOP' ? 5 : null,
      'green': _activeRules['green'] != 'STOP' ? 5 : null,
    };

    // Determine P2 presence for coop move limits
    final hasP2 = _engine.players.any((p) => p.id == 'p2' && p.x != -1);
    if (hasP2) {
      _movesLimit = level.movesLimit;
    } else {
      _movesLimit = level.movesLimit;
    }
    _movesLeft = _movesLimit;
    _undoStack.clear();

    if (mounted) {
      setState(() {});
    }
  }

  void _pushUndoSnapshot() {
    _undoStack.add({
      'rules': Map<String, String>.from(_activeRules),
      'expiries': Map<String, int?>.from(_ruleExpiryCounters),
      'movesLeft': _movesLeft,
      'engine': _engine.getStateSnapshot(),
    });
  }

  void _performLocalMove(int dx, int dy) {
    // Determine active player tag
    String activePlayerId = 'p1';
    
    if (widget.networkRole == NetworkRole.client) {
      // In local multi-device network client, we default to controlling P2
      activePlayerId = 'p2';
    }

    if (!_engine.isGameActive || _engine.hasAnyPlayerDead() || _movesLeft <= 0) return;
    final p = _engine.getPlayer(activePlayerId);
    if (!_engine.isPlayerActive(p)) return;

    _pushUndoSnapshot();

    final res = _engine.tryMove(dx, dy, _activeRules, playerId: activePlayerId);
    if (res.moved) {
      if (res.moveCost > _movesLeft) {
        final snap = _undoStack.removeLast();
        _activeRules = snap['rules'] as Map<String, String>;
        _ruleExpiryCounters = snap['expiries'] as Map<String, int?>;
        _movesLeft = snap['movesLeft'] as int;
        _engine.restoreState(snap['engine'] as Map<String, dynamic>);
        _handleOutOfSteps();
        setState(() {});
        return;
      }

      _movesLeft -= res.moveCost;
      _decayRules();

      if (widget.networkController != null && widget.networkController!.isConnected) {
        widget.networkController!.sendMessage(NetworkMessage('move', {
          'dx': dx,
          'dy': dy,
          'playerId': activePlayerId,
          'rules': _activeRules,
          'expiries': _ruleExpiryCounters,
          'moveCost': res.moveCost,
        }));
      }

      _checkMoveResult(res);
      AudioManager.instance.playMove();
    } else {
      _undoStack.removeLast();
    }

    setState(() {});
  }

  void _decayRules() {
    bool didRevert = false;
    for (final color in ['red', 'blue', 'green']) {
      if (_ruleExpiryCounters[color] != null) {
        _ruleExpiryCounters[color] = _ruleExpiryCounters[color]! - 1;
        if (_ruleExpiryCounters[color]! <= 0) {
          _activeRules[color] = 'STOP';
          _ruleExpiryCounters[color] = null;
          didRevert = true;
        }
      }
    }
    if (didRevert) {
      AudioManager.instance.playRuleChange();
    }
  }

  void _checkMoveResult(MoveResult res) {
    if (res.dead || res.deadPlayerIds.isNotEmpty) {
      _handleDeath();
    } else if (res.won) {
      _handleWin();
    } else if (_movesLeft <= 0) {
      _handleOutOfSteps();
    }
  }

  void _saveProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String progressKey = "max_unlocked_level_idx_${widget.mode}";
      final currentSaved = prefs.getInt(progressKey) ?? 0;
      if (_currentLevelIdx + 1 > currentSaved) {
        await prefs.setInt(progressKey, _currentLevelIdx + 1);
      }
    } catch (e) {
      // ignore failures
    }
  }

  void _handleWin() {
    _saveProgress();
    AudioManager.instance.playWin();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF131317),
        title: const Text("Success!", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
        content: const Text("Level cleared successfully!", style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (_currentLevelIdx + 1 < _levelList.length) {
                _currentLevelIdx++;
                _loadLevel(_currentLevelIdx);
                
                // Sync next level to network partner if hosting
                if (widget.networkRole == NetworkRole.host && widget.networkController != null) {
                  widget.networkController!.sendMessage(NetworkMessage('level', {'index': _currentLevelIdx}));
                }
              } else {
                Navigator.of(context).pop(); // Back to level select
              }
            },
            child: const Text("Next Level", style: TextStyle(color: Colors.cyanAccent)),
          )
        ],
      ),
    );
  }

  void _handleDeath() {
    AudioManager.instance.playFail();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Pemain mati terkena duri/laser! Silakan undo atau restart."),
        backgroundColor: Colors.redAccent,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _handleOutOfSteps() {
    AudioManager.instance.playFail();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Batas langkah habis!"),
        backgroundColor: Colors.orangeAccent,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _handleNetworkMessage(NetworkMessage msg) {
    if (msg.type == 'move') {
      final data = msg.data;
      final dx = data['dx'] as int;
      final dy = data['dy'] as int;
      final playerId = data['playerId'] as String;

      // Sync rules state from partner before executing target move
      final syncRules = Map<String, String>.from(data['rules'] as Map);
      final syncExpiries = (data['expiries'] as Map).map((k, v) => MapEntry(k as String, v as int?));
      
      _activeRules = syncRules;
      _ruleExpiryCounters = syncExpiries;

      _pushUndoSnapshot();
      final res = _engine.tryMove(dx, dy, _activeRules, playerId: playerId);
      
      if (res.moved) {
        final moveCost = data['moveCost'];
        final appliedMoveCost = moveCost is int ? moveCost : res.moveCost;
        if (appliedMoveCost > _movesLeft) {
          final snap = _undoStack.removeLast();
          _activeRules = snap['rules'] as Map<String, String>;
          _ruleExpiryCounters = snap['expiries'] as Map<String, int?>;
          _movesLeft = snap['movesLeft'] as int;
          _engine.restoreState(snap['engine'] as Map<String, dynamic>);
          _handleOutOfSteps();
          setState(() {});
          return;
        }

        _movesLeft -= appliedMoveCost;
        _checkMoveResult(res);
        AudioManager.instance.playMove();
      } else {
        _undoStack.removeLast();
      }
    } else if (msg.type == 'rule') {
      final data = msg.data;
      final color = data['color'] as String;
      final rule = data['rule'] as String;
      
      _pushUndoSnapshot();
      _activeRules[color] = rule;
      _ruleExpiryCounters[color] = rule != 'STOP' ? 5 : null;
      _engine.updateTriggers();
      AudioManager.instance.playRuleChange();
    } else if (msg.type == 'level') {
      final index = msg.data['index'] as int;
      _currentLevelIdx = index;
      _loadLevel(index);
    } else if (msg.type == 'reset') {
      _loadLevel(_currentLevelIdx);
    } else if (msg.type == 'undo') {
      _performUndo(local: false);
    }
    
    setState(() {});
  }

  void _performUndo({bool local = true}) {
    if (_undoStack.isEmpty) return;
    
    final snap = _undoStack.removeLast();
    _activeRules = snap['rules'] as Map<String, String>;
    _ruleExpiryCounters = snap['expiries'] as Map<String, int?>;
    _movesLeft = snap['movesLeft'] as int;
    
    _engine.restoreState(snap['engine'] as Map<String, dynamic>);
    AudioManager.instance.playUndo();

    if (local && widget.networkController != null && widget.networkController!.isConnected) {
      widget.networkController!.sendMessage(NetworkMessage('undo', {}));
    }

    setState(() {});
  }

  void _performReset({bool local = true}) {
    _loadLevel(_currentLevelIdx);
    AudioManager.instance.playUndo();

    if (local && widget.networkController != null && widget.networkController!.isConnected) {
      widget.networkController!.sendMessage(NetworkMessage('reset', {}));
    }

    setState(() {});
  }

  void _changeRuleLocally(String color, String rule) {
    if (!_engine.isGameActive || _engine.hasAnyPlayerDead()) return;
    if (_activeRules[color] == rule) return;

    _pushUndoSnapshot();
    _activeRules[color] = rule;
    _ruleExpiryCounters[color] = rule != 'STOP' ? 5 : null;
    _engine.updateTriggers();
    AudioManager.instance.playRuleChange();

    if (widget.networkController != null && widget.networkController!.isConnected) {
      widget.networkController!.sendMessage(NetworkMessage('rule', {
        'color': color,
        'rule': rule,
      }));
    }

    setState(() {});
  }

  void _showDisconnectDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF131317),
        title: const Text("Connection Lost", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: const Text("Partner player disconnected from the local network.", style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // dialog
              Navigator.of(context).pop(); // screen
            },
            child: const Text("Exit to Menu", style: TextStyle(color: Colors.cyanAccent)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDpadLeft = _dpadLocation == 'left';
    
    // Sidebar Container (takes dedicated width of 185px and wraps the RulesPanel)
    final sidebar = Container(
      width: 185,
      child: RulesPanel(
        levelName: _levelList[_currentLevelIdx].name,
        levelProgress: "LEVEL: ${_currentLevelIdx + 1} / ${_levelList.length}",
        movesLeft: _movesLeft,
        movesLimit: _movesLimit,
        undoEnabled: _undoStack.isNotEmpty,
        onBack: () {
          AudioManager.instance.playRuleChange();
          Navigator.of(context).pop();
        },
        onUndo: () => _performUndo(local: true),
        onReset: () => _performReset(local: true),
        isLeft: !isDpadLeft,
        activeRules: _activeRules,
        allowedRules: _levelList[_currentLevelIdx].allowedRules,
        ruleExpiryCounters: _ruleExpiryCounters,
        onRuleSelected: _changeRuleLocally,
        isMultiplayer: widget.mode != '1',
        isHost: widget.networkRole == NetworkRole.host,
        localPlayerName: widget.localPlayerName,
        localPlayerAvatar: widget.localPlayerAvatar,
        peerPlayerName: widget.peerPlayerName,
        peerPlayerAvatar: widget.peerPlayerAvatar,
      ),
    );  // Board area containing centered grid board and the floating DPad
    final boardArea = Expanded(
      child: Stack(
        children: [
          // Centered Grid Board
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Center(
                child: GridBoard(
                  engine: _engine,
                ),
              ),
            ),
          ),
          
          // Dpad Overlay (floating inside the board area, aligned bottom-left or bottom-right)
          Positioned(
            left: isDpadLeft ? 16 : null,
            right: isDpadLeft ? null : 16,
            bottom: 16,
            child: DPad(
              onDirectionPressed: _performLocalMove,
              scale: _dpadScale,
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF09090C),
      body: SafeArea(
        child: Row(
          children: isDpadLeft ? [boardArea, sidebar] : [sidebar, boardArea],
        ),
      ),
    );
  }
}
