#!/bin/sh

rm -f doctabs.zip &&
    find . \( -path '*.git' -o -path '*/tags' -o -path '*/zip.sh' \) -prune -o -type f -print |
    zip -@ doctabs.zip
