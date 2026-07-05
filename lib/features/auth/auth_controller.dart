import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tdlib/td_api.dart' as td;
import '../../core/constants.dart';
import '../../services/tdlib_service.dart';
import '../../services/storage_service.dart';
import '../settings/settings_provider.dart';
import '../../services/sync_service.dart';
import '../../core/logger.dart';

enum AuthStep { loading, waitingForNumber, waitingForCode, waitingForPassword, authenticated, error }

class AuthState {
  final AuthStep step;
  final String? errorMessage;

  AuthState({this.step = AuthStep.loading, this.errorMessage});
  
  AuthState copyWith({AuthStep? step, String? errorMessage}) {
    return AuthState(
      step: step ?? this.step,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AuthController extends Notifier<AuthState> {
  StreamSubscription? _updatesSubscription;
  bool _isResetting = false;

  @override
  AuthState build() {
    _initStream();
    
    // Automatically initialize TDLib using hardcoded constants
    Future.microtask(() => initializeTdlib());
    
    ref.onDispose(() {
      _updatesSubscription?.cancel();
    });
    return AuthState();
  }

  void _initStream() {
    final tdlibService = ref.read(tdlibServiceProvider);
    _updatesSubscription = tdlibService.updates.listen((event) {
      if (event is td.UpdateAuthorizationState) {
        _handleAuthStateChange(event.authorizationState);
      } else if (event is td.TdError) {
        // Log global TDLib errors, but do not break login state or crash the app.
        // Specifically ignore harmless request cancellations / client closure aborts.
        if (event.message != "Request aborted" && !event.message.contains("aborted")) {
          // Only switch to error step if initialization fails completely.
          // In-progress errors are handled locally by setPhoneNumber, checkCode, checkPassword.
          if (state.step == AuthStep.loading) {
            state = state.copyWith(step: AuthStep.error, errorMessage: event.message);
          }
        }
      }
    });
  }

  void initializeTdlib() {
    state = state.copyWith(step: AuthStep.loading, errorMessage: null);
    final storage = ref.read(storageServiceProvider);
    final excludedPaths = storage.getDownloadedFiles().values.toList();
    final settings = ref.read(videoSettingsProvider);
    
    final double? limitMb = settings.cacheLimitMb == -1 ? null : settings.cacheLimitMb.toDouble();
    final int? ttlDays = settings.cacheTtlDays == -1 ? null : settings.cacheTtlDays;

    ref.read(tdlibServiceProvider).init(
      Constants.apiId, 
      Constants.apiHash,
      excludedPaths: excludedPaths,
      limitMb: limitMb,
      ttlDays: ttlDays,
    ).catchError((e) {
      state = state.copyWith(step: AuthStep.error, errorMessage: e.toString());
    });
  }

  void resetAuth() {
    _isResetting = true;
    initializeTdlib();
    
    // Fallback timeout in case TDLib hangs during close/reset
    Future.delayed(const Duration(seconds: 4), () {
      if (_isResetting) {
        _isResetting = false;
        if (state.step != AuthStep.waitingForNumber && state.step != AuthStep.authenticated) {
          Log.w('TDLib reset timeout reached. Forcing re-initialization.');
          initializeTdlib();
        }
      }
    });
  }

  void _handleAuthStateChange(td.AuthorizationState authState) {
    if (authState is td.AuthorizationStateWaitPhoneNumber) {
      _isResetting = false; // Successfully reached phone entry state, reset flag
      state = state.copyWith(step: AuthStep.waitingForNumber, errorMessage: null);
    } else if (authState is td.AuthorizationStateWaitCode) {
      state = state.copyWith(step: AuthStep.waitingForCode, errorMessage: null);
    } else if (authState is td.AuthorizationStateWaitPassword) {
      state = state.copyWith(step: AuthStep.waitingForPassword, errorMessage: null);
    } else if (authState is td.AuthorizationStateReady) {
      _isResetting = false;
      state = state.copyWith(step: AuthStep.authenticated, errorMessage: null);
      ref.read(tdlibServiceProvider).loadChatsInBackground();
      
      // Restore cloud progress sync data on successful login/ready
      Future.delayed(const Duration(seconds: 2), () {
        ref.read(progressSyncServiceProvider.notifier).restoreFromCloud().catchError((e) {
          Log.e('Auto cloud sync restore failed', e);
        });
      });
    } else if (authState is td.AuthorizationStateClosed) {
      if (!_isResetting) {
        // Automatically re-initialize TDLib to allow logging in again immediately
        Future.microtask(() => initializeTdlib());
      }
    }
  }

  Future<void> setPhoneNumber(String phoneNumber) async {
    state = state.copyWith(step: AuthStep.loading, errorMessage: null);
    final response = await ref.read(tdlibServiceProvider).sendAsync(td.SetAuthenticationPhoneNumber(
      phoneNumber: phoneNumber,
      settings: const td.PhoneNumberAuthenticationSettings(
        allowFlashCall: false,
        allowMissedCall: false,
        isCurrentPhoneNumber: false,
        allowSmsRetrieverApi: false,
        authenticationTokens: [],
      ),
    ));
    if (response is td.TdError) {
      state = state.copyWith(
        step: AuthStep.waitingForNumber,
        errorMessage: _mapErrorToFriendlyMessage(response.message),
      );
    }
  }

  Future<void> checkCode(String code) async {
    state = state.copyWith(step: AuthStep.loading, errorMessage: null);
    final response = await ref.read(tdlibServiceProvider).sendAsync(td.CheckAuthenticationCode(code: code));
    if (response is td.TdError) {
      state = state.copyWith(
        step: AuthStep.waitingForCode,
        errorMessage: _mapErrorToFriendlyMessage(response.message),
      );
    }
  }

  Future<void> checkPassword(String password) async {
    state = state.copyWith(step: AuthStep.loading, errorMessage: null);
    final response = await ref.read(tdlibServiceProvider).sendAsync(td.CheckAuthenticationPassword(password: password));
    if (response is td.TdError) {
      state = state.copyWith(
        step: AuthStep.waitingForPassword,
        errorMessage: _mapErrorToFriendlyMessage(response.message),
      );
    }
  }

  void logout() {
    state = state.copyWith(step: AuthStep.loading, errorMessage: null);
    ref.read(tdlibServiceProvider).send(td.LogOut());
  }

  String _mapErrorToFriendlyMessage(String message) {
    if (message.contains("PHONE_NUMBER_INVALID")) {
      return "Invalid phone number. Please check the country code and number.";
    }
    if (message.contains("PHONE_CODE_INVALID")) {
      return "Invalid code. Please try again.";
    }
    if (message.contains("PASSWORD_HASH_INVALID")) {
      return "Incorrect 2FA password. Please try again.";
    }
    if (message.contains("PHONE_NUMBER_FLOOD")) {
      return "Too many attempts. Please try again later.";
    }
    if (message.contains("PHONE_CODE_EXPIRED")) {
      return "The code has expired. Please request a new one.";
    }
    return message;
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(() {
  return AuthController();
});
