#!/bin/bash

# CodeQuery wrapper script - automatically activates venv and runs cq
# This allows users to run 'cq' without worrying about venv activation

CQ_VENV="/opt/codequery/venv"
CQ_PYTHON="$CQ_VENV/bin/python"
CQ_COMMAND="$CQ_VENV/bin/cq"

# Source .env if it exists in the current directory
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs -0)
fi

# If still no OPENAI_API_KEY, try home directory .env
if [ -z "$OPENAI_API_KEY" ] && [ -f "$HOME/.env" ]; then
    export $(grep -v '^#' "$HOME/.env" | grep "OPENAI_API_KEY" | xargs -0)
fi

# Check if OPENAI_API_KEY is set
if [ -z "$OPENAI_API_KEY" ]; then
    echo "Warning: OPENAI_API_KEY environment variable is not set."
    echo "CodeQuery requires an OpenAI API key to function properly."
    echo ""
    echo "To set it temporarily for this session:"
    echo "  export OPENAI_API_KEY='your-api-key-here'"
    echo ""
    echo "To set it permanently for this project, add it to a .env file:"
    echo "  echo \"OPENAI_API_KEY=your-api-key-here\" >> .env"
    echo ""
fi

# Execute cq with all arguments passed through
exec "$CQ_COMMAND" "$@"