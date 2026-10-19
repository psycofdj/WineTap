<script>
  // E-05 — Entrer en stock (téléphone) ; sert aussi à modifier une bouteille.
  import { routeur } from '../../lib/routeur.svelte.js';
  import { cave } from '../../lib/stores/cave.svelte.js';
  import { FormulaireBouteille } from '../../lib/formulaire.svelte.js';
  import { creation } from '../../lib/stores/creation.svelte.js';
  import { normaliserTag } from '../../lib/format.js';
  import EnTete from '../../components/EnTete.svelte';
  import Field from '../../components/Field.svelte';
  import Autocomplete from '../../components/Autocomplete.svelte';
  import TagField from '../../components/TagField.svelte';
  import WineGlass from '../../components/WineGlass.svelte';
  import Button from '../../components/Button.svelte';

  const f = new FormulaireBouteille();
  const q = routeur.query;
  // Retour de la création d'une cuvée lancée d'ici : le brouillon est repris.
  const repris = creation.reprendre();
  if (repris) f.reprendre(repris.cadre.brouillon, repris.cadre, repris.resultat);
  else if (q.modifier && cave.parId(Number(q.modifier))) f.modifier(cave.parId(Number(q.modifier)));
  else f.nouvelle(q.modele ? cave.parId(Number(q.modele)) : null, q.tag ? normaliserTag(q.tag) : null);

  /** « Créer la cuvée … » : écran de création du catalogue, puis retour ici. */
  function creerCuvee(texte) {
    creation.lancer({
      champ: 'cuv',
      q: texte,
      libelle: 'la bouteille',
      fil: f.modification ? 'Bouteille' : 'Nouvelle bouteille',
      brouillon: { ...f.brouillon(), cuveeId: null, texteCuvee: texte },
    });
  }

  const sousTitre = $derived(f.modification ? '' : f.rang > 1 ? `${f.rang}e bouteille de la caisse` : 'Nouvelle bouteille');

  async function terminer() {
    if (await f.enregistrer(false)) routeur.retour('/inventaire');
  }
</script>

<div class="page">
  <EnTete titre={f.modification ? 'Modifier la bouteille' : 'Entrer en stock'} {sousTitre} retour="/inventaire" />

  <TagField bind:tagId={f.tagId} exclure={f.idModifie} erreur={f.erreurs.tag} />

  <div class="bloc">
    <Field label="Cuvée" id="t-cuvee" erreur={f.erreurs.cuvee}>
      <Autocomplete
        id="t-cuvee"
        bind:valeur={f.texteCuvee}
        bind:choisi={f.cuveeId}
        options={f.options}
        erreur={!!f.erreurs.cuvee}
        placeholder="Rechercher une cuvée"
        onchoisir={(o) => f.choisirCuvee(o.id)}
        oncreer={creerCuvee}
        libelleCreer={(t) => `Créer la cuvée « ${t} »`}
        vide="Saisissez le nom d’une cuvée"
        frais={f.cuveeFraiche && f.cuveeId ? 'Cuvée créée à l’instant' : ''}
      />
    </Field>
    {#if f.derive}
      <span class="derive"
        ><WineGlass couleur={f.derive.couleur} taille={16} style="color:var(--wt-ink)" />{[
          f.derive.libelle,
          f.derive.domaine,
          f.derive.appellation && f.derive.appellation + (f.derive.region ? ` (${f.derive.region})` : ''),
        ]
          .filter(Boolean)
          .join(' · ')}</span
      >
    {/if}
  </div>

  <div class="deux">
    <Field label="Millésime" id="t-mil" erreur={f.erreurs.millesime}>
      <input id="t-mil" class="champ" class:erreur={!!f.erreurs.millesime} inputmode="numeric" maxlength="4" bind:value={f.millesime} />
    </Field>
    <Field label="À boire avant" id="t-garde" erreur={f.erreurs.aBoireAvant}>
      <input id="t-garde" class="champ" class:erreur={!!f.erreurs.aBoireAvant} inputmode="numeric" maxlength="4" bind:value={f.aBoireAvant} />
    </Field>
  </div>

  <Field label="Prix d'achat" id="t-prix" facultatif erreur={f.erreurs.prix}>
    <div class="champ-unite">
      <input id="t-prix" class="champ" class:erreur={!!f.erreurs.prix} inputmode="decimal" bind:value={f.prix} />
      <span class="unite">€</span>
    </div>
  </Field>

  {#if f.modification}
    <Field label="Commentaire" id="t-com" facultatif>
      <textarea id="t-com" class="champ commentaire" rows="3" bind:value={f.commentaire}></textarea>
    </Field>
  {/if}

  <div class="boutons">
    {#if f.modification}
      <Button taille="tel-l" variante="primary" disabled={f.enCours} onclick={terminer}>Enregistrer</Button>
    {:else}
      <Button taille="tel-l" variante="primary" sousTitre="même cuvée, tag suivant" disabled={f.enCours} onclick={() => f.enregistrer(true)}
        >Enregistrer et continuer</Button
      >
      <Button taille="tel-m" disabled={f.enCours} onclick={terminer}>Enregistrer et terminer</Button>
    {/if}
  </div>
</div>

<style>
  .page {
    display: flex;
    flex-direction: column;
    padding: 0 20px 24px;
    gap: 14px;
  }
  .bloc {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  .derive {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 13px;
    color: var(--wt-ink2);
  }
  .deux {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
  }
  .commentaire {
    font-family: var(--font-serif);
    font-size: 18px !important;
    min-height: 0 !important;
  }
  .boutons {
    display: flex;
    flex-direction: column;
    gap: 10px;
    margin-top: 6px;
  }
</style>
