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
        senderID == "current_user"
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

struct User: Identifiable, Codable {
    let id = UUID()
    let name: String
    let avatarURL: String?
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

enum ConnectionStatus {
    case connected
    case disconnected
    case connecting
}

class ChatManager: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isTyping: [String: Bool] = [:]
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var typingUsers: Set<String> = []
    
    private var webSocket: URLSessionWebSocketTask?
    private var typingTimer: Timer?
    
    init() {
        loadMockMessages()
    }
    
    func connect() {
        connectionStatus = .connecting
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.connectionStatus = .connected
        }
    }
    
    func disconnect() {
        connectionStatus = .disconnected
        webSocket?.cancel()
    }
    
    func sendMessage(_ content: String, replyToID: UUID? = nil) {
        let message = Message(
            content: content,
            senderID: "current_user",
            senderName: "You",
            timestamp: Date(),
            type: .text,
            status: .sending,
            replyToID: replyToID
        )
        
        messages.append(message)
        
        // Simulate delivery
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let index = self.messages.firstIndex(where: { $0.id == message.id }) {
                self.messages[index] = Message(
                    content: message.content,
                    senderID: message.senderID,
                    senderName: message.senderName,
                    timestamp: message.timestamp,
                    type: message.type,
                    status: .delivered,
                    replyToID: message.replyToID
                )
            }
        }
    }
    
    func sendTypingIndicator(isTyping: Bool) {
        if isTyping {
            typingUsers.insert("other_user")
            typingTimer?.invalidate()
            typingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
                self.typingUsers.remove("other_user")
            }
        } else {
            typingUsers.remove("other_user")
        }
    }
    
    private func loadMockMessages() {
        messages = [
            Message(
                content: "Hey! How's your day going?",
                senderID: "other_user",
                senderName: "Alice",
                timestamp: Date().addingTimeInterval(-3600),
                type: .text,
                status: .read,
                replyToID: nil
            ),
            Message(
                content: "Pretty good! Just working on some new features. How about you?",
                senderID: "current_user",
                senderName: "You",
                timestamp: Date().addingTimeInterval(-3500),
                type: .text,
                status: .read,
                replyToID: nil
            ),
            Message(
                content: "Same here! This new chat interface is looking great 🎉",
                senderID: "other_user",
                senderName: "Alice",
                timestamp: Date().addingTimeInterval(-3400),
                type: .text,
                status: .read,
                replyToID: nil
            ),
            Message(
                content: "Thanks! I'm really excited about the real-time features",
                senderID: "current_user",
                senderName: "You",
                timestamp: Date().addingTimeInterval(-3300),
                type: .text,
                status: .read,
                replyToID: nil
            ),
            Message(
                content: "The typing indicators work perfectly! ✨",
                senderID: "other_user",
                senderName: "Alice",
                timestamp: Date().addingTimeInterval(-300),
                type: .text,
                status: .read,
                replyToID: nil
            )
        ]
    }
}

struct MessageBubble: View {
    let message: Message
    let isFromCurrentUser: Bool
    let onReply: (Message) -> Void
    
    @State private var showingReactions = false
    @State private var reactions: [String: Int] = [:]
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer()
                messageContent
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .contextMenu {
                        Button("Reply") {
                            onReply(message)
                        }
                        Button("Copy") {
                            UIPasteboard.general.string = message.content
                        }
                    }
            } else {
                messageContent
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .contextMenu {
                        Button("Reply") {
                            onReply(message)
                        }
                        Button("Copy") {
                            UIPasteboard.general.string = message.content
                        }
                    }
                Spacer()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message.senderName) said \(message.content) at \(message.timestamp.formatted(.dateTime.hour().minute()))")
    }
    
    private var messageContent: some View {
        VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
            if !isFromCurrentUser {
                Text(message.senderName)
                    .font(.caption)
                    .opacity(0.7)
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
            }
            
            Text(message.content)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .multilineTextAlignment(isFromCurrentUser ? .trailing : .leading)
            
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Replying to \(originalMessage.senderName): \(originalMessage.content)")
    }
}

struct TypingIndicator: View {
    let typingUsers: Set<String>
    @State private var typingAnimation = false
    
    var body: some View {
        HStack {
            if !typingUsers.isEmpty {
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
                .onAppear {
                    typingAnimation = true
                }
                .onDisappear {
                    typingAnimation = false
                }
                .accessibilityLabel("Someone is typing")
            }
            
            Spacer()
        }
        .padding(.horizontal)
    }
}

struct ChatView: View {
    @StateObject private var chatManager = ChatManager()
    @State private var messageText = ""
    @State private var isTyping = false
    @State private var replyingTo: Message?
    @State private var showingImagePicker = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Connection status
            if chatManager.connectionStatus != .connected {
                HStack {
                    Image(systemName: "wifi.slash")
                        .foregroundColor(.orange)
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1))
            }
            
            // Message list
            messageList
            
            // Reply preview
            if let replyMessage = replyingTo {
                ReplyPreview(originalMessage: replyMessage) {
                    replyingTo = nil
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            
            // Typing indicator
            TypingIndicator(typingUsers: chatManager.typingUsers)
            
            // Input bar
            inputBar
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            chatManager.connect()
        }
        .onDisappear {
            chatManager.disconnect()
        }
        .onTapGesture {
            isInputFocused = false
        }
    }
    
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(chatManager.messages) { message in
                        MessageBubble(
                            message: message,
                            isFromCurrentUser: message.isFromCurrentUser,
                            onReply: { replyingTo = $0 }
                        )
                        .id(message.id)
                    }
                    
                    // Invisible anchor for scrolling
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 1)
                        .id("bottom")
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
                await loadMoreMessages()
            }
        }
    }
    
    private var inputBar: some View {
        HStack(spacing: 12) {
            Button(action: { showingImagePicker = true }) {
                Image(systemName: "plus")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .accessibilityLabel("Add attachment")
            
            TextField("Type a message...", text: $messageText, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(1...5)
                .focused($isInputFocused)
                .onChange(of: messageText) { newValue in
                    if !newValue.isEmpty && !isTyping {
                        isTyping = true
                        chatManager.sendTypingIndicator(isTyping: true)
                    } else if newValue.isEmpty && isTyping {
                        isTyping = false
                        chatManager.sendTypingIndicator(isTyping: false)
                    }
                }
                .onSubmit {
                    if !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        sendMessage()
                    }
                }
            
            Button(action: sendMessage) {
                Image(systemName: "paperplane.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Send message")
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.gray.opacity(0.3)),
            alignment: .top
        )
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker { _ in
                // Handle image selection
            }
        }
    }
    
    private var statusText: String {
        switch chatManager.connectionStatus {
        case .connecting:
            return "Connecting..."
        case .disconnected:
            return "Offline"
        case .connected:
            return "Connected"
        }
    }
    
    private func sendMessage() {
        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        
        chatManager.sendMessage(content, replyToID: replyingTo?.id)
        
        messageText = ""
        replyingTo = nil
        isTyping = false
        chatManager.sendTypingIndicator(isTyping: false)
    }
    
    private func scrollToBottom(proxy: ScrollViewReader) {
        withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }
    
    private func loadMoreMessages() async {
        // Simulate loading more messages
        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    let onImageSelected: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onImageSelected: onImageSelected)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImageSelected: (UIImage) -> Void
        
        init(onImageSelected: @escaping (UIImage) -> Void) {
            self.onImageSelected = onImageSelected
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImageSelected(image)
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}