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
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: OtrColors.magenta,
            boxShadow: [BoxShadow(color: OtrColors.magenta.withValues(alpha: 0.45), blurRadius: 30, spreadRadius: 2)],
          ),
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
