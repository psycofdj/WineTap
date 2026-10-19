// Sauvegarde et restauration du fichier de base (voir API.md, §6).

import { api, ErreurApi } from './api.js';
import { ctx } from './contexte.svelte.js';
import { nomSauvegarde } from './format.js';
import { chargerTout } from './session.js';
import { toast } from './toast.svelte.js';

/** Type d'une image d'après ses premiers octets. */
function typeImage(o) {
  if (o[0] === 0x89 && o[1] === 0x50) return 'image/png';
  if (o[0] === 0xff && o[1] === 0xd8) return 'image/jpeg';
  if (o[0] === 0x47 && o[1] === 0x49) return 'image/gif';
  if (o.length > 12 && String.fromCharCode(...o.slice(8, 12)) === 'WEBP') return 'image/webp';
  return 'application/octet-stream';
}

/**
 * Dans l'application : choix d'un fichier par le sélecteur du système (pont `pickFile`).
 * Renvoie un File, ou null si l'utilisateur annule.
 */
export async function choisirFichierNatif() {
  const r = await ctx.pont.pickFile();
  if (!r || r.annule || !r.base64) return null;
  const octets = Uint8Array.from(atob(r.base64), (c) => c.charCodeAt(0));
  return new File([octets], r.nom ?? 'fichier', { type: typeImage(octets) });
}

/** Télécharge (navigateur) ou enregistre sur le téléphone (application) une sauvegarde. */
export async function sauvegarder() {
  const nom = nomSauvegarde();
  if (ctx.pont?.saveBackup) {
    try {
      const r = await ctx.pont.saveBackup();
      if (r?.enregistre) toast.afficher(`Fichier ${r.nom ?? nom} enregistré`);
    } catch {
      toast.afficher('Sauvegarde impossible');
    }
    return;
  }
  const a = document.createElement('a');
  a.href = '/api/sauvegarde';
  a.download = nom;
  document.body.appendChild(a);
  a.click();
  a.remove();
  toast.afficher(`Téléchargement de ${nom}`);
}

/**
 * Examine un fichier avant restauration.
 * @returns {Promise<{ valide: true, enStock: number|null } | { valide: false }>}
 */
export async function examiner(fichier) {
  try {
    const r = await api.fichier('/restauration/examen', fichier);
    return { valide: true, enStock: r?.en_stock ?? null };
  } catch (e) {
    if (e instanceof ErreurApi && (e.code === 'fichier_invalide' || e.statut === 400 || e.statut === 413)) return { valide: false };
    throw e;
  }
}

/** Remplace toute la cave par le fichier. */
export async function restaurer(fichier) {
  await api.fichier('/restauration', fichier);
  await chargerTout();
  toast.afficher('Cave restaurée');
}
