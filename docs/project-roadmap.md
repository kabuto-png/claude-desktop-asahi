# Project Roadmap & Status

## Current Status: Active Development
**Last Updated**: 2026-03-19
**Claude Desktop Version**: 0.14+ (tracks official releases)
**Supported Platforms**: Fedora Asahi ARM64, generic Linux (manual build)

## Phase 1: Foundation ✓ (Complete)

### Build System
- ✓ Universal build entry point (build-appimage.sh)
- ✓ Fedora Asahi ARM64 optimized builder
- ✓ Fallback manual builder
- ✓ Dependency validation
- ✓ 4 critical patches implemented
- ✓ Native module stubs created
- ✓ AppImage packaging

### Runtime
- ✓ Main launcher with process management
- ✓ Process cleanup utility
- ✓ Status checker
- ✓ HiDPI auto-detection and scaling
- ✓ Environment variable setup

### Version Management
- ✓ Official version detection
- ✓ Auto-update mechanism
- ✓ GitHub fallback for updates
- ✓ Version caching
- ✓ AppImage version inspection

### Support Tools
- ✓ Auth diagnostics
- ✓ Debug launcher
- ✓ Cleanup utility

**Completion**: 100% - Core functionality stable

## Phase 2: Polish & Documentation ✓ (In Progress)

### Documentation (Current Work)
- ✓ Project overview & requirements
- ✓ Codebase summary
- ✓ Code standards & conventions
- ✓ System architecture
- ⏳ Project roadmap (this file)
- ⏳ README update (reduce to <300 lines, update refs)
- 🔲 Troubleshooting guide
- 🔲 Quick start guide
- 🔲 Contributing guidelines

### Code Quality
- 🔲 Refactor for clarity (if >200 LOC per script)
- 🔲 Linting check (ShellCheck)
- 🔲 Code review

**Target Completion**: 2026-03-31 (2 weeks)

## Phase 3: Enhancement & Testing (Planned)

### Expanded Platform Support
- 🔲 x86_64 Linux (generic)
- 🔲 Ubuntu 22.04+ support
- 🔲 Debian 12+ support
- 🔲 openSUSE support
- 🔲 Alpine Linux (lightweight)

### Improved Update System
- 🔲 Update notifier UI (Zenity dialog)
- 🔲 Multiple version management
- 🔲 Rollback to previous version
- 🔲 Scheduled update checks
- 🔲 Update from custom URL support

### Testing Infrastructure
- 🔲 ShellCheck linting in CI
- 🔲 Integration tests for build
- 🔲 Runtime smoke tests
- 🔲 GitHub Actions CI/CD

**Target Completion**: 2026-06-30 (3 months)

## Phase 4: Advanced Features (Future)

### Security & Hardening
- 🔲 AppArmor confinement profiles
- 🔲 Seccomp sandboxing
- 🔲 Code signing & verification
- 🔲 Checksum validation for downloads

### User Experience
- 🔲 Desktop integration (menu entry, icons)
- 🔲 System tray integration
- 🔲 Keyboard shortcuts configuration
- 🔲 Theme support (light/dark)

### Packaging Alternatives
- 🔲 RPM package (.rpm)
- 🔲 Debian package (.deb)
- 🔲 Flatpak support
- 🔲 Snap support
- 🔲 Nix package
- 🔲 Docker/Podman image

### Plugin System
- 🔲 Custom extension loading
- 🔲 Plugin management UI
- 🔲 Plugin marketplace integration

**Target Completion**: 2026-12-31 (9 months, lower priority)

## Known Issues & Limitations

### Current Issues

1. **ARM64 Native Modules**
   - Status: Open
   - Severity: Medium
   - Description: Windows-compiled native modules don't run on ARM64 Linux
   - Workaround: Stub with no-ops (works for most features)
   - Long-term: Wait for upstream Electron + Claude support or rebuild modules

2. **Window Management**
   - Status: Open
   - Severity: Low
   - Description: Some window decorations don't match native GTK perfectly
   - Workaround: Works adequately; cosmetic only
   - Long-term: Upstream Electron improvements

3. **Audio/Video Codecs**
   - Status: Open
   - Severity: Medium (if user needs screen share)
   - Description: Some codecs may not work on Linux
   - Workaround: Test with specific codec; report to Anthropic
   - Long-term: Update Electron + ffmpeg

4. **Clipboard Integration**
   - Status: Open
   - Severity: Low
   - Description: Clipboard may not sync with system perfectly
   - Workaround: Manual copy/paste works
   - Long-term: Improve X11/Wayland integration

### Limitations (By Design)

1. **No Source Build** - Uses official Windows installer (not building from source)
   - Reason: Simpler, faster, stays in sync with official releases
   - Trade-off: More dependent on Windows-to-Linux compatibility

2. **AppImage Format** - Not traditional package manager
   - Reason: Portability across distros, no system-level installation
   - Trade-off: Manual installation, no package manager integration (yet)

3. **Manual Installation** - Not in official repos
   - Reason: Unofficial/community project
   - Trade-off: Extra steps to set up

## Success Metrics

### Phase 1 (Foundation) - ✓ Met
- [x] Builds on Fedora Asahi ARM64
- [x] AppImage runs without crashes
- [x] Claude Code integration works
- [x] Auto-update detects versions
- [x] HiDPI scaling works

### Phase 2 (Polish) - In Progress
- [x] Documentation complete (by 2026-03-31)
- [ ] Zero ShellCheck warnings
- [ ] All tests pass
- [ ] Code reviewed

### Phase 3 (Expansion) - Planned
- [ ] Build succeeds on ≥3 distros (Fedora, Ubuntu, Debian)
- [ ] x86_64 support working
- [ ] Update UI functional
- [ ] CI/CD pipeline established

### Phase 4 (Advanced) - Future
- [ ] ≥2 alternative packages (RPM, DEB)
- [ ] Security profiles functional
- [ ] Community plugins available

## Dependencies & Blockers

### External Dependencies

**Anthropic Official**
- RELEASES endpoint availability
- Installer format stability (WinRAR → asar)
- Claude Desktop update frequency

**Upstream Projects**
- christian-korneck/claude-desktop-asahi-fedora-arm64 (patches)
- aaddrick/claude-desktop-debian (fallback updates)
- Electron framework (core runtime)

### Technical Blockers

1. **ARM64 Codec Support** - Blocked on Electron/ffmpeg updates
2. **Flatpak Integration** - Blocked on Flatpak review process
3. **Official Anthropic Support** - Requires upstream interest
4. **Desktop Integration** - Requires distro integration

## Maintenance Plan

### Weekly (Ongoing)
- Monitor Anthropic releases for new versions
- Check upstream projects for patch updates
- Review GitHub issues/discussions

### Monthly (Quarterly)
- Update documentation with new features
- Review and merge community contributions
- Test on latest Fedora/Ubuntu LTS

### Major Updates (As Needed)
- Evaluate new Electron versions
- Test compatibility with major system updates
- Update build scripts for breaking changes

## Community Involvement

### Contributing
- Bug reports: GitHub Issues
- Feature requests: GitHub Discussions
- Code: Pull requests with tests
- Documentation: Wiki edits

### Support Channels
- GitHub Issues (technical problems)
- Discussions (questions, ideas)
- Documentation (self-service help)

## Acknowledgments

**Direct Sources**
- christian-korneck/claude-desktop-asahi-fedora-arm64 - Core patches
- aaddrick/claude-desktop-debian - Original AppImage concept
- bsneed/claude-desktop-fedora - Indirect inspiration

**Community**
- Fedora Asahi project (ARM64 support)
- Electron project (core framework)
- Open source tools (curl, aria2, appimagetool)

## Version History

| Version | Date | Major Changes |
|---------|------|---------------|
| 0.1.0 | 2026-03-19 | Initial release, Fedora Asahi ARM64 support |
| (planned) | 2026-04-30 | Documentation complete, x86_64 support |
| (planned) | 2026-06-30 | Package alternatives, CI/CD |
| (planned) | 2026-12-31 | Advanced features (plugins, confinement) |

## Getting Help

- **Build Failed** → Run `./fedora_asahi_build_script.sh` with `DEBUG=1`
- **Launch Failed** → Run `claude-auth-diagnostics.sh`
- **Update Issues** → Check `investigate_version_sources.sh`
- **General Help** → See `docs/` directory
- **Report Bug** → GitHub Issues with reproducible steps

## Next Steps

1. **Immediate** (This week)
   - Complete documentation (Phase 2)
   - Code review + ShellCheck pass

2. **Short-term** (This month)
   - Troubleshooting guide
   - Quick start guide
   - Contributing guidelines

3. **Medium-term** (This quarter)
   - x86_64 support
   - Additional distros
   - Update UI improvements

4. **Long-term** (This year)
   - Package alternatives
   - Security hardening
   - Community plugins

---

**Last Updated**: 2026-03-19
**Maintained By**: Community
**License**: See LICENSE file
