<script>
  // Image en grand (carte d'une appellation), par-dessus tout le reste, sur téléphone comme sur
  // ordinateur. Échap, le bouton ou un clic hors de l'image ferment.
  // Le voile est rattaché à <body> : ouverte depuis une fenêtre (Modal, Sheet), la visionneuse n'est
  // ni coupée par elle, ni fermée avec elle par Échap.
  import { onMount } from 'svelte';
  import { fade, scale } from 'svelte/transition';
  import { quintOut } from 'svelte/easing';
  import Icon from './Icon.svelte';

  /** @type {{ src: string, alt: string, onfermer: () => void }} */
  let { src, alt, onfermer } = $props();

  let fermer = /** @type {HTMLButtonElement} */ ($state());

  /** Déplace le nœud dans <body>. */
  function portail(node) {
    document.body.appendChild(node);
    return { destroy: () => node.remove() };
  }

  onMount(() => {
    const precedent = /** @type {HTMLElement|null} */ (document.activeElement);
    fermer.focus();
    return () => precedent?.focus?.();
  });

  function clavier(e) {
    // Rien ne passe aux raccourcis de l'écran ni à la fenêtre du dessous.
    e.stopPropagation();
    if (e.key === 'Escape') {
      e.preventDefault();
      onfermer();
    } else if (e.key === 'Tab') {
      e.preventDefault();
      fermer.focus();
    }
  }
</script>

<div
  use:portail
  class="voile"
  role="dialog"
  aria-modal="true"
  aria-label={alt}
  tabindex="-1"
  onclick={onfermer}
  onkeydown={clavier}
  transition:fade={{ duration: 180 }}
>
  <img {src} {alt} onclick={(e) => e.stopPropagation()} role="presentation" transition:scale={{ start: 0.96, duration: 260, easing: quintOut }} />
  <button bind:this={fermer} type="button" class="fermer" aria-label="Fermer" onclick={onfermer}><Icon nom="x" taille={22} /></button>
</div>

<style>
  .voile {
    position: fixed;
    inset: 0;
    z-index: 50;
    background: rgba(20, 14, 10, 0.82);
    display: flex;
    align-items: center;
    justify-content: center;
    padding: max(56px, env(safe-area-inset-top)) 16px max(24px, env(safe-area-inset-bottom));
    outline: none;
    cursor: zoom-out;
  }
  img {
    max-width: 100%;
    max-height: 100%;
    object-fit: contain;
    border-radius: 12px;
    background: var(--wt-paper);
    box-shadow: 0 30px 80px rgba(0, 0, 0, 0.35);
    cursor: default;
  }
  .fermer {
    position: absolute;
    top: max(12px, env(safe-area-inset-top));
    right: 12px;
    width: 40px;
    height: 40px;
    border-radius: 999px;
    border: 0;
    background: rgba(255, 255, 255, 0.14);
    color: #fff;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
  }
  .fermer:hover,
  .fermer:focus-visible {
    background: rgba(255, 255, 255, 0.26);
  }
</style>
