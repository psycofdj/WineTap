<script>
  // Point d'entrée : autorisation (E-10), perte du téléphone (E-11), puis coque téléphone ou ordinateur.
  import { onMount } from 'svelte';
  import { ctx } from './lib/contexte.svelte.js';
  import { obtenirAcces } from './lib/session.js';
  import { catalogue } from './lib/stores/catalogue.svelte.js';
  import { cave } from './lib/stores/cave.svelte.js';
  import CoqueTelephone from './ecrans/telephone/Coque.svelte';
  import CoqueOrdinateur from './ecrans/ordinateur/Coque.svelte';
  import AttenteAutorisation from './ecrans/AttenteAutorisation.svelte';
  import Injoignable from './ecrans/Injoignable.svelte';
  import Toast from './components/Toast.svelte';

  let erreurDemarrage = $state('');
  const pret = $derived(catalogue.charge && cave.charge);
  const injoignable = $derived(ctx.telephone === 'injoignable' && !ctx.dansApplication);

  onMount(() => {
    obtenirAcces().catch((e) => (erreurDemarrage = e?.message ?? String(e)));

    // Secours si l'événement « session » n'arrive pas, et reprise après une coupure au démarrage.
    const minuteur = setInterval(() => {
      const attente = ctx.autorisation === 'en_attente' || ctx.autorisation === 'limitee';
      const perduAvantChargement = ctx.telephone === 'injoignable' && !pret;
      if (attente || perduAvantChargement) obtenirAcces().catch(() => {});
    }, 3000);
    return () => clearInterval(minuteur);
  });
</script>

<div class="racine" class:ordinateur={ctx.ordinateur} class:telephone={!ctx.ordinateur}>
  {#if injoignable}
    <Injoignable />
  {:else if ['inconnue', 'en_attente', 'refusee', 'limitee'].includes(ctx.autorisation)}
    <AttenteAutorisation />
  {:else if ctx.autorisation === 'autorisee' && pret}
    {#if ctx.ordinateur}
      <CoqueOrdinateur />
    {:else}
      <CoqueTelephone />
    {/if}
  {:else if erreurDemarrage}
    <div class="erreur">
      <span class="serif">WineTap</span>
      <p>Le site n'a pas pu démarrer&nbsp;: {erreurDemarrage}</p>
      <button type="button" onclick={() => location.reload()}>Recharger</button>
    </div>
  {/if}
  <Toast avecOnglets={!ctx.ordinateur} />
</div>

<style>
  .racine {
    height: 100%;
    background: var(--wt-paper);
    color: var(--wt-ink);
  }
  .telephone {
    font-size: 16px;
  }
  .erreur {
    height: 100%;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 12px;
    padding: 24px;
    text-align: center;
  }
  .erreur .serif {
    font-size: 26px;
    font-weight: 600;
  }
  .erreur button {
    height: 40px;
    border-radius: 10px;
    border: 1px solid var(--wt-line2);
    background: var(--wt-card);
    padding: 0 18px;
    font-weight: 600;
  }
</style>
