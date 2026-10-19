<script>
  // E-06 — Catalogue (ordinateur) : colonne liste de 330 px et détail.
  import { routeur } from '../../lib/routeur.svelte.js';
  import { catalogue } from '../../lib/stores/catalogue.svelte.js';
  import { creation } from '../../lib/stores/creation.svelte.js';
  import { elements, RUBRIQUES } from '../../lib/catalogue-vues.js';
  import { simplifier } from '../../lib/format.js';
  import Icon from '../../components/Icon.svelte';
  import Kbd from '../../components/Kbd.svelte';
  import WineGlass from '../../components/WineGlass.svelte';
  import Blason from '../../components/Blason.svelte';
  import FicheCatalogue from '../FicheCatalogue.svelte';

  const rubrique = $derived(RUBRIQUES[routeur.segments[1]] ? routeur.segments[1] : 'cuvees');
  let filtre = $state('');

  const liste = $derived.by(() => {
    catalogue.appellations;
    catalogue.domaines;
    catalogue.cuvees;
    const q = simplifier(filtre.trim());
    return elements(rubrique).filter((e) => !q || simplifier(e.nom + ' ' + e.sous).includes(q));
  });

  // Sans fiche choisie : la première de la liste.
  const id = $derived(routeur.segments[2] ?? (liste[0] ? String(liste[0].id) : 'nouveau'));

  /** « Ajouter » : écran de création sans objet d'origine. */
  function ajouter() {
    creation.vider();
    routeur.aller(`/catalogue/${rubrique}/nouveau`);
  }

  function clavier(e) {
    const t = /** @type {HTMLElement} */ (e.target);
    if (t.closest('input, textarea, select, [contenteditable]') || e.metaKey || e.ctrlKey || e.altKey) return;
    if (e.key === 'n') {
      e.preventDefault();
      ajouter();
    }
  }
</script>

<svelte:window onkeydown={clavier} />

<div class="ecran">
  <div class="colonne">
    <div class="c-haut">
      <div class="c-titre">
        <h1>{RUBRIQUES[rubrique].titre}</h1>
        <button type="button" class="ajouter" onclick={ajouter}>
          <Icon nom="plus" taille={14} epaisseur={2.2} />Ajouter<Kbd touche="N" />
        </button>
      </div>
      <label class="filtre">
        <Icon nom="search" taille={16} />
        <input type="search" placeholder="Filtrer" bind:value={filtre} aria-label="Filtrer" />
      </label>
    </div>
    <div class="liste">
      {#each liste as e (e.id)}
        <button
          type="button"
          class="element"
          class:on={String(e.id) === id}
          onclick={() => {
            creation.vider();
            routeur.aller(`/catalogue/${rubrique}/${e.id}`, { remplacer: true });
          }}
        >
          {#if e.couleur !== undefined}<WineGlass couleur={e.couleur} taille={18} />{/if}
          <span class="textes"
            ><span class="nom">{e.nom}</span><span class="sous"
              >{#if e.region}<Blason region={e.region} largeur={11} hauteur={13} />{/if}<span class="coupe">{e.sous}</span></span
            ></span
          >
        </button>
      {/each}
    </div>
  </div>
  {#key rubrique + '/' + id}
    <FicheCatalogue {rubrique} {id} />
  {/key}
</div>

<style>
  .ecran {
    flex: 1;
    min-height: 0;
    display: flex;
  }
  .colonne {
    width: 330px;
    flex: none;
    border-right: 1px solid var(--wt-line);
    display: flex;
    flex-direction: column;
  }
  .c-haut {
    padding: 20px 16px 12px;
    display: flex;
    flex-direction: column;
    gap: 12px;
  }
  .c-titre {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  h1 {
    font-family: var(--font-serif);
    font-size: 28px;
    font-weight: 500;
  }
  .ajouter {
    height: 32px;
    border-radius: 8px;
    border: 0;
    background: var(--wt-accent);
    color: var(--wt-on-accent);
    padding: 0 10px;
    font-size: 13px;
    font-weight: 600;
    display: flex;
    align-items: center;
    gap: 5px;
  }
  .filtre {
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
  .filtre:focus-within {
    border-color: var(--wt-accent);
    box-shadow: 0 0 0 3px var(--wt-accent-tint);
  }
  .filtre input {
    flex: 1;
    min-width: 0;
    border: 0;
    outline: none;
    background: transparent;
    font-size: 13.5px;
    color: var(--wt-ink);
  }
  .filtre input::placeholder {
    color: var(--wt-ink3);
  }
  .liste {
    flex: 1;
    overflow: auto;
    padding: 0 8px 12px;
    scrollbar-width: thin;
  }
  .element {
    width: 100%;
    border: 0;
    background: transparent;
    border-radius: 8px;
    padding: 8px 10px;
    display: flex;
    align-items: center;
    gap: 10px;
    text-align: left;
    color: var(--wt-ink);
  }
  .element:hover:not(.on) {
    background: var(--wt-card2);
  }
  .element.on {
    background: var(--wt-accent-tint);
  }
  .textes {
    display: flex;
    flex-direction: column;
    min-width: 0;
  }
  .nom {
    font-size: 14px;
    font-weight: 500;
  }
  .sous {
    font-size: 12.5px;
    color: var(--wt-ink2);
    display: flex;
    align-items: center;
    gap: 5px;
    min-width: 0;
  }
  .coupe {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
</style>
