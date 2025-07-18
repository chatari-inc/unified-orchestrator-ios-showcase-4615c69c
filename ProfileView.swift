// filepath: ProfileView.swift

import SwiftUI
import PhotosUI

struct ProfileView: View {
    @State private var profile = UserProfile(
        id: UUID(),
        name: "John Doe",
        email: "john.doe@example.com",
        phone: "+1 (555) 123-4567",
        bio: "iOS Developer passionate about creating beautiful and functional apps. Always learning new technologies and improving user experiences.",
        profileImageURL: nil,
        lastUpdated: Date()
    )
    
    @State private var editedProfile = UserProfile(
        id: UUID(),
        name: "",
        email: "",
        phone: "",
        bio: "",
        profileImageURL: nil,
        lastUpdated: Date()
    )
    
    @State private var isEditing = false
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showingAlert = false
    @State private var showingDiscardConfirmation = false
    @State private var showingImagePreview = false
    @State private var validationErrors: [String: String] = [:]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    profileHeader
                    informationSection
                    actionButtons
                }
                .padding()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .disabled(isLoading)
            .overlay(
                Group {
                    if isLoading {
                        Color.black.opacity(0.3)
                            .edgesIgnoringSafeArea(.all)
                        ProgressView()
                            .scaleEffect(1.2)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                }
            )
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(selectedImage: $selectedImage, sourceType: .photoLibrary)
                    .onDisappear {
                        if let image = selectedImage {
                            updateProfileImage(image)
                        }
                    }
            }
            .sheet(isPresented: $showingImagePreview) {
                ImagePreviewView(image: getCurrentProfileImage())
            }
            .alert("Error", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .alert("Discard Changes", isPresented: $showingDiscardConfirmation) {
                Button("Discard", role: .destructive) {
                    cancelEditing()
                }
                Button("Keep Editing", role: .cancel) { }
            } message: {
                Text("Are you sure you want to discard your changes?")
            }
        }
    }
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            Button(action: {
                if isEditing {
                    showingImagePicker = true
                } else {
                    showingImagePreview = true
                }
            }) {
                ZStack {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 120, height: 120)
                            .overlay(
                                Text(String(profile.name.prefix(1)))
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }
                    
                    if isEditing {
                        Circle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "camera.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .accessibility(label: Text("Profile photo"))
            .accessibility(hint: Text(isEditing ? "Tap to change photo" : "Tap to view full size"))
            
            VStack(spacing: 4) {
                Text(isEditing ? editedProfile.name : profile.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Last updated: \(formattedDate(profile.lastUpdated))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var informationSection: some View {
        VStack(spacing: 16) {
            InfoCard(
                title: "Name",
                value: isEditing ? $editedProfile.name : .constant(profile.name),
                isEditing: isEditing,
                errorMessage: validationErrors["name"]
            )
            
            InfoCard(
                title: "Email",
                value: isEditing ? $editedProfile.email : .constant(profile.email),
                isEditing: isEditing,
                keyboardType: .emailAddress,
                errorMessage: validationErrors["email"]
            )
            
            InfoCard(
                title: "Phone",
                value: isEditing ? $editedProfile.phone : .constant(profile.phone),
                isEditing: isEditing,
                keyboardType: .phonePad,
                errorMessage: validationErrors["phone"]
            )
            
            InfoCard(
                title: "Bio",
                value: isEditing ? $editedProfile.bio : .constant(profile.bio),
                isEditing: isEditing,
                isMultiline: true,
                errorMessage: validationErrors["bio"]
            )
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if isEditing {
                HStack(spacing: 16) {
                    Button(action: {
                        if hasChanges() {
                            showingDiscardConfirmation = true
                        } else {
                            cancelEditing()
                        }
                    }) {
                        Text("Cancel")
                            .font(.headline)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .accessibility(label: Text("Cancel editing"))
                    
                    Button(action: saveChanges) {
                        Text("Save")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [.blue, .purple]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                    }
                    .disabled(!isValidForm())
                    .opacity(isValidForm() ? 1.0 : 0.6)
                    .accessibility(label: Text("Save changes"))
                }
            } else {
                Button(action: startEditing) {
                    Text("Edit Profile")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                }
                .accessibility(label: Text("Edit profile information"))
            }
        }
    }
    
    private func startEditing() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isEditing = true
            editedProfile = profile
            validationErrors.removeAll()
        }
    }
    
    private func cancelEditing() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isEditing = false
            editedProfile = UserProfile(
                id: UUID(),
                name: "",
                email: "",
                phone: "",
                bio: "",
                profileImageURL: nil,
                lastUpdated: Date()
            )
            selectedImage = nil
            validationErrors.removeAll()
        }
    }
    
    private func saveChanges() {
        guard validateForm() else { return }
        
        isLoading = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                profile = editedProfile
                profile.lastUpdated = Date()
                isEditing = false
                isLoading = false
                validationErrors.removeAll()
            }
        }
    }
    
    private func validateForm() -> Bool {
        validationErrors.removeAll()
        
        if editedProfile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            validationErrors["name"] = "Name is required"
        } else if editedProfile.name.count < 2 {
            validationErrors["name"] = "Name must be at least 2 characters"
        } else if editedProfile.name.count > 50 {
            validationErrors["name"] = "Name must be less than 50 characters"
        }
        
        if editedProfile.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            validationErrors["email"] = "Email is required"
        } else if !isValidEmail(editedProfile.email) {
            validationErrors["email"] = "Please enter a valid email address"
        }
        
        if !editedProfile.phone.isEmpty && !isValidPhone(editedProfile.phone) {
            validationErrors["phone"] = "Please enter a valid phone number"
        }
        
        if editedProfile.bio.count > 500 {
            validationErrors["bio"] = "Bio must be less than 500 characters"
        }
        
        return validationErrors.isEmpty
    }
    
    private func isValidForm() -> Bool {
        return !editedProfile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !editedProfile.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               isValidEmail(editedProfile.email) &&
               (editedProfile.phone.isEmpty || isValidPhone(editedProfile.phone)) &&
               editedProfile.bio.count <= 500
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
    }
    
    private func isValidPhone(_ phone: String) -> Bool {
        let phoneRegex = "^[+]?[0-9\\s\\-\\(\\)]{10,}$"
        return NSPredicate(format: "SELF MATCHES %@", phoneRegex).evaluate(with: phone)
    }
    
    private func hasChanges() -> Bool {
        return editedProfile.name != profile.name ||
               editedProfile.email != profile.email ||
               editedProfile.phone != profile.phone ||
               editedProfile.bio != profile.bio ||
               selectedImage != nil
    }
    
    private func updateProfileImage(_ image: UIImage) {
        selectedImage = image
    }
    
    private func getCurrentProfileImage() -> UIImage? {
        return selectedImage
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct InfoCard: View {
    let title: String
    @Binding var value: String
    let isEditing: Bool
    var keyboardType: UIKeyboardType = .default
    var isMultiline: Bool = false
    var errorMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            if isEditing {
                if isMultiline {
                    TextEditor(text: $value)
                        .frame(minHeight: 80)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .font(.body)
                } else {
                    TextField(title, text: $value)
                        .keyboardType(keyboardType)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.body)
                }
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            } else {
                Text(value.isEmpty ? "Not provided" : value)
                    .font(.body)
                    .foregroundColor(value.isEmpty ? .secondary : .primary)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct UserProfile {
    var id: UUID
    var name: String
    var email: String
    var phone: String
    var bio: String
    var profileImageURL: URL?
    var lastUpdated: Date
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    let sourceType: UIImagePickerController.SourceType
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

struct ImagePreviewView: View {
    let image: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .edgesIgnoringSafeArea(.all)
                } else {
                    Text("No Image Available")
                        .foregroundColor(.white)
                        .font(.title2)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Profile Photo")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}