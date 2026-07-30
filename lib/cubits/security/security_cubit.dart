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

  /// In-app blur overlay rendered by [SecurityWrapper] on top of whatever it
  /// would otherwise show. Toggled by [onAppPaused] / [onAppResumed].
  ///
  /// Composes with the locked/unlocked render — i.e. if the app pauses while
  /// unlocked, [onAppPaused] also calls [lockApp], so the blur sits on top
  /// of the lock screen. When the user resumes and the blur is removed, the
  /// lock screen is already in place underneath, no flash of unlocked
  /// content.
  ///
  /// Why a separate Listenable rather than a SecurityState value: the
  /// existing enum is mutually exclusive (locked / unlocked / blurred /
  /// idlePrompt). Keeping blur orthogonal lets it overlay any of the others
  /// without needing a combinatorial enum or a Stream-of-tuple.
  final ValueNotifier<bool> blurOverlay = ValueNotifier<bool>(false);

  /// When set by [beginExternalFilePickerGuard], the next [onAppResumed] skips PIN lock after
  /// [paused]/[hidden] (system gallery / document picker). Cleared on that resume or by
  /// [cancelExternalFilePickerGuard] if the OS never backgrounded the activity.
  bool _externalPickerGuardActive = false;
  bool _externalPickerPauseSeen = false;

  SecurityCubit(this.prefs, this.secureStorage) : super(SecurityState.unlocked) {
    // When cubit is created, check if app should be locked
    // This happens when app is reopened after being closed
    debugPrint('🔒 SECURITY CUBIT - Initialized with state: $state');
    // Initialize activity time to now so idle detection can work immediately
    _lastActivityTime = DateTime.now();
    debugPrint('📊   Initialized _lastActivityTime to: $_lastActivityTime');
  }

  /// Mark a real backgrounding transition ([AppLifecycleState.paused] /
  /// [hidden]). Not tied to [AppLifecycleState.inactive] — that also runs
  /// for the notification shade.
  ///
  /// Lock the session immediately so it sits *behind* the blur overlay
  /// during the background window. On resume the blur is dismissed and the
  /// lock screen is already underneath — no flash of unlocked content
  /// between the blur disappearing and the lock screen appearing.
  ///
  /// Recents-tile / app-switcher privacy is handled natively (Android
  /// `FLAG_SECURE` in `MainActivity`; iOS overlay view in
  /// `AppDelegate.applicationWillResignActive`). The Flutter blur is the
  /// in-app cover (visible during the brief paused window before the OS
  /// snapshot takes over, and during the resume frame before the OS hands
  /// the live frame back).
  void onAppPaused() {
    if (_externalPickerGuardActive) {
      // File picker / gallery transition: treat as in-flow activity, not a
      // true background lock trigger.
      _externalPickerPauseSeen = true;
      _backgroundTime = null;
      return;
    }
    _backgroundTime ??= DateTime.now();
    // Cover the surface immediately so the brief paused-but-still-rendering
    // window is opaque.
    blurOverlay.value = true;
    // Lock behind the blur (no-op if already locked) so the resume reveals
    // a lock screen, not the dashboard.
    if (state != SecurityState.locked) {
      lockApp(isIdleTimeout: true);
    }
  }

  /// Called when the app returns to the foreground.
  ///
  /// The lock state was already set in [onAppPaused], so on resume we just
  /// dismiss the blur overlay — the lock screen is already underneath it.
  void onAppResumed() {
    // Always remove the blur overlay on resume. The state underneath is
    // the lock screen (set on pause) or the dashboard (the legitimate
    // file-picker-guard or fast-resume cases below).
    blurOverlay.value = false;

    if (_externalPickerGuardActive && _externalPickerPauseSeen) {
      _externalPickerGuardActive = false;
      _externalPickerPauseSeen = false;
      _backgroundTime = null;
      _isIdlePromptShown = false;
      final now = DateTime.now();
      _lastActivityTime = now;
      _lastUnlockTime = now;
      return;
    }

    if (state == SecurityState.locked) {
      debugPrint('📊   App resumed but is locked - waiting for PIN entry');
      return;
    }

    if (_backgroundTime != null) {
      // Defensive: onAppPaused should have already locked, but if we get
      // here unlocked, lock now (preserves idle-lock semantics).
      _backgroundTime = null;
      lockApp(isIdleTimeout: true);
      return;
    }

    if (state == SecurityState.unlocked) {
      final now = DateTime.now();
      _lastActivityTime = now;
      _lastUnlockTime = now;
      _isIdlePromptShown = false;
    }
  }

  /// Call immediately before [FilePicker.platform.pickFiles] (or similar) so returning from
  /// the system gallery does not PIN-lock the session.
  void beginExternalFilePickerGuard() {
    _externalPickerGuardActive = true;
    _externalPickerPauseSeen = false;
  }

  /// Call in [finally] after [pickFiles] returns so the guard is not left active if [paused]
  /// never ran (and so a future resume does not incorrectly skip lock).
  void cancelExternalFilePickerGuard() {
    if (!_externalPickerPauseSeen) {
      _externalPickerGuardActive = false;
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
    debugPrint('📊 [$timestamp] 🔒 SECURITY CUBIT - lockApp() CALLED');
    debugPrint('📊   Current state before lock: $state');
    debugPrint('📊   isIdleTimeout: $isIdleTimeout');
    debugPrint('📊   Instance hash: $hashCode');
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
    debugPrint('📊 [$timestamp] 🔓 SECURITY CUBIT - unlockApp() CALLED');
    debugPrint('📊   Current state before unlock: $state');
    debugPrint('📊   Instance hash: $hashCode');
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
    
    // After 5 minutes idle, lock the app
    if (idleDuration.inMinutes >= 5) {
      debugPrint('📊   🔒 Locking app due to idle timeout (${idleDuration.inMinutes}m idle)');
      lockApp(isIdleTimeout: true);
    }
    // After 3 minutes idle, show the "are you still there?" prompt
    // (gives the user 2 minutes to dismiss before the auto-lock above).
    else if (idleDuration.inMinutes >= 3 && !_isIdlePromptShown) {
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

