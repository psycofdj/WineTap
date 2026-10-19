<script>
  // Simulation de l'écran natif N-E4 (développement seulement).
  import { onMount } from 'svelte';
  import { OBJETS } from '../lib/nfc.js';
  import Icon from '../components/Icon.svelte';

  /** @type {{ objet: string, terminer: (r: any) => void }} */
  let { objet, terminer } = $props();

  let tags = $state({ en_stock: [], libere: null });
  let lu = $state('');

  onMount(async () => {
    tags = await fetch('/__mock/tags').then((r) => r.json());
  });

  function lire(tag) {
    lu = tag;
    setTimeout(() => terminer({ tag_id: tag }), 900);
  }
</script>

<div class="natif">
  <div class="origine"><span class="pill"><Icon nom="phone" taille={16} epaisseur={2} />Depuis ce téléphone</span></div>
  <div class="centre">
    <div class="objet">{OBJETS[objet] ?? objet}</div>
    {#if lu}
      <div class="rond ok"><Icon nom="check" taille={64} /></div>
      <div class="titre">Tag lu</div>
      <div class="uid">{lu}</div>
    {:else}
      <div class="c1"><div class="c2"><div class="c3"><Icon nom="nfc" taille={48} /></div></div></div>
      <div class="titre">Présentez le tag</div>
      <div class="texte">Approchez le haut du téléphone du tag collé sur la bouteille</div>
    {/if}
  </div>
  <div class="bas">
    <div class="simu">
      <span class="s-titre">Développement · simuler la lecture</span>
      <div class="s-boutons">
        <button type="button" disabled={!tags.en_stock.length} onclick={() => lire(tags.en_stock[Math.floor(Math.random() * tags.en_stock.length)])}>Tag en stock</button>
        <button type="button" onclick={() => lire('04' + Math.floor(Math.random() * 0xffffff).toString(16).toUpperCase().padStart(6, '0'))}>Tag inconnu</button>
        <button type="button" disabled={!tags.libere} onclick={() => lire(tags.libere)}>Déjà consommée</button>
      </div>
    </div>
    <button type="button" class="annuler" onclick={() => terminer({ annule: true })}>Annuler</button>
  </div>
</div>

<style>
  .natif {
    position: fixed;
    inset: 0;
    z-index: 100;
    background: var(--wt-paper);
    color: var(--wt-ink);
    display: flex;
    flex-direction: column;
    padding: calc(16px + env(safe-area-inset-top)) 24px 28px;
    font-family: var(--font-sans);
  }
  .origine {
    display: flex;
    justify-content: center;
  }
  .pill {
    display: flex;
    align-items: center;
    gap: 8px;
    background: var(--wt-card2);
    color: var(--wt-ink2);
    border-radius: 999px;
    padding: 8px 14px;
    font-size: 13px;
    font-weight: 600;
  }
  .centre {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    text-align: center;
    gap: 14px;
  }
  .objet {
    font-size: 13px;
    font-weight: 600;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: var(--wt-accent-ink);
  }
  .c1 {
    width: 220px;
    height: 220px;
    border-radius: 999px;
    border: 1px solid var(--wt-line);
    display: flex;
    align-items: center;
    justify-content: center;
    margin: 18px 0;
  }
  .c2 {
    width: 164px;
    height: 164px;
    border-radius: 999px;
    border: 1px solid var(--wt-line2);
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .c3 {
    width: 108px;
    height: 108px;
    border-radius: 999px;
    background: var(--wt-accent);
    color: var(--wt-on-accent);
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .rond.ok {
    width: 164px;
    height: 164px;
    border-radius: 999px;
    background: var(--wt-ok-tint);
    color: var(--wt-ok);
    display: flex;
    align-items: center;
    justify-content: center;
    margin: 46px 0;
  }
  .titre {
    font-family: var(--font-serif);
    font-size: 36px;
    font-weight: 500;
    line-height: 1.1;
  }
  .texte {
    font-size: 16px;
    color: var(--wt-ink2);
    max-width: 280px;
  }
  .uid {
    font-family: var(--font-mono);
    font-size: 18px;
    color: var(--wt-ink2);
    letter-spacing: 0.06em;
  }
  .bas {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }
  .simu {
    border: 1px dashed var(--wt-line2);
    border-radius: 14px;
    padding: 10px 12px;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .s-titre {
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: var(--wt-ink3);
  }
  .s-boutons {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
  }
  .s-boutons button {
    border: 1px solid var(--wt-line2);
    background: var(--wt-card);
    color: var(--wt-ink);
    border-radius: 999px;
    padding: 6px 12px;
    font-size: 13px;
  }
  .s-boutons button:disabled {
    opacity: 0.5;
  }
  .annuler {
    height: 56px;
    border-radius: 16px;
    border: 1px solid var(--wt-line2);
    background: var(--wt-card);
    color: var(--wt-ink);
    font-size: 17px;
    font-weight: 600;
  }
</style>
