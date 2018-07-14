#!/bin/csh -f
exec /usr/bin/openssl dgst -sha1 $*:q | sed -e 's|^SHA1(\(.*\))= \(.*\)$|\2 \1|'
