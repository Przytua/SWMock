//
//  Mock.swift
//  SWMock
//
//  Created by Łukasz Przytuła on 03/03/2019.
//  Copyright © 2019 Mildware. All rights reserved.
//

import Foundation
import XCTest

public class FunctionCallRecord {
    let name: String
    let arguments: KeyValuePairs<String, Any?>

    init(name: String, arguments: KeyValuePairs<String, Any?>) {
        self.name = name
        self.arguments = arguments
    }
}

protocol MockFunctionCallVerifierDelegate: class {
    func calls(of function: String, with args: KeyValuePairs<String, Any?>) -> [FunctionCallRecord]
}

@dynamicCallable
class MockFunctionCallVerifier {

    let functionName: String
    weak var delegate: MockFunctionCallVerifierDelegate!

    init(functionName: String) {
        self.functionName = functionName
    }

    func dynamicallyCall(withKeywordArguments args: KeyValuePairs<String, Any?>) -> Bool {
        let calls = delegate.calls(of: functionName, with: args)
        return !calls.isEmpty
    }

}

@dynamicMemberLookup
class MockVerifier {

    weak var delegate: MockFunctionCallVerifierDelegate!

    subscript(dynamicMember input: String) -> MockFunctionCallVerifier {
        let callVerifier = MockFunctionCallVerifier(functionName: input)
        callVerifier.delegate = delegate
        return callVerifier
    }

}

protocol MockFunctionCallRecorderDelegate: class {
    @discardableResult
    func called<T>(function: String, with args: KeyValuePairs<String, Any?>) -> T
    @discardableResult
    func called(function: String, with args: KeyValuePairs<String, Any?>) -> Any?
}

@dynamicCallable
class MockFunctionCallRecorder {

    let functionName: String
    weak var delegate: MockFunctionCallRecorderDelegate!

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
public class Mock {

    var functionsReturnValues: [String: Any] = [:]
    var propertiesValues: [String: Any] = [:]
    private var calls: [FunctionCallRecord] = []
    private var verifier: MockVerifier
#if canImport(Nimble)
    private var expectationProvider: MockFunctionCallsExpectationProvider
#endif

    init() {
        verifier = MockVerifier()
#if canImport(Nimble)
        expectationProvider = MockFunctionCallsExpectationProvider()
#endif
        verifier.delegate = self
#if canImport(Nimble)
        expectationProvider.delegate = self
#endif
    }

    subscript<T>(dynamicMember input: String) -> T {
        get {
            if input == "verifier", let verifier = verifier as? T {
                return verifier
            }
            if input == "expectationProvider", let expectationProvider = expectationProvider as? T {
                return expectationProvider
            }
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

    subscript(dynamicMember input: String) -> MockFunctionCallRecorder {
        let callRecorder = MockFunctionCallRecorder(functionName: input)
        callRecorder.delegate = self
        return callRecorder
    }

}

extension Mock {

    public var callsCount: Int {
        return calls.count
    }

    public func called(function: String, with args: [Any?]? = nil, times: Int? = nil) -> Bool {
        let count = countOfCalls(of: function, with: args)
        if let times = times {
            return count == times
        }
        return count > 0
    }

    private func countOfCalls(of function: String, with args: [Any?]? = nil) -> Int {
        guard let args = args else {
            return calls.count(where: { $0.name == function })
        }
        return calls.count(where: {
            guard $0.name == function else {
                return false
            }
            let callArgs: [Any?] = $0.arguments.map { $0.value }
            return String(describing: callArgs) == String(describing: args)
        })
    }

}

extension Mock: MockFunctionCallRecorderDelegate {

    func called(function: String, with args: KeyValuePairs<String, Any?>) -> Any? {
        calls.append(FunctionCallRecord(name: function, arguments: args))
        let returnValue = functionsReturnValues[function]
        print(function, args, type(of: returnValue))
        return returnValue
    }

    func called<T>(function: String, with args: KeyValuePairs<String, Any?>) -> T {
        calls.append(FunctionCallRecord(name: function, arguments: args))
        let returnValue = functionsReturnValues[function] as! T
        print(function, args, type(of: returnValue))
        return returnValue
    }

}

extension Mock: MockFunctionCallVerifierDelegate {

    func calls(of function: String, with args: KeyValuePairs<String, Any?>) -> [FunctionCallRecord] {
        guard !args.isEmpty else {
            return calls.filter({ $0.name == function })
        }
        return calls.filter({
            guard $0.name == function else {
                return false
            }
            return String(describing: $0.arguments) == String(describing: args)
        })
    }

}

func verify(_ mock: Mock) -> MockVerifier {
    return mock.verifier
}

#if canImport(Nimble)

import Nimble

protocol MockFunctionCallExpectationProviderDelegate: class {
    func calls(of function: String, with args: KeyValuePairs<String, Any?>) -> [FunctionCallRecord]
}

extension Mock: MockFunctionCallExpectationProviderDelegate {}

@dynamicCallable
public class MockFunctionCallExpectationProvider {

    let functionName: String
    weak var delegate: MockFunctionCallExpectationProviderDelegate!
    var location: (file: FileString, line: UInt)?

    init(functionName: String) {
        self.functionName = functionName
    }

    func dynamicallyCall(withKeywordArguments args: KeyValuePairs<String, Any?>) -> Expectation<[FunctionCallRecord]> {
        let calls = delegate.calls(of: functionName, with: args)
        return expect(calls, file: self.location?.file ?? "Unknown file", line: self.location?.line ?? 0)
    }

}

@dynamicMemberLookup
public class MockFunctionCallsExpectationProvider {

    weak var delegate: MockFunctionCallExpectationProviderDelegate!
    var currentLocation: (FileString, UInt)?

    subscript(dynamicMember input: String) -> MockFunctionCallExpectationProvider {
        let expectationProvider = MockFunctionCallExpectationProvider(functionName: input)
        expectationProvider.delegate = delegate
        expectationProvider.location = currentLocation
        return expectationProvider
    }

}

public func beCalled(times count: Int? = nil) -> Predicate<[FunctionCallRecord]> {
    let matcher: (Expression<[FunctionCallRecord]>) throws -> PredicateResult = { actualExpression in
        guard let actualValue = try actualExpression.evaluate() else {
            return PredicateResult(status: PredicateStatus(bool: false), message: .expectedTo("be called"))
        }
        if let count = count {
            return PredicateResult(status: PredicateStatus(bool: actualValue.count == count), message: .expectedTo("be called"))
        }
        return PredicateResult(status: PredicateStatus(bool: !actualValue.isEmpty), message: .expectedTo("be called"))
    }
    return Predicate<[FunctionCallRecord]>(matcher).requireNonNil
}

public func expectMock(_ mock: Mock, file: FileString = #file, line: UInt = #line) -> MockFunctionCallsExpectationProvider {
    (mock.expectationProvider as MockFunctionCallsExpectationProvider).currentLocation = (file, line)
    return mock.expectationProvider
}

#endif
