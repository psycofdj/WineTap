<script>
  // En-tête des sous-pages du téléphone : hauteur 52, retour de 44, titre 17 / 600, action à droite.
  import { routeur } from '../lib/routeur.svelte.js';
  import Icon from './Icon.svelte';

  /**
   * @type {{ titre?: string, sousTitre?: string, retour?: string, onretour?: () => void,
   *   action?: string, onaction?: () => void, actionDesactivee?: boolean, marge?: number }}
   */
  let { titre = '', sousTitre = '', retour = '/', onretour, action = '', onaction, actionDesactivee = false, marge = 12 } = $props();
</script>

<header class="entete" style:margin="0 -{marge}px">
  <button type="button" class="retour" aria-label="Retour" onclick={() => (onretour ? onretour() : routeur.retour(retour))}>
    <Icon nom="chevL" taille={24} />
  </button>
  <span class="titres">
    {#if titre}<span class="titre">{titre}</span>{/if}
    {#if sousTitre}<span class="sous">{sousTitre}</span>{/if}
  </span>
  {#if action}
    <button type="button" class="action" disabled={actionDesactivee} onclick={onaction}>{action}</button>
  {/if}
</header>

<style>
  .entete {
    display: flex;
    align-items: center;
    height: 52px;
    gap: 2px;
    flex: none;
  }
  .retour {
    width: 44px;
    height: 44px;
    border: 0;
    background: transparent;
    color: var(--wt-ink);
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 12px;
    flex: none;
  }
  .titres {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
  }
  .titre {
    font-size: 17px;
    font-weight: 600;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .sous {
    font-size: 12px;
    color: var(--wt-ink3);
  }
  .action {
    height: 44px;
    border: 0;
    background: transparent;
    color: var(--wt-accent-ink);
    font-size: 16px;
    font-weight: 600;
    padding: 0 12px;
  }
  .action:disabled {
    opacity: 0.5;
  }
</style>
