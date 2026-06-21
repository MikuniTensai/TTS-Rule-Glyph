import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/services.dart';

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
  final String type; // 'level', 'move', 'rule', 'reset', 'undo', lobby messages, 'join_ack'
  final Map<String, dynamic> data;

  NetworkMessage(this.type, this.data);

  String serialize() {
    return jsonEncode({
      'type': type,
      'data': data,
    }) + '\n';
  }

  factory NetworkMessage.deserialize(String raw) {
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    final type = parsed['type'];
    final data = parsed['data'];
    if (type is! String || data is! Map) {
      throw const FormatException('Invalid network message shape');
    }
    return NetworkMessage(
      type,
      Map<String, dynamic>.from(data),
    );
  }
}

class LocalNetworkController {
  static const int defaultPort = 12345;
  static const int defaultDiscoveryPort = 12346;
  static const String _discoveryType = 'rule_glyph_room';
  static const String _discoveryRequestType = 'rule_glyph_room_request';
  static const MethodChannel _networkChannel = MethodChannel('rule_glyph/local_network');

  NetworkRole role = NetworkRole.none;
  ServerSocket? _serverSocket;
  Socket? _clientSocket; // If host: connection to client. If client: connection to host.
  RawDatagramSocket? _discoverySocket;
  Timer? _discoveryTimer;
  String? _hostRoomId;
  String? _hostMode;
  int _hostPort = defaultPort;
  int _discoveryPort = defaultDiscoveryPort;
  bool _multicastLockHeld = false;
  final Map<String, LocalNetworkRoom> _discoveredRooms = {};
  
  final _messageController = StreamController<NetworkMessage>.broadcast();
  Stream<NetworkMessage> get messageStream => _messageController.stream;

  final _connectionStateController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  final _roomDiscoveryController = StreamController<List<LocalNetworkRoom>>.broadcast();
  Stream<List<LocalNetworkRoom>> get roomDiscoveryStream => _roomDiscoveryController.stream;

  bool get isConnected => _clientSocket != null;

  String hostIpAddress = '';
  List<String> localIpAddresses = const [];
  
  LocalNetworkController();

  /// Discover own local IP address on Wi-Fi network
  Future<String> discoverLocalIp() async {
    final addresses = await discoverLocalIpAddresses();
    hostIpAddress = addresses.isEmpty ? '' : addresses.first;
    return hostIpAddress;
  }

  /// Discover all private IPv4 LAN addresses on this device.
  Future<List<String>> discoverLocalIpAddresses() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
        includeLoopback: false,
      );

      final addresses = <String>{};
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (isPrivateIpv4(addr.address)) {
            addresses.add(addr.address);
          }
        }
      }

      final sortedAddresses = addresses.toList()
        ..sort((a, b) => _lanAddressPriority(a).compareTo(_lanAddressPriority(b)));
      localIpAddresses = sortedAddresses;
      if (sortedAddresses.isNotEmpty) {
        hostIpAddress = sortedAddresses.first;
      }
      return sortedAddresses;
    } catch (e) {
      localIpAddresses = const [];
    }
    hostIpAddress = '';
    return localIpAddresses;
  }

  static String normalizeHostAddress(String input) {
    var value = input.trim();
    if (value.startsWith('http://') || value.startsWith('https://')) {
      final uri = Uri.tryParse(value);
      if (uri != null && uri.host.isNotEmpty) {
        value = uri.host;
      }
    }

    final slashIndex = value.indexOf('/');
    if (slashIndex != -1) {
      value = value.substring(0, slashIndex);
    }

    final portIndex = value.indexOf(':');
    if (portIndex != -1) {
      value = value.substring(0, portIndex);
    }

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
    if (local[0] == 127 || host[0] == 127) {
      return local[0] == 127 && host[0] == 127;
    }
    if (!isPrivateIpv4(localAddress) || !isPrivateIpv4(hostAddress)) {
      return false;
    }

    return local[0] == host[0] && local[1] == host[1] && local[2] == host[2];
  }

  static String subnetHint(String address) {
    final parts = _parseIpv4(address);
    if (parts == null) return '';
    return '${parts[0]}.${parts[1]}.${parts[2]}.x';
  }

  Future<LocalNetworkValidationResult> validateHostAddress(String hostIp) async {
    final normalizedHostIp = normalizeHostAddress(hostIp);
    if (!isValidIpv4(normalizedHostIp)) {
      return LocalNetworkValidationResult(
        canConnect: false,
        hostIp: normalizedHostIp,
        localAddresses: const [],
        message: 'Enter a valid IPv4 host address, for example 192.168.1.8.',
      );
    }

    if (isLoopbackIpv4(normalizedHostIp)) {
      return LocalNetworkValidationResult(
        canConnect: false,
        hostIp: normalizedHostIp,
        localAddresses: const [],
        message: '127.x.x.x only points to this device. Use the host IP shown on the hosting device.',
      );
    }

    final localAddresses = await discoverLocalIpAddresses();
    if (localAddresses.isEmpty) {
      return LocalNetworkValidationResult(
        canConnect: false,
        hostIp: normalizedHostIp,
        localAddresses: localAddresses,
        message: 'No Wi-Fi/LAN IPv4 address was found on this device. Connect both devices to the same Wi-Fi network.',
      );
    }

    for (final localAddress in localAddresses) {
      if (isSameLanSubnet(localAddress, normalizedHostIp)) {
        return LocalNetworkValidationResult(
          canConnect: true,
          hostIp: normalizedHostIp,
          localAddresses: localAddresses,
          matchingLocalAddress: localAddress,
          message: 'Host is on the same local network.',
        );
      }
    }

    final localSubnets = localAddresses.map(subnetHint).where((hint) => hint.isNotEmpty).join(', ');
    return LocalNetworkValidationResult(
      canConnect: true,
      hostIp: normalizedHostIp,
      localAddresses: localAddresses,
      message: 'Host IP $normalizedHostIp is not on this device local subnet ($localSubnets). Connection will still be attempted.',
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

  int _lanAddressPriority(String address) {
    if (address.startsWith('192.168.')) return 0;
    if (address.startsWith('10.')) return 1;
    if (isPrivateIpv4(address)) return 2;
    return 3;
  }

  static String _roomKey(String hostIp, int port, String mode) => '$hostIp:$port:$mode';

  static LocalNetworkRoom? parseDiscoveryPacket(String raw, InternetAddress sender) {
    try {
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      if (parsed['type'] != _discoveryType) return null;

      final hostIpValue = parsed['hostIp'];
      final modeValue = parsed['mode'];
      final portValue = parsed['port'];
      if (hostIpValue is! String || modeValue is! String || portValue is! int) {
        return null;
      }

      final hostIp = normalizeHostAddress(hostIpValue.isEmpty ? sender.address : hostIpValue);
      if (!isValidIpv4(hostIp) || !isPrivateIpv4(hostIp)) return null;

      final idValue = parsed['id'];
      final hostNameValue = parsed['hostName'];
      return LocalNetworkRoom(
        id: idValue is String && idValue.isNotEmpty ? idValue : _roomKey(hostIp, portValue, modeValue),
        hostIp: hostIp,
        hostName: hostNameValue is String && hostNameValue.isNotEmpty ? hostNameValue : 'Rule Glyph Host',
        mode: modeValue,
        port: portValue,
        lastSeen: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _startHostDiscovery({
    required String mode,
    required int port,
    int discoveryPort = defaultDiscoveryPort,
  }) async {
    await stopRoomDiscovery();
    await _acquireMulticastLock();
    _hostMode = mode;
    _hostPort = port;
    _discoveryPort = discoveryPort;
    _hostRoomId = '${hostIpAddress}_${port}_${DateTime.now().millisecondsSinceEpoch}';
    try {
      _discoverySocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
        reuseAddress: true,
        reusePort: false,
      );
    } catch (_) {
      await stopRoomDiscovery();
      rethrow;
    }
    _discoverySocket!.broadcastEnabled = true;
    _discoverySocket!.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = _discoverySocket!.receive();
      if (datagram == null) return;
      _handleDiscoveryRequest(
        utf8.decode(datagram.data),
        datagram.address,
        datagram.port,
      );
    });

    void announce() => _sendDiscoveryAnnouncement();
    announce();
    _discoveryTimer = Timer.periodic(const Duration(seconds: 1), (_) => announce());
  }

  void _sendDiscoveryAnnouncement() {
    _sendDiscoveryPacket();
  }

  void _sendDiscoveryPacket({InternetAddress? address, int? port}) {
    final socket = _discoverySocket;
    final roomId = _hostRoomId;
    final mode = _hostMode;
    if (socket == null || roomId == null || mode == null || hostIpAddress.isEmpty) {
      return;
    }

    final payload = utf8.encode(jsonEncode({
      'type': _discoveryType,
      'id': roomId,
      'hostIp': hostIpAddress,
      'hostName': 'Rule Glyph Host',
      'mode': mode,
      'port': _hostPort,
    }));

    if (address != null && port != null) {
      _sendDatagram(socket, payload, address, port);
      return;
    }

    for (final broadcastAddress in _broadcastAddresses()) {
      _sendDatagram(socket, payload, InternetAddress(broadcastAddress), _discoveryPort);
    }
  }

  Iterable<String> _broadcastAddresses() sync* {
    yield '255.255.255.255';
    for (final address in localIpAddresses) {
      final parts = _parseIpv4(address);
      if (parts == null) continue;
      yield '${parts[0]}.${parts[1]}.${parts[2]}.255';
    }
  }

  void _sendDiscoveryRequest({String? mode}) {
    final socket = _discoverySocket;
    if (socket == null) return;

    final payload = utf8.encode(jsonEncode({
      'type': _discoveryRequestType,
      'mode': mode,
    }));

    for (final broadcastAddress in _broadcastAddresses()) {
      _sendDatagram(socket, payload, InternetAddress(broadcastAddress), _discoveryPort);
    }
  }

  void _sendDatagram(
    RawDatagramSocket socket,
    List<int> payload,
    InternetAddress address,
    int port,
  ) {
    try {
      socket.send(payload, address, port);
    } catch (_) {
      // Some networks reject one broadcast address; keep other discovery paths alive.
    }
  }

  void _handleDiscoveryRequest(String raw, InternetAddress address, int port) {
    try {
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      if (parsed['type'] != _discoveryRequestType) return;

      final requestedMode = parsed['mode'];
      if (requestedMode is String && requestedMode.isNotEmpty && requestedMode != _hostMode) {
        return;
      }

      final requesterIp = address.address;
      if (!isPrivateIpv4(requesterIp) && !isLoopbackIpv4(requesterIp)) return;

      _sendDiscoveryPacket(address: address, port: port);
    } catch (_) {
      // Ignore malformed discovery requests.
    }
  }

  Future<void> startRoomScan({
    String? mode,
    int discoveryPort = defaultDiscoveryPort,
  }) async {
    await stopRoomDiscovery();
    await _acquireMulticastLock();
    _discoveryPort = discoveryPort;
    _discoveredRooms.clear();
    _roomDiscoveryController.add(const []);

    final localAddresses = await discoverLocalIpAddresses();
    try {
      _discoverySocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
        reuseAddress: true,
        reusePort: false,
      );
    } catch (_) {
      await stopRoomDiscovery();
      rethrow;
    }

    _discoverySocket!.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = _discoverySocket!.receive();
      if (datagram == null) return;

      final raw = utf8.decode(datagram.data);
      final room = parseDiscoveryPacket(raw, datagram.address);
      if (room == null || (mode != null && room.mode != mode)) return;
      if (localAddresses.contains(room.hostIp)) return;

      _discoveredRooms[_roomKey(room.hostIp, room.port, room.mode)] = room;
      _publishDiscoveredRooms();
    });

    _discoveryTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _sendDiscoveryRequest(mode: mode);
      _discoveredRooms.removeWhere(
        (_, room) => DateTime.now().difference(room.lastSeen) > const Duration(seconds: 5),
      );
      _publishDiscoveredRooms();
    });
    _sendDiscoveryRequest(mode: mode);
  }

  void _publishDiscoveredRooms() {
    final rooms = _discoveredRooms.values.toList()
      ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
    if (!_roomDiscoveryController.isClosed) {
      _roomDiscoveryController.add(List.unmodifiable(rooms));
    }
  }

  Future<void> stopRoomDiscovery() async {
    _discoveryTimer?.cancel();
    _discoveryTimer = null;
    _hostRoomId = null;
    _hostMode = null;
    _discoverySocket?.close();
    _discoverySocket = null;
    _discoveredRooms.clear();
    await _releaseMulticastLock();
  }

  Future<void> _acquireMulticastLock() async {
    if (_multicastLockHeld) return;
    try {
      await _networkChannel.invokeMethod<void>('acquireMulticastLock');
      _multicastLockHeld = true;
    } on MissingPluginException {
      _multicastLockHeld = false;
    } catch (_) {
      _multicastLockHeld = false;
    }
  }

  Future<void> _releaseMulticastLock() async {
    if (!_multicastLockHeld) return;
    try {
      await _networkChannel.invokeMethod<void>('releaseMulticastLock');
    } on MissingPluginException {
      // No native lock on this platform.
    } catch (_) {
      // Ignore lock release failures.
    } finally {
      _multicastLockHeld = false;
    }
  }

  /// Start TCP server acting as multiplayer Host
  Future<void> startHost({String mode = '2', int port = defaultPort}) async {
    await shutdown();
    final localIp = await discoverLocalIp();
    if (localIp.isEmpty) {
      throw const LocalNetworkException(
        'No Wi-Fi/LAN IPv4 address was found. Connect this device to the same Wi-Fi network before hosting.',
      );
    }
    
    role = NetworkRole.host;
    _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
    await _startHostDiscovery(mode: mode, port: port);
    
    _serverSocket!.listen((Socket client) {
      final remoteAddress = client.remoteAddress.address;
      if (!isPrivateIpv4(remoteAddress) && !isLoopbackIpv4(remoteAddress)) {
        client.destroy();
        return;
      }

      if (_clientSocket != null) {
        // Only support 1 connected client at a time for local 2P
        client.destroy();
        return;
      }
      
      _clientSocket = client;
      unawaited(stopRoomDiscovery());
      _connectionStateController.add(true);
      _listenToSocket(client);
      
      // Send a welcome message
      sendMessage(NetworkMessage('join_ack', {'message': 'Connected to host!'}));
    });
  }

  /// Connect to Host acting as Client
  Future<void> connectToHost(String hostIp, {int port = defaultPort}) async {
    await shutdown();
    final validation = await validateHostAddress(hostIp);
    if (!validation.canConnect) {
      throw LocalNetworkException(validation.message);
    }

    role = NetworkRole.client;
    
    _clientSocket = await Socket.connect(validation.hostIp, port, timeout: const Duration(seconds: 5));
    _connectionStateController.add(true);
    _listenToSocket(_clientSocket!);
  }

  void _listenToSocket(Socket socket) {
    StringBuffer buffer = StringBuffer();
    
    socket.listen(
      (data) {
        final rawStr = utf8.decode(data);
        buffer.write(rawStr);
        
        String bufferContent = buffer.toString();
        while (bufferContent.contains('\n')) {
          final parts = bufferContent.split('\n');
          final completeMessage = parts.first;
          bufferContent = parts.sublist(1).join('\n');
          
          if (completeMessage.trim().isNotEmpty) {
            try {
              final msg = NetworkMessage.deserialize(completeMessage);
              if (!_messageController.isClosed) {
                _messageController.add(msg);
              }
            } catch (e) {
              // ignore malformed packets
            }
          }
        }
        buffer.clear();
        buffer.write(bufferContent);
      },
      onDone: () {
        _handleDisconnect();
      },
      onError: (e) {
        _handleDisconnect();
      },
    );
  }

  void _handleDisconnect() {
    _clientSocket = null;
    if (!_connectionStateController.isClosed) {
      _connectionStateController.add(false);
    }
  }

  /// Broadcast message to peer
  void sendMessage(NetworkMessage message) {
    if (_clientSocket != null) {
      try {
        _clientSocket!.write(message.serialize());
      } catch (e) {
        _handleDisconnect();
      }
    }
  }

  /// Shutdown server and sockets
  Future<void> shutdown() async {
    await stopRoomDiscovery();

    final socket = _clientSocket;
    _clientSocket = null;
    socket?.destroy();
    _handleDisconnect();
    
    if (_serverSocket != null) {
      await _serverSocket!.close();
      _serverSocket = null;
    }
    
    role = NetworkRole.none;
  }

  Future<void> dispose() async {
    await shutdown();
    await _messageController.close();
    await _connectionStateController.close();
    await _roomDiscoveryController.close();
  }
}
