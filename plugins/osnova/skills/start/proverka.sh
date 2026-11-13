#!/bin/bash
# Проверка компьютера для KOROBEINIKOV AI: что есть, чего нет и как поставить. Ничего не меняет.
# Последняя строка — живая проверка: охрана секретов пакета действительно срабатывает.
HOOKS="$(cd "$(dirname "$0")/../../hooks" && pwd)"
TOOLS="bash $(cd "$(dirname "$0")" && pwd)/instrumenty.sh"
PATH="$HOME/.local/bin:$PATH"
bad=0
ok() { echo "✅ $1"; }
no() { echo "❌ $1 → $2"; bad=1; }
warn() { echo "⚠️ $1 → $2"; }

if xcode-select -p >/dev/null 2>&1; then ok "Инструменты разработчика Apple (git, python3)"
else no "Нет инструментов разработчика Apple" "запусти сам xcode-select --install; руки человека: в окне нажать «Установить»; жди конца в фоне"; fi

if command -v gh >/dev/null; then
  ok "GitHub CLI (связь с GitHub)"
  if gh auth status >/dev/null 2>&1; then ok "Вход в GitHub"
  else warn "Нет входа в GitHub (начать не мешает)" "когда понадобится копия проекта: запусти в фоне gh auth login --web --git-protocol https, открой человеку https://github.com/login/device и покажи код; руки человека: вставить код, нажать «Authorize»; потом gh auth setup-git"; fi
else no "Нет GitHub CLI" "$TOOLS"; fi

if command -v gitleaks >/dev/null; then ok "Сканер секретов gitleaks"
else no "Нет сканера секретов gitleaks" "$TOOLS"; fi

# Живая проверка охраны: попытка добавить .env в git должна быть остановлена хуком пакета.
T=$(mktemp -d)
git -C "$T" init -q 2>/dev/null; echo "KEY=1" > "$T/.env"
printf '{"tool_input":{"command":"git add .env"},"cwd":"%s"}' "$T" | (cd "$T" && python3 "$HOOKS/block-env-commit.py") >/dev/null 2>&1
code=$?
rm -rf "$T"
if [ "$code" -eq 2 ]; then ok "Охрана секретов срабатывает"
else no "Охрана секретов НЕ сработала (код $code)" "сначала почини строки выше; не помогло — сообщи автору пакета"; fi

exit $bad
