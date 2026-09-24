## Order of hook calls in a template

1. `pre_fetch()` runs before downloading sources. It is rarely used.
2. `do_fetch()` downloads archives from distfiles. `build_style` usually provides it, so it is rarely overridden.
3. `post_fetch()` runs after downloading and before extraction.
4. `pre_extract()` runs before extracting the archive.
5. `do_extract()` extracts the archive into `$wrksrc`. `build_style` usually provides it.
6. `post_extract()` runs after extraction and before applying patches.
7. `pre_patch()` runs before applying patches from the `patches/` directory.
8. `do_patch()` applies patches. `build_style` usually provides it.
9. `post_patch()` runs after patches and before configuration. It is a common place for `sed` edits.
10. `pre_configure()` runs before the project's configuration step, such as `./configure` or `cmake`.
11. `do_configure()` runs the configuration command. `build_style` usually handles it using `configure_args`.
12. `post_configure()` runs after configuration and before building.
13. `pre_build()` runs before compilation. Use it to adjust Makefiles or the CMake cache.
14. `do_build()` compiles the project with commands such as `make`, `cargo build`, or `ninja`. `build_style` usually provides it.
15. `post_build()` runs after compilation and before tests.
16. `pre_check()` runs before tests.
17. `do_check()` runs tests such as `make check`, `ctest`, or `cargo test`. Tests are often disabled by default.
18. `post_check()` runs after tests and before installation.
19. `pre_install()` runs before installing files into `${DESTDIR}`.
20. `do_install()` installs files into `${DESTDIR}`. It usually uses `make install`, `cargo install`, or the selected `build_style`.
21. `post_install()` performs final package changes, such as creating runit scripts, copying licenses, removing unwanted files, and installing headers or pkg-config files. Use `${PKGDESTDIR}` for new files and `${DESTDIR}` to adjust files that are already installed.
22. `do_clean()` removes temporary files.

## Порядок вызова хуков в шаблоне

1. `pre_fetch()` выполняется до скачивания исходников. Используется редко.
2. `do_fetch()` скачивает архивы из distfiles. Обычно его предоставляет `build_style`, поэтому переопределяется редко.
3. `post_fetch()` выполняется после скачивания и до распаковки.
4. `pre_extract()` выполняется до распаковки архива.
5. `do_extract()` распаковывает архив в `$wrksrc`. Обычно его предоставляет `build_style`.
6. `post_extract()` выполняется после распаковки и до применения патчей.
7. `pre_patch()` выполняется до применения патчей из каталога `patches/`.
8. `do_patch()` применяет патчи. Обычно его предоставляет `build_style`.
9. `post_patch()` выполняется после патчей и до настройки проекта. Здесь часто редактируют файлы с помощью `sed`.
10. `pre_configure()` выполняется до настройки проекта, например через `./configure` или `cmake`.
11. `do_configure()` запускает настройку проекта. Обычно `build_style` обрабатывает ее с помощью `configure_args`.
12. `post_configure()` выполняется после настройки и до сборки.
13. `pre_build()` выполняется до компиляции. Здесь можно изменить Makefile или кэш CMake.
14. `do_build()` компилирует проект командами `make`, `cargo build` или `ninja`. Обычно его предоставляет `build_style`.
15. `post_build()` выполняется после компиляции и до тестов.
16. `pre_check()` выполняется до запуска тестов.
17. `do_check()` запускает тесты, например `make check`, `ctest` или `cargo test`. По умолчанию тесты часто отключены.
18. `post_check()` выполняется после тестов и до установки.
19. `pre_install()` выполняется до установки файлов в `${DESTDIR}`.
20. `do_install()` устанавливает файлы в `${DESTDIR}`. Обычно используются `make install`, `cargo install` или выбранный `build_style`.
21. `post_install()` вносит последние изменения в пакет: создает скрипты runit, копирует лицензии, удаляет ненужные файлы и устанавливает заголовки или pkg-config. Для новых файлов используется `${PKGDESTDIR}`, а для изменения уже установленных файлов `${DESTDIR}`.
22. `do_clean()` удаляет временные файлы.
