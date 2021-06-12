#!/bin/csh -f
#---------------------------------------------------------------------------------------------
 #  Copyright © 2016-present Earth Computing Corporation. All rights reserved.
 #  Licensed under the MIT License. See LICENSE.txt in the project root for license information.
#---------------------------------------------------------------------------------------------

# UGH - gotta pick some charater that doesn't appear in the file !!
# $'\n'

sort -k2 | sed \
    -e 's| ;| ;@|g' \
    -e 's|::|::@|' \
    -e 's|%%|	|g' \
| tr "@" "\n"
