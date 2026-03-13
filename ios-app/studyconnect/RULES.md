Swift / SwiftUI Project Rules

Target modern Swift and SwiftUI conventions.
Assume Swift 5.9+ minimum, and prefer Swift 6.2-compatible patterns when possible.

Core rule
Do not use older SwiftUI state-management/property-wrapper patterns when the Observation package can replace them.

Use these modern replacements

Prefer @Observable instead of ObservableObject when modeling observable reference-type state.

Prefer direct observable properties instead of @Published.

Prefer @State for locally owned observable models where appropriate, instead of @StateObject.

Prefer passing observable models directly instead of using @ObservedObject.

Prefer @Environment instead of @EnvironmentObject for subtree/shared dependency injection when applicable.

Keep using @Binding when true two-way binding is needed.

Disallowed or strongly discouraged patterns

Do not introduce ObservableObject unless there is a clear, unavoidable reason.

Do not add @Published to model properties unless there is a clear compatibility reason.

Do not use @StateObject by default.

Do not use @ObservedObject by default.

Do not use @EnvironmentObject by default.

Do not use Grand Central Dispatch APIs such as DispatchQueue.main.async or other GCD-based patterns unless explicitly justified.

Do not use RunLoop.

Do not use MainActor indiscriminately. Use it only when there is a real UI or actor-isolation need.

Do not use ZStack or GeometryReader unless their use is explicitly justified by the layout requirement.

Concurrency rules

Prefer Swift concurrency features over GCD.

Prefer async/await, Task, structured concurrency, and actor-safe code.

If UI work must happen on the main thread, use modern Swift concurrency approaches and only use MainActor where truly necessary.

Avoid legacy thread-dispatch patterns.

State management rules

Build state in the simplest modern way possible.

Make dependencies explicit.

Prefer property-level observation behavior from @Observable over whole-object publishing behavior from older wrappers.

Use @Binding only for genuine child-to-parent writable state flow.

Layout rules

Avoid ZStack unless elements truly need layered visual stacking.

Avoid GeometryReader unless exact parent-size measurement is actually required.

If either ZStack or GeometryReader is used, add a short comment explaining why it is necessary.

Code generation expectations
When generating Swift code for this project:

Default to modern Observation-based state management.

Default to Swift concurrency, not GCD.

Default to simple SwiftUI layouts using VStack, HStack, List, ScrollView, Spacer, padding, frame, and alignment before considering ZStack or GeometryReader.

Keep code minimal, readable, and idiomatic.

Do not add compatibility workarounds for older Swift versions unless asked.

Do not add unnecessary architecture, wrappers, abstractions, or boilerplate.

If a forbidden or discouraged pattern seems necessary, stop and explain why before using it.

Review checklist for generated code
Before finalizing any Swift or SwiftUI code, verify:

No ObservableObject unless justified.

No @Published unless justified.

No @StateObject unless justified.

No @ObservedObject unless justified.

No @EnvironmentObject unless justified.

No DispatchQueue or other GCD usage unless justified.

No RunLoop usage.

No unnecessary MainActor usage.

No ZStack unless justified.

No GeometryReader unless justified.

If uncertain
Choose the more modern SwiftUI/Observation/concurrency approach and avoid legacy patterns by default.