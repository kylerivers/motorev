import SwiftUI
import Combine

struct AuthenticationView: View {
    @EnvironmentObject var networkManager: NetworkManager
    @State private var isLoginMode = true
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemBackground),
                        Color.red.opacity(0.1)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Logo
                        VStack(spacing: 20) {
                            ZStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 100, height: 100)
                                
                                Image(systemName: "motorcycle")
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            Text("MotoRev")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Text("AI-Powered Motorcycle Safety")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 40)
                        
                        // Mode selector
                        Picker("Mode", selection: $isLoginMode) {
                            Text("Login").tag(true)
                            Text("Sign Up").tag(false)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                        
                        // Form fields
                        VStack(spacing: 20) {
                            TextField("Username", text: $username)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                            
                            if !isLoginMode {
                                TextField("Email", text: $email)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .autocapitalization(.none)
                                    .keyboardType(.emailAddress)
                                
                                TextField("First Name", text: $firstName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                TextField("Last Name", text: $lastName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            
                            SecureField("Password", text: $password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        .padding(.horizontal)
                        
                        // Action button
                        Button(action: {
                            if isLoginMode {
                                login()
                            } else {
                                register()
                            }
                        }) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color.red)
                                    .cornerRadius(10)
                            } else {
                                Text(isLoginMode ? "Login" : "Create Account")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color.red)
                                    .cornerRadius(10)
                            }
                        }
                        .disabled(isLoading)
                        .padding(.horizontal)
                        
                        // Toggle mode text
                        Button(action: {
                            withAnimation {
                                isLoginMode.toggle()
                                clearForm()
                            }
                        }) {
                            Text(isLoginMode ? "Don't have an account? Sign up" : "Already have an account? Login")
                                .font(.footnote)
                                .foregroundColor(.red)
                        }
                        
                        Spacer(minLength: 50)
                    }
                }
            }
            .navigationBarHidden(true)
            .alert("Error", isPresented: $showingError) {
                Button("OK") {
                    showingError = false
                }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func login() {
        guard !username.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all fields"
            showingError = true
            return
        }
        
        isLoading = true
        
        networkManager.login(username: username, password: password)
            .sink(
                receiveCompletion: { completion in
                    isLoading = false
                    if case .failure(let error) = completion {
                        errorMessage = error.localizedDescription
                        showingError = true
                    }
                },
                receiveValue: { _ in
                    // Login successful - NetworkManager handles the state update
                }
            )
            .store(in: &cancellables)
    }
    
    private func register() {
        guard !username.isEmpty, !email.isEmpty, !password.isEmpty, !firstName.isEmpty, !lastName.isEmpty else {
            errorMessage = "Please fill in all fields"
            showingError = true
            return
        }
        
        isLoading = true
        
        networkManager.register(
            username: username,
            email: email,
            password: password,
            firstName: firstName,
            lastName: lastName,
            phoneNumber: nil,
            motorcycleMake: nil,
            motorcycleModel: nil,
            motorcycleYear: nil,
            ridingExperience: "beginner"
        )
        .sink(
            receiveCompletion: { completion in
                isLoading = false
                if case .failure(let error) = completion {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            },
            receiveValue: { _ in
                // Registration successful - NetworkManager handles the state update
            }
        )
        .store(in: &cancellables)
    }
    
    private func clearForm() {
        username = ""
        email = ""
        password = ""
        firstName = ""
        lastName = ""
    }
    
    @State private var cancellables = Set<AnyCancellable>()
}

struct AuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        AuthenticationView()
    }
} 