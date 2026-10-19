<script>
  // Carte d'une appellation (D-20) : glisser-déposer, choix de fichier, collage Ctrl+V (événement paste).
  // `image` : undefined = inchangée, chaîne base64 = nouvelle image, null = retirée.
  import { ctx } from '../lib/contexte.svelte.js';
  import { enBase64 } from '../lib/api.js';
  import { toast } from '../lib/toast.svelte.js';
  import { choisirFichierNatif } from '../lib/sauvegarde.js';
  import Icon from './Icon.svelte';
  import Visionneuse from './Visionneuse.svelte';

  /** @type {{ urlActuelle?: string|null, image?: string|null|undefined }} */
  let { urlActuelle = null, image = $bindable(undefined) } = $props();

  let apercu = $state(/** @type {string|null} */ (null));
  let survol = $state(false);
  let entree = /** @type {HTMLInputElement} */ ($state());
  let agrandie = $state(false);

  const affichee = $derived(image === null ? null : image !== undefined ? apercu : urlActuelle);

  const COTE_MAX = 1600;

  /** Réduit les très grandes images, pour garder une base légère. */
  async function preparer(fichier) {
    const bmp = await createImageBitmap(fichier).catch(() => null);
    if (!bmp || (bmp.width <= COTE_MAX && bmp.height <= COTE_MAX)) {
      bmp?.close();
      return fichier;
    }
    const r = COTE_MAX / Math.max(bmp.width, bmp.height);
    const c = document.createElement('canvas');
    c.width = Math.round(bmp.width * r);
    c.height = Math.round(bmp.height * r);
    c.getContext('2d').drawImage(bmp, 0, 0, c.width, c.height);
    bmp.close();
    const type = fichier.type === 'image/png' ? 'image/png' : 'image/jpeg';
    return await new Promise((ok) => c.toBlob((b) => ok(b ?? fichier), type, 0.88));
  }

  async function prendre(fichier) {
    if (!fichier || !fichier.type.startsWith('image/')) {
      toast.afficher('Ce fichier n’est pas une image');
      return;
    }
    const pret = await preparer(fichier);
    image = await enBase64(pret);
    if (apercu) URL.revokeObjectURL(apercu);
    apercu = URL.createObjectURL(pret);
  }

  function coller(e) {
    const items = e.clipboardData?.items ?? [];
    for (const it of items) {
      if (it.kind === 'file' && it.type.startsWith('image/')) {
        e.preventDefault();
        prendre(it.getAsFile());
        return;
      }
    }
  }

  function deposer(e) {
    e.preventDefault();
    survol = false;
    prendre(e.dataTransfer?.files?.[0]);
  }

  /** Choix d'un fichier : sélecteur du système dans l'application, sinon celui du navigateur. */
  async function choisir() {
    if (ctx.pont?.pickFile) {
      const f = await choisirFichierNatif();
      if (f) prendre(f);
    } else {
      entree.click();
    }
  }

  /** Un clic sur la carte l'affiche en grand ; sur la zone vide, il ouvre le choix d'un fichier. */
  function cliquerZone() {
    if (affichee) agrandie = true;
    else choisir();
  }

  function retirer() {
    image = null;
    if (apercu) URL.revokeObjectURL(apercu);
    apercu = null;
  }
</script>

<svelte:window onpaste={coller} />

<input bind:this={entree} type="file" accept="image/*" class="sr-only" tabindex="-1" onchange={(e) => prendre(e.currentTarget.files?.[0])} />

{#if ctx.ordinateur}
  <div class="o">
    <span class="label">Carte de l'appellation</span>
    <button
      type="button"
      class="zone o-zone"
      class:survol
      class:image={!!affichee}
      aria-label={affichee ? 'Agrandir la carte' : 'Choisir une image'}
      ondragover={(e) => {
        e.preventDefault();
        survol = true;
      }}
      ondragleave={() => (survol = false)}
      ondrop={deposer}
      onclick={cliquerZone}
    >
      {#if affichee}
        <img src={affichee} alt="Carte de l'appellation" />
      {:else}
        <span class="vide"><Icon nom="image" taille={28} epaisseur={1.5} />Déposez une carte ou collez-la (Ctrl+V)</span>
      {/if}
    </button>
    <div class="o-boutons">
      <button type="button" class="o-btn principal" onclick={choisir}><Icon nom="upload" taille={14} />Choisir un fichier</button>
      <button type="button" class="o-btn" disabled={!affichee} onclick={retirer}>Retirer</button>
    </div>
    <span class="aide">Une carte qui situe l'appellation dans sa région. PNG ou JPEG.</span>
  </div>
{:else}
  <div class="t">
    <span class="t-label">Carte de l'appellation</span>
    <button type="button" class="zone t-zone" class:image={!!affichee} aria-label={affichee ? 'Agrandir la carte' : 'Choisir une image'} onclick={cliquerZone}>
      {#if affichee}
        <img src={affichee} alt="Carte de l'appellation" />
      {:else}
        <span class="vide"><Icon nom="image" taille={32} epaisseur={1.5} />Touchez pour choisir une carte</span>
      {/if}
    </button>
    <div class="t-boutons">
      <button type="button" class="t-btn" onclick={choisir}><Icon nom="image" taille={18} />Choisir une image</button>
      <button type="button" class="t-btn retirer" disabled={!affichee} onclick={retirer}>Retirer</button>
    </div>
  </div>
{/if}

{#if agrandie && affichee}
  <Visionneuse src={affichee} alt="Carte de l'appellation" onfermer={() => (agrandie = false)} />
{/if}

<style>
  .zone.image {
    cursor: zoom-in;
  }
  .zone {
    display: block;
    padding: 0;
    overflow: hidden;
    background: var(--wt-paper);
    border: 1px solid var(--wt-line);
    color: var(--wt-ink3);
    transition: border-color var(--t-micro) var(--ease);
  }
  .zone img {
    width: 100%;
    height: 100%;
    object-fit: contain;
    display: block;
  }
  .vide {
    height: 100%;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 10px;
    padding: 20px;
    text-align: center;
    font-size: 13px;
  }
  .survol {
    border-color: var(--wt-accent);
    box-shadow: 0 0 0 3px var(--wt-accent-tint);
  }

  .o {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .label {
    font-size: 12.5px;
    font-weight: 600;
    color: var(--wt-ink2);
  }
  .o-zone {
    width: 300px;
    height: 300px;
    border-radius: 12px;
  }
  .o-boutons {
    display: flex;
    gap: 6px;
    width: 300px;
  }
  .o-btn {
    height: 32px;
    border-radius: 8px;
    border: 1px solid var(--wt-line2);
    background: var(--wt-card);
    color: var(--wt-ink2);
    padding: 0 10px;
    font-size: 13px;
  }
  .o-btn.principal {
    flex: 1;
    color: var(--wt-ink);
    font-weight: 500;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 6px;
  }
  .o-btn:disabled {
    opacity: 0.5;
  }
  .aide {
    font-size: 12px;
    color: var(--wt-ink3);
    max-width: 300px;
  }

  .t {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .t-label {
    font-size: 14px;
    font-weight: 600;
  }
  .t-zone {
    width: 100%;
    height: 260px;
    border-radius: var(--r-xl);
  }
  .t-boutons {
    display: grid;
    grid-template-columns: 1fr auto;
    gap: 8px;
  }
  .t-btn {
    height: 48px;
    border-radius: var(--r-lg);
    border: 1px solid var(--wt-line2);
    background: var(--wt-card);
    color: var(--wt-ink);
    font-size: 15px;
    font-weight: 600;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
  }
  .t-btn.retirer {
    color: var(--wt-ink2);
    font-weight: 400;
    padding: 0 16px;
  }
  .t-btn:disabled {
    opacity: 0.5;
  }
</style>
