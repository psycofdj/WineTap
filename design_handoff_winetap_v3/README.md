# Handoff : WineTap v3, site embarqué (Svelte 5)

## Vue d'ensemble

WineTap gère une cave à vin personnelle (environ 180 bouteilles), chaque bouteille portant un tag NFC. En v3, l'application Flutter sert un site web (SPA) qui remplace le manager de bureau. Ce site s'affiche dans la WebView du téléphone et dans le navigateur d'un ordinateur du même réseau. La spécification fonctionnelle complète est dans `v3-web.md`, joint. Les décisions de design sont D-14 à D-21.

Le dossier contient :
- `v3-web.md` : la spécification (contraintes, API, sécurité, fonctions, décisions) ;
- `tokens.css` : les variables de la charte, prêtes à importer ;
- `ECRANS.md` : la description écran par écran (mise en page, contenus, états) ;
- `maquettes/` : les maquettes HTML cliquables.

## À propos des maquettes

Les fichiers de `maquettes/` sont des **références de design en HTML**, pas du code à reprendre. Le travail consiste à **recréer ces écrans en Svelte 5 + Vite** (D-14), avec des composants `.svelte` et du CSS propre à chaque composant, appuyés sur `tokens.css`.

Pour voir les maquettes : ouvrir `maquettes/WineTap Planche.dc.html` dans un navigateur, depuis un petit serveur local (par exemple `npx serve maquettes`). La planche montre la charte puis tous les écrans. Chaque écran est cliquable sur place.
- `WineTap-Telephone.dc.html` : prototype téléphone, 390 × 844.
- `WineTap-Ordinateur.dc.html` : prototype ordinateur, 1280 × 800.
- `winetap-data.js` : données d'exemple, glyphes des verres, tracés d'icônes.

Dans les prototypes, les boutons en pointillés marqués « Prototype · simuler » remplacent le NFC et le serveur. Ils ne font pas partie du produit.

## Fidélité

**Haute fidélité.** Couleurs, typographie, rayons, espacements et textes sont définitifs. Reproduire au pixel près, à partir des valeurs de `tokens.css` et d'`ECRANS.md`.

## Contraintes à respecter (rappel de la spec)

- Svelte 5 avec la syntaxe actuelle (runes `$state`, `$props`, `$derived`, `$effect` ; gestionnaires `onclick={…}`). Pas d'ancienne syntaxe (`export let`, `$:`, `on:click`).
- Le site est embarqué dans l'application et fonctionne **sans Internet** : polices et icônes sont empaquetées, sans CDN.
- HTTP seulement sur l'ordinateur (C-02) : ni caméra, ni API presse-papier asynchrone, ni service worker. Le collage d'image passe par l'événement `paste` (Ctrl+V).
- Le schéma de base ne change pas (C-01). L'image d'appellation utilise le champ image existant.
- Les fonctions qui lisent un tag (consommer, identifier) n'existent que **dans l'application**. Le site détecte s'il tourne dans la WebView (présence du pont JS) et masque ces fonctions dans un navigateur d'ordinateur.
- Interface en français, typographie française (espace insécable avant `: ; ? !`, guillemets « »).

## Architecture front proposée

```
src/
  app.css                 ← importe tokens.css
  lib/
    api.js                ← appels /api/*, gestion des erreurs
    events.js             ← EventSource /api/events (scan, données, autorisation)
    nfc.js                ← lireTag(objet) : pont WebView ou scan demandé au téléphone
    contexte.js           ← dansApplication (bool), état de connexion du téléphone
    garde.js              ← calcul de l'état « à boire avant »
    stores/*.svelte.js    ← état partagé avec $state (bouteilles, catalogue, réglages)
  components/
    WineGlass.svelte  GardeBadge.svelte  StatusPill.svelte  Button.svelte
    Field.svelte  Autocomplete.svelte  Segmented.svelte  Sheet.svelte  Modal.svelte
    Toast.svelte  TabBar.svelte  Sidebar.svelte  BottleDetail.svelte  TagField.svelte
    ImageDrop.svelte  ConfirmDanger.svelte
  routes/ (ou écrans/)
    telephone/*  ordinateur/*  partagés : Inventaire, Bouteille, Catalogue, …
```

Format : le même site sert les deux usages. Retenir la mise en page **téléphone** sous 720 px de large et **ordinateur** au-delà. Les écrans E-10 et E-11 n'existent que sur ordinateur.

## Composants de base

| Composant | Rôle et règles |
|---|---|
| `WineGlass` | Repère de couleur du vin (D-16). Prop `couleur` (0 inconnue, 1 rouge, 2 blanc, 3 rosé, 4 effervescent, 5 autre). SVG 20 × 20 : tracé du verre en `currentColor` (trait 1,3), liquide rempli de `--wine-*`. Formes : rouge = verre ballon, blanc et rosé = tulipe, effervescent = flûte avec bulles, autre = petit verre, inconnue = tulipe vide avec « ? ». Tracés exacts dans `winetap-data.js` (objet `G`). Toujours accompagné du libellé, sauf dans une liste où le libellé est ailleurs sur la ligne. Tailles : 16 (légende), 18 (table), 20 à 22 (listes téléphone), 30 (charte). |
| `GardeBadge` | `annee` → aucune / ok / cette année / dépassée (année courante du téléphone). Dépassée : fond `--wt-danger-tint`, texte `--wt-danger`. Cette année : `--wt-warn-tint` / `--wt-warn`. Ok : texte `--wt-ink2` sans fond. Rayon 6, 13 px, année en 600. |
| `StatusPill` | Pastille ronde (rayon 999, 13 px, 600, padding 5 × 12) : en stock (ok), consommée (`--wt-card2` / `--wt-ink2`), NFC (attente = accent-tint, lu = ok, inconnu = warn, déjà consommée = danger, annulée = card2), connexion (point de 8 px + libellé). |
| `Button` | Variantes `primary` (fond `--wt-accent`, texte `--wt-on-accent`), `secondary` (fond `--wt-card`, bordure 1 px `--wt-line2`), `ghost` (transparent, texte `--wt-accent-ink`), `danger` (texte `--wt-danger`, ou fond plein `--wt-danger` pour la confirmation). Téléphone : hauteur 56 (52 pour le secondaire), rayon 16, 17 px 600. Ordinateur : hauteur 34 à 38, rayon 9, 13,5 px 600. Appui : `transform: scale(.97)`, 100 ms. Désactivé : opacité .5. |
| `Field` | Libellé au-dessus (téléphone 14 px 600 ; ordinateur 12,5 px 600 `--wt-ink2`). Champ : téléphone h 52, rayon 14, 17 px ; ordinateur h 36, rayon 8, 14 px. Bordure 1 px `--wt-line2`. Focus : bordure 1,5 px `--wt-accent` + halo 3 px `--wt-accent-tint`. Erreur : libellé et bordure 1,5 px `--wt-danger`, message dessous avec l'icône alerte. |
| `Autocomplete` | Liste sous le champ (bordure `--wt-line2`, rayon 10, ombre `--wt-shadow`). Chaque option : nom (partie saisie en 600) et ligne secondaire 12 px (domaine · appellation · couleur). Dernière option : « Créer la cuvée « … » » en accent 600. Clavier : ↑ ↓ Entrée Échap. |
| `Segmented` | Fond `--wt-card2`, rayon 12, padding 3 ; option active fond `--wt-card` + ombre `0 1px 3px rgba(42,29,21,.12)`. H 40, 14 px 600. |
| `Sheet` (téléphone) | Feuille du bas : rayon 28 en haut, poignée 40 × 5, voile `rgba(42,29,21,.45)`. Ferme au clic sur le voile et par glissement. |
| `Modal` (ordinateur) | 680 px de large, hauteur max 700, rayon 18, ombre `0 30px 80px rgba(42,29,21,.3)`, voile `rgba(42,29,21,.4)`. Échap ferme ; focus piégé dans la fenêtre. |
| `Toast` | Fond `--wt-ink`, texte `--wt-paper`, rayon 14 (10 sur ordinateur), icône info. Téléphone : au-dessus de la barre d'onglets. Ordinateur : centré en bas. Disparaît après 2,6 s. |
| `TagField` | Champ « Tag NFC » du formulaire. États : vide (bouton « Lire le tag » / « Lire avec le téléphone »), attente (fond accent-tint, rond NFC accent, « En attente du tag », Annuler), lu (fond ok-tint, coche, UID en mono), déjà associé (fond warn-tint, bouteille concernée, « Lire un autre tag »). |
| `ImageDrop` | Carte d'appellation : glisser-déposer, choix de fichier, collage Ctrl+V (événement `paste`). Affichage en `contain`, fond `--wt-paper`. Boutons « Choisir un fichier » et « Retirer ». |

## Interactions et comportement

- **Lecture NFC dans l'application** : `lireTag(objet)` appelle le pont de la WebView ; l'écran natif N-E4 s'affiche, puis le site reçoit `{ tagId }` ou `{ annule: true }`. Une annulation affiche le toast « Lecture annulée » et revient à l'écran précédent.
- **Lecture NFC depuis l'ordinateur** : `POST /api/scan` ; le résultat arrive par `/api/events`. Le `TagField` passe en attente, puis lu, déjà associé ou annulé.
- **Consommer (téléphone)** : bouton rond de la barre d'onglets ou grand bouton de l'accueil → N-E4 → E-02. Après consommation : bouteille consommée, puis possibilité de commentaire (textarea Newsreader 18 px) et « Terminé ».
- **Inventaire** : un clic (ou Entrée) sur une bouteille ouvre la fenêtre de détail (D-19) : modale sur ordinateur, feuille sur téléphone.
- **Enregistrer et continuer** : garde la cuvée, le millésime, la garde et le prix ; vide le tag ; incrémente le compteur « Bouteille n° X de la saisie » ; toast.
- **Suppression au catalogue** : refusée si l'objet est utilisé ; message warn « Suppression impossible : … ».
- **Restauration** : choix du fichier, puis confirmation danger « Remplacer toute la cave ? » avec le nombre de bouteilles du fichier et de la cave actuelle. Un fichier invalide affiche « Fichier non reconnu… La cave n'a pas été modifiée ».
- **« Demander à l'IA »** : ouvre Claude ou ChatGPT (réglage commun, D-09) dans un nouvel onglet, avec une question préparée.
- **Tableau de bord** : un clic sur une part de couleur ou une barre de région ouvre l'inventaire filtré.
- **Perte du téléphone (ordinateur)** : si `/api/events` tombe, afficher E-11 et réessayer toutes les 5 s ; revenir automatiquement à l'écran précédent quand le téléphone répond.
- **Clavier sur ordinateur (D-21)** : ↑ ↓ (ou j k) déplacent la sélection dans la table ; Entrée ouvre le détail ; Échap ferme la fenêtre ou le panneau ; / met le focus dans la recherche ; N ajouter, M sur le modèle, E modifier, T scanner, P imprimer ; ⌘/Ctrl+Entrée enregistre le formulaire. Raccourcis inactifs quand le focus est dans un champ.
- **Mouvement** : 120 ms pour les micro-interactions, 200 ms de base, 360 ms pour les entrées (feuilles, modale) ; courbe `cubic-bezier(.22,1,.36,1)`. Pas de rebond.

## État (stores)

- `contexte` : `dansApplication`, `telephone` (joignable / injoignable), `autorisation` (en attente / refusée / ok).
- `bouteilles` : liste en stock, rafraîchie par l'événement « données changées » de `/api/events` ; filtres, tri et regroupement de l'inventaire.
- `catalogue` : appellations, domaines, cuvées.
- `reglages` : assistant IA, thème (clair / sombre, ou celui du système par défaut).
- `scan` : `inactif | attente | lu | deja-associe | annule`, plus le `tagId`.

## Variables de la charte

Toutes les valeurs sont dans `tokens.css`. En résumé :
- **Surfaces** : papier `#F6F1E7`, carte `#FFFDF8`, carte 2 `#EFE7D8`, filet `#E4D9C6`, bordure `#CDBFA6`.
- **Encre** : `#2A1D15`, `#5C4A3C`, `#76624F`. **Action** : bordeaux `#7B1E2E`.
- **États** : danger `#A8321F` / `#F8E2DB`, warn `#7F5300` / `#F6E9C8`, ok `#2F6B3A` / `#E2EDD9`.
- **Vins** : rouge `#6E1A2B`, blanc `#E3C04F`, rosé `#EC9AA8`, effervescent `#EFE0A0`, autre `#B5762A`, inconnue sans remplissage.
- **Thème sombre** : bloc `[data-theme="sombre"]`. Contrastes AA vérifiés dans les deux thèmes (minimum 4,7:1).
- **Typographie** :

| Usage | Police | Taille / graisse |
|---|---|---|
| Chiffre clé (accueil, tableau de bord) | Newsreader | 56 à 72 / 500, interligne 0,9 à 1 |
| Titre d'écran ordinateur | Newsreader | 30 / 500, -0,01em |
| Titre de fiche téléphone | Newsreader | 32 à 38 / 500, interligne 1,05 |
| Titre de section | Newsreader | 20 à 22 / 500 |
| Commentaire de dégustation | Newsreader italique | 16 à 18 / 400, entre « » |
| Texte téléphone | IBM Plex Sans | 16 / 400, libellés 14 / 600 |
| Texte ordinateur | IBM Plex Sans | 14 / 400 ; table 13,5 ; légendes 12 à 13 |
| Surtitre | IBM Plex Sans | 11 à 13 / 600, majuscules, +0,08 à 0,12em |
| Tag NFC, adresse IP | IBM Plex Mono | 14 à 18 / 500, +0,05em ; adresse N-E1 : 38 |

- **Espacements** : grille de 4 px. Marges du téléphone 20 (24 sur les écrans natifs), écart entre blocs 14 à 18. Ordinateur : contenu à 24 px, panneau de 380 px, barre latérale de 228 px.
- **Cibles tactiles** : 44 px minimum ; en pratique 48 à 64 sur téléphone.

## Ressources

- **Icônes** : Lucide (trait 1,75, bouts ronds), en SVG embarqué. Tracés utilisés dans `winetap-data.js` (objet `I`) ; on peut aussi utiliser `lucide-svelte`.
- **Verres** : SVG dessinés pour WineTap, dans `winetap-data.js` (objet `G`).
- **Polices** : Newsreader, IBM Plex Sans, IBM Plex Mono (licence OFL), à empaqueter.
- **Cartes d'appellation** : fournies par l'utilisateur, aucune livrée.

## Fichiers

- `ECRANS.md` : spécification écran par écran.
- `tokens.css`
- `v3-web.md`
- `maquettes/WineTap Planche.dc.html`, `maquettes/WineTap-Telephone.dc.html`, `maquettes/WineTap-Ordinateur.dc.html`, `maquettes/winetap-data.js`
