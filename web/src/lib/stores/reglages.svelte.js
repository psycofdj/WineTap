// Réglages communs à tous les navigateurs, rangés sur le téléphone (D-09).

import { api } from '../api.js';

class Reglages {
  /** 'claude' | 'chatgpt' */
  assistant = $state('claude');

  get nomAssistant() {
    return this.assistant === 'chatgpt' ? 'ChatGPT' : 'Claude';
  }

  async charger() {
    const r = await api.get('/reglages');
    this.assistant = r.assistant === 'chatgpt' ? 'chatgpt' : 'claude';
  }

  async choisirAssistant(a) {
    const avant = this.assistant;
    this.assistant = a;
    try {
      await api.put('/reglages', { assistant: a });
    } catch (e) {
      this.assistant = avant;
      throw e;
    }
  }
}

export const reglages = new Reglages();
