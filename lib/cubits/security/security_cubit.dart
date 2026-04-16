import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum SecurityState {
  unlocked,
  locked,
  blurred,
  idlePrompt,
}

class SecurityCubit extends Cubit<SecurityState> {
  final SharedPreferences prefs;
  final FlutterSecureStorage secureStorage;
  DateTime? _lastActivityTime;
  DateTime? _backgroundTime;
  bool _isIdlePromptShown = false;
  DateTime? _lastUnlockTime; // Track when app was last unlocked to prevent immediate re-lock
  bool _isLockedDueToIdleTimeout = false; // Track if app is locked due to idle timeout

  SecurityCubit(this.prefs, this.secureStorage) : super(SecurityState.unlocked) {
    // When cubit is created, check if app should be locked
    // This happens when app is reopened after being closed
    debugPrint('🔒 SECURITY CUBIT - Initialized with state: $state');
    // Initialize activity time to now so idle detection can work immediately
    _lastActivityTime = DateTime.now();
    debugPrint('📊   Initialized _lastActivityTime to: $_lastActivityTime');
  }

  /// Called when app goes to background
  void onAppPaused() {
    _backgroundTime = DateTime.now();
    emit(SecurityState.blurred);
  }

  /// Called when app comes to foreground
  void onAppResumed() {
    // CRITICAL: If app is locked, do NOT unlock it - user must enter PIN
    if (state == SecurityState.locked) {
      debugPrint('📊   App resumed but is locked - NOT unlocking (user must enter PIN)');
      return;
    }
    
    if (_backgroundTime != null) {
      final duration = DateTime.now().difference(_backgroundTime!);
      // If app was in background for more than 30 seconds, require PIN again but keep the session token
      if (duration.inSeconds > 30) {
        lockApp(isIdleTimeout: true);
      } else {
        // Just remove blur and reset activity time
        _backgroundTime = null;
        final now = DateTime.now();
        _lastActivityTime = now; // Reset activity time when resuming
        _lastUnlockTime = now; // Track unlock time to prevent immediate re-lock
        _isIdlePromptShown = false;
        emit(SecurityState.unlocked);
      }
    } else {
      // App resumed but wasn't in background (e.g., status bar interaction)
      // Only unlock if app is not already locked
      // If app is blurred, just remove blur
      if (state == SecurityState.blurred) {
        _backgroundTime = null;
        final now = DateTime.now();
        _lastActivityTime = now;
        _lastUnlockTime = now;
        _isIdlePromptShown = false;
        emit(SecurityState.unlocked);
      } else if (state == SecurityState.unlocked) {
        // Already unlocked, just reset activity time
        final now = DateTime.now();
        _lastActivityTime = now;
        _lastUnlockTime = now;
        _isIdlePromptShown = false;
        // Don't emit - already unlocked
      }
      // If state is locked, do nothing - user must enter PIN
    }
  }

  /// Called when the process is about to detach (swipe away / restart).
  /// Use the same policy as idle lock: keep the auth token so the next launch can go
  /// straight to PIN / welcome-back instead of treating the user as logged out.
  void onAppDetached() {
    lockApp(isIdleTimeout: true);
  }

  /// Lock the app (requires re-authentication)
  /// [isIdleTimeout] - if true, this lock is due to idle timeout
  /// When idle timeout locks the app, the token is NOT deleted - user must still re-authenticate with PIN
  /// When app locks due to other reasons (pause, logout, etc.), the token IS deleted
  void lockApp({bool isIdleTimeout = false}) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final stackTrace = StackTrace.current;
    debugPrint('📊 [${timestamp}] 🔒 SECURITY CUBIT - lockApp() CALLED');
    debugPrint('📊   Current state before lock: $state');
    debugPrint('📊   isIdleTimeout: $isIdleTimeout');
    debugPrint('📊   Instance hash: ${hashCode}');
    debugPrint('📊   Stack trace: ${stackTrace.toString().split('\n').take(5).join('\n')}');
    
    // CRITICAL: Only delete token when app locks due to reasons OTHER than idle timeout
    // For idle timeout: Keep the token but still require PIN validation to unlock
    // For other locks (app pause, logout, etc.): Delete token to force full re-authentication
    // This ensures:
    // 1. Idle timeout: User can unlock with PIN (token still valid, but PIN must be validated)
    // 2. Other locks: User must fully re-authenticate (token deleted)
    // Note: We don't await this - it happens asynchronously, but state is emitted immediately
    // IMPORTANT: We keep the login in secure storage so it can be displayed on the lock screen
    if (!isIdleTimeout) {
      // Not an idle timeout lock - delete token to force full re-authentication
      secureStorage.delete(key: 'token').then((_) {
        debugPrint('📊   🗑️ Deleted token from secure storage (app is locking - NOT idle timeout)');
      }).catchError((e) {
        debugPrint('📊   ⚠️ Error deleting token: $e');
      });
    } else {
      // Idle timeout lock - keep token but user must still validate PIN
      debugPrint('📊   🔒 Idle timeout lock - KEEPING token (user must still validate PIN to unlock)');
      debugPrint('📊   🔒 PIN will be validated with backend before unlocking');
    }
    // DO NOT delete login - we need it to display on the lock screen (even for idle timeout)
    
    // Track if this is an idle timeout lock (for tracking purposes)
    _isLockedDueToIdleTimeout = isIdleTimeout;
    
    emit(SecurityState.locked);
    debugPrint('📊   Emitted SecurityState.locked');
    debugPrint('📊   State after emit: $state');
  }
  
  /// Check if app is locked due to idle timeout
  bool get isLockedDueToIdleTimeout => _isLockedDueToIdleTimeout;

  /// Unlock the app after successful authentication
  void unlockApp() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final stackTrace = StackTrace.current;
    debugPrint('📊 [${timestamp}] 🔓 SECURITY CUBIT - unlockApp() CALLED');
    debugPrint('📊   Current state before unlock: $state');
    debugPrint('📊   Instance hash: ${hashCode}');
    debugPrint('📊   Stack trace: ${stackTrace.toString().split('\n').take(5).join('\n')}');
    
    // CRITICAL: Reset activity time to NOW to prevent immediate re-lock from idle detection
    final now = DateTime.now();
    _lastActivityTime = now;
    _lastUnlockTime = now; // Track unlock time to prevent immediate re-lock
    _isIdlePromptShown = false;
    _backgroundTime = null; // Clear background time as well
    _isLockedDueToIdleTimeout = false; // Clear idle timeout flag
    
    debugPrint('📊   Reset _lastActivityTime to: $_lastActivityTime');
    debugPrint('📊   Set _lastUnlockTime to: $_lastUnlockTime');
    debugPrint('📊   Reset _isIdlePromptShown to: $_isIdlePromptShown');
    debugPrint('📊   Reset _isLockedDueToIdleTimeout to: $_isLockedDueToIdleTimeout');
    
    // Always emit unlocked state - this will trigger BlocBuilder rebuild
    // Even if state is already unlocked, emitting again ensures the widget tree updates
    emit(SecurityState.unlocked);
    debugPrint('📊   Emitted SecurityState.unlocked');
    debugPrint('📊   State after emit: $state');
  }

  /// Record user activity (called on user interaction)
  void recordActivity() {
    // CRITICAL: Do NOT record activity if app is locked
    // User must enter PIN/password to unlock, not just interact
    if (state == SecurityState.locked) {
      debugPrint('📊   ⚠️ Attempted to record activity while app is LOCKED - ignoring');
      return;
    }
    
    _lastActivityTime = DateTime.now();
    _isIdlePromptShown = false;
    
    // Clear unlock time tracking after user interacts (they're actively using the app)
    _lastUnlockTime = null;
    
    // If we're in idle prompt state, go back to unlocked
    if (state == SecurityState.idlePrompt) {
      emit(SecurityState.unlocked);
    }
  }

  /// Check for idle timeout
  void checkIdleTimeout() {
    // Don't check idle timeout if app is already locked
    if (state == SecurityState.locked) {
      debugPrint('📊   Skipping idle check - app is locked');
      return;
    }
    
    // CRITICAL: Prevent immediate re-lock after unlock (give at least 30 seconds grace period)
    // This ensures the app doesn't lock immediately after user successfully enters PIN
    if (_lastUnlockTime != null) {
      final timeSinceUnlock = DateTime.now().difference(_lastUnlockTime!);
      if (timeSinceUnlock.inSeconds < 30) {
        debugPrint('📊   Skipping idle check - just unlocked ${timeSinceUnlock.inSeconds}s ago (grace period)');
        return;
      }
    }
    
    // If _lastActivityTime is null, initialize it to now (first check after unlock)
    // This prevents locking immediately if the timer runs before any user interaction
    if (_lastActivityTime == null) {
      debugPrint('📊   Initializing _lastActivityTime to now (first idle check)');
      _lastActivityTime = DateTime.now();
      return;
    }

    final idleDuration = DateTime.now().difference(_lastActivityTime!);
    debugPrint('📊   Idle duration: ${idleDuration.inMinutes}m ${idleDuration.inSeconds % 60}s');
    
    // After 2 minutes idle, lock the app
    if (idleDuration.inMinutes >= 2) {
      debugPrint('📊   🔒 Locking app due to idle timeout (${idleDuration.inMinutes}m idle)');
      lockApp(isIdleTimeout: true);
    }
    // After 1 minute idle, show prompt
    else if (idleDuration.inMinutes >= 1 && !_isIdlePromptShown) {
      debugPrint('📊   ⏰ Showing idle prompt (${idleDuration.inMinutes}m idle)');
      _isIdlePromptShown = true;
      emit(SecurityState.idlePrompt);
    }
  }

  /// Reset idle state (user confirmed they're still there)
  void resetIdle() {
    _lastActivityTime = DateTime.now();
    _isIdlePromptShown = false;
    emit(SecurityState.unlocked);
  }
}

