import 'package:flutter/material.dart';
import 'package:hemophilia_manager/auth/auth.dart';
import 'package:hemophilia_manager/services/firestore.dart';
import 'package:hemophilia_manager/routes/routes.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hemophilia_manager/screens/main_screen/patient_screens/main_screen_hud.dart';
import 'package:hemophilia_manager/screens/main_screen/healthcare_provider_screen/healthcare_main_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final savedEmail = await _secureStorage.read(key: 'saved_email');
      final savedPassword = await _secureStorage.read(key: 'saved_password');
      final rememberMe = await _secureStorage.read(key: 'remember_me');
      
      if (savedEmail != null && rememberMe == 'true') {
        setState(() {
          _emailController.text = savedEmail;
          _passwordController.text = savedPassword ?? '';
          _rememberMe = true;
        });
      }
    } catch (e) {
      print('Error loading saved credentials: $e');
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      
      final user = await AuthService().signIn(email, password);
      
      if (user != null) {
        final userRole = await _firestoreService.getUserRole(user.uid);
        
        if (userRole != null) {
          // Store login data in secure storage
          await _secureStorage.write(key: 'isLoggedIn', value: 'true');
          await _secureStorage.write(key: 'userRole', value: userRole);
          await _secureStorage.write(key: 'userUid', value: user.uid);
          
          // Handle remember me
          if (_rememberMe) {
            await _secureStorage.write(key: 'saved_email', value: email);
            await _secureStorage.write(key: 'saved_password', value: password);
            await _secureStorage.write(key: 'remember_me', value: 'true');
          } else {
            await _secureStorage.delete(key: 'saved_email');
            await _secureStorage.delete(key: 'saved_password');
            await _secureStorage.write(key: 'remember_me', value: 'false');
          }
          
          if (!mounted) return;
          
          // Navigate based on user role
          Widget targetScreen;
          switch (userRole) {
            case 'patient':
            case 'caregiver':
              targetScreen = MainScreenDisplay();
              break;
            case 'medical':
              targetScreen = HealthcareMainScreen();
              break;
            default:
              _showError('Invalid user role. Please contact support.');
              setState(() => _isLoading = false);
              return;
          }
          
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => targetScreen),
            (route) => false,
          );
        } else {
          _showError('User role not found. Please contact support.');
        }
      } else {
        _showError('Invalid email or password');
      }
    } catch (e) {
      _showError('Login failed: ${e.toString()}');
    }
    
    if (mounted) setState(() => _isLoading = false);
  }

  void _showError(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 12),
                  Image.asset('assets/images/app_logo.png', width: 80, height: 80),
                  SizedBox(height: 18),
                  Text(
                    'Welcome Back',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                      letterSpacing: 1.1,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Sign in to RedSyncPH to continue.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 28),

                  // Email Field
                  _buildInputField(
                    controller: _emailController,
                    label: 'Email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Enter email';
                      if (!value.contains('@')) return 'Enter valid email';
                      return null;
                    },
                  ),
                  SizedBox(height: 18),

                  // Password Field
                  _buildInputField(
                    controller: _passwordController,
                    label: 'Password',
                    icon: Icons.lock_outline,
                    obscureText: _obscurePassword,
                    showPasswordToggle: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Enter password';
                      return null;
                    },
                  ),
                  SizedBox(height: 8),

                  // Remember Me & Forgot Password
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: (value) => setState(() => _rememberMe = value ?? false),
                            activeColor: Colors.redAccent,
                          ),
                          Text('Remember me', style: TextStyle(color: Colors.black87)),
                        ],
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blue,
                          padding: EdgeInsets.zero,
                        ),
                        child: Text('Forgot Password?', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.forgotPassword),
                      ),
                    ],
                  ),
                  SizedBox(height: 18),

                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              'Login',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(height: 24),

                  // Register Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Don\'t have an account?', style: TextStyle(color: Colors.black87, fontSize: 14)),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          padding: EdgeInsets.zero,
                        ),
                        child: Text('Register now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        onPressed: () => Navigator.pushReplacementNamed(context, '/register'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    bool showPasswordToggle = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.redAccent),
        suffixIcon: showPasswordToggle
            ? IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility : Icons.visibility_off,
                  color: Colors.grey.shade600,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              )
            : null,
        border: UnderlineInputBorder(),
        labelStyle: TextStyle(color: Colors.grey.shade700),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.redAccent, width: 2),
        ),
      ),
    );
  }
}
