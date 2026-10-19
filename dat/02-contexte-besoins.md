# 2. Contexte et besoins

<!-- toc -->

**Sur cette page**

- [2.1 Service rendu](#21-service-rendu)
- [2.2 Utilisateurs](#22-utilisateurs)
- [2.3 Volumétrie](#23-volumétrie)
- [2.4 Exigences et contraintes](#24-exigences-et-contraintes)

<!-- /toc -->

## 2.1 Service rendu

WineTap tient l'inventaire d'une cave à vin personnelle, bouteille par bouteille. Il permet :

- de **décrire le catalogue** : appellations, domaines, cuvées, avec description et, pour une
  appellation, une carte qui la situe ;
- d'**enregistrer chaque bouteille** à son entrée en cave, avec son millésime, son prix d'achat et
  la date avant laquelle la boire, et de lui associer un tag NFC ;
- de **consommer une bouteille** d'un geste : on appuie sur « Consommer », on approche le
  téléphone du tag, la bouteille sort du stock et le tag est libéré pour une autre bouteille ;
- de **parcourir la cave** sur le téléphone comme sur un ordinateur : tri, filtres,
  regroupements, alertes de date de garde, impression, tableau de bord par couleur et par région ;
- de **garder l'historique des dégustations**, avec un commentaire par bouteille consommée.

Le principe tient en trois points :

1. **Le téléphone est le serveur.** Il porte la seule base de données, lit les tags et sert un site
   web et son API sur le port 8080.
2. **Le site est l'interface.** Le même site s'affiche dans l'application et dans le navigateur
   d'un ordinateur du même réseau ; l'application n'ajoute que ce qui est propre au téléphone :
   lecture NFC, sélecteurs de fichiers, autorisation des ordinateurs.
3. **Le téléphone suffit.** Toutes les fonctions marchent sans ordinateur et sans Wi-Fi : la
   WebView parle au serveur par `localhost`.

## 2.2 Utilisateurs

| Population | Usage | Accès |
|---|---|---|
| Propriétaire de la cave | Toutes les opérations : catalogue, entrée en stock, consommation, sauvegarde, autorisation des ordinateurs | L'application sur son téléphone ; le navigateur de son ordinateur, une fois autorisé sur le téléphone. Aucun compte, aucun mot de passe |
| Proches qui partagent le téléphone | Consommer ou identifier une bouteille, parcourir la cave | Le téléphone, application ouverte |
| Navigateur d'un ordinateur autorisé | Toutes les fonctions, sauf consommer et identifier par le tag, réservées à l'application | Session autorisée sur le téléphone, sans expiration, révocable ([§9.2](09-securite.md#92-autorisation-des-navigateurs)) |
| Tout autre appareil du même réseau | Aucun | Il peut demander une autorisation ; sans elle, l'API lui répond 401 |

WineTap est mono-utilisateur par construction : une cave, un téléphone, une base. Plusieurs
navigateurs peuvent être ouverts en même temps : le canal d'événements les tient à jour des
modifications des autres ([§5.5](05-site-web.md#55-état-et-événements)).

## 2.3 Volumétrie

Le système vise une cave personnelle : quelques centaines de bouteilles. Les ordres de grandeur
connus viennent du code et des jeux d'essai :

| Indicateur | Valeur |
|---|---|
| Appellations livrées dans une base neuve | 320, plus l'appellation sentinelle « (unassigned) » ([§8.7](08-donnees.md#87-données-de-référence-et-jeux-dessai)) |
| Domaines livrés dans une base neuve | 128 |
| Jeu d'essai des versions de développement | Une vingtaine de cuvées, 62 bouteilles |
| Jeu d'essai de l'API simulée du site | Environ 180 bouteilles |
| Taille maximale d'une restauration | 100 Mo ; 32 Mo pour un corps JSON |
| Page de l'historique des dégustations | 20 bouteilles |
| Test de performance de la sauvegarde | 500 bouteilles en moins de 10 secondes |

Le site charge au démarrage le catalogue complet et toutes les bouteilles en stock, puis les
recharge à chaque événement de modification ; les listes de l'API ne sont pas paginées, sauf
l'historique des dégustations.

## 2.4 Exigences et contraintes

| Exigence ou contrainte | Ce qu'elle impose | Réponse du système |
|---|---|---|
| **Aucun service en ligne, aucun compte** | Les données ne quittent pas le réseau local | Base sur le téléphone, site servi par le téléphone, pas de serveur central ([§3.1](03-vue-ensemble.md#31-schéma-général)) |
| **Pas de matériel dédié** | Ni Raspberry Pi, ni serveur allumé en permanence | Le téléphone, qui a déjà le NFC, porte la base et le serveur ([D-01](12-decisions-architecture.md#d-01--le-téléphone-est-le-serveur)) |
| **Rien à installer sur l'ordinateur** | Le manager de bureau demandait un binaire par système | Le site s'ouvre dans n'importe quel navigateur récent ([D-17](12-decisions-architecture.md#d-17--un-site-embarqué-pour-le-téléphone-et-lordinateur)) |
| **Tout faire depuis le téléphone** | La v2 réservait le catalogue et l'entrée en stock au manager | Le site a un format téléphone complet ([§5.3](05-site-web.md#53-écrans)) |
| **Base inchangée** | Les fichiers de la v2 et de la v3 doivent s'ouvrir dans les deux versions | Schéma version 2 conservé ; sessions et réglages rangés hors de la base ([D-21](12-decisions-architecture.md#d-21--schéma-inchangé-état-de-la-v3-hors-de-la-base)) |
| **Seul le propriétaire accède à la cave** | Le site est servi sur le réseau local | Autorisation de chaque navigateur sur le téléphone ([D-18](12-decisions-architecture.md#d-18--autorisation-des-navigateurs-sur-le-téléphone)) |
| **Connexion simple** | Pas de configuration réseau | Le téléphone affiche l'adresse à saisir ; le navigateur la garde ([D-05](12-decisions-architecture.md#d-05--adresse-affichée-par-le-téléphone)) |
| **Android et iOS** | Une seule base de code mobile, NFC sur les deux | Flutter et `nfc_manager`, implémentation NFC propre à chaque système ([§4.4](04-application-mobile.md#44-lecture-nfc)) |
| **Hors ligne** | Pas d'accès à Internet nécessaire | Polices et icônes du site empaquetées ; aucun appel externe ([§5.1](05-site-web.md#51-construction)) |
| **Résilience des données** | Le téléphone peut être perdu ou cassé | Sauvegarde et restauration du fichier de base, depuis le téléphone ou un ordinateur ([§11.4](11-exploitation-continuite.md#114-sauvegarde-et-restauration)) |
| **Exploitation par une seule personne** | Pas d'administration à faire | Tout est publié par la CI sur étiquette ; aucune infrastructure à tenir |
| **Interface en français** | Caves françaises, appellations françaises | Chaînes en français dans le site et les écrans natifs ([D-14](12-decisions-architecture.md#d-14--interface-en-français)) |
