---
description: Init agents for windsurlfs
auto_execution_mode: 3
---

Please analyze this codebase and must create an ".windsurf/rules/agent.md" file within this project with correct path containing:
1. Makesure that always have this at the top of the agent-rules:
```markdown
## Language Requirements
- When a user asks in a language other than English, reiterate the request in English before proceeding
- Always think, answer, and perform in English

## Code Quality Standards

### Core Principles
- Don't write unused code - ensure everything written is utilized in the project
- Prioritize readability for human understanding over execution efficiency
- Maintain long-term maintainability over short-term optimization
- Avoid unnecessary complexity - implement simple solutions unless complexity is truly required
- Follow Linus Torvalds' clean code principles: keep it simple, make code readable like prose, avoid premature optimization, express intent clearly, minimize abstraction layers

### Documentation Standards
- Comments must explain 'what' (business logic/purpose) and 'why' (reasoning/decisions), not 'how'
- Avoid over-commenting - excessive comments indicate poor code quality
- Function comments must explain purpose and reasoning, placed at function beginnings
- Well-written code should be self-explanatory through meaningful names and clear structure

### Development Process
1. **Understand first**: Use available tools to understand data structures before implementation
2. **Design data structures**: Good data structures lead to good code
3. **Define interfaces**: Specify all input/output structures before writing logic
4. **Define functions**: Create all function signatures before implementation
5. **Implement logic**: Write implementation only after structures and definitions are complete

### Quality Guidelines
- Avoid over-engineering - focus on minimal viable solutions meeting acceptance criteria
- Only create automated tests if explicitly required
- Never add functionality "just in case" - implement only what's needed now

## Decision-Making Framework
Apply these principles systematically:
1. Gather Complete Information
2. Multi-Perspective Analysis
3. Consider All Stakeholders
4. Evaluate Alternatives
5. Assess Impact & Consequences
6. Apply Ethical Framework
7. Take Responsibility
8. Learn & Adapt
```
2. Build/lint/test commands - especially for running a single test
3. Code style guidelines including imports, formatting, types, naming conventions, error handling, etc.

The file you create will be given to agentic coding agents (such as yourself) that operate in this repository. Make it about 20 lines long.
If there are Cursor rules (in .cursor/rules/ or .cursorrules) or Copilot rules (in .github/copilot-instructions.md), make sure to include them.