#!/usr/bin/env bash
# Установка метода одной строкой (её показывает страница пакета):
#   bash <(curl -fsSL https://raw.githubusercontent.com/korobeinikov-ai/method/main/install.sh)
# В строке нет кавычек: мессенджеры подменяют их на «ёлочки», и команда ломается.
# Не `curl | bash` с `</dev/tty`: на таком вводе Claude падает с ошибкой kqueue. Здесь клавиатура настоящая.
# Готовит Mac и запускает Claude с фразой, дальше ведёт инструкция CLAUDE.md.
# Повторный запуск безопасен: что уже стоит, не трогает.
# Всё внутри main: оборвётся скачивание — не выполнится половина.
set -uo pipefail

FRAZA='Установи систему метода Коробейникова. Прочитай инструкцию для тебя целиком и сделай всё по ней: https://raw.githubusercontent.com/korobeinikov-ai/method/main/CLAUDE.md'
STROKA='bash <(curl -fsSL https://raw.githubusercontent.com/korobeinikov-ai/method/main/install.sh)'
PUT='export PATH="$HOME/.local/bin:$PATH"'

# Остановка: что случилось, что делать и как запустить снова.
stop() {
  echo
  echo "❌ $1"
  echo "Что делать: $2"
  echo
  echo "Потом нажмите стрелку вверх и Enter или вставьте эту строку ещё раз. Что уже поставилось, она не тронет:"
  echo "  $STROKA"
  echo
  echo "Снова не вышло — пришлите автору текст с экрана там, где вы с ним общаетесь."
  exit 1
}

# Файл или папка в доме бывают закрыты от владельца: их правили или запускали через sudo.
otkryt() {
  local f="$HOME/$1" ya
  ya=$(id -un)
  [ -e "$f" ] || return 0
  [ -w "$f" ] && [ -r "$f" ] && [ -z "$(find "$f" ! -user "$ya" -print -quit 2>/dev/null)" ] && return 0
  echo "⏳ $1 закрыт от вас. Mac спросит пароль: введите пароль от компьютера и нажмите Enter. Символы на экране не появляются, это нормально."
  sudo chown -R "$ya" "$f" && chmod u+rw "$f" || stop "Не вышло открыть $1." \
    "запустите установку ещё раз и введите пароль от Mac. Если вы не администратор этого Mac, попросите его ввести пароль."
  echo "✅ $1 открыт"
}

# Терминал Zed и новые окна находят claude только по этой записи.
# Сверяем всю строку: прошлая запись могла сломаться, если её передавали через мессенджер.
zapisat_put() {
  otkryt "$1"
  grep -qsxF "$PUT" "$HOME/$1" || echo "$PUT" >> "$HOME/$1" || stop "Не вышло записать путь к Claude в $1." \
    "запустите установку ещё раз."
}

main() {
  echo "Установка метода KOROBEINIKOV AI"
  echo

  [ "$(uname)" = Darwin ] || { echo "Метод пока работает только на Mac."; exit 1; }
  local versiya
  versiya=$(sw_vers -productVersion)
  [ "${versiya%%.*}" -ge 13 ] || stop "Claude работает на macOS 13 и новее, у вас $versiya." \
    "обновите систему: яблоко в левом верхнем углу → «Об этом Mac» → «Обновление ПО»."
  echo "✅ Система подходит: macOS $versiya"
  export PATH="$HOME/.local/bin:$PATH"

  # Пароль, если он нужен, спрашиваем сразу, а не после получаса скачивания. На учётке со старого Mac оболочка бывает bash.
  for f in .local .claude .claude.json .config; do otkryt "$f"; done
  case "${SHELL:-}" in
    *bash) zapisat_put .bash_profile; zapisat_put .bashrc ;;
    *) zapisat_put .zshrc ;;
  esac

  # Инструменты Apple качаются дольше всего: запускаем первыми, остальное ставим, пока они идут.
  if xcode-select -p >/dev/null 2>&1; then
    echo "✅ Инструменты Apple уже стоят"
  else
    xcode-select --install
    echo "⏳ Инструменты Apple: в окне Apple нажмите «Установить» и примите условия. Дальше скачается само, я пока продолжу."
  fi

  # Официальная установка Zed удаляет стоящую копию: запускаем, только если его нет.
  if [ -d /Applications/Zed.app ]; then
    echo "✅ Zed уже стоит"
  else
    echo "⏳ Ставлю Zed..."
    curl -fsSL https://zed.dev/install.sh | sh
    if [ -d /Applications/Zed.app ]; then
      echo "✅ Zed поставлен"
    else
      echo "⚠️ Zed не поставился. Это не страшно: продолжаю, Claude попробует ещё раз."
    fi
  fi

  # На новом Zed окно для команд открыто сразу: в нём человек работает. Чужие настройки не трогаем.
  if [ ! -e "$HOME/.config/zed/settings.json" ]; then
    mkdir -p "$HOME/.config/zed"
    echo '{ "terminal": { "starts_open": true } }' > "$HOME/.config/zed/settings.json"
  fi

  # Спрашиваем сам Claude, а не ищем файл: сломанная копия поставится заново.
  if claude --version >/dev/null 2>&1; then
    echo "✅ Claude уже стоит"
  else
    echo "⏳ Ставлю Claude. Несколько минут экран будет молчать, это нормально."
    curl -fsSL https://claude.ai/install.sh | bash
    claude --version >/dev/null 2>&1 || stop "Claude не поставился." "проверьте интернет и свободное место на диске."
    echo "✅ Claude поставлен"
  fi

  # Рабочая папка метода. Ответ «да» на вопрос Claude о папке действует и на проекты внутри неё, а в домашней не запоминается.
  mkdir -p "$HOME/vibecoding" && cd "$HOME/vibecoding" || stop "Не вышло создать папку vibecoding." "запустите установку ещё раз."

  echo
  xcode-select -p >/dev/null 2>&1 || echo "⏳ Инструменты Apple ещё качаются, Claude их дождётся."
  echo "✅ Подготовка закончена. Запускаю Claude."
  echo "На первых вопросах нажимайте Enter, потом откроется браузер: войдите своей подпиской."
  echo "⚠️ На вопросе про папку (Yes, I trust this folder) сначала нажмите стрелку вниз, потом Enter: там по умолчанию стоит «нет»."
  echo "Дальше Claude поставит пакет сам и в конце покажет итог."
  claude "$FRAZA"

  # Пакета нет: Claude закрылся раньше времени, чаще всего на вопросе про папку выбрано «нет».
  claude plugin list 2>/dev/null | grep 'osnova@' >/dev/null || stop "Claude закрылся раньше, чем поставил метод." \
    "запустите установку снова. На вопросе про папку (Yes, I trust this folder) сначала нажмите стрелку вниз, потом Enter."

  # Это окно открыто до установки и не знает, где claude, а инструкция просит запустить его снова.
  exec "${SHELL:-/bin/zsh}" -l
}

main
