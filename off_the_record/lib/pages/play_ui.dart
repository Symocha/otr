import 'package:flutter/material.dart';

import 'package:off_the_record/theme/otr_logo.dart';
import 'package:off_the_record/theme/palette.dart';
import 'join_ui.dart';
import 'lobby_ui.dart';

class playPage extends StatelessWidget {
  const playPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: OtrColors.background,
      child: Column(
        children: [
          const Expanded(
            flex: 4,
            child: Center(child: OtrLogo()),
          ),
          Expanded(
            flex: 6,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: OtrColors.background,
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 130,
                          height: 130,
                          child: ElevatedButton(
                            onPressed: () async{
                              Navigator.push(context, MaterialPageRoute(
                                builder: (context) => const LobbyPage(isHost: true),
                              ));
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: OtrColors.magenta,
                              foregroundColor: OtrColors.onMagenta,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: const Text(
                              "Create Lobby",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 130,
                          height: 130,
                          child: OutlinedButton(
                            onPressed: () async{
                              Navigator.push(context, MaterialPageRoute(
                                builder: (context) => const JoinScanPage(),
                              ));
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: OtrColors.textPrimary,
                              side: const BorderSide(
                                color: OtrColors.borderDim,
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: const Text(
                              "Join Lobby",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              ),
            ),
          ),
        ],
      ),
    );
  }
}
