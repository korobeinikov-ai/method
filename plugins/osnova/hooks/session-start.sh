#!/bin/bash
# SessionStart: правила пакета + состояние человека — в каждый сеанс (старт, /clear, сжатие).
# Без python3: работает и на голом Mac. Обычный текст на выходе Claude видит как контекст
# (CLAUDE.md из плагина Claude Code не грузит). Предел — 10 000 знаков на весь вывод.
# Состояние — в постоянной папке пакета ($CLAUDE_PLUGIN_DATA), её не стирают обновления:
#   gotovo — проводник пройден; nastroyki-versiya — какие настройки человек принял или отклонил;
#   sprosit-zadachu — проект только что заведён: один раз спросить «что хотите сделать?»;
#   zadacha — задача, которую человек назвал ещё до настройки: напомнить вместо вопроса.
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
DATA="${CLAUDE_PLUGIN_DATA:-}"
TPL="$ROOT/skills/start/nastroyki.json"

cat "$ROOT/rules/PRAVILA.md" || echo "KOROBEINIKOV AI: не прочитал правила пакета ($ROOT/rules/PRAVILA.md)" >&2

# git и python3 — из инструментов разработчика Apple; без них /usr/bin/git и python3 — пустышки
dev=$(xcode-select -p 2>/dev/null)
if [ -z "$dev" ] || [ ! -x "$dev/usr/bin/git" ] || [ ! -x "$dev/usr/bin/python3" ]; then
  cat <<'EOF'

## ⚠️ Нет инструментов разработчика Apple
На компьютере нет git и python3 — охрана пакета сейчас НЕ работает. До любой другой работы: запусти
`xcode-select --install`, скажи человеку в окне нажать «Установить», дождись конца в фоне, потом /start.
EOF
fi

if [ -z "$DATA" ]; then
  echo "KOROBEINIKOV AI: нет постоянной папки пакета (CLAUDE_PLUGIN_DATA) — первый запуск не отслеживаю" >&2
  exit 0
fi

# Строка внизу окна (настройка statusLine) смотрит в постоянную папку: кладём свежую копию каждый сеанс
mkdir -p "$DATA" && cp "$ROOT/skills/start/stroka.py" "$DATA/stroka.py" \
  || echo "KOROBEINIKOV AI: не обновил строку внизу окна ($DATA/stroka.py)" >&2

if [ ! -f "$DATA/gotovo" ]; then
  cat <<'EOF'

## Первый запуск KOROBEINIKOV AI
Человек ещё не прошёл проводник. На первое же его сообщение (даже «привет») запусти навык `start` и веди
по нему. Если он сразу написал задачу — скажи, что сначала за пару минут всё настроишь как у автора,
а потом сразу к ней; задачу запомни.
EOF
  exit 0
fi

have=$(cat "$DATA/nastroyki-versiya" 2>/dev/null || echo 0)
new=$(sed -n 's/.*"versiya": *\([0-9][0-9]*\).*/\1/p' "$TPL" | head -1)
if [ -n "$new" ] && [ "$have" -lt "$new" ] 2>/dev/null; then
  what=$(sed -n 's/.*"chto_novogo": *"\([^"]*\)".*/\1/p' "$TPL" | head -1)
  cat <<EOF

## Автор обновил настройки
У человека настройки версии $have, в пакете — $new: $what. В естественной паузе, не перебивая задачу,
одной строкой предложи обновить. Согласится — навык \`start\`, только настройки из шага 2.
EOF
fi

if [ -f "$DATA/sprosit-zadachu" ]; then
  proj=$(cat "$DATA/sprosit-zadachu")
  there=$(cd "$proj" 2>/dev/null && pwd -P)
  here=$(cd "${CLAUDE_PROJECT_DIR:-$PWD}" 2>/dev/null && pwd -P)
  if [ -n "$there" ] && [ "$here" = "$there" ]; then  # метку тратит только сеанс в папке проекта
    task=$(cat "$DATA/zadacha" 2>/dev/null)  # уже укорочена при записи (novyi_proekt.py)
    rm -f "$DATA/sprosit-zadachu" "$DATA/zadacha"
    if [ -n "$task" ]; then
      ask="Ещё до настройки человек назвал задачу: «${task}». Напомни её одной строкой и предложи начать
с неё — заново не спрашивай"
    else
      ask="Спроси «Что хотите сделать?»"
    fi
    cat <<EOF

## Проект только что заведён
Проводник пройден, это папка нового проекта. На первое сообщение коротко поздравь. $ask
(навык \`start\`, шаг «За дело»).
EOF
  elif [ -n "$there" ]; then
    cat <<EOF

## Новый проект ждёт
Недавно заведён проект в $proj, но Claude открыт в другой папке. Хочет человек работать над
проектом — в приложении Claude открой новый сеанс в этой папке, в терминале подскажи: \`/exit\`, затем \`cd $proj && claude\`.
EOF
  fi
fi
exit 0
