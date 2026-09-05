# Sideloadly Refresher — état du projet

*Architecture corrigée après avoir découvert que SideStore a abandonné AltSign
au profit de SideSign — beaucoup plus simple, sans conflit OpenSSL.*

## Dépendances réelles (toutes en Swift pur, SPM)
- **minimuxer** (github.com/SideStore/minimuxer, branche `develop`) — tunnel loopback,
  cloné en local dans `vendor/minimuxer` par le workflow CI (a des sous-dépendances
  locales incompatibles avec un usage en package distant direct)
- **SideSign** (github.com/SideStore/SideSign, branche `main`) — remplace AltSign
  ET tout le Rust `apple-private-apis` d'un coup : signature de code (`AppBundleSigner`)
  + auth Apple Developer (`DeveloperPortal`) + génération anisette locale (`AnisetteKit`,
  inclus comme sous-dépendance). Aucune dépendance OpenSSL (utilise swift-crypto
  officiel d'Apple) — donc plus de conflit de target avec minimuxer.

## Vrai prérequis à régler toi-même (pas fourni ici)
`AnisetteKit.LocalAnisetteProvider` a besoin de deux bibliothèques Apple propriétaires :
`libstoreservicescore.so` et `libCoreADI.so`. Je ne peux pas te les fournir (binaires
Apple, pas open source). C'est la même contrainte que tous les projets "anisette-v3" —
cherche du côté de la communauté SideStore (Discord/wiki) pour savoir où les obtenir.

## État du code
- Fonctionnel : `TrackedApp`, `AppRegistry`, `AppListView`, `AddAppView`, `generate_pairing.py`
- Architecturé avec la vraie API SideSign/minimuxer (`PairingManager`, `InstallManager`,
  `ResignManager`, `CertificateManager`, `RefreshCoordinator`) — mais **jamais compilé
  avec succès jusqu'ici**, donc attends-toi à d'autres erreurs de compilation au
  prochain run CI. `CertificateManager.authenticate()` a un `fatalError` volontaire :
  la conversion entre les headers anisette bruts et le type `AnisetteData` attendu par
  `DeveloperPortal.authenticate` doit être vérifiée/corrigée une fois que ça compile
  (je n'ai pas pu confirmer cette signature exacte sans compilateur Swift disponible).

## Prochaine étape
Relancer le build CI avec ce zip, et itérer sur les erreurs de compilation Xcode
restantes (il y en aura probablement) une par une.
