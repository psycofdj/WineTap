<script>
  // Barre d'onglets du téléphone (D-17) : Accueil, Inventaire, Consommer (rond central), Catalogue, Réglages.
  import { routeur } from '../lib/routeur.svelte.js';
  import { ctx } from '../lib/contexte.svelte.js';
  import { creation } from '../lib/stores/creation.svelte.js';
  import Icon from './Icon.svelte';

  /** @type {{ onconsommer: () => void }} */
  let { onconsommer } = $props();

  const ONGLET_DE = {
    '': 'accueil',
    accueil: 'accueil',
    'tableau-de-bord': 'accueil',
    degustations: 'accueil',
    inventaire: 'inventaire',
    bouteille: 'inventaire',
    entree: 'inventaire',
    catalogue: 'catalogue',
    parametres: 'parametres',
  };
  const actif = $derived(ONGLET_DE[routeur.ecran] ?? '');

  const onglets = [
    { cle: 'accueil', libelle: 'Accueil', icone: 'home', chemin: '/accueil' },
    { cle: 'inventaire', libelle: 'Inventaire', icone: 'list', chemin: '/inventaire' },
    { cle: 'catalogue', libelle: 'Catalogue', icone: 'book', chemin: '/catalogue/cuvees' },
    { cle: 'parametres', libelle: 'Réglages', icone: 'sliders', chemin: '/parametres' },
  ];
</script>

{#snippet onglet(o)}
  <button
    type="button"
    class="onglet"
    class:actif={actif === o.cle}
    aria-current={actif === o.cle ? 'page' : undefined}
    onclick={() => {
      creation.vider();
      routeur.aller(o.chemin, { remplacer: true });
    }}
  >
    <Icon nom={o.icone} taille={24} />{o.libelle}
  </button>
{/snippet}

<nav class="barre" class:quatre={!ctx.dansApplication} aria-label="Navigation principale">
  {@render onglet(onglets[0])}
  {@render onglet(onglets[1])}
  {#if ctx.dansApplication}
    <div class="centre">
      <button type="button" class="consommer" aria-label="Consommer une bouteille" onclick={onconsommer}>
        <Icon nom="wine" taille={28} />
      </button>
      <span>Consommer</span>
    </div>
  {/if}
  {@render onglet(onglets[2])}
  {@render onglet(onglets[3])}
</nav>

<style>
  .barre {
    flex: none;
    height: calc(64px + max(22px, env(safe-area-inset-bottom)));
    padding-bottom: max(22px, env(safe-area-inset-bottom));
    background: var(--wt-card);
    border-top: 1px solid var(--wt-line);
    display: grid;
    grid-template-columns: repeat(5, 1fr);
    align-items: center;
    position: relative;
    z-index: 10;
  }
  .quatre {
    grid-template-columns: repeat(4, 1fr);
  }
  .onglet {
    height: 56px;
    border: 0;
    background: transparent;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 3px;
    color: var(--wt-ink3);
    font-size: 11px;
    font-weight: 500;
  }
  .onglet.actif {
    color: var(--wt-accent-ink);
  }
  .centre {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 3px;
    margin-top: -26px;
  }
  .centre span {
    font-size: 11px;
    font-weight: 600;
    color: var(--wt-accent-ink);
  }
  .consommer {
    width: 64px;
    height: 64px;
    border-radius: 999px;
    border: 4px solid var(--wt-card);
    background: var(--wt-accent);
    color: var(--wt-on-accent);
    display: flex;
    align-items: center;
    justify-content: center;
    box-shadow: var(--wt-shadow);
    transition: transform var(--t-micro) var(--ease);
  }
  .consommer:active {
    transform: scale(0.96);
  }
</style>
