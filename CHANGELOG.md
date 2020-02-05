# boltwash changelog

## 0.2.0 (2020-02-05)

- Switch to using Bolt transport connections to implement exec. Now supports exec over SSH, WinRM, and Docker. Provides more complete support for Bolt inventory options. (#3)
- Specify the `os.login_shell` attribute for Wash so that Wash built-ins - such as `volume.FS` and `wps` - work with PowerShell. Requires Wash 0.20.0. (#4)

## 0.1.0 (2020-01-29)

Supports executing commands over SSH, viewing inventory config on a target as metadata, and exploring the filesystem of targets over SSH.
