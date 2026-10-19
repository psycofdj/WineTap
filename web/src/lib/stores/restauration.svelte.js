// État de la restauration dans les paramètres : choix du fichier, confirmation, erreur.

import { cave } from './cave.svelte.js';
import { examiner, restaurer } from '../sauvegarde.js';
import { toast } from '../toast.svelte.js';

export class Restauration {
  /** 'repos' | 'confirmation' | 'erreur' | 'en_cours' */
  etat = $state('repos');
  /** @type {File|null} */
  fichier = $state(null);
  enStockFichier = $state(/** @type {number|null} */ (null));

  get enStockActuel() {
    return cave.enStock.length;
  }

  async choisir(fichier) {
    if (!fichier) return;
    this.fichier = fichier;
    try {
      const r = await examiner(fichier);
      if (r.valide) {
        this.enStockFichier = r.enStock;
        this.etat = 'confirmation';
      } else {
        this.etat = 'erreur';
      }
    } catch (e) {
      toast.afficher(e.message);
      this.etat = 'repos';
    }
  }

  annuler() {
    this.etat = 'repos';
    this.fichier = null;
  }

  async confirmer() {
    if (!this.fichier) return;
    this.etat = 'en_cours';
    try {
      await restaurer(this.fichier);
      this.etat = 'repos';
      this.fichier = null;
    } catch (e) {
      toast.afficher(e.message || 'Restauration impossible');
      this.etat = 'confirmation';
    }
  }
}
