import 'dart:io';
import 'dart:math';

import 'package:network_info_plus/network_info_plus.dart';

/// Resolves the device's own LAN-reachable IPv4 address, whether it's
/// connected to a Wi-Fi network or acting as the hotspot access point itself
/// (see OffTheRecord_HANDOFF.md §4b — `network_info_plus` alone misses the
/// hotspot case because it only reads the Wi-Fi client interface).
Future<String?> resolveLocalIp() async {
  final ifaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLoopback: false,
  );

  const priority = ['ap0', 'swlan0', 'wlan1', 'wlan0'];
  for (final name in priority) {
    final match = ifaces.where((i) => i.name.startsWith(name));
    if (match.isNotEmpty) return match.first.addresses.first.address;
  }

  final wifiIp = await NetworkInfo().getWifiIP();
  if (wifiIp != null && wifiIp.isNotEmpty) return wifiIp;

  return ifaces.isNotEmpty ? ifaces.first.addresses.first.address : null;
}

const _roomCodeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

String generateRoomCode({int length = 4}) {
  final rand = Random.secure();
  return List.generate(length, (_) => _roomCodeChars[rand.nextInt(_roomCodeChars.length)]).join();
}

String generatePlayerId() {
  final rand = Random.secure();
  final bytes = List.generate(8, (_) => rand.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
