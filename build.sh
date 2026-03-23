#!/bin/sh

# Parse arguments
FORCE_BUILD=0
for arg in "$@"; do
  case "$arg" in
    --force) FORCE_BUILD=1 ;;
  esac
done

# Use emacsclient to extract variables from your Emacs config
ORG_DIR=$(emacsclient -e "(expand-file-name org-directory)" | tr -d '"')
BIBLIOGRAPHY=$(emacsclient -e "(car org-cite-global-bibliography)" | tr -d '"')

# Export the variables to the environment
export ORG_DIR
export BIBLIOGRAPHY
export FORCE_BUILD

echo "Building site from $ORG_DIR"
if [ "$FORCE_BUILD" = "1" ]; then
  echo "Force rebuild requested, ignoring cache"
fi

emacs -Q --script build.el
