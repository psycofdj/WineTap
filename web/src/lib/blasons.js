// Blasons des régions viticoles, empaquetés avec le site (pas d'Internet sur le réseau local).
// Correspondance en dur : nom de région en minuscules, sans accents, espaces remplacés par des
// tirets (« Rhône » → rhone, « Sud-Ouest » → sud-ouest). Une région absente n'a pas d'icône.

const FICHIERS = import.meta.glob('../assets/blasons/*.svg', { eager: true, query: '?url', import: 'default' });

/** @type {Map<string, string>} */
const URLS = new Map(
  Object.entries(FICHIERS).map(([chemin, url]) => [chemin.slice(chemin.lastIndexOf('/') + 1, -4), /** @type {string} */ (url)]),
);

/** Clé du blason d'une région. */
export function cleRegion(region) {
  return String(region ?? '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .trim()
    .replace(/\s+/g, '-');
}

/** URL du blason d'une région, ou '' s'il n'y en a pas. */
export function blason(region) {
  return URLS.get(cleRegion(region)) ?? '';
}
