<script>
  // E-06 — Catalogue (téléphone) : segmenté Appellations / Domaines / Cuvées, recherche, liste.
  import { routeur } from '../../lib/routeur.svelte.js';
  import { catalogue } from '../../lib/stores/catalogue.svelte.js';
  import { elements, RUBRIQUES } from '../../lib/catalogue-vues.js';
  import { simplifier } from '../../lib/format.js';
  import Segmented from '../../components/Segmented.svelte';
  import Icon from '../../components/Icon.svelte';
  import WineGlass from '../../components/WineGlass.svelte';

  const rubrique = $derived(RUBRIQUES[routeur.segments[1]] ? routeur.segments[1] : 'cuvees');
  let recherche = $state('');

  const liste = $derived.by(() => {
    catalogue.appellations;
    catalogue.domaines;
    catalogue.cuvees;
    const q = simplifier(recherche.trim());
    return elements(rubrique).filter((e) => !q || simplifier(e.nom + ' ' + e.sous).includes(q));
  });
</script>

<div class="page">
  <Segmented
    label="Rubrique du catalogue"
    valeur={rubrique}
    options={[
      { valeur: 'appellations', libelle: 'Appellations' },
      { valeur: 'domaines', libelle: 'Domaines' },
      { valeur: 'cuvees', libelle: 'Cuvées' },
    ]}
    onchange={(v) => {
      recherche = '';
      routeur.aller(`/catalogue/${v}`, { remplacer: true });
    }}
  />
  <div class="outils">
    <label class="recherche">
      <Icon nom="search" taille={20} />
      <input type="search" placeholder="Rechercher" bind:value={recherche} aria-label="Rechercher" />
    </label>
    <button type="button" class="ajouter" aria-label={RUBRIQUES[rubrique].nouvelle} onclick={() => routeur.aller(`/catalogue/${rubrique}/nouveau`)}>
      <Icon nom="plus" taille={22} epaisseur={2} />
    </button>
  </div>
  {#if liste.length}
    <div class="liste">
      {#each liste as e (e.id)}
        <button type="button" class="ligne" onclick={() => routeur.aller(`/catalogue/${rubrique}/${e.id}`)}>
          {#if e.couleur !== undefined}<WineGlass couleur={e.couleur} taille={20} />{/if}
          <span class="textes"><span class="nom">{e.nom}</span><span class="sous">{e.sous}</span></span>
          <Icon nom="chevR" taille={18} couleur="var(--wt-ink3)" />
        </button>
      {/each}
    </div>
  {:else}
    <p class="aucun">Rien ne correspond.</p>
  {/if}
</div>

<style>
  .page {
    display: flex;
    flex-direction: column;
    padding: 8px 20px 24px;
    gap: 12px;
  }
  .outils {
    display: flex;
    gap: 8px;
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
  .ajouter {
    width: 48px;
    height: 48px;
    border-radius: 14px;
    background: var(--wt-accent);
    border: 0;
    color: var(--wt-on-accent);
    display: flex;
    align-items: center;
    justify-content: center;
    flex: none;
  }
  .liste {
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
    min-height: 60px;
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
  }
  .nom {
    font-size: 16px;
    font-weight: 500;
  }
  .sous {
    font-size: 13px;
    color: var(--wt-ink2);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .aucun {
    padding: 24px 0;
    text-align: center;
    color: var(--wt-ink3);
  }
</style>
