// Zone de texte qui s'agrandit avec son contenu, sans barre de défilement. Chromium le fait seul
// (`field-sizing: content`) ; ailleurs (Firefox, Safari), la hauteur suit `scrollHeight`.
// Usage : <textarea use:autoHauteur={valeur}> (le paramètre recalcule après un changement de valeur).

const NATIF = typeof CSS !== 'undefined' && CSS.supports?.('field-sizing', 'content');

/** @param {HTMLTextAreaElement} zone */
export function autoHauteur(zone) {
  if (NATIF) return {};
  let largeur = 0;
  const ajuster = () => {
    zone.style.height = 'auto';
    const bords = zone.offsetHeight - zone.clientHeight;
    zone.style.height = `${zone.scrollHeight + bords}px`;
  };
  const surTaille = () => {
    if (zone.clientWidth === largeur) return;
    largeur = zone.clientWidth;
    ajuster();
  };
  const obs = new ResizeObserver(surTaille);
  obs.observe(zone);
  zone.addEventListener('input', ajuster);
  ajuster();
  return {
    update: () => requestAnimationFrame(ajuster),
    destroy() {
      obs.disconnect();
      zone.removeEventListener('input', ajuster);
    },
  };
}
