---
name: wsl-keep-awake
description: Keep this WSL2 laptop from idle-sleeping while long unattended work runs (an overnight CI watch, a long build, a wait on a maintainer), then let it sleep again. Use when the user asks to stop the notebook/laptop/computer from sleeping, to keep it awake, or to undo that; and check `status` whenever a session that used it ends or resumes.
---

# Keep the laptop awake from WSL2

This machine is WSL2 on a Windows laptop, so sleep is Windows' decision. `keep-awake.sh` (next to this file) holds a temporary Windows request instead of changing power settings: a hidden, detached Windows PowerShell process calls `SetThreadExecutionState(ES_CONTINUOUS | ES_SYSTEM_REQUIRED)` and sleeps until it expires. When it ends, normal sleep returns on its own.

```bash
~/.claude/skills/wsl-keep-awake/keep-awake.sh start 6   # hours, 0 < h <= 24; refuses if one is running
~/.claude/skills/wsl-keep-awake/keep-awake.sh status    # every holder, with its expiry
~/.claude/skills/wsl-keep-awake/keep-awake.sh stop      # stops all holders, then confirms none is left
```

## Rules

- Size `start` to the wait plus a margin, and run `stop` as soon as the work is done. Tell the user it is on, until when, and that it changes no settings.
- Confirm a stop by its output line `keep-awake: none running`, never by a PID you remember. On 2026-10-22 a stop by PID left a second holder running for hours.
- The holder is detached, so it survives the session. A session that started one and ends, or resumes after a limit, runs `status` first.
- Say what it does not cover: closing the lid (when Windows sleeps on lid close), choosing Sleep, a critically low battery. The display may still turn off. Keep the lid open, ideally on power.

## Why it is built this way

- `powercfg /requests`, which would list the request, needs an elevated prompt, so it can't confirm from here. The script instead waits 8 s after starting: a holder that cannot set the request exits at once (`$ErrorActionPreference = 'Stop'`, exit 3 on a 0 return), so a live process means the request is held.
- Scripts go to `powershell.exe` as `-EncodedCommand` (UTF-16LE base64), because quoting does not survive WSL interop.
- Holders are found by a marker line at the start of the encoded command (`# claude-keep-awake v1`). A plain search for the word "EncodedCommand" matches the query's own process.
- Piping a long-running `powershell.exe` through `tr` into a file shows nothing until it exits (`tr` buffers), which is why `start` detaches the holder instead of streaming it.
