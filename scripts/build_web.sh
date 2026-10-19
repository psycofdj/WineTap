#!/bin/bash
# Construit le site (web/) et le copie dans les ressources de l'application (mobile/assets/site/).
# À lancer avant toute construction de l'application ; la CI le fait aussi.
set -euo pipefail

racine="$(cd "$(dirname "$0")/.." && pwd)"

cd "$racine/web"
if [[ ! -d node_modules ]]; then
  npm ci
fi
npm run build

rm -rf "$racine/mobile/assets/site"
mkdir -p "$racine/mobile/assets/site"
cp -R "$racine/web/dist/." "$racine/mobile/assets/site/"
echo "Site copié dans mobile/assets/site/"
