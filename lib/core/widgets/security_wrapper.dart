import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:communal_mobile/cubits/security/security_cubit.dart';
import 'package:communal_mobile/core/widgets/blur_overlay.dart';
import 'package:communal_mobile/core/widgets/idle_prompt_dialog.dart';
import 'package:communal_mobile/screens/auth/welcome_back_screen.dart';
import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/theme/colors.dart';
import 'package:go_router/go_router.dart';
import 'package:communal_mobile/routes/app_routes.dart';

/// Wrapper widget that handles app security (lock, blur, idle detection)
class SecurityWrapper extends StatefulWidget {
  final Widget child;

  const SecurityWrapper({
    super.key,
    required this.child,
  });

  @override
  State<SecurityWrapper> createState() => _SecurityWrapperState();
}

class _SecurityWrapperState extends State<SecurityWrapper>
    with WidgetsBindingObserver {
  bool _hasInitializedLock = false;
  bool _shouldLockOnNextAuth = false; // Track if we should lock when user becomes authenticated
  bool _hasSeenAuthBefore = false; // Track if we've seen AuthAuthenticated before (to distinguish first login vs app start with token)
  DateTime? _lastUnlockTime; // Track when app was last unlocked to prevent immediate re-lock
  bool _userJustUnlocked = false; // Track if user just unlocked via PIN (prevents immediate re-lock)
  bool _isFreshLogin = false; // CRITICAL: Track if this is a fresh login (user just logged in, not app start with token)
  bool _isFromWelcomeBackScreen = false; // Track if AuthAuthenticated came from WelcomeBackScreen (fresh login)
  DateTime? _freshLoginTimestamp; // Track when fresh login was detected
  
  // Cache the locked screen widget to prevent unnecessary rebuilds
  Widget? _cachedLockedScreen;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // CRITICAL: Initialize flags to prevent locking on first login
    // _shouldLockOnNextAuth should only be set when app is resumed/detached
    // NOT on app start or first login
    _shouldLockOnNextAuth = false;
    _hasSeenAuthBefore = false;
    _hasInitializedLock = false;
    _isFreshLogin = false; // Will be set to true when user logs in for first time
    
    // Start idle detection timer
    _startIdleDetection();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final securityCubit = context.read<SecurityCubit>();
    final authState = context.read<AuthBloc>().state;
    
    // Only apply security features if user is authenticated
    if (authState is! AuthAuthenticated) {
      return; // Skip security if not logged in
    }
    
    switch (state) {
      case AppLifecycleState.paused:
        // App went to background
        securityCubit.onAppPaused();
        break;
      case AppLifecycleState.resumed:
        // App came to foreground
        // CRITICAL: If app is currently locked, do NOT call onAppResumed() as it might unlock
        // Only call onAppResumed() if app is not locked (e.g., was blurred)
        if (securityCubit.state != SecurityState.locked) {
          debugPrint('🔒 SECURITY WRAPPER - App resumed, app is not locked - calling onAppResumed()');
          securityCubit.onAppResumed();
        } else {
          debugPrint('🔒 SECURITY WRAPPER - App resumed but app is LOCKED - NOT calling onAppResumed() (user must enter PIN)');
          // Mark that we should lock on next authentication (if user unlocks and app goes to background again)
          _hasInitializedLock = false;
          _shouldLockOnNextAuth = true;
        }
        break;
      case AppLifecycleState.detached:
        // App is being closed - mark that we should lock on next authentication
        debugPrint('🔒 SECURITY WRAPPER - App detached, marking for lock on next auth');
        _hasInitializedLock = false;
        _shouldLockOnNextAuth = true; // Lock when user becomes authenticated after detach
        securityCubit.onAppDetached();
        break;
      case AppLifecycleState.inactive:
        // App is transitioning (e.g., incoming call)
        break;
      case AppLifecycleState.hidden:
        // App is hidden (iOS specific)
        securityCubit.onAppPaused();
        break;
    }
  }

  void _startIdleDetection() {
    // Check for idle timeout every 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        final authState = context.read<AuthBloc>().state;
        final securityCubit = context.read<SecurityCubit>();
        
        // Only check idle timeout if:
        // 1. User is authenticated
        // 2. App is NOT already locked (don't check if locked)
        // Note: Removed _hasInitializedLock check - idle detection should work as soon as user is authenticated
        if (authState is AuthAuthenticated && 
            securityCubit.state != SecurityState.locked) {
          debugPrint('📊   🔍 Checking idle timeout...');
          securityCubit.checkIdleTimeout();
        } else {
          debugPrint('📊   ⏭️ Skipping idle check - authState: ${authState.runtimeType}, securityState: ${securityCubit.state}');
        }
        _startIdleDetection(); // Continue checking
      }
    });
  }

  void _handleUserInteraction() {
    // Record activity on any user interaction
    context.read<SecurityCubit>().recordActivity();
  }

  void _logState(String action) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    debugPrint('📊 [${timestamp}] SECURITY WRAPPER - $action');
    debugPrint('📊   _hasInitializedLock: $_hasInitializedLock');
    debugPrint('📊   _shouldLockOnNextAuth: $_shouldLockOnNextAuth');
    debugPrint('📊   _hasSeenAuthBefore: $_hasSeenAuthBefore');
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) {
        // CRITICAL: Do NOT listen for AuthAuthenticated here
        // The unlock should ONLY happen in WelcomeBackScreen when user successfully enters PIN/password
        // This prevents unlocking when a cached token causes AuthAuthenticated to be emitted
        // (e.g., when user enters wrong password but there's still a valid token in storage)
        return false;
      },
      listener: (context, state) {
        // Listener disabled - unlock only happens in WelcomeBackScreen after successful PIN/password entry
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        buildWhen: (previous, current) {
          // Only rebuild when state type changes or when it's a meaningful transition
          // This prevents unnecessary rebuilds that cause WelcomeBackScreen to rebuild
          if (previous.runtimeType == current.runtimeType) {
            // Same state type - only rebuild if it's AuthFailure with different error
            if (previous is AuthFailure && current is AuthFailure) {
              return previous.error != current.error;
            }
            // Same state type and same content - no rebuild needed
            return false;
          }
          // Different state types - rebuild needed
          return true;
        },
        builder: (context, authState) {
          _logState('BUILD - AuthState: ${authState.runtimeType}');
          
          // If user is not authenticated, skip all security features
          // BUT: Don't reset _hasInitializedLock if app is currently locked (user is entering PIN)
          // This prevents re-locking when AuthBloc goes to AuthLoading during PIN entry
          // CRITICAL: Only unlock SecurityCubit if user is actually unauthenticated (logged out),
          // NOT if there's an AuthFailure (wrong password) - in that case, keep the app locked
          if (authState is! AuthAuthenticated) {
            final securityCubit = context.read<SecurityCubit>();
            
            // CRITICAL: When user logs out (AuthUnauthenticated), reset security state
            // This ensures the app is in a clean state after logout
            if (authState is AuthUnauthenticated) {
              debugPrint('📊   🚪 User logged out - resetting security state');
              // Reset all security flags
              _hasInitializedLock = false;
              _shouldLockOnNextAuth = false;
              _hasSeenAuthBefore = false;
              _userJustUnlocked = false; // Clear unlock flag on logout
              _isFreshLogin = false; // Clear fresh login flag on logout
              _isFromWelcomeBackScreen = false; // Clear WelcomeBackScreen flag on logout
              _freshLoginTimestamp = null; // Clear fresh login timestamp on logout
              _lastUnlockTime = null; // Clear unlock time
              _cachedLockedScreen = null; // Clear cached locked screen on logout
              // CRITICAL: Lock the app when user logs out to prevent unauthorized access
              if (securityCubit.state != SecurityState.locked) {
                securityCubit.lockApp();
              }
              
                  // CRITICAL: Navigate to welcome screen if not already there
                  // Use the global appRouter to avoid context issues when app is locked
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      try {
                        // Try to use context router first (works when not locked)
                        final router = GoRouter.maybeOf(context);
                        if (router != null) {
                          router.go('/welcome');
                          debugPrint('📊   🚪 Navigated to /welcome after logout (using context router)');
                        } else {
                          // If no router in context (locked screen), use global appRouter directly
                          debugPrint('📊   ⚠️ No GoRouter in context - using global appRouter');
                          appRouter.go('/welcome');
                          debugPrint('📊   🚪 Navigated to /welcome after logout (using global appRouter)');
                        }
                      } catch (e) {
                        debugPrint('📊   ⚠️ Could not navigate to /welcome: $e');
                        // Fallback: use global appRouter
                        try {
                          appRouter.go('/welcome');
                          debugPrint('📊   🚪 Navigated to /welcome after logout (fallback to global appRouter)');
                        } catch (e2) {
                          debugPrint('📊   ❌ Failed to navigate even with global appRouter: $e2');
                        }
                      }
                    }
                  });
              
              debugPrint('📊   ✅ Security flags reset - user is logged out');
            } else if (authState is AuthFailure) {
              // CRITICAL: AuthFailure means wrong password - app MUST stay locked
              debugPrint('📊   🔒 Authentication failed (wrong password) - ensuring app stays LOCKED');
              debugPrint('📊   🔒 SecurityCubit state: ${securityCubit.state}');
              if (securityCubit.state != SecurityState.locked) {
                debugPrint('📊   ⚠️ SecurityCubit is NOT locked - locking it NOW');
                securityCubit.lockApp();
                debugPrint('📊   🔒 SecurityCubit state after lock: ${securityCubit.state}');
              } else {
                debugPrint('📊   ✅ SecurityCubit is already locked - good');
              }
              // CRITICAL: If app is locked after AuthFailure, we MUST show lock screen
              // Do NOT return widget.child - continue to SecurityCubit builder which will show lock screen
              if (securityCubit.state == SecurityState.locked) {
                debugPrint('📊   🔒 App is LOCKED after wrong PIN - will show lock screen via SecurityCubit builder');
                // Continue to SecurityCubit builder below - don't return widget.child
              } else {
                debugPrint('📊   ⚠️⚠️⚠️ CRITICAL: App is NOT locked after AuthFailure - this should not happen!');
                // Force lock one more time
                securityCubit.lockApp();
                // Continue to SecurityCubit builder to show lock screen
              }
            }
            
            // Only reset _hasInitializedLock if app is not locked (and not already reset for logout)
            // If app is locked, user is in the process of unlocking, so keep the flag
            if (authState is! AuthUnauthenticated && securityCubit.state != SecurityState.locked) {
              _hasInitializedLock = false;
            }
            
            // CRITICAL: If app is locked (due to AuthFailure or other reasons), show lock screen
            // Do NOT return widget.child if app is locked - continue to SecurityCubit builder
            if (securityCubit.state == SecurityState.locked) {
              debugPrint('📊   🔒 App is LOCKED - will show lock screen via SecurityCubit builder (authState: ${authState.runtimeType})');
              // Continue to SecurityCubit builder below - don't return widget.child
              // Fall through to SecurityCubit builder
            } else {
              debugPrint('📊   User not authenticated, skipping security (locked=${securityCubit.state == SecurityState.locked}, state=${authState.runtimeType})');
              // Don't reset _shouldLockOnNextAuth here - keep it for when user becomes authenticated
              return widget.child;
            }
          }
        
        // User is authenticated OR app is locked (even with AuthFailure) - check security state
        final securityCubit = context.read<SecurityCubit>();
        debugPrint('📊   SecurityCubit state: ${securityCubit.state}');
        debugPrint('📊   AuthState: ${authState.runtimeType}');
        
        // CRITICAL: If app is LOCKED, check if this is a fresh login that just completed
        // BUT: Skip fresh login check if AuthFailure occurred (wrong PIN entered)
        // The key indicator: if we haven't seen AuthAuthenticated before AND SecurityCubit is locked,
        // it means WelcomeBackScreen just validated PIN and will unlock SecurityCubit
        // We should NOT show lock screen in this case - show dashboard instead
        if (securityCubit.state == SecurityState.locked) {
          // CRITICAL: If AuthFailure occurred, this is NOT a fresh login - user entered wrong PIN
          // Skip fresh login check and go directly to showing lock screen
          if (authState is AuthFailure) {
            debugPrint('📊   🔒 App is LOCKED after wrong PIN - will show lock screen (NOT a fresh login)');
            // Clear any stale fresh login flags
            _isFreshLogin = false;
            _isFromWelcomeBackScreen = false;
            _freshLoginTimestamp = null;
            // Continue to SecurityCubit builder to show lock screen
          } else if (authState is AuthAuthenticated) {
            // Only check for fresh login if AuthAuthenticated (not AuthFailure)
            debugPrint('📊   App is LOCKED - checking if this is fresh login');
            
            // CRITICAL: Check if this is a recently completed fresh login
            // If fresh login was completed within last 10 seconds, don't treat as new fresh login
            final recentlyCompletedFreshLogin = _freshLoginTimestamp != null && 
                DateTime.now().difference(_freshLoginTimestamp!).inSeconds < 10;
            
            // CRITICAL: Only treat as fresh login if:
            // 1. We haven't seen AuthAuthenticated before (first time)
            // 2. AND we haven't already completed a fresh login recently (within 10 seconds)
            if (!_hasSeenAuthBefore && !recentlyCompletedFreshLogin) {
              // This is a genuine fresh login - first time seeing AuthAuthenticated
              debugPrint('📊   App is LOCKED - checking if this is fresh login');
              _hasSeenAuthBefore = true;
              _hasInitializedLock = true;
              _shouldLockOnNextAuth = false;
              _isFreshLogin = true; // Mark as fresh login
              _isFromWelcomeBackScreen = true; // Mark that unlock is coming from WelcomeBackScreen
              _freshLoginTimestamp = DateTime.now(); // Record when fresh login was detected
              debugPrint('📊   ✅✅✅ FIRST TIME AuthAuthenticated + SecurityCubit locked = FRESH LOGIN');
              debugPrint('📊   ✅ Flags set: _isFreshLogin=$_isFreshLogin, _isFromWelcomeBackScreen=$_isFromWelcomeBackScreen, _freshLoginTimestamp=$_freshLoginTimestamp');
              // CRITICAL: Unlock SecurityCubit IMMEDIATELY to prevent lock screen from showing
              // This ensures that when SecurityCubit builder runs, it will see unlocked state
              debugPrint('📊   🔓 Unlocking SecurityCubit IMMEDIATELY for fresh login');
              securityCubit.unlockApp();
              securityCubit.recordActivity(); // Record activity to prevent immediate re-lock
              debugPrint('📊   ✅ SecurityCubit unlocked - fresh login will show dashboard');
            } else if (recentlyCompletedFreshLogin) {
              // Fresh login was just completed - don't treat this as a new fresh login
              debugPrint('📊   ⚠️ Fresh login was just completed (${DateTime.now().difference(_freshLoginTimestamp!).inSeconds}s ago) - NOT treating as new fresh login');
              debugPrint('📊   ⚠️ This is likely a rebuild after successful login - unlocking if still locked');
              // If still locked, unlock it (shouldn't happen, but defensive)
              if (securityCubit.state == SecurityState.locked) {
                debugPrint('📊   ⚠️ SecurityCubit is still locked after fresh login - unlocking now');
                securityCubit.unlockApp();
                securityCubit.recordActivity();
              }
            } else {
              // We've seen AuthAuthenticated before, so this is an app lock scenario
              // User is unlocking the app after it was locked (idle timeout, app pause, etc.)
              debugPrint('📊   App is LOCKED - user is entering PIN (app lock scenario)');
              debugPrint('📊   ⚠️ NOT setting _userJustUnlocked - waiting for PIN validation');
              debugPrint('📊   ⚠️ SecurityWrapper will only trust unlock when SecurityCubit emits unlocked');
            }
          } else {
            // Other auth states (AuthLoading, etc.) - just continue to show lock screen
            debugPrint('📊   App is LOCKED - authState is ${authState.runtimeType} - will show lock screen');
          }
        }
        // CRITICAL: If app is UNLOCKED, check if we should lock
        else if (securityCubit.state == SecurityState.unlocked) {
          // Always update _lastUnlockTime FIRST to prevent race conditions
          _lastUnlockTime = DateTime.now();
          final recentlyUnlocked = _lastUnlockTime != null && 
              DateTime.now().difference(_lastUnlockTime!).inSeconds < 15; // 15 second grace period
          
          // CRITICAL LOGIC - SIMPLIFIED:
          // 1. If user just unlocked OR fresh login → DON'T lock
          // 2. If app was resumed/detached → LOCK
          // 3. Otherwise → DON'T lock
          
          // CRITICAL: Check for fresh login FIRST - if app is unlocked and we see AuthAuthenticated
          // for the first time AND app is not locked, it means user just logged in (not app start with token)
          // App start with token would have locked the app first, so we wouldn't see unlocked state
          // ALSO: If user just unlocked via PIN, don't lock again
          if (_userJustUnlocked || recentlyUnlocked || _isFreshLogin) {
            // User just unlocked OR fresh login - don't lock again
            _hasInitializedLock = true;
            _shouldLockOnNextAuth = false;
            _userJustUnlocked = false; // Clear the flag
            // CRITICAL: DON'T clear _isFreshLogin immediately - keep it for a few seconds
            // to handle race condition where SecurityCubit builder runs while still locked
            // The flag will be cleared after the timestamp expires (5 seconds)
            // _isFreshLogin = false; // DON'T clear immediately - let timestamp handle it
            if (!_hasSeenAuthBefore) {
              _hasSeenAuthBefore = true;
            }
            debugPrint('📊   ✅ User just unlocked OR fresh login - preventing re-lock');
            debugPrint('📊   ✅ Keeping _isFreshLogin=true for race condition handling');
            _logState('JUST UNLOCKED OR FRESH LOGIN - preventing re-lock');
          } else if (!_hasSeenAuthBefore) {
            // First time seeing AuthAuthenticated
            _hasSeenAuthBefore = true;
            
            // CRITICAL: If app is unlocked and we haven't seen auth before AND app wasn't resumed,
            // this is a FRESH LOGIN - user just logged in, DON'T lock
            if (!_shouldLockOnNextAuth) {
              _hasInitializedLock = true;
              _shouldLockOnNextAuth = false;
              _lastUnlockTime = DateTime.now();
              _isFreshLogin = true; // Mark as fresh login
              debugPrint('📊   ✅✅✅ FRESH LOGIN DETECTED - First time AuthAuthenticated + app not resumed');
              debugPrint('📊   ✅✅✅ App will NOT lock - user just logged in');
              _logState('FRESH LOGIN - NO LOCK');
              // DO NOT lock - user just logged in
            } else if (_shouldLockOnNextAuth) {
              // First time seeing AuthAuthenticated BUT app was resumed/detached - lock it
              _hasInitializedLock = true;
              _shouldLockOnNextAuth = false;
              debugPrint('🔒 SECURITY WRAPPER - Locking app (app resumed, first auth)');
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && securityCubit.state == SecurityState.unlocked) {
                  securityCubit.lockApp();
                }
              });
            }
          } else if (_shouldLockOnNextAuth && !_hasInitializedLock) {
            // App was resumed/detached and we haven't locked yet
            _hasInitializedLock = true;
            _shouldLockOnNextAuth = false;
            debugPrint('🔒 SECURITY WRAPPER - Locking app (app resumed)');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && securityCubit.state == SecurityState.unlocked) {
                securityCubit.lockApp();
              }
            });
          } else {
            // Already handled or no need to lock
            debugPrint('📊   ✅ Skipping lock (already handled or no need)');
            _logState('SKIPPING LOCK');
          }
        }
        
        // User is authenticated, apply security features
        return BlocListener<SecurityCubit, SecurityState>(
          listener: (context, state) {
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            debugPrint('📊 [${timestamp}] SECURITY WRAPPER LISTENER - State changed to: $state');
            _logState('LISTENER - SecurityState changed');
            
            // CRITICAL: When app is unlocked by user (after entering PIN), this means:
            // 1. User entered PIN on welcome_back_screen
            // 2. Backend validated the PIN (LoginRequested was dispatched)
            // 3. Backend returned AuthAuthenticated
            // 4. welcome_back_screen verified _waitingForBackendValidation was true
            // 5. welcome_back_screen called securityCubit.unlockApp()
            // 6. NOW SecurityCubit emits SecurityState.unlocked
            // This is the ONLY time we should trust that unlock is valid
            if (state == SecurityState.unlocked) {
              debugPrint('📊   ✅ SecurityCubit emitted UNLOCKED - PIN was validated by backend');
              debugPrint('📊   ✅ Setting flags to prevent re-lock');
              // Set flags to prevent re-locking on next build
              _hasInitializedLock = true;
              _shouldLockOnNextAuth = false; // User just unlocked, don't lock again
              _lastUnlockTime = DateTime.now(); // Record unlock time to prevent immediate re-lock
              _userJustUnlocked = true; // Mark that user just unlocked (PIN was validated)
              if (!_hasSeenAuthBefore) {
                _hasSeenAuthBefore = true; // Mark that we've seen authentication
              }
              // Clear cached locked screen since app is now unlocked
              _cachedLockedScreen = null;
              debugPrint('📊   ✅ Flags set - app will NOT re-lock');
              debugPrint('📊   ✅ Cleared cached locked screen - app is unlocked');
              _logState('LISTENER - After PIN validation and unlock');
            }
            
            // Show idle prompt dialog when needed
            if (state == SecurityState.idlePrompt && mounted) {
              // Use Navigator.of(context, rootNavigator: true) to ensure dialog shows
              // even if there's no MaterialApp ancestor yet
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && context.mounted) {
                  // Check if we have a valid MaterialApp context
                  final navigator = Navigator.maybeOf(context, rootNavigator: true);
                  if (navigator != null) {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => const IdlePromptDialog(),
                    );
                  }
                }
              });
            }
          },
          child: BlocBuilder<SecurityCubit, SecurityState>(
            buildWhen: (previous, current) {
              // Only rebuild when state actually changes
              // This prevents unnecessary rebuilds that cause WelcomeBackScreen to rebuild
              if (previous == current) {
                return false; // Same state, no rebuild needed
              }
              final timestamp = DateTime.now().millisecondsSinceEpoch;
              debugPrint('📊 [${timestamp}] SECURITY WRAPPER BUILDER - buildWhen: previous=$previous, current=$current');
              _logState('BUILDER buildWhen');
              return true; // State changed, rebuild needed
            },
            builder: (context, state) {
              final timestamp = DateTime.now().millisecondsSinceEpoch;
              debugPrint('📊 [${timestamp}] SECURITY WRAPPER BUILDER - Building with state: $state');
              _logState('BUILDER building');
              
              // Show lock screen if locked (use welcome-back screen)
              if (state == SecurityState.locked) {
                // CRITICAL: Check if this lock is due to idle timeout
                // If locked due to idle timeout, ALWAYS show lock screen (never treat as fresh login)
                final securityCubit = context.read<SecurityCubit>();
                final isIdleTimeoutLock = securityCubit.isLockedDueToIdleTimeout;
                debugPrint('🔒 SECURITY WRAPPER BUILDER - ⚠️⚠️⚠️ SecurityCubit is LOCKED');
                debugPrint('🔒   isLockedDueToIdleTimeout: $isIdleTimeoutLock');
                
                // CRITICAL: If locked due to idle timeout, ALWAYS show lock screen
                // Do NOT treat idle timeout locks as fresh login
                if (isIdleTimeoutLock) {
                  debugPrint('🔒 SECURITY WRAPPER BUILDER - 🔒🔒🔒 IDLE TIMEOUT LOCK - ALWAYS showing lock screen');
                  debugPrint('🔒   ⚠️ This is NOT a fresh login - user must enter PIN to unlock');
                  // Clear any stale fresh login flags that might have been set incorrectly
                  _isFreshLogin = false;
                  _isFromWelcomeBackScreen = false;
                  _freshLoginTimestamp = null;
                  debugPrint('🔒   ✅ Cleared stale fresh login flags');
                } else {
                  // Not an idle timeout lock - check if this is a fresh login that just completed
                  // If AuthAuthenticated was just received and we haven't seen it before, it's a fresh login
                  // In that case, WelcomeBackScreen will unlock SecurityCubit, so we show dashboard instead
                  final authState = context.read<AuthBloc>().state;
                  debugPrint('🔒   Checking authState: ${authState.runtimeType}');
                  debugPrint('🔒   Current flags: _isFreshLogin=$_isFreshLogin, _isFromWelcomeBackScreen=$_isFromWelcomeBackScreen, _freshLoginTimestamp=$_freshLoginTimestamp');
                  
                  if (authState is AuthAuthenticated) {
                    debugPrint('🔒 SECURITY WRAPPER BUILDER - ✅✅✅ AuthAuthenticated detected, checking for fresh login');
                    
                    // CRITICAL: Check if this is a recently completed fresh login
                    // If fresh login was completed within last 10 seconds, show dashboard (not lock screen)
                    final recentlyCompletedFreshLogin = _freshLoginTimestamp != null && 
                        DateTime.now().difference(_freshLoginTimestamp!).inSeconds < 10;
                    
                    // CRITICAL: Only treat as fresh login if:
                    // 1. Fresh login flags are set AND timestamp is recent (within 10 seconds)
                    // 2. OR this is the first time seeing AuthAuthenticated (genuine fresh login)
                    // BUT: Don't treat as fresh login if we've already seen AuthAuthenticated before AND it's been more than 10 seconds
                    final isGenuineFreshLogin = (!_hasSeenAuthBefore || recentlyCompletedFreshLogin) && 
                        (_isFreshLogin || _isFromWelcomeBackScreen || recentlyCompletedFreshLogin);
                    
                    debugPrint('🔒 SECURITY WRAPPER BUILDER - Checking fresh login scenario');
                    debugPrint('🔒   _hasSeenAuthBefore: $_hasSeenAuthBefore');
                    debugPrint('🔒   _isFromWelcomeBackScreen: $_isFromWelcomeBackScreen');
                    debugPrint('🔒   _isFreshLogin: $_isFreshLogin');
                    debugPrint('🔒   recentlyCompletedFreshLogin: $recentlyCompletedFreshLogin (timestamp: $_freshLoginTimestamp)');
                    debugPrint('🔒   isGenuineFreshLogin: $isGenuineFreshLogin');
                    
                    if (isGenuineFreshLogin) {
                      debugPrint('🔒 SECURITY WRAPPER BUILDER - ✅✅✅ FRESH LOGIN DETECTED - NOT showing lock screen');
                      debugPrint('🔒   ✅ Returning widget.child (dashboard) instead of lock screen');
                      // CRITICAL: If SecurityCubit is still locked but this is a fresh login, unlock it
                      if (securityCubit.state == SecurityState.locked) {
                        debugPrint('🔒   ⚠️ SecurityCubit is still locked - unlocking now');
                        securityCubit.unlockApp();
                        securityCubit.recordActivity();
                      }
                      return widget.child;
                    } else {
                      debugPrint('🔒 SECURITY WRAPPER BUILDER - ⚠️ NOT a fresh login - showing lock screen');
                      debugPrint('🔒   ⚠️ _hasSeenAuthBefore: $_hasSeenAuthBefore');
                      debugPrint('🔒   ⚠️ _isFromWelcomeBackScreen: $_isFromWelcomeBackScreen');
                      debugPrint('🔒   ⚠️ _isFreshLogin: $_isFreshLogin');
                      debugPrint('🔒   ⚠️ recentlyCompletedFreshLogin: $recentlyCompletedFreshLogin');
                      // Clear stale fresh login flags if they exist
                      if (_freshLoginTimestamp != null && !recentlyCompletedFreshLogin) {
                        debugPrint('🔒   🧹 Clearing stale fresh login flags');
                        _isFreshLogin = false;
                        _isFromWelcomeBackScreen = false;
                        _freshLoginTimestamp = null;
                      }
                    }
                  } else if (authState is AuthFailure) {
                    // CRITICAL: AuthFailure means wrong PIN - clear any fresh login flags
                    debugPrint('🔒 SECURITY WRAPPER BUILDER - 🔒 AuthFailure detected - clearing fresh login flags');
                    _isFreshLogin = false;
                    _isFromWelcomeBackScreen = false;
                    _freshLoginTimestamp = null;
                  } else if (authState is AuthFailure) {
                    // CRITICAL: AuthFailure means wrong PIN - clear any fresh login flags
                    debugPrint('🔒 SECURITY WRAPPER BUILDER - 🔒 AuthFailure detected - clearing fresh login flags');
                    _isFreshLogin = false;
                    _isFromWelcomeBackScreen = false;
                    _freshLoginTimestamp = null;
                  }
                }
                
                // If we get here, it's an app lock scenario (not fresh login)
                final authState = context.read<AuthBloc>().state;
                debugPrint('🔒 SECURITY WRAPPER BUILDER - Showing lock screen (app lock scenario)');
                debugPrint('🔒   AuthState: ${authState.runtimeType}');
                debugPrint('🔒   _isFromWelcomeBackScreen: $_isFromWelcomeBackScreen');
                debugPrint('🔒   _isFreshLogin: $_isFreshLogin');
                debugPrint('🔒   _hasSeenAuthBefore: $_hasSeenAuthBefore');
                debugPrint('🔒   _freshLoginTimestamp: $_freshLoginTimestamp');
                debugPrint('🔒   isLockedDueToIdleTimeout: ${securityCubit.isLockedDueToIdleTimeout}');
                // Get the SecurityCubit and AuthBloc from parent context to provide to locked screen
                final authBloc = context.read<AuthBloc>();
                debugPrint('🔒 SECURITY WRAPPER BUILDER - SecurityCubit instance: ${securityCubit.hashCode}');
                debugPrint('🔒 SECURITY WRAPPER BUILDER - SecurityCubit current state: ${securityCubit.state}');
                
                // Cache the locked screen widget to prevent unnecessary rebuilds of WelcomeBackScreen
                // Only recreate if it doesn't exist
                if (_cachedLockedScreen == null) {
                  _cachedLockedScreen = Directionality(
                    key: const ValueKey('locked_screen'),
                    textDirection: TextDirection.ltr,
                    child: Material(
                      child: MultiBlocProvider(
                        providers: [
                          BlocProvider.value(value: securityCubit),
                          BlocProvider.value(value: authBloc),
                        ],
                        child: MaterialApp(
                          key: const ValueKey('locked_material_app'),
                          debugShowCheckedModeBanner: false,
                          theme: AppTheme.light,
                          darkTheme: AppTheme.dark,
                          themeMode: ThemeMode.system,
                          home: WelcomeBackScreen(
                            key: const ValueKey('welcome_back_screen_locked'),
                            phoneNumber: '',
                            method: SignInMethod.fingerprint,
                            isAppLock: true,
                          ),
                        ),
                      ),
                    ),
                  );
                  debugPrint('🔒 SECURITY WRAPPER BUILDER - Created cached locked screen widget');
                } else {
                  debugPrint('🔒 SECURITY WRAPPER BUILDER - Reusing cached locked screen widget (preventing rebuild)');
                }
                
                return _cachedLockedScreen!;
              }

              // Show blur overlay if blurred
              if (state == SecurityState.blurred) {
                return Directionality(
                  textDirection: TextDirection.ltr,
                  child: Stack(
                    children: [
                      widget.child,
                      GestureDetector(
                        onTap: () {
                          context.read<SecurityCubit>().onAppResumed();
                        },
                        child: const BlurOverlay(),
                      ),
                    ],
                  ),
                );
              }

              // Normal unlocked state - wrap child to detect interactions
              debugPrint('🔓 SECURITY WRAPPER BUILDER - Showing unlocked state (child widget)');
              // Only wrap with GestureDetector if app is NOT locked
              // When locked, the lock screen handles its own interactions
              return GestureDetector(
                key: const ValueKey('unlocked_screen'),
                onTap: () {
                  // Only record activity if app is not locked
                  final securityCubit = context.read<SecurityCubit>();
                  if (securityCubit.state != SecurityState.locked) {
                    _handleUserInteraction();
                  }
                },
                onPanDown: (_) {
                  // Only record activity if app is not locked
                  final securityCubit = context.read<SecurityCubit>();
                  if (securityCubit.state != SecurityState.locked) {
                    _handleUserInteraction();
                  }
                },
                behavior: HitTestBehavior.translucent,
                child: widget.child,
              );
            },
          ),
        );
        },
      ),
    );
  }
}

