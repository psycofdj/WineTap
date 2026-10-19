<script>
  // Interrupteur de la barre d'outils (ordinateur) : libellé court, état allumé ou éteint.

  /** @type {{ actif?: boolean, libelle: string, titre?: string, onchange?: (v: boolean) => void }} */
  let { actif = $bindable(false), libelle, titre, onchange } = $props();
</script>

<button
  type="button"
  role="switch"
  aria-checked={actif}
  class="interrupteur"
  title={titre}
  onclick={() => {
    actif = !actif;
    onchange?.(actif);
  }}
>
  <span class="piste" class:actif><span class="bouton"></span></span>{libelle}
</button>

<style>
  .interrupteur {
    height: 34px;
    border: 0;
    background: transparent;
    color: var(--wt-ink);
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 0 8px;
    font-size: 13.5px;
    white-space: nowrap;
    border-radius: 8px;
  }
  .piste {
    position: relative;
    width: 30px;
    height: 18px;
    flex: none;
    border-radius: 999px;
    background: var(--wt-line2);
    transition: background-color var(--t-micro, 150ms) var(--ease, ease);
  }
  .piste.actif {
    background: var(--wt-accent);
  }
  .bouton {
    position: absolute;
    top: 2px;
    left: 2px;
    width: 14px;
    height: 14px;
    border-radius: 999px;
    background: var(--wt-card);
    box-shadow: 0 1px 2px rgba(42, 29, 21, 0.3);
    transition: transform var(--t-micro, 150ms) var(--ease, ease);
  }
  .piste.actif .bouton {
    transform: translateX(12px);
  }
  @media (prefers-reduced-motion: reduce) {
    .piste,
    .bouton {
      transition: none;
    }
  }
</style>
