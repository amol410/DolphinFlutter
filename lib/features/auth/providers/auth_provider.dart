import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../data/models/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;

  const AuthState({this.user, this.isLoading = false, this.error});

  AuthState copyWith({UserModel? user, bool? isLoading, String? error}) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;

  AuthNotifier(this._repo) : super(const AuthState()) {
    _loadCachedUser();
  }

  Future<void> _loadCachedUser() async {
    final user = await _repo.getCachedUser();
    if (user != null) state = state.copyWith(user: user);
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repo.login(email, password);
      if (result['requireVerification'] == true) {
        state = state.copyWith(isLoading: false);
        return result;
      }
      state = state.copyWith(user: result['user'] as UserModel, isLoading: false);
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<Map<String, dynamic>> register(String name, String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repo.register(name, email, password);
      if (result['requireVerification'] == true) {
        state = state.copyWith(isLoading: false);
        return result;
      }
      state = state.copyWith(user: result['user'] as UserModel, isLoading: false);
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<Map<String, dynamic>> verifyRegistrationOtp(String email, String otp) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repo.verifyRegistrationOtp(email, otp);
      state = state.copyWith(user: result['user'] as UserModel, isLoading: false);
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> resendRegistrationOtp(String email) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.resendRegistrationOtp(email);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repo.signInWithGoogle();
      if (result != null) {
        state = state.copyWith(user: result['user'] as UserModel, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> requestPasswordResetOtp(String email) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.requestPasswordResetOtp(email);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> verifyOtp(String email, String otp) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.verifyOtp(email, otp);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> resetPassword(String email, String otp, String newPassword) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.resetPassword(email, otp, newPassword);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> updateProfile(String name, String bio) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repo.updateProfile(name, bio);
      state = state.copyWith(user: user, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> changePassword(String current, String newPass) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.changePassword(current, newPass);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState();
  }
}

typedef AuthController = AuthNotifier;

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.watch(authRepositoryProvider)),
);

final authControllerProvider = authProvider;
