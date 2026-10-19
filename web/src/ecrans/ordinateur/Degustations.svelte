<script>
  // E-08 — Dégustations (ordinateur) : lignes en grille, édition sur place, pagination.
  import { onMount, tick } from 'svelte';
  import { Degustations } from '../../lib/stores/degustations.svelte.js';
  import { toast } from '../../lib/toast.svelte.js';
  import { dateLongue, millesime, pluriel } from '../../lib/format.js';
  import WineGlass from '../../components/WineGlass.svelte';
  import Blason from '../../components/Blason.svelte';
  import Icon from '../../components/Icon.svelte';

  const PAR_PAGE = 20;
  const d = new Degustations(PAR_PAGE);
  let edition = $state(/** @type {number|null} */ (null));
  let texte = $state('');
  let champ = /** @type {HTMLTextAreaElement} */ ($state());

  onMount(() => {
    d.page(0).catch((e) => toast.afficher(e.message));
  });

  async function modifier(b) {
    edition = b.id;
    texte = b.commentaire ?? '';
    await tick();
    champ?.focus();
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

  function clavier(e) {
    if (e.key === 'Escape') {
      e.preventDefault();
      edition = null;
    } else if (e.key === 'Enter' && (e.metaKey || e.ctrlKey || !e.shiftKey)) {
      e.preventDefault();
      enregistrer();
    }
  }

  const fin = $derived(Math.min(d.depuis + d.bouteilles.length, d.total));
</script>

<div class="page">
  <div class="titre">
    <h1>Dégustations</h1>
    <span class="resume">{pluriel(d.total, 'bouteille')} {d.total > 1 ? 'consommées' : 'consommée'} · de la plus récente à la plus ancienne</span>
  </div>
  <div class="carte">
    {#each d.bouteilles as b (b.id)}
      <div class="ligne">
        <span class="date tnum">{dateLongue(b.consommee_le)}</span>
        <WineGlass couleur={b.couleur} taille={20} style="margin-top:1px" />
        <div class="textes">
          <span class="nom"
            >{b.domaine?.nom} · {b.cuvee?.nom}
            <span class="meta"
              >· {b.appellation?.nom ?? 'Sans appellation'} · {millesime(b.millesime)}{#if b.region}<span class="meta-region"
                  >·<Blason region={b.region} largeur={12} hauteur={14} />{b.region}</span
                >{/if}</span
            ></span
          >
          {#if edition === b.id}
            <div class="edition">
              <textarea bind:this={champ} class="champ-edition" rows="2" bind:value={texte} onkeydown={clavier} aria-label="Commentaire"></textarea>
              <div class="e-boutons">
                <button type="button" class="enregistrer" onclick={enregistrer}>Enregistrer</button>
                <span class="echap">Échap pour annuler</span>
              </div>
            </div>
          {:else if b.commentaire}
            <span class="com">«&nbsp;{b.commentaire}&nbsp;»</span>
          {:else}
            <span class="sans">Pas de commentaire</span>
          {/if}
        </div>
        <button type="button" class="crayon" aria-label="Modifier le commentaire" onclick={() => modifier(b)}><Icon nom="pencil" taille={16} /></button>
      </div>
    {:else}
      {#if !d.chargement}<div class="vide">Aucune bouteille consommée pour l'instant.</div>{/if}
    {/each}
    {#if d.total > 0}
      <div class="pagination">
        <span>{d.depuis + 1}–{fin} sur {d.total}</span>
        <span class="p-boutons">
          <button type="button" disabled={d.depuis === 0} onclick={() => d.page(Math.max(0, d.depuis - PAR_PAGE))}>Précédent</button>
          <button type="button" disabled={fin >= d.total} onclick={() => d.page(d.depuis + PAR_PAGE)}>Suivant</button>
        </span>
      </div>
    {/if}
  </div>
</div>

<style>
  .page {
    flex: 1;
    overflow: auto;
    padding: 20px 24px 24px;
    display: flex;
    flex-direction: column;
    gap: 16px;
  }
  .titre {
    display: flex;
    align-items: baseline;
    gap: 12px;
    flex-wrap: wrap;
  }
  h1 {
    font-family: var(--font-serif);
    font-size: 30px;
    font-weight: 500;
    letter-spacing: -0.01em;
  }
  .resume {
    color: var(--wt-ink3);
  }
  .carte {
    border: 1px solid var(--wt-line);
    background: var(--wt-card);
    border-radius: 14px;
    overflow: hidden;
    max-width: 880px;
    /* Dans la colonne flex de .page, la carte rétrécirait à la hauteur de l'écran et
       couperait la liste (overflow: hidden) au lieu de laisser .page défiler. */
    flex-shrink: 0;
  }
  .ligne {
    display: grid;
    grid-template-columns: 110px 28px minmax(0, 1fr) auto;
    gap: 12px;
    align-items: start;
    padding: 14px 18px;
    border-bottom: 1px solid var(--wt-line);
  }
  .date {
    font-size: 13px;
    color: var(--wt-ink3);
    padding-top: 2px;
  }
  .textes {
    display: flex;
    flex-direction: column;
    gap: 4px;
    min-width: 0;
  }
  .nom {
    font-size: 14.5px;
    font-weight: 500;
  }
  .meta {
    color: var(--wt-ink3);
    font-weight: 400;
    display: inline-flex;
    align-items: center;
    gap: 5px;
    vertical-align: -2px;
  }
  .meta-region {
    display: inline-flex;
    align-items: center;
    gap: 5px;
  }
  .com {
    font-family: var(--font-serif);
    font-style: italic;
    font-size: 17px;
    color: var(--wt-ink2);
  }
  .sans {
    font-size: 13.5px;
    color: var(--wt-ink3);
  }
  .crayon {
    width: 32px;
    height: 32px;
    border-radius: 8px;
    border: 0;
    background: transparent;
    color: var(--wt-ink3);
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .crayon:hover {
    background: var(--wt-card2);
    color: var(--wt-ink);
  }
  .edition {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .champ-edition {
    min-height: 60px;
    border-radius: 8px;
    border: 1.5px solid var(--wt-accent);
    box-shadow: 0 0 0 3px var(--wt-accent-tint);
    padding: 8px 10px;
    font-family: var(--font-serif);
    font-size: 17px;
    background: var(--wt-card);
    color: var(--wt-ink);
    outline: none;
    resize: vertical;
  }
  .e-boutons {
    display: flex;
    gap: 8px;
    align-items: center;
  }
  .enregistrer {
    height: 30px;
    border-radius: 8px;
    border: 0;
    background: var(--wt-accent);
    color: var(--wt-on-accent);
    padding: 0 12px;
    font-size: 13px;
    font-weight: 600;
  }
  .echap {
    font-size: 12px;
    color: var(--wt-ink3);
  }
  .pagination {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 10px 18px;
    font-size: 13px;
    color: var(--wt-ink2);
  }
  .p-boutons {
    display: flex;
    gap: 6px;
  }
  .p-boutons button {
    height: 28px;
    padding: 0 10px;
    border-radius: 7px;
    border: 1px solid var(--wt-line2);
    background: var(--wt-card);
    color: var(--wt-ink);
    font-size: 13px;
  }
  .p-boutons button:disabled {
    color: var(--wt-ink3);
  }
  .vide {
    padding: 40px;
    text-align: center;
    color: var(--wt-ink3);
  }
</style>
