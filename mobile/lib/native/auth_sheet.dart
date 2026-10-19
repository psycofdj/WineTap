import 'package:flutter/material.dart';

import '../server/sessions.dart';
import 'theme.dart';

/// N-E2 — Demande d'autorisation d'un ordinateur. Renvoie true pour autoriser.
Future<bool?> showAuthSheet(BuildContext context, AccessRequest request) {
  final p = Palette.of(context);
  return showModalBottomSheet<bool>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    // La hauteur suit le contenu (sinon limitée aux 9/16 de l'écran).
    isScrollControlled: true,
    backgroundColor: p.card,
    barrierColor: const Color(0x732A1D15),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => _AuthSheet(request: request),
  );
}

class _AuthSheet extends StatelessWidget {
  const _AuthSheet({required this.request});

  final AccessRequest request;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final c = request.client;
    final lib = TextStyle(fontFamily: sans, fontSize: 15, color: p.ink3);
    final val = TextStyle(
      fontFamily: sans,
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: p.ink,
    );
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: p.line2,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: p.accentTint,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: LucideIcon(
                  'monitor',
                  size: 28,
                  color: p.accentInk,
                  strokeWidth: 1.6,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Autoriser cette connexion ?',
                style: TextStyle(
                  fontFamily: serif,
                  fontSize: 30,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                  color: p.ink,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: p.paper,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Table(
                  columnWidths: const {
                    0: IntrinsicColumnWidth(),
                    1: FlexColumnWidth(),
                  },
                  children: [
                    _ligne(
                      'Navigateur',
                      Text(
                        '${c.browser}${c.browserVersion.isEmpty ? '' : ' ${c.browserVersion}'}',
                        style: val,
                      ),
                      lib,
                    ),
                    _ligne('Système', Text(c.os, style: val), lib),
                    _ligne(
                      'Adresse IP',
                      Text(
                        c.ip,
                        style: TextStyle(
                          fontFamily: mono,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: p.ink,
                        ),
                      ),
                      lib,
                    ),
                    _ligne(
                      'Heure',
                      Text(
                        heureFr(c.requestedAt),
                        style: val.copyWith(fontWeight: FontWeight.w400),
                      ),
                      lib,
                      dernier: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Ce navigateur aura accès à toute la cave, jusqu’à ce que vous révoquiez la connexion.',
                style: TextStyle(fontFamily: sans, fontSize: 14, color: p.ink2),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: WtButton(
                      label: 'Refuser',
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: WtButton(
                      label: 'Autoriser',
                      primary: true,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  TableRow _ligne(
    String libelle,
    Widget valeur,
    TextStyle style, {
    bool dernier = false,
  }) => TableRow(
    children: [
      Padding(
        padding: EdgeInsets.only(right: 16, bottom: dernier ? 0 : 10),
        child: Text(libelle, style: style),
      ),
      Padding(
        padding: EdgeInsets.only(bottom: dernier ? 0 : 10),
        child: valeur,
      ),
    ],
  );
}
