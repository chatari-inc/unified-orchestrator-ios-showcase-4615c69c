// filepath: ChatView.swift

import SwiftUI
import Foundation

struct Message: Identifiable, Codable {
    let id: UUID
    let content: String
    let senderID: String
    let senderName: String
    let timestamp: Date
    let type: MessageType
    let status: MessageStatus
    let replyToID: UUID?
    let reactions: [String: Int]
    
    var isFromCurrentUser: Bool {
        senderID == "current_user"
    }
    
    init(content: String, senderID: String, senderName: String, type: MessageType = .text, replyToID: UUID? = nil) {
        self.id = UUID()
        self.content = content
        self.senderID = senderID
        self.senderName = senderName
        self.timestamp = Date()
        self.type = type
        self.status = .sent
        self.replyToID = replyToID
        self.reactions = [:]
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

enum ConnectionStatus {
    case connected
    case connecting
    case disconnected
}

struct User: Identifiable, Codable {
    let id: String
    let name: String
    let avatar: String
    let isOnline: Bool
}

class ChatManager: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isTyping: [String: Bool] = [:]
    @Published var connectionStatus: ConnectionStatus = .connected
    @Published var onlineUsers: [User] = []
    
    private var typingTimer: Timer?
    
    init() {
        loadSampleData()
    }
    
    func connect() {
        connectionStatus = .connecting
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.connectionStatus = .connected
        }
    }
    
    func disconnect() {
        connectionStatus = .disconnected
        typingTimer?.invalidate()
    }
    
    func sendMessage(_ message: Message) {
        messages.append(message)
        simulateTypingStop()
    }
    
    func sendTypingIndicator(isTyping: Bool) {
        if isTyping {
            simulateTypingStart()
        } else {
            simulateTypingStop()
        }
    }
    
    func addReaction(to messageID: UUID, emoji: String) {
        if let index = messages.firstIndex(where: { $0.id == messageID }) {
            var updatedMessage = messages[index]
            var reactions = updatedMessage.reactions
            reactions[emoji] = (reactions[emoji] ?? 0) + 1
            
            let newMessage = Message(
                content: updatedMessage.content,
                senderID: updatedMessage.senderID,
                senderName: updatedMessage.senderName,
                type: updatedMessage.type,
                replyToID: updatedMessage.replyToID
            )
            
            messages[index] = newMessage
        }
    }
    
    private func simulateTypingStart() {
        isTyping["other_user"] = true
        
        typingTimer?.invalidate()
        typingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            self.simulateTypingStop()
            self.simulateIncomingMessage()
        }
    }
    
    private func simulateTypingStop() {
        isTyping["other_user"] = false
        typingTimer?.invalidate()
    }
    
    private func simulateIncomingMessage() {
        let responses = [
            "That's interesting!",
            "I agree with that.",
            "Thanks for sharing!",
            "Let me think about that.",
            "Good point!",
            "I see what you mean."
        ]
        
        let randomResponse = responses.randomElement() ?? "Thanks!"
        let incomingMessage = Message(
            content: randomResponse,
            senderID: "other_user",
            senderName: "Assistant"
        )
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.messages.append(incomingMessage)
        }
    }
    
    private func loadSampleData() {
        let sampleMessages = [
            Message(content: "Hello! How are you doing today?", senderID: "current_user", senderName: "You"),
            Message(content: "I'm doing great, thanks for asking! How about you?", senderID: "other_user", senderName: "Assistant"),
            Message(content: "I'm doing well! Just working on some SwiftUI projects.", senderID: "current_user", senderName: "You"),
            Message(content: "That sounds exciting! SwiftUI is such a powerful framework.", senderID: "other_user", senderName: "Assistant"),
            Message(content: "Absolutely! The declarative syntax makes UI development so much more intuitive.", senderID: "current_user", senderName: "You")
        ]
        
        messages = sampleMessages
        
        onlineUsers = [
            User(id: "current_user", name: "You", avatar: "person.circle.fill", isOnline: true),
            User(id: "other_user", name: "Assistant", avatar: "person.circle.fill", isOnline: true)
        ]
    }
}

struct MessageBubble: View {
    let message: Message
    let isFromCurrentUser: Bool
    let onReply: (Message) -> Void
    let onReact: (UUID, String) -> Void
    
    @State private var showingReactions = false
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer(minLength: 60)
                messageContent
                    .background(Color.blue)
                    .foregroundColor(.white)
            } else {
                messageContent
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                Spacer(minLength: 60)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contextMenu {
            Button("Reply") {
                onReply(message)
            }
            Button("React") {
                showingReactions.toggle()
            }
            Button("Copy") {
                UIPasteboard.general.string = message.content
            }
        }
        .sheet(isPresented: $showingReactions) {
            ReactionPicker { emoji in
                onReact(message.id, emoji)
                showingReactions = false
            }
        }
    }
    
    private var messageContent: some View {
        VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
            if !isFromCurrentUser {
                HStack {
                    Text(message.senderName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }
            
            if let replyToID = message.replyToID {
                ReplyIndicator(replyToID: replyToID)
                    .padding(.horizontal, 12)
            }
            
            Text(message.content)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .multilineTextAlignment(isFromCurrentUser ? .trailing : .leading)
            
            if !message.reactions.isEmpty {
                MessageReactions(reactions: message.reactions) { emoji in
                    onReact(message.id, emoji)
                }
                .padding(.horizontal, 12)
            }
            
            HStack {
                if isFromCurrentUser {
                    Spacer()
                }
                
                Text(message.timestamp.formatted(.dateTime.hour().minute()))
                    .font(.caption2)
                    .opacity(0.7)
                
                if isFromCurrentUser {
                    MessageStatusIcon(status: message.status)
                }
                
                if !isFromCurrentUser {
                    Spacer()
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }
}

struct MessageStatusIcon: View {
    let status: MessageStatus
    
    var body: some View {
        switch status {
        case .sending:
            Image(systemName: "clock")
                .font(.caption2)
                .opacity(0.7)
        case .sent:
            Image(systemName: "checkmark")
                .font(.caption2)
                .opacity(0.7)
        case .delivered:
            Image(systemName: "checkmark.circle")
                .font(.caption2)
                .opacity(0.7)
        case .read:
            Image(systemName: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundColor(.blue)
        }
    }
}

struct ReplyIndicator: View {
    let replyToID: UUID
    
    var body: some View {
        HStack {
            Rectangle()
                .fill(Color.blue)
                .frame(width: 3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Reply to message")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Original message content...")
                    .font(.caption)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
            
            Spacer()
        }
    }
}

struct ReactionPicker: View {
    let onReact: (String) -> Void
    
    private let reactions = ["❤️", "😂", "😮", "😢", "😠", "👍", "👎", "🎉"]
    
    var body: some View {
        NavigationView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 20) {
                ForEach(reactions, id: \.self) { emoji in
                    Button(action: { onReact(emoji) }) {
                        Text(emoji)
                            .font(.largeTitle)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
            }
            .padding()
            .navigationTitle("React")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ReplyPreview: View {
    let originalMessage: Message
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
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
    @State private var typingAnimation = false
    
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 8, height: 8)
                        .scaleEffect(typingAnimation ? 1.2 : 0.8)
                        .animation(
                            Animation.easeInOut(duration: 0.5)
                                .repeatForever()
                                .delay(Double(index) * 0.1),
                            value: typingAnimation
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            Spacer()
        }
        .onAppear {
            typingAnimation = true
        }
    }
}

struct ConnectionStatusBar: View {
    let status: ConnectionStatus
    
    var body: some View {
        Group {
            switch status {
            case .connecting:
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Connecting...")
                        .font(.caption)
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                .background(Color.orange.opacity(0.2))
                
            case .disconnected:
                HStack {
                    Image(systemName: "wifi.slash")
                        .font(.caption)
                    Text("No Connection")
                        .font(.caption)
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                .background(Color.red.opacity(0.2))
                
            case .connected:
                EmptyView()
            }
        }
    }
}

struct ChatView: View {
    @StateObject private var chatManager = ChatManager()
    @State private var messageText = ""
    @State private var replyingTo: Message?
    @State private var showingImagePicker = false
    @State private var isTyping = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            ConnectionStatusBar(status: chatManager.connectionStatus)
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(chatManager.messages) { message in
                            MessageBubble(
                                message: message,
                                isFromCurrentUser: message.isFromCurrentUser,
                                onReply: { msg in
                                    replyingTo = msg
                                    isInputFocused = true
                                },
                                onReact: { messageID, emoji in
                                    chatManager.addReaction(to: messageID, emoji: emoji)
                                }
                            )
                            .id(message.id)
                        }
                        
                        if chatManager.isTyping.values.contains(true) {
                            TypingIndicator()
                                .id("typing-indicator")
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
                .onChange(of: chatManager.isTyping) { _ in
                    if chatManager.isTyping.values.contains(true) {
                        scrollToBottom(proxy: proxy)
                    }
                }
            }
            
            if let replyMessage = replyingTo {
                ReplyPreview(originalMessage: replyMessage) {
                    replyingTo = nil
                }
                .padding(.horizontal)
            }
            
            inputBar
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {}) {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.blue)
                }
            }
        }
        .onAppear {
            chatManager.connect()
        }
        .onDisappear {
            chatManager.disconnect()
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker()
        }
    }
    
    private var inputBar: some View {
        HStack(spacing: 12) {
            Button(action: {
                showingImagePicker = true
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            
            HStack {
                TextField("Type a message...", text: $messageText, axis: .vertical)
                    .focused($isInputFocused)
                    .lineLimit(1...5)
                    .onChange(of: messageText) { newValue in
                        if !newValue.isEmpty && !isTyping {
                            isTyping = true
                            chatManager.sendTypingIndicator(isTyping: true)
                        } else if newValue.isEmpty && isTyping {
                            isTyping = false
                            chatManager.sendTypingIndicator(isTyping: false)
                        }
                    }
                
                Button(action: {
                    showingImagePicker = true
                }) {
                    Image(systemName: "camera.fill")
                        .font(.title3)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            
            Button(action: sendMessage) {
                Image(systemName: "paperplane.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                    .clipShape(Circle())
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
        
        let message = Message(
            content: trimmedText,
            senderID: "current_user",
            senderName: "You",
            replyToID: replyingTo?.id
        )
        
        chatManager.sendMessage(message)
        messageText = ""
        replyingTo = nil
        isTyping = false
    }
    
    private func scrollToBottom(proxy: ScrollViewReader) {
        if let lastMessage = chatManager.messages.last {
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        } else if chatManager.isTyping.values.contains(true) {
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo("typing-indicator", anchor: .bottom)
            }
        }
    }
}

struct ImagePicker: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                Image(systemName: "photo")
                    .font(.system(size: 64))
                    .foregroundColor(.gray)
                
                Text("Image Picker")
                    .font(.title2)
                    .padding()
                
                Text("This would integrate with PHPickerViewController or UIImagePickerController")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding()
            }
            .navigationTitle("Select Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}