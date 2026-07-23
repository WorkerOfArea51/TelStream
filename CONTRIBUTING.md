# Contributing to TelStream

First off, thank you for considering contributing to TelStream! It's people like you that make open-source software such a great community.

## 🚀 Getting Started
1. **Fork the repo** and clone it locally.
2. Run `flutter pub get` to install dependencies.
3. Make sure you run `flutter analyze` and ensure no analyzer errors exist before opening a PR.

## 🏗 Architecture (Riverpod)
We heavily use **Riverpod 2.x** for state management and dependency injection.
- Prefer `AsyncNotifierProvider` for services that require asynchronous initialization.
- Do not use `Future.delayed` hacks for fake concurrency; use `Isolate.run()` for CPU-heavy tasks.
- Keep UI components small. If a file exceeds ~1000 lines, it probably needs refactoring into smaller widgets.

## 💅 Code Style
- Use `dart format` to format your code.
- Keep imports organized.
- Avoid deprecated properties (e.g., use `activeTrackColor` instead of `activeColor`).

## 📝 Commit Messages
We follow Conventional Commits:
- `feat:` A new feature
- `fix:` A bug fix
- `docs:` Documentation only changes
- `style:` Changes that do not affect the meaning of the code (white-space, formatting, etc)
- `refactor:` A code change that neither fixes a bug nor adds a feature
- `perf:` A code change that improves performance
- `chore:` Changes to the build process or auxiliary tools

Example: `feat: add support for picture-in-picture mode`

Thank you for contributing!
