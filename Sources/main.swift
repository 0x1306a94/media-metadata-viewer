// The Swift Programming Language
// https://docs.swift.org/swift-book

import ArgumentParser

@main
struct MediaMetadataViewer: AsyncParsableCommand {
    @Option(name: .shortAndLong, help: "The path to the media file")
    var path: String

    func run() async throws {
        print("Hello, world!")
    }
}