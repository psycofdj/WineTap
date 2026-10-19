<script>
  // Carte « Stock » du tableau de bord (§ 8.1) : anneau et tableau, par couleur, appellation ou
  // région. Chaque ligne ouvre l'inventaire filtré (`onchoisir`).
  import { ctx } from '../lib/contexte.svelte.js';
  import { repartition, pourcentage } from '../lib/stats.js';
  import { tableau } from '../lib/stores/tableau.svelte.js';
  import Donut from './Donut.svelte';
  import Selecteur from './Selecteur.svelte';
  import TableauLegende from './TableauLegende.svelte';

  /** @type {{ enStock: any[], onchoisir: (ligne: any, par: 'couleur'|'appellation'|'region') => void }} */
  let { enStock, onchoisir } = $props();

  const OPTIONS = [
    { valeur: 'couleur', libelle: 'Couleur' },
    { valeur: 'appellation', libelle: 'Appellation' },
    { valeur: 'region', libelle: 'Région' },
  ];

  const r = $derived(repartition(enStock, tableau.stock));
  const lignes = $derived(
    r.lignes.map((l) => ({ ...l, valeurs: [l.n, pourcentage(l.pct)], onclick: () => onchoisir(l, tableau.stock) })),
  );
</script>

<section class="carte">
  <div class="tete">
    <span class="titre">Stock</span>
    <Selecteur options={OPTIONS} bind:valeur={tableau.stock} label="Répartition du stock" />
  </div>
  <div class="corps">
    {#if ctx.ordinateur}
      <Donut fond={r.fond} total={r.total} />
    {:else}
      <div class="centre"><Donut fond={r.fond} total={r.total} taille={200} trou={124} tailleChiffre={32} /></div>
    {/if}
    <div class="legende">
      {#if lignes.length}
        <TableauLegende entete={r.entete} colonnes={['Bouteilles', 'Part']} {lignes} label="Stock par {r.entete.toLowerCase()}" />
      {:else}
        <span class="vide">La cave est vide.</span>
      {/if}
    </div>
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
    gap: 16px;
    min-width: 0;
  }
  .tete {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 10px 12px;
    flex-wrap: wrap;
  }
  .titre {
    font-family: var(--font-serif);
    font-size: 20px;
    font-weight: 500;
  }
  .corps {
    display: flex;
    gap: 28px;
    align-items: center;
    flex-wrap: wrap;
  }
  .legende {
    flex: 1;
    min-width: 280px;
    width: 100%;
  }
  .vide {
    font-size: 13.5px;
    color: var(--wt-ink3);
  }

  /* Téléphone : anneau centré, tableau dessous. */
  :global(.telephone) .carte {
    border-radius: 18px;
    padding: 18px;
  }
  :global(.telephone) .tete {
    align-items: center;
  }
  :global(.telephone) .titre {
    font-size: 22px;
  }
  :global(.telephone) .corps {
    flex-direction: column;
    align-items: stretch;
    gap: 16px;
  }
  :global(.telephone) .legende {
    min-width: 0;
  }
  .centre {
    display: flex;
    justify-content: center;
  }
</style>
