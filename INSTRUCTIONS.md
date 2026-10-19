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
