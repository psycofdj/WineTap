# 6. Réseau et flux

<!-- toc -->

**Sur cette page**

- [6.1 Topologie](#61-topologie)
- [6.2 Adresse du téléphone](#62-adresse-du-téléphone)
- [6.3 Exposition du téléphone](#63-exposition-du-téléphone)
- [6.4 Matrice de flux](#64-matrice-de-flux)

<!-- /toc -->

## 6.1 Topologie

WineTap n'a pas de réseau propre. Il en utilise deux :

- **la boucle locale du téléphone** : la WebView de l'application parle au serveur par
  `http://localhost:8080`. Ce chemin ne dépend d'aucun réseau : l'application marche sans Wi-Fi ;
- **le réseau local de l'utilisateur**, en général le Wi-Fi de la maison, pour un ordinateur. Le
  téléphone et l'ordinateur doivent être sur le même réseau, et ce réseau doit laisser passer les
  connexions TCP d'un client vers un autre, vers le port 8080 du téléphone.

Aucun échange entre un navigateur et le téléphone ne sort du réseau local. Il n'y a ni serveur
relais, ni tunnel, ni accès depuis Internet, ni multicast.

Le système ne fonctionne qu'en **IPv4** : le téléphone n'écoute que sur ses adresses IPv4.

## 6.2 Adresse du téléphone

Il n'y a pas de découverte automatique. Le téléphone affiche son adresse sur l'écran N-E1
([§4.3](04-application-mobile.md#43-écrans-natifs)), relue toutes les 5 secondes ;
l'utilisateur la saisit dans le navigateur de l'ordinateur, qui la garde dans son historique et
ses favoris.

L'adresse dépend du bail attribué par la box et peut changer. Le cookie de session d'un
navigateur est lié au nom d'hôte saisi, ici l'adresse IP : pour le navigateur, une nouvelle
adresse du téléphone est un autre site, auquel il n'envoie pas sa session. Après un changement
d'adresse, le navigateur demande donc une nouvelle autorisation, et l'ancienne session reste dans
la liste N-E3 jusqu'à sa révocation.

## 6.3 Exposition du téléphone

Le serveur du téléphone écoute sur **toutes ses adresses IPv4**, port 8080, en HTTP sans TLS. Il
répond donc :

- sur la boucle locale, à la WebView de l'application ;
- sur le Wi-Fi, à **tout appareil du même réseau** ;
- sur l'interface de données mobiles, à qui peut joindre cette adresse ; en pratique, les
  opérateurs placent les téléphones derrière une traduction d'adresses qui bloque les connexions
  entrantes ;
- sur l'interface de partage de connexion, quand le téléphone sert de point d'accès, aux appareils
  qui s'y connectent.

À tous, le serveur sert les fichiers du site. L'API, elle, n'est ouverte qu'à la WebView et aux
navigateurs autorisés ; un autre appareil ne peut que **demander une autorisation**
([§9.2](09-securite.md#92-autorisation-des-navigateurs)). Le port n'est ouvert que lorsque
l'application est au premier plan ([§4.5.2](04-application-mobile.md#452-premier-plan-seulement)).

## 6.4 Matrice de flux

| # | Source | Destination | Protocole et port | Objet | Chiffrement | Authentification |
|---|---|---|---|---|---|---|
| F-01 | WebView de l'application | Serveur du téléphone (`localhost:8080`) | TCP 8080, HTTP | Site, API, événements | Aucun (boucle locale) | Jeton d'application : cookie `wt_app`, en-tête `X-WineTap-Token` |
| F-02 | Navigateur d'un ordinateur | Téléphone | TCP 8080, HTTP | Site, API, événements | Aucun | Cookie de session `wt_session`, autorisé sur le téléphone |
| F-03 | Navigateur d'un ordinateur non autorisé | Téléphone | TCP 8080, HTTP | Site ; `GET` et `POST /api/session` ; événement `session` seulement | Aucun | Aucune |
| F-04 | Tag NFC | Téléphone | NFC, 13,56 MHz | Lecture de l'UID | Aucun | Aucune |
| F-05 | Navigateur de l'ordinateur ou du téléphone | `chatgpt.com` ou `claude.ai` | TCP 443, HTTPS | Question préparée par le site, à l'initiative de l'utilisateur ([§5.7](05-site-web.md#57-aide-à-la-saisie-par-un-assistant-ia)) | TLS | Session de l'utilisateur chez le fournisseur, s'il en a une |
| F-06 | GitHub Actions | Registre npm, dépôts Flutter et Pub | TCP 443, HTTPS | Dépendances du site et de l'application, à la construction | TLS | Aucune |
| F-07 | GitHub Actions | API Google Play | TCP 443, HTTPS | Envoi du paquet Android sur la piste interne | TLS | Compte de service Google ([§10.4](10-livraison.md#104-signature-et-secrets)) |
| F-08 | GitHub Actions | API App Store Connect | TCP 443, HTTPS | Envoi du paquet iOS | TLS | Clé d'API App Store Connect |
| F-09 | Téléphone | Magasins | TCP 443, HTTPS | Installation de l'application | TLS | Selon le magasin |

Aucun autre flux n'existe : ni l'application ni le site n'appellent de service externe, en dehors
de l'ouverture de l'assistant IA (F-05).
