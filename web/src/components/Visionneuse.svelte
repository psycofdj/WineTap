<script>
  // Carte d'appellation en grand, par-dessus tout le reste. Ordinateur : voile sombre, image
  // jusqu'à 640 px, titre au-dessus. Téléphone : plein écran sur fond sombre.
  // Échap, le bouton ou un clic hors de l'image ferment. Le voile est rattaché à <body> : ouverte
  // depuis une fenêtre (Modal, Sheet), la visionneuse n'est ni coupée par elle, ni fermée avec elle
  // par Échap (Échap ferme d'abord la carte).
  import { onMount } from 'svelte';
  import { fade, scale } from 'svelte/transition';
  import { quintOut } from 'svelte/easing';
  import { ctx } from '../lib/contexte.svelte.js';
  import Icon from './Icon.svelte';

  /** @type {{ src: string, alt: string, titre?: string, sousTitre?: string, onfermer: () => void }} */
  let { src, alt, titre = '', sousTitre = '', onfermer } = $props();

  let fermer = /** @type {HTMLButtonElement} */ ($state());
  /** Largeur / hauteur de l'image : la carte tient en entier dans l'écran, en portrait comme en paysage. */
  let ratio = $state(1);

  /** @param {Event} e */
  function chargee(e) {
    const img = /** @type {HTMLImageElement} */ (e.currentTarget);
    if (img.naturalWidth && img.naturalHeight) ratio = img.naturalWidth / img.naturalHeight;
  }

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

{#if ctx.ordinateur}
  <div
    use:portail
    class="voile o"
    role="dialog"
    aria-modal="true"
    aria-label={alt}
    tabindex="-1"
    onclick={onfermer}
    onkeydown={clavier}
    transition:fade={{ duration: 180 }}
  >
    <!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_static_element_interactions -->
    <div class="cadre" onclick={(e) => e.stopPropagation()} transition:scale={{ start: 0.96, duration: 260, easing: quintOut }}>
      <div class="o-tete">
        <span class="o-titre">{titre}{#if sousTitre}<span class="o-sous"> · {sousTitre}</span>{/if}</span>
        <button bind:this={fermer} type="button" class="fermer" aria-label="Fermer" onclick={onfermer}><Icon nom="x" taille={20} /></button>
      </div>
      <img {src} {alt} style:--ratio={ratio} onload={chargee} />
    </div>
  </div>
{:else}
  <div use:portail class="voile t" role="dialog" aria-modal="true" aria-label={alt} tabindex="-1" onkeydown={clavier} transition:fade={{ duration: 180 }}>
    <div class="t-tete">
      <span class="t-titres">
        {#if titre}<span class="t-titre">{titre}</span>{/if}
        {#if sousTitre}<span class="t-sous">{sousTitre}</span>{/if}
      </span>
      <button bind:this={fermer} type="button" class="fermer" aria-label="Fermer" onclick={onfermer}><Icon nom="x" taille={22} /></button>
    </div>
    <!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_static_element_interactions -->
    <div class="t-corps" onclick={onfermer}>
      <img {src} {alt} style:--ratio={ratio} onload={chargee} transition:scale={{ start: 0.96, duration: 260, easing: quintOut }} />
    </div>
  </div>
{/if}

<style>
  .voile {
    position: fixed;
    inset: 0;
    z-index: 50;
    outline: none;
    color: #fffdf8;
  }
  .fermer {
    border: 0;
    background: rgba(255, 253, 248, 0.14);
    color: #fffdf8;
    display: flex;
    align-items: center;
    justify-content: center;
    flex: none;
    cursor: pointer;
  }
  .fermer:hover,
  .fermer:focus-visible {
    background: rgba(255, 253, 248, 0.26);
  }
  img {
    display: block;
    border-radius: 12px;
    background: var(--wt-paper);
  }

  /* Ordinateur */
  .o {
    background: rgba(42, 29, 21, 0.72);
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 32px;
    cursor: zoom-out;
  }
  .cadre {
    position: relative;
    display: flex;
    flex-direction: column;
    gap: 10px;
    max-height: 100%;
    cursor: default;
  }
  .o-tete {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 16px;
  }
  .o-titre {
    font-family: var(--font-serif);
    font-size: 24px;
    font-weight: 500;
  }
  .o-sous {
    font-family: var(--font-sans);
    font-size: 14px;
    opacity: 0.8;
  }
  .o .fermer {
    width: 36px;
    height: 36px;
    border-radius: 8px;
  }
  /* Jusqu'à 640 px de large, sans dépasser l'écran : hauteur disponible = voile (2 × 32 px) moins
     le titre (36 px + 10 px d'écart). */
  .o img {
    width: min(640px, calc(100vw - 64px), calc((100vh - 110px) * var(--ratio)));
    height: auto;
    box-shadow: 0 30px 80px rgba(0, 0, 0, 0.4);
  }

  /* Téléphone */
  .t {
    background: #1c1410;
    display: flex;
    flex-direction: column;
  }
  .t-tete {
    margin-top: env(safe-area-inset-top);
    height: 56px;
    flex: none;
    padding: 0 8px 0 20px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
  }
  .t-titres {
    display: flex;
    flex-direction: column;
    min-width: 0;
  }
  .t-titre {
    font-family: var(--font-serif);
    font-size: 22px;
    font-weight: 500;
    line-height: 1.1;
  }
  .t-sous {
    font-size: 13px;
    opacity: 0.8;
  }
  .t .fermer {
    width: 44px;
    height: 44px;
    border-radius: 12px;
  }
  .t-corps {
    flex: 1;
    min-height: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 16px 16px max(16px, env(safe-area-inset-bottom));
  }
  .t img {
    width: min(100%, calc((100dvh - 88px - env(safe-area-inset-top) - max(16px, env(safe-area-inset-bottom))) * var(--ratio)));
    height: auto;
    max-height: 100%;
    object-fit: contain;
  }
</style>
