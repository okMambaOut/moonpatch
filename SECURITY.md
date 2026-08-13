# Security Policy

## Supported Version

Security fixes are applied to the latest release line.

## Reporting

Report suspected vulnerabilities privately through GitHub Security Advisories
after the public repository is available. Do not include secrets or sensitive
production patches in a public issue.

## Threat Model

MoonPatch treats every patch, path, and file inventory as untrusted input. It
rejects absolute, dot-segment, backslash, duplicate, and conflicting paths;
bounds input size, numeric ranges, relocation distance, and LCS allocation; and
requires unique exact context matches. It performs no filesystem I/O, command
execution, networking, archive extraction, or dynamic code loading.

Consumers remain responsible for authorization, filesystem sandboxing, atomic
disk writes, symlink defenses, and limiting aggregate inventory size.

