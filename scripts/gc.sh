#!/bin/sh
#gc.sh - run ecdump.

remove_if_nodiffs()
#Usage:  remove_if_nodiffs lastdumpdir newdumpdir
{
    #see if we can delete the previous dump.  we are looking for a ddiff file that
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

    if [ "$nullcnt" -eq 3 ]; then
        bldmsg -p $p -mark New run has no changes, removing identical new dump: $newrun
        bldmsg -p $p -markbeg remove identical dump
        rm -rf "$newrun"
        status=$?
        bldmsg -p $p -status $status -markbeg remove identical dump
        if [ $status -ne  0 ]; then
            bldmsg -p $p -error -status $status command failed:  rm -rf "$newrun"
            exit 1
        fi
    else
        bldmsg -p $p -mark New run has changes - see logs/$newrun/ddiff.log for differences
    fi
}

p=`basename $0`
remove_if_nodiffs $*
