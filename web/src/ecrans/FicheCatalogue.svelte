<script>
  // E-06 — Fiche d'une appellation, d'un domaine ou d'une cuvée (les deux formats).
  import { untrack } from 'svelte';
  import { ctx } from '../lib/contexte.svelte.js';
  import { routeur } from '../lib/routeur.svelte.js';
  import { ErreurApi } from '../lib/api.js';
  import { catalogue } from '../lib/stores/catalogue.svelte.js';
  import { cave } from '../lib/stores/cave.svelte.js';
  import { reglages } from '../lib/stores/reglages.svelte.js';
  import { toast } from '../lib/toast.svelte.js';
  import { RUBRIQUES, cuveesLiees, sousLigne, messageRefus, appellationPrincipale } from '../lib/catalogue-vues.js';
  import { questionAppellation, questionDomaine, questionCuvee, demanderIA } from '../lib/ia.js';
  import { millesime, pluriel, accord } from '../lib/format.js';
  import EnTete from '../components/EnTete.svelte';
  import Field from '../components/Field.svelte';
  import ImageDrop from '../components/ImageDrop.svelte';
  import { vin } from '../lib/vins.js';
  import ChoixCouleur from '../components/ChoixCouleur.svelte';
  import WineGlass from '../components/WineGlass.svelte';
  import Button from '../components/Button.svelte';
  import Icon from '../components/Icon.svelte';

  /** @type {{ rubrique: string, id: string }} */
  let { rubrique, id } = $props();

  const nouveau = $derived(id === 'nouveau');
  const idNum = $derived(nouveau ? null : Number(id));
  const R = $derived(RUBRIQUES[rubrique] ?? RUBRIQUES.cuvees);
  const objet = $derived(
    idNum === null ? null : rubrique === 'appellations' ? catalogue.appellation(idNum) : rubrique === 'domaines' ? catalogue.domaine(idNum) : catalogue.cuvee(idNum),
  );

  // Champs du formulaire
  let nom = $state('');
  let region = $state('');
  let description = $state('');
  let image = $state(/** @type {string|null|undefined} */ (undefined));
  let domaineId = $state(0);
  let appellationId = $state(0);
  let couleur = $state(1);
  let erreur = $state('');
  let refus = $state('');
  let enCours = $state(false);

  function charger() {
    const o = objet;
    nom = o?.nom ?? '';
    region = o?.region ?? '';
    description = o?.description ?? '';
    image = undefined;
    domaineId = o?.domaine_id ?? 0;
    appellationId = o?.appellation_id ?? 0;
    couleur = o?.couleur ?? 1;
    erreur = '';
    refus = '';
  }

  // Recharge le formulaire quand on change de fiche (pas quand le catalogue est rechargé).
  $effect(() => {
    rubrique;
    id;
    untrack(charger);
  });

  const liees = $derived(nouveau || rubrique === 'cuvees' ? [] : cuveesLiees(rubrique, /** @type {number} */ (idNum), cave.enStock));
  const bouteillesEnCave = $derived(liees.reduce((s, l) => s + l.qte, 0));
  const cuveesEnCave = $derived(new Set(liees.map((l) => l.cuvee)).size);
  const principale = $derived(rubrique === 'domaines' && idNum ? appellationPrincipale(idNum) : null);
  const titre = $derived(nom.trim() || (nouveau ? R.nouvelle : objet?.nom ?? ''));
  const sous = $derived(nouveau ? '' : sousLigne(rubrique, objet));

  function donnees() {
    if (rubrique === 'appellations') {
      const d = { nom: nom.trim(), region: region.trim(), description: description.trim() };
      if (image !== undefined) d.image = image;
      return d;
    }
    if (rubrique === 'domaines') return { nom: nom.trim(), description: description.trim() };
    return { nom: nom.trim(), domaine_id: domaineId, appellation_id: appellationId, couleur, description: description.trim() };
  }

  async function enregistrer() {
    if (!nom.trim()) {
      erreur = 'Le nom est obligatoire';
      return;
    }
    if (rubrique === 'cuvees' && !domaineId) {
      erreur = 'Choisissez un domaine';
      return;
    }
    enCours = true;
    try {
      const o = await catalogue.enregistrer(rubrique, idNum, donnees());
      toast.afficher('Fiche enregistrée');
      image = undefined;
      if (!ctx.ordinateur) routeur.retour(`/catalogue/${rubrique}`);
      else if (nouveau) routeur.aller(`/catalogue/${rubrique}/${o.id}`, { remplacer: true });
    } catch (e) {
      erreur = e instanceof ErreurApi ? e.message : 'Enregistrement impossible';
    } finally {
      enCours = false;
    }
  }

  async function supprimer() {
    refus = '';
    try {
      await catalogue.supprimer(rubrique, /** @type {number} */ (idNum));
      toast.afficher('Fiche supprimée');
      if (ctx.ordinateur) routeur.aller(`/catalogue/${rubrique}`, { remplacer: true });
      else routeur.retour(`/catalogue/${rubrique}`);
    } catch (e) {
      if (e instanceof ErreurApi && e.code === 'referencee') refus = messageRefus(rubrique, e.donnees.nombre ?? 1);
      else toast.afficher(e.message);
    }
  }

  function ia() {
    const n = nom.trim() || objet?.nom || '';
    if (!n) {
      toast.afficher('Saisissez d’abord un nom');
      return;
    }
    let q;
    if (rubrique === 'appellations') q = questionAppellation(n);
    else if (rubrique === 'domaines') q = questionDomaine(n);
    else q = questionCuvee(n, catalogue.domaine(domaineId)?.nom, catalogue.appellation(appellationId)?.nom, couleur ? vin(couleur).libelle : undefined);
    const qui = demanderIA(q);
    if (!ctx.dansApplication) toast.afficher(`${qui} s’ouvre dans un nouvel onglet`);
  }

  function clavier(e) {
    if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
      e.preventDefault();
      enregistrer();
    }
  }
</script>

<svelte:window onkeydown={ctx.ordinateur ? clavier : undefined} />

{#snippet champNom()}
  <Field label="Nom" id="cat-nom" erreur={erreur}>
    <input id="cat-nom" class="champ" class:erreur={!!erreur} bind:value={nom} oninput={() => (erreur = '')} />
  </Field>
{/snippet}
{#snippet champDescription()}
  <Field label="Description" id="cat-desc">
    <textarea id="cat-desc" class="champ" bind:value={description}></textarea>
  </Field>
{/snippet}
{#snippet champRegion()}
  <Field label="Région" id="cat-region">
    <input id="cat-region" class="champ liste-deroulante" list="regions" bind:value={region} autocomplete="off" />
    <datalist id="regions">
      {#each catalogue.regions as r (r)}<option value={r}></option>{/each}
    </datalist>
  </Field>
{/snippet}
{#snippet champsCuvee()}
  <Field label="Domaine" id="cat-dom">
    <select id="cat-dom" class="champ" bind:value={domaineId}>
      {#if !domaineId}<option value={0}>Choisir un domaine</option>{/if}
      {#each catalogue.domaines as d (d.id)}<option value={d.id}>{d.nom}</option>{/each}
    </select>
  </Field>
  <Field label="Appellation" id="cat-app">
    <select id="cat-app" class="champ" bind:value={appellationId}>
      <option value={0}>Sans appellation</option>
      {#each catalogue.appellations as a (a.id)}<option value={a.id}>{a.nom}</option>{/each}
    </select>
  </Field>
{/snippet}
{#snippet refusSuppression()}
  {#if refus}
    <div class="refus" role="alert">
      <Icon nom="info" taille={16} epaisseur={1.9} couleur="var(--wt-warn)" />
      <span>Suppression impossible&nbsp;: {refus}. Modifiez-les ou supprimez-les d'abord.</span>
    </div>
  {/if}
{/snippet}

{#if ctx.ordinateur}
  <div class="o-detail">
    <div class="o-tete">
      <div class="o-titres">
        <span class="surtitre">{R.type}</span>
        <span class="o-nom">{titre}</span>
        {#if sous}<span class="o-sous">{sous}</span>{/if}
      </div>
      <div class="o-actions">
        <Button taille="ord-s" onclick={ia}
          ><Icon nom="sparkles" taille={16} couleur="var(--wt-accent-ink)" />Demander à {reglages.nomAssistant}<Icon
            nom="ext"
            taille={13}
            couleur="var(--wt-ink3)"
          /></Button
        >
        {#if !nouveau}
          <button type="button" class="corbeille" aria-label="Supprimer" onclick={supprimer}><Icon nom="trash" taille={16} /></button>
        {/if}
      </div>
    </div>
    {@render refusSuppression()}

    {#if rubrique === 'appellations'}
      <div class="o-grille app">
        <div class="pile">
          {@render champNom()}
          {@render champRegion()}
          {@render champDescription()}
        </div>
        <ImageDrop urlActuelle={catalogue.urlImage(objet)} bind:image />
      </div>
    {:else if rubrique === 'domaines'}
      <div class="o-grille dom">
        <div class="pile">
          {@render champNom()}
          {@render champDescription()}
        </div>
        {#if !nouveau}
          <div class="tuile">
            <div class="t-chiffre"><span class="grand">{bouteillesEnCave}</span><span class="t-lib">{accord(bouteillesEnCave, 'bouteille')} en cave</span></div>
            <div class="t-princ"><span class="t-lib3">Appellation principale</span><span>{principale?.nom ?? '—'}</span></div>
          </div>
        {/if}
      </div>
    {:else}
      <div class="o-grille cuv">
        <div class="span2">{@render champNom()}</div>
        {@render champsCuvee()}
        <div class="span2"><ChoixCouleur bind:couleur /></div>
        <div class="span2">{@render champDescription()}</div>
      </div>
    {/if}

    {#if !nouveau && rubrique !== 'cuvees'}
      <div class="liees">
        <span class="l-titre"
          >{rubrique === 'appellations' ? 'Cuvées de cette appellation' : 'Cuvées du domaine'}
          <span class="l-nb">· {pluriel(liees.length, 'cuvée')}</span></span
        >
        {#if liees.length}
          <div class="l-table">
            {#each liees as l (l.cle)}
              <div class="l-ligne">
                <WineGlass couleur={l.couleur} taille={18} />
                <span class="l-cuvee">{l.cuvee}</span>
                <span class="l-sous">{l.sous}</span>
                <span class="tnum">{millesime(l.millesime)}</span>
                <span class="tnum droite">{pluriel(l.qte, 'bouteille')}</span>
              </div>
            {/each}
          </div>
        {:else}
          <span class="l-vide">Aucune bouteille en cave.</span>
        {/if}
      </div>
    {/if}

    <div class="o-pied">
      <Button variante="primary" taille="ord-m" style="padding:0 16px" disabled={enCours} onclick={enregistrer}>Enregistrer</Button>
      <Button taille="ord-m" style="font-weight:400" onclick={charger}>Annuler</Button>
    </div>
  </div>
{:else}
  <div class="t-page">
    <EnTete retour="/catalogue/{rubrique}" action="Enregistrer" actionDesactivee={enCours} onaction={enregistrer} />
    <div class="t-titres">
      <span class="surtitre t">{R.type}</span>
      <span class="t-nom">{titre}</span>
      {#if sous}<span class="t-sous">{sous}</span>{/if}
    </div>

    {#if rubrique === 'appellations'}
      <ImageDrop urlActuelle={catalogue.urlImage(objet)} bind:image />
      {@render champNom()}
      {@render champRegion()}
      {@render champDescription()}
    {:else if rubrique === 'domaines'}
      {#if !nouveau}
        <div class="t-tuiles">
          <div class="t-tuile"><span class="t-grand">{bouteillesEnCave}</span><span>{accord(bouteillesEnCave, 'bouteille')} en cave</span></div>
          <div class="t-tuile"><span class="t-grand">{cuveesEnCave}</span><span>{accord(cuveesEnCave, 'cuvée')} en cave</span></div>
        </div>
      {/if}
      {@render champNom()}
      {@render champDescription()}
    {:else}
      {@render champNom()}
      {@render champsCuvee()}
      <ChoixCouleur bind:couleur />
      {@render champDescription()}
    {/if}

    {#if !nouveau && rubrique !== 'cuvees' && liees.length}
      <div class="t-liees">
        <span class="t-ltitre">{rubrique === 'appellations' ? 'Cuvées de cette appellation' : 'Cuvées du domaine'}</span>
        <div class="t-liste">
          {#each liees as l (l.cle)}
            <div class="t-ligne">
              <WineGlass couleur={l.couleur} taille={20} />
              <span class="t-textes"
                ><span class="t-cuvee">{l.cuvee} <span class="mil">{millesime(l.millesime)}</span></span><span class="t-lsous">{l.sous}</span></span
              >
              <span class="t-qte">{l.qte}</span>
            </div>
          {/each}
        </div>
      </div>
    {/if}

    <Button taille="tel-s" onclick={ia}><Icon nom="sparkles" taille={18} couleur="var(--wt-accent-ink)" />Demander à {reglages.nomAssistant}</Button>
    {#if !nouveau}
      <Button taille="tel-s" variante="danger-texte" onclick={supprimer}>Supprimer</Button>
    {/if}
    {@render refusSuppression()}
  </div>
{/if}

<style>
  .surtitre {
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.1em;
    text-transform: uppercase;
    color: var(--wt-ink3);
  }
  .surtitre.t {
    font-size: 12px;
  }
  .refus {
    display: flex;
    align-items: center;
    gap: 8px;
    background: var(--wt-warn-tint);
    border-radius: 9px;
    padding: 9px 12px;
    font-size: 13.5px;
  }
  .liste-deroulante {
    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%2376624F' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='m6 9 6 6 6-6'/%3E%3C/svg%3E");
    background-repeat: no-repeat;
    background-size: 14px;
    background-position: right 10px center;
  }

  /* Ordinateur */
  .o-detail {
    flex: 1;
    min-width: 0;
    container-type: inline-size;
    overflow: auto;
    padding: 20px 28px;
    display: flex;
    flex-direction: column;
    gap: 16px;
  }
  .o-tete {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 12px;
  }
  .o-titres {
    display: flex;
    flex-direction: column;
    gap: 2px;
    min-width: 0;
  }
  .o-nom {
    font-family: var(--font-serif);
    font-size: 30px;
    font-weight: 500;
    line-height: 1.1;
  }
  .o-sous {
    font-size: 13.5px;
    color: var(--wt-ink2);
  }
  .o-actions {
    display: flex;
    gap: 8px;
    flex: none;
  }
  .corbeille {
    height: 34px;
    width: 34px;
    border-radius: 9px;
    border: 1px solid var(--wt-line2);
    background: var(--wt-card);
    color: var(--wt-danger);
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .o-grille {
    display: grid;
    gap: 24px;
    align-items: start;
  }
  .o-grille.app {
    grid-template-columns: minmax(0, 1fr) 300px;
  }
  .o-grille.dom {
    grid-template-columns: minmax(0, 1fr) 220px;
  }
  .o-grille.cuv {
    grid-template-columns: 1fr 1fr;
    gap: 14px;
    max-width: 720px;
  }
  /* Panneau étroit (tablette, petite fenêtre) : champs puis carte ou tuile, sur une colonne. */
  @container (max-width: 640px) {
    .o-grille.app,
    .o-grille.dom {
      grid-template-columns: minmax(0, 1fr);
    }
  }
  .span2 {
    grid-column: span 2;
  }
  .pile {
    display: flex;
    flex-direction: column;
    gap: 14px;
  }
  .tuile {
    border: 1px solid var(--wt-line);
    border-radius: 12px;
    background: var(--wt-card);
    padding: 16px;
    display: flex;
    flex-direction: column;
    gap: 12px;
  }
  .t-chiffre {
    display: flex;
    flex-direction: column;
  }
  .grand {
    font-family: var(--font-serif);
    font-size: 40px;
    line-height: 1;
    font-weight: 500;
  }
  .t-lib {
    font-size: 13px;
    color: var(--wt-ink2);
  }
  .t-princ {
    display: flex;
    flex-direction: column;
    gap: 2px;
    font-size: 13.5px;
  }
  .t-lib3 {
    color: var(--wt-ink3);
  }
  .liees {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .l-titre {
    font-family: var(--font-serif);
    font-size: 19px;
    font-weight: 500;
  }
  .l-nb {
    font-family: var(--font-sans);
    font-size: 13px;
    color: var(--wt-ink3);
    font-weight: 400;
  }
  .l-table {
    border: 1px solid var(--wt-line);
    border-radius: 10px;
    background: var(--wt-card);
    overflow: hidden;
  }
  .l-ligne {
    display: grid;
    grid-template-columns: 24px minmax(0, 1fr) minmax(0, 1fr) 60px 90px;
    gap: 10px;
    align-items: center;
    height: 38px;
    padding: 0 12px;
    border-bottom: 1px solid var(--wt-line);
    font-size: 13.5px;
  }
  .l-ligne:last-child {
    border-bottom: 0;
  }
  .l-cuvee {
    font-weight: 500;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .l-sous {
    color: var(--wt-ink2);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .droite {
    text-align: right;
  }
  .l-vide {
    font-size: 13.5px;
    color: var(--wt-ink3);
  }
  .o-pied {
    display: flex;
    gap: 8px;
  }

  /* Téléphone */
  .t-page {
    display: flex;
    flex-direction: column;
    padding: 0 20px 24px;
    gap: 14px;
  }
  .t-titres {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .t-nom {
    font-family: var(--font-serif);
    font-size: 32px;
    font-weight: 500;
    line-height: 1.1;
  }
  .t-sous {
    font-size: 14px;
    color: var(--wt-ink2);
  }
  .t-tuiles {
    display: flex;
    gap: 10px;
  }
  .t-tuile {
    flex: 1;
    background: var(--wt-card);
    border: 1px solid var(--wt-line);
    border-radius: 16px;
    padding: 14px 16px;
    display: flex;
    flex-direction: column;
    font-size: 13px;
    color: var(--wt-ink2);
  }
  .t-grand {
    font-family: var(--font-serif);
    font-size: 34px;
    line-height: 1;
    color: var(--wt-ink);
  }
  .t-liees {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .t-ltitre {
    font-family: var(--font-serif);
    font-size: 21px;
    font-weight: 500;
  }
  .t-liste {
    background: var(--wt-card);
    border: 1px solid var(--wt-line);
    border-radius: 16px;
    overflow: hidden;
  }
  .t-ligne {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 12px 14px;
    border-bottom: 1px solid var(--wt-line);
    min-height: 56px;
  }
  .t-ligne:last-child {
    border-bottom: 0;
  }
  .t-textes {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
  }
  .t-cuvee {
    font-size: 16px;
    font-weight: 500;
  }
  .mil {
    color: var(--wt-ink3);
    font-weight: 400;
  }
  .t-lsous {
    font-size: 13px;
    color: var(--wt-ink2);
  }
  .t-qte {
    font-family: var(--font-serif);
    font-size: 20px;
  }
  .t-page .refus {
    border-radius: 14px;
    padding: 12px 14px;
    font-size: 14px;
  }
</style>
