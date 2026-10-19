(function () {
  const G = {
    ballon: { glass: 'M4.5 2h11c.3 6.5-2 9.5-5.5 9.5S4.2 8.5 4.5 2zM10 11.5V17M6.5 17.5h7', liquid: 'M4.8 6h10.4c-.4 3.8-2.4 5.5-5.2 5.5S5.2 9.8 4.8 6z' },
    tulipe: { glass: 'M6 1.5h8c.8 4 .6 6.5-.4 8.2-.8 1.3-2.1 1.8-3.6 1.8s-2.8-.5-3.6-1.8C5.4 8 5.2 5.5 6 1.5zM10 11.5V17M6.5 17.5h7', liquid: 'M5.9 6h8.2c-.1 1.6-.3 2.8-.9 3.7-.7 1.2-1.8 1.8-3.2 1.8s-2.5-.6-3.2-1.8C6.2 8.8 6 7.6 5.9 6z' },
    flute: { glass: 'M7.5 1h5l-.4 8.6c-.1 1.4-1 2.2-2.1 2.2s-2-.8-2.1-2.2zM10 11.8V17.2M7 17.5h6M9.4 7.4h.01M10.6 5.6h.01', liquid: 'M7.65 4h4.7l-.3 5.6c-.1 1.3-.9 2-2.05 2s-1.95-.7-2.05-2z' },
    copita: { glass: 'M7 5h6c.4 3.5-.8 5.8-3 5.8S6.6 8.5 7 5zM10 10.8V17M7 17.5h6', liquid: 'M7.05 7h5.9c-.2 2.3-1.3 3.8-2.95 3.8S7.25 9.3 7.05 7z' },
    inconnue: { glass: 'M6 1.5h8c.8 4 .6 6.5-.4 8.2-.8 1.3-2.1 1.8-3.6 1.8s-2.8-.5-3.6-1.8C5.4 8 5.2 5.5 6 1.5zM10 11.5V17M6.5 17.5h7M8.7 4.6a1.3 1.3 0 1 1 1.9 1.2c-.4.2-.6.5-.6.9M10 8.6h.01', liquid: '' },
  };
  const W = {
    rouge: { key: 'rouge', label: 'Rouge', fill: '#6E1A2B', hex: '#6E1A2B', ...G.ballon, shape: 'Verre ballon' },
    blanc: { key: 'blanc', label: 'Blanc', fill: '#E3C04F', hex: '#E3C04F', ...G.tulipe, shape: 'Verre tulipe' },
    rose: { key: 'rose', label: 'Rosé', fill: '#EC9AA8', hex: '#EC9AA8', ...G.tulipe, shape: 'Verre tulipe' },
    eff: { key: 'eff', label: 'Effervescent', fill: '#EFE0A0', hex: '#EFE0A0', ...G.flute, shape: 'Flûte, bulles' },
    autre: { key: 'autre', label: 'Autre', fill: '#B5762A', hex: '#B5762A', ...G.copita, shape: 'Petit verre' },
    inconnue: { key: 'inconnue', label: 'Inconnue', fill: 'transparent', hex: 'aucune', ...G.inconnue, shape: 'Verre vide, ?' },
  };
  const GARDE = {
    over: { label: 'dépassée', bg: 'var(--wt-danger-tint)', fg: 'var(--wt-danger)', show: true },
    year: { label: 'cette année', bg: 'var(--wt-warn-tint)', fg: 'var(--wt-warn)', show: true },
    ok: { label: '', bg: 'transparent', fg: 'var(--wt-ink2)', show: false },
    none: { label: '', bg: 'transparent', fg: 'var(--wt-ink3)', show: false },
  };
  const CUV = {
    'Grand Vin|Château Margaux': 'Le grand vin du château : environ 87 % de cabernet sauvignon, élevé 18 à 24 mois en barriques neuves.',
    'Les Pucelles|Domaine Leflaive': 'Premier cru voisin du Bâtard-Montrachet. Chardonnay floral, tendu, de longue garde.',
    'Bandol rosé|Domaine Tempier': 'Assemblage de mourvèdre, grenache et cinsault. Rosé de repas, à boire dans ses deux ou trois ans.',
    'Special Cuvée|Bollinger': 'Brut sans année, majorité de pinot noir, vins de réserve élevés en magnum.',
    'Le Haut-Lieu sec|Domaine Huet': 'Chenin blanc du premier lieu-dit du domaine, argiles et calcaire.',
    'La Mouline|E. Guigal': 'Côte Blonde, syrah co-fermentée avec 11 % de viognier, 42 mois en fûts neufs.',
    'Riesling Schlossberg|Domaine Weinbach': 'Granit du Schlossberg, riesling ciselé et minéral.',
    'Grand Vin|Château Léoville Barton': 'Cabernet sauvignon majoritaire, merlot et cabernet franc ; classique et de grande garde.',
  };
  const DESC = {
    app: {
      'Margaux': 'Appellation du Médoc, rive gauche de la Gironde. Graves profondes, cabernet sauvignon dominant ; vins réputés pour leur finesse.',
      'Puligny-Montrachet': 'Village de la Côte de Beaune, consacré presque entièrement au chardonnay. Blancs tendus, floraux, de grande garde.',
      'Bandol': 'Appellation provençale en restanques autour de Bandol. Le mourvèdre y domine ; rosés de gastronomie et rouges de garde.',
      'Champagne': 'Vins effervescents par seconde fermentation en bouteille. Chardonnay, pinot noir et meunier.',
      'Vouvray': 'Appellation de Touraine sur tuffeau, dédiée au chenin blanc, du sec au moelleux et en fines bulles.',
      'Côte-Rôtie': 'Coteaux très pentus du nord de la vallée du Rhône. Syrah, parfois complétée de viognier.',
      'Alsace Grand Cru': 'Cinquante et un lieux-dits classés en Alsace. Cépages nobles : riesling, gewurztraminer, pinot gris, muscat.',
      'Saint-Julien': 'Commune du Médoc entre Pauillac et Margaux, sans premier cru mais d\u2019une grande régularité.',
      'Meursault': 'Village de la Côte de Beaune connu pour ses blancs amples et beurrés.',
      'Saumur-Champigny': 'Rouges de cabernet franc sur tuffeau, en Anjou-Saumur.',
      'Palette': 'Petite appellation près d\u2019Aix-en-Provence, sur éboulis calcaires.',
      'Arbois': 'Appellation du Jura : savagnin, vin jaune élevé sous voile, poulsard et trousseau.',
      'Côtes du Roussillon': 'Appellation catalane du sud de la France, schistes et granites.',
    },
    dom: {
      'Château Margaux': 'Premier grand cru classé en 1855. Domaine de 82 ha de vignes, dont une partie en blanc (Pavillon blanc).',
      'Domaine Leflaive': 'Domaine familial de Puligny-Montrachet, en biodynamie depuis les années 1990.',
      'Domaine Tempier': 'Domaine historique de Bandol, maison de la famille Peyraud.',
      'Bollinger': 'Maison de Champagne à Aÿ, fondée en 1829. Vinification partielle sous bois.',
      'Domaine Huet': 'Référence de Vouvray, trois lieux-dits : Le Haut-Lieu, Le Mont, Clos du Bourg.',
      'E. Guigal': 'Maison d\u2019Ampuis fondée en 1946 ; célèbre pour ses « La La » de Côte-Rôtie.',
      'Domaine Weinbach': 'Domaine de Kaysersberg, au pied du Schlossberg, conduit par la famille Faller.',
      'Château Léoville Barton': 'Deuxième grand cru classé de Saint-Julien, propriété de la famille Barton depuis 1826.',
    },
  };
  const raw = [
    ['Grand Vin', 'Château Margaux', 'Margaux', 'Bordeaux', 'rouge', 2015, 2045, 3, 650, '12/03/2024', '04A32BFF'],
    ['Les Pucelles', 'Domaine Leflaive', 'Puligny-Montrachet', 'Bourgogne', 'blanc', 2019, 2031, 4, 310, '02/11/2023', '04B1C0D2'],
    ['Bandol rosé', 'Domaine Tempier', 'Bandol', 'Provence', 'rose', 2023, 2025, 2, 32, '18/06/2024', '04C7E19A'],
    ['Special Cuvée', 'Bollinger', 'Champagne', 'Champagne', 'eff', null, null, 6, 58, '20/12/2024', '04D2F377'],
    ['Le Haut-Lieu sec', 'Domaine Huet', 'Vouvray', 'Loire', 'blanc', 2020, 2032, 3, 29, '05/04/2023', '04E44A10'],
    ['La Mouline', 'E. Guigal', 'Côte-Rôtie', 'Rhône', 'rouge', 2017, 2026, 2, 420, '14/01/2022', '04F09C3B'],
    ['Riesling Schlossberg', 'Domaine Weinbach', 'Alsace Grand Cru', 'Alsace', 'blanc', 2021, 2036, 4, 48, '30/09/2024', '0412AB6E'],
    ['Grand Vin', 'Château Léoville Barton', 'Saint-Julien', 'Bordeaux', 'rouge', 2016, 2040, 6, 95, '10/05/2021', '0423CD81'],
    ['Côte-Rôtie', 'Domaine Jamet', 'Côte-Rôtie', 'Rhône', 'rouge', 2018, 2034, 3, 110, '15/11/2023', '0434EF92'],
    ['Meursault', 'Domaine Roulot', 'Meursault', 'Bourgogne', 'blanc', 2020, 2026, 2, 140, '22/02/2023', '044501A3'],
    ['Le Bourg', 'Clos Rougeard', 'Saumur-Champigny', 'Loire', 'rouge', 2014, 2025, 1, 180, '08/07/2020', '045612B4'],
    ['Palette rosé', 'Château Simone', 'Palette', 'Provence', 'rose', 2022, 2027, 2, 45, '01/06/2024', '046723C5'],
    ['Vin jaune', 'Domaine Tissot', 'Arbois', 'Jura', 'autre', 2015, 2050, 2, 55, '12/12/2022', '047834D6'],
    ['Les Calcinaires', 'Domaine Gauby', 'Côtes du Roussillon', 'Roussillon', 'inconnue', 2021, null, 1, 24, '03/03/2025', '048945E7'],
  ];
  const YEAR = 2026;
  const bottles = raw.map((r, i) => {
    const g = r[6] == null ? 'none' : r[6] < YEAR ? 'over' : r[6] === YEAR ? 'year' : 'ok';
    return {
      id: i, cuvee: r[0], domaine: r[1], appellation: r[2], region: r[3], w: W[r[4]], color: r[4],
      vintage: r[5] || 'NM', vintageLong: r[5] ? String(r[5]) : 'Sans millésime',
      before: r[6] || '—', qty: r[7], qtyLabel: r[7] > 1 ? r[7] + ' bouteilles' : '1 bouteille',
      price: r[8] + ' €', added: r[9], tag: r[10], garde: GARDE[g], gardeKey: g,
      title: r[1] + ' · ' + r[0],
      appDesc: DESC.app[r[2]] || 'Pas de description.', domDesc: DESC.dom[r[1]] || 'Pas de description.',
      cuvDesc: CUV[r[0] + '|' + r[1]] || 'Pas de description.',
    };
  });
  const colors = [
    { w: W.rouge, n: 98 }, { w: W.blanc, n: 46 }, { w: W.eff, n: 18 }, { w: W.rose, n: 12 }, { w: W.autre, n: 5 }, { w: W.inconnue, n: 3 },
  ].map(c => ({ ...c, pct: Math.round(c.n / 182 * 1000) / 10 + '%', width: (c.n / 182 * 100) + '%' }));
  const regions = [['Bordeaux', 52], ['Bourgogne', 34], ['Rhône', 28], ['Loire', 19], ['Champagne', 18], ['Alsace', 14], ['Provence', 9], ['Autres', 8]]
    .map(([name, n]) => ({ name, n, width: (n / 52 * 100) + '%', pct: Math.round(n / 182 * 100) + ' %' }));
  const tastings = [
    { date: '14 oct. 2026', title: 'Château Léoville Barton · Grand Vin', meta: 'Saint-Julien · 2010', w: W.rouge, comment: 'Superbe, encore jeune, à carafer 2 h', has: true },
    { date: '9 oct. 2026', title: 'Domaine Tempier · Bandol rosé', meta: 'Bandol · 2022', w: W.rose, comment: 'Un peu fatigué, à boire vite', has: true },
    { date: '2 oct. 2026', title: 'Bollinger · Special Cuvée', meta: 'Champagne · NM', w: W.eff, comment: 'Bulles fines, parfait à l\u2019apéritif', has: true },
    { date: '27 sept. 2026', title: 'Domaine Huet · Le Haut-Lieu sec', meta: 'Vouvray · 2018', w: W.blanc, comment: '', has: false },
    { date: '19 sept. 2026', title: 'E. Guigal · La Mouline', meta: 'Côte-Rôtie · 2012', w: W.rouge, comment: 'Grand vin, fruit et fumé, longue finale', has: true },
    { date: '6 sept. 2026', title: 'Domaine Weinbach · Riesling Schlossberg', meta: 'Alsace Grand Cru · 2019', w: W.blanc, comment: 'Tendu, citronné, belle minéralité', has: true },
  ];
  const appellations = [
    { name: 'Margaux', region: 'Bordeaux', n: 9 }, { name: 'Saint-Julien', region: 'Bordeaux', n: 6 }, { name: 'Puligny-Montrachet', region: 'Bourgogne', n: 4 },
    { name: 'Meursault', region: 'Bourgogne', n: 2 }, { name: 'Côte-Rôtie', region: 'Rhône', n: 5 }, { name: 'Vouvray', region: 'Loire', n: 3 },
    { name: 'Bandol', region: 'Provence', n: 2 }, { name: 'Champagne', region: 'Champagne', n: 6 }, { name: 'Alsace Grand Cru', region: 'Alsace', n: 4 }, { name: 'Arbois', region: 'Jura', n: 2 },
  ].map(a => ({ ...a, n: bottles.filter(b => b.appellation === a.name).length })).map(a => ({ ...a, sub: a.region + ' · ' + a.n + ' cuvée' + (a.n > 1 ? 's' : ''), desc: DESC.app[a.name] || '', slot: 'carte-' + a.name.normalize('NFD').replace(/[^A-Za-z]/g, '').toLowerCase() }));
  const domaines = [
    ['Château Margaux', 'Margaux', 3], ['Domaine Leflaive', 'Puligny-Montrachet', 2], ['Domaine Tempier', 'Bandol', 2], ['Bollinger', 'Champagne', 2],
    ['Domaine Huet', 'Vouvray', 3], ['E. Guigal', 'Côte-Rôtie', 4], ['Domaine Weinbach', 'Alsace', 3], ['Château Léoville Barton', 'Saint-Julien', 1],
  ].map(([name, place]) => [name, place, bottles.filter(b => b.domaine === name).length]).map(([name, place, n]) => ({ name, place, sub: place + ' · ' + n + ' cuvée' + (n > 1 ? 's' : ''), desc: DESC.dom[name] || '' }));
  const cuvees = bottles.map(b => ({ name: b.cuvee, sub: b.domaine + ' · ' + b.appellation, w: b.w }));
  const I = {
    home: 'M15 21v-8a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v8M3 10a2 2 0 0 1 .709-1.528l7-5.999a2 2 0 0 1 2.582 0l7 5.999A2 2 0 0 1 21 10v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z',
    wine: 'M8 22h8M7 10h10M12 15v7M12 15a5 5 0 0 0 5-5c0-2-.5-4-2-8H9c-1.5 4-2 6-2 8a5 5 0 0 0 5 5Z',
    list: 'M3 12h.01M3 18h.01M3 6h.01M8 12h13M8 18h13M8 6h13',
    book: 'M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2zM22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z',
    sliders: 'M20 7h-9M14 17H5M20 17a3 3 0 1 1-6 0a3 3 0 1 1 6 0M10 7a3 3 0 1 1-6 0a3 3 0 1 1 6 0',
    search: 'M19 11a8 8 0 1 1-16 0a8 8 0 1 1 16 0M21 21l-4.3-4.3',
    plus: 'M5 12h14M12 5v14',
    chevR: 'm9 18 6-6-6-6', chevL: 'm15 18-6-6 6-6', chevD: 'm6 9 6 6 6-6',
    check: 'M20 6 9 17l-5-5', x: 'M18 6 6 18M6 6l12 12',
    pie: 'M21.21 15.89A10 10 0 1 1 8 2.83M22 12A10 10 0 0 0 12 2v10z',
    monitor: 'M4 3h16a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2zM8 21h8M12 17v4',
    phone: 'M7 2h10a2 2 0 0 1 2 2v16a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2zM12 18h.01',
    printer: 'M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2M6 9V3a1 1 0 0 1 1-1h10a1 1 0 0 1 1 1v6M7 14h10a1 1 0 0 1 1 1v6a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1v-6a1 1 0 0 1 1-1z',
    filter: 'M22 3H2l8 9.46V19l4 2v-8.54L22 3z',
    sparkles: 'M9.937 15.5A2 2 0 0 0 8.5 14.063l-6.135-1.582a.5.5 0 0 1 0-.962L8.5 9.936A2 2 0 0 0 9.937 8.5l1.582-6.135a.5.5 0 0 1 .963 0L14.063 8.5A2 2 0 0 0 15.5 9.937l6.135 1.581a.5.5 0 0 1 0 .964L15.5 14.063a2 2 0 0 0-1.437 1.437l-1.582 6.135a.5.5 0 0 1-.963 0z',
    download: 'M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3',
    upload: 'M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M17 8l-5-5-5 5M12 3v12',
    pencil: 'M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z',
    trash: 'M3 6h18M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2',
    alert: 'm21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3M12 9v4M12 17h.01',
    image: 'M5 3h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2zM11 9a2 2 0 1 1-4 0a2 2 0 1 1 4 0M21 15l-3.086-3.086a2 2 0 0 0-2.828 0L6 21',
    layers: 'M12.83 2.18a2 2 0 0 0-1.66 0L2.6 6.08a1 1 0 0 0 0 1.83l8.58 3.91a2 2 0 0 0 1.66 0l8.58-3.9a1 1 0 0 0 0-1.83ZM22 17.65l-9.17 4.16a2 2 0 0 1-1.66 0L2 17.65M22 12.65l-9.17 4.16a2 2 0 0 1-1.66 0L2 12.65',
    wifi: 'M12 20h.01M2 8.82a15 15 0 0 1 20 0M5 12.859a10 10 0 0 1 14 0M8.5 16.429a5 5 0 0 1 7 0',
    wifiOff: 'M12 20h.01M8.5 16.429a5 5 0 0 1 7 0M5 12.859a10 10 0 0 1 5.17-2.69M19 12.859a10 10 0 0 0-2.007-1.523M2 8.82a15 15 0 0 1 4.177-2.643M22 8.82a15 15 0 0 0-11.288-3.764M2 2l20 20',
    sort: 'm21 16-4 4-4-4M17 20V4M3 8l4-4 4 4M7 4v16',
    ext: 'M15 3h6v6M10 14 21 3M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h3',
    msg: 'M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z',
    tag: 'M12.586 2.586A2 2 0 0 0 11.172 2H4a2 2 0 0 0-2 2v7.172a2 2 0 0 0 .586 1.414l8.704 8.704a2.426 2.426 0 0 0 3.42 0l6.58-6.58a2.426 2.426 0 0 0 0-3.42zM7.5 7.5h.01',
    scan: 'M3 7V5a2 2 0 0 1 2-2h2M17 3h2a2 2 0 0 1 2 2v2M21 17v2a2 2 0 0 1-2 2h-2M7 21H5a2 2 0 0 1-2-2v-2M7 12h10',
    nfc: 'M6 8.32a7.43 7.43 0 0 1 0 7.36M9.46 6.21a11.76 11.76 0 0 1 0 11.58M12.91 4.1a15.91 15.91 0 0 1 .01 15.8M16.37 2a20.16 20.16 0 0 1 0 20',
    clock: 'M22 12a10 10 0 1 1-20 0a10 10 0 1 1 20 0M12 6v6l4 2',
    copy: 'M10 8h10a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H10a2 2 0 0 1-2-2V10a2 2 0 0 1 2-2zM4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2',
    shield: 'M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z',
    info: 'M22 12a10 10 0 1 1-20 0a10 10 0 1 1 20 0M12 16v-4M12 8h.01',
    grid: 'M4 3h6a1 1 0 0 1 1 1v6a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1zM14 3h6a1 1 0 0 1 1 1v6a1 1 0 0 1-1 1h-6a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1zM14 13h6a1 1 0 0 1 1 1v6a1 1 0 0 1-1 1h-6a1 1 0 0 1-1-1v-6a1 1 0 0 1 1-1zM4 13h6a1 1 0 0 1 1 1v6a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1v-6a1 1 0 0 1 1-1z',
    minusC: 'M22 12a10 10 0 1 1-20 0a10 10 0 1 1 20 0M8 12h8',
    plusC: 'M22 12a10 10 0 1 1-20 0a10 10 0 1 1 20 0M8 12h8M12 8v8',
    more: 'M12 12h.01M19 12h.01M5 12h.01',
  };
  window.WT = { W, WINES: Object.values(W), GARDE, bottles, colors, regions, tastings, appellations, domaines, cuvees, I, total: 182 };
  window.WT_DARK = {
    '--wt-paper': '#1A1411', '--wt-card': '#241C17', '--wt-card2': '#2F2520', '--wt-line': '#3A2E27', '--wt-line2': '#54443A',
    '--wt-ink': '#F3EADB', '--wt-ink2': '#CDBFAE', '--wt-ink3': '#A8988A',
    '--wt-accent': '#E09AA4', '--wt-on-accent': '#1A1411', '--wt-accent-tint': 'rgba(224,154,164,0.16)', '--wt-accent-ink': '#E9AEB6',
    '--wt-danger': '#F1A097', '--wt-danger-tint': 'rgba(241,160,151,0.14)', '--wt-warn': '#E6B868', '--wt-warn-tint': 'rgba(230,184,104,0.14)',
    '--wt-ok': '#9CCB98', '--wt-ok-tint': 'rgba(156,203,152,0.14)', '--wt-shadow': '0 12px 32px rgba(0,0,0,0.45)',
    display: 'contents',
  };
})();
