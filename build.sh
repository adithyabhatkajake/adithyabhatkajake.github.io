#!/bin/sh

# Use emacsclient to extract variables from your Emacs config
ORG_DIR=$(emacsclient -e "(expand-file-name org-directory)" | tr -d '"')
BIBLIOGRAPHY=$(emacsclient -e "(car org-cite-global-bibliography)" | tr -d '"')

# Export the variables to the environment
export ORG_DIR
export BIBLIOGRAPHY

echo "Building site for $BLOG_TITLE from $ORG_DIR"

emacs -Q --script build.el
