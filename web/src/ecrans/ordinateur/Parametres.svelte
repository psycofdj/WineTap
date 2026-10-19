<script>
  // E-09 — Paramètres (ordinateur) : apparence, assistant IA, sauvegarde et restauration.
  import { ctx, choisirTheme } from '../../lib/contexte.svelte.js';
  import Interrupteur from '../../components/Interrupteur.svelte';
  import { reglages } from '../../lib/stores/reglages.svelte.js';
  import { Restauration } from '../../lib/stores/restauration.svelte.js';
  import { sauvegarder } from '../../lib/sauvegarde.js';
  import { toast } from '../../lib/toast.svelte.js';
  import { nomSauvegarde, pluriel } from '../../lib/format.js';
  import Icon from '../../components/Icon.svelte';
  import Button from '../../components/Button.svelte';

  const r = new Restauration();
  let entree = /** @type {HTMLInputElement} */ ($state());

  async function choisirAssistant(a) {
    try {
      await reglages.choisirAssistant(a);
    } catch (e) {
      toast.afficher(e.message);
    }
  }
</script>

<div class="page">
  <h1>Paramètres</h1>

  <section>
    <div class="s-tete">
      <span class="s-titre">Apparence</span>
      <span class="s-texte">Propre à ce navigateur.</span>
    </div>
    <div class="theme">
      <Interrupteur libelle="Thème sombre" actif={ctx.theme === 'sombre'} onchange={(v) => choisirTheme(v ? 'sombre' : 'clair')} />
      {#if ctx.choixTheme}
        <button type="button" class="lien" onclick={() => choisirTheme(null)}>Suivre le thème du système</button>
      {:else}
        <span class="note">Suit le thème du système</span>
      {/if}
    </div>
  </section>

  <section>
    <div class="s-tete">
      <span class="s-titre">Assistant IA</span>
      <span class="s-texte">Utilisé par «&nbsp;Demander à l'IA&nbsp;» dans le catalogue. Réglage commun à tous les navigateurs.</span>
    </div>
    <div class="radios" role="radiogroup" aria-label="Assistant IA">
      {#each [['claude', 'Claude'], ['chatgpt', 'ChatGPT']] as [cle, nom] (cle)}
        <button type="button" role="radio" aria-checked={reglages.assistant === cle} class="radio" onclick={() => choisirAssistant(cle)}>
          <span class="rond">{#if reglages.assistant === cle}<span class="point"></span>{/if}</span>{nom}
        </button>
      {/each}
    </div>
  </section>

  <section>
    <div class="s-tete">
      <span class="s-titre">Sauvegarde et restauration</span>
      <span class="s-texte">Le fichier contient toute la cave&nbsp;: catalogue, bouteilles, dégustations.</span>
    </div>
    <div class="rangee bord">
      <span class="r-textes"><span class="r-titre">Télécharger une sauvegarde</span><span class="r-sous">{nomSauvegarde()}</span></span>
      <Button taille="ord-m" icone="download" onclick={sauvegarder}>Télécharger</Button>
    </div>
    <div class="rangee">
      <span class="r-textes"><span class="r-titre">Restaurer une sauvegarde</span><span class="r-sous">Remplace toute la cave actuelle</span></span>
      <Button taille="ord-m" variante="danger" icone="upload" onclick={() => entree.click()}>Choisir un fichier</Button>
    </div>
    <input
      bind:this={entree}
      type="file"
      class="sr-only"
      tabindex="-1"
      onchange={(e) => {
        r.choisir(e.currentTarget.files?.[0]);
        e.currentTarget.value = '';
      }}
    />
    {#if r.etat === 'erreur'}
      <div class="alerte ligne">
        <Icon nom="alert" taille={18} epaisseur={1.9} couleur="var(--wt-danger)" style="margin-top:2px" />
        <span class="a-pile">
          <span class="a-titre">Fichier non reconnu</span>
          <span class="a-texte">«&nbsp;{r.fichier?.name}&nbsp;» n'est pas une sauvegarde WineTap. La cave n'a pas été modifiée.</span>
        </span>
      </div>
    {:else if r.etat === 'confirmation' || r.etat === 'en_cours'}
      <div class="alerte">
        <span class="a-titre">Remplacer toute la cave&nbsp;?</span>
        <span class="a-texte"
          >{[r.fichier?.name, r.enStockFichier !== null && pluriel(r.enStockFichier, 'bouteille') + ' en stock'].filter(Boolean).join(' · ')}. Les {pluriel(r.enStockActuel, 'bouteille')}
          actuelles et leur historique seront remplacés. Téléchargez d'abord une sauvegarde si besoin.</span
        >
        <div class="a-boutons">
          <Button taille="ord-s" variante="danger-plein" style="font-weight:600;padding:0 14px" disabled={r.etat === 'en_cours'} onclick={() => r.confirmer()}
            >Remplacer la cave</Button
          >
          <Button taille="ord-s" style="padding:0 14px" onclick={() => r.annuler()}>Annuler</Button>
        </div>
      </div>
    {/if}
  </section>
</div>

<style>
  .page {
    flex: 1;
    overflow: auto;
    padding: 20px 24px 24px;
    display: flex;
    flex-direction: column;
    gap: 18px;
    max-width: 760px;
  }
  h1 {
    font-family: var(--font-serif);
    font-size: 30px;
    font-weight: 500;
    letter-spacing: -0.01em;
  }
  section {
    border: 1px solid var(--wt-line);
    background: var(--wt-card);
    border-radius: 14px;
    padding: 18px 20px;
    display: flex;
    flex-direction: column;
    gap: 14px;
  }
  .s-tete {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .s-titre {
    font-family: var(--font-serif);
    font-size: 20px;
    font-weight: 500;
  }
  .s-texte {
    font-size: 13.5px;
    color: var(--wt-ink2);
  }
  .radios {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 10px;
  }
  .radio {
    height: 52px;
    border-radius: 10px;
    border: 1.5px solid var(--wt-line2);
    background: var(--wt-card);
    color: var(--wt-ink);
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 0 14px;
    font-size: 14.5px;
    font-weight: 500;
  }
  .rond {
    width: 18px;
    height: 18px;
    border-radius: 99px;
    border: 1.5px solid var(--wt-line2);
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .point {
    width: 10px;
    height: 10px;
    border-radius: 99px;
    background: var(--wt-accent);
  }
  .theme {
    display: flex;
    align-items: center;
    gap: 16px;
    margin-left: -8px;
  }
  .note {
    font-size: 13px;
    color: var(--wt-ink3);
  }
  .lien {
    border: 0;
    background: transparent;
    font-size: 13px;
    color: var(--wt-accent-ink);
    font-weight: 500;
    padding: 0;
  }
  .rangee {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 12px;
  }
  .rangee.bord {
    padding-bottom: 14px;
    border-bottom: 1px solid var(--wt-line);
  }
  .r-textes {
    display: flex;
    flex-direction: column;
  }
  .r-titre {
    font-size: 14.5px;
    font-weight: 500;
  }
  .r-sous {
    font-size: 13px;
    color: var(--wt-ink3);
  }
  .alerte {
    border-radius: 10px;
    background: var(--wt-danger-tint);
    padding: 14px 16px;
    display: flex;
    flex-direction: column;
    gap: 10px;
  }
  .alerte.ligne {
    flex-direction: row;
    align-items: flex-start;
  }
  .a-pile {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  .a-titre {
    font-size: 14.5px;
    font-weight: 600;
    color: var(--wt-danger);
  }
  .a-texte {
    font-size: 13.5px;
    color: var(--wt-ink);
  }
  .a-boutons {
    display: flex;
    gap: 8px;
  }
</style>
