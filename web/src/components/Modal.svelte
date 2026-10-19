<script>
  // Fenêtre (ordinateur) : 680 px, hauteur max 700, rayon 18. Échap ferme ; focus piégé.
  import { onMount } from 'svelte';
  import { fade, scale } from 'svelte/transition';
  import { quintOut } from 'svelte/easing';

  /** @type {{ onfermer: () => void, label?: string, largeur?: number, children: any }} */
  let { onfermer, label = '', largeur = 680, children } = $props();

  let boite = /** @type {HTMLDivElement} */ ($state());
  let precedent = /** @type {HTMLElement|null} */ (null);

  const FOCUSABLES = 'button:not([disabled]), [href], input:not([disabled]), select, textarea, [tabindex]:not([tabindex="-1"])';

  onMount(() => {
    precedent = /** @type {HTMLElement} */ (document.activeElement);
    boite.focus();
    return () => precedent?.focus?.();
  });

  function clavier(e) {
    if (e.key === 'Escape') {
      e.preventDefault();
      e.stopPropagation();
      onfermer();
      return;
    }
    if (e.key !== 'Tab') return;
    const els = [...boite.querySelectorAll(FOCUSABLES)];
    if (!els.length) return;
    const premier = /** @type {HTMLElement} */ (els[0]);
    const dernier = /** @type {HTMLElement} */ (els[els.length - 1]);
    if (e.shiftKey && (document.activeElement === premier || document.activeElement === boite)) {
      dernier.focus();
      e.preventDefault();
    } else if (!e.shiftKey && document.activeElement === dernier) {
      premier.focus();
      e.preventDefault();
    }
  }
</script>

<div class="voile" transition:fade={{ duration: 200 }} onclick={onfermer} role="presentation">
  <div
    bind:this={boite}
    class="modale"
    role="dialog"
    aria-modal="true"
    aria-label={label}
    tabindex="-1"
    style:width="{largeur}px"
    onclick={(e) => e.stopPropagation()}
    onkeydown={clavier}
    transition:scale={{ start: 0.97, duration: 360, easing: quintOut }}
  >
    {@render children()}
  </div>
</div>

<style>
  .voile {
    position: fixed;
    inset: 0;
    z-index: 40;
    background: rgba(42, 29, 21, 0.4);
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 24px;
  }
  .modale {
    max-width: 100%;
    max-height: min(700px, 100%);
    background: var(--wt-card);
    border-radius: 18px;
    box-shadow: 0 30px 80px rgba(42, 29, 21, 0.3);
    display: flex;
    flex-direction: column;
    overflow: hidden;
    outline: none;
  }
</style>
