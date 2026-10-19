// Pont JavaScript simulé de l'application (voir API.md, §9), pour développer dans un navigateur.

import { mount, unmount } from 'svelte';
import LectureSimulee from './LectureSimulee.svelte';

const JETON = 'jeton-dev';

function lecture(objet) {
  return new Promise((resoudre) => {
    const cible = document.createElement('div');
    document.body.appendChild(cible);
    const composant = mount(LectureSimulee, {
      target: cible,
      props: {
        objet,
        terminer: (r) => {
          unmount(composant);
          cible.remove();
          resoudre(r);
        },
      },
    });
  });
}

export function installerPont() {
  window.winetapBridge = {
    token: JETON,
    readTag: (objet) => lecture(objet),
    async saveBackup() {
      const rep = await fetch('/api/sauvegarde', { headers: { 'X-WineTap-Token': JETON } });
      const blob = await rep.blob();
      const nom = /filename="([^"]+)"/.exec(rep.headers.get('Content-Disposition') ?? '')?.[1] ?? 'winetap.db';
      const a = document.createElement('a');
      a.href = URL.createObjectURL(blob);
      a.download = nom;
      a.click();
      return { enregistre: true, nom };
    },
    pickFile() {
      return new Promise((resoudre) => {
        const entree = document.createElement('input');
        entree.type = 'file';
        entree.onchange = () => {
          const f = entree.files?.[0];
          if (!f) return resoudre({ annule: true });
          const lecteur = new FileReader();
          lecteur.onload = () => {
            const s = /** @type {string} */ (lecteur.result);
            resoudre({ nom: f.name, base64: s.slice(s.indexOf(',') + 1) });
          };
          lecteur.readAsDataURL(f);
        };
        entree.click();
      });
    },
    openNative(ecran) {
      alert(`Écran natif « ${ecran} » (N-E1 ou N-E3) : affiché par l'application Flutter.`);
    },
    openExternal(url) {
      window.open(url, '_blank', 'noopener');
    },
  };
}
