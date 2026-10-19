// lireTag(objet) : pont de la WebView dans l'application, scan demandé au téléphone ailleurs.

import { ctx } from './contexte.svelte.js';
import { normaliserTag } from './format.js';
import { scanDistant } from './stores/scan.svelte.js';

/** Libellés de l'objet d'une lecture (N-E4). */
export const OBJETS = {
  consommer: 'Consommer une bouteille',
  identifier: 'Identifier une bouteille',
  entree: 'Entrer une bouteille en stock',
  recherche: 'Rechercher une bouteille par son tag',
};

/**
 * @param {'consommer'|'identifier'|'entree'|'recherche'} objet
 * @returns {Promise<{tag_id?: string, annule?: boolean, erreur?: string}>}
 */
export async function lireTag(objet) {
  const pont = ctx.pont;
  if (pont) {
    try {
      const r = await pont.readTag(objet);
      if (!r || r.annule) return { annule: true };
      return { tag_id: normaliserTag(r.tag_id) };
    } catch {
      return { erreur: 'lecture' };
    }
  }
  if (objet === 'consommer' || objet === 'identifier') {
    // Ces fonctions n'existent que dans l'application (D-13).
    return { erreur: 'indisponible' };
  }
  try {
    return await scanDistant.demander(objet);
  } catch {
    return { erreur: 'injoignable' };
  }
}

/** Annule une lecture demandée depuis l'ordinateur (ou une fenêtre de navigateur étroite). Dans l'application, l'annulation se fait sur N-E4. */
export function annulerLecture() {
  if (!ctx.pont) scanDistant.annuler();
}
