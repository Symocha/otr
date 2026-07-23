import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:off_the_record/dto/transfer.dart';
import 'package:off_the_record/net/game_client.dart';
import 'package:off_the_record/pages/lobby_ui.dart';
import 'package:off_the_record/theme/palette.dart';

class JoinScanPage extends StatefulWidget {
  const JoinScanPage({super.key});

  @override
  State<JoinScanPage> createState() => _JoinScanPageState();
}

class _JoinScanPageState extends State<JoinScanPage> {
  bool _connecting = false;
  String? _error;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_connecting) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final raw = barcodes.first.rawValue;
    if (raw == null) return;

    setState(() {
      _connecting = true;
      _error = null;
    });

    GameClient? client;
    try {
      final payload = jsonDecode(raw) as Map<String, dynamic>;
      final ip = payload['ip'] as String;
      final port = payload['port'] as int;
      final room = payload['room'] as String;

      client = GameClient();
      await client.connect(ip, port);
      await client.join(room, playerName.isNotEmpty ? playerName : 'Guest');

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LobbyPage(isHost: false, client: client!)),
      );
    } catch (e) {
      client?.disconnect();
      if (!mounted) return;
      setState(() {
        _error = 'Could not join lobby: $e';
        _connecting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OtrColors.background,
      appBar: AppBar(
        backgroundColor: OtrColors.background,
        elevation: 0,
        title: const Text('Scan Lobby QR', style: TextStyle(color: OtrColors.textPrimary)),
        iconTheme: const IconThemeData(color: OtrColors.textPrimary),
      ),
      body: Stack(
        children: [
          MobileScanner(onDetect: _onDetect),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: OtrColors.magenta, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          if (_connecting)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: OtrColors.magenta),
              ),
            ),
          if (_error != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 32,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: OtrColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: OtrColors.dangerRed),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
