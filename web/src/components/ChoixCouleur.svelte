<script>
  // Choix de la couleur d'une cuvée : 6 choix avec leur verre ; l'actif bordé d'accent.
  // Téléphone : grille 2 × 3 ; ordinateur : une ligne.
  import { ORDRE_COULEURS, vin } from '../lib/vins.js';
  import WineGlass from './WineGlass.svelte';

  /** @type {{ couleur?: number, label?: string }} */
  let { couleur = $bindable(0), label = 'Couleur' } = $props();
</script>

<div class="bloc" role="radiogroup" aria-label={label}>
  <span class="label">{label}</span>
  <div class="choix">
    {#each ORDRE_COULEURS as c (c)}
      <button type="button" role="radio" aria-checked={couleur === c} class:actif={couleur === c} onclick={() => (couleur = c)}>
        <WineGlass couleur={c} taille={20} />{vin(c).libelle}
      </button>
    {/each}
  </div>
</div>

<style>
  .bloc {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  .label {
    font-size: 14px;
    font-weight: 600;
  }
  .choix {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 8px;
  }
  button {
    height: 48px;
    border-radius: 12px;
    border: 1.5px solid var(--wt-line2);
    background: var(--wt-card);
    color: var(--wt-ink);
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 0 12px;
    font-size: 15px;
    font-weight: 400;
    transition: border-color var(--t-micro) var(--ease);
  }
  .actif {
    border-color: var(--wt-accent);
    background: var(--wt-accent-tint);
    font-weight: 600;
  }

  :global(.ordinateur) .bloc {
    gap: 5px;
  }
  :global(.ordinateur) .label {
    font-size: 12.5px;
    color: var(--wt-ink2);
  }
  :global(.ordinateur) .choix {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
  }
  :global(.ordinateur) button {
    height: 34px;
    border-radius: 8px;
    gap: 6px;
    padding: 0 10px;
    font-size: 13.5px;
  }
  :global(.ordinateur) button :global(svg) {
    width: 18px;
    height: 18px;
  }
</style>
