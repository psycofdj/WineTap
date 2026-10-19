<script>
  // Interrupteur : libellé court, état allumé ou éteint. Deux dispositions : barre d'outils
  // (ordinateur, interrupteur puis libellé) et ligne de réglage (téléphone, libellé à gauche,
  // interrupteur plus grand à droite, toute la largeur).

  /**
   * @type {{ actif?: boolean, libelle: string, titre?: string, ligne?: boolean,
   *   onchange?: (v: boolean) => void }}
   */
  let { actif = $bindable(false), libelle, titre, ligne = false, onchange } = $props();
</script>

<button
  type="button"
  role="switch"
  aria-checked={actif}
  class="interrupteur"
  class:ligne
  title={titre}
  onclick={() => {
    actif = !actif;
    onchange?.(actif);
  }}
>
  {#if ligne}<span class="libelle">{libelle}</span>{/if}
  <span class="piste" class:actif><span class="bouton"></span></span>
  {#if !ligne}{libelle}{/if}
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
    --l: 30px;
    --h: 18px;
  }
  .interrupteur.ligne {
    width: 100%;
    height: auto;
    min-height: 52px;
    padding: 0 16px;
    font-size: 16px;
    justify-content: space-between;
    border-radius: 0;
    --l: 46px;
    --h: 28px;
  }
  .libelle {
    text-align: left;
  }
  .piste {
    position: relative;
    width: var(--l);
    height: var(--h);
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
    width: calc(var(--h) - 4px);
    height: calc(var(--h) - 4px);
    border-radius: 999px;
    background: var(--wt-card);
    box-shadow: 0 1px 2px rgba(42, 29, 21, 0.3);
    transition: transform var(--t-micro, 150ms) var(--ease, ease);
  }
  .piste.actif .bouton {
    transform: translateX(calc(var(--l) - var(--h)));
  }
  @media (prefers-reduced-motion: reduce) {
    .piste,
    .bouton {
      transition: none;
    }
  }
</style>
