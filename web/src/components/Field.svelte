<script>
  // Champ de formulaire : libellé au-dessus, contrôle, message d'erreur.
  // Le style du contrôle vient des classes globales .champ (voir app.css), adaptées au format.
  import Icon from './Icon.svelte';

  /**
   * @type {{ label: string, id?: string, erreur?: string, facultatif?: boolean, aide?: string,
   *   style?: string, children: any }}
   */
  let { label, id, erreur = '', facultatif = false, aide = '', style = '', children } = $props();
</script>

<div class="field" class:en-erreur={!!erreur} {style}>
  <label for={id}>{label}{#if facultatif}<span class="facultatif">{' · facultatif'}</span>{/if}</label>
  {@render children()}
  {#if erreur}
    <span class="message" role="alert"><Icon nom="alert" taille={14} epaisseur={2} />{erreur}</span>
  {:else if aide}
    <span class="aide">{aide}</span>
  {/if}
</div>

<style>
  .field {
    display: flex;
    flex-direction: column;
    gap: 6px;
    min-width: 0;
  }
  label {
    font-size: 14px;
    font-weight: 600;
  }
  .facultatif {
    font-weight: 400;
    color: var(--wt-ink3);
  }
  .message {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 14px;
    color: var(--wt-danger);
    line-height: 1.3;
  }
  .aide {
    font-size: 12px;
    color: var(--wt-ink3);
  }
  .en-erreur label {
    color: var(--wt-danger);
  }

  :global(.ordinateur) .field {
    gap: 5px;
  }
  :global(.ordinateur) label {
    font-size: 12.5px;
    color: var(--wt-ink2);
  }
  :global(.ordinateur) .en-erreur label {
    color: var(--wt-danger);
  }
  :global(.ordinateur) .message {
    font-size: 12.5px;
  }
</style>
