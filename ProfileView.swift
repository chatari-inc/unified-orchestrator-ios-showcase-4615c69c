// filepath: ProfileView.swift

import SwiftUI
import PhotosUI

struct ProfileView: View {
    @StateObject private var profileManager = ProfileManager()
    @State private var isEditing = false
    @State private var showingImagePicker = false
    @State private var showingPhotoPicker = false
    @State private var selectedImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingDiscardAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    // Edit state
    @State private var editName = ""
    @State private var editEmail = ""
    @State private var editPhone = ""
    @State private var editBio = ""
    
    // Validation states
    @State private var nameError = ""
    @State private var emailError = ""
    @State private var phoneError = ""
    @State private var bioError = ""
    
    var body: some View {
        NavigationView {
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isEditing {
                        Button("Done") {
                            saveChanges()
                        }
                        .disabled(!isFormValid)
                    } else {
                        Button("Edit") {
                            startEditing()
                        }
                    }
                }
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .alert("Discard Changes", isPresented: $showingDiscardAlert) {
                Button("Discard", role: .destructive) {
                    cancelEditing()
                }
                Button("Keep Editing", role: .cancel) { }
            } message: {
                Text("Are you sure you want to discard your changes?")
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $selectedImage, sourceType: .camera)
            }
            .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotoItem, matching: .images)
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                        profileManager.updateProfileImage(image)
                    }
                }
            }
            .onChange(of: selectedImage) { _, newImage in
                if let image = newImage {
                    profileManager.updateProfileImage(image)
                }
            }
        }
    }
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                if let image = profileManager.profile.profileImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                        )
                }
                
                if isEditing {
                    Circle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        )
                        .onTapGesture {
                            showImagePickerOptions()
                        }
                }
            }
            .accessibilityLabel("Profile picture")
            .accessibilityHint(isEditing ? "Tap to change profile picture" : "Profile picture")
            
            if !isEditing {
                VStack(spacing: 4) {
                    Text(profileManager.profile.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(profileManager.profile.email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var informationSection: some View {
        VStack(spacing: 16) {
            InfoCard(
                title: "Name",
                value: isEditing ? $editName : .constant(profileManager.profile.name),
                isEditing: isEditing,
                errorMessage: nameError,
                keyboardType: .default
            )
            
            InfoCard(
                title: "Email",
                value: isEditing ? $editEmail : .constant(profileManager.profile.email),
                isEditing: isEditing,
                errorMessage: emailError,
                keyboardType: .emailAddress
            )
            
            InfoCard(
                title: "Phone",
                value: isEditing ? $editPhone : .constant(profileManager.profile.phone),
                isEditing: isEditing,
                errorMessage: phoneError,
                keyboardType: .phonePad
            )
            
            InfoCard(
                title: "Bio",
                value: isEditing ? $editBio : .constant(profileManager.profile.bio),
                isEditing: isEditing,
                errorMessage: bioError,
                isMultiline: true
            )
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if isEditing {
                HStack(spacing: 16) {
                    Button("Cancel") {
                        if hasUnsavedChanges {
                            showingDiscardAlert = true
                        } else {
                            cancelEditing()
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    
                    Button("Save") {
                        saveChanges()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!isFormValid)
                }
            } else {
                Button("Edit Profile") {
                    startEditing()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }
    
    private var isFormValid: Bool {
        nameError.isEmpty && emailError.isEmpty && phoneError.isEmpty && bioError.isEmpty &&
        !editName.isEmpty && !editEmail.isEmpty
    }
    
    private var hasUnsavedChanges: Bool {
        editName != profileManager.profile.name ||
        editEmail != profileManager.profile.email ||
        editPhone != profileManager.profile.phone ||
        editBio != profileManager.profile.bio
    }
    
    private func startEditing() {
        isEditing = true
        editName = profileManager.profile.name
        editEmail = profileManager.profile.email
        editPhone = profileManager.profile.phone
        editBio = profileManager.profile.bio
        clearValidationErrors()
    }
    
    private func saveChanges() {
        validateForm()
        
        if isFormValid {
            profileManager.updateProfile(
                name: editName,
                email: editEmail,
                phone: editPhone,
                bio: editBio
            )
            isEditing = false
            clearValidationErrors()
        }
    }
    
    private func cancelEditing() {
        isEditing = false
        clearValidationErrors()
    }
    
    private func validateForm() {
        // Name validation
        if editName.isEmpty {
            nameError = "Name is required"
        } else if editName.count < 2 {
            nameError = "Name must be at least 2 characters"
        } else if editName.count > 50 {
            nameError = "Name must be less than 50 characters"
        } else {
            nameError = ""
        }
        
        // Email validation
        if editEmail.isEmpty {
            emailError = "Email is required"
        } else if !isValidEmail(editEmail) {
            emailError = "Please enter a valid email address"
        } else {
            emailError = ""
        }
        
        // Phone validation
        if !editPhone.isEmpty && !isValidPhone(editPhone) {
            phoneError = "Please enter a valid phone number"
        } else {
            phoneError = ""
        }
        
        // Bio validation
        if editBio.count > 500 {
            bioError = "Bio must be less than 500 characters"
        } else {
            bioError = ""
        }
    }
    
    private func clearValidationErrors() {
        nameError = ""
        emailError = ""
        phoneError = ""
        bioError = ""
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    private func isValidPhone(_ phone: String) -> Bool {
        let phoneRegEx = "^[+]?[0-9]{10,15}$"
        let phonePred = NSPredicate(format:"SELF MATCHES %@", phoneRegEx)
        return phonePred.evaluate(with: phone)
    }
    
    private func showImagePickerOptions() {
        let alert = UIAlertController(title: "Select Photo", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Camera", style: .default) { _ in
            showingImagePicker = true
        })
        
        alert.addAction(UIAlertAction(title: "Photo Library", style: .default) { _ in
            showingPhotoPicker = true
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(alert, animated: true)
        }
    }
}

struct InfoCard: View {
    let title: String
    @Binding var value: String
    let isEditing: Bool
    let errorMessage: String
    let keyboardType: UIKeyboardType
    let isMultiline: Bool
    
    init(title: String, value: Binding<String>, isEditing: Bool, errorMessage: String = "", keyboardType: UIKeyboardType = .default, isMultiline: Bool = false) {
        self.title = title
        self._value = value
        self.isEditing = isEditing
        self.errorMessage = errorMessage
        self.keyboardType = keyboardType
        self.isMultiline = isMultiline
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            if isEditing {
                if isMultiline {
                    TextEditor(text: $value)
                        .frame(minHeight: 80)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .keyboardType(keyboardType)
                } else {
                    TextField("Enter \(title.lowercased())", text: $value)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(keyboardType)
                        .autocapitalization(keyboardType == .emailAddress ? .none : .words)
                }
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            } else {
                Text(value.isEmpty ? "Not specified" : value)
                    .font(.body)
                    .foregroundColor(value.isEmpty ? .secondary : .primary)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value.isEmpty ? "Not specified" : value)")
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.blue)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct UserProfile {
    var id = UUID()
    var name: String
    var email: String
    var phone: String
    var bio: String
    var profileImage: UIImage?
    var lastUpdated = Date()
}

class ProfileManager: ObservableObject {
    @Published var profile = UserProfile(
        name: "John Doe",
        email: "john.doe@example.com",
        phone: "+1 (555) 123-4567",
        bio: "iOS Developer with a passion for creating beautiful and functional applications. Always learning and exploring new technologies."
    )
    
    func updateProfile(name: String, email: String, phone: String, bio: String) {
        profile.name = name
        profile.email = email
        profile.phone = phone
        profile.bio = bio
        profile.lastUpdated = Date()
    }
    
    func updateProfileImage(_ image: UIImage) {
        profile.profileImage = image
        profile.lastUpdated = Date()
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
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
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}