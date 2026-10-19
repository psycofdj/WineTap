<script>
  // Historique des 12 derniers mois (E-07), barres empilées par couleur, par appellation ou par
  // région (sélecteur propre à chaque carte). Les barres poussent à l'ouverture ; survol, focus ou
  // toucher d'un mois affiche son détail dans une bulle. Légende en tableau sous le graphique.
  import { parMois, plafond } from '../lib/stats.js';
  import { accord, prix } from '../lib/format.js';
  import Selecteur from './Selecteur.svelte';
  import TableauLegende from './TableauLegende.svelte';

  /**
   * @type {{ titre: string, bouteilles: any[] | null, champ: 'consommee_le'|'entree_le',
   *   par?: 'couleur'|'appellation'|'region', verbe: string, montant?: boolean, vide: string, hauteur?: number }}
   */
  let { titre, bouteilles, champ, par = $bindable('couleur'), verbe, montant = false, vide, hauteur = 150 } = $props();

  const OPTIONS = [
    { valeur: 'couleur', libelle: 'Couleur' },
    { valeur: 'appellation', libelle: 'Appellation' },
    { valeur: 'region', libelle: 'Région' },
  ];

  const donnees = $derived(bouteilles ? parMois(bouteilles, champ, par) : null);
  let pret = $state(false);
  let actif = $state(/** @type {number|null} */ (null));

  // Les barres poussent dès que les données arrivent (les consommées sont chargées après l'écran).
  $effect(() => {
    if (!donnees || pret) return;
    let id = requestAnimationFrame(() => (id = requestAnimationFrame(() => (pret = true))));
    return () => cancelAnimationFrame(id);
  });

  const haut = $derived(plafond(donnees?.max ?? 0));
  const moyenne = $derived(donnees ? Math.round(donnees.moyenne * 10) / 10 : 0);
  const choisi = $derived(donnees && actif !== null ? donnees.mois[actif] : null);
  const legende = $derived(
    (donnees?.series ?? []).map((s) => ({ ...s, cle: String(s.cle), valeurs: [s.total, s.moyenne, s.max] })),
  );

  function bulle(i) {
    if (i <= 1) return 'gauche';
    if (i >= 10) return 'droite';
    return '';
  }
</script>

<section class="carte">
  <div class="tete">
    <div class="titres">
      <span class="titre">{titre}</span>
      {#if donnees}
        <span class="resume">
          <b class="tnum">{donnees.total}</b>
          {accord(donnees.total, 'bouteille')} sur 12 mois · {moyenne.toLocaleString('fr-FR')} par mois{#if montant && donnees.montant}{' · '}<b
              class="tnum">{prix(donnees.montant)}</b
            >{/if}
        </span>
      {/if}
    </div>
    <Selecteur options={OPTIONS} bind:valeur={par} label="Répartition des {titre.toLowerCase()}" />
  </div>

  {#if !donnees}
    <div class="attente" style:height="{hauteur + 24}px"></div>
  {:else if donnees.total === 0}
    <div class="aucun" style:height="{hauteur + 24}px">{vide}</div>
  {:else}
    <div class="graphe" role="group" aria-label={titre} style:--h="{hauteur}px" onpointerleave={() => (actif = null)}>
      <div class="axe" aria-hidden="true">
        <span style:bottom="100%">{haut.toLocaleString('fr-FR')}</span>
        <span style:bottom="50%">{(haut / 2).toLocaleString('fr-FR')}</span>
        <span style:bottom="0%">0</span>
      </div>
      <div class="zone">
        <div class="grilles" aria-hidden="true"><span></span><span></span><span></span></div>
        {#each donnees.mois as m, i (m.cle)}
          <button
            type="button"
            class="colonne"
            class:active={actif === i}
            class:estompee={actif !== null && actif !== i}
            aria-label="{m.long} : {m.n} {accord(m.n, 'bouteille')} {verbe}"
            onpointerenter={(e) => e.pointerType !== 'touch' && (actif = i)}
            onclick={() => (actif = i)}
            onfocus={() => (actif = i)}
            onblur={() => (actif = null)}
          >
            <span class="pile" style:height={pret ? `calc(var(--h) * ${m.n / haut})` : '0px'} style:transition-delay="{i * 35}ms">
              {#each m.parts as c (c.cle)}
                <span class="morceau" style:flex-grow={c.n} style:background={c.teinte}></span>
              {/each}
            </span>
            {#if m.n}<span class="valeur tnum" class:visible={pret} style:--part={m.n / haut}>{m.n}</span>{/if}
            <span class="mois" class:an={m.janvier || i === 0}
              ><span class="m-nom">{m.court}</span><span class="m-initiale" aria-hidden="true">{m.initiale}</span
              >{#if m.janvier || i === 0}<br />{m.annee}{/if}</span
            >
            {#if choisi && actif === i}
              <span class="bulle {bulle(i)}" role="tooltip">
                <span class="b-titre">{m.long}</span>
                <span class="b-total">{m.n} {accord(m.n, 'bouteille')} {verbe}{#if montant && m.montant}{' · '}{prix(m.montant)}{/if}</span>
                {#each m.parts as c (c.cle)}
                  <span class="b-ligne"><span class="pastille" style:background={c.teinte}></span>{c.libelle}<b class="tnum">{c.n}</b></span>
                {/each}
              </span>
            {/if}
          </button>
        {/each}
      </div>
    </div>
    <TableauLegende variante="histo" entete={donnees.entete} colonnes={['Total', 'Moy./mois', 'Max']} lignes={legende} label="Légende des {titre.toLowerCase()}" />
  {/if}
</section>

<style>
  .carte {
    border: 1px solid var(--wt-line);
    background: var(--wt-card);
    border-radius: 14px;
    padding: 20px;
    display: flex;
    flex-direction: column;
    gap: 14px;
    min-width: 0;
  }
  .tete {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 10px 12px;
    flex-wrap: wrap;
  }
  .titres {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .titre {
    font-family: var(--font-serif);
    font-size: 20px;
    font-weight: 500;
  }
  .resume {
    font-size: 13px;
    color: var(--wt-ink3);
  }
  .resume b {
    color: var(--wt-ink);
    font-weight: 600;
  }
  .attente {
    border-radius: 10px;
    background: var(--wt-card2);
    opacity: 0.6;
  }
  .aucun {
    display: flex;
    align-items: center;
    justify-content: center;
    color: var(--wt-ink3);
    font-size: 14px;
    text-align: center;
  }
  .graphe {
    display: flex;
    gap: 8px;
    padding-top: 18px;
  }
  .axe {
    position: relative;
    width: 22px;
    height: var(--h);
    flex: none;
    font-size: 11px;
    color: var(--wt-ink3);
  }
  .axe span {
    position: absolute;
    right: 0;
    transform: translateY(50%);
    font-variant-numeric: tabular-nums;
  }
  .zone {
    position: relative;
    container-type: inline-size;
    flex: 1;
    min-width: 0;
    display: grid;
    grid-template-columns: repeat(12, minmax(0, 1fr));
    gap: 4px;
  }
  .grilles {
    position: absolute;
    left: 0;
    right: 0;
    top: 0;
    height: var(--h);
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    pointer-events: none;
  }
  .grilles span {
    border-top: 1px dashed var(--wt-line);
  }
  .grilles span:last-child {
    border-top: 1px solid var(--wt-line2);
  }
  /* Une colonne : la hauteur du graphe, plus 30 px pour le nom du mois sous la ligne de base. */
  .colonne {
    position: relative;
    height: calc(var(--h) + 30px);
    border: 0;
    background: transparent;
    padding: 0;
    display: flex;
    flex-direction: column;
    align-items: center;
    color: var(--wt-ink);
    border-radius: 6px;
    cursor: default;
    outline: none;
  }
  .colonne::before {
    /* Zone de survol de toute la hauteur du graphe. */
    content: '';
    position: absolute;
    left: -2px;
    right: -2px;
    top: 0;
    height: var(--h);
    border-radius: 6px;
    transition: background 160ms var(--ease, ease);
  }
  .colonne.active::before,
  .colonne:focus-visible::before {
    background: var(--wt-card2);
  }
  /* La pile se pose sur la ligne de base ; sa hauteur est calculée sur --h dans le balisage. */
  .pile {
    position: absolute;
    bottom: 30px;
    left: 50%;
    transform: translateX(-50%);
    width: min(70%, 34px);
    max-height: var(--h);
    display: flex;
    flex-direction: column-reverse;
    gap: 1px;
    border-radius: 4px 4px 1px 1px;
    overflow: hidden;
    transition: height 700ms cubic-bezier(0.22, 1, 0.36, 1);
  }
  .estompee .pile {
    opacity: 0.45;
  }
  .morceau {
    flex-basis: 0;
    min-height: 2px;
  }
  .valeur {
    position: absolute;
    bottom: calc(30px + 4px + var(--h) * var(--part));
    font-size: 11px;
    color: var(--wt-ink2);
    opacity: 0;
    transition: opacity 300ms 500ms;
    pointer-events: none;
  }
  .valeur.visible {
    opacity: 1;
  }
  .mois {
    position: absolute;
    bottom: 0;
    height: 26px;
    font-size: 11px;
    line-height: 1.15;
    color: var(--wt-ink3);
    white-space: nowrap;
    text-align: center;
  }
  .mois.an {
    color: var(--wt-ink2);
  }
  .m-initiale {
    display: none;
  }
  /* Colonnes étroites (téléphone) : l'initiale du mois seulement. */
  @container (max-width: 480px) {
    .m-nom {
      display: none;
    }
    .m-initiale {
      display: inline;
    }
  }
  .bulle {
    position: absolute;
    bottom: calc(30px + var(--h) * 0.35);
    left: 50%;
    transform: translateX(-50%);
    z-index: 5;
    min-width: 170px;
    padding: 10px 12px;
    border-radius: 10px;
    background: var(--wt-ink);
    color: var(--wt-paper);
    box-shadow: 0 10px 30px rgba(42, 29, 21, 0.25);
    display: flex;
    flex-direction: column;
    gap: 3px;
    text-align: left;
    font-size: 12.5px;
    pointer-events: none;
    animation: apparition 160ms var(--ease, ease);
  }
  .bulle.gauche {
    left: 0;
    transform: none;
  }
  .bulle.droite {
    left: auto;
    right: 0;
    transform: none;
  }
  @keyframes apparition {
    from {
      opacity: 0;
      translate: 0 4px;
    }
  }
  .b-titre {
    font-weight: 600;
    text-transform: capitalize;
  }
  .b-total {
    opacity: 0.8;
    margin-bottom: 2px;
  }
  .b-ligne {
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .b-ligne b {
    margin-left: auto;
    padding-left: 12px;
  }
  .pastille {
    width: 9px;
    height: 9px;
    border-radius: 3px;
    box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.25);
  }
  @media (prefers-reduced-motion: reduce) {
    .pile,
    .valeur {
      transition: none;
    }
    .bulle {
      animation: none;
    }
  }
</style>
