# Contributing to DevConnect Manage Kit

Thank you for your interest in contributing! DevConnect Manage Kit is open source and we welcome contributions from the community.

## How to Contribute

1. **Fork** the repository
2. **Create** your feature branch (`git checkout -b feature/my-feature`)
3. **Commit** your changes (`git commit -m 'feat: add my feature'`)
4. **Push** to the branch (`git push origin feature/my-feature`)
5. **Open** a Pull Request

## Development Setup

### Desktop App (Flutter)

```bash
git clone https://github.com/ridelinktechs/devconnect-manage-kit.git
cd devconnect-manage-kit
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d macos
```

### React Native SDK

```bash
cd client_sdks/devconnect-react-native
npm install
npm run build
```

### Flutter SDK

Pure Dart — no build step needed.

### Android SDK

Open `client_sdks/devconnect-android` in Android Studio.

## Guidelines

- Keep PRs focused — one feature or fix per PR
- Follow existing code style
- Add tests if applicable
- Update README if adding new features

## Reporting Issues

- Use [GitHub Issues](https://github.com/ridelinktechs/devconnect-manage-kit/issues)
- Include steps to reproduce
- Include platform, OS version, SDK version

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
