#!/bin/bash

# This script is called from Makefile on "make setup-ace"

ACE_DIR=~/go/src/github.com/bhmj/ace-builds

git clone https://github.com/bhmj/ace-builds.git $ACE_DIR
git -C $ACE_DIR/ pull
rm -r www/js/ace/
mkdir -p www/js/ace/src-noconflict/
cp -a $ACE_DIR/src-noconflict/. www/js/ace/src-noconflict/
