# master-pressure — «Давление»

Первая игра серии «Мастер»: трубы с напором. Godot 4.7.2, GDScript.

- Правила: [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md)
- Задачи: [docs/TASKS.md](docs/TASKS.md)

## Инструменты (локально)
Godot для headless-запуска, JDK 17 и Android SDK лежат рядом, в `../_tools/`.
Запуск всегда через обёртку (она подставляет актуальные пути):

    ../_tools/godot.sh --headless -s tests/run_all.gd

APK собирать во временную папку вне репозитория, затем копировать.
