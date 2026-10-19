<script>
  /** @type {{ options: Array<{ valeur: string, libelle: string }>, valeur?: string, onchange?: (v: string) => void, label?: string }} */
  let { options, valeur = $bindable(), onchange, label = '' } = $props();
</script>

<div class="seg" role="tablist" aria-label={label} style:grid-template-columns="repeat({options.length}, 1fr)">
  {#each options as o (o.valeur)}
    <button
      type="button"
      role="tab"
      aria-selected={valeur === o.valeur}
      class:actif={valeur === o.valeur}
      onclick={() => {
        valeur = o.valeur;
        onchange?.(o.valeur);
      }}>{o.libelle}</button
    >
  {/each}
</div>

<style>
  .seg {
    display: grid;
    background: var(--wt-card2);
    border-radius: 12px;
    padding: 3px;
    gap: 3px;
  }
  button {
    height: 40px;
    border: 0;
    border-radius: 10px;
    background: transparent;
    color: var(--wt-ink2);
    font-size: 14px;
    font-weight: 600;
    transition: background-color var(--t-micro) var(--ease);
  }
  .actif {
    background: var(--wt-card);
    color: var(--wt-ink);
    box-shadow: 0 1px 3px rgba(42, 29, 21, 0.12);
  }
</style>
