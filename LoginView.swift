// filepath: LoginView.swift

import SwiftUI

struct LoginView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var rememberMe = false
    @State private var isLoading = false
    @State private var showPassword = false
    @State private var errorMessage = ""
    @State private var showingForgotPassword = false
    @State private var isLoginSuccessful = false
    
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case username, password
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        Text("Welcome Back")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Sign in to your account")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // Form Fields
                    VStack(spacing: 16) {
                        // Username Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email or Username")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            TextField("Enter your email or username", text: $username)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .username)
                                .onSubmit {
                                    focusedField = .password
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(usernameError.isEmpty ? Color.clear : Color.red, lineWidth: 1)
                                )
                                .accessibilityLabel("Email or Username")
                                .accessibilityHint("Enter your email address or username")
                            
                            if !usernameError.isEmpty {
                                Text(usernameError)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .accessibilityLabel("Username error: \(usernameError)")
                            }
                        }
                        
                        // Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            HStack {
                                Group {
                                    if showPassword {
                                        TextField("Enter your password", text: $password)
                                    } else {
                                        SecureField("Enter your password", text: $password)
                                    }
                                }
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .focused($focusedField, equals: .password)
                                .onSubmit {
                                    if isFormValid {
                                        login()
                                    }
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(passwordError.isEmpty ? Color.clear : Color.red, lineWidth: 1)
                                )
                                
                                Button(action: {
                                    showPassword.toggle()
                                }) {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundColor(.secondary)
                                }
                                .accessibilityLabel(showPassword ? "Hide password" : "Show password")
                            }
                            
                            if !passwordError.isEmpty {
                                Text(passwordError)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .accessibilityLabel("Password error: \(passwordError)")
                            }
                        }
                        
                        // Remember Me Toggle
                        HStack {
                            Toggle("Remember Me", isOn: $rememberMe)
                                .toggleStyle(SwitchToggleStyle())
                            
                            Spacer()
                            
                            Button("Forgot Password?") {
                                showingForgotPassword = true
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .accessibilityLabel("Forgot password")
                            .accessibilityHint("Tap to reset your password")
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Error Message
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .padding(.horizontal, 20)
                            .multilineTextAlignment(.center)
                            .accessibilityLabel("Error: \(errorMessage)")
                    }
                    
                    // Login Button
                    Button(action: login) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                Text("Signing In...")
                            } else {
                                Text("Sign In")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(isFormValid && !isLoading ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(!isFormValid || isLoading)
                    .padding(.horizontal, 20)
                    .accessibilityLabel("Sign in")
                    .accessibilityHint("Double tap to sign in to your account")
                    
                    // Success Indicator
                    if isLoginSuccessful {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Login Successful!")
                                .foregroundColor(.green)
                                .fontWeight(.medium)
                        }
                        .transition(.opacity)
                        .accessibilityLabel("Login successful")
                    }
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .onTapGesture {
                focusedField = nil
            }
            .alert("Reset Password", isPresented: $showingForgotPassword) {
                Button("Cancel", role: .cancel) { }
                Button("Send Reset Link") {
                    // Handle forgot password
                }
            } message: {
                Text("Enter your email address to receive a password reset link.")
            }
        }
    }
    
    private var usernameError: String {
        if username.isEmpty {
            return ""
        }
        
        if username.count < 3 {
            return "Username must be at least 3 characters"
        }
        
        if username.contains("@") && !isValidEmail(username) {
            return "Please enter a valid email address"
        }
        
        return ""
    }
    
    private var passwordError: String {
        if password.isEmpty {
            return ""
        }
        
        if password.count < 6 {
            return "Password must be at least 6 characters"
        }
        
        return ""
    }
    
    private var isFormValid: Bool {
        return !username.isEmpty && 
               !password.isEmpty && 
               usernameError.isEmpty && 
               passwordError.isEmpty
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func login() {
        guard isFormValid else { return }
        
        isLoading = true
        errorMessage = ""
        focusedField = nil
        
        // Simulate network request
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isLoading = false
            
            // Simulate login validation
            if username.lowercased() == "admin" && password == "password" {
                withAnimation(.easeInOut(duration: 0.5)) {
                    isLoginSuccessful = true
                }
                
                // Hide success message after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        isLoginSuccessful = false
                    }
                }
            } else if username.isEmpty || password.isEmpty {
                errorMessage = "Please fill in all required fields"
            } else if !isValidEmail(username) && !username.contains("@") {
                errorMessage = "Please enter a valid email address or username"
            } else {
                errorMessage = "Invalid credentials. Please try again."
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}