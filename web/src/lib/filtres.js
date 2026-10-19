// Recherche et filtres de l'inventaire, communs aux deux formats.

import { simplifier } from './format.js';
import { gardeSignalee } from './garde.js';

/** Texte cherché dans une bouteille : cuvée, domaine, appellation, région, millésime, tag. */
export function correspond(b, requete) {
  if (!requete) return true;
  const mots = simplifier(requete).split(/\s+/).filter(Boolean);
  const texte = simplifier(
    [b.cuvee?.nom, b.domaine?.nom, b.appellation?.nom, b.region, b.millesime || 'NM', b.tag_id].filter(Boolean).join(' '),
  );
  return mots.every((m) => texte.includes(m));
}

/**
 * Filtres venant de l'URL (#/inventaire?couleur=1, ?region=Bordeaux, ?filtre=garde, ?appellation=3, ?domaine=2).
 * @param {Record<string,string>} q
 */
export function filtreUrl(q) {
  return (b) => {
    if (q.couleur !== undefined && q.couleur !== '' && b.couleur !== Number(q.couleur)) return false;
    if (q.region && (b.region || 'Sans région') !== q.region) return false;
    if (q.filtre === 'garde' && !gardeSignalee(b.garde)) return false;
    if (q.garde && b.garde !== q.garde) return false;
    return true;
  };
}
