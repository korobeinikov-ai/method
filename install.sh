#!/usr/bin/env bash
# Установка метода одной строкой (её показывает страница пакета):
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/korobeinikov-ai/method/main/install.sh)"
# Готовит Mac и запускает Claude с фразой, дальше ведёт инструкция CLAUDE.md.
# Повторный запуск безопасен: что уже стоит, не трогает.
set -uo pipefail

FRAZA='Установи систему метода Коробейникова. Прочитай инструкцию для тебя целиком и сделай всё по ней: https://raw.githubusercontent.com/korobeinikov-ai/method/main/CLAUDE.md'

[ "$(uname)" = Darwin ] || { echo "Метод пока работает только на Mac."; exit 1; }
[ "$(sw_vers -productVersion | cut -d. -f1)" -ge 13 ] || {
  echo "❌ Claude работает на macOS 13 и новее, у вас $(sw_vers -productVersion). Обновите систему: яблоко в левом верхнем углу → «Об этом Mac» → «Обновление ПО», потом вставьте строку ещё раз."
  exit 1
}
export PATH="$HOME/.local/bin:$PATH"

# Инструменты Apple качаются дольше всего: запускаем первыми, остальное ставим, пока они идут.
if ! xcode-select -p >/dev/null 2>&1; then
  xcode-select --install
  echo "Появилось окно Apple: нажмите «Установить» и примите условия. Дальше скачается само, я пока продолжу."
fi

# Официальная установка Zed удаляет стоящую копию: запускаем, только если его нет.
if [ ! -d /Applications/Zed.app ]; then
  echo "Ставлю Zed..."
  curl -fsSL https://zed.dev/install.sh | sh || echo "⚠️ Zed не поставился. Claude попробует ещё раз позже."
fi

# На новом Zed окно для команд открыто сразу: в нём человек работает. Чужие настройки не трогаем.
if [ ! -e "$HOME/.config/zed/settings.json" ]; then
  mkdir -p "$HOME/.config/zed"
  echo '{ "terminal": { "starts_open": true } }' > "$HOME/.config/zed/settings.json"
fi

if ! command -v claude >/dev/null; then
  echo "Ставлю Claude. Несколько минут экран будет молчать, это нормально."
  curl -fsSL https://claude.ai/install.sh | bash
fi
command -v claude >/dev/null || {
  echo "❌ Claude не поставился. Проверьте интернет и вставьте строку ещё раз. Не вышло — напишите автору там, где вы с ним общаетесь."
  exit 1
}

# Терминал Zed и новые окна должны находить claude. На учётке, перенесённой со старого Mac, оболочка бывает bash.
case "${SHELL:-}" in
  *bash) rcs=".bash_profile .bashrc" ;;
  *) rcs=".zshrc" ;;
esac
for rc in $rcs; do
  grep -qs '\.local/bin' "$HOME/$rc" || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/$rc"
done

echo
echo "Запускаю Claude. Войдите своей подпиской (откроется браузер), на вопросах первого запуска нажимайте Enter."
claude "$FRAZA"

# Это окно открыто до установки и не знает, где claude, а инструкция просит запустить его снова.
exec "${SHELL:-/bin/zsh}" -l
