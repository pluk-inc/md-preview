---
name: swift-concurrency
description: Diagnose Swift Concurrency issues, refactor callback-based code to async/await, and guide Swift 6 migration when working with tasks, actors, @MainActor, Sendable, data races, thread safety, or concurrency-related compiler and linter warnings.
---
# Swift Concurrency

## Fast Path

Before proposing a fix:

1. Analyze `Package.swift` or `.pbxproj` to determine Swift language mode, strict concurrency level, default isolation, and upcoming features. Do this always, not only for migration work.
2. Capture the exact diagnostic and offending symbol.
3. Determine the isolation boundary: `@MainActor`, custom actor, actor instance isolation, or `nonisolated`.
4. Confirm whether the code is UI-bound or intended to run off the main actor. When spawning unstructured tasks, inspect the synchronous prefix (everything before the first `await`): start on `@MainActor` only when that prefix truly needs main-actor access; otherwise use `Task { @concurrent in ... }` and hop back with `MainActor.run` only after the suspension. A trivial non-main line (for example, `print`) followed by main-actor work in the same prefix is not a reason to use `@concurrent`. For delayed retries, timers, and backoff tasks, separate the waiting from the UI mutation. The sleep often belongs off the main actor even when the final state update belongs on it.

Project settings that change concurrency behavior:

| Setting | SwiftPM (`Package.swift`) | Xcode (`.pbxproj`) |
|---|---|---|
| Language mode | `swiftLanguageVersions` or `-swift-version` (`// swift-tools-version:` is not a reliable proxy) | Swift Language Version |
| Strict concurrency | `.enableExperimentalFeature("StrictConcurrency=targeted")` | `SWIFT_STRICT_CONCURRENCY` |
| Default isolation | `.defaultIsolation(MainActor.self)` | `SWIFT_DEFAULT_ACTOR_ISOLATION` |
| Upcoming features | `.enableUpcomingFeature("NonisolatedNonsendingByDefault")` | `SWIFT_UPCOMING_FEATURE_*` |

If any of these are unknown, ask the developer to confirm them before giving migration-sensitive guidance. Do not guess.

Guardrails:

- Do not recommend `@MainActor` as a blanket fix. Justify why the code is truly UI-bound.
- Prefer structured concurrency over unstructured tasks. Use `Task.detached` only with a clear reason.
- If recommending `@preconcurrency`, `@unchecked Sendable`, or `nonisolated(unsafe)`, require a documented safety invariant and a follow-up removal plan.
- Optimize for the smallest safe change. Do not refactor unrelated architecture during migration.
- Course references are for deeper learning only. Use them sparingly and only when they clearly help answer the developer's question.

## Quick Fix Mode

Use Quick Fix Mode when all of these are true:

- The issue is localized to one file or one type.
- The isolation boundary is clear.
- The fix can be explained in 1-2 behavior-preserving steps.

Skip Quick Fix Mode when any of these are true:

- Build settings or default isolation are unknown.
- The issue crosses module boundaries or changes public API behavior.
- The likely fix depends on unsafe escape hatches.

## Common Diagnostics

| Diagnostic | First check | Smallest safe fix | Escalate to |
|---|---|---|---|
| `Main actor-isolated ... cannot be used from a nonisolated context` | Is this truly UI-bound? | Isolate the caller to `@MainActor` or use `await MainActor.run { ... }` only when main-actor ownership is correct. | `references/actors.md`, `references/threading.md` |
| `Actor-isolated type does not conform to protocol` | Must the requirement run on the actor? | Prefer isolated conformance (e.g., `extension Foo: @MainActor SomeProtocol`); use `nonisolated` only for truly nonisolated requirements. | `references/actors.md` |
| `Sending value of non-Sendable type ... risks causing data races` | What isolation boundary is being crossed? | Keep access inside one actor, or convert the transferred value to an immutable/value type. | `references/sendable.md`, `references/threading.md` |
| `SwiftLint async_without_await` | Is `async` actually required by protocol, override, or `@concurrent`? | Remove `async`, or use a narrow suppression with rationale. Never add fake awaits. | `references/linting.md` |
| `wait(...) is unavailable from asynchronous contexts` | Is this legacy XCTest async waiting? | Replace with `await fulfillment(of:)` or Swift Testing equivalents. | `references/testing.md` |
| Core Data concurrency warnings | Are `NSManagedObject` instances crossing contexts or actors? | Pass `NSManagedObjectID` or map to a Sendable value type. | `references/core-data.md` |
| `Thread.current` unavailable from asynchronous contexts | Are you debugging by thread instead of isolation? | Reason in terms of isolation and use Instruments/debugger instead. | `references/threading.md` |
| SwiftLint concurrency-related warnings | Which specific lint rule triggered? | Use `references/linting.md` for rule intent and preferred fixes; avoid dummy awaits. | `references/linting.md` |

## When Quick Fixes Fail

1. Gather project settings if not already confirmed.
2. Re-evaluate which isolation boundaries the type crosses.
3. Route to the matching reference file for a deeper fix.
4. If the fix may change behavior, document the invariant and add verification steps.

## Smallest Safe Fixes

Prefer changes that preserve behavior while satisfying data-race safety:

- **UI-bound state**: isolate the type or member to `@MainActor`.
- **Shared mutable state**: move it behind an `actor`, or use `@MainActor` only if the state is UI-owned.
- **Background work**: when work must hop off caller isolation, use an `async` API marked `@concurrent`; when work can safely inherit caller isolation, use `nonisolated` without `@concurrent`. When spawning a `Task`, match entry isolation to its synchronous prefix. If nothing before the first `await` needs the main actor, use `Task { @concurrent in ... }` and hop back via `await MainActor.run { ... }` for the UI update. If the prefix mixes a trivial non-main statement with main-actor work, keep the inherited `@MainActor` start—splitting the cheap line off-main is not worth an extra hop.
- **Sendability issues**: prefer immutable values and explicit boundaries over `@unchecked Sendable`.

## Concurrency Tool Selection

| Need | Tool | Key Guidance |
|---|---|---|
| Single async operation | `async/await` | Default choice for sequential async work |
| Fixed parallel operations | `async let` | Known count at compile time; auto-cancelled on throw |
| Dynamic parallel operations | `withTaskGroup` | Unknown count; structured — cancels children on scope exit |
| Sync → async bridge | `Task { }` | Inherits actor context; use `Task.detached` only with documented reason |
| Shared mutable state | `actor` | Prefer over locks/queues; keep isolated sections small |
| UI-bound state | `@MainActor` | Only for truly UI-related code; justify isolation |

### Common Scenarios

**Network request with UI update**
```swift
Task { @concurrent in
    let data = try await fetchData()
    await MainActor.run { self.updateUI(with: data) }
}
```

**Processing array items in parallel**
```swift
await withTaskGroup(of: ProcessedItem.self) { group in
    for item in items {
        group.addTask { await process(item) }
    }
    for await result in group {
        results.append(result)
    }
}
```


## Task entry isolation

Match a `Task`'s entry isolation to its synchronous prefix (everything from `{` to the first `await`).

- If anything in that prefix needs `@MainActor`, keep the inherited `@MainActor` start.
- If nothing in that prefix needs `@MainActor`, prefer `Task { @concurrent in ... }` and hop back only for UI-owned mutation.

```swift
// ❌ Synchronous prefix is empty; first work hops away
Task {
    await hopToOtherIsolationDomain()
}

// ❌ Synchronous prefix is only `print` (trivial, non-main); first await hops away
Task {
    print("Also not main-thread-bound")
    await hopToOtherIsolationDomain()
}

// ✅ Start off the main actor, hop back only for UI work
Task { @concurrent in
    await hopToOtherIsolationDomain()
    await MainActor.run { updateUI() }
}

// ✅ Synchronous prefix DOES contain main-actor work — keep inheritance
Task {
    print("debug")              // trivial, non-main — rides along
    self.isLoading = true       // needs @MainActor, before any await
    await fetchData()
}
```

## Swift 6 Migration Quick Guide

Key changes in Swift 6:
- **Strict concurrency checking** enabled by default
- **Complete data-race safety** at compile time
- **Sendable requirements** enforced on boundaries
- **Isolation checking** for all async boundaries

### Migration Validation Loop

Apply this cycle for each migration change:

1. **Build** — Run `swift build` or Xcode build to surface new diagnostics
2. **Fix** — Address one category of error at a time (e.g., all Sendable issues first)
3. **Rebuild** — Confirm the fix compiles cleanly before moving on
4. **Test** — Run the test suite to catch regressions (`swift test` or Cmd+U)
5. **Only proceed** to the next file/module when all diagnostics are resolved

If a fix introduces new warnings, resolve them before continuing. Never batch multiple unrelated fixes — keep commits small and reviewable.

For detailed migration steps, see `references/migration.md`.

## Reference Router

Open the smallest reference that matches the question:

- Foundations
  - `references/async-await-basics.md` — async/await syntax, execution order, async let, URLSession patterns
  - `references/tasks.md` — Task lifecycle, cancellation, priorities, task groups, structured vs unstructured
  - `references/actors.md` — Actor isolation, @MainActor, global actors, reentrancy, custom executors, Mutex
  - `references/sendable.md` — Sendable conformance, value/reference types, @unchecked, region isolation
  - `references/threading.md` — Execution model, suspension points, Swift 6.2 isolation behavior
- Streams
  - `references/async-sequences.md` — AsyncSequence, AsyncStream, when to use vs regular async methods
  - `references/async-algorithms.md` — Debounce, throttle, merge, combineLatest, channels, timers
- Applied topics
  - `references/testing.md` — Swift Testing first, XCTest fallback, leak checks
  - `references/performance.md` — Profiling with Instruments, reducing suspension points, execution strategies
  - `references/memory-management.md` — Retain cycles in tasks, memory safety patterns
  - `references/core-data.md` — NSManagedObject sendability, custom executors, isolation conflicts
- Migration and tooling
  - `references/migration.md` — Swift 6 migration strategy, closure-to-async conversion, @preconcurrency, FRP migration
  - `references/linting.md` — Concurrency-focused lint rules and SwiftLint `async_without_await`
- Glossary
  - `references/glossary.md` — Quick definitions of core concurrency terms

## Verification Checklist

When changing concurrency code:

1. Re-check build settings before interpreting diagnostics.
2. Build and clear one category of errors before moving on. Do not batch unrelated fixes into the same change.
3. Run tests, especially actor-, lifetime-, and cancellation-sensitive tests.
4. Use Instruments for performance claims instead of guessing.
5. Verify deallocation and cancellation behavior for long-lived tasks.
6. Check `Task.isCancelled` in long-running operations.
7. Never use semaphores or ad hoc locking in async contexts when actor isolation or `Mutex` would express ownership more safely.

---

**Note**: This skill is based on the comprehensive [Swift Concurrency Course](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=skill-footer) by Antoine van der Lee.
