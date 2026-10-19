// Choix d'affichage du tableau de bord, gardés pendant la session : répartition du stock et de
// chaque historique (chaque carte garde le sien).

class Tableau {
  /** @type {'couleur'|'appellation'|'region'} */
  stock = $state('couleur');
  /** @type {'couleur'|'appellation'|'region'} */
  conso = $state('couleur');
  /** @type {'couleur'|'appellation'|'region'} */
  achats = $state('couleur');
}

export const tableau = new Tableau();
