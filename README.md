<p align="center">
  <img src="assets/banner.png" alt="ClaudeGravity — Gemini и Claude в Claude Desktop" width="100%">
</p>

<h1 align="center">ClaudeGravity</h1>

<p align="center">
  <strong>Gemini и Claude внутри привычного Claude Desktop.</strong><br>
  Один установщик, один проверенный bundled runtime, Google OAuth и selective Smart DNS — без глобальных <code>npm @latest</code> на машине пользователя.
</p>

<p align="center">
  <a href="https://github.com/dantegolf/ClaudeGravity-/actions/workflows/installers.yml"><img alt="Installers" src="https://github.com/dantegolf/ClaudeGravity-/actions/workflows/installers.yml/badge.svg"></a>
  <a href="https://github.com/dantegolf/ClaudeGravity-/actions/workflows/distribution.yml"><img alt="Distribution" src="https://github.com/dantegolf/ClaudeGravity-/actions/workflows/distribution.yml/badge.svg"></a>
</p>

<p align="center">
  <a href="#-быстрый-старт">Быстрый старт</a> ·
  <a href="#-что-получится">Возможности</a> ·
  <a href="#-как-это-работает">Архитектура</a> ·
  <a href="#-решение-проблем">Troubleshooting</a> ·
  <a href="#-для-разработчиков">Для разработчиков</a>
</p>

> [!CAUTION]
> ClaudeGravity использует неофициальную интеграцию и не связан с Anthropic или Google. Доступ к Google Antigravity может зависеть от аккаунта, страны, IP/ASN и изменений upstream. Если вы не готовы принять этот риск, не используйте основной Google-аккаунт.

## ⚡ Быстрый старт

### 1. Подготовьте Claude Desktop

1. Установите [Claude Desktop](https://claude.ai/download).
2. В Claude Desktop включите **Help → Troubleshooting → Enable Developer Mode**.
3. Убедитесь, что установлен **Node.js 18+**.

> [!NOTE]
> Системный DNS менять не нужно. Selective Smart DNS встроен в ClaudeGravity и применяется только к целевым Antigravity / Cloud Code API-хостам.

### 2. Установите ClaudeGravity

<details open>
<summary><strong>Windows</strong></summary>

Откройте обычный **Windows PowerShell** и выполните:

```powershell
irm https://raw.githubusercontent.com/dantegolf/ClaudeGravity-/main/install-windows.ps1 | iex
```

Установщик предпочитает системные `curl.exe` для скачивания runtime и `tar.exe` для быстрой распаковки ZIP. `Invoke-WebRequest` и `Expand-Archive` остаются совместимыми fallback-путями.

</details>

<details>
<summary><strong>macOS</strong></summary>

Откройте **Terminal** и выполните:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/dantegolf/ClaudeGravity-/main/install-macos.sh)"
```

Runtime скачивается через `curl`, распаковывается системным `tar` и устанавливается в `~/Documents/ClaudeGravity`.

Если Node.js отсутствует, установщик сможет поставить его через Homebrew, если `brew` уже доступен.

</details>

<details>
<summary><strong>Linux</strong></summary>

Откройте терминал и выполните:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/dantegolf/ClaudeGravity-/main/install-linux.sh)"
```

Поддерживаются `apt`, `dnf`, `pacman` и `zypper`. `sudo` используется только при необходимости установить Node.js/curl; сам ClaudeGravity устанавливается в профиль пользователя.

</details>

Установщики скачивают **готовый `ClaudeGravity-runtime` только из GitHub Releases этого репозитория**. Proxy и Relay не устанавливаются из npm на машине пользователя.

## ✦ Что получится

- Claude Desktop с моделями Google Antigravity через локальный Relay AI gateway.
- Пять моделей по умолчанию в избранном:
  - **Gemini 3.7 Flash High**
  - **Gemini 3.1 Pro High**
  - **Gemini 2.5 Pro**
  - **Claude Sonnet 4.6**
  - **Claude Opus 4.6 Thinking**
- Дополнительные Antigravity model IDs регистрируются в локальном Relay.
- Google OAuth через браузер — приложение Google Antigravity отдельно устанавливать не требуется.
- Локальный Antigravity engine на `127.0.0.1:8080`.
- Selective Smart DNS только для нужных Google API-хостов.
- OAuth и остальные домены продолжают использовать системный DNS.
- Bundled runtime с заранее проверенными и закреплёнными зависимостями.
- Одинаковая схема для Windows, macOS и Linux.

> [!IMPORTANT]
> Фактическая доступность моделей и квот определяется Google и конкретным аккаунтом. Наличие model ID в Relay не гарантирует, что upstream разрешит его использовать.

## ◉ Первый запуск

Установщик создаёт следующие launchers:

| Платформа | Основной запуск | Состояние / лимиты |
|---|---|---|
| Windows | `Документы\ClaudeGravity\ClaudeGravity.cmd` | `Check-Limits.cmd` |
| macOS | `~/Documents/ClaudeGravity/ClaudeGravity.sh` | `Check-Limits.sh` |
| Linux | `~/ClaudeGravity/ClaudeGravity.sh` + пункт меню | `Check-Limits.sh` |

При старте ClaudeGravity:

1. проверяет bundled runtime и compatibility patch;
2. обновляет конфигурацию Relay AI, сохраняя сторонние провайдеры и пользовательские настройки;
3. при необходимости предлагает привязать Google-аккаунт через OAuth;
4. запускает локальный Antigravity engine;
5. ждёт успешный health-check proxy;
6. запускает Relay AI gateway для Claude Desktop.

После этого в Claude Desktop переключитесь в **Code** и выберите нужную модель.

> [!TIP]
> Не закрывайте окно/Terminal ClaudeGravity во время работы — в нём живёт локальный gateway. Для быстрой проверки proxy используйте `Check-Limits` рядом с основным launcher.

## ⟳ Как это работает

```text
                         GitHub Actions
                              │
                    pinned upstream inputs
          proxy commit SHA · Relay exact version
                              │
                              ▼
                     ClaudeGravity patch
               compatibility + selective DNS
                              │
                              ▼
                       CI validation
                installers + runtime checks
                              │
                              ▼
                     GitHub Release
             runtime.zip / runtime.tar.gz
                              │
                              ▼
                        Пользователь
                              │
                              ▼
Claude Desktop → bundled Relay → bundled Antigravity engine → Google APIs
                                      │
                                      ├─ OAuth / обычные домены → system DNS
                                      └─ Cloud Code API → selective Smart DNS
```

### Почему runtime bundled

Раньше launcher мог получать новые upstream-пакеты через `npm ...@latest`. Это означало, что пользователь мог получить несовместимое обновление раньше, чем ClaudeGravity успевал его проверить.

Теперь:

- upstream inputs закреплены в `distribution/manifest.json`;
- Antigravity proxy фиксируется **полным commit SHA**;
- Relay AI фиксируется **точной package version**;
- CI собирает runtime заранее;
- compatibility + Smart DNS patch применяется во время сборки;
- собранный bundle повторно валидируется до публикации.

Текущие pins:

- `antigravity-claude-proxy` — `055699fcebcac83cea64bf599546a3ce820ebcdb` (`2.7.7` package metadata)
- `@jacobbd/relay-ai` — `0.9.5`

Полное дерево npm-зависимостей сохраняется в `runtime/package-lock.json` внутри release bundle.

## 🌐 Selective Smart DNS

ClaudeGravity не меняет DNS всей системы. По умолчанию специальный resolver используется только для:

- `cloudcode-pa.googleapis.com`
- `daily-cloudcode-pa.googleapis.com`
- `generativelanguage.googleapis.com`
- `antigravity-unleash.goog`

Default resolvers:

```text
111.88.96.50
111.88.96.51
```

OAuth, `accounts.google.com` и все остальные hostname остаются на системном resolver. При ошибке Smart DNS lookup автоматически используется системный DNS.

Отключить selective Smart DNS:

```bash
CLAUDEGRAVITY_SMART_DNS=off
```

Использовать свои resolver'ы:

```bash
CLAUDEGRAVITY_SMART_DNS_SERVERS=111.88.96.50,111.88.96.51
```

Переменные должны быть заданы **до запуска ClaudeGravity**.

## 🧪 Проверки и CI

В репозитории две основные GitHub Actions проверки:

- **Installers** — Windows PowerShell 5.1, PowerShell 7, macOS и Ubuntu.
- **Distribution** — validation исходников, сборка pinned runtime, повторная проверка готового bundle, упаковка ZIP/tar.gz и upload artifact.

Основные локальные smoke/check команды:

```bash
node tests/distribution.mjs
bash tests/unix-installer.sh
```

Windows installer проверяется отдельным PowerShell suite в GitHub Actions.

## 🧰 Для разработчиков

### Собрать runtime локально

```bash
node distribution/build-runtime.mjs
node tests/distribution.mjs dist/ClaudeGravity
```

Сборщик:

1. читает exact inputs из `distribution/manifest.json`;
2. устанавливает зависимости только в staging runtime;
3. применяет `patch-antigravity-proxy.mjs`;
4. проверяет marker selective Smart DNS;
5. валидирует pinned proxy source в lockfile;
6. добавляет launchers, manifest и third-party notices.

### Выпустить release

Workflow `.github/workflows/distribution.yml` запускается на push/PR. При создании тега `v*` он публикует:

```text
ClaudeGravity-runtime.zip
ClaudeGravity-runtime.tar.gz
```

Именно эти файлы используют platform installers через `releases/latest/download`.

## ? Решение проблем

### Installer получает `404` на runtime

Проверьте, что в последнем GitHub Release существуют:

```text
ClaudeGravity-runtime.zip
ClaudeGravity-runtime.tar.gz
```

### Windows долго стоит на скачивании или распаковке

Актуальный installer из `main` сначала использует `curl.exe`, затем `tar.exe`. Если один из fast paths недоступен или завершается ошибкой, используются PowerShell fallback-механизмы. Для повторного теста всегда запускайте команду установки из README, чтобы получить свежий installer.

### `User location is not supported for the API use`

Selective Smart DNS работает только с выбранными API-hostnames и не может отменить ограничения аккаунта или выходного IP/ASN. Попробуйте другой интернет-канал или VPN.

### Claude Desktop не показывает модели

Проверьте:

1. **Developer Mode** включён;
2. Claude Desktop находится в режиме **Code**;
3. ClaudeGravity launcher продолжает работать;
4. после переустановки ClaudeGravity был перезапущен Claude Desktop.

### `Check-Limits` пишет, что proxy не запущен

Сначала запустите основной ClaudeGravity launcher. `Check-Limits` проверяет локальный health endpoint `http://127.0.0.1:8080/health`, но не запускает engine самостоятельно.

### Хочу полностью исключить Smart DNS из диагностики

Запустите ClaudeGravity с:

```bash
CLAUDEGRAVITY_SMART_DNS=off
```

Если после этого поведение меняется, проблема, вероятно, связана с resolver или сетевым маршрутом.

## 🔒 Лицензии и ответственность

Bundled third-party компоненты сохраняют upstream LICENSE-файлы внутри `runtime/node_modules`. Дополнительная информация находится в [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

Claude, Gemini, Google Antigravity и названия моделей являются товарными знаками соответствующих владельцев.

Проект предоставляется **«как есть»**, без гарантий доступности моделей, квот, стабильности upstream или сохранности аккаунта.
