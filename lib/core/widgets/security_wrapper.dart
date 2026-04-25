import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:communal_mobile/cubits/security/security_cubit.dart';
import 'package:communal_mobile/core/widgets/blur_overlay.dart';
import 'package:communal_mobile/core/widgets/idle_prompt_dialog.dart';
import 'package:communal_mobile/screens/auth/welcome_back_screen.dart';
import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_event.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/theme/colors.dart';
import 'package:communal_mobile/core/security/session_invalidation_notifier.dart';
import 'package:communal_mobile/routes/app_routes.dart';
import 'package:communal_mobile/core/navigation/root_navigator_key.dart';

/// True while the initial splash is active — do not override routing (e.g. to /welcome).
bool _isOnSplashRoute() {
  try {
    final path = appRouter.state.uri.path;
    return path == '/' || path.isEmpty;
  } catch (_) {
    return false;
  }
}

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
  static const Duration _sessionHeartbeatInterval = Duration(seconds: 45);

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

  /// Prevents stacking multiple idle dialogs if the cubit re-emits before dismiss.
  bool _idlePromptDialogOpen = false;

  // Key for widget.child to force rebuild when unlocking
  int _childKey = 0;
  DateTime? _lastSessionHeartbeatAt;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    appRouter.routeInformationProvider.addListener(_onRouteLocationChanged);
    
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
    appRouter.routeInformationProvider.removeListener(_onRouteLocationChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// When the user navigates into KYC, clear any idle prompt and refresh activity so
  /// [checkIdleTimeout] does not fire while they work through long forms.
  void _onRouteLocationChanged() {
    if (!mounted) return;
    if (!_isKycFlowActive()) return;
    try {
      final securityCubit = context.read<SecurityCubit>();
      if (securityCubit.state == SecurityState.idlePrompt) {
        securityCubit.resetIdle();
      } else {
        securityCubit.recordActivity();
      }
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final securityCubit = context.read<SecurityCubit>();
    final authState = context.read<AuthBloc>().state;

    switch (state) {
      case AppLifecycleState.paused:
        // Only blur when a member session is active (same as before).
        if (authState is! AuthAuthenticated) {
          return;
        }
        securityCubit.onAppPaused();
        break;
      case AppLifecycleState.resumed:
        // Clear privacy blur when actually returning to the app ([paused]/[hidden] had run).
        // Do not blur on [inactive] — that also runs for the notification shade / system sheets.
        if (securityCubit.state == SecurityState.locked) {
          _hasInitializedLock = false;
          _shouldLockOnNextAuth = true;
        } else {
          securityCubit.onAppResumed();
        }
        break;
      case AppLifecycleState.detached:
        if (authState is! AuthAuthenticated) {
          return;
        }
        _hasInitializedLock = false;
        _shouldLockOnNextAuth = true; // Lock when user becomes authenticated after detach
        securityCubit.onAppDetached();
        break;
      case AppLifecycleState.inactive:
        // Intentionally no security action: this state also occurs when opening the notification
        // shade, control center, etc. Blurring here looked like a lock and forced spurious PIN UX.
        break;
      case AppLifecycleState.hidden:
        if (authState is! AuthAuthenticated) {
          return;
        }
        securityCubit.onAppPaused();
        break;
    }
  }

  /// KYC flows can take several minutes; idle prompts / auto-lock would interrupt uploads and forms.
  ///
  /// Prefer [GoRouter.state] — [RouteInformationProvider.value] can lag or not match the
  /// active match list, which caused idle prompts to fire on `/kyc/*` despite the exemption.
  bool _isKycFlowActive() {
    bool segmentIsKyc(String? p) {
      if (p == null || p.isEmpty) return false;
      return p.startsWith('/kyc') ||
          p.startsWith('kyc/') ||
          p.contains('/kyc/');
    }

    try {
      final s = appRouter.state;
      if (segmentIsKyc(s.uri.path)) return true;
      if (segmentIsKyc(s.matchedLocation)) return true;
      if (segmentIsKyc(s.fullPath)) return true;
      final name = s.name;
      if (name != null && name.startsWith('kyc-')) return true;
      try {
        final enginePath = appRouter.routeInformationProvider.value.uri.path;
        if (segmentIsKyc(enginePath)) return true;
      } catch (_) {}
    } catch (_) {}
    return false;
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
          _runSessionHeartbeat(authState);
          if (_isKycFlowActive()) {
            // Dismiss idle prompt if user navigated into KYC; keep activity fresh so timer doesn't fire on exit.
            if (securityCubit.state == SecurityState.idlePrompt) {
              securityCubit.resetIdle();
            } else {
              securityCubit.recordActivity();
            }
          } else {
            securityCubit.checkIdleTimeout();
          }
        } else {
        }
        _startIdleDetection(); // Continue checking
      }
    });
  }

  void _runSessionHeartbeat(AuthAuthenticated authState) {
    final now = DateTime.now();
    final last = _lastSessionHeartbeatAt;
    if (last != null && now.difference(last) < _sessionHeartbeatInterval) {
      return;
    }

    _lastSessionHeartbeatAt = now;
    context.read<AuthBloc>().add(AuthRefreshUserRequested());
  }

  void _handleUserInteraction() {
    // Record activity on any user interaction
    context.read<SecurityCubit>().recordActivity();
  }

  /// Idle detection only runs when authenticated; taps must reset the timer on every screen.
  /// Early `return widget.child` paths previously skipped this wrapper, so idle fired using
  /// stale activity from app start or pre-login.
  Widget _wrapDashboardWithIdleTracking(Widget child) {
    return GestureDetector(
      key: const ValueKey('unlocked_screen'),
      onTap: () {
        final securityCubit = context.read<SecurityCubit>();
        if (securityCubit.state != SecurityState.locked) {
          _handleUserInteraction();
        }
      },
      onPanDown: (_) {
        final securityCubit = context.read<SecurityCubit>();
        if (securityCubit.state != SecurityState.locked) {
          _handleUserInteraction();
        }
      },
      behavior: HitTestBehavior.translucent,
      child: child,
    );
  }

  void _logState(String action) {
    // Logging disabled - can be enabled for debugging
  }

  Widget _buildSessionInvalidationOverlay(Widget child, String message) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned.fill(
          child: AbsorbPointer(
            absorbing: true,
            child: Container(color: Colors.black.withValues(alpha: 0.55)),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 34),
                    const SizedBox(height: 10),
                    const Text(
                      'Session Ended',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          clearSessionInvalidation();
                          context.read<SecurityCubit>().unlockApp();
                          context.read<AuthBloc>().add(LogoutRequested());
                          appRouter.go('/welcome');
                        },
                        child: const Text('Log out'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final securityContent = BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          current is AuthAuthenticated && previous is! AuthAuthenticated,
      listener: (context, state) {
        context.read<SecurityCubit>().recordActivity();
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
            if (previous is AuthVerifyingCredentials && current is AuthVerifyingCredentials) {
              return previous.attemptId != current.attemptId;
            }
            if (previous is AuthSessionTakeoverPending && current is AuthSessionTakeoverPending) {
              return previous.takeoverChallengeId != current.takeoverChallengeId;
            }
            // Same state type and same content - no rebuild needed
            // CRITICAL: Don't rebuild for CheckLoginSuccess, AuthLoading, etc. if they're the same
            return false;
          }
          // Different state types - rebuild needed
          // BUT: Don't rebuild if both are non-authenticated states (CheckLoginSuccess, AuthLoading, etc.)
          // Only rebuild for meaningful transitions (AuthAuthenticated, AuthUnauthenticated, AuthFailure)
          if (previous is! AuthAuthenticated && previous is! AuthUnauthenticated && previous is! AuthFailure &&
              previous is! AuthSessionTakeoverPending &&
              current is! AuthAuthenticated && current is! AuthUnauthenticated && current is! AuthFailure &&
              current is! AuthSessionTakeoverPending) {
            // Both are intermediate states (CheckLoginSuccess, AuthLoading, AuthVerifyingCredentials, etc.) - don't rebuild
            return false;
          }
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
            
            // CRITICAL: When AuthUnauthenticated is emitted, check if it's fresh install or logout
            // Fresh install: No login in storage → Don't lock, let router show welcome/onboarding
            // Logout: Login exists → Unlock and navigate to welcome
            if (authState is AuthUnauthenticated) {
              
              // Check if login exists in secure storage
              final secureStorage = securityCubit.secureStorage;
              secureStorage.read(key: 'login').then((login) {
                final hasLogin = login != null && login.isNotEmpty;
                
                // Reset all security flags
                _hasInitializedLock = false;
                _shouldLockOnNextAuth = false;
                _hasSeenAuthBefore = false;
                _userJustUnlocked = false;
                _isFreshLogin = false;
                _isFromWelcomeBackScreen = false;
                _freshLoginTimestamp = null;
                _lastUnlockTime = null;
                _cachedLockedScreen = null;
                
                if (hasLogin) {
                  // Logout scenario - unlock and navigate
                  if (securityCubit.state == SecurityState.locked) {
                    securityCubit.unlockApp();
                  }
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      try {
                        // SplashCubit owns cold-start routing (offline, onboarding, welcome).
                        // [AppStarted] often finishes before splash and emits [AuthUnauthenticated]
                        // when the token check fails offline — do not steal the router.
                        if (_isOnSplashRoute()) {
                          return;
                        }
                        appRouter.go('/welcome');
                      } catch (e) {
                        // Router may be unavailable during transitional teardown; ignore.
                      }
                    }
                  });
                } else {
                  // Fresh install - don't lock, let router handle it
                  if (securityCubit.state == SecurityState.locked) {
                    securityCubit.unlockApp();
                  }
                }
              });
              
              // Reset flags immediately (async check will handle navigation)
              _hasInitializedLock = false;
              _shouldLockOnNextAuth = false;
              _hasSeenAuthBefore = false;
              _userJustUnlocked = false;
              _isFreshLogin = false;
              _isFromWelcomeBackScreen = false;
              _freshLoginTimestamp = null;
              _lastUnlockTime = null;
              _cachedLockedScreen = null;
              
            } else if (authState is AuthFailure) {
              // CRITICAL: AuthFailure means wrong password
              // BUT: Only lock the app if it's already locked (app lock scenario)
              // If app is NOT locked, this is a fresh login - let WelcomeBackScreen handle the error
              
              if (securityCubit.state == SecurityState.locked) {
                // App is already locked (app lock scenario) - keep it locked
                // Continue to SecurityCubit builder below to show lock screen
              } else {
                // App is NOT locked (fresh login scenario) - DO NOT lock it
                // Let WelcomeBackScreen handle the error display without rebuilding
                // Return widget.child to prevent rebuild - WelcomeBackScreen will show the error
                return widget.child;
              }
            }
            
            // Only reset _hasInitializedLock if app is not locked (and not already reset for logout)
            // If app is locked, user is in the process of unlocking, so keep the flag
            if (authState is! AuthUnauthenticated && securityCubit.state != SecurityState.locked) {
              _hasInitializedLock = false;
            }
            
            // CRITICAL: If app is locked (due to AuthFailure or other reasons), show lock screen
            // BUT: If AuthUnauthenticated and no login exists (fresh install), don't show lock screen
            if (authState is AuthUnauthenticated) {
              // For fresh install, check if login exists asynchronously
              // If no login, unlock and return widget.child to let router handle it
              final secureStorage = securityCubit.secureStorage;
              secureStorage.read(key: 'login').then((login) {
                final hasLogin = login != null && login.isNotEmpty;
                if (!hasLogin && securityCubit.state == SecurityState.locked) {
                  // Fresh install but locked - unlock it
                  securityCubit.unlockApp();
                }
              });
              
              // If app is not locked, return widget.child to let router handle navigation
              if (securityCubit.state != SecurityState.locked) {
                return widget.child;
              }
            }
            
            // If app is locked, show lock screen
            if (securityCubit.state == SecurityState.locked) {
              // Continue to SecurityCubit builder below - don't return widget.child
              // Fall through to SecurityCubit builder
            } else {
              // Don't reset _shouldLockOnNextAuth here - keep it for when user becomes authenticated
              // Never return widget.child while PIN is verifying: that strips the SecurityCubit subtree,
              // disposes WelcomeBack's BlocListener, and the next AuthFailure/AuthAuthenticated can be
              // missed or mishandled (cold start keeps SecurityCubit unlocked until first PIN).
              if (authState is! AuthVerifyingCredentials &&
                  authState is! AuthSessionTakeoverPending) {
                return widget.child;
              }
            }
          }
        
        // User is authenticated OR app is locked (even with AuthFailure) - check security state
        final securityCubit = context.read<SecurityCubit>();
        
        // CRITICAL: If app is LOCKED, check if this is a fresh login that just completed
        // BUT: Skip fresh login check if AuthFailure occurred (wrong PIN entered)
        // The key indicator: if we haven't seen AuthAuthenticated before AND SecurityCubit is locked,
        // it means WelcomeBackScreen just validated PIN and will unlock SecurityCubit
        // We should NOT show lock screen in this case - show dashboard instead
        if (securityCubit.state == SecurityState.locked) {
          // CRITICAL: If AuthFailure occurred, this is NOT a fresh login - user entered wrong PIN
          // Skip fresh login check and go directly to showing lock screen
          if (authState is AuthFailure) {
            // Clear any stale fresh login flags
            _isFreshLogin = false;
            _isFromWelcomeBackScreen = false;
            _freshLoginTimestamp = null;
            // Continue to SecurityCubit builder to show lock screen
          } else if (authState is AuthAuthenticated) {
            // Only check for fresh login if AuthAuthenticated (not AuthFailure)
            
            // CRITICAL: Check if this is a recently completed fresh login (within last 5 seconds)
            final recentlyCompletedFreshLogin = _freshLoginTimestamp != null && 
                DateTime.now().difference(_freshLoginTimestamp!).inSeconds < 5;
            
            // CRITICAL: If this is the first time seeing AuthAuthenticated, it's a fresh login
            // OR if we just completed a fresh login recently, unlock immediately
            if (!_hasSeenAuthBefore || recentlyCompletedFreshLogin) {
              if (!_hasSeenAuthBefore) {
                _hasSeenAuthBefore = true;
                _isFreshLogin = true;
                _isFromWelcomeBackScreen = true;
                _freshLoginTimestamp = DateTime.now();
              }
              _hasInitializedLock = true;
              _shouldLockOnNextAuth = false;
              // CRITICAL: Unlock SecurityCubit IMMEDIATELY to prevent lock screen from showing
              securityCubit.unlockApp();
              securityCubit.recordActivity();
            } else {
              // We've seen AuthAuthenticated before, so this is an app lock scenario
              // User is unlocking the app after it was locked (idle timeout, app pause, etc.)
            }
          } else {
            // Other auth states (AuthLoading, AuthVerifyingCredentials, etc.) - just continue to show lock screen
          }
        }
        // CRITICAL: If app is UNLOCKED, check if we should lock
        else if (securityCubit.state == SecurityState.unlocked) {
          // Only AuthAuthenticated should drive idle/resume lock policy here. PIN verification uses
          // AuthVerifyingCredentials while SecurityCubit is still unlocked (splash → welcome-back);
          // running this block for that state incorrectly sets fresh-login flags.
          if (authState is AuthAuthenticated) {
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
                _logState('FRESH LOGIN - NO LOCK');
                // DO NOT lock - user just logged in
              } else if (_shouldLockOnNextAuth) {
                // First time seeing AuthAuthenticated BUT app was resumed/detached - lock it
                _hasInitializedLock = true;
                _shouldLockOnNextAuth = false;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && securityCubit.state == SecurityState.unlocked) {
                    securityCubit.lockApp(isIdleTimeout: true);
                  }
                });
              }
            } else if (_shouldLockOnNextAuth && !_hasInitializedLock) {
              // App was resumed/detached and we haven't locked yet
              _hasInitializedLock = true;
              _shouldLockOnNextAuth = false;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && securityCubit.state == SecurityState.unlocked) {
                  securityCubit.lockApp(isIdleTimeout: true);
                }
              });
            } else {
              // Already handled or no need to lock
              _logState('SKIPPING LOCK');
            }
          }
        }
        
        // User is authenticated, apply security features
        return BlocListener<SecurityCubit, SecurityState>(
          listenWhen: (previous, current) =>
              (current == SecurityState.idlePrompt &&
                  previous != SecurityState.idlePrompt) ||
              current == SecurityState.unlocked ||
              (current == SecurityState.locked && previous != SecurityState.locked),
          listener: (context, state) {
            _logState('LISTENER - SecurityState changed');

            // Auto-lock while "Are you still there?" is open: strip only that dialog route
            // so a modal is not left over the PIN screen (and we never pop arbitrary pages).
            if (state == SecurityState.locked) {
              _idlePromptDialogOpen = false;
              final nav = rootNavigatorKey.currentState;
              if (nav != null) {
                nav.popUntil(
                  (route) =>
                      route.settings.name != 'idle_prompt_dialog',
                );
              }
              return;
            }
            
            // CRITICAL: When app is unlocked by user (after entering PIN), this means:
            // 1. User entered PIN on welcome_back_screen
            // 2. Backend validated the PIN (LoginRequested was dispatched)
            // 3. Backend returned AuthAuthenticated
            // 4. welcome_back_screen verified _waitingForBackendValidation was true
            // 5. welcome_back_screen called securityCubit.unlockApp()
            // 6. NOW SecurityCubit emits SecurityState.unlocked
            // This is the ONLY time we should trust that unlock is valid
            if (state == SecurityState.unlocked) {
              
              // Check if this is a fresh login (first time seeing AuthAuthenticated)
              final authState = context.read<AuthBloc>().state;
              if (authState is AuthAuthenticated && !_hasSeenAuthBefore) {
                // This is a fresh login - set fresh login flags
                _isFreshLogin = true;
                _isFromWelcomeBackScreen = true;
                _freshLoginTimestamp = DateTime.now();
              }
              
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
              _childKey++; // Force rebuild by changing key
              _logState('LISTENER - After PIN validation and unlock');
              // BlocBuilder below already rebuilds on [SecurityState.unlocked]. Avoid
              // setState + a second [unlockApp] here — that re-enters layout/focus and
              // triggers "wrong build scope" / InheritedWidget assertions after hot reload.
              if (mounted) {
                setState(() {});
              }
            }
            
            // Idle prompt: [SecurityWrapper] sits above [MaterialApp.router], so
            // Navigator.maybeOf(securityWrapperContext) is null — use [rootNavigatorKey].
            if (state == SecurityState.idlePrompt && mounted) {
              if (_isKycFlowActive()) {
                context.read<SecurityCubit>().resetIdle();
                return;
              }
              if (_idlePromptDialogOpen) return;
              final securityCubit = context.read<SecurityCubit>();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final navContext = rootNavigatorKey.currentContext;
                if (!mounted || navContext == null || !navContext.mounted) {
                  return;
                }
                if (securityCubit.state != SecurityState.idlePrompt) {
                  return;
                }
                _idlePromptDialogOpen = true;
                showDialog<void>(
                  context: navContext,
                  barrierDismissible: false,
                  routeSettings: const RouteSettings(name: 'idle_prompt_dialog'),
                  builder: (_) => BlocProvider.value(
                    value: securityCubit,
                    child: const IdlePromptDialog(),
                  ),
                ).whenComplete(() {
                  _idlePromptDialogOpen = false;
                });
              });
            }
          },
          child: BlocBuilder<SecurityCubit, SecurityState>(
              buildWhen: (previous, current) {
              // CRITICAL: Always rebuild when transitioning to unlocked OR when already unlocked
              // This ensures dashboard is shown immediately after correct PIN
              // Even if state was already unlocked (re-emitted), we need to rebuild to show dashboard
              if (current == SecurityState.unlocked) {
                debugPrint('📊   🔓 SECURITY WRAPPER buildWhen - State is unlocked, ALWAYS rebuilding');
                debugPrint('📊   🔓 Previous: $previous, Current: $current');
                // CRITICAL: Always rebuild when unlocked, even if previous was also unlocked
                // This ensures the MaterialApp is replaced with widget.child
                return true;
              }
              
              // CRITICAL: Also rebuild when transitioning from locked to unlocked
              // This is the most important transition - must rebuild to show dashboard
              if (previous == SecurityState.locked && current == SecurityState.unlocked) {
                debugPrint('📊   🔓 SECURITY WRAPPER buildWhen - locked → unlocked, FORCING rebuild');
                return true;
              }
              
              // Only rebuild when state actually changes
              // This prevents unnecessary rebuilds that cause WelcomeBackScreen to rebuild
              if (previous == current) {
                return false; // Same state, no rebuild needed
              }
              
              // CRITICAL: If transitioning from locked to unlocked, this is likely a successful unlock
              // Set fresh login flags immediately to prevent showing lock screen again
              if (previous == SecurityState.locked && current == SecurityState.unlocked) {
                final authState = context.read<AuthBloc>().state;
                if (authState is AuthAuthenticated && !_hasSeenAuthBefore) {
                  _isFreshLogin = true;
                  _isFromWelcomeBackScreen = true;
                  _freshLoginTimestamp = DateTime.now();
                }
                // Always rebuild when unlocking (important state change)
                // This is critical for showing dashboard after correct PIN
                debugPrint('📊   🔓 SECURITY WRAPPER buildWhen - locked → unlocked, rebuilding');
                return true;
              }
              
              // CRITICAL: If already locked and staying locked, don't rebuild
              // This prevents flickering when wrong PIN is entered (lockApp() called but already locked)
              if (previous == SecurityState.locked && current == SecurityState.locked) {
                return false; // Still locked - no rebuild needed, prevents flicker
              }
              
              // Only rebuild for meaningful state changes (locked, unlocked, blurred)
              // Don't rebuild for intermediate states that don't affect UI
              final meaningfulStates = [
                SecurityState.locked,
                SecurityState.unlocked,
                SecurityState.blurred,
                SecurityState.idlePrompt,
              ];
              
              final previousIsMeaningful = meaningfulStates.contains(previous);
              final currentIsMeaningful = meaningfulStates.contains(current);
              
              // Only rebuild if transitioning between meaningful states
              if (previousIsMeaningful || currentIsMeaningful) {
                _logState('BUILDER buildWhen');
                return true;
              }
              
              // Not a meaningful state change - don't rebuild
              return false;
            },
            builder: (context, state) {
              _logState('BUILDER building');
              debugPrint('📊   🔓 SECURITY WRAPPER BUILDER - State parameter: $state');
              
              // CRITICAL: Check actual SecurityCubit state FIRST (most reliable)
              // This handles edge cases where state parameter hasn't updated yet
              final securityCubit = context.read<SecurityCubit>();
              final actualState = securityCubit.state;
              debugPrint('📊   🔓 SECURITY WRAPPER BUILDER - Actual state: $actualState');
              debugPrint('📊   🔓 SECURITY WRAPPER BUILDER - Cached lock screen: ${_cachedLockedScreen != null ? "EXISTS" : "NULL"}');
              debugPrint('📊   🔓 SECURITY WRAPPER BUILDER - Child key: $_childKey');
              
              // CRITICAL: If actual state is unlocked, show dashboard IMMEDIATELY
              // This is the most reliable check - reads directly from SecurityCubit
              // This MUST be checked first to handle app lock unlock scenario
              if (actualState == SecurityState.unlocked) {
                // Clear cache immediately
                if (_cachedLockedScreen != null) {
                  _cachedLockedScreen = null;
                  debugPrint('📊   🔓 SECURITY WRAPPER BUILDER - Cleared cached lock screen');
                }
                _childKey++; // Force rebuild by changing key
                debugPrint('📊   🔓 SECURITY WRAPPER BUILDER - Actual state is unlocked, showing dashboard');
                debugPrint('📊   🔓 Returning widget.child directly with key: $_childKey');
                // Return widget.child directly - no wrapper needed
                return _wrapDashboardWithIdleTracking(widget.child);
              }
              
              // Fallback: Check state parameter (should match actualState, but check both)
              if (state == SecurityState.unlocked) {
                // App is unlocked - show dashboard immediately
                // CRITICAL: Clear cached lock screen to ensure MaterialApp is removed
                if (_cachedLockedScreen != null) {
                  _cachedLockedScreen = null;
                }
                _childKey++; // Force rebuild by changing key
                debugPrint('📊   🔓 SECURITY WRAPPER BUILDER - State parameter is unlocked, showing dashboard');
                debugPrint('📊   🔓 Returning widget.child directly with key: $_childKey');
                // Return widget.child directly
                return _wrapDashboardWithIdleTracking(widget.child);
              }
              
              // CRITICAL: Double-check if we're in a weird state where state says locked but actual is unlocked
              // This can happen if BlocBuilder didn't rebuild properly
              if (state == SecurityState.locked && actualState == SecurityState.unlocked) {
                debugPrint('📊   ⚠️ SECURITY WRAPPER BUILDER - State mismatch! Parameter says locked but actual is unlocked');
                debugPrint('📊   🔓 Showing dashboard anyway (actual state takes precedence)');
                // CRITICAL: Clear cached lock screen to ensure MaterialApp is removed
                if (_cachedLockedScreen != null) {
                  _cachedLockedScreen = null;
                }
                _childKey++; // Force rebuild by changing key
                debugPrint('📊   🔓 Returning widget.child directly with key: $_childKey');
                // Return widget.child directly
                return _wrapDashboardWithIdleTracking(widget.child);
              }
              
              // CRITICAL: Before checking if locked, verify actual state again
              // Sometimes the state parameter is stale but actualState is current
              if (actualState == SecurityState.unlocked) {
                // App is actually unlocked - show dashboard immediately
                _cachedLockedScreen = null;
                _childKey++;
                debugPrint('📊   🔓 SECURITY WRAPPER BUILDER - Re-check: Actual state is unlocked, showing dashboard');
                return _wrapDashboardWithIdleTracking(widget.child);
              }
              
              // App is locked - check if this is a fresh login that just completed
              if (state == SecurityState.locked) {
                // CRITICAL: Double-check actual state one more time before showing lock screen
                final doubleCheckState = securityCubit.state;
                if (doubleCheckState == SecurityState.unlocked) {
                  _cachedLockedScreen = null;
                  _childKey++;
                  debugPrint('📊   🔓 SECURITY WRAPPER BUILDER - Double-check: State is unlocked, showing dashboard');
                  return _wrapDashboardWithIdleTracking(widget.child);
                }
                
                final authState = context.read<AuthBloc>().state;
                
                // CRITICAL: Check if this is a recently completed fresh login (within last 5 seconds)
                final recentlyCompletedFreshLogin = _freshLoginTimestamp != null && 
                    DateTime.now().difference(_freshLoginTimestamp!).inSeconds < 5;
                
                // CRITICAL: If locked due to idle timeout, ALWAYS show lock screen
                final isIdleTimeoutLock = securityCubit.isLockedDueToIdleTimeout;
                if (isIdleTimeoutLock) {
                  _isFreshLogin = false;
                  _isFromWelcomeBackScreen = false;
                  _freshLoginTimestamp = null;
                } else if (authState is AuthAuthenticated && (recentlyCompletedFreshLogin || _isFreshLogin || _isFromWelcomeBackScreen)) {
                  // Fresh login: never call [unlockApp] synchronously from [build] — it emits
                  // and can re-enter the framework ("wrong build scope", _dependents assertions).
                  _cachedLockedScreen = null;
                  _childKey++;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    final c = context.read<SecurityCubit>();
                    if (c.state == SecurityState.locked) {
                      c.unlockApp();
                      c.recordActivity();
                    }
                  });
                  return _wrapDashboardWithIdleTracking(widget.child);
                }
                
                // App is locked and not a fresh login - show lock screen
                final authBloc = context.read<AuthBloc>();
                
                // Cache the locked screen widget to prevent unnecessary rebuilds
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
                          themeMode: ThemeMode.light,
                          home: RepaintBoundary(
                            child: WelcomeBackScreen(
                              key: const ValueKey('welcome_back_screen_locked'),
                              phoneNumber: '',
                              method: SignInMethod.fingerprint,
                              isAppLock: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                } else {
                }
                
                // CRITICAL: Final check before returning lock screen
                // Sometimes the state parameter is stale but actualState is current
                final finalCheckState = securityCubit.state;
                debugPrint('📊   🔓 SECURITY WRAPPER BUILDER - Final check state: $finalCheckState');
                if (finalCheckState == SecurityState.unlocked) {
                  _cachedLockedScreen = null;
                  _childKey++;
                  debugPrint('📊   🔓 SECURITY WRAPPER BUILDER - Final check: State is unlocked, showing dashboard');
                  debugPrint('📊   🔓 Returning widget.child directly with key: $_childKey');
                  return _wrapDashboardWithIdleTracking(widget.child);
                }
                
                return _cachedLockedScreen!;
              }

              // Show blur overlay if blurred (real background: [paused] / [hidden] only).
              if (state == SecurityState.blurred) {
                return Directionality(
                  textDirection: TextDirection.ltr,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      widget.child,
                      Positioned.fill(
                        child: AbsorbPointer(
                          absorbing: true,
                          child: const BlurOverlay(),
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Normal unlocked state - wrap child to detect interactions
              // Only wrap with GestureDetector if app is NOT locked
              // When locked, the lock screen handles its own interactions
              return _wrapDashboardWithIdleTracking(widget.child);
            },
          ),
      );
        },
      ),
    );

    return ValueListenableBuilder<String?>(
      valueListenable: sessionInvalidationMessage,
      builder: (context, message, child) {
        if (message == null || message.trim().isEmpty) {
          return child!;
        }
        return _buildSessionInvalidationOverlay(child!, message.trim());
      },
      child: securityContent,
    );
  }
}

