#!/bin/bash
# Ставит программы пакета прямо в ~/.local/bin: связь с GitHub (gh), сканер секретов (gitleaks),
# проверка кода (ruff). Без Homebrew и без пароля Mac, всего ~30 МБ. Что уже есть — не трогает.
# Версии и контрольные суммы закреплены: подменённый файл не поставится. Новая версия — только правкой здесь.
BIN="$HOME/.local/bin"
PATH="$BIN:$PATH"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
mkdir -p "$BIN"
bad=0

# get <программа> <адрес файла> <контрольная сумма>
get() {
  local name=$1 url=$2 found
  if command -v "$name" >/dev/null; then echo "✅ $name уже есть"; return; fi
  if ! curl -fsSL -o "$T/$name.pack" "$url"; then
    echo "❌ $name не скачался — проверь интернет и запусти снова"; bad=1; return
  fi
  if [ "$(shasum -a 256 "$T/$name.pack" | cut -d' ' -f1)" != "$3" ]; then
    echo "❌ $name: файл не совпал с контрольной суммой — не ставлю, сообщи автору пакета"; bad=1; return
  fi
  mkdir "$T/$name"
  case "$url" in
    *.zip) unzip -q "$T/$name.pack" -d "$T/$name" ;;
    *) tar -xzf "$T/$name.pack" -C "$T/$name" ;;
  esac
  found=$(find "$T/$name" -type f -name "$name" | head -1)
  if [ -n "$found" ] && mv "$found" "$BIN/$name" && chmod +x "$BIN/$name" && "$BIN/$name" --version >/dev/null; then
    echo "✅ $name поставлен"
  else
    echo "❌ $name не запустился — сообщи автору пакета"; bad=1
  fi
}

GH=https://github.com/cli/cli/releases/download/v2.103.3/gh_2.103.3_macOS
GL=https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_darwin
RF=https://github.com/astral-sh/ruff/releases/download/0.17.3/ruff
if [ "$(uname -m)" = arm64 ]; then
  get gh "${GH}_arm64.zip" d700207eae9ae98fe2b89535c2c087c07823d4628c56364695a5a07ef311c062
  get gitleaks "${GL}_arm64.tar.gz" b40ab0ae55c505963e365f271a8d3846efbc170aa17f2607f13df610a9aeb6a5
  get ruff "$RF-aarch64-apple-darwin.tar.gz" 118f7121aa838785672bf612487f755a89108bb5f44e0f3df96c5967a72614f9
else
  get gh "${GH}_amd64.zip" a2f86418f4350ae6e9ec60d5000bdf7665728436946a97fc27fe50e6ae752682
  get gitleaks "${GL}_x64.tar.gz" dfe101a4db2255fc85120ac7f3d25e4342c3c20cf749f2c20a18081af1952709
  get ruff "$RF-x86_64-apple-darwin.tar.gz" 17f95b1bee24d70de62ffe5beec7f71bb541c7e3d147a1c3d84f7cd6525f6fdf
fi
exit $bad
