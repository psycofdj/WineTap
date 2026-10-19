Je refonds WineTap, une application de gestion de cave à vin personnelle. La spécification
jointe (v3-web.md) décrit le projet ; les sections 6 (fonctions) et 7 (écrans et charte) sont
celles qui comptent pour toi. Je te demande la charte graphique et les maquettes de tous les
écrans.

## Le produit en bref

- Chaque bouteille de la cave porte un tag NFC. On l'enregistre en stock avec son tag ; quand on
  la boit, on scanne le tag avec le téléphone et elle sort du stock.
- Tout tient dans le téléphone : une application mobile qui affiche un site web (WebView) et lit
  les tags NFC. Le même site s'ouvre aussi dans le navigateur d'un ordinateur, pour saisir plus
  confortablement.
- Le téléphone seul doit suffire à tout faire, facilement. L'ordinateur est un confort.
- Public : un amateur, quelques centaines de bouteilles, vins français. Interface en français.

## Ce que j'attends

1. **Une charte graphique créée de zéro** : couleurs, typographie, composants (boutons, champs,
   tables, cartes, badges, onglets, navigation), thème clair et thème sombre. Je ne suis pas
   graphiste : propose une identité complète et cohérente. Ton recherché : un carnet de cave
   soigné, chaleureux et précis, pas un logiciel de gestion d'entrepôt.
2. **Les maquettes de tous les écrans** listés au §7.1 de la spécification, dans leurs formats :
   - **téléphone**, en portrait : grandes cibles tactiles, usage d'une main, peu de texte par
     écran. On y parcourt aussi l'inventaire tranquillement, en choisissant son vin avant de
     descendre à la cave ;
   - **ordinateur**, fenêtre large : écrans denses, tables longues, filtres, formulaires utilisables
     au clavier.
   Les écrans marqués « Les deux » sont à faire dans les deux formats.
3. **Les écrans natifs** (N-E1 à N-E4) avec la même identité que le site : on ne doit pas voir le
   passage du site à un écran natif.

## Repères visuels à prévoir

- **Couleur des vins** : rouge, blanc, rosé, effervescent, autre, inconnue. Chacune a une couleur
  de repère, utilisée dans les tables, les fiches et les graphiques, et distinguable par une
  personne daltonienne (la couleur ne doit jamais être le seul indice).
- **Date de garde** (« à boire avant ») : dépassée, dans l'année en cours, ou sans souci.
- **États d'une bouteille** : en stock, consommée.
- **Lecture NFC** : en attente du tag, tag lu, tag inconnu, bouteille déjà consommée, lecture
  annulée.
- **Connexion** (sur ordinateur) : téléphone joignable, téléphone injoignable, en attente
  d'autorisation.
- Accessibilité : contrastes au niveau AA du WCAG.

## Navigation

Propose la navigation qui te semble la meilleure pour chaque format. Pour t'orienter, les
rubriques sont :
- **Cave** : accueil (téléphone), tableau de bord, inventaire, historique des dégustations ;
- **Catalogue** : appellations, domaines, cuvées ;
- **Paramètres** : assistant IA, sauvegarde et restauration.
Sur le téléphone, « Consommer une bouteille » est le geste le plus fréquent : il doit être
accessible immédiatement depuis l'accueil.

## Le geste NFC sur le téléphone

Sur le site, dans l'application, l'utilisateur appuie par exemple sur « Consommer une bouteille ».
Le téléphone passe alors en plein écran sur l'écran natif de lecture NFC (N-E4) : « Présentez le
tag », avec l'objet de la lecture et un bouton Annuler. Une fois le tag lu, on revient au site,
qui montre le résultat : la bouteille consommée, avec la possibilité d'ajouter un commentaire de
dégustation. Le même écran natif sert à identifier une bouteille, à associer un tag lors de
l'entrée en stock, à rechercher une bouteille par son tag, et quand c'est un ordinateur qui
demande la lecture (il l'indique alors).

## Contenu des écrans

- **Bouteille** : cuvée (avec son domaine et son appellation), couleur, millésime, prix d'achat
  (facultatif, en euros), « à boire avant » (une année, facultative), commentaire, identifiant du
  tag (par exemple `04A32BFF`), date d'entrée, date de consommation.
- **Cuvée** : nom, domaine, appellation, couleur, description.
- **Appellation** : nom, région, description, image (choisie dans un fichier ou collée).
- **Domaine** : nom, description.
- **Inventaire sur ordinateur** : table avec les colonnes couleur, cuvée, domaine, appellation,
  région, millésime, à boire avant, quantité (en vue regroupée), date d'entrée, date de
  consommation ; tri et filtre sur chaque colonne ; regroupement des bouteilles identiques ;
  case « afficher les bouteilles consommées » ; actions ajouter, ajouter sur le modèle de la
  sélection, modifier, supprimer, consommer, rechercher par tag, imprimer.
- **Entrée en stock** : formulaire de bouteille avec la complétion des noms, la création d'une
  cuvée à la volée, l'attente du tag, et « Enregistrer et continuer » pour entrer une caisse
  entière (une bouteille, un tag, puis la suivante).
- **Formulaires du catalogue** : un bouton « Demander à l'IA » ouvre ChatGPT ou Claude dans un
  nouvel onglet, avec une question préparée sur le vin ou le domaine.
- **Tableau de bord** : nombre total de bouteilles en stock, répartition par couleur et par
  région ; un clic sur une part ouvre l'inventaire filtré.
- **Historique des dégustations** : bouteilles consommées, de la plus récente à la plus
  ancienne, avec leur commentaire modifiable.
- **Paramètres** : choix de l'assistant IA (ChatGPT ou Claude), sauvegarde (téléchargement du
  fichier de la base), restauration (envoi d'un fichier, avec confirmation, car elle remplace
  toute la cave).
- **Écrans natifs** : l'adresse à saisir dans le navigateur de l'ordinateur, en très grand
  (`http://192.168.1.42:8080`) ; la demande d'autorisation d'un ordinateur (navigateur, système,
  adresse IP, Autoriser / Refuser) ; la liste des ordinateurs autorisés, avec révocation ; la
  lecture NFC.

## Données d'exemple

Utilise des données réalistes, une cave d'environ 180 bouteilles en stock, par exemple :
- Château Margaux, Grand Vin, Margaux (Bordeaux), rouge, 2015, 650 €, à boire avant 2045 ;
- Domaine Leflaive, Les Pucelles, Puligny-Montrachet (Bourgogne), blanc, 2019, 4 bouteilles ;
- Domaine Tempier, Bandol rosé (Provence), 2023, à boire avant 2025 (date dépassée) ;
- Bollinger, Special Cuvée, Champagne, effervescent, sans millésime ;
- Domaine Huet, Le Haut-Lieu sec, Vouvray (Loire), blanc, 2020 ;
- E. Guigal, La Mouline, Côte-Rôtie (Rhône), rouge, 2017, à boire avant 2026 (cette année) ;
- Domaine Weinbach, Riesling Schlossberg, Alsace Grand Cru (Alsace), blanc, 2021.
Dégustations récentes : « Superbe, encore jeune, à carafer 2 h », « Un peu fatigué, à boire
vite ».

## Contraintes à respecter

- Pas de caméra, pas d'appareil photo : le site ne s'en sert pas.
- Pas de fonction en plus de celles de la spécification.
- Les fonctions de lecture de tag (consommer, identifier) n'existent que sur le téléphone ; sur
  ordinateur, la lecture se fait en demandant au téléphone de scanner.
