#!/bin/csh -f

# UGH - gotta pick some charater that doesn't appear in the file !!
# $'\n'

sort -k2 | sed \
    -e 's| ;| ;@|g' \
    -e 's|::|::@|' \
    -e 's|%%|	|g' \
| tr "@" "\n"
