<script>
  // Création d'une cuvée depuis le formulaire de bouteille (« Créer la cuvée « … » »).
  import { untrack } from 'svelte';
  import { ctx } from '../lib/contexte.svelte.js';
  import { catalogue } from '../lib/stores/catalogue.svelte.js';
  import { toast } from '../lib/toast.svelte.js';
  import Sheet from './Sheet.svelte';
  import Modal from './Modal.svelte';
  import Field from './Field.svelte';
  import Autocomplete from './Autocomplete.svelte';
  import ChoixCouleur from './ChoixCouleur.svelte';
  import Button from './Button.svelte';
  import Icon from './Icon.svelte';

  /** @type {{ nom: string, onfermer: () => void, oncree: (id: number) => void }} */
  let { nom: nomInitial, onfermer, oncree } = $props();

  let nom = $state(untrack(() => nomInitial));
  let texteDomaine = $state('');
  let domaineId = $state(/** @type {number|null} */ (null));
  let texteAppellation = $state('');
  let appellationId = $state(0);
  let couleur = $state(1);
  let erreurs = $state(/** @type {Record<string,string>} */ ({}));
  let enCours = $state(false);

  const optDomaines = $derived(catalogue.domaines.map((d) => ({ id: d.id, nom: d.nom })));
  const optApps = $derived(catalogue.appellations.map((a) => ({ id: a.id, nom: a.nom, sous: a.region })));

  async function creerDomaine(texte) {
    try {
      const d = await catalogue.enregistrer('domaines', null, { nom: texte, description: '' });
      domaineId = d.id;
      texteDomaine = d.nom;
      toast.afficher(`Domaine « ${d.nom} » créé`);
    } catch (e) {
      toast.afficher(e.message);
    }
  }

  async function creerAppellation(texte) {
    try {
      const a = await catalogue.enregistrer('appellations', null, { nom: texte, region: '', description: '' });
      appellationId = a.id;
      texteAppellation = a.nom;
      toast.afficher(`Appellation « ${a.nom} » créée`);
    } catch (e) {
      toast.afficher(e.message);
    }
  }

  async function creer() {
    const e = {};
    if (!nom.trim()) e.nom = 'Le nom est obligatoire';
    if (!domaineId || catalogue.domaine(domaineId)?.nom !== texteDomaine) e.domaine = 'Choisissez ou créez un domaine';
    erreurs = e;
    if (Object.keys(e).length) return;
    enCours = true;
    try {
      const appOk = appellationId && catalogue.appellation(appellationId)?.nom === texteAppellation ? appellationId : 0;
      const c = await catalogue.enregistrer('cuvees', null, {
        nom: nom.trim(),
        domaine_id: domaineId,
        appellation_id: appOk,
        couleur,
        description: '',
      });
      toast.afficher(`Cuvée « ${c.nom} » créée`);
      oncree(c.id);
    } catch (err) {
      toast.afficher(err.message);
    } finally {
      enCours = false;
    }
  }
</script>

{#snippet formulaire()}
  <Field label="Nom" id="nc-nom" erreur={erreurs.nom}>
    <input id="nc-nom" class="champ" class:erreur={!!erreurs.nom} bind:value={nom} />
  </Field>
  <Field label="Domaine" id="nc-domaine" erreur={erreurs.domaine}>
    <Autocomplete
      id="nc-domaine"
      bind:valeur={texteDomaine}
      options={optDomaines}
      erreur={!!erreurs.domaine}
      placeholder="Nom du domaine"
      onchoisir={(o) => (domaineId = o.id)}
      oncreer={creerDomaine}
      libelleCreer={(t) => `Créer le domaine « ${t} »`}
    />
  </Field>
  <Field label="Appellation" id="nc-app" facultatif>
    <Autocomplete
      id="nc-app"
      bind:valeur={texteAppellation}
      options={optApps}
      placeholder="Nom de l'appellation"
      onchoisir={(o) => (appellationId = o.id)}
      oncreer={creerAppellation}
      libelleCreer={(t) => `Créer l'appellation « ${t} »`}
    />
  </Field>
  <ChoixCouleur bind:couleur />
{/snippet}

{#if ctx.ordinateur}
  <Modal {onfermer} label="Nouvelle cuvée" largeur={480}>
    <div class="o-tete">
      <span class="o-titre">Nouvelle cuvée</span>
      <button type="button" class="fermer" aria-label="Fermer" onclick={onfermer}><Icon nom="x" taille={18} /></button>
    </div>
    <div class="o-corps">{@render formulaire()}</div>
    <div class="o-pied">
      <Button taille="ord-l" onclick={onfermer}>Annuler</Button>
      <Button taille="ord-l" variante="primary" disabled={enCours} onclick={creer}>Créer la cuvée</Button>
    </div>
  </Modal>
{:else}
  <Sheet {onfermer} label="Nouvelle cuvée">
    <div class="t-corps">
      <span class="t-titre">Nouvelle cuvée</span>
      {@render formulaire()}
    </div>
    {#snippet pied()}
      <div class="t-pied">
        <Button taille="tel-l" variante="primary" pleine disabled={enCours} onclick={creer}>Créer la cuvée</Button>
      </div>
    {/snippet}
  </Sheet>
{/if}

<style>
  .o-tete {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 16px 20px;
    border-bottom: 1px solid var(--wt-line);
  }
  .o-titre {
    font-family: var(--font-serif);
    font-size: 22px;
    font-weight: 500;
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
  .o-corps {
    padding: 16px 20px;
    display: flex;
    flex-direction: column;
    gap: 14px;
    overflow: auto;
  }
  .o-pied {
    padding: 14px 20px;
    border-top: 1px solid var(--wt-line);
    display: flex;
    gap: 8px;
    justify-content: flex-end;
  }
  .t-corps {
    padding: 8px 22px 16px;
    display: flex;
    flex-direction: column;
    gap: 14px;
  }
  .t-titre {
    font-family: var(--font-serif);
    font-size: 28px;
    font-weight: 500;
  }
  .t-pied {
    display: flex;
  }
</style>
