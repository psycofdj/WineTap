// Action du bouton assistant des fiches du catalogue : ouvrir l'assistant (« ask ») ou copier la
// question (« copy »). Le choix vaut pour la session, sur toutes les fiches et écrans de création.

import { ctx } from '../contexte.svelte.js';
import { demanderIA } from '../ia.js';
import { copierTexte } from '../presse-papiers.js';
import { toast } from '../toast.svelte.js';

const CLE = 'wt-ai-action';

/** @returns {'ask'|'copy'} */
function lire() {
  try {
    return sessionStorage.getItem(CLE) === 'copy' ? 'copy' : 'ask';
  } catch {
    return 'ask';
  }
}

class Assistant {
  /** @type {'ask'|'copy'} */
  mode = $state(lire());

  /** @param {'ask'|'copy'} mode */
  choisir(mode) {
    this.mode = mode;
    try {
      sessionStorage.setItem(CLE, mode);
    } catch {
      // Stockage indisponible : le choix vaut pour cette page.
    }
  }

  /**
   * Lance l'action choisie. `question` vaut null quand le nom est vide : rien n'est envoyé.
   * @param {string|null} question
   */
  async agir(question) {
    if (!question) {
      toast.afficher('Saisissez un nom pour interroger l’assistant');
      return;
    }
    if (this.mode === 'copy') {
      const ok = await copierTexte(question);
      toast.afficher(ok ? 'Prompt copié' : 'Copie impossible dans ce navigateur');
      return;
    }
    const qui = demanderIA(question);
    toast.afficher(ctx.dansApplication ? `${qui} s’ouvre dans le navigateur` : `${qui} s’ouvre dans un nouvel onglet`);
  }
}

export const assistant = new Assistant();
