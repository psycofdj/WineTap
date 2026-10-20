# 4. Application mobile

<!-- toc -->

**Sur cette page**

- [4.1 Démarrage](#41-démarrage)
- [4.2 WebView et pont](#42-webview-et-pont)
- [4.3 Écrans natifs](#43-écrans-natifs)
- [4.4 Lecture NFC](#44-lecture-nfc)
  - [4.4.1 Ce qui est lu](#441-ce-qui-est-lu)
  - [4.4.2 Une file de lecture unique](#442-une-file-de-lecture-unique)
  - [4.4.3 Machine à états du lecteur](#443-machine-à-états-du-lecteur)
  - [4.4.4 Android et iOS](#444-android-et-ios)
- [4.5 Serveur embarqué et cycle de vie](#45-serveur-embarqué-et-cycle-de-vie)
  - [4.5.1 Serveur HTTP](#451-serveur-http)
  - [4.5.2 Premier plan seulement](#452-premier-plan-seulement)
  - [4.5.3 Adresse affichée](#453-adresse-affichée)
- [4.6 Échanges de fichiers](#46-échanges-de-fichiers)

<!-- /toc -->

L'application mobile est une application Flutter, identifiant `com.winetap.mobile` sur Android
comme sur iOS. Elle est à la fois le serveur du système, le lecteur NFC, et l'hôte du site, qu'elle
affiche dans une WebView. Elle ne garde en Flutter que ce qui est propre au téléphone.

## 4.1 Démarrage

Au lancement, l'application prépare tous ses services **avant d'afficher la première image** :

1. elle ouvre la base `AppDatabase` et force une première requête, pour que le fichier existe ;
2. sur une version de développement dont la base n'a aucune bouteille, elle charge le jeu d'essai
   ([§8.7](08-donnees.md#87-données-de-référence-et-jeux-dessai)) ; un échec est journalisé et
   ignoré ;
3. elle place la base dans un `DbHolder`, qui permet de la remplacer à chaud lors d'une
   restauration ;
4. elle charge les sessions autorisées et les réglages depuis les préférences de l'application
   (`SessionStore`, `Settings`) et tire un **jeton d'application** aléatoire, valable jusqu'à
   l'arrêt du processus ;
5. elle crée le canal d'événements (`EventHub`) et la file des lectures à distance (`RemoteScan`) ;
6. elle crée le `NfcService` du système (sur Android, une session NFC permanente démarre à ce
   moment) ;
7. elle démarre le serveur HTTP sur le port 8080 par `ServerLifecycle` ; **un échec arrête
   l'application** ;
8. elle affiche `AppShell`, qui charge le site dans la WebView.

## 4.2 WebView et pont

`AppShell` affiche le site dans une WebView (`webview_flutter`). Elle ouvre
`http://localhost:8080/?jeton=<jeton d'application>` : le serveur pose alors le cookie `wt_app`
et redirige vers `/`, et sert à cette WebView une page `index.html` dans laquelle il a injecté le
script du pont ([§7.2](07-api.md#72-authentification)).

Le pont, `window.winetapBridge`, passe par un canal JavaScript nommé `WineTapNative` : le site y
poste un message `{id, methode, args}`, la classe `Bridge` le traite, puis rappelle
`window.__wtRetour(id, résultat)` dans la WebView.

| Méthode | Effet côté natif |
|---|---|
| `readTag(objet)` | Ouvre l'écran de lecture N-E4 ; rend `{tag_id}`, ou `{annule: true}` si l'utilisateur annule ([§4.4](#44-lecture-nfc)) |
| `saveBackup()` | Produit la sauvegarde de la base et ouvre le sélecteur « Enregistrer sous » du système ([§4.6](#46-échanges-de-fichiers)) |
| `pickFile()` | Ouvre le sélecteur de documents et rend le fichier choisi en base64 : sauvegarde à restaurer, carte d'une appellation |
| `openNative(ecran)` | Ouvre l'écran d'adresse (`adresse`, N-E1) ou la liste des connexions (`connexions`, N-E3) |
| `openExternal(url)` | Ouvre une adresse `http` ou `https` dans le navigateur du téléphone |
| `setTheme(theme)` | Applique aux écrans natifs le thème du site : `clair`, `sombre` ou `systeme` ; le choix est gardé dans les préférences (`v3.theme`) pour le lancement suivant |

Autres comportements de la coque :

- **Navigation.** Seules les pages servies par `localhost` ou `127.0.0.1` restent dans la WebView ;
  toute autre adresse s'ouvre dans le navigateur du téléphone.
- **Retour.** Le bouton ou le geste de retour annule d'abord une lecture NFC en cours, puis revient
  à la page précédente du site, puis quitte l'application.
- **Messages.** Un bandeau natif confirme les actions faites hors du site : « Tag envoyé à
  l'ordinateur », « <navigateur> autorisé », « Connexion refusée », « Connexion révoquée ».
- **Thème.** Les écrans natifs et la barre d'état suivent le thème du site : celui du système, ou
  celui choisi dans les réglages, que le site transmet par `setTheme` au démarrage et à chaque
  changement. Ils utilisent les polices du site, embarquées dans l'application.

## 4.3 Écrans natifs

| Écran | Rôle | Accès |
|---|---|---|
| **N-E1 Adresse** | Affiche `http://<adresse IPv4 locale>:8080` en grand, sélectionnable, et l'état « Serveur actif » ; signale l'absence de réseau local. L'adresse est relue toutes les 5 secondes | Réglages du site, « Accès depuis un ordinateur » |
| **N-E2 Autorisation** | Feuille modale « Autoriser cette connexion ? » : navigateur et version, système, adresse IP, heure de la demande ; « Refuser » ou « Autoriser ». Les demandes s'affichent une à une, dans l'ordre d'arrivée ; une réponse donnée après l'expiration de la demande (5 minutes) ne décide rien | S'ouvre seule dès qu'un navigateur demande l'accès |
| **N-E3 Connexions autorisées** | Liste des sessions : navigateur et système, date d'autorisation, dernière activité, pastille « active » si le navigateur a écrit dans les 2 dernières minutes ; « Révoquer » par session, « Tout révoquer » | Réglages du site, ou depuis N-E1 |
| **N-E4 Lecture NFC** | Plein écran par-dessus la WebView : origine de la demande (« Depuis ce téléphone » ou « Demandé par un ordinateur · <navigateur> sur <système> »), objet de la lecture, consigne « Présentez le tag », puis « Tag lu » ou « Lecture impossible » avec « Réessayer » ; « Annuler » | Toute lecture de tag ([§4.4](#44-lecture-nfc)) |

Une révocation sur N-E3 ferme aussitôt le canal d'événements du navigateur révoqué, qui revient à
l'écran d'attente d'autorisation ([§9.2](09-securite.md#92-autorisation-des-navigateurs)).

## 4.4 Lecture NFC

### 4.4.1 Ce qui est lu

L'application ne lit que **l'identifiant matériel (UID)** du tag. Elle n'écrit jamais sur le tag
et ne lit pas son contenu NDEF. L'UID est converti en hexadécimal majuscule, sans séparateur
(`04A32BFF`).

Les deux implémentations interrogent les technologies ISO 14443 et ISO 15693.

### 4.4.2 Une file de lecture unique

Toute lecture passe par le `ReadingController`, qui alimente N-E4 :

| Origine | Déclenchement | Résultat |
|---|---|---|
| Le site, dans l'application | `readTag(objet)` du pont ; objet `consommer`, `identifier`, `entree` ou `recherche` | Rendu au site par le pont |
| Un ordinateur | `POST /api/scan` ; objet `entree` ou `recherche` | Rendu au navigateur par l'événement `scan` ([§7.5](07-api.md#75-lecture-demandée-par-un-ordinateur)) |

Une seule lecture à la fois : une lecture demandée par un ordinateur pendant une lecture en cours
est aussitôt annulée, et `readTag` rend une annulation si une lecture est déjà affichée. Après un
tag lu, N-E4 affiche « Tag lu » pendant 0,9 seconde, puis se ferme. Après une erreur de lecture,
N-E4 reste ouvert sur « Lecture impossible » jusqu'à « Réessayer » ou « Annuler ».

### 4.4.3 Machine à états du lecteur

`NfcServiceBase` porte l'état du lecteur, commun aux deux systèmes :

| État | Sens | Transition |
|---|---|---|
| `ready` | Prêt à lire | Une lecture le fait passer à `scanning` |
| `scanning` | Une lecture est en cours | Tag lu, annulation ou erreur : passe à `postScanning` |
| `postScanning` | Période de garde après une lecture | Une nouvelle lecture attend la fin des **5 secondes** qui suivent la précédente, puis repasse à `ready` |

La période de garde évite qu'un même tag, encore près du téléphone, soit lu deux fois de suite.

### 4.4.4 Android et iOS

| | Android (`NfcServiceAndroid`) | iOS (`NfcServiceIos`) |
|---|---|---|
| Session NFC | **Une session permanente**, ouverte au démarrage et pendant toute la vie de l'application ; elle capte les tags au premier plan, ce qui empêche Android d'ouvrir sa propre fenêtre de tag | **Une session par lecture**, qui affiche la feuille NFC du système par-dessus N-E4 |
| Lecture | Hors lecture demandée, les tags détectés sont ignorés ; une lecture « arme » la session pour le tag suivant | La session se ferme sur « Tag lu », sur une erreur ou si l'utilisateur ferme la feuille |
| UID | Identifiant du tag Android | Identifiant ISO 7816 ou MIFARE |
| Retour au premier plan | La session est fermée puis rouverte | Sans objet |

Sur un système sans NFC (ordinateur, simulateur), `NoOpNfcService` rend aussitôt un faux tag
`FFFF…`, pour le développement.

## 4.5 Serveur embarqué et cycle de vie

### 4.5.1 Serveur HTTP

Le serveur est construit avec `shelf` et `shelf_router`. Il écoute sur **toutes les adresses
IPv4** du téléphone, port **8080**, en HTTP. Une connexion inactive est fermée après 60 secondes ;
le canal d'événements envoie un message de maintien toutes les 20 secondes pour rester ouvert.

Il sert deux choses :

- **le site**, à la racine : fichiers lus dans les ressources de l'application (`assets/site/`) ;
  `index.html` sans cache et avec une politique de sécurité du contenu, les fichiers de
  `assets/`, dont le nom porte une empreinte, avec un cache d'un an ;
- **l'API**, sous `/api/` ([chapitre 7](07-api.md)).

Toutes les requêtes passent par deux intergiciels :

- `securityMiddleware` identifie l'appelant (WebView, navigateur autorisé, en attente ou inconnu)
  et applique les contrôles du [§9.3](09-securite.md#93-contrôles-du-serveur) ;
- `wakelockMiddleware` **garde l'écran allumé** et relance un minuteur de 5 minutes à chaque
  requête, au bout duquel l'écran peut de nouveau s'éteindre. Le canal d'événements, ouvert en
  permanence, ne relance pas ce minuteur : seules les actions de l'utilisateur le font.

### 4.5.2 Premier plan seulement

Le serveur ne fonctionne que **quand l'application est ouverte au premier plan**. Rien ne le garde
actif en arrière-plan : iOS suspend l'application, Android peut arrêter son processus.

À chaque retour au premier plan après un passage en arrière-plan (état `paused`),
`ServerLifecycle` relance tout, dans cet ordre, chaque étape étant tentée même si la précédente
échoue :

1. fermeture de tous les canaux d'événements ;
2. fermeture forcée du serveur HTTP ;
3. réouverture de la session NFC (Android) ;
4. démarrage d'un nouveau serveur HTTP.

Une simple perte de focus, sans passage en arrière-plan, ne relance rien : la feuille NFC d'iOS, le
centre de contrôle ou une alerte du système font passer l'application par l'état `inactive` puis
`resumed`, et le serveur continue de répondre.

Les navigateurs rouvrent seuls leur canal d'événements, au bout de 5 secondes
([§5.4](05-site-web.md#54-accès-et-connexion-au-téléphone)). Le jeton d'application, les sessions
autorisées et une lecture à distance en cours survivent à la relance ; les demandes d'autorisation
en attente et la lecture en cours sont perdues si le processus est arrêté.

### 4.5.3 Adresse affichée

L'adresse de N-E1, et celle que l'API rend au site, est tirée de la première interface Wi-Fi
(`en*` sur iOS, `wlan*` sur Android), sinon de la première autre adresse IPv4 qui n'est ni locale
ni celle des données mobiles. Sans réseau local, N-E1 le dit, et le site affiche
`localhost:8080`.

## 4.6 Échanges de fichiers

Sauvegarde et choix de fichier passent par un canal natif, `com.winetap.mobile/file_io`, écrit en
Kotlin sur Android et en Swift sur iOS :

- `saveFile` ouvre le sélecteur « Enregistrer sous » du système et écrit le fichier choisi ;
- `pickFileBytes` ouvre le sélecteur de documents et rend le contenu du fichier choisi.

Le pont s'en sert pour `saveBackup` et `pickFile`. L'application n'a donc besoin d'aucune
permission d'accès au stockage : l'utilisateur choisit lui-même l'emplacement. Le déroulé complet
est au [§11.4](11-exploitation-continuite.md#114-sauvegarde-et-restauration).
