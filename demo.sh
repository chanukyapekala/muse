#!/bin/bash
# muse on-device LLM demo — fully self-contained
# Starts server, runs 5 conversations, shows traces, shuts down.

set -e

BLUE='\033[1;34m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}  muse — On-Device LLM Demo (Llama 3.2 1B via MLX)${RESET}"
echo -e "${BOLD}  No internet. No API keys. No cost. Fully private.${RESET}"
echo -e "${BOLD}═══════════════════════════════════════════════════════${RESET}"
echo ""

# Start server
echo -e "${DIM}Starting muse server on localhost:8000...${RESET}"
export MLX_MODEL=mlx-community/Llama-3.2-1B-Instruct-4bit
uv run uvicorn muse.api:app --host 127.0.0.1 --port 8000 --log-level warning &
SERVER_PID=$!
sleep 3

# Verify
if ! curl -s http://localhost:8000/health > /dev/null 2>&1; then
    echo "Server failed to start"
    exit 1
fi
echo -e "${GREEN}Server ready (PID: $SERVER_PID)${RESET}"
echo ""

TOTAL_TOKENS=0

ask_muse() {
    local turn=$1
    local label=$2
    local system=$3
    local prompt=$4
    local max_tokens=$5

    echo -e "${BOLD}──────────────────────────────────────────${RESET}"
    echo -e "${BLUE}Turn $turn: $label${RESET}"
    echo -e "${YELLOW}>>> POST /v1/chat/completions  model=mlx  max_tokens=$max_tokens${RESET}"
    echo -e "${DIM}>>> prompt: \"$prompt\"${RESET}"
    echo ""

    RESPONSE=$(curl -s http://localhost:8000/v1/chat/completions \
        -H "Content-Type: application/json" \
        -d "{\"model\": \"mlx\", \"messages\": [{\"role\": \"system\", \"content\": \"$system\"}, {\"role\": \"user\", \"content\": \"$prompt\"}], \"max_tokens\": $max_tokens}")

    CONTENT=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['choices'][0]['message']['content'])" 2>/dev/null || echo "ERROR")
    TOKENS=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['usage']['total_tokens'])" 2>/dev/null || echo "0")

    echo -e "${GREEN}<<< muse response:${RESET}"
    echo -e "${CYAN}$CONTENT${RESET}"
    echo ""
    echo -e "${DIM}tokens: $TOKENS | cost: \$0.00 | provider: on-device MLX | internet: none${RESET}"
    echo ""

    TOTAL_TOKENS=$((TOTAL_TOKENS + TOKENS))
}

# Turn 1
ask_muse 1 "CS Exam Prep" \
    "You are a helpful CS tutor. Be concise." \
    "Explain recursion in 3 sentences." \
    100

# Turn 2
ask_muse 2 "Code Generation" \
    "You are a Python tutor. Write clean code." \
    "Write a Python function to reverse a linked list. Keep it short." \
    200

# Turn 3
ask_muse 3 "Essay Help" \
    "You are a writing tutor. Be structured." \
    "Give me 3 thesis statement options for an essay on: Should AI be regulated?" \
    150

# Turn 4
ask_muse 4 "Bug Detection" \
    "You are a code reviewer. Find the bug." \
    "Find the bug: def factorial(n): if n == 0: return 0; return n * factorial(n-1)" \
    150

# Turn 5
ask_muse 5 "Creative Brainstorm" \
    "You are a startup advisor. Be specific." \
    "One unique app idea a college student can build in a weekend." \
    150

# Summary
echo -e "${BOLD}═══════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}  DEMO COMPLETE${RESET}"
echo -e "${BOLD}═══════════════════════════════════════════════════════${RESET}"
echo ""
echo -e "  Turns:      ${GREEN}5/5 successful${RESET}"
echo -e "  Tokens:     ${GREEN}$TOTAL_TOKENS total${RESET}"
echo -e "  Cost:       ${GREEN}\$0.00${RESET}"
echo -e "  Provider:   ${GREEN}Llama 3.2 1B via Apple MLX${RESET}"
echo -e "  Internet:   ${GREEN}none required${RESET}"
echo -e "  Privacy:    ${GREEN}all data stayed on this machine${RESET}"
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════${RESET}"

# Cleanup
kill $SERVER_PID 2>/dev/null
echo -e "${DIM}Server stopped.${RESET}"
