#!/bin/bash
REPO=/home/ptr1337/.docker/build/nginx/www/repo/x86_64/cachyos
rm -f $REPO/cachyos.*
repoctl reset -P cachyos

#!/bin/bash
REPO=/home/ptr1337/.docker/build/nginx/www/repo/x86_64_v3/cachyos-v3
rm -f $REPO/cachyos-v3.*
repoctl reset -P cachyos-v3
