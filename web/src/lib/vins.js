// Couleurs des vins (D-16) : un verre propre à chaque couleur, rempli de sa teinte.
// Tracés repris de winetap-data.js (objet G). La valeur `code` est celle de la base (C-01).

const G = {
  ballon: {
    verre: 'M4.5 2h11c.3 6.5-2 9.5-5.5 9.5S4.2 8.5 4.5 2zM10 11.5V17M6.5 17.5h7',
    liquide: 'M4.8 6h10.4c-.4 3.8-2.4 5.5-5.2 5.5S5.2 9.8 4.8 6z',
  },
  tulipe: {
    verre:
      'M6 1.5h8c.8 4 .6 6.5-.4 8.2-.8 1.3-2.1 1.8-3.6 1.8s-2.8-.5-3.6-1.8C5.4 8 5.2 5.5 6 1.5zM10 11.5V17M6.5 17.5h7',
    liquide:
      'M5.9 6h8.2c-.1 1.6-.3 2.8-.9 3.7-.7 1.2-1.8 1.8-3.2 1.8s-2.5-.6-3.2-1.8C6.2 8.8 6 7.6 5.9 6z',
  },
  flute: {
    verre: 'M7.5 1h5l-.4 8.6c-.1 1.4-1 2.2-2.1 2.2s-2-.8-2.1-2.2zM10 11.8V17.2M7 17.5h6M9.4 7.4h.01M10.6 5.6h.01',
    liquide: 'M7.65 4h4.7l-.3 5.6c-.1 1.3-.9 2-2.05 2s-1.95-.7-2.05-2z',
  },
  copita: {
    verre: 'M7 5h6c.4 3.5-.8 5.8-3 5.8S6.6 8.5 7 5zM10 10.8V17M7 17.5h6',
    liquide: 'M7.05 7h5.9c-.2 2.3-1.3 3.8-2.95 3.8S7.25 9.3 7.05 7z',
  },
  inconnue: {
    verre:
      'M6 1.5h8c.8 4 .6 6.5-.4 8.2-.8 1.3-2.1 1.8-3.6 1.8s-2.8-.5-3.6-1.8C5.4 8 5.2 5.5 6 1.5zM10 11.5V17M6.5 17.5h7M8.7 4.6a1.3 1.3 0 1 1 1.9 1.2c-.4.2-.6.5-.6.9M10 8.6h.01',
    liquide: '',
  },
};

/** @type {Record<number, {code:number, cle:string, libelle:string, teinte:string, verre:string, liquide:string}>} */
export const VINS = {
  1: { code: 1, cle: 'rouge', libelle: 'Rouge', teinte: 'var(--wine-rouge)', ...G.ballon },
  2: { code: 2, cle: 'blanc', libelle: 'Blanc', teinte: 'var(--wine-blanc)', ...G.tulipe },
  3: { code: 3, cle: 'rose', libelle: 'Rosé', teinte: 'var(--wine-rose)', ...G.tulipe },
  4: { code: 4, cle: 'eff', libelle: 'Effervescent', teinte: 'var(--wine-eff)', ...G.flute },
  5: { code: 5, cle: 'autre', libelle: 'Autre', teinte: 'var(--wine-autre)', ...G.copita },
  0: { code: 0, cle: 'inconnue', libelle: 'Inconnue', teinte: 'transparent', ...G.inconnue },
};

/** Ordre d'affichage des choix de couleur (charte, grille 2 × 3). */
export const ORDRE_COULEURS = [1, 2, 3, 4, 5, 0];

/** Couleur des parts « inconnue » dans les graphiques (pas de teinte propre). */
export const TEINTE_GRAPHIQUE_INCONNUE = 'var(--wt-line2)';

export function vin(code) {
  return VINS[code] ?? VINS[0];
}

export function teinteGraphique(code) {
  return code === 0 || !VINS[code] ? TEINTE_GRAPHIQUE_INCONNUE : VINS[code].teinte;
}
