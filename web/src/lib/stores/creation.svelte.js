// Création en cascade (bouteille → cuvée → domaine ou appellation), sans fenêtre : « Créer … »
// ouvre l'écran de création normal du catalogue, puis on revient à l'écran d'origine, champ rempli.
//
// Chaque cadre de la pile retient l'écran d'origine et son brouillon. Revenir, c'est revenir en
// arrière dans l'historique : l'écran d'origine, recréé, appelle `reprendre()`, qui dépile son cadre
// et lui rend l'objet créé (ou rien, après une annulation, y compris par le bouton retour du
// téléphone).

import { routeur } from '../routeur.svelte.js';

/**
 * @typedef {{ champ: 'cuv'|'dom'|'app', q: string, libelle: string, fil: string, brouillon: any,
 *   origine: string, origineUrl: string, cible: string }} Cadre
 */

const RUBRIQUE = { cuv: 'cuvees', dom: 'domaines', app: 'appellations' };

class Creation {
  /** @type {Cadre[]} */
  pile = $state([]);
  /** Objet créé, rendu à l'écran d'origine : { id, nom } */
  #resultat = /** @type {{id:number, nom:string}|null} */ (null);

  get sommet() {
    return this.pile.at(-1) ?? null;
  }

  /**
   * Empile un cadre et ouvre l'écran de création.
   * @param {Omit<Cadre, 'origine'|'origineUrl'|'cible'>} cadre
   */
  lancer(cadre) {
    const cible = `/catalogue/${RUBRIQUE[cadre.champ]}/nouveau`;
    this.#resultat = null;
    this.pile = [...this.pile, { ...cadre, origine: routeur.chemin, origineUrl: location.hash.replace(/^#/, '') || '/', cible }];
    routeur.aller(cible);
  }

  /** Cadre de l'écran de création affiché, s'il a été ouvert depuis un autre objet. */
  cadre(chemin = routeur.chemin) {
    const s = this.sommet;
    return s && s.cible === chemin ? s : null;
  }

  /**
   * Revient à l'écran d'origine, avec l'objet créé ou null (annulation).
   * @param {{id:number, nom:string}|null} objet
   */
  terminer(objet) {
    const s = this.sommet;
    if (!s) return;
    this.#resultat = objet;
    routeur.retour(s.origineUrl);
  }

  /**
   * Appelé par un écran à sa création : s'il est l'origine du cadre au sommet, le dépile.
   * @returns {{ cadre: Cadre, resultat: {id:number, nom:string}|null } | null}
   */
  reprendre(origine = routeur.chemin) {
    const s = this.sommet;
    if (!s || s.origine !== origine) return null;
    this.pile = this.pile.slice(0, -1);
    const resultat = this.#resultat;
    this.#resultat = null;
    return { cadre: s, resultat };
  }

  /** Navigation ailleurs (menu, liste du catalogue) : les brouillons sont abandonnés. */
  vider() {
    this.pile = [];
    this.#resultat = null;
  }
}

export const creation = new Creation();
