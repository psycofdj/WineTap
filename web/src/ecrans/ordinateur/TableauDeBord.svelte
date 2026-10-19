<script>
  // E-07 — Tableau de bord (ordinateur) : total, alertes de garde, couleurs, régions par couleur,
  // consommations et achats des 12 derniers mois.
  import { onMount } from 'svelte';
  import { ctx } from '../../lib/contexte.svelte.js';
  import { routeur } from '../../lib/routeur.svelte.js';
  import { cave } from '../../lib/stores/cave.svelte.js';
  import { statistiques, pourcentage, parMois } from '../../lib/stats.js';
  import { vin } from '../../lib/vins.js';
  import { pluriel, accord } from '../../lib/format.js';
  import { toast } from '../../lib/toast.svelte.js';
  import WineGlass from '../../components/WineGlass.svelte';
  import Donut from '../../components/Donut.svelte';
  import Histogramme from '../../components/Histogramme.svelte';
  import RegionsCouleurs from '../../components/RegionsCouleurs.svelte';

  const s = $derived(statistiques(cave.enStock));
  const liste = (noms) => (noms.length > 3 ? noms.slice(0, 3).join(', ') + '…' : noms.join(', '));
  let actif = $state(/** @type {number|null} */ (null));

  // Les histogrammes ont besoin des bouteilles consommées (chargées à la demande).
  onMount(() => {
    if (!cave.consommeesBrutes) cave.chargerConsommees().catch((e) => toast.afficher(e.message));
  });
  const consommations = $derived(cave.consommeesBrutes ? parMois(cave.consommees, 'consommee_le') : null);
  const achats = $derived(cave.consommeesBrutes ? parMois([...cave.enStock, ...cave.consommees], 'entree_le') : null);
</script>

<div class="page">
  <h1>Tableau de bord</h1>
  <div class="grille">
    <div class="col1">
      <button type="button" class="total" onclick={() => routeur.aller('/inventaire')}>
        <span class="lib">En stock</span>
        <span class="chiffre">{s.total}</span>
        <span class="lib2">{accord(s.total, 'bouteille')} · {pluriel(s.references, 'référence')}</span>
      </button>
      <button type="button" class="alerte warn" onclick={() => routeur.aller('/inventaire?garde=annee')}>
        <span class="a-titre">À boire en {ctx.annee}</span>
        <span class="a-texte">{[s.annee.n ? pluriel(s.annee.n, 'bouteille') : 'Aucune bouteille', liste(s.annee.noms)].filter(Boolean).join(' · ')}</span>
      </button>
      <button type="button" class="alerte danger" onclick={() => routeur.aller('/inventaire?garde=depassee')}>
        <span class="a-titre">Garde dépassée</span>
        <span class="a-texte">{[s.depassee.n ? pluriel(s.depassee.n, 'bouteille') : 'Aucune bouteille', liste(s.depassee.noms)].filter(Boolean).join(' · ')}</span>
      </button>
    </div>

    <section class="carte">
      <span class="c-titre">Par couleur</span>
      <div class="couleurs">
        <Donut parts={s.couleurs} total={s.total} taille={180} bind:actif onchoisir={(c) => routeur.aller(`/inventaire?couleur=${c}`)} />
        <div class="legende">
          {#each s.couleurs as c (c.code)}
            <button
              type="button"
              class="leg"
              class:active={actif === c.code}
              onpointerenter={() => (actif = c.code)}
              onpointerleave={() => (actif = null)}
              onfocus={() => (actif = c.code)}
              onblur={() => (actif = null)}
              onclick={() => routeur.aller(`/inventaire?couleur=${c.code}`)}
            >
              <WineGlass couleur={c.code} taille={18} />
              <span class="leg-nom">{vin(c.code).libelle}</span>
              <b class="tnum">{c.n}</b>
              <span class="pct tnum">{pourcentage(c.pct)}</span>
            </button>
          {/each}
        </div>
      </div>
    </section>

    <RegionsCouleurs regions={s.regions} couleurs={s.couleurs} />
  </div>

  <div class="histos">
    <Histogramme titre="Consommations" donnees={consommations} verbe="consommées" vide="Aucune bouteille consommée sur les 12 derniers mois." />
    <Histogramme titre="Achats" donnees={achats} verbe="entrées en stock" montant vide="Aucune bouteille entrée en stock sur les 12 derniers mois." />
  </div>
</div>

<style>
  .page {
    flex: 1;
    overflow: auto;
    padding: 20px 24px 24px;
    display: flex;
    flex-direction: column;
    gap: 16px;
  }
  h1 {
    font-family: var(--font-serif);
    font-size: 30px;
    font-weight: 500;
    letter-spacing: -0.01em;
  }
  .grille {
    display: grid;
    grid-template-columns: 280px minmax(0, 1fr) minmax(0, 1fr);
    gap: 16px;
    align-items: start;
  }
  @media (max-width: 1120px) {
    .grille {
      grid-template-columns: 280px minmax(0, 1fr);
    }
    /* Le total et les alertes occupent la première colonne sur deux lignes : couleurs et régions
       s'empilent dans la seconde, sans vide entre elles. */
    .col1 {
      grid-row: 1 / span 2;
    }
    .grille > :global(:last-child) {
      grid-column: 2;
    }
  }
  @media (max-width: 900px) {
    .grille {
      grid-template-columns: 1fr;
    }
    .col1 {
      grid-row: auto;
    }
    .grille > :global(:last-child) {
      grid-column: auto;
    }
  }
  .histos {
    display: grid;
    grid-template-columns: minmax(0, 1fr) minmax(0, 1fr);
    gap: 16px;
  }
  @media (max-width: 1000px) {
    .histos {
      grid-template-columns: 1fr;
    }
  }
  .col1 {
    display: flex;
    flex-direction: column;
    gap: 16px;
  }
  .total {
    text-align: left;
    border: 1px solid var(--wt-line);
    background: var(--wt-card);
    border-radius: 14px;
    padding: 20px;
    color: var(--wt-ink);
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  .lib {
    font-size: 13px;
    color: var(--wt-ink2);
  }
  .chiffre {
    font-family: var(--font-serif);
    font-size: 72px;
    line-height: 1;
    font-weight: 500;
  }
  .lib2 {
    font-size: 13.5px;
    color: var(--wt-ink2);
  }
  .alerte {
    text-align: left;
    border: 0;
    border-radius: 14px;
    padding: 14px 16px;
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .alerte.warn {
    background: var(--wt-warn-tint);
  }
  .alerte.danger {
    background: var(--wt-danger-tint);
  }
  .a-titre {
    font-size: 13px;
    font-weight: 600;
  }
  .warn .a-titre {
    color: var(--wt-warn);
  }
  .danger .a-titre {
    color: var(--wt-danger);
  }
  .a-texte {
    font-size: 15px;
    color: var(--wt-ink);
  }
  .carte {
    border: 1px solid var(--wt-line);
    background: var(--wt-card);
    border-radius: 14px;
    padding: 20px;
    display: flex;
    flex-direction: column;
    gap: 12px;
  }
  .c-titre {
    font-family: var(--font-serif);
    font-size: 20px;
    font-weight: 500;
  }
  .couleurs {
    display: flex;
    flex-wrap: wrap;
    justify-content: center;
    gap: 16px 22px;
    align-items: center;
    margin-top: 4px;
  }
  .legende {
    flex: 1;
    min-width: 210px;
    display: flex;
    flex-direction: column;
  }
  .leg {
    border: 0;
    background: transparent;
    display: flex;
    align-items: center;
    gap: 8px;
    height: 30px;
    padding: 0 6px;
    border-radius: 6px;
    color: var(--wt-ink);
    font-size: 13.5px;
  }
  .leg:hover,
  .leg.active {
    background: var(--wt-card2);
  }
  .leg-nom {
    flex: 1;
    text-align: left;
  }
  b {
    font-weight: 600;
  }
  .pct {
    width: 52px;
    text-align: right;
    color: var(--wt-ink3);
  }
</style>
