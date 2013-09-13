#!/bin/sh
#initialize p4 git-fusion repo

showenv()
{
    cat << EOF
    P4CLIENT=$P4CLIENT
    P4USER=$P4USER
    P4PORT=$P4PORT
EOF

}

if [ -z "$P4CLIENT" -o -z "$P4USER" -o -z "$P4PORT" ]; then
    echo One or more environment variables undefined:
    showenv
    exit 1
else
    showenv
fi

p4 client -i < $P4CLIENT.spec

rm -rf /tmp/ecscm-master
mkdir -p /tmp/ecscm-master
cd /tmp/ecscm-master
cat > README.txt << EOF
This is the SCM location for ecdumps.
EOF

p4 add README.txt
p4 submit -d "add README file"

echo $?
