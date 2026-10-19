<script>
  // E-08 — Dégustations (téléphone) : cartes du plus récent au plus ancien, chargées en défilant.
  import { onMount } from 'svelte';
  import { Degustations } from '../../lib/stores/degustations.svelte.js';
  import { toast } from '../../lib/toast.svelte.js';
  import { dateLongue, millesime } from '../../lib/format.js';
  import EnTete from '../../components/EnTete.svelte';
  import WineGlass from '../../components/WineGlass.svelte';
  import Blason from '../../components/Blason.svelte';
  import Icon from '../../components/Icon.svelte';
  import Button from '../../components/Button.svelte';

  const d = new Degustations(20);
  let edition = $state(/** @type {number|null} */ (null));
  let texte = $state('');
  let fin = /** @type {HTMLElement} */ ($state());

  onMount(() => {
    d.suite();
    const obs = new IntersectionObserver((e) => e[0].isIntersecting && d.suite(), { rootMargin: '300px' });
    obs.observe(fin);
    return () => obs.disconnect();
  });

  function modifier(b) {
    edition = b.id;
    texte = b.commentaire ?? '';
  }

  async function enregistrer() {
    try {
      await d.commenter(/** @type {number} */ (edition), texte.trim());
      edition = null;
      toast.afficher('Commentaire enregistré');
    } catch (e) {
      toast.afficher(e.message);
    }
  }
</script>

<div class="page">
  <EnTete titre="Dégustations" retour="/accueil" />
  {#each d.bouteilles as b (b.id)}
    <div class="carte">
      <div class="haut">
        <WineGlass couleur={b.couleur} taille={18} />
        <span class="date">{dateLongue(b.consommee_le)}</span>
        {#if edition !== b.id}
          <button type="button" class="crayon" aria-label="Modifier le commentaire" onclick={() => modifier(b)}><Icon nom="pencil" taille={17} /></button>
        {/if}
      </div>
      <span class="titre">{b.domaine?.nom} · {b.cuvee?.nom}</span>
      <span class="meta"
        >{b.appellation?.nom ?? 'Sans appellation'} · {millesime(b.millesime)}{#if b.region}<span class="meta-region"
            >·<Blason region={b.region} largeur={12} hauteur={14} />{b.region}</span
          >{/if}</span
      >
      {#if edition === b.id}
        <!-- svelte-ignore a11y_autofocus -->
        <textarea class="champ edition" rows="3" placeholder="Vos impressions…" bind:value={texte} autofocus></textarea>
        <div class="boutons">
          <Button taille="tel-s" onclick={() => (edition = null)}>Annuler</Button>
          <Button taille="tel-s" variante="primary" onclick={enregistrer}>Enregistrer</Button>
        </div>
      {:else if b.commentaire}
        <span class="com">«&nbsp;{b.commentaire}&nbsp;»</span>
      {/if}
    </div>
  {:else}
    {#if !d.chargement}<p class="vide">Aucune bouteille consommée pour l'instant.</p>{/if}
  {/each}
  <div bind:this={fin} class="fin"></div>
</div>

<style>
  .page {
    display: flex;
    flex-direction: column;
    padding: 0 20px 24px;
    gap: 12px;
  }
  .carte {
    background: var(--wt-card);
    border: 1px solid var(--wt-line);
    border-radius: 16px;
    padding: 14px 16px;
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  .haut {
    display: flex;
    align-items: center;
    gap: 8px;
    min-height: 20px;
  }
  .date {
    font-size: 12.5px;
    color: var(--wt-ink3);
    flex: 1;
  }
  .crayon {
    width: 36px;
    height: 36px;
    margin: -8px -8px -8px 0;
    border: 0;
    background: transparent;
    color: var(--wt-ink3);
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .titre {
    font-size: 16px;
    font-weight: 500;
  }
  .meta {
    font-size: 13px;
    color: var(--wt-ink2);
    display: flex;
    align-items: center;
    gap: 5px;
    flex-wrap: wrap;
  }
  .meta-region {
    display: inline-flex;
    align-items: center;
    gap: 5px;
  }
  .com {
    font-family: var(--font-serif);
    font-style: italic;
    font-size: 18px;
    color: var(--wt-ink2);
  }
  .edition {
    font-family: var(--font-serif);
    font-size: 18px !important;
    min-height: 0 !important;
    margin-top: 4px;
  }
  .boutons {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 8px;
  }
  .vide {
    color: var(--wt-ink3);
    padding: 24px 0;
    text-align: center;
  }
  .fin {
    height: 1px;
  }
</style>
