import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:off_the_record/net/hotspot_settings.dart';
import 'package:off_the_record/theme/palette.dart';

/// The host lobby's two-step join affordance (OffTheRecord_HANDOFF.md §4b).
///
/// Players must be on the host's network *before* the game QR is reachable, so
/// step 1 is a standard Wi-Fi QR the stock camera joins natively, and step 2 is
/// the `{ip, port, room}` game payload. When the party is already on shared
/// Wi-Fi the host can skip straight to step 2.
class JoinQrCard extends StatefulWidget {
  final String gamePayload;

  const JoinQrCard({super.key, required this.gamePayload});

  @override
  State<JoinQrCard> createState() => _JoinQrCardState();
}

class _JoinQrCardState extends State<JoinQrCard> {
  static const _qrSize = 116.0;

  int _step = 0;

  @override
  void initState() {
    super.initState();
    hotspotSettings.addListener(_onChanged);
    if (!hotspotSettings.isLoaded) {
      hotspotSettings.load();
    } else if (!hotspotSettings.isConfigured) {
      // Nothing to show on step 1 — open straight on the game QR.
      _step = 1;
    }
  }

  @override
  void dispose() {
    hotspotSettings.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _editHotspot() async {
    final ssidController = TextEditingController(text: hotspotSettings.ssid);
    final passwordController = TextEditingController(text: hotspotSettings.password);

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: OtrColors.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hotspot details',
              style: TextStyle(
                color: OtrColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Android will not let the app read these itself, so type them once '
              'and OffTheRecord will remember them for next time.',
              style: TextStyle(color: OtrColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 20),
            _field(controller: ssidController, label: 'Network name (SSID)'),
            const SizedBox(height: 12),
            _field(controller: passwordController, label: 'Password'),
            const SizedBox(height: 20),
            Row(
              children: [
                if (hotspotSettings.isConfigured)
                  TextButton(
                    onPressed: () async {
                      await hotspotSettings.clear();
                      if (ctx.mounted) Navigator.pop(ctx, false);
                    },
                    child: const Text('Forget', style: TextStyle(color: OtrColors.textMuted)),
                  ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: OtrColors.magenta,
                    foregroundColor: OtrColors.onMagenta,
                  ),
                  child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    final ssid = ssidController.text.trim();
    if (ssid.isEmpty) return;
    await hotspotSettings.save(ssid: ssid, password: passwordController.text);
    if (mounted) setState(() => _step = 0);
  }

  static Widget _field({required TextEditingController controller, required String label}) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: OtrColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: OtrColors.textMuted),
        filled: true,
        fillColor: OtrColors.surfaceAlt,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: OtrColors.borderDim),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: OtrColors.magenta),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _stepChip(index: 0, label: '1 · Wi-Fi'),
            const SizedBox(width: 8),
            _stepChip(index: 1, label: '2 · Game'),
          ],
        ),
        const SizedBox(height: 10),
        if (_step == 0) _wifiStep() else _gameStep(),
      ],
    );
  }

  Widget _stepChip({required int index, required String label}) {
    final selected = _step == index;
    return InkWell(
      onTap: () => setState(() => _step = index),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? OtrColors.magenta : OtrColors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? OtrColors.onMagenta : OtrColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _wifiStep() {
    final payload = hotspotSettings.wifiQrPayload;
    if (payload == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: _qrSize,
            height: _qrSize,
            decoration: BoxDecoration(
              color: OtrColors.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: OtrColors.borderDim, width: 1.5),
            ),
            child: const Icon(Icons.wifi_off, color: OtrColors.textMuted, size: 34),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _editHotspot,
            child: const Text(
              'Set hotspot details',
              style: TextStyle(color: OtrColors.magenta, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _qrFrame(payload),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                'Turn on your hotspot, then scan to join ${hotspotSettings.ssid}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: OtrColors.textMuted, fontSize: 11),
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: _editHotspot,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.edit, color: OtrColors.textMuted, size: 14),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _gameStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _qrFrame(widget.gamePayload),
        const SizedBox(height: 6),
        const Text(
          'Already on the network? Scan to join the lobby',
          textAlign: TextAlign.center,
          style: TextStyle(color: OtrColors.textMuted, fontSize: 11),
        ),
      ],
    );
  }

  Widget _qrFrame(String data) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: OtrColors.magenta, width: 2),
      ),
      child: QrImageView(data: data, size: _qrSize, backgroundColor: Colors.white),
    );
  }
}
