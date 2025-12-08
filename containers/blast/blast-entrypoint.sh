#!/bin/bash
set -e

echo "🚀 BLAST Container started - Available tools:"
echo "🧬 BLAST: $(blastn -version | head -1)"
echo "🐍 Python: $(python3 --version)"
echo "🔧 AWS CLI: $(aws --version 2>/dev/null || echo 'not available')"

# If no command provided, show BLAST help
if [ "$#" -eq 0 ]; then
    echo "Usage: This container supports BLAST analysis"
    echo "Example: blastn -help"
    blastn -help
    exit 0
fi

# Execute the command
echo "🔧 Executing: $@"
exec "$@"
