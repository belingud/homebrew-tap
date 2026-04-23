# belingud/homebrew-tap

This is the Homebrew tap for `belingud` command-line tools.

Currently available formulas:

- `gptcomet`
- `gh-download`
- `trash-cli-rs`

## Install

Add the tap first:

```bash
brew tap belingud/tap
```

Then install the formula you want.

### Install gptcomet

```bash
brew install belingud/tap/gptcomet
```

Installed commands:

- `gptcomet`
- `gmsg`

### Install gh-download

```bash
brew install belingud/tap/gh-download
```

Installed commands:

- `gh-download`

### Install trash-cli-rs

```bash
brew install belingud/tap/trash-cli-rs
```

Installed commands:

- `trash`

## Repository Layout

```text
Formula/
  gptcomet.rb
  gh-download.rb
  trash-cli-rs.rb
update_formulas.sh
AGENTS.md
README.md
```

Files:

- `Formula/`: Homebrew formula files
- `update_formulas.sh`: script to update one or more formulas
- `AGENTS.md`: maintenance notes and workflow for this tap

## Update Formulas

Use the shared update script:

```bash
./update_formulas.sh
```

This updates all formulas by default.

Update a single formula:

```bash
./update_formulas.sh gptcomet
./update_formulas.sh gh-download
./update_formulas.sh trash-cli-rs
```

## Debug Formula Updates

Use `--debug` to print step-by-step progress:

```bash
./update_formulas.sh --debug
./update_formulas.sh --debug gptcomet
```

Debug mode is useful when checking where an update is blocked, for example:

- fetching the latest release tag
- falling back to remote tag lookup
- resolving the revision for a tag
- comparing current formula values with remote values

## Update Strategy

`update_formulas.sh` works like this:

1. Read the current `version`, `tag`, and `revision` from the formula.
2. Fetch the latest release information from the remote repository.
3. Compare current values with remote values.
4. Write back only when something changed.

Remote lookup order:

1. GitHub Releases API
2. Remote revision lookup for the resolved tag
3. Fallback remote tag listing when needed

## Maintenance Notes

- Formulas prefer source builds over prebuilt release archives.
- Formulas pin both `tag` and `revision`.
- Go projects use `go build`.
- Rust projects use `cargo install --locked`.
- `test do` should stay minimal but meaningful.

See [AGENTS.md](AGENTS.md) for the maintenance workflow and repository conventions.
