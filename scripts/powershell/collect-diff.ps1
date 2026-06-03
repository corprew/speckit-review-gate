<#
.SYNOPSIS
  Resolve the feature-branch implementation diff for the Spec Kit Review Gate.
.DESCRIPTION
  Emits JSON describing the diff so /speckit.review-gate.review can hand it to
  /code-review. Windows parity for scripts/bash/collect-diff.sh.
.PARAMETER Json
  Emit machine-readable JSON (default).
.PARAMETER Base
  Override base ref. Otherwise REVIEW_GATE_BASE env var, then auto-detection.
#>
param(
  [switch]$Json,
  [string]$Base = $env:REVIEW_GATE_BASE
)
$ErrorActionPreference = 'Stop'

function Fail($msg) {
  @{ error = $msg } | ConvertTo-Json -Compress
  exit 1
}

git rev-parse --is-inside-work-tree *> $null
if ($LASTEXITCODE -ne 0) { Fail "not a git repository" }

$repoRoot = (git rev-parse --show-toplevel).Trim()
Set-Location $repoRoot

$branch = (git rev-parse --abbrev-ref HEAD 2>$null)
if (-not $branch) { $branch = "HEAD" }

# Resolve base ref.
$baseRef = ""
if ($Base -and $Base -ne "auto") {
  $baseRef = $Base
} else {
  foreach ($cand in @("main", "master")) {
    git show-ref --verify --quiet "refs/heads/$cand"
    if ($LASTEXITCODE -eq 0) { $baseRef = $cand; break }
  }
}

# Determine comparison point.
$mergeBase = ""
if ($baseRef) {
  $mergeBase = (git merge-base $baseRef HEAD 2>$null)
}
if (-not $mergeBase) {
  $mergeBase = (git rev-list --max-parents=0 HEAD 2>$null | Select-Object -Last 1)
}
if (-not $mergeBase) {
  $mergeBase = (git hash-object -t tree $null)
}

# Resolve feature directory (spec-kit convention: specs/<branch>).
$featureDir = ""
if (Test-Path "specs/$branch") {
  $featureDir = "specs/$branch"
} elseif (Test-Path "specs") {
  $latest = Get-ChildItem -Path "specs" -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($latest) { $featureDir = "specs/$($latest.Name)" }
}

$diffPath = [System.IO.Path]::GetTempFileName()
git diff $mergeBase HEAD 2>$null | Out-File -FilePath $diffPath -Encoding utf8

$diffStat = (git diff --stat $mergeBase HEAD 2>$null | Select-Object -Last 1)
if ($diffStat) { $diffStat = $diffStat.Trim() } else { $diffStat = "" }

$changedFiles = @(git diff --name-only $mergeBase HEAD 2>$null | Where-Object { $_ -ne "" })

[ordered]@{
  feature_dir   = $featureDir
  branch        = $branch
  base          = $baseRef
  merge_base    = $mergeBase
  changed_files = $changedFiles
  diff_stat     = $diffStat
  diff_path     = $diffPath
} | ConvertTo-Json -Compress
