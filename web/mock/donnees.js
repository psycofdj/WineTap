// Jeu de données du serveur de développement : une cave d'environ 180 bouteilles.
// Reprend les vins des maquettes, complétés pour atteindre des volumes réalistes.

// Générateur pseudo-aléatoire déterministe (mêmes données à chaque démarrage).
function prng(graine) {
  let s = graine >>> 0;
  return () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 2 ** 32;
  };
}

const APPELLATIONS = [
  ['Margaux', 'Bordeaux', 'Appellation du Médoc, rive gauche de la Gironde. Graves profondes, cabernet sauvignon dominant ; vins réputés pour leur finesse.'],
  ['Saint-Julien', 'Bordeaux', 'Commune du Médoc entre Pauillac et Margaux, sans premier cru mais d’une grande régularité.'],
  ['Pauillac', 'Bordeaux', 'Cœur du Médoc, trois premiers crus. Cabernet sauvignon puissant sur graves.'],
  ['Saint-Émilion Grand Cru', 'Bordeaux', 'Rive droite, plateau calcaire et côtes ; merlot et cabernet franc.'],
  ['Pessac-Léognan', 'Bordeaux', 'Graves au sud de Bordeaux, rouges et blancs de garde.'],
  ['Puligny-Montrachet', 'Bourgogne', 'Village de la Côte de Beaune, consacré presque entièrement au chardonnay. Blancs tendus, floraux, de grande garde.'],
  ['Meursault', 'Bourgogne', 'Village de la Côte de Beaune connu pour ses blancs amples et beurrés.'],
  ['Chablis', 'Bourgogne', 'Chardonnay sur marnes kimméridgiennes, au nord de la Bourgogne. Vins tendus et iodés.'],
  ['Corton-Charlemagne', 'Bourgogne', 'Grand cru blanc de la colline de Corton.'],
  ['Gevrey-Chambertin', 'Bourgogne', 'Village de la Côte de Nuits, pinot noir structuré.'],
  ['Volnay', 'Bourgogne', 'Pinot noir délicat et parfumé de la Côte de Beaune.'],
  ['Côte-Rôtie', 'Rhône', 'Coteaux très pentus du nord de la vallée du Rhône. Syrah, parfois complétée de viognier.'],
  ['Hermitage', 'Rhône', 'Colline de granit au-dessus de Tain, syrah de très longue garde.'],
  ['Cornas', 'Rhône', 'Syrah sur granit, rouges sombres et puissants.'],
  ['Saint-Joseph', 'Rhône', 'Rive droite du Rhône nord, syrah plus souple.'],
  ['Crozes-Hermitage', 'Rhône', 'Plus grande appellation du Rhône nord, syrah fruitée.'],
  ['Condrieu', 'Rhône', 'Viognier exclusivement, blancs aromatiques.'],
  ['Châteauneuf-du-Pape', 'Rhône', 'Galets roulés et treize cépages autorisés, grenache dominant.'],
  ['Tavel', 'Rhône', 'Rosé de gastronomie, uniquement en rosé.'],
  ['Vouvray', 'Loire', 'Appellation de Touraine sur tuffeau, dédiée au chenin blanc, du sec au moelleux et en fines bulles.'],
  ['Montlouis-sur-Loire', 'Loire', 'Chenin blanc en face de Vouvray, sur la rive gauche.'],
  ['Saumur-Champigny', 'Loire', 'Rouges de cabernet franc sur tuffeau, en Anjou-Saumur.'],
  ['Chinon', 'Loire', 'Cabernet franc de Touraine, sur graviers et tuffeau.'],
  ['Bourgueil', 'Loire', 'Cabernet franc de Touraine, rouges de garde moyenne.'],
  ['Sancerre', 'Loire', 'Sauvignon blanc sur silex et terres blanches.'],
  ['Savennières', 'Loire', 'Chenin sec sur schistes, en Anjou.'],
  ['Muscadet Sèvre et Maine', 'Loire', 'Melon de Bourgogne élevé sur lies, près de Nantes.'],
  ['Champagne', 'Champagne', 'Vins effervescents par seconde fermentation en bouteille. Chardonnay, pinot noir et meunier.'],
  ['Alsace Grand Cru', 'Alsace', 'Cinquante et un lieux-dits classés en Alsace. Cépages nobles : riesling, gewurztraminer, pinot gris, muscat.'],
  ['Bandol', 'Provence', 'Appellation provençale en restanques autour de Bandol. Le mourvèdre y domine ; rosés de gastronomie et rouges de garde.'],
  ['Palette', 'Provence', 'Petite appellation près d’Aix-en-Provence, sur éboulis calcaires.'],
  ['Côtes de Provence', 'Provence', 'Vaste appellation provençale, majoritairement en rosé.'],
  ['Morgon', 'Beaujolais', 'Cru du Beaujolais sur roches décomposées, gamay charpenté.'],
  ['Fleurie', 'Beaujolais', 'Cru du Beaujolais sur granit rose, gamay floral.'],
  ['Cahors', 'Sud-Ouest', 'Malbec du Lot, rouges sombres et tanniques.'],
  ['Madiran', 'Sud-Ouest', 'Tannat du Béarn, rouges puissants.'],
  ['Arbois', 'Jura', 'Appellation du Jura : savagnin, vin jaune élevé sous voile, poulsard et trousseau.'],
  ['Côtes du Roussillon', 'Roussillon', 'Appellation catalane du sud de la France, schistes et granites.'],
  ['Banyuls', 'Roussillon', 'Vin doux naturel de grenache, sur les schistes de la Côte Vermeille.'],
];

const DOMAINES = {
  'Château Margaux': 'Premier grand cru classé en 1855. Domaine de 82 ha de vignes, dont une partie en blanc (Pavillon blanc).',
  'Château Léoville Barton': 'Deuxième grand cru classé de Saint-Julien, propriété de la famille Barton depuis 1826.',
  'Château Pontet-Canet': 'Cinquième grand cru classé de Pauillac, en biodynamie.',
  'Château Figeac': 'Premier grand cru classé de Saint-Émilion, sur graves.',
  'Domaine de Chevalier': 'Cru classé de Graves, à Léognan, rouge et blanc.',
  'Domaine Leflaive': 'Domaine familial de Puligny-Montrachet, en biodynamie depuis les années 1990.',
  'Domaine Roulot': 'Domaine de Meursault réputé pour la précision de ses blancs.',
  'Domaine Raveneau': 'Domaine de référence de Chablis, premiers et grands crus.',
  'Domaine Bonneau du Martray': 'Domaine historique de la colline de Corton.',
  'Domaine Denis Mortet': 'Domaine de Gevrey-Chambertin, pinots noirs denses.',
  'Domaine des Comtes Lafon': 'Domaine de Meursault, également à Volnay.',
  'E. Guigal': 'Maison d’Ampuis fondée en 1946 ; célèbre pour ses « La La » de Côte-Rôtie.',
  'Domaine Jamet': 'Domaine familial d’Ampuis, Côte-Rôtie classique.',
  'Domaine Jean-Louis Chave': 'Famille de vignerons à Mauves depuis 1481, référence de l’Hermitage.',
  'Domaine Thierry Allemand': 'Petit domaine de Cornas, vinifications sans soufre.',
  'Domaine Gonon': 'Domaine de Mauves, Saint-Joseph de vieilles vignes.',
  'Alain Graillot': 'Domaine de Crozes-Hermitage fondé en 1985.',
  'Clos des Papes': 'Domaine de la famille Avril à Châteauneuf-du-Pape.',
  'Château d’Aqueria': 'Domaine historique de Tavel.',
  'Domaine Huet': 'Référence de Vouvray, trois lieux-dits : Le Haut-Lieu, Le Mont, Clos du Bourg.',
  'François Chidaine': 'Vigneron de Montlouis, chenins en biodynamie.',
  'Clos Rougeard': 'Domaine mythique de Chacé, cabernet franc de garde.',
  'Charles Joguet': 'Domaine de Sazilly, Chinon de lieux-dits.',
  'Domaine de la Butte': 'Domaine de Bourgueil sur coteau.',
  'François Cotat': 'Vigneron de Chavignol, Sancerre de longue garde.',
  'Nicolas Joly': 'Coulée de Serrant, monopole en biodynamie.',
  'Domaine de la Pépière': 'Domaine de Maisdon-sur-Sèvre, muscadets de terroir.',
  'Bollinger': 'Maison de Champagne à Aÿ, fondée en 1829. Vinification partielle sous bois.',
  'Billecart-Salmon': 'Maison familiale de Mareuil-sur-Aÿ.',
  'Domaine Weinbach': 'Domaine de Kaysersberg, au pied du Schlossberg, conduit par la famille Faller.',
  'Domaine Tempier': 'Domaine historique de Bandol, maison de la famille Peyraud.',
  'Château Simone': 'Domaine familial, presque toute l’appellation Palette.',
  'Clos Cibonne': 'Domaine du Pradet, spécialiste du tibouren.',
  'Jean Foillard': 'Vigneron de Villié-Morgon, vins naturels.',
  'Domaine Métras': 'Petit domaine de Fleurie.',
  'Clos Triguedina': 'Domaine de Puy-l’Évêque, famille Baldès.',
  'Château Montus': 'Domaine d’Alain Brumont à Madiran.',
  'Domaine Tissot': 'Domaine d’Arbois en biodynamie, vins jaunes et ouillés.',
  'Domaine Gauby': 'Domaine de Calce, sur schistes et calcaires.',
  'Domaine de la Rectorie': 'Domaine de Banyuls, famille Parcé.',
  'Cave du village': '',
};

// [cuvée, domaine, appellation (null = sans appellation), couleur, millésime, à boire avant, quantité, prix, description]
const LIGNES = [
  ['Grand Vin', 'Château Margaux', 'Margaux', 1, 2015, 2045, 3, 650, 'Le grand vin du château : environ 87 % de cabernet sauvignon, élevé 18 à 24 mois en barriques neuves.'],
  ['Pavillon Rouge', 'Château Margaux', 'Margaux', 1, 2018, 2038, 4, 230, 'Second vin du château, plus de merlot.'],
  ['Grand Vin', 'Château Léoville Barton', 'Saint-Julien', 1, 2016, 2040, 6, 95, 'Cabernet sauvignon majoritaire, merlot et cabernet franc ; classique et de grande garde.'],
  ['Grand Vin', 'Château Léoville Barton', 'Saint-Julien', 1, 2019, 2045, 6, 105, null],
  ['Pontet-Canet', 'Château Pontet-Canet', 'Pauillac', 1, 2016, 2042, 6, 140, 'Cabernet sauvignon en biodynamie, élevage en partie en amphores.'],
  ['Château Figeac', 'Château Figeac', 'Saint-Émilion Grand Cru', 1, 2015, 2040, 3, 290, 'Trois tiers : cabernet sauvignon, cabernet franc, merlot.'],
  ['Domaine de Chevalier rouge', 'Domaine de Chevalier', 'Pessac-Léognan', 1, 2018, 2036, 6, 75, null],
  ['La Mouline', 'E. Guigal', 'Côte-Rôtie', 1, 2017, 2026, 2, 420, 'Côte Blonde, syrah co-fermentée avec 11 % de viognier, 42 mois en fûts neufs.'],
  ['Côte-Rôtie', 'Domaine Jamet', 'Côte-Rôtie', 1, 2018, 2034, 3, 110, 'Assemblage de nombreuses parcelles, vendange entière.'],
  ['Hermitage', 'Domaine Jean-Louis Chave', 'Hermitage', 1, 2016, 2040, 2, 380, null],
  ['Chaillot', 'Domaine Thierry Allemand', 'Cornas', 1, 2019, 2037, 2, 160, null],
  ['Vieilles Vignes', 'Domaine Gonon', 'Saint-Joseph', 1, 2020, 2030, 6, 45, null],
  ['Crozes-Hermitage', 'Alain Graillot', 'Crozes-Hermitage', 1, 2021, 2028, 6, 28, null],
  ['Clos des Papes', 'Clos des Papes', 'Châteauneuf-du-Pape', 1, 2019, 2035, 6, 85, null],
  ['Le Bourg', 'Clos Rougeard', 'Saumur-Champigny', 1, 2014, 2025, 1, 180, 'Vieilles vignes de cabernet franc, élevage long en fûts.'],
  ['Clos de la Dioterie', 'Charles Joguet', 'Chinon', 1, 2020, 2032, 6, 40, null],
  ['Mi-Pente', 'Domaine de la Butte', 'Bourgueil', 1, 2019, 2029, 3, 30, null],
  ['Bandol rouge', 'Domaine Tempier', 'Bandol', 1, 2018, 2033, 4, 48, null],
  ['Côte du Py', 'Jean Foillard', 'Morgon', 1, 2021, 2028, 6, 32, null],
  ['Fleurie', 'Domaine Métras', 'Fleurie', 1, 2022, 2027, 4, 35, null],
  ['Vieilles Vignes', 'Domaine Denis Mortet', 'Gevrey-Chambertin', 1, 2019, 2032, 3, 120, null],
  ['Santenots-du-Milieu', 'Domaine des Comtes Lafon', 'Volnay', 1, 2017, 2030, 2, 140, null],
  ['Probus', 'Clos Triguedina', 'Cahors', 1, 2016, 2030, 4, 38, null],
  ['Montus', 'Château Montus', 'Madiran', 1, 2015, 2026, 4, 45, null],
  ['Les Pucelles', 'Domaine Leflaive', 'Puligny-Montrachet', 2, 2019, 2031, 4, 310, 'Premier cru voisin du Bâtard-Montrachet. Chardonnay floral, tendu, de longue garde.'],
  ['Le Haut-Lieu sec', 'Domaine Huet', 'Vouvray', 2, 2020, 2032, 3, 29, 'Chenin blanc du premier lieu-dit du domaine, argiles et calcaire.'],
  ['Le Mont sec', 'Domaine Huet', 'Vouvray', 2, 2019, 2030, 3, 32, null],
  ['Riesling Schlossberg', 'Domaine Weinbach', 'Alsace Grand Cru', 2, 2021, 2036, 4, 48, 'Granit du Schlossberg, riesling ciselé et minéral.'],
  ['Gewurztraminer Furstentum', 'Domaine Weinbach', 'Alsace Grand Cru', 2, 2020, 2028, 3, 42, null],
  ['Meursault', 'Domaine Roulot', 'Meursault', 2, 2020, 2026, 2, 140, null],
  ['Montée de Tonnerre', 'Domaine Raveneau', 'Chablis', 2, 2019, 2033, 3, 160, null],
  ['Corton-Charlemagne', 'Domaine Bonneau du Martray', 'Corton-Charlemagne', 2, 2018, 2032, 2, 220, null],
  ['Les Monts Damnés', 'François Cotat', 'Sancerre', 2, 2022, 2030, 6, 35, null],
  ['Clos de la Coulée de Serrant', 'Nicolas Joly', 'Savennières', 2, 2018, 2035, 2, 95, null],
  ['La Doriane', 'E. Guigal', 'Condrieu', 2, 2021, 2027, 3, 85, null],
  ['Domaine de Chevalier blanc', 'Domaine de Chevalier', 'Pessac-Léognan', 2, 2017, 2032, 3, 120, null],
  ['Clos des Briords', 'Domaine de la Pépière', 'Muscadet Sèvre et Maine', 2, 2022, 2027, 6, 15, null],
  ['Les Choisilles', 'François Chidaine', 'Montlouis-sur-Loire', 2, 2021, 2029, 2, 25, null],
  ['Special Cuvée', 'Bollinger', 'Champagne', 4, 2019, null, 6, 58, 'Brut sans année, majorité de pinot noir, vins de réserve élevés en magnum.'],
  ['La Grande Année', 'Bollinger', 'Champagne', 4, 2014, 2034, 3, 150, null],
  ['Brut Rosé', 'Billecart-Salmon', 'Champagne', 4, 2020, 2028, 3, 85, null],
  ['Pétillant', 'Domaine Huet', 'Vouvray', 4, 2017, 2030, 6, 28, null],
  ['Bandol rosé', 'Domaine Tempier', 'Bandol', 3, 2023, 2025, 2, 32, 'Assemblage de mourvèdre, grenache et cinsault. Rosé de repas, à boire dans ses deux ou trois ans.'],
  ['Palette rosé', 'Château Simone', 'Palette', 3, 2022, 2027, 2, 45, null],
  ['Tavel', 'Château d’Aqueria', 'Tavel', 3, 2023, 2026, 4, 18, null],
  ['Tibouren', 'Clos Cibonne', 'Côtes de Provence', 3, 2022, 2026, 4, 26, null],
  ['Vin jaune', 'Domaine Tissot', 'Arbois', 5, 2015, 2050, 2, 55, null],
  ['Rimage', 'Domaine de la Rectorie', 'Banyuls', 5, 2019, 2040, 3, 30, null],
  ['Les Calcinaires', 'Domaine Gauby', 'Côtes du Roussillon', 0, 2021, null, 1, 24, null],
  ['Cuvée de la maison', 'Cave du village', null, 0, 2020, null, 2, 9, null],
];

const COMMENTAIRES = [
  'Superbe, encore jeune, à carafer 2 h',
  'Un peu fatigué, à boire vite',
  'Bulles fines, parfait à l’apéritif',
  '',
  'Grand vin, fruit et fumé, longue finale',
  'Tendu, citronné, belle minéralité',
  'Très bon avec un gigot',
  'Bouchonné, dommage',
  '',
  'Fruit éclatant, tanins soyeux',
  'Encore fermé, attendre 3 ans',
  'Belle surprise pour le prix',
];

export function creerDonnees() {
  const alea = prng(20261018);
  const tagsVus = new Set();
  const tag = () => {
    let t;
    do t = '04' + Math.floor(alea() * 0xffffff).toString(16).toUpperCase().padStart(6, '0');
    while (tagsVus.has(t));
    tagsVus.add(t);
    return t;
  };

  const appellations = APPELLATIONS.map(([nom, region, description], i) => ({
    id: i + 1,
    nom,
    region,
    description,
    image: null,
  }));
  const appParNom = new Map(appellations.map((a) => [a.nom, a]));

  const domaines = Object.entries(DOMAINES).map(([nom, description], i) => ({ id: i + 1, nom, description }));
  const domParNom = new Map(domaines.map((d) => [d.nom, d]));

  const cuvees = [];
  const cuvParCle = new Map();
  const bouteilles = [];
  const maintenant = Date.now();
  const JOUR = 86400000;
  let idB = 1;

  for (const [nomCuvee, nomDomaine, nomApp, couleur, millesime, aBoire, qte, prix, desc] of LIGNES) {
    const cle = `${nomCuvee}|${nomDomaine}`;
    let cuvee = cuvParCle.get(cle);
    if (!cuvee) {
      cuvee = {
        id: cuvees.length + 1,
        nom: nomCuvee,
        domaine_id: domParNom.get(nomDomaine).id,
        appellation_id: nomApp ? appParNom.get(nomApp).id : 0,
        couleur,
        description: desc ?? '',
      };
      cuvees.push(cuvee);
      cuvParCle.set(cle, cuvee);
    }
    const entree = new Date(maintenant - Math.floor(200 + alea() * 1800) * JOUR);
    entree.setUTCHours(9 + Math.floor(alea() * 10), 0, 0, 0);
    for (let i = 0; i < qte; i++) {
      bouteilles.push({
        id: idB++,
        tag_id: tag(),
        cuvee_id: cuvee.id,
        millesime,
        commentaire: '',
        prix,
        a_boire_avant: aBoire,
        entree_le: entree.toISOString(),
        consommee_le: null,
      });
    }
  }

  // Historique : 64 bouteilles consommées, de la plus récente à la plus ancienne.
  const ecarts = [4, 9, 16, 21, 29, 42];
  for (let i = 0; i < 64; i++) {
    const ligne = LIGNES[(i * 7) % LIGNES.length];
    const cuvee = cuvParCle.get(`${ligne[0]}|${ligne[1]}`);
    const jours = i < ecarts.length ? ecarts[i] : 42 + (i - 5) * 9;
    const conso = new Date(maintenant - jours * JOUR);
    conso.setUTCHours(18 + (i % 3), 30, 0, 0);
    const entree = new Date(conso.getTime() - Math.floor(300 + alea() * 1500) * JOUR);
    bouteilles.push({
      id: idB++,
      tag_id: null,
      cuvee_id: cuvee.id,
      millesime: ligne[4] - 2,
      commentaire: COMMENTAIRES[i % COMMENTAIRES.length],
      prix: ligne[7],
      a_boire_avant: ligne[5],
      entree_le: entree.toISOString(),
      consommee_le: conso.toISOString(),
    });
  }

  return { appellations, domaines, cuvees, bouteilles, reglages: { assistant: 'claude' } };
}
