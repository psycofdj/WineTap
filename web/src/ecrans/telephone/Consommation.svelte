<script>
  // E-02 — Résultat d'une lecture sur le téléphone : bouteille consommée, tag inconnu, déjà consommée.
  import { routeur } from '../../lib/routeur.svelte.js';
  import { cave } from '../../lib/stores/cave.svelte.js';
  import { lecture } from '../../lib/stores/lecture.svelte.js';
  import { toast } from '../../lib/toast.svelte.js';
  import { resteEnCave } from '../../lib/groupes.js';
  import { vin } from '../../lib/vins.js';
  import { dateLongue, millesime, pluriel } from '../../lib/format.js';
  import Icon from '../../components/Icon.svelte';
  import WineGlass from '../../components/WineGlass.svelte';
  import StatusPill from '../../components/StatusPill.svelte';
  import Button from '../../components/Button.svelte';

  let commentaireOuvert = $state(false);
  let commentaire = $state('');
  const b = $derived(lecture.bouteille);
  const reste = $derived(b ? resteEnCave(cave.enStock, b) : 0);

  function terminer() {
    routeur.aller('/accueil', { remplacer: true });
  }

  async function enregistrer() {
    if (!commentaire.trim()) {
      commentaireOuvert = false;
      return;
    }
    try {
      await cave.commenter(b.id, commentaire.trim());
      lecture.commentaireEnregistre = true;
      commentaireOuvert = false;
      toast.afficher('Commentaire enregistré');
    } catch (e) {
      toast.afficher(e.message);
    }
  }
</script>

<div class="page">
  <div class="haut">
    <button type="button" class="fermer" aria-label="Fermer" onclick={terminer}><Icon nom="x" taille={24} /></button>
  </div>

  {#if lecture.etat === 'ok' && b}
    <div class="tete">
      <StatusPill ton="ok" icone="check" taille={14} padding="6px 12px">Bouteille consommée</StatusPill>
      <div class="cuvee">{b.cuvee?.nom}</div>
      <div class="sous">{[b.domaine?.nom, b.appellation?.nom].filter(Boolean).join(' · ')}</div>
      <div class="meta"><span class="vin"><WineGlass couleur={b.couleur} taille={20} />{vin(b.couleur).libelle}</span><span>{millesime(b.millesime)}</span></div>
    </div>
    <div class="carte">
      <div><span class="lib">Reste en cave</span><span class="fort">{pluriel(reste, 'bouteille')}</span></div>
      <div><span class="lib">Tag libéré</span><span class="mono">{lecture.tag}</span></div>
    </div>
    {#if commentaireOuvert}
      <div class="commentaire">
        <label for="com">Commentaire de dégustation</label>
        <!-- svelte-ignore a11y_autofocus -->
        <textarea id="com" class="champ" rows="4" placeholder="Vos impressions…" bind:value={commentaire} autofocus></textarea>
      </div>
    {/if}
    <div class="espace"></div>
    <div class="boutons">
      {#if commentaireOuvert}
        <Button taille="tel-l" variante="primary" onclick={enregistrer}>Enregistrer le commentaire</Button>
        <Button taille="tel-m" variante="discret" onclick={terminer}>Plus tard</Button>
      {:else}
        {#if !lecture.commentaireEnregistre}
          <Button taille="tel-l" icone="msg" onclick={() => (commentaireOuvert = true)}>Ajouter un commentaire</Button>
        {/if}
        <Button taille="tel-l" variante="primary" onclick={terminer}>Terminé</Button>
      {/if}
    </div>
  {:else if lecture.etat === 'deja' && b}
    <div class="erreur">
      <span class="rond danger"><Icon nom="alert" taille={30} /></span>
      <div class="titre">Déjà consommée</div>
      <div class="texte">Cette bouteille est sortie du stock. Rien n'a été modifié.</div>
    </div>
    <div class="bouteille">
      <WineGlass couleur={b.couleur} taille={22} style="margin-top:2px" />
      <div class="b-textes">
        <span class="b-nom">{b.domaine?.nom} · {b.cuvee?.nom}</span>
        <span class="b-meta">{vin(b.couleur).libelle} · {millesime(b.millesime)}</span>
        <span class="b-date">Consommée le {dateLongue(b.consommee_le)}</span>
      </div>
    </div>
    <div class="espace"></div>
    <div class="boutons">
      <Button taille="tel-l" variante="primary" onclick={() => lecture.relancer()}>Lire un autre tag</Button>
      <Button taille="tel-l" onclick={() => routeur.aller('/degustations', { remplacer: true })}>Voir les dégustations</Button>
    </div>
  {:else}
    <div class="erreur">
      <span class="rond warn"><Icon nom="tag" taille={30} /></span>
      <div class="titre">Tag inconnu</div>
      <div class="texte">Ce tag n'est associé à aucune bouteille en stock.</div>
      <div class="puce mono">{lecture.tag}</div>
    </div>
    <div class="espace"></div>
    <div class="boutons">
      <Button taille="tel-l" variante="primary" onclick={() => lecture.relancer()}>Lire un autre tag</Button>
      <Button taille="tel-l" onclick={() => routeur.aller(`/entree?tag=${lecture.tag}`, { remplacer: true })}>Entrer une bouteille avec ce tag</Button>
    </div>
  {/if}
</div>

<style>
  .page {
    min-height: 100%;
    display: flex;
    flex-direction: column;
    padding: 4px 20px calc(28px + env(safe-area-inset-bottom));
    gap: 18px;
  }
  .haut {
    display: flex;
    justify-content: flex-end;
  }
  .fermer {
    width: 44px;
    height: 44px;
    border: 0;
    background: transparent;
    color: var(--wt-ink);
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 12px;
  }
  .tete {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: 10px;
  }
  .cuvee {
    font-family: var(--font-serif);
    font-size: 38px;
    font-weight: 500;
    line-height: 1.05;
  }
  .sous {
    font-size: 16px;
    color: var(--wt-ink2);
  }
  .meta {
    display: flex;
    gap: 16px;
    font-size: 15px;
    align-items: center;
  }
  .vin {
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .carte {
    background: var(--wt-card);
    border: 1px solid var(--wt-line);
    border-radius: 16px;
    display: flex;
    flex-direction: column;
  }
  .carte > div {
    display: flex;
    justify-content: space-between;
    padding: 14px 16px;
    font-size: 15px;
  }
  .carte > div:first-child {
    border-bottom: 1px solid var(--wt-line);
  }
  .lib {
    color: var(--wt-ink2);
  }
  .fort {
    font-weight: 600;
  }
  .commentaire {
    display: flex;
    flex-direction: column;
    gap: 10px;
  }
  .commentaire label {
    font-size: 14px;
    font-weight: 600;
  }
  .commentaire textarea {
    font-family: var(--font-serif);
    font-size: 18px;
    padding: 14px;
    resize: none;
    min-height: 0;
  }
  .espace {
    flex: 1;
  }
  .boutons {
    display: flex;
    flex-direction: column;
    gap: 10px;
  }
  .erreur {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: 12px;
  }
  .rond {
    width: 64px;
    height: 64px;
    border-radius: 999px;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .rond.warn {
    background: var(--wt-warn-tint);
    color: var(--wt-warn);
  }
  .rond.danger {
    background: var(--wt-danger-tint);
    color: var(--wt-danger);
  }
  .titre {
    font-family: var(--font-serif);
    font-size: 36px;
    font-weight: 500;
    line-height: 1.1;
  }
  .texte {
    font-size: 16px;
    color: var(--wt-ink2);
    text-wrap: pretty;
  }
  .puce {
    font-size: 16px;
    background: var(--wt-card2);
    border-radius: 8px;
    padding: 6px 10px;
    letter-spacing: 0.05em;
  }
  .bouteille {
    background: var(--wt-card);
    border: 1px solid var(--wt-line);
    border-radius: 16px;
    padding: 14px 16px;
    display: flex;
    gap: 12px;
    align-items: flex-start;
  }
  .b-textes {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .b-nom {
    font-size: 16px;
    font-weight: 500;
  }
  .b-meta {
    font-size: 14px;
    color: var(--wt-ink2);
  }
  .b-date {
    font-size: 14px;
    color: var(--wt-ink3);
  }
</style>
