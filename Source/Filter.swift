import Foundation

/// A single fullscreen shader pass applied by a ``FilterChain``.
public struct Filter {
    /// The name of the Metal fragment function to run.
    public let fragmentFunction: String

    /// The bundle containing the compiled Metal library with ``fragmentFunction``.
    /// Use `Bundle.module` for Swift Package targets, or `Bundle.main` for app targets.
    public let bundle: Bundle

    /// Creates a filter backed by a fragment function in the given bundle.
    /// - Parameters:
    ///   - fragmentFunction: The Metal fragment function name.
    ///   - bundle: The bundle containing the compiled `.metallib`.
    public init(fragmentFunction: String, bundle: Bundle) {
        self.fragmentFunction = fragmentFunction
        self.bundle = bundle
    }
}
