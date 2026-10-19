// Session, autorisation, chargement des données et canal d'événements.

import { api, ErreurApi, ErreurReseau } from './api.js';
import { ctx } from './contexte.svelte.js';
import { catalogue } from './stores/catalogue.svelte.js';
import { cave } from './stores/cave.svelte.js';
import { reglages } from './stores/reglages.svelte.js';
import { scanDistant } from './stores/scan.svelte.js';
import { toast } from './toast.svelte.js';

const DELAI_RECONNEXION = 5000;

function appliquerSession(s) {
  ctx.autorisation = 'autorisee';
  ctx.telephone = 'joignable';
  ctx.appareil = { nom: s.telephone?.nom ?? '', adresse: s.telephone?.adresse ?? location.host };
  if (s.annee) ctx.annee = s.annee;
  ctx.connexions = s.connexions ?? 0;
}

/** Interroge la session. Renvoie le statut. */
export async function verifierSession() {
  try {
    const s = await api.get('/session');
    appliquerSession(s);
  } catch (e) {
    if (e instanceof ErreurReseau) {
      ctx.telephone = 'injoignable';
    } else if (e instanceof ErreurApi && e.statut === 401) {
      ctx.telephone = 'joignable';
      ctx.autorisation = e.donnees.statut ?? 'inconnue';
      if (e.donnees.client) ctx.client = e.donnees.client;
    } else {
      throw e;
    }
  }
  return ctx.autorisation;
}

/**
 * Demande l'autorisation de ce navigateur au téléphone. Le téléphone peut refuser de prendre
 * la demande pour l'instant (429) : autre demande en attente depuis cette adresse, refus récent,
 * trop de demandes ; le site l'affiche et réessaie à l'interrogation suivante.
 */
export async function demanderAutorisation() {
  let r;
  try {
    r = await api.post('/session');
  } catch (e) {
    if (e instanceof ErreurApi && e.statut === 429) {
      ctx.limite = e.message;
      if (ctx.autorisation !== 'refusee') ctx.autorisation = 'limitee';
      return;
    }
    throw e;
  }
  ctx.limite = '';
  if (r?.client) ctx.client = r.client;
  if (r?.statut === 'autorisee') await verifierSession();
  else ctx.autorisation = r?.statut ?? 'en_attente';
}

let enCours = /** @type {Promise<string>|null} */ (null);

/**
 * Vérifie la session, demande l'autorisation si besoin, charge les données, ouvre les événements.
 * `nouveau` : ne réutilise pas une vérification déjà en cours (elle peut dater d'avant la décision).
 */
export async function obtenirAcces({ nouveau = false } = {}) {
  if (nouveau && enCours) await enCours.catch(() => {});
  enCours ??= (async () => {
    try {
      let statut = await verifierSession();
      if (statut === 'inconnue' && !ctx.dansApplication) {
        await demanderAutorisation();
        statut = ctx.autorisation;
      }
      if (statut === 'autorisee') await chargerTout();
      ouvrirEvenements();
      return statut;
    } finally {
      enCours = null;
    }
  })();
  return enCours;
}

if (typeof window !== 'undefined') {
  // Une requête a reçu 401 alors que la session était autorisée : elle a été révoquée.
  window.addEventListener('wt-session-perdue', () => obtenirAcces().catch(() => {}));
}

/** Charge tout ce dont le site a besoin. */
export async function chargerTout() {
  await catalogue.charger();
  await Promise.all([cave.charger(), reglages.charger()]);
}

let source = /** @type {EventSource|null} */ (null);
let minuteur = 0;
let perdu = false;

/** Ouvre le canal d'événements ; se reconnecte toutes les 5 s si le téléphone ne répond plus. */
export function ouvrirEvenements() {
  fermerEvenements();
  const token = ctx.pont?.token;
  source = new EventSource('/api/events' + (token ? `?token=${encodeURIComponent(token)}` : ''));

  source.onopen = async () => {
    const revenu = perdu;
    perdu = false;
    ctx.telephone = 'joignable';
    if (revenu) {
      // Des changements ont pu être manqués pendant la coupure.
      const statut = await verifierSession().catch(() => null);
      if (statut === 'autorisee') await chargerTout().catch(() => {});
    }
  };

  source.onerror = () => {
    perdu = true;
    ctx.telephone = 'injoignable';
    scanDistant.perdu();
    if (source?.readyState === EventSource.CLOSED) {
      clearTimeout(minuteur);
      minuteur = setTimeout(ouvrirEvenements, DELAI_RECONNEXION);
    }
  };

  source.addEventListener('donnees', async (e) => {
    const { quoi = [] } = JSON.parse(e.data || '{}');
    try {
      if (quoi.includes('catalogue')) await catalogue.charger();
      if (quoi.includes('bouteilles')) await cave.charger();
      if (quoi.includes('reglages')) await reglages.charger();
    } catch {
      /* rechargé au prochain événement */
    }
  });

  source.addEventListener('scan', (e) => scanDistant.recevoir(JSON.parse(e.data)));

  source.addEventListener('session', async (e) => {
    const { statut } = JSON.parse(e.data || '{}');
    if (statut === 'autorisee' && ctx.autorisation !== 'autorisee') {
      await obtenirAcces({ nouveau: true }); // charge les données et rouvre le canal avec la session autorisée
    } else if (statut === 'refusee') {
      ctx.autorisation = 'refusee';
    } else if (statut === 'revoquee') {
      ctx.autorisation = 'inconnue';
      toast.afficher('Cette connexion a été révoquée sur le téléphone');
      await obtenirAcces({ nouveau: true });
    }
  });
}

export function fermerEvenements() {
  clearTimeout(minuteur);
  source?.close();
  source = null;
}

/** « Réessayer maintenant » (E-11). */
export function reessayer() {
  return obtenirAcces();
}
