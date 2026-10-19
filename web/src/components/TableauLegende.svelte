<script>
  // Légende en tableau du tableau de bord (stock et historiques) : pastille, verre ou blason,
  // libellé, puis colonnes chiffrées alignées à droite. Une ligne cliquable est un bouton.
  import WineGlass from './WineGlass.svelte';
  import Blason from './Blason.svelte';

  /**
   * @typedef {{ cle: string, libelle: string, teinte: string, couleur?: number, region?: string,
   *   valeurs: Array<string|number>, onclick?: () => void }} Ligne
   * @type {{ entete: string, colonnes: string[], lignes: Ligne[], variante?: 'stock'|'histo', label: string }}
   */
  let { entete, colonnes, lignes, variante = 'stock', label } = $props();
</script>

{#snippet cellules(l)}
  <span role="cell" class="nom">
    <span class="pastille" style:background={l.teinte}></span>
    {#if l.couleur !== undefined}<WineGlass couleur={l.couleur} taille={16} style="margin-left:-2px;color:var(--wt-ink)" />{/if}
    {#if l.region}<Blason region={l.region} style="margin-left:-2px" />{/if}
    <span class="coupe">{l.libelle}</span>
  </span>
  {#each l.valeurs as v, i (i)}
    <span role="cell" class="chiffre" class:fort={i === 0}>{v}</span>
  {/each}
{/snippet}

<div class="table {variante}" role="table" aria-label={label}>
  <div class="ligne entete" role="row">
    <span role="columnheader">{entete}</span>
    {#each colonnes as c (c)}<span role="columnheader" class="chiffre">{c}</span>{/each}
  </div>
  {#each lignes as l (l.cle)}
    {#if l.onclick}
      <button type="button" class="ligne corps cliquable" role="row" onclick={l.onclick}>{@render cellules(l)}</button>
    {:else}
      <div class="ligne corps" role="row">{@render cellules(l)}</div>
    {/if}
  {/each}
</div>

<style>
  .table {
    display: flex;
    flex-direction: column;
    border-top: 1px solid var(--wt-line);
    min-width: 0;
  }
  .ligne {
    display: grid;
    gap: 8px;
    align-items: center;
    border-bottom: 1px solid var(--wt-line);
  }
  .stock .ligne {
    grid-template-columns: minmax(0, 1fr) 84px 64px;
    padding: 0 6px;
  }
  .histo .ligne {
    grid-template-columns: minmax(0, 1fr) 60px 72px 48px;
  }
  .entete {
    height: 28px;
    font-size: 11.5px;
    font-weight: 600;
    color: var(--wt-ink3);
  }
  .corps {
    color: var(--wt-ink2);
    font-variant-numeric: tabular-nums;
  }
  .stock .corps {
    min-height: 30px;
    font-size: 13px;
  }
  .histo .corps {
    min-height: 28px;
    font-size: 12.5px;
  }
  button.ligne {
    width: 100%;
    border-top: 0;
    border-left: 0;
    border-right: 0;
    background: transparent;
    text-align: left;
    font-family: inherit;
    transition: background-color var(--t-micro) var(--ease);
  }
  button.ligne:hover {
    background: var(--wt-card2);
  }
  .nom {
    display: flex;
    align-items: center;
    gap: 8px;
    min-width: 0;
    color: var(--wt-ink);
  }
  .pastille {
    width: 10px;
    height: 10px;
    border-radius: 3px;
    flex: none;
    box-shadow: inset 0 0 0 1px rgba(42, 29, 21, 0.15);
  }
  .coupe {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .chiffre {
    text-align: right;
    font-variant-numeric: tabular-nums;
  }
  .fort {
    font-weight: 600;
    color: var(--wt-ink);
  }

  /* Téléphone */
  :global(.telephone) .entete {
    font-size: 12px;
  }
  :global(.telephone) .stock .ligne {
    grid-template-columns: minmax(0, 1fr) 56px 60px;
  }
  :global(.telephone) .stock .corps {
    min-height: 44px;
    font-size: 14px;
  }
  :global(.telephone) .histo .ligne {
    grid-template-columns: minmax(0, 1fr) 44px 64px 36px;
  }
  :global(.telephone) .histo .corps {
    min-height: 34px;
    font-size: 13px;
  }
</style>
