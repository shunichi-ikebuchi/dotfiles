# Personal AI Agent Instructions

These are my personal coding principles and guidelines that apply to **all projects** I work on. This file defines my development philosophy, coding standards, and preferences that AI coding agents should follow when assisting me.

**AGENTS.md** is an open standard for guiding AI coding agents, adopted by 20,000+ repositories and supported by Claude Code, OpenAI Codex, GitHub Copilot, Cursor, Google Jules, Aider, and others.

---

## Top-Level Rules

- **You must think exclusively in English**. However, you are required to **respond in Japanese**.
- To maximize efficiency, **if you need to execute multiple independent processes, invoke those tools concurrently, not sequentially**.
- To understand how to use a library, **always retrieve the latest information** from official documentation or reliable sources.

---

## Core Philosophy

All AI agents should familiarize themselves with these foundational principles:

### Universal Philosophy
- **[Meta-Principles](docs/philosophy/meta-principles.md)**: Top-down & bottom-up thinking, goal-oriented approach, intellectual honesty, avoiding tunnel vision
- **[Foundational Principles](docs/philosophy/foundational-principles.md)**: Inquiry-driven, systems-oriented, pluralistic & context-aware, shift left
- **[Decision-Making](docs/philosophy/decision-making.md)**: Evaluating options, time-horizon analysis, when NOT to decide
- **[Application Patterns](docs/philosophy/application-patterns.md)**: Abstraction-first communication, problem-solution discipline, systems-building, knowledge transformation, dogfooding

### Universal Design Principles
- **[Security-First Principles](docs/principles/security-first.md)**: Security First, Secure by Default, Defense in Depth, Least Privilege, Zero Trust
- **[Unix Philosophy](docs/principles/unix-philosophy.md)**: Do one thing well, composability, universal interfaces, single source of truth

### Software Design Principles
- **[SOLID Principles](docs/software/design/principles/solid.md)**: Object-oriented design principles (SRP, OCP, LSP, ISP, DIP)

### Testing Strategy
- **[Testing Strategy](docs/software/testing/strategy.md)**: Testing pyramid, shift left, human-AI collaboration
- **[Testing Automation](docs/software/testing/automation.md)**: What to automate, maximizing automation, anti-patterns
- **[QA Principles](docs/software/testing/qa-principles.md)**: Human judgment activities, requirements validation, UX evaluation, exploratory testing

### Operations
- **[AI-Driven Automation](docs/software/operations/ai-automation.md)**: Leveraging AI for productivity, human-AI collaboration patterns

### Implementation Practices
- **[Code Quality Principles](docs/software/implementation/general/code-quality.md)**: Writing clear, maintainable code (explicitness, locality, fail-fast design)

---

## Language-Specific Guidelines

When working with specific programming languages, consult the appropriate language-specific guidelines:

| Language | Quick Reference | Best Practices | Testing | Patterns |
|----------|----------------|----------------|---------|----------|
| **TypeScript** | [AGENTS.md](docs/software/implementation/languages/typescript/AGENTS.md) | [best-practices.md](docs/software/implementation/languages/typescript/best-practices.md) | [testing.md](docs/software/implementation/languages/typescript/testing.md) | [patterns.md](docs/software/implementation/languages/typescript/patterns.md) |
| **Go** | [AGENTS.md](docs/software/implementation/languages/go/AGENTS.md) | [best-practices.md](docs/software/implementation/languages/go/best-practices.md) | [testing.md](docs/software/implementation/languages/go/testing.md) | [patterns.md](docs/software/implementation/languages/go/patterns.md) |
| **Python** | [AGENTS.md](docs/software/implementation/languages/python/AGENTS.md) | [best-practices.md](docs/software/implementation/languages/python/best-practices.md) | [testing.md](docs/software/implementation/languages/python/testing.md) | [patterns.md](docs/software/implementation/languages/python/patterns.md) |
| **Java** | [AGENTS.md](docs/software/implementation/languages/java/AGENTS.md) | [best-practices.md](docs/software/implementation/languages/java/best-practices.md) | - | - |
| **Rust** | [AGENTS.md](docs/software/implementation/languages/rust/AGENTS.md) | [best-practices.md](docs/software/implementation/languages/rust/best-practices.md) | - | - |
| **Zig** | [AGENTS.md](docs/software/implementation/languages/zig/AGENTS.md) | [best-practices.md](docs/software/implementation/languages/zig/best-practices.md) | - | - |
| **Haskell** | [AGENTS.md](docs/software/implementation/languages/haskell/AGENTS.md) | [best-practices.md](docs/software/implementation/languages/haskell/best-practices.md) | - | - |

---

## Platform-Specific Guidelines

When working with cloud platforms, consult the appropriate platform-specific guidelines:

| Platform | Quick Reference | Architecture | IaC | Cost Optimization | Security |
|----------|----------------|--------------|-----|-------------------|----------|
| **Google Cloud Platform** | [AGENTS.md](docs/software/implementation/platforms/gcp/AGENTS.md) | [architecture.md](docs/software/implementation/platforms/gcp/architecture.md) | [iac.md](docs/software/implementation/platforms/gcp/iac.md) | [cost-optimization.md](docs/software/implementation/platforms/gcp/cost-optimization.md) | [security.md](docs/software/implementation/platforms/gcp/security.md) |
| **Amazon Web Services** | [AGENTS.md](docs/software/implementation/platforms/aws/AGENTS.md) | [architecture.md](docs/software/implementation/platforms/aws/architecture.md) | [iac.md](docs/software/implementation/platforms/aws/iac.md) | [cost-optimization.md](docs/software/implementation/platforms/aws/cost-optimization.md) | [security.md](docs/software/implementation/platforms/aws/security.md) |

**Platform Philosophy**: Leverage cloud provider strengths while avoiding excessive vendor lock-in through portable patterns and abstractions.

---

## Tool-Specific Configurations

While AGENTS.md serves as the universal instruction source, some tools have additional configuration files for tool-specific settings:

### Claude Code
For Claude Code-specific configurations and meta-principles, see:
- **[.claude/CLAUDE.md](.claude/CLAUDE.md)**: Claude Code-specific settings, decision-making frameworks, and application patterns

### Gemini CLI
For Gemini CLI-specific configurations, see:
- **[.gemini/GEMINI.md](.gemini/GEMINI.md)**: Gemini CLI-specific settings and imports

---

## How to Use This File

### For AI Agents
1. **Read this file first** to understand my personal development philosophy and coding standards
2. **Consult language-specific AGENTS.md** when working with a particular language
3. **Reference detailed practice documents** for in-depth guidance
4. **Check tool-specific configs** if using Claude Code or Gemini CLI
5. **Apply these principles across all projects** I work on, unless project-specific AGENTS.md overrides them

### Hierarchy of Instructions
When working on a specific project:
1. **Personal AGENTS.md** (this file): My universal coding principles
2. **Project-specific AGENTS.md** (if exists in project root): Project-specific overrides or additions
3. **Language-specific guidelines**: Detailed language practices from this file

### For Me (Developer)
- **Update this AGENTS.md** when my coding philosophy or standards evolve
- **Add new languages** in `.claude/practices/<language>/` as I learn them
- **Keep this as Single Source of Truth** for my personal development practices
- **Project-specific AGENTS.md should reference this file** and only add project-specific details

---

## Philosophy

**Automate everything that CAN be automated, so humans can focus on what MUST be human.**

This repository embraces AI-driven development while maintaining human oversight for:
- Strategic decisions and architecture
- Requirements validation
- UX evaluation
- Risk assessment
- Compliance and governance

See [AI-Driven Automation](.claude/principles/ai-automation.md) for our complete philosophy on human-AI collaboration.

---

## Evolution of This File

As my development philosophy evolves:
1. **Update core principles** when I discover better approaches
2. **Add new languages** as I learn them (create `.claude/practices/<language>/`)
3. **Refine language-specific practices** based on real-world experience
4. **Keep AI agents informed**: Clear, unambiguous instructions in natural language
5. **Verify across tools**: Test that changes work well with Claude, Copilot, Cursor, Gemini, etc.

This is a living document that grows with my expertise and reflects my current understanding of software engineering best practices.

---

## About AGENTS.md

AGENTS.md is an open standard created collaboratively by OpenAI Codex, Google Jules, Cursor, Factory, and other contributors in the AI coding agent ecosystem. It provides a predictable, portable format for AI agent instructions.

Learn more: https://agents.md/
