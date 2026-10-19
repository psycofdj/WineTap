// Contexte d'exécution : dans l'application ou dans un navigateur, format, état du téléphone.

const LARGEUR_ORDINATEUR = 720;
/**
 * Hauteur minimale du format ordinateur : un téléphone en paysage dépasse 720 px de large, mais
 * ses 360 à 430 px de haut ne laissent aucune place à la table de l'inventaire. Il garde le
 * format téléphone, qui défile en entier.
 */
const HAUTEUR_ORDINATEUR = 500;
const FORMAT_ORDINATEUR = `(min-width: ${LARGEUR_ORDINATEUR}px) and (min-height: ${HAUTEUR_ORDINATEUR}px)`;

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
  /** Thème : 'clair' | 'sombre', celui du système par défaut. */
  theme = $state('clair');

  get pont() {
    return pont();
  }
}

export const ctx = new Contexte();

if (typeof window !== 'undefined') {
  const mq = window.matchMedia(FORMAT_ORDINATEUR);
  const majFormat = () => (ctx.ordinateur = mq.matches);
  mq.addEventListener('change', majFormat);
  majFormat();

  const sombre = window.matchMedia('(prefers-color-scheme: dark)');
  const majTheme = () => {
    ctx.theme = sombre.matches ? 'sombre' : 'clair';
    document.documentElement.dataset.theme = ctx.theme;
  };
  sombre.addEventListener('change', majTheme);
  majTheme();
}
