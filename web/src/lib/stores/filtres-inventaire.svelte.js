// Filtres de l'inventaire (ordinateur), gardés pendant la session : ils survivent au passage par
// le tableau de bord ou le catalogue. ET entre colonnes, OU à l'intérieur d'un choix multiple.

import { simplifier, millesime } from '../format.js';
import { gardeSignalee } from '../garde.js';
import { correspond } from '../filtres.js';

export function filtresVides() {
  return {
    /** Recherche globale */
    q: '',
    /** @type {number[]} codes de couleur */
    couleur: [],
    cuvee: '',
    domaine: '',
    appellation: '',
    /** @type {string[]} */
    region: [],
    millesime: '',
    /** '' | 'depassee' | 'annee' | 'ok' | 'aucune' | 'a_boire' */
    garde: '',
  };
}

class FiltresInventaire {
  f = $state(filtresVides());

  /** Un filtre est actif (recherche comprise). */
  get actif() {
    const f = this.f;
    return !!(f.q.trim() || f.couleur.length || f.cuvee.trim() || f.domaine.trim() || f.appellation.trim() || f.region.length || f.millesime.trim() || f.garde);
  }

  effacer() {
    this.f = filtresVides();
  }

  /**
   * Filtres demandés par l'adresse (tableau de bord, accueil) : ils remplacent les filtres en cours.
   * #/inventaire?couleur=1 · ?region=Bordeaux · ?appellation=Margaux · ?garde=annee · ?filtre=garde · ?tout
   * @param {Record<string,string>} q
   */
  depuisAdresse(q) {
    if (!Object.keys(q).length) return;
    const f = filtresVides();
    if (q.couleur !== undefined && q.couleur !== '') f.couleur = [Number(q.couleur)];
    if (q.region) f.region = [q.region];
    if (q.appellation) f.appellation = q.appellation;
    if (q.garde) f.garde = q.garde;
    if (q.filtre === 'garde') f.garde = 'a_boire';
    this.f = f;
  }

  /** La bouteille passe-t-elle les filtres ? */
  passe(b) {
    const f = this.f;
    if (!correspond(b, f.q)) return false;
    if (f.couleur.length && !f.couleur.includes(b.couleur)) return false;
    if (f.cuvee.trim() && !simplifier(b.cuvee?.nom).includes(simplifier(f.cuvee.trim()))) return false;
    if (f.domaine.trim() && !simplifier(b.domaine?.nom).includes(simplifier(f.domaine.trim()))) return false;
    if (f.appellation.trim() && !simplifier(b.appellation?.nom ?? 'Sans appellation').includes(simplifier(f.appellation.trim()))) return false;
    if (f.region.length && !f.region.includes(b.region || 'Sans région')) return false;
    if (f.millesime.trim() && !simplifier(millesime(b.millesime)).includes(simplifier(f.millesime.trim()))) return false;
    if (f.garde === 'a_boire' && !gardeSignalee(b.garde)) return false;
    if (f.garde && f.garde !== 'a_boire' && b.garde !== f.garde) return false;
    return true;
  }
}

export const filtresInventaire = new FiltresInventaire();
