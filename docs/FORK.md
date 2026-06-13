# AmneziaVPN fork — desktop redesign + vpn.devkz.ru

Форк [amnezia-vpn/amnezia-client](https://github.com/amnezia-vpn/amnezia-client)
(GPL-3.0) с переработанным десктопным интерфейсом под macOS и интеграцией
с панелью подписок vpn.devkz.ru. Изменения живут в ветке `redesign`.

## Что добавлено

### Десктопный интерфейс (macOS)
- Двухколоночный экран в стиле Finder/System Settings вместо «телефонного»
  окна: слева сайдбар со списком профилей, справа — детали подключения.
  Реализация: `client/ui/qml/Pages2/PageHomeDesktop.qml` (роутится из
  `PageHome` через `PageController::getPagePath` только на десктопе; мобильный
  и TV-интерфейс не затронуты).
- Подключение/отключение — переключателем в строке с названием профиля,
  рядом компактная кнопка «Check».
- Лог подключения отдельный на каждый профиль, с копированием и очисткой.
- Добавление подключения — модалкой (`Components/`): файл с диска,
  вставка vpn:// ключа / текста конфига / ссылки подписки.
- Переименование, удаление и протокольные настройки профиля — в центральной
  панели. Подтверждения — `Components/DesktopConfirmDialog.qml` (центрированная
  карточка вместо нижнего bottom-sheet).
- Настройки — двухпанельная модалка `Components/DesktopSettingsModal.qml`
  (General / Connection / Split tunneling / Logging / Backup / vpn.devkz.ru /
  About).
- Первый запуск — стартовый экран в новом стиле с полем для токена/ключа.
- Тёмная тема форсится на macOS (`forceDarkAppearance`, `ui/utils/macosUtil.mm`).
- Окно 940×620, ресайзабельно. Своё имя single-instance сокета
  (`AmneziaVPNForkInstance`), чтобы сосуществовать с официальным клиентом.

### Интеграция vpn.devkz.ru (API v1)
Контракт: [`docs/devkz-api-contract.md`](devkz-api-contract.md). Реализовано в
`client/core/controllers/selfhosted/importController.cpp`:
- Импорт подписки: bare-токен (по умолчанию vpn.devkz.ru), legacy
  `/api/sub/<token>` или `/api/v1/sub/<token>`. Запрос идёт на `/api/v1/sub`
  с `Authorization: Bearer`, на 404 — откат на legacy-путь.
- Профили сопоставляются по стабильному `id`; в конфиге сервера хранятся
  token / profile id / revision.
- Обновление профилей: in-place по id (новые добавляются, исчезнувшие
  удаляются), плюс фоновый рефреш по ETag (`If-None-Match`, раз в 10 минут).
- Живые статусы `/api/v1/status` (poll раз в 60 с) — индикация alive/offline
  в сайдбаре и строка Availability в деталях.
- Диагностика `/api/v1/health` — раздел vpn.devkz.ru в настройках
  (exits, gateways, your_profiles, route_presets, issues).
- `POST /api/v1/feedback` при неудачной проверке Check или ошибке подключения.

## Сборка (macOS, Apple Silicon)

```bash
brew install qt conan cmake
git submodule update --init --recursive
conan profile detect
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=$(brew --prefix qt)
cmake --build build -j $(sysctl -n hw.ncpu)
open build/client/AmneziaVPN.app
```

Правка для сборки с arm64-only Qt из Homebrew: `cmake/platform_settings.cmake`
собирает под архитектуру хоста (`CMAKE_HOST_SYSTEM_PROCESSOR`) вместо
жёсткого `x86_64` (апстрим рассчитан на универсальный Qt из официального
инсталлятора).

## Dev-флаги (только для разработки, в релизе не задаются)

| Переменная | Эффект |
|---|---|
| `AMNEZIA_DEV_NO_KEYCHAIN=1` | ключ шифрования читается из локального `dev-secrets.ini` вместо системного keychain — нет запроса пароля на каждый запуск пересобранного бинаря. Первый запуск мигрирует существующий ключ из keychain (один prompt), чтобы уже сохранённые серверы остались читаемыми. |
| `AMNEZIA_FORCE_SHOW=1` | игнорировать «start minimized» и сразу показать окно. |

## Лицензия и брендинг

Код под GPL-3.0 (как апстрим). Название и логотип «AmneziaVPN» — товарный знак
проекта Amnezia и не покрываются лицензией на код: для публичного релиза форк
нужно переименовать и заменить брендинг. Это отдельный, ещё не сделанный шаг;
тогда же форку имеет смысл дать собственные org/app для QSettings и отдельный
демон, чтобы полностью отвязаться от официального клиента.
