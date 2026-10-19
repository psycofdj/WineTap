<script>
  // E-01 — Accueil (téléphone). Pas de titre d'écran : le contenu commence directement.
  import { ctx } from '../../lib/contexte.svelte.js';
  import { routeur } from '../../lib/routeur.svelte.js';
  import { cave } from '../../lib/stores/cave.svelte.js';
  import { lecture } from '../../lib/stores/lecture.svelte.js';
  import { statistiques } from '../../lib/stats.js';
  import { teinteGraphique, vin } from '../../lib/vins.js';
  import { dateLongue, pluriel } from '../../lib/format.js';
  import Icon from '../../components/Icon.svelte';
  import WineGlass from '../../components/WineGlass.svelte';

  const s = $derived(statistiques(cave.enStock));

  let dernieres = $state(/** @type {any[]} */ ([]));
  $effect(() => {
    cave.brutes; // recharge après une consommation
    cave
      .degustations(0, 2)
      .then((r) => (dernieres = r.bouteilles))
      .catch(() => {});
  });

  const compte = (n) => (n ? pluriel(n, 'bouteille') : 'Aucune');
</script>

<div class="page">
  <button type="button" class="carte-stock" onclick={() => routeur.aller('/tableau-de-bord')}>
    <span class="ligne">
      <span class="total"><span class="chiffre">{s.total}</span><span class="lib">bouteilles en stock</span></span>
      <Icon nom="chevR" taille={20} couleur="var(--wt-ink3)" />
    </span>
    <span class="barre">
      {#each s.couleurs as c (c.code)}
        <span style:width="{c.pct}%" style:background={teinteGraphique(c.code)}></span>
      {/each}
    </span>
    <span class="legende">
      {#each s.couleurs as c (c.code)}
        <span><WineGlass couleur={c.code} taille={16} style="color:var(--wt-ink)" />{vin(c.code).libelle} <b>{c.n}</b></span>
      {/each}
    </span>
  </button>

  <div class="alertes">
    <button type="button" class="alerte warn" onclick={() => routeur.aller('/inventaire?filtre=garde')}>
      <span class="a-titre"><Icon nom="clock" taille={16} epaisseur={2} />À boire en {ctx.annee}</span>
      <span class="a-nb">{compte(s.annee.n)}</span>
    </button>
    <button type="button" class="alerte danger" onclick={() => routeur.aller('/inventaire?filtre=garde')}>
      <span class="a-titre"><Icon nom="alert" taille={16} epaisseur={2} />Garde dépassée</span>
      <span class="a-nb">{compte(s.depassee.n)}</span>
    </button>
  </div>

  <div class="gestes">
    {#if ctx.dansApplication}
      <button type="button" class="consommer" onclick={() => lecture.consommer()}>
        <Icon nom="wine" taille={30} epaisseur={1.6} />
        <span class="c-textes"><span class="c-titre">Consommer une bouteille</span><span class="c-sous">Présentez le tag au téléphone</span></span>
        <Icon nom="chevR" taille={20} />
      </button>
    {/if}
    <div class="tuiles" class:une={!ctx.dansApplication}>
      {#if ctx.dansApplication}
        <button type="button" class="tuile" onclick={() => lecture.identifier()}>
          <Icon nom="scan" taille={24} couleur="var(--wt-accent-ink)" />Identifier
        </button>
      {/if}
      <button type="button" class="tuile" onclick={() => routeur.aller('/entree')}>
        <Icon nom="plusC" taille={24} couleur="var(--wt-accent-ink)" />Entrer en stock
      </button>
    </div>
  </div>

  <section class="degustations">
    <div class="d-tete">
      <span class="d-titre">Dernières dégustations</span>
      <button type="button" class="tout" onclick={() => routeur.aller('/degustations')}>Tout voir</button>
    </div>
    {#each dernieres as t (t.id)}
      <div class="d-carte">
        <WineGlass couleur={t.couleur} taille={20} style="margin-top:2px;color:var(--wt-ink)" />
        <div class="d-textes">
          <span class="d-nom">{t.domaine?.nom} · {t.cuvee?.nom}</span>
          {#if t.commentaire}<span class="d-com">«&nbsp;{t.commentaire}&nbsp;»</span>{/if}
          <span class="d-date">{dateLongue(t.consommee_le)}</span>
        </div>
      </div>
    {:else}
      <p class="d-vide">Aucune dégustation pour l'instant.</p>
    {/each}
  </section>
</div>

<style>
  .page {
    padding: 8px 20px 28px;
    display: flex;
    flex-direction: column;
    gap: 18px;
  }
  .carte-stock {
    text-align: left;
    border: 1px solid var(--wt-line);
    background: var(--wt-card);
    border-radius: 18px;
    padding: 18px 18px 16px;
    display: flex;
    flex-direction: column;
    gap: 14px;
    color: var(--wt-ink);
    width: 100%;
  }
  .ligne {
    display: flex;
    align-items: flex-end;
    justify-content: space-between;
    width: 100%;
  }
  .total {
    display: flex;
    align-items: baseline;
    gap: 10px;
  }
  .chiffre {
    font-family: var(--font-serif);
    font-size: 56px;
    line-height: 0.9;
    font-weight: 500;
  }
  .lib {
    font-size: 15px;
    color: var(--wt-ink2);
  }
  .barre {
    display: flex;
    height: 10px;
    border-radius: 999px;
    overflow: hidden;
    gap: 2px;
    width: 100%;
    background: var(--wt-card);
  }
  .barre span {
    box-shadow: inset 0 0 0 1px rgba(42, 29, 21, 0.15);
  }
  .legende {
    display: flex;
    flex-wrap: wrap;
    gap: 6px 14px;
    font-size: 13px;
    color: var(--wt-ink2);
  }
  .legende > span {
    display: flex;
    align-items: center;
    gap: 4px;
  }
  .legende b {
    font-weight: 600;
    color: var(--wt-ink);
  }
  .alertes {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 10px;
  }
  .alerte {
    border: 0;
    border-radius: 14px;
    padding: 12px 14px;
    text-align: left;
    display: flex;
    flex-direction: column;
    gap: 2px;
    min-height: 64px;
  }
  .alerte.warn {
    background: var(--wt-warn-tint);
    color: var(--wt-warn);
  }
  .alerte.danger {
    background: var(--wt-danger-tint);
    color: var(--wt-danger);
  }
  .a-titre {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 13px;
    font-weight: 600;
  }
  .a-nb {
    font-size: 15px;
    color: var(--wt-ink);
  }
  .gestes {
    display: flex;
    flex-direction: column;
    gap: 10px;
  }
  /* Téléphone en paysage : deux colonnes, pour que les gestes (« Consommer une bouteille »)
     restent visibles au-dessus de la barre d'onglets sans faire défiler. */
  @media (orientation: landscape) and (max-height: 499px) {
    .page {
      display: grid;
      grid-template-columns: minmax(0, 1fr) minmax(0, 1fr);
      align-items: start;
      gap: 14px 16px;
    }
    .carte-stock {
      grid-column: 1;
      grid-row: 1;
    }
    .alertes {
      grid-column: 1;
      grid-row: 2;
    }
    .gestes {
      grid-column: 2;
      grid-row: 1 / span 2;
    }
    .degustations {
      grid-column: 1 / -1;
    }
  }
  .consommer {
    border: 0;
    border-radius: 18px;
    background: var(--wt-accent);
    color: var(--wt-on-accent);
    min-height: 72px;
    padding: 0 20px;
    display: flex;
    align-items: center;
    gap: 14px;
    text-align: left;
    transition: transform var(--t-micro) var(--ease);
  }
  .consommer:active {
    transform: scale(0.98);
  }
  .c-textes {
    display: flex;
    flex-direction: column;
    flex: 1;
  }
  .c-titre {
    font-size: 18px;
    font-weight: 600;
  }
  .c-sous {
    font-size: 13px;
    opacity: 0.85;
  }
  .tuiles {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 10px;
  }
  .tuiles.une {
    grid-template-columns: 1fr;
  }
  .tuile {
    border: 1px solid var(--wt-line);
    border-radius: 16px;
    background: var(--wt-card);
    color: var(--wt-ink);
    min-height: 84px;
    padding: 14px;
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    justify-content: space-between;
    font-size: 15px;
    font-weight: 500;
    transition: transform var(--t-micro) var(--ease);
  }
  .tuile:active {
    transform: scale(0.98);
  }
  .degustations {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .d-tete {
    display: flex;
    justify-content: space-between;
    align-items: baseline;
  }
  .d-titre {
    font-family: var(--font-serif);
    font-size: 22px;
    font-weight: 500;
  }
  .tout {
    border: 0;
    background: transparent;
    color: var(--wt-accent-ink);
    font-size: 14px;
    font-weight: 600;
    padding: 8px 0;
  }
  .d-carte {
    background: var(--wt-card);
    border: 1px solid var(--wt-line);
    border-radius: 14px;
    padding: 12px 14px;
    display: flex;
    gap: 10px;
  }
  .d-textes {
    display: flex;
    flex-direction: column;
    gap: 2px;
    min-width: 0;
  }
  .d-nom {
    font-size: 15px;
    font-weight: 500;
  }
  .d-com {
    font-family: var(--font-serif);
    font-style: italic;
    font-size: 16px;
    color: var(--wt-ink2);
  }
  .d-date {
    font-size: 12px;
    color: var(--wt-ink3);
  }
  .d-vide {
    font-size: 15px;
    color: var(--wt-ink3);
  }
</style>
