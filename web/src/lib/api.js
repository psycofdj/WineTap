// Appels à l'API du téléphone (voir API.md).

import { ctx } from './contexte.svelte.js';

export class ErreurApi extends Error {
  /**
   * @param {number} statut
   * @param {string} code
   * @param {string} message
   * @param {any} donnees
   */
  constructor(statut, code, message, donnees = {}) {
    super(message || code);
    this.statut = statut;
    this.code = code;
    this.donnees = donnees;
  }
}

/** Erreur réseau : le téléphone ne répond pas. */
export class ErreurReseau extends Error {}

function entetes(extra = {}) {
  const h = { ...extra };
  const token = ctx.pont?.token;
  if (token) h['X-WineTap-Token'] = token;
  return h;
}

/**
 * @param {string} methode
 * @param {string} chemin
 * @param {{ json?: any, corps?: BodyInit, brut?: boolean }} [options]
 */
export async function requete(methode, chemin, options = {}) {
  /** @type {RequestInit} */
  const init = { method: methode, credentials: 'same-origin', headers: entetes() };
  if (options.json !== undefined) {
    init.headers = entetes({ 'Content-Type': 'application/json' });
    init.body = JSON.stringify(options.json);
  } else if (options.corps !== undefined) {
    init.headers = entetes({ 'Content-Type': 'application/octet-stream' });
    init.body = options.corps;
  }

  let rep;
  try {
    rep = await fetch(`/api${chemin}`, init);
  } catch {
    throw new ErreurReseau('Téléphone injoignable');
  }

  if (options.brut && rep.ok) return rep;
  if (rep.status === 204) return null;

  let donnees = null;
  const type = rep.headers.get('Content-Type') || '';
  if (type.includes('application/json')) {
    try {
      donnees = await rep.json();
    } catch {
      donnees = null;
    }
  }

  if (!rep.ok) {
    if (rep.status === 401 && ctx.autorisation === 'autorisee' && chemin !== '/session') {
      ctx.autorisation = 'inconnue';
      window.dispatchEvent(new Event('wt-session-perdue'));
    }
    throw new ErreurApi(rep.status, donnees?.erreur ?? 'erreur', donnees?.message ?? '', donnees ?? {});
  }
  return donnees;
}

export const api = {
  get: (chemin) => requete('GET', chemin),
  post: (chemin, json) => requete('POST', chemin, { json: json ?? {} }),
  put: (chemin, json) => requete('PUT', chemin, { json }),
  del: (chemin) => requete('DELETE', chemin),
  fichier: (chemin, corps) => requete('POST', chemin, { corps }),
};

/** Lit un fichier en base64 (sans l'en-tête data:). */
export function enBase64(blob) {
  return new Promise((resoudre, rejeter) => {
    const lecteur = new FileReader();
    lecteur.onload = () => {
      const s = /** @type {string} */ (lecteur.result);
      resoudre(s.slice(s.indexOf(',') + 1));
    };
    lecteur.onerror = () => rejeter(lecteur.error);
    lecteur.readAsDataURL(blob);
  });
}
