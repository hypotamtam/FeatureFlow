import FeatureFlow

struct SearchState: State {
    var query = ""
    var results: [String] = []
    var isSearching = false
}

@CasePathable
enum SearchAction: Action {
    case queryChanged(String)
    case searchResponse([String])
}
