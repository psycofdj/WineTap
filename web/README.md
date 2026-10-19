# WineTap v3 — site embarqué

Site servi par l'application mobile (spécification : `specs/v3-web.md` ; maquettes :
`design_handoff_winetap_v3/`). Svelte 5 et Vite. Le même site s'affiche dans la WebView du
téléphone (format téléphone, y compris en paysage) et dans le navigateur d'un ordinateur (format
ordinateur à partir de 720 px de large et 500 px de haut).

## Commandes

```bash
npm install
npm run dev      # http://localhost:5173, avec l'API simulée (mock/)
npm run check    # svelte-check
npm run build    # dist/ : fichiers à embarquer dans l'application
```

La construction n'a besoin d'aucun accès à Internet à l'exécution : polices (Newsreader,
IBM Plex Sans, IBM Plex Mono, sous-ensemble latin) et icônes sont empaquetées.

## Développement

`npm run dev` branche sur Vite un serveur qui implémente [API.md](API.md) en mémoire, avec une
cave d'environ 180 bouteilles (`mock/donnees.js`). Il simule aussi le téléphone :

| Adresse | Ce qu'elle simule |
|---|---|
| `http://localhost:5173/` | Navigateur d'un ordinateur (ou téléphone hors application si la fenêtre est étroite). Le panneau « Téléphone simulé », en bas à gauche, joue le rôle du téléphone : autoriser ou refuser la connexion, répondre à une lecture de tag, couper le téléphone 12 s, consommer une bouteille sur le téléphone |
| `?app` | WebView de l'application : pont `window.winetapBridge` simulé ; la lecture d'un tag ouvre une imitation de l'écran natif N-E4 avec des boutons de simulation |
| `?mock_auth=attente` | Ce navigateur doit être autorisé depuis le panneau (E-10) |
| `?nodev` | Masque le panneau « Téléphone simulé » |

Par défaut, le serveur simulé autorise automatiquement les navigateurs (case du panneau).

## Organisation

```
src/
  App.svelte                 autorisation (E-10), téléphone injoignable (E-11), coque selon le format
  app.css, styles/           charte (tokens.css de la maquette), polices, classes des champs
  lib/
    api.js, session.js       appels /api, session, chargement, canal d'événements (SSE)
    contexte.svelte.js       dans l'application ou non, format, état du téléphone
    nfc.js                   lireTag(objet) : pont de la WebView, ou lecture demandée au téléphone
    routeur.svelte.js        routes par fragment (#/inventaire…), bouton retour
    formulaire.svelte.js     formulaire de bouteille commun aux deux formats
    stores/                  catalogue, cave, réglages, lecture à distance, dernière lecture…
  components/                composants de la charte (WineGlass, Button, Field, Autocomplete, Sheet, Modal, TagField…)
  ecrans/telephone/          E-01 à E-09 au format téléphone
  ecrans/ordinateur/         E-04 à E-09 au format ordinateur
  ecrans/                    écrans communs (E-10, E-11, fiche du catalogue)
  dev/                       pont simulé et panneau « Téléphone simulé » (absents de la construction)
mock/                        API simulée (développement seulement)
```

## Choix faits pendant l'implémentation

- **API** : le contrat est dans [API.md](API.md) ; c'est ce que sert le serveur Flutter (`mobile/lib/server/`).
  Les bouteilles arrivent sans les noms du catalogue : le site les joint lui-même.
- **Millésime obligatoire** : entre 1900 et l'année courante. Une bouteille ancienne enregistrée
  avec 0 s'affiche « NM ».
- **Déjà consommée** : le tag étant effacé à la consommation (C-01), le serveur reconnaît un tag
  « déjà consommé » par une mémoire des tags libérés depuis son démarrage (API.md, §3).
- **Regroupement** : comme le manager v2, les bouteilles identiques sont celles de même cuvée,
  même millésime et même « à boire avant ». Les actions sur un groupe portent sur la bouteille
  entrée la première.
- **Consommer depuis l'ordinateur** : sans confirmation, comme le bouton du manager v2 ; la
  suppression demande une confirmation.
- **Thème** : celui du système (clair ou sombre).
