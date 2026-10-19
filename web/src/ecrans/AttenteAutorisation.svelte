<script>
  // E-10 — En attente d'autorisation, ou connexion refusée (navigateur d'un ordinateur).
  import { ctx } from '../lib/contexte.svelte.js';
  import { demanderAutorisation } from '../lib/session.js';
  import { dateHeure } from '../lib/format.js';
  import Icon from '../components/Icon.svelte';
  import StatusPill from '../components/StatusPill.svelte';

  const refusee = $derived(ctx.autorisation === 'refusee');
  const limitee = $derived(ctx.autorisation === 'limitee');
</script>

<div class="page">
  <div class="colonne">
    <span class="marque">WineTap</span>
    {#if refusee}
      <span class="rond danger"><Icon nom="x" taille={34} /></span>
      <h1>Connexion refusée</h1>
      <p>La connexion de ce navigateur a été refusée sur le téléphone.</p>
      <button type="button" class="encore" onclick={() => demanderAutorisation().catch(() => {})}>Demander à nouveau</button>
      {#if ctx.limite}<p class="limite">{ctx.limite}</p>{/if}
    {:else if limitee}
      <div class="cercle"><span class="rond warn"><Icon nom="phone" taille={34} epaisseur={1.6} /></span></div>
      <StatusPill ton="warn" point>Demande en attente</StatusPill>
      <h1>Le téléphone ne prend pas la demande pour l'instant</h1>
      <p>{ctx.limite}</p>
      <p class="limite">Cette page réessaie d'elle-même.</p>
    {:else}
      <div class="cercle"><span class="rond warn"><Icon nom="phone" taille={34} epaisseur={1.6} /></span></div>
      <StatusPill ton="warn" point>En attente d'autorisation</StatusPill>
      <h1>Regardez votre téléphone</h1>
      <p>
        WineTap demande s'il faut autoriser ce navigateur. Appuyez sur «&nbsp;Autoriser&nbsp;» sur le téléphone&nbsp;: cette page
        s'ouvrira d'elle-même.
      </p>
      <dl class="infos">
        <dt>Navigateur</dt>
        <dd>{ctx.client.navigateur} sur {ctx.client.systeme}</dd>
        <dt>Adresse</dt>
        <dd class="mono">{ctx.client.ip}</dd>
        <dt>Heure</dt>
        <dd>{dateHeure(ctx.client.demande_le || new Date().toISOString())}</dd>
      </dl>
    {/if}
  </div>
</div>

<style>
  .page {
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 40px 20px;
    overflow: auto;
  }
  .colonne {
    width: 460px;
    max-width: 100%;
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
    gap: 16px;
  }
  .marque {
    font-family: var(--font-serif);
    font-size: 26px;
    font-weight: 600;
  }
  .cercle {
    width: 120px;
    height: 120px;
    border-radius: 999px;
    border: 1px solid var(--wt-line2);
    display: flex;
    align-items: center;
    justify-content: center;
    margin: 12px 0;
  }
  .rond {
    width: 76px;
    height: 76px;
    border-radius: 999px;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .rond.warn {
    background: var(--wt-warn-tint);
    color: var(--wt-warn);
    animation: pouls 2.4s var(--ease) infinite;
  }
  .rond.danger {
    background: var(--wt-danger-tint);
    color: var(--wt-danger);
    margin: 12px 0;
  }
  @keyframes pouls {
    50% {
      transform: scale(1.05);
    }
  }
  h1 {
    font-family: var(--font-serif);
    font-size: 34px;
    font-weight: 500;
    line-height: 1.15;
  }
  p {
    font-size: 15px;
    color: var(--wt-ink2);
    text-wrap: pretty;
  }
  .infos {
    margin: 0;
    display: grid;
    grid-template-columns: auto 1fr;
    gap: 6px 16px;
    text-align: left;
    background: var(--wt-card);
    border: 1px solid var(--wt-line);
    border-radius: 12px;
    padding: 14px 18px;
    font-size: 13.5px;
    width: 100%;
  }
  dt {
    color: var(--wt-ink3);
  }
  dd {
    margin: 0;
  }
  .limite {
    font-size: 13.5px;
    color: var(--wt-ink3);
  }
  .encore {
    height: 40px;
    border-radius: 10px;
    border: 1px solid var(--wt-line2);
    background: var(--wt-card);
    color: var(--wt-ink);
    padding: 0 18px;
    font-size: 14px;
    font-weight: 600;
  }
</style>
