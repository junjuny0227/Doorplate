# Security policy

## Supported versions

Doorplate is in 0.x beta. Only the latest release receives fixes; please check that a problem still happens there before reporting it.

## Reporting a vulnerability

Please report privately through GitHub: open the repository's **Security** tab and choose **Report a vulnerability** ([direct link](https://github.com/junjuny0227/Doorplate/security/advisories/new)). Do not open a public issue for a security problem.

Include the Doorplate version, your macOS version, the steps to reproduce, and what an attacker gains. Leave out personal paths and scan output you do not need to share.

Doorplate is maintained by one person in their spare time. You can expect an acknowledgement within a week; fixes ship as a new release through the in-app updater and Homebrew, and the advisory is published once the fix is out. Credit is given unless you ask otherwise.

## Scope

Examples of what counts:

- Bypassing the update signature check (Sparkle EdDSA) or making Doorplate install an update it should reject.
- Making Doorplate stop a process the user did not choose, for example through PID reuse, or stop a Docker runtime or a macOS service.
- Code or command execution through data Doorplate reads: process names and arguments, project files such as `package.json`, or Docker API responses.
- Doorplate sending data off the Mac, connecting to listening ports, or using administrator rights, all of which it promises not to do.

Not vulnerabilities:

- The Gatekeeper warning on first launch. Releases are signed ad hoc and not notarized; this is documented.
- Problems that need an attacker who already runs code as your user or has administrator rights.
- Ports, project names or paths shown in the menu: Doorplate shows them to you on purpose, locally.
