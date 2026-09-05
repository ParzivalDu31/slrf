# Sideloadly Refresher — état du projet

*Mis à jour après inspection réelle des repos SideStore (clonés et lus, pas devinés).*

## Ce qui est codé et fonctionnel dès maintenant
- `Models/TrackedApp.swift` — modèle de données
- `Core/AppRegistry.swift` — persistance de la liste blanche (JSON local)
- `Views/AppListView.swift`, `Views/AddAppView.swift` — UI complète et utilisable
- `Companion/generate_pairing.py` — génère le pairing file une fois (nécessite `pip install pymobiledevice3`)

## Bonne nouvelle confirmée en inspectant le code source réel
`minimuxer` et `AltSign` (SideStore) sont maintenant du **Swift pur, packagés en SPM standard**,
avec des binaryTargets déjà précompilés (EMProxy.xcframework, OpenSSL.xcframework) —
**pas besoin de compiler du Rust toi-même pour ces deux-là**. Il suffit de :
```
Xcode > File > Add Package Dependencies…
  https://github.com/SideStore/minimuxer.git
  https://github.com/SideStore/AltSign.git
```
`PairingManager.swift`, `InstallManager.swift` et `ResignManager.swift` dans ce projet
appellent déjà les vraies fonctions (`Minimuxer.shared().core.start(...)`,
`LdidBridge.sign(...)`, etc.) telles qu'elles existent dans ces repos au 3 sept. 2026.

## La seule brique qui reste vraiment en Rust
**`apple-private-apis`** (github.com/SideStore/apple-private-apis) — auth Apple ID (GSA/GrandSlam)
+ appels developer.apple.com (lister/révoquer certificats, soumettre un CSR, créer un
provisioning profile). C'est un workspace Rust (`omnisette`, `icloud-auth`, `apple-dev-apis`,
`apple-codesign-wrapper`), sans binding Swift officiel prêt à l'emploi pour l'instant.

`CertificateManager.swift` documente précisément les étapes de compilation croisée et de
bridge FFI nécessaires (voir commentaires en tête du fichier) — c'est le seul vrai morceau
de travail d'intégration restant sur ce projet.

## Plan d'intégration détaillé (à suivre dans cet ordre)

### 1. minimuxer + AltSign — juste du SPM, rapide
Dans Xcode : File > Add Package Dependencies…, ajoute les deux URLs ci-dessus.
Le code de ce projet (`PairingManager`, `InstallManager`, `ResignManager`) compile
déjà contre leurs vraies API. Reste à :
- Fournir un vrai pairing file (via `generate_pairing.py`) pour tester `startLoopbackSession()`
- Tester `LdidBridge.sign` sur un .ipa de test, vérifier avec `codesign -dv` après coup

### 2. apple-private-apis (Rust — le vrai morceau de travail)
```
git clone https://github.com/SideStore/apple-private-apis.git
cd apple-private-apis
rustup target add aarch64-apple-ios
cargo install cbindgen
# Regarde icloud-auth/src/client.rs et apple-dev-apis/src/session.rs
# pour les fonctions publiques exactes à exposer en C.
cargo build --release --target aarch64-apple-ios -p icloud-auth -p apple-dev-apis
```
Puis génère les headers, ajoute `crate-type = ["staticlib"]` si absent dans les
`Cargo.toml` concernés, et lie le résultat dans Xcode comme n'importe quel `.a`.
Pour l'Anisette, récupère la liste à jour depuis `SideStore/AnisetteServers` (JSON).

### Ordre de test recommandé
1. `generate_pairing.py` en isolation (vérifie que pymobiledevice3 voit ton device)
2. minimuxer seul, via SPM (juste `startLoopbackSession()` + `isReady`)
3. AltSign seul (re-signer un .ipa de test en local, vérifier avec `codesign -dv`)
4. apple-private-apis (le plus dur) — juste récupérer un certificat, sans re-signer encore
5. Assembler les quatre dans RefreshCoordinator une fois chaque brique validée isolément

## Prérequis compte
- Compte Apple ID **gratuit** confirmé compatible avec ce flux (pas besoin de compte payant,
  grâce au tunnel WireGuard App Store + Jitterbug loopback).
- WireGuard installé depuis l'App Store (app séparée, gratuite).
