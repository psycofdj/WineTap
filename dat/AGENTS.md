# Consignes pour les agents — DAT de WineTap

Ce dossier contient le Dossier d'Architecture Technique (DAT) de WineTap : l'application mobile
(Flutter), qui porte la base, le serveur HTTP et le lecteur NFC, et le site web (Svelte 5) qu'elle
embarque, affiché dans sa WebView et dans le navigateur d'un ordinateur autorisé. Il décrit le
système tel qu'il est codé, pas les intentions.

## Langue

- Les agents échangent avec l'utilisateur **en français, toujours**.

## Organisation

- Un fichier markdown par chapitre : `NN-titre.md`. `00-presentation.md` est la page d'accueil et
  n'a pas de titre de niveau 1.
- Titres : `# N. Titre`, sections `## N.M Titre`, sous-sections `### N.M.K Titre`.
- **Table des matières** en tête de chaque page (sections `##` et `###`), entre les marqueurs
  `<!-- toc -->` et `<!-- /toc -->` : ne pas l'éditer à la main, la régénérer par
  `python3 tools/toc.py` (depuis `dat/`) après toute modification d'un titre.
- Schémas dans `schemas/` : SVG écrit à la main (source) et PNG rendu à côté. Le markdown référence
  le PNG, suivi d'une légende `*Figure N — …*`.

## Sources

- Le code fait foi : `mobile/` (application Flutter), `web/` (site et contrat `web/API.md`),
  `.github/workflows/` et `scripts/` (livraison). Un README, un document de `docs/`, une
  spécification (`specs/`, `spec.md`) ou un document de `_bmad-output/` qui contredit le code est un
  écart, listé en annexe C.
- Les décisions viennent de la spécification v3 (`specs/v3-web.md`, `design_handoff_winetap_v3/`)
  et des documents de conception antérieurs (`_bmad-output/planning-artifacts/`), mais le DAT les
  décrit dans l'état où le code les applique.

## Règles de rédaction

- Décrire le système tel qu'il est codé : pas de fonction prévue présentée comme existante.
- Les faiblesses vont toutes au chapitre 13 (registre des risques), pas dans les chapitres
  descriptifs.
- Pas de chemin de fichier ni de numéro de ligne comme « preuve » : les noms de classes, de routes,
  de variables, de fichiers de configuration et de secrets sont bienvenus.
- Aucune valeur secrète, jamais : citer le nom du secret ou de la variable.
- Français, phrases complètes, voix active ; dates au format `AAAA-MM-JJ`.
- Chaque renvoi est un lien vers la section visée (ancres au format GitHub). Après une
  renumérotation, corriger tous les renvois.
- Modifier de façon ciblée : relire le passage avant de le changer, ne pas régénérer un chapitre
  entier. L'utilisateur corrige aussi les fichiers à la main.

## Schémas

- Relire le SVG avant de le modifier.
- Rendu PNG : `render_schema.sh schemas/<nom>.svg` (script du plugin `architecture:dat`, Chrome
  sans interface, ×1,5), puis regarder le PNG pour vérifier qu'aucun texte ne déborde.

## Git

- L'utilisateur gère lui-même les commits et les branches : les agents s'arrêtent aux
  modifications de l'arbre de travail et disent ce qui est prêt.
