// Copie dans le presse-papiers. Sur l'ordinateur, le site est servi en HTTP (C-02) :
// `navigator.clipboard` n'y existe pas. Repli : zone de texte hors écran, sélection, execCommand.

/** @returns {Promise<boolean>} vrai si le texte a été copié */
export async function copierTexte(texte) {
  if (window.isSecureContext && navigator.clipboard?.writeText) {
    try {
      await navigator.clipboard.writeText(texte);
      return true;
    } catch {
      // Refus du navigateur : on tente le repli.
    }
  }
  const precedent = /** @type {HTMLElement|null} */ (document.activeElement);
  const zone = document.createElement('textarea');
  zone.value = texte;
  zone.setAttribute('readonly', '');
  zone.style.position = 'fixed';
  zone.style.top = '-1000px';
  zone.style.left = '0';
  zone.style.opacity = '0';
  document.body.appendChild(zone);
  zone.select();
  let ok = false;
  try {
    ok = document.execCommand('copy');
  } catch {
    ok = false;
  }
  zone.remove();
  precedent?.focus?.();
  return ok;
}
