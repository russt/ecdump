#!/bin/sh
#initialize p4 git-fusion repo

P4CLIENT="ecscm-master"
P4USER="ecdump"
P4PORT="gitconfusion:1666"
GITURL="git@ecdump.gitconfusion"
GITREPO="${GITURL}:${P4CLIENT}"

p4 client -i < $P4CLIENT.spec

rm -rf /tmp/ecscm-master
mkdir -p /tmp/ecscm-master
cd /tmp/ecscm-master
cat > README.txt << EOF
This is the SCM location for ecdumps.
EOF

p4 add README.txt
p4 submit -d "add README file"
