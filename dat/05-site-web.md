# 5. Site web

<!-- toc -->

**Sur cette page**

- [5.1 Construction](#51-construction)
- [5.2 Formats](#52-formats)
- [5.3 Écrans](#53-écrans)
- [5.4 Accès et connexion au téléphone](#54-accès-et-connexion-au-téléphone)
- [5.5 État et événements](#55-état-et-événements)
- [5.6 Lecture des tags](#56-lecture-des-tags)
- [5.7 Aide à la saisie par un assistant IA](#57-aide-à-la-saisie-par-un-assistant-ia)
- [5.8 Développement](#58-développement)

<!-- /toc -->

Le site porte toute l'interface de gestion de WineTap. C'est une application d'une page (*single
page application*), servie par le téléphone et affichée de la même façon dans la WebView de
l'application et dans le navigateur d'un ordinateur.

## 5.1 Construction

| Élément | Choix |
|---|---|
| Cadre | Svelte 5, syntaxe à runes (`$state`, `$derived`, `$effect`, `$props`) |
| Construction | Vite ; cible `es2020`, Safari 15 et Chrome 100 |
| Vérification | `svelte-check` sur des types JSDoc (`jsconfig.json`) |
| Polices | Newsreader (titres, chiffres), IBM Plex Sans (interface), IBM Plex Mono (tags), sous-ensemble latin, empaquetées par `@fontsource` |
| Icônes | Tracés Lucide recopiés dans le code |
| Charte | Jetons CSS de la maquette (`tokens.css`) : papier crème, encre brune, bordeaux pour l'action ; thèmes clair et sombre selon le système |

Le site ne fait **aucun appel à Internet** à l'exécution : polices, icônes et images sont dans les
fichiers construits. `scripts/build_web.sh` construit le site (`npm ci` si besoin, puis
`npm run build`) et copie le dossier `dist/` dans `mobile/assets/site/`, que l'application
embarque. Ce dossier n'est pas versionné : toute construction de l'application commence par ce
script, en CI comme sur un poste ([§10.2](10-livraison.md#102-intégration-continue)).

## 5.2 Formats

Le site choisit son format d'après la taille de la fenêtre : format ordinateur à partir de
720 pixels de large et 500 de haut, format téléphone sinon. Un téléphone en paysage dépasse
720 pixels de large, mais sa hauteur ne laisserait aucune place à la table de l'inventaire : il
garde le format téléphone, qui défile en entier.

| | Format téléphone | Format ordinateur |
|---|---|---|
| Où | WebView de l'application ; navigateur étroit | Navigateur d'un ordinateur |
| Navigation | Barre d'onglets : Accueil, Inventaire, Consommer (bouton rond central), Catalogue, Réglages | Barre latérale : Cave (inventaire, tableau de bord, dégustations), Catalogue, Paramètres ; état du téléphone en bas |
| Formulaire de bouteille | Plein écran | Panneau à droite, la table restant visible |
| Clavier | — | Raccourcis : ↑ ↓ naviguer, Entrée ouvrir, Échap fermer, / rechercher, N ajouter, M sur le modèle, E modifier, T lire un tag, P imprimer |

Le site sait qu'il est **dans l'application** à la présence du pont `window.winetapBridge`
([§4.2](04-application-mobile.md#42-webview-et-pont)). Les gestes qui lisent un tag sur le
téléphone pour agir aussitôt, consommer et identifier, n'apparaissent que dans l'application.

Les écrans sont adressés par le fragment de l'URL (`#/inventaire?couleur=1`) : le bouton retour du
téléphone et du navigateur revient à l'écran précédent.

## 5.3 Écrans

| # | Écran | Format | Contenu |
|---|---|---|---|
| E-01 | Accueil | Téléphone | Gestes rapides : consommer, identifier, entrer une bouteille ; nombre de bouteilles et répartition ; accès au tableau de bord et aux dégustations. En paysage, deux colonnes, les gestes à droite, pour qu'ils restent visibles |
| E-02 | Consommation | Téléphone, application | Bouteille consommée, ajout d'un commentaire ; erreurs « tag inconnu » et « déjà consommée » |
| E-03 | Identification, fiche | Téléphone | Fiche de la bouteille lue ou choisie |
| E-04 | Inventaire | Les deux | Liste filtrable sur téléphone ; table triable, filtrable par colonne (régions à choix multiple), avec les interrupteurs « Regrouper » et « Consommées » sur ordinateur (la colonne de la date de consommation n'apparaît qu'avec les consommées), mise en évidence de la date de garde et impression par le navigateur. Un clic ouvre le détail : bouteille, cuvée, domaine, appellation ; un clic sur la carte de l'appellation l'affiche en grand |
| E-05 | Formulaire de bouteille | Les deux | Création, modification, création « sur le modèle » d'une bouteille, « Enregistrer et continuer » pour une caisse entière, lecture du tag, création d'une cuvée sans quitter le formulaire. Millésime obligatoire, entre 1900 et l'année courante |
| E-06 | Catalogue | Les deux | Appellations (avec carte, affichée en grand d'un clic), domaines, cuvées : listes, fiches, formulaires, complétion des noms, « Demander à l'IA » ; suppression refusée avec un message quand l'objet est utilisé |
| E-07 | Tableau de bord | Les deux | Total et alertes de garde ; anneau des couleurs animé (survol ou toucher d'une part : son détail au centre) ; régions, chaque barre découpée par couleur ; histogrammes des consommations et des achats (entrées en stock, avec le montant) des 12 derniers mois, empilés par couleur. Un clic sur une couleur ou une région ouvre l'inventaire filtré. Le tableau de bord charge aussi les bouteilles consommées |
| E-08 | Dégustations | Les deux | Bouteilles consommées, de la plus récente à la plus ancienne, par pages de 20 ; commentaire modifiable |
| E-09 | Réglages, Paramètres | Les deux | Choix de l'assistant IA ; sauvegarde et restauration ; dans l'application, accès aux écrans natifs N-E1 et N-E3 |
| E-10 | En attente d'autorisation | Ordinateur | Consigne de regarder le téléphone, puis refus éventuel |
| E-11 | Téléphone injoignable | Ordinateur | Application fermée ou en arrière-plan ; consigne pour reprendre |

La couleur d'un vin est montrée par un petit verre, de forme propre à chaque couleur, et par son
libellé : la couleur n'est jamais le seul indice.

## 5.4 Accès et connexion au téléphone

Au chargement, le site interroge `GET /api/session` :

- **dans l'application**, le jeton du pont l'identifie : il est aussitôt autorisé ;
- **sur un ordinateur**, sans session autorisée, il demande l'accès (`POST /api/session`) et
  affiche E-10 ; il passe au site dès l'événement `session` « autorisee », ou au plus tard à
  l'interrogation suivante de `GET /api/session`, répétée toutes les 3 secondes pendant l'attente.
  Si le téléphone ne prend pas la demande pour l'instant (429), E-10 affiche la raison donnée et le
  site redemande à chaque interrogation.

Le site ouvre ensuite le canal d'événements. Si le canal tombe, le site marque le téléphone
**injoignable** : sur un ordinateur, il affiche E-11 par-dessus le site ; le navigateur tente de
rouvrir le canal toutes les 5 secondes et le site reprend où il en était dès qu'il y parvient. Une
révocation ferme le canal et ramène le navigateur à E-10.

## 5.5 État et événements

Le site tient en mémoire des magasins d'état (catalogue, cave, réglages, lecture à distance,
dégustations), chargés depuis l'API au démarrage. Il ne garde rien dans le stockage du
navigateur.

Chaque modification, d'où qu'elle vienne, fait émettre au serveur l'événement `donnees`, avec la
liste de ce qui a changé (`bouteilles`, `catalogue`, `reglages`). Chaque navigateur ouvert, et la
WebView, recharge alors les magasins concernés : une bouteille consommée sur le téléphone disparaît
de l'inventaire ouvert sur l'ordinateur sans rechargement de la page. Les bouteilles arrivent de
l'API sans les noms du catalogue ; le site les joint lui-même.

## 5.6 Lecture des tags

Le site lit un tag par une seule fonction, `lireTag(objet)`, qui choisit le moyen selon l'endroit :

| Où | Moyen | Objets |
|---|---|---|
| Application | `readTag(objet)` du pont : le téléphone affiche N-E4 et rend le tag | `consommer`, `identifier`, `entree`, `recherche` |
| Ordinateur | `POST /api/scan` : le téléphone affiche N-E4, le tag revient par l'événement `scan` ; « Annuler » envoie `DELETE /api/scan/<id>` | `entree`, `recherche` |

Ce que le site fait du tag dépend de l'objet :

- **consommer** : `POST /api/consommer` ; la bouteille est consommée sans confirmation et E-02
  propose un commentaire ;
- **identifier, rechercher** : `GET /api/bouteilles/tag/<tag>`, puis la fiche ;
- **entrée en stock** : le tag remplit le champ du formulaire ; si une bouteille en stock le porte
  déjà, le serveur refuse la création et le site l'indique.

## 5.7 Aide à la saisie par un assistant IA

Le bouton « Demander à l'IA » des fiches et formulaires du catalogue ouvre **ChatGPT** ou
**Claude**, selon le réglage, avec une question préparée dans l'adresse, reprise du manager v2 :
description d'une appellation (avec sa région et une carte), d'un domaine (avec ses méthodes de
production, son adresse et son téléphone) ou d'une cuvée (style, nez, bouche, accords, garde, prix,
en six paragraphes), à partir de son nom et, pour une cuvée, de son domaine, de son appellation et
de sa couleur. La question invite à chercher sur des sites de critique de vin et demande une
réponse en texte seul, à recopier. Sur un ordinateur, la page s'ouvre dans un nouvel onglet ; dans
l'application, dans le navigateur du téléphone, par `openExternal`. L'utilisateur recopie lui-même
la réponse : le site n'appelle aucune API d'IA.

## 5.8 Développement

`npm run dev` lance Vite avec un serveur simulé, branché comme greffon : il implémente l'API en
mémoire, avec une cave d'environ 180 bouteilles, et ajoute un panneau « Téléphone simulé » qui
autorise les navigateurs, répond aux lectures à distance, coupe le téléphone ou consomme une
bouteille. Le paramètre `?app` simule la WebView : un pont factice imite N-E4. Ce serveur et ce
panneau ne font pas partie du site construit.

Le site est aussi essayé contre le vrai serveur, sans téléphone : un test Flutter, lancé à la
demande (`WINETAP_E2E=1`), démarre le serveur avec le site construit sur le port 8099, accepte
seul les autorisations et répond aux lectures à distance.
