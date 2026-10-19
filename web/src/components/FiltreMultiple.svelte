<script>
  // Filtre de colonne à choix multiple (ordinateur) : un bouton au format des autres filtres, et une
  // liste de cases. La liste est placée par rapport à la fenêtre : la zone de la table, qui défile,
  // ne la coupe pas. Échap ou un clic ailleurs la ferment.
  import { tick } from 'svelte';
  import Icon from './Icon.svelte';

  /**
   * @type {{ options: string[], choix?: string[], tous?: string, pluriel?: string, label: string }}
   */
  let { options, choix = $bindable([]), tous = 'Toutes', pluriel = 'choix', label } = $props();

  let ouvert = $state(false);
  let bouton = /** @type {HTMLButtonElement} */ ($state());
  let liste = /** @type {HTMLDivElement} */ ($state());
  let position = $state({ haut: 0, gauche: 0, largeur: 0 });

  const resume = $derived(choix.length === 0 ? tous : choix.length === 1 ? choix[0] : `${choix.length} ${pluriel}`);

  function placer() {
    const r = bouton.getBoundingClientRect();
    position = { haut: r.bottom + 4, gauche: r.left, largeur: Math.max(r.width, 200) };
    return r.bottom > 0 && r.top < innerHeight;
  }

  async function ouvrir() {
    placer();
    ouvert = true;
    await tick();
    liste?.querySelector('button')?.focus();
  }

  function fermer(rendreFocus = false) {
    ouvert = false;
    if (rendreFocus) bouton?.focus();
  }

  function basculer(o) {
    choix = choix.includes(o) ? choix.filter((c) => c !== o) : [...choix, o];
  }

  function clavier(e) {
    // Rien ne passe aux raccourcis de l'inventaire tant que la liste est ouverte.
    e.stopPropagation();
    if (e.key === 'Escape') {
      e.preventDefault();
      fermer(true);
    } else if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
      e.preventDefault();
      const boutons = [...liste.querySelectorAll('button')];
      const i = boutons.indexOf(/** @type {HTMLButtonElement} */ (document.activeElement));
      const j = e.key === 'ArrowDown' ? Math.min(boutons.length - 1, i + 1) : Math.max(0, i - 1);
      boutons[j]?.focus();
    }
  }

  // Le défilement ne remonte pas : écouté en capture, sauf celui de la liste elle-même. La liste
  // suit son bouton (un filtre qui réduit la table fait défiler la zone) ; elle se ferme quand le
  // bouton sort de l'écran.
  $effect(() => {
    if (!ouvert) return;
    const surDefilement = (e) => e.target !== liste && !placer() && fermer();
    window.addEventListener('scroll', surDefilement, true);
    return () => window.removeEventListener('scroll', surDefilement, true);
  });

  function dehors(e) {
    if (ouvert && !liste?.contains(e.target) && !bouton?.contains(e.target)) fermer();
  }
</script>

<svelte:window onpointerdown={dehors} onresize={() => fermer()} />

<button
  bind:this={bouton}
  type="button"
  class="declencheur"
  class:filtre-actif={choix.length > 0}
  aria-haspopup="listbox"
  aria-expanded={ouvert}
  aria-label={label}
  title={choix.length > 1 ? choix.join(', ') : undefined}
  onclick={() => (ouvert ? fermer() : ouvrir())}
>
  <span class="texte">{resume}</span>
  <Icon nom="chevD" taille={12} epaisseur={2} />
</button>

{#if ouvert}
  <div
    bind:this={liste}
    class="liste"
    role="listbox"
    aria-multiselectable="true"
    aria-label={label}
    tabindex="-1"
    style:top="{position.haut}px"
    style:left="{position.gauche}px"
    style:min-width="{position.largeur}px"
    onkeydown={clavier}
    onfocusout={(e) => !liste.contains(/** @type {Node} */ (e.relatedTarget)) && e.relatedTarget !== bouton && fermer()}
  >
    {#each options as o (o)}
      {@const coche = choix.includes(o)}
      <button type="button" class="option" role="option" aria-selected={coche} onclick={() => basculer(o)}>
        <span class="boite" class:coche><Icon nom="check" taille={11} epaisseur={3} /></span>{o}
      </button>
    {/each}
    <div class="pied">
      <button type="button" class="effacer" disabled={!choix.length} onclick={() => (choix = [])}>Tout effacer</button>
    </div>
  </div>
{/if}

<style>
  .declencheur {
    width: 100%;
    height: 24px;
    border: 1px solid var(--wt-line);
    border-radius: 6px;
    padding: 0 5px 0 6px;
    background: var(--wt-card);
    font-size: 12px;
    color: var(--wt-ink);
    display: flex;
    align-items: center;
    gap: 4px;
    text-align: left;
  }
  .declencheur :global(svg) {
    flex: none;
    color: var(--wt-ink3);
  }
  .declencheur:focus-visible,
  .declencheur[aria-expanded='true'] {
    border-color: var(--wt-accent);
    outline: none;
  }
  .declencheur.filtre-actif {
    border-color: var(--wt-accent);
    background: var(--wt-accent-tint);
    color: var(--wt-accent-ink);
    font-weight: 600;
  }
  .texte {
    flex: 1;
    min-width: 0;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .liste {
    position: fixed;
    z-index: 30;
    max-height: min(320px, 60vh);
    overflow-y: auto;
    padding: 4px;
    border-radius: 10px;
    border: 1px solid var(--wt-line);
    background: var(--wt-card);
    box-shadow: 0 12px 32px rgba(42, 29, 21, 0.18);
    display: flex;
    flex-direction: column;
    outline: none;
  }
  .option {
    height: 30px;
    border: 0;
    border-radius: 6px;
    background: transparent;
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 0 8px;
    font-size: 13px;
    color: var(--wt-ink);
    text-align: left;
    white-space: nowrap;
  }
  .option:hover,
  .option:focus-visible {
    background: var(--wt-card2);
    outline: none;
  }
  .boite {
    width: 15px;
    height: 15px;
    flex: none;
    border-radius: 4px;
    border: 1.5px solid var(--wt-line2);
    color: transparent;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .boite.coche {
    border-color: var(--wt-accent);
    background: var(--wt-accent);
    color: var(--wt-on-accent);
  }
  .pied {
    border-top: 1px solid var(--wt-line);
    margin-top: 4px;
    padding: 4px 4px 0;
  }
  .effacer {
    border: 0;
    background: transparent;
    font-size: 12.5px;
    color: var(--wt-accent-ink);
    padding: 4px;
  }
  .effacer:disabled {
    color: var(--wt-ink3);
  }
</style>
