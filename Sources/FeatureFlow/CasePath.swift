import Foundation

/// A path that allows for embedding a value into a root type (typically an enum) and extracting a value from that root type.
///
/// Case paths are the enum equivalent of key paths. While key paths allow us to reference a specific property of a struct,
/// case paths allow us to reference a specific case of an enum.
public struct CasePath<Root, Value>: Sendable {
    /// A function that takes a value and returns a root type, typically by wrapping the value in an enum case.
    public let embed: @Sendable (Value) -> Root

    /// A function that takes a root type and attempts to extract a value from it, returning `nil` if the root type is not the expected case.
    public let extract: @Sendable (Root) -> Value?

    public init(
        embed: @escaping @Sendable (Value) -> Root,
        extract: @escaping @Sendable (Root) -> Value?
    ) {
        self.embed = embed
        self.extract = extract
    }
}
