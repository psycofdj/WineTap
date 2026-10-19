<script>
  // État « à boire avant » : aucune / ok / cette année / dépassée (année courante du téléphone).
  import { ctx } from '../lib/contexte.svelte.js';
  import { etatGarde, LIBELLE_GARDE, gardeSignalee } from '../lib/garde.js';
  import Icon from './Icon.svelte';

  /**
   * forme :
   * - 'table'    : cellule de l'inventaire ordinateur (année en 600 + libellé)
   * - 'liste'    : sous une ligne de liste téléphone (« Avant 2026 · cette année »), si signalée
   * - 'pastille' : pastille ronde des fiches, si signalée
   * - 'fiche'    : pastille ronde avec horloge (« À boire avant 2026 · cette année »), si signalée
   * @type {{ annee: number|null|undefined, forme?: 'table'|'liste'|'pastille'|'fiche', taille?: number }}
   */
  let { annee, forme = 'table', taille } = $props();

  const etat = $derived(etatGarde(annee, ctx.annee));
  const signalee = $derived(gardeSignalee(etat));
  const libelle = $derived(LIBELLE_GARDE[etat]);
</script>

{#if forme === 'table'}
  {#if etat === 'aucune'}
    <span class="vide">—</span>
  {:else}
    <span class="badge table {etat}"><b>{annee}</b>{#if libelle}{libelle}{/if}</span>
  {/if}
{:else if signalee}
  {#if forme === 'liste'}
    <span class="badge liste {etat}">Avant {annee} · {libelle}</span>
  {:else if forme === 'fiche'}
    <span class="pastille {etat}" style:font-size={taille ? taille + 'px' : null}
      ><Icon nom="clock" taille={14} epaisseur={2.2} />À boire avant {annee} · {libelle}</span
    >
  {:else}
    <span class="pastille {etat}" style:font-size={taille ? taille + 'px' : null}>Avant {annee} · {libelle}</span>
  {/if}
{/if}

<style>
  .badge {
    display: inline-flex;
    align-items: center;
    border-radius: var(--r-xs);
    font-variant-numeric: tabular-nums;
  }
  .table {
    gap: 5px;
    padding: 1px 7px;
    font-size: 13px;
  }
  .table b {
    font-weight: 600;
  }
  .table.ok {
    color: var(--wt-ink2);
  }
  .liste {
    align-self: flex-start;
    margin-top: 3px;
    padding: 1px 7px;
    font-size: 12px;
    font-weight: 600;
  }
  .depassee {
    background: var(--wt-danger-tint);
    color: var(--wt-danger);
  }
  .annee {
    background: var(--wt-warn-tint);
    color: var(--wt-warn);
  }
  .vide {
    color: var(--wt-ink3);
    padding-left: 7px;
  }
  .pastille {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    border-radius: var(--r-pill);
    padding: 4px 10px;
    font-size: 13px;
    font-weight: 600;
  }
</style>
