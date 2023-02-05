import ArgumentParser
import BoxesAndArrows
import Cocoa
import DrawCocoa
import Foundation

@main
struct BoxArr: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "boxarr",
        abstract: "Generates a diagram based on input spec",
        discussion: "Reads text input file or STDIN. Outputs PNG to file name derived from input or STDOUT."
    )

    @Argument(help: "Name of input file")
    var inputFile: String?

    @Option(name: .shortAndLong, help: "Name of output file")
    var outputFile: String?

    func run() throws {
        let input = try read(source: self.inputFile)
        let output = try outputHandle(inputFile: self.inputFile, outputFile: self.outputFile)
        let graphics = GraphicsCocoa()
        let image = try BoxesAndArrows.drawSpec(input, graphics: graphics)
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:])
        else {
            throw ImageExportError()
        }

        try output.write(contentsOf: png)
    }
}

struct ImageExportError: Error {}

struct FileCreationError: Error {
    let path: String
}

func outputHandle(inputFile: String?, outputFile: String?) throws -> FileHandle {
    if let outputFile {
        return try createFile(path: outputFile)
    } else if let inputFile {
        let outputName = pngFileName(source: inputFile)
        return try createFile(path: outputName)
    } else {
        return FileHandle.standardOutput
    }
}

func createFile(path: String) throws -> FileHandle {
    guard FileManager.default.createFile(atPath: path, contents: nil) else {
        throw FileCreationError(path: path)
    }
    return try FileHandle(forWritingTo: URL(string: path)!)
}

func pngFileName(source: String) -> String {
    let basename = {
        if let lastSlash = source.lastIndex(of: "/"), lastSlash != source.endIndex {
            return source.suffix(from: source.index(after: lastSlash))
        } else {
            return source[...]
        }
    }()

    let dotless = {
        if let firstDot = basename.firstIndex(of: "."), firstDot != source.endIndex {
            return basename.prefix(upTo: firstDot)
        } else {
            return basename
        }
    }()

    guard !dotless.isEmpty else {
        return "output.png"
    }
    return "\(dotless).png"
}

func read(source: String?) throws -> String {
    try source.map(readFile(path:)) ?? readStdIn()
}

func readFile(path: String) throws -> String {
    try String(contentsOfFile: path, encoding: .utf8)
}

func readStdIn() throws -> String {
    var lines = [String]()
    while let line = readLine() {
        lines.append(line)
    }
    return lines.joined(separator: "\n")
}
