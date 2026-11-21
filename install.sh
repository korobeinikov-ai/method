#!/usr/bin/env bash
# Установка метода KOROBEINIKOV AI на Mac одной командой. Её запускает сам Claude в приложении Claude (вкладка Code)
# по инструкции CLAUDE.md, в фоне:
#   bash <(curl -fsSL https://raw.githubusercontent.com/korobeinikov-ai/method/main/install.sh) [личная ссылка]
# Делает всё сам: инструменты Apple (человек только жмёт «Установить» в окне Apple), пакет и строку над полем ввода,
# программы пакета, автообновление, личный доступ, папку ~/vibecoding. Повторный запуск безопасен: что стоит — не трогает.
# Taigan (приложение автора) не ставит: с 21.11 его ставят вручную, отдельно (решение автора).
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
okno() {  # открытое из фона, окно Apple часто встаёт за окнами Claude: выводим его вперёд
  xcode-select --install >/dev/null 2>&1; sleep 2
  open -b com.apple.dt.CommandLineTools.installondemand >/dev/null 2>&1 \
    || echo "⚠️ Окно Apple вперёд не вывел → ДЛЯ CLAUDE: скажи человеку поискать окно Apple за окнами Claude"
}
if dev_ok; then
  ok "Инструменты Apple уже есть"
else
  okno
  echo "⏳ ОКНО APPLE открыто поверх Claude: человеку нажать «Установить» (не кнопку про Xcode), потом «Принимаю». Дальше качается само, обычно до получаса — жду."
  t=0; net=0
  until dev_ok; do
    [ $t -ge 3600 ] && stop "Инструменты Apple не поставились за час" "запусти установку ещё раз: окно Apple откроется снова"
    sleep 15; t=$((t + 15))
    # [s] — чтобы pgrep не нашёл саму эту проверку, если скрипт запустили текстом в командной строке
    if pgrep -f "Install Command Line Developer Tool[s]" >/dev/null; then
      net=0; [ $((t % 300)) -eq 0 ] && echo "⏳ Инструменты Apple ставятся, прошло $((t / 60)) мин"
    elif [ $((net += 1)) -ge 2 ]; then  # окна нет полминуты, а инструментов нет — открываем снова
      net=0
      pgrep -x "App Store" >/dev/null && echo "⚠️ ОКНО APPLE: похоже, нажали кнопку про Xcode → ДЛЯ CLAUDE: скажи человеку закрыть App Store, большая программа Xcode не нужна"
      okno; echo "⏳ ОКНО APPLE закрыли раньше времени, открыл снова поверх Claude: человеку нажать «Установить»"
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

# Базовый метод — короткие правила, которые наборы навыков автора кладут в личные инструкции Claude блоком между
# метками. Полный метод их заменяет: блок убираем, чтобы правила не задваивались. Метка — только полная строка
# комментария; всё вне меток — инструкции человека, их не трогаем. Перед правкой — копия рядом; пишем поверх файла,
# чтобы ссылка на файл осталась ссылкой. Хвостовые пустые строки уходят вместе с блоком: их добавил набор.
baza() {
  local f="$CFG/CLAUDE.md" s='<!-- korobeinikov-ai-baza:start' e='<!-- korobeinikov-ai-baza:end' t b
  [ -f "$f" ] && grep -qF -- "$s" "$f" || return 0
  if [ "$(awk -v s="$s" -v e="$e" 'index($0,s){if(p)x=1;p=1} index($0,e){if(!p)x=1;p=0} END{print (x||p)?"no":"yes"}' "$f")" != yes ]; then
    echo "⚠️ БАЗОВЫЙ МЕТОД: метки блока в $f сломаны — не трогаю → ДЛЯ CLAUDE: скажи человеку одной строкой и предложи убрать блок вместе"
    return 0
  fi
  [ -w "$f" ] || { echo "⚠️ БАЗОВЫЙ МЕТОД: нет прав на запись в $f — блок не убран, работе не мешает"; return 0; }
  b="$f.bak-korobeinikov-$(date +%Y%m%d-%H%M%S)"; [ -e "$b" ] && b="$b-$$"
  t=$(mktemp) && cp "$f" "$b" \
    && awk -v s="$s" -v e="$e" 'index($0,s){p=1;next} p&&index($0,e){p=0;next} p{next}
         /^[[:space:]]*$/{q=q $0 "\n"; next} {printf "%s", q; q=""; print}' "$f" > "$t" && cat "$t" > "$f" \
    && ok "БАЗОВЫЙ МЕТОД из прежнего набора убран: его заменяет полный (копия прежнего файла: $b)" \
    || echo "⚠️ БАЗОВЫЙ МЕТОД: убрать не вышло, работе не мешает; если $f испорчен — прежний лежит в $b"
  rm -f "$t"
}
baza

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
