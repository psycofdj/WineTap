<script>
  // E-09 — Réglages (téléphone) : apparence, assistant IA, sauvegarde, accès depuis un ordinateur.
  import { ctx, choisirTheme } from '../../lib/contexte.svelte.js';
  import { reglages } from '../../lib/stores/reglages.svelte.js';
  import { Restauration } from '../../lib/stores/restauration.svelte.js';
  import { sauvegarder, choisirFichierNatif } from '../../lib/sauvegarde.js';
  import { toast } from '../../lib/toast.svelte.js';
  import { pluriel } from '../../lib/format.js';
  import Icon from '../../components/Icon.svelte';
  import Interrupteur from '../../components/Interrupteur.svelte';

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
  <section>
    <span class="groupe">Apparence</span>
    <div class="carte">
      <Interrupteur ligne libelle="Thème sombre" actif={ctx.theme === 'sombre'} onchange={(v) => choisirTheme(v ? 'sombre' : 'clair')} />
    </div>
    {#if ctx.choixTheme}
      <button type="button" class="note lien" onclick={() => choisirTheme(null)}>Suivre le thème du système</button>
    {:else}
      <span class="note">Suit le thème du système</span>
    {/if}
  </section>

  <section>
    <span class="groupe">Assistant IA</span>
    <div class="carte">
      <button type="button" class="ligne" onclick={() => choisirAssistant('claude')}>
        Claude{#if reglages.assistant === 'claude'}<Icon nom="check" taille={20} epaisseur={2.2} couleur="var(--wt-accent-ink)" />{/if}
      </button>
      <button type="button" class="ligne" onclick={() => choisirAssistant('chatgpt')}>
        ChatGPT{#if reglages.assistant === 'chatgpt'}<Icon nom="check" taille={20} epaisseur={2.2} couleur="var(--wt-accent-ink)" />{/if}
      </button>
    </div>
  </section>

  <section>
    <span class="groupe">Sauvegarde</span>
    <div class="carte">
      <button type="button" class="ligne haute" onclick={sauvegarder}>
        <Icon nom="download" taille={20} /><span class="texte">Enregistrer une sauvegarde</span>
      </button>
      <button
        type="button"
        class="ligne haute danger"
        onclick={async () => (ctx.pont?.pickFile ? r.choisir(await choisirFichierNatif()) : entree.click())}
      >
        <Icon nom="upload" taille={20} /><span class="texte">Restaurer une sauvegarde</span>
      </button>
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
      <div class="alerte">
        <span class="a-titre">Fichier non reconnu</span>
        <span class="a-texte">Ce fichier n'est pas une sauvegarde WineTap. La cave n'a pas été modifiée.</span>
      </div>
    {:else if r.etat === 'confirmation' || r.etat === 'en_cours'}
      <div class="alerte">
        <span class="a-titre">Remplacer toute la cave&nbsp;?</span>
        <span class="a-texte"
          >{[r.fichier?.name, r.enStockFichier !== null && pluriel(r.enStockFichier, 'bouteille')].filter(Boolean).join(' · ')}. Les {pluriel(r.enStockActuel, 'bouteille')} actuelles
          et leur historique seront remplacés.</span
        >
        <div class="a-boutons">
          <button type="button" class="a-annuler" onclick={() => r.annuler()}>Annuler</button>
          <button type="button" class="a-remplacer" disabled={r.etat === 'en_cours'} onclick={() => r.confirmer()}>Remplacer</button>
        </div>
      </div>
    {/if}
  </section>

  {#if ctx.dansApplication}
    <section>
      <span class="groupe">Accès depuis un ordinateur</span>
      <div class="carte">
        <button type="button" class="ligne haute" onclick={() => ctx.pont?.openNative?.('adresse')}>
          <Icon nom="monitor" taille={20} /><span class="texte">Adresse de connexion</span><Icon nom="chevR" taille={18} couleur="var(--wt-ink3)" />
        </button>
        <button type="button" class="ligne haute" onclick={() => ctx.pont?.openNative?.('connexions')}>
          <Icon nom="shield" taille={20} /><span class="texte">Connexions autorisées</span><span class="nb">{ctx.connexions}</span><Icon
            nom="chevR"
            taille={18}
            couleur="var(--wt-ink3)"
          />
        </button>
      </div>
    </section>
  {/if}
</div>

<style>
  .page {
    display: flex;
    flex-direction: column;
    padding: 12px 20px 24px;
    gap: 18px;
  }
  section {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .groupe {
    font-size: 12px;
    font-weight: 600;
    letter-spacing: 0.1em;
    text-transform: uppercase;
    color: var(--wt-ink3);
    padding: 0 4px;
  }
  .carte {
    background: var(--wt-card);
    border: 1px solid var(--wt-line);
    border-radius: 16px;
    overflow: hidden;
  }
  .ligne {
    width: 100%;
    min-height: 52px;
    border: 0;
    border-bottom: 1px solid var(--wt-line);
    background: transparent;
    color: var(--wt-ink);
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    padding: 0 16px;
    font-size: 16px;
    text-align: left;
  }
  .ligne:last-child {
    border-bottom: 0;
  }
  .ligne:active {
    background: var(--wt-card2);
  }
  .haute {
    min-height: 56px;
    justify-content: flex-start;
  }
  .texte {
    flex: 1;
  }
  .danger {
    color: var(--wt-danger);
  }
  .nb {
    color: var(--wt-ink3);
    font-size: 15px;
  }
  .note {
    font-size: 13px;
    color: var(--wt-ink3);
    padding: 0 4px;
    align-self: flex-start;
  }
  .lien {
    border: 0;
    background: transparent;
    color: var(--wt-accent-ink);
    font-weight: 500;
  }
  .alerte {
    background: var(--wt-danger-tint);
    border-radius: 16px;
    padding: 14px 16px;
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  .a-titre {
    font-size: 16px;
    font-weight: 600;
    color: var(--wt-danger);
  }
  .a-texte {
    font-size: 14px;
  }
  .a-boutons {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 8px;
    margin-top: 4px;
  }
  .a-annuler,
  .a-remplacer {
    height: 48px;
    border-radius: 12px;
    font-size: 15px;
    font-weight: 600;
  }
  .a-annuler {
    border: 1px solid var(--wt-line2);
    background: var(--wt-card);
    color: var(--wt-ink);
  }
  .a-remplacer {
    border: 0;
    background: var(--wt-danger);
    color: var(--wt-card);
  }
  .a-remplacer:disabled {
    opacity: 0.5;
  }
</style>
