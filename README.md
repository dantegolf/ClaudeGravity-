<p align="center">
  <img src="assets/banner.png" alt="ClaudeGravity — несколько AI-моделей в Claude Desktop" width="100%">
</p>

<h1 align="center">ClaudeGravity</h1>

<p align="center">
  <strong>Gemini и Claude внутри привычного Claude Desktop.</strong><br>
  Один установщик, один проверенный runtime, один источник обновлений.
</p>

<p align="center">
  <a href="#-установка">Установка</a> ·
  <a href="#-что-получится">Возможности</a> ·
  <a href="#-как-это-работает">Как это работает</a> ·
  <a href="#-решение-проблем">Помощь</a>
</p>

> [!CAUTION]
> ClaudeGravity использует неофициальную интеграцию и не связан с Anthropic или Google. Доступ Google может зависеть от аккаунта, страны, IP/ASN и изменений upstream. Не используйте основной Google-аккаунт, если не принимаете этот риск.

## ✦ Что получится

- Claude Desktop с подготовленными моделями Google Antigravity.
- Google OAuth через браузер.
- Локальный Antigravity engine и Relay gateway.
- Встроенный selective Smart DNS только для Antigravity / Cloud Code API-хостов.
- OAuth и остальные домены остаются на системном DNS.
- Один проверенный ClaudeGravity runtime вместо глобальных `npm @latest` компонентов.
- Одинаковая модель установки на Windows, macOS и Linux.

## ↓ Установка

### Перед началом

1. Установите [Claude Desktop](https://claude.ai/download).
2. В Claude Desktop включите **Help → Troubleshooting → Enable Developer Mode**.
3. Обычную смену DNS всей системы делать не нужно: selective Smart DNS встроен в ClaudeGravity.
4. Требуется Node.js 18+. Если его нет, Windows/Linux installer попробует поставить его штатным менеджером пакетов; на macOS используется Homebrew, если он доступен.

### Windows

Откройте обычный **Windows PowerShell**:

```powershell
irm https://raw.githubusercontent.com/dantegolf/ClaudeGravity-/main/install-windows.ps1 | iex
```

### macOS

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/dantegolf/ClaudeGravity-/main/install-macos.sh)"
```

### Linux

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/dantegolf/ClaudeGravity-/main/install-linux.sh)"
```

Установщики больше не скачивают proxy/Relay из npm на машине пользователя. Они получают готовый `ClaudeGravity-runtime` только из GitHub Releases этого репозитория.

> [!IMPORTANT]
> Для новой bundled-схемы в Releases должен существовать `ClaudeGravity-runtime.zip` и `ClaudeGravity-runtime.tar.gz`. Эти файлы автоматически создаются workflow `Distribution` при публикации тега `v*`.

## ◉ Первый запуск

Установщик создаёт:

| Платформа | Основной запуск | Проверка лимитов |
|---|---|---|
| Windows | `Документы\ClaudeGravity\ClaudeGravity.cmd` | `Check-Limits.cmd` |
| macOS | `Документы/ClaudeGravity/ClaudeGravity.sh` | `Check-Limits.sh` |
| Linux | `~/ClaudeGravity/ClaudeGravity.sh` | `Check-Limits.sh` |

При первом запуске:

1. ClaudeGravity проверяет целостность bundled runtime и наш compatibility patch.
2. Если Google-аккаунт ещё не добавлен, откроется OAuth-привязка.
3. Запускается локальный Antigravity engine.
4. Relay AI подключает его к Claude Desktop.
5. В Claude Desktop выберите режим **Code** и нужную модель.

## ⟳ Как это работает

```text
                    GitHub Actions (только сборка)
                              │
                 pinned upstream versions
                 proxy 2.7.7 · relay 0.9.5
                              │
                              ▼
                    ClaudeGravity patch
               compatibility + Smart DNS
                              │
                              ▼
                  ClaudeGravity Release
             runtime.zip / runtime.tar.gz
                              │
                 пользователь скачивает
                    только наш Release
                              │
                              ▼
Claude Desktop → bundled Relay → bundled Antigravity engine → Google APIs
                                      │
                                      ├─ OAuth → system DNS
                                      └─ Cloud Code → selective Smart DNS
```

### Почему runtime теперь bundled

Раньше launcher выполнял `npm install -g ...@latest`, поэтому новая upstream-версия могла приехать пользователю раньше, чем ClaudeGravity успевал проверить совместимость.

Теперь версии движков закреплены в `distribution/manifest.json`. CI собирает их заранее, применяет наш patch, запускает тесты и только затем публикует готовый bundle в Releases. Пользовательская машина больше не зависит от npm-версий proxy/Relay во время установки или запуска.

Текущие pins:

- `antigravity-claude-proxy` — `2.7.7`
- `@jacobbd/relay-ai` — `0.9.5`

Конкретное дерево зависимостей каждой сборки сохраняется в `runtime/package-lock.json` внутри release bundle.

### Selective Smart DNS

По умолчанию через Smart DNS резолвятся только:

- `cloudcode-pa.googleapis.com`
- `daily-cloudcode-pa.googleapis.com`
- `generativelanguage.googleapis.com`
- `antigravity-unleash.goog`

По умолчанию используются `111.88.96.50` и `111.88.96.51`. OAuth и все остальные hostname используют системный resolver. Если Smart DNS не отвечает, lookup откатывается на системный DNS.

Отключить Smart DNS для запуска:

```text
CLAUDEGRAVITY_SMART_DNS=off
```

Задать свои resolver'ы:

```text
CLAUDEGRAVITY_SMART_DNS_SERVERS=111.88.96.50,111.88.96.51
```

Переменные должны быть заданы до запуска `ClaudeGravity`.

## ⚙ Для разработчиков

### Собрать runtime локально

```bash
node distribution/build-runtime.mjs
node tests/distribution.mjs dist/ClaudeGravity
```

Сборщик:

1. читает точные версии из `distribution/manifest.json`;
2. устанавливает их только в staging runtime;
3. применяет `patch-antigravity-proxy.mjs`;
4. проверяет marker selective Smart DNS;
5. добавляет launchers, manifest и third-party notices.

### Опубликовать release

Workflow `.github/workflows/distribution.yml` собирает и тестирует runtime на обычных push/PR. При теге `v*` тот же workflow публикует ZIP и tar.gz в GitHub Release.

Upstream используется **только во время нашей сборки**. Конечный пользователь получает proxy, Relay и ClaudeGravity patch одним bundle из `dantegolf/ClaudeGravity-`.

## ? Решение проблем

**Installer получает 404 на `ClaudeGravity-runtime`**  
Для bundled-схемы ещё не опубликован Release asset. Проверьте последний GitHub Release или используйте версию проекта, для которой runtime уже опубликован.

**`User location is not supported for the API use`**  
Selective Smart DNS уже применяется к целевым API-хостам. Если ошибка сохраняется, Google может отклонять аккаунт или выходной IP/ASN. Попробуйте другой интернет-канал или VPN.

**Claude Desktop не показывает модели**  
Проверьте Developer Mode, режим Code и перезапустите ClaudeGravity/Claude Desktop.

**Прокси не отвечает**  
Запустите `ClaudeGravity` повторно. Launcher сам проверяет bundled engine и пытается поднять его заново.

## Лицензии и ответственность

Bundled third-party компоненты сохраняют свои upstream LICENSE-файлы внутри `runtime/node_modules`. Дополнительные сведения находятся в [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

Claude, Gemini, Google Antigravity и названия моделей являются товарными знаками соответствующих владельцев. Проект предоставляется «как есть» без гарантий доступности моделей, квот или сохранности аккаунта.
