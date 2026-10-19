<script>
  // Bouton assistant à double action (fiches et écrans de création du catalogue) : « Demander à
  // Claude » ouvre l'assistant, « Copier le prompt » met la question dans le presse-papiers. La
  // partie droite ouvre le menu du choix, mémorisé pour la session.
  // Sur téléphone, le bouton est compact ; `children` (le bouton Enregistrer de la barre du haut)
  // fait partie du groupe, pour que le menu s'aligne sur son bord droit sans sortir de l'écran.
  import { ctx } from '../lib/contexte.svelte.js';
  import { reglages } from '../lib/stores/reglages.svelte.js';
  import { assistant } from '../lib/stores/assistant.svelte.js';
  import Icon from './Icon.svelte';

  /** @type {{ question: () => string|null, children?: any }} */
  let { question, children } = $props();

  let menu = $state(false);
  let groupe = /** @type {HTMLElement} */ ($state());

  const nom = $derived(reglages.nomAssistant);
  const libelleAction = $derived(assistant.mode === 'copy' ? 'Copier le prompt' : `Demander à ${nom}`);
  const choix = $derived([
    { mode: /** @type {const} */ ('ask'), libelle: `Demander à ${nom}`, sous: 'Ouvre l’assistant avec la question', icone: 'sparkles' },
    { mode: /** @type {const} */ ('copy'), libelle: 'Copier le prompt', sous: 'Met la question dans le presse-papiers', icone: 'copy' },
  ]);

  function choisir(mode) {
    assistant.choisir(mode);
    menu = false;
  }

  function dehors(e) {
    if (menu && !groupe?.contains(/** @type {Node} */ (e.target))) menu = false;
  }

  function clavier(e) {
    if (menu && e.key === 'Escape') {
      e.preventDefault();
      e.stopPropagation();
      menu = false;
    }
  }
</script>

<svelte:window onpointerdown={dehors} onkeydowncapture={clavier} />

<div class="groupe" class:o={ctx.ordinateur} class:t={!ctx.ordinateur} bind:this={groupe}>
  <div class="divise">
    <button type="button" class="action" aria-label={libelleAction} onclick={() => assistant.agir(question())}>
      {#if assistant.mode === 'copy'}
        <Icon nom="copy" taille={ctx.ordinateur ? 16 : 17} couleur="var(--wt-accent-ink)" />{ctx.ordinateur ? 'Copier le prompt' : 'Prompt'}
      {:else}
        <Icon nom="sparkles" taille={ctx.ordinateur ? 16 : 17} couleur="var(--wt-accent-ink)" />{ctx.ordinateur ? `Demander à ${nom}` : nom}<Icon
          nom="ext"
          taille={13}
          couleur="var(--wt-ink3)"
        />
      {/if}
    </button>
    <button
      type="button"
      class="chevron"
      class:ouvert={menu}
      aria-label="Choisir l'action de l'assistant"
      aria-haspopup="menu"
      aria-expanded={menu}
      onclick={() => (menu = !menu)}
    >
      <Icon nom="chevD" taille={ctx.ordinateur ? 14 : 16} epaisseur={ctx.ordinateur ? 2 : 1.75} />
    </button>
  </div>
  {@render children?.()}
  {#if menu}
    <div class="menu" role="menu">
      {#each choix as c (c.mode)}
        {@const on = assistant.mode === c.mode}
        <button type="button" class="item" class:on role="menuitemradio" aria-checked={on} onclick={() => choisir(c.mode)}>
          <Icon nom={c.icone} taille={ctx.ordinateur ? 16 : 18} couleur="var(--wt-accent-ink)" style="margin-top:{ctx.ordinateur ? 2 : 0}px" />
          <span class="textes"><span class="lib">{c.libelle}</span><span class="sous">{c.sous}</span></span>
          {#if on}<Icon nom="check" taille={ctx.ordinateur ? 16 : 18} epaisseur={ctx.ordinateur ? 2.2 : 1.75} couleur="var(--wt-accent-ink)" style="margin-top:{ctx.ordinateur ? 2 : 0}px" />{/if}
        </button>
      {/each}
    </div>
  {/if}
</div>

<style>
  .groupe {
    position: relative;
    display: flex;
    align-items: center;
    gap: 2px;
  }
  .divise {
    display: flex;
  }
  .action,
  .chevron {
    border: 1px solid var(--wt-line2);
    background: var(--wt-card);
    color: var(--wt-ink);
    display: flex;
    align-items: center;
    white-space: nowrap;
    transition: background-color var(--t-micro) var(--ease);
  }
  .action {
    border-right: 0;
  }
  .chevron {
    justify-content: center;
    padding: 0;
    color: var(--wt-ink2);
  }
  .action:hover,
  .chevron:hover,
  .chevron.ouvert {
    background: var(--wt-card2);
  }
  .menu {
    position: absolute;
    right: 0;
    z-index: 20;
    background: var(--wt-card);
    border: 1px solid var(--wt-line2);
    box-shadow: var(--wt-shadow);
    padding: 4px;
    display: flex;
    flex-direction: column;
    gap: 2px;
    animation: entree var(--t-base) var(--ease);
  }
  .item {
    display: grid;
    border: 0;
    background: transparent;
    text-align: left;
    color: var(--wt-ink);
  }
  .item:hover {
    background: var(--wt-card2);
  }
  .item.on {
    background: var(--wt-accent-tint);
  }
  .textes {
    display: flex;
    flex-direction: column;
    gap: 1px;
  }
  .lib {
    font-weight: 500;
  }
  .sous {
    color: var(--wt-ink3);
  }

  /* Ordinateur : bouton divisé de 34 px. */
  .o .action {
    height: 34px;
    border-radius: 9px 0 0 9px;
    padding: 0 12px;
    gap: 7px;
    font-size: 13.5px;
    font-weight: 500;
  }
  .o .chevron {
    height: 34px;
    width: 28px;
    border-radius: 0 9px 9px 0;
  }
  .o .menu {
    top: 40px;
    width: 270px;
    border-radius: 10px;
  }
  .o .item {
    grid-template-columns: 18px minmax(0, 1fr) 16px;
    gap: 8px;
    align-items: start;
    padding: 8px 10px;
    border-radius: 7px;
  }
  .o .lib {
    font-size: 13.5px;
  }
  .o .sous {
    font-size: 12px;
  }

  /* Téléphone : version compacte dans la barre du haut. */
  .t .action {
    height: 40px;
    border-radius: 12px 0 0 12px;
    padding: 0 10px;
    gap: 6px;
    font-size: 15px;
    font-weight: 600;
  }
  .t .chevron {
    height: 40px;
    width: 36px;
    border-radius: 0 12px 12px 0;
  }
  .t .menu {
    top: 46px;
    width: 280px;
    border-radius: 14px;
  }
  .t .item {
    min-height: 56px;
    grid-template-columns: 20px minmax(0, 1fr) 18px;
    gap: 10px;
    align-items: center;
    padding: 8px 12px;
    border-radius: 10px;
  }
  .t .lib {
    font-size: 15px;
  }
  .t .sous {
    font-size: 13px;
  }

  @keyframes entree {
    from {
      opacity: 0;
      transform: translateY(-4px);
    }
  }
</style>
