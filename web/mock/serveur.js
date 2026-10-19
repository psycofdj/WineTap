// Serveur de développement : implémente API.md en mémoire, branché sur le serveur Vite.
// Il simule aussi le téléphone (autorisation, lecture de tag, coupure) par les routes /__mock/*.

import { randomBytes } from 'node:crypto';
import { creerDonnees } from './donnees.js';

const JETON_APPLICATION = 'jeton-dev';
const ENTETE_SQLITE = Buffer.from('SQLite format 3\0', 'binary');

export function apiSimulee() {
  let db = creerDonnees();
  /** tag libéré → id de la bouteille consommée (voir API.md, « Déjà consommée ») */
  const tagsLiberes = new Map();
  /** @type {Map<string, {id:string, statut:string, client:any, autorisee_le?:string, actif_le?:string}>} */
  const sessions = new Map();
  const politique = { auto: true };
  /** @type {Set<{res:any, session:string}>} */
  const abonnes = new Set();
  /** @type {{id:string, objet:string, session:string}|null} */
  let scan = null;
  let coupeJusque = 0;

  // --- Utilitaires -----------------------------------------------------------

  const json = (res, statut, corps, entetes = {}) => {
    res.writeHead(statut, { 'Content-Type': 'application/json; charset=utf-8', ...entetes });
    res.end(corps === undefined ? '' : JSON.stringify(corps));
  };
  const erreur = (res, statut, code, message, extra = {}) => json(res, statut, { erreur: code, message, ...extra });
  const vide = (res) => {
    res.writeHead(204);
    res.end();
  };

  const lireCorps = (req) =>
    new Promise((resoudre, rejeter) => {
      const morceaux = [];
      let taille = 0;
      req.on('data', (m) => {
        taille += m.length;
        if (taille > 100 * 1024 * 1024) rejeter(new Error('trop_gros'));
        morceaux.push(m);
      });
      req.on('end', () => resoudre(Buffer.concat(morceaux)));
      req.on('error', rejeter);
    });
  const lireJson = async (req) => {
    const b = await lireCorps(req);
    if (!b.length) return {};
    return JSON.parse(b.toString('utf8'));
  };

  const cookies = (req) =>
    Object.fromEntries(
      (req.headers.cookie || '')
        .split(';')
        .map((c) => c.trim().split('='))
        .filter((p) => p[0])
        .map(([k, ...v]) => [k, decodeURIComponent(v.join('='))]),
    );

  const client = (req) => {
    const ua = req.headers['user-agent'] || '';
    const navigateur = /Firefox\/(\d+)/.test(ua)
      ? 'Firefox'
      : /Edg\//.test(ua)
        ? 'Edge'
        : /Chrome\//.test(ua)
          ? 'Chrome'
          : /Safari\//.test(ua)
            ? 'Safari'
            : 'Navigateur';
    const systeme = /Android/.test(ua)
      ? 'Android'
      : /iPhone|iPad/.test(ua)
        ? 'iOS'
        : /Mac OS X/.test(ua)
          ? 'macOS'
          : /Windows/.test(ua)
            ? 'Windows'
            : /Linux/.test(ua)
              ? 'Linux'
              : 'Inconnu';
    let ip = (req.socket.remoteAddress || '').replace('::ffff:', '');
    if (ip === '::1' || ip === '127.0.0.1') ip = '192.168.1.27';
    return { navigateur, systeme, ip, demande_le: new Date().toISOString() };
  };

  const millesimeValide = (m) => Number.isInteger(Number(m)) && Number(m) >= 1900 && Number(m) <= new Date().getFullYear();
  const normaliserTag = (t) => (t ?? '').toString().replace(/[:\s-]/g, '').toUpperCase();

  /** @returns {{type:'application'}|{type:'navigateur', session:any}|null} */
  function identifier(req, url) {
    const jeton = req.headers['x-winetap-token'] || url.searchParams.get('token');
    if (jeton === JETON_APPLICATION) return { type: 'application' };
    const id = cookies(req).wt_session;
    const s = id && sessions.get(id);
    return s ? { type: 'navigateur', session: s } : null;
  }

  function diffuser(evenement, donnees, filtre = () => true) {
    const ligne = `event: ${evenement}\ndata: ${JSON.stringify(donnees)}\n\n`;
    for (const a of abonnes) {
      const s = sessions.get(a.session);
      const autorise = a.session === 'application' || s?.statut === 'autorisee';
      if ((evenement === 'session' || autorise) && filtre(a)) a.res.write(ligne);
    }
  }
  const changement = (...quoi) => diffuser('donnees', { quoi });

  const enStock = () => db.bouteilles.filter((b) => !b.consommee_le);
  const bouteille = (id) => db.bouteilles.find((b) => b.id === id);

  function consommer(b) {
    if (b.tag_id) tagsLiberes.set(b.tag_id, b.id);
    b.tag_id = null;
    b.consommee_le = new Date().toISOString();
  }

  function parTag(tag) {
    const b = enStock().find((x) => x.tag_id === tag);
    if (b) return { b };
    const idConso = tagsLiberes.get(tag);
    if (idConso && bouteille(idConso)) return { deja: bouteille(idConso) };
    return {};
  }

  function associerTag(tag) {
    if (tag) tagsLiberes.delete(tag);
  }

  const sansImage = (a) => {
    const { image, ...reste } = a;
    return { ...reste, a_image: !!image };
  };

  function sauvegarde() {
    return Buffer.concat([ENTETE_SQLITE, Buffer.from(JSON.stringify(db), 'utf8')]);
  }

  function examiner(buf) {
    if (buf.length < 16 || !buf.subarray(0, 16).equals(ENTETE_SQLITE)) return null;
    try {
      const d = JSON.parse(buf.subarray(16).toString('utf8'));
      return { donnees: d, en_stock: d.bouteilles.filter((b) => !b.consommee_le).length };
    } catch {
      return { donnees: null, en_stock: null };
    }
  }

  // --- Catalogue générique -----------------------------------------------------

  const RUBRIQUES = {
    appellations: {
      table: () => db.appellations,
      champs: (c, ancien = {}) => {
        const o = {
          nom: (c.nom ?? '').trim(),
          region: (c.region ?? '').trim(),
          description: (c.description ?? '').trim(),
          image: ancien.image ?? null,
        };
        if ('image' in c) o.image = c.image || null;
        return o;
      },
      utilisee: (id) => db.cuvees.filter((c) => c.appellation_id === id).length,
      sortie: sansImage,
    },
    domaines: {
      table: () => db.domaines,
      champs: (c) => ({ nom: (c.nom ?? '').trim(), description: (c.description ?? '').trim() }),
      utilisee: (id) => db.cuvees.filter((c) => c.domaine_id === id).length,
      sortie: (x) => x,
    },
    cuvees: {
      table: () => db.cuvees,
      champs: (c) => ({
        nom: (c.nom ?? '').trim(),
        domaine_id: Number(c.domaine_id),
        appellation_id: Number(c.appellation_id) || 0,
        couleur: Number(c.couleur) || 0,
        description: (c.description ?? '').trim(),
      }),
      utilisee: (id) => db.bouteilles.filter((b) => b.cuvee_id === id).length,
      sortie: (x) => x,
    },
  };

  function verifierCatalogue(rubrique, o, id) {
    if (!o.nom) return 'Le nom est obligatoire.';
    if (rubrique !== 'cuvees') {
      const doublon = RUBRIQUES[rubrique].table().find((x) => x.nom.toLowerCase() === o.nom.toLowerCase() && x.id !== id);
      if (doublon) return `« ${o.nom} » existe déjà.`;
    } else if (!db.domaines.some((d) => d.id === o.domaine_id)) {
      return 'Choisissez un domaine.';
    }
    return null;
  }

  // --- Routes -------------------------------------------------------------------

  async function api(req, res, url) {
    const chemin = url.pathname.replace(/^\/api/, '');
    const m = req.method;
    const qui = identifier(req, url);

    // Session
    if (chemin === '/session') {
      if (m === 'GET') {
        if (qui?.type === 'application') {
          return json(res, 200, {
            statut: 'autorisee',
            dans_application: true,
            telephone: { nom: 'iPhone', adresse: '192.168.1.42:8080' },
            annee: new Date().getFullYear(),
            connexions: [...sessions.values()].filter((s) => s.statut === 'autorisee').length,
          });
        }
        if (qui?.session?.statut === 'autorisee') {
          qui.session.actif_le = new Date().toISOString();
          return json(res, 200, {
            statut: 'autorisee',
            dans_application: false,
            telephone: { nom: 'iPhone', adresse: '192.168.1.42:8080' },
            annee: new Date().getFullYear(),
            connexions: 0,
          });
        }
        return json(res, 401, { statut: qui?.session?.statut ?? 'inconnue', client: qui?.session?.client ?? client(req) });
      }
      if (m === 'POST') {
        const id = qui?.session?.id ?? randomBytes(16).toString('hex');
        const s = { id, statut: politique.auto ? 'autorisee' : 'en_attente', client: client(req) };
        if (s.statut === 'autorisee') s.autorisee_le = new Date().toISOString();
        sessions.set(id, s);
        return json(res, 202, { statut: s.statut, client: s.client }, {
          'Set-Cookie': `wt_session=${id}; HttpOnly; SameSite=Strict; Path=/`,
        });
      }
    }

    // Événements
    if (chemin === '/events' && m === 'GET') {
      res.writeHead(200, { 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache', Connection: 'keep-alive' });
      res.write('retry: 5000\n\n');
      const abonne = { res, session: qui?.type === 'application' ? 'application' : (qui?.session?.id ?? 'anonyme') };
      abonnes.add(abonne);
      const ping = setInterval(() => res.write(': ping\n\n'), 20000);
      req.on('close', () => {
        clearInterval(ping);
        abonnes.delete(abonne);
      });
      return;
    }

    const autorise = qui?.type === 'application' || qui?.session?.statut === 'autorisee';
    if (!autorise) return erreur(res, 401, 'non_autorise', 'Ce navigateur n’est pas autorisé.');
    if (qui?.session) qui.session.actif_le = new Date().toISOString();

    // Image d'une appellation
    let r = chemin.match(/^\/appellations\/(\d+)\/image$/);
    if (r && m === 'GET') {
      const a = db.appellations.find((x) => x.id === Number(r[1]));
      if (!a?.image) return erreur(res, 404, 'introuvable', 'Pas d’image.');
      const buf = Buffer.from(a.image, 'base64');
      const type = buf[0] === 0x89 ? 'image/png' : buf[0] === 0xff ? 'image/jpeg' : buf.subarray(0, 4).toString() === 'RIFF' ? 'image/webp' : buf.subarray(0, 3).toString() === 'GIF' ? 'image/gif' : 'image/svg+xml';
      res.writeHead(200, { 'Content-Type': type, 'Cache-Control': 'no-cache' });
      return res.end(buf);
    }

    // Catalogue
    r = chemin.match(/^\/(appellations|domaines|cuvees)(?:\/(\d+))?$/);
    if (r) {
      const [, rubrique, idTexte] = r;
      const R = RUBRIQUES[rubrique];
      const id = idTexte ? Number(idTexte) : null;
      if (!id && m === 'GET') return json(res, 200, R.table().map(R.sortie));
      if (!id && m === 'POST') {
        const o = R.champs(await lireJson(req));
        const err = verifierCatalogue(rubrique, o, null);
        if (err) return erreur(res, 400, 'invalide', err);
        const nouvel = { id: Math.max(0, ...R.table().map((x) => x.id)) + 1, ...o };
        R.table().push(nouvel);
        changement('catalogue');
        return json(res, 201, R.sortie(nouvel));
      }
      const obj = id && R.table().find((x) => x.id === id);
      if (!obj) return erreur(res, 404, 'introuvable', 'Fiche introuvable.');
      if (m === 'GET') return json(res, 200, R.sortie(obj));
      if (m === 'PUT') {
        const o = R.champs(await lireJson(req), obj);
        const err = verifierCatalogue(rubrique, o, id);
        if (err) return erreur(res, 400, 'invalide', err);
        Object.assign(obj, o);
        changement('catalogue');
        return json(res, 200, R.sortie(obj));
      }
      if (m === 'DELETE') {
        const n = R.utilisee(id);
        if (n) return erreur(res, 409, 'referencee', 'Fiche encore utilisée.', { nombre: n });
        const t = R.table();
        t.splice(t.indexOf(obj), 1);
        changement('catalogue');
        return vide(res);
      }
    }

    // Bouteilles
    if (chemin === '/bouteilles' && m === 'GET') {
      return json(res, 200, url.searchParams.get('consommees') ? db.bouteilles : enStock());
    }
    if (chemin === '/bouteilles' && m === 'POST') {
      const c = await lireJson(req);
      const tag = c.tag_id ? normaliserTag(c.tag_id) : null;
      if (!db.cuvees.some((x) => x.id === Number(c.cuvee_id))) return erreur(res, 400, 'invalide', 'Choisissez une cuvée.');
      if (!millesimeValide(c.millesime)) return erreur(res, 400, 'invalide', 'Millésime obligatoire, entre 1900 et l\u2019année en cours.');
      if (tag) {
        const occ = enStock().find((x) => x.tag_id === tag);
        if (occ) return erreur(res, 409, 'tag_utilise', 'Ce tag est déjà sur une bouteille en stock.', { bouteille_id: occ.id });
      }
      associerTag(tag);
      const b = {
        id: Math.max(0, ...db.bouteilles.map((x) => x.id)) + 1,
        tag_id: tag,
        cuvee_id: Number(c.cuvee_id),
        millesime: Number(c.millesime),
        commentaire: (c.commentaire ?? '').trim(),
        prix: c.prix == null || c.prix === '' ? null : Number(c.prix),
        a_boire_avant: c.a_boire_avant ? Number(c.a_boire_avant) : null,
        entree_le: new Date().toISOString(),
        consommee_le: null,
      };
      db.bouteilles.push(b);
      changement('bouteilles');
      return json(res, 201, b);
    }
    r = chemin.match(/^\/bouteilles\/(\d+)(\/consommer)?$/);
    if (r) {
      const b = bouteille(Number(r[1]));
      if (!b) return erreur(res, 404, 'introuvable', 'Bouteille introuvable.');
      if (r[2] && m === 'POST') {
        if (b.consommee_le) return erreur(res, 409, 'deja_consommee', 'Déjà consommée.', { bouteille: b });
        consommer(b);
        changement('bouteilles');
        return json(res, 200, b);
      }
      if (m === 'PUT') {
        const c = await lireJson(req);
        if ('tag_id' in c) {
          const tag = c.tag_id ? normaliserTag(c.tag_id) : null;
          const occ = tag && enStock().find((x) => x.tag_id === tag && x.id !== b.id);
          if (occ) return erreur(res, 409, 'tag_utilise', 'Ce tag est déjà sur une bouteille en stock.', { bouteille_id: occ.id });
          associerTag(tag);
          b.tag_id = tag;
        }
        if ('cuvee_id' in c) b.cuvee_id = Number(c.cuvee_id);
        if ('millesime' in c) {
          if (!millesimeValide(c.millesime)) return erreur(res, 400, 'invalide', 'Millésime obligatoire, entre 1900 et l\u2019année en cours.');
          b.millesime = Number(c.millesime);
        }
        if ('commentaire' in c) b.commentaire = (c.commentaire ?? '').trim();
        if ('prix' in c) b.prix = c.prix == null || c.prix === '' ? null : Number(c.prix);
        if ('a_boire_avant' in c) b.a_boire_avant = c.a_boire_avant ? Number(c.a_boire_avant) : null;
        changement('bouteilles');
        return json(res, 200, b);
      }
      if (m === 'DELETE') {
        db.bouteilles.splice(db.bouteilles.indexOf(b), 1);
        changement('bouteilles');
        return vide(res);
      }
    }
    if (chemin === '/consommer' && m === 'POST') {
      const tag = normaliserTag((await lireJson(req)).tag_id);
      const t = parTag(tag);
      if (t.deja) return erreur(res, 409, 'deja_consommee', 'Bouteille déjà consommée.', { bouteille: t.deja });
      if (!t.b) return erreur(res, 404, 'tag_inconnu', 'Ce tag n’est associé à aucune bouteille en stock.');
      consommer(t.b);
      changement('bouteilles');
      return json(res, 200, { bouteille: t.b });
    }
    r = chemin.match(/^\/bouteilles\/tag\/([^/]+)$/);
    if (r && m === 'GET') {
      const t = parTag(normaliserTag(decodeURIComponent(r[1])));
      if (t.deja) return erreur(res, 409, 'deja_consommee', 'Bouteille déjà consommée.', { bouteille: t.deja });
      if (!t.b) return erreur(res, 404, 'tag_inconnu', 'Tag inconnu.');
      return json(res, 200, t.b);
    }
    if (chemin === '/degustations' && m === 'GET') {
      const depuis = Number(url.searchParams.get('depuis') || 0);
      const nombre = Number(url.searchParams.get('nombre') || 20);
      const conso = db.bouteilles.filter((b) => b.consommee_le).sort((a, b) => b.consommee_le.localeCompare(a.consommee_le));
      return json(res, 200, { total: conso.length, bouteilles: conso.slice(depuis, depuis + nombre) });
    }

    // Réglages
    if (chemin === '/reglages') {
      if (m === 'GET') return json(res, 200, db.reglages);
      if (m === 'PUT') {
        const c = await lireJson(req);
        db.reglages.assistant = c.assistant === 'chatgpt' ? 'chatgpt' : 'claude';
        changement('reglages');
        return json(res, 200, db.reglages);
      }
    }

    // Lecture demandée par un ordinateur
    if (chemin === '/scan' && m === 'POST') {
      const c = await lireJson(req);
      if (scan) return erreur(res, 409, 'occupe', 'Une lecture est déjà en cours.');
      scan = { id: randomBytes(6).toString('hex'), objet: c.objet === 'recherche' ? 'recherche' : 'entree', session: qui?.session?.id ?? 'application' };
      return json(res, 202, { id: scan.id });
    }
    r = chemin.match(/^\/scan\/([^/]+)$/);
    if (r && m === 'DELETE') {
      if (scan?.id === r[1]) {
        diffuser('scan', { id: scan.id, statut: 'annule' });
        scan = null;
      }
      return vide(res);
    }

    // Sauvegarde et restauration
    if (chemin === '/sauvegarde' && m === 'GET') {
      const d = new Date();
      const p = (n) => String(n).padStart(2, '0');
      res.writeHead(200, {
        'Content-Type': 'application/octet-stream',
        'Content-Disposition': `attachment; filename="winetap-${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}.db"`,
      });
      return res.end(sauvegarde());
    }
    if ((chemin === '/restauration/examen' || chemin === '/restauration') && m === 'POST') {
      let buf;
      try {
        buf = await lireCorps(req);
      } catch {
        return erreur(res, 413, 'trop_gros', 'Le fichier dépasse 100 Mo.');
      }
      const ex = examiner(buf);
      if (!ex) return erreur(res, 400, 'fichier_invalide', 'Ce fichier n’est pas une sauvegarde WineTap.');
      if (chemin === '/restauration' && ex.donnees) {
        db = ex.donnees;
        tagsLiberes.clear();
        changement('catalogue', 'bouteilles', 'reglages');
      }
      return json(res, 200, { en_stock: ex.en_stock });
    }

    return erreur(res, 404, 'introuvable', `Route inconnue : ${m} ${chemin}`);
  }

  // --- Simulation du téléphone (/__mock/*) ------------------------------------

  async function mock(req, res, url) {
    const chemin = url.pathname.replace(/^\/__mock/, '');
    if (chemin === '/etat') {
      return json(res, 200, {
        politique,
        scan,
        coupure: Math.max(0, coupeJusque - Date.now()),
        sessions: [...sessions.values()],
      });
    }
    const c = req.method === 'POST' ? await lireJson(req).catch(() => ({})) : {};
    if (chemin === '/politique') {
      politique.auto = !!c.auto;
      return json(res, 200, politique);
    }
    if (chemin === '/session') {
      // Décision du téléphone sur une session (ou celle du navigateur appelant).
      const id = c.id ?? cookies(req).wt_session;
      const s = id && sessions.get(id);
      if (!s) return erreur(res, 404, 'introuvable', 'Session inconnue.');
      s.statut = c.statut;
      if (c.statut === 'autorisee') s.autorisee_le = new Date().toISOString();
      diffuser('session', { statut: c.statut === 'inconnue' ? 'revoquee' : c.statut }, (a) => a.session === s.id);
      if (c.statut === 'inconnue') sessions.delete(s.id);
      return json(res, 200, s);
    }
    if (chemin === '/scan') {
      if (!scan) return erreur(res, 404, 'introuvable', 'Aucune lecture en cours.');
      const id = scan.id;
      let evt;
      if (c.action === 'nouveau') evt = { id, statut: 'lu', tag_id: '04' + randomBytes(3).toString('hex').toUpperCase() };
      else if (c.action === 'existant') evt = { id, statut: 'lu', tag_id: enStock()[Math.floor(Math.random() * enStock().length)]?.tag_id };
      else if (c.action === 'erreur') evt = { id, statut: 'erreur' };
      else evt = { id, statut: 'annule' };
      scan = null;
      diffuser('scan', evt);
      return json(res, 200, evt);
    }
    if (chemin === '/couper') {
      coupeJusque = Date.now() + (Number(c.secondes) || 15) * 1000;
      for (const a of abonnes) a.res.destroy();
      abonnes.clear();
      return json(res, 200, { jusque: coupeJusque });
    }
    if (chemin === '/consommer-sur-telephone') {
      const b = enStock().find((x) => x.tag_id);
      if (!b) return erreur(res, 404, 'introuvable', 'Cave vide.');
      consommer(b);
      changement('bouteilles');
      return json(res, 200, b);
    }
    if (chemin === '/tags') {
      // Pour le pont simulé : un tag en stock, un tag libéré.
      const libere = [...tagsLiberes.keys()].pop() ?? null;
      return json(res, 200, { en_stock: enStock().filter((b) => b.tag_id).slice(0, 40).map((b) => b.tag_id), libere });
    }
    if (chemin === '/vider') {
      db.bouteilles = [];
      changement('bouteilles');
      return json(res, 200, {});
    }
    if (chemin === '/reinitialiser') {
      db = creerDonnees();
      tagsLiberes.clear();
      changement('catalogue', 'bouteilles', 'reglages');
      return json(res, 200, {});
    }
    return erreur(res, 404, 'introuvable', 'Route de simulation inconnue.');
  }

  return {
    name: 'winetap-api-simulee',
    configureServer(server) {
      server.middlewares.use(async (req, res, next) => {
        const url = new URL(req.url, 'http://localhost');
        try {
          if (url.pathname.startsWith('/__mock/')) return await mock(req, res, url);
          if (url.pathname.startsWith('/api/')) {
            if (Date.now() < coupeJusque) {
              req.socket.destroy();
              return;
            }
            return await api(req, res, url);
          }
        } catch (e) {
          console.error('[api simulée]', e);
          if (!res.headersSent) return erreur(res, 500, 'interne', String(e?.message ?? e));
          return;
        }
        next();
      });
    },
  };
}
