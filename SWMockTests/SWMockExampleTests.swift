//
//  SWMockExampleTests.swift
//  SWMockExampleTests
//
//  Created by Łukasz Przytuła on 03/03/2019.
//  Copyright © 2019 Mildware. All rights reserved.
//

import XCTest
@testable import SWMock

protocol ExampleProtocol {
    var exampleProperty: Int { get }
    var exampleMutableProperty: Int { get set }
    func exampleFunctionWithoutArguments()
    func exampleFunction(with argument: String)
    func exampleFunctionWithReturnValue() -> Double
}

class ExampleProtocolMock: Mock, ExampleProtocol {

    var exampleProperty: Int {
        return super.exampleProperty
    }

    var exampleMutableProperty: Int {
        get {
            return super.exampleMutableProperty
        }
        set {
            super.exampleMutableProperty = newValue
        }
    }

    func exampleFunctionWithoutArguments() {
        super.exampleFunctionWithoutArguments()
    }

    func exampleFunction(with argument: String) {
        super.exampleFunction(with: argument)
    }

    func exampleFunctionWithReturnValue() -> Double {
        return super.exampleFunctionWithReturnValue() as! Double
    }

}

class ExampleProtocolUser {

    var protocolImplementation: ExampleProtocol

    var propertyValue: Int?
    var mutablePropertyValue: Int?
    var functionReturnValue: Double?

    init(with protocolImplementation: ExampleProtocol) {
        self.protocolImplementation = protocolImplementation
    }

    func use() {
        propertyValue = protocolImplementation.exampleProperty

        mutablePropertyValue = protocolImplementation.exampleMutableProperty

        protocolImplementation.exampleFunctionWithoutArguments()
        protocolImplementation.exampleFunctionWithoutArguments()

        protocolImplementation.exampleFunction(with: "example argument")
        protocolImplementation.exampleFunction(with: "another argument")

        functionReturnValue = protocolImplementation.exampleFunctionWithReturnValue()
    }

}

class SWMockExampleTests: XCTestCase {

    var exampleMock: ExampleProtocolMock!
    var protocolUser: ExampleProtocolUser!

    override func setUp() {
        super.setUp()

        let exampleMock = ExampleProtocolMock()

        exampleMock.propertiesValues["exampleProperty"] = Int(64)
        exampleMock.exampleMutableProperty = Int(32)

        exampleMock.functionsReturnValues["exampleFunctionWithReturnValue"] = Double(1.2345)

        self.exampleMock = exampleMock
        self.protocolUser = ExampleProtocolUser(with: exampleMock)
        
        protocolUser.use()
    }

    func testMockObject() {
        XCTAssert(protocolUser.propertyValue == 64)

        XCTAssert(protocolUser.mutablePropertyValue == 32)

        XCTAssert(exampleMock.exampleFunctionWithoutArgumentsCalled)
        XCTAssert(exampleMock.called(function: "exampleFunctionWithoutArguments", times: 2))

        XCTAssert(exampleMock.exampleFunctionCalled)
        XCTAssert(exampleMock.called(function: "exampleFunction", times: 2))
        XCTAssert(exampleMock.called(function: "exampleFunction", with: ["example argument"]))
        XCTAssert(exampleMock.called(function: "exampleFunction", with: ["example argument"], times: 1))
        XCTAssert(exampleMock.called(function: "exampleFunction", with: ["another argument"]))
        XCTAssert(exampleMock.called(function: "exampleFunction", with: ["another argument"], times: 1))

        XCTAssert(exampleMock.exampleFunctionWithReturnValueCalled)
        XCTAssert(protocolUser.functionReturnValue == 1.2345)

        XCTAssert(exampleMock.calls.count == 5)
    }

}
