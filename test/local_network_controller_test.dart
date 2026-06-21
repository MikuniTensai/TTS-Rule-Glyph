import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rule_glyph_app/engine/local_network_controller.dart';

void main() {
  group('LocalNetworkController address helpers', () {
    test('normalizes copied host addresses', () {
      expect(
        LocalNetworkController.normalizeHostAddress(' 192.168.1.8:12345 '),
        '192.168.1.8',
      );
      expect(
        LocalNetworkController.normalizeHostAddress('http://192.168.1.8:12345/join'),
        '192.168.1.8',
      );
    });

    test('accepts only private IPv4 addresses as LAN addresses', () {
      expect(LocalNetworkController.isPrivateIpv4('192.168.1.8'), isTrue);
      expect(LocalNetworkController.isPrivateIpv4('10.0.0.12'), isTrue);
      expect(LocalNetworkController.isPrivateIpv4('172.16.4.9'), isTrue);
      expect(LocalNetworkController.isPrivateIpv4('172.31.4.9'), isTrue);
      expect(LocalNetworkController.isPrivateIpv4('172.32.4.9'), isFalse);
      expect(LocalNetworkController.isPrivateIpv4('8.8.8.8'), isFalse);
    });

    test('matches clients and hosts on the same LAN subnet', () {
      expect(
        LocalNetworkController.isSameLanSubnet('192.168.1.7', '192.168.1.8'),
        isTrue,
      );
      expect(
        LocalNetworkController.isSameLanSubnet('192.168.2.7', '192.168.1.8'),
        isFalse,
      );
      expect(
        LocalNetworkController.isSameLanSubnet('10.0.0.4', '10.0.0.8'),
        isTrue,
      );
      expect(
        LocalNetworkController.isSameLanSubnet('127.0.0.1', '192.168.1.8'),
        isFalse,
      );
    });

    test('parses valid discovery packets', () {
      final room = LocalNetworkController.parseDiscoveryPacket(
        jsonEncode({
          'type': 'rule_glyph_room',
          'id': 'room-1',
          'hostIp': '192.168.1.8',
          'hostName': 'Rule Glyph Host',
          'mode': '2',
          'port': LocalNetworkController.defaultPort,
        }),
        InternetAddress('192.168.1.8'),
      );

      expect(room, isNotNull);
      expect(room!.id, 'room-1');
      expect(room.hostIp, '192.168.1.8');
      expect(room.mode, '2');
      expect(room.port, LocalNetworkController.defaultPort);
    });

    test('ignores invalid discovery packets', () {
      expect(
        LocalNetworkController.parseDiscoveryPacket(
          jsonEncode({
            'type': 'other_app_room',
            'hostIp': '192.168.1.8',
            'mode': '2',
            'port': LocalNetworkController.defaultPort,
          }),
          InternetAddress('192.168.1.8'),
        ),
        isNull,
      );
      expect(
        LocalNetworkController.parseDiscoveryPacket(
          jsonEncode({
            'type': 'rule_glyph_room',
            'hostIp': '8.8.8.8',
            'mode': '2',
            'port': LocalNetworkController.defaultPort,
          }),
          InternetAddress('8.8.8.8'),
        ),
        isNull,
      );
    });
  });
}
