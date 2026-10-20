# 12. Décisions d'architecture

<!-- toc -->

**Sur cette page**

- [12.1 Décisions structurantes](#121-décisions-structurantes)
  - [D-01 — Le téléphone est le serveur](#d-01--le-téléphone-est-le-serveur)
  - [D-17 — Un site embarqué pour le téléphone et l'ordinateur](#d-17--un-site-embarqué-pour-le-téléphone-et-lordinateur)
  - [D-02 — Une API HTTP en JSON dessinée pour le site](#d-02--une-api-http-en-json-dessinée-pour-le-site)
  - [D-03 — Une seule base sur le téléphone, sans synchronisation](#d-03--une-seule-base-sur-le-téléphone-sans-synchronisation)
  - [D-18 — Autorisation des navigateurs sur le téléphone](#d-18--autorisation-des-navigateurs-sur-le-téléphone)
  - [D-04 — Pas de chiffrement sur le réseau local](#d-04--pas-de-chiffrement-sur-le-réseau-local)
  - [D-05 — Adresse affichée par le téléphone](#d-05--adresse-affichée-par-le-téléphone)
  - [D-06 — Événements poussés par le serveur](#d-06--événements-poussés-par-le-serveur)
  - [D-19 — Un seul écran natif pour toute lecture de tag](#d-19--un-seul-écran-natif-pour-toute-lecture-de-tag)
  - [D-09 — Le tag est une association temporaire](#d-09--le-tag-est-une-association-temporaire)
  - [D-11 — Sauvegarde par copie brute du fichier SQLite](#d-11--sauvegarde-par-copie-brute-du-fichier-sqlite)
  - [D-21 — Schéma inchangé, état de la v3 hors de la base](#d-21--schéma-inchangé-état-de-la-v3-hors-de-la-base)
- [12.2 Décisions de fonctionnement](#122-décisions-de-fonctionnement)
  - [D-07 — Application au premier plan, écran maintenu allumé pendant l'activité](#d-07--application-au-premier-plan-écran-maintenu-allumé-pendant-lactivité)
  - [D-08 — Relance du serveur au retour au premier plan](#d-08--relance-du-serveur-au-retour-au-premier-plan)
  - [D-10 — Consommation sans confirmation](#d-10--consommation-sans-confirmation)
  - [D-12 — Aide IA par le navigateur](#d-12--aide-ia-par-le-navigateur)
  - [D-20 — Réglages communs, rangés sur le téléphone](#d-20--réglages-communs-rangés-sur-le-téléphone)
  - [D-13 — Pile technique](#d-13--pile-technique)
  - [D-14 — Interface en français](#d-14--interface-en-français)
  - [D-15 — Publication sur étiquette par GitHub Actions](#d-15--publication-sur-étiquette-par-github-actions)
  - [D-16 — Catalogue de référence embarqué](#d-16--catalogue-de-référence-embarqué)
- [12.3 Décisions remplacées](#123-décisions-remplacées)

<!-- /toc -->

Ce chapitre présente chaque décision **dans l'état où le code l'applique** au 2026-10-18. Les
décisions de la v3 viennent de la spécification `specs/v3-web.md`, rédigée le 2026-10-18 ; celles
d'avant, des documents de conception (`_bmad-output/planning-artifacts/`), dont l'architecture
« Mobile v2 » du 2026-04-01, qui a fait du téléphone le serveur. Quand ces documents et le code
divergent, le DAT suit le code. Les numéros des décisions sont propres au DAT. Les conséquences
négatives qui forment un risque sont aussi au [chapitre 13](13-risques.md).

## 12.1 Décisions structurantes

Ces décisions fixent la forme du système : où sont les données, qui sert qui, comment le site, le
téléphone et les ordinateurs se trouvent et se parlent.

### D-01 — Le téléphone est le serveur

| | |
|---|---|
| **Contexte** | La première version reposait sur un Raspberry Pi allumé en permanence, avec la base, un serveur gRPC et un lecteur RFID. Le public visé, un amateur avec 100 à 500 bouteilles, n'a ni envie ni besoin d'un matériel dédié à installer et à maintenir. |
| **Options** | (a) Garder le Raspberry Pi, le téléphone devenant un client de plus ; (b) faire du téléphone le serveur ; (c) un service en ligne. |
| **Décision** | (b), prise le 2026-04-01 et reconduite par la v3. L'application mobile porte la base SQLite, la lecture NFC, le site et son API. |
| **Conséquences** | Plus aucun matériel ni service à tenir. Le téléphone est toujours à portée de main, et il a déjà le NFC. En contrepartie, le serveur n'existe que lorsque l'application est ouverte ([D-07](#d-07--application-au-premier-plan-écran-maintenu-allumé-pendant-lactivité)), et la cave dépend d'un appareil que l'on peut perdre ([D-11](#d-11--sauvegarde-par-copie-brute-du-fichier-sqlite)). |

### D-17 — Un site embarqué pour le téléphone et l'ordinateur

| | |
|---|---|
| **Contexte** | En v2, le catalogue et l'inventaire se géraient dans un manager de bureau en Go et Qt6, à installer sur chaque ordinateur, construit pour trois systèmes ; l'application mobile avait sa propre interface Flutter, réduite à la consommation. On ne pouvait pas tout faire depuis le téléphone. |
| **Options** | (a) Garder le manager ; (b) tout porter dans l'application Flutter, et Flutter Web pour l'ordinateur ; (c) un site léger, servi par le téléphone, affiché par une WebView dans l'application et par le navigateur de l'ordinateur. |
| **Décision** | (c), le 2026-10-18 : un maximum de fonctions dans le site ; Flutter ne garde que ce qui est propre au téléphone (NFC, fichiers, autorisation des ordinateurs, adresse). Le site est en Svelte 5, construit par Vite, avec une charte créée pour la v3. |
| **Conséquences** | Une seule interface à écrire et à tester, deux formats ; rien à installer sur l'ordinateur ; plus de chaîne CGo et Qt à construire. Le site est embarqué dans l'application : il change avec elle, et chaque construction de l'application commence par celle du site. L'application dépend du moteur web du téléphone : elle demande iOS 15 au moins. |

### D-02 — Une API HTTP en JSON dessinée pour le site

| | |
|---|---|
| **Contexte** | L'API REST de la v2 servait le manager : chemins en anglais, attente longue pour le scan, pas d'authentification. |
| **Options** | (a) Garder l'API v2 et y ajouter le nécessaire ; (b) une API redessinée pour le site, sans compatibilité avec le manager. |
| **Décision** | (b). Routes sous `/api/`, en français, champs en `snake_case`, erreurs `{erreur, message}` ; contrat écrit dans `web/API.md`, implémenté par le serveur Dart et par le serveur simulé du site. |
| **Conséquences** | Le site lit l'API sans couche de traduction, et le serveur simulé permet de développer le site sans téléphone. Le contrat n'est garanti que par les tests de chaque côté ([R-33](13-risques.md#131-risques-à-traiter)). Un manager v2 ne peut pas parler à un téléphone v3. |

### D-03 — Une seule base sur le téléphone, sans synchronisation

| | |
|---|---|
| **Contexte** | Plusieurs écrans, sur le téléphone et sur des ordinateurs, modifient les données. |
| **Options** | (a) Une base par client, synchronisées ; (b) une seule base, sur le téléphone. |
| **Décision** | (b). Le téléphone est la seule source de vérité ; le site lit et écrit tout par l'API et recharge ce qui change à chaque événement `donnees`. |
| **Conséquences** | Aucun conflit à résoudre ; tous les écrans ouverts restent à jour. Le site ne fonctionne pas sans le téléphone. Deux modifications simultanées de la même fiche : la dernière l'emporte. |

### D-18 — Autorisation des navigateurs sur le téléphone

| | |
|---|---|
| **Contexte** | En v2, tout appareil du réseau local avait tous les droits sur la cave. La v3 sert en plus un site complet, que n'importe quel navigateur peut ouvrir. |
| **Options** | (a) Garder la confiance dans le réseau ; (b) un mot de passe ; (c) un écran de confirmation sur le téléphone pour chaque nouveau navigateur. |
| **Décision** | (c), le 2026-10-18. Un navigateur inconnu demande l'accès ; le téléphone affiche « Autoriser cette connexion ? » avec le navigateur, le système et l'adresse IP. Une session autorisée est gardée sans expiration ; seule sa révocation, depuis le téléphone, y met fin. La WebView est authentifiée par un jeton tiré par l'application, pas par sa seule adresse de boucle locale. Contrôles de l'hôte et de l'origine contre le *DNS rebinding* et les requêtes d'autres sites. |
| **Conséquences** | Rien à retenir ni à saisir ; l'accès suppose d'avoir le téléphone en main. Un navigateur autorisé le reste tant qu'il garde son cookie. Une demande peut être faite par tout appareil du réseau : elles sont limitées par adresse et en nombre ([R-05](13-risques.md#131-risques-à-traiter)). Un cookie lié à l'adresse IP oblige à autoriser de nouveau quand l'adresse change, ce qui est accepté ([R-20](13-risques.md#132-risques-acceptés)). |

### D-04 — Pas de chiffrement sur le réseau local

| | |
|---|---|
| **Contexte** | Le téléphone n'a pas de nom de domaine ni de certificat qu'un navigateur reconnaîtrait sur un réseau local ; un certificat auto-signé déclenche un avertissement à chaque connexion. |
| **Options** | (a) HTTP en clair ; (b) HTTPS avec certificat auto-signé ; (c) HTTPS avec un nom public et un certificat reconnu. |
| **Décision** | (a), reconduite de la v2 et confirmée le 2026-10-18. |
| **Conséquences** | Connexion sans avertissement. Les échanges, cookie de session compris, passent en clair sur le Wi-Fi ([R-06](13-risques.md#131-risques-à-traiter)). |

### D-05 — Adresse affichée par le téléphone

| | |
|---|---|
| **Contexte** | En v2, le téléphone s'annonçait par mDNS et le manager le cherchait. Un navigateur ne sait pas chercher un service mDNS. |
| **Options** | (a) Garder une annonce mDNS (nom `.local`) ; (b) afficher l'adresse sur le téléphone. |
| **Décision** | (b), le 2026-10-18. L'écran N-E1 affiche l'adresse courante ; plus d'annonce mDNS. |
| **Conséquences** | Plus de dépendance au multicast ni de permission associée. L'utilisateur saisit l'adresse une fois, et de nouveau quand elle change. |

### D-06 — Événements poussés par le serveur

| | |
|---|---|
| **Contexte** | Le site doit apprendre le résultat d'une lecture à distance, les modifications faites ailleurs, et la décision prise sur sa demande d'autorisation. La v2 utilisait une attente longue pour le scan, et le manager ne voyait les autres modifications qu'au rechargement. |
| **Options** | (a) Interrogations périodiques ; (b) attente longue ; (c) WebSocket ; (d) *Server-Sent Events*. |
| **Décision** | (d) : un flux `GET /api/events` par client, avec les événements `donnees`, `scan` et `session`, une reconnexion au bout de 5 s et un maintien toutes les 20 s. |
| **Conséquences** | Simple à servir avec `shelf` et à consommer avec `EventSource`, qui se reconnecte seul. Le flux sert aussi à détecter la perte du téléphone (E-11). Un flux ouvert par client. |

### D-19 — Un seul écran natif pour toute lecture de tag

| | |
|---|---|
| **Contexte** | La lecture NFC ne peut se faire que dans l'application. Elle est demandée par le site dans l'application (consommer, identifier, entrer une bouteille) ou par un ordinateur (entrée en stock, recherche). |
| **Décision** | Un écran natif, N-E4, plein écran par-dessus la WebView, sert à toute lecture : il porte l'objet et l'origine de la demande, et un bouton d'annulation. Le site l'ouvre par le pont, un ordinateur par `POST /api/scan`. Une lecture à la fois. Consommer et identifier par le tag n'existent que dans l'application. |
| **Conséquences** | Un seul parcours de lecture à tester et à expliquer. Une lecture demandée par un ordinateur exige quelqu'un près du téléphone ; une demande pendant une lecture locale est refusée. |

### D-09 — Le tag est une association temporaire

| | |
|---|---|
| **Contexte** | Un tag pourrait identifier un vin durablement, ou seulement une bouteille le temps de sa présence en cave. |
| **Décision** | Le tag n'est qu'une association entre un objet et une bouteille **en stock**. Seul son UID est lu ; rien n'y est écrit. À la consommation, le tag est retiré de la bouteille et peut servir à une autre. |
| **Conséquences** | Les tags sont réutilisables à l'infini et n'importe quel tag NFC convient. Une bouteille consommée ne garde aucune trace du tag qu'elle portait ; le serveur s'en souvient en mémoire jusqu'à son arrêt, pour signaler « déjà consommée ». |

### D-11 — Sauvegarde par copie brute du fichier SQLite

| | |
|---|---|
| **Contexte** | Le téléphone est la seule copie des données ([D-03](#d-03--une-seule-base-sur-le-téléphone-sans-synchronisation)). |
| **Options** | (a) Export dans un format d'échange (JSON, CSV) ; (b) copie du fichier de base. |
| **Décision** | (b). `GET /api/sauvegarde` rend le fichier SQLite après intégration du journal. La restauration se fait en deux temps : examen du fichier (tables, version de schéma, bouteilles en stock), puis remplacement et réouverture de la base **à chaud**, sans redémarrer l'application. |
| **Conséquences** | Sauvegarde complète et fidèle, compatible entre la v2 et la v3 ; migrations appliquées à la restauration d'une base plus ancienne. Le fichier n'est lisible que par SQLite. La sauvegarde reste un geste manuel ([R-10](13-risques.md#131-risques-à-traiter)). |

### D-21 — Schéma inchangé, état de la v3 hors de la base

| | |
|---|---|
| **Contexte** | Les fichiers de la v2 doivent s'ouvrir en v3, et ceux de la v3 en v2. La v3 doit pourtant garder des sessions et des réglages. |
| **Décision** | Le schéma reste en version 2. Sessions autorisées et réglages sont rangés dans les préférences de l'application ; l'API calcule ce qui manque (année courante, `a_image`) et renomme les champs sans toucher aux colonnes. |
| **Conséquences** | Retour à la v2 possible à tout moment par une sauvegarde. Les fonctions qui demanderaient une colonne (annulation d'une consommation, historique d'un tag) sont écartées ; les sessions ne voyagent pas avec la sauvegarde. |

## 12.2 Décisions de fonctionnement

### D-07 — Application au premier plan, écran maintenu allumé pendant l'activité

| | |
|---|---|
| **Contexte** | iOS suspend les applications en arrière-plan ; Android peut arrêter leur processus. Un serveur permanent demanderait un service d'arrière-plan sur Android et n'est pas possible sur iOS. |
| **Décision** | Le serveur ne fonctionne qu'au premier plan, choix accepté le 2026-04-01 et reconduit le 2026-10-18. Chaque requête garde l'écran allumé 5 minutes ; le canal d'événements, ouvert en permanence, ne le fait pas. |
| **Conséquences** | Le téléphone doit rester ouvert sur WineTap pendant une séance depuis un ordinateur ; après 5 minutes sans action, l'écran peut s'éteindre et l'ordinateur perdre le téléphone. L'usage dans l'application n'est pas concerné. |

### D-08 — Relance du serveur au retour au premier plan

| | |
|---|---|
| **Contexte** | Au retour au premier plan, le système peut avoir fermé la socket d'écoute ou la session NFC. |
| **Décision** | À chaque retour au premier plan, `ServerLifecycle` ferme les canaux d'événements et le serveur, rouvre la session NFC et relance le serveur, chaque étape étant tentée même si la précédente échoue. |
| **Conséquences** | Les navigateurs retrouvent le téléphone seuls, par la reconnexion de leur canal. La relance a lieu même quand rien n'était cassé. |

### D-10 — Consommation sans confirmation

| | |
|---|---|
| **Contexte** | Consommer une bouteille doit être immédiat. La première version demandait une confirmation. |
| **Décision** | Dans l'application, lire le tag d'une bouteille en stock la consomme aussitôt (`POST /api/consommer`), sans étape de confirmation ; un commentaire peut être ajouté ensuite. Sur un ordinateur, le bouton de l'inventaire consomme sans tag ni confirmation. |
| **Conséquences** | Consommation en deux gestes. Une lecture involontaire consomme la bouteille, et rien ne permet de l'annuler ([R-12](13-risques.md#131-risques-à-traiter)). |

### D-12 — Aide IA par le navigateur

| | |
|---|---|
| **Contexte** | Décrire un domaine, une appellation ou une cuvée demande des recherches. Appeler une API d'IA demanderait une clé, donc un compte et un coût. |
| **Options** | (a) API d'un fournisseur, avec clé ; (b) ouverture du navigateur sur l'assistant, avec une question préparée ; (c) pilotage d'un navigateur par ChromeDP. |
| **Décision** | (b). Le bouton « Demander à l'IA » ouvre ChatGPT ou Claude, au choix dans les réglages, avec la question dans l'adresse. |
| **Conséquences** | Ni clé, ni secret, ni coût pour le projet. L'utilisateur recopie lui-même la réponse. La question, qui contient le nom du vin, part chez le fournisseur choisi. |

### D-20 — Réglages communs, rangés sur le téléphone

| | |
|---|---|
| **Décision** | Les réglages (assistant IA) sont les mêmes pour tous les navigateurs et la WebView ; ils sont rangés sur le téléphone, hors de la base, et lus par `GET /api/reglages`. |
| **Conséquences** | Un changement fait sur l'ordinateur vaut aussitôt dans l'application. Les réglages ne voyagent pas avec la sauvegarde. |

### D-13 — Pile technique

| | |
|---|---|
| **Décision** | Application : Flutter et Dart, `drift` pour SQLite, `shelf` pour le serveur, `nfc_manager` pour le NFC, `webview_flutter` pour la WebView, `shared_preferences` pour les préférences, `flutter_svg` pour les icônes des écrans natifs. Site : Svelte 5 et Vite, sans autre bibliothèque d'exécution que les polices. |
| **Conséquences** | Une base de code mobile pour Android et iOS ; un site léger, construit hors ligne. Deux chaînes d'outils (Flutter et Node), réunies par `scripts/build_web.sh`. |

### D-14 — Interface en français

| | |
|---|---|
| **Décision** | Le site et les écrans natifs sont en français, sans mécanisme de traduction. L'API et le code du site sont aussi en français ; le code Dart et les tables restent en anglais. |
| **Conséquences** | Adapté aux caves et aux appellations françaises ; une traduction demanderait d'abord d'extraire les chaînes. |

### D-15 — Publication sur étiquette par GitHub Actions

| | |
|---|---|
| **Décision** | Une étiquette `v*` construit le site, puis l'application, et la publie sur la piste interne de Google Play et sur App Store Connect ; la release GitHub reçoit les deux paquets. Les secrets de signature sont des secrets GitHub. |
| **Conséquences** | Une publication complète en un geste, sans poste de construction. La mise en production dans les magasins reste manuelle. |

### D-16 — Catalogue de référence embarqué

| | |
|---|---|
| **Décision** | Une base neuve reçoit 320 appellations (liste SIQO de l'INAO) et 128 domaines, embarqués dans l'application. |
| **Conséquences** | La complétion fonctionne dès le premier usage, sans réseau. Le catalogue de référence n'est jamais mis à jour : une appellation nouvelle se crée à la main. |

## 12.3 Décisions remplacées

Les deux conceptions précédentes de WineTap sont remplacées : celle du Raspberry Pi (`spec.md`,
puis l'architecture « Mobile » v1), et celle du manager de bureau (v2). Rien n'en reste dans le
code.

| Ancienne décision | Remplacée par |
|---|---|
| Serveur `rpc-server` sur un Raspberry Pi, base SQLite sur le Pi | [D-01](#d-01--le-téléphone-est-le-serveur), [D-03](#d-03--une-seule-base-sur-le-téléphone-sans-synchronisation) |
| API gRPC et messages protobuf, puis API REST en anglais pour le manager | [D-02](#d-02--une-api-http-en-json-dessinée-pour-le-site) |
| Programme `cellar` sur le Pi, avec lecteur RFID UHF Chafon CF-RU5102 | Lecture NFC par le téléphone ([D-19](#d-19--un-seul-écran-natif-pour-toute-lecture-de-tag)) |
| Manager de bureau en Go et Qt6 (liaisons `miqt`), pour Linux, macOS et Windows, retiré le 2026-10-18 | [D-17](#d-17--un-site-embarqué-pour-le-téléphone-et-lordinateur) |
| Interface Flutter de l'application (consommation, identification, entrée en cave, historique, réglages) | Le site, dans la WebView ([D-17](#d-17--un-site-embarqué-pour-le-téléphone-et-lordinateur)) |
| Ni authentification ni chiffrement : tout appareil du réseau a tous les droits | [D-18](#d-18--autorisation-des-navigateurs-sur-le-téléphone) ; chiffrement toujours absent ([D-04](#d-04--pas-de-chiffrement-sur-le-réseau-local)) |
| Découverte par mDNS : annonce `_winetap._tcp` par le téléphone, recherche par le manager, boucle de santé toutes les 5 s | [D-05](#d-05--adresse-affichée-par-le-téléphone) |
| Scan à distance par attente longue (`/scan/request`, `/scan/result`), puis flux gRPC bidirectionnel dans la première version | [D-06](#d-06--événements-poussés-par-le-serveur), [D-19](#d-19--un-seul-écran-natif-pour-toute-lecture-de-tag) |
| Consommation sur le téléphone directement dans la base, sans l'API | Consommation par l'API, depuis le site ([D-10](#d-10--consommation-sans-confirmation)) |
| Restauration suivie de l'arrêt de l'application, sans examen du fichier | Examen puis remplacement à chaud ([D-11](#d-11--sauvegarde-par-copie-brute-du-fichier-sqlite)) |
| Configuration du manager dans `manager.yaml` (adresse, journaux, style, assistant) | Réglages sur le téléphone ([D-20](#d-20--réglages-communs-rangés-sur-le-téléphone)) |
| Journal des événements (tags inconnus, pannes du lecteur), acquittables | Supprimé, sans remplacement |
| Mise à jour du référentiel des appellations depuis les données ouvertes de l'INAO | [D-16](#d-16--catalogue-de-référence-embarqué), sans mise à jour |
| Saisie assistée par ChatGPT piloté par ChromeDP, retirée le 2026-04-07 | [D-12](#d-12--aide-ia-par-le-navigateur) |
| Consommation avec confirmation | [D-10](#d-10--consommation-sans-confirmation) |
| Modification groupée de bouteilles et route dédiée au tag, retirées le 2026-04-07 | Modification bouteille par bouteille, tag compris, par `PUT /api/bouteilles/:id` |
