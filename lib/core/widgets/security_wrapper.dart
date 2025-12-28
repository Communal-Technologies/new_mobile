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
          securityCubit.onAppResumed();
        } else {
          // Mark that we should lock on next authentication (if user unlocks and app goes to background again)
          _hasInitializedLock = false;
          _shouldLockOnNextAuth = true;
        }
        break;
      case AppLifecycleState.detached:
        // App is being closed - mark that we should lock on next authentication
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
          securityCubit.checkIdleTimeout();
        } else {
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
            // CRITICAL: Don't rebuild for CheckLoginSuccess, AuthLoading, etc. if they're the same
            return false;
          }
          // Different state types - rebuild needed
          // BUT: Don't rebuild if both are non-authenticated states (CheckLoginSuccess, AuthLoading, etc.)
          // Only rebuild for meaningful transitions (AuthAuthenticated, AuthUnauthenticated, AuthFailure)
          if (previous is! AuthAuthenticated && previous is! AuthUnauthenticated && previous is! AuthFailure &&
              current is! AuthAuthenticated && current is! AuthUnauthenticated && current is! AuthFailure) {
            // Both are intermediate states (CheckLoginSuccess, AuthLoading, etc.) - don't rebuild
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
                        appRouter.go('/welcome');
                      } catch (e) {
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
              return widget.child;
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
            // Other auth states (AuthLoading, etc.) - just continue to show lock screen
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
                  securityCubit.lockApp();
                }
              });
            }
          } else if (_shouldLockOnNextAuth && !_hasInitializedLock) {
            // App was resumed/detached and we haven't locked yet
            _hasInitializedLock = true;
            _shouldLockOnNextAuth = false;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && securityCubit.state == SecurityState.unlocked) {
                securityCubit.lockApp();
              }
            });
          } else {
            // Already handled or no need to lock
            _logState('SKIPPING LOCK');
          }
        }
        
        // User is authenticated, apply security features
        return BlocListener<SecurityCubit, SecurityState>(
          listener: (context, state) {
            final timestamp = DateTime.now().millisecondsSinceEpoch;
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
                return true;
              }
              
              // Only rebuild for meaningful state changes (locked, unlocked, blurred)
              // Don't rebuild for intermediate states that don't affect UI
              final meaningfulStates = [
                SecurityState.locked,
                SecurityState.unlocked,
                SecurityState.blurred,
              ];
              
              final previousIsMeaningful = meaningfulStates.contains(previous);
              final currentIsMeaningful = meaningfulStates.contains(current);
              
              // Only rebuild if transitioning between meaningful states
              if (previousIsMeaningful || currentIsMeaningful) {
                final timestamp = DateTime.now().millisecondsSinceEpoch;
                _logState('BUILDER buildWhen');
                return true;
              }
              
              // Not a meaningful state change - don't rebuild
              return false;
            },
            builder: (context, state) {
              final timestamp = DateTime.now().millisecondsSinceEpoch;
              _logState('BUILDER building');
              
              // CRITICAL: Check actual SecurityCubit state first - if unlocked, show dashboard immediately
              // This prevents showing lock screen after a successful unlock
              final securityCubit = context.read<SecurityCubit>();
              final actualState = securityCubit.state;
              
              if (actualState != SecurityState.locked) {
                // App is not actually locked - show dashboard
                return widget.child;
              }
              
              // App is locked - check if this is a fresh login that just completed
              if (state == SecurityState.locked) {
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
                  // Fresh login detected - unlock and show dashboard
                  securityCubit.unlockApp();
                  securityCubit.recordActivity();
                  // Clear cached lock screen since we're showing dashboard
                  _cachedLockedScreen = null;
                  return widget.child;
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
                          darkTheme: AppTheme.dark,
                          themeMode: ThemeMode.system,
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

