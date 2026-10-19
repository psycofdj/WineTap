<script>
  // Filtre de colonne à choix multiple (ordinateur) : un bouton au format des autres filtres, et une
  // liste de cases. La liste est placée par rapport à la fenêtre : la zone de la table, qui défile,
  // ne la coupe pas. Échap ou un clic ailleurs la ferment.
  import { tick } from 'svelte';
  import Icon from './Icon.svelte';
  import WineGlass from './WineGlass.svelte';
  import Blason from './Blason.svelte';

  /**
   * Chaque choix montre sa case, son verre (couleur) ou son blason (région), son libellé et son
   * nombre de bouteilles.
   * @typedef {{ valeur: any, libelle: string, n?: number, couleur?: number, region?: string }} Choix
   * @type {{ options: Choix[], choix?: any[], tous?: string, pluriel?: string, label: string }}
   */
  let { options, choix = $bindable([]), tous = 'Toutes', pluriel = 'choix', label } = $props();

  let ouvert = $state(false);
  let bouton = /** @type {HTMLButtonElement} */ ($state());
  let liste = /** @type {HTMLDivElement} */ ($state());
  let position = $state({ haut: 0, gauche: 0, largeur: 0 });

  const libelleDe = (v) => options.find((o) => o.valeur === v)?.libelle ?? String(v);
  const resume = $derived(choix.length === 0 ? tous : choix.length === 1 ? libelleDe(choix[0]) : `${choix.length} ${pluriel}`);

  function placer() {
    const r = bouton.getBoundingClientRect();
    position = { haut: r.bottom + 4, gauche: r.left, largeur: Math.max(r.width, 210) };
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
  title={choix.length > 1 ? choix.map(libelleDe).join(', ') : undefined}
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
    {#each options as o (o.valeur)}
      {@const coche = choix.includes(o.valeur)}
      <button type="button" class="option" class:coche role="option" aria-selected={coche} onclick={() => basculer(o.valeur)}>
        <span class="boite" class:coche><Icon nom="check" taille={12} epaisseur={3} /></span>
        {#if o.couleur !== undefined}<WineGlass couleur={o.couleur} taille={18} style="color:var(--wt-ink)" />{/if}
        {#if o.region}<Blason region={o.region} largeur={13} hauteur={16} />{/if}
        <span class="libelle">{o.libelle}</span>
        {#if o.n !== undefined}<span class="nombre">{o.n}</span>{/if}
      </button>
    {/each}
    <div class="pied">
      <button type="button" class="effacer" disabled={!choix.length} onclick={() => (choix = [])}>Tout effacer</button>
      <button type="button" class="ok" onclick={() => fermer(true)}>OK</button>
    </div>
  </div>
{/if}

<style>
  .declencheur {
    width: 100%;
    height: 24px;
    border: 1px solid var(--wt-line);
    border-radius: 6px;
    padding: 0 4px 0 6px;
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
    border: 1px solid var(--wt-line2);
    background: var(--wt-card);
    box-shadow: var(--wt-shadow);
    display: flex;
    flex-direction: column;
    gap: 1px;
    outline: none;
  }
  .option {
    min-height: 32px;
    border: 0;
    border-radius: 7px;
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
  .option.coche {
    background: var(--wt-accent-tint);
  }
  .option:hover,
  .option:focus-visible {
    background: var(--wt-card2);
    outline: none;
  }
  .libelle {
    flex: 1;
    min-width: 0;
  }
  .nombre {
    font-size: 12px;
    color: var(--wt-ink3);
    font-variant-numeric: tabular-nums;
    padding-left: 8px;
  }
  .boite {
    width: 16px;
    height: 16px;
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
    margin-top: 3px;
    padding: 4px 4px 0;
    display: flex;
    justify-content: space-between;
  }
  .effacer {
    height: 28px;
    border: 0;
    background: transparent;
    font-size: 12.5px;
    font-weight: 600;
    color: var(--wt-accent-ink);
    padding: 0 6px;
  }
  .ok {
    height: 28px;
    border: 0;
    border-radius: 6px;
    background: var(--wt-card2);
    color: var(--wt-ink);
    font-size: 12.5px;
    font-weight: 600;
    padding: 0 10px;
  }
  .effacer:disabled {
    color: var(--wt-ink3);
  }
</style>
