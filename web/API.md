# API du site WineTap v3

Contrat entre le site (ce dossier) et le serveur embarqué dans l'application Flutter. Le serveur de
développement (`mock/`) l'implémente en mémoire. Toutes les routes sont sous `/api/`, en JSON,
champs en `snake_case`. Le fichier de base ne change pas (C-01) : les champs ci-dessous sont ceux
des tables existantes, plus des valeurs calculées.

## 1. Authentification

| Origine | Moyen |
|---|---|
| WebView de l'application | En-tête `X-WineTap-Token`, valeur `window.winetapBridge.token` injectée par l'application. Pour `GET /api/events` et `GET /api/appellations/:id/image`, qui ne peuvent pas porter d'en-tête, le même secret passe en paramètre `?token=` |
| Navigateur d'un ordinateur | Cookie de session `wt_session` (`HttpOnly`, `SameSite=Strict`), posé par `POST /api/session` |

Le serveur refuse (403) toute requête dont l'en-tête `Host` n'est ni l'adresse du téléphone ni
`localhost`, et toute requête qui modifie des données sans en-tête `Origin` conforme. Sans session
autorisée, seules `GET /api/session`, `POST /api/session` et `GET /api/events` répondent ; les
autres renvoient 401.

### `GET /api/session`

- 200, session autorisée :
  ```json
  { "statut": "autorisee", "dans_application": false,
    "telephone": { "nom": "iPhone", "adresse": "192.168.1.42:8080" },
    "annee": 2026, "connexions": 3 }
  ```
  `annee` est l'année courante du téléphone (états de garde). `connexions` est le nombre de
  connexions autorisées (affiché dans les réglages de l'application).
- 401, session absente ou non autorisée :
  ```json
  { "statut": "inconnue" | "en_attente" | "refusee",
    "client": { "navigateur": "Firefox", "systeme": "macOS", "ip": "192.168.1.27", "demande_le": "2026-10-18T18:14:00Z" } }
  ```

### `POST /api/session`

Demande une autorisation pour ce navigateur : pose le cookie et affiche N-E2 sur le téléphone.
Réponse 202 avec le même corps que le 401 ci-dessus (`statut: "en_attente"`).

Le téléphone limite les demandes : une seule en attente par adresse IP, trois au plus en tout ;
une demande sans réponse expire au bout de 5 minutes ; après un refus, la même adresse attend
2 minutes avant de redemander. Sinon : 429 `trop_de_demandes`, avec la raison dans `message`, et
aucun cookie n'est posé. Le site affiche la raison et réessaie à son interrogation suivante.

## 2. Catalogue

### Appellations

| Route | Effet |
|---|---|
| `GET /api/appellations` | Liste, sans l'appellation sentinelle `id = 0` |
| `POST /api/appellations` | Création ; 201 |
| `PUT /api/appellations/:id` | Mise à jour |
| `DELETE /api/appellations/:id` | 204 ; 409 `referencee` si une cuvée l'utilise |
| `GET /api/appellations/:id/image` | Image brute (`Content-Type` selon le contenu) ; 404 sans image |

Objet : `{ "id", "nom", "region", "description", "a_image": bool }`.
Écriture : `{ "nom", "region", "description", "image"? }`. `image` est une image encodée en
base64 : une chaîne remplace l'image, `null` la retire, l'absence du champ la laisse inchangée.

### Domaines

`GET|POST /api/domaines`, `PUT|DELETE /api/domaines/:id`.
Objet : `{ "id", "nom", "description" }`. Suppression refusée (409 `referencee`) si une cuvée
l'utilise.

### Cuvées

`GET|POST /api/cuvees`, `PUT|DELETE /api/cuvees/:id`.
Objet : `{ "id", "nom", "domaine_id", "appellation_id", "couleur", "description" }`.
`couleur` : 0 inconnue, 1 rouge, 2 blanc, 3 rosé, 4 effervescent, 5 autre. `appellation_id` vaut 0
quand la cuvée n'a pas d'appellation. Suppression refusée (409 `referencee`) si une bouteille,
même consommée, l'utilise.

## 3. Bouteilles

Objet bouteille :

```json
{ "id": 12, "tag_id": "04A32BFF", "cuvee_id": 3, "millesime": 2015, "commentaire": "",
  "prix": 650.0, "a_boire_avant": 2045, "entree_le": "2024-03-12T09:00:00Z", "consommee_le": null }
```

Correspondance avec la table `bottles` : `millesime` = `vintage`, `commentaire` = `description`,
`prix` = `purchase_price`, `a_boire_avant` = `drink_before`, `entree_le` = `added_at`,
`consommee_le` = `consumed_at`. `millesime` est obligatoire, entre 1900 et l'année courante.

| Route | Effet |
|---|---|
| `GET /api/bouteilles` | Bouteilles en stock |
| `GET /api/bouteilles?consommees=1` | Bouteilles en stock et consommées |
| `POST /api/bouteilles` | Création ; 201. 409 `tag_utilise` (avec `bouteille_id`) si le tag est déjà sur une bouteille en stock |
| `PUT /api/bouteilles/:id` | Mise à jour partielle (champs présents seulement) ; `tag_id: null` retire le tag ; `entree_le` et `consommee_le` ne se modifient pas |
| `DELETE /api/bouteilles/:id` | Suppression définitive ; 204 |
| `POST /api/bouteilles/:id/consommer` | Consommation sans tag ; renvoie la bouteille |
| `POST /api/consommer` `{ "tag_id" }` | Consommation par tag ; 200 `{ "bouteille" }` ; 404 `tag_inconnu` ; 409 `deja_consommee` avec `{ "bouteille" }` |
| `GET /api/bouteilles/tag/:tag_id` | Bouteille en stock portant ce tag ; mêmes erreurs que ci-dessus |
| `GET /api/degustations?depuis=0&nombre=20` | `{ "total", "bouteilles": [...] }`, bouteilles consommées de la plus récente à la plus ancienne |

L'identifiant de tag est normalisé par le serveur (séparateurs retirés, majuscules).

**Déjà consommée.** Le tag est effacé à la consommation (C-01) : la base ne sait plus quelle
bouteille il portait. Le serveur garde en mémoire, depuis son démarrage, l'association entre les
tags libérés et leur bouteille, et l'oublie dès que le tag est associé à une autre bouteille.

## 4. Réglages

`GET /api/reglages` → `{ "assistant": "claude" | "chatgpt" }` ; `PUT /api/reglages` avec le même
corps. Rangés dans le stockage de l'application, hors de la base (D-09).

## 5. Lecture d'un tag demandée par un ordinateur

| Route | Effet |
|---|---|
| `POST /api/scan` `{ "objet": "entree" \| "recherche" }` | Ouvre une lecture sur le téléphone (N-E4) ; 202 `{ "id" }` ; 409 `occupe` si une lecture est en cours |
| `DELETE /api/scan/:id` | Annule la lecture ; 204 |

Le résultat arrive par l'événement `scan` (§7).

## 6. Sauvegarde et restauration

| Route | Effet |
|---|---|
| `GET /api/sauvegarde` | Fichier de base complet, `Content-Disposition: attachment; filename="winetap-AAAA-MM-JJ.db"` |
| `POST /api/restauration/examen` (corps : le fichier) | 200 `{ "en_stock": 176 }` si c'est une base WineTap ; 400 `fichier_invalide` sinon. Ne modifie rien |
| `POST /api/restauration` (corps : le fichier) | Remplace la base ; 200 `{ "en_stock" }` ; 400 `fichier_invalide`. L'événement `donnees` suit |

Taille maximale du fichier : 100 Mo (413 au-delà).

## 7. Événements

`GET /api/events` : flux *Server-Sent Events*. Le serveur envoie `retry: 5000`.

| Événement | Données | Quand |
|---|---|---|
| `donnees` | `{ "quoi": ["bouteilles", "catalogue", "reglages"] }` | Après toute modification, d'où qu'elle vienne |
| `scan` | `{ "id", "statut": "lu" \| "annule" \| "erreur", "tag_id"? }` | Fin d'une lecture demandée par `POST /api/scan` |
| `session` | `{ "statut": "autorisee" \| "refusee" \| "revoquee" }` | Décision sur le téléphone ; révocation |

Un navigateur non autorisé ne reçoit que l'événement `session`.

## 8. Erreurs

Corps : `{ "erreur": "<code>", "message": "<texte en français>", ... }`.

| Statut | Codes |
|---|---|
| 400 | `invalide`, `fichier_invalide` |
| 401 | `non_autorise` |
| 403 | `origine_refusee` |
| 404 | `introuvable`, `tag_inconnu` |
| 409 | `referencee` (avec `nombre`), `tag_utilise` (avec `bouteille_id`), `deja_consommee` (avec `bouteille`), `occupe` |
| 413 | `trop_gros` |
| 429 | `trop_de_demandes` |

## 9. Pont JavaScript de l'application

Dans la WebView, l'application expose `window.winetapBridge` :

| Membre | Rôle |
|---|---|
| `token` | Secret à envoyer dans `X-WineTap-Token` |
| `readTag(objet)` → `Promise<{ tag_id } \| { annule: true }>` | Affiche N-E4 et lit un tag. `objet` : `consommer`, `identifier`, `entree`, `recherche`. Les erreurs de lecture se règlent sur N-E4 (« Réessayer ») |
| `saveBackup()` → `Promise<{ enregistre: bool, nom }>` | Enregistre une sauvegarde sur le téléphone (sélecteur du système) |
| `pickFile()` → `Promise<{ nom, base64 } \| { annule: true }>` | Choisit un fichier avec le sélecteur du système : fichier de restauration, carte d'appellation |
| `openNative(ecran)` | Ouvre un écran natif : `adresse` (N-E1) ou `connexions` (N-E3) |
| `openExternal(url)` | Ouvre une adresse dans le navigateur du téléphone (assistant IA) |

Le site détecte l'application par la présence de `window.winetapBridge`. Dans l'application, le pont
est injecté par le serveur dans `index.html` : la WebView ouvre `/?jeton=<secret>`, qui pose le
cookie `wt_app` (`HttpOnly`, `SameSite=Strict`) et redirige vers `/`. Les réponses du pont arrivent
par `window.__wtRetour(id, résultat)`, les appels partent par le canal `WineTapNative`.
