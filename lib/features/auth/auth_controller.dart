import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tdlib/td_api.dart' as td;
import '../../core/constants.dart';
import '../../services/tdlib_service.dart';

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
        state = state.copyWith(step: AuthStep.error, errorMessage: event.message);
      }
    });
  }

  void initializeTdlib() {
    state = state.copyWith(step: AuthStep.loading, errorMessage: null);
    ref.read(tdlibServiceProvider).init(Constants.apiId, Constants.apiHash).catchError((e) {
      state = state.copyWith(step: AuthStep.error, errorMessage: e.toString());
    });
  }

  void _handleAuthStateChange(td.AuthorizationState authState) {
    if (authState is td.AuthorizationStateWaitPhoneNumber) {
      state = state.copyWith(step: AuthStep.waitingForNumber, errorMessage: null);
    } else if (authState is td.AuthorizationStateWaitCode) {
      state = state.copyWith(step: AuthStep.waitingForCode, errorMessage: null);
    } else if (authState is td.AuthorizationStateWaitPassword) {
      state = state.copyWith(step: AuthStep.waitingForPassword, errorMessage: null);
    } else if (authState is td.AuthorizationStateReady) {
      state = state.copyWith(step: AuthStep.authenticated, errorMessage: null);
      ref.read(tdlibServiceProvider).loadChatsInBackground();
    } else if (authState is td.AuthorizationStateClosed) {
      // Automatically re-initialize TDLib to allow logging in again immediately
      Future.microtask(() => initializeTdlib());
    }
  }

  void setPhoneNumber(String phoneNumber) {
    state = state.copyWith(step: AuthStep.loading);
    ref.read(tdlibServiceProvider).send(td.SetAuthenticationPhoneNumber(
      phoneNumber: phoneNumber,
      settings: const td.PhoneNumberAuthenticationSettings(
        allowFlashCall: false,
        allowMissedCall: false,
        isCurrentPhoneNumber: false,
        allowSmsRetrieverApi: false,
        authenticationTokens: [],
      ),
    ));
  }

  void checkCode(String code) {
    state = state.copyWith(step: AuthStep.loading);
    ref.read(tdlibServiceProvider).send(td.CheckAuthenticationCode(code: code));
  }

  void checkPassword(String password) {
    state = state.copyWith(step: AuthStep.loading);
    ref.read(tdlibServiceProvider).send(td.CheckAuthenticationPassword(password: password));
  }

  void logout() {
    ref.read(tdlibServiceProvider).send(td.LogOut());
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(() {
  return AuthController();
});
