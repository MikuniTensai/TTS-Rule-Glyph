import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/audio_manager.dart';
import '../data/levels_data.dart';
import '../engine/local_network_controller.dart';
import 'game_screen.dart';

class MultiplayerLobbyScreen extends StatefulWidget {
  final String mode;
  final NetworkRole networkRole;
  final LocalNetworkController networkController;

  const MultiplayerLobbyScreen({
    Key? key,
    required this.mode,
    required this.networkRole,
    required this.networkController,
  }) : super(key: key);

  @override
  State<MultiplayerLobbyScreen> createState() => _MultiplayerLobbyScreenState();
}

class _MultiplayerLobbyScreenState extends State<MultiplayerLobbyScreen> {
  late final List<LevelData> _levelList;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _connectionSubscription;
  Timer? _syncTimer;

  int _localUnlockedIdx = 0;
  int? _peerUnlockedIdx;
  int _selectedLevelIdx = 0;
  bool _isLoading = true;
  bool _isStarting = false;
  bool _leavingForGame = false;

  bool get _isHost => widget.networkRole == NetworkRole.host;

  int get _roomMaxUnlockedIdx {
    final peerUnlocked = _peerUnlockedIdx;
    final maxIdx = peerUnlocked == null
        ? _localUnlockedIdx
        : (_localUnlockedIdx < peerUnlocked ? _localUnlockedIdx : peerUnlocked);
    return _clampLevelIdx(maxIdx);
  }

  int _clampLevelIdx(int index) {
    if (_levelList.isEmpty) return 0;
    return index.clamp(0, _levelList.length - 1).toInt();
  }

  @override
  void initState() {
    super.initState();
    _levelList = LEVELS_BY_MODE[widget.mode] ?? LEVELS;
    _messageSubscription = widget.networkController.messageStream.listen(_handleNetworkMessage);
    _connectionSubscription = widget.networkController.connectionStateStream.listen((connected) {
      if (!connected && mounted && !_leavingForGame) {
        _showDisconnectDialog();
      }
    });
    _syncTimer = Timer.periodic(const Duration(seconds: 1), (_) => _syncLobby());
    _loadLocalProgress();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _connectionSubscription?.cancel();
    _syncTimer?.cancel();
    if (!_leavingForGame) {
      widget.networkController.shutdown();
    }
    super.dispose();
  }

  Future<void> _loadLocalProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final progressKey = "max_unlocked_level_idx_${widget.mode}";
    final unlocked = _clampLevelIdx(prefs.getInt(progressKey) ?? 0);

    if (!mounted) return;
    setState(() {
      _localUnlockedIdx = unlocked;
      _selectedLevelIdx = _selectedLevelIdx.clamp(0, _roomMaxUnlockedIdx).toInt();
      _isLoading = false;
    });

    _syncLobby();
  }

  void _syncLobby() {
    if (_isLoading || !widget.networkController.isConnected || _leavingForGame) return;

    widget.networkController.sendMessage(NetworkMessage('progress', {
      'mode': widget.mode,
      'maxUnlockedLevel': _localUnlockedIdx,
    }));

    if (_isHost) {
      _publishLobbyState();
    }
  }

  void _handleNetworkMessage(NetworkMessage msg) {
    if (msg.type == 'progress') {
      final mode = msg.data['mode'];
      final unlocked = msg.data['maxUnlockedLevel'];
      if (mode != widget.mode || unlocked is! int) return;

      setState(() {
        _peerUnlockedIdx = _clampLevelIdx(unlocked);
        if (_selectedLevelIdx > _roomMaxUnlockedIdx) {
          _selectedLevelIdx = _roomMaxUnlockedIdx;
        }
      });

      if (_isHost) {
        _publishLobbyState();
      }
    } else if (msg.type == 'lobby_state') {
      final mode = msg.data['mode'];
      if (mode != widget.mode) return;

      final hostUnlocked = msg.data['hostUnlocked'];
      final selectedLevel = msg.data['selectedLevel'];
      if (hostUnlocked is! int || selectedLevel is! int) return;

      setState(() {
        _peerUnlockedIdx = _clampLevelIdx(hostUnlocked);
        _selectedLevelIdx = _clampLevelIdx(selectedLevel);
      });
    } else if (msg.type == 'start_level') {
      final mode = msg.data['mode'];
      final levelIndex = msg.data['levelIndex'];
      if (mode != widget.mode || levelIndex is! int) return;
      _openGame(_clampLevelIdx(levelIndex));
    }
  }

  void _publishLobbyState() {
    if (!_isHost || !widget.networkController.isConnected) return;

    widget.networkController.sendMessage(NetworkMessage('lobby_state', {
      'mode': widget.mode,
      'hostUnlocked': _localUnlockedIdx,
      'clientUnlocked': _peerUnlockedIdx,
      'roomMaxUnlocked': _roomMaxUnlockedIdx,
      'selectedLevel': _selectedLevelIdx,
    }));
  }

  void _selectLevel(int levelIdx) {
    if (!_isHost || levelIdx > _roomMaxUnlockedIdx) {
      AudioManager.instance.playFail();
      return;
    }

    AudioManager.instance.playRuleChange();
    setState(() {
      _selectedLevelIdx = levelIdx;
    });
    _publishLobbyState();
  }

  void _startLevel() {
    if (!_isHost || _peerUnlockedIdx == null || _isStarting) return;

    setState(() {
      _isStarting = true;
    });

    widget.networkController.sendMessage(NetworkMessage('start_level', {
      'mode': widget.mode,
      'levelIndex': _selectedLevelIdx,
    }));
    _openGame(_selectedLevelIdx);
  }

  void _openGame(int levelIdx) {
    if (_leavingForGame) return;
    _leavingForGame = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => GameScreen(
          mode: widget.mode,
          networkRole: widget.networkRole,
          networkController: widget.networkController,
          startLevelIdx: levelIdx,
        ),
      ),
    );
  }

  Future<bool> _confirmExit() async {
    if (_leavingForGame) return true;
    await widget.networkController.shutdown();
    return true;
  }

  void _showDisconnectDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF131317),
        title: const Text(
          "Connection Lost",
          style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "Partner player disconnected from the local network.",
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text("Exit", style: TextStyle(color: Colors.cyanAccent)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF09090C),
        body: Center(child: CircularProgressIndicator(color: Colors.tealAccent)),
      );
    }

    final selectedLevel = _levelList[_selectedLevelIdx];
    final peerText = _peerUnlockedIdx == null
        ? "Waiting for partner progress..."
        : "Partner unlock: ${_peerUnlockedIdx! + 1}";

    return WillPopScope(
      onWillPop: _confirmExit,
      child: Scaffold(
        backgroundColor: const Color(0xFF09090C),
        body: Stack(
          children: [
            Positioned(
              left: -100,
              top: -100,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.tealAccent.withOpacity(0.025),
                      blurRadius: 120,
                      spreadRadius: 60,
                    )
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () async {
                            if (await _confirmExit() && mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "${widget.mode} Player Room",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          _isHost ? "HOST" : "CLIENT",
                          style: TextStyle(
                            color: _isHost ? Colors.cyanAccent : Colors.tealAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildStat("Your unlock", "${_localUnlockedIdx + 1}")),
                        const SizedBox(width: 10),
                        Expanded(child: _buildStat("Room max", "${_roomMaxUnlockedIdx + 1}")),
                        const SizedBox(width: 10),
                        Expanded(child: _buildStat("Partner", peerText)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: _buildLevelGrid(),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 260,
                            child: _buildSelectedLevelPanel(selectedLevel),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.035),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelGrid() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.22),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 64,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1,
        ),
        itemCount: _levelList.length,
        itemBuilder: (context, index) {
          final isAllowed = index <= _roomMaxUnlockedIdx;
          final isSelected = index == _selectedLevelIdx;
          final isCompleted = index < _roomMaxUnlockedIdx;

          Color borderColor = Colors.white.withOpacity(0.10);
          Color textColor = Colors.white30;
          Color bgColor = Colors.white.withOpacity(0.03);
          if (isAllowed) {
            borderColor = isSelected ? Colors.tealAccent : Colors.greenAccent.withOpacity(0.35);
            textColor = isSelected ? Colors.tealAccent : Colors.greenAccent;
            bgColor = isSelected
                ? Colors.tealAccent.withOpacity(0.10)
                : Colors.greenAccent.withOpacity(isCompleted ? 0.06 : 0.04);
          }

          return InkWell(
            onTap: () => _selectLevel(index),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              decoration: BoxDecoration(
                color: bgColor,
                border: Border.all(color: borderColor, width: isSelected ? 1.8 : 1.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: isAllowed
                    ? Text(
                        "${_levelList[index].id}",
                        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                      )
                    : Icon(Icons.lock_outline, color: Colors.white.withOpacity(0.20), size: 16),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectedLevelPanel(LevelData level) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.035),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Level ${level.id}",
                style: const TextStyle(color: Colors.tealAccent, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                level.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                level.description,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
              ),
              const Spacer(),
              Text(
                _isHost
                    ? "Host IP: ${widget.networkController.hostIpAddress}"
                    : "Connected to host. Waiting for start.",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(height: 10),
              Text(
                _isHost
                    ? "Host selects the level. Locked levels follow the lowest unlock in this room."
                    : "Waiting for host to select and start.",
                style: const TextStyle(color: Colors.white38, fontSize: 11, height: 1.3),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isHost && _peerUnlockedIdx != null && !_isStarting ? _startLevel : null,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: Text(_isHost ? "Start" : "Waiting"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.white.withOpacity(0.08),
                  disabledForegroundColor: Colors.white38,
                  minimumSize: const Size(double.infinity, 44),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
