# Security policy

## Reporting a vulnerability

Do not disclose credentials, exploit details, private user data, or suspected
malicious behavior in a public issue. Use GitHub's private vulnerability
reporting for this repository when available. If it is unavailable, contact
the maintainer privately through the address listed in the repository's GitHub
security settings and include:

- The affected release or exact commit.
- The relevant file and behavior.
- A safe reproduction, without real credentials or personal data.
- Whether user files, themes, shell state, or desktop restoration are affected.

Please allow time for validation and a coordinated fix before public
disclosure.

## Trust boundaries

Omagen is unsandboxed plugin code. It can read selected images and Omarchy
configuration, write its own state and generated themes, invoke the bundled
backend and explicitly reviewed runtime adapters, and interact with the
user's Omarchy/Hyprland session. It does not require `sudo`, install packages,
or modify package-owned Omarchy files.

The installer and runtime preserve ownership markers and use the backend
session record for restoration. Users should review the source and use the
documented Cancel, Restore, Recovery, or uninstall paths rather than deleting
Omagen state manually during an active session.

## Automated baseline

Run `python3 scripts/marketplace-preflight.py` before promotion. The check is
deterministic and commit-bound. It looks for a limited set of unsafe patterns,
reports capabilities such as installers and bundled binaries, and fails closed
on incomplete scans. It is not a security audit, certification, endorsement,
or guarantee that the plugin is safe.

The stable marketplace submission must identify the exact full commit that was
scanned. Any later source change requires a new scan and marketplace update.
