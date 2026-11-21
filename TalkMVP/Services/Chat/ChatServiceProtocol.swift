//
//  Copyright © 2025–2026 David Song. All rights reserved.
//

import Foundation
import SwiftData

protocol ChatServiceProtocol: AnyObject {
    func sendMessage(_ message: Message, to chatRoom: ChatRoom)
    func markAsRead(chatRoom: ChatRoom)
    func editMessage(_ message: Message, in chatRoom: ChatRoom)
    func deleteMessage(_ message: Message, in chatRoom: ChatRoom)
}
