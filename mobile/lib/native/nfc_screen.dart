import 'package:flutter/material.dart';

import 'reading.dart';
import 'theme.dart';

const purposes = {
  'consommer': 'Consommer une bouteille',
  'identifier': 'Identifier une bouteille',
  'entree': 'Entrer une bouteille en stock',
  'recherche': 'Rechercher une bouteille par son tag',
};

/// N-E4 — Lecture NFC, plein écran par-dessus la WebView.
class NfcScreen extends StatelessWidget {
  const NfcScreen({super.key, required this.controller});

  final ReadingController controller;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final r = controller.current;
        if (r == null) return const SizedBox.shrink();
        final origin = r.request?.origin;
        return Material(
          color: p.paper,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: Column(
                children: [
                  Center(
                    child: r.fromComputer
                        ? Pill(
                            label:
                                'Demandé par un ordinateur${origin != null ? ' · ${origin.label}' : ''}',
                            background: p.accentTint,
                            foreground: p.accentInk,
                            leading: LucideIcon(
                              'monitor',
                              size: 16,
                              color: p.accentInk,
                              strokeWidth: 2,
                            ),
                          )
                        : Pill(
                            label: 'Depuis ce téléphone',
                            background: p.card2,
                            foreground: p.ink2,
                            leading: LucideIcon(
                              'phone',
                              size: 16,
                              color: p.ink2,
                              strokeWidth: 2,
                            ),
                          ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          (purposes[r.purpose] ?? r.purpose).toUpperCase(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: sans,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 13 * 0.08,
                            color: p.accentInk,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ..._body(r, p),
                      ],
                    ),
                  ),
                  WtButton(label: 'Annuler', onPressed: controller.cancel),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _body(Reading r, Palette p) {
    final titre = TextStyle(
      fontFamily: serif,
      fontSize: 36,
      fontWeight: FontWeight.w500,
      height: 1.1,
      color: p.ink,
    );
    final texte = TextStyle(
      fontFamily: sans,
      fontSize: 16,
      color: p.ink2,
      height: 1.45,
    );
    switch (r.state) {
      case ReadingState.waiting:
        return [
          Container(
            width: 220,
            height: 220,
            margin: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: p.line),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 164,
              height: 164,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: p.line2),
              ),
              alignment: Alignment.center,
              child: Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.accent,
                ),
                alignment: Alignment.center,
                child: LucideIcon('nfc', size: 48, color: p.onAccent),
              ),
            ),
          ),
          Text('Présentez le tag', style: titre, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          SizedBox(
            width: 280,
            child: Text(
              'Approchez le haut du téléphone du tag collé sur la bouteille',
              style: texte,
              textAlign: TextAlign.center,
            ),
          ),
        ];
      case ReadingState.read:
        return [
          Container(
            width: 164,
            height: 164,
            margin: const EdgeInsets.symmetric(vertical: 46),
            decoration: BoxDecoration(shape: BoxShape.circle, color: p.okTint),
            alignment: Alignment.center,
            child: LucideIcon('check', size: 64, color: p.ok),
          ),
          Text('Tag lu', style: titre),
          const SizedBox(height: 14),
          Text(
            r.tag ?? '',
            style: TextStyle(
              fontFamily: mono,
              fontSize: 18,
              fontWeight: FontWeight.w500,
              letterSpacing: 18 * 0.06,
              color: p.ink2,
            ),
          ),
        ];
      case ReadingState.error:
        return [
          Container(
            width: 164,
            height: 164,
            margin: const EdgeInsets.symmetric(vertical: 46),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: p.dangerTint,
            ),
            alignment: Alignment.center,
            child: LucideIcon('alert', size: 60, color: p.danger),
          ),
          Text('Lecture impossible', style: titre, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          SizedBox(
            width: 280,
            child: Text(
              'Le tag n’a pas pu être lu. Gardez le téléphone immobile et réessayez.',
              style: texte,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: TextButton(
              onPressed: controller.retry,
              style: TextButton.styleFrom(
                backgroundColor: p.accent,
                foregroundColor: p.onAccent,
                padding: const EdgeInsets.symmetric(horizontal: 28),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontFamily: sans,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Réessayer'),
            ),
          ),
        ];
    }
  }
}
