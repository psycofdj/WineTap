// Mise en forme en français. Espace insécable :  .

export const NBSP = ' ';

const fmtCourt = new Intl.DateTimeFormat('fr-FR', { day: '2-digit', month: '2-digit', year: 'numeric' });
const fmtLong = new Intl.DateTimeFormat('fr-FR', { day: 'numeric', month: 'short', year: 'numeric' });
const fmtJourMois = new Intl.DateTimeFormat('fr-FR', { day: 'numeric', month: 'short' });
const fmtHeure = new Intl.DateTimeFormat('fr-FR', { hour: '2-digit', minute: '2-digit' });

function date(iso) {
  if (!iso) return null;
  const d = new Date(iso);
  return Number.isNaN(d.getTime()) ? null : d;
}

/** 12/03/2024 */
export function dateCourte(iso) {
  const d = date(iso);
  return d ? fmtCourt.format(d) : '—';
}

/** 14 oct. 2026 */
export function dateLongue(iso) {
  const d = date(iso);
  return d ? fmtLong.format(d) : '—';
}

/** 18 oct. 2026, 20:14 */
export function dateHeure(iso) {
  const d = date(iso);
  return d ? `${fmtLong.format(d)}, ${fmtHeure.format(d)}` : '—';
}

/** 20:14 */
export function heure(iso) {
  const d = date(iso);
  return d ? fmtHeure.format(d) : '—';
}

/** « 14 oct. » ou « 14 oct. 2025 » si ce n'est pas l'année en cours. */
export function dateRelativeAnnee(iso, annee) {
  const d = date(iso);
  if (!d) return '—';
  return d.getFullYear() === annee ? fmtJourMois.format(d) : fmtLong.format(d);
}

/** Accord en nombre ; 0 et 1 au singulier. */
export function pluriel(n, singulier, pluriel = singulier + 's') {
  return `${n}${NBSP}${Math.abs(n) > 1 ? pluriel : singulier}`;
}

/** Mot seul, accordé. */
export function accord(n, singulier, pluriel = singulier + 's') {
  return Math.abs(n) > 1 ? pluriel : singulier;
}

const fmtPrix = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', minimumFractionDigits: 0, maximumFractionDigits: 2 });

/** 310 € ; 32,5 € → 32,50 € */
export function prix(valeur) {
  if (valeur == null || valeur === '') return '—';
  const n = Number(valeur);
  if (!Number.isFinite(n)) return '—';
  if (Number.isInteger(n)) return fmtPrix.format(n);
  return new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', minimumFractionDigits: 2 }).format(n);
}

/** Millésime court (table, listes) : 2019 ou NM. */
export function millesime(v) {
  return v ? String(v) : 'NM';
}

/** Millésime long (fiches) : 2019 ou « Sans millésime ». */
export function millesimeLong(v) {
  return v ? String(v) : 'Sans millésime';
}

/** Nom de fichier de sauvegarde du jour. */
export function nomSauvegarde(d = new Date()) {
  const p = (n) => String(n).padStart(2, '0');
  return `winetap-${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}.db`;
}

/** Comparaison alphabétique française, insensible à la casse et aux accents. */
export const comparer = new Intl.Collator('fr', { sensitivity: 'base', numeric: true }).compare;

/** Texte simplifié pour la recherche : minuscules, sans accents. */
export function simplifier(s) {
  return (s ?? '')
    .toString()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase();
}

/** Normalisation d'un identifiant de tag (comme le serveur). */
export function normaliserTag(t) {
  return (t ?? '').replace(/[:\s-]/g, '').toUpperCase();
}
