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
    .package(url: "https://github.com/pointfreeco/sqlite-data", from: "1.5.0"),
    .package(url: "https://github.com/pointfreeco/swiftui-navigation", from: "1.5.5"),
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.10.0")
  ],
  targets: [
    .target(
      name: "AppFeature",
      dependencies: [
        .product(name: "SQLiteData", package: "sqlite-data"),
        .product(name: "SwiftUINavigation", package: "swiftui-navigation"),
        .product(name: "SwiftUINavigationCore", package: "swiftui-navigation"),
        .product(name: "Dependencies", package: "swift-dependencies")
      ],
      path: "AppFeature",
      resources: [
        .process("Localizable.xcstrings"),
        .process("Assets.xcassets")
      ]
    ),
    .testTarget(
      name: "AppFeatureTests",
      dependencies: ["AppFeature"],
      path: "AppFeatureTests"
    )
  ]
)
