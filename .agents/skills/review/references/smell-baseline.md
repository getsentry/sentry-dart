# Smell Baseline

A fallback set of code smells (Fowler, _Refactoring_ ch.3) for the Standards axis to apply **only in areas the repo doesn't document**. Two rules bind it:

- **The repo overrides.** A documented standard in `code-guidelines` / `test-guidelines` always wins; where it endorses something this baseline would flag, suppress the smell.
- **Always a judgement call.** Each smell is a labelled heuristic ("possible Feature Envy"), never a hard violation — and skip anything `dart analyze` / `dart format` / lints already enforce.

Each reads *what it is* → *how to fix*; match against the diff.

- **Mysterious Name** — a name that doesn't reveal what it does or holds. → rename; if no honest name comes, the design is murky.
- **Duplicated Code** — the same logic shape in more than one hunk or file in the change. → extract the shared shape, call it from both.
- **Feature Envy** — a method that reaches into another object's data more than its own. → move it onto the data it envies.
- **Data Clumps** — the same few fields/params keep travelling together. → bundle them into one type, pass that.
- **Primitive Obsession** — a primitive or string standing in for a domain concept that deserves its own type. → give the concept a small type (a Dart extension type or value class).
- **Repeated Switches** — the same `switch`/`if`-cascade on the same type recurs across the change. → replace with polymorphism, sealed-class exhaustiveness, or one shared map.
- **Shotgun Surgery** — one logical change forces scattered edits across many files. → gather what changes together into one module.
- **Divergent Change** — one file edited for several unrelated reasons. → split so each module changes for one reason.
- **Speculative Generality** — abstraction, params, or hooks added for needs the spec doesn't have. → delete it; inline until a real need shows.
- **Message Chains** — long `a.b().c().d()` navigation the caller shouldn't depend on. → hide the walk behind one method on the first object.
- **Middle Man** — a class or function that mostly just delegates onward. → cut it, call the real target directly.
- **Shallow Module** — an interface nearly as complex as its implementation (per design-first). → deepen or merge; apply the deletion test.
