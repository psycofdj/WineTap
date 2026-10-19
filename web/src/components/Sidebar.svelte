<script>
  // Barre latérale de l'ordinateur (D-18) : Cave, Catalogue, Paramètres ; état du téléphone en bas.
  import { routeur } from '../lib/routeur.svelte.js';
  import { ctx } from '../lib/contexte.svelte.js';
  import { creation } from '../lib/stores/creation.svelte.js';
  import Icon from './Icon.svelte';

  const groupes = [
    {
      titre: 'Cave',
      elements: [
        { libelle: 'Tableau de bord', icone: 'pie', chemin: '/tableau-de-bord', actif: (s) => s[0] === 'tableau-de-bord' },
        { libelle: 'Inventaire', icone: 'list', chemin: '/inventaire', actif: (s) => s[0] === 'inventaire' || !s[0] },
        { libelle: 'Dégustations', icone: 'book', chemin: '/degustations', actif: (s) => s[0] === 'degustations' },
      ],
    },
    {
      titre: 'Catalogue',
      elements: [
        { libelle: 'Appellations', icone: 'grid', chemin: '/catalogue/appellations', actif: (s) => s[0] === 'catalogue' && s[1] === 'appellations' },
        { libelle: 'Domaines', icone: 'home', chemin: '/catalogue/domaines', actif: (s) => s[0] === 'catalogue' && s[1] === 'domaines' },
        { libelle: 'Cuvées', icone: 'wine', chemin: '/catalogue/cuvees', actif: (s) => s[0] === 'catalogue' && (s[1] === 'cuvees' || !s[1]) },
      ],
    },
    {
      titre: '',
      elements: [{ libelle: 'Paramètres', icone: 'sliders', chemin: '/parametres', actif: (s) => s[0] === 'parametres' }],
    },
  ];

  const ip = $derived((ctx.appareil.adresse || location.host).split(':')[0]);
</script>

<nav class="laterale no-print" aria-label="Navigation principale">
  <div class="marque">WineTap</div>
  {#each groupes as g, i (i)}
    <div class="groupe">
      {#if g.titre}<div class="titre">{g.titre}</div>{/if}
      {#each g.elements as e (e.chemin)}
        {@const on = e.actif(routeur.segments)}
        <button type="button" class="element" class:on aria-current={on ? 'page' : undefined} onclick={() => {
            creation.vider();
            routeur.aller(e.chemin);
          }}>
          <Icon nom={e.icone} taille={18} couleur={on ? 'var(--wt-accent-ink)' : 'var(--wt-ink3)'} />
          {e.libelle}
        </button>
      {/each}
    </div>
  {/each}
  <div class="espace"></div>
  <div class="etat" class:perdu={ctx.telephone !== 'joignable'}>
    <span class="point"></span>
    <span class="textes">
      <span class="t1">{ctx.telephone === 'joignable' ? 'Téléphone joignable' : 'Téléphone injoignable'}</span>
      <span class="t2">{ctx.appareil.nom || 'Téléphone'} · {ip}</span>
    </span>
  </div>
</nav>

<style>
  .laterale {
    width: 228px;
    flex: none;
    border-right: 1px solid var(--wt-line);
    display: flex;
    flex-direction: column;
    padding: 18px 12px 14px;
    gap: 18px;
    overflow-y: auto;
  }
  .marque {
    padding: 0 10px;
    font-family: var(--font-serif);
    font-size: 26px;
    font-weight: 600;
    letter-spacing: -0.01em;
    line-height: 1.2;
  }
  .groupe {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .titre {
    padding: 0 10px 6px;
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.1em;
    text-transform: uppercase;
    color: var(--wt-ink3);
  }
  .element {
    height: 36px;
    border-radius: 9px;
    border: 1px solid transparent;
    background: transparent;
    color: var(--wt-ink2);
    font-weight: 500;
    font-size: 14px;
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 0 10px;
    text-align: left;
    transition: background-color var(--t-micro) var(--ease);
  }
  .element:hover:not(.on) {
    background: var(--wt-card2);
  }
  .element.on {
    background: var(--wt-card);
    border-color: var(--wt-line);
    color: var(--wt-ink);
    font-weight: 600;
  }
  .espace {
    flex: 1;
  }
  .etat {
    border: 1px solid var(--wt-line);
    background: var(--wt-card);
    border-radius: 12px;
    padding: 10px 12px;
    display: flex;
    gap: 10px;
    align-items: center;
  }
  .point {
    width: 9px;
    height: 9px;
    border-radius: 99px;
    background: var(--wt-ok);
    box-shadow: 0 0 0 3px var(--wt-ok-tint);
    flex: none;
  }
  .perdu .point {
    background: var(--wt-danger);
    box-shadow: 0 0 0 3px var(--wt-danger-tint);
  }
  .textes {
    display: flex;
    flex-direction: column;
    min-width: 0;
  }
  .t1 {
    font-size: 13px;
    font-weight: 600;
  }
  .t2 {
    font-size: 12px;
    color: var(--wt-ink3);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
</style>
