# Add App Launcher Icons

The goal is to configure and generate app launcher icons for both Android and iOS using the `flutter_launcher_icons` package, utilizing the provided icon image.

## User Review Required

> [!IMPORTANT]
> The project already contains a `flutter_launcher_icons.yaml` file pointing to `icons/icons.png`. However, the active document is `assets/images/icons.png`. I will update the configuration to use `assets/images/icons.png` as it seems to be the intended source.
>
> I will also add the `flutter_launcher_icons` dependency to `pubspec.yaml` as it is currently missing.

## Proposed Changes

### Build Configuration

#### [MODIFY] [pubspec.yaml](file:///C:/Users/AC/StudioProjects/universbook/pubspec.yaml)
- Add `flutter_launcher_icons: ^0.13.1` to `dev_dependencies`.

#### [MODIFY] [flutter_launcher_icons.yaml](file:///C:/Users/AC/StudioProjects/universbook/flutter_launcher_icons.yaml)
- Update `image_path` to `"assets/images/icons.png"`.

## Verification Plan

### Automated Tests
- Run `flutter pub get` to install dependencies.
- Run `flutter pub run flutter_launcher_icons` to generate the icons.
- Verify that `android/app/src/main/res/mipmap-*` directories are updated with new icons.
- Verify that `ios/Runner/Assets.xcassets/AppIcon.appiconset` is updated (if iOS exists and is accessible).

### Manual Verification
- Check the generated files in the file explorer to ensure they match the source image.
