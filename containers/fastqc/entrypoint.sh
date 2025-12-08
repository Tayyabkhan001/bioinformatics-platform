#!/bin/bash
set -e  # Exit on any error

echo "🚀 Container started - Available tools:"
echo "🐍 Python: $(python3 --version)"
echo "🔧 AWS CLI: $(aws --version 2>/dev/null || echo 'not available')"
echo "🧪 FastQC: $(fastqc --version || echo 'not available')"
echo "☕ Java: $(java -version 2>&1 | head -1)"

# If no command provided, show help
if [ "$#" -eq 0 ]; then
    echo "Usage: This container supports FastQC analysis"
    echo "Commands will be executed as provided"
    exit 0
fi

# Execute the command
echo "🔧 Executing: $@"
exec "$@"
