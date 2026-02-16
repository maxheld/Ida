// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "Modules",
  defaultLocalization: "en",
  platforms: [
    .iOS(.v26)
  ],
  products: [
    .library(
      name: "AppFeature",
      targets: ["AppFeature"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/sqlite-data", from: "1.5.2"),
    .package(url: "https://github.com/pointfreeco/swiftui-navigation", from: "1.5.5"),
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.10.0"),
    .package(url: "https://github.com/pointfreeco/swift-sharing", from: "2.0.0")
  ],
  targets: [
    .target(
      name: "AppFeature",
      dependencies: [
        .product(name: "SQLiteData", package: "sqlite-data"),
        .product(name: "SwiftUINavigation", package: "swiftui-navigation"),
        .product(name: "SwiftUINavigationCore", package: "swiftui-navigation"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "Sharing", package: "swift-sharing")
      ],
      path: "AppFeature",
      resources: [
        .process("Resources")
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self)
      ],
    ),
    .testTarget(
      name: "AppFeatureTests",
      dependencies: [
        "AppFeature",
        .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
        .product(name: "Sharing", package: "swift-sharing")
      ],
      path: "AppFeatureTests",
      swiftSettings: [
        .defaultIsolation(MainActor.self)
      ],
    )
  ]
)
