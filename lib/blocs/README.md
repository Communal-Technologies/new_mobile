# State management — Bloc vs Cubit

Audit M40. Both `Bloc` and `Cubit` from `flutter_bloc` coexist in this
codebase. This file documents which to reach for, so we stop adding new
state by coin-flip.

## Use a `Bloc` when

- The state machine has **discrete events** that warrant their own type
  (`LoginRequested`, `LogoutRequested`, `VerifyOtpRequested`).
- The flow **spans multiple screens** and the bloc is provided high in
  the widget tree so screens listen + dispatch.
- The audit trail "what user action caused this state" matters for
  debugging — events are first-class and serializable.
- Concrete examples: `lib/blocs/auth/auth_bloc.dart`. Auth state is
  shared across splash, welcome-back, every protected screen, and the
  router redirect listenable.

## Use a `Cubit` when

- State is **screen-local** or owned by a small widget subtree.
- Methods on the cubit (`unlockApp()`, `recordActivity()`) read more
  naturally than dispatching events.
- There's no event-history value — calls are just imperative state
  setters.
- Concrete examples:
  - `lib/cubits/security/security_cubit.dart` — locks / blurs / idle
    state; exposed via `SecurityWrapper`.
  - `lib/cubits/connectivity/connectivity_cubit.dart` — online/offline
    flag exposed via the network interceptor.
  - `lib/cubits/settings/settings_cubit.dart` — fetches + caches
    `/fetch-system-settings` once at boot.
  - `lib/cubits/splash/splash_cubit.dart` — owns the splash → router
    cold-start decision.

## When in doubt

Prefer `Cubit`. Promote to `Bloc` only when the second event arrives or
when the screens-spanning surface justifies the extra typing. Don't
rewrite an existing `Cubit` into a `Bloc` for symmetry — both are fine.

## DI registration

Both subclass `BlocBase` and are registered the same way:

```dart
@injectable
class FooBloc extends Bloc<FooEvent, FooState> { ... }

@injectable
class BarCubit extends Cubit<BarState> { ... }
```

`@lazySingleton` is appropriate for either when the state must outlive
the screen tree (e.g. `SecurityCubit`, `ConnectivityCubit`). Default to
`@injectable` (factory) for screen-local cubits so each screen gets a
fresh instance.
