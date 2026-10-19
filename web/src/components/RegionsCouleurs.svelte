<script>
  // Bouteilles par région (E-07), chaque barre découpée par couleur de vin. Les barres s'étirent à
  // l'ouverture. Survol ou focus d'une part : son détail au-dessus du graphe. Clic sur une part :
  // inventaire de la région et de la couleur ; sur le nom ou le nombre : inventaire de la région.
  import { onMount } from 'svelte';
  import { routeur } from '../lib/routeur.svelte.js';
  import { teinteGraphique, vin } from '../lib/vins.js';
  import { pourcentage } from '../lib/stats.js';
  import { accord } from '../lib/format.js';

  /** @type {{ regions: any[], couleurs: {code:number}[], titre?: string, tactile?: boolean }} */
  let { regions, couleurs, titre = 'Par région', tactile = false } = $props();

  let pret = $state(false);
  // Clés seulement (nom de région, code de couleur) : pas d'objet dans l'état réactif.
  let survol = $state(/** @type {{region:string, code:number}|null} */ (null));
  const detail = $derived.by(() => {
    if (!survol) return null;
    const region = regions.find((r) => r.nom === survol.region);
    const part = region?.couleurs.find((p) => p.code === survol.code);
    return part ? { region, part } : null;
  });

  onMount(() => {
    const id = requestAnimationFrame(() => requestAnimationFrame(() => (pret = true)));
    return () => cancelAnimationFrame(id);
  });

  function aller(r, code) {
    if (r.autres) return routeur.aller(code === undefined ? '/inventaire' : `/inventaire?couleur=${code}`);
    const q = [`region=${encodeURIComponent(r.nom)}`, code !== undefined && `couleur=${code}`].filter(Boolean).join('&');
    routeur.aller(`/inventaire?${q}`);
  }
</script>

<section class="carte" class:tactile>
  <span class="titre">{titre}</span>

  <div class="info" aria-live="polite">
    {#if detail}
      <span class="pastille" style:background={teinteGraphique(detail.part.code)}></span>
      <span><b>{detail.region.nom}</b> · {vin(detail.part.code).libelle} : <b class="tnum">{detail.part.n}</b>
        {accord(detail.part.n, 'bouteille')} ({pourcentage(detail.part.pct)} de la région)</span>
    {:else}
      <span class="legende">
        {#each couleurs as c (c.code)}
          <span class="l"><span class="pastille" style:background={teinteGraphique(c.code)}></span>{vin(c.code).libelle}</span>
        {/each}
      </span>
    {/if}
  </div>

  <div class="lignes">
    {#each regions as r, i (r.nom)}
      <div class="ligne" class:estompee={survol && survol.region !== r.nom}>
        <button type="button" class="r-nom" onclick={() => aller(r)}>{r.nom}</button>
        <span class="piste">
          {#each r.couleurs as p (p.code)}
            <button
              type="button"
              class="part"
              class:active={survol?.region === r.nom && survol?.code === p.code}
              style:width={pret ? `${p.largeur}%` : '0%'}
              style:background={teinteGraphique(p.code)}
              style:transition-delay="{i * 50}ms"
              aria-label="{r.nom}, {vin(p.code).libelle} : {p.n}"
              onpointerenter={(e) => e.pointerType !== 'touch' && (survol = { region: r.nom, code: p.code })}
              onpointerleave={() => (survol = null)}
              onfocus={() => (survol = { region: r.nom, code: p.code })}
              onblur={() => (survol = null)}
              onclick={() => aller(r, p.code)}
            ></button>
          {/each}
        </span>
        <button type="button" class="n tnum" onclick={() => aller(r)}>{r.n}</button>
      </div>
    {/each}
  </div>
</section>

<style>
  .carte {
    border: 1px solid var(--wt-line);
    background: var(--wt-card);
    border-radius: 14px;
    padding: 20px;
    display: flex;
    flex-direction: column;
    gap: 10px;
    min-width: 0;
  }
  .carte.tactile {
    border-radius: 18px;
    padding: 18px;
  }
  .titre {
    font-family: var(--font-serif);
    font-size: 20px;
    font-weight: 500;
  }
  .tactile .titre {
    font-size: 22px;
  }
  /* Hauteur fixe : la légende (deux lignes) et le détail d'une part (une ligne) s'y relaient sans
     déplacer les barres sous le pointeur. */
  .info {
    height: 36px;
    overflow: hidden;
    font-size: 12.5px;
    color: var(--wt-ink2);
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .info b {
    color: var(--wt-ink);
    font-weight: 600;
  }
  .legende {
    display: flex;
    flex-wrap: wrap;
    gap: 4px 12px;
    color: var(--wt-ink3);
  }
  .l {
    display: inline-flex;
    align-items: center;
    gap: 5px;
  }
  .pastille {
    width: 10px;
    height: 10px;
    border-radius: 3px;
    flex: none;
    box-shadow: inset 0 0 0 1px rgba(42, 29, 21, 0.15);
  }
  .lignes {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  .ligne {
    display: grid;
    grid-template-columns: 96px 1fr 32px;
    align-items: center;
    gap: 10px;
    min-height: 26px;
    transition: opacity 200ms var(--ease, ease);
  }
  .tactile .ligne {
    min-height: 32px;
  }
  .ligne.estompee {
    opacity: 0.45;
  }
  .r-nom,
  .n {
    border: 0;
    background: transparent;
    padding: 2px 4px;
    border-radius: 6px;
    color: var(--wt-ink);
    font-size: 13.5px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .tactile .r-nom,
  .tactile .n {
    font-size: 15px;
  }
  .r-nom {
    text-align: left;
  }
  .n {
    text-align: right;
    font-weight: 600;
  }
  .r-nom:hover,
  .n:hover {
    background: var(--wt-card2);
  }
  .piste {
    height: 14px;
    background: var(--wt-card2);
    border-radius: 4px;
    overflow: hidden;
    display: flex;
    gap: 1px;
  }
  .part {
    border: 0;
    padding: 0;
    height: 100%;
    min-width: 0;
    cursor: pointer;
    transition:
      width 800ms cubic-bezier(0.22, 1, 0.36, 1),
      filter 160ms,
      box-shadow 160ms;
    box-shadow: inset 0 0 0 1px rgba(42, 29, 21, 0.12);
  }
  .part.active,
  .part:focus-visible {
    filter: brightness(1.08) saturate(1.15);
    box-shadow: inset 0 0 0 2px var(--wt-ink);
    outline: none;
  }
  @media (prefers-reduced-motion: reduce) {
    .part {
      transition: none;
    }
  }
</style>
