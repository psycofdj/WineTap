<script>
  // Case à cocher de la barre d'outils (ordinateur).
  import Icon from './Icon.svelte';

  /** @type {{ coche?: boolean, libelle: string, onchange?: (v: boolean) => void }} */
  let { coche = $bindable(false), libelle, onchange } = $props();
</script>

<button
  type="button"
  role="checkbox"
  aria-checked={coche}
  class="case"
  onclick={() => {
    coche = !coche;
    onchange?.(coche);
  }}
>
  <span class="boite" class:coche><Icon nom="check" taille={12} epaisseur={3} /></span>{libelle}
</button>

<style>
  .case {
    height: 34px;
    border: 0;
    background: transparent;
    color: var(--wt-ink);
    display: flex;
    align-items: center;
    gap: 7px;
    padding: 0 8px;
    font-size: 13.5px;
    white-space: nowrap;
  }
  .boite {
    width: 16px;
    height: 16px;
    flex: none;
    border-radius: 4px;
    border: 1.5px solid var(--wt-line2);
    background: var(--wt-card);
    color: transparent;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: background-color var(--t-micro) var(--ease);
  }
  .boite.coche {
    border-color: var(--wt-accent);
    background: var(--wt-accent);
    color: var(--wt-on-accent);
  }
</style>
