<!-- toc -->

**Sur cette page**

- [Comment lire ce document](#comment-lire-ce-document)
- [Sommaire](#sommaire)
- [Historique](#historique)

<!-- /toc -->

Ce dossier décrit l'architecture technique de **WineTap**, un système de gestion de cave à vin
qui suit chaque bouteille de son entrée en cave à sa consommation grâce à un tag NFC collé sur
la bouteille.

Il décrit le système tel qu'il est codé au **2026-10-18** : version 3, branche `v3`, arbre de
travail non encore commité, construit sur le commit `d78543c`. Il comprend :

- une **application mobile** Flutter, pour Android et iOS, qui porte la base de données SQLite,
  lit les tags NFC et sert, sur le port 8080, un site web et son API ;
- un **site web** en Svelte 5, embarqué dans l'application, qui porte toute l'interface de
  gestion : il s'affiche dans l'application (format téléphone) et dans le navigateur d'un
  ordinateur du même réseau (format ordinateur), après autorisation sur le téléphone ;
- une **chaîne de livraison** GitHub Actions qui construit le site et publie l'application sur
  Google Play et l'App Store.

Il n'y a ni serveur central, ni compte, ni service en ligne : tout tient dans le téléphone, et un
ordinateur du même réseau local n'est qu'un écran de plus.

## Comment lire ce document

- **Le code fait foi.** Chaque affirmation vient du code du dépôt : `mobile/` pour l'application,
  `web/` pour le site, `.github/workflows/` et `scripts/` pour la livraison. Quand la
  documentation de `docs/`, une spécification ou un document de conception dit autre chose, le DAT
  suit le code. Les écarts relevés sont listés en
  [annexe C](14-annexes.md#c-écarts-entre-la-documentation-et-le-code).
- **Les chapitres décrivent, le chapitre 13 juge.** Les chapitres 1 à 12 décrivent le système sans
  commenter ses faiblesses. Elles sont toutes au [chapitre 13](13-risques.md), le registre des
  risques.
- **Les anciens systèmes n'apparaissent qu'au chapitre 12.** WineTap a d'abord été conçu autour
  d'un Raspberry Pi, puis d'un manager de bureau en Go et Qt6 qui pilotait le téléphone par une API
  REST découverte par mDNS. Rien de cela n'existe plus dans le code ; le
  [§12.3](12-decisions-architecture.md#123-décisions-remplacées) dit ce qui a été remplacé.
- **Aucune valeur secrète n'apparaît ici.** Un secret est désigné par le nom de sa variable, du
  secret GitHub ou de l'entrée du coffre qui le contient.

## Sommaire

| Chapitre | Contenu |
|---|---|
| [1. Objet et périmètre](01-objet-perimetre.md) | Objet, lecteurs, périmètre, état du code, conventions |
| [2. Contexte et besoins](02-contexte-besoins.md) | Service rendu, utilisateurs, volumétrie, exigences et contraintes |
| [3. Vue d'ensemble](03-vue-ensemble.md) | Schéma général, composants, parcours, choix structurants, fournisseurs et coûts |
| [4. Application mobile](04-application-mobile.md) | Démarrage, WebView et pont, écrans natifs, NFC, serveur embarqué, cycle de vie |
| [5. Site web](05-site-web.md) | Construction, formats, écrans, état et événements, lecture des tags, développement |
| [6. Réseau et flux](06-reseau-flux.md) | Topologie, adresse du téléphone, exposition, matrice de flux |
| [7. API et lecture à distance](07-api.md) | Conventions, authentification, routes, événements, lecture demandée par un ordinateur |
| [8. Données](08-donnees.md) | Modèle, cycle de vie d'une bouteille, tags, stockage, données hors base, jeux d'essai |
| [9. Sécurité](09-securite.md) | Modèle de confiance, autorisation des navigateurs, permissions du système, secrets |
| [10. Livraison et distribution](10-livraison.md) | Dépôt, intégration continue, publication, signature, versions |
| [11. Exploitation et continuité](11-exploitation-continuite.md) | Installation, mise en service, journaux, sauvegarde et restauration, pannes |
| [12. Décisions d'architecture](12-decisions-architecture.md) | Décisions en vigueur et décisions remplacées |
| [13. Risques](13-risques.md) | Risques à traiter, risques acceptés |
| [14. Annexes](14-annexes.md) | Composants et versions, glossaire, écarts, questions ouvertes |

## Historique

| Version | Date | Contenu |
|---|---|---|
| v1 | 2026-10-18 | Première version, rédigée d'après le code du commit `d78543c` (application mobile et manager de bureau). |
| v1.1 | 2026-10-18 | Réponses aux questions Q-01 à Q-03 : dépôt public, application publiée sur l'App Store, publication par la CI seulement ; gravités de R-02 et R-14 revues. |
| v2 | 2026-10-18 | Version 3 de WineTap (branche `v3`) : le manager de bureau et la découverte mDNS disparaissent ; le téléphone sert un site web, autorise les navigateurs et pousse des événements. Chapitres 3 à 7 réécrits, registre des risques revu. |
