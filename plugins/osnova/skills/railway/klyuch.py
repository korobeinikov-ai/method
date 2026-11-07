#!/usr/bin/env python3
"""Ключи мимо чата: буфер обмена → .env проекта → Railway. Значение ключа не печатается никогда.

  klyuch.py vzyat ИМЯ                                взять из буфера обмена и сохранить в .env
  klyuch.py peredat ИМЯ --service S [--bez-vykladki] передать из .env на Railway
  klyuch.py imena --service S                        какие настройки есть на Railway (только имена)
  klyuch.py nastroyki                                как устроены части на Railway (без значений ключей)
  klyuch.py zhurnal --service S                      нет ли значений ключей в журналах новой выкладки
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path


def stop(tekst):
    print(f"❌ {tekst}")
    sys.exit(1)


def koren():
    r = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True, check=False)
    return Path(r.stdout.strip()) if r.returncode == 0 else Path.cwd()


def nayti(imya):
    """Значение из .env проекта или None."""
    fayl = koren() / ".env"
    if fayl.exists():
        for stroka in fayl.read_text().splitlines():
            if stroka.startswith(f"{imya}="):
                return stroka.split("=", 1)[1]
    return None


def prochitat(imya):
    znachenie = nayti(imya)
    if znachenie is None:
        stop(f"В файле ключей проекта нет {imya}")
    return znachenie


def zapisat(imya, znachenie):
    """Заменяет строку ключа или дописывает её. Файл читает только владелец компьютера."""
    fayl = koren() / ".env"
    stroki = fayl.read_text().splitlines() if fayl.exists() else []
    novaya = f"{imya}={znachenie}"
    if any(s.startswith(f"{imya}=") for s in stroki):
        stroki = [novaya if s.startswith(f"{imya}=") else s for s in stroki]
    else:
        stroki.append(novaya)
    # Файл рождается закрытым: ключ ни на миг не лежит на диске с открытым доступом.
    with os.fdopen(os.open(fayl, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600), "w") as f:
        f.write("\n".join(stroki) + "\n")
    fayl.chmod(0o600)


def vzyat(imya):
    r = subprocess.run(["git", "check-ignore", "-q", ".env"], cwd=koren(), capture_output=True, check=False)
    if r.returncode != 0:
        stop("Файл ключей не закрыт от git: сначала добавь .env в .gitignore")
    znachenie = subprocess.run(["pbpaste"], capture_output=True, text=True, check=True).stdout.strip()
    if len(znachenie) < 20 or re.search(r"\s", znachenie):
        stop("В буфере обмена не ключ. Попроси человека скопировать ключ ещё раз, целиком")
    zapisat(imya, znachenie)
    subprocess.run(["pbcopy"], input="", text=True, check=True)
    print(f"✅ {imya} сохранён в файле ключей проекта, буфер обмена очищен")


def vse_klyuchi():
    """Длинные значения из .env: короткие настройки вроде часового пояса ключами не считаем."""
    fayl = koren() / ".env"
    pary = (s.split("=", 1) for s in (fayl.read_text().splitlines() if fayl.exists() else []) if "=" in s)
    return {imya: znachenie for imya, znachenie in pary if len(znachenie) >= 20}


def railway(argumenty, vvod=None, skryt=()):
    """Запускает программу Railway из корня проекта: связь с Railway запомнена по папке.

    Значения ключей не должны попасть в вывод даже при ошибке.
    """
    programma = shutil.which("railway", path=f"{Path.home()}/.local/bin{os.pathsep}{os.environ.get('PATH', '')}")
    if not programma:
        stop("Нет программы Railway: сначала шаг 1 навыка railway")
    r = subprocess.run(
        [programma, *argumenty], input=vvod, capture_output=True, text=True, errors="replace", check=False, cwd=koren()
    )
    if r.returncode != 0:
        tekst = (r.stderr or r.stdout).strip()
        for znachenie in skryt:
            tekst = tekst.replace(znachenie, "***")
        stop(f"Railway не выполнил команду: {tekst}")
    return r.stdout


def peredat(imya, servis, bez_vykladki):
    znachenie = prochitat(imya)
    argumenty = ["variable", "set", imya, "--stdin", "--service", servis]
    if bez_vykladki:
        argumenty.append("--skip-deploys")
    railway(argumenty, vvod=znachenie, skryt=[znachenie])
    print(f"✅ {imya} передан на Railway: {servis}" + ("" if bez_vykladki else ", началась новая выкладка"))


def imena(servis):
    dannye = json.loads(railway(["variable", "list", "--service", servis, "--json"]))
    svoi = sorted(k for k in dannye if not k.startswith("RAILWAY_"))
    print("\n".join(svoi) if svoi else "Настроек пока нет")


def nastroyki():
    """Railway отдаёт настройки вместе со значениями ключей, поэтому берём только эти поля."""
    dannye = json.loads(railway(["environment", "config", "--json"]))
    polya = (("source", "rootDirectory"), ("source", "repo"), ("source", "branch"), ("deploy", "restartPolicyType"))
    chasti = {
        imya: {f"{gruppa}.{pole}": (chast.get(gruppa) or {}).get(pole) for gruppa, pole in polya}
        for imya, chast in dannye.get("services", {}).items()
    }
    print(json.dumps(chasti, ensure_ascii=False, indent=2))


def zhurnal(servis):
    """Запускать до показа журнала в разговоре: без --latest Railway смотрит прошлую удачную выкладку."""
    klyuchi = vse_klyuchi()
    if not klyuchi:
        stop("В файле ключей проекта нет ключей")
    for vid in ([], ["--build"]):
        vyvod = railway(["logs", *vid, "--latest", "--service", servis, "--lines", "500"], skryt=klyuchi.values())
        for imya, znachenie in klyuchi.items():
            if znachenie in vyvod:
                stop(f"Значение {imya} есть в журнале: ключ раскрыт, журнал не показывай, замени ключ и почини вывод")
    print(f"✅ В последних 500 строках журналов работы и сборки нет значений: {', '.join(klyuchi)}")


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("deystvie", choices=["vzyat", "peredat", "imena", "nastroyki", "zhurnal"])
    p.add_argument("imya", nargs="?")
    p.add_argument("--service")
    p.add_argument("--bez-vykladki", action="store_true")
    a = p.parse_args()
    if a.deystvie in ("vzyat", "peredat") and not a.imya:
        stop("Назови ключ: например, TELEGRAM_BOT_TOKEN")
    if a.deystvie not in ("vzyat", "nastroyki") and not a.service:
        stop("Назови часть на Railway: --service bot")
    if not os.path.exists("/usr/bin/pbpaste") and a.deystvie == "vzyat":
        stop("Нет буфера обмена: этот шаг работает только на Mac")
    if a.deystvie == "vzyat":
        vzyat(a.imya)
    elif a.deystvie == "peredat":
        peredat(a.imya, a.service, a.bez_vykladki)
    elif a.deystvie == "imena":
        imena(a.service)
    elif a.deystvie == "nastroyki":
        nastroyki()
    else:
        zhurnal(a.service)


if __name__ == "__main__":
    main()
