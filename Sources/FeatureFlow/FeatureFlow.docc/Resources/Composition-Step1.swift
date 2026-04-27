import Foundation
import FeatureFlow

struct AppState: State {
    var counter = CounterState()
    var editor: EditProfileState? = nil
}

@CasePathable
enum AppAction: Action, Equatable {
    case counterAction(CounterAction)
    case editorAction(EditProfileAction)
    
    case showEditor
    case dismissEditor
}
