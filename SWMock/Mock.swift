//
//  Mock.swift
//  SWMock
//
//  Created by Łukasz Przytuła on 03/03/2019.
//  Copyright © 2019 Mildware. All rights reserved.
//

import Foundation

protocol CallRecorderDelegate: class {
    @discardableResult
    func called<T>(function: String, with args: KeyValuePairs<String, Any?>) -> T
    @discardableResult
    func called(function: String, with args: KeyValuePairs<String, Any?>) -> Any?
}

@dynamicCallable
class CallRecorder {

    let functionName: String
    weak var delegate: CallRecorderDelegate!

    init(functionName: String) {
        self.functionName = functionName
    }

    @discardableResult
    func dynamicallyCall<T>(withKeywordArguments args: KeyValuePairs<String, Any?>) -> T {
        return delegate.called(function: functionName, with: args)
    }

    @discardableResult
    func dynamicallyCall(withKeywordArguments args: KeyValuePairs<String, Any?>) -> Any? {
        return delegate.called(function: functionName, with: args)
    }


}

@dynamicMemberLookup
class Mock {

    var calls: [(function: String, arguments: KeyValuePairs<String, Any?>)] = []
    var functionsReturnValues: [String: Any] = [:]
    var propertiesValues: [String: Any] = [:]

    subscript<T>(dynamicMember input: String) -> T {
        get {
            if T.self == Bool.self, let range = input.range(of: "Called") {
                var functionName = input
                functionName.removeSubrange(range)
                return called(function: functionName) as! T
            }
            print(input, T.self)
            return propertiesValues[input]! as! T
        }
        set {
            propertiesValues[input] = newValue
        }
    }

    subscript(dynamicMember input: String) -> CallRecorder {
        let callRecorder = CallRecorder(functionName: input)
        callRecorder.delegate = self
        return callRecorder
    }

    func called(function: String, with args: [Any?]? = nil, times: Int? = nil) -> Bool {
        let count = countOfCalls(of: function, with: args)
        if let times = times {
            return count == times
        }
        return count > 0
    }

    private func countOfCalls(of function: String, with args: [Any?]? = nil) -> Int {
        guard let args = args else {
            return calls.count(where: { $0.function == function })
        }
        return calls.count(where: {
            guard $0.function == function else {
                return false
            }
            let callArgs: [Any?] = $0.arguments.map { $0.value }
            return String(describing: callArgs) == String(describing: args)
        })
    }

}

extension Mock: CallRecorderDelegate {

    func called(function: String, with args: KeyValuePairs<String, Any?>) -> Any? {
        calls.append((function: function, arguments: args))
        let returnValue = functionsReturnValues[function]
        print(function, args, type(of: returnValue))
        return returnValue
    }

    func called<T>(function: String, with args: KeyValuePairs<String, Any?>) -> T {
        calls.append((function: function, arguments: args))
        let returnValue = functionsReturnValues[function] as! T
        print(function, args, type(of: returnValue))
        return returnValue
    }

}
