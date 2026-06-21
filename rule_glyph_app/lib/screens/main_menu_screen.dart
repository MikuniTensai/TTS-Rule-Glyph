import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../audio/audio_manager.dart';
import '../engine/local_network_controller.dart';
import 'level_select_screen.dart';
import 'multiplayer_lobby_screen.dart';
import '../widgets/dpad.dart';
import '../widgets/legal_doc_viewer.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({Key? key}) : super(key: key);

  @override
  _MainMenuScreenState createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  final LocalNetworkController _networkController = LocalNetworkController();
  final TextEditingController _ipInputController = TextEditingController();
  bool _isConnecting = false;

  double _controlScale = 1.0;
  String _controlLocation = 'left';
  double _controlOpacity = 0.8;
  String _playerName = "Player";
  String? _playerAvatarBase64;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    AudioManager.instance.startBackgroundMusic();
  }

  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _controlScale = prefs.getDouble('control_scale') ?? 1.0;
      _controlLocation = prefs.getString('control_location') ?? 'left';
      _controlOpacity = prefs.getDouble('control_opacity') ?? 0.8;
      _playerName = prefs.getString('player_name') ?? "Player";
      _playerAvatarBase64 = prefs.getString('player_avatar_base64');
    });
  }

  @override
  void dispose() {
    _ipInputController.dispose();
    _networkController.dispose();
    super.dispose();
  }

  void _navigateToLobby({
    required String mode,
    required NetworkRole role,
    required LocalNetworkController netController,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MultiplayerLobbyScreen(
          mode: mode,
          networkRole: role,
          networkController: netController,
        ),
      ),
    );
  }

  bool _isMultiplayerModeEnabled(String mode) => mode == '2';

  void _showModeDisabledMessage(String mode) {
    AudioManager.instance.playFail();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("$mode Player multiplayer sementara dinonaktifkan untuk rilis awal."),
        backgroundColor: Colors.orangeAccent.withOpacity(0.9),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showMultiplayerDialog(String mode) {
    if (!_isMultiplayerModeEnabled(mode)) {
      _showModeDisabledMessage(mode);
      return;
    }

    AudioManager.instance.playRuleChange();
    showDialog(
      context: context,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: AlertDialog(
            backgroundColor: const Color(0xFF131317),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.cyanAccent.withOpacity(0.3), width: 1.5),
            ),
            title: Text(
              "Local Network $mode Player",
              style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Make sure all devices are on the same local Wi-Fi network.",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    _hostGame(mode);
                  },
                  icon: const Icon(Icons.wifi_tethering),
                  label: const Text("Host Game"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent.withOpacity(0.12),
                    foregroundColor: Colors.cyanAccent,
                    side: const BorderSide(color: Colors.cyanAccent, width: 1),
                    minimumSize: const Size(double.infinity, 44),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showJoinDialog(mode);
                  },
                  icon: const Icon(Icons.sensors),
                  label: const Text("Join Game"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent.withOpacity(0.12),
                    foregroundColor: Colors.tealAccent,
                    side: const BorderSide(color: Colors.tealAccent, width: 1),
                    minimumSize: const Size(double.infinity, 44),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLocalNetworkHint(Color color) {
    return FutureBuilder<List<String>>(
      future: _networkController.discoverLocalIpAddresses(),
      builder: (context, snapshot) {
        final addresses = snapshot.data ?? const <String>[];
        final text = addresses.isEmpty
            ? 'No local Wi-Fi/LAN IP detected yet.'
            : 'This device: ${addresses.join(', ')}';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Text(
            text,
            style: TextStyle(color: color.withOpacity(0.9), fontSize: 12),
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }

  Future<void> _hostGame(String mode) async {
    if (!_isMultiplayerModeEnabled(mode)) {
      _showModeDisabledMessage(mode);
      return;
    }

    setState(() {
      _isConnecting = true;
    });

    try {
      await _networkController.startHost(mode: mode);

      if (mounted) {
        AudioManager.instance.playStart();
        _navigateToLobby(
          mode: mode,
          role: NetworkRole.host,
          netController: _networkController,
        );
      }
    } catch (e) {
      if (mounted) {
        _showError("Failed to start server: $e");
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  void _showJoinDialog(String mode) {
    if (!_isMultiplayerModeEnabled(mode)) {
      _showModeDisabledMessage(mode);
      return;
    }

    _networkController.startRoomScan(mode: mode).catchError((e) {
      if (mounted) {
        _showError("Failed to scan rooms: $e");
      }
    });

    showDialog(
      context: context,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: AlertDialog(
            backgroundColor: const Color(0xFF131317),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.tealAccent.withOpacity(0.3), width: 1.5),
            ),
            title: const Text(
              "Join Local Room",
              style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLocalNetworkHint(Colors.tealAccent),
                const SizedBox(height: 12),
                _buildDetectedRooms(mode),
                const SizedBox(height: 12),
                const Text(
                  "Tap a detected room, or enter the host IP shown on the hosting device.",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _ipInputController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "e.g. 192.168.1.8",
                    hintStyle: const TextStyle(color: Colors.white30),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.tealAccent),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await _networkController.stopRoomDiscovery();
                  Navigator.of(context).pop();
                },
                child: const Text("Cancel", style: TextStyle(color: Colors.redAccent)),
              ),
              ElevatedButton(
                onPressed: () {
                  final ip = _ipInputController.text.trim();
                  if (ip.isNotEmpty) {
                    Navigator.of(context).pop();
                    _joinGame(mode, ip);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
                child: const Text("Connect"),
              ),
            ],
          ),
        );
      },
    ).whenComplete(_networkController.stopRoomDiscovery);
  }

  Widget _buildDetectedRooms(String mode) {
    return StreamBuilder<List<LocalNetworkRoom>>(
      stream: _networkController.roomDiscoveryStream,
      initialData: const [],
      builder: (context, snapshot) {
        final rooms = snapshot.data ?? const <LocalNetworkRoom>[];
        if (rooms.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.tealAccent,
                  ),
                ),
                SizedBox(width: 10),
                Flexible(
                  child: Text(
                    "Scanning rooms...",
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }

        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 150),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: rooms.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final room = rooms[index];
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    Navigator.of(context).pop();
                    _joinGame(mode, room.hostIp, port: room.port);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.tealAccent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.sensors, color: Colors.tealAccent, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "${room.mode} Player Room",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                room.hostIp,
                                style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right, color: Colors.tealAccent, size: 18),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _joinGame(String mode, String hostIp, {int port = LocalNetworkController.defaultPort}) async {
    if (!_isMultiplayerModeEnabled(mode)) {
      _showModeDisabledMessage(mode);
      return;
    }

    setState(() {
      _isConnecting = true;
    });
    
    // Show connecting loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.tealAccent),
      ),
    );

    try {
      await _networkController.connectToHost(hostIp, port: port);
      
      // Pop loading spinner
      if (!mounted) return;
      Navigator.of(context).pop();

      AudioManager.instance.playStart();
      _navigateToLobby(
        mode: mode,
        role: NetworkRole.client,
        netController: _networkController,
      );
    } catch (e) {
      // Pop loading spinner
      if (mounted) {
        Navigator.of(context).pop();
        _showError("Failed to connect to host: $e");
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF131317),
        title: const Text("Error", style: TextStyle(color: Colors.redAccent)),
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  Widget _buildMenuButton({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
    bool isCompact = false,
    bool enabled = true,
    String? statusLabel,
  }) {
    final effectiveColor = enabled ? color : Colors.white38;
    return Container(
      margin: EdgeInsets.symmetric(vertical: isCompact ? 4 : 6),
      height: isCompact ? 44 : 48,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Container(
            decoration: BoxDecoration(
              color: effectiveColor.withOpacity(enabled ? 0.06 : 0.035),
              border: Border.all(color: effectiveColor.withOpacity(enabled ? 0.32 : 0.12), width: 1.2),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: effectiveColor.withOpacity(enabled ? 0.04 : 0.0),
                  blurRadius: 6,
                )
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: enabled ? onTap : null,
                highlightColor: effectiveColor.withOpacity(0.2),
                splashColor: effectiveColor.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(icon, color: effectiveColor, size: isCompact ? 18 : 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                title,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: enabled ? Colors.white : Colors.white38,
                                  fontSize: isCompact ? 12 : 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (statusLabel != null)
                        Text(
                          statusLabel,
                          style: TextStyle(
                            color: effectiveColor.withOpacity(0.85),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      else
                        Icon(Icons.chevron_right, color: effectiveColor.withOpacity(0.5), size: isCompact ? 16 : 18),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDialogButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.08),
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.4), width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      ),
    );
  }

  Widget _buildHyperlink(String label, String value) {
    return InkWell(
      onTap: () async {
        AudioManager.instance.playRuleChange();
        try {
          await Clipboard.setData(ClipboardData(text: label));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Tautan disalin ke papan klip: $label"),
                backgroundColor: Colors.pinkAccent.withOpacity(0.8),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          // Fallback
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.cyanAccent,
            decoration: TextDecoration.underline,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showOptionsDialog() {
    AudioManager.instance.playRuleChange();
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isMuted = AudioManager.instance.isMuted;
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: AlertDialog(
                backgroundColor: const Color(0xFF131317),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.white.withOpacity(0.12), width: 1.5),
                ),
                title: const Text("Options & Support", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Mute Audio Effects", style: TextStyle(color: Colors.white70)),
                          Switch(
                            value: isMuted,
                            activeColor: Colors.cyanAccent,
                            onChanged: (val) {
                              setDialogState(() {
                                AudioManager.instance.toggleMute();
                              });
                              AudioManager.instance.playRuleChange();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Dpad Size", style: TextStyle(color: Colors.white70)),
                          DropdownButton<double>(
                            value: _controlScale,
                            dropdownColor: const Color(0xFF131317),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            underline: Container(),
                            onChanged: (double? newValue) async {
                              if (newValue != null) {
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.setDouble('control_scale', newValue);
                                setDialogState(() {
                                  _controlScale = newValue;
                                });
                                setState(() {});
                              }
                            },
                            items: const [
                              DropdownMenuItem<double>(
                                value: 0.8,
                                child: Text("Small (Kecil)"),
                              ),
                              DropdownMenuItem<double>(
                                value: 1.0,
                                child: Text("Medium (Sedang)"),
                              ),
                              DropdownMenuItem<double>(
                                value: 1.2,
                                child: Text("Large (Besar)"),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Dpad Position", style: TextStyle(color: Colors.white70)),
                          DropdownButton<String>(
                            value: _controlLocation,
                            dropdownColor: const Color(0xFF131317),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            underline: Container(),
                            onChanged: (String? newValue) async {
                              if (newValue != null) {
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.setString('control_location', newValue);
                                setDialogState(() {
                                  _controlLocation = newValue;
                                });
                                setState(() {});
                              }
                            },
                            items: const [
                              DropdownMenuItem<String>(
                                value: 'left',
                                child: Text("Left (Kiri)"),
                              ),
                              DropdownMenuItem<String>(
                                value: 'right',
                                child: Text("Right (Kanan)"),
                              ),
                            ],
                          ),
                        ],
                      ),
                      
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 4),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "PLAYER PROFILE (MULTIPLAYER)",
                          style: TextStyle(
                            color: Colors.cyanAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          InkWell(
                            onTap: () => _pickAvatarImage(setDialogState),
                            borderRadius: BorderRadius.circular(30),
                            child: Stack(
                              children: [
                                _playerAvatarBase64 != null
                                    ? ClipOval(
                                        child: Image.memory(
                                          base64Decode(_playerAvatarBase64!),
                                          width: 56,
                                          height: 56,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : CircleAvatar(
                                        radius: 28,
                                        backgroundColor: Colors.cyanAccent.withOpacity(0.12),
                                        child: const Icon(Icons.person, color: Colors.cyanAccent, size: 28),
                                      ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: CircleAvatar(
                                    radius: 9,
                                    backgroundColor: Colors.cyanAccent,
                                    child: const Icon(Icons.edit, size: 10, color: Colors.black),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextFormField(
                              initialValue: _playerName,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                labelText: "Player Name",
                                labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(color: Colors.cyanAccent),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onChanged: (val) async {
                                if (val.trim().isNotEmpty) {
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setString('player_name', val.trim());
                                  _playerName = val.trim();
                                  setState(() {});
                                }
                              },
                            ),
                          ),
                        ],
                      ),

                      const Divider(color: Colors.white10),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDialogButton(
                              label: "Privacy Policy",
                              icon: Icons.privacy_tip_outlined,
                              color: Colors.cyanAccent,
                              onPressed: () {
                                Navigator.of(context).pop();
                                _showPrivacyPolicyDialog();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDialogButton(
                              label: "Terms of Service",
                              icon: Icons.description_outlined,
                              color: Colors.tealAccent,
                              onPressed: () {
                                Navigator.of(context).pop();
                                _showTermsDialog();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDialogButton(
                              label: "Contact Support",
                              icon: Icons.help_outline,
                              color: Colors.pinkAccent,
                              onPressed: () {
                                Navigator.of(context).pop();
                                _showSupportDialog();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDialogButton(
                              label: "Reset Progress",
                              icon: Icons.restart_alt,
                              color: Colors.redAccent,
                              onPressed: () {
                                Navigator.of(context).pop();
                                _confirmResetProgress();
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("Close", style: TextStyle(color: Colors.cyanAccent)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showPrivacyPolicyDialog() {
    AudioManager.instance.playRuleChange();
    LegalDocViewer.show(
      context,
      title: "Privacy Policy / Kebijakan Privasi",
      assetPath: "assets/legal/privacy_policy.md",
    ).then((_) {
      _showOptionsDialog();
    });
  }

  void _showTermsDialog() {
    AudioManager.instance.playRuleChange();
    LegalDocViewer.show(
      context,
      title: "Terms of Service / Ketentuan Layanan",
      assetPath: "assets/legal/terms_of_service.md",
    ).then((_) {
      _showOptionsDialog();
    });
  }

  void _showSupportDialog() {
    AudioManager.instance.playRuleChange();
    LegalDocViewer.show(
      context,
      title: "Support & Legal Center",
      assetPath: "assets/legal/support.md",
    ).then((_) {
      _showOptionsDialog();
    });
  }

  void _confirmResetProgress() {
    AudioManager.instance.playFail();
    showDialog(
      context: context,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: AlertDialog(
            backgroundColor: const Color(0xFF1C1313),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.redAccent.withOpacity(0.4), width: 1.5),
            ),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                SizedBox(width: 8),
                Text(
                  "Reset Progress?",
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: const Text(
              "Apakah Anda yakin ingin mereset seluruh kemajuan level Anda? Tindakan ini tidak dapat dibatalkan.",
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showOptionsDialog();
                },
                child: const Text("Batal", style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _resetProgressAction();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Reset Sekarang"),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _resetProgressAction() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove("max_unlocked_level_idx_1");
      await prefs.remove("max_unlocked_level_idx_2");
      await prefs.remove("max_unlocked_level_idx_3");
      await prefs.remove("max_unlocked_level_idx_4");
      
      AudioManager.instance.playWin();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Progres game berhasil direset!"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _showError("Gagal mereset progres: $e");
    }
  }



  void _showCreditsDialog() {
    AudioManager.instance.playRuleChange();
    showDialog(
      context: context,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: AlertDialog(
            backgroundColor: const Color(0xFF131317),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.pinkAccent.withOpacity(0.3), width: 1.5),
            ),
            title: const Text("Credits", style: TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold)),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("TTS: RULE GLYPH LAB", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 8),
                Text("Concept & Logic: Richard Locke", style: TextStyle(color: Colors.white70, fontSize: 13)),
                Text("Flutter Native Port: Antigravity AI", style: TextStyle(color: Colors.white70, fontSize: 13)),
                SizedBox(height: 12),
                Text("Developed with a vision to build robust, logic-driven cross-device grid puzzle game systems.", style: TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Close", style: TextStyle(color: Colors.pinkAccent)),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      body: Stack(
        children: [
          // Background Neon Dots
          Positioned(
            left: -80,
            top: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyanAccent.withOpacity(0.03),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: -80,
            bottom: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.pinkAccent.withOpacity(0.03),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left Side: Title & Subtitle
                  Expanded(
                    flex: 4,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.cyanAccent.withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/logo.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "TTS: RULE GLYPH LAB",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            shadows: [
                              Shadow(color: Colors.white.withOpacity(0.3), blurRadius: 8)
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Teka-Teki Simbol (TTS) Grid Puzzle",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.cyanAccent.withOpacity(0.8),
                            fontSize: 11,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Right Side: Buttons Column
                  Expanded(
                    flex: 5,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildMenuButton(
                          title: "Survival (1 Player)",
                          icon: Icons.emoji_events_outlined,
                          onTap: () {
                            AudioManager.instance.playRuleChange();
                            AudioManager.instance.playStart();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const LevelSelectScreen(mode: '1'),
                              ),
                            );
                          },
                          color: Colors.cyanAccent,
                        ),
                        _buildMenuButton(
                          title: "2 Player Local Net",
                          icon: Icons.people_outline,
                          onTap: () => _showMultiplayerDialog('2'),
                          color: Colors.tealAccent,
                        ),
                        _buildMenuButton(
                          title: "3 Player Local Net",
                          icon: Icons.groups_outlined,
                          onTap: () => _showMultiplayerDialog('3'),
                          color: Colors.pinkAccent,
                          enabled: false,
                          statusLabel: "SOON",
                        ),
                        _buildMenuButton(
                          title: "4 Player Local Net",
                          icon: Icons.diversity_3_outlined,
                          onTap: () => _showMultiplayerDialog('4'),
                          color: Colors.purpleAccent,
                          isCompact: true,
                          enabled: false,
                          statusLabel: "SOON",
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _buildMenuButton(
                                title: "Options",
                                icon: Icons.tune,
                                onTap: _showOptionsDialog,
                                color: Colors.grey,
                                isCompact: true,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildMenuButton(
                                title: "Credits",
                                icon: Icons.info_outline,
                                onTap: _showCreditsDialog,
                                color: Colors.grey,
                                isCompact: true,
                              ),
                            ),
                          ],
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
    );
  }

  Future<void> _pickAvatarImage(StateSetter setDialogState) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 80,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        final base64Str = base64Encode(bytes);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('player_avatar_base64', base64Str);
        setDialogState(() {
          _playerAvatarBase64 = base64Str;
        });
        setState(() {});
      }
    } catch (e) {
      print("Failed to pick image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Format/Izin gambar tidak didukung: $e")),
      );
    }
  }
}
