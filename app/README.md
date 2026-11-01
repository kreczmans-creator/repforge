# RepForge app

Flutter application. Layering and rules: `../docs/wp0/D03-target-architecture.md`; coding standards: `../docs/engineering-standards.md`.

```
lib/
  app/        bootstrap, router, composition root (providers)
  ui/         design system: tokens, theme, Rf* components
  domain/     entities, value objects, Result/AppError, repository interfaces
  data/       drift database + repositories
  features/   <feature>/application (use cases), <feature>/presentation (screens, controllers)
test/         mirrors lib/
integration_test/
```

Generated files (`*.g.dart`, `*.freezed.dart`) are committed; CI fails if they are stale.
