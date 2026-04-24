# Dependency Update Skill

This skill automates the process of checking for outdated dependencies, evaluating upgrade safety, and applying updates with appropriate testing.

## Overview

The dependency update skill performs the following tasks:
1. Scans the project for dependency files (`pyproject.toml`, `requirements*.txt`, `setup.py`)
2. Identifies outdated packages using `pip list --outdated` or `uv pip list --outdated`
3. Evaluates changelogs and release notes for breaking changes
4. Groups updates by risk level (patch, minor, major)
5. Applies updates in order of safety, running tests after each group
6. Generates a summary report of applied and skipped updates

## Inputs

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `UPDATE_STRATEGY` | One of `patch`, `minor`, `all` | No | `minor` |
| `DRY_RUN` | If `true`, only report without applying changes | No | `false` |
| `SKIP_PACKAGES` | Comma-separated list of packages to skip | No | `` |
| `TEST_COMMAND` | Command to run tests after updates | No | `pytest` |
| `BRANCH_NAME` | Branch to create for the update PR | No | `deps/auto-update` |

## Outputs

- Updated dependency files committed to `BRANCH_NAME`
- `dependency-update-report.md` summarizing all changes
- PR created with update details and test results

## Usage

### GitHub Actions

```yaml
- uses: ./.agents/skills/dependency-update
  with:
    UPDATE_STRATEGY: minor
    DRY_RUN: false
    TEST_COMMAND: "pytest tests/ -x -q"
```

### Manual

```bash
bash .agents/skills/dependency-update/scripts/run.sh
```

## Risk Levels

- **Patch** (`x.y.Z`): Bug fixes only — applied automatically
- **Minor** (`x.Y.z`): New features, backward-compatible — applied with test validation
- **Major** (`X.y.z`): Potentially breaking — flagged for manual review, skipped unless `UPDATE_STRATEGY=all`

## Notes

- The skill respects version pins and constraints defined in `pyproject.toml`
- If tests fail after a group of updates, that group is rolled back and individual packages are retried
- Packages listed in `SKIP_PACKAGES` are never modified
