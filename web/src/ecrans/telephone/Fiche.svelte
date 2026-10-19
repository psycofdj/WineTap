<script>
  // E-03 — Fiche d'une bouteille (identification, recherche par tag) : informations, puis cuvée,
  // domaine et appellation avec leurs descriptions et la carte.
  import { routeur } from '../../lib/routeur.svelte.js';
  import { cave } from '../../lib/stores/cave.svelte.js';
  import { toast } from '../../lib/toast.svelte.js';
  import { resteEnCave } from '../../lib/groupes.js';
  import { vin } from '../../lib/vins.js';
  import { dateCourte, millesimeLong, pluriel, prix } from '../../lib/format.js';
  import EnTete from '../../components/EnTete.svelte';
  import WineGlass from '../../components/WineGlass.svelte';
  import StatusPill from '../../components/StatusPill.svelte';
  import GardeBadge from '../../components/GardeBadge.svelte';
  import Button from '../../components/Button.svelte';
  import Blason from '../../components/Blason.svelte';
  import VignetteCarte from '../../components/VignetteCarte.svelte';

  /** @type {{ id: number }} */
  let { id } = $props();

  const b = $derived(cave.parId(id));
  const qte = $derived(b ? resteEnCave(cave.enStock, b) : 0);

  async function consommerSansTag() {
    try {
      const c = await cave.consommer(id);
      toast.afficher(`${c.cuvee?.nom} consommée`);
      routeur.retour('/inventaire');
    } catch (e) {
      toast.afficher(e.message);
    }
  }
</script>

{#snippet description(texte)}
  {#if texte}<span class="desc">{texte}</span>{:else}<span class="desc vide">Pas de description.</span>{/if}
{/snippet}

<div class="page">
  <EnTete retour="/inventaire" action={b && !b.consommee_le ? 'Modifier' : ''} onaction={() => routeur.aller(`/entree?modifier=${id}`)} />
  {#if b}
    <div class="tete">
      <span class="surligne"><WineGlass couleur={b.couleur} taille={20} style="color:var(--wt-ink)" />{vin(b.couleur).libelle} · {millesimeLong(b.millesime)}</span>
      <span class="cuvee">{b.cuvee?.nom}</span>
      <span class="domaine">{b.domaine?.nom}</span>
      <div class="pastilles">
        {#if b.consommee_le}
          <StatusPill ton="neutre">Consommée</StatusPill>
        {:else}
          <StatusPill ton="ok" icone="check" tailleIcone={14} epaisseurIcone={2.4} padding="5px 11px">En stock · {pluriel(qte, 'bouteille')}</StatusPill>
          <GardeBadge annee={b.a_boire_avant} forme="fiche" />
        {/if}
      </div>
    </div>

    <div class="carte">
      <div><span>Appellation</span><span class="droite">{b.appellation?.nom ?? '—'}</span></div>
      <div><span>Région</span><span class="region"><Blason region={b.region} largeur={15} hauteur={18} />{b.region || '—'}</span></div>
      <div><span>À boire avant</span><span>{b.a_boire_avant || '—'}</span></div>
      <div><span>Prix d'achat</span><span>{prix(b.prix)}</span></div>
      <div><span>Entrée en cave</span><span>{dateCourte(b.entree_le)}</span></div>
      <div><span>Tag</span><span class="mono">{b.tag_id || '—'}</span></div>
    </div>

    <div class="blocs">
      <div class="bloc">
        <span class="surtitre">Cuvée</span>
        <span class="nom">{b.cuvee?.nom}</span>
        {@render description(b.cuvee?.description)}
      </div>
      <div class="bloc">
        <span class="surtitre">Domaine</span>
        <span class="nom">{b.domaine?.nom}</span>
        {@render description(b.domaine?.description)}
      </div>
      {#if b.appellation}
        <div class="bloc large">
          <span class="surtitre">Appellation</span>
          <VignetteCarte appellation={b.appellation} />
          <span class="nom"
            >{b.appellation.nom}
            {#if b.region}<span class="b-region">· <Blason region={b.region} />{b.region}</span>{/if}</span
          >
          {@render description(b.appellation.description)}
        </div>
      {/if}
    </div>

    {#if !b.consommee_le}
      <div class="boutons">
        <Button taille="tel-l" style="font-size:16px" onclick={consommerSansTag}>Consommer sans tag</Button>
        <Button taille="tel-l" style="font-size:16px" icone="copy" onclick={() => routeur.aller(`/entree?modele=${id}`)}>Ajouter sur ce modèle</Button>
      </div>
    {/if}
  {:else}
    <p class="absente">Cette bouteille n'existe plus.</p>
  {/if}
</div>

<style>
  .page {
    display: flex;
    flex-direction: column;
    padding: 0 20px 28px;
    gap: 18px;
  }
  .tete {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .surligne {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 14px;
    color: var(--wt-ink2);
  }
  .cuvee {
    font-family: var(--font-serif);
    font-size: 38px;
    font-weight: 500;
    line-height: 1.05;
  }
  .domaine {
    font-size: 16px;
    color: var(--wt-ink2);
  }
  .pastilles {
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
    margin-top: 4px;
  }
  .carte {
    background: var(--wt-card);
    border: 1px solid var(--wt-line);
    border-radius: 16px;
    display: flex;
    flex-direction: column;
    font-size: 15px;
  }
  .carte > div {
    display: flex;
    justify-content: space-between;
    gap: 12px;
    padding: 13px 16px;
    border-bottom: 1px solid var(--wt-line);
  }
  .carte > div:last-child {
    border-bottom: 0;
  }
  .carte > div > span:first-child {
    color: var(--wt-ink2);
    flex: none;
  }
  .droite {
    text-align: right;
  }
  .region {
    display: flex;
    align-items: center;
    gap: 7px;
  }
  .blocs {
    display: flex;
    flex-direction: column;
    gap: 16px;
  }
  .bloc {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  .bloc + .bloc {
    padding-top: 14px;
    border-top: 1px solid var(--wt-line);
  }
  .bloc.large {
    gap: 8px;
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
  .b-region {
    font-family: var(--font-sans);
    font-size: 14px;
    font-weight: 400;
    color: var(--wt-ink3);
    display: inline-flex;
    align-items: center;
    gap: 5px;
    vertical-align: 1px;
  }
  .desc {
    font-size: 15px;
    line-height: 1.5;
    color: var(--wt-ink2);
  }
  .desc.vide {
    color: var(--wt-ink3);
  }
  .boutons {
    display: flex;
    flex-direction: column;
    gap: 10px;
  }
  .absente {
    color: var(--wt-ink3);
    padding: 24px 0;
  }
</style>
