// Outils de développement (absents de la construction) :
// - ?app           : simule la WebView de l'application (pont window.winetapBridge, écran N-E4 simulé) ;
// - ?mock_auth=attente : ce navigateur doit être autorisé depuis le panneau « Téléphone simulé » ;
// - ?nodev         : masque le panneau « Téléphone simulé ».

import { mount } from 'svelte';

export async function preparerDev() {
  const p = new URLSearchParams(location.search);

  if (p.get('mock_auth') === 'attente') {
    await fetch('/__mock/politique', { method: 'POST', body: JSON.stringify({ auto: false }) });
    await fetch('/__mock/session', { method: 'POST', body: JSON.stringify({ statut: 'inconnue' }) }).catch(() => {});
  } else if (p.has('mock_auth')) {
    await fetch('/__mock/politique', { method: 'POST', body: JSON.stringify({ auto: true }) });
  }

  if (p.has('app')) {
    const { installerPont } = await import('./pont-simule.js');
    installerPont();
  } else if (!p.has('nodev')) {
    const { default: Panneau } = await import('./TelephoneSimule.svelte');
    const cible = document.createElement('div');
    document.body.appendChild(cible);
    mount(Panneau, { target: cible });
  }
}
