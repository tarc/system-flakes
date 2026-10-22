#!/usr/bin/env bash
# keep-awake.sh — hold a temporary Windows "system required" request from WSL2,
# so the laptop does not idle-sleep during a long unattended wait.
#
#   keep-awake.sh start <hours>   start one holder (refuses if one is running)
#   keep-awake.sh status          list every running holder and its expiry
#   keep-awake.sh stop            stop every running holder, then confirm none is left
#
# The holder is a detached, hidden Windows PowerShell process that calls
# SetThreadExecutionState(ES_CONTINUOUS | ES_SYSTEM_REQUIRED) and sleeps until its
# expiry, then clears the request. Nothing persistent changes: no power plan or
# powercfg setting is touched, and normal sleep returns as soon as the process ends.
# The display may still turn off. Closing the lid or choosing Sleep still sleeps.
#
# Every holder's encoded command starts with the same marker line, so status and
# stop find ALL holders by that marker, never by a remembered PID (a stop by PID
# once missed a second copy).
set -euo pipefail

MARKER='# claude-keep-awake v1'
MAX_HOURS=24

# Run a PowerShell script passed on stdin, encoded because quoting does not
# survive the trip through WSL interop. Progress records are switched off: with
# stderr redirected they arrive as CLIXML noise. Strips the CRs Windows adds.
ps_run() {
  local enc
  enc=$( { echo '$ProgressPreference = "SilentlyContinue"'; cat; } | iconv -f UTF-8 -t UTF-16LE | base64 -w0)
  powershell.exe -NoProfile -NonInteractive -EncodedCommand "$enc" 2>&1 | tr -d '\r'
}

# PowerShell that defines $found: every running holder, excluding the querying
# process itself (its own command line is never a holder, but exclude it anyway).
FIND='
$m = [Text.Encoding]::Unicode.GetBytes("# claude-keep-awake v1")
$prefix = [Convert]::ToBase64String($m).Substring(0, [Math]::Floor($m.Length / 3) * 4)
$found = @(Get-CimInstance Win32_Process |
  Where-Object { $_.Name -eq "powershell.exe" -and $_.ProcessId -ne $PID -and $_.CommandLine -and $_.CommandLine.Contains($prefix) })
function Get-Expiry($p) {
  $b64 = (($p.CommandLine -split "-EncodedCommand\s+")[1].Trim() -split "\s+")[0]
  $text = [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($b64))
  if ($text -match "hours = ([0-9.]+)") { return $p.CreationDate.AddHours([double]$Matches[1]) }
  return $null
}
'

cmd_status() {
  ps_run <<EOF
$FIND
if (\$found.Count -eq 0) { "keep-awake: none running"; exit 0 }
foreach (\$p in \$found) {
  "keep-awake: pid {0}, started {1:yyyy-MM-dd HH:mm}, expires {2:yyyy-MM-dd HH:mm} (Windows local time)" -f \$p.ProcessId, \$p.CreationDate, (Get-Expiry \$p)
}
EOF
}

cmd_stop() {
  ps_run <<EOF
$FIND
foreach (\$p in \$found) { Stop-Process -Id \$p.ProcessId -ErrorAction SilentlyContinue; "keep-awake: stopped pid {0}" -f \$p.ProcessId }
Start-Sleep -Seconds 1
$FIND
if (\$found.Count -eq 0) { "keep-awake: none running" } else { foreach (\$p in \$found) { "keep-awake: STILL RUNNING pid {0}" -f \$p.ProcessId }; exit 1 }
EOF
}

cmd_start() {
  local hours=${1:-}
  if ! [[ $hours =~ ^[0-9]+([.][0-9]+)?$ ]] || ! awk -v h="$hours" -v m="$MAX_HOURS" 'BEGIN { exit !(h > 0 && h <= m) }'; then
    echo "usage: keep-awake.sh start <hours>  (0 < hours <= $MAX_HOURS)" >&2
    exit 2
  fi
  local running
  running=$(cmd_status)
  if grep -q 'keep-awake: pid ' <<<"$running"; then
    echo "$running"
    echo "keep-awake: already running; run 'keep-awake.sh stop' first" >&2
    exit 1
  fi

  # The holder. Its first line is the marker; "hours = N" is read back by status.
  local payload
  payload=$(cat <<EOF
$MARKER
\$ErrorActionPreference = 'Stop'
\$hours = $hours
\$k = Add-Type -MemberDefinition '[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint esFlags);' -Name Power -Namespace ClaudeKeepAwake -PassThru
if (\$k::SetThreadExecutionState([uint32]2147483649) -eq 0) { exit 3 }
try { Start-Sleep -Seconds ([int](\$hours * 3600)) }
finally { [void]\$k::SetThreadExecutionState([uint32]2147483648) }
EOF
)
  local penc
  penc=$(printf '%s' "$payload" | iconv -f UTF-8 -t UTF-16LE | base64 -w0)

  # Start-Process detaches the holder from WSL, so it outlives this shell and the
  # session that ran it. A holder that cannot set the request exits within
  # seconds, so a live process after the wait means the request is held.
  ps_run <<EOF
\$p = Start-Process powershell.exe -WindowStyle Hidden -PassThru -ArgumentList '-NoProfile','-NonInteractive','-EncodedCommand','$penc'
Start-Sleep -Seconds 8
if (Get-Process -Id \$p.Id -ErrorAction SilentlyContinue) {
  "keep-awake: started pid {0}, expires {1:yyyy-MM-dd HH:mm} (Windows local time)" -f \$p.Id, (Get-Date).AddHours($hours)
} else { "keep-awake: FAILED, the holder exited (request not held)"; exit 1 }
EOF
}

case ${1:-} in
  start) shift; cmd_start "$@" ;;
  status) cmd_status ;;
  stop) cmd_stop ;;
  *) echo "usage: keep-awake.sh start <hours> | status | stop" >&2; exit 2 ;;
esac
