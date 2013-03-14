#!/bin/sh
#doecdump.sh - run ecdump.

p=`basename $0`
if [ "$ECDUMPROOT" = "" ]; then
    bldmsg -p $p -error please set ECDUMPROOT to the dump directory
    exit 1
fi

bldmsg -p $p ECDUMPROOT=$ECDUMPROOT
bldmsg -p $p ECDUMP_IGNORES=$ECDUMP_IGNORES

p=`basename $0`
bldmsg -p $p -markbeg ecdump
ecdump -clean -verbose -props $HOME/.jdbc/commander-slave.props -dump "$ECDUMPROOT" -P "$PROJECT/bnrprojects2.txt"
status=$?
bldmsg -p $p -status $status -markend ecdump

if [ $status -ne  0 ]; then
    bldmsg -p $p -error -status $status ecdump FAILED.
    exit 1
fi

######
#ddiff latest 2 runs
######

#find the last 2 dumps:
LAST2RUNS=`\ls -1 | grep -v '[^0-9]' | tail -2`
nfiles=`echo $LAST2RUNS | wc -w`

if [ $nfiles -eq 2 ]; then
    bldmsg -p $p -markbeg ddiff
    ddiff -fdiffonly $LAST2RUNS
    bldmsg -p $p -markend -status $? ddiff
else
    bldmsg -error -p $0 wrong number of files to diff, file list= "'$LAST2RUNS'"
    exit 1
fi

exit 0
