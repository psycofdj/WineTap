<script>
  // Confirmation d'une action destructrice (suppression d'une bouteille, d'une fiche du catalogue).
  // `empile` (téléphone) : boutons de 52 px l'un sous l'autre, l'action en premier.
  import { ctx } from '../lib/contexte.svelte.js';
  import Modal from './Modal.svelte';
  import Sheet from './Sheet.svelte';
  import Button from './Button.svelte';

  /** @type {{ titre: string, texte: string, action: string, empile?: boolean, onconfirmer: () => void, onfermer: () => void }} */
  let { titre, texte, action, empile = false, onconfirmer, onfermer } = $props();
</script>

{#if ctx.ordinateur}
  <Modal {onfermer} label={titre} largeur={440}>
    <div class="o">
      <span class="titre">{titre}</span>
      <p>{texte}</p>
      <div class="o-boutons">
        <Button taille="ord-l" onclick={onfermer}>Annuler</Button>
        <Button taille="ord-l" variante="danger-plein" onclick={onconfirmer}>{action}</Button>
      </div>
    </div>
  </Modal>
{:else}
  <Sheet {onfermer} label={titre}>
    <div class="t" class:empile>
      <span class="titre t-titre">{titre}</span>
      <p>{texte}</p>
      {#if empile}
        <div class="t-pile">
          <Button taille="tel-m" variante="danger-plein" style="border-radius:14px" onclick={onconfirmer}>{action}</Button>
          <Button taille="tel-m" style="border-radius:14px" onclick={onfermer}>Annuler</Button>
        </div>
      {:else}
        <div class="t-boutons">
          <Button taille="tel-l" onclick={onfermer}>Annuler</Button>
          <Button taille="tel-l" variante="danger-plein" onclick={onconfirmer}>{action}</Button>
        </div>
      {/if}
    </div>
  </Sheet>
{/if}

<style>
  .o {
    padding: 22px 24px 18px;
    display: flex;
    flex-direction: column;
    gap: 10px;
  }
  .titre {
    font-family: var(--font-serif);
    font-size: 24px;
    font-weight: 500;
  }
  p {
    font-size: 14px;
    color: var(--wt-ink2);
  }
  .o-boutons {
    display: flex;
    gap: 8px;
    justify-content: flex-end;
    margin-top: 8px;
  }
  .t {
    padding: 8px 24px calc(28px + env(safe-area-inset-bottom));
    display: flex;
    flex-direction: column;
    gap: 12px;
  }
  .t-titre {
    font-size: 30px;
  }
  .t p {
    font-size: 16px;
  }
  .empile .t-titre {
    font-size: 24px;
    line-height: 1.2;
  }
  .empile p {
    font-size: 15px;
    line-height: 1.5;
  }
  .t-pile {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }
  .t-boutons {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 10px;
    margin-top: 6px;
  }
</style>
