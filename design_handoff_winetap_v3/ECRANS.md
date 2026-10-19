# Écrans — WineTap v3

Les identifiants (E-xx, N-Ex) sont ceux du §7.1 de `v3-web.md`. Pour chaque écran, l'état de départ dans les prototypes est indiqué entre crochets ; dans la planche, il figure sous l'étiquette de l'écran.

---

## Téléphone (390 × 844, dans la WebView)

**Cadre commun.** Fond `--wt-paper`. Contenu défilant avec des marges latérales de 20 px. Barre d'onglets en bas : hauteur 86 dont 22 de zone de geste, fond `--wt-card`, filet en haut, 5 colonnes.
- Onglets : Accueil, Inventaire, **Consommer**, Catalogue, Réglages. Icône 24 et libellé 11 px / 500. Actif en `--wt-accent-ink`, inactif en `--wt-ink3`.
- Consommer est un rond de 64 px en `--wt-accent`, remonté de 26 px, bordé de 4 px `--wt-card`, avec une icône verre de 28 et le libellé « Consommer » en 600.
- La barre est masquée sur les écrans natifs, sur N-E4 et sur les résultats E-02.
- **En-tête des sous-pages** : hauteur 52, bouton retour de 44 (chevron), titre 17 px / 600, action à droite en ghost (« Modifier », « Enregistrer »).

### E-01 Accueil [home]
Pas de titre d'écran : le contenu commence directement, pour gagner de la place.
1. **Carte stock** (bouton → E-07). Carte rayon 18, padding 18.
   - « 182 » en Newsreader 56 et « bouteilles en stock » en 15 `--wt-ink2`, chevron.
   - Barre empilée de 10 px (rayon 999, écart 2 px) avec une part par couleur.
   - Légende en ligne : verre 16, libellé, nombre en 600.
2. **Deux tuiles d'alerte** (grille 2 colonnes, rayon 14, hauteur min. 64) → inventaire filtré « À boire » :
   - « À boire en 2026 · 4 bouteilles » sur fond warn ;
   - « Garde dépassée · 3 bouteilles » sur fond danger.
3. **Grand bouton « Consommer une bouteille »** : hauteur 72, rayon 18, fond accent, verre 30, sous-titre « Présentez le tag au téléphone » en 13 px.
4. **Deux tuiles** (hauteur 84, rayon 16, icône accent 24) :
   - « Identifier » → N-E4 (identifier) ;
   - « Entrer en stock » → E-05.
5. **« Dernières dégustations »** (Newsreader 22) avec « Tout voir » (→ E-08) et deux cartes : verre, titre 15 / 500, commentaire en Newsreader italique 16, date 12.

### N-E4 Lecture NFC [nfc, nfcComputer, nfcRead] — natif
Plein écran, même identité que le site.
- **En haut** : pastille d'origine, « Depuis ce téléphone » (card2) ou « Demandé par un ordinateur · Firefox sur macOS » (accent-tint, icône écran).
- **Au centre** : surtitre de l'objet de la lecture (Consommer une bouteille, Identifier une bouteille, Entrer une bouteille en stock, Rechercher une bouteille par son tag).
- **Attente** : cercles concentriques de 220 et 164 px (filets) et rond de 108 en accent avec l'icône NFC de 48. Titre « Présentez le tag » en Newsreader 36, consigne « Approchez le haut du téléphone du tag collé sur la bouteille ».
- **Lu** : rond de 164 ok-tint avec coche de 64, « Tag lu », UID en mono 18. Retour au site après environ 0,9 s.
- **Erreur de lecture** : rond danger avec alerte, « Lecture impossible », bouton « Réessayer ».
- **En bas** : « Annuler » en secondaire, hauteur 56.
- Lecture demandée par l'ordinateur : retour à l'écran précédent et toast « Tag envoyé à l'ordinateur ».

### E-02 Consommation [consumed, commentOpen, consumeError, alreadyConsumed]
- **Consommée** : bouton fermer à droite.
  - Pastille ok « Bouteille consommée », cuvée en Newsreader 38, domaine · appellation, verre + couleur + millésime.
  - Carte avec deux lignes : « Reste en cave » 3 bouteilles, « Tag libéré » UID.
  - En bas : « Ajouter un commentaire » (secondaire, icône message), puis « Terminé » (primaire).
- **Commentaire** : textarea de 4 lignes en Newsreader 18 ; « Enregistrer le commentaire » et « Plus tard ».
- **Tag inconnu** : rond warn avec icône tag, « Tag inconnu », « Ce tag n'est associé à aucune bouteille en stock. », UID dans une puce mono. Boutons « Lire un autre tag » et « Entrer une bouteille avec ce tag ».
- **Déjà consommée** : rond danger, « Déjà consommée », « Cette bouteille est sortie du stock. Rien n'a été modifié. », carte de la bouteille avec sa date de consommation. Boutons « Lire un autre tag » et « Voir les dégustations ».

### E-03 Identification · fiche [bottle]
En-tête : retour et « Modifier ».
- Verre, couleur · millésime ; cuvée en Newsreader 38 ; domaine.
- Pastilles « En stock · N bouteilles » et garde (si cette année ou dépassée).
- Carte de 6 lignes (libellé à gauche en `--wt-ink2`, valeur à droite) : Appellation, Région, À boire avant, Prix d'achat, Entrée en cave, Tag (mono).
- Boutons « Consommer sans tag » et « Ajouter sur ce modèle ».

### E-04 Inventaire [inventory, inventoryEmpty, bottleModal]
- **Ligne d'outils** : champ « Rechercher un vin » (h 48, rayon 14), bouton NFC 48 (recherche par tag → N-E4), bouton + 48 accent (→ E-05).
- **Filtres** en pastilles défilant horizontalement (h 36) : Tout, Rouge, Blanc, Rosé, Effervescent, À boire. Pastille active en fond `--wt-ink` et texte `--wt-paper`.
- Compteur en 13 px `--wt-ink3`, par exemple « 182 bouteilles · groupées par cuvée ».
- **Liste groupée par cuvée** dans une carte : ligne de 64 px min. avec verre 22, « Cuvée millésime » en 16 / 500 (millésime en ink3), « Domaine · Appellation » en 13. Badge de garde 12 px si cette année ou dépassée. Quantité à droite en Newsreader 22.
- **Vide** : verre vide de 64, « La cave est vide », boutons « Entrer une bouteille » et « Restaurer une sauvegarde ».
- **Détail d'une bouteille (D-19)** : feuille du bas d'au plus 760 px.
  - En-tête : verre, couleur · millésime, fermer ; cuvée en Newsreader 32 ; domaine ; pastilles.
  - Encadré papier sur 3 colonnes : À boire avant, Prix, Entrée.
  - Sections Cuvée, Domaine et Appellation : surtitre 11 px en majuscules, nom en Newsreader 20, description 15 / 1,5. L'appellation affiche aussi sa carte (h 110) et sa région.
  - Pied : « Sur ce modèle » et « Modifier ».

### E-05 Entrée en stock [form, formTag, formError]
En-tête : « Entrer en stock » avec la ligne « Nouvelle bouteille » ou « 3e bouteille de la caisse ».
- **Tag** : bouton pointillé accent de hauteur 64, « Lire le tag de la bouteille » ; une fois lu, encadré ok avec l'UID.
- **Cuvée** : champ avec complétion ; dessous, la ligne dérivée (verre, couleur · domaine · appellation).
- Millésime et À boire avant côte à côte.
- Prix d'achat, marqué « · facultatif », avec le symbole €.
- Boutons « Enregistrer et continuer » (primaire, sous-titre « même cuvée, tag suivant ») et « Enregistrer et terminer ».
- **Erreur** : « Choisissez ou créez une cuvée ».

### E-06 Catalogue [catalogue, catalogueApp, catalogueDom, catForm, catFormDom]
- **Liste** : segmenté Appellations / Domaines / Cuvées, recherche et bouton +, liste (h 60) avec nom et ligne secondaire (région · N cuvées ; lieu · N cuvées ; domaine · appellation avec verre).
- **Fiche appellation** : surtitre « Appellation », nom en Newsreader 32, sous-ligne.
  - **Carte de l'appellation** (D-20) : zone image de 260 px de haut, rayon 16, affichage `contain` ; boutons « Choisir une image » et « Retirer ».
  - Champs Nom, Région, Description.
  - « Cuvées de cette appellation » : liste avec verre, cuvée et millésime, domaine, quantité.
- **Fiche domaine** : deux tuiles chiffrées (bouteilles en cave, cuvées en cave), Nom, Description, « Cuvées du domaine ».
- **Fiche cuvée** : Nom, Domaine, Appellation, Couleur (grille 2 × 3 de choix avec verre, l'actif bordé d'accent), Description.
- **Communs** : « Demander à Claude » (icône étincelles), « Supprimer » (danger, avec message de refus si l'objet est utilisé), « Enregistrer » dans l'en-tête.

### E-07 Tableau de bord [dashboard]
- **Carte couleurs** : anneau de 200 px (conic-gradient, séparations de 0,4 % en `--wt-card`) avec « 182 en stock » au centre. Dessous, une ligne cliquable par couleur (h 46) : verre, libellé, nombre, chevron.
- **Carte « Par région »** : barres horizontales (libellé 92 px, barre de 12 px en accent sur card2, nombre).

### E-08 Dégustations [history]
Cartes du plus récent au plus ancien : verre, date, crayon (modifier), titre 16 / 500, appellation · millésime, commentaire en Newsreader italique 18. Chargement par pages en défilant.

### E-09 Réglages [settings, restoreError]
Groupes avec surtitre en majuscules et cartes de listes (lignes de 52 à 56 px) :
- **Assistant IA** : Claude et ChatGPT, l'actif marqué d'une coche.
- **Sauvegarde** : « Enregistrer une sauvegarde » et « Restaurer une sauvegarde » (danger). La confirmation danger s'affiche dans la page ; « Fichier non reconnu » en cas de fichier invalide.
- **Accès depuis un ordinateur** : Adresse de connexion (→ N-E1) et Connexions autorisées (→ N-E3, avec leur nombre).

### N-E1 Adresse de connexion [address, addressNone] — natif
- Pastille « Serveur actif » (ok).
- « Dans le navigateur de l'ordinateur, saisissez : », puis une carte avec `http://` en mono 15, l'IP en mono 38 / 500 et `:8080` en mono 24.
- Réseau Wi-Fi (icône wifi) et rappel « Gardez WineTap ouvert… L'adresse peut changer : elle est toujours à jour ici. »
- Bouton « Connexions autorisées ».
- **Sans réseau** : pastille danger « Pas de réseau local », icône wifi barrée, « Aucune adresse à afficher », consigne de connexion au Wi-Fi.

### N-E2 Demande d'autorisation [authReq] — natif
Feuille du bas par-dessus l'écran courant, rayon 28.
- Icône écran dans un carré accent-tint de 56, titre « Autoriser cette connexion ? » en Newsreader 30.
- Encadré papier : Navigateur, Système, Adresse IP (mono), Heure.
- Rappel « Ce navigateur aura accès à toute la cave, jusqu'à ce que vous révoquiez la connexion. »
- Boutons « Refuser » (secondaire) et « Autoriser » (primaire), côte à côte.

### N-E3 Connexions autorisées [connections] — natif
- Liste : icône écran, nom du navigateur (point vert si actif), « Autorisé le … · actif … », bouton « Révoquer » (danger).
- « Tout révoquer » en bas.
- **Vide** : « Aucun ordinateur autorisé… ».

---

## Ordinateur (1280 × 800 dans les maquettes, mise en page fluide au-delà)

**Cadre commun.**
- **Barre latérale** de 228 px, filet à droite.
  - « WineTap » en Newsreader 26 / 600.
  - Groupes « Cave » (Tableau de bord, Inventaire, Dégustations), « Catalogue » (Appellations, Domaines, Cuvées), puis Paramètres. Surtitres 11 px en majuscules `--wt-ink3`.
  - Éléments de 36 px, rayon 9, icône 18. Élément actif : fond `--wt-card`, bordure `--wt-line`, 600, icône accent.
  - En bas, carte d'état du téléphone : point ok avec halo, « Téléphone joignable », « iPhone · 192.168.1.42 ».
- **Contenu** : padding 20 × 24.
- **Panneau droit** (formulaire) de 380 px, fond carte, filet et ombre à gauche.

### E-04 Inventaire [inventory, inventoryEmpty, bottleModal]
- **En-tête** : « Inventaire » en Newsreader 30 et « 182 bouteilles · 43 lignes ». À droite : Scanner `T`, Imprimer `P`, **Ajouter** `N` (primaire). Boutons sur une ligne ; ils passent sous le titre si la place manque.
- **Barre d'outils** : recherche de 260 px (`/`), cases « Regrouper les bouteilles identiques » et « Afficher les bouteilles consommées », puis les actions de sélection : Sur ce modèle `M`, Modifier `E`, Consommer, Supprimer (icône danger).
- **Table** dans une carte de rayon 12, défilement interne, en-tête collant.
  - Colonnes : repère de sélection 32, Couleur 112, Cuvée, Domaine, Appellation, Région 92, Millésime 68, À boire avant 150, Qté 44 (à droite), Entrée 88, Consommée 92.
  - Ligne de filtres sous l'en-tête (champs de 24 px, rayon 6).
  - Lignes de 38 px, 13,5 px, chiffres tabulaires. Survol en `--wt-card2`. Sélection en `--wt-accent-tint` avec une barre accent de 6 × 20 à gauche.
  - Bouteilles consommées : fond papier, cuvée barrée, date en ink2.
- Sous la table : rappel « ↑ ↓ naviguer · Entrée ouvrir · Échap fermer · / rechercher » en 12 px ink3.
- **Vide** : verre vide de 56, « La cave est vide », « Ajouter une bouteille » et « Restaurer une sauvegarde ».
- **Détail d'une bouteille (D-19)** : modale de 680 px.
  - En-tête : verre, couleur · millésime, cuvée en Newsreader 34, domaine · appellation (région), pastilles.
  - Grille de 3 × 2 champs : Millésime, À boire avant, Prix d'achat, Entrée en cave, Tag, Quantité.
  - Sections Cuvée, Domaine et Appellation (carte de 132 × 96 à gauche, nom, région, description).
  - Pied à droite : Ajouter sur ce modèle, Consommer, **Modifier**.

### E-05 Formulaire de bouteille [inventoryPanel, formError, scanWait, scanUsed]
Panneau droit.
- En-tête : « Nouvelle bouteille » en Newsreader 22 et « Bouteille n° X de la saisie » ; bouton fermer.
- **Cuvée** avec complétion ouverte (voir `Autocomplete`), puis la ligne dérivée sur fond papier.
- Millésime, À boire avant et Prix d'achat (€) sur trois colonnes ; Commentaire (facultatif).
- **Tag NFC** : voir `TagField`, avec « Lire avec le téléphone » (bouton foncé `--wt-ink`).
- Pied : « Enregistrer et continuer » (secondaire, en pleine largeur) et « Enregistrer ⌘↵ » (primaire).
- **Erreurs** : cuvée vide (« Choisissez une cuvée existante ou créez-en une »), millésime hors bornes (« Année entre 1900 et 2026 »).

### E-06 Catalogue [catalogue, catalogueApp, catalogueDom]
- **Colonne liste** de 330 px : titre de la rubrique en Newsreader 28 et « Ajouter », filtre, éléments (nom 14 / 500, sous-ligne 12,5, verre pour les cuvées ; sélection en accent-tint).
- **Détail** : surtitre (Appellation, Domaine, Cuvée), nom en Newsreader 30, sous-ligne. Boutons « Demander à Claude ↗ » et supprimer. Message warn si la suppression est refusée.
  - **Appellation** : à gauche Nom, Région (liste), Description ; à droite, carte de 300 × 300 (`contain`, collage Ctrl+V, dépôt de fichier) avec « Choisir un fichier », « Retirer » et l'aide « PNG ou JPEG ». Dessous, la table « Cuvées de cette appellation » (verre, cuvée, domaine, millésime, quantité).
  - **Domaine** : Nom et Description ; tuile de 220 px avec le nombre de bouteilles en cave et l'appellation principale ; table « Cuvées du domaine ».
  - **Cuvée** : Nom, Domaine, Appellation, Couleur (6 choix avec verre), Description.
- « Enregistrer » et « Annuler » en bas.

### E-07 Tableau de bord [dashboard]
Grille de trois colonnes (280 px, puis deux colonnes égales).
- **Colonne 1** : « 182 » en Newsreader 72 avec « bouteilles · 43 références », puis les tuiles « À boire en 2026 » et « Garde dépassée » (avec les cuvées concernées).
- **Colonne 2, « Par couleur »** : anneau de 170 px et légende cliquable (verre, libellé, nombre, pourcentage).
- **Colonne 3, « Par région »** : barres.
- Chaque élément ouvre l'inventaire filtré.

### E-08 Dégustations [history]
- Carte de 880 px au plus. Lignes en grille : date 110, verre, titre · méta, commentaire en Newsreader italique 17 (ou « Pas de commentaire »), crayon.
- Édition sur place : champ accent, « Enregistrer », « Échap pour annuler ».
- Pagination « 1–6 sur 64 » avec Précédent et Suivant.

### E-09 Paramètres [settings, restoreError]
Cartes de 760 px au plus.
- **Assistant IA** : deux boutons radio de 52 px.
- **Sauvegarde et restauration** : « Télécharger » (nom du fichier `winetap-AAAA-MM-JJ.db`) et « Choisir un fichier » (danger). Confirmation danger dans la page, avec « Remplacer la cave » et « Annuler » ; erreur « Fichier non reconnu ».

### E-10 En attente d'autorisation [waitingAuth]
Plein écran, sans barre latérale, colonne centrée de 460 px.
- « WineTap », icône téléphone dans des cercles, pastille warn « En attente d'autorisation ».
- « Regardez votre téléphone » en Newsreader 34 et l'explication.
- Encadré : Navigateur, Adresse, Heure.
- **Refusée** : rond danger, « Connexion refusée », « Demander à nouveau ».

### E-11 Téléphone injoignable [unreachable]
- Pastille danger « Téléphone injoignable », « Le téléphone ne répond plus ».
- Trois étapes numérotées (ouvrir WineTap au premier plan, même Wi-Fi, saisir la nouvelle adresse).
- « Nouvelle tentative automatique toutes les 5 secondes · dernière adresse … », bouton « Réessayer maintenant ».
