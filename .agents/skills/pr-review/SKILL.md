# PR Review Skill

This skill automates pull request review tasks, including checking code quality,
verifying test coverage, validating documentation updates, and ensuring consistency
with project conventions.

## What This Skill Does

- Analyzes pull request diffs for common issues
- Checks that new code has corresponding tests
- Validates that documentation is updated when public APIs change
- Ensures commit messages follow the project's style guide
- Flags potential breaking changes
- Summarizes the PR for reviewers

## Inputs

| Variable | Description | Required |
|----------|-------------|----------|
| `PR_NUMBER` | The pull request number to review | Yes |
| `REPO` | The repository in `owner/repo` format | Yes |
| `GITHUB_TOKEN` | GitHub token with PR read access | Yes |
| `REVIEW_LEVEL` | `light`, `standard`, or `deep` (default: `standard`) | No |
| `POST_COMMENT` | Whether to post review as a PR comment (`true`/`false`, default: `false`) | No |

## Outputs

The skill produces a structured review report containing:

- **Summary**: High-level description of the changes
- **Issues**: List of detected problems with severity levels
- **Suggestions**: Optional improvements that are not blocking
- **Checklist**: Pass/fail status for standard review criteria
- **Score**: Overall review score (0–100)

## Usage

### Running Locally

```bash
export PR_NUMBER=42
export REPO=openai/openai-agents-python
export GITHUB_TOKEN=ghp_...
export REVIEW_LEVEL=standard
export POST_COMMENT=false

bash .agents/skills/pr-review/scripts/run.sh
```

### Running on Windows

```powershell
$env:PR_NUMBER = "42"
$env:REPO = "openai/openai-agents-python"
$env:GITHUB_TOKEN = "ghp_..."
$env:REVIEW_LEVEL = "standard"
$env:POST_COMMENT = "false"

.agents\skills\pr-review\scripts\run.ps1
```

## Review Criteria

### Light Review
- Commit message format
- No obvious syntax errors
- PR description is present

### Standard Review (default)
- All light checks
- Test files updated alongside source changes
- No hardcoded secrets or credentials
- Public API changes have docstring updates
- No large unrelated changes mixed in

### Deep Review
- All standard checks
- Type annotations present on new public functions
- Changelog or release notes updated if applicable
- No deprecated APIs introduced
- Performance-sensitive paths have benchmarks or comments

## Notes

- The skill uses the GitHub REST API and does not require a local clone of the repository.
- When `POST_COMMENT=true`, the bot will post a single review comment. Re-running will update the existing comment rather than creating a new one.
- Secrets scanning is heuristic-based and should not replace dedicated secret-scanning tools.
