// Vues du catalogue : sous-lignes, nombres, cuvées liées (communes aux deux formats).

import { comparer, pluriel, accord } from './format.js';
import { vin } from './vins.js';
import { catalogue } from './stores/catalogue.svelte.js';
import { grouper } from './groupes.js';

export const RUBRIQUES = {
  appellations: { titre: 'Appellations', type: 'Appellation', nouvelle: 'Nouvelle appellation', libelleAjout: 'Ajouter' },
  domaines: { titre: 'Domaines', type: 'Domaine', nouvelle: 'Nouveau domaine', libelleAjout: 'Ajouter' },
  cuvees: { titre: 'Cuvées', type: 'Cuvée', nouvelle: 'Nouvelle cuvée', libelleAjout: 'Ajouter' },
};

/** Appellation la plus fréquente parmi les cuvées d'un domaine. */
export function appellationPrincipale(domaineId) {
  const n = new Map();
  for (const c of catalogue.cuvees) {
    if (c.domaine_id !== domaineId || !c.appellation_id) continue;
    n.set(c.appellation_id, (n.get(c.appellation_id) ?? 0) + 1);
  }
  let meilleure = 0;
  let max = 0;
  for (const [id, k] of n) if (k > max) [meilleure, max] = [id, k];
  return meilleure ? catalogue.appellation(meilleure) : null;
}

/** Éléments de la liste d'une rubrique : { id, nom, sous, couleur? }. */
export function elements(rubrique) {
  if (rubrique === 'appellations') {
    return catalogue.appellations.map((a) => {
      const n = catalogue.cuvees.filter((c) => c.appellation_id === a.id).length;
      return { id: a.id, nom: a.nom, region: a.region, sous: [a.region, pluriel(n, 'cuvée')].filter(Boolean).join(' · ') };
    });
  }
  if (rubrique === 'domaines') {
    return catalogue.domaines.map((d) => {
      const n = catalogue.cuvees.filter((c) => c.domaine_id === d.id).length;
      const app = appellationPrincipale(d.id);
      return { id: d.id, nom: d.nom, sous: [app?.nom, pluriel(n, 'cuvée')].filter(Boolean).join(' · ') };
    });
  }
  return catalogue.cuvees.map((c) => {
    const d = catalogue.domaine(c.domaine_id);
    const a = c.appellation_id ? catalogue.appellation(c.appellation_id) : null;
    return { id: c.id, nom: c.nom, couleur: c.couleur, sous: [d?.nom, a?.nom].filter(Boolean).join(' · ') };
  });
}

/**
 * Lignes « Cuvées de cette appellation / du domaine » : bouteilles en stock groupées
 * par cuvée et millésime.
 */
export function cuveesLiees(rubrique, id, enStock) {
  const cuvees = new Set(
    catalogue.cuvees.filter((c) => (rubrique === 'appellations' ? c.appellation_id === id : c.domaine_id === id)).map((c) => c.id),
  );
  return grouper(enStock.filter((b) => cuvees.has(b.cuvee_id)))
    .map((g) => ({
      cle: g.cle,
      couleur: g.premiere.couleur,
      cuvee: g.premiere.cuvee?.nom ?? '',
      millesime: g.premiere.millesime,
      sous: rubrique === 'appellations' ? (g.premiere.domaine?.nom ?? '') : (g.premiere.appellation?.nom ?? ''),
      qte: g.qte,
    }))
    .sort((a, b) => comparer(a.cuvee, b.cuvee) || a.millesime - b.millesime);
}

/** Sous-ligne de la fiche (sous le nom). */
export function sousLigne(rubrique, obj) {
  if (!obj) return '';
  if (rubrique === 'appellations') {
    const n = catalogue.cuvees.filter((c) => c.appellation_id === obj.id).length;
    return [obj.region, pluriel(n, 'cuvée')].filter(Boolean).join(' · ');
  }
  if (rubrique === 'domaines') {
    const n = catalogue.cuvees.filter((c) => c.domaine_id === obj.id).length;
    const app = appellationPrincipale(obj.id);
    return [app?.nom, pluriel(n, 'cuvée')].filter(Boolean).join(' · ');
  }
  const d = catalogue.domaine(obj.domaine_id);
  const a = obj.appellation_id ? catalogue.appellation(obj.appellation_id) : null;
  return [d?.nom, a?.nom, vin(obj.couleur).libelle].filter(Boolean).join(' · ');
}

/** Message de refus de suppression. */
export function messageRefus(rubrique, nombre) {
  if (rubrique === 'cuvees') return `${pluriel(nombre, 'bouteille')} ${accord(nombre, 'utilise', 'utilisent')} encore cette fiche`;
  return `${pluriel(nombre, 'cuvée')} ${accord(nombre, 'utilise', 'utilisent')} encore cette fiche`;
}
