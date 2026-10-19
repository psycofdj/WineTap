<script>
  // Coque de l'ordinateur (720 px et plus) : barre latérale et contenu.
  import { routeur } from '../../lib/routeur.svelte.js';
  import Sidebar from '../../components/Sidebar.svelte';
  import Inventaire from './Inventaire.svelte';
  import TableauDeBord from './TableauDeBord.svelte';
  import Degustations from './Degustations.svelte';
  import Catalogue from './Catalogue.svelte';
  import Parametres from './Parametres.svelte';

  const ecran = $derived(routeur.ecran);
</script>

<div class="coque">
  <Sidebar />
  <main class="contenu">
    {#if ecran === 'tableau-de-bord'}
      <TableauDeBord />
    {:else if ecran === 'degustations'}
      <Degustations />
    {:else if ecran === 'catalogue'}
      <Catalogue />
    {:else if ecran === 'parametres'}
      <Parametres />
    {:else}
      {#key routeur.query}
        <Inventaire />
      {/key}
    {/if}
  </main>
</div>

<style>
  .coque {
    height: 100%;
    display: flex;
    min-height: 0;
  }
  .contenu {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }
</style>
