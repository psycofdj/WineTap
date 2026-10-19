// Regroupement des bouteilles identiques : même cuvée, même millésime, même « à boire avant »
// (règle du manager v2).

import { gardeSignalee } from './garde.js';
import { trierParDefaut } from './stores/cave.svelte.js';

/**
 * @param {import('./stores/cave.svelte.js').Bouteille[]} bouteilles
 * @returns {Array<{ cle: string, bouteilles: any[], premiere: any, qte: number, derniereEntree: string }>}
 */
export function grouper(bouteilles) {
  const groupes = new Map();
  for (const b of bouteilles) {
    const cle = `${b.cuvee_id}|${b.millesime}|${b.a_boire_avant ?? ''}`;
    let g = groupes.get(cle);
    if (!g) {
      g = { cle, bouteilles: [], premiere: b, qte: 0, derniereEntree: b.entree_le };
      groupes.set(cle, g);
    }
    g.bouteilles.push(b);
    g.qte++;
    if (b.entree_le > g.derniereEntree) g.derniereEntree = b.entree_le;
  }
  return [...groupes.values()];
}

/** Bouteilles à boire (garde dans l'année ou dépassée). */
export function aBoire(bouteilles) {
  return bouteilles.filter((b) => gardeSignalee(b.garde));
}

/** Nombre de bouteilles en stock identiques à celle-ci (même cuvée et millésime). */
export function resteEnCave(enStock, b) {
  return enStock.filter((x) => x.cuvee_id === b.cuvee_id && x.millesime === b.millesime).length;
}

export { trierParDefaut };
