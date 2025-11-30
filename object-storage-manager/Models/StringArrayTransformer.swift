//
//  StringArrayTransformer.swift
//  object-storage-manager
//
//  Created by Codex on 2024/11/28.
//

import Foundation

/// Secure transformer for storing `[String]` in SwiftData.
/// Uses JSON for new values and can fall back to unarchiving older entries.
@objc(StringArrayTransformer)
final class StringArrayTransformer: ValueTransformer {
    override class func transformedValueClass() -> AnyClass { NSData.self }

    override class func allowsReverseTransformation() -> Bool {
        true
    }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let strings = value as? [String] else { return nil }
        return try? JSONEncoder().encode(strings)
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else { return [] }

        // Preferred path: decode JSON
        if let decoded = try? JSONDecoder().decode([String].self, from: data) {
            return decoded
        }

        // Fallback: decode legacy keyed archive data
        let allowed: [AnyClass] = [NSArray.self, NSString.self]
        if let legacy = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: allowed, from: data) as? [String] {
            return legacy
        }

        return []
    }
}
