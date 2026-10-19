// Formulaire de bouteille (E-05), commun au téléphone et à l'ordinateur.

import { ErreurApi } from './api.js';
import { ctx } from './contexte.svelte.js';
import { vin } from './vins.js';
import { catalogue } from './stores/catalogue.svelte.js';
import { cave } from './stores/cave.svelte.js';
import { toast } from './toast.svelte.js';

export class FormulaireBouteille {
  /** null = nouvelle bouteille */
  idModifie = $state(/** @type {number|null} */ (null));
  cuveeId = $state(/** @type {number|null} */ (null));
  texteCuvee = $state('');
  millesime = $state('');
  aBoireAvant = $state('');
  prix = $state('');
  commentaire = $state('');
  tagId = $state(/** @type {string|null} */ (null));
  /** Rang de la bouteille dans la saisie en cours (« Enregistrer et continuer ») */
  rang = $state(1);
  erreurs = $state(/** @type {Record<string,string>} */ ({}));
  enCours = $state(false);

  cuvee = $derived(this.cuveeId ? catalogue.cuvee(this.cuveeId) : null);

  /** Ligne dérivée sous le champ Cuvée : couleur · domaine · appellation (région). */
  derive = $derived.by(() => {
    const c = this.cuvee;
    if (!c) return null;
    const d = catalogue.domaine(c.domaine_id);
    const a = c.appellation_id ? catalogue.appellation(c.appellation_id) : null;
    return { couleur: c.couleur, libelle: vin(c.couleur).libelle, domaine: d?.nom ?? '', appellation: a?.nom ?? '', region: a?.region ?? '' };
  });

  /** Options de la complétion des cuvées. */
  options = $derived(
    catalogue.cuvees.map((c) => {
      const d = catalogue.domaine(c.domaine_id);
      const a = c.appellation_id ? catalogue.appellation(c.appellation_id) : null;
      return { id: c.id, nom: c.nom, couleur: c.couleur, sous: [d?.nom, a?.nom, vin(c.couleur).libelle].filter(Boolean).join(' · ') };
    }),
  );

  get modification() {
    return this.idModifie !== null;
  }

  /** Nouvelle bouteille, éventuellement sur le modèle d'une autre, éventuellement avec un tag déjà lu. */
  nouvelle(modele = null, tag = null) {
    this.idModifie = null;
    this.rang = 1;
    this.erreurs = {};
    this.commentaire = '';
    this.tagId = tag;
    if (modele) this.#remplir(modele);
    else {
      this.cuveeId = null;
      this.texteCuvee = '';
      this.millesime = '';
      this.aBoireAvant = '';
      this.prix = '';
    }
  }

  modifier(b) {
    this.idModifie = b.id;
    this.rang = 1;
    this.erreurs = {};
    this.#remplir(b);
    this.commentaire = b.commentaire ?? '';
    this.tagId = b.tag_id;
  }

  #remplir(b) {
    this.cuveeId = b.cuvee_id;
    this.texteCuvee = catalogue.cuvee(b.cuvee_id)?.nom ?? '';
    this.millesime = b.millesime ? String(b.millesime) : '';
    this.aBoireAvant = b.a_boire_avant ? String(b.a_boire_avant) : '';
    this.prix = b.prix != null ? String(b.prix).replace('.', ',') : '';
  }

  choisirCuvee(id) {
    this.cuveeId = id;
    this.texteCuvee = catalogue.cuvee(id)?.nom ?? '';
    delete this.erreurs.cuvee;
  }

  /** La saisie du nom de cuvée ne correspond plus à la cuvée choisie. */
  saisieCuvee(texte) {
    if (this.cuvee && this.cuvee.nom !== texte) this.cuveeId = null;
  }

  valider() {
    const e = {};
    const annee = ctx.annee;
    if (!this.cuveeId) e.cuvee = ctx.ordinateur ? 'Choisissez une cuvée existante ou créez-en une' : 'Choisissez ou créez une cuvée';
    const m = this.millesime.trim();
    if (!/^\d{4}$/.test(m) || +m < 1900 || +m > annee) e.millesime = `Année entre 1900 et ${annee}`;
    const a = this.aBoireAvant.trim();
    if (a && (!/^\d{4}$/.test(a) || +a < 1900 || +a > 2200)) e.aBoireAvant = 'Année entre 1900 et 2200';
    const p = this.prix.trim().replace(',', '.').replace(/\s|€/g, '');
    if (p && !(Number.isFinite(+p) && +p >= 0)) e.prix = 'Prix invalide';
    this.erreurs = e;
    return Object.keys(e).length === 0;
  }

  #donnees() {
    const p = this.prix.trim().replace(',', '.').replace(/\s|€/g, '');
    return {
      cuvee_id: this.cuveeId,
      millesime: Number(this.millesime),
      a_boire_avant: this.aBoireAvant.trim() ? Number(this.aBoireAvant) : null,
      prix: p ? Number(p) : null,
      commentaire: this.commentaire.trim(),
      tag_id: this.tagId || null,
    };
  }

  /**
   * Enregistre. `continuer` : garde cuvée, millésime, garde et prix ; vide le tag.
   * @returns {Promise<boolean>}
   */
  async enregistrer(continuer = false) {
    if (this.enCours || !this.valider()) return false;
    this.enCours = true;
    try {
      const d = this.#donnees();
      if (this.modification) {
        await cave.modifier(/** @type {number} */ (this.idModifie), d);
        toast.afficher('Bouteille enregistrée');
      } else {
        await cave.creer(d);
        if (continuer) {
          this.rang += 1;
          this.tagId = null;
          this.commentaire = '';
          toast.afficher(ctx.ordinateur ? 'Bouteille enregistrée · prête pour la suivante' : 'Bouteille enregistrée · même cuvée, tag suivant');
        } else {
          toast.afficher('Bouteille enregistrée');
        }
      }
      return true;
    } catch (e) {
      if (e instanceof ErreurApi && e.code === 'tag_utilise') {
        this.erreurs = { ...this.erreurs, tag: 'Ce tag est déjà sur une bouteille en stock' };
      } else {
        toast.afficher(e?.message || 'Enregistrement impossible');
      }
      return false;
    } finally {
      this.enCours = false;
    }
  }
}
