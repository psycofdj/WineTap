<script>
  // Coque du téléphone (moins de 720 px) : contenu défilant et barre d'onglets.
  import { routeur } from '../../lib/routeur.svelte.js';
  import { lecture } from '../../lib/stores/lecture.svelte.js';
  import TabBar from '../../components/TabBar.svelte';
  import Accueil from './Accueil.svelte';
  import Inventaire from './Inventaire.svelte';
  import Fiche from './Fiche.svelte';
  import Entree from './Entree.svelte';
  import Consommation from './Consommation.svelte';
  import Catalogue from './Catalogue.svelte';
  import FicheCatalogue from '../FicheCatalogue.svelte';
  import TableauDeBord from './TableauDeBord.svelte';
  import Degustations from './Degustations.svelte';
  import Reglages from './Reglages.svelte';

  let zone = /** @type {HTMLElement} */ ($state());
  const ecran = $derived(routeur.ecran || 'accueil');
  const sansOnglets = $derived(ecran === 'consommation');

  // Nouvel écran : on revient en haut.
  $effect(() => {
    routeur.chemin;
    if (zone) zone.scrollTop = 0;
  });
</script>

<div class="coque">
  <main class="defilement" bind:this={zone}>
    {#key routeur.chemin}
      {#if ecran === 'accueil'}
        <Accueil />
      {:else if ecran === 'inventaire'}
        <Inventaire />
      {:else if ecran === 'bouteille'}
        <Fiche id={Number(routeur.segments[1])} />
      {:else if ecran === 'entree'}
        <Entree />
      {:else if ecran === 'consommation'}
        <Consommation />
      {:else if ecran === 'catalogue' && routeur.segments[2]}
        <FicheCatalogue rubrique={routeur.segments[1]} id={routeur.segments[2]} />
      {:else if ecran === 'catalogue'}
        <Catalogue />
      {:else if ecran === 'tableau-de-bord'}
        <TableauDeBord />
      {:else if ecran === 'degustations'}
        <Degustations />
      {:else if ecran === 'parametres'}
        <Reglages />
      {:else}
        <Accueil />
      {/if}
    {/key}
  </main>
  {#if !sansOnglets}
    <TabBar onconsommer={() => lecture.consommer()} />
  {/if}
</div>

<style>
  .coque {
    height: 100%;
    display: flex;
    flex-direction: column;
    background: var(--wt-paper);
  }
  .defilement {
    flex: 1;
    min-height: 0;
    overflow-y: auto;
    overflow-x: hidden;
    position: relative;
    scrollbar-width: none;
    padding-top: env(safe-area-inset-top);
    -webkit-overflow-scrolling: touch;
  }
  .defilement::-webkit-scrollbar {
    display: none;
  }
</style>
