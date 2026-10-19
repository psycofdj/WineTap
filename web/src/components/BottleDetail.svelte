<script>
  // Détail d'une bouteille (D-19) : bouteille, cuvée, domaine et appellation avec leurs descriptions.
  // Feuille du bas sur téléphone, fenêtre sur ordinateur.
  import { ctx } from '../lib/contexte.svelte.js';
  import { vin } from '../lib/vins.js';
  import { catalogue } from '../lib/stores/catalogue.svelte.js';
  import { dateCourte, dateLongue, millesimeLong, pluriel, prix } from '../lib/format.js';
  import WineGlass from './WineGlass.svelte';
  import GardeBadge from './GardeBadge.svelte';
  import StatusPill from './StatusPill.svelte';
  import Sheet from './Sheet.svelte';
  import Modal from './Modal.svelte';
  import Button from './Button.svelte';
  import Icon from './Icon.svelte';
  import Blason from './Blason.svelte';
  import VignetteCarte from './VignetteCarte.svelte';

  /**
   * @type {{ bouteille: any, qte?: number, onfermer: () => void, onmodele: () => void,
   *   onmodifier: () => void, onconsommer?: () => void }}
   */
  let { bouteille: b, qte = 1, onfermer, onmodele, onmodifier, onconsommer } = $props();

  const v = $derived(vin(b.couleur));
  const carte = $derived(catalogue.urlImage(b.appellation));
  const consommee = $derived(!!b.consommee_le);
</script>

{#snippet region()}
  {#if b.region}<span class="region">· <Blason region={b.region} />{b.region}</span>{/if}
{/snippet}

{#snippet pastilles(t)}
  <span class="pastilles">
    {#if consommee}
      <StatusPill ton="neutre" taille={t} padding={t > 13 ? '4px 10px' : '3px 10px'}>Consommée le {dateLongue(b.consommee_le)}</StatusPill>
    {:else}
      <StatusPill ton="ok" taille={t} padding={t > 13 ? '4px 10px' : '3px 10px'}>En stock · {pluriel(qte, 'bouteille')}</StatusPill>
      <GardeBadge annee={b.a_boire_avant} forme="pastille" taille={t} />
    {/if}
  </span>
{/snippet}

{#snippet description(texte)}
  {#if texte}<span class="desc">{texte}</span>{:else}<span class="desc vide">Pas de description.</span>{/if}
{/snippet}

{#if ctx.ordinateur}
  <Modal {onfermer} label="Détail de la bouteille">
    <div class="o-tete">
      <div class="o-titres">
        <span class="surligne"><WineGlass couleur={b.couleur} taille={20} />{v.libelle} · {millesimeLong(b.millesime)}</span>
        <span class="o-cuvee">{b.cuvee?.nom}</span>
        <span class="o-sous"
          >{[b.domaine?.nom, b.appellation?.nom].filter(Boolean).join(' · ')}{#if b.region}{' '}<span class="o-region"
              >(<Blason region={b.region} largeur={13} hauteur={16} />{b.region})</span
            >{/if}</span
        >
        {@render pastilles(12.5)}
      </div>
      <button type="button" class="fermer o" aria-label="Fermer" onclick={onfermer}><Icon nom="x" taille={20} /></button>
    </div>
    <div class="o-corps">
      <div class="grille">
        <div><span class="lib">Millésime</span><span>{millesimeLong(b.millesime)}</span></div>
        <div><span class="lib">À boire avant</span><span>{b.a_boire_avant || '—'}</span></div>
        <div><span class="lib">Prix d'achat</span><span>{prix(b.prix)}</span></div>
        <div><span class="lib">Entrée en cave</span><span>{dateCourte(b.entree_le)}</span></div>
        <div><span class="lib">Tag</span><span class="mono">{b.tag_id || '—'}</span></div>
        <div><span class="lib">Quantité</span><span>{pluriel(qte, 'bouteille')}</span></div>
      </div>
      {#if b.commentaire}
        <div class="section"><span class="surtitre">Commentaire</span><span class="commentaire">« {b.commentaire} »</span></div>
      {/if}
      <div class="section"><span class="surtitre">Cuvée</span><span class="nom">{b.cuvee?.nom}</span>{@render description(b.cuvee?.description)}</div>
      <div class="section"><span class="surtitre">Domaine</span><span class="nom">{b.domaine?.nom}</span>{@render description(b.domaine?.description)}</div>
      {#if b.appellation}
        <div class="section ligne">
          {#if carte}<VignetteCarte appellation={b.appellation} />{/if}
          <div class="pile">
            <span class="surtitre">Appellation</span>
            <span class="nom">{b.appellation.nom} {@render region()}</span>
            {@render description(b.appellation.description)}
          </div>
        </div>
      {/if}
    </div>
    <div class="o-pied">
      <Button taille="ord-l" onclick={onmodele}>Ajouter sur ce modèle</Button>
      {#if onconsommer && !consommee}<Button taille="ord-l" onclick={onconsommer}>Consommer</Button>{/if}
      <Button taille="ord-l" variante="primary" onclick={onmodifier}>Modifier</Button>
    </div>
  </Modal>
{:else}
  <Sheet {onfermer} label="Détail de la bouteille">
    <div class="t-corps">
      <div class="t-tete">
        <div class="t-ligne1">
          <span class="surligne t"><WineGlass couleur={b.couleur} taille={20} />{v.libelle} · {millesimeLong(b.millesime)}</span>
          <button type="button" class="fermer t" aria-label="Fermer" onclick={onfermer}><Icon nom="x" taille={22} /></button>
        </div>
        <span class="t-cuvee">{b.cuvee?.nom}</span>
        <span class="t-sous">{b.domaine?.nom}</span>
        {@render pastilles(13)}
      </div>
      <div class="encadre">
        <div><span class="lib">À boire avant</span><span>{b.a_boire_avant || '—'}</span></div>
        <div><span class="lib">Prix</span><span>{prix(b.prix)}</span></div>
        <div><span class="lib">Entrée</span><span>{dateCourte(b.entree_le)}</span></div>
      </div>
      {#if b.commentaire}
        <div class="t-section premiere"><span class="surtitre">Commentaire</span><span class="commentaire t">« {b.commentaire} »</span></div>
      {/if}
      <div class="t-section" class:premiere={!b.commentaire}><span class="surtitre">Cuvée</span><span class="nom">{b.cuvee?.nom}</span>{@render description(b.cuvee?.description)}</div>
      <div class="t-section bord"><span class="surtitre">Domaine</span><span class="nom">{b.domaine?.nom}</span>{@render description(b.domaine?.description)}</div>
      {#if b.appellation}
        <div class="t-section bord large">
          <span class="surtitre">Appellation</span>
          {#if carte}<VignetteCarte appellation={b.appellation} />{/if}
          <span class="nom">{b.appellation.nom} {@render region()}</span>
          {@render description(b.appellation.description)}
        </div>
      {/if}
    </div>
    {#snippet pied()}
      <div class="t-pied">
        <Button taille="tel-s" onclick={onmodele} style="height:52px;border-radius:14px">Sur ce modèle</Button>
        <Button taille="tel-s" variante="primary" onclick={onmodifier} style="height:52px;border-radius:14px">Modifier</Button>
      </div>
    {/snippet}
  </Sheet>
{/if}


<style>
  .surligne {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 13px;
    color: var(--wt-ink2);
  }
  .surligne :global(svg) {
    color: var(--wt-ink);
  }
  .surligne.t {
    font-size: 14px;
  }
  .pastilles {
    display: flex;
    gap: 6px;
    flex-wrap: wrap;
    margin-top: 4px;
  }
  .fermer {
    border: 0;
    background: transparent;
    color: var(--wt-ink2);
    display: flex;
    align-items: center;
    justify-content: center;
    flex: none;
  }
  .fermer.o {
    width: 34px;
    height: 34px;
    border-radius: 8px;
  }
  .fermer.t {
    width: 44px;
    height: 44px;
    margin: -10px -12px -10px 0;
  }
  .surtitre {
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.1em;
    text-transform: uppercase;
    color: var(--wt-ink3);
  }
  .nom {
    font-family: var(--font-serif);
    font-size: 20px;
    font-weight: 500;
  }
  .region {
    font-family: var(--font-sans);
    font-size: 14px;
    color: var(--wt-ink3);
    font-weight: 400;
    display: inline-flex;
    align-items: center;
    gap: 5px;
    vertical-align: 1px;
  }
  .o-region {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    vertical-align: -2px;
  }
  .desc {
    font-size: 14px;
    line-height: 1.55;
    color: var(--wt-ink2);
  }
  .desc.vide {
    color: var(--wt-ink3);
  }
  .commentaire {
    font-family: var(--font-serif);
    font-style: italic;
    font-size: 17px;
    color: var(--wt-ink2);
  }
  .commentaire.t {
    font-size: 18px;
  }
  .lib {
    font-size: 12px;
    color: var(--wt-ink3);
  }

  /* Ordinateur */
  .o-tete {
    padding: 22px 24px 18px;
    border-bottom: 1px solid var(--wt-line);
    display: flex;
    gap: 16px;
    align-items: flex-start;
  }
  .o-titres {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  .o-cuvee {
    font-family: var(--font-serif);
    font-size: 34px;
    font-weight: 500;
    line-height: 1.05;
  }
  .o-sous {
    font-size: 15px;
    color: var(--wt-ink2);
  }
  .o-corps {
    flex: 1;
    overflow: auto;
    padding: 18px 24px;
    display: flex;
    flex-direction: column;
    gap: 18px;
    scrollbar-width: thin;
  }
  .grille {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 12px 20px;
    font-size: 14px;
  }
  .grille > div,
  .encadre > div {
    display: flex;
    flex-direction: column;
  }
  .section {
    display: flex;
    flex-direction: column;
    gap: 4px;
    padding-top: 16px;
    border-top: 1px solid var(--wt-line);
  }
  .section.ligne {
    flex-direction: row;
    gap: 16px;
  }
  .pile {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  .o-pied {
    padding: 14px 24px;
    border-top: 1px solid var(--wt-line);
    display: flex;
    gap: 8px;
    justify-content: flex-end;
  }

  /* Téléphone */
  .t-corps {
    padding: 8px 22px 16px;
    display: flex;
    flex-direction: column;
    gap: 16px;
  }
  .t-tete {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  .t-ligne1 {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  .t-cuvee {
    font-family: var(--font-serif);
    font-size: 32px;
    font-weight: 500;
    line-height: 1.05;
  }
  .t-sous {
    font-size: 15px;
    color: var(--wt-ink2);
  }
  .encadre {
    display: grid;
    grid-template-columns: 1fr 1fr 1fr;
    gap: 10px;
    font-size: 15px;
    background: var(--wt-paper);
    border-radius: 14px;
    padding: 12px 14px;
  }
  .t-section {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  .t-section .desc {
    font-size: 15px;
    line-height: 1.5;
  }
  .t-section.bord {
    padding-top: 14px;
    border-top: 1px solid var(--wt-line);
  }
  .t-section.large {
    gap: 8px;
  }
  .t-pied {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 10px;
  }
</style>
