// Contexte d'exécution : dans l'application ou dans un navigateur, format, état du téléphone.

const LARGEUR_ORDINATEUR = 720;
/**
 * Hauteur minimale du format ordinateur : un téléphone en paysage dépasse 720 px de large, mais
 * ses 360 à 430 px de haut ne laissent aucune place à la table de l'inventaire. Il garde le
 * format téléphone, qui défile en entier.
 */
const HAUTEUR_ORDINATEUR = 500;
const FORMAT_ORDINATEUR = `(min-width: ${LARGEUR_ORDINATEUR}px) and (min-height: ${HAUTEUR_ORDINATEUR}px)`;
const CLE_THEME = 'wt.theme';

/** @returns {'clair'|'sombre'|null} */
function lireChoixTheme() {
  try {
    const v = localStorage.getItem(CLE_THEME);
    return v === 'clair' || v === 'sombre' ? v : null;
  } catch {
    return null;
  }
}

function pont() {
  return typeof window !== 'undefined' ? window.winetapBridge ?? null : null;
}

class Contexte {
  /** Le site tourne dans la WebView de l'application (pont JS présent, injecté avant le site). */
  get dansApplication() {
    return !!pont();
  }
  /** Mise en page ordinateur à partir de 720 px de large et 500 px de haut. */
  ordinateur = $state(typeof window !== 'undefined' ? window.matchMedia(FORMAT_ORDINATEUR).matches : true);
  /** 'joignable' | 'injoignable' */
  telephone = $state('joignable');
  /** 'chargement' | 'inconnue' | 'en_attente' | 'refusee' | 'limitee' | 'autorisee' */
  autorisation = $state('chargement');
  /** Raison donnée par le téléphone quand il n'accepte pas de demande pour l'instant (429). */
  limite = $state('');
  /** Infos du téléphone : { nom, adresse } */
  appareil = $state({ nom: '', adresse: '' });
  /** Infos de ce navigateur, telles que vues par le téléphone */
  client = $state({ navigateur: '', systeme: '', ip: '', demande_le: '' });
  /** Année courante du téléphone (états de garde). */
  annee = $state(new Date().getFullYear());
  /** Nombre de connexions autorisées (réglages de l'application). */
  connexions = $state(0);
  /** Thème affiché : 'clair' | 'sombre'. */
  theme = $state('clair');
  /** Thème choisi sur cet appareil ; null : celui du système. */
  choixTheme = $state(/** @type {'clair'|'sombre'|null} */ (null));

  get pont() {
    return pont();
  }
}

export const ctx = new Contexte();

const systeme = typeof window !== 'undefined' ? window.matchMedia('(prefers-color-scheme: dark)') : null;

function majTheme() {
  ctx.theme = ctx.choixTheme ?? (systeme?.matches ? 'sombre' : 'clair');
  document.documentElement.dataset.theme = ctx.theme;
}

if (typeof window !== 'undefined') {
  const mq = window.matchMedia(FORMAT_ORDINATEUR);
  const majFormat = () => (ctx.ordinateur = mq.matches);
  mq.addEventListener('change', majFormat);
  majFormat();

  systeme.addEventListener('change', majTheme);
  ctx.choixTheme = lireChoixTheme();
  majTheme();
  // Dans l'application, les écrans natifs suivent le même thème.
  pont()?.setTheme?.(ctx.choixTheme ?? 'systeme');
}

/**
 * Choisit le thème sur cet appareil : 'clair', 'sombre', ou null pour suivre le système. Le choix
 * est propre à chaque appareil (un ordinateur et le téléphone peuvent différer) : il est gardé
 * dans le navigateur, pas dans les réglages communs du téléphone.
 * @param {'clair'|'sombre'|null} choix
 */
export function choisirTheme(choix) {
  ctx.choixTheme = choix;
  try {
    if (choix) localStorage.setItem(CLE_THEME, choix);
    else localStorage.removeItem(CLE_THEME);
  } catch {
    // Stockage indisponible (navigation privée) : le choix vaut pour cette page.
  }
  majTheme();
  pont()?.setTheme?.(choix ?? 'systeme');
}
