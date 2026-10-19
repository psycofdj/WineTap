// Historique des dégustations : pages servies par le téléphone, commentaire modifiable.

import { cave } from './cave.svelte.js';

export class Degustations {
  /** @type {any[]} */
  bouteilles = $state([]);
  total = $state(0);
  depuis = $state(0);
  chargement = $state(false);
  nombre;

  constructor(nombre = 20) {
    this.nombre = nombre;
  }

  /** Page fixe (ordinateur). */
  async page(depuis) {
    this.chargement = true;
    try {
      const r = await cave.degustations(depuis, this.nombre);
      this.bouteilles = r.bouteilles;
      this.total = r.total;
      this.depuis = depuis;
    } finally {
      this.chargement = false;
    }
  }

  /** Page suivante, ajoutée à la liste (téléphone, chargement en défilant). */
  async suite() {
    if (this.chargement || (this.bouteilles.length && this.bouteilles.length >= this.total)) return;
    this.chargement = true;
    try {
      const r = await cave.degustations(this.bouteilles.length, this.nombre);
      const vus = new Set(this.bouteilles.map((b) => b.id));
      this.bouteilles = [...this.bouteilles, ...r.bouteilles.filter((b) => !vus.has(b.id))];
      this.total = r.total;
    } finally {
      this.chargement = false;
    }
  }

  async commenter(id, texte) {
    const b = await cave.commenter(id, texte);
    this.bouteilles = this.bouteilles.map((x) => (x.id === id ? b : x));
  }
}
