<script>
  // Bouton de la charte. Variantes : primary, secondary, ghost, danger (texte), danger-plein, sombre.
  // Tailles téléphone : tel-l (56), tel-m (52), tel-s (48) ; ordinateur : ord-l (38), ord-m (36), ord-s (34), ord-xs (30).
  import Icon from './Icon.svelte';
  import Kbd from './Kbd.svelte';

  /**
   * @type {{ variante?: string, taille?: string, icone?: string, tailleIcone?: number, epaisseurIcone?: number,
   *   kbd?: string, pleine?: boolean, disabled?: boolean, type?: 'button'|'submit', onclick?: (e: MouseEvent) => void,
   *   title?: string, 'aria-label'?: string, sousTitre?: string, style?: string, children?: any, element?: HTMLButtonElement }}
   */
  let {
    variante = 'secondary',
    taille = 'ord-m',
    icone,
    tailleIcone,
    epaisseurIcone = 1.75,
    kbd,
    pleine = false,
    disabled = false,
    type = 'button',
    onclick,
    title,
    sousTitre,
    style = '',
    children,
    element = $bindable(),
    ...reste
  } = $props();

  const tIcone = $derived(tailleIcone ?? (taille.startsWith('tel') ? 20 : 16));
</script>

<button
  bind:this={element}
  {type}
  {disabled}
  {onclick}
  {title}
  aria-label={reste['aria-label']}
  class="btn {variante} {taille}"
  class:pleine
  class:avec-sous={!!sousTitre}
  {style}
>
  {#if icone}<Icon nom={icone} taille={tIcone} epaisseur={variante === 'primary' && icone === 'plus' ? 2 : epaisseurIcone} />{/if}
  {#if sousTitre}
    <span class="libelle">{@render children?.()}</span>
    <span class="sous">{sousTitre}</span>
  {:else}
    {@render children?.()}
  {/if}
  {#if kbd}<Kbd touche={kbd} />{/if}
</button>

<style>
  .btn {
    border: 0;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    font-weight: 600;
    white-space: nowrap;
    transition:
      transform var(--t-micro) var(--ease),
      background-color var(--t-micro) var(--ease),
      opacity var(--t-micro);
    -webkit-user-select: none;
    user-select: none;
  }
  .btn:active:not(:disabled) {
    transform: scale(0.97);
  }
  .btn:disabled {
    opacity: 0.5;
  }
  .pleine {
    width: 100%;
  }

  /* Variantes */
  .primary {
    background: var(--wt-accent);
    color: var(--wt-on-accent);
  }
  .secondary {
    background: var(--wt-card);
    color: var(--wt-ink);
    border: 1px solid var(--wt-line2);
  }
  .ghost {
    background: transparent;
    color: var(--wt-accent-ink);
  }
  .discret {
    background: transparent;
    color: var(--wt-ink2);
    font-weight: 500;
  }
  .danger {
    background: var(--wt-card);
    color: var(--wt-danger);
    border: 1px solid var(--wt-line2);
  }
  .danger-texte {
    background: transparent;
    color: var(--wt-danger);
  }
  .danger-plein {
    background: var(--wt-danger);
    color: var(--wt-card);
  }
  .sombre {
    background: var(--wt-ink);
    color: var(--wt-paper);
  }

  /* Tailles téléphone */
  .tel-l {
    height: 56px;
    border-radius: var(--r-xl);
    font-size: 17px;
    padding: 0 20px;
  }
  .tel-m {
    height: 52px;
    border-radius: var(--r-xl);
    font-size: 16px;
    padding: 0 18px;
  }
  .tel-s {
    height: 48px;
    border-radius: var(--r-lg);
    font-size: 15px;
    padding: 0 16px;
  }
  /* Tailles ordinateur */
  .ord-l {
    height: 38px;
    border-radius: 9px;
    font-size: 13.5px;
    padding: 0 16px;
  }
  .ord-m {
    height: 36px;
    border-radius: 9px;
    font-size: 13.5px;
    padding: 0 14px;
  }
  .ord-s {
    height: 34px;
    border-radius: 9px;
    font-size: 13.5px;
    padding: 0 12px;
    gap: 7px;
  }
  .ord-s.secondary {
    font-weight: 500;
  }
  .ord-xs {
    height: 30px;
    border-radius: var(--r-sm);
    font-size: 13px;
    padding: 0 10px;
    gap: 6px;
    font-weight: 400;
  }
  .ord-xs.primary {
    font-weight: 600;
  }

  .avec-sous {
    flex-direction: column;
    gap: 0;
    line-height: 1.2;
  }
  .sous {
    font-size: 12px;
    font-weight: 400;
    opacity: 0.85;
  }
</style>
