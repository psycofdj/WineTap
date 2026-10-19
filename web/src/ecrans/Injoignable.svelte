<script>
  // E-11 — Téléphone injoignable. Nouvelle tentative automatique toutes les 5 s (canal d'événements).
  import { ctx } from '../lib/contexte.svelte.js';
  import { reessayer } from '../lib/session.js';
  import Icon from '../components/Icon.svelte';
  import StatusPill from '../components/StatusPill.svelte';

  let essai = $state(false);
  const adresse = $derived(ctx.appareil.adresse || location.host);

  async function maintenant() {
    essai = true;
    await reessayer().catch(() => {});
    essai = false;
  }
</script>

<div class="page">
  <div class="colonne">
    <span class="marque">WineTap</span>
    <span class="rond"><Icon nom="wifiOff" taille={34} epaisseur={1.6} /></span>
    <StatusPill ton="danger" point>Téléphone injoignable</StatusPill>
    <h1>Le téléphone ne répond plus</h1>
    <ol>
      <li><b>1</b>Ouvrez WineTap sur le téléphone et laissez-le au premier plan.</li>
      <li><b>2</b>Vérifiez que le téléphone et l'ordinateur sont sur le même Wi-Fi.</li>
      <li><b>3</b>Si l'adresse a changé, saisissez celle affichée par le téléphone.</li>
    </ol>
    <span class="note">Nouvelle tentative automatique toutes les 5 secondes · dernière adresse {adresse}</span>
    <button type="button" class="reessayer" disabled={essai} onclick={maintenant}>Réessayer maintenant</button>
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
    width: 480px;
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
  .rond {
    width: 76px;
    height: 76px;
    border-radius: 999px;
    background: var(--wt-danger-tint);
    color: var(--wt-danger);
    display: flex;
    align-items: center;
    justify-content: center;
    margin: 12px 0;
  }
  h1 {
    font-family: var(--font-serif);
    font-size: 34px;
    font-weight: 500;
    line-height: 1.15;
  }
  ol {
    margin: 0;
    list-style: none;
    display: flex;
    flex-direction: column;
    gap: 8px;
    text-align: left;
    background: var(--wt-card);
    border: 1px solid var(--wt-line);
    border-radius: 12px;
    padding: 16px 18px;
    font-size: 14px;
    width: 100%;
  }
  li {
    display: flex;
    gap: 10px;
  }
  li b {
    font-family: var(--font-serif);
    font-size: 17px;
    color: var(--wt-accent-ink);
    width: 14px;
    flex: none;
    line-height: 1.2;
  }
  .note {
    font-size: 13px;
    color: var(--wt-ink3);
  }
  .reessayer {
    height: 40px;
    border-radius: 10px;
    border: 0;
    background: var(--wt-accent);
    color: var(--wt-on-accent);
    padding: 0 18px;
    font-size: 14px;
    font-weight: 600;
  }
  .reessayer:disabled {
    opacity: 0.5;
  }
</style>
