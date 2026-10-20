# 1. Objet et périmètre

<!-- toc -->

**Sur cette page**

- [1.1 Objet](#11-objet)
- [1.2 Lecteurs](#12-lecteurs)
- [1.3 Périmètre](#13-périmètre)
- [1.4 État du code](#14-état-du-code)
- [1.5 Conventions](#15-conventions)
  - [1.5.1 Vocabulaire](#151-vocabulaire)
  - [1.5.2 Couleurs des vins](#152-couleurs-des-vins)
  - [1.5.3 Noms et dates](#153-noms-et-dates)

<!-- /toc -->

## 1.1 Objet

Ce document décrit l'architecture technique de WineTap. Il sert trois usages :

- **partager une connaissance commune** du système : ce qui tourne, où, comment le site, le
  serveur et le lecteur NFC du téléphone se parlent, et où vivent les données ;
- **faire évoluer le système en connaissance de cause** : les choix structurants, leurs raisons
  et les risques qui restent sont rassemblés aux chapitres [12](12-decisions-architecture.md) et
  [13](13-risques.md) ;
- **répondre aux questions des tiers** : magasins d'applications (permissions, données
  collectées), utilisateurs avertis (où sont mes données, qui peut y accéder).

Il n'a pas de visée d'audit ou de conformité.

## 1.2 Lecteurs

| Lecteur | Ce qu'il y cherche | Chapitres conseillés |
|---|---|---|
| Mainteneur du projet | Le fonctionnement complet, les risques à traiter | Tout le document |
| Contributeur ou nouvel arrivant | Une vue d'ensemble, puis le détail de sa partie | 1 à 3, puis 4 (application), 5 (site), 7 (API) |
| Utilisateur averti | Où sont les données, qui peut se connecter, ce qui transite sur le réseau, comment sauvegarder | 3, 6, 8, 9.2, 11 |
| Personne qui prépare une publication | Signature, secrets, magasins | 10, 9.6 |

## 1.3 Périmètre

**Inclus** : tout ce que décrit le code du dépôt public `psycofdj/WineTap`, et les ressources que sa
chaîne de livraison utilise chez les fournisseurs.

| Élément | Emplacement dans le dépôt | Contenu |
|---|---|---|
| Application mobile | `mobile/` | Application Flutter `com.winetap.mobile` : WebView, pont JavaScript, écrans natifs, NFC, base SQLite, serveur HTTP |
| Site web | `web/` | Application d'une page en Svelte 5, construite par Vite, embarquée dans l'application ; API simulée pour le développement |
| Contrat d'API | `web/API.md` | Routes `/api/*`, événements et pont JavaScript ; le code fait foi ([chapitre 7](07-api.md)) |
| Intégration continue et publication | `.github/workflows/`, `.github/dependabot.yml` | Vérifications des pull requests, publication sur étiquette `v*` |
| Construction locale | `scripts/build_web.sh`, `scripts/build_packages.sh` | Construction du site dans les ressources de l'application ; construction d'un paquet Android signé depuis un poste, qui ne sert pas à publier |
| Magasins | Google Play, App Store Connect, GitHub Releases | Destinations de la publication ([chapitre 10](10-livraison.md)) |

**Exclus**, cités seulement comme systèmes externes :

- le réseau Wi-Fi de l'utilisateur et sa box ;
- les navigateurs des ordinateurs qui se connectent au téléphone ;
- les **tags NFC** eux-mêmes (le système n'en lit que l'identifiant matériel) ;
- les assistants **ChatGPT** et **Claude**, ouverts dans un nouvel onglet par le site
  ([§5.7](05-site-web.md#57-aide-à-la-saisie-par-un-assistant-ia)) ;
- les documents de conception du dépôt (`specs/`, `design_handoff_winetap_v3/`, `_bmad/`,
  `_bmad-output/`) et la spécification d'origine `spec.md`, qui décrivent des intentions ou des
  états antérieurs.

## 1.4 État du code

État au 2026-10-18 : branche `v3`, arbre de travail non commité, construit sur le commit
`d78543c` (2026-05-23).

| Élément | État |
|---|---|
| Site web | Format téléphone (écrans E-01 à E-09) et format ordinateur (E-04 à E-09), écrans d'attente d'autorisation (E-10) et de téléphone injoignable (E-11), thèmes clair et sombre ([chapitre 5](05-site-web.md)) |
| Application mobile | WebView et pont JavaScript ; écrans natifs d'adresse (N-E1), d'autorisation (N-E2), des connexions autorisées (N-E3) et de lecture NFC (N-E4) |
| Serveur embarqué | Site et 31 routes `/api/*` sur le port 8080, dont un canal d'événements ([§7.3](07-api.md#73-routes)) |
| Manager de bureau | Supprimé : code Go, flux de CI et tâches de publication retirés |
| Tests | 115 tests Flutter (114 réussis, 1 ignoré hors essai de bout en bout) et `svelte-check` sans erreur, le 2026-10-18 ; parcours de bout en bout dans un navigateur réussi contre le serveur réel |
| Essais sur téléphone | Non faits au 2026-10-18 : lecture NFC, WebView, autorisation d'un ordinateur sur un vrai réseau ; seul le paquet Android de débogage a été construit |
| Publication | Chaîne complète sur étiquette `v*` : site, puis application vers la piste interne de Google Play et vers App Store Connect ([§10.3](10-livraison.md#103-publication)). La version 2 de l'application est **en ligne sur l'App Store** ; la version 3 n'est pas publiée |
| Version de l'application dans le dépôt | `0.0.0+dev` : la vraie version est donnée par l'étiquette au moment de la publication |

## 1.5 Conventions

### 1.5.1 Vocabulaire

| Terme | Sens dans ce document |
|---|---|
| **Téléphone** | L'appareil Android ou iOS qui exécute l'application mobile. Il porte la base, le serveur et le site. |
| **Site** | L'application web servie par le téléphone. Un seul site, deux formats : téléphone et ordinateur. |
| **WebView** | Le composant de l'application qui affiche le site servi par `localhost`. C'est l'interface principale de l'application. |
| **Pont** | L'objet JavaScript `window.winetapBridge`, injecté dans le site affiché par la WebView, qui donne accès au NFC et aux fichiers du téléphone. |
| **Ordinateur** | Tout appareil qui ouvre le site dans un navigateur, par l'adresse du téléphone sur le réseau local. |
| **Session autorisée** | Un navigateur d'ordinateur accepté sur le téléphone ; elle n'expire pas et se révoque depuis le téléphone. |
| **Appellation** | Une appellation d'origine (AOC, AOP). Table `designations`, route `/api/appellations`. |
| **Domaine** | Un producteur. Table `domains`, route `/api/domaines`. |
| **Cuvée** | Un vin nommé d'un domaine, rattaché à une appellation, avec une couleur. Table `cuvees`, route `/api/cuvees`. |
| **Bouteille** | Un exemplaire physique d'une cuvée, d'un millésime donné. Table `bottles`, route `/api/bouteilles`. |
| **Tag** | L'étiquette NFC collée sur une bouteille. Seul son identifiant matériel (UID) est lu. |
| **Identifiant de tag** | L'UID du tag en hexadécimal majuscule, sans séparateur (`04A32BFF`). Champ `tag_id`. |
| **En stock** | Bouteille dont `consumed_at` est vide. |
| **Entrée en stock** | Enregistrement d'une bouteille avec son tag, depuis le site, dans l'application ou sur un ordinateur. |
| **Consommation** | Passage d'une bouteille en « consommée » : date posée, tag libéré. |
| **Identification** | Lecture d'un tag dans l'application pour afficher la bouteille, sans la consommer. |
| **Lecture à distance** | Lecture d'un tag par le téléphone, demandée par un ordinateur ([§7.5](07-api.md#75-lecture-demandée-par-un-ordinateur)). |

Les écrans portent les numéros de la spécification v3 et des maquettes : `E-xx` pour les écrans du
site, `N-Ex` pour les écrans natifs. Les sigles et les termes techniques sont définis dans le
[glossaire](14-annexes.md#b-glossaire).

### 1.5.2 Couleurs des vins

La couleur d'une cuvée est un entier :

| Valeur | Couleur |
|---|---|
| 0 | Inconnue (valeur par défaut) |
| 1 | Rouge |
| 2 | Blanc |
| 3 | Rosé |
| 4 | Effervescent |
| 5 | Autre |

### 1.5.3 Noms et dates

- Les dates du document sont au format `AAAA-MM-JJ`.
- Les dates enregistrées par le système (`added_at`, `consumed_at`) sont en UTC, au format
  ISO 8601.
- L'interface est en français. Le code Dart et les tables sont en anglais ; l'API et le code du
  site sont en français (`/api/bouteilles`, champ `millesime`).
