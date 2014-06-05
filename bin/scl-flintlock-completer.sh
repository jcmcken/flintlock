#!/bin/bash

completer=$(scl enable ruby193 "which flintlock-completer")

complete -o default -C $completer flintlock
