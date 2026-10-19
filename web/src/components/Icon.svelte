<script>
  import { I } from '../lib/icones.js';

  /** @type {{ nom: keyof typeof I, taille?: number, epaisseur?: number, couleur?: string, style?: string }} */
  let { nom, taille = 24, epaisseur = 1.75, couleur = 'currentColor', style = '' } = $props();
</script>

<svg
  viewBox="0 0 24 24"
  width={taille}
  height={taille}
  aria-hidden="true"
  style="flex:none;fill:none;stroke:{couleur};stroke-width:{epaisseur};stroke-linecap:round;stroke-linejoin:round;{style}"
>
  <path d={I[nom]} />
</svg>
