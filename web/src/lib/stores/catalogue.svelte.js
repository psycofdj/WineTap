// Catalogue : appellations, domaines, cuvées.

import { api } from '../api.js';
import { comparer } from '../format.js';

const parNom = (a, b) => comparer(a.nom, b.nom);

class Catalogue {
  /** @type {Array<{id:number, nom:string, region:string, description:string, a_image:boolean}>} */
  appellations = $state([]);
  /** @type {Array<{id:number, nom:string, description:string}>} */
  domaines = $state([]);
  /** @type {Array<{id:number, nom:string, domaine_id:number, appellation_id:number, couleur:number, description:string}>} */
  cuvees = $state([]);
  charge = $state(false);
  /** Incrémenté à chaque changement d'image, pour recharger les <img>. */
  versionImages = $state(0);

  #apps = $derived(new Map(this.appellations.map((a) => [a.id, a])));
  #doms = $derived(new Map(this.domaines.map((d) => [d.id, d])));
  #cuvs = $derived(new Map(this.cuvees.map((c) => [c.id, c])));

  /** Régions connues, triées (liste du champ Région). */
  regions = $derived([...new Set(this.appellations.map((a) => a.region).filter(Boolean))].sort(comparer));

  appellation(id) {
    return this.#apps.get(id) ?? null;
  }
  domaine(id) {
    return this.#doms.get(id) ?? null;
  }
  cuvee(id) {
    return this.#cuvs.get(id) ?? null;
  }

  async charger() {
    const [a, d, c] = await Promise.all([api.get('/appellations'), api.get('/domaines'), api.get('/cuvees')]);
    this.appellations = a.sort(parNom);
    this.domaines = d.sort(parNom);
    this.cuvees = c.sort(parNom);
    this.charge = true;
  }

  /** URL de l'image d'une appellation (null si elle n'en a pas). */
  urlImage(appellation) {
    if (!appellation?.a_image) return null;
    const token = typeof window !== 'undefined' ? window.winetapBridge?.token : null;
    const q = new URLSearchParams({ v: String(this.versionImages) });
    if (token) q.set('token', token);
    return `/api/appellations/${appellation.id}/image?${q}`;
  }

  // Écritures : le serveur renvoie l'objet ; on recharge la liste concernée.

  async enregistrer(rubrique, id, donnees) {
    const chemin = `/${rubrique}`;
    const obj = id ? await api.put(`${chemin}/${id}`, donnees) : await api.post(chemin, donnees);
    await this.#recharger(rubrique);
    if (rubrique === 'appellations' && 'image' in donnees) this.versionImages++;
    return obj;
  }

  async supprimer(rubrique, id) {
    await api.del(`/${rubrique}/${id}`);
    await this.#recharger(rubrique);
  }

  async #recharger(rubrique) {
    const liste = (await api.get(`/${rubrique}`)).sort(parNom);
    if (rubrique === 'appellations') this.appellations = liste;
    else if (rubrique === 'domaines') this.domaines = liste;
    else this.cuvees = liste;
  }
}

export const catalogue = new Catalogue();
