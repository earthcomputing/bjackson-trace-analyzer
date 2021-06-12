#!/bin/csh -f
#---------------------------------------------------------------------------------------------
 #  Copyright © 2016-present Earth Computing Corporation. All rights reserved.
 #  Licensed under the MIT License. See LICENSE.txt in the project root for license information.
#---------------------------------------------------------------------------------------------
exec /usr/bin/openssl dgst -sha1 $*:q | sed -e 's|^SHA1(\(.*\))= \(.*\)$|\2 \1|'
