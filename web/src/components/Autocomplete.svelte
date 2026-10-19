<script>
  // Champ à complétion (cuvée, domaine, appellation). Au focus, la liste montre les premières
  // entrées ; la saisie filtre sur le nom (sous-chaîne, sans casse ni accents). Dernière ligne :
  // « Créer … » si aucune entrée ne porte exactement ce nom.
  // Clavier (ordinateur) : ↑ ↓ option active, Entrée choisit ou crée, Échap ferme et rétablit.
  import { ctx } from '../lib/contexte.svelte.js';
  import { simplifier } from '../lib/format.js';
  import Icon from './Icon.svelte';
  import Blason from './Blason.svelte';

  /**
   * @typedef {{ id: number, nom: string, sous?: string, region?: string }} Option
   * @type {{ valeur?: string, choisi?: number|null, options: Option[], onchoisir?: (o: Option) => void,
   *   oncreer?: (texte: string) => void, libelleCreer?: (texte: string) => string, placeholder?: string,
   *   id?: string, erreur?: boolean, max?: number, vide?: string, frais?: string, element?: HTMLInputElement }}
   */
  let {
    valeur = $bindable(''),
    choisi = $bindable(null),
    options,
    onchoisir,
    oncreer,
    libelleCreer = (t) => `Créer « ${t} »`,
    placeholder = '',
    id,
    erreur = false,
    max = 6,
    vide = '',
    frais = '',
    element = $bindable(),
  } = $props();

  const idListe = `auto-${Math.random().toString(36).slice(2, 8)}`;
  let ouvert = $state(false);
  let actif = $state(0);
  /** La saisie a changé depuis le focus : on filtre. */
  let saisi = $state(false);
  let avant = { valeur: '', choisi: /** @type {number|null} */ (null) };

  const requete = $derived(simplifier(valeur.trim()));

  const correspondances = $derived.by(() => {
    if (!saisi || !requete) return options.slice(0, max);
    const debut = [];
    const dedans = [];
    for (const o of options) {
      const n = simplifier(o.nom);
      if (n.startsWith(requete)) debut.push(o);
      else if (n.includes(requete)) dedans.push(o);
    }
    return [...debut, ...dedans].slice(0, max);
  });

  const exacte = $derived(options.some((o) => simplifier(o.nom) === requete));
  const peutCreer = $derived(!!oncreer && saisi && !!requete && !exacte);
  const nbChoix = $derived(correspondances.length + (peutCreer ? 1 : 0));
  const aucun = $derived(nbChoix === 0 && !!vide);
  const visible = $derived(ouvert && (nbChoix > 0 || aucun));

  /** Découpe le nom pour mettre en gras la partie saisie. */
  function decouper(nom) {
    const i = saisi && requete ? simplifier(nom).indexOf(requete) : -1;
    if (i < 0) return [nom, '', ''];
    return [nom.slice(0, i), nom.slice(i, i + requete.length), nom.slice(i + requete.length)];
  }

  function choisir(o) {
    valeur = o.nom;
    choisi = o.id;
    ouvert = false;
    saisi = false;
    onchoisir?.(o);
  }

  function creer() {
    const t = valeur.trim();
    ouvert = false;
    oncreer?.(t);
  }

  function saisir() {
    ouvert = true;
    saisi = true;
    actif = 0;
    // Le texte ne correspond plus au choix : il est retiré.
    if (choisi !== null && choisi !== 0 && options.find((o) => o.id === choisi)?.nom !== valeur) choisi = null;
  }

  function clavier(e) {
    if (e.key === 'Escape') {
      if (!ouvert && valeur === avant.valeur) return;
      e.preventDefault();
      e.stopPropagation();
      valeur = avant.valeur;
      choisi = avant.choisi;
      ouvert = false;
      saisi = false;
      element?.blur();
      return;
    }
    if (!visible) {
      if (e.key === 'ArrowDown' && nbChoix) {
        ouvert = true;
        e.preventDefault();
      }
      return;
    }
    if (e.key === 'ArrowDown') {
      actif = Math.min(nbChoix - 1, actif + 1);
      e.preventDefault();
    } else if (e.key === 'ArrowUp') {
      actif = Math.max(0, actif - 1);
      e.preventDefault();
    } else if (e.key === 'Enter' && !(e.metaKey || e.ctrlKey)) {
      e.preventDefault();
      if (actif < correspondances.length) choisir(correspondances[actif]);
      else if (peutCreer) creer();
    }
  }
</script>

<div class="auto" class:ordinateur={ctx.ordinateur}>
  <input
    bind:this={element}
    {id}
    class="champ"
    class:erreur
    type="text"
    autocomplete="off"
    role="combobox"
    aria-expanded={visible}
    aria-controls={idListe}
    aria-autocomplete="list"
    {placeholder}
    bind:value={valeur}
    oninput={saisir}
    onfocus={() => {
      avant = { valeur, choisi };
      saisi = false;
      actif = 0;
      ouvert = true;
    }}
    onblur={() => {
      ouvert = false;
      saisi = false;
    }}
    onkeydown={clavier}
  />
  {#if frais}
    <span class="frais"><Icon nom="check" taille={ctx.ordinateur ? 14 : 16} epaisseur={2.2} />{frais}</span>
  {/if}
  {#if visible}
    <div class="liste" role="listbox" id={idListe}>
      {#each correspondances as o, i (o.id)}
        {@const [a, b, c] = decouper(o.nom)}
        <button
          type="button"
          role="option"
          aria-selected={i === actif}
          class="option"
          class:actif={i === actif}
          tabindex="-1"
          onmousedown={(e) => e.preventDefault()}
          onclick={() => choisir(o)}
          onmouseenter={() => (actif = i)}
        >
          <span class="nom">{a}<b>{b}</b>{c}</span>
          {#if o.sous}<span class="sous"><Blason region={o.region} largeur={11} hauteur={13} />{o.sous}</span>{/if}
        </button>
      {/each}
      {#if peutCreer}
        <button
          type="button"
          role="option"
          aria-selected={actif === correspondances.length}
          class="option creer"
          class:actif={actif === correspondances.length}
          tabindex="-1"
          onmousedown={(e) => e.preventDefault()}
          onclick={creer}
          onmouseenter={() => (actif = correspondances.length)}
        >
          <Icon nom="plus" taille={ctx.ordinateur ? 14 : 18} epaisseur={ctx.ordinateur ? 2 : 1.75} />{libelleCreer(valeur.trim())}
        </button>
      {/if}
      {#if aucun}
        <div class="option aucun">{vide}</div>
      {/if}
    </div>
  {/if}
</div>

<style>
  .auto {
    position: relative;
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  .frais {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 14px;
    color: var(--wt-ok);
  }
  .liste {
    border: 1px solid var(--wt-line2);
    border-radius: 14px;
    background: var(--wt-card);
    box-shadow: var(--wt-shadow);
    overflow: hidden;
    animation: entree var(--t-base) var(--ease);
  }
  .option {
    width: 100%;
    min-height: 52px;
    border: 0;
    border-top: 1px solid var(--wt-line);
    background: transparent;
    text-align: left;
    padding: 8px 14px;
    display: flex;
    flex-direction: column;
    justify-content: center;
    color: var(--wt-ink);
    font-size: 16px;
  }
  .option:first-child {
    border-top: 0;
  }
  .nom b {
    font-weight: 600;
  }
  .sous {
    display: flex;
    align-items: center;
    gap: 5px;
    font-size: 13px;
    color: var(--wt-ink2);
  }
  .creer {
    flex-direction: row;
    align-items: center;
    justify-content: flex-start;
    gap: 8px;
    padding: 0 14px;
    color: var(--wt-accent-ink);
    font-weight: 600;
  }
  .aucun {
    padding: 0 14px;
    color: var(--wt-ink3);
    font-size: 15px;
  }

  /* Ordinateur : liste par-dessus le formulaire, option active surlignée. */
  .ordinateur {
    gap: 5px;
  }
  .ordinateur .frais {
    font-size: 12.5px;
  }
  .ordinateur .liste {
    position: absolute;
    z-index: 20;
    top: calc(36px + 3px);
    left: 0;
    right: 0;
    border-radius: 10px;
    font-size: 13.5px;
  }
  .ordinateur .option {
    min-height: 0;
    padding: 8px 10px;
    font-size: 13.5px;
  }
  .ordinateur .option.actif {
    background: var(--wt-accent-tint);
  }
  .ordinateur .sous {
    font-size: 12px;
  }
  .ordinateur .creer {
    gap: 6px;
  }
  .ordinateur .aucun {
    font-size: 13.5px;
  }

  @keyframes entree {
    from {
      opacity: 0;
      transform: translateY(-4px);
    }
  }
</style>
