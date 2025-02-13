//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import TestingInternals

#if canImport(Foundation)
private import Foundation
#endif

#if !SWT_NO_TAG_COLORS
#if os(macOS) || (os(iOS) && targetEnvironment(macCatalyst)) || os(Linux)
/// The path to the current user's home directory, if known.
private var _homeDirectoryPath: String? {
#if canImport(Foundation)
  NSHomeDirectory()
#else
  if let homeVariable = Environment.variable(named: "HOME") {
    homeVariable
  } else if let pwd = getpwuid(geteuid()) {
    String(validatingUTF8: pwd.pointee.pw_dir)
  } else {
    nil
  }
#endif
}
#endif

#if os(Windows)
/// The path to the current user's App Data directory, if known.
private var _appDataDirectoryPath: String? {
  var appDataDirectoryPath: PWSTR? = nil
  if S_OK == SHGetKnownFolderPath(FOLDERID_LocalAppData, 0, NULL, &appDataDirectoryPath), let appDataDirectoryPath {
    defer {
      CoTaskMemFree(appDataDirectoryPath)
    }
    return String.decodeCString(appDataDirectoryPath, as: UTF16.self)?.result
  }
  return nil
}
#endif

/// The path to the user-specific `".swift-testing"` directory.
///
/// On Apple platforms and on Linux, this path is equivalent to
/// `"~/.swift-testing"`. On Windows, it is equivalent to
/// `"%HOMEPATH%\AppData\Local\.swift-testing"`.
var swiftTestingDirectoryPath: String {
  // The (default) name of the .swift-testing directory.
  let swiftTestingDirectoryName = ".swift-testing"

#if os(macOS) || (os(iOS) && targetEnvironment(macCatalyst)) || os(Linux)
  if let homeDirectoryPath = _homeDirectoryPath {
    return "\(homeDirectoryPath)/\(swiftTestingDirectoryName)"
  }
#elseif os(Windows)
  if let appDataDirectoryPath = _appDataDirectoryPath {
    return "\(appDataDirectoryPath)\\\(swiftTestingDirectoryName)"
  }
#else
#warning("Platform-specific implementation missing: swift-testing directory location unavailable")
#endif
  return ""
}
#endif

/// Read tag colors out of the file `"tag-colors.json"` in a given directory.
///
/// - Parameters:
///   - swiftTestingDirectoryPath: The `".swift-testing"` directory from which
///     tag color data should be read.
///
/// - Returns: A sequence of zero or more ``Event/Recorder/Option`` values
///   representing the tag colors read from the file.
///
/// This function attempts to read the contents of the file
/// `"tag-colors.json"` in the directory specified by
/// `swiftTestingDirectoryPath`. The file is assumed to contain a JSON object (a
/// dictionary) where the keys are tags' string values and the values represent
/// tag colors. For a list of the supported formats for tag colors in this
/// dictionary, see <doc:AddingTags>.
func tagColorOptions(fromFileInDirectoryAtPath swiftTestingDirectoryPath: String = swiftTestingDirectoryPath) -> [Event.Recorder.Option] {
#if !SWT_NO_TAG_COLORS && canImport(Foundation)
  // Find the path to the tag-colors.json file.
  let tagColorsURL = URL(fileURLWithPath: swiftTestingDirectoryPath, isDirectory: true)
    .appendingPathComponent("tag-colors.json", isDirectory: false)

  // Try to read from the JSON file. If we can't, ignore the error and just
  // don't load any tag colors.
  guard let tagColorsData = try? Data(contentsOf: tagColorsURL, options: [.mappedIfSafe]) else {
    return []
  }

  // By default, a dictionary with non-string keys is encoded to and decoded
  // from JSON as an array, so we decode the dictionary as if its keys are plain
  // strings, then map them to tags.
  //
  // nil is a valid decoded color value (representing "no color") that we can
  // use for merging tag color data from multiple sources, but it is not valid
  // as an actual tag color, so we have a step here that filters it.
  return (try? JSONDecoder().decode([String: Tag.Color?].self, from: tagColorsData))
    .map { $0.map { (Tag(rawValue: $0), $1) } }
    .map { Dictionary(uniqueKeysWithValues: $0) }
    .map { $0.compactMapValues { $0 } }
    .map { [.useTagColors($0)] } ?? []
#else
  []
#endif
}
