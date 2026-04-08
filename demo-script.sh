#!/usr/bin/env bash
# Simulated expert mode demo
clear

CYAN='\033[1;36m'
DIM='\033[2m'
BOLD='\033[1m'
GREEN='\033[1;32m'
RESET='\033[0m'

sleep 0.5

printf "${GREEN}/expert on${RESET}\n"
echo ""
sleep 0.3
echo "  Expert mode activated (auto)"
echo "  Profiles: trading · security · data-ml · systems · frontend · database · testing"
echo ""
sleep 1.5

echo "─────────────────────────────────────────────────────────────────"
echo ""
printf "${BOLD}You:${RESET} \"make it secure\"\n"
echo ""
sleep 0.6
printf "${CYAN}> Expert translation [security]:${RESET}\n"
echo "> Enumerate the attack surface using STRIDE. Check for: hardcoded"
echo "> secrets, missing input validation, auth flow gaps, overly broad"
echo "> permissions. Prioritize by severity and likelihood."
echo ""
sleep 2

echo "─────────────────────────────────────────────────────────────────"
echo ""
printf "${BOLD}You:${RESET} \"add a users table\"\n"
echo ""
sleep 0.6
printf "${CYAN}> Expert translation [database]:${RESET}\n"
echo "> UUID primary key, unique index on email, NOT NULL constraints,"
echo "> bcrypt password hash (never plaintext), migration must be"
echo "> reversible. What's the access pattern — read-heavy or write-heavy?"
echo ""
sleep 2

echo "─────────────────────────────────────────────────────────────────"
echo ""
printf "${BOLD}You:${RESET} \"show risk exposure on the dashboard\"\n"
echo ""
sleep 0.6
printf "${CYAN}> Expert translation [trading + frontend]:${RESET}\n"
echo "> Display a correlation matrix heatmap of active positions."
echo "> Diverging color palette (red=correlated, blue=negative)."
echo "> Flag pairs above r=0.7 as concentrated exposure risk."
echo ""
sleep 2

echo "─────────────────────────────────────────────────────────────────"
echo ""
printf "${BOLD}You:${RESET} \"read the main.py file\"\n"
echo ""
sleep 0.6
printf "${DIM}  (pass-through — no translation needed)${RESET}\n"
echo ""
sleep 2.5
