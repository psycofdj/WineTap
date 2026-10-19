# Politique de confidentialité — WineTap

**Date d'entrée en vigueur :** 4 avril 2026
**Dernière mise à jour :** 18 octobre 2026

---

## 1. Introduction

La présente politique de confidentialité décrit la manière dont l'application **WineTap** (ci-après "l'Application") collecte, utilise et protège les informations lorsque vous utilisez notre service de gestion d'inventaire de cave à vin.

En utilisant l'Application, vous acceptez les pratiques décrites dans la présente politique.



---

## 2. Données collectées

L'Application est un outil de gestion d'inventaire de cave à vin fonctionnant en réseau local. Les données suivantes sont collectées et stockées **exclusivement sur votre téléphone**, dans l'Application :

### 2.1 Données relatives aux bouteilles

- Couleur du vin
- Appellation / désignation (AOC/AOP), avec sa région, sa description et une image facultative
- Domaine / producteur, avec sa description
- Cuvée, avec sa description
- Millésime
- Prix d'achat (optionnel)
- Date limite de consommation recommandée (optionnel)
- Notes / description libre, commentaire de dégustation (optionnel)
- Date d'ajout et de consommation

### 2.2 Données techniques

- Identifiants (UID) des tags NFC associés aux bouteilles

### 2.3 Connexions autorisées et réglages

Lorsque vous autorisez, sur le téléphone, le navigateur d'un ordinateur à accéder à votre cave, l'Application conserve pour cette connexion :

- le nom du navigateur et le système de l'ordinateur (tirés de l'en-tête `User-Agent`)
- l'adresse IP de l'ordinateur sur votre réseau local
- la date d'autorisation et la date de dernière activité
- une empreinte (hachage) de l'identifiant de session ; l'identifiant lui-même n'est pas conservé

L'Application conserve aussi votre choix d'assistant IA (Claude ou ChatGPT) pour le bouton « Demander à l'IA ».

### 2.4 Données personnelles

**L'Application ne vous demande aucune donnée personnelle.** Il n'y a pas de création de compte utilisateur, et aucune information permettant de vous identifier n'est requise pour utiliser l'Application. Les seules informations relatives à vos appareils sont celles des connexions autorisées décrites au §2.3 ; elles restent sur votre téléphone.

---

## 3. Stockage des données

Les données de votre cave (§2.1 et §2.2) sont stockées **localement** dans une base de données SQLite, sur votre téléphone, dans l'espace de l'Application.

Les connexions autorisées et le choix de l'assistant IA (§2.3) sont stockés dans les préférences de l'Application, sur votre téléphone, en dehors de la base de données. Ils ne font pas partie des sauvegardes WineTap (le fichier de la base) ; comme les autres données de l'Application, ils peuvent figurer dans la sauvegarde automatique de votre téléphone (compte Google, iCloud), selon vos réglages.

Une sauvegarde est un fichier de la base de données que vous enregistrez vous-même, à l'emplacement de votre choix.

**Aucune donnée n'est transmise à des serveurs externes ou au cloud par l'Application**, sauf lorsque vous utilisez vous-même le bouton « Demander à l'IA » (voir §5).

---

## 4. Partage des données

L'Application **ne partage aucune donnée avec des tiers**. Plus précisément :

- Aucune donnée n'est vendue à des tiers
- Aucune donnée n'est transmise à des services d'analyse ou de statistiques
- Aucune donnée n'est transmise à des réseaux publicitaires
- Aucune donnée n'est partagée avec des courtiers en données

Seule exception, à votre initiative : la question préparée par le bouton « Demander à l'IA » (§5), que vous envoyez vous-même à l'assistant choisi.

---

## 5. Services tiers

L'Application **n'intègre aucun service tiers** susceptible de collecter des données :

- Pas de service d'analyse (analytics)
- Pas de réseau publicitaire
- Pas de SDK de suivi
- Pas de service de notification push externe

La liste de référence des appellations est incluse dans l'Application : aucune connexion n'est nécessaire pour l'obtenir.

L'Application ne se connecte à aucun service sur Internet. Seule exception, à votre initiative : lorsque vous appuyez sur « Demander à l'IA », l'Application ouvre dans votre navigateur le site de l'assistant choisi dans les réglages, ChatGPT (chatgpt.com) ou Claude (claude.ai), avec une question préparée. Cette question contient le nom de l'appellation, du domaine ou de la cuvée concernés (et, pour une cuvée, le nom de son domaine et de son appellation). Aucune autre donnée de votre cave n'est envoyée. L'usage de ce site relève de son éditeur et de sa propre politique de confidentialité. De même, une adresse externe ouverte depuis l'Application s'ouvre dans votre navigateur.

---

## 6. Sécurité des données

Les mesures suivantes sont en place pour protéger vos données :

- Fonctionnement exclusif sur réseau local (aucune exposition à Internet requise)
- Aucun compte, aucune authentification distante, aucun transit de vos données sur Internet
- Les données restent physiquement sur votre téléphone, sous votre contrôle

L'Application utilise votre réseau local pour qu'un ordinateur connecté au même réseau Wi-Fi puisse ouvrir votre cave dans un navigateur, à l'adresse affichée par l'Application. Chaque navigateur doit d'abord être autorisé sur le téléphone. Les connexions autorisées n'expirent pas ; vous pouvez les révoquer à tout moment, une à une ou toutes, depuis l'Application. Les échanges sur le réseau local se font en HTTP, sans chiffrement.

La sécurité de votre réseau local relève de votre responsabilité.

---

## 7. Conservation et suppression des données

- Les bouteilles consommées sont conservées dans l'historique (suppression logique)
- L'utilisateur peut supprimer définitivement une bouteille depuis l'Application
- Les connexions autorisées sont conservées jusqu'à leur révocation depuis l'Application
- L'ensemble des données peut être supprimé à tout moment en désinstallant l'Application ou en effaçant ses données

---

## 8. Droits des utilisateurs

Étant donné que toutes les données sont stockées localement sur votre téléphone, vous avez un contrôle total sur vos données. Vous pouvez à tout moment :

- Consulter l'intégralité des données stockées
- Modifier les informations des bouteilles
- Supprimer des bouteilles individuellement
- Consulter et révoquer les connexions autorisées
- Supprimer l'ensemble des données

---

## 9. Enfants

L'Application **n'est pas destinée aux enfants de moins de 13 ans** et ne collecte sciemment aucune information auprès d'enfants de moins de 13 ans. L'Application est un outil de gestion de cave à vin destiné à un public adulte.

---

## 10. Modifications de la politique de confidentialité

Nous nous réservons le droit de modifier la présente politique de confidentialité. Toute modification sera publiée sur cette page avec une mise à jour de la date de dernière modification. Nous vous encourageons à consulter régulièrement cette page.

---

## 11. Contact

Pour toute question concernant cette politique de confidentialité, veuillez nous contacter.

---

## 12. Consentement

En utilisant l'Application, vous consentez à la présente politique de confidentialité.
