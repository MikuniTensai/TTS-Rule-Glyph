import 'dart:async';
import 'dart:convert';

enum NetworkRole { host, client, none }

class LocalNetworkRoom {
  final String id;
  final String hostIp;
  final String hostName;
  final String mode;
  final int port;
  final DateTime lastSeen;

  const LocalNetworkRoom({
    required this.id,
    required this.hostIp,
    required this.hostName,
    required this.mode,
    required this.port,
    required this.lastSeen,
  });

  LocalNetworkRoom copyWith({
    String? id,
    String? hostIp,
    String? hostName,
    String? mode,
    int? port,
    DateTime? lastSeen,
  }) {
    return LocalNetworkRoom(
      id: id ?? this.id,
      hostIp: hostIp ?? this.hostIp,
      hostName: hostName ?? this.hostName,
      mode: mode ?? this.mode,
      port: port ?? this.port,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}

class LocalNetworkException implements Exception {
  final String message;

  const LocalNetworkException(this.message);

  @override
  String toString() => message;
}

class LocalNetworkValidationResult {
  final bool canConnect;
  final String hostIp;
  final List<String> localAddresses;
  final String? matchingLocalAddress;
  final String message;

  const LocalNetworkValidationResult({
    required this.canConnect,
    required this.hostIp,
    required this.localAddresses,
    required this.message,
    this.matchingLocalAddress,
  });
}

class NetworkMessage {
  final String type;
  final Map<String, dynamic> data;

  NetworkMessage(this.type, this.data);

  String serialize() {
    return '${jsonEncode({
          'type': type,
          'data': data,
        })}\n';
  }

  factory NetworkMessage.deserialize(String raw) {
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    final type = parsed['type'];
    final data = parsed['data'];
    if (type is! String || data is! Map) {
      throw const FormatException('Invalid network message shape');
    }
    return NetworkMessage(type, Map<String, dynamic>.from(data));
  }
}

class LocalNetworkController {
  static const int defaultPort = 12345;
  static const int defaultDiscoveryPort = 12346;

  NetworkRole role = NetworkRole.none;
  String hostIpAddress = '';
  List<String> localIpAddresses = const [];

  final _messageController = StreamController<NetworkMessage>.broadcast();
  Stream<NetworkMessage> get messageStream => _messageController.stream;

  final _connectionStateController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  final _roomDiscoveryController =
      StreamController<List<LocalNetworkRoom>>.broadcast();
  Stream<List<LocalNetworkRoom>> get roomDiscoveryStream =>
      _roomDiscoveryController.stream;

  bool get isConnected => false;

  LocalNetworkController();

  Future<String> discoverLocalIp() async {
    hostIpAddress = '';
    return hostIpAddress;
  }

  Future<List<String>> discoverLocalIpAddresses() async {
    localIpAddresses = const [];
    return localIpAddresses;
  }

  static String normalizeHostAddress(String input) {
    var value = input.trim();
    if (value.startsWith('http://') || value.startsWith('https://')) {
      final uri = Uri.tryParse(value);
      if (uri != null && uri.host.isNotEmpty) value = uri.host;
    }
    final slashIndex = value.indexOf('/');
    if (slashIndex != -1) value = value.substring(0, slashIndex);
    final portIndex = value.indexOf(':');
    if (portIndex != -1) value = value.substring(0, portIndex);
    return value;
  }

  static bool isValidIpv4(String address) => _parseIpv4(address) != null;

  static bool isPrivateIpv4(String address) {
    final parts = _parseIpv4(address);
    if (parts == null) return false;
    if (parts[0] == 10) return true;
    if (parts[0] == 192 && parts[1] == 168) return true;
    return parts[0] == 172 && parts[1] >= 16 && parts[1] <= 31;
  }

  static bool isLoopbackIpv4(String address) {
    final parts = _parseIpv4(address);
    return parts != null && parts[0] == 127;
  }

  static bool isSameLanSubnet(String localAddress, String hostAddress) {
    final local = _parseIpv4(localAddress);
    final host = _parseIpv4(hostAddress);
    if (local == null || host == null) return false;
    if (localAddress == hostAddress) return true;
    return local[0] == host[0] && local[1] == host[1] && local[2] == host[2];
  }

  static String subnetHint(String address) {
    final parts = _parseIpv4(address);
    if (parts == null) return '';
    return '${parts[0]}.${parts[1]}.${parts[2]}.x';
  }

  static LocalNetworkRoom? parseDiscoveryPacket(String raw, dynamic sender) {
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['type'] != 'rule_glyph_room') return null;

      final senderAddress = sender is String
          ? sender
          : (sender?.address is String ? sender.address as String : '');
      final hostIpValue = data['hostIp'] as String? ?? '';
      final hostIp = normalizeHostAddress(
        hostIpValue.isEmpty ? senderAddress : hostIpValue,
      );
      if (!isValidIpv4(hostIp) || !isPrivateIpv4(hostIp)) return null;

      final mode = data['mode'] as String? ?? '2';
      if (!{'2', '3', '4'}.contains(mode)) return null;

      return LocalNetworkRoom(
        id: data['id'] as String? ?? hostIp,
        hostIp: hostIp,
        hostName: data['hostName'] as String? ?? 'Rule Glyph Host',
        mode: mode,
        port: data['port'] as int? ?? defaultPort,
        lastSeen: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<LocalNetworkValidationResult> validateHostAddress(
      String hostIp) async {
    final normalizedHostIp = normalizeHostAddress(hostIp);
    return LocalNetworkValidationResult(
      canConnect: false,
      hostIp: normalizedHostIp,
      localAddresses: const [],
      message:
          'Local multiplayer LAN belum tersedia di web. Gunakan Android untuk host/join room.',
    );
  }

  static List<int>? _parseIpv4(String address) {
    final parts = address.trim().split('.');
    if (parts.length != 4) return null;

    final parsed = <int>[];
    for (final part in parts) {
      if (part.isEmpty) return null;
      final value = int.tryParse(part);
      if (value == null || value < 0 || value > 255) return null;
      parsed.add(value);
    }
    return parsed;
  }

  Future<void> startRoomScan({
    String? mode,
    int discoveryPort = defaultDiscoveryPort,
  }) async {
    _roomDiscoveryController.add(const []);
  }

  Future<void> stopRoomDiscovery() async {}

  Future<void> startHost({String mode = '2', int port = defaultPort}) async {
    throw const LocalNetworkException(
      'Local multiplayer LAN belum tersedia di web. Gunakan Android untuk host room.',
    );
  }

  Future<void> connectToHost(String hostIp, {int port = defaultPort}) async {
    throw const LocalNetworkException(
      'Local multiplayer LAN belum tersedia di web. Gunakan Android untuk join room.',
    );
  }

  void sendMessage(NetworkMessage message) {}

  Future<void> shutdown() async {
    role = NetworkRole.none;
  }

  Future<void> dispose() async {
    await shutdown();
    await _messageController.close();
    await _connectionStateController.close();
    await _roomDiscoveryController.close();
  }
}
