# 13. Risques

<!-- toc -->

**Sur cette page**

- [13.1 Risques à traiter](#131-risques-à-traiter)
  - [Sécurité](#sécurité)
  - [Données et continuité](#données-et-continuité)
  - [Fonctionnement](#fonctionnement)
  - [Livraison et maintenabilité](#livraison-et-maintenabilité)
- [13.2 Risques acceptés](#132-risques-acceptés)
- [13.3 Risques levés par la v3](#133-risques-levés-par-la-v3)

<!-- /toc -->

Gravité : 🔴 Critique · 🟠 Majeure · 🟡 Mineure · 🔵 Amélioration.

Les risques sont constatés dans le code au 2026-10-18 (branche `v3`, arbre de travail). Sauf
mention « déduit, non éprouvé », chacun se lit directement dans le code. La colonne « Suivi »
indique la décision qui couvre le risque, ou « À arbitrer » quand aucune n'est prise. Les risques
de la v1 du DAT qui ont disparu avec la v3 sont listés au [§13.3](#133-risques-levés-par-la-v3).

## 13.1 Risques à traiter

### Sécurité

| ID | Gravité | Risque | Action | Suivi |
|---|---|---|---|---|
| R-01 | 🟡 | **Une session autorisée a tous les droits, sans limite de durée.** Elle peut lire, modifier, télécharger ou remplacer toute la cave ([§9.1](09-securite.md#91-modèle-de-confiance)). Elle n'expire pas, et rien ne signale sur le téléphone l'activité d'une session, sauf la pastille « active » de N-E3. Un ordinateur partagé ou perdu garde l'accès tant que la session n'est pas révoquée et que le navigateur garde son cookie. | Rappel des sessions inactives depuis longtemps dans N-E3 ; à défaut, expiration après une longue inactivité | Accepté par la spécification v3 ([D-18](12-decisions-architecture.md#d-18--autorisation-des-navigateurs-sur-le-téléphone)) ; à confirmer |
| R-02 | 🟡 | **Le mot de passe maître du coffre KeePassXC peut rester en clair sur le disque.** `scripts/build_packages.sh`, qui ne sert plus à publier (la CI publie), l'écrit dans `~/winetap-build/key`, et y exporte la clé de téléversement Android, puis efface ce dossier **à la dernière ligne seulement**. Le script s'arrêtant à la première erreur (`set -e`), un échec de la construction du site, de Flutter ou de `keepassxc.cli` laisse le mot de passe maître et la clé de signature dans ce dossier. | Supprimer le script, inutile depuis la publication par la CI ; à défaut, dossier créé par `mktemp -d`, effacé par un `trap … EXIT`, et mot de passe passé à `keepassxc.cli` par l'entrée standard | À arbitrer |
| R-05 | 🔵 | **Tout appareil du réseau peut encore présenter une demande d'autorisation.** Les demandes sont limitées (une en attente par adresse IP, trois en tout, deux minutes après un refus, expiration après cinq minutes : [§9.2](09-securite.md#92-autorisation-des-navigateurs)), mais un appareil peut toujours faire apparaître une feuille N-E2 toutes les deux minutes, avec un navigateur et un système qu'il choisit (en-tête `User-Agent`) ; seule l'adresse IP affichée est fiable. Les canaux d'événements des navigateurs non autorisés ne sont pas limités en nombre. | Rappeler sur N-E2 de vérifier l'adresse IP ; limiter les flux d'événements non autorisés | Réduit le 2026-10-18 ; reste à arbitrer |
| R-06 | 🟡 | **Le cookie de session passe en clair sur le Wi-Fi.** Faute de HTTPS ([D-04](12-decisions-architecture.md#d-04--pas-de-chiffrement-sur-le-réseau-local)), un appareil qui peut lire le trafic du réseau (réseau ouvert, point d'accès d'un tiers, poste compromis) peut recopier le cookie `wt_session` d'un navigateur autorisé et obtenir les mêmes droits, sans limite de durée (R-01). Sur un Wi-Fi domestique chiffré (WPA2, WPA3), la lecture du trafic d'un autre client demande déjà une attaque active. | Lier la session à l'adresse IP ou au moins la signaler dans N-E3 quand elle change ; à terme, HTTPS | Accepté par la spécification v3 ; à confirmer |
| R-03 | 🔵 | **La restauration ne garde aucune copie de la base remplacée.** Le fichier est examiné (tables, version), mais le `.bak` est effacé dès le remplacement : restaurer par erreur une sauvegarde ancienne, depuis le téléphone ou un ordinateur autorisé, perd tout ce qui a changé depuis. Le site affiche une confirmation avec les deux nombres de bouteilles. | Garder la base précédente (copie datée) jusqu'à la restauration suivante | À arbitrer |

### Données et continuité

| ID | Gravité | Risque | Action | Suivi |
|---|---|---|---|---|
| R-10 | 🟠 | **Une seule copie des données, sauvegardée à la main.** Toute la cave est sur le téléphone ; aucune sauvegarde n'est planifiée et rien ne rappelle d'en faire une. La perte, le vol ou la casse du téléphone perdent tout ce qui a changé depuis la dernière sauvegarde, sauf si la sauvegarde du système (Google, iCloud) est active, ce que l'application ne contrôle ni ne vérifie. | Rappel de sauvegarde ; sauvegarde proposée par le site sur l'ordinateur à intervalle régulier | Écarté de la v3 par la spécification (pas de fonction nouvelle) ; à arbitrer ensuite |
| R-11 | 🟡 | **Les exclusions de la sauvegarde Android ne visent pas le bon dossier** (déduit, non éprouvé). Les règles excluent `winetap.sqlite-wal` et `-shm` des domaines `database` et `file`, mais la base est dans le dossier `app_flutter`, du domaine `root`. La sauvegarde du système peut donc copier la base et son journal dans un état incohérent. | Règles sur le domaine `root` (`app_flutter/…`), à vérifier par une sauvegarde et une restauration réelles (`adb shell bmgr`) | À arbitrer |
| R-12 | 🟡 | **Une consommation ne peut pas être annulée.** Lire un tag consomme sans confirmation ([D-10](12-decisions-architecture.md#d-10--consommation-sans-confirmation)) et efface le tag ; le bouton de l'inventaire consomme aussi sans confirmation ; aucune route ni aucun écran ne remet `consumed_at` à vide. Après une erreur, il faut recréer la bouteille, avec une nouvelle date d'entrée. | Action « Annuler » quelques secondes après la consommation, ou remise en stock depuis l'historique | Écarté de la v3 par la spécification ; à arbitrer ensuite |
| R-13 | 🔵 | **Sauvegarde et restauration ne sont pas sérialisées.** Une sauvegarde demandée par un navigateur pendant une restauration lancée par un autre peut lire une base fermée ou en cours de remplacement. | Verrou autour de la sauvegarde et de la restauration | À arbitrer |
| R-14 | 🔵 | **Le jeu d'essai dépend du seul numéro de version.** Une version qui contient `0.0.0` est traitée comme une version de développement : sur une base sans bouteille, l'application charge 62 bouteilles fictives au démarrage. Les publications, faites par la CI, fixent la version depuis l'étiquette et n'y sont pas exposées ; une construction de `release` qui ne fixe pas de version (`scripts/build_packages.sh` produit `0.0.0-<commit>-dev`) le serait. Le commentaire du code annonce un test sur `+dev`, qui n'est pas celui appliqué. | Conditionner aussi au mode débogage (`kDebugMode`) | À arbitrer |

### Fonctionnement

| ID | Gravité | Risque | Action | Suivi |
|---|---|---|---|---|
| R-25 | 🟡 | **Aucun essai sur un vrai téléphone n'a été fait pour la v3** au 2026-10-18 : lecture NFC par le pont et à distance, WebView, sélecteurs de fichiers, autorisation d'un ordinateur sur un vrai réseau, permission de réseau local d'iOS. Les tests automatiques simulent le NFC et la WebView. | Recette sur un téléphone Android et un iPhone avant publication | À traiter |
| R-21 | 🔵 | **L'écran du téléphone peut s'éteindre pendant une pause sur l'ordinateur.** Il reste allumé 5 minutes après la dernière requête ; ensuite, sur iOS en particulier, le verrouillage suspend l'application et l'ordinateur affiche « Téléphone injoignable ». | Garder l'écran allumé tant qu'un navigateur autorisé a un canal d'événements ouvert, avec un délai plus long | À arbitrer |
| R-22 | 🔵 | Les listes ne sont pas paginées : le site charge toutes les bouteilles en stock au démarrage, et les recharge à chaque événement `donnees`, sur chaque écran ouvert. Sans effet à quelques centaines de bouteilles. | Événements plus fins (bouteille modifiée) ou pagination si la cave grossit | À arbitrer |
| R-23 | 🔵 | **Le choix d'un fichier dans l'application passe en base64 par la WebView.** `pickFile` rend le fichier entier encodé dans un appel JavaScript ; une sauvegarde de plusieurs dizaines de mégaoctets (images d'appellations) peut ralentir ou faire échouer la WebView (déduit, non éprouvé). | Envoyer le fichier au serveur côté natif et ne rendre au site qu'un identifiant | À arbitrer |

### Livraison et maintenabilité

| ID | Gravité | Risque | Action | Suivi |
|---|---|---|---|---|
| R-31 | 🔵 | **Constructions non entièrement reproductibles.** La publication prend la dernière version de Flutter (canal `stable`) et les actions par version majeure. Les dépendances npm sont fixées par `package-lock.json` ; Dependabot ne suit ni Gradle ni CocoaPods. | Épingler la version de Flutter ; ajouter `gradle` à Dependabot | À arbitrer |
| R-33 | 🔵 | **Le contrat d'API n'est vérifié par aucun test commun en CI.** Le site est développé contre son serveur simulé, l'application est testée contre elle-même ; l'essai de bout en bout contre le serveur réel est manuel. Un écart entre `mock/` et le serveur Dart peut passer la CI. | Lancer en CI le parcours de bout en bout du site contre le serveur réel | À arbitrer |
| R-35 | 🔵 | **Restes et imprécisions** : fonctions de complétion de la base sans route ni appel hors des tests ; statut `erreur` de l'événement `scan` jamais émis ; unité de `purchase_price` non définie ; commentaire de `dev_seed.dart` en désaccord avec le code (R-14). | Nettoyage | À arbitrer |

## 13.2 Risques acceptés

| ID | Sujet | Décision | Justification |
|---|---|---|---|
| R-50 | Le serveur n'existe que lorsque l'application est ouverte au premier plan : téléphone en veille ou application en arrière-plan, l'ordinateur ne fonctionne pas | Accepté le 2026-04-01, reconduit le 2026-10-18 ([D-07](12-decisions-architecture.md#d-07--application-au-premier-plan-écran-maintenu-allumé-pendant-lactivité)) | iOS ne permet pas de serveur en arrière-plan ; l'usage dans l'application n'en dépend pas. |
| R-51 | Le site ne fonctionne pas sans le téléphone ; deux modifications simultanées de la même fiche : la dernière l'emporte | Accepté ([D-03](12-decisions-architecture.md#d-03--une-seule-base-sur-le-téléphone-sans-synchronisation)) | Pas de synchronisation, donc pas de conflit à résoudre ; usage mono-utilisateur ; les autres écrans sont prévenus par les événements. |
| R-52 | La question préparée par « Demander à l'IA » (nom de l'appellation, du domaine ou de la cuvée) est envoyée à OpenAI ou à Anthropic | Accepté ([D-12](12-decisions-architecture.md#d-12--aide-ia-par-le-navigateur)) | Geste volontaire de l'utilisateur, dans son navigateur ; aucune autre donnée de l'inventaire n'est envoyée. |
| R-20 | Un changement d'adresse IP du téléphone oblige à autoriser de nouveau les navigateurs : le cookie est lié à l'adresse saisie ([§6.2](06-reseau-flux.md#62-adresse-du-téléphone)) ; les anciennes sessions restent dans N-E3 jusqu'à leur révocation | Accepté le 2026-10-18 | Les baux DHCP sont stables sur la plupart des réseaux domestiques. |
| R-53 | Le catalogue de référence n'est jamais mis à jour | Accepté ([D-16](12-decisions-architecture.md#d-16--catalogue-de-référence-embarqué)) | Les appellations changent rarement ; une nouvelle se crée à la main. |

## 13.3 Risques levés par la v3

| ID | Risque de la v1 du DAT | Ce qui l'a levé |
|---|---|---|
| R-24 | Le site ne pouvait pas s'afficher sur iOS 13 et 14, déclarés par l'application alors que le site vise Safari 15 | Version minimale d'iOS portée à 15 le 2026-10-18 |
| R-01 (v1) | Tout appareil du réseau local avait tous les droits sur la cave | Autorisation des navigateurs ([D-18](12-decisions-architecture.md#d-18--autorisation-des-navigateurs-sur-le-téléphone)) ; reste R-01, R-05, R-06 |
| R-03 (v1) | Restauration de n'importe quel fichier SQLite, suivie d'un arrêt brutal de l'application | Examen du fichier, remplacement à chaud ; reste R-03 |
| R-04 | Corps de requête sans limite, texte des exceptions renvoyé | Corps plafonnés (32 Mo, 100 Mo), erreur 500 générique |
| R-13 (v1) | Tag perdu entre deux attentes longues | Attente longue remplacée par les événements |
| R-20 (v1) | Découverte mDNS fragile | Adresse affichée ; changement d’adresse accepté (R-20) |
| R-21 (v1) | Écran jamais éteint tant que le manager était lancé | Plus de boucle de santé ; le canal d'événements ne garde pas l'écran allumé ; reste R-21 |
| R-30 | Politique de confidentialité décrivant un autre système | Réécrite le 2026-10-18 pour la v3 |
| R-32 | Documentation en retard sur le code | README, `docs/` et `spec.md` mis à jour le 2026-10-18 |
| R-34 | Binaires du manager non signés | Manager supprimé |
| R-35 (v1) | Restes de l'ancien système (pilote RFID vide, client Go, ancienne `MainActivity`, `shared_preferences` inutilisé, commentaire vers un fichier Go) | Supprimés ou désormais utilisés ; reste R-35 |
