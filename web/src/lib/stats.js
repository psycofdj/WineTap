// Statistiques du stock (accueil et tableau de bord).

import { comparer } from './format.js';
import { ORDRE_COULEURS } from './vins.js';
import { grouper } from './groupes.js';

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

/** Pourcentage affiché : 53,8 % */
export function pourcentage(pct) {
  return `${(Math.round(pct * 10) / 10).toLocaleString('fr-FR')} %`;
}

const NOM_MOIS = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
const NOM_MOIS_LONG = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];

/**
 * Bouteilles par mois sur les 12 derniers mois, mois en cours compris, d'après une date des
 * bouteilles (`consommee_le` pour les consommations, `entree_le` pour les achats).
 * @param {any[]} bouteilles
 * @param {'consommee_le'|'entree_le'} champ
 * @param {Date} [maintenant]
 */
export function parMois(bouteilles, champ, maintenant = new Date()) {
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
      parCouleur: new Map(),
    });
  }
  const index = new Map(mois.map((m, i) => [m.cle, i]));
  for (const b of bouteilles) {
    if (!b[champ]) continue;
    const d = new Date(b[champ]);
    const i = index.get(`${d.getFullYear()}-${d.getMonth()}`);
    if (i === undefined) continue;
    const m = mois[i];
    m.n++;
    if (b.prix) m.montant += b.prix;
    m.parCouleur.set(b.couleur, (m.parCouleur.get(b.couleur) ?? 0) + 1);
  }
  const total = mois.reduce((s, m) => s + m.n, 0);
  const montant = mois.reduce((s, m) => s + m.montant, 0);
  return {
    total,
    montant,
    moyenne: total / 12,
    max: Math.max(0, ...mois.map((m) => m.n)),
    mois: mois.map(({ parCouleur, ...m }) => ({
      ...m,
      couleurs: ORDRE_COULEURS.filter((c) => parCouleur.has(c)).map((code) => ({ code, n: parCouleur.get(code) })),
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
