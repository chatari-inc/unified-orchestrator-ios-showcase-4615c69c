// filepath: ProfileView.swift

import SwiftUI
import PhotosUI

struct ProfileView: View {
    @State private var profile = UserProfile(
        id: UUID(),
        name: "John Doe",
        email: "john.doe@example.com",
        phone: "+1 (555) 123-4567",
        bio: "iOS Developer passionate about creating great user experiences with SwiftUI and modern app development.",
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
    @State private var showingImagePreview = false
    @State private var selectedImage: UIImage?
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showingError = false
    @State private var showingDiscardAlert = false
    @State private var showingSuccessAlert = false
    @State private var validationErrors: [String: String] = [:]
    
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
            .navigationBarBackButtonHidden(isEditing)
            .toolbar {
                if isEditing {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Cancel") {
                            if hasUnsavedChanges() {
                                showingDiscardAlert = true
                            } else {
                                cancelEditing()
                            }
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .overlay(
                Group {
                    if isLoading {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        ProgressView("Saving...")
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                    }
                }
            )
            .alert("Discard Changes?", isPresented: $showingDiscardAlert) {
                Button("Discard", role: .destructive) {
                    cancelEditing()
                }
                Button("Keep Editing", role: .cancel) { }
            } message: {
                Text("You have unsaved changes. Are you sure you want to discard them?")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Success", isPresented: $showingSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Profile updated successfully!")
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $selectedImage)
            }
            .sheet(isPresented: $showingImagePreview) {
                ImagePreviewView(image: selectedImage ?? UIImage())
            }
        }
    }
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                if let selectedImage = selectedImage {
                    Image(uiImage: selectedImage)
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
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Button(action: {
                                showingImagePicker = true
                            }) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                            }
                        )
                } else {
                    Button(action: {
                        showingImagePreview = true
                    }) {
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 120, height: 120)
                    }
                }
            }
            .accessibilityLabel("Profile photo")
            .accessibilityHint(isEditing ? "Tap to change photo" : "Tap to view full size")
            
            VStack(spacing: 4) {
                Text(isEditing ? editedProfile.name : profile.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(isEditing ? editedProfile.email : profile.email)
                    .font(.subheadline)
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
                Button(action: saveChanges) {
                    Text("Save Changes")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .disabled(isLoading || !isFormValid())
                .opacity(isFormValid() ? 1.0 : 0.6)
            } else {
                Button(action: startEditing) {
                    Text("Edit Profile")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }
        }
    }
    
    private func startEditing() {
        editedProfile = profile
        isEditing = true
        validationErrors.removeAll()
    }
    
    private func saveChanges() {
        validateForm()
        
        if validationErrors.isEmpty {
            isLoading = true
            
            // Simulate API call
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                profile = editedProfile
                profile.lastUpdated = Date()
                isLoading = false
                isEditing = false
                showingSuccessAlert = true
            }
        }
    }
    
    private func cancelEditing() {
        isEditing = false
        validationErrors.removeAll()
        selectedImage = nil
    }
    
    private func hasUnsavedChanges() -> Bool {
        return editedProfile.name != profile.name ||
               editedProfile.email != profile.email ||
               editedProfile.phone != profile.phone ||
               editedProfile.bio != profile.bio ||
               selectedImage != nil
    }
    
    private func validateForm() {
        validationErrors.removeAll()
        
        // Name validation
        if editedProfile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            validationErrors["name"] = "Name is required"
        } else if editedProfile.name.count < 2 {
            validationErrors["name"] = "Name must be at least 2 characters"
        } else if editedProfile.name.count > 50 {
            validationErrors["name"] = "Name must be less than 50 characters"
        }
        
        // Email validation
        if editedProfile.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            validationErrors["email"] = "Email is required"
        } else if !isValidEmail(editedProfile.email) {
            validationErrors["email"] = "Please enter a valid email address"
        }
        
        // Phone validation
        if !editedProfile.phone.isEmpty && !isValidPhone(editedProfile.phone) {
            validationErrors["phone"] = "Please enter a valid phone number"
        }
        
        // Bio validation
        if editedProfile.bio.count > 500 {
            validationErrors["bio"] = "Bio must be less than 500 characters"
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func isValidPhone(_ phone: String) -> Bool {
        let phoneRegex = "^[+]?[0-9\\s\\-\\(\\)]{10,}$"
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        return phonePredicate.evaluate(with: phone)
    }
    
    private func isFormValid() -> Bool {
        validateForm()
        return validationErrors.isEmpty
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
                .font(.headline)
                .foregroundColor(.primary)
            
            if isEditing {
                if isMultiline {
                    TextEditor(text: $value)
                        .frame(minHeight: 80)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .keyboardType(keyboardType)
                } else {
                    TextField(title, text: $value)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(keyboardType)
                        .autocapitalization(keyboardType == .emailAddress ? .none : .words)
                }
            } else {
                Text(value.isEmpty ? "Not specified" : value)
                    .font(.body)
                    .foregroundColor(value.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            }
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
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
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
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
            if let editedImage = info[.editedImage] as? UIImage {
                parent.image = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.image = originalImage
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct ImagePreviewView: View {
    let image: UIImage
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .ignoresSafeArea()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
}