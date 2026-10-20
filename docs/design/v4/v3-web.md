# WineTap v3 — Application web embarquée

Spécification en cours de rédaction. État : **brouillon**, ouvert le 2026-10-18.

Étapes prévues : cette spécification, puis les maquettes des écrans avec Claude Design, puis
l'implémentation.

## 1. Contexte

La v2 compte deux clients : l'application mobile (Flutter), qui porte la base, le NFC et l'API, et
le manager de bureau (Go et Qt6), qui gère le catalogue et l'inventaire par cette API. Le manager
trouve le téléphone par mDNS. Le système actuel est décrit dans le DAT (`dat/`).

## 2. Objectifs et non-objectifs

### 2.1 Objectifs

| # | Objectif |
|---|---|
| O-01 | Retirer le manager de bureau (client lourd Go et Qt6). |
| O-02 | L'application mobile embarque et sert une application web (SPA). |
| O-03 | Le même site s'utilise sur le téléphone, dans l'application mobile, et depuis un ordinateur, dans un navigateur qui se connecte au téléphone. |
| O-04 | Le site reprend toutes les fonctions du manager et toutes les fonctions de l'application mobile qui ne lisent pas de tag, en particulier la gestion de l'inventaire et l'entrée des bouteilles en stock. |
| O-05 | L'application Flutter se limite à ce qui est propre au téléphone : serveur, base, lecteur NFC, autorisation des connexions. |
| O-06 | Le téléphone seul suffit à tout faire, facilement : l'ordinateur est un confort pour la saisie, jamais une obligation. |

### 2.2 Non-objectifs

| # | Hors du périmètre de la v3 |
|---|---|
| N-01 | Découverte mDNS : abandonnée ; le téléphone affiche l'adresse à saisir. |
| N-02 | HTTPS : le site est servi en HTTP. |
| N-03 | Fonctionnement de l'application en arrière-plan : le téléphone reste ouvert sur WineTap pendant l'usage depuis un ordinateur, comme en v2. |
| N-04 | Toute évolution du schéma de la base (contrainte C-01). |
| N-05 | Lecture NFC par le navigateur de l'ordinateur : les tags se lisent toujours avec le téléphone. |

## 3. Contraintes

### C-01 — Base de données inchangée

Le schéma de la base SQLite ne change pas. Un fichier de base produit par la v2 s'ouvre dans la
v3, et réciproquement, sans conversion.

Concrètement :

- **Structure figée** : les quatre tables `designations`, `domains`, `cuvees` et `bottles`, leurs
  colonnes, leurs types, leurs valeurs par défaut et leurs contraintes (unicité, clés étrangères)
  restent identiques. Pas de nouvelle table, de nouvelle colonne ni de nouvel index.
- **Version de schéma** : la version drift reste **2** ; la v3 n'ajoute aucune migration.
- **Sens des valeurs inchangé** :
  - couleur d'une cuvée : 0 inconnue, 1 rouge, 2 blanc, 3 rosé, 4 effervescent, 5 autre ;
  - `added_at` et `consumed_at` : date UTC au format ISO 8601 ;
  - `vintage` et `drink_before` : années ;
  - `tag_id` : UID en hexadécimal majuscule, sans séparateur ; vidé à la consommation ;
  - appellation sentinelle `id = 0`, « (unassigned) » ;
  - bouteille en stock : `consumed_at` vide ; consommée : `consumed_at` renseigné.
- **Sauvegardes croisées** : une sauvegarde de la v2 se restaure dans la v3, et une sauvegarde de
  la v3 dans la v2.

Conséquences sur la conception :

- tout état propre à la v3 qui doit persister (connexions autorisées, réglages) est rangé **hors du
  fichier de base**, dans le stockage de l'application ; il n'est donc pas compris dans les
  sauvegardes ;
- une nouvelle fonction ne peut enregistrer que ce que les colonnes existantes savent porter ;
- l'API peut changer librement : seul le fichier de base est figé.

### C-02 — Pas de HTTPS

Le site est servi en HTTP. Sur l'ordinateur, une page servie en HTTP depuis une adresse IP n'est
pas un « contexte sécurisé » pour le navigateur : le site n'utilise donc ni la caméra, ni l'API
asynchrone du presse-papier, ni service worker. Le collage d'une image par Ctrl+V (événement
`paste`) reste possible. Dans l'application, la WebView charge `localhost`, qui est un contexte
sécurisé.

## 4. Architecture cible

### 4.1 Répartition des rôles

| Partie | Technologie | Rôle |
|---|---|---|
| Application mobile | Flutter (Android, iOS) | Base SQLite (inchangée), serveur HTTP, fichiers du site, lecteur NFC, pont JavaScript vers le NFC, écran d'adresse, autorisation des connexions, écran de scan demandé par un ordinateur, maintien de l'écran allumé |
| Site | SPA légère (Svelte 5, construite par Vite), embarquée dans les ressources de l'application | Toute l'interface de gestion, pour le téléphone et pour l'ordinateur |
| WebView | Composant de l'application mobile | Affiche le site servi par `localhost` ; c'est l'interface principale de l'application |

### 4.2 Serveur

- Un seul serveur HTTP sur le téléphone, port 8080, qui sert :
  - les fichiers statiques du site à la racine (`/`) ;
  - l'API sous `/api/` ;
  - un canal d'événements temps réel (*Server-Sent Events*) sous `/api/events`.
- L'API est redessinée pour le site ; elle ne garde pas la compatibilité avec le manager v2.
- Le canal d'événements pousse au site : résultat d'un scan demandé, changement des données (une
  bouteille consommée sur le téléphone, une modification faite depuis un autre navigateur),
  autorisation accordée ou refusée. Il remplace l'attente longue de la v2.

### 4.3 Lecture NFC

Toute lecture de tag passe par **un même écran natif de lecture NFC**, affiché en plein écran
par-dessus la WebView. Il porte la consigne (« Présentez le tag »), l'objet de la lecture
(consommer, identifier, entrer une bouteille, rechercher), et un bouton d'annulation. Sur iOS, la
feuille NFC du système s'affiche en plus, par-dessus.

- **Dans l'application** : l'utilisateur appuie sur un bouton du site (par exemple « Consommer une
  bouteille ») ; le site appelle le pont JavaScript fourni par la WebView (par exemple
  `readTag("consume")`) ; l'écran natif de lecture s'affiche ; une fois le tag lu ou la lecture
  annulée, il se ferme et le site reçoit l'UID, ou l'annulation, et affiche la suite (bouteille
  consommée, fiche, formulaire rempli…).
- **Depuis un ordinateur** : le site demande un scan au téléphone par l'API. L'application affiche
  le même écran natif de lecture, par-dessus ce que montre la WebView, lit le tag, et le résultat
  est poussé au navigateur par le canal d'événements.
- Les fonctions qui consistent à lire un tag sur le téléphone (consommer, identifier) n'existent
  que dans l'application ; le site ne les affiche pas dans un navigateur d'ordinateur.

## 5. Accès depuis un ordinateur

### 5.1 Adresse

- L'application affiche un **écran d'adresse** clair : l'URL à saisir dans le navigateur
  (`http://192.168.1.42:8080`), en grand, avec le nom du réseau Wi-Fi si le système le permet.
- Si le téléphone n'a pas d'adresse sur un réseau local, l'écran le dit.
- L'adresse peut changer (bail DHCP) : l'écran affiche toujours l'adresse courante.

### 5.2 Autorisation des connexions

1. Un navigateur inconnu qui ouvre l'adresse voit une page « En attente d'autorisation sur le
   téléphone ».
2. Le téléphone affiche aussitôt une demande : « Autoriser cette connexion ? », avec ce qui permet
   de reconnaître l'ordinateur (navigateur et système tirés de l'en-tête `User-Agent`, adresse IP,
   heure).
3. « Autoriser » : le navigateur reçoit une session et accède au site. « Refuser » : la page
   l'indique.
4. La session est **gardée en mémoire** : le même navigateur n'a plus à être autorisé, même après
   un redémarrage de l'application ou un changement d'adresse IP.
5. L'application liste les connexions autorisées (navigateur, date d'autorisation, dernière
   activité) et permet de les révoquer, une à une ou toutes.

Exigences techniques :

- la session est un identifiant aléatoire dans un cookie `HttpOnly`, `SameSite=Strict` ; le
  téléphone n'en garde qu'une empreinte ;
- le serveur refuse toute requête dont l'en-tête `Host` n'est pas l'adresse du téléphone ou
  `localhost`, pour empêcher un site tiers d'atteindre l'API par rebinding DNS ;
- les requêtes qui modifient des données exigent une session valide et un en-tête `Origin`
  conforme ;
- la WebView de l'application est authentifiée par un secret généré par l'application et injecté
  dans la WebView, pas par sa seule adresse de boucle locale ;
- sessions et réglages sont rangés dans le stockage de l'application (C-01), hors de la base.

## 6. Fonctions

### 6.1 Où se trouve chaque fonction

| Fonction | Site, dans l'application | Site, sur un ordinateur | Natif (Flutter) |
|---|---|---|---|
| Catalogue : appellations, domaines, cuvées | ✓ | ✓ | |
| Inventaire | ✓ | ✓ | |
| Entrée en stock d'une bouteille | ✓ (tag lu par le pont NFC) | ✓ (tag lu par scan demandé au téléphone) | Lecture du tag |
| Recherche d'une bouteille par son tag | ✓ | ✓ | Lecture du tag |
| Tableau de bord | ✓ | ✓ | |
| Historique des dégustations, commentaires | ✓ | ✓ | |
| Sauvegarde et restauration | ✓ | ✓ | Enregistrement du fichier sur le téléphone |
| Paramètres (assistant IA…) | ✓ | ✓ | |
| Consommer une bouteille (lecture du tag) | ✓ | — | Lecture du tag |
| Identifier une bouteille (lecture du tag) | ✓ | — | Lecture du tag |
| Écran d'adresse | | | ✓ |
| Autorisation et liste des connexions | | | ✓ |
| Écran de lecture NFC, pour toute lecture (demandée par le site dans l'application ou par un ordinateur) | | | ✓ |

### 6.2 Fonctions reprises du manager

- **Catalogue**
  - Appellations : nom, région, description, image (fichier ou collage depuis le presse-papier).
  - Domaines : nom, description.
  - Cuvées : nom, domaine, appellation, couleur, description ; création possible depuis le
    formulaire de bouteille.
  - Complétion des noms d'appellation, de domaine et de cuvée.
  - Bouton « Demander à l'IA » : ouvre ChatGPT ou Claude dans un nouvel onglet avec une question
    préparée.
  - Suppression refusée, avec un message clair, quand l'objet est encore utilisé.
- **Inventaire**
  - Table des bouteilles : couleur, cuvée, domaine, appellation, région, millésime, « à boire
    avant », date d'entrée, date de consommation.
  - Tri par colonne, filtres par colonne, regroupement, affichage facultatif des bouteilles
    consommées.
  - Mise en évidence de la date de garde : dépassée, ou dans l'année en cours.
  - Ajout, modification, suppression, consommation sans tag (bouton).
  - Ajout à partir d'une bouteille existante prise comme modèle ; « Enregistrer et continuer »
    pour entrer une caisse entière, un tag après l'autre.
  - Recherche par tag.
  - Export ou impression de la table (impression du navigateur).
- **Tableau de bord** : nombre de bouteilles en stock, répartition par couleur et par
  appellation ; un clic ouvre l'inventaire filtré.

### 6.3 Fonctions reprises de l'application mobile

- Consommation : lecture du tag, consommation immédiate, ajout facultatif d'un commentaire
  (dans l'application seulement).
- Identification : lecture du tag, affichage de la bouteille (dans l'application seulement).
- Historique des dégustations, du plus récent au plus ancien, avec modification du commentaire.
- Statistiques du stock (nombre, couleurs, régions), reprises par le tableau de bord.
- Sauvegarde (téléchargement du fichier de base) et restauration (envoi d'un fichier).

## 7. Écrans à maquetter

### 7.1 Inventaire des écrans

Deux formats : **téléphone**, en portrait, dans la WebView de l'application ; **ordinateur**,
fenêtre large de navigateur. Interface en français.

| # | Écran | Format | Contenu principal |
|---|---|---|---|
| E-01 | Accueil | Téléphone | Gestes rapides : consommer, identifier, entrer une bouteille ; statistiques du stock ; accès aux autres écrans |
| E-02 | Consommation | Téléphone | Attente du tag, bouteille consommée, ajout d'un commentaire, erreurs (tag inconnu, déjà consommée) |
| E-03 | Identification | Téléphone | Attente du tag, fiche de la bouteille |
| E-04 | Inventaire | Les deux | Table et ses outils sur ordinateur ; liste filtrable sur téléphone |
| E-05 | Fiche et formulaire d'une bouteille | Les deux | Création, modification, modèle, « Enregistrer et continuer », attente du tag |
| E-06 | Appellations, domaines, cuvées | Les deux | Listes et formulaires, complétion, image, « Demander à l'IA » |
| E-07 | Tableau de bord | Les deux | Total, camemberts, accès à l'inventaire filtré |
| E-08 | Historique des dégustations | Les deux | Liste paginée, commentaire modifiable |
| E-09 | Paramètres | Les deux | Assistant IA, sauvegarde, restauration |
| E-10 | En attente d'autorisation | Ordinateur | Message, consigne de regarder le téléphone, refus |
| E-11 | Téléphone injoignable | Ordinateur | Application fermée ou en arrière-plan, consigne pour reprendre |
| N-E1 | Adresse de connexion | Natif | URL en grand, réseau, état du serveur |
| N-E2 | Demande d'autorisation | Natif | Navigateur, système, adresse IP, Autoriser / Refuser |
| N-E3 | Connexions autorisées | Natif | Liste, révocation |
| N-E4 | Lecture NFC | Natif | « Présentez le tag », objet de la lecture (consommer, identifier, entrer une bouteille, rechercher), origine (ce téléphone ou un ordinateur), annulation ; puis tag lu ou erreur, avant le retour au site |

### 7.2 Brief pour la charte graphique

La charte part d'une page blanche : Claude Design en propose une, à partir des éléments suivants.
Ce sont des propositions, à amender.

- **Sujet** : la cave à vin d'un amateur, quelques centaines de bouteilles, en France. Le ton est
  celui d'un carnet de cave soigné, pas d'un logiciel de gestion d'entrepôt.
- **Deux usages, une même identité** :
  - sur le téléphone, des gestes rapides, souvent d'une main : grandes cibles tactiles, peu de
    texte par écran. Le plus souvent, on choisit son vin avant de descendre à la cave : le
    téléphone sert aussi à parcourir l'inventaire tranquillement, pas seulement à scanner ;
  - sur l'ordinateur, une saisie et une consultation denses : tables longues, filtres, formulaires
    au clavier.
- **Couleurs des vins** : les cinq couleurs du modèle (rouge, blanc, rosé, effervescent, autre)
  plus « inconnue » ont chacune une couleur de repère, reconnaissable dans les tables et les
  graphiques, distincte pour les personnes daltoniennes.
- **États** à rendre lisibles d'un coup d'œil : bouteille en stock, consommée, date de garde
  dépassée, date de garde dans l'année ; tag lu, tag inconnu, en attente du tag ; téléphone
  joignable ou non.
- **Thèmes** : clair et sombre.
- **Accessibilité** : contrastes conformes au niveau AA du WCAG, tailles de texte lisibles sur
  téléphone.
- **Écrans natifs** (N-E1 à N-E4) : même identité que le site, pour que le passage de la WebView à
  un écran natif ne se voie pas.

## 8. Décisions prises

| # | Décision | Date |
|---|---|---|
| D-01 | Un maximum de fonctions dans le site ; Flutter ne garde que ce qui est propre au téléphone, dont le NFC. | 2026-10-18 |
| D-02 | Site en SPA légère (Vite), pas en Flutter Web ; framework fixé par D-14. | 2026-10-18 |
| D-03 | Connexion d'un ordinateur autorisée sur le téléphone par un écran de confirmation ; sessions autorisées gardées en mémoire. | 2026-10-18 |
| D-04 | Plus de découverte mDNS : le téléphone affiche l'adresse à saisir. | 2026-10-18 |
| D-05 | Pas de HTTPS. | 2026-10-18 |
| D-06 | Le téléphone reste au premier plan pendant l'usage depuis un ordinateur. | 2026-10-18 |
| D-07 | Schéma de base inchangé, compatibilité des fichiers dans les deux sens (C-01). | 2026-10-18 |
| D-08 | Maquettes des écrans produites avec Claude Design, à partir de cette spécification. | 2026-10-18 |
| D-09 | Réglages (assistant IA…) communs à tous les navigateurs, rangés sur le téléphone, hors de la base. | 2026-10-18 |
| D-10 | Une session autorisée n'expire pas ; seule sa révocation, depuis le téléphone, y met fin. | 2026-10-18 |
| D-11 | Pas de fonction nouvelle au passage (annulation d'une consommation, rappel de sauvegarde) : la v3 reprend les fonctions existantes. | 2026-10-18 |
| D-12 | Charte graphique créée de zéro avec Claude Design, sans reprendre celle de la v2 ; brief au [§7.2](#72-brief-pour-la-charte-graphique). | 2026-10-18 |
| D-13 | Consommer et identifier sont des écrans du site. Un bouton du site appelle le NFC natif ; le téléphone passe sur l'écran natif de lecture NFC (N-E4), puis revient au site avec le résultat. Ce même écran sert à toute lecture, y compris celles demandées par un ordinateur. | 2026-10-18 |
| D-14 | Site en Svelte 5 (syntaxe actuelle, avec `$state`, `$props`, `$derived`), construit par Vite. Ferme Q-02. | 2026-10-18 |
| D-15 | Charte retenue : papier crème, encre brune, bordeaux pour l'action ; Newsreader pour les titres et les chiffres, IBM Plex Sans pour l'interface, IBM Plex Mono pour les tags. Thèmes clair et sombre, contrastes AA vérifiés. Référence : maquettes `WineTap Planche`. | 2026-10-18 |
| D-16 | Couleur d'un vin signalée par un petit verre (forme propre à chaque couleur, rempli de sa teinte) et par son libellé ; la couleur n'est jamais le seul indice. | 2026-10-18 |
| D-17 | Navigation téléphone : barre d'onglets Accueil, Inventaire, Consommer (bouton rond central), Catalogue, Réglages. Tableau de bord et dégustations s'ouvrent depuis l'accueil. | 2026-10-18 |
| D-18 | Navigation ordinateur : barre latérale (Cave, Catalogue, Paramètres) avec l'état du téléphone en bas ; formulaire de bouteille en panneau à droite, la table restant visible. | 2026-10-18 |
| D-19 | Un clic sur une bouteille de l'inventaire ouvre une fenêtre de détail : bouteille, cuvée, domaine et appellation avec leurs descriptions. | 2026-10-18 |
| D-20 | L'image d'une appellation est une carte qui la situe ; elle utilise le champ image existant (C-01). | 2026-10-18 |
| D-21 | Sur ordinateur, raccourcis clavier : ↑ ↓ naviguer, Entrée ouvrir, Échap fermer, / rechercher, N ajouter, M sur le modèle, E modifier, T scanner, P imprimer. | 2026-10-18 |

## 9. Questions ouvertes

| # | Question | Proposition |
|---|---|---|
| — | Aucune pour l'instant (Q-02 fermée par D-14). | |
