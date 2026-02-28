import 'dart:async';

import 'package:cinemuse_app/core/error/app_exception.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Mocks
class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockGoTrueClient extends Mock implements GoTrueClient {}

void main() {
  late MockSupabaseClient mockSupabaseClient;
  late MockGoTrueClient mockGoTrueClient;
  late AuthService authService;
  late StreamController<AuthState> authStateController;

  final testUser = User(
    id: 'test-id',
    appMetadata: {},
    userMetadata: {},
    aud: '',
    createdAt: '',
  );

  final testSession = Session(
    accessToken: 'test-token',
    tokenType: 'bearer',
    user: testUser,
  );

  setUp(() {
    mockSupabaseClient = MockSupabaseClient();
    mockGoTrueClient = MockGoTrueClient();
    authStateController = StreamController<AuthState>.broadcast();

    // Stub the auth property of the client
    when(() => mockSupabaseClient.auth).thenReturn(mockGoTrueClient);
    
    // Stub onAuthStateChange
    when(() => mockGoTrueClient.onAuthStateChange).thenAnswer(
      (_) => authStateController.stream,
    );
  });

  tearDown(() {
    authStateController.close();
  });

  group('AuthService Initialization', () {
    test('initializes with no user when session is null', () {
      when(() => mockGoTrueClient.currentSession).thenReturn(null);

      authService = AuthService(mockSupabaseClient);

      expect(authService.state, const AsyncValue<User?>.data(null));
    });

    test('initializes with current user when session exists', () {
      when(() => mockGoTrueClient.currentSession).thenReturn(testSession);

      authService = AuthService(mockSupabaseClient);

      expect(authService.state, AsyncValue<User?>.data(testUser));
    });

    test('updates state when onAuthStateChange emits', () async {
      when(() => mockGoTrueClient.currentSession).thenReturn(null);

      authService = AuthService(mockSupabaseClient);

      // Verify initial state
      expect(authService.state, const AsyncValue<User?>.data(null));

      // Emit new state
      authStateController.add(AuthState(AuthChangeEvent.signedIn, testSession));

      // Wait for stream to process
      await Future.delayed(Duration.zero);

      expect(authService.state, AsyncValue<User?>.data(testUser));
    });

    test('updates state to null when onAuthStateChange emits signedOut', () async {
      when(() => mockGoTrueClient.currentSession).thenReturn(testSession);

      authService = AuthService(mockSupabaseClient);

      // Verify initial state
      expect(authService.state, AsyncValue<User?>.data(testUser));

      // Emit signed out state
      authStateController.add(AuthState(AuthChangeEvent.signedOut, null));

      // Wait for stream to process
      await Future.delayed(Duration.zero);

      expect(authService.state, const AsyncValue<User?>.data(null));
    });
  });

  group('AuthService signIn', () {
    setUp(() {
      when(() => mockGoTrueClient.currentSession).thenReturn(null);
      authService = AuthService(mockSupabaseClient);
    });

    test('successfully signs in and updates state via stream', () async {
      when(
        () => mockGoTrueClient.signInWithPassword(
          email: 'test@test.com',
          password: 'password',
        ),
      ).thenAnswer(
        (_) async => AuthResponse(user: testUser, session: testSession),
      );

      // We explicitly DO NOT await here right away to check the loading state
      final future = authService.signIn('test@test.com', 'password');
      
      // Before future completes, state should be loading
      expect(authService.state, const AsyncValue<User?>.loading());

      await future;

      verify(
        () => mockGoTrueClient.signInWithPassword(
          email: 'test@test.com',
          password: 'password',
        ),
      ).called(1);
    });

    test('handles sign in failure', () async {
      final authException = AuthException('Invalid credentials');
      
      when(
        () => mockGoTrueClient.signInWithPassword(
          email: 'test@test.com',
          password: 'wrong_password',
        ),
      ).thenThrow(authException);

      when(() => mockGoTrueClient.currentUser).thenReturn(null);

      expect(
        () => authService.signIn('test@test.com', 'wrong_password'),
        throwsA(isA<AppException>()),
      );

      // Verify state was reset properly. The App Exception contains the message, but the state data remains null.
      await Future.delayed(Duration.zero);
      expect(authService.state.value, null);
    });
  });

  group('AuthService signUp', () {
    setUp(() {
      when(() => mockGoTrueClient.currentSession).thenReturn(null);
      authService = AuthService(mockSupabaseClient);
    });

    test('successfully signs up', () async {
      when(
        () => mockGoTrueClient.signUp(
          email: 'new@test.com',
          password: 'password',
        ),
      ).thenAnswer(
        (_) async => AuthResponse(user: testUser, session: testSession),
      );

      final future = authService.signUp('new@test.com', 'password');
      expect(authService.state, const AsyncValue<User?>.loading());

      await future;

      verify(
        () => mockGoTrueClient.signUp(
          email: 'new@test.com',
          password: 'password',
        ),
      ).called(1);
    });

    test('handles sign up failure', () async {
      final authException = AuthException('User already exists');
      
      when(
        () => mockGoTrueClient.signUp(
          email: 'test@test.com',
          password: 'password',
        ),
      ).thenThrow(authException);

      when(() => mockGoTrueClient.currentUser).thenReturn(null);

      expect(
        () => authService.signUp('test@test.com', 'password'),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('AuthService signOut', () {
    setUp(() {
      when(() => mockGoTrueClient.currentSession).thenReturn(testSession);
      authService = AuthService(mockSupabaseClient);
    });

    test('successfully signs out', () async {
      when(() => mockGoTrueClient.signOut()).thenAnswer((_) async {});

      final future = authService.signOut();
      
      expect(authService.state, const AsyncValue<User?>.loading());

      await future;

      verify(() => mockGoTrueClient.signOut()).called(1);
    });
  });
}
