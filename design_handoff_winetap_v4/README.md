# Handoff : WineTap v3.1, évolutions des écrans (Svelte 5)

## Vue d'ensemble

Ce dossier complète le handoff v3 (site embarqué en Svelte 5, servi par l'application Flutter). Il décrit **les évolutions apportées aux maquettes depuis la v3**, à implémenter dans le code existant :

1. bouton assistant à double action (Demander à Claude / Copier le prompt) ;
2. suppression des fiches du catalogue avec confirmation et refus ;
3. champs à complétion (cuvée, domaine, appellation) avec **création en cascade** et retour vers l'objet d'origine ;
4. blasons de région partout où une région s'affiche ;
5. cartes d'appellation (image) et vue agrandie ;
6. descriptions éditables qui s'agrandissent avec le texte ;
7. filtres fonctionnels de l'inventaire, dont la sélection multiple ;
8. tableau de bord harmonisé : donut de stock et historiques avec sélecteur Couleur / Appellation / Région, légendes en tableau ;
9. dégustations : région et blason ;
10. ajustements de mise en page : colonne « À boire avant », écran E-03, barre du haut des fiches sur téléphone.

Le dossier contient :
- `README.md` : ce document, autonome pour les évolutions ;
- `v3-web.md` : la spécification v3, inchangée (contraintes C-01, C-02, API, décisions) ;
- `ECRANS-v3.md` : la description écran par écran de la v3. **Ce README fait foi** quand il la contredit ;
- `tokens.css` : les variables de la charte, inchangées ;
- `maquettes/` : les maquettes HTML cliquables à jour, avec les blasons et les cartes d'exemple.

## À propos des maquettes

Les fichiers de `maquettes/` sont des **références de design en HTML**, pas du code à reprendre. Il s'agit de **recréer ces comportements dans l'application Svelte 5 + Vite existante**, avec ses composants et `tokens.css`.

Pour les voir : servir le dossier (`npx serve maquettes`) puis ouvrir `WineTap Planche.dc.html`. La planche montre chaque écran dans plusieurs états. Chaque écran est cliquable.
- `WineTap-Telephone.dc.html` : prototype téléphone, 390 × 844 ;
- `WineTap-Ordinateur.dc.html` : prototype ordinateur, 1280 × 800 ;
- `winetap-data.js` : données d'exemple, correspondance région → blason, cartes, données des graphiques.

Le paramètre `start` des prototypes ouvre un état précis. Les noms d'état sont cités entre crochets dans ce document, par exemple [flow3].

## Fidélité

**Haute fidélité.** Couleurs, typographie, rayons, espacements et textes sont définitifs. Les données des graphiques par appellation et par région sont **inventées** pour la maquette. En production, elles se calculent depuis la base.

## Contraintes à revérifier

- **C-01 (base inchangée).** Les évolutions ne doivent rien ajouter au schéma. Points à vérifier avant d'implémenter :
  - **image du domaine** (écran Nouveau domaine) : la maquette prévoit une zone d'image. S'il n'existe pas de colonne image sur `domains`, retirer cette zone ;
  - **descriptions** des appellations, domaines et cuvées : utiliser les colonnes existantes, sinon garder le champ en lecture seule ;
  - **région d'une appellation** : utiliser la colonne existante de `designations`.
- **C-02 (HTTP seulement).** Sur l'ordinateur, l'API `navigator.clipboard` n'est pas disponible. **« Copier le prompt » doit passer par un repli** : `textarea` hors écran, `select()`, puis `document.execCommand('copy')`. Garder `navigator.clipboard.writeText` quand `window.isSecureContext` est vrai, c'est-à-dire dans la WebView.
- Le site fonctionne sans Internet : blasons et images sont empaquetés.

---

## 1. Bouton assistant à double action

Présent dans l'en-tête des fiches du catalogue (appellation, domaine, cuvée) et dans les écrans de création.

**Ordinateur.** Bouton divisé, hauteur 34 :
- partie gauche (rayon 9 0 0 9, filet `--wt-line2`, fond `--wt-card`, padding 0 12, 13,5 px / 500) :
  - mode « ask » : icône étincelles 16 en `--wt-accent-ink`, « Demander à Claude » (ou « ChatGPT » selon le réglage Assistant IA), icône lien externe 13 en `--wt-ink3` ;
  - mode « copy » : icône copier 16, « Copier le prompt » ;
- partie droite : 28 × 34, rayon 0 9 9 0, chevron bas 14. Elle ouvre un menu.
- **Menu** : `role="menu"`, position absolue à 40 px sous le bouton, aligné à droite, largeur 270, rayon 10, ombre `--wt-shadow`, padding 4. Deux `menuitemradio` en grille `18px 1fr 16px` :
  - « Demander à Claude » / « Ouvre l'assistant avec la question » ;
  - « Copier le prompt » / « Met la question dans le presse-papiers ».
  - Le choix actif a un fond `--wt-accent-tint` et une coche.

**Téléphone.** Version compacte dans la barre du haut, à gauche de « Enregistrer » / « Créer » :
- libellés courts : « Claude » (ou « ChatGPT ») et « Prompt » ;
- hauteur 40, chevron de 36 × 40 ;
- le menu (largeur 280) est ancré sur le bord droit du **groupe formé par le bouton assistant et Enregistrer**, sinon il sort de l'écran ;
- `aria-label` complet sur le bouton (« Demander à Claude » / « Copier le prompt »).

**Comportement**
- Le mode choisi est mémorisé pour la session : `sessionStorage['wt-ai-action']` = `ask` | `copy`. Il est partagé entre toutes les fiches et les écrans de création.
- Prompt : `Présente {la cuvée | le domaine | l'appellation} « {nom} » en quelques phrases, pour une fiche de cave.`
- « ask » ouvre l'assistant dans un nouvel onglet avec le prompt dans l'URL. Toast « Claude s'ouvre dans un nouvel onglet ».
- « copy » copie le prompt (voir C-02). Toast « Prompt copié ».
- Si le nom est vide (en création), rien n'est envoyé. Toast ou erreur « Saisissez un nom pour interroger l'assistant ».

## 2. Suppression d'une fiche du catalogue

- **Bouton** : poubelle 34 × 34 en `--wt-danger` sur ordinateur, à droite du bouton assistant. Sur téléphone, bouton texte « Supprimer » en bas de fiche. Il est masqué en création.
- **Refus** si des bouteilles, **en stock ou consommées**, sont rattachées à la fiche (directement ou par une cuvée). Un bandeau `--wt-warn-tint` (rayon 9, padding 9 12) s'affiche sous l'en-tête : « Suppression impossible : des bouteilles en stock ou consommées sont associées à cette fiche. » [catDeleteRefused]
- **Confirmation** dans les autres cas :
  - ordinateur : fenêtre « Supprimer cette appellation ? » / « … ce domaine ? » / « … cette cuvée ? », avec le texte « « {nom} » sera retiré(e) du catalogue. Aucune bouteille, en stock ou consommée, n'y est associée. » et les boutons Annuler / Supprimer (`--wt-danger`) [catDeleteConfirm] ;
  - téléphone : feuille en bas d'écran, « Supprimer « {nom} » ? », boutons de 52 px.
- Après suppression : retour à la liste, toast « « {nom} » supprimé du catalogue ».

## 3. Complétion et création en cascade

### 3.1 Champ à complétion (composant `Autocomplete`)

Utilisé pour **Cuvée** (formulaire bouteille), **Domaine** et **Appellation** (fiche cuvée). Même composant partout.

- **Champ** : ordinateur hauteur 36, rayon 8, 14 px ; téléphone hauteur 52, rayon 14, 17 px. `role="combobox"`, `aria-expanded`.
- **Au focus**, la liste s'ouvre avec les 6 premières entrées. La saisie filtre sur le nom (sous-chaîne, sans tenir compte de la casse).
- **Liste** :
  - ordinateur : position absolue à 62 px du haut du champ, rayon 10, ombre `--wt-shadow` ;
  - téléphone : en flux, sous le champ ;
  - chaque option affiche le nom (partie trouvée en **600**) et une ligne secondaire en 12 px `--wt-ink2`, avec le blason de la région quand il existe ;
  - option active (survol ou flèches) en fond `--wt-accent-tint`.
- **Dernière ligne**, si aucune entrée ne porte exactement ce nom : « + Créer le domaine « {saisie} » » / « Créer l'appellation … » / « Créer la cuvée … », en 600 `--wt-accent-ink`.
- Champ vide sans résultat : « Saisissez le nom d'un domaine » (ou d'une appellation, d'une cuvée).
- **Clavier (ordinateur)** : ↑ ↓ déplacent l'option active, Entrée choisit l'option ou lance la création, Échap ferme la liste et rétablit la valeur.
- **Choix récent** : sous le champ, message en `--wt-ok` avec une coche, « Domaine créé à l'instant, rattaché à cette cuvée » (ou appellation, cuvée).

### 3.2 Création en cascade (pas de fenêtre modale)

Choisir « Créer … » **ouvre l'écran de création normal du catalogue**, le même que le bouton « Ajouter », avec le nom déjà rempli. Après la création, on revient à l'objet d'origine, avec le champ rempli.

Exemple complet, aussi présent dans la planche :
1. Ajout d'une bouteille, Cuvée « Les Fées » introuvable → « Créer la cuvée « Les Fées » » [flow1]
2. Écran Nouvelle cuvée, Domaine « Clos des F » introuvable → « Créer le domaine » [flow2]
3. Écran Nouveau domaine [flow3]. Erreur de doublon [flow3err]. Annulation [flow3cancel]
4. Retour à la cuvée, domaine rattaché, toast [flow4]
5. Écran Nouvelle appellation [flow5]
6. Retour à la cuvée, appellation rattachée [flow6]. Cuvée sans nom [flow6err]
7. Retour au formulaire bouteille, cuvée choisie, toast « Cuvée « Les Fées » créée » [flow7]

**Pile de retour.** Une pile de cadres `{ field, q, label, crumb, snapshot }` :
- `field` : le champ à remplir au retour (`cuv`, `dom`, `app`) ;
- `q` : le texte qui était tapé ;
- `label` : « la bouteille » / « la cuvée « Les Fées » » ;
- `crumb` : texte du fil d'Ariane ;
- `snapshot` : l'état complet du formulaire d'origine (cuvée en cours de saisie, domaine déjà choisi, n° de bouteille, tag…). **Ce brouillon doit survivre au détour** : le garder dans un store.

Comportement :
- **Lancer une création** : empiler un cadre, puis naviguer vers l'écran de création. Un seul niveau par objet, au maximum bouteille → cuvée → domaine ou appellation.
- **Bandeau** en haut de l'écran de création, quand la pile n'est pas vide : fond `--wt-accent-tint`, rayon 10 (14 sur téléphone).
  - Il affiche le fil d'Ariane, par exemple « Nouvelle bouteille › Nouvelle cuvée « Les Fées » › Nouveau domaine ». Le dernier élément est en 600 `--wt-ink`, les autres en `--wt-ink2`, avec des séparateurs « › » en `--wt-ink3`.
  - Sur ordinateur, il contient en plus un bouton « ← Revenir à {label} ».
- **Bouton principal** : « Créer et revenir à {label} ». Sans pile, depuis « Ajouter » : « Créer le domaine » / « Créer l'appellation » / « Créer la cuvée ».
  - Sur téléphone, il s'affiche en bas de fiche (hauteur min. 52, fond accent), avec « Revenir à {label} » en secondaire. La barre du haut montre « Créer ».
- **Valider** : contrôler le nom. Vide : « Le nom est obligatoire ». Doublon, sans tenir compte de la casse : « Ce domaine existe déjà » / « Cette appellation existe déjà ».
  - En cas d'erreur, le libellé et la bordure du champ Nom passent en `--wt-danger` (1,5 px) et le message s'affiche sous le champ avec une icône d'alerte.
  - Si le nom est valide : créer l'objet, dépiler, restaurer le snapshot, remplir `field` avec le nouvel objet, afficher le message vert sous le champ et un toast.
- **Annuler** (bouton, flèche retour sur téléphone) : dépiler et restaurer le snapshot. Le champ d'origine reprend le texte tapé (`q`), sans choix.
- Quitter par le menu latéral ou un clic dans la liste du catalogue **vide la pile**.

**Écran de création** (même mise en page que la fiche existante, en mode création) :
- titre « Nouveau domaine » / « Nouvelle appellation » / « Nouvelle cuvée » ; la ligne secondaire sous le titre est masquée ;
- Nom en champ de saisie ; pour l'appellation, Région en champ texte avec suggestions et le blason à gauche du texte (padding gauche 32 px quand un blason s'affiche) ;
- Description en zone de texte qui s'agrandit (§ 6) ;
- appellation : zone d'image « Carte de l'appellation » ; domaine : « Image du domaine » (voir C-01) ;
- masqués en création : bouton Supprimer, carte de stock du domaine, listes « Cuvées de cette appellation » et « Cuvées du domaine ». Sans la carte de stock, le formulaire du domaine prend toute la largeur (colonne `minmax(0,1fr)`, au lieu de `minmax(0,1fr) 220px`).

## 4. Blasons de région

- 14 SVG dans `maquettes/blasons/` : alsace, beaujolais, bordeaux, bourgogne, champagne, corse, jura, languedoc, loire, provence, rhone, roussillon, savoie, sud-ouest.
- **Correspondance en dur** : nom de région → minuscules, sans accents, espaces remplacés par des tirets. « Rhône » donne `rhone`, « Sud-Ouest » donne `sud-ouest`. Une région absente de la liste s'affiche **sans icône**. Voir `blason()` dans `winetap-data.js`.
- Le blason se place **à gauche** du nom de la région, avec un écart de 5 à 8 px. Tailles :
  - 15 × 18 : tableau de l'inventaire, champ Région ;
  - 13 × 16 : fiche bouteille, carte stock ;
  - 11–12 × 13–15 : lignes secondaires, options de complétion, dégustations.
- **Où** : colonne Région de l'inventaire (stock et consommées) ; fiche bouteille (ligne Région, sous-titre, encart Appellation) ; liste et fiche des appellations ; options de complétion d'appellation ; tableau de bord (stock et historiques en mode Région) ; dégustations.

## 5. Cartes d'appellation

- **Fiche appellation** : zone d'image de 300 × 300 sur ordinateur, ou 100 % × 260 sur téléphone. Rayon 12 (16), fond `--wt-paper`, `object-fit: contain`. Elle accepte le dépôt, le collage (Ctrl+V) et « Choisir un fichier / Retirer ». Texte d'aide : « Une carte qui situe l'appellation dans sa région. PNG ou JPEG. » Sur téléphone, la carte se place **après la description**.
- **Fiche bouteille, encart Appellation** : miniature de 132 × 96 sur ordinateur, ou 100 % × 140 sur téléphone, en `object-fit: cover`, avec une icône d'agrandissement de 24 px (32 sur téléphone) en bas à droite, sur un fond blanc à 92 %. Au survol, curseur `zoom-in` et bordure accent.
- **Vue agrandie** [mapZoom] :
  - ordinateur : voile `rgba(42,29,21,0.72)`, image jusqu'à 640 px de large (rayon 12, ombre forte), titre « {appellation} · {région} » en blanc au-dessus, bouton × ;
  - téléphone : plein écran sur fond `#1C1410`.
  - Fermeture : ×, clic sur le voile ou Échap. Échap ferme d'abord la carte, avant la fiche bouteille.
- `maquettes/cartes/*.svg` sont des **pseudo-cartes de test**. Ne pas les livrer.

## 6. Descriptions

Pour les appellations, domaines et cuvées, la description est une `textarea` éditable qui **montre toujours tout le texte, sans barre de défilement** :
- hauteur minimale 120 px sur ordinateur, 110 px sur téléphone, `resize: none`, `overflow: hidden` ;
- hauteur automatique : `field-sizing: content` dans Chromium. Firefox et Safari ne le gèrent pas : ajouter une action Svelte qui recalcule `height = scrollHeight` à chaque saisie.

## 7. Filtres de l'inventaire (ordinateur)

**Recherche globale** : champ de 260 × 34 dans la barre d'outils.
- Elle cherche dans la cuvée, le domaine, l'appellation, la région, le millésime et l'UID du tag, sans tenir compte des accents ni de la casse.
- La touche `/` place le curseur dans le champ, Échap le vide.

**Ligne de filtres** sous l'en-tête du tableau (hauteur 34, contrôles de 24 px, rayon 6, 12 px) :

| Colonne | Contrôle |
|---|---|
| Couleur | liste à **sélection multiple** |
| Cuvée, Domaine, Appellation | champ texte, recherche par sous-chaîne |
| Région | liste à **sélection multiple** |
| Millésime | champ texte |
| À boire avant | liste : Toutes dates / Dépassée / Cette année / À venir / Sans date |

- **Logique** : ET entre colonnes, OU à l'intérieur d'une sélection multiple.
- Un filtre actif a une bordure `--wt-accent` et un fond `--wt-accent-tint`.
- **Sélection multiple** :
  - **Bouton** : libellé « Toutes » sans sélection, le nom de l'option si une seule est cochée, sinon « 3 régions » / « 2 couleurs ».
  - **Panneau** : `role="listbox"`, `aria-multiselectable`, position absolue à 28 px, largeur min. 210, hauteur max. 320, rayon 10.
  - **Options** : chaque option fait 32 px de haut. Elle montre une case de 16 px (rayon 4 ; cochée en fond accent, coche blanche), le verre (couleur) ou le blason (région), le libellé et le nombre de bouteilles en `--wt-ink3`.
  - **Pied du panneau** : « Tout effacer » et « OK ».
  - **Fermeture** : clic à côté ou Échap.
- **Réinitialiser** : quand un filtre est actif, l'icône entonnoir en tête de ligne devient un bouton × (24 × 24, fond accent-tint), « Effacer les filtres ».
- **Compteur** : « {n} bouteilles · {m} lignes sur 182 ». Sans résultat : « Aucune bouteille ne correspond » avec le bouton « Effacer les filtres ».
- Les filtres s'appliquent aussi aux bouteilles consommées quand elles sont affichées.
- Le tableau de bord ouvre l'inventaire filtré (§ 8).

**Colonne « À boire avant »** : l'année seule, en 600, sur fond coloré (rayon 6, padding 1 7). Fond `--wt-danger-tint` / texte `--wt-danger` si la date est dépassée, `--wt-warn-tint` / `--wt-warn` si c'est cette année, transparent sinon. **Pas de texte** « dépassée » ou « cette année » dans la cellule, seulement en `title`. Largeur de colonne **104 px**.

Grille des colonnes : `32px 112px minmax(130px,1.3fr) minmax(140px,1.4fr) minmax(130px,1.2fr) 112px 68px 104px 44px 96px`, plus `92px` quand les consommées sont affichées. Largeur min. 900 px (992 px avec les consommées).

## 8. Tableau de bord

### 8.1 Carte « Stock » (remplace « Par couleur » et « Par région »)

- **Ordinateur** : la carte occupe les deux colonnes à droite de la colonne d'alertes (`grid-column: span 2`). Donut de 190 px (trou de 116, total en Newsreader 30 et « bouteilles » en 12 px) à gauche, tableau à droite (largeur min. 280).
- **Téléphone** : donut de 200 px (trou de 124) centré, tableau en dessous.
- **Sélecteur** en haut à droite : « Couleur / Appellation / Région ». Groupe `radiogroup`, fond `--wt-card2`, padding 2. Boutons de 26 px (36 sur téléphone), 12,5 px / 600. Bouton actif en fond `--wt-card`, avec l'ombre `0 1px 2px rgba(42,29,21,0.14)`.
- **Donut** : `conic-gradient` avec un écart de 0,4 % (couleur `--wt-card`) entre les parts.
- **Couleurs des parts** :
  - couleur : teinte du vin (`--wt-line2` pour « inconnue ») ;
  - appellation ou région : `#6E1A2B #B5762A #E3C04F #7C8B5C #5E7F95 #9B6A8E #C98B6B`, puis `#CDBFA6` pour « Autres ».
- **Contenu** : couleur, les 7 premières appellations + « Autres appellations », ou les 7 premières régions + « Autres ».
- **Tableau** (même modèle qu'en § 8.3), colonnes {Couleur | Appellation | Région} · Bouteilles · Part.
  - Chaque ligne est un bouton qui ouvre l'inventaire filtré sur la couleur, l'appellation ou la région.
  - « Autres » ouvre l'inventaire sans filtre.
  - Sur téléphone, seul le filtre par couleur existe ; les autres lignes ouvrent l'inventaire complet.

### 8.2 Historiques « Consommations » et « Achats »

- Même sélecteur Couleur / Appellation / Région en haut à droite de chaque carte. **Chaque carte garde son choix.**
- Barres empilées par mois : sur 12 mois, découpées par couleur, ou par les 5 premières appellations ou régions de la période + « Autres … ».
- **Légende en tableau** dans les trois modes, sous le graphique. Colonnes : {Couleur | Appellation | Région} · Total · Moy./mois · Max.
  - Total : somme sur 12 mois ;
  - Moy./mois : Total ÷ 12, une décimale, virgule française ;
  - Max : le mois le plus haut.

### 8.3 Modèle de tableau de légende (commun)

- Filet en haut. En-tête de 28 px, 11,5 px / 600 (12 sur téléphone), couleur `--wt-ink3`, filet en bas.
- Lignes de 28 à 30 px (34 à 44 sur téléphone), filet en bas, 12,5–13 px, couleur `--wt-ink2`.
- Première cellule en `--wt-ink` : pastille de 10 × 10 (rayon 3), puis le verre de 16 en mode Couleur ou le blason de 12 × 15 en mode Région, puis le libellé, coupé avec des points de suspension si trop long.
- Colonnes chiffrées alignées à droite, en chiffres tabulaires. La première colonne chiffrée est en 600 `--wt-ink`.
- **Grilles** :
  - stock : `minmax(0,1fr) 84px 64px` (téléphone : `56px 60px`) ;
  - historiques : `minmax(0,1fr) 60px 72px 48px` (téléphone : `44px 64px 36px`).

## 9. Dégustations

Dans la liste des dégustations (ordinateur et téléphone, y compris sur la fiche bouteille), ajouter après « {appellation} · {millésime} » : « · [blason] {région} ». La région se déduit de l'appellation.

## 10. Autres ajustements

- **E-03 (fiche après identification, téléphone)** : elle reprend les informations du détail E-04, avec trois blocs sous le tableau d'informations, séparés par des filets :
  - « Cuvée » : nom et description ;
  - « Domaine » : nom et description ;
  - « Appellation » : la carte agrandissable, le nom, le blason, la région et la description.
  - Le tableau d'informations, avec le tag, est conservé.
- **Fiches du catalogue** : Nom (et Région pour les appellations) deviennent éditables sur les fiches existantes.
- **Formulaire bouteille** : sous le champ Cuvée, une ligne d'information sur fond `--wt-paper` affiche « {couleur} · {domaine} · {appellation} ({région}) » pour la cuvée choisie.

---

## État à prévoir (stores Svelte)

- `aiMode` : `'ask' | 'copy'`, lu et écrit dans `sessionStorage['wt-ai-action']`.
- `createStack` : la pile de cadres du § 3.2 et le brouillon de chaque formulaire d'origine.
- `inventoryFilters` : `{ q, color: string[], cuvee, domaine, appellation, region: string[], vintage, garde }`. À conserver quand on passe du tableau de bord à l'inventaire.
- `dashboard` : `stockBy`, et `histBy` par carte (`{ conso, achats }`), chacun valant `'color' | 'app' | 'region'`.
- `mapZoom` : booléen sur la fiche bouteille.

## API utile (à ajouter si absente, sans toucher au schéma)

- Comptage des bouteilles rattachées (stock et consommées) à une appellation, un domaine ou une cuvée, pour refuser la suppression.
- Agrégats du stock par couleur, appellation et région.
- Historique mensuel sur 12 mois des consommations (`consumed_at`) et des achats (`added_at`), par couleur, appellation et région.

## Fichiers des maquettes

- `maquettes/WineTap Planche.dc.html` : tous les états, à ouvrir en premier.
- `maquettes/WineTap-Ordinateur.dc.html` et `maquettes/WineTap-Telephone.dc.html` : prototypes. La logique (pile de retour, filtres, graphiques) est dans la classe `Component`, en bas de chaque fichier.
- `maquettes/winetap-data.js` : `blason()`, `carte()`, `stock(by)`, `hist(kind, h, narrow, by)` et les données d'exemple.
- `maquettes/blasons/` : **à livrer**. `maquettes/cartes/` : test uniquement.
