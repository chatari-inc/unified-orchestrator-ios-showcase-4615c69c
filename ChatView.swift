// filepath: ChatView.swift

import SwiftUI
import Foundation

struct Message: Identifiable, Codable {
    let id = UUID()
    let content: String
    let senderID: String
    let senderName: String
    let timestamp: Date
    let type: MessageType
    let status: MessageStatus
    let replyToID: UUID?
    
    var isFromCurrentUser: Bool {
        senderID == "current-user"
    }
}

enum MessageType: String, Codable {
    case text
    case image
    case system
}

enum MessageStatus: String, Codable {
    case sending
    case sent
    case delivered
    case read
}

struct Chat: Identifiable, Codable {
    let id = UUID()
    let participants: [User]
    let messages: [Message]
    let lastMessage: Message?
    let isTyping: [String: Bool]
    let createdAt: Date
    let updatedAt: Date
}

struct User: Identifiable, Codable {
    let id: String
    let name: String
    let avatar: String
}

enum ConnectionStatus {
    case connected
    case connecting
    case disconnected
}

class ChatManager: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isTyping: [String: Bool] = [:]
    @Published var connectionStatus: ConnectionStatus = .connected
    @Published var typingUsers: [String] = []
    
    private var timer: Timer?
    
    init() {
        loadSampleMessages()
        simulateTyping()
    }
    
    func connect() {
        connectionStatus = .connecting
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.connectionStatus = .connected
        }
    }
    
    func disconnect() {
        connectionStatus = .disconnected
        timer?.invalidate()
    }
    
    func sendMessage(_ content: String, replyTo: Message? = nil) {
        let message = Message(
            content: content,
            senderID: "current-user",
            senderName: "You",
            timestamp: Date(),
            type: .text,
            status: .sending,
            replyToID: replyTo?.id
        )
        
        messages.append(message)
        
        // Simulate message delivery
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let index = self.messages.firstIndex(where: { $0.id == message.id }) {
                self.messages[index] = Message(
                    content: message.content,
                    senderID: message.senderID,
                    senderName: message.senderName,
                    timestamp: message.timestamp,
                    type: message.type,
                    status: .sent,
                    replyToID: message.replyToID
                )
            }
        }
        
        // Simulate response
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.simulateResponse(to: content)
        }
    }
    
    func sendTypingIndicator(isTyping: Bool) {
        if isTyping {
            typingUsers.append("other-user")
        } else {
            typingUsers.removeAll { $0 == "other-user" }
        }
    }
    
    private func loadSampleMessages() {
        messages = [
            Message(
                content: "Hey! How's it going?",
                senderID: "other-user",
                senderName: "Alex",
                timestamp: Date().addingTimeInterval(-3600),
                type: .text,
                status: .read,
                replyToID: nil
            ),
            Message(
                content: "I'm doing great! Just working on some SwiftUI projects.",
                senderID: "current-user",
                senderName: "You",
                timestamp: Date().addingTimeInterval(-3500),
                type: .text,
                status: .read,
                replyToID: nil
            ),
            Message(
                content: "That sounds awesome! SwiftUI is such a powerful framework.",
                senderID: "other-user",
                senderName: "Alex",
                timestamp: Date().addingTimeInterval(-3400),
                type: .text,
                status: .read,
                replyToID: nil
            ),
            Message(
                content: "Alex joined the chat",
                senderID: "system",
                senderName: "System",
                timestamp: Date().addingTimeInterval(-3700),
                type: .system,
                status: .read,
                replyToID: nil
            )
        ]
    }
    
    private func simulateResponse(to message: String) {
        let responses = [
            "That's interesting!",
            "I see what you mean.",
            "Sounds good to me!",
            "Let me think about that...",
            "Great idea!",
            "I totally agree.",
            "That makes sense."
        ]
        
        let response = Message(
            content: responses.randomElement() ?? "Cool!",
            senderID: "other-user",
            senderName: "Alex",
            timestamp: Date(),
            type: .text,
            status: .sent,
            replyToID: nil
        )
        
        messages.append(response)
    }
    
    private func simulateTyping() {
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { _ in
            self.typingUsers.append("other-user")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.typingUsers.removeAll { $0 == "other-user" }
            }
        }
    }
}

struct MessageBubble: View {
    let message: Message
    let isFromCurrentUser: Bool
    @State private var reactions: [String: Int] = [:]
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer(minLength: 50)
                messageContent
                    .background(Color.blue)
                    .foregroundColor(.white)
            } else {
                if message.type != .system {
                    AsyncImage(url: URL(string: "https://via.placeholder.com/30")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 30, height: 30)
                    .clipShape(Circle())
                }
                
                messageContent
                    .background(message.type == .system ? Color.clear : Color.gray.opacity(0.2))
                    .foregroundColor(message.type == .system ? .secondary : .primary)
                
                Spacer(minLength: 50)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: message.type == .system ? 0 : 16))
        .contextMenu {
            Button("Copy") {
                UIPasteboard.general.string = message.content
            }
            
            Button("Reply") {
                // Reply action
            }
            
            Button("React") {
                addReaction("❤️")
            }
        }
    }
    
    private var messageContent: some View {
        VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
            if message.type == .system {
                Text(message.content)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Capsule())
            } else {
                if !isFromCurrentUser {
                    Text(message.senderName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                }
                
                Text(message.content)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .accessibilityLabel("Message from \(message.senderName): \(message.content)")
                
                HStack {
                    if !reactions.isEmpty {
                        MessageReactions(reactions: reactions) { emoji in
                            addReaction(emoji)
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text(message.timestamp.formatted(.dateTime.hour().minute()))
                            .font(.caption2)
                            .opacity(0.7)
                        
                        if isFromCurrentUser {
                            Image(systemName: statusIcon)
                                .font(.caption2)
                                .opacity(0.7)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
            }
        }
    }
    
    private var statusIcon: String {
        switch message.status {
        case .sending:
            return "clock"
        case .sent:
            return "checkmark"
        case .delivered:
            return "checkmark.circle"
        case .read:
            return "checkmark.circle.fill"
        }
    }
    
    private func addReaction(_ emoji: String) {
        reactions[emoji, default: 0] += 1
    }
}

struct MessageReactions: View {
    let reactions: [String: Int]
    let onReact: (String) -> Void
    
    var body: some View {
        HStack {
            ForEach(Array(reactions.keys), id: \.self) { emoji in
                Button(action: { onReact(emoji) }) {
                    Text("\(emoji) \(reactions[emoji] ?? 0)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
        }
    }
}

struct ReplyPreview: View {
    let originalMessage: Message
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Replying to \(originalMessage.senderName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(originalMessage.content)
                    .font(.body)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct TypingIndicator: View {
    let typingUsers: [String]
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack {
            if !typingUsers.isEmpty {
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 8, height: 8)
                            .offset(y: animationOffset)
                            .animation(
                                Animation.easeInOut(duration: 0.6)
                                    .repeatForever()
                                    .delay(Double(index) * 0.2),
                                value: animationOffset
                            )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .onAppear {
                    animationOffset = -3
                }
                .onDisappear {
                    animationOffset = 0
                }
            }
            
            Spacer()
        }
        .padding(.horizontal)
    }
}

struct ConnectionStatusBar: View {
    let status: ConnectionStatus
    
    var body: some View {
        if status != .connected {
            HStack {
                Image(systemName: status == .connecting ? "wifi.slash" : "exclamationmark.triangle")
                    .foregroundColor(.white)
                
                Text(status == .connecting ? "Connecting..." : "No Internet Connection")
                    .foregroundColor(.white)
                    .font(.caption)
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .background(status == .connecting ? Color.orange : Color.red)
        }
    }
}

struct ChatView: View {
    @StateObject private var chatManager = ChatManager()
    @State private var messageText = ""
    @State private var isTyping = false
    @State private var replyingTo: Message?
    @State private var showingImagePicker = false
    @State private var typingTimer: Timer?
    
    var body: some View {
        VStack(spacing: 0) {
            ConnectionStatusBar(status: chatManager.connectionStatus)
            
            messageList
            
            if let replyMessage = replyingTo {
                ReplyPreview(originalMessage: replyMessage) {
                    replyingTo = nil
                }
                .padding(.horizontal)
            }
            
            TypingIndicator(typingUsers: chatManager.typingUsers)
            
            inputBar
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(
            trailing: Button(action: {
                showingImagePicker = true
            }) {
                Image(systemName: "camera")
            }
        )
        .onAppear {
            chatManager.connect()
        }
        .onDisappear {
            chatManager.disconnect()
        }
        .sheet(isPresented: $showingImagePicker) {
            Text("Image Picker")
        }
        .onTapGesture {
            hideKeyboard()
        }
    }
    
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(chatManager.messages) { message in
                        MessageBubble(
                            message: message,
                            isFromCurrentUser: message.isFromCurrentUser
                        )
                        .id(message.id)
                        .onLongPressGesture {
                            if message.type != .system {
                                replyingTo = message
                            }
                        }
                    }
                }
                .padding()
            }
            .onAppear {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: chatManager.messages.count) { _ in
                scrollToBottom(proxy: proxy)
            }
            .refreshable {
                // Load more messages
            }
        }
    }
    
    private var inputBar: some View {
        HStack(spacing: 12) {
            Button(action: {
                showingImagePicker = true
            }) {
                Image(systemName: "plus")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            
            TextField("Type a message...", text: $messageText, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(1...5)
                .onChange(of: messageText) { newValue in
                    handleTyping()
                }
                .onSubmit {
                    sendMessage()
                }
            
            Button(action: sendMessage) {
                Image(systemName: "paperplane.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.gray.opacity(0.3)),
            alignment: .top
        )
    }
    
    private func sendMessage() {
        let trimmedText = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        chatManager.sendMessage(trimmedText, replyTo: replyingTo)
        messageText = ""
        replyingTo = nil
        
        // Stop typing indicator
        typingTimer?.invalidate()
        chatManager.sendTypingIndicator(isTyping: false)
        isTyping = false
    }
    
    private func handleTyping() {
        if !isTyping && !messageText.isEmpty {
            isTyping = true
            chatManager.sendTypingIndicator(isTyping: true)
        }
        
        typingTimer?.invalidate()
        typingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            isTyping = false
            chatManager.sendTypingIndicator(isTyping: false)
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewReader) {
        if let lastMessage = chatManager.messages.last {
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ChatView()
        }
    }
}