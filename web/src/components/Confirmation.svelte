<script>
  // Confirmation d'une action destructrice (suppression d'une bouteille).
  import { ctx } from '../lib/contexte.svelte.js';
  import Modal from './Modal.svelte';
  import Sheet from './Sheet.svelte';
  import Button from './Button.svelte';

  /** @type {{ titre: string, texte: string, action: string, onconfirmer: () => void, onfermer: () => void }} */
  let { titre, texte, action, onconfirmer, onfermer } = $props();
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
    <div class="t">
      <span class="titre t-titre">{titre}</span>
      <p>{texte}</p>
      <div class="t-boutons">
        <Button taille="tel-l" onclick={onfermer}>Annuler</Button>
        <Button taille="tel-l" variante="danger-plein" onclick={onconfirmer}>{action}</Button>
      </div>
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
  .t-boutons {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 10px;
    margin-top: 6px;
  }
</style>
