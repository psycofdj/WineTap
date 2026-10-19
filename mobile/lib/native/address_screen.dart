import 'dart:async';

import 'package:flutter/material.dart';

import 'network.dart';
import 'theme.dart';

/// N-E1 — Adresse à saisir dans le navigateur de l'ordinateur (D-04).
/// L'adresse peut changer : elle est relue toutes les 5 secondes.
class AddressScreen extends StatefulWidget {
  const AddressScreen({
    super.key,
    required this.port,
    required this.onConnections,
  });

  final int port;
  final VoidCallback onConnections;

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  String? _ip;
  bool _loaded = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  Future<void> _refresh() async {
    final ip = await localAddress();
    if (!mounted) return;
    setState(() {
      _ip = ip;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      backgroundColor: p.paper,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SubHeader(title: 'Accès depuis un ordinateur'),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: !_loaded
                      ? const SizedBox.shrink()
                      : (_ip == null ? _sansReseau(p) : _adresse(p)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: WtButton(
                  label: 'Connexions autorisées',
                  height: 56,
                  onPressed: widget.onConnections,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _point(Color c) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  );

  Widget _adresse(Palette p) {
    final m = TextStyle(
      fontFamily: mono,
      fontWeight: FontWeight.w500,
      color: p.ink,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Pill(
          label: 'Serveur actif',
          background: p.okTint,
          foreground: p.ok,
          leading: _point(p.ok),
        ),
        const SizedBox(height: 18),
        Text(
          'Dans le navigateur de l’ordinateur, saisissez :',
          style: TextStyle(fontFamily: sans, fontSize: 16, color: p.ink2),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('http://', style: m.copyWith(fontSize: 15, color: p.ink3)),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: SelectableText(
                  _ip!,
                  style: m.copyWith(
                    fontSize: 38,
                    height: 1.1,
                    letterSpacing: -0.38,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                ':${widget.port}',
                style: m.copyWith(fontSize: 24, color: p.ink2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            LucideIcon('wifi', size: 20, color: p.ink2),
            const SizedBox(width: 10),
            Text(
              'Réseau local',
              style: TextStyle(fontFamily: sans, fontSize: 15, color: p.ink2),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'Gardez WineTap ouvert sur le téléphone pendant l’utilisation depuis l’ordinateur. '
          'L’adresse peut changer : elle est toujours à jour ici.',
          style: TextStyle(
            fontFamily: sans,
            fontSize: 14,
            color: p.ink3,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _sansReseau(Palette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Pill(
          label: 'Pas de réseau local',
          background: p.dangerTint,
          foreground: p.danger,
          leading: _point(p.danger),
        ),
        const SizedBox(height: 30),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: p.dangerTint,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: LucideIcon('wifiOff', size: 30, color: p.danger),
        ),
        const SizedBox(height: 12),
        Text(
          'Aucune adresse à afficher',
          style: TextStyle(
            fontFamily: serif,
            fontSize: 32,
            fontWeight: FontWeight.w500,
            height: 1.1,
            color: p.ink,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Le téléphone n’est connecté à aucun réseau Wi-Fi. Connectez-le au même réseau que l’ordinateur ; l’adresse apparaîtra ici.',
          style: TextStyle(
            fontFamily: sans,
            fontSize: 16,
            color: p.ink2,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Sur ce téléphone, WineTap fonctionne normalement.',
          style: TextStyle(fontFamily: sans, fontSize: 14, color: p.ink3),
        ),
      ],
    );
  }
}
