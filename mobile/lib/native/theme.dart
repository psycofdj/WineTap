import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Charte du site (tokens.css, D-15), pour que le passage de la WebView à un
/// écran natif ne se voie pas.
class Palette {
  const Palette._({
    required this.paper,
    required this.card,
    required this.card2,
    required this.line,
    required this.line2,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.accent,
    required this.onAccent,
    required this.accentTint,
    required this.accentInk,
    required this.danger,
    required this.dangerTint,
    required this.warn,
    required this.warnTint,
    required this.ok,
    required this.okTint,
  });

  final Color paper, card, card2, line, line2, ink, ink2, ink3;
  final Color accent, onAccent, accentTint, accentInk;
  final Color danger, dangerTint, warn, warnTint, ok, okTint;

  static const clair = Palette._(
    paper: Color(0xFFF6F1E7),
    card: Color(0xFFFFFDF8),
    card2: Color(0xFFEFE7D8),
    line: Color(0xFFE4D9C6),
    line2: Color(0xFFCDBFA6),
    ink: Color(0xFF2A1D15),
    ink2: Color(0xFF5C4A3C),
    ink3: Color(0xFF76624F),
    accent: Color(0xFF7B1E2E),
    onAccent: Color(0xFFFFFDF8),
    accentTint: Color(0xFFF3E3E1),
    accentInk: Color(0xFF7B1E2E),
    danger: Color(0xFFA8321F),
    dangerTint: Color(0xFFF8E2DB),
    warn: Color(0xFF7F5300),
    warnTint: Color(0xFFF6E9C8),
    ok: Color(0xFF2F6B3A),
    okTint: Color(0xFFE2EDD9),
  );

  static const sombre = Palette._(
    paper: Color(0xFF1A1411),
    card: Color(0xFF241C17),
    card2: Color(0xFF2F2520),
    line: Color(0xFF3A2E27),
    line2: Color(0xFF54443A),
    ink: Color(0xFFF3EADB),
    ink2: Color(0xFFCDBFAE),
    ink3: Color(0xFFA8988A),
    accent: Color(0xFFE09AA4),
    onAccent: Color(0xFF1A1411),
    accentTint: Color(0x29E09AA4),
    accentInk: Color(0xFFE9AEB6),
    danger: Color(0xFFF1A097),
    dangerTint: Color(0x24F1A097),
    warn: Color(0xFFE6B868),
    warnTint: Color(0x24E6B868),
    ok: Color(0xFF9CCB98),
    okTint: Color(0x249CCB98),
  );

  static Palette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? sombre : clair;
}

const serif = 'Newsreader';
const sans = 'IBM Plex Sans';
const mono = 'IBM Plex Mono';

ThemeData winetapTheme(Brightness b) {
  final p = b == Brightness.dark ? Palette.sombre : Palette.clair;
  return ThemeData(
    brightness: b,
    fontFamily: sans,
    scaffoldBackgroundColor: p.paper,
    colorScheme: ColorScheme.fromSeed(
      seedColor: p.accent,
      brightness: b,
      surface: p.card,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.ink,
      contentTextStyle: TextStyle(
        fontFamily: sans,
        fontSize: 15,
        color: p.paper,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

/// Tracés Lucide (les mêmes que le site, src/lib/icones.js).
const lucide = {
  'nfc':
      'M6 8.32a7.43 7.43 0 0 1 0 7.36M9.46 6.21a11.76 11.76 0 0 1 0 11.58M12.91 4.1a15.91 15.91 0 0 1 .01 15.8M16.37 2a20.16 20.16 0 0 1 0 20',
  'check': 'M20 6 9 17l-5-5',
  'alert':
      'm21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3M12 9v4M12 17h.01',
  'monitor':
      'M4 3h16a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2zM8 21h8M12 17v4',
  'phone':
      'M7 2h10a2 2 0 0 1 2 2v16a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2zM12 18h.01',
  'chevL': 'm15 18-6-6 6-6',
  'wifi':
      'M12 20h.01M2 8.82a15 15 0 0 1 20 0M5 12.859a10 10 0 0 1 14 0M8.5 16.429a5 5 0 0 1 7 0',
  'wifiOff':
      'M12 20h.01M8.5 16.429a5 5 0 0 1 7 0M5 12.859a10 10 0 0 1 5.17-2.69M19 12.859a10 10 0 0 0-2.007-1.523M2 8.82a15 15 0 0 1 4.177-2.643M22 8.82a15 15 0 0 0-11.288-3.764M2 2l20 20',
  'shield':
      'M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z',
};

/// Icône Lucide en trait.
class LucideIcon extends StatelessWidget {
  const LucideIcon(
    this.name, {
    super.key,
    this.size = 24,
    this.color,
    this.strokeWidth = 1.75,
  });

  final String name;
  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final c =
        color ??
        DefaultTextStyle.of(context).style.color ??
        Palette.of(context).ink;
    final hex =
        '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    final opacity = (c.a).toStringAsFixed(3);
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="$hex" stroke-opacity="$opacity" '
      'stroke-width="$strokeWidth" stroke-linecap="round" stroke-linejoin="round"><path d="${lucide[name]}"/></svg>',
      width: size,
      height: size,
    );
  }
}

/// Bouton de la charte, format téléphone.
class WtButton extends StatelessWidget {
  const WtButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.height = 56,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool danger;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final bg = primary ? p.accent : p.card;
    final fg = primary ? p.onAccent : (danger ? p.danger : p.ink);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: primary ? BorderSide.none : BorderSide(color: p.line2),
          ),
          textStyle: const TextStyle(
            fontFamily: sans,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

/// Pastille ronde d'état.
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.leading,
  });

  final String label;
  final Color background, foreground;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: sans,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// En-tête des sous-pages : retour de 44, titre 17 / 600.
class SubHeader extends StatelessWidget {
  const SubHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              tooltip: 'Retour',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: LucideIcon('chevL', color: p.ink),
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: sans,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: p.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _mois = [
  'janv.',
  'févr.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.',
];

/// « 12 oct. 2026 »
String dateFr(DateTime d) {
  final l = d.toLocal();
  return '${l.day} ${_mois[l.month - 1]} ${l.year}';
}

/// « 20:14 »
String heureFr(DateTime d) {
  final l = d.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

/// « il y a 2 min », « le 28 sept. »
String depuisFr(DateTime d, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final diff = n.difference(d);
  if (diff.inMinutes < 1) return 'à l’instant';
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
  final l = d.toLocal();
  return 'le ${l.day} ${_mois[l.month - 1]}${l.year == n.year ? '' : ' ${l.year}'}';
}
