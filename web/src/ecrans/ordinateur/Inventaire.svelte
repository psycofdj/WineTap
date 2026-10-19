<script>
  // E-04 — Inventaire (ordinateur) : table, tri, filtres par colonne, regroupement, clavier (D-21),
  // détail en fenêtre (D-19), formulaire en panneau (D-18).
  import { tick } from 'svelte';
  import { ctx } from '../../lib/contexte.svelte.js';
  import { routeur } from '../../lib/routeur.svelte.js';
  import { cave } from '../../lib/stores/cave.svelte.js';
  import { catalogue } from '../../lib/stores/catalogue.svelte.js';
  import { lireTag } from '../../lib/nfc.js';
  import { scanDistant } from '../../lib/stores/scan.svelte.js';
  import { toast } from '../../lib/toast.svelte.js';
  import { grouper } from '../../lib/groupes.js';
  import { correspond } from '../../lib/filtres.js';
  import { gardeSignalee } from '../../lib/garde.js';
  import { vin, ORDRE_COULEURS } from '../../lib/vins.js';
  import { comparer, dateCourte, millesime, pluriel, accord, simplifier } from '../../lib/format.js';
  import Button from '../../components/Button.svelte';
  import Checkbox from '../../components/Checkbox.svelte';
  import Icon from '../../components/Icon.svelte';
  import Kbd from '../../components/Kbd.svelte';
  import WineGlass from '../../components/WineGlass.svelte';
  import GardeBadge from '../../components/GardeBadge.svelte';
  import BottleDetail from '../../components/BottleDetail.svelte';
  import Confirmation from '../../components/Confirmation.svelte';
  import PanneauBouteille from './PanneauBouteille.svelte';

  // --- État ---------------------------------------------------------------------
  const q = routeur.query;
  let recherche = $state('');
  let groupe = $state(true);
  let consommees = $state(false);
  let tri = $state({ col: 'cuvee', sens: 1 });
  let filtres = $state({
    couleur: q.couleur ?? '',
    cuvee: '',
    domaine: '',
    appellation: '',
    region: q.region ?? '',
    millesime: '',
    garde: q.filtre === 'garde' ? 'a_boire' : (q.garde ?? ''),
  });
  let sel = $state(-1);
  let detail = $state(/** @type {any} */ (null));
  let panneau = $state(/** @type {any} */ (null));
  let numeroPanneau = $state(0);
  let aSupprimer = $state(/** @type {any} */ (null));
  let scanEnCours = $state(false);
  let champRecherche = /** @type {HTMLInputElement} */ ($state());
  let zoneTable = /** @type {HTMLElement} */ ($state());

  $effect(() => {
    if (consommees && !cave.consommeesBrutes) cave.chargerConsommees().catch((e) => toast.afficher(e.message));
  });

  // --- Lignes -------------------------------------------------------------------
  function passeFiltres(b) {
    const f = filtres;
    if (!correspond(b, recherche)) return false;
    if (f.couleur !== '' && b.couleur !== Number(f.couleur)) return false;
    if (f.cuvee && !simplifier(b.cuvee?.nom).includes(simplifier(f.cuvee))) return false;
    if (f.domaine && !simplifier(b.domaine?.nom).includes(simplifier(f.domaine))) return false;
    if (f.appellation && !simplifier(b.appellation?.nom ?? 'Sans appellation').includes(simplifier(f.appellation))) return false;
    if (f.region && (b.region || 'Sans région') !== f.region) return false;
    if (f.millesime && !millesime(b.millesime).includes(f.millesime.trim().toUpperCase())) return false;
    if (f.garde === 'a_boire' && !gardeSignalee(b.garde)) return false;
    if (f.garde && f.garde !== 'a_boire' && b.garde !== f.garde) return false;
    return true;
  }

  const CLES = {
    couleur: (r) => vin(r.b.couleur).libelle,
    cuvee: (r) => r.b.cuvee?.nom ?? '',
    domaine: (r) => r.b.domaine?.nom ?? '',
    appellation: (r) => r.b.appellation?.nom ?? '',
    region: (r) => r.b.region,
    millesime: (r) => r.b.millesime,
    garde: (r) => r.b.a_boire_avant ?? 99999,
    qte: (r) => r.qte,
    entree: (r) => r.entree,
    consommee: (r) => r.b.consommee_le ?? '',
  };

  function comparerLignes(a, b) {
    const k = CLES[tri.col];
    const va = k(a);
    const vb = k(b);
    const c = typeof va === 'number' && typeof vb === 'number' ? va - vb : comparer(String(va), String(vb));
    return c * tri.sens || comparer(a.b.cuvee?.nom ?? '', b.b.cuvee?.nom ?? '') || a.b.millesime - b.b.millesime;
  }

  const enStockFiltrees = $derived(cave.enStock.filter(passeFiltres));
  const lignesStock = $derived(
    (groupe
      ? grouper(enStockFiltrees).map((g) => ({ cle: g.cle, b: g.premiere, qte: g.qte, entree: g.derniereEntree, bouteilles: g.bouteilles }))
      : enStockFiltrees.map((b) => ({ cle: String(b.id), b, qte: 1, entree: b.entree_le, bouteilles: [b] }))
    ).sort(comparerLignes),
  );
  const lignesConsommees = $derived(
    consommees
      ? cave.consommees
          .filter(passeFiltres)
          .sort((a, b) => (b.consommee_le ?? '').localeCompare(a.consommee_le ?? ''))
          .map((b) => ({ cle: 'c' + b.id, b, qte: 1, entree: b.entree_le, bouteilles: [b], consommee: true }))
      : [],
  );
  const lignes = $derived([...lignesStock, ...lignesConsommees]);
  const ligneSel = $derived(lignes[sel] ?? null);
  const vide = $derived(cave.enStock.length === 0);
  const regions = $derived([...new Set(cave.enStock.map((b) => b.region || 'Sans région'))].sort(comparer));

  // Garde la sélection dans les bornes.
  $effect(() => {
    if (sel >= lignes.length) sel = lignes.length - 1;
  });

  // --- Actions ------------------------------------------------------------------
  function trier(col) {
    tri = tri.col === col ? { col, sens: -tri.sens } : { col, sens: 1 };
  }

  async function selectionner(i) {
    sel = i;
    await tick();
    zoneTable?.querySelector(`[data-ligne="${i}"]`)?.scrollIntoView({ block: 'nearest' });
  }

  function ouvrirPanneau(mode) {
    detail = null;
    numeroPanneau++;
    panneau = mode;
  }

  /** Bouteille sur laquelle agir dans une ligne (groupe : la plus ancienne entrée). */
  function cible(l) {
    return [...l.bouteilles].sort((a, b) => a.entree_le.localeCompare(b.entree_le))[0];
  }

  async function consommer(l = ligneSel) {
    if (!l || l.consommee) return;
    try {
      const b = await cave.consommer(cible(l).id);
      detail = null;
      toast.afficher(`${b.cuvee?.nom} ${millesime(b.millesime)} consommée`);
    } catch (e) {
      toast.afficher(e.message);
    }
  }

  async function supprimer() {
    const l = aSupprimer;
    aSupprimer = null;
    try {
      await cave.supprimer(cible(l).id);
      toast.afficher('Bouteille supprimée');
    } catch (e) {
      toast.afficher(e.message);
    }
  }

  async function scanner() {
    if (scanEnCours) {
      scanDistant.annuler();
      return;
    }
    scanEnCours = true;
    toast.afficher('Lecture demandée au téléphone');
    const r = await lireTag('recherche');
    scanEnCours = false;
    if (r.annule) return toast.afficher('Lecture annulée');
    if (r.erreur) return toast.afficher('Téléphone injoignable, réessayez');
    let i = lignes.findIndex((l) => l.bouteilles.some((b) => b.tag_id === r.tag_id));
    if (i < 0 && cave.parTag(r.tag_id)) {
      // Masquée par un filtre : on les retire.
      recherche = '';
      filtres = { couleur: '', cuvee: '', domaine: '', appellation: '', region: '', millesime: '', garde: '' };
      await tick();
      i = lignes.findIndex((l) => l.bouteilles.some((b) => b.tag_id === r.tag_id));
    }
    if (i < 0) return toast.afficher(`Aucune bouteille en stock avec le tag ${r.tag_id}`);
    await selectionner(i);
    detail = lignes[i];
  }

  function clavier(e) {
    if (detail || aSupprimer || e.defaultPrevented) return;
    const k = e.key;
    // Échap ferme le panneau, même depuis un champ.
    if (k === 'Escape') {
      if (panneau) panneau = null;
      return;
    }
    const t = /** @type {HTMLElement} */ (e.target);
    if (t.closest('input, textarea, select, [contenteditable]')) return;
    if (e.metaKey || e.ctrlKey || e.altKey) return;
    if (panneau && k !== '/' ) return;
    if (k === 'ArrowDown' || k === 'j') {
      e.preventDefault();
      selectionner(Math.min(lignes.length - 1, sel + 1));
    } else if (k === 'ArrowUp' || k === 'k') {
      e.preventDefault();
      selectionner(Math.max(0, sel - 1));
    } else if (k === 'Enter') {
      if (ligneSel) detail = ligneSel;
    } else if (k === '/') {
      e.preventDefault();
      champRecherche.focus();
    } else if (k === 'n') {
      e.preventDefault();
      ouvrirPanneau({ type: 'nouvelle' });
    } else if (k === 'm' && ligneSel) {
      e.preventDefault();
      ouvrirPanneau({ type: 'nouvelle', modele: ligneSel.b });
    } else if (k === 'e' && ligneSel) {
      e.preventDefault();
      ouvrirPanneau({ type: 'modifier', bouteille: cible(ligneSel) });
    } else if (k === 't') {
      e.preventDefault();
      scanner();
    } else if (k === 'p') {
      e.preventDefault();
      window.print();
    }
  }

  const colonnes = [
    ['couleur', 'Couleur'],
    ['cuvee', 'Cuvée'],
    ['domaine', 'Domaine'],
    ['appellation', 'Appellation'],
    ['region', 'Région'],
    ['millesime', 'Millés.'],
    ['garde', 'À boire avant'],
    ['qte', 'Qté'],
    ['entree', 'Entrée'],
    ['consommee', 'Consommée'],
  ];
</script>

<svelte:window onkeydown={clavier} />

<div class="ecran">
  <div class="principal">
    <div class="haut">
      <div class="titre-ligne">
        <div class="titre">
          <h1>Inventaire</h1>
          <span class="resume">
            {#if vide}0 bouteille{:else}{pluriel(cave.enStock.length, 'bouteille')} · {pluriel(lignesStock.length, 'ligne')}{/if}
          </span>
        </div>
        <div class="actions no-print">
          <Button taille="ord-s" icone="nfc" kbd="T" onclick={scanner}>{scanEnCours ? 'En attente du tag…' : 'Scanner'}</Button>
          <Button taille="ord-s" icone="printer" kbd="P" onclick={() => window.print()}>Imprimer</Button>
          <Button taille="ord-s" variante="primary" icone="plus" kbd="N" style="padding:0 14px" onclick={() => ouvrirPanneau({ type: 'nouvelle' })}>Ajouter</Button>
        </div>
      </div>
      <div class="outils no-print">
        <label class="recherche">
          <Icon nom="search" taille={16} />
          <input bind:this={champRecherche} type="search" placeholder="Rechercher" bind:value={recherche} aria-label="Rechercher" />
          <Kbd touche="/" discret />
        </label>
        <Checkbox bind:coche={groupe} libelle="Regrouper les bouteilles identiques" />
        <Checkbox bind:coche={consommees} libelle="Afficher les bouteilles consommées" />
        <div class="espace"></div>
        <span class="sel-lib">Sélection&nbsp;:</span>
        <Button taille="ord-xs" icone="copy" tailleIcone={14} kbd="M" disabled={!ligneSel} onclick={() => ouvrirPanneau({ type: 'nouvelle', modele: ligneSel.b })}
          >Sur ce modèle</Button
        >
        <Button taille="ord-xs" kbd="E" disabled={!ligneSel} onclick={() => ouvrirPanneau({ type: 'modifier', bouteille: cible(ligneSel) })}>Modifier</Button>
        <Button taille="ord-xs" disabled={!ligneSel || ligneSel.consommee} onclick={() => consommer()}>Consommer</Button>
        <button type="button" class="corbeille" aria-label="Supprimer" disabled={!ligneSel} onclick={() => (aSupprimer = ligneSel)}>
          <Icon nom="trash" taille={15} />
        </button>
      </div>
    </div>

    <div class="table-zone" bind:this={zoneTable}>
      <div class="table" role="grid" aria-label="Bouteilles" aria-rowcount={lignes.length}>
        <div class="ligne entete" role="row">
          <span></span>
          {#each colonnes as [col, lib] (col)}
            <button
              type="button"
              role="columnheader"
              class="th"
              class:actif={tri.col === col}
              class:droite={col === 'qte'}
              class:decale={col === 'entree'}
              aria-sort={tri.col === col ? (tri.sens > 0 ? 'ascending' : 'descending') : 'none'}
              onclick={() => trier(col)}
              >{lib}{#if tri.col === col}<Icon nom={tri.sens > 0 ? 'chevD' : 'chevU'} taille={12} epaisseur={2.2} />{/if}</button
            >
          {/each}
        </div>
        <div class="ligne filtres no-print">
          <span class="f-icone"><Icon nom="filter" taille={13} /></span>
          <span class="f"
            ><select class="filtre" bind:value={filtres.couleur} aria-label="Filtrer par couleur">
              <option value="">Toutes</option>
              {#each ORDRE_COULEURS as c (c)}<option value={String(c)}>{vin(c).libelle}</option>{/each}
            </select></span
          >
          <span class="f"><input class="filtre" placeholder="Filtrer" bind:value={filtres.cuvee} aria-label="Filtrer par cuvée" /></span>
          <span class="f"><input class="filtre" placeholder="Filtrer" bind:value={filtres.domaine} aria-label="Filtrer par domaine" /></span>
          <span class="f"><input class="filtre" placeholder="Filtrer" bind:value={filtres.appellation} aria-label="Filtrer par appellation" /></span>
          <span class="f"
            ><select class="filtre" bind:value={filtres.region} aria-label="Filtrer par région">
              <option value="">Toutes</option>
              {#each regions as r (r)}<option value={r}>{r}</option>{/each}
            </select></span
          >
          <span class="f"><input class="filtre" placeholder="—" bind:value={filtres.millesime} aria-label="Filtrer par millésime" /></span>
          <span class="f"
            ><select class="filtre" bind:value={filtres.garde} aria-label="Filtrer par date de garde">
              <option value="">Toutes dates</option>
              <option value="a_boire">À boire</option>
              <option value="depassee">Dépassée</option>
              <option value="annee">Cette année ({ctx.annee})</option>
              <option value="ok">Plus tard</option>
              <option value="aucune">Sans date</option>
            </select></span
          >
          <span></span><span></span><span></span>
        </div>

        {#if vide && !lignesConsommees.length}
          <div class="vide">
            <svg viewBox="0 0 20 20" width="56" height="56" aria-hidden="true" style="color:var(--wt-ink3)">
              <path d={vin(0).verre} style="fill:none;stroke:currentColor;stroke-width:0.9;stroke-linecap:round;stroke-linejoin:round" />
            </svg>
            <span class="v-titre">La cave est vide</span>
            <span class="v-texte">Ajoutez une première bouteille, ou restaurez une sauvegarde depuis les paramètres.</span>
            <div class="v-boutons">
              <Button taille="ord-m" variante="primary" style="padding:0 16px" onclick={() => ouvrirPanneau({ type: 'nouvelle' })}>Ajouter une bouteille</Button>
              <Button taille="ord-m" style="font-weight:400" onclick={() => routeur.aller('/parametres')}>Restaurer une sauvegarde</Button>
            </div>
          </div>
        {:else if !lignes.length}
          <div class="aucune">Aucune bouteille ne correspond aux filtres.</div>
        {/if}

        {#each lignes as l, i (l.cle)}
          {@const b = l.b}
          <div
            class="ligne corps"
            class:selection={i === sel}
            class:conso={l.consommee}
            role="row"
            tabindex="-1"
            aria-selected={i === sel}
            data-ligne={i}
            onclick={() => {
              sel = i;
              detail = l;
            }}
            onkeydown={() => {}}
          >
            <span class="repere">{#if i === sel}<span class="barre-sel"></span>{/if}</span>
            <span class="couleur"><WineGlass couleur={b.couleur} taille={18} opacite={l.consommee ? 0.6 : 1} style={l.consommee ? '' : 'color:var(--wt-ink)'} />{vin(b.couleur).libelle}</span>
            <span class="cuvee coupe">{b.cuvee?.nom}</span>
            <span class="coupe">{b.domaine?.nom}</span>
            <span class="coupe gris">{b.appellation?.nom ?? '—'}</span>
            <span class="gris coupe">{b.region || '—'}</span>
            <span class="tnum">{millesime(b.millesime)}</span>
            <span class="garde">
              {#if l.consommee}<span class="g-conso">{b.a_boire_avant || '—'}</span>{:else}<GardeBadge annee={b.a_boire_avant} />{/if}
            </span>
            <span class="tnum droite qte">{l.qte}</span>
            <span class="tnum gris decale">{dateCourte(l.entree)}</span>
            <span class="tnum" class:date-conso={l.consommee} class:tiret={!l.consommee}>{l.consommee ? dateCourte(b.consommee_le) : '—'}</span>
          </div>
        {/each}
      </div>
    </div>
    <div class="aide no-print"><span>↑ ↓ naviguer</span><span>Entrée ouvrir</span><span>Échap fermer</span><span>/ rechercher</span></div>
  </div>

  {#if panneau}
    {#key numeroPanneau}
      <PanneauBouteille mode={panneau} onfermer={() => (panneau = null)} />
    {/key}
  {/if}
</div>

{#if detail}
  <BottleDetail
    bouteille={detail.b}
    qte={detail.qte}
    onfermer={() => (detail = null)}
    onmodele={() => ouvrirPanneau({ type: 'nouvelle', modele: detail.b })}
    onmodifier={() => ouvrirPanneau({ type: 'modifier', bouteille: cible(detail) })}
    onconsommer={() => consommer(detail)}
  />
{/if}

{#if aSupprimer}
  <Confirmation
    titre="Supprimer cette bouteille ?"
    texte="{aSupprimer.b.domaine?.nom} · {aSupprimer.b.cuvee?.nom} {millesime(aSupprimer.b.millesime)}. La suppression est définitive : réservée aux erreurs de saisie et aux tags perdus.{aSupprimer.qte > 1 ? ` Une seule des ${aSupprimer.qte} bouteilles du groupe est supprimée.` : ''}"
    action="Supprimer"
    onconfirmer={supprimer}
    onfermer={() => (aSupprimer = null)}
  />
{/if}

<style>
  .ecran {
    flex: 1;
    min-height: 0;
    display: flex;
  }
  .principal {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }
  .haut {
    padding: 20px 24px 12px;
    display: flex;
    flex-direction: column;
    gap: 14px;
    flex: none;
  }
  .titre-ligne {
    display: flex;
    align-items: flex-end;
    justify-content: space-between;
    gap: 12px 16px;
    flex-wrap: wrap;
  }
  .titre {
    display: flex;
    align-items: baseline;
    gap: 12px;
  }
  h1 {
    font-family: var(--font-serif);
    font-size: 30px;
    font-weight: 500;
    letter-spacing: -0.01em;
  }
  .resume {
    color: var(--wt-ink3);
    font-size: 14px;
    white-space: nowrap;
  }
  .actions {
    display: flex;
    gap: 8px;
  }
  .outils {
    display: flex;
    align-items: center;
    gap: 8px;
    flex-wrap: wrap;
  }
  .recherche {
    width: 260px;
    height: 34px;
    border-radius: 9px;
    border: 1px solid var(--wt-line2);
    background: var(--wt-card);
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 0 10px;
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
    font-size: 13.5px;
    color: var(--wt-ink);
  }
  .recherche input::placeholder {
    color: var(--wt-ink3);
  }
  .espace {
    flex: 1;
  }
  .sel-lib {
    font-size: 13px;
    color: var(--wt-ink3);
  }
  .corbeille {
    height: 30px;
    width: 30px;
    border-radius: 8px;
    border: 1px solid var(--wt-line2);
    background: var(--wt-card);
    color: var(--wt-danger);
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .corbeille:disabled {
    opacity: 0.5;
  }

  .table-zone {
    flex: 1;
    min-height: 0;
    overflow: auto;
    margin: 0 24px 20px;
    border: 1px solid var(--wt-line);
    border-radius: 12px;
    background: var(--wt-card);
    scrollbar-width: thin;
  }
  .table {
    min-width: 1018px;
  }
  .ligne {
    display: grid;
    grid-template-columns: 32px 112px minmax(130px, 1.3fr) minmax(140px, 1.4fr) minmax(130px, 1.2fr) 92px 68px 150px 44px 96px 92px;
    align-items: center;
  }
  .entete {
    position: sticky;
    top: 0;
    z-index: 2;
    background: var(--wt-card2);
    height: 36px;
    border-bottom: 1px solid var(--wt-line);
  }
  .th {
    border: 0;
    background: transparent;
    padding: 0;
    height: 100%;
    display: flex;
    align-items: center;
    gap: 4px;
    font-size: 12px;
    font-weight: 600;
    color: var(--wt-ink2);
    text-align: left;
    white-space: nowrap;
  }
  .th.actif {
    color: var(--wt-ink);
  }
  .th.droite {
    justify-content: flex-end;
  }
  .th.decale {
    padding-left: 12px;
  }
  .filtres {
    height: 34px;
    border-bottom: 1px solid var(--wt-line);
    font-size: 12px;
    color: var(--wt-ink3);
    position: sticky;
    top: 36px;
    z-index: 2;
    background: var(--wt-card);
  }
  .f-icone {
    display: flex;
    justify-content: center;
  }
  .f {
    padding-right: 8px;
  }
  .filtre {
    width: 100%;
    height: 24px;
    border: 1px solid var(--wt-line);
    border-radius: 6px;
    padding: 0 6px;
    background: var(--wt-card);
    font-size: 12px;
    color: var(--wt-ink);
    outline: none;
  }
  .filtre::placeholder {
    color: var(--wt-ink3);
  }
  .filtre:focus {
    border-color: var(--wt-accent);
  }
  select.filtre {
    -webkit-appearance: none;
    appearance: none;
    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%2376624F' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='m6 9 6 6 6-6'/%3E%3C/svg%3E");
    background-repeat: no-repeat;
    background-size: 12px;
    background-position: right 5px center;
    padding-right: 20px;
  }
  .corps {
    height: 38px;
    border-bottom: 1px solid var(--wt-line);
    font-size: 13.5px;
    cursor: default;
    outline: none;
  }
  .corps:hover {
    background: var(--wt-card2);
  }
  .corps.selection {
    background: var(--wt-accent-tint);
  }
  .repere {
    display: flex;
    justify-content: center;
  }
  .barre-sel {
    width: 6px;
    height: 20px;
    border-radius: 3px;
    background: var(--wt-accent);
  }
  .couleur {
    display: flex;
    align-items: center;
    gap: 6px;
    color: var(--wt-ink2);
    font-size: 13px;
  }
  .cuvee {
    font-weight: 500;
  }
  .coupe {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    padding-right: 10px;
  }
  .gris {
    color: var(--wt-ink2);
  }
  .garde {
    display: flex;
  }
  .droite {
    text-align: right;
  }
  .qte {
    font-weight: 600;
  }
  .decale {
    padding-left: 12px;
  }
  .tiret {
    color: var(--wt-ink3);
  }
  .conso {
    background: var(--wt-paper);
    color: var(--wt-ink3);
  }
  .conso .cuvee {
    text-decoration: line-through;
    font-weight: 400;
  }
  .conso .gris,
  .conso .couleur {
    color: var(--wt-ink3);
  }
  .conso .qte {
    font-weight: 400;
  }
  .g-conso {
    padding-left: 7px;
  }
  .date-conso {
    color: var(--wt-ink2);
    font-weight: 500;
  }
  .vide {
    padding: 72px 24px;
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
    gap: 10px;
  }
  .v-titre {
    font-family: var(--font-serif);
    font-size: 26px;
    font-weight: 500;
  }
  .v-texte {
    font-size: 14px;
    color: var(--wt-ink2);
    max-width: 380px;
  }
  .v-boutons {
    display: flex;
    gap: 8px;
    margin-top: 6px;
  }
  .aucune {
    padding: 40px 24px;
    text-align: center;
    color: var(--wt-ink3);
  }
  .aide {
    flex: none;
    margin: -10px 24px 14px;
    display: flex;
    gap: 16px;
    font-size: 12px;
    color: var(--wt-ink3);
  }

  @media print {
    .ecran,
    .principal,
    .table-zone {
      overflow: visible;
      display: block;
      height: auto;
    }
    .table-zone {
      margin: 0;
      border: 0;
    }
    .table {
      min-width: 0;
    }
    .entete {
      position: static;
    }
    .corps {
      break-inside: avoid;
    }
  }
</style>
