// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TOYShared",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(
            name: "TOYShared",
            targets: ["TOYShared"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0"),
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "8.0.0"),
    ],
    targets: [
        .target(
            name: "TOYShared",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift"),
                .product(name: "Kingfisher", package: "Kingfisher"),
            ]
        ),
        .testTarget(
            name: "TOYSharedTests",
            dependencies: ["TOYShared"]
        ),
    ]
)
