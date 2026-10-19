// État « à boire avant » d'une bouteille, par rapport à l'année courante du téléphone.

/**
 * @param {number|null|undefined} aBoireAvant
 * @param {number} annee
 * @returns {'aucune'|'ok'|'annee'|'depassee'}
 */
export function etatGarde(aBoireAvant, annee) {
  if (aBoireAvant == null || aBoireAvant === 0) return 'aucune';
  if (aBoireAvant < annee) return 'depassee';
  if (aBoireAvant === annee) return 'annee';
  return 'ok';
}

export const LIBELLE_GARDE = {
  aucune: '',
  ok: '',
  annee: 'cette année',
  depassee: 'dépassée',
};

/** Vrai quand l'état mérite d'être signalé (pastilles, filtre « À boire »). */
export function gardeSignalee(etat) {
  return etat === 'annee' || etat === 'depassee';
}
