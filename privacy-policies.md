# Politique de confidentialité — WineTap

**Date d'entrée en vigueur :** 4 avril 2026
**Dernière mise à jour :** 4 avril 2026

---

## 1. Introduction

La présente politique de confidentialité décrit la manière dont l'application **WineTap** (ci-après "l'Application") collecte, utilise et protège les informations lorsque vous utilisez notre service de gestion d'inventaire de cave à vin.

En utilisant l'Application, vous acceptez les pratiques décrites dans la présente politique.



---

## 2. Données collectées

L'Application est un outil de gestion d'inventaire de cave à vin fonctionnant en réseau local. Les données suivantes sont collectées et stockées **exclusivement sur votre propre matériel** (serveur local) :

### 2.1 Données relatives aux bouteilles

- Couleur du vin
- Appellation / désignation (AOC/AOP)
- Domaine / producteur
- Millésime
- Prix d'achat (optionnel)
- Date limite de consommation recommandée (optionnel)
- Notes / description libre (optionnel)
- Date d'ajout et de consommation

### 2.2 Données techniques

- Identifiants RFID (EPC) des tags associés aux bouteilles
- Événements d'erreurs du système (tags inconnus, pannes du lecteur)

### 2.3 Données personnelles

**L'Application ne collecte aucune donnée personnelle.** Il n'y a pas de création de compte utilisateur, pas d'authentification, et aucune information permettant d'identifier directement ou indirectement une personne physique n'est requise pour utiliser l'Application.

---

## 3. Stockage des données

Toutes les données sont stockées **localement** dans une base de données SQLite hébergée sur votre propre matériel (Raspberry Pi ou équivalent), sur votre réseau domestique.

**Aucune donnée n'est transmise à des serveurs externes, au cloud ou à des tiers.**

---

## 4. Partage des données

L'Application **ne partage aucune donnée avec des tiers**. Plus précisément :

- Aucune donnée n'est vendue à des tiers
- Aucune donnée n'est transmise à des services d'analyse ou de statistiques
- Aucune donnée n'est transmise à des réseaux publicitaires
- Aucune donnée n'est partagée avec des courtiers en données

---

## 5. Services tiers

L'Application **n'intègre aucun service tiers** susceptible de collecter des données :

- Pas de service d'analyse (analytics)
- Pas de réseau publicitaire
- Pas de SDK de suivi
- Pas de service de notification push externe

L'Application se connecte uniquement au registre INAO (données ouvertes disponibles sur data.gouv.fr) pour actualiser la base de données des appellations viticoles. Cette connexion ne transmet aucune donnée personnelle ni aucune donnée relative à votre inventaire.

---

## 6. Sécurité des données

Les mesures suivantes sont en place pour protéger vos données :

- Fonctionnement exclusif sur réseau local (aucune exposition à Internet requise)
- Aucune authentification distante, aucun transit de données sur Internet
- Les données restent physiquement sur votre matériel, sous votre contrôle

La sécurité de votre réseau local relève de votre responsabilité.

---

## 7. Conservation et suppression des données

- Les bouteilles consommées sont conservées dans l'historique (suppression logique)
- L'utilisateur peut supprimer définitivement une bouteille depuis l'Application
- Les événements d'erreurs sont conservés et peuvent être acquittés par l'utilisateur
- L'ensemble des données peut être supprimé à tout moment en effaçant la base de données locale

---

## 8. Droits des utilisateurs

Étant donné que toutes les données sont stockées localement sur votre propre matériel, vous avez un contrôle total sur vos données. Vous pouvez à tout moment :

- Consulter l'intégralité des données stockées
- Modifier les informations des bouteilles
- Supprimer des bouteilles individuellement
- Supprimer l'ensemble de la base de données

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
