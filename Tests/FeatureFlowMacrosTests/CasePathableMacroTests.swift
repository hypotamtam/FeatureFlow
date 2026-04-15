#if os(macOS)
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import FeatureFlowMacros

@MainActor
final class CasePathableMacroTests: XCTestCase {
    let testMacros: [String: Macro.Type] = [
        "CasePathable": CasePathableMacro.self,
    ]

    func testMacro() {
        assertMacroExpansion(
            """
            @CasePathable
            enum AppAction {
                case counter(CounterAction)
                case user(UserAction)
            }
            """,
            expandedSource: """
            enum AppAction {
                case counter(CounterAction)
                case user(UserAction)
            }

            extension AppAction {
                internal enum Cases {
                    internal static let counter = CasePath<AppAction, CounterAction>(
                        embed: AppAction.counter,
                        extract: { root in
                            guard case let .counter(value) = root else {
                                    return nil
                                }
                            return value
                        }
                    )
                    internal static let user = CasePath<AppAction, UserAction>(
                        embed: AppAction.user,
                        extract: { root in
                            guard case let .user(value) = root else {
                                    return nil
                                }
                            return value
                        }
                    )
                }
            }
            """,
            macros: testMacros
        )
    }

    func testPublicEnum() {
        assertMacroExpansion(
            """
            @CasePathable
            public enum AppAction {
                case counter(CounterAction)
            }
            """,
            expandedSource: """
            public enum AppAction {
                case counter(CounterAction)
            }

            extension AppAction {
                public enum Cases {
                    public static let counter = CasePath<AppAction, CounterAction>(
                        embed: AppAction.counter,
                        extract: { root in
                            guard case let .counter(value) = root else {
                                    return nil
                                }
                            return value
                        }
                    )
                }
            }
            """,
            macros: testMacros
        )
    }
    
    func testInternalEnum() {
        assertMacroExpansion(
            """
            @CasePathable
            internal enum AppAction {
                case counter(CounterAction)
            }
            """,
            expandedSource: """
            internal enum AppAction {
                case counter(CounterAction)
            }

            extension AppAction {
                internal enum Cases {
                    internal static let counter = CasePath<AppAction, CounterAction>(
                        embed: AppAction.counter,
                        extract: { root in
                            guard case let .counter(value) = root else {
                                    return nil
                                }
                            return value
                        }
                    )
                }
            }
            """,
            macros: testMacros
        )
    }

    func testNoAssociatedValue() {
        assertMacroExpansion(
            """
            @CasePathable
            enum AppAction {
                case onAppear
                case child(ChildAction)
            }
            """,
            expandedSource: """
            enum AppAction {
                case onAppear
                case child(ChildAction)
            }

            extension AppAction {
                internal enum Cases {
                    internal static let child = CasePath<AppAction, ChildAction>(
                        embed: AppAction.child,
                        extract: { root in
                            guard case let .child(value) = root else {
                                    return nil
                                }
                            return value
                        }
                    )
                }
            }
            """,
            macros: testMacros
        )
    }

    func testNotApplicableToStruct() {
        assertMacroExpansion(
            """
            @CasePathable
            struct NotAnEnum {
                var value: Int
            }
            """,
            expandedSource: """
            struct NotAnEnum {
                var value: Int
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@CasePathable can only be applied to enums.", line: 1, column: 1)
            ],
            macros: testMacros
        )
    }
    
    func testNotApplicableToClass() {
        assertMacroExpansion(
            """
            @CasePathable
            class NotAnEnum {
                var value: Int
            }
            """,
            expandedSource: """
            class NotAnEnum {
                var value: Int
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@CasePathable can only be applied to enums.", line: 1, column: 1)
            ],
            macros: testMacros
        )
    }
    
    func testNotApplicableToActor() {
        assertMacroExpansion(
            """
            @CasePathable
            actor NotAnEnum {
                var value: Int
            }
            """,
            expandedSource: """
            actor NotAnEnum {
                var value: Int
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@CasePathable can only be applied to enums.", line: 1, column: 1)
            ],
            macros: testMacros
        )
    }
}
#endif
