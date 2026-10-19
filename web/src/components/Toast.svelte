<script>
  import { fly } from 'svelte/transition';
  import { quintOut } from 'svelte/easing';
  import { toast } from '../lib/toast.svelte.js';
  import { ctx } from '../lib/contexte.svelte.js';
  import Icon from './Icon.svelte';

  /** @type {{ avecOnglets?: boolean }} */
  let { avecOnglets = true } = $props();
</script>

<div class="place no-print" class:ordinateur={ctx.ordinateur} class:haut={!ctx.ordinateur && avecOnglets} aria-live="polite">
  {#if toast.message}
    {#key toast.message}
      <div class="toast" role="status" transition:fly={{ y: 16, duration: 200, easing: quintOut }}>
        <Icon nom="info" taille={ctx.ordinateur ? 18 : 20} />
        <span>{toast.message}</span>
      </div>
    {/key}
  {/if}
</div>

<style>
  .place {
    position: fixed;
    z-index: 60;
    left: 16px;
    right: 16px;
    bottom: calc(24px + env(safe-area-inset-bottom));
    display: flex;
    justify-content: center;
    pointer-events: none;
  }
  .haut {
    bottom: calc(104px + env(safe-area-inset-bottom));
  }
  .toast {
    width: 100%;
    background: var(--wt-ink);
    color: var(--wt-paper);
    border-radius: 14px;
    padding: 14px 16px;
    font-size: 15px;
    display: flex;
    align-items: center;
    gap: 10px;
    box-shadow: var(--wt-shadow);
  }
  .ordinateur {
    bottom: 24px;
  }
  .ordinateur .toast {
    width: auto;
    border-radius: 10px;
    padding: 10px 16px;
    font-size: 14px;
    gap: 8px;
    white-space: nowrap;
  }
</style>
