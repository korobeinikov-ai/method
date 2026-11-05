#!/usr/bin/env python3
"""Заводит проект человека из скелета пакета: ~/vibecoding/<папка>.

  novyi_proekt.py <папка> "<Название>" "<Для чего>" [--data DIR] [--zadacha "<задача>"] [--bez-github]

1) папка со скелетом (правила, карта, охрана секретов), метки заполнены;
2) git: охрана секретов перед каждым сохранением (core.hooksPath .githooks), первая версия;
   с --data — отметка «проводник пройден» и просьба следующему сеансу в папке спросить задачу
   (с --zadacha — напомнить задачу, которую человек назвал ещё до настройки);
3) закрытая копия на GitHub — если есть вход в GitHub и нет --bez-github.
Упал посередине — запусти так же ещё раз: продолжит с места остановки.
"""
import re
import shutil
import subprocess
import sys
from pathlib import Path

SKELET = Path(__file__).resolve().parent.parent.parent / "skelet"
NAME = re.compile(r"^[a-z0-9][a-z0-9-]{0,49}$")
NO_GITHUB = "пока нет — заведём, когда понадобится"


def run(args, cwd=None):
    r = subprocess.run(args, check=False, cwd=cwd, capture_output=True, text=True, timeout=120)
    return r.returncode, (r.stdout + r.stderr).strip()


def gh_login():
    if not shutil.which("gh"):
        return None, None
    code, out = run(["gh", "api", "user", "--jq", ".login + \" \" + (.id|tostring)"])
    parts = out.split()
    return (parts[0], parts[1]) if code == 0 and len(parts) == 2 else (None, None)


def fill(path, values):
    text = path.read_text(encoding="utf-8")
    path.write_text(re.sub(r"\{\{(ИМЯ|ЗАЧЕМ|GITHUB)\}\}", lambda m: values[m.group(1)], text), encoding="utf-8")


def opt(argv, name):
    return argv[argv.index(name) + 1] if name in argv and argv.index(name) + 1 < len(argv) else None


def main(argv):
    data, task = opt(argv, "--data"), opt(argv, "--zadacha")
    args = [a for i, a in enumerate(argv[1:], 1) if not a.startswith("--") and argv[i - 1] not in ("--data", "--zadacha")]
    if len(args) != 3 or not NAME.match(args[0]) or not args[1].strip() or not args[2].strip():
        print(__doc__)
        print("❌ Нужно: имя папки (строчные латинские буквы, цифры, дефис), название и «для чего» — не пустые.")
        return 2
    folder, title, purpose = args
    no_github = "--bez-github" in argv
    target = Path.home() / "vibecoding" / folder
    ours = (target / ".githooks" / "pre-commit").is_file() and (target / "CLAUDE.md").is_file()

    if ours:
        print(f"✅ Папка проекта уже есть — продолжаю с места остановки: {target}")
    elif target.exists() and any(target.iterdir()):
        print(f"❌ Папка уже есть, и в ней не проект пакета: {target}. Выбери другое имя.")
        return 1
    else:
        shutil.copytree(SKELET, target, dirs_exist_ok=True)
        for name in ("CLAUDE.md", "STRUCTURE.md", "IDEYA.md"):
            fill(target / name, {"ИМЯ": title, "ЗАЧЕМ": purpose, "GITHUB": NO_GITHUB})
        print(f"✅ Папка проекта: {target}")

    def git(*a):
        return run(["git", *a], cwd=target)

    login, uid = (None, None) if no_github else gh_login()
    if git("rev-parse", "--verify", "-q", "HEAD")[0] != 0:  # первой версии ещё нет
        steps = [] if (target / ".git").exists() else [["init", "-q", "-b", "main"]]
        steps.append(["config", "core.hooksPath", ".githooks"])
        if git("config", "user.email")[0] != 0:  # на новом Mac git не знает, кто сохраняет
            name, email = (login, f"{uid}+{login}@users.noreply.github.com") if login else ("Владелец проекта", "owner@localhost")
            steps += [["config", "user.name", name], ["config", "user.email", email]]  # только в этом проекте
        steps += [["add", "-A"], ["commit", "-q", "-m", "Скелет проекта по методу KOROBEINIKOV AI"]]
        for s in steps:
            code, out = git(*s)
            if code != 0:
                print(f"❌ Шаг «git {s[0]}» не прошёл:\n{out[-800:]}\nПочини и запусти этот же шаг ещё раз.")
                return 1
    print("✅ Охрана секретов в проекте включена, первая версия сохранена")

    if data:  # проводник пройден: копия на GitHub может и подождать
        d = Path(data)
        d.mkdir(parents=True, exist_ok=True)
        (d / "gotovo").write_text("1", encoding="utf-8")
        (d / "sprosit-zadachu").write_text(str(target), encoding="utf-8")
        if task and task.strip():
            (d / "zadacha").write_text(" ".join(task.split())[:300], encoding="utf-8")  # одна строка, коротко

    if no_github:
        return 0
    if git("remote", "get-url", "origin")[0] != 0:
        if not login:
            print("⚠️ Нет входа в GitHub — копию на GitHub заведём позже (нужен вход: gh auth login).")
            return 0
        code, out = run(["gh", "repo", "create", f"{login}/{folder}", "--private", "--description", title,
                         "--source", str(target), "--remote", "origin"])
        if code != 0:
            print(f"⚠️ Закрытую копию на GitHub не завёл: {out.splitlines()[-1] if out else 'нет ответа'}")
            return 0
        structure = target / "STRUCTURE.md"
        structure.write_text(structure.read_text(encoding="utf-8").replace(NO_GITHUB, f"https://github.com/{login}/{folder}"),
                             encoding="utf-8")
        git("add", "STRUCTURE.md")
        git("commit", "-q", "-m", "Карта: где закрытая копия на GitHub")
    code, out = git("push", "-q", "-u", "origin", "main")
    if code != 0:
        print(f"⚠️ Копия на GitHub заведена, но отправить не вышло: {out[-300:]}\nПочини и запусти этот же шаг ещё раз.")
        return 0
    print(f"✅ Закрытая копия на GitHub: {git('remote', 'get-url', 'origin')[1].removesuffix('.git')}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
