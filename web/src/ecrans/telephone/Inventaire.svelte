<script>
  // E-04 — Inventaire (téléphone) : recherche, filtres en pastilles, liste groupée par cuvée.
  import { ctx } from '../../lib/contexte.svelte.js';
  import { routeur } from '../../lib/routeur.svelte.js';
  import { cave } from '../../lib/stores/cave.svelte.js';
  import { lecture } from '../../lib/stores/lecture.svelte.js';
  import { grouper } from '../../lib/groupes.js';
  import { correspond, filtreUrl } from '../../lib/filtres.js';
  import { millesime, accord } from '../../lib/format.js';
  import { gardeSignalee } from '../../lib/garde.js';
  import Icon from '../../components/Icon.svelte';
  import WineGlass from '../../components/WineGlass.svelte';
  import GardeBadge from '../../components/GardeBadge.svelte';
  import BottleDetail from '../../components/BottleDetail.svelte';

  const PASTILLES = [
    { cle: 'tout', libelle: 'Tout' },
    { cle: '1', libelle: 'Rouge' },
    { cle: '2', libelle: 'Blanc' },
    { cle: '3', libelle: 'Rosé' },
    { cle: '4', libelle: 'Effervescent' },
    { cle: 'garde', libelle: 'À boire' },
  ];

  // Filtre initial venant de l'URL (accueil, tableau de bord).
  let pastille = $state(routeur.query.filtre === 'garde' ? 'garde' : (routeur.query.couleur ?? 'tout'));
  let region = $state(routeur.query.region ?? '');
  let recherche = $state('');
  let ouvert = $state(/** @type {any} */ (null));

  const filtrees = $derived(
    cave.enStock.filter(
      (b) =>
        correspond(b, recherche) &&
        (pastille === 'tout' || (pastille === 'garde' ? gardeSignalee(b.garde) : b.couleur === Number(pastille))) &&
        filtreUrl({ region })(b),
    ),
  );
  const groupes = $derived(grouper(filtrees));
  const vide = $derived(cave.enStock.length === 0);
</script>

<div class="page">
  <div class="outils">
    <label class="recherche">
      <Icon nom="search" taille={20} />
      <input type="search" placeholder="Rechercher un vin" bind:value={recherche} aria-label="Rechercher un vin" />
    </label>
    {#if ctx.dansApplication}
      <button type="button" class="carre" aria-label="Rechercher par tag" onclick={() => lecture.identifier('recherche')}>
        <Icon nom="nfc" taille={22} />
      </button>
    {/if}
    <button type="button" class="carre plein" aria-label="Entrer une bouteille" onclick={() => routeur.aller('/entree')}>
      <Icon nom="plus" taille={22} epaisseur={2} />
    </button>
  </div>

  <div class="pastilles">
    {#if region}
      <button type="button" class="pastille on" onclick={() => (region = '')}>{region}<Icon nom="x" taille={14} epaisseur={2} /></button>
    {/if}
    {#each PASTILLES as p (p.cle)}
      <button type="button" class="pastille" class:on={pastille === p.cle} onclick={() => (pastille = p.cle)}>{p.libelle}</button>
    {/each}
  </div>

  <div class="compteur">{filtrees.length} {accord(filtrees.length, 'bouteille')} · groupées par cuvée</div>

  {#if vide}
    <div class="vide">
      <svg viewBox="0 0 20 20" width="64" height="64" aria-hidden="true" style="color:var(--wt-ink3)">
        <path d="M6 1.5h8c.8 4 .6 6.5-.4 8.2-.8 1.3-2.1 1.8-3.6 1.8s-2.8-.5-3.6-1.8C5.4 8 5.2 5.5 6 1.5zM10 11.5V17M6.5 17.5h7M8.7 4.6a1.3 1.3 0 1 1 1.9 1.2c-.4.2-.6.5-.6.9M10 8.6h.01" style="fill:none;stroke:currentColor;stroke-width:0.9;stroke-linecap:round;stroke-linejoin:round" />
      </svg>
      <span class="v-titre">La cave est vide</span>
      <span class="v-texte">Entrez une première bouteille avec son tag, ou restaurez une sauvegarde.</span>
      <button type="button" class="v-btn primaire" onclick={() => routeur.aller('/entree')}>Entrer une bouteille</button>
      <button type="button" class="v-btn" onclick={() => routeur.aller('/parametres')}>Restaurer une sauvegarde</button>
    </div>
  {:else if groupes.length}
    <div class="liste">
      {#each groupes as g (g.cle)}
        {@const b = g.premiere}
        <button type="button" class="ligne" onclick={() => (ouvert = g)}>
          <WineGlass couleur={b.couleur} taille={22} />
          <span class="textes">
            <span class="nom">{b.cuvee?.nom} <span class="mil">{millesime(b.millesime)}</span></span>
            <span class="sous">{[b.domaine?.nom, b.appellation?.nom].filter(Boolean).join(' · ')}</span>
            <GardeBadge annee={b.a_boire_avant} forme="liste" />
          </span>
          <span class="qte">{g.qte}</span>
        </button>
      {/each}
    </div>
  {:else}
    <p class="aucun">Aucune bouteille ne correspond.</p>
  {/if}
</div>

{#if ouvert}
  <BottleDetail
    bouteille={ouvert.premiere}
    qte={ouvert.qte}
    onfermer={() => (ouvert = null)}
    onmodele={() => {
      const id = ouvert.premiere.id;
      ouvert = null;
      routeur.aller(`/entree?modele=${id}`);
    }}
    onmodifier={() => {
      const id = ouvert.premiere.id;
      ouvert = null;
      routeur.aller(`/entree?modifier=${id}`);
    }}
  />
{/if}

<style>
  .page {
    display: flex;
    flex-direction: column;
    padding: 8px 0 24px;
    gap: 12px;
  }
  .outils {
    display: flex;
    gap: 8px;
    padding: 0 20px;
  }
  .recherche {
    flex: 1;
    min-width: 0;
    height: 48px;
    border-radius: 14px;
    background: var(--wt-card);
    border: 1px solid var(--wt-line);
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 0 14px;
    color: var(--wt-ink3);
  }
  .recherche:focus-within {
    border-color: var(--wt-accent);
    box-shadow: 0 0 0 3px var(--wt-accent-tint);
  }
  .recherche input {
    flex: 1;
    min-width: 0;
    border: 0;
    outline: none;
    background: transparent;
    font-size: 16px;
    color: var(--wt-ink);
  }
  .recherche input::placeholder {
    color: var(--wt-ink3);
  }
  .carre {
    width: 48px;
    height: 48px;
    flex: none;
    border-radius: 14px;
    background: var(--wt-card);
    border: 1px solid var(--wt-line);
    color: var(--wt-accent-ink);
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .carre.plein {
    background: var(--wt-accent);
    border: 0;
    color: var(--wt-on-accent);
  }
  .pastilles {
    display: flex;
    gap: 8px;
    overflow-x: auto;
    padding: 0 20px;
    scrollbar-width: none;
  }
  .pastilles::-webkit-scrollbar {
    display: none;
  }
  .pastille {
    flex: none;
    height: 36px;
    border-radius: 999px;
    border: 1px solid var(--wt-line2);
    background: var(--wt-card);
    color: var(--wt-ink);
    padding: 0 14px;
    font-size: 14px;
    font-weight: 500;
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .pastille.on {
    background: var(--wt-ink);
    color: var(--wt-paper);
  }
  .compteur {
    padding: 0 20px;
    font-size: 13px;
    color: var(--wt-ink3);
  }
  .liste {
    margin: 0 20px;
    background: var(--wt-card);
    border: 1px solid var(--wt-line);
    border-radius: 16px;
    overflow: hidden;
  }
  .ligne {
    width: 100%;
    border: 0;
    border-bottom: 1px solid var(--wt-line);
    background: transparent;
    color: var(--wt-ink);
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 12px 14px;
    min-height: 64px;
    text-align: left;
  }
  .ligne:last-child {
    border-bottom: 0;
  }
  .ligne:active {
    background: var(--wt-card2);
  }
  .textes {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 1px;
  }
  .nom {
    font-size: 16px;
    font-weight: 500;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .mil {
    color: var(--wt-ink3);
    font-weight: 400;
  }
  .sous {
    font-size: 13px;
    color: var(--wt-ink2);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .qte {
    font-family: var(--font-serif);
    font-size: 22px;
    font-weight: 500;
    min-width: 28px;
    text-align: right;
  }
  .vide {
    margin: 24px 20px 0;
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
    gap: 10px;
    padding: 32px 12px;
  }
  .v-titre {
    font-family: var(--font-serif);
    font-size: 28px;
    font-weight: 500;
  }
  .v-texte {
    font-size: 15px;
    color: var(--wt-ink2);
  }
  .v-btn {
    height: 52px;
    width: 100%;
    border-radius: 16px;
    border: 1px solid var(--wt-line2);
    background: var(--wt-card);
    color: var(--wt-ink);
    font-size: 16px;
    font-weight: 600;
  }
  .v-btn.primaire {
    margin-top: 8px;
    height: 56px;
    border: 0;
    background: var(--wt-accent);
    color: var(--wt-on-accent);
    font-size: 17px;
  }
  .aucun {
    padding: 24px 20px;
    text-align: center;
    color: var(--wt-ink3);
    font-size: 15px;
  }
</style>
