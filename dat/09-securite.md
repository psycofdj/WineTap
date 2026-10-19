# 9. Sécurité

<!-- toc -->

**Sur cette page**

- [9.1 Modèle de confiance](#91-modèle-de-confiance)
- [9.2 Autorisation des navigateurs](#92-autorisation-des-navigateurs)
- [9.3 Contrôles du serveur](#93-contrôles-du-serveur)
- [9.4 Robustesse des entrées](#94-robustesse-des-entrées)
- [9.5 Permissions du système](#95-permissions-du-système)
- [9.6 Secrets](#96-secrets)
- [9.7 Politique de confidentialité](#97-politique-de-confidentialité)

<!-- /toc -->

## 9.1 Modèle de confiance

WineTap fait confiance à **qui tient le téléphone** : c'est sur le téléphone, déverrouillé et
WineTap ouvert, que l'on autorise un navigateur. Être sur le même réseau ne donne plus accès à la
cave, seulement le droit de demander une autorisation
([D-18](12-decisions-architecture.md#d-18--autorisation-des-navigateurs-sur-le-téléphone)).

| Mesure | État |
|---|---|
| Comptes, mots de passe | Aucun |
| Accès de la WebView | Jeton d'application aléatoire, tiré à chaque démarrage, injecté dans la page ; il ne quitte pas le téléphone |
| Accès d'un navigateur d'ordinateur | Session autorisée sur le téléphone, par un écran de confirmation ; sans expiration, révocable une à une ou toutes ensemble |
| Chiffrement des échanges | Aucun : HTTP en clair sur le port 8080 ([D-04](12-decisions-architecture.md#d-04--pas-de-chiffrement-sur-le-réseau-local)) |
| Authentification du téléphone par le navigateur | Aucune : le navigateur fait confiance à l'adresse saisie |
| Fenêtre d'exposition | L'application ouverte au premier plan ; écran gardé allumé 5 minutes après chaque requête |
| Accès au téléphone lui-même | Celui du système : verrouillage de l'écran ; l'application n'ajoute rien |

Une session autorisée a tous les droits : lire et modifier le catalogue et l'inventaire,
télécharger la base entière (`GET /api/sauvegarde`) ou la remplacer (`POST /api/restauration`).
Les risques qui restent sont au [chapitre 13](13-risques.md#131-risques-à-traiter) (R-01, R-05,
R-06).

## 9.2 Autorisation des navigateurs

1. Un navigateur sans session ouvre le site ; le site envoie `POST /api/session`. Le serveur tire
   un identifiant de session aléatoire, le pose dans le cookie `wt_session` (`HttpOnly`,
   `SameSite=Strict`, durée de dix ans) et enregistre une **demande en attente**, en mémoire, avec
   le navigateur et le système tirés de l'en-tête `User-Agent`, l'adresse IP et l'heure. Les
   demandes sont limitées : une seule en attente par adresse IP, trois au plus en tout, deux
   minutes d'attente pour une adresse après un refus ; au-delà, le serveur répond 429
   `trop_de_demandes` sans rien afficher sur le téléphone, et le site l'indique en réessayant toutes
   les 3 secondes. Une demande sans réponse expire au bout de 5 minutes ; une réponse donnée après
   l'expiration ne décide rien et le téléphone affiche « Demande expirée ».
2. Le téléphone affiche aussitôt la feuille N-E2. Le site affiche E-10.
3. « Autoriser » : la session est enregistrée dans les préférences, sous la forme de l'empreinte
   SHA-256 de son identifiant, avec le navigateur, le système, l'adresse IP et les dates ; le
   serveur émet l'événement `session` « autorisee », et le site s'ouvre. « Refuser » : la demande
   passe à l'état « refusée », en mémoire ; le site l'indique.
4. Le navigateur garde son cookie : les visites suivantes sont reconnues sans nouvelle
   autorisation, après un redémarrage de l'application comme du navigateur.
5. Chaque requête d'une session autorisée met à jour sa dernière activité et sa dernière adresse
   IP ; elles sont écrites dans les préférences au plus une fois par minute.
6. Révocation depuis N-E3 : la session est retirée des préférences, ses canaux d'événements
   reçoivent `session` « revoquee » et sont fermés ; ses requêtes suivantes reçoivent 401.

La WebView n'a pas besoin d'autorisation : elle ouvre `/?jeton=<jeton>`, qui pose le cookie
`wt_app` et redirige vers `/`. Un jeton faux rend 403. Ce jeton change à chaque démarrage du
processus.

## 9.3 Contrôles du serveur

`securityMiddleware` traite chaque requête avant les routes :

| Contrôle | Règle | Refus |
|---|---|---|
| Identification | Jeton d'application (cookie `wt_app`, en-tête `X-WineTap-Token` ou paramètre `token`) ; sinon session (cookie `wt_session`), autorisée, en attente, refusée ou inconnue | — |
| Hôte | Sur `/api/`, l'en-tête `Host` doit être `localhost` ou une adresse IP littérale : un site tiers qui ferait pointer un nom de domaine vers le téléphone (*DNS rebinding*) ne peut pas atteindre l'API | 403 `origine_refusee` |
| Origine | Pour `POST`, `PUT`, `PATCH` et `DELETE`, l'en-tête `Origin` doit être présent et égal à `http://<Host>` : un autre site ouvert dans le navigateur ne peut pas écrire | 403 `origine_refusee` |
| Autorisation | WebView ou session autorisée ; sans elles, seules `GET` et `POST /api/session` et `GET /api/events` répondent | 401 `non_autorise` |
| Demandes d'autorisation | Une en attente par adresse IP, trois en tout, deux minutes après un refus | 429 `trop_de_demandes` |

S'y ajoutent, pour le site :

- `index.html` porte une politique de sécurité du contenu : scripts, styles, images et connexions
  limités à l'origine du téléphone (plus `data:` et `blob:` pour les images, et les scripts et
  styles en ligne), pas d'affichage dans un cadre (`frame-ancestors 'none'`) ;
- tous les fichiers sont servis avec `X-Content-Type-Options: nosniff` ;
- dans la WebView, seules les pages de `localhost` et `127.0.0.1` sont chargées ; toute autre
  adresse s'ouvre dans le navigateur du téléphone.

## 9.4 Robustesse des entrées

| Entrée | Contrôle |
|---|---|
| Corps JSON | 32 Mo au plus ; décodé, puis chaque champ attendu est vérifié (présence, type, millésime) ; une erreur rend 400 `invalide` |
| Requêtes SQL | Construites par `drift`, paramétrées |
| Intégrité | Contraintes de SQLite (unicité, clés étrangères), traduites en 409 |
| Restauration | 100 Mo au plus ; en-tête `SQLite format 3` ; fichier ouvert en lecture seule dans un dossier temporaire ; tables `designations`, `domains`, `cuvees` et `bottles` présentes ; version de schéma au plus 2. Sinon 400 `fichier_invalide`, sans rien modifier |
| Identifiant de tag | Normalisé ; refusé s'il est vide après normalisation |
| Erreur imprévue | 500 `interne`, message générique ; le détail ne part que dans le journal |

## 9.5 Permissions du système

| Système | Permission ou déclaration | Usage |
|---|---|---|
| Android | `android.permission.NFC` | Lire les tags |
| Android | `android.permission.INTERNET` | Ouvrir le port 8080 ; charger le site par `localhost` dans la WebView |
| Android | `networkSecurityConfig` | Autorise le HTTP en clair vers `localhost` et `127.0.0.1` seulement, pour la WebView |
| Android | `<queries>` sur les adresses `https` | Ouvrir l'assistant IA dans le navigateur du téléphone |
| iOS | Droit `com.apple.developer.nfc.readersession.formats` (`TAG`) et `NFCReaderUsageDescription` | Lire les tags ; texte affiché à la demande d'accès au NFC |
| iOS | `NSLocalNetworkUsageDescription` | Autorisation d'accès au réseau local, demandée à l'utilisateur, pour être joint par un ordinateur |
| iOS | `NSAppTransportSecurity` : `NSAllowsLocalNetworking` | HTTP en clair vers le réseau local et `localhost`, pour la WebView |

L'application ne demande ni la localisation, ni l'accès aux photos, aux contacts ou au stockage :
les fichiers passent par les sélecteurs du système
([§4.6](04-application-mobile.md#46-échanges-de-fichiers)). Garder l'écran allumé ne demande pas de
permission.

## 9.6 Secrets

Les seuls secrets du projet servent à **signer et publier** l'application. Aucun secret n'est
embarqué dans l'application ni dans le site ; le jeton d'application est tiré à l'exécution.

| Secret | Usage | Où il est rangé |
|---|---|---|
| Clé de téléversement Android (`upload-keystore.jks`), son alias et ses mots de passe | Signer le paquet Android | Secrets GitHub `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `ANDROID_STORE_PASSWORD` ; sur le poste, entrée `winetap` d'un coffre KeePassXC (attributs `android_key_alias`, `android_password`, pièce jointe `upload-keystore.jks`) |
| Compte de service Google Play | Envoyer le paquet sur la piste interne | Secret GitHub `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` |
| Certificat de distribution Apple et son mot de passe | Signer le paquet iOS | Secrets GitHub `IOS_CERTIFICATE_P12_BASE64`, `IOS_CERTIFICATE_PASSWORD` |
| Profil de provisionnement « WineTap AppStore Distribution » | Distribution App Store | Secret GitHub `IOS_PROVISIONING_PROFILE_BASE64` |
| Clé d'API App Store Connect | Envoyer le paquet iOS | Secrets GitHub `APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_API_ISSUER_ID`, `APP_STORE_CONNECT_API_KEY_P8` |
| Jeton GitHub du dépôt | Créer la release, fusionner les mises à jour de Dependabot | `GITHUB_TOKEN`, fourni par GitHub Actions à chaque exécution |

Sur un poste de développement, la signature Android peut aussi lire un fichier
`mobile/android/key.properties`, et la signature iOS un fichier `mobile/ios/Flutter/Local.xcconfig` ;
tous deux sont exclus du dépôt par `.gitignore`.

L'usage de ces secrets dans la chaîne de publication est décrit au
[§10.4](10-livraison.md#104-signature-et-secrets).

## 9.7 Politique de confidentialité

Le dépôt contient une politique de confidentialité en français (`privacy-policies.md`), destinée
aux magasins d'applications, mise à jour pour la v3 le 2026-10-18. Elle décrit la base sur le
téléphone, les connexions autorisées gardées dans les préférences, l'accès par le réseau local et
l'envoi du nom d'un vin à l'assistant IA choisi, à la demande de l'utilisateur.
