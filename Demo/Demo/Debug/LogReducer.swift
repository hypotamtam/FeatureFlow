//
//  LogReducer.swift
//  UDF-Example
//
//  Created by Thomas Cassany on 12/03/2026.
//

import FeatureFlow

func createLogReducer<State: FeatureFlow.State, Action: Sendable>() -> Flow<State, Action> {
    .init { state, action in
        print("---- Send ----")
        dump(action, name: "Action")
        dump(state, name: "State")
        print("--------------")
        return .result(state)
    }
}
