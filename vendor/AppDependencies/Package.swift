// swift-tools-version:5.9
import PackageDescription

/// Ce package existe UNIQUEMENT pour résoudre un conflit réel entre minimuxer
/// (via DeviceGateway → RemotePairingKit, qui vend son propre target "OpenSSL")
/// et AltSign (qui dépend directement de krzyzanowskim/OpenSSL, target aussi
/// nommé "OpenSSL"). SwiftPM interdit deux targets de même nom dans tout le
/// graphe — on utilise `moduleAliases` (SwiftPM 5.7+) pour renommer l'un des
/// deux au moment de la résolution, sans toucher au code source des deux libs.
let package = Package(
    name: "AppDependencies",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "AppDependencies", targets: ["AppDependencies"])
    ],
    dependencies: [
        .package(path: "../minimuxer"),
        .package(url: "https://github.com/SideStore/AltSign.git", branch: "feature/swiftpm")
    ],
    targets: [
        .target(
            name: "AppDependencies",
            dependencies: [
                .product(name: "Minimuxer", package: "minimuxer"),
                .product(
                    name: "AltSign",
                    package: "AltSign",
                    moduleAliases: ["OpenSSL": "AltSignOpenSSL"]
                )
            ],
            path: "Sources/AppDependencies"
        )
    ]
)
