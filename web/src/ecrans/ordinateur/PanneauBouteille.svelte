<script>
  // E-05 — Formulaire de bouteille en panneau à droite (D-18), la table restant visible.
  import { onMount, untrack } from 'svelte';
  import { FormulaireBouteille } from '../../lib/formulaire.svelte.js';
  import Field from '../../components/Field.svelte';
  import Autocomplete from '../../components/Autocomplete.svelte';
  import TagField from '../../components/TagField.svelte';
  import WineGlass from '../../components/WineGlass.svelte';
  import Button from '../../components/Button.svelte';
  import Icon from '../../components/Icon.svelte';
  import NouvelleCuvee from '../../components/NouvelleCuvee.svelte';

  /**
   * mode : { type: 'nouvelle', modele?: any } | { type: 'modifier', bouteille: any }
   * @type {{ mode: any, onfermer: () => void }}
   */
  let { mode, onfermer } = $props();

  // Le panneau est recréé à chaque ouverture : seul le mode initial compte.
  const depart = untrack(() => mode);
  const f = new FormulaireBouteille();
  if (depart.type === 'modifier') f.modifier(depart.bouteille);
  else f.nouvelle(depart.modele ?? null);

  const raccourci = /Mac|iPhone|iPad/.test(navigator.platform) ? '⌘↵' : 'Ctrl ↵';
  let creation = $state(/** @type {string|null} */ (null));
  let champCuvee = /** @type {HTMLInputElement} */ ($state());

  onMount(() => {
    if (depart.type !== 'modifier' && !depart.modele) champCuvee?.focus();
  });

  async function enregistrer(continuer) {
    const ok = await f.enregistrer(continuer);
    if (ok && (!continuer || f.modification)) onfermer();
  }

  function clavier(e) {
    if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
      e.preventDefault();
      enregistrer(false);
    }
  }
</script>

<svelte:window onkeydown={clavier} />

<aside class="panneau no-print" aria-label="Formulaire de bouteille">
  <div class="tete">
    <div class="titres">
      <span class="titre">{f.modification ? 'Modifier la bouteille' : 'Nouvelle bouteille'}</span>
      {#if !f.modification}<span class="sous">Bouteille n° {f.rang} de la saisie</span>{/if}
    </div>
    <button type="button" class="fermer" aria-label="Fermer" onclick={onfermer}><Icon nom="x" taille={18} /></button>
  </div>

  <div class="corps">
    <Field label="Cuvée" id="o-cuvee" erreur={f.erreurs.cuvee}>
      <Autocomplete
        id="o-cuvee"
        bind:element={champCuvee}
        bind:valeur={f.texteCuvee}
        options={f.options}
        erreur={!!f.erreurs.cuvee}
        placeholder="Nom de la cuvée"
        onchoisir={(o) => f.choisirCuvee(o.id)}
        onsaisie={(t) => f.saisieCuvee(t)}
        oncreer={(t) => (creation = t)}
        libelleCreer={(t) => `Créer la cuvée « ${t} »`}
      />
    </Field>
    {#if f.derive}
      <div class="derive">
        <WineGlass couleur={f.derive.couleur} taille={18} style="color:var(--wt-ink)" />
        <span>{[f.derive.libelle, f.derive.domaine, f.derive.appellation && f.derive.appellation + (f.derive.region ? ` (${f.derive.region})` : '')].filter(Boolean).join(' · ')}</span>
      </div>
    {/if}

    <div class="trois">
      <Field label="Millésime" id="o-mil" erreur={f.erreurs.millesime}>
        <input id="o-mil" class="champ" class:erreur={!!f.erreurs.millesime} inputmode="numeric" maxlength="4" bind:value={f.millesime} />
      </Field>
      <Field label="À boire avant" id="o-garde" erreur={f.erreurs.aBoireAvant}>
        <input id="o-garde" class="champ" class:erreur={!!f.erreurs.aBoireAvant} inputmode="numeric" maxlength="4" bind:value={f.aBoireAvant} />
      </Field>
      <Field label="Prix d'achat" id="o-prix" erreur={f.erreurs.prix}>
        <div class="champ-unite">
          <input id="o-prix" class="champ" class:erreur={!!f.erreurs.prix} inputmode="decimal" bind:value={f.prix} />
          <span class="unite">€</span>
        </div>
      </Field>
    </div>

    <Field label="Commentaire" id="o-com">
      <textarea id="o-com" class="champ commentaire" placeholder="Facultatif" bind:value={f.commentaire}></textarea>
    </Field>

    <TagField bind:tagId={f.tagId} exclure={f.idModifie} erreur={f.erreurs.tag} />
  </div>

  <div class="pied">
    {#if !f.modification}
      <Button taille="ord-l" style="flex:1" disabled={f.enCours} onclick={() => enregistrer(true)}>Enregistrer et continuer</Button>
    {/if}
    <Button taille="ord-l" variante="primary" style={f.modification ? 'flex:1' : ''} disabled={f.enCours} onclick={() => enregistrer(false)}
      >Enregistrer<span class="raccourci">{raccourci}</span></Button
    >
  </div>
</aside>

{#if creation !== null}
  <NouvelleCuvee
    nom={creation}
    onfermer={() => (creation = null)}
    oncree={(id) => {
      f.choisirCuvee(id);
      creation = null;
    }}
  />
{/if}

<style>
  .panneau {
    width: 380px;
    flex: none;
    border-left: 1px solid var(--wt-line);
    background: var(--wt-card);
    display: flex;
    flex-direction: column;
    box-shadow: -12px 0 30px rgba(42, 29, 21, 0.06);
    animation: glisse var(--t-entree) var(--ease);
  }
  @keyframes glisse {
    from {
      transform: translateX(24px);
      opacity: 0;
    }
  }
  .tete {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 16px 20px;
    border-bottom: 1px solid var(--wt-line);
  }
  .titres {
    display: flex;
    flex-direction: column;
  }
  .titre {
    font-family: var(--font-serif);
    font-size: 22px;
    font-weight: 500;
  }
  .sous {
    font-size: 12.5px;
    color: var(--wt-ink3);
  }
  .fermer {
    width: 32px;
    height: 32px;
    border: 0;
    border-radius: 8px;
    background: transparent;
    color: var(--wt-ink2);
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .fermer:hover {
    background: var(--wt-card2);
  }
  .corps {
    flex: 1;
    overflow: auto;
    padding: 16px 20px;
    display: flex;
    flex-direction: column;
    gap: 14px;
    scrollbar-width: thin;
  }
  .derive {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 13px;
    color: var(--wt-ink2);
    background: var(--wt-paper);
    border-radius: 8px;
    padding: 8px 10px;
    margin-top: -6px;
  }
  .trois {
    display: grid;
    grid-template-columns: 1fr 1fr 1fr;
    gap: 10px;
  }
  .commentaire {
    min-height: 56px !important;
    padding: 8px 10px !important;
    font-size: 14px;
  }
  .pied {
    padding: 14px 20px;
    border-top: 1px solid var(--wt-line);
    display: flex;
    gap: 8px;
    align-items: center;
  }
  .raccourci {
    font-family: var(--font-mono);
    font-size: 11px;
    opacity: 0.8;
  }
</style>
