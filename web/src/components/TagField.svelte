<script>
  // Champ « Tag NFC » du formulaire de bouteille.
  // États : vide, attente (lecture demandée au téléphone), lu, déjà associé à une autre bouteille.
  import { ctx } from '../lib/contexte.svelte.js';
  import { lireTag, annulerLecture } from '../lib/nfc.js';
  import { cave } from '../lib/stores/cave.svelte.js';
  import { toast } from '../lib/toast.svelte.js';
  import { millesime } from '../lib/format.js';
  import Icon from './Icon.svelte';

  /** @type {{ tagId?: string|null, exclure?: number|null, erreur?: string }} */
  let { tagId = $bindable(null), exclure = null, erreur = '' } = $props();

  let attente = $state(false);
  /** @type {any} */
  let deja = $state(null);
  let tagDeja = $state('');

  export async function lire() {
    deja = null;
    attente = true;
    const r = await lireTag('entree');
    attente = false;
    if (r.annule) {
      toast.afficher('Lecture annulée');
      return;
    }
    if (r.erreur) {
      toast.afficher(r.erreur === 'injoignable' ? 'Téléphone injoignable, réessayez' : 'Lecture impossible, réessayez');
      return;
    }
    const occupe = cave.parTag(r.tag_id);
    if (occupe && occupe.id !== exclure) {
      deja = occupe;
      tagDeja = r.tag_id;
      return;
    }
    tagId = r.tag_id;
  }

  function annuler() {
    annulerLecture();
  }
</script>

{#if ctx.ordinateur}
  <div class="o-champ">
    <span class="o-label" class:rouge={!!erreur}>Tag NFC</span>
    {#if attente}
      <div class="o-boite attente">
        <span class="rond"><Icon nom="nfc" taille={20} epaisseur={1.9} /></span>
        <span class="textes"><span class="t1">En attente du tag</span><span class="t2">Présentez le tag au téléphone</span></span>
        <button type="button" class="o-petit" onclick={annuler}>Annuler</button>
      </div>
    {:else if deja}
      <div class="o-boite deja">
        <span class="ligne-deja"><Icon nom="tag" taille={18} epaisseur={1.9} />Tag déjà associé<span class="uid">{tagDeja}</span></span>
        <span class="explication">Ce tag est sur une bouteille en stock : {deja.domaine?.nom} · {deja.cuvee?.nom} {millesime(deja.millesime)}.</span>
        <button type="button" class="o-petit gras" onclick={lire}>Lire un autre tag</button>
      </div>
    {:else if tagId}
      <div class="o-boite lu">
        <Icon nom="check" taille={20} epaisseur={2.2} /><span class="t-lu">Tag lu</span><span class="uid">{tagId}</span>
        <button type="button" class="o-lien" onclick={lire} title="Lire un autre tag">Changer</button>
      </div>
    {:else}
      <div class="o-boite vide">
        <span class="aucun">Aucun tag associé</span>
        <button type="button" class="lire" onclick={lire}><Icon nom="nfc" taille={15} epaisseur={1.9} />Lire avec le téléphone</button>
      </div>
    {/if}
    {#if erreur}<span class="o-erreur"><Icon nom="alert" taille={14} epaisseur={2} />{erreur}</span>{/if}
  </div>
{:else}
  <div class="t-champ">
    <span class="t-label" class:rouge={!!erreur}>Tag</span>
    {#if attente && !ctx.dansApplication}
      <div class="t-boite attente">
        <span class="rond"><Icon nom="nfc" taille={22} epaisseur={1.9} /></span>
        <span class="textes"><span class="t1">En attente du tag</span><span class="t2">Présentez le tag au téléphone</span></span>
        <button type="button" class="o-petit" onclick={annuler}>Annuler</button>
      </div>
    {:else if deja}
      <div class="t-boite deja">
        <span class="ligne-deja"><Icon nom="tag" taille={20} epaisseur={1.9} />Tag déjà associé<span class="uid">{tagDeja}</span></span>
        <span class="explication">Ce tag est sur une bouteille en stock : {deja.domaine?.nom} · {deja.cuvee?.nom} {millesime(deja.millesime)}.</span>
        <button type="button" class="t-autre" onclick={lire}>Lire un autre tag</button>
      </div>
    {:else if tagId}
      <button type="button" class="t-lu-boite" onclick={lire} title="Lire un autre tag">
        <Icon nom="check" taille={22} epaisseur={2.2} /><span class="gras">Tag lu</span><span class="uid">{tagId}</span>
      </button>
    {:else}
      <button type="button" class="t-lire" class:erreur={!!erreur} onclick={lire}>
        <Icon nom="nfc" taille={24} />{ctx.dansApplication ? 'Lire le tag de la bouteille' : 'Lire avec le téléphone'}
      </button>
    {/if}
    {#if erreur}<span class="t-erreur"><Icon nom="alert" taille={16} epaisseur={2} />{erreur}</span>{/if}
  </div>
{/if}

<style>
  /* Ordinateur */
  .o-champ {
    display: flex;
    flex-direction: column;
    gap: 5px;
  }
  .o-label {
    font-size: 12.5px;
    font-weight: 600;
    color: var(--wt-ink2);
  }
  .rouge {
    color: var(--wt-danger) !important;
  }
  .o-boite {
    border-radius: 10px;
    padding: 12px;
    display: flex;
    align-items: center;
    gap: 10px;
  }
  .vide {
    border: 1px dashed var(--wt-line2);
    justify-content: space-between;
  }
  .aucun {
    font-size: 13.5px;
    color: var(--wt-ink2);
  }
  .lire {
    height: 32px;
    border-radius: 8px;
    border: 0;
    background: var(--wt-ink);
    color: var(--wt-paper);
    padding: 0 12px;
    font-size: 13px;
    font-weight: 600;
    display: flex;
    align-items: center;
    gap: 6px;
    white-space: nowrap;
  }
  .attente {
    background: var(--wt-accent-tint);
    gap: 12px;
  }
  .rond {
    width: 40px;
    height: 40px;
    border-radius: 99px;
    background: var(--wt-accent);
    color: var(--wt-on-accent);
    display: flex;
    align-items: center;
    justify-content: center;
    flex: none;
    box-shadow: 0 0 0 6px rgba(123, 30, 46, 0.12);
    animation: pouls 1.6s var(--ease) infinite;
  }
  @keyframes pouls {
    50% {
      box-shadow: 0 0 0 10px rgba(123, 30, 46, 0.06);
    }
  }
  .textes {
    flex: 1;
    display: flex;
    flex-direction: column;
  }
  .t1 {
    font-size: 14px;
    font-weight: 600;
    color: var(--wt-accent-ink);
  }
  .t2 {
    font-size: 12.5px;
    color: var(--wt-ink2);
  }
  .o-petit {
    height: 30px;
    border-radius: 8px;
    border: 1px solid var(--wt-line2);
    background: var(--wt-card);
    color: var(--wt-ink);
    padding: 0 10px;
    font-size: 13px;
    white-space: nowrap;
  }
  .gras {
    font-weight: 600;
  }
  .lu {
    background: var(--wt-ok-tint);
    color: var(--wt-ok);
  }
  .t-lu {
    font-size: 14px;
    font-weight: 600;
  }
  .uid {
    font-family: var(--font-mono);
    font-weight: 500;
    color: var(--wt-ink);
    margin-left: auto;
    font-size: 14px;
    letter-spacing: 0.05em;
  }
  .o-lien {
    border: 0;
    background: transparent;
    color: var(--wt-ok);
    font-size: 12.5px;
    font-weight: 600;
    padding: 0 0 0 6px;
    text-decoration: underline;
    text-underline-offset: 2px;
  }
  .deja {
    background: var(--wt-warn-tint);
    flex-direction: column;
    align-items: stretch;
    gap: 8px;
  }
  .ligne-deja {
    display: flex;
    align-items: center;
    gap: 8px;
    color: var(--wt-warn);
    font-size: 14px;
    font-weight: 600;
  }
  .explication {
    font-size: 13px;
    color: var(--wt-ink);
  }
  .deja .o-petit {
    align-self: flex-start;
  }
  .o-erreur {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 12.5px;
    color: var(--wt-danger);
  }

  /* Téléphone */
  .t-champ {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  .t-label {
    font-size: 14px;
    font-weight: 600;
  }
  .t-lire {
    height: 64px;
    border-radius: var(--r-xl);
    border: 1.5px dashed var(--wt-accent);
    background: var(--wt-accent-tint);
    color: var(--wt-accent-ink);
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 10px;
    font-size: 16px;
    font-weight: 600;
  }
  .t-lire.erreur {
    border-color: var(--wt-danger);
  }
  .t-lu-boite {
    height: 64px;
    border-radius: var(--r-xl);
    border: 0;
    background: var(--wt-ok-tint);
    color: var(--wt-ok);
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 0 16px;
    font-size: 16px;
  }
  .t-lu-boite .uid {
    font-size: 16px;
  }
  .t-boite {
    border-radius: var(--r-xl);
    padding: 14px 16px;
    display: flex;
    align-items: center;
    gap: 12px;
  }
  .t-boite.attente {
    background: var(--wt-accent-tint);
  }
  .t-boite.deja {
    background: var(--wt-warn-tint);
    flex-direction: column;
    align-items: stretch;
    gap: 10px;
  }
  .t-boite .explication {
    font-size: 15px;
  }
  .t-autre {
    height: 48px;
    border-radius: var(--r-lg);
    border: 1px solid var(--wt-line2);
    background: var(--wt-card);
    color: var(--wt-ink);
    font-size: 15px;
    font-weight: 600;
  }
  .t-erreur {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 14px;
    color: var(--wt-danger);
  }
</style>
