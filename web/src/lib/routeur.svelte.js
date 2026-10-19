// Routeur par fragment d'URL (#/inventaire?couleur=1). Le bouton retour du téléphone
// (et celui du navigateur) suit l'historique.

function lire() {
  const h = location.hash.replace(/^#/, '') || '/';
  const [chemin, qs = ''] = h.split('?');
  const segments = chemin.split('/').filter(Boolean).map(decodeURIComponent);
  const query = Object.fromEntries(new URLSearchParams(qs));
  return { chemin: '/' + segments.join('/'), segments, query };
}

class Routeur {
  chemin = $state('/');
  /** @type {string[]} */
  segments = $state([]);
  /** @type {Record<string,string>} */
  query = $state({});
  profondeur = 0;

  constructor() {
    if (typeof window === 'undefined') return;
    this.#appliquer();
    this.profondeur = history.state?.wtProfondeur ?? 0;
    window.addEventListener('popstate', (e) => {
      this.profondeur = e.state?.wtProfondeur ?? 0;
      this.#appliquer();
    });
    window.addEventListener('hashchange', () => this.#appliquer());
  }

  /** Dernière adresse appliquée : popstate et hashchange arrivent tous deux pour un retour. */
  #adresse = '';

  #appliquer() {
    if (location.hash === this.#adresse) return;
    this.#adresse = location.hash;
    const r = lire();
    this.chemin = r.chemin;
    this.segments = r.segments;
    this.query = r.query;
  }

  /** Premier segment : nom de l'écran. */
  get ecran() {
    return this.segments[0] ?? '';
  }

  /**
   * @param {string} chemin  ex. '/inventaire?couleur=1'
   * @param {{ remplacer?: boolean }} [options]
   */
  aller(chemin, options = {}) {
    const url = '#' + chemin;
    if (url === location.hash && !options.remplacer) return;
    if (options.remplacer) {
      history.replaceState({ wtProfondeur: this.profondeur }, '', url);
    } else {
      this.profondeur += 1;
      history.pushState({ wtProfondeur: this.profondeur }, '', url);
    }
    this.#appliquer();
  }

  /** Retour à l'écran précédent, ou à `defaut` s'il n'y en a pas. */
  retour(defaut = '/') {
    if (this.profondeur > 0) history.back();
    else this.aller(defaut, { remplacer: true });
  }
}

export const routeur = new Routeur();
