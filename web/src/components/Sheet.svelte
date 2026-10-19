<script>
  // Feuille du bas (téléphone) : rayon 28, poignée, voile ; ferme au clic sur le voile et par glissement.
  import { fly, fade } from 'svelte/transition';
  import { quintOut } from 'svelte/easing';

  /** @type {{ onfermer: () => void, label?: string, maxHauteur?: number, pied?: any, children: any }} */
  let { onfermer, label = '', maxHauteur = 760, pied, children } = $props();

  let decalage = $state(0);
  let depart = $state(/** @type {number|null} */ (null));

  function debut(e) {
    depart = e.clientY;
    e.currentTarget.setPointerCapture(e.pointerId);
  }
  function deplacement(e) {
    if (depart === null) return;
    decalage = Math.max(0, e.clientY - depart);
  }
  function fin() {
    if (depart === null) return;
    depart = null;
    if (decalage > 110) onfermer();
    else decalage = 0;
  }
</script>

<svelte:window onkeydown={(e) => e.key === 'Escape' && onfermer()} />

<div class="voile" transition:fade={{ duration: 200 }} onclick={onfermer} role="presentation">
  <div
    class="feuille"
    role="dialog"
    aria-modal="true"
    aria-label={label}
    style:max-height="min({maxHauteur}px, calc(100% - 40px))"
    style:transform={decalage ? `translateY(${decalage}px)` : null}
    style:transition={depart === null ? 'transform 200ms var(--ease)' : 'none'}
    transition:fly={{ y: 500, duration: 360, easing: quintOut, opacity: 1 }}
    onclick={(e) => e.stopPropagation()}
    onkeydown={() => {}}
    tabindex="-1"
  >
    <div class="poignee" onpointerdown={debut} onpointermove={deplacement} onpointerup={fin} onpointercancel={fin} role="presentation">
      <span></span>
    </div>
    <div class="contenu">
      {@render children()}
    </div>
    {#if pied}<div class="pied">{@render pied()}</div>{/if}
  </div>
</div>

<style>
  .voile {
    position: fixed;
    inset: 0;
    z-index: 40;
    background: rgba(42, 29, 21, 0.45);
    display: flex;
    align-items: flex-end;
  }
  .feuille {
    width: 100%;
    background: var(--wt-card);
    border-radius: var(--r-sheet) var(--r-sheet) 0 0;
    display: flex;
    flex-direction: column;
    overflow: hidden;
    outline: none;
  }
  .poignee {
    display: flex;
    justify-content: center;
    padding: 10px 0 2px;
    touch-action: none;
    cursor: grab;
  }
  .poignee span {
    width: 40px;
    height: 5px;
    border-radius: 99px;
    background: var(--wt-line2);
  }
  .contenu {
    flex: 1;
    overflow-y: auto;
    overscroll-behavior: contain;
    scrollbar-width: none;
  }
  .pied {
    border-top: 1px solid var(--wt-line);
    padding: 12px 22px calc(30px + env(safe-area-inset-bottom));
  }
</style>
