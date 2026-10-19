// « Demander à l'IA » : ouvre Claude ou ChatGPT avec une question préparée (D-12 de la v2).

import { ctx } from './contexte.svelte.js';
import { reglages } from './stores/reglages.svelte.js';

// Les questions reprennent celles du manager v2 : même structure de réponse, mêmes sources.

const SOURCES = `Tu peux chercher sur des sites web de critique de vin tels que vivino, vinsolite, buveurdevin ou autre.`;

const TEXTE_SEUL = `Dans ta réponse :
- n'affiche que du texte
- supprime les balises de citation
- supprime les titres de paragraphes`;

export function questionAppellation(nom) {
  return `Tu es un expert en vins français.
Rédige une courte description (3 à 4 phrases) de l'appellation « ${nom} » : caractéristiques gustatives et géographiques. Je veux aussi la région viticole associée.

${SOURCES}

${TEXTE_SEUL}

Donne-moi aussi une image d'une carte pour situer géographiquement cette appellation.`;
}

export function questionDomaine(nom) {
  return `Tu es un expert en vins français.
Rédige une courte description (3 à 4 phrases) du domaine viticole « ${nom} » : appellations, style des vins, réputation.
${SOURCES}
Je veux aussi l'adresse postale et le numéro de téléphone.
Réponds-moi sous forme de 3 paragraphes séparés par deux sauts de ligne :
- description du domaine
- description des méthodes de production
- adresse et téléphone
Ne mets pas d'intitulé de paragraphe ni de lien : je veux pouvoir copier-coller ta réponse sans avoir de liens web.`;
}

/**
 * @param {string} nom
 * @param {string} [domaine]
 * @param {string} [appellation]
 * @param {string} [couleur]  libellé de la couleur (Rouge, Blanc…)
 */
export function questionCuvee(nom, domaine, appellation, couleur) {
  const precisions = [
    domaine && `du domaine « ${domaine} »`,
    appellation && `de l'appellation « ${appellation} »`,
    couleur && `en « ${couleur} »`,
  ]
    .filter(Boolean)
    .join(' ');
  return `Tu es un expert en vins français. Fais des recherches sur internet, puis rédige un court résumé à propos de la cuvée « ${nom} » ${precisions}.

Réponds en 6 paragraphes :
- présentation de la cuvée : style de vin (léger, corsé, etc.), bio/naturel/sans sulfites ou pas, type d'élevage (fût de chêne, acier, etc.), cépages utilisés et autres faits saillants.
- présentation du nez : concis : les arômes dominants.
- présentation en bouche : concis : l'attaque, la bouche et la finale.
- présentation des accords à table : concis : quels types de plats et la température de service idéale.
- présentation de la garde : concis, peu d'explication : une fourchette d'années pour atteindre le pic de maturité, et une fourchette d'années pour la garde maximale.
- prix d'une bouteille : concis, sans explication, juste une fourchette de prix en euros.

${SOURCES}

${TEXTE_SEUL}`;
}

/** Ouvre l'assistant choisi dans les réglages ; renvoie son nom. */
export function demanderIA(question) {
  const url =
    reglages.assistant === 'chatgpt'
      ? `https://chatgpt.com/?q=${encodeURIComponent(question)}`
      : `https://claude.ai/new?q=${encodeURIComponent(question)}`;
  if (ctx.pont?.openExternal) ctx.pont.openExternal(url);
  else window.open(url, '_blank', 'noopener');
  return reglages.nomAssistant;
}
