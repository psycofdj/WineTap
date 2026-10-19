# 14. Annexes

<!-- toc -->

**Sur cette page**

- [A. Composants et versions](#a-composants-et-versions)
  - [A.1 Application mobile](#a1-application-mobile)
  - [A.2 Site web](#a2-site-web)
  - [A.3 Chaîne de livraison](#a3-chaîne-de-livraison)
- [B. Glossaire](#b-glossaire)
- [C. Écarts entre la documentation et le code](#c-écarts-entre-la-documentation-et-le-code)
- [D. Questions ouvertes](#d-questions-ouvertes)

<!-- /toc -->

## A. Composants et versions

Versions résolues au 2026-10-18 (`mobile/pubspec.lock`, `web/package-lock.json`, flux GitHub
Actions).

### A.1 Application mobile

| Composant | Version | Rôle |
|---|---|---|
| Dart | 3.11.4 au moins | Langage |
| Flutter | 3.41.6 sur le poste de développement, dernière du canal `stable` en CI | Cadre d'application |
| `drift`, `drift_flutter` | 2.32.1, 0.3.0 | Base SQLite, requêtes typées, migrations |
| `sqlite3`, `sqlite3_flutter_libs` | 3.2.0, 0.6.0 | Moteur SQLite embarqué ; examen des fichiers de restauration |
| `shelf`, `shelf_router` | 1.4.2, 1.1.4 | Serveur HTTP et routage |
| `webview_flutter` (Android, WKWebView) | 4.14.1 (4.12.0, 3.25.1) | WebView et canal JavaScript |
| `nfc_manager` | 4.2.1 | Lecture NFC, Android et iOS |
| `shared_preferences` | 2.5.5 | Sessions autorisées, réglages |
| `crypto` | 3.0.7 | Empreinte SHA-256 des identifiants de session |
| `url_launcher` | 6.3.3 | Ouverture des liens externes |
| `flutter_svg` | 2.3.0 | Icônes des écrans natifs |
| `wakelock_plus` | 1.5.1 | Écran maintenu allumé |
| `package_info_plus` | 9.0.1 | Version de l'application |
| `path_provider` | 2.1.5 | Dossier des documents |
| Android | Java 17 ; SDK minimal, cible et de compilation : valeurs par défaut de Flutter | Plate-forme |
| iOS | 15.0 au moins (moteur web du site) | Plate-forme |

### A.2 Site web

| Composant | Version | Rôle |
|---|---|---|
| Node.js | 22 (`web/.nvmrc`) | Construction |
| `svelte` | 5.57.2 | Cadre |
| `vite`, `@sveltejs/vite-plugin-svelte` | 8.3.4, 7.3.1 | Construction, serveur de développement |
| `svelte-check` | 4.7.7 | Vérification |
| `@fontsource-variable/newsreader`, `@fontsource/ibm-plex-sans`, `@fontsource/ibm-plex-mono` | 5.3 | Polices empaquetées |

### A.3 Chaîne de livraison

| Composant | Version |
|---|---|
| Exécuteurs | `ubuntu-24.04`, `macos-26` |
| `actions/checkout` | v6 |
| `actions/setup-node`, `actions/setup-java`, `actions/upload-artifact`, `actions/download-artifact` | v4 |
| `subosito/flutter-action` | v2 |
| `r0adkll/upload-google-play` | v1 |
| `dependabot/fetch-metadata` | v2 |
| `codemagic-cli-tools` | dernière version, installée par `pip` |

## B. Glossaire

| Terme | Définition |
|---|---|
| **AAB** | *Android App Bundle* : format de publication d'une application Android sur Google Play. |
| **AOC, AOP** | Appellation d'origine contrôlée, protégée. |
| **App Store Connect** | Console d'Apple pour publier une application iOS. |
| **CSP** | *Content Security Policy* : en-tête qui limite ce qu'une page peut charger et exécuter. |
| **DNS rebinding** | Attaque où un site tiers fait pointer son nom de domaine vers une adresse du réseau local, pour que le navigateur de la victime y envoie des requêtes. |
| **drift** | Bibliothèque Dart d'accès à SQLite, avec requêtes typées et migrations. |
| **INAO** | Institut national de l'origine et de la qualité, qui tient la liste des appellations. |
| **IPA** | Paquet d'une application iOS. |
| **NFC** | *Near Field Communication* : lecture sans contact à quelques centimètres, à 13,56 MHz. |
| **Pont** | Objet JavaScript `window.winetapBridge`, par lequel le site appelle le code natif de l'application. |
| **Premier plan** | État d'une application visible à l'écran et active. |
| **RFID UHF** | Identification par radiofréquence à longue portée, utilisée par la première version de WineTap. |
| **Server-Sent Events (SSE)** | Flux HTTP gardé ouvert, par lequel le serveur pousse des événements au navigateur ; l'objet `EventSource` le consomme et se reconnecte seul. |
| **shelf** | Bibliothèque Dart de serveur HTTP. |
| **SIQO** | Signes officiels d'identification de la qualité et de l'origine. |
| **SPA** | *Single Page Application* : site d'une seule page, dont le JavaScript affiche les écrans. |
| **Svelte** | Cadre de construction d'interfaces web, compilé en JavaScript. |
| **UID** | Identifiant matériel d'un tag NFC, écrit à la fabrication. |
| **Vite** | Outil de construction et serveur de développement pour le web. |
| **WAL** | *Write-Ahead Log* : journal de SQLite, dans un fichier `-wal` à côté de la base. |
| **WebView** | Composant qui affiche une page web à l'intérieur d'une application. |

## C. Écarts entre la documentation et le code

Le DAT suit le code. Les écarts suivants ont été relevés le 2026-10-18, après la mise à jour du
README, de `docs/`, de `spec.md` et de la politique de confidentialité pour la v3.

| Document | Ce qu'il dit | Ce que fait le code |
|---|---|---|
| `specs/v3-web.md`, §5.2 | Une session survit à un changement d'adresse IP du téléphone | Le cookie est lié à l'adresse saisie : il faut autoriser de nouveau ; accepté (R-20) |
| `specs/v3-web.md`, §5.2 ; `web/API.md`, §1 | L'en-tête `Host` doit être l'adresse du téléphone ou `localhost` | Toute adresse IP littérale est acceptée, en plus de `localhost` ; l'effet contre le *DNS rebinding* est le même |
| `specs/v3-web.md`, §5.1 | N-E1 affiche le nom du réseau Wi-Fi si le système le permet | N-E1 affiche « Réseau local », sans nom de réseau |
| `web/API.md`, §7 | Statut `erreur` de l'événement `scan` | Jamais émis (R-35) |
| `spec.md` | Raspberry Pi, `rpc-server` gRPC, programme `cellar`, voyants, journal d'événements ; images `specs/generated/*.png` | Rien de cela n'existe ; une note en tête le signale. Les images n'existent pas |
| Commentaire de `dev_seed.dart` | Version de développement reconnue à `+dev` | Reconnue à `0.0.0` (R-14) |

## D. Questions ouvertes

| # | Question | Pourquoi elle compte |
|---|---|---|
| Q-04 | La sauvegarde du système Android capture-t-elle réellement la base ? | Conditionne la reprise après perte du téléphone (R-10, R-11). |
| Q-06 | Les sessions autorisées doivent-elles rester sans expiration ? | Durée d'un accès oublié (R-01). |

Questions résolues :

| # | Question | Réponse (2026-10-18) | Effet sur le DAT |
|---|---|---|---|
| Q-01 | Le dépôt `psycofdj/WineTap` est-il public ? | Oui | Paquets signés de la release téléchargeables par tous ; CI gratuite ; accès des forks aux secrets décrit au [§10.4](10-livraison.md#104-signature-et-secrets) |
| Q-02 | L'application est-elle publiée au-delà des pistes de test ? | Oui, sur l'App Store ; Google Play reste sur la piste interne | Les utilisateurs iOS recevront la v3 à sa publication (R-24) |
| Q-03 | `scripts/build_packages.sh` sert-il encore à publier ? | Non, la CI publie | R-02 en mineur, R-14 en amélioration |
| Q-05 | Quelle version minimale d'iOS la v3 doit-elle déclarer ? | iOS 15 | R-24 levé |
| Q-07 | Faut-il garder une session autorisée quand l'adresse du téléphone change ? | Non : les baux DHCP sont stables sur la plupart des réseaux domestiques | R-20 accepté |
