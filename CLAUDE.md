# CLAUDE.md — Rules for Claude Code in this project

## What this project is
A lightweight, polished, stable 2D mobile multiplayer card game (Android first, iOS later).
Initial games: **Spades** and **29 (Twenty-Nine)**. Inspired by the experience of worldofcardgames.com.
Target: 4 players on 4 separate phones, one phone is host AND a player, over **local Wi-Fi and Bluetooth (both required)**.

## About the owner (IMPORTANT)
The owner is a **complete beginner at programming**.
- Explain technical decisions in plain language. Avoid or define jargon.
- Before asking the owner to run any terminal command, explain: what it does, why it is needed, and what its output means.
- The owner wants to understand and maintain the code, not just receive it. Explain important code changes in beginner-friendly language.

## Tech stack (fixed unless the owner agrees to change it)
- Engine: Godot 4 (Standard, not .NET)
- Language: GDScript with static typing (`var x: int`, `func f(a: String) -> bool`)
- Platform: Android first, iOS later
- Version control: Git + GitHub
- Editor: VS Code
- Independent reviewer: OpenAI Codex
- Do NOT introduce Rust, Unity, Firebase, Supabase or other external technologies without first explaining a concrete reason and getting approval.

## Architecture rules (details in docs/ARCHITECTURE.md)
Keep four layers strictly separate:
1. UI / card presentation
2. Game logic and rules (pure code, no UI, no networking, testable on its own)
3. Multiplayer protocol (the logical messages)
4. Network transport (Wi-Fi, Bluetooth) — swappable behind one interface

- The **host is authoritative**: it validates every action and owns the official game state.
- **Never send a player's private cards to anyone but that player.** Clients only get their own hand plus public information.
- Wi-Fi and Bluetooth must carry the same logical messages.
- Design for disconnect/reconnect. Host migration is postponed.
- Do not assume Android↔iOS Bluetooth compatibility; verify against the platform APIs first.

## Workflow rules
- Small, understandable steps. Explain the purpose of a feature before building it.
- Prefer simple, maintainable solutions.
- Use automated tests for important game logic (test-driven where practical).
- Test in Godot before calling anything done. **Never claim something works without verifying it** — show the evidence.
- Use Superpowers skills when relevant (brainstorming, writing-plans, test-driven-development, systematic-debugging, verification-before-completion).
- Ask Codex for an independent review of important changes when appropriate.
- If a decision materially affects architecture, explain the alternatives and ask the owner first.

## Git and safety rules
- **Never commit, push, delete branches, or run destructive Git operations without explicit approval from the owner.**
- Never install software, change system settings, or change environment variables without asking first.
- Never expose or commit passwords, API keys, keystores or other secrets.
- Inspect only what is relevant; do not scan the whole computer.

## Game rules rule
- **Do not invent game rules.** Spades and especially 29 have many regional variants. Rules must be written down in `docs/` and confirmed by the owner (see `docs/OPEN_QUESTIONS.md`) before being implemented.

## Environment notes
- OS: Windows 11. Shell: PowerShell / Git Bash.
- Project folder: `C:\Claude-Code\Card-Game`
