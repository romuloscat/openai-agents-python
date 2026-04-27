# Issue Triage Skill

Automatically triages new GitHub issues by analyzing content, applying labels, assigning priority, and routing to the appropriate team or milestone.

## Overview

This skill monitors newly opened issues and performs the following actions:

1. **Classify** the issue type (bug, feature request, question, documentation, etc.)
2. **Apply labels** based on content analysis (component, severity, type)
3. **Assign priority** (P0-critical, P1-high, P2-medium, P3-low)
4. **Request clarification** if the issue lacks sufficient detail
5. **Link related issues** or pull requests when duplicates or related work is detected
6. **Add to milestone** if the issue fits an existing roadmap item

## Triggers

- New issue opened
- Issue reopened
- Issue edited (re-triage if content changes significantly)

## Labels Applied

### Type Labels
- `bug` — Something isn't working as expected
- `enhancement` — New feature or improvement request
- `question` — User asking for help or clarification
- `documentation` — Docs need updating or are missing
- `performance` — Performance-related concern
- `security` — Security vulnerability or concern

### Priority Labels
- `P0-critical` — Service-breaking, needs immediate attention
- `P1-high` — Significant impact, address in current sprint
- `P2-medium` — Moderate impact, address soon
- `P3-low` — Minor issue, address when capacity allows

### Component Labels
- `comp:agents` — Core agent runtime
- `comp:tools` — Tool/function calling system
- `comp:tracing` — Tracing and observability
- `comp:streaming` — Streaming response handling
- `comp:handoffs` — Agent handoff mechanism
- `comp:memory` — Memory and context management

## Clarification Requests

The skill will post a comment requesting more information when:
- Bug reports lack reproduction steps
- Feature requests lack use-case description
- Issues are missing environment/version details

## Configuration

The skill uses the following environment variables:
- `GITHUB_TOKEN` — Token with issues read/write permissions
- `OPENAI_API_KEY` — For content classification
- `REPO_OWNER` — Repository owner
- `REPO_NAME` — Repository name

## Example Output

For a bug report about agent streaming failing:
```
Labels added: bug, P1-high, comp:streaming
Comment posted: "Thanks for the report! I've labeled this as a high-priority streaming bug."
```

## Notes

- The skill avoids re-triaging issues that already have priority labels unless explicitly triggered
- Security issues are flagged privately and not labeled publicly until reviewed
- Duplicate detection uses semantic similarity, not just keyword matching
