# AI Agent Guidelines (AGENTS.md)

Welcome! This document outlines mandatory rules and best practices for AI agents working in this SDK repository.

---

## 🚨 MANDATORY / MAJOR RULE

**EVERY TIME any agent is coding in this SDK repository, it MUST ALWAYS inspect the main SwiftCode repository:**

👉 **[https://github.com/dylans2010/SwiftCode-Mac](https://github.com/dylans2010/SwiftCode-Mac)**

### Why this is required:
1. **API & Contract Alignment:** Ensure SDK interfaces, types, and schemas align perfectly with the main SwiftCode-Mac application.
2. **Architectural Consistency:** Follow design patterns, conventions, and architectural choices established in the main app.
3. **Upstream Changes:** Keep track of recent updates, breaking changes, or refactoring in SwiftCode-Mac that affect the SDK.

Before making any structural changes, adding endpoints/methods, or refactoring code in this SDK repo, search or review the relevant components in `github.com/dylans2010/SwiftCode-Mac`.

---

## 🛠 Coding Standards & Best Practices

1. **Code Quality & Documentation**
   - Write clear, clean, self-documenting code.
   - Include clear docstrings/comments for public APIs, types, and exported modules.

2. **Testing & Verification**
   - Always run and add unit tests for new features or bug fixes.
   - Verify changes thoroughly before marking steps complete or submitting PRs.

3. **Workflow & Verification Checklist**
   - Check `github.com/dylans2010/SwiftCode-Mac` first.
   - Implement minimal, robust changes in the SDK.
   - Test locally to confirm no regressions.
   - Verify all modified or created files using read-only tools.
