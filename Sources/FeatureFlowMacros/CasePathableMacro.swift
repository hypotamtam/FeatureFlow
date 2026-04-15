import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct CasePathableMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
            throw MacroError.onlyApplicableToEnums
        }

        let access = enumDecl.modifiers.first { modifier in
            modifier.name.tokenKind == .keyword(.public) || 
            modifier.name.tokenKind == .keyword(.package) ||
            modifier.name.tokenKind == .keyword(.internal)
        }?.name.text ?? "internal"

        let cases = enumDecl.memberBlock.members
            .compactMap { $0.decl.as(EnumCaseDeclSyntax.self) }
            .flatMap { $0.elements }

        var casePathDecls: [String] = []

        for caseElement in cases {
            let caseName = caseElement.name.text
            
            // We only support cases with exactly one associated value for now
            // as it's the standard for Action composition.
            guard let parameterList = caseElement.parameterClause?.parameters,
                  parameterList.count == 1,
                  let firstParam = parameterList.first else {
                continue
            }
            
            let associatedType = firstParam.type.description.trimmingCharacters(in: .whitespaces)
            
            let decl = """
                public static let \(caseName) = CasePath<\(type), \(associatedType)>(
                    embed: \(type).\(caseName),
                    extract: { root in
                        guard case let .\(caseName)(value) = root else { return nil }
                        return value
                    }
                )
            """
            casePathDecls.append(decl)
        }

        if casePathDecls.isEmpty {
            return []
        }

        let extensionDecl = try ExtensionDeclSyntax("extension \(type)") {
            try EnumDeclSyntax("\(raw: access) enum Cases") {
                for decl in casePathDecls {
                    DeclSyntax(stringLiteral: decl)
                }
            }
        }

        return [extensionDecl]
    }
}

enum MacroError: Error, CustomStringConvertible {
    case onlyApplicableToEnums

    var description: String {
        switch self {
        case .onlyApplicableToEnums:
            return "@CasePathable can only be applied to enums."
        }
    }
}
