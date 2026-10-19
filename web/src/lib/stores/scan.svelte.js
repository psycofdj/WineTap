// Lecture d'un tag demandée au téléphone depuis un ordinateur (POST /api/scan + événement « scan »).

import { api } from '../api.js';
import { normaliserTag } from '../format.js';

class ScanDistant {
  /** 'inactif' | 'attente' */
  etat = $state('inactif');
  /** @type {string|null} */
  #id = null;
  /** @type {((r: any) => void) | null} */
  #resoudre = null;

  /**
   * @param {'entree'|'recherche'} objet
   * @returns {Promise<{tag_id?: string, annule?: boolean, erreur?: string}>}
   */
  async demander(objet) {
    if (this.etat === 'attente') await this.annuler();
    const r = await api.post('/scan', { objet });
    this.#id = r.id;
    this.etat = 'attente';
    return new Promise((resoudre) => (this.#resoudre = resoudre));
  }

  /** Données de l'événement « scan ». */
  recevoir(evt) {
    if (!this.#id || evt.id !== this.#id) return;
    if (evt.statut === 'lu') this.#terminer({ tag_id: normaliserTag(evt.tag_id) });
    else if (evt.statut === 'annule') this.#terminer({ annule: true });
    else this.#terminer({ erreur: 'lecture' });
  }

  async annuler() {
    const id = this.#id;
    this.#terminer({ annule: true });
    if (id) {
      try {
        await api.del(`/scan/${id}`);
      } catch {
        /* le téléphone a pu fermer la lecture de lui-même */
      }
    }
  }

  /** Le téléphone ne répond plus : la lecture en cours échoue. */
  perdu() {
    if (this.etat === 'attente') this.#terminer({ erreur: 'injoignable' });
  }

  #terminer(resultat) {
    const r = this.#resoudre;
    this.#id = null;
    this.#resoudre = null;
    this.etat = 'inactif';
    r?.(resultat);
  }
}

export const scanDistant = new ScanDistant();
