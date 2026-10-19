import { mount } from 'svelte';
import './app.css';

async function demarrer() {
  // Développement : pont de l'application simulé (?app) et simulation du téléphone.
  if (import.meta.env.DEV) {
    const { preparerDev } = await import('./dev/dev.js');
    await preparerDev();
  }
  const { default: App } = await import('./App.svelte');
  mount(App, { target: /** @type {HTMLElement} */ (document.getElementById('app')) });
}

demarrer();
