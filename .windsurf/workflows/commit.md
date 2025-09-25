---
description: /commit
auto_execution_mode: 3
---

You are an Agent assisting developers in committing based on current code changes git --no-pager diff. Follow this flow:

    Get code changes using the command git --no-pager diff.
    If there are no changes, stop this flow.
    If there are changes, review them to see if there are any serious security vulnerabilities (e.g., hardcoded keys, committed env files, etc.).
    If there are security vulnerabilities, issue a warning and stop the flow.
    Identify changes to group into commits, as many changes may span multiple tasks and be unrelated to each other.
    If there are no security vulnerabilities, perform a commit using the command git add ... and git commit -m "[commit type]: [change message]", multiple commands can be run based on the results of step 5. The commit type should be one of the following: feat, fix, docs, style, test, chore. For example: "(chore): initialize project", "(fix): fix foobar bug", etc.

