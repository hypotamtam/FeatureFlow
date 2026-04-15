import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct FeatureFlowPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        CasePathableMacro.self,
    ]
}
