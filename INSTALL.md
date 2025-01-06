# Инструкция по установке

## Системные требования

### Общие требования
- [Flutter SDK](https://flutter.dev/docs/get-started/install)
- Git
- VS Code или Android Studio (рекомендуется)

### Windows
- Windows 10 или выше
- Visual Studio 2019 или выше с Desktop development with C++ workload
- Windows 10 SDK

### Android
- Android Studio
- Android SDK
- Java Development Kit (JDK)

## Установка

1. Клонируйте репозиторий:
```bash
git clone [url-репозитория]
cd AIChatFlutter
```

2. Установите Flutter SDK:
   - Скачайте Flutter SDK с [официального сайта](https://flutter.dev/docs/get-started/install)
   - Добавьте Flutter в PATH
   - Запустите `flutter doctor` и следуйте инструкциям для установки недостающих компонентов

3. Установите зависимости проекта:
```bash
flutter pub get
```

## Настройка окружения для сборки

### Windows
1. Установите Visual Studio с компонентами для разработки на C++:
   - Desktop development with C++
   - Windows 10 SDK
   - Visual C++ tools for CMake
   
2. Включите режим разработчика в Windows:
   - Настройки > Обновление и безопасность > Для разработчиков
   - Включите "Режим разработчика"

3. Проверьте настройку Flutter для Windows:
```bash
flutter config --enable-windows-desktop
flutter doctor -v
```

### Android
1. Установите Android Studio:
   - Скачайте и установите [Android Studio](https://developer.android.com/studio)
   - Запустите Android Studio и пройдите начальную настройку
   - Установите Android SDK через SDK Manager
   - В SDK Manager установите:
     - Android SDK Build-Tools
     - Android SDK Command-line Tools
     - Android SDK Platform-Tools

2. Настройте Android Studio:
   - Установите Flutter и Dart плагины
   - Настройте Android SDK
   - Создайте и настройте Android эмулятор

3. Настройте подписывание APK (для release-сборки):
   - Создайте keystore для подписи релизной версии:
     ```bash
     keytool -genkey -v -keystore android/app/upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
     ```
   - Создайте файл `android/key.properties` со следующим содержимым:
     ```properties
     storePassword=<пароль от keystore>
     keyPassword=<пароль от ключа>
     keyAlias=upload
     storeFile=app/upload-keystore.jks
     ```
   - Добавьте `key.properties` в `.gitignore`

4. Проверьте настройку Flutter для Android:
```bash
flutter doctor -v
```

5. Сборка APK:
   - Debug версия (для тестирования):
     ```bash
     flutter build apk --debug
     ```
   - Release версия (для публикации):
     ```bash
     flutter build apk --release
     ```
   - Split APKs по архитектуре (оптимизированный размер):
     ```bash
     flutter build apk --split-per-abi
     ```

   APK файлы будут доступны в следующих локациях:
   - Debug: `build/app/outputs/flutter-apk/app-debug.apk`
   - Release: `build/app/outputs/flutter-apk/app-release.apk`
   - Split APKs:
     - `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk`
     - `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
     - `build/app/outputs/flutter-apk/app-x86_64-release.apk`

## Конфигурация

1. Создайте файл .env на основе .env.example:
```bash
cp .env.example .env
```

2. Отредактируйте .env и добавьте ваш API ключ:
```
OPENROUTER_API_KEY=ваш-ключ-здесь
```

## Запуск в Android эмуляторе

1. Откройте Android Studio
2. Перейдите в Device Manager (Tools > Device Manager или значок смартфона на панели инструментов)
3. Нажмите "Create Device"
4. Выберите тип устройства (например, Pixel 6)
5. Выберите образ системы:
   - Рекомендуется API 33 (Android 13) или новее
   - Если образ не установлен, нажмите "Download" рядом с нужной версией
6. Задайте имя эмулятора и нажмите "Finish"

Запуск приложения в эмуляторе:

1. Запустите созданный эмулятор одним из способов:
   - Через Android Studio: Device Manager > ▶️ (кнопка запуска рядом с эмулятором)
   - Через командную строку:
     ```bash
     # Список доступных эмуляторов
     emulator -list-avds
     
     # Запуск конкретного эмулятора
     emulator -avd имя_эмулятора
     ```

2. После загрузки эмулятора, запустите приложение:
   ```bash
   # Из корневой директории проекта
   flutter run
   
   # Или если нужно указать конкретное устройство
   flutter run -d имя_эмулятора
   ```

Горячие клавиши при запущенном приложении:
- R - Перезагрузить приложение
- r - Hot reload (быстрая перезагрузка изменений)
- q - Выйти из режима разработки

## Проверка установки

1. Проверьте статус Flutter:
```bash
flutter doctor
```

2. Запустите приложение для проверки:
```bash
flutter run
```

Если все установлено правильно, приложение должно запуститься на выбранном устройстве (эмулятор Android или Windows).
