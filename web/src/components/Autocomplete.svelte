<script>
  // Champ avec complétion. Clavier : ↑ ↓ Entrée Échap.
  import { simplifier } from '../lib/format.js';
  import Icon from './Icon.svelte';
  import WineGlass from './WineGlass.svelte';

  /**
   * @typedef {{ id: number, nom: string, sous?: string, couleur?: number }} Option
   * @type {{ valeur?: string, options: Option[], onchoisir: (o: Option) => void, oncreer?: (texte: string) => void,
   *   libelleCreer?: (texte: string) => string, placeholder?: string, id?: string, erreur?: boolean,
   *   max?: number, onsaisie?: (texte: string) => void, element?: HTMLInputElement }}
   */
  let {
    valeur = $bindable(''),
    options,
    onchoisir,
    oncreer,
    libelleCreer = (t) => `Créer « ${t} »`,
    placeholder = '',
    id,
    erreur = false,
    max = 6,
    onsaisie,
    element = $bindable(),
  } = $props();

  const idListe = `auto-${Math.random().toString(36).slice(2, 8)}`;
  let ouvert = $state(false);
  let actif = $state(0);

  const requete = $derived(simplifier(valeur.trim()));

  const correspondances = $derived.by(() => {
    if (!requete) return [];
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
  const peutCreer = $derived(!!oncreer && !!requete && !exacte);
  const nbChoix = $derived(correspondances.length + (peutCreer ? 1 : 0));
  const visible = $derived(ouvert && nbChoix > 0);

  /** Découpe le nom pour mettre en gras la partie saisie. */
  function decouper(nom) {
    const i = simplifier(nom).indexOf(requete);
    if (i < 0 || !requete) return [nom, '', ''];
    return [nom.slice(0, i), nom.slice(i, i + requete.length), nom.slice(i + requete.length)];
  }

  function choisir(o) {
    valeur = o.nom;
    ouvert = false;
    onchoisir(o);
  }

  function creer() {
    const t = valeur.trim();
    ouvert = false;
    oncreer?.(t);
  }

  function clavier(e) {
    if (!visible) {
      if (e.key === 'ArrowDown' && nbChoix) {
        ouvert = true;
        e.preventDefault();
      }
      return;
    }
    if (e.key === 'ArrowDown') {
      actif = (actif + 1) % nbChoix;
      e.preventDefault();
    } else if (e.key === 'ArrowUp') {
      actif = (actif - 1 + nbChoix) % nbChoix;
      e.preventDefault();
    } else if (e.key === 'Enter' && !(e.metaKey || e.ctrlKey)) {
      e.preventDefault();
      if (actif < correspondances.length) choisir(correspondances[actif]);
      else creer();
    } else if (e.key === 'Escape') {
      ouvert = false;
      e.stopPropagation();
    }
  }
</script>

<div class="auto">
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
    oninput={() => {
      ouvert = true;
      actif = 0;
      onsaisie?.(valeur);
    }}
    onfocus={() => (ouvert = true)}
    onblur={() => (ouvert = false)}
    onkeydown={clavier}
  />
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
          onmousedown={(e) => e.preventDefault()}
          onclick={() => choisir(o)}
          onmouseenter={() => (actif = i)}
        >
          <span class="nom">
            {#if o.couleur !== undefined}<WineGlass couleur={o.couleur} taille={16} />{/if}
            <span>{a}<b>{b}</b>{c}</span>
          </span>
          {#if o.sous}<span class="sous">{o.sous}</span>{/if}
        </button>
      {/each}
      {#if peutCreer}
        <button
          type="button"
          role="option"
          aria-selected={actif === correspondances.length}
          class="option creer"
          class:actif={actif === correspondances.length}
          onmousedown={(e) => e.preventDefault()}
          onclick={creer}
          onmouseenter={() => (actif = correspondances.length)}
        >
          <Icon nom="plus" taille={14} epaisseur={2} />{libelleCreer(valeur.trim())}
        </button>
      {/if}
    </div>
  {/if}
</div>

<style>
  .auto {
    position: relative;
  }
  .liste {
    position: absolute;
    z-index: 20;
    top: calc(100% + 5px);
    left: 0;
    right: 0;
    border: 1px solid var(--wt-line2);
    border-radius: 10px;
    background: var(--wt-card);
    box-shadow: var(--wt-shadow);
    overflow: hidden;
    font-size: 13.5px;
    animation: entree var(--t-base) var(--ease);
  }
  .option {
    width: 100%;
    border: 0;
    border-top: 1px solid var(--wt-line);
    background: transparent;
    text-align: left;
    padding: 8px 10px;
    display: flex;
    flex-direction: column;
    color: var(--wt-ink);
  }
  .option:first-child {
    border-top: 0;
  }
  .option.actif {
    background: var(--wt-accent-tint);
  }
  .nom {
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .nom b {
    font-weight: 600;
  }
  .sous {
    font-size: 12px;
    color: var(--wt-ink2);
  }
  .creer {
    flex-direction: row;
    align-items: center;
    gap: 6px;
    color: var(--wt-accent-ink);
    font-weight: 600;
  }

  :global(.telephone) .liste {
    border-radius: 14px;
    font-size: 16px;
  }
  :global(.telephone) .option {
    padding: 12px 14px;
    min-height: 48px;
  }
  :global(.telephone) .sous {
    font-size: 13px;
  }

  @keyframes entree {
    from {
      opacity: 0;
      transform: translateY(-4px);
    }
  }
</style>
