<script>
  // Miniature de la carte d'une appellation (fiche bouteille) ; un clic l'affiche en grand.
  // Ordinateur 132 × 96, téléphone pleine largeur × 140 ; image recadrée, icône d'agrandissement.
  import { ctx } from '../lib/contexte.svelte.js';
  import { catalogue } from '../lib/stores/catalogue.svelte.js';
  import Icon from './Icon.svelte';
  import Visionneuse from './Visionneuse.svelte';

  /** @type {{ appellation: any }} */
  let { appellation } = $props();

  const src = $derived(catalogue.urlImage(appellation));
  let agrandie = $state(false);
</script>

{#if src}
  <button
    type="button"
    class="vignette"
    class:o={ctx.ordinateur}
    aria-label="Agrandir la carte de l'appellation {appellation.nom}"
    onclick={() => (agrandie = true)}
  >
    <img {src} alt="Carte de l'appellation {appellation.nom}" />
    <span class="loupe"><Icon nom="agrandir" taille={ctx.ordinateur ? 14 : 16} epaisseur={ctx.ordinateur ? 2 : 1.75} /></span>
  </button>
  {#if agrandie}
    <Visionneuse
      {src}
      alt="Carte de l'appellation {appellation.nom}"
      titre={appellation.nom}
      sousTitre={appellation.region}
      onfermer={() => (agrandie = false)}
    />
  {/if}
{/if}

<style>
  .vignette {
    position: relative;
    display: block;
    width: 100%;
    height: 140px;
    flex: none;
    padding: 0;
    border-radius: 12px;
    border: 1px solid var(--wt-line);
    background: var(--wt-paper);
    overflow: hidden;
    cursor: zoom-in;
    transition: border-color var(--t-micro) var(--ease);
  }
  .vignette.o {
    width: 132px;
    height: 96px;
    border-radius: 10px;
  }
  .vignette:hover {
    border-color: var(--wt-accent);
  }
  img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    display: block;
  }
  .loupe {
    position: absolute;
    right: 8px;
    bottom: 8px;
    width: 32px;
    height: 32px;
    border-radius: 8px;
    background: rgba(255, 253, 248, 0.92);
    color: #2a1d15;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .o .loupe {
    right: 6px;
    bottom: 6px;
    width: 24px;
    height: 24px;
    border-radius: 6px;
  }
</style>
