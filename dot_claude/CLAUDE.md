# Claude Code Configuration

This file contains **Claude Code-specific** configurations, rules, and workflows.

For general coding principles, philosophies, and practices, see **[~/AGENTS.md](../AGENTS.md)**.

---

## Claude-Specific Rules

- To understand how to use a library, **always use the Contex7 MCP** to retrieve the latest information.

---

## Integration with AGENTS.md

**This project follows the AGENTS.md standard**, an open format for guiding AI coding agents adopted by 20,000+ repositories and supported by OpenAI Codex, GitHub Copilot, Cursor, Google Jules, and other AI tools.

**Primary instruction source**: See [~/AGENTS.md](../AGENTS.md) for:
- Universal philosophy (meta-principles, foundational principles, decision-making, application patterns)
- Design principles (SOLID)
- Design practices (Unix philosophy)
- Testing strategy (strategy, automation, QA principles)
- Operations (AI-driven automation)
- Implementation practices (code quality)
- Language-specific guidelines (TypeScript, Go, Python, Rust, Zig, Haskell)

This file (CLAUDE.md) contains **Claude Code-specific** configurations that complement the general AGENTS.md instructions.

---

## Git Commit Rules

- **Do NOT include Claude Code signature in commit messages**
- Remove the following lines from all commit messages:
  - `🤖 Generated with [Claude Code](https://claude.com/claude-code)`
  - `Co-Authored-By: Claude <noreply@anthropic.com>`
- Keep commit messages clean and professional without AI attribution

---

## Machine-Specific Configuration

<!--
This section loads machine-specific settings from local.md if it exists.
Create .claude/local.md for machine-specific rules that should not be version controlled.
-->

<!-- Include machine-specific settings if they exist -->
<!-- Note: local.md should be added to .gitignore -->
