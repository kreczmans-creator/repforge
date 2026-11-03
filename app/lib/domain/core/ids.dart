/// Generates record identifiers (UUID v4 in production). Injected so tests
/// can be deterministic.
typedef IdGenerator = String Function();
