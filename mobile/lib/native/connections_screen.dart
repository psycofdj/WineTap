import 'package:flutter/material.dart';

import '../server/events.dart';
import '../server/sessions.dart';
import 'theme.dart';

/// N-E3 — Ordinateurs autorisés, révocation (D-10).
class ConnectionsScreen extends StatelessWidget {
  const ConnectionsScreen({
    super.key,
    required this.sessions,
    required this.events,
    required this.onMessage,
  });

  final SessionStore sessions;
  final EventHub events;
  final void Function(String) onMessage;

  Future<void> _revoke(AuthorizedSession s) async {
    await sessions.revoke(s.hash);
    events.session(s.hash, 'revoquee');
    onMessage('Connexion révoquée');
  }

  Future<void> _revokeAll() async {
    for (final h in await sessions.revokeAll()) {
      events.session(h, 'revoquee');
    }
    onMessage('Toutes les connexions sont révoquées');
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      backgroundColor: p.paper,
      body: SafeArea(
        child: StreamBuilder<void>(
          stream: sessions.changes,
          builder: (context, _) {
            final list = sessions.authorized;
            return Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SubHeader(title: 'Connexions autorisées'),
                  const SizedBox(height: 14),
                  if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 40, 12, 0),
                      child: Text(
                        'Aucun ordinateur autorisé. Le prochain navigateur qui ouvrira l’adresse demandera une autorisation.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: sans,
                          fontSize: 15,
                          color: p.ink2,
                          height: 1.45,
                        ),
                      ),
                    )
                  else ...[
                    Expanded(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Container(
                          margin: const EdgeInsets.only(left: 12),
                          decoration: BoxDecoration(
                            color: p.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: p.line),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: list.length,
                            separatorBuilder: (_, _) =>
                                Divider(height: 1, thickness: 1, color: p.line),
                            itemBuilder: (context, i) => _ligne(p, list[i]),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: WtButton(
                        label: 'Tout révoquer',
                        danger: true,
                        onPressed: _revokeAll,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _ligne(Palette p, AuthorizedSession s) {
    final actif =
        DateTime.now().difference(s.lastSeen) < const Duration(minutes: 2);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          LucideIcon('monitor', size: 22, color: p.ink2, strokeWidth: 1.6),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        s.label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: sans,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: p.ink,
                        ),
                      ),
                    ),
                    if (actif) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: p.ok,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  'Autorisé le ${dateFr(s.authorizedAt)} · actif ${depuisFr(s.lastSeen)}',
                  style: TextStyle(
                    fontFamily: sans,
                    fontSize: 13,
                    color: p.ink2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 40,
            child: OutlinedButton(
              onPressed: () => _revoke(s),
              style: OutlinedButton.styleFrom(
                foregroundColor: p.danger,
                backgroundColor: p.card,
                side: BorderSide(color: p.line2),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontFamily: sans,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Révoquer'),
            ),
          ),
        ],
      ),
    );
  }
}
