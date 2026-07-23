import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:off_the_record/api/spotApi.dart';
import 'package:off_the_record/state/session_state.dart';
import 'package:off_the_record/shell/mainShell.dart';
import 'package:off_the_record/storage/playlist_repository.dart';
import 'package:off_the_record/theme/otr_logo.dart';
import 'package:off_the_record/theme/palette.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await playlistRepository.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OTR Login',
      debugShowCheckedModeBanner: false,
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _loading = false;
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _spotSignIn() async {
    setState(() => _loading = true);
    try {
      await SpotApi.login();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
      setState(() => _loading = false);
    }
  }


  void signIn() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),

      );
      return;
    }
    sessionState.playerName = name;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OtrColors.background,
      body: Column(
        children: [
          const Expanded(
            flex: 4,
            child: Center(child: OtrLogo()),
          ),
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: OtrColors.background,
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 50),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 360,
                      height: 48,
                      child: TextField(
                        controller: _nameController,
                        style: const TextStyle(color: OtrColors.textPrimary),
                        maxLength: 32,
                        maxLengthEnforcement: MaxLengthEnforcement.enforced,
                        buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                        decoration: InputDecoration(
                          hintText: 'Enter your name',
                          hintStyle: const TextStyle(color: OtrColors.textMuted),
                          filled: true,
                          fillColor: OtrColors.surfaceRaised,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 360,
                      height: 55,
                      child: ElevatedButton.icon(
                        onPressed: signIn,
                        icon: const Icon(Icons.person),
                        label: const Text('Guest Sign In'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: OtrColors.magenta,
                          foregroundColor: OtrColors.onMagenta,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 360,
                      height: 55,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _spotSignIn,
                        icon: _loading
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Icon(Icons.music_note),
                        label: Text(
                            _loading ? 'Connecting...' : 'Spotify Sign In'
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1DB954),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
