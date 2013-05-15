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

    have_diffs=0
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
        have_diffs=1
    fi

    return $_rind_status
}

do_ecsync()
{
    dumpdir="$1"
    cd $PROJECT

    bldmsg -p $p -markbeg ecsync.sh -push $dumpdir
    ecsync.sh -push $dumpdir
    if [ $? -ne 0 ]; then
        bldmsg -error -p $p -status $? FAILED: ecsync.sh -push $dumpdir
        bldmsg -p $p -markend -status 1 ecsync.sh -push $dumpdir
        return 1
    fi
    bldmsg -p $p -markend -status 0 ecsync.sh -push $dumpdir

    return 0
}

##################################### MAIN #####################################

p=`basename $0`
if [ "$ECDUMPROOT" = "" ]; then
    bldmsg -p $p -error please set ECDUMPROOT to the dump directory
    exit 1
fi
if [ "$LOGROOT" = "" ]; then
    bldmsg -p $p -error please set ECDUMPROOT to the dump directory
    exit 1
fi

if [ -z "$DO_EC_SCM_SYNC" ]; then
    DO_EC_SCM_SYNC=0
    bldmsg -p $p -warn defaulting DO_EC_SCM_SYNC=$DO_EC_SCM_SYNC
else
    bldmsg -p $p -mark NOTE: DO_EC_SCM_SYNC=$DO_EC_SCM_SYNC
fi

bldmsg -p $p Using `ecdump -V`
bldmsg -p $p ECDUMPROOT=$ECDUMPROOT
bldmsg -p $p ECDUMP_IGNORES=$ECDUMP_IGNORES

bldmsg -p $p -markbeg ecdump
#remove -indexsteps:  too many diffs.  RT 3/27/13
#ecdump -indexsteps -clean -verbose -props $PROJECT/.jdbc/commander-slave.props -dump "$ECDUMPROOT" -P "$PROJECT/bnrprojects2.txt"
ecdump -clean -verbose -props $PROJECT/.jdbc/commander-slave.props -dump "$ECDUMPROOT" -P "$PROJECT/bnrprojects2.txt"
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
LAST2RUNS=`\ls -1 | grep '^[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]$' | tail -2`
nfiles=`echo $LAST2RUNS | wc -w`

if [ $nfiles -eq 2 ]; then
    bldmsg -p $p -markbeg ddiff
    ddiff -fdiffonly $LAST2RUNS > $LOGROOT/ddiff.log 2>&1
    bldmsg -p $p -markend -status $? ddiff
else
    bldmsg -error -p $p wrong number of files to diff, file list= "'$LAST2RUNS'"
    exit 1
fi

have_diffs=0
remove_if_nodiffs $LAST2RUNS
if [ $? -ne 0 ]; then
    bldmsg -error -p $p -status $? FAILED: remove_if_nodiffs $LAST2RUNS
    exit 1
fi

#if we have diffs, then call ecsync.sh script to push the diffs to SCM:
if [ $DO_EC_SCM_SYNC -eq 1 -a $have_diffs -eq 1 ]; then
    do_ecsync $YYMMDDHHMM > $LOGROOT/ecsync.log 2>&1
    if [ $? -ne 0 ]; then
        bldmsg -error -p $p -status $? do_ecsync FAILED.
        exit 1
    fi
fi

exit 0
