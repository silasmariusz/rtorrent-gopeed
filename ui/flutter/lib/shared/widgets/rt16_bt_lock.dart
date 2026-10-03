import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../theme/app_palette.dart';

/// The line over Gopeed's BitTorrent settings while Rtorrent16 takes the torrents. It is the add-on owner's
/// wording and the same in every language, so it is a literal and not in the l10n catalogue.
const rt16BtLockLabel = 'Rtorrent16 enabled';

/// Rtorrent16: while the add-on's shim hands torrents and magnets to rtorrent16, Gopeed's own BitTorrent
/// settings have no effect. With [locked] the [child] stays on the page, greyed out, and takes no pointer or
/// keyboard input, under a line that says why. Without it the child is returned as it is.
class Rt16BtLock extends StatelessWidget {
  const Rt16BtLock({super.key, required this.locked, required this.child});

  final bool locked;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!locked) {
      return child;
    }
    final palette = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 14, color: palette.textPrimary),
              const SizedBox(width: 6),
              Text(
                rt16BtLockLabel,
                key: const ValueKey('rt16-bt-lock-label'),
                style: TextStyle(color: palette.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        Semantics(
          enabled: false,
          child: ExcludeFocus(
            child: AbsorbPointer(child: Opacity(opacity: 0.45, child: child)),
          ),
        ),
      ],
    );
  }
}
