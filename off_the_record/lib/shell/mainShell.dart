import 'package:flutter/material.dart';
import 'package:off_the_record/api/spotApi.dart';
import 'package:off_the_record/dto/transfer.dart';
import 'package:off_the_record/pages/login_ui.dart';
import 'package:off_the_record/pages/play_ui.dart';
import 'package:off_the_record/pages/playlist_ui.dart';
import 'package:off_the_record/theme/palette.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = [
    playPage(),
    playlistPage(),
  ];

  Future<void> _logout() async {
    await SpotApi.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: OtrColors.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, color: OtrColors.textPrimary, size: 40),
                const SizedBox(width: 12),
                Text(
                  playerName.isNotEmpty ? playerName : 'Guest',
                  style: const TextStyle(
                    color: OtrColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            ListTile(
              leading: const Icon(Icons.logout, color: OtrColors.dangerRed),
              title: const Text('Logout', style: TextStyle(color: OtrColors.dangerRed)),
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: OtrColors.background,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: _openSettings,
                icon: const Icon(Icons.person, color: OtrColors.textPrimary, size: 32),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 16),
              Text(
                playerName.isNotEmpty ? playerName : 'Guest',
                style: const TextStyle(
                  color: OtrColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 21,
                ),
              ),
            ],
          ),
        ),
        leadingWidth: 160,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        backgroundColor: OtrColors.surfaceRaised,
        selectedItemColor: OtrColors.magenta,
        unselectedItemColor: OtrColors.textMuted,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.play_circle_outline),
            activeIcon: Icon(Icons.play_circle),
            label: 'Play',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.queue_music_outlined),
            activeIcon: Icon(Icons.queue_music),
            label: 'Playlists',
          ),
        ],
      ),
    );
  }
}
