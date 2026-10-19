<script>
  // E-07 — Tableau de bord (téléphone) : anneau des couleurs, régions par couleur, consommations et
  // achats des 12 derniers mois.
  import { onMount } from 'svelte';
  import { routeur } from '../../lib/routeur.svelte.js';
  import { cave } from '../../lib/stores/cave.svelte.js';
  import { statistiques, parMois, pourcentage } from '../../lib/stats.js';
  import { vin } from '../../lib/vins.js';
  import { toast } from '../../lib/toast.svelte.js';
  import EnTete from '../../components/EnTete.svelte';
  import WineGlass from '../../components/WineGlass.svelte';
  import Icon from '../../components/Icon.svelte';
  import Donut from '../../components/Donut.svelte';
  import Histogramme from '../../components/Histogramme.svelte';
  import RegionsCouleurs from '../../components/RegionsCouleurs.svelte';

  const s = $derived(statistiques(cave.enStock));
  let actif = $state(/** @type {number|null} */ (null));

  onMount(() => {
    if (!cave.consommeesBrutes) cave.chargerConsommees().catch((e) => toast.afficher(e.message));
  });
  const consommations = $derived(cave.consommeesBrutes ? parMois(cave.consommees, 'consommee_le') : null);
  const achats = $derived(cave.consommeesBrutes ? parMois([...cave.enStock, ...cave.consommees], 'entree_le') : null);
</script>

<div class="page">
  <EnTete titre="Tableau de bord" retour="/accueil" />
  <div class="carte couleurs">
    <div style:--taille-chiffre="40px">
      <Donut parts={s.couleurs} total={s.total} taille={210} bind:actif onchoisir={(c) => routeur.aller(`/inventaire?couleur=${c}`)} />
    </div>
    <div class="lignes">
      {#each s.couleurs as c (c.code)}
        <button type="button" class="ligne" class:active={actif === c.code} onclick={() => routeur.aller(`/inventaire?couleur=${c.code}`)}>
          <WineGlass couleur={c.code} taille={20} />
          <span class="nom">{vin(c.code).libelle}</span>
          <span class="pct">{pourcentage(c.pct)}</span>
          <b>{c.n}</b>
          <Icon nom="chevR" taille={16} couleur="var(--wt-ink3)" />
        </button>
      {/each}
    </div>
  </div>
  <RegionsCouleurs regions={s.regions} couleurs={s.couleurs} tactile />
  <Histogramme titre="Consommations" donnees={consommations} verbe="consommées" hauteur={130} vide="Aucune bouteille consommée sur les 12 derniers mois." />
  <Histogramme titre="Achats" donnees={achats} verbe="entrées en stock" montant hauteur={130} vide="Aucune bouteille entrée en stock sur les 12 derniers mois." />
</div>

<style>
  .page {
    display: flex;
    flex-direction: column;
    padding: 0 20px 24px;
    gap: 16px;
  }
  .carte {
    background: var(--wt-card);
    border: 1px solid var(--wt-line);
    border-radius: 18px;
  }
  .couleurs {
    padding: 20px;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 16px;
  }
  .lignes {
    width: 100%;
    display: flex;
    flex-direction: column;
  }
  .ligne {
    border: 0;
    border-top: 1px solid var(--wt-line);
    background: transparent;
    display: flex;
    align-items: center;
    gap: 10px;
    min-height: 46px;
    color: var(--wt-ink);
    font-size: 15px;
    padding: 0 2px;
  }
  .nom {
    flex: 1;
    text-align: left;
  }
  .ligne.active {
    background: var(--wt-card2);
  }
  .pct {
    font-size: 13px;
    color: var(--wt-ink3);
  }
  b {
    font-weight: 600;
  }
</style>
