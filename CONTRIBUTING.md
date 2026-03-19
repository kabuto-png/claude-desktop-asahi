# Contributing

Thanks for your interest in contributing to Claude Desktop AppImage Builder!

## Reporting Bugs

Use the [bug report template](.github/ISSUE_TEMPLATE/bug_report.md) and include:
- OS, architecture, Claude Desktop version
- Steps to reproduce
- Relevant logs from `~/.cache/claude-desktop-launch.log`

## Development Setup

```bash
git clone https://github.com/user/claude-desktop-to-appimage.git
cd claude-desktop-to-appimage
chmod +x *.sh
```

### Dependencies
- `curl`, `jq`, `unzip`/`7z`, `appimagetool`
- Node.js + npm (for asar extraction)
- FUSE (for AppImage mounting)

### Testing
- Build on target architecture: `./build-appimage.sh`
- Test AppImage launches: `./Claude_Desktop-*.AppImage --no-sandbox`
- Run ShellCheck: `shellcheck -s bash -S error *.sh`

## Pull Requests

1. Fork the repo and create a feature branch
2. Make your changes
3. Ensure `shellcheck -s bash -S error *.sh` passes
4. Test on your target platform
5. Submit PR using the [PR template](.github/PULL_REQUEST_TEMPLATE.md)

## Code Style

- Shell scripts follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html) loosely
- Use `snake_case` for functions and variables
- Add comments for non-obvious logic
- See `docs/code-standards.md` for project conventions

## Credits

This project builds on work by:
- [christian-korneck](https://github.com/christian-korneck/claude-desktop-asahi-fedora-arm64) - Critical patches
- [aaddrick](https://github.com/aaddrick/claude-desktop-debian) - Original AppImage concept

## License

By contributing, you agree that your contributions will be licensed under the Apache License 2.0.
