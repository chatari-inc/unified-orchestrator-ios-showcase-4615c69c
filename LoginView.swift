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
    @State private var loginSuccess = false
    
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case username, password
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Logo/Header
                        VStack(spacing: 20) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.white)
                                .accessibility(label: Text("App Logo"))
                            
                            Text("Welcome Back")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .accessibility(addTraits: .isHeader)
                            
                            Text("Sign in to your account")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.top, 40)
                        
                        // Login Form
                        VStack(spacing: 20) {
                            // Username Field
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "envelope")
                                        .foregroundColor(.gray)
                                        .frame(width: 20)
                                    
                                    TextField("Email or Username", text: $username)
                                        .textInputAutocapitalization(.never)
                                        .keyboardType(.emailAddress)
                                        .autocorrectionDisabled()
                                        .focused($focusedField, equals: .username)
                                        .onSubmit {
                                            focusedField = .password
                                        }
                                        .accessibility(label: Text("Email or Username"))
                                        .accessibility(hint: Text("Enter your email address or username"))
                                }
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(usernameValidationColor, lineWidth: 2)
                                )
                                
                                if !username.isEmpty && !isValidUsername {
                                    Text("Please enter a valid email address")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .accessibility(label: Text("Username validation error"))
                                }
                            }
                            
                            // Password Field
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "lock")
                                        .foregroundColor(.gray)
                                        .frame(width: 20)
                                    
                                    if showPassword {
                                        TextField("Password", text: $password)
                                            .focused($focusedField, equals: .password)
                                            .onSubmit {
                                                login()
                                            }
                                    } else {
                                        SecureField("Password", text: $password)
                                            .focused($focusedField, equals: .password)
                                            .onSubmit {
                                                login()
                                            }
                                    }
                                    
                                    Button(action: {
                                        showPassword.toggle()
                                    }) {
                                        Image(systemName: showPassword ? "eye.slash" : "eye")
                                            .foregroundColor(.gray)
                                    }
                                    .accessibility(label: Text(showPassword ? "Hide password" : "Show password"))
                                }
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(passwordValidationColor, lineWidth: 2)
                                )
                                
                                if !password.isEmpty && !isValidPassword {
                                    Text("Password must be at least 6 characters")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .accessibility(label: Text("Password validation error"))
                                }
                            }
                            
                            // Remember Me Toggle
                            HStack {
                                Toggle("Remember Me", isOn: $rememberMe)
                                    .toggleStyle(CheckboxToggleStyle())
                                    .accessibility(label: Text("Remember Me"))
                                    .accessibility(hint: Text("Keep me signed in on this device"))
                                
                                Spacer()
                                
                                Button("Forgot Password?") {
                                    showingForgotPassword = true
                                }
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .accessibility(label: Text("Forgot Password"))
                                .accessibility(hint: Text("Reset your password"))
                            }
                        }
                        .padding(.horizontal, 30)
                        
                        // Error Message
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundColor(.red)
                                .padding(.horizontal, 30)
                                .multilineTextAlignment(.center)
                                .accessibility(label: Text("Error: \(errorMessage)"))
                        }
                        
                        // Login Button
                        Button(action: login) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                        .accessibility(label: Text("Signing in"))
                                } else {
                                    Text("Sign In")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(isFormValid ? Color.white : Color.gray.opacity(0.6))
                            .foregroundColor(isFormValid ? .blue : .white)
                            .cornerRadius(12)
                            .scaleEffect(isLoading ? 0.95 : 1.0)
                        }
                        .disabled(!isFormValid || isLoading)
                        .padding(.horizontal, 30)
                        .accessibility(label: Text("Sign In Button"))
                        .accessibility(hint: Text("Tap to sign in to your account"))
                        .accessibility(addTraits: isFormValid ? [] : .isNotEnabled)
                        
                        // Success Animation
                        if loginSuccess {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.title2)
                                Text("Login Successful!")
                                    .foregroundColor(.white)
                                    .fontWeight(.medium)
                            }
                            .padding()
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(12)
                            .transition(.scale.combined(with: .opacity))
                            .accessibility(label: Text("Login successful"))
                        }
                        
                        Spacer()
                    }
                }
            }
            .navigationBarHidden(true)
            .onTapGesture {
                focusedField = nil
            }
            .sheet(isPresented: $showingForgotPassword) {
                ForgotPasswordView()
            }
            .onChange(of: username) { _ in
                clearErrorMessage()
            }
            .onChange(of: password) { _ in
                clearErrorMessage()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var isValidUsername: Bool {
        let emailRegex = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: username) || (!username.isEmpty && username.count >= 3)
    }
    
    private var isValidPassword: Bool {
        return password.count >= 6
    }
    
    private var isFormValid: Bool {
        return isValidUsername && isValidPassword && !username.isEmpty && !password.isEmpty
    }
    
    private var usernameValidationColor: Color {
        if username.isEmpty {
            return .clear
        }
        return isValidUsername ? .green : .red
    }
    
    private var passwordValidationColor: Color {
        if password.isEmpty {
            return .clear
        }
        return isValidPassword ? .green : .red
    }
    
    // MARK: - Methods
    
    private func login() {
        guard isFormValid else { return }
        
        isLoading = true
        errorMessage = ""
        focusedField = nil
        
        // Simulate network request
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            // Simulate login logic
            if username.lowercased() == "demo@example.com" && password == "password123" {
                // Success
                loginSuccess = true
                isLoading = false
                
                // Hide success message and navigate
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    // Navigate to main app or handle success
                    loginSuccess = false
                }
            } else {
                // Failure
                isLoading = false
                errorMessage = "Invalid credentials. Please try again."
                
                // Add haptic feedback
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
            }
        }
    }
    
    private func clearErrorMessage() {
        if !errorMessage.isEmpty {
            errorMessage = ""
        }
    }
}

// MARK: - Custom Toggle Style

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                .foregroundColor(configuration.isOn ? .white : .white.opacity(0.7))
                .font(.system(size: 16))
                .onTapGesture {
                    configuration.isOn.toggle()
                }
            
            configuration.label
                .foregroundColor(.white)
                .font(.subheadline)
        }
    }
}

// MARK: - Forgot Password View

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var isLoading = false
    @State private var showingSuccess = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                VStack(spacing: 20) {
                    Image(systemName: "envelope.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Forgot Password")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Enter your email address and we'll send you a link to reset your password.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                VStack(spacing: 20) {
                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(.gray)
                            .frame(width: 20)
                        
                        TextField("Email Address", text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    Button(action: sendResetLink) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Text("Send Reset Link")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(isValidEmail ? Color.blue : Color.gray.opacity(0.6))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!isValidEmail || isLoading)
                    
                    if showingSuccess {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Reset link sent to your email!")
                                .foregroundColor(.green)
                                .fontWeight(.medium)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 30)
                
                Spacer()
            }
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var isValidEmail: Bool {
        let emailRegex = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func sendResetLink() {
        guard isValidEmail else { return }
        
        isLoading = true
        errorMessage = ""
        
        // Simulate network request
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isLoading = false
            showingSuccess = true
            
            // Auto dismiss after success
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                dismiss()
            }
        }
    }
}

#Preview {
    LoginView()
}