import 'package:flutter/material.dart';

/// Neon-party palette (see OffTheRecord_HANDOFF.md §8.2), now applied
/// app-wide except the Playlists tab, which keeps its original look until
/// that gets its own pass.
abstract class OtrColors {
  static const background = Color(0xFF0B0710);
  static const surfaceRaised = Color(0xFF1A1424);
  static const surfaceAlt = Color(0xFF251C33);
  static const trackInactive = Color(0xFF241A2E);
  static const borderDim = Color(0xFF3D2B4F);
  static const divider = Color(0xFF2A2035);

  static const textPrimary = Color(0xFFEDE9F5);
  static const textSecondary = Color(0xFFB8AEC9);
  static const textMuted = Color(0xFF7E7590);
  static const textDisabled = Color(0xFF6E6580);

  /// Muted player-name color for a "no" (unrelated) guess row.
  static const nameNeutral = Color(0xFF8A8296);

  static const magenta = Color(0xFFFF2D95);
  static const onMagenta = Color(0xFF3D0022);

  static const cyan = Color(0xFF00E5FF);
  static const onCyan = Color(0xFF04323A);
  static const cyanTintBg = Color(0xFF0C2B31);
  static const cyanTintText = Color(0xFF8FD9E6);

  static const amber = Color(0xFFFFB020);
  static const amberTintBg = Color(0xFF2E2110);
  static const amberTintText = Color(0xFFF5D9A8);
  static const amberTintBorder = Color(0xFF6B4A12);

  static const purple = Color(0xFF7B2E8E);
  static const onPurple = Color(0xFFEDD5F5);
  static const dangerRed = Color(0xFFFF2D2D);
}
