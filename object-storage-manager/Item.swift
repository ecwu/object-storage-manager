//
//  Item.swift
//  object-storage-manager
//
//  Created by Zhenghao Wu on 2025/11/28.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
