#!/bin/sh
#gc.sh - run ecdump.

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
remove_if_nodiffs $*
