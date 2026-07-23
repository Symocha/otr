import 'package:flutter/material.dart';

import 'palette.dart';

/// Shared "T R" monogram used on Login and Play — the only two screens
/// that show it.
class OtrLogo extends StatelessWidget {
  const OtrLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'images/SQ-6.png',
          width: 110,
          height: 110,
        ),
        const SizedBox(width: 12),
        const Text(
          "T R",
          style: TextStyle(
            color: OtrColors.textPrimary,
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}
