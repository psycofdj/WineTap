<script>
  // Anneau des couleurs (E-07) : parts dessinées en tournant à l'ouverture ; survol ou focus d'une
  // part, ou de sa ligne de légende (`actif`, partagé), l'élargit et affiche son détail au centre.
  // Clic : `onchoisir(code)`. Au toucher, un premier appui montre la part, un second la choisit.
  import { onMount } from 'svelte';
  import { Tween, prefersReducedMotion } from 'svelte/motion';
  import { cubicOut } from 'svelte/easing';
  import { teinteGraphique, vin } from '../lib/vins.js';
  import { pourcentage } from '../lib/stats.js';
  import { accord } from '../lib/format.js';

  /**
   * @type {{ parts: {code:number, n:number, pct:number}[], total: number, taille?: number,
   *   actif?: number|null, onchoisir?: (code: number) => void }}
   */
  let { parts, total, taille = 190, actif = $bindable(null), onchoisir } = $props();

  const R = 80;
  const EPAISSEUR = 26;
  const C = 2 * Math.PI * R;
  const ECART = 1.6;

  const progres = new Tween(0, { duration: 900, easing: cubicOut });
  onMount(() => {
    progres.set(1, { duration: prefersReducedMotion.current ? 0 : 900 });
  });

  const arcs = $derived.by(() => {
    let debut = 0;
    return parts.map((p) => {
      const longueur = (p.pct / 100) * C;
      const a = { ...p, debut, longueur };
      debut += longueur;
      return a;
    });
  });

  const choisie = $derived(parts.find((p) => p.code === actif) ?? null);
  // Toucher : le focus arrive avant le clic ; il ne doit pas compter comme premier appui.
  let toucher = false;

  function clic(code) {
    if (toucher && actif !== code) {
      actif = code;
      return;
    }
    onchoisir?.(code);
  }
</script>

<div class="donut" style:width="{taille}px" style:height="{taille}px">
  <svg viewBox="0 0 200 200" role="group" aria-label="Répartition par couleur">
    <circle cx="100" cy="100" r={R} fill="none" stroke="var(--wt-card2)" stroke-width={EPAISSEUR} />
    <g transform="rotate(-90 100 100)">
      {#each arcs as a (a.code)}
        {@const ecart = arcs.length > 1 ? ECART : 0}
        <circle
          class="part"
          class:active={actif === a.code}
          class:estompee={actif !== null && actif !== a.code}
          cx="100"
          cy="100"
          r={R}
          fill="none"
          stroke={teinteGraphique(a.code)}
          stroke-width={EPAISSEUR}
          stroke-dasharray="{Math.max(0, a.longueur * progres.current - ecart)} {C}"
          stroke-dashoffset={-a.debut * progres.current}
          role="button"
          tabindex="0"
          aria-label="{vin(a.code).libelle} : {a.n} ({pourcentage(a.pct)})"
          onpointerdown={(e) => (toucher = e.pointerType === 'touch')}
          onpointerenter={(e) => e.pointerType !== 'touch' && (actif = a.code)}
          onpointerleave={(e) => e.pointerType !== 'touch' && (actif = null)}
          onfocus={() => !toucher && (actif = a.code)}
          onblur={() => (actif = null)}
          onclick={() => clic(a.code)}
          onkeydown={(e) => (e.key === 'Enter' || e.key === ' ') && (e.preventDefault(), onchoisir?.(a.code))}
        />
      {/each}
    </g>
  </svg>
  <div class="centre" aria-live="polite">
    {#if choisie}
      <span class="chiffre">{choisie.n}</span>
      <span class="lib fort">{vin(choisie.code).libelle}</span>
      <span class="lib">{pourcentage(choisie.pct)}</span>
    {:else}
      <span class="chiffre">{total}</span>
      <span class="lib">{accord(total, 'bouteille')}</span>
    {/if}
  </div>
</div>

<style>
  .donut {
    position: relative;
    flex: none;
  }
  svg {
    width: 100%;
    height: 100%;
    overflow: visible;
  }
  .part {
    cursor: pointer;
    outline: none;
    transition:
      stroke-width 220ms var(--ease, ease),
      opacity 220ms var(--ease, ease);
  }
  .part.active {
    stroke-width: 36;
  }
  .part.estompee {
    opacity: 0.35;
  }
  .part:focus-visible {
    stroke-width: 36;
  }
  .centre {
    position: absolute;
    inset: 0;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    pointer-events: none;
    text-align: center;
  }
  .chiffre {
    font-family: var(--font-serif);
    font-size: calc(var(--taille-chiffre, 30px));
    line-height: 1;
    font-variant-numeric: tabular-nums;
  }
  .lib {
    font-size: 12px;
    color: var(--wt-ink3);
  }
  .lib.fort {
    color: var(--wt-ink);
    font-weight: 600;
    margin-top: 2px;
  }
  @media (prefers-reduced-motion: reduce) {
    .part {
      transition: none;
    }
  }
</style>
