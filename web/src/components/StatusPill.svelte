<script>
  // Pastille ronde d'état : en stock, consommée, NFC, connexion.
  import Icon from './Icon.svelte';

  /**
   * @type {{ ton?: 'ok'|'warn'|'danger'|'accent'|'neutre', icone?: string, point?: boolean,
   *   taille?: number, padding?: string, epaisseurIcone?: number, tailleIcone?: number, children: any }}
   */
  let {
    ton = 'ok',
    icone,
    point = false,
    taille = 13,
    padding = '5px 12px',
    epaisseurIcone = 2.2,
    tailleIcone = 16,
    children,
  } = $props();
</script>

<span class="pill {ton}" style:font-size="{taille}px" style:padding>
  {#if point}<span class="point"></span>{/if}
  {#if icone}<Icon nom={icone} taille={tailleIcone} epaisseur={epaisseurIcone} />{/if}
  {@render children()}
</span>

<style>
  .pill {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    border-radius: var(--r-pill);
    font-weight: 600;
    white-space: nowrap;
  }
  .point {
    width: 8px;
    height: 8px;
    border-radius: 99px;
    background: currentColor;
    flex: none;
  }
  .ok {
    background: var(--wt-ok-tint);
    color: var(--wt-ok);
  }
  .warn {
    background: var(--wt-warn-tint);
    color: var(--wt-warn);
  }
  .danger {
    background: var(--wt-danger-tint);
    color: var(--wt-danger);
  }
  .accent {
    background: var(--wt-accent-tint);
    color: var(--wt-accent-ink);
  }
  .neutre {
    background: var(--wt-card2);
    color: var(--wt-ink2);
  }
</style>
