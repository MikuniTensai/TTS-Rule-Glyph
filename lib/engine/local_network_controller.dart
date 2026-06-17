import 'dart:convert';
import 'dart:io';
import 'dart:async';

enum NetworkRole { host, client, none }

class NetworkMessage {
  final String type; // 'level', 'move', 'rule', 'reset', 'undo', 'join_ack'
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

  NetworkRole role = NetworkRole.none;
  ServerSocket? _serverSocket;
  Socket? _clientSocket; // If host: connection to client. If client: connection to host.
  
  final _messageController = StreamController<NetworkMessage>.broadcast();
  Stream<NetworkMessage> get messageStream => _messageController.stream;

  final _connectionStateController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  bool get isConnected => _clientSocket != null;

  String hostIpAddress = '';
  
  LocalNetworkController();

  /// Discover own local IP address on Wi-Fi network
  Future<String> discoverLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
        includeLoopback: false,
      );

      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          // Look for common LAN subnets
          if (addr.address.startsWith('192.168.') ||
              addr.address.startsWith('10.') ||
              _isPrivate172Address(addr.address)) {
            hostIpAddress = addr.address;
            return addr.address;
          }
        }
      }
      
      // Fallback
      if (interfaces.isNotEmpty && interfaces.first.addresses.isNotEmpty) {
        hostIpAddress = interfaces.first.addresses.first.address;
        return hostIpAddress;
      }
    } catch (e) {
      // ignore
    }
    hostIpAddress = '127.0.0.1';
    return hostIpAddress;
  }

  bool _isPrivate172Address(String address) {
    final parts = address.split('.');
    if (parts.length != 4 || parts[0] != '172') return false;
    final second = int.tryParse(parts[1]);
    return second != null && second >= 16 && second <= 31;
  }

  /// Start TCP server acting as multiplayer Host
  Future<void> startHost({int port = defaultPort}) async {
    await shutdown();
    await discoverLocalIp();
    
    role = NetworkRole.host;
    _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
    
    _serverSocket!.listen((Socket client) {
      if (_clientSocket != null) {
        // Only support 1 connected client at a time for local 2P
        client.destroy();
        return;
      }
      
      _clientSocket = client;
      _connectionStateController.add(true);
      _listenToSocket(client);
      
      // Send a welcome message
      sendMessage(NetworkMessage('join_ack', {'message': 'Connected to host!'}));
    });
  }

  /// Connect to Host acting as Client
  Future<void> connectToHost(String hostIp, {int port = defaultPort}) async {
    await shutdown();
    role = NetworkRole.client;
    
    _clientSocket = await Socket.connect(hostIp, port, timeout: const Duration(seconds: 5));
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
  }
}
