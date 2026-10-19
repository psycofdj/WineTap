<script>
  // Repère de couleur du vin (D-16) : verre en currentColor, liquide de la teinte du vin.
  import { vin } from '../lib/vins.js';

  /** @type {{ couleur: number, taille?: number, epaisseur?: number, style?: string, opacite?: number }} */
  let { couleur, taille = 20, epaisseur = 1.3, style = '', opacite = 1 } = $props();

  const v = $derived(vin(couleur));
</script>

<svg viewBox="0 0 20 20" width={taille} height={taille} aria-hidden="true" style="flex:none;opacity:{opacite};{style}">
  {#if v.liquide}<path d={v.liquide} style="fill:{v.teinte}" />{/if}
  <path
    d={v.verre}
    style="fill:none;stroke:currentColor;stroke-width:{epaisseur};stroke-linecap:round;stroke-linejoin:round"
  />
</svg>
