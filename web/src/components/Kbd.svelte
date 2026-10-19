<script>
  /** Raccourci clavier affiché dans un bouton (ordinateur). */
  let { touche, discret = false } = $props();
</script>

<span class="kbd" class:discret>{touche}</span>

<style>
  .kbd {
    font-family: var(--font-mono);
    font-weight: 500;
    font-size: 11px;
    border: 1px solid currentColor;
    border-radius: 4px;
    padding: 0 4px;
    opacity: 0.6;
    line-height: 16px;
  }
  .discret {
    border-color: var(--wt-line2);
    opacity: 1;
    line-height: 16px;
  }
</style>
