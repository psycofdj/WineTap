<script>
  // E-07 — Tableau de bord (ordinateur) : total, alertes de garde, stock par couleur, appellation ou
  // région, consommations et achats des 12 derniers mois.
  import { onMount } from 'svelte';
  import { ctx } from '../../lib/contexte.svelte.js';
  import { routeur } from '../../lib/routeur.svelte.js';
  import { cave } from '../../lib/stores/cave.svelte.js';
  import { tableau } from '../../lib/stores/tableau.svelte.js';
  import { statistiques } from '../../lib/stats.js';
  import { pluriel, accord } from '../../lib/format.js';
  import { toast } from '../../lib/toast.svelte.js';
  import CarteStock from '../../components/CarteStock.svelte';
  import Histogramme from '../../components/Histogramme.svelte';

  const s = $derived(statistiques(cave.enStock));
  const liste = (noms) => (noms.length > 3 ? noms.slice(0, 3).join(', ') + '…' : noms.join(', '));

  // Les historiques ont besoin des bouteilles consommées (chargées à la demande).
  onMount(() => {
    if (!cave.consommeesBrutes) cave.chargerConsommees().catch((e) => toast.afficher(e.message));
  });
  const consommees = $derived(cave.consommeesBrutes ? cave.consommees : null);
  const entrees = $derived(cave.consommeesBrutes ? [...cave.enStock, ...cave.consommees] : null);

  /** Inventaire filtré sur la ligne choisie ; « Autres » ouvre l'inventaire sans filtre. */
  function ouvrir(l, par) {
    if (l.autres) return routeur.aller('/inventaire?tout');
    const cle = par === 'couleur' ? 'couleur' : par === 'appellation' ? 'appellation' : 'region';
    routeur.aller(`/inventaire?${cle}=${encodeURIComponent(par === 'couleur' ? l.couleur : l.cle)}`);
  }
</script>

<div class="page">
  <h1>Tableau de bord</h1>
  <div class="grille">
    <div class="col1">
      <button type="button" class="total" onclick={() => routeur.aller('/inventaire?tout')}>
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

    <div class="stock"><CarteStock enStock={cave.enStock} onchoisir={ouvrir} /></div>
  </div>

  <div class="histos">
    <Histogramme titre="Consommations" bouteilles={consommees} champ="consommee_le" bind:par={tableau.conso} verbe="consommées" vide="Aucune bouteille consommée sur les 12 derniers mois." />
    <Histogramme titre="Achats" bouteilles={entrees} champ="entree_le" bind:par={tableau.achats} verbe="entrées en stock" montant vide="Aucune bouteille entrée en stock sur les 12 derniers mois." />
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
  /* La carte « Stock » occupe les deux colonnes à droite des alertes. */
  .stock {
    grid-column: span 2;
    min-width: 0;
  }
  @media (max-width: 900px) {
    .grille {
      grid-template-columns: 1fr;
    }
    .stock {
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
</style>
