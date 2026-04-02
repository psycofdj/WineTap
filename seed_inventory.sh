#!/usr/bin/env bash
#
# seed_inventory.sh — Populate the winetap inventory with ~200 fake bottles.
#
# Usage:
#   ./seed_inventory.sh [BASE_URL]
#
# BASE_URL defaults to http://localhost:8080
#
set -euo pipefail

BASE="${1:-http://localhost:8080}"

# Counters for progress reporting.
domain_count=0
desig_count=0
cuvee_count=0
bottle_count=0

# ── Helpers ──────────────────────────────────────────────────────────────────

post() {
  local path="$1" data="$2"
  local status body
  body=$(curl -s -w '\n%{http_code}' -X POST "${BASE}${path}" \
    -H 'Content-Type: application/json' -d "$data")
  status=$(echo "$body" | tail -1)
  body=$(echo "$body" | sed '$d')
  if [[ "$status" -ge 200 && "$status" -lt 300 ]]; then
    echo "$body"
  else
    echo "ERROR $status on POST $path: $body" >&2
    return 1
  fi
}

# Extract "id" from a JSON response.
id_of() { echo "$1" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }

# json_lookup: search a JSON array for an object matching a field value,
# return the id.  Usage: json_lookup "$json_array" "name" "value"
json_lookup() {
  local json="$1" field="$2" value="$3"
  echo "$json" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for item in data:
    if item.get('$field') == '''$value''':
        print(item['id']); break
" 2>/dev/null || true
}

# ── 1. Designations ─────────────────────────────────────────────────────────
# Fetch all existing designations once, then only POST new ones.

declare -A DESIG_IDS  # name → id

echo "==> Fetching existing designations..."
ALL_DESIG_JSON=$(curl -s "${BASE}/designations")

create_designation() {
  local name="$1" region="$2"
  # Check if it already exists.
  local existing_id
  existing_id=$(json_lookup "$ALL_DESIG_JSON" "name" "$name")
  if [[ -n "$existing_id" ]]; then
    DESIG_IDS["$name"]=$existing_id
    return
  fi
  # Does not exist — create it.
  local resp
  resp=$(post /designations "{\"name\":\"$name\",\"region\":\"$region\"}")
  if [[ -n "$resp" ]]; then
    DESIG_IDS["$name"]=$(id_of "$resp")
    ((desig_count++))
  fi
}

# Create/ensure the designations we'll use.
echo "==> Creating designations..."
create_designation "Saint-Émilion Grand Cru" "Bordeaux"
create_designation "Pauillac"                "Bordeaux"
create_designation "Margaux"                 "Bordeaux"
create_designation "Saint-Julien"            "Bordeaux"
create_designation "Pessac-Léognan"          "Bordeaux"
create_designation "Sauternes"               "Bordeaux"
create_designation "Haut-Médoc"              "Bordeaux"
create_designation "Pomerol"                 "Bordeaux"
create_designation "Gevrey-Chambertin"       "Bourgogne"
create_designation "Meursault"               "Bourgogne"
create_designation "Chablis"                 "Bourgogne"
create_designation "Chablis Premier Cru"     "Bourgogne"
create_designation "Puligny-Montrachet"      "Bourgogne"
create_designation "Nuits-Saint-Georges"     "Bourgogne"
create_designation "Pommard"                 "Bourgogne"
create_designation "Châteauneuf-du-Pape"     "Vallée du Rhône"
create_designation "Côtes du Rhône"          "Vallée du Rhône"
create_designation "Gigondas"                "Vallée du Rhône"
create_designation "Crozes-Hermitage"        "Vallée du Rhône"
create_designation "Hermitage"               "Vallée du Rhône"
create_designation "Côte-Rôtie"              "Vallée du Rhône"
create_designation "Champagne"               "Champagne"
create_designation "Sancerre"                "Loire"
create_designation "Vouvray"                 "Loire"
create_designation "Muscadet"                "Loire"
create_designation "Chinon"                  "Loire"
create_designation "Bandol"                  "Provence"
create_designation "Côtes de Provence"       "Provence"
create_designation "Madiran"                 "Sud-Ouest"
create_designation "Cahors"                  "Sud-Ouest"
create_designation "Jurançon"                "Sud-Ouest"
create_designation "Alsace"                  "Alsace"
create_designation "Alsace Grand Cru"        "Alsace"
create_designation "Languedoc"               "Languedoc-Roussillon"
create_designation "Minervois"               "Languedoc-Roussillon"
create_designation "Corbières"               "Languedoc-Roussillon"
create_designation "Fitou"                   "Languedoc-Roussillon"

echo "    $desig_count designations created (others already existed)"

# ── 2. Domains (producers) ──────────────────────────────────────────────────

declare -A DOM_IDS  # name → id

echo "==> Fetching existing domains..."
ALL_DOM_JSON=$(curl -s "${BASE}/domains")

create_domain() {
  local name="$1"
  local existing_id
  existing_id=$(json_lookup "$ALL_DOM_JSON" "name" "$name")
  if [[ -n "$existing_id" ]]; then
    DOM_IDS["$name"]=$existing_id
    return
  fi
  local resp
  resp=$(post /domains "{\"name\":\"$name\"}")
  if [[ -n "$resp" ]]; then
    DOM_IDS["$name"]=$(id_of "$resp")
    domain_count=$((domain_count + 1))
  fi
}

echo "==> Creating domains..."
create_domain "Château Margaux"
create_domain "Château Lafite Rothschild"
create_domain "Château Mouton Rothschild"
create_domain "Château Latour"
create_domain "Château Haut-Brion"
create_domain "Château Cheval Blanc"
create_domain "Château Ausone"
create_domain "Petrus"
create_domain "Château d'Yquem"
create_domain "Domaine de la Romanée-Conti"
create_domain "Domaine Armand Rousseau"
create_domain "Domaine Leflaive"
create_domain "Domaine William Fèvre"
create_domain "Domaine Coche-Dury"
create_domain "Château de Beaucastel"
create_domain "E. Guigal"
create_domain "M. Chapoutier"
create_domain "Domaine Jean-Louis Chave"
create_domain "Château Rayas"
create_domain "Veuve Clicquot"
create_domain "Dom Pérignon"
create_domain "Krug"
create_domain "Bollinger"
create_domain "Domaine Alphonse Mellot"
create_domain "Domaine Huet"
create_domain "Domaine de la Pépière"
create_domain "Château de Villeneuve"
create_domain "Domaine Tempier"
create_domain "Château d'Esclans"
create_domain "Château Montus"
create_domain "Château du Cèdre"
create_domain "Domaine Cauhapé"
create_domain "Domaine Weinbach"
create_domain "Domaine Zind-Humbrecht"
create_domain "Château de la Négly"
create_domain "Château Maris"
create_domain "Gérard Bertrand"
create_domain "Château de Nouvelles"

echo "    $domain_count domains created"

# ── 3. Cuvées ────────────────────────────────────────────────────────────────

declare -A CUVEE_IDS  # "domain|cuvee_name" → id
cuvee_list=()          # ordered list of keys for bottle assignment

echo "==> Fetching existing cuvées..."
ALL_CUVEE_JSON=$(curl -s "${BASE}/cuvees")

create_cuvee() {
  local domain="$1" name="$2" designation="$3" color="$4"
  local dom_id="${DOM_IDS[$domain]}"
  local desig_id="${DESIG_IDS[$designation]:-0}"
  local key="${domain}|${name}"

  # Check if this cuvée already exists (match by name + domain_id).
  local existing_id
  existing_id=$(echo "$ALL_CUVEE_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for c in data:
    if c['name'] == '''$name''' and c['domain_id'] == $dom_id:
        print(c['id']); break
" 2>/dev/null || true)
  if [[ -n "$existing_id" ]]; then
    CUVEE_IDS["$key"]=$existing_id
    cuvee_list+=("$key")
    return
  fi

  local resp
  resp=$(post /cuvees "{\"name\":\"$name\",\"domain_id\":$dom_id,\"designation_id\":$desig_id,\"color\":$color}")
  if [[ -n "$resp" ]]; then
    CUVEE_IDS["$key"]=$(id_of "$resp")
    cuvee_count=$((cuvee_count + 1))
  fi
  cuvee_list+=("$key")
}

echo "==> Creating cuvées..."

# Color: 1=rouge, 2=blanc, 3=rosé, 4=effervescent

# ── Bordeaux rouges
create_cuvee "Château Margaux"              "Grand Vin"                    "Margaux"                 1
create_cuvee "Château Margaux"              "Pavillon Rouge"               "Margaux"                 1
create_cuvee "Château Lafite Rothschild"    "Grand Vin"                    "Pauillac"                1
create_cuvee "Château Lafite Rothschild"    "Carruades de Lafite"          "Pauillac"                1
create_cuvee "Château Mouton Rothschild"    "Grand Vin"                    "Pauillac"                1
create_cuvee "Château Mouton Rothschild"    "Le Petit Mouton"              "Pauillac"                1
create_cuvee "Château Latour"               "Grand Vin"                    "Pauillac"                1
create_cuvee "Château Latour"               "Les Forts de Latour"          "Pauillac"                1
create_cuvee "Château Haut-Brion"           "Grand Vin Rouge"              "Pessac-Léognan"          1
create_cuvee "Château Haut-Brion"           "Le Clarence de Haut-Brion"    "Pessac-Léognan"          1
create_cuvee "Château Cheval Blanc"         "Grand Vin"                    "Saint-Émilion Grand Cru" 1
create_cuvee "Château Cheval Blanc"         "Le Petit Cheval"              "Saint-Émilion Grand Cru" 1
create_cuvee "Château Ausone"               "Grand Vin"                    "Saint-Émilion Grand Cru" 1
create_cuvee "Petrus"                       "Grand Vin"                    "Pomerol"                 1

# ── Bordeaux blanc / liquoreux
create_cuvee "Château Haut-Brion"           "Grand Vin Blanc"              "Pessac-Léognan"          2
create_cuvee "Château d'Yquem"              "Grand Vin"                    "Sauternes"               2

# ── Bourgogne rouges
create_cuvee "Domaine Armand Rousseau"      "Chambertin"                   "Gevrey-Chambertin"       1
create_cuvee "Domaine Armand Rousseau"      "Clos de la Roche"             "Gevrey-Chambertin"       1
create_cuvee "Domaine de la Romanée-Conti"  "Romanée-Conti"                "Nuits-Saint-Georges"     1
create_cuvee "Domaine de la Romanée-Conti"  "La Tâche"                     "Nuits-Saint-Georges"     1
create_cuvee "Domaine de la Romanée-Conti"  "Richebourg"                   "Nuits-Saint-Georges"     1

# ── Bourgogne blancs
create_cuvee "Domaine Leflaive"             "Puligny-Montrachet"           "Puligny-Montrachet"      2
create_cuvee "Domaine Leflaive"             "Bâtard-Montrachet"            "Puligny-Montrachet"      2
create_cuvee "Domaine Coche-Dury"           "Meursault Les Perrières"      "Meursault"               2
create_cuvee "Domaine Coche-Dury"           "Corton-Charlemagne"           "Meursault"               2
create_cuvee "Domaine William Fèvre"        "Chablis Les Clos"             "Chablis Premier Cru"     2
create_cuvee "Domaine William Fèvre"        "Chablis Valmur"               "Chablis"                 2

# ── Vallée du Rhône
create_cuvee "Château de Beaucastel"        "Châteauneuf-du-Pape Rouge"    "Châteauneuf-du-Pape"     1
create_cuvee "Château de Beaucastel"        "Hommage à Jacques Perrin"     "Châteauneuf-du-Pape"     1
create_cuvee "Château de Beaucastel"        "Châteauneuf-du-Pape Blanc"    "Châteauneuf-du-Pape"     2
create_cuvee "E. Guigal"                    "Côte-Rôtie La Mouline"        "Côte-Rôtie"              1
create_cuvee "E. Guigal"                    "Côte-Rôtie La Landonne"       "Côte-Rôtie"              1
create_cuvee "E. Guigal"                    "Côtes du Rhône"               "Côtes du Rhône"          1
create_cuvee "M. Chapoutier"                "Hermitage De l'Orée"          "Hermitage"               2
create_cuvee "M. Chapoutier"                "Crozes-Hermitage Les Meysonniers" "Crozes-Hermitage"    1
create_cuvee "Domaine Jean-Louis Chave"     "Hermitage Rouge"              "Hermitage"               1
create_cuvee "Château Rayas"                "Châteauneuf-du-Pape"          "Châteauneuf-du-Pape"     1

# ── Champagne
create_cuvee "Veuve Clicquot"               "Brut Carte Jaune"             "Champagne"               4
create_cuvee "Veuve Clicquot"               "La Grande Dame"               "Champagne"               4
create_cuvee "Dom Pérignon"                 "Brut Vintage"                 "Champagne"               4
create_cuvee "Dom Pérignon"                 "Rosé Vintage"                 "Champagne"               3
create_cuvee "Krug"                         "Grande Cuvée"                 "Champagne"               4
create_cuvee "Krug"                         "Clos du Mesnil"               "Champagne"               4
create_cuvee "Bollinger"                    "Spécial Cuvée"                "Champagne"               4
create_cuvee "Bollinger"                    "R.D."                         "Champagne"               4

# ── Loire
create_cuvee "Domaine Alphonse Mellot"      "La Moussière"                 "Sancerre"                2
create_cuvee "Domaine Alphonse Mellot"      "Génération XIX"               "Sancerre"                2
create_cuvee "Domaine Huet"                 "Le Haut-Lieu Moelleux"        "Vouvray"                 2
create_cuvee "Domaine Huet"                 "Le Mont Sec"                  "Vouvray"                 2
create_cuvee "Domaine de la Pépière"        "Clisson"                      "Muscadet"                2
create_cuvee "Château de Villeneuve"        "Les Cormiers"                 "Chinon"                  1

# ── Provence
create_cuvee "Domaine Tempier"              "Bandol Rouge La Tourtine"     "Bandol"                  1
create_cuvee "Domaine Tempier"              "Bandol Rosé"                  "Bandol"                  3
create_cuvee "Château d'Esclans"            "Whispering Angel"             "Côtes de Provence"       3
create_cuvee "Château d'Esclans"            "Garrus"                       "Côtes de Provence"       3

# ── Sud-Ouest
create_cuvee "Château Montus"               "Prestige"                     "Madiran"                 1
create_cuvee "Château Montus"               "Cuvée XL"                     "Madiran"                 1
create_cuvee "Château du Cèdre"             "Le Cèdre"                     "Cahors"                  1
create_cuvee "Château du Cèdre"             "GC"                           "Cahors"                  1
create_cuvee "Domaine Cauhapé"              "Quintessence du Petit Manseng" "Jurançon"               2

# ── Alsace
create_cuvee "Domaine Weinbach"             "Riesling Schlossberg"         "Alsace Grand Cru"        2
create_cuvee "Domaine Weinbach"             "Gewurztraminer Mambourg"      "Alsace Grand Cru"        2
create_cuvee "Domaine Zind-Humbrecht"       "Pinot Gris Rangen"           "Alsace Grand Cru"        2
create_cuvee "Domaine Zind-Humbrecht"       "Riesling Brand"               "Alsace Grand Cru"        2

# ── Languedoc-Roussillon
create_cuvee "Château de la Négly"          "La Porte du Ciel"             "Languedoc"               1
create_cuvee "Château de la Négly"          "La Clape"                     "Languedoc"               1
create_cuvee "Château Maris"                "La Touge Syrah"               "Minervois"               1
create_cuvee "Gérard Bertrand"              "Cigalus Rouge"                "Languedoc"               1
create_cuvee "Gérard Bertrand"              "Cigalus Blanc"                "Languedoc"               2
create_cuvee "Gérard Bertrand"              "Clos du Temple"               "Languedoc"               3
create_cuvee "Château de Nouvelles"         "Fitou Tradition"              "Fitou"                   1

echo "    $cuvee_count cuvées created"

# ── 4. Bottles ───────────────────────────────────────────────────────────────
#
# We create ~200 bottles spread across cuvées with varying vintages, prices,
# and drink-before windows. Each gets a unique fake EPC tag ID.

echo "==> Creating bottles..."

tag_counter=1

add_bottle() {
  local cuvee_key="$1" vintage="$2" price="$3" drink_before="$4"
  local cuvee_id="${CUVEE_IDS[$cuvee_key]:-}"
  if [[ -z "$cuvee_id" ]]; then
    echo "WARN: no cuvee_id for $cuvee_key, skipping" >&2
    return
  fi

  # Generate a fake 24-char EPC tag (like a real UHF EPC).
  local tag
  tag=$(printf "E200CAFE%04X%012X" $((tag_counter % 65536)) $tag_counter)
  ((tag_counter++))

  local json="{\"tag_id\":\"$tag\",\"cuvee_id\":$cuvee_id,\"vintage\":$vintage"
  if [[ "$price" != "null" ]]; then
    json="$json,\"purchase_price\":$price"
  fi
  if [[ "$drink_before" != "null" ]]; then
    json="$json,\"drink_before\":$drink_before"
  fi
  json="$json}"

  post /bottles "$json" > /dev/null
  bottle_count=$((bottle_count + 1))
}

# ── Bordeaux rouges (40 bottles) ──
for v in 2015 2016 2018 2019 2020; do
  add_bottle "Château Margaux|Grand Vin"                     $v  350   $((v+20))
  add_bottle "Château Lafite Rothschild|Grand Vin"           $v  400   $((v+25))
done
for v in 2016 2018 2019; do
  add_bottle "Château Margaux|Pavillon Rouge"                $v  120   $((v+12))
  add_bottle "Château Lafite Rothschild|Carruades de Lafite" $v  100   $((v+10))
done
for v in 2015 2016 2018 2020; do
  add_bottle "Château Mouton Rothschild|Grand Vin"           $v  380   $((v+20))
done
add_bottle "Château Mouton Rothschild|Le Petit Mouton"       2018 90   2033
add_bottle "Château Mouton Rothschild|Le Petit Mouton"       2019 95   2034
for v in 2015 2016 2018; do
  add_bottle "Château Latour|Grand Vin"                      $v  500   $((v+30))
  add_bottle "Château Latour|Les Forts de Latour"            $v  130   $((v+15))
done
add_bottle "Château Haut-Brion|Grand Vin Rouge"              2016 420  2046
add_bottle "Château Haut-Brion|Grand Vin Rouge"              2018 380  2048
add_bottle "Château Haut-Brion|Le Clarence de Haut-Brion"    2018 110  2035
add_bottle "Château Cheval Blanc|Grand Vin"                  2015 450  2045
add_bottle "Château Cheval Blanc|Grand Vin"                  2016 480  2046
add_bottle "Château Cheval Blanc|Le Petit Cheval"            2018 85   2033
add_bottle "Château Ausone|Grand Vin"                        2015 550  2050
add_bottle "Château Ausone|Grand Vin"                        2016 600  2050
add_bottle "Petrus|Grand Vin"                                2015 3200 2055
add_bottle "Petrus|Grand Vin"                                2016 3500 2055
add_bottle "Petrus|Grand Vin"                                2018 3000 2058

# ── Bordeaux blancs & liquoreux (5 bottles) ──
add_bottle "Château Haut-Brion|Grand Vin Blanc"              2018 350  2038
add_bottle "Château Haut-Brion|Grand Vin Blanc"              2019 320  2039
add_bottle "Château d'Yquem|Grand Vin"                       2015 350  2060
add_bottle "Château d'Yquem|Grand Vin"                       2017 300  2060
add_bottle "Château d'Yquem|Grand Vin"                       2019 280  2065

# ── Bourgogne rouges (15 bottles) ──
for v in 2017 2018 2019; do
  add_bottle "Domaine Armand Rousseau|Chambertin"             $v  800  $((v+20))
  add_bottle "Domaine Armand Rousseau|Clos de la Roche"       $v  500  $((v+15))
done
for v in 2016 2017 2018; do
  add_bottle "Domaine de la Romanée-Conti|Romanée-Conti"      $v 15000 $((v+30))
  add_bottle "Domaine de la Romanée-Conti|La Tâche"           $v  4000 $((v+25))
done
add_bottle "Domaine de la Romanée-Conti|Richebourg"           2017 2500 2042
add_bottle "Domaine de la Romanée-Conti|Richebourg"           2018 2800 2043
add_bottle "Domaine de la Romanée-Conti|Richebourg"           2019 2600 2044

# ── Bourgogne blancs (15 bottles) ──
for v in 2018 2019 2020; do
  add_bottle "Domaine Leflaive|Puligny-Montrachet"            $v  120  $((v+8))
  add_bottle "Domaine Coche-Dury|Meursault Les Perrières"     $v  900  $((v+12))
done
add_bottle "Domaine Leflaive|Bâtard-Montrachet"               2018 800  2033
add_bottle "Domaine Leflaive|Bâtard-Montrachet"               2019 850  2034
add_bottle "Domaine Coche-Dury|Corton-Charlemagne"            2018 1200 2035
add_bottle "Domaine Coche-Dury|Corton-Charlemagne"            2019 1300 2036
for v in 2019 2020 2021; do
  add_bottle "Domaine William Fèvre|Chablis Les Clos"         $v  80   $((v+8))
done
add_bottle "Domaine William Fèvre|Chablis Valmur"             2020 65   2030
add_bottle "Domaine William Fèvre|Chablis Valmur"             2021 70   2031

# ── Vallée du Rhône (30 bottles) ──
for v in 2016 2017 2018 2019; do
  add_bottle "Château de Beaucastel|Châteauneuf-du-Pape Rouge" $v 65   $((v+15))
done
add_bottle "Château de Beaucastel|Hommage à Jacques Perrin"    2017 350  2040
add_bottle "Château de Beaucastel|Hommage à Jacques Perrin"    2018 380  2043
add_bottle "Château de Beaucastel|Châteauneuf-du-Pape Blanc"   2019 80  2029
add_bottle "Château de Beaucastel|Châteauneuf-du-Pape Blanc"   2020 85  2030
for v in 2015 2016 2017; do
  add_bottle "E. Guigal|Côte-Rôtie La Mouline"                $v  250  $((v+20))
  add_bottle "E. Guigal|Côte-Rôtie La Landonne"               $v  260  $((v+20))
done
for v in 2019 2020 2021 2022; do
  add_bottle "E. Guigal|Côtes du Rhône"                        $v  12   $((v+5))
done
add_bottle "M. Chapoutier|Hermitage De l'Orée"                 2018 180  2033
add_bottle "M. Chapoutier|Hermitage De l'Orée"                 2019 190  2034
for v in 2019 2020 2021; do
  add_bottle "M. Chapoutier|Crozes-Hermitage Les Meysonniers"  $v  18   $((v+5))
done
add_bottle "Domaine Jean-Louis Chave|Hermitage Rouge"          2017 300  2042
add_bottle "Domaine Jean-Louis Chave|Hermitage Rouge"          2018 320  2043
add_bottle "Château Rayas|Châteauneuf-du-Pape"                 2017 600  2040
add_bottle "Château Rayas|Châteauneuf-du-Pape"                 2018 650  2043

# ── Champagne (20 bottles) ──
for v in 2018 2019 2020; do
  add_bottle "Veuve Clicquot|Brut Carte Jaune"                $v  45   null
done
add_bottle "Veuve Clicquot|La Grande Dame"                     2015 150  null
add_bottle "Veuve Clicquot|La Grande Dame"                     2012 180  null
for v in 2012 2013 2015; do
  add_bottle "Dom Pérignon|Brut Vintage"                       $v  200  null
done
add_bottle "Dom Pérignon|Rosé Vintage"                         2012 350  null
add_bottle "Dom Pérignon|Rosé Vintage"                         2013 380  null
for v in 2018 2019 2020; do
  add_bottle "Krug|Grande Cuvée"                               $v  220  null
done
add_bottle "Krug|Clos du Mesnil"                               2008 800  null
add_bottle "Krug|Clos du Mesnil"                               2006 900  null
for v in 2018 2019 2020; do
  add_bottle "Bollinger|Spécial Cuvée"                         $v  50   null
done
add_bottle "Bollinger|R.D."                                    2008 180  null
add_bottle "Bollinger|R.D."                                    2007 200  null

# ── Loire (16 bottles) ──
for v in 2020 2021 2022; do
  add_bottle "Domaine Alphonse Mellot|La Moussière"            $v  25   $((v+5))
done
add_bottle "Domaine Alphonse Mellot|Génération XIX"            2019 65   2030
add_bottle "Domaine Alphonse Mellot|Génération XIX"            2020 70   2032
for v in 2018 2019 2020; do
  add_bottle "Domaine Huet|Le Haut-Lieu Moelleux"             $v  40   $((v+20))
  add_bottle "Domaine Huet|Le Mont Sec"                       $v  30   $((v+8))
done
for v in 2020 2021; do
  add_bottle "Domaine de la Pépière|Clisson"                  $v  18   $((v+8))
done
add_bottle "Château de Villeneuve|Les Cormiers"                2019 22   2032
add_bottle "Château de Villeneuve|Les Cormiers"                2020 24   2034

# ── Provence (10 bottles) ──
for v in 2018 2019; do
  add_bottle "Domaine Tempier|Bandol Rouge La Tourtine"        $v  55   $((v+12))
done
for v in 2022 2023; do
  add_bottle "Domaine Tempier|Bandol Rosé"                     $v  30   $((v+3))
done
for v in 2022 2023 2024; do
  add_bottle "Château d'Esclans|Whispering Angel"              $v  22   $((v+2))
done
add_bottle "Château d'Esclans|Garrus"                          2021 95   2027
add_bottle "Château d'Esclans|Garrus"                          2022 100  2028
add_bottle "Château d'Esclans|Garrus"                          2023 105  2029

# ── Sud-Ouest (12 bottles) ──
for v in 2016 2017 2018 2019; do
  add_bottle "Château Montus|Prestige"                         $v  35   $((v+15))
done
add_bottle "Château Montus|Cuvée XL"                           2017 60   2035
add_bottle "Château Montus|Cuvée XL"                           2018 65   2038
for v in 2017 2018 2019; do
  add_bottle "Château du Cèdre|Le Cèdre"                      $v  28   $((v+12))
done
add_bottle "Château du Cèdre|GC"                               2017 55   2035
add_bottle "Domaine Cauhapé|Quintessence du Petit Manseng"     2019 45   2040
add_bottle "Domaine Cauhapé|Quintessence du Petit Manseng"     2020 48   2042

# ── Alsace (10 bottles) ──
for v in 2019 2020 2021; do
  add_bottle "Domaine Weinbach|Riesling Schlossberg"           $v  50   $((v+10))
done
add_bottle "Domaine Weinbach|Gewurztraminer Mambourg"          2019 55   2032
add_bottle "Domaine Weinbach|Gewurztraminer Mambourg"          2020 58   2034
for v in 2018 2019 2020; do
  add_bottle "Domaine Zind-Humbrecht|Pinot Gris Rangen"       $v  65   $((v+10))
done
add_bottle "Domaine Zind-Humbrecht|Riesling Brand"             2020 45   2035
add_bottle "Domaine Zind-Humbrecht|Riesling Brand"             2021 48   2036

# ── Languedoc-Roussillon (15 bottles) ──
for v in 2018 2019 2020; do
  add_bottle "Château de la Négly|La Porte du Ciel"            $v  45   $((v+12))
  add_bottle "Château de la Négly|La Clape"                    $v  18   $((v+8))
done
add_bottle "Château Maris|La Touge Syrah"                      2019 22   2030
add_bottle "Château Maris|La Touge Syrah"                      2020 24   2032
for v in 2020 2021; do
  add_bottle "Gérard Bertrand|Cigalus Rouge"                   $v  28   $((v+8))
  add_bottle "Gérard Bertrand|Cigalus Blanc"                   $v  25   $((v+5))
done
add_bottle "Gérard Bertrand|Clos du Temple"                    2022 80   2028
add_bottle "Château de Nouvelles|Fitou Tradition"              2019 14   2028
add_bottle "Château de Nouvelles|Fitou Tradition"              2020 15   2029

# ── Done ─────────────────────────────────────────────────────────────────────

echo ""
echo "=== Seed complete ==="
echo "    Designations : $desig_count created"
echo "    Domains      : $domain_count created"
echo "    Cuvées       : $cuvee_count created"
echo "    Bottles      : $bottle_count created"
echo ""
echo "Verify: curl -s ${BASE}/bottles | python3 -c 'import json,sys; d=json.load(sys.stdin); print(len(d), \"bottles in stock\")'"
