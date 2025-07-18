// filepath: LoginView.swift

import SwiftUI

struct LoginView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var rememberMe = false
    @State private var isLoading = false
    @State private var showPassword = false
    @State private var errorMessage = ""
    @State private var isLoggedIn = false
    @State private var usernameError = ""
    @State private var passwordError = ""
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case username, password
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                            .accessibilityLabel("Login icon")
                        
                        Text("Welcome Back")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .accessibilityAddTraits(.isHeader)
                        
                        Text("Sign in to your account")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // Form
                    VStack(spacing: 16) {
                        // Username Field
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Email or Username", text: $username)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .username)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(usernameError.isEmpty ? Color.clear : Color.red, lineWidth: 1)
                                )
                                .accessibilityLabel("Username or email input")
                                .accessibilityHint("Enter your email address or username")
                                .onChange(of: username) { _ in
                                    validateUsername()
                                }
                                .onSubmit {
                                    focusedField = .password
                                }
                            
                            if !usernameError.isEmpty {
                                Text(usernameError)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .accessibilityLabel("Username error: \(usernameError)")
                            }
                        }
                        
                        // Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Group {
                                    if showPassword {
                                        TextField("Password", text: $password)
                                    } else {
                                        SecureField("Password", text: $password)
                                    }
                                }
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .focused($focusedField, equals: .password)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(passwordError.isEmpty ? Color.clear : Color.red, lineWidth: 1)
                                )
                                .accessibilityLabel("Password input")
                                .accessibilityHint("Enter your password")
                                .onChange(of: password) { _ in
                                    validatePassword()
                                }
                                .onSubmit {
                                    if isFormValid {
                                        login()
                                    }
                                }
                                
                                Button(action: {
                                    showPassword.toggle()
                                }) {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundColor(.secondary)
                                }
                                .accessibilityLabel(showPassword ? "Hide password" : "Show password")
                                .padding(.trailing, 8)
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
                                .accessibilityLabel("Remember me toggle")
                                .accessibilityHint("Keep me signed in on this device")
                            
                            Spacer()
                            
                            Button("Forgot Password?") {
                                handleForgotPassword()
                            }
                            .font(.body)
                            .foregroundColor(.blue)
                            .accessibilityLabel("Forgot password")
                            .accessibilityHint("Reset your password")
                        }
                        
                        // Error Message
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.body)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .accessibilityLabel("Error message: \(errorMessage)")
                        }
                        
                        // Login Button
                        Button(action: login) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                        .accessibilityLabel("Signing in")
                                } else {
                                    Text("Sign In")
                                        .font(.headline)
                                        .accessibilityLabel("Sign in button")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isFormValid && !isLoading ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(!isFormValid || isLoading)
                        .accessibilityHint(isFormValid ? "Sign in to your account" : "Complete the form to sign in")
                    }
                    .padding(.horizontal, 24)
                    
                    // Sign Up Link
                    HStack {
                        Text("Don't have an account?")
                            .foregroundColor(.secondary)
                        
                        Button("Sign Up") {
                            handleSignUp()
                        }
                        .foregroundColor(.blue)
                        .accessibilityLabel("Sign up")
                        .accessibilityHint("Create a new account")
                    }
                    .padding(.top, 20)
                    
                    Spacer()
                }
            }
            .navigationTitle("Login")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
        }
        .onTapGesture {
            hideKeyboard()
        }
        .fullScreenCover(isPresented: $isLoggedIn) {
            Text("Welcome! You are now logged in.")
                .font(.title)
                .padding()
                .accessibilityLabel("Login successful")
        }
    }
    
    private var isFormValid: Bool {
        return !username.isEmpty && 
               !password.isEmpty && 
               usernameError.isEmpty && 
               passwordError.isEmpty &&
               isValidEmail(username) &&
               password.count >= 6
    }
    
    private func validateUsername() {
        usernameError = ""
        
        if username.isEmpty {
            usernameError = "Username is required"
        } else if !isValidEmail(username) && username.count < 3 {
            usernameError = "Please enter a valid email or username (3+ characters)"
        }
    }
    
    private func validatePassword() {
        passwordError = ""
        
        if password.isEmpty {
            passwordError = "Password is required"
        } else if password.count < 6 {
            passwordError = "Password must be at least 6 characters"
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func login() {
        guard isFormValid else { return }
        
        isLoading = true
        errorMessage = ""
        hideKeyboard()
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isLoading = false
            
            // Simulate different scenarios
            if username.lowercased() == "error@test.com" {
                errorMessage = "Invalid credentials. Please check your email and password."
            } else if username.lowercased() == "locked@test.com" {
                errorMessage = "Account is temporarily locked. Please try again later."
            } else if username.lowercased() == "network@test.com" {
                errorMessage = "Network error. Please check your connection and try again."
            } else {
                // Successful login
                isLoggedIn = true
                
                // Save credentials if remember me is enabled
                if rememberMe {
                    UserDefaults.standard.set(username, forKey: "savedUsername")
                    UserDefaults.standard.set(true, forKey: "rememberMe")
                }
            }
        }
    }
    
    private func handleForgotPassword() {
        // Handle forgot password action
        print("Forgot password tapped")
    }
    
    private func handleSignUp() {
        // Handle sign up action
        print("Sign up tapped")
    }
    
    private func hideKeyboard() {
        focusedField = nil
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}