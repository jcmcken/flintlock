#!/bin/bash

COMPLETER="bash -c 'scl enable ruby193 flintlock-completer'"

complete -o default -C "$COMPLETER" flintlock
