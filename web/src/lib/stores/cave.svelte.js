// Bouteilles : en stock (toujours chargées), consommées (à la demande).

import { api } from '../api.js';
import { ctx } from '../contexte.svelte.js';
import { etatGarde } from '../garde.js';
import { comparer } from '../format.js';
import { catalogue } from './catalogue.svelte.js';

/**
 * Bouteille enrichie des noms du catalogue.
 * @typedef {{ id:number, tag_id:string|null, cuvee_id:number, millesime:number, commentaire:string,
 *   prix:number|null, a_boire_avant:number|null, entree_le:string, consommee_le:string|null,
 *   cuvee:any, domaine:any, appellation:any, couleur:number, region:string, garde:string }} Bouteille
 */

/** @returns {Bouteille} */
export function enrichir(b) {
  const cuvee = catalogue.cuvee(b.cuvee_id);
  const domaine = cuvee ? catalogue.domaine(cuvee.domaine_id) : null;
  const appellation = cuvee && cuvee.appellation_id ? catalogue.appellation(cuvee.appellation_id) : null;
  return {
    ...b,
    cuvee,
    domaine,
    appellation,
    couleur: cuvee?.couleur ?? 0,
    region: appellation?.region ?? '',
    garde: etatGarde(b.a_boire_avant, ctx.annee),
  };
}

/** Tri par défaut : domaine, cuvée, millésime. */
export function trierParDefaut(a, b) {
  return (
    comparer(a.cuvee?.nom ?? '', b.cuvee?.nom ?? '') ||
    comparer(a.domaine?.nom ?? '', b.domaine?.nom ?? '') ||
    a.millesime - b.millesime
  );
}

class Cave {
  /** Bouteilles en stock, brutes */
  brutes = $state([]);
  /** Bouteilles consommées, brutes (null tant qu'elles ne sont pas chargées) */
  consommeesBrutes = $state(null);
  charge = $state(false);

  /** @type {Bouteille[]} */
  enStock = $derived(this.brutes.map(enrichir).sort(trierParDefaut));
  /** @type {Bouteille[]} */
  consommees = $derived((this.consommeesBrutes ?? []).map(enrichir));

  #parTag = $derived(new Map(this.enStock.filter((b) => b.tag_id).map((b) => [b.tag_id, b])));

  /** Bouteille en stock portant ce tag, ou null. */
  parTag(tagId) {
    return this.#parTag.get(tagId) ?? null;
  }

  parId(id) {
    return this.enStock.find((b) => b.id === id) ?? this.consommees.find((b) => b.id === id) ?? null;
  }

  async charger() {
    this.brutes = await api.get('/bouteilles');
    if (this.consommeesBrutes) await this.chargerConsommees();
    this.charge = true;
  }

  async chargerConsommees() {
    const toutes = await api.get('/bouteilles?consommees=1');
    this.consommeesBrutes = toutes.filter((b) => b.consommee_le);
  }

  /** Bouteilles consommées, de la plus récente à la plus ancienne (pagination serveur). */
  async degustations(depuis = 0, nombre = 20) {
    const r = await api.get(`/degustations?depuis=${depuis}&nombre=${nombre}`);
    return { total: r.total, bouteilles: r.bouteilles.map(enrichir) };
  }

  /** Modifie le commentaire d'une bouteille consommée. */
  async commenter(id, commentaire) {
    const b = await api.put(`/bouteilles/${id}`, { commentaire });
    this.#remplacer(b);
    return enrichir(b);
  }

  async creer(donnees) {
    const b = await api.post('/bouteilles', donnees);
    this.brutes = [...this.brutes, b];
    return b;
  }

  async modifier(id, champs) {
    const b = await api.put(`/bouteilles/${id}`, champs);
    this.#remplacer(b);
    return b;
  }

  async supprimer(id) {
    await api.del(`/bouteilles/${id}`);
    this.brutes = this.brutes.filter((x) => x.id !== id);
    if (this.consommeesBrutes) this.consommeesBrutes = this.consommeesBrutes.filter((x) => x.id !== id);
  }

  /** Consommation sans tag. */
  async consommer(id) {
    const b = await api.post(`/bouteilles/${id}/consommer`);
    this.#remplacer(b);
    return enrichir(b);
  }

  /** Consommation par tag ; lève ErreurApi (tag_inconnu, deja_consommee). */
  async consommerParTag(tagId) {
    const r = await api.post('/consommer', { tag_id: tagId });
    this.#remplacer(r.bouteille);
    return enrichir(r.bouteille);
  }

  #remplacer(b) {
    if (b.consommee_le) {
      this.brutes = this.brutes.filter((x) => x.id !== b.id);
      if (this.consommeesBrutes) this.consommeesBrutes = [b, ...this.consommeesBrutes.filter((x) => x.id !== b.id)];
    } else {
      const existe = this.brutes.some((x) => x.id === b.id);
      this.brutes = existe ? this.brutes.map((x) => (x.id === b.id ? b : x)) : [...this.brutes, b];
    }
  }
}

export const cave = new Cave();
