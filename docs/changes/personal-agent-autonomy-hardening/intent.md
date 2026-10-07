# Intent: Autonomous delivery for personal projects

Author: Etienne van Delden. Status: accepted (2026-10-01). Type: feature.

## Problem

Etienne spends too much time reading and accepting intent, specification and plan documents, then manually steering agents between implementation, review and fixes. Even when the desired feature and its use by a human are clear, routine technical decisions and handoffs keep returning to him. The attention needed to supervise delivery limits what he can build on personal projects.

## Proposed outcome

Personal-project work starts with a conversation about what to build, how a human should use it and what successful behavior looks like. Etienne agrees to that scope before autonomous delivery starts.

After that agreement, multiple models and agents take responsibility for technical decisions, specification, planning, implementation, verification, review and fixes. They coordinate their own work and challenge each other's conclusions without requiring Etienne to review or accept intermediate documents, invoke each stage or relay reports between agents.

Agents carry the agreed change through to a verified pull request. Etienne receives a concise account of the delivered behavior and the evidence supporting it, with one final approval before merging. Product choices that materially change the agreed behavior, actions outside the granted authority and genuine blockers return to him with a concrete decision to make.

Success means a representative personal-project change reaches a verified PR after the initial product conversation, without routine stage approvals or manual steering. Multiple models and agents contribute to delivery and review, and required checks and review findings are resolved before the final handoff.

## Affected users and systems

Etienne's personal development workflow, the shared Claude Code and Codex guidance maintained in this public dotfiles repository, and repositories identified as his personal projects. Both agent environments should support the same autonomy boundaries.

The provisional repository for the first end-to-end trial is `journal_administration`.

## Constraints

- This is a personal-only amendment to the accepted AI-native workflow. Professional projects retain their current approval requirements.
- Human agreement on the intended behavior and human approval before merging remain required. Deployment is outside the autonomous delivery scope.
- Removing routine human approvals must preserve meaningful tests, linting, security checks, independent review and verification of the delivered behavior. Agents must resolve findings without weakening checks to obtain a pass.
- AI work continues through local CLIs under the existing policy; this intent does not authorize AI agents in GitHub Actions or GitHub apps.
- Existing explicit permission requirements for dependencies, system tooling, destructive database operations, deployment and infrastructure changes, symlinks and Stow, and posting GitHub comments remain in force unless separately revised. Agents should surface known permission needs during the initial conversation where possible.
- Work stays isolated in feature worktrees and PRs. No employer-specific code, configuration, credentials or internal source material enters this public workflow.

## Open questions

- Which representative change in `journal_administration` should be used for the first end-to-end trial?
