<script>
  // Blason d'une région, à gauche de son nom (rien si la région n'en a pas).
  import { blason } from '../lib/blasons.js';

  /** @type {{ region: string|null|undefined, largeur?: number, hauteur?: number, style?: string }} */
  let { region, largeur = 12, hauteur = 15, style = '' } = $props();

  const src = $derived(blason(region));
</script>

{#if src}<img {src} alt="" width={largeur} height={hauteur} {style} />{/if}

<style>
  img {
    flex: none;
    display: block;
  }
</style>
