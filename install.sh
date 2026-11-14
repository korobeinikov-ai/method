#!/usr/bin/env bash
# Установка метода KOROBEINIKOV AI на Mac одной командой. Её запускает сам Claude в приложении Claude (вкладка Code)
# по инструкции CLAUDE.md, в фоне:
#   bash <(curl -fsSL https://raw.githubusercontent.com/korobeinikov-ai/method/main/install.sh) [личная ссылка]
# Делает всё сам: инструменты Apple (человек только жмёт «Установить» в окне Apple), пакет и строку над полем ввода,
# программы пакета, автообновление, личный доступ, папку ~/vibecoding. Повторный запуск безопасен: что стоит — не трогает.
# Вывод читает Claude: в конце итог и пути для следующих шагов инструкции.
# Запустили не из Claude (старые строки установки и личная строка в Терминале) — только говорит, как поставить метод
# в приложении. Поэтому файл не переименовывать: на него ссылаются строки, которые люди получили раньше.
set -u

# Claude, который нас запустил: в приложении — его своя копия (CLAUDE_CODE_EXECPATH), в терминале — команда claude
C="${CLAUDE_CODE_EXECPATH:-}"
{ [ -n "$C" ] && "$C" --version 2>/dev/null | grep -q "Claude Code"; } || C=""
if [ -z "$C" ] && [ -n "${CLAUDECODE:-}" ]; then C=$(command -v claude 2>/dev/null || true); fi
if [ -z "$C" ] && [ -n "${CLAUDECODE:-}" ]; then
  echo "❌ Не нашёл программу Claude, которая запустила установку → ДЛЯ CLAUDE: найди её путь (в приложении —"
  echo "   CLAUDE_CODE_EXECPATH) и запусти установку ещё раз с CLAUDE_CODE_EXECPATH=<путь>. Человеку команд не показывай."
  echo "ИТОГ: ❌ установка не началась."
  exit 1
fi

if [ -z "$C" ]; then
  echo "Метод KOROBEINIKOV AI теперь ставится в приложении Claude, без Терминала."
  echo
  echo "1. Скачайте Claude: страница сейчас откроется в браузере, вот она: https://claude.ai/download"
  echo "   Перетащите Claude в «Программы», откройте и войдите своей подпиской."
  echo "2. Вверху окна выберите раздел Code, под полем ввода — папку «Документы»."
  echo "3. Вставьте в поле ввода этот текст и нажмите Enter:"
  echo
  echo "Установи метод Коробейникова. Прочитай инструкцию для тебя целиком и сделай всё по ней: https://raw.githubusercontent.com/korobeinikov-ai/method/main/CLAUDE.md"
  echo
  echo "Уже ставили метод раньше? Переставлять ничего не нужно: в разделе Code откройте папку своего проекта."
  echo "Подробнее: https://github.com/korobeinikov-ai/method"
  open https://claude.ai/download 2>/dev/null || echo "⚠️ Браузер сам не открылся: откройте ссылку выше."
  exit 0
fi

M=korobeinikov-ai-method
CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
DATA="$CFG/plugins/data/osnova-$M"
bad=0
ok() { echo "✅ $1"; }
stop() { echo "❌ $1 → $2"; echo; echo "ИТОГ: ❌ установка остановилась на строке выше."; exit 1; }

echo "Установка метода KOROBEINIKOV AI (Mac)"
[ "$(uname)" = Darwin ] || stop "Это не Mac" "возьми инструкцию для Windows: https://raw.githubusercontent.com/korobeinikov-ai/method-windows/main/CLAUDE.md"
v=$(sw_vers -productVersion 2>/dev/null)
[ "${v%%.*}" -ge 13 ] 2>/dev/null || stop "macOS ${v:-?}: нужна 13 или новее" "человеку: яблоко слева вверху → «Об этом Mac» → «Обновление ПО», потом поставить метод заново"
ok "macOS $v"

# Инструменты Apple: без них нет git и python3, а на них держится охрана пакета и сама установка пакета
dev_ok() { local d; d=$(xcode-select -p 2>/dev/null) && [ -x "$d/usr/bin/git" ] && [ -x "$d/usr/bin/python3" ]; }
if dev_ok; then
  ok "Инструменты Apple уже есть"
else
  xcode-select --install >/dev/null 2>&1
  echo "⏳ ОКНО APPLE: человеку нажать в нём «Установить» и принять условия. Дальше качается само, обычно до получаса — жду."
  t=0
  until dev_ok; do
    [ $t -ge 3600 ] && stop "Инструменты Apple не поставились за час" "запусти установку ещё раз: окно Apple откроется снова"
    sleep 15; t=$((t + 15))
    if [ $((t % 300)) -eq 0 ]; then  # раз в 5 минут: идёт ли установка; окно закрыли — открываем снова
      if pgrep -f "Install Command Line Developer Tools" >/dev/null; then echo "⏳ Инструменты Apple ставятся, прошло $((t / 60)) мин"
      else xcode-select --install >/dev/null 2>&1; echo "⏳ ОКНО APPLE закрыли раньше времени, открыл снова: человеку нажать «Установить»"; fi
    fi
  done
  ok "Инструменты Apple поставлены"
fi

# Пакет метода и строка над полем ввода. Полка уже подключена — не ошибка: судим по списку пакетов.
has() { "$C" plugin list 2>/dev/null | grep -q "$1@$M"; }
if has osnova; then
  ok "Пакет метода уже стоит"
else
  out=$("$C" plugin marketplace add korobeinikov-ai/method 2>&1; "$C" plugin install "osnova@$M" 2>&1)
  has osnova || { echo "$out" | tail -15; stop "Пакет метода не поставился" "прочитай ответ выше, почини и запусти установку ещё раз"; }
  ok "Пакет метода поставлен"
fi
if has stroka || "$C" plugin install "stroka@$M" >/dev/null 2>&1; then ok "Строка над полем ввода"
else echo "⚠️ Строка над полем ввода не поставилась — работе не мешает"; fi

# Где лежит поставленный пакет: оттуда берём проводник (его скрипты — следующие шаги инструкции)
START=$(python3 -c 'import json, sys
for e in json.load(open(sys.argv[1])).get("plugins", {}).get(sys.argv[2], []):
    if e.get("installPath"): print(e["installPath"]); break' "$CFG/plugins/installed_plugins.json" "osnova@$M" 2>/dev/null)/skills/start
[ -f "$START/SKILL.md" ] || START=$(ls -td "$CFG/plugins/cache/$M/osnova/"*/skills/start 2>/dev/null | head -1)
[ -f "${START:-}/SKILL.md" ] || stop "Пакет стоит, но его папки нет на диске" "запусти установку ещё раз"

bash "$START/instrumenty.sh" || bad=1
python3 "$START/nastroyki.py" obnovleniya || bad=1
mkdir -p "$HOME/vibecoding" && ok "Папка для проектов: ~/vibecoding" || { echo "❌ Не создал папку ~/vibecoding"; bad=1; }

# Личный доступ: одноразовая ссылка из бота. Ключ сервер отдаёт только самому запуску и сразу в закрытый файл.
if [ -n "${1:-}" ]; then
  if [[ "$1" =~ ^https://korobeinikov-ai\.up\.railway\.app/u/[A-Za-z0-9_-]+$ ]]; then
    # 200 — скрипт доступа, 410 — скрипт с причиной отказа («уже сработала, устарела…»); остальное не запускаем
    s=$(curl -sS --max-time 60 -w '\n%{http_code}' "$1" 2>&1); kod=${s##*$'\n'}; s=${s%$'\n'*}
    case "$kod" in
      200|410) bash -c "$s" || echo "ДОСТУП: ❌ не подключился (причина строкой выше), остальное поставлено" ;;
      *) echo "ДОСТУП: ❌ сервер метода не ответил (код ${kod:-нет}) — запусти установку ещё раз через минуту" ;;
    esac
  else
    echo "ДОСТУП: ❌ это не ссылка из бота метода — попроси человека прислать текст из бота ещё раз"
  fi
fi

echo
echo "Проверка:"
bash "$START/proverka.sh" || bad=1
echo
echo "ПРОВОДНИК=$START"
echo "ДАННЫЕ=$DATA"
if [ -f "$DATA/gotovo" ]; then echo "ПРОВОДНИК_ПРОЙДЕН=да"; else echo "ПРОВОДНИК_ПРОЙДЕН=нет"; fi
echo "НАСТРОЙКИ:"
python3 "$START/nastroyki.py" pokazat
echo
if [ $bad -eq 0 ]; then echo "ИТОГ: ✅ всё поставлено. Метод заработает в новом сеансе Claude."
else echo "ИТОГ: ❌ есть строки с ❌ выше — почини по подсказке и запусти установку ещё раз."; fi
exit $bad
