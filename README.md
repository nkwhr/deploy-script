# Deploy Script

A sample script for application deployment written in Bash.

## Description

This script only does the followings:

1. Clone the source code from git repository.
2. Copy the source code to a single remote host using rsync(1).
3. Create a symlink in remote host which points the latest release.
4. Switch back symlink to last release if necessary.

## Usage

```
$ bin/deploy.sh (clone|test|deploy|release|rollback)
```

### commands

- clone
  - Clone latest release from git repository.
- test
  - Dry run deployment to remote host.
- deploy
  - Deploy a latest release to remote host.
- release
  - Switch application to deployed release.
- rollback
  - Switch back to last release.
