<p align="center">
  <img src="assets/banner.png" alt="ClaudeGravity — Gemini и Claude в Claude Desktop" width="100%">
</p>

<h1 align="center">ClaudeGravity</h1>

<p align="center">
  Gemini и Claude в Claude Desktop через локальный Antigravity proxy и Relay AI.
</p>

<p align="center">
  <a href="https://github.com/dantegolf/ClaudeGravity-/actions/workflows/installers.yml"><img alt="Installers" src="https://github.com/dantegolf/ClaudeGravity-/actions/workflows/installers.yml/badge.svg"></a>
  <a href="https://github.com/dantegolf/ClaudeGravity-/actions/workflows/distribution.yml"><img alt="Distribution" src="https://github.com/dantegolf/ClaudeGravity-/actions/workflows/distribution.yml/badge.svg"></a>
</p>

ClaudeGravity настраивает Claude Desktop для работы с моделями Google Antigravity через локальный proxy. Proxy и Relay AI поставляются вместе с релизом проекта: во время обычной установки они не подтягиваются через `npm @latest` и не устанавливаются глобально.

Поддерживаются Windows, macOS и Linux.

> [!CAUTION]
> Проект использует неофициальную интеграцию и не связан с Anthropic или Google. Доступ к Google Antigravity зависит от аккаунта, региона, сети и текущих ограничений со стороны Google. Для тестов разумнее использовать отдельный Google-аккаунт.

## Установка

Перед установкой:

1. Установите [Claude Desktop](https://claude.ai/download).
2. В Claude Desktop включите **Help → Troubleshooting → Enable Developer Mode**.
3. Убедитесь, что установлен **Node.js 18 или новее**.

Менять DNS всей системы не требуется. ClaudeGravity использует отдельный resolver только для нескольких Antigravity / Cloud Code API-хостов.

### Windows

Откройте обычный **Windows PowerShell** и выполните:

```powershell
irm https://raw.githubusercontent.com/dantegolf/ClaudeGravity-/main/install-windows.ps1 | iex
```

По возможности установщик использует системные `curl.exe` и `tar.exe`. Если они недоступны, остаются стандартные PowerShell-варианты через `Invoke-WebRequest` и `Expand-Archive`.

Установка выполняется в:

```text
Документы\ClaudeGravity
```

### macOS

Откройте **Terminal** и выполните:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/dantegolf/ClaudeGravity-/main/install-macos.sh)"
```

Файлы устанавливаются в:

```text
~/Documents/ClaudeGravity
```

Если Node.js не установлен, скрипт может поставить его через Homebrew, если `brew` уже есть в системе.

### Linux

Откройте терминал и выполните:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/dantegolf/ClaudeGravity-/main/install-linux.sh)"
```

Поддерживаются `apt`, `dnf`, `pacman` и `zypper`. Права `sudo` нужны только в том случае, если требуется установить Node.js или `curl`. Сам ClaudeGravity устанавливается в пользовательский каталог.

## Первый запуск

После установки используйте основной launcher:

| Платформа | Запуск | Проверка состояния |
|---|---|---|
| Windows | `Документы\ClaudeGravity\ClaudeGravity.cmd` | `Check-Limits.cmd` |
| macOS | `~/Documents/ClaudeGravity/ClaudeGravity.sh` | `Check-Limits.sh` |
| Linux | `~/ClaudeGravity/ClaudeGravity.sh` | `Check-Limits.sh` |

При запуске ClaudeGravity:

1. проверяет локальный runtime;
2. добавляет Antigravity provider в конфигурацию Relay AI, не удаляя другие пользовательские провайдеры;
3. при необходимости предлагает войти в Google через OAuth;
4. запускает Antigravity proxy на `127.0.0.1:8080`;
5. ждёт ответа от proxy;
6. запускает Relay AI для Claude Desktop.

После этого откройте Claude Desktop, переключитесь в режим **Code** и выберите модель.

Окно или Terminal с запущенным ClaudeGravity закрывать не нужно: пока оно работает, работает и локальный gateway.

## Модели

По умолчанию в избранное Relay AI добавляются:

- Gemini 3.7 Flash High
- Gemini 3.1 Pro High
- Gemini 2.5 Pro
- Claude Sonnet 4.6
- Claude Opus 4.6 Thinking

В Relay также регистрируются дополнительные Antigravity model IDs.

Наличие модели в списке не означает, что конкретный Google-аккаунт обязательно получит к ней доступ. Доступность моделей и квоты определяются на стороне Google.

## Как устроен ClaudeGravity

```text
Claude Desktop
      │
      ▼
Relay AI
      │
      ▼
Antigravity proxy
      │
      ├── OAuth и обычные домены ──→ системный DNS
      │
      └── Cloud Code API ──────────→ selective Smart DNS
                                      │
                                      ▼
                                  Google APIs
```

Proxy и Relay AI заранее собираются в GitHub Actions и попадают в `ClaudeGravity-runtime.zip` и `ClaudeGravity-runtime.tar.gz`.

Установщики скачивают эти архивы из GitHub Releases этого репозитория. На пользовательской машине нет необходимости отдельно ставить `antigravity-claude-proxy` или Relay AI через npm.

Текущие версии зафиксированы в `distribution/manifest.json`:

- `antigravity-claude-proxy` — commit `055699fcebcac83cea64bf599546a3ce820ebcdb` (package metadata `2.7.7`)
- `@jacobbd/relay-ai` — `0.9.5`

Proxy закреплён по полному commit SHA, чтобы сборка не зависела от изменения тегов или метаданных upstream. Полное дерево npm-зависимостей сохраняется в `runtime/package-lock.json` внутри релизного архива.

## Selective Smart DNS

ClaudeGravity не меняет системные DNS-настройки.

Отдельный resolver используется только для следующих адресов:

```text
cloudcode-pa.googleapis.com
daily-cloudcode-pa.googleapis.com
generativelanguage.googleapis.com
antigravity-unleash.goog
```

По умолчанию используются:

```text
111.88.96.50
111.88.96.51
```

OAuth, `accounts.google.com` и остальные домены продолжают использовать системный DNS. Если отдельный resolver не отвечает, запрос возвращается к системному DNS.

Отключить эту логику для диагностики можно так:

```bash
CLAUDEGRAVITY_SMART_DNS=off
```

Указать другие resolver'ы:

```bash
CLAUDEGRAVITY_SMART_DNS_SERVERS=111.88.96.50,111.88.96.51
```

Переменные нужно задать до запуска ClaudeGravity.

## Обновление

Чтобы получить последнюю опубликованную версию, достаточно снова выполнить установочную команду для своей системы.

Установщик заменит каталог ClaudeGravity свежим runtime из последнего GitHub Release. Настройки Relay AI и данные Google OAuth хранятся отдельно и при обычной переустановке не удаляются.

## Проверки

В репозитории работают два GitHub Actions workflow:

- **Installers** — проверяет Windows PowerShell 5.1, PowerShell 7, macOS и Ubuntu;
- **Distribution** — собирает runtime, проверяет его содержимое и создаёт ZIP/tar.gz архивы.

Основные проверки, которые можно запустить локально:

```bash
node tests/distribution.mjs
bash tests/unix-installer.sh
```

Windows-скрипты отдельно проверяются PowerShell-тестами.

## Если что-то не работает

### Установщик получает `404` на runtime

В последнем GitHub Release должны присутствовать файлы:

```text
ClaudeGravity-runtime.zip
ClaudeGravity-runtime.tar.gz
```

Если их нет, релиз был опубликован без distribution artifacts.

### Windows долго скачивает или распаковывает архив

Используйте установочную команду из этого README, чтобы получить актуальную версию `install-windows.ps1`.

Текущий скрипт сначала пытается скачать архив через `curl.exe` и распаковать его через `tar.exe`. Более медленные PowerShell-механизмы используются только как запасной вариант.

### Claude Desktop не показывает модели

Проверьте четыре вещи:

1. включён **Developer Mode**;
2. выбран режим **Code**;
3. ClaudeGravity всё ещё запущен;
4. Claude Desktop был перезапущен после установки или обновления.

### `Check-Limits` сообщает, что proxy не запущен

Сначала запустите основной ClaudeGravity launcher. `Check-Limits` только проверяет локальный endpoint `http://127.0.0.1:8080/health` и сам proxy не запускает.

### `User location is not supported for the API use`

Selective Smart DNS помогает только с DNS-маршрутизацией выбранных API-хостов. Он не снимает ограничения, которые Google применяет к аккаунту или внешнему IP-адресу.

В такой ситуации можно проверить другой интернет-канал или VPN.

### Нужно проверить работу без Smart DNS

Запустите ClaudeGravity с:

```bash
CLAUDEGRAVITY_SMART_DNS=off
```

Если после этого поведение меняется, стоит проверить DNS resolver и сетевой маршрут.

## Для разработчиков

Собрать runtime локально:

```bash
node distribution/build-runtime.mjs
node tests/distribution.mjs dist/ClaudeGravity
```

Сборщик устанавливает версии из `distribution/manifest.json` в отдельный runtime-каталог, применяет compatibility/Smart DNS patch и проверяет результат перед упаковкой.

Workflow `.github/workflows/distribution.yml` запускается на push и pull request. При создании тега `v*` он публикует:

```text
ClaudeGravity-runtime.zip
ClaudeGravity-runtime.tar.gz
```

Именно эти файлы затем скачивают установщики Windows, macOS и Linux через `releases/latest/download`.

## Лицензии и ответственность

Лицензии сторонних компонентов сохраняются внутри `runtime/node_modules`. Дополнительная информация находится в [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

Claude, Gemini, Google Antigravity и названия моделей принадлежат соответствующим владельцам товарных знаков.

Проект предоставляется «как есть». Автор проекта не может гарантировать доступность конкретных моделей, квот или неизменность поведения сторонних сервисов.
