<script>
  // E-07 — Tableau de bord (téléphone) : stock par couleur, appellation ou région, consommations et
  // achats des 12 derniers mois.
  import { onMount } from 'svelte';
  import { routeur } from '../../lib/routeur.svelte.js';
  import { cave } from '../../lib/stores/cave.svelte.js';
  import { tableau } from '../../lib/stores/tableau.svelte.js';
  import { toast } from '../../lib/toast.svelte.js';
  import EnTete from '../../components/EnTete.svelte';
  import CarteStock from '../../components/CarteStock.svelte';
  import Histogramme from '../../components/Histogramme.svelte';

  onMount(() => {
    if (!cave.consommeesBrutes) cave.chargerConsommees().catch((e) => toast.afficher(e.message));
  });
  const consommees = $derived(cave.consommeesBrutes ? cave.consommees : null);
  const entrees = $derived(cave.consommeesBrutes ? [...cave.enStock, ...cave.consommees] : null);

  /** Sur téléphone, seul le filtre par couleur existe : les autres lignes ouvrent tout l'inventaire. */
  function ouvrir(l, par) {
    if (par === 'couleur' && [1, 2, 3, 4].includes(l.couleur)) routeur.aller(`/inventaire?couleur=${l.couleur}`);
    else routeur.aller('/inventaire');
  }
</script>

<div class="page">
  <EnTete titre="Tableau de bord" retour="/accueil" />
  <CarteStock enStock={cave.enStock} onchoisir={ouvrir} />
  <Histogramme titre="Consommations" bouteilles={consommees} champ="consommee_le" bind:par={tableau.conso} verbe="consommées" hauteur={130} vide="Aucune bouteille consommée sur les 12 derniers mois." />
  <Histogramme titre="Achats" bouteilles={entrees} champ="entree_le" bind:par={tableau.achats} verbe="entrées en stock" montant hauteur={130} vide="Aucune bouteille entrée en stock sur les 12 derniers mois." />
</div>

<style>
  .page {
    display: flex;
    flex-direction: column;
    padding: 0 20px 24px;
    gap: 16px;
  }
</style>
