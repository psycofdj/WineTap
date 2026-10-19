// Résultat de la dernière lecture faite sur le téléphone (E-02), et les gestes NFC du téléphone.

import { api, ErreurApi } from '../api.js';
import { lireTag } from '../nfc.js';
import { routeur } from '../routeur.svelte.js';
import { toast } from '../toast.svelte.js';
import { cave, enrichir } from './cave.svelte.js';

class Lecture {
  /** 'consommer' | 'identifier' | 'recherche' */
  objet = $state('consommer');
  /** 'ok' | 'inconnu' | 'deja' */
  etat = $state('ok');
  /** @type {any} */
  bouteille = $state(null);
  tag = $state('');
  /** Commentaire enregistré pendant cette consommation */
  commentaireEnregistre = $state(false);

  #resultat(objet, etat, bouteille, tag, remplacer) {
    this.objet = objet;
    this.etat = etat;
    this.bouteille = bouteille;
    this.tag = tag;
    this.commentaireEnregistre = false;
    routeur.aller('/consommation', { remplacer });
  }

  /** Bouton « Consommer une bouteille » : lecture, puis consommation immédiate (D-10 de la v2). */
  async consommer({ remplacer = false } = {}) {
    const r = await lireTag('consommer');
    if (!this.#lu(r)) return;
    try {
      const b = await cave.consommerParTag(r.tag_id);
      this.#resultat('consommer', 'ok', b, r.tag_id, remplacer);
    } catch (e) {
      this.#erreur(e, 'consommer', r.tag_id, remplacer);
    }
  }

  /** Identifier ou rechercher une bouteille par son tag : ouvre sa fiche. */
  async identifier(objet = 'identifier', { remplacer = false } = {}) {
    const r = await lireTag(objet);
    if (!this.#lu(r)) return;
    const b = cave.parTag(r.tag_id);
    if (b) {
      routeur.aller(`/bouteille/${b.id}`, { remplacer });
      return;
    }
    try {
      const brute = await api.get(`/bouteilles/tag/${encodeURIComponent(r.tag_id)}`);
      routeur.aller(`/bouteille/${brute.id}`, { remplacer });
    } catch (e) {
      this.#erreur(e, objet, r.tag_id, remplacer);
    }
  }

  /** Relance la lecture depuis l'écran de résultat. */
  relancer() {
    if (this.objet === 'consommer') this.consommer({ remplacer: true });
    else this.identifier(this.objet, { remplacer: true });
  }

  #lu(r) {
    if (r.annule) {
      toast.afficher('Lecture annulée');
      return false;
    }
    if (r.erreur) {
      toast.afficher(r.erreur === 'indisponible' ? 'La lecture de tag se fait dans l’application' : 'Lecture impossible, réessayez');
      return false;
    }
    return true;
  }

  #erreur(e, objet, tag, remplacer) {
    if (e instanceof ErreurApi && e.code === 'deja_consommee') {
      this.#resultat(objet, 'deja', enrichir(e.donnees.bouteille), tag, remplacer);
    } else if (e instanceof ErreurApi && (e.code === 'tag_inconnu' || e.statut === 404)) {
      this.#resultat(objet, 'inconnu', null, tag, remplacer);
    } else {
      toast.afficher('Erreur : ' + (e?.message ?? 'inconnue'));
    }
  }
}

export const lecture = new Lecture();
