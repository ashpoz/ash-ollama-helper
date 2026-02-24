#!/bin/zsh
# Interactive Ollama prompt script with fzf, error handling, logging, and temperature control

# --- Configuration ---
OLLAMA_TEMPERATURE="${OLLAMA_TEMPERATURE:-0.2}"       # Default temperature (low for coding)
LOG_DIR="${OLLAMA_LOG_DIR:-$HOME/.ollama_logs}"       # Default log directory
LOG_FILE="$LOG_DIR/$(date +%Y-%m-%d).log"            # One log file per day
TMPRESPONSE=$(mktemp)                                 # Temp file for streaming response

# --- Trap to clean up on exit, interrupt, or error ---
trap 'stty sane 2>/dev/null; rm -f "$TMPRESPONSE"' EXIT INT TERM

# --- Dependency checks ---
require() {
    local cmd="$1"
    local install_hint="$2"
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: '$cmd' is not installed."
        echo "Install with: $install_hint"
        exit 1
    fi
}

require ollama "curl -fsSL https://ollama.com/install.sh | sh"
require fzf    "sudo apt install fzf   or   brew install fzf"

if ! ollama list &> /dev/null; then
    echo "Error: ollama is not running. Start it with: ollama serve"
    exit 1
fi

# --- Logging setup ---
mkdir -p "$LOG_DIR" || { echo "Error: could not create log directory at $LOG_DIR"; exit 1; }

log() {
    local section="$1"
    local content="$2"
    {
        echo "=== $section === $(date '+%Y-%m-%d %H:%M:%S')"
        echo "$content"
        echo ""
    } >> "$LOG_FILE"
}

# --- Step 1: Select model interactively ---
echo "Available Ollama models:"
MODEL=$(ollama list | awk 'NR>1 {print $1}' | fzf --prompt="Select model: " --height=40% --reverse)
MODEL="${MODEL:-mistral:latest}"

# Verify the selected model exists
if ! ollama list | awk 'NR>1 {print $1}' | grep -q "^$MODEL$"; then
    echo "Error: model '$MODEL' not found. Run 'ollama pull $MODEL' to download it."
    exit 1
fi

# --- Step 2: Select context file interactively ---
CONTEXT_FILE=""
CONTEXT_DIR="${OLLAMA_CONTEXT_DIR:-$HOME/.ollama_contexts}"
if [ -d "$CONTEXT_DIR" ]; then
    echo "Available context files in $CONTEXT_DIR:"
    CONTEXT_FILE=$(find "$CONTEXT_DIR" -type f | fzf --prompt="Select context file (or ESC to skip): " --height=40% --reverse --preview="cat {}")
    if [ -n "$CONTEXT_FILE" ]; then
        echo "Using context: $CONTEXT_FILE"
    fi
else
    echo "No context directory found at $CONTEXT_DIR. Skipping context."
fi

# --- Step 3: Enter prompt ---
echo "Enter your prompt (press Ctrl+D to finish):"
stty erase '^?' 2>/dev/null
PROMPT=$(cat)
stty sane 2>/dev/null

if [ -z "$PROMPT" ]; then
    echo "Error: prompt cannot be empty."
    exit 1
fi

# --- Combine context and prompt ---
if [ -n "$CONTEXT_FILE" ]; then
    CONTEXT=$(cat "$CONTEXT_FILE")
    FULL_PROMPT="Context:\n$CONTEXT\n\nPrompt:\n$PROMPT"
else
    FULL_PROMPT="$PROMPT"
fi

# --- Log the request ---
log "MODEL" "$MODEL"
log "TEMPERATURE" "$OLLAMA_TEMPERATURE"
log "PROMPT" "$PROMPT"
[ -n "$CONTEXT_FILE" ] && log "CONTEXT FILE" "$CONTEXT_FILE"

# --- Call Ollama, stream output, and capture for logging ---
echo -e "\n\033[1;34m=== Ollama ($MODEL) [temp: $OLLAMA_TEMPERATURE] ===\033[0m"
echo -e "/set parameter temperature $OLLAMA_TEMPERATURE\n$FULL_PROMPT" | \
    ollama run "$MODEL" | \
    tee "$TMPRESPONSE" | \
awk '
/```/ {
    in_code_block = !in_code_block
    if (in_code_block) {
        lang = substr($0, 4)
        printf "\033[1;35m┌─── %s ───\033[0m\n", (lang != "" ? lang : "code")
    } else {
        printf "\033[1;35m└────────────\033[0m\n"
        printf "\033[0m"
    }
    next
}
{
    if (in_code_block)
        print "\033[48;5;235m\033[38;5;226m" $0 "\033[0m"
    else
        print "\033[36m" $0 "\033[0m"
}
'
# --- Log the response after streaming completes ---
RESPONSE=$(cat "$TMPRESPONSE")

if [ -z "$RESPONSE" ]; then
    echo "Error: no response received from ollama."
    exit 1
fi

log "RESPONSE" "$RESPONSE"
echo -e "\033[1;90mLogged to: $LOG_FILE\033[0m"
