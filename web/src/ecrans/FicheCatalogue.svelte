<script>
  // E-06 — Fiche d'une appellation, d'un domaine ou d'une cuvée (les deux formats), et écran de
  // création (id « nouveau »). Ouvert depuis un autre objet (création en cascade), il montre le fil
  // d'Ariane et revient à l'objet d'origine après la création ou l'annulation.
  import { untrack } from 'svelte';
  import { ctx } from '../lib/contexte.svelte.js';
  import { routeur } from '../lib/routeur.svelte.js';
  import { ErreurApi } from '../lib/api.js';
  import { catalogue } from '../lib/stores/catalogue.svelte.js';
  import { cave } from '../lib/stores/cave.svelte.js';
  import { creation } from '../lib/stores/creation.svelte.js';
  import { toast } from '../lib/toast.svelte.js';
  import { RUBRIQUES, cuveesLiees, sousLigne, messageRefus, appellationPrincipale, elements } from '../lib/catalogue-vues.js';
  import { questionAppellation, questionDomaine, questionCuvee } from '../lib/ia.js';
  import { autoHauteur } from '../lib/auto-hauteur.js';
  import { blason } from '../lib/blasons.js';
  import { millesime, pluriel, accord } from '../lib/format.js';
  import { vin } from '../lib/vins.js';
  import EnTete from '../components/EnTete.svelte';
  import Field from '../components/Field.svelte';
  import ImageDrop from '../components/ImageDrop.svelte';
  import Autocomplete from '../components/Autocomplete.svelte';
  import ChoixCouleur from '../components/ChoixCouleur.svelte';
  import WineGlass from '../components/WineGlass.svelte';
  import Blason from '../components/Blason.svelte';
  import Button from '../components/Button.svelte';
  import BoutonAssistant from '../components/BoutonAssistant.svelte';
  import Confirmation from '../components/Confirmation.svelte';
  import Icon from '../components/Icon.svelte';

  /** @type {{ rubrique: string, id: string }} */
  let { rubrique, id } = $props();

  // La fiche est recréée à chaque changement de rubrique ou d'objet : seuls les props de départ comptent.
  const depart = untrack(() => ({ rubrique, id }));
  const nouveau = depart.id === 'nouveau';
  const idNum = nouveau ? null : Number(depart.id);
  const R = RUBRIQUES[depart.rubrique] ?? RUBRIQUES.cuvees;
  const objet = $derived(
    idNum === null
      ? null
      : depart.rubrique === 'appellations'
        ? catalogue.appellation(idNum)
        : depart.rubrique === 'domaines'
          ? catalogue.domaine(idNum)
          : catalogue.cuvee(idNum),
  );
  const CREE = { appellations: 'Appellation « {} » créée', domaines: 'Domaine « {} » créé', cuvees: 'Cuvée « {} » créée' };
  const LIBELLE_CREER = { appellations: 'Créer l’appellation', domaines: 'Créer le domaine', cuvees: 'Créer la cuvée' };
  const NOM_VIDE = { appellations: 'Nom de l’appellation', domaines: 'Nom du domaine', cuvees: 'Nom de la cuvée' };

  // --- Champs ---------------------------------------------------------------------
  function depuisObjet() {
    const o = untrack(() => objet);
    const d = o?.domaine_id ? catalogue.domaine(o.domaine_id) : null;
    const a = o?.appellation_id ? catalogue.appellation(o.appellation_id) : null;
    return {
      nom: o?.nom ?? '',
      region: o?.region ?? '',
      description: o?.description ?? '',
      couleur: o?.couleur ?? 1,
      domaineId: d ? d.id : null,
      texteDomaine: d?.nom ?? '',
      appellationId: a ? a.id : o ? 0 : null,
      texteAppellation: a?.nom ?? '',
      fraisDom: false,
      fraisApp: false,
    };
  }

  // Retour d'une création lancée d'ici (domaine ou appellation d'une cuvée) : brouillon repris.
  const repris = creation.reprendre();
  const init = repris ? { ...repris.cadre.brouillon } : depuisObjet();
  if (repris) {
    const { cadre, resultat } = repris;
    const k = cadre.champ === 'dom' ? 'Domaine' : 'Appellation';
    init[`${k[0].toLowerCase() + k.slice(1)}Id`] = resultat ? resultat.id : null;
    init[`texte${k}`] = resultat ? resultat.nom : cadre.q;
    init[cadre.champ === 'dom' ? 'fraisDom' : 'fraisApp'] = !!resultat;
  } else if (nouveau) {
    init.nom = creation.cadre()?.q ?? '';
  }

  let nom = $state(init.nom);
  let region = $state(init.region);
  let description = $state(init.description);
  let couleur = $state(init.couleur);
  let domaineId = $state(/** @type {number|null} */ (init.domaineId));
  let texteDomaine = $state(init.texteDomaine);
  let appellationId = $state(/** @type {number|null} */ (init.appellationId));
  let texteAppellation = $state(init.texteAppellation);
  let fraisDom = $state(init.fraisDom);
  let fraisApp = $state(init.fraisApp);
  let image = $state(/** @type {string|null|undefined} */ (undefined));
  let erreur = $state('');
  let erreurDom = $state('');
  let erreurApp = $state('');
  let refus = $state('');
  let confirmation = $state(false);
  let enCours = $state(false);

  function reinitialiser() {
    const v = depuisObjet();
    nom = v.nom;
    region = v.region;
    description = v.description;
    couleur = v.couleur;
    domaineId = v.domaineId;
    texteDomaine = v.texteDomaine;
    appellationId = v.appellationId;
    texteAppellation = v.texteAppellation;
    fraisDom = fraisApp = false;
    image = undefined;
    erreur = erreurDom = erreurApp = refus = '';
  }

  // --- Vues ---------------------------------------------------------------------
  /** Cadre de la création en cascade qui a ouvert cet écran (sinon null). */
  const cadre = $derived(nouveau ? creation.cadre() : null);
  const fil = $derived(cadre ? [...creation.pile.map((f) => f.fil), R.nouvelle] : []);
  const liees = $derived(nouveau || rubrique === 'cuvees' ? [] : cuveesLiees(rubrique, /** @type {number} */ (idNum), cave.enStock));
  const bouteillesEnCave = $derived(liees.reduce((s, l) => s + l.qte, 0));
  const cuveesEnCave = $derived(new Set(liees.map((l) => l.cuvee)).size);
  const principale = $derived(rubrique === 'domaines' && idNum ? appellationPrincipale(idNum) : null);
  const titre = $derived(nouveau ? R.nouvelle : nom.trim() || objet?.nom || '');
  const sous = $derived(nouveau ? '' : sousLigne(rubrique, objet));
  const libelleEnregistrer = $derived(nouveau ? (cadre ? `Créer et revenir à ${cadre.libelle}` : LIBELLE_CREER[rubrique]) : 'Enregistrer');
  const libelleRetour = $derived(cadre ? `Revenir à ${cadre.libelle}` : 'Annuler');
  const blasonRegion = $derived(blason(region));
  const optDomaines = $derived.by(() => {
    catalogue.cuvees;
    return elements('domaines');
  });
  const optApps = $derived.by(() => {
    catalogue.cuvees;
    return elements('appellations');
  });

  // --- Actions ------------------------------------------------------------------
  function donnees() {
    if (rubrique === 'appellations') {
      const d = { nom: nom.trim(), region: region.trim(), description: description.trim() };
      if (image !== undefined) d.image = image;
      return d;
    }
    if (rubrique === 'domaines') return { nom: nom.trim(), description: description.trim() };
    return { nom: nom.trim(), domaine_id: domaineId, appellation_id: appellationId ?? 0, couleur, description: description.trim() };
  }

  function valider() {
    erreur = erreurDom = erreurApp = '';
    const n = nom.trim();
    if (!n) erreur = 'Le nom est obligatoire';
    else if (rubrique !== 'cuvees') {
      const liste = rubrique === 'domaines' ? catalogue.domaines : catalogue.appellations;
      if (liste.some((x) => x.id !== idNum && x.nom.trim().toLowerCase() === n.toLowerCase())) {
        erreur = rubrique === 'domaines' ? 'Ce domaine existe déjà' : 'Cette appellation existe déjà';
      }
    }
    if (rubrique === 'cuvees') {
      if (!domaineId) erreurDom = 'Choisissez ou créez un domaine';
      if (texteAppellation.trim() && !appellationId) erreurApp = 'Choisissez ou créez une appellation';
      if (!texteAppellation.trim()) appellationId = 0;
    }
    return !erreur && !erreurDom && !erreurApp;
  }

  async function enregistrer() {
    if (enCours || !valider()) return;
    enCours = true;
    try {
      const o = await catalogue.enregistrer(rubrique, idNum, donnees());
      image = undefined;
      if (nouveau) {
        toast.afficher(CREE[rubrique].replace('{}', o.nom));
        if (cadre) creation.terminer({ id: o.id, nom: o.nom });
        else if (ctx.ordinateur) routeur.aller(`/catalogue/${rubrique}/${o.id}`, { remplacer: true });
        else routeur.retour(`/catalogue/${rubrique}`);
      } else {
        toast.afficher('Fiche enregistrée');
        if (!ctx.ordinateur) routeur.retour(`/catalogue/${rubrique}`);
      }
    } catch (e) {
      erreur = e instanceof ErreurApi ? e.message : 'Enregistrement impossible';
    } finally {
      enCours = false;
    }
  }

  /** Annuler : retour à l'objet d'origine (champ repris tel que tapé), ou à la liste. */
  function annuler() {
    if (cadre) creation.terminer(null);
    else if (nouveau) routeur.retour(`/catalogue/${rubrique}`);
    else reinitialiser();
  }

  /** Domaine ou appellation introuvable : écran de création, puis retour à cette cuvée. */
  function creerDepuisCuvee(champ, texte) {
    const n = nom.trim();
    creation.lancer({
      champ,
      q: texte,
      libelle: n ? `la cuvée « ${n} »` : 'la cuvée',
      fil: (nouveau ? 'Nouvelle cuvée' : 'Cuvée') + (n ? ` « ${n} »` : ''),
      brouillon: {
        nom,
        region,
        description,
        couleur,
        domaineId: champ === 'dom' ? null : domaineId,
        texteDomaine,
        appellationId: champ === 'app' ? null : appellationId,
        texteAppellation,
        fraisDom,
        fraisApp,
      },
    });
  }

  /** Bouteilles, en stock ou consommées, rattachées à la fiche (directement ou par une cuvée). */
  function bouteillesRattachees() {
    const cuvees = new Set(
      rubrique === 'cuvees'
        ? [idNum]
        : catalogue.cuvees.filter((c) => (rubrique === 'appellations' ? c.appellation_id === idNum : c.domaine_id === idNum)).map((c) => c.id),
    );
    return [...cave.brutes, ...(cave.consommeesBrutes ?? [])].filter((b) => cuvees.has(b.cuvee_id)).length;
  }

  async function demanderSuppression() {
    refus = '';
    try {
      if (!cave.consommeesBrutes) await cave.chargerConsommees();
    } catch (e) {
      toast.afficher(e.message);
      return;
    }
    if (bouteillesRattachees()) refus = 'Suppression impossible : des bouteilles en stock ou consommées sont associées à cette fiche.';
    else confirmation = true;
  }

  async function supprimer() {
    confirmation = false;
    const n = objet?.nom ?? nom;
    try {
      await catalogue.supprimer(rubrique, /** @type {number} */ (idNum));
      toast.afficher(`« ${n} » supprimé du catalogue`);
      if (ctx.ordinateur) routeur.aller(`/catalogue/${rubrique}`, { remplacer: true });
      else routeur.retour(`/catalogue/${rubrique}`);
    } catch (e) {
      // Des cuvées sans bouteille utilisent encore la fiche : le téléphone refuse.
      if (e instanceof ErreurApi && e.code === 'referencee') refus = `Suppression impossible : ${messageRefus(rubrique, e.donnees.nombre ?? 1)}. Modifiez-les ou supprimez-les d'abord.`;
      else toast.afficher(e.message);
    }
  }

  /** Question préparée pour l'assistant ; null sans nom. */
  function question() {
    const n = nom.trim() || (nouveau ? '' : (objet?.nom ?? ''));
    if (!n) return null;
    if (rubrique === 'appellations') return questionAppellation(n);
    if (rubrique === 'domaines') return questionDomaine(n);
    return questionCuvee(n, domaineId ? catalogue.domaine(domaineId)?.nom : undefined, appellationId ? catalogue.appellation(appellationId)?.nom : undefined, couleur ? vin(couleur).libelle : undefined);
  }

  function clavier(e) {
    if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
      e.preventDefault();
      enregistrer();
    }
  }

  const GENRE = { appellations: ['cette appellation', 'retirée'], domaines: ['ce domaine', 'retiré'], cuvees: ['cette cuvée', 'retirée'] };
</script>

<svelte:window onkeydown={ctx.ordinateur ? clavier : undefined} />

{#snippet champNom()}
  <Field label="Nom" id="cat-nom" erreur={erreur}>
    <input id="cat-nom" class="champ" class:erreur={!!erreur} placeholder={NOM_VIDE[rubrique]} autocomplete="off" bind:value={nom} oninput={() => (erreur = '')} />
  </Field>
{/snippet}
{#snippet champDescription()}
  <Field label="Description" id="cat-desc">
    <textarea id="cat-desc" class="champ extensible" bind:value={description} use:autoHauteur={description}></textarea>
  </Field>
{/snippet}
{#snippet champRegion()}
  <Field label="Région" id="cat-region">
    <div class="region-champ" class:avec-blason={!!blasonRegion}>
      {#if blasonRegion}<img class="region-blason" src={blasonRegion} alt="" />{/if}
      <input id="cat-region" class="champ" list="regions" placeholder="Bourgogne, Loire…" bind:value={region} autocomplete="off" />
    </div>
    <datalist id="regions">
      {#each catalogue.regions as r (r)}<option value={r}></option>{/each}
    </datalist>
  </Field>
{/snippet}
{#snippet champsCuvee()}
  <Field label="Domaine" id="cat-dom" erreur={erreurDom}>
    <Autocomplete
      id="cat-dom"
      bind:valeur={texteDomaine}
      bind:choisi={domaineId}
      options={optDomaines}
      erreur={!!erreurDom}
      placeholder="Rechercher un domaine"
      onchoisir={() => {
        fraisDom = false;
        erreurDom = '';
      }}
      oncreer={(t) => creerDepuisCuvee('dom', t)}
      libelleCreer={(t) => `Créer le domaine « ${t} »`}
      vide="Saisissez le nom d’un domaine"
      frais={fraisDom && domaineId ? 'Domaine créé à l’instant, rattaché à cette cuvée' : ''}
    />
  </Field>
  <Field label="Appellation" id="cat-app" erreur={erreurApp}>
    <Autocomplete
      id="cat-app"
      bind:valeur={texteAppellation}
      bind:choisi={appellationId}
      options={optApps}
      erreur={!!erreurApp}
      placeholder="Rechercher une appellation"
      onchoisir={() => {
        fraisApp = false;
        erreurApp = '';
      }}
      oncreer={(t) => creerDepuisCuvee('app', t)}
      libelleCreer={(t) => `Créer l’appellation « ${t} »`}
      vide="Saisissez le nom d’une appellation"
      frais={fraisApp && appellationId ? 'Appellation créée à l’instant, rattachée à cette cuvée' : ''}
    />
  </Field>
{/snippet}
{#snippet refusSuppression()}
  {#if refus}
    <div class="refus" role="alert">
      <Icon nom="info" taille={16} epaisseur={1.9} couleur="var(--wt-warn)" />
      <span>{refus}</span>
    </div>
  {/if}
{/snippet}
{#snippet filAriane()}
  <span class="fil">
    {#each fil as f, i (i)}
      <span class="f-elt" class:dernier={i === fil.length - 1}>{f}</span>
      {#if i < fil.length - 1}<span class="f-sep">›</span>{/if}
    {/each}
  </span>
{/snippet}
{#snippet sousTitre(classe)}
  {#if sous}
    <span class={classe}>{#if rubrique === 'appellations'}<Blason region={objet?.region} />{/if}{sous}</span>
  {/if}
{/snippet}
{#snippet listeLiees()}
  {#if !nouveau && rubrique !== 'cuvees'}
    {#if ctx.ordinateur}
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
    {:else if liees.length}
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
  {/if}
{/snippet}

{#if ctx.ordinateur}
  <div class="o-detail">
    {#if cadre}
      <div class="bandeau">
        {@render filAriane()}
        <button type="button" class="revenir" onclick={annuler}><Icon nom="flecheG" taille={14} epaisseur={2} />{libelleRetour}</button>
      </div>
    {/if}
    <div class="o-tete">
      <div class="o-titres">
        <span class="surtitre">{R.type}</span>
        <span class="o-nom">{titre}</span>
        {@render sousTitre('o-sous')}
      </div>
      <div class="o-actions">
        <BoutonAssistant {question} />
        {#if !nouveau}
          <button type="button" class="corbeille" aria-label="Supprimer" onclick={demanderSuppression}><Icon nom="trash" taille={16} /></button>
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
      <div class="o-grille dom" class:seul={nouveau}>
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

    {@render listeLiees()}

    <div class="o-pied">
      <Button variante="primary" taille="ord-m" style="padding:0 16px" disabled={enCours} onclick={enregistrer}>{libelleEnregistrer}</Button>
      <Button taille="ord-m" style="font-weight:400" onclick={annuler}>Annuler</Button>
    </div>
  </div>
{:else}
  <div class="t-page">
    <EnTete onretour={() => (cadre ? creation.terminer(null) : routeur.retour(`/catalogue/${rubrique}`))}>
      {#snippet droite()}
        <BoutonAssistant {question}>
          <button type="button" class="t-action" disabled={enCours} onclick={enregistrer}>{nouveau ? 'Créer' : 'Enregistrer'}</button>
        </BoutonAssistant>
      {/snippet}
    </EnTete>
    {#if cadre}<div class="bandeau t">{@render filAriane()}</div>{/if}
    <div class="t-titres">
      <span class="surtitre t">{R.type}</span>
      <span class="t-nom">{titre}</span>
      {@render sousTitre('t-sous')}
    </div>

    {#if rubrique === 'appellations'}
      {@render champNom()}
      {@render champRegion()}
      {@render champDescription()}
      <ImageDrop urlActuelle={catalogue.urlImage(objet)} bind:image />
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

    {@render listeLiees()}

    {#if nouveau}
      <div class="t-creer">
        <button type="button" class="t-principal" disabled={enCours} onclick={enregistrer}>{libelleEnregistrer}</button>
        <button type="button" class="t-second" onclick={annuler}>{libelleRetour}</button>
      </div>
    {:else}
      <button type="button" class="t-supprimer" onclick={demanderSuppression}>Supprimer</button>
    {/if}
    {@render refusSuppression()}
  </div>
{/if}

{#if confirmation}
  {#if ctx.ordinateur}
    <Confirmation
      titre="Supprimer {GENRE[rubrique][0]} ?"
      texte="« {objet?.nom ?? nom} » sera {GENRE[rubrique][1]} du catalogue. Aucune bouteille, en stock ou consommée, n'y est associée."
      action="Supprimer"
      onconfirmer={supprimer}
      onfermer={() => (confirmation = false)}
    />
  {:else}
    <Confirmation
      titre="Supprimer « {objet?.nom ?? nom} » ?"
      texte="La fiche est retirée du catalogue. Cette action est irréversible."
      action="Supprimer"
      empile
      onconfirmer={supprimer}
      onfermer={() => (confirmation = false)}
    />
  {/if}
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
  /* Création en cascade : fil d'Ariane */
  .bandeau {
    display: flex;
    align-items: center;
    gap: 12px;
    flex-wrap: wrap;
    background: var(--wt-accent-tint);
    border-radius: 10px;
    padding: 8px 8px 8px 12px;
    font-size: 13px;
  }
  .bandeau.t {
    border-radius: 14px;
    padding: 10px 14px;
    font-size: 13.5px;
    margin-top: -4px;
  }
  .fil {
    display: flex;
    align-items: center;
    flex-wrap: wrap;
    gap: 4px 6px;
    flex: 1;
    min-width: 0;
  }
  .f-elt {
    color: var(--wt-ink2);
  }
  .f-elt.dernier {
    color: var(--wt-ink);
    font-weight: 600;
  }
  .f-sep {
    color: var(--wt-ink3);
  }
  .revenir {
    height: 30px;
    flex: none;
    border-radius: 8px;
    border: 1px solid var(--wt-line2);
    background: var(--wt-card);
    color: var(--wt-ink);
    padding: 0 10px;
    font-size: 13px;
    font-weight: 600;
    display: flex;
    align-items: center;
    gap: 6px;
  }
  /* Région : blason à gauche du texte */
  .region-champ {
    position: relative;
    display: flex;
    align-items: center;
  }
  .region-blason {
    position: absolute;
    left: 10px;
    width: 15px;
    height: 18px;
    pointer-events: none;
  }
  .avec-blason .champ {
    padding-left: 32px;
  }
  :global(.telephone) .region-blason {
    left: 14px;
    width: 17px;
    height: 20px;
  }
  :global(.telephone) .avec-blason .champ {
    padding-left: 40px;
  }
  .o-sous,
  .t-sous {
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .o-grille.dom.seul {
    grid-template-columns: minmax(0, 1fr);
  }
  /* Téléphone : barre du haut et boutons du bas */
  .t-action {
    height: 44px;
    border: 0;
    background: transparent;
    color: var(--wt-accent-ink);
    font-size: 16px;
    font-weight: 600;
    padding: 0 12px;
  }
  .t-action:disabled {
    opacity: 0.5;
  }
  .t-creer {
    display: flex;
    flex-direction: column;
    gap: 8px;
    margin-top: 4px;
  }
  .t-principal {
    min-height: 52px;
    border-radius: 14px;
    border: 0;
    background: var(--wt-accent);
    color: var(--wt-on-accent);
    font-size: 16px;
    font-weight: 600;
    padding: 8px 16px;
  }
  .t-principal:disabled {
    opacity: 0.5;
  }
  .t-second {
    height: 48px;
    border-radius: 14px;
    border: 1px solid var(--wt-line2);
    background: var(--wt-card);
    color: var(--wt-ink);
    font-size: 15px;
    font-weight: 600;
  }
  .t-supprimer {
    height: 48px;
    border: 0;
    background: transparent;
    color: var(--wt-danger);
    font-size: 15px;
    font-weight: 600;
  }
</style>
