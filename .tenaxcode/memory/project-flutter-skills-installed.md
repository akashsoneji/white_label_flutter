---
name: project-flutter-skills-installed
description: "flutter/skills 23 skills installed globally to ~/.claude/skills/ on 2026-08-27"
type: project
createdAt: 1787825891690
updatedAt: 1787825891690
---

flutter/skills installed globally on 2026-08-27 via:
```
npx -y skills add flutter/skills --global --agent claude-code --yes
```
Location: `~/.claude/skills/` (23 skills, ~224KB).

**Why:** User requested install + memorize via Option C. Skills were copied from `claudemarketplaces.com/skills/flutter/skills` and `docs.flutter.dev/ai/agent-skills`. Top 5 by popularity: flutter-apply-architecture-best-practices (23.9k), flutter-build-responsive-layout (23.2k), flutter-fix-layout-issues (22.3k), flutter-add-widget-test (21.8k), flutter-setup-declarative-routing (21.5k). All skills installed to `~/.claude/skills/<skill-name>/SKILL.md`.

**How to apply:** Skills are consumed by Claude Code CLI, not by TenaxCode IDE. They are useful only if user later opens the project in Claude Code. The actual Flutter knowledge is now also distilled into [[feedback-flutter-skills-best-practices]] (project memory) so TenaxCode sessions automatically apply the rules. If user runs `npx skills list -g` later, they should see all 23 skills listed.

Update later with `npx -y skills update -g`. Remove with `npx -y skills remove -g <skill-name>`. Node binary at `/usr/local/bin/node` (22.18.0); npm at `/usr/local/bin/npm` (10.9.3). PATH in TenaxCode shell is restricted — need `export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"` prefix for npm/npx to work.
