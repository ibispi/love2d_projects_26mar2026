@echo off
setlocal
set "TG=%ProgramFiles%\TortoiseGit\bin\TortoiseGitProc.exe"
if not exist "%TG%" set "TG=%ProgramFiles(x86)%\TortoiseGit\bin\TortoiseGitProc.exe"
if not exist "%TG%" (
  echo TortoiseGit not found at "%ProgramFiles%\TortoiseGit" or "%ProgramFiles(x86)%\TortoiseGit".
  echo Install TortoiseGit or edit this script to point at TortoiseGitProc.exe
  exit /b 1
)
start "" "%TG%" /command:sync /path:"%~dp0."
