//
//  AnchorTolerancesTests.swift
//  Yams
//
//  Created by Adora Lynch on 9/18/24.
//  Copyright (c) 2024 Yams. All rights reserved.
//

import Foundation
import XCTest
import Yams

class AnchorTolerancesTests: XCTestCase {

    struct Example: Codable, Hashable {
        var myCustomAnchorDeclaration: Anchor
        var extraneousValue: Int
    }

    /// Any type that is Encodable and contains an `Anchor`value but with a coding key different from
    /// YamlAnchorProviding will not encode to a yaml anchor
    /// This may be unexpected
    func testAnchorEncoding_undeclaredBehavior() throws {
        let expectedYAML = """
                           myCustomAnchorDeclaration: I-did-it-myyyyy-way
                           extraneousValue: 3

                           """

        let value = Example(myCustomAnchorDeclaration: "I-did-it-myyyyy-way",
                            extraneousValue: 3)

        let encoder = YAMLEncoder()
        let producedYAML = try encoder.encode(value)
        XCTAssertEqual(producedYAML, expectedYAML, "Produced YAML not identical to expected YAML.")
    }

    /// Any type that is Encodable and contains an `Anchor`value with the same coding key as
    /// YamlAnchorProviding will encode to a yaml anchor even though the type does not conform to
    /// YamlAnchorProviding
    /// This may be unexpected
    func testAnchorEncoding_undeclaredBehavior_7() throws {
        struct Example: Codable, Hashable {
            var yamlAnchor: Anchor
            var extraneousValue: Int
        }

        let expectedYAML = """
                           &I-did-it-myyyyy-way
                           extraneousValue: 3

                           """

        let value = Example(yamlAnchor: "I-did-it-myyyyy-way",
                            extraneousValue: 3)

        let encoder = YAMLEncoder()
        let producedYAML = try encoder.encode(value)
        XCTAssertEqual(producedYAML, expectedYAML, "Produced YAML not identical to expected YAML.")
    }

    /// Any type that is Decodable and contains an `Anchor` value but with a coding key different from
    /// YamlAnchorProviding will not decode an anchor from the text representation.
    /// In this case a key not found error will be thrown during decoding
    /// This may be unexpected
    func testAnchorDecoding_undeclaredBehavior_1() throws {
        let sourceYAML = """
                           &a-different-tag
                           extraneousValue: 3
                           """
        let decoder = YAMLDecoder()
        XCTAssertThrowsError(try decoder.decode(Example.self, from: sourceYAML))
        // error is ^^ key not found, "myCustomAnchorDeclaration"
    }

    /// Any type that is Decodable and contains an `Anchor` value but with a coding key different from
    /// YamlAnchorProviding will not decode an anchor from the text representation.
    /// In this case the decoding is successful and the anchor is respected by the parser.
    /// This may be unexpected
    func testAnchorDecoding_undeclaredBehavior_6() throws {
        struct Example: Codable, Hashable {
            var myCustomAnchorDeclaration: Anchor?
            var extraneousValue: Int
        }
        let sourceYAML = """
                           &a-different-tag
                           extraneousValue: 3

                           """

        let expectedValue = Example(myCustomAnchorDeclaration: nil,
                                    extraneousValue: 3)

        let decoder = YAMLDecoder()
        let decodedValue = try decoder.decode(Example.self, from: sourceYAML)
        XCTAssertEqual(decodedValue, expectedValue, "\(Example.self) did not round-trip to an equal value.")
    }

    /// Any type that is Decodable and contains an `Anchor` value with the same coding key as
    /// YamlAnchorProviding will decode an anchor from the text representation even though the type does
    /// not conform to YamlAnchorCoding
    /// This may be unexpected
    func testAnchorDecoding_undeclaredBehavior_8() throws {
        struct Example: Codable, Hashable {
            var yamlAnchor: Anchor?
            var extraneousValue: Int
        }
        let sourceYAML = """
                           &a-different-tag
                           extraneousValue: 3

                           """

        let expectedValue = Example(yamlAnchor: "a-different-tag",
                                    extraneousValue: 3)

        let decoder = YAMLDecoder()
        let decodedValue = try decoder.decode(Example.self, from: sourceYAML)
        XCTAssertEqual(decodedValue, expectedValue, "\(Example.self) did not round-trip to an equal value.")
    }

    /// Any type that is Decodable and contains an `Anchor` value but with a coding key different from
    /// YamlAnchorProviding will not decode an anchor from the text representation.
    /// In this case the decoding is successful and the anchor is respected by the parser.
    /// This is expected behavior, but in a strange situation.
    func testAnchorDecoding_undeclaredBehavior_3() throws {
        let sourceYAML = """
                           &a-different-tag
                           extraneousValue: 3
                           myCustomAnchorDeclaration: deliver-us-from-evil

                           """
        let expectedValue = Example(myCustomAnchorDeclaration: "deliver-us-from-evil",
                                    extraneousValue: 3)

        let decoder = YAMLDecoder()
        let decodedValue = try decoder.decode(Example.self, from: sourceYAML)
        XCTAssertEqual(decodedValue, expectedValue, "\(Example.self) did not round-trip to an equal value.")

    }

    /// Any type that is Decodable and contains an `Anchor` value but with a coding key different from
    /// YamlAnchorProviding will not decode an anchor from the text representation.
    /// In this case the decoding is successful even though and the `Anchor` was initialized with
    /// unsupported characters. The anchor is respected by the parser.
    /// This is expected behavior, but in a strange situation.
    func testAnchorDecoding_undeclaredBehavior_2() throws {
        let sourceYAML = """
                           &a-different-tag
                           extraneousValue: 3
                           myCustomAnchorDeclaration: "deliver us from |()evil"

                           """

        let expectedValue = Example(myCustomAnchorDeclaration: "deliver us from |()evil",
                                    extraneousValue: 3)

        let decoder = YAMLDecoder()
        let decodedValue = try decoder.decode(Example.self, from: sourceYAML)
        XCTAssertEqual(decodedValue, expectedValue, "\(Example.self) did not round-trip to an equal value.")

    }

}

final class ParserAnchoredKeyTests: XCTestCase, @unchecked Sendable {
    func testAliasKeyCompositionPreservesMetadata() throws {
        let depth = aliasKeyDepth
        let yaml = aliasKeyYAML(depth: depth, key: "*n\(depth)")
        if depth == 25 {
            // The observed Core regression's complete prompt is 686 bytes.
            XCTAssertEqual(("---\n" + yaml + "\n---\nBody").utf8.count, 686)
        }

        let parser = try Parser(yaml: yaml, duplicateKeyPolicy: .deferAnchoredKeys)
        let root = try XCTUnwrap(parser.singleRoot())
        try withExtendedLifetime(parser) {
            let mapping = try XCTUnwrap(root.mapping)
            XCTAssertEqual(mapping.count, depth + 2)
            let pair = try XCTUnwrap(mapping.suffix(1).first)
            XCTAssertEqual(pair.value.string, "key-value")
            XCTAssertEqual(pair.key.anchor?.rawValue, "n\(depth)")
            let sequence = try XCTUnwrap(pair.key.sequence)
            XCTAssertEqual(sequence.count, 2)
            XCTAssertEqual(sequence[0].anchor?.rawValue, "n\(depth - 1)")
            XCTAssertEqual(sequence[1].anchor?.rawValue, "n\(depth - 1)")
            XCTAssertEqual(pair.key.mark?.line, depth + 1)
        }
    }

    func testNestedAliasKeysCompositionPreservesMetadata() throws {
        let depth = aliasKeyDepth
        let alias = "*n\(depth)"
        let cases: [(String, (Node) throws -> Node)] = [
            ("[ordinary, [\(alias)]]", { try XCTUnwrap($0.sequence?[1].sequence?.first) }),
            ("{ \(alias) : ordinary }", { try XCTUnwrap($0.mapping?.first?.key) }),
            ("{ outer: { inner: \(alias) } }", { try XCTUnwrap($0.mapping?.first?.value.mapping?.first?.value) })
        ]
        for (key, anchoredNode) in cases {
            let yaml = aliasKeyYAML(depth: depth, key: key)
            let parser = try Parser(yaml: yaml, duplicateKeyPolicy: .deferAnchoredKeys)
            let root = try XCTUnwrap(parser.singleRoot())
            try withExtendedLifetime(parser) {
                let mapping = try XCTUnwrap(root.mapping)
                XCTAssertEqual(mapping.count, depth + 2)
                let pair = try XCTUnwrap(mapping.suffix(1).first)
                XCTAssertNil(pair.key.anchor)
                XCTAssertEqual(pair.value.string, "key-value")
                let node = try anchoredNode(pair.key)
                XCTAssertEqual(node.anchor?.rawValue, "n\(depth)")
                XCTAssertEqual(node.sequence?.count, 2)
                XCTAssertEqual(node.mark?.line, depth + 1)
            }
        }
    }

    func testOnlyComparisonsInvolvingAnchoredKeysAreDeferred() throws {
        let keys = [
            ("&key shared", "shared", "*key"),
            ("&key [shared]", "[shared]", "*key"),
            ("&key {nested: shared}", "{nested: shared}", "*key"),
            ("[ordinary, &key shared]", "[ordinary, shared]", "[ordinary, *key]"),
            ("{ &key shared : ordinary }", "{ shared: ordinary }", "{ *key : ordinary }"),
            ("{ ordinary: &key shared }", "{ ordinary: shared }", "{ ordinary: *key }")
        ]
        for (anchored, ordinary, aliased) in keys {
            let yaml = "? \(anchored)\n: first\n? \(ordinary)\n: second\n? \(aliased)\n: third"
            assertDuplicateKeys(yaml, policy: .checkAll)
            let parser = try Parser(yaml: yaml, duplicateKeyPolicy: .deferAnchoredKeys)
            let root = try XCTUnwrap(parser.singleRoot())
            withExtendedLifetime(parser) {
                XCTAssertEqual(root.mapping?.count, 3)
                XCTAssertEqual(root.mapping?.map { $0.value.string }, ["first", "second", "third"])
            }
        }
    }

    func testUnanchoredDuplicatesAreStillRejected() {
        let sources = [
            "a: first\na: second",
            "? [a, b]\n: first\n? [a, b]\n: second",
            "? {a: b}\n: first\n? {a: b}\n: second",
            "&root {a: first, a: second}",
            "? [&key {a: first, a: second}]\n: value",
            "? &key [shared]\n: value\na: first\na: second",
            "a: &value [shared]\na: *value",
            "'&literal': first\n'&literal': second"
        ]
        for yaml in sources {
            let expected = assertDuplicateKeys(yaml, policy: .checkAll)
            XCTAssertEqual(assertDuplicateKeys(yaml, policy: .deferAnchoredKeys), expected)
        }
    }

    func testScalarAliasesAndAnchorShadowingAreUnchanged() throws {
        let yaml = """
            first: &shared old
            firstAlias: *shared
            second: &shared new
            secondAlias: *shared
            ? *shared
            : alias-key-value
            """
        for policy in [Parser.DuplicateKeyPolicy.checkAll, .deferAnchoredKeys] {
            let parser = try Parser(yaml: yaml, duplicateKeyPolicy: policy)
            let root = try XCTUnwrap(parser.singleRoot())
            try withExtendedLifetime(parser) {
                let mapping = try XCTUnwrap(root.mapping)
                XCTAssertEqual(mapping.map { $0.value.string }, ["old", "old", "new", "new", "alias-key-value"])
                let oldAnchor = try XCTUnwrap(mapping[0].value.anchor)
                let newAnchor = try XCTUnwrap(mapping[2].value.anchor)
                XCTAssertEqual(oldAnchor.rawValue, "shared")
                XCTAssertEqual(newAnchor.rawValue, "shared")
                XCTAssertFalse(oldAnchor === newAnchor)
                XCTAssertTrue(mapping[1].value.anchor === oldAnchor)
                XCTAssertTrue(mapping[3].value.anchor === newAnchor)
                XCTAssertTrue(mapping[4].key.anchor === newAnchor)
                XCTAssertEqual(mapping[4].key.scalar?.string, "new")
                XCTAssertEqual(mapping[4].key.mark?.line, 3)
            }
        }
    }

    func testPolicyIsLocalToEachParser() throws {
        let yaml = "? &key shared\n: first\nshared: second"
        let defaultParser = try Parser(yaml: yaml)
        let deferredParser = try Parser(yaml: yaml + "\n---\n" + yaml, duplicateKeyPolicy: .deferAnchoredKeys)
        XCTAssertEqual(try deferredParser.nextRoot()?.mapping?.count, 2)
        XCTAssertThrowsError(try defaultParser.singleRoot())
        XCTAssertEqual(try deferredParser.nextRoot()?.mapping?.count, 2)
        XCTAssertNil(try deferredParser.nextRoot())
        XCTAssertThrowsError(try Parser(yaml: yaml).singleRoot())
        XCTAssertThrowsError(try Yams.compose(yaml: yaml))
    }

    func testDataInitializerPassesThePolicyForBothEncodings() throws {
        let yaml = "? &key shared\n: first\nshared: second"
        for encoding in [Parser.Encoding.utf8, .utf16] {
            let data = try XCTUnwrap(yaml.data(using: encoding.swiftStringEncoding))
            XCTAssertThrowsError(try Parser(yaml: data, encoding: encoding).singleRoot())
            let parser = try Parser(yaml: data, encoding: encoding, duplicateKeyPolicy: .deferAnchoredKeys)
            let root = try XCTUnwrap(parser.singleRoot())
            withExtendedLifetime(parser) {
                XCTAssertEqual(root.mapping?.count, 2)
                XCTAssertEqual(root.mapping?.first?.key.anchor?.rawValue, "key")
            }
        }
    }

    func testLiteralMarkersAndOrderedMetadataAreUnchanged() throws {
        let yaml = """
            quoted: "&anchor *alias #literal"
            single: '*alias &anchor #literal'
            plain: middle&anchor middle*alias &anchor *alias
            literal: |
              &anchor
              *alias
              #literal
            folded: >
              &anchor
              *alias
            tagged: !!str "*alias &anchor"
            nonspecific: ! '&anchor *alias'
            # &anchor *alias
            future: !future {z: last, a: first}
            """
        let marker = Tag.Name(rawValue: "tag:test:plain")
        let resolver = Resolver.basic.appending(try Resolver.Rule(marker, "^[\\s\\S]*$"))
        let expected = try Parser(yaml: yaml, resolver: resolver).singleRoot()
        let parser = try Parser(yaml: yaml, resolver: resolver, duplicateKeyPolicy: .deferAnchoredKeys)
        let root = try XCTUnwrap(parser.singleRoot())
        XCTAssertEqual(root, expected)
        let mapping = try XCTUnwrap(root.mapping)
        XCTAssertEqual(mapping.map { $0.key.string },
                       ["quoted", "single", "plain", "literal", "folded", "tagged", "nonspecific", "future"])
        XCTAssertEqual(mapping[0].value.scalar?.style, .doubleQuoted)
        XCTAssertEqual(mapping[1].value.scalar?.style, .singleQuoted)
        XCTAssertEqual(mapping[2].value.scalar?.string, "middle&anchor middle*alias &anchor *alias")
        XCTAssertEqual(mapping[2].value.tag.rawValue, marker.rawValue)
        XCTAssertEqual(mapping[3].value.scalar?.string, "&anchor\n*alias\n#literal\n")
        XCTAssertEqual(mapping[4].value.scalar?.string, "&anchor *alias\n")
        XCTAssertEqual(mapping[5].value.tag.rawValue, Tag.Name.str.rawValue)
        XCTAssertEqual(mapping[7].value.tag.rawValue, "!future")
        XCTAssertEqual(mapping[7].value.mapping?.map { $0.key.string }, ["z", "a"])
        XCTAssertTrue(mapping.allSatisfy { $0.key.anchor == nil && $0.value.anchor == nil })
    }

    func testMalformedUndefinedAndRecursiveAliasesKeepTheirErrors() {
        let sources = ["[&key value,", "*missing", "&cycle [*cycle]", "&cycle {self: *cycle}"]
        for yaml in sources {
            var expected = ""
            XCTAssertThrowsError(try Parser(yaml: yaml).singleRoot()) { expected = "\($0)" }
            XCTAssertThrowsError(try Parser(yaml: yaml, duplicateKeyPolicy: .deferAnchoredKeys).singleRoot()) {
                XCTAssertTrue($0 is YamlError)
                XCTAssertEqual("\($0)", expected)
            }
        }
    }

    private var aliasKeyDepth: Int {
        // Run large depths only with an external process deadline, for example:
        // YAMS_TEST_ALIAS_KEY_DEPTH=25 timeout 10 <xctest> YamsTests.ParserAnchoredKeyTests
        // Ordinary suites stay safe even if expanded-key hashing regresses.
        return Int(ProcessInfo.processInfo.environment["YAMS_TEST_ALIAS_KEY_DEPTH"] ?? "8") ?? 8
    }

    private func aliasKeyYAML(depth: Int, key: String) -> String {
        var entries = ["seed: &n0 [value]"]
        for index in 1...depth {
            entries.append("level\(index): &n\(index) [*n\(index - 1), *n\(index - 1)]")
        }
        entries.append("? \(key)\n: key-value")
        return entries.joined(separator: "\n")
    }

    @discardableResult
    private func assertDuplicateKeys(_ yaml: String, policy: Parser.DuplicateKeyPolicy,
                                     file: StaticString = #filePath, line: UInt = #line) -> String {
        var diagnostic = ""
        XCTAssertThrowsError(try Parser(yaml: yaml, duplicateKeyPolicy: policy).singleRoot(), file: file, line: line) {
            diagnostic = "\($0)"
            guard case .duplicatedKeysInMapping? = $0 as? YamlError else {
                XCTFail("Expected duplicate keys, got \($0)", file: file, line: line)
                return
            }
        }
        return diagnostic
    }
}
