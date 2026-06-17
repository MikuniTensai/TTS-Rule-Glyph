import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../audio/audio_manager.dart';
import '../engine/local_network_controller.dart';
import 'game_screen.dart';
import 'level_select_screen.dart';
import '../widgets/dpad.dart';

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

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _controlScale = prefs.getDouble('control_scale') ?? 1.0;
      _controlLocation = prefs.getString('control_location') ?? 'left';
      _controlOpacity = prefs.getDouble('control_opacity') ?? 0.8;
    });
  }

  @override
  void dispose() {
    _ipInputController.dispose();
    _networkController.dispose();
    super.dispose();
  }

  void _navigateToGame({
    required String mode,
    required NetworkRole role,
    LocalNetworkController? netController,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GameScreen(
          mode: mode,
          networkRole: role,
          networkController: netController,
        ),
      ),
    );
  }

  void _showMultiplayerDialog(String mode) {
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

  Future<void> _hostGame(String mode) async {
    setState(() {
      _isConnecting = true;
    });

    try {
      await _networkController.startHost();
      
      // Show waiting screen
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return WillPopScope(
            onWillPop: () async {
              await _networkController.shutdown();
              return true;
            },
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: AlertDialog(
                backgroundColor: const Color(0xFF131317),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.cyanAccent.withOpacity(0.3), width: 1.5),
                ),
                title: const Text(
                  "Hosting Game",
                  style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.cyanAccent),
                    const SizedBox(height: 20),
                    Text(
                      "Your IP / Invite Code:",
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      _networkController.hostIpAddress,
                      style: const TextStyle(color: Colors.cyanAccent, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Waiting for client to connect...",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () async {
                      await _networkController.shutdown();
                      Navigator.of(context).pop();
                    },
                    child: const Text("Cancel", style: TextStyle(color: Colors.redAccent)),
                  )
                ],
              ),
            ),
          );
        },
      );

      // Listen for incoming connection
      _networkController.connectionStateStream.firstWhere((connected) => connected).then((_) {
        // Pop Host Wait dialog
        Navigator.of(context).pop();
        // Go to game
        _navigateToGame(
          mode: mode,
          role: NetworkRole.host,
          netController: _networkController,
        );
      });
    } catch (e) {
      _showError("Failed to start server: $e");
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  void _showJoinDialog(String mode) {
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
              "Enter Host Invite Code / IP",
              style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                onPressed: () {
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
    );
  }

  Future<void> _joinGame(String mode, String hostIp) async {
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
      await _networkController.connectToHost(hostIp);
      
      // Pop loading spinner
      Navigator.of(context).pop();

      _navigateToGame(
        mode: mode,
        role: NetworkRole.client,
        netController: _networkController,
      );
    } catch (e) {
      // Pop loading spinner
      Navigator.of(context).pop();
      _showError("Failed to connect to host: $e");
    } finally {
      setState(() {
        _isConnecting = false;
      });
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
  }) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: isCompact ? 4 : 6),
      height: isCompact ? 44 : 48,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Container(
            decoration: BoxDecoration(
              color: color.withOpacity(0.06),
              border: Border.all(color: color.withOpacity(0.32), width: 1.2),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.04),
                  blurRadius: 6,
                )
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                highlightColor: color.withOpacity(0.2),
                splashColor: color.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(icon, color: color, size: isCompact ? 18 : 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                title,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
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
                      Icon(Icons.chevron_right, color: color.withOpacity(0.5), size: isCompact ? 16 : 18),
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
                content: Column(
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
    _showLegalDialog(
      title: "Privacy Policy / Kebijakan Privasi",
      content: _privacyPolicyText,
      accentColor: Colors.cyanAccent,
    );
  }

  void _showTermsDialog() {
    _showLegalDialog(
      title: "Terms of Service / Ketentuan Layanan",
      content: _termsOfServiceText,
      accentColor: Colors.tealAccent,
    );
  }

  void _showLegalDialog({
    required String title,
    required String content,
    required Color accentColor,
  }) {
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
              side: BorderSide(color: accentColor.withOpacity(0.4), width: 1.5),
            ),
            title: Text(
              title,
              style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            content: Container(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 500),
              width: double.maxFinite,
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(
                    content,
                    style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showOptionsDialog(); // return to options
                },
                child: Text("Back to Options", style: TextStyle(color: accentColor)),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Close", style: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSupportDialog() {
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
              side: BorderSide(color: Colors.pinkAccent.withOpacity(0.4), width: 1.5),
            ),
            title: const Text(
              "Support & Contact",
              style: TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Butuh bantuan atau ingin memberikan masukan?",
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Website Resmi:",
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 2),
                _buildHyperlink(
                  "https://nitedreamworks.com/",
                  "https://nitedreamworks.com/",
                ),
                const SizedBox(height: 16),
                const Text(
                  "Email Dukungan:",
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 2),
                _buildHyperlink(
                  "support@nitedreamworks.com",
                  "mailto:support@nitedreamworks.com",
                ),
                const SizedBox(height: 16),
                const Text(
                  "Salin tautan atau email di atas untuk menghubungi kami.",
                  style: TextStyle(color: Colors.white54, fontSize: 10, fontStyle: FontStyle.italic),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showOptionsDialog();
                },
                child: const Text("Back to Options", style: TextStyle(color: Colors.pinkAccent)),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Close", style: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
        );
      },
    );
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

  static const String _privacyPolicyText = 
    "PRIVACY POLICY / KEBIJAKAN PRIVASI\n\n"
    "English:\n"
    "Last updated: June 15, 2026\n\n"
    "This Privacy Policy describes how Rule Glyph Lab handles user data.\n\n"
    "1. Information Collection\n"
    "Rule Glyph Lab is a logical puzzle game that stores level progression and settings locally on your device. Local network multiplayer uses your LAN connection only to host or join a nearby game session. We do not collect, transmit to our servers, store, or share any personal data, device identifiers, or usage statistics.\n\n"
    "2. Third-Party Services\n"
    "Our application does not integrate with any third-party analytics, tracking, advertising SDKs, or cloud services.\n\n"
    "3. Children's Privacy\n"
    "Because we do not collect any personal information, our application is safe for children of all ages.\n\n"
    "4. Contact Us\n"
    "If you have any questions about this Privacy Policy, please contact us at support@nitedreamworks.com.\n\n"
    "--------------------------------------------------\n\n"
    "Bahasa Indonesia:\n"
    "Terakhir diperbarui: 15 Juni 2026\n\n"
    "Kebijakan Privasi ini menjelaskan bagaimana Rule Glyph Lab mengelola data Anda.\n\n"
    "1. Pengumpulan Informasi\n"
    "Rule Glyph Lab adalah game puzzle logika yang menyimpan kemajuan level dan pengaturan secara lokal di perangkat Anda. Mode multiplayer jaringan lokal memakai koneksi LAN hanya untuk host atau join sesi game terdekat. Kami tidak mengumpulkan, mengirimkan ke server kami, menyimpan, atau membagikan data pribadi, pengenal perangkat, atau statistik penggunaan Anda.\n\n"
    "2. Layanan Pihak Ketiga\n"
    "Aplikasi kami tidak terintegrasi dengan SDK analisis pihak ketiga, pelacakan, iklan, atau layanan cloud apa pun.\n\n"
    "3. Privasi Anak-Anak\n"
    "Karena kami tidak mengumpulkan informasi pribadi apa pun, aplikasi kami sepenuhnya aman untuk anak-anak dari segala usia.\n\n"
    "4. Hubungi Kami\n"
    "Jika Anda memiliki pertanyaan tentang Kebijakan Privasi ini, silakan hubungi kami di support@nitedreamworks.com.";

  static const String _termsOfServiceText = 
    "TERMS OF SERVICE / KETENTUAN LAYANAN\n\n"
    "English:\n"
    "Last updated: June 15, 2026\n\n"
    "Please read these Terms of Service (\"Terms\") carefully before using the Rule Glyph Lab mobile application.\n\n"
    "1. Agreement to Terms\n"
    "By installing or playing this game, you agree to be bound by these Terms. If you do not agree, do not install or use the application.\n\n"
    "2. License to Use\n"
    "We grant you a personal, non-exclusive, non-transferable, revocable license to use the Rule Glyph Lab application for your personal, non-commercial entertainment on compatible devices.\n\n"
    "3. Intellectual Property\n"
    "All content, logic, grid levels, graphics, and custom synthesized audio are the intellectual property of Nite Dreamworks and its developers. You may not copy, reverse engineer, or redistribute the application assets.\n\n"
    "4. Disclaimer of Warranties\n"
    "The application is provided \"as-is\" and \"as-available\" without warranties of any kind, either express or implied.\n\n"
    "5. Limitation of Liability\n"
    "In no event shall we be liable for any indirect, incidental, or consequential damages arising out of your use or inability to use the application.\n\n"
    "6. Governing Law\n"
    "Terms of Service are governed by laws of Indonesia.\n\n"
    "--------------------------------------------------\n\n"
    "Bahasa Indonesia:\n"
    "Terakhir diperbarui: 15 Juni 2026\n\n"
    "Silakan baca Ketentuan Layanan ini dengan cermat sebelum menggunakan aplikasi mobile Rule Glyph Lab.\n\n"
    "1. Persetujuan Ketentuan\n"
    "Dengan menginstal atau memainkan game ini, Anda setuju untuk terikat oleh Ketentuan ini. Jika Anda tidak setuju, jangan menginstal atau menggunakan aplikasi ini.\n\n"
    "2. Lisensi Penggunaan\n"
    "Kami memberi Anda lisensi pribadi, non-eksklusif, non-transferabel, dapat ditarik kembali untuk menggunakan aplikasi Rule Glyph Lab untuk hiburan pribadi non-komersial pada perangkat yang kompatibel.\n\n"
    "3. Hak Kekayaan Intelektual\n"
    "Semua konten, logika, level kisi, grafis, dan efek suara sintetis adalah kekayaan intelektual dari Nite Dreamworks dan pengembangnya. Anda tidak boleh menyalin, merekayasa balik, atau mendistribusikan ulang aset aplikasi.\n\n"
    "4. Penafian Jaminan\n"
    "Aplikasi ini disediakan secara \"sebagaimana adanya\" dan \"sebagaimana tersedia\" tanpa jaminan dalam bentuk apa pun, baik tersurat maupun tersirat.\n\n"
    "5. Batasan Tanggung Jawab\n"
    "Dalam keadaan apa pun kami tidak bertanggung jawab atas kerusakan tidak langsung, insidental, atau konsekuensial yang timbul dari penggunaan atau ketidakmampuan Anda untuk menggunakan aplikasi.\n\n"
    "6. Hukum yang Mengatur\n"
    "Ketentuan ini diatur dan ditafsirkan sesuai dengan hukum Negara Republik Indonesia, tanpa memperhatikan pertentangan aturan hukumnya.";

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
                Text("RULE GLYPH LAB", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
                        Icon(
                          Icons.dashboard_customize_outlined,
                          size: 64,
                          color: Colors.cyanAccent,
                          shadows: [
                            Shadow(color: Colors.cyanAccent.withOpacity(0.6), blurRadius: 20)
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "RULE GLYPH LAB",
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
                          "Logical Grid Puzzle Game",
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
                        ),
                        _buildMenuButton(
                          title: "4 Player Local Net",
                          icon: Icons.diversity_3_outlined,
                          onTap: () => _showMultiplayerDialog('4'),
                          color: Colors.purpleAccent,
                          isCompact: true,
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
}
