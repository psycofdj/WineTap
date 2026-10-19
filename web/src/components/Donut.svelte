<script>
  // Anneau du stock (E-07) : dégradé conique, total au centre.
  import { accord } from '../lib/format.js';

  /** @type {{ fond: string, total: number, taille?: number, trou?: number, tailleChiffre?: number }} */
  let { fond, total, taille = 190, trou = 116, tailleChiffre = 30 } = $props();
</script>

<div class="anneau" style:width="{taille}px" style:height="{taille}px" style:background={fond} role="img" aria-label="{total} {accord(total, 'bouteille')}">
  <span class="trou" style:width="{trou}px" style:height="{trou}px">
    <span class="chiffre" style:font-size="{tailleChiffre}px">{total}</span>
    <span class="lib">{accord(total, 'bouteille')}</span>
  </span>
</div>

<style>
  .anneau {
    flex: none;
    border-radius: 999px;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .trou {
    border-radius: 999px;
    background: var(--wt-card);
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
  }
  .chiffre {
    font-family: var(--font-serif);
    line-height: 1;
    font-variant-numeric: tabular-nums;
  }
  .lib {
    font-size: 12px;
    color: var(--wt-ink3);
  }
</style>
