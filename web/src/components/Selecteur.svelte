<script>
  // Sélecteur Couleur / Appellation / Région du tableau de bord (groupe radio compact).
  /**
   * @type {{ options: Array<{ valeur: string, libelle: string }>, valeur?: string, label: string,
   *   onchange?: (v: string) => void }}
   */
  let { options, valeur = $bindable(), label, onchange } = $props();
</script>

<div class="sel" role="radiogroup" aria-label={label}>
  {#each options as o (o.valeur)}
    <button
      type="button"
      role="radio"
      aria-checked={valeur === o.valeur}
      class:on={valeur === o.valeur}
      onclick={() => {
        valeur = o.valeur;
        onchange?.(o.valeur);
      }}>{o.libelle}</button
    >
  {/each}
</div>

<style>
  .sel {
    display: flex;
    flex: none;
    gap: 2px;
    padding: 2px;
    border-radius: 8px;
    background: var(--wt-card2);
  }
  button {
    height: 26px;
    border: 0;
    border-radius: 6px;
    padding: 0 10px;
    background: transparent;
    color: var(--wt-ink2);
    font-size: 12.5px;
    font-weight: 600;
    transition: background-color var(--t-micro) var(--ease);
  }
  .on {
    background: var(--wt-card);
    color: var(--wt-ink);
    box-shadow: 0 1px 2px rgba(42, 29, 21, 0.14);
  }
  :global(.telephone) .sel {
    border-radius: 10px;
  }
  :global(.telephone) button {
    height: 36px;
    border-radius: 8px;
    padding: 0 12px;
    font-size: 13.5px;
  }
</style>
