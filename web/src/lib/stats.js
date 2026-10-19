// Statistiques du stock (accueil et tableau de bord).

import { comparer } from './format.js';
import { ORDRE_COULEURS, teinteGraphique, vin } from './vins.js';
import { grouper } from './groupes.js';

/** @typedef {'couleur'|'appellation'|'region'} Repartition */

/** Teintes des parts par appellation ou par région (charte du tableau de bord). */
const TEINTES_STOCK = ['#6E1A2B', '#B5762A', '#E3C04F', '#7C8B5C', '#5E7F95', '#9B6A8E', '#C98B6B'];
const TEINTES_HISTO = ['#6E1A2B', '#B5762A', '#E3C04F', '#7C8B5C', '#5E7F95'];
const TEINTE_AUTRES = '#CDBFA6';

export const ENTETE_REPARTITION = { couleur: 'Couleur', appellation: 'Appellation', region: 'Région' };

/** Clé d'une bouteille selon la répartition. */
function cleDe(b, par) {
  if (par === 'couleur') return b.couleur;
  if (par === 'appellation') return b.appellation?.nom ?? 'Sans appellation';
  return b.region || 'Sans région';
}

/** Libellé de la part « Autres ». */
function libelleAutres(par, histo) {
  if (par === 'appellation') return 'Autres appellations';
  return histo ? 'Autres régions' : 'Autres';
}

/** Valeurs triées par nombre décroissant, puis par nom. */
function classer(compte) {
  return [...compte.entries()].sort((a, b) => b[1] - a[1] || comparer(String(a[0]), String(b[0])));
}

/** Pourcentage avec une décimale à la française : 53,8 % */
export function pourcentage(pct) {
  return `${(Math.round(pct * 10) / 10).toLocaleString('fr-FR')} %`;
}

/**
 * Stock par couleur, par appellation ou par région (carte « Stock ») : les 7 premières
 * appellations ou régions, puis « Autres ». `fond` est le dégradé conique de l'anneau.
 * @param {any[]} enStock
 * @param {Repartition} par
 */
export function repartition(enStock, par) {
  const total = enStock.length;
  const compte = new Map();
  for (const b of enStock) {
    const k = cleDe(b, par);
    compte.set(k, (compte.get(k) ?? 0) + 1);
  }
  let lignes;
  if (par === 'couleur') {
    lignes = classer(compte).map(([code, n]) => ({ cle: String(code), libelle: vin(code).libelle, n, teinte: teinteGraphique(code), couleur: code }));
  } else {
    const classees = classer(compte);
    const tete = classees.slice(0, 7);
    const reste = classees.slice(tete.length);
    lignes = tete.map(([nom, n], i) => ({ cle: nom, libelle: nom, n, teinte: TEINTES_STOCK[i], region: par === 'region' ? nom : undefined }));
    if (reste.length) {
      lignes.push({ cle: '…autres', libelle: libelleAutres(par, false), n: reste.reduce((s, [, n]) => s + n, 0), teinte: TEINTE_AUTRES, autres: true });
    }
  }
  lignes = lignes.map((l) => ({ ...l, pct: total ? (l.n / total) * 100 : 0 }));

  // Anneau : une part par ligne, séparées par un écart de 0,4 % couleur carte.
  const ECART = lignes.length > 1 ? 0.4 : 0;
  let acc = 0;
  const parts = [];
  for (const l of lignes) {
    const a = (acc / (total || 1)) * 100;
    const z = ((acc + l.n) / (total || 1)) * 100;
    const m = Math.max(a, z - ECART);
    acc += l.n;
    parts.push(`${l.teinte} ${a.toFixed(2)}% ${m.toFixed(2)}%`, `var(--wt-card) ${m.toFixed(2)}% ${z.toFixed(2)}%`);
  }
  const fond = total ? `conic-gradient(${parts.join(', ')})` : 'var(--wt-card2)';
  return { total, lignes, fond, entete: ENTETE_REPARTITION[par] };
}

/** @param {any[]} enStock */
export function statistiques(enStock) {
  const total = enStock.length;

  const compteCouleurs = new Map();
  for (const b of enStock) compteCouleurs.set(b.couleur, (compteCouleurs.get(b.couleur) ?? 0) + 1);
  const couleurs = [...compteCouleurs.entries()]
    .map(([code, n]) => ({ code, n, pct: total ? (n / total) * 100 : 0 }))
    .sort((a, b) => b.n - a.n || a.code - b.code);

  // Régions, avec la répartition des couleurs de chacune.
  const compteRegions = new Map();
  for (const b of enStock) {
    const r = b.region || 'Sans région';
    const e = compteRegions.get(r) ?? { n: 0, parCouleur: new Map() };
    e.n++;
    e.parCouleur.set(b.couleur, (e.parCouleur.get(b.couleur) ?? 0) + 1);
    compteRegions.set(r, e);
  }
  let regions = [...compteRegions.entries()]
    .map(([nom, e]) => ({ nom, n: e.n, parCouleur: e.parCouleur }))
    .sort((a, b) => b.n - a.n || comparer(a.nom, b.nom));
  if (regions.length > 8) {
    const parCouleur = new Map();
    for (const r of regions.slice(7)) for (const [c, n] of r.parCouleur) parCouleur.set(c, (parCouleur.get(c) ?? 0) + n);
    const autres = regions.slice(7).reduce((s, r) => s + r.n, 0);
    regions = [...regions.slice(0, 7), { nom: 'Autres', n: autres, parCouleur, autres: true }];
  }
  const maxRegion = Math.max(1, ...regions.map((r) => r.n));

  const annee = enStock.filter((b) => b.garde === 'annee');
  const depassee = enStock.filter((b) => b.garde === 'depassee');
  const noms = (liste) => [...new Set(liste.map((b) => b.cuvee?.nom).filter(Boolean))];

  return {
    total,
    references: grouper(enStock).length,
    couleurs,
    regions: regions.map(({ parCouleur, ...r }) => ({
      ...r,
      largeur: (r.n / maxRegion) * 100,
      // Parts de la barre, dans l'ordre des couleurs de la charte ; largeur en % de la piste.
      couleurs: ORDRE_COULEURS.filter((c) => parCouleur.has(c)).map((code) => ({
        code,
        n: parCouleur.get(code),
        pct: (parCouleur.get(code) / r.n) * 100,
        largeur: (parCouleur.get(code) / maxRegion) * 100,
      })),
    })),
    annee: { n: annee.length, noms: noms(annee) },
    depassee: { n: depassee.length, noms: noms(depassee) },
  };
}

const NOM_MOIS = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
const NOM_MOIS_LONG = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];

/** Moyenne mensuelle sur 12 mois, une décimale, virgule française. */
function moyenneMois(total) {
  return (Math.round((total / 12) * 10) / 10).toLocaleString('fr-FR');
}

/**
 * Bouteilles par mois sur les 12 derniers mois, mois en cours compris, d'après une date des
 * bouteilles (`consommee_le` pour les consommations, `entree_le` pour les achats). Les barres sont
 * découpées par couleur, ou par les 5 premières appellations ou régions de la période et « Autres ».
 * `series` sert de légende : total, moyenne mensuelle et meilleur mois de chaque part.
 * @param {any[]} bouteilles
 * @param {'consommee_le'|'entree_le'} champ
 * @param {Repartition} [par]
 * @param {Date} [maintenant]
 */
export function parMois(bouteilles, champ, par = 'couleur', maintenant = new Date()) {
  const mois = [];
  for (let i = 11; i >= 0; i--) {
    const d = new Date(maintenant.getFullYear(), maintenant.getMonth() - i, 1);
    mois.push({
      cle: `${d.getFullYear()}-${d.getMonth()}`,
      court: NOM_MOIS[d.getMonth()],
      initiale: NOM_MOIS_LONG[d.getMonth()][0].toUpperCase(),
      long: `${NOM_MOIS_LONG[d.getMonth()]} ${d.getFullYear()}`,
      annee: d.getFullYear(),
      janvier: d.getMonth() === 0,
      n: 0,
      montant: 0,
      /** @type {Map<any, number>} */
      parCle: new Map(),
    });
  }
  const index = new Map(mois.map((m, i) => [m.cle, i]));
  const periode = [];
  for (const b of bouteilles) {
    if (!b[champ]) continue;
    const d = new Date(b[champ]);
    const i = index.get(`${d.getFullYear()}-${d.getMonth()}`);
    if (i === undefined) continue;
    periode.push({ b, i });
  }

  // Parts : couleurs dans l'ordre de la charte, ou 5 premières appellations / régions + « Autres ».
  let series;
  /** @type {(b:any) => any} */
  let serieDe;
  if (par === 'couleur') {
    const presentes = new Set(periode.map(({ b }) => b.couleur));
    series = ORDRE_COULEURS.filter((c) => presentes.has(c)).map((code) => ({ cle: code, libelle: vin(code).libelle, teinte: teinteGraphique(code), couleur: code }));
    serieDe = (b) => b.couleur;
  } else {
    const compte = new Map();
    for (const { b } of periode) compte.set(cleDe(b, par), (compte.get(cleDe(b, par)) ?? 0) + 1);
    const classees = classer(compte);
    const tete = classees.slice(0, 5).map(([nom]) => nom);
    series = tete.map((nom, i) => ({ cle: nom, libelle: nom, teinte: TEINTES_HISTO[i], region: par === 'region' ? nom : undefined }));
    if (classees.length > 5) series.push({ cle: '…autres', libelle: libelleAutres(par, true), teinte: TEINTE_AUTRES, autres: true });
    const gardees = new Set(tete);
    serieDe = (b) => (gardees.has(cleDe(b, par)) ? cleDe(b, par) : '…autres');
  }

  for (const { b, i } of periode) {
    const m = mois[i];
    m.n++;
    if (b.prix) m.montant += b.prix;
    const k = serieDe(b);
    m.parCle.set(k, (m.parCle.get(k) ?? 0) + 1);
  }

  const total = mois.reduce((s, m) => s + m.n, 0);
  const montant = mois.reduce((s, m) => s + m.montant, 0);
  return {
    total,
    montant,
    moyenne: total / 12,
    max: Math.max(0, ...mois.map((m) => m.n)),
    entete: ENTETE_REPARTITION[par],
    series: series
      .map((s) => {
        const valeurs = mois.map((m) => m.parCle.get(s.cle) ?? 0);
        const t = valeurs.reduce((a, v) => a + v, 0);
        return { ...s, total: t, moyenne: moyenneMois(t), max: Math.max(0, ...valeurs) };
      })
      .filter((s) => s.total > 0),
    mois: mois.map(({ parCle, ...m }) => ({
      ...m,
      parts: series.filter((s) => parCle.has(s.cle)).map((s) => ({ cle: s.cle, libelle: s.libelle, teinte: s.teinte, n: parCle.get(s.cle) })),
    })),
  };
}

/** Graduation lisible au-dessus du maximum : 4, 5, 10, 20, 25, 50… */
export function plafond(max) {
  if (max <= 4) return 4;
  const pas = [1, 2, 2.5, 5, 10];
  const p = 10 ** Math.floor(Math.log10(max));
  for (const k of pas) if (k * p >= max) return k * p;
  return 10 * p;
}
