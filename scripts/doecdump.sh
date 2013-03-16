#!/bin/sh
#doecdump.sh - run ecdump.

remove_if_nodiffs()
#Usage:  remove_if_nodiffs lastdumpdir newdumpdir
{
    #see if we can delete the new dump.  we are looking for a ddiff file that
    #looks like this:
    #+-----------------------------------------------------------------+
    #|### In 1303151230 but not in 1303151330:                         |
    #|    NULL                                                         |
    #|### In 1303151330 but not in 1303151230:                         |
    #|    NULL                                                         |
    #|### In both 1303151230 and 1303151330:, with different content:  |
    #|    NULL                                                         |
    #+-----------------------------------------------------------------+

    #get last, curr run dirs:
    lastrun="$1"
    newrun="$2"

    echo remove_if_nodiffs: lastrun=$lastrun newrun=$newrun

    #note - first char is actually a tab, but grep does not allow \t.  RT 3/15/13
    nullcnt=`grep '^.NULL$' logs/$newrun/ddiff.log | wc -w`
    _rind_status=0

    if [ "$nullcnt" -eq 3 ]; then
        bldmsg -p $p -mark New run has no changes, removing it: $newrun
        bldmsg -p $p -markbeg remove identical dump
        rm -rf "$newrun"
        _rind_status=$?
        bldmsg -p $p -status $_rind_status -markend remove identical dump
        if [ $_rind_status -ne  0 ]; then
            bldmsg -p $p -error -status $_rind_status command failed:  rm -rf "$newrun"
        fi
    else
        bldmsg -p $p -mark New run has changes - see logs/$newrun/ddiff.log for differences
    fi

    return $_rind_status
}

p=`basename $0`
if [ "$ECDUMPROOT" = "" ]; then
    bldmsg -p $p -error please set ECDUMPROOT to the dump directory
    exit 1
fi
if [ "$LOGROOT" = "" ]; then
    bldmsg -p $p -error please set ECDUMPROOT to the dump directory
    exit 1
fi

bldmsg -p $p Using `ecdump -V`
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
# yymmddhhmm
#                             yy        mm        dd        hh        mm
LAST2RUNS=`\ls -1 | grep '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]' | tail -2`
nfiles=`echo $LAST2RUNS | wc -w`

if [ $nfiles -eq 2 ]; then
    bldmsg -p $p -markbeg ddiff
    ddiff -fdiffonly $LAST2RUNS > $LOGROOT/ddiff.log 2>&1
    bldmsg -p $p -markend -status $? ddiff
else
    bldmsg -error -p $0 wrong number of files to diff, file list= "'$LAST2RUNS'"
    exit 1
fi

remove_if_nodiffs $LAST2RUNS
exit $?
