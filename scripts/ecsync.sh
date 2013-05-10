#!/bin/sh
#
# Usage:  ecsync dumpdirs ...
#

################################ USAGE ROUTINES ################################

usage()
{
    status=$1

#-verbose        Turn on verbose messages.
#-test           Run all scripts in non-destructive test mode.

    cat << EOF

Usage:  $p [options...] ecdumpdir ...

 Sync a list of time-stamped ecdump trees with the source management system.
 Directories are processed in the order given.

Options:
 -help           Display this message.
 -clean          Start with new local git master and working directories.
 -push           If all processing is successful, push commits from
                 local master to remote master.

Environment:
 LOGDIR          Where to put all log files.

Example:
 $p -clean 1303271430 1303271600 1305031242

EOF

    exit $status
}

parse_args()
{
    DEBUG=0
    VERBOSE=0
    DOCLEAN=0
    DOREMOTEPUSH=0
    TESTMODE=0
    ECDUMP_LIST=

    while [ $# -gt 0 -a "$1" != "" ]
    do
        arg=$1; shift

        case $arg in
        -h* )
            usage 0
            ;;
        -debug )
            DEBUG=1
            ;;
        -t* )
            TESTMODE=1
            ;;
        -push )
            DOREMOTEPUSH=1
            ;;
        -clean )
            DOCLEAN=1
            ;;
        -* )
            echo "${p}: unknown option, $arg"
            usage 1
            ;;
        * )
            #add to dump list:
            ECDUMP_LIST="$ECDUMP_LIST $arg"
            ;;
        esac
    done

    return 0
}

check_setup()
# check the set-up
{
    if [ -z "$ECDUMP_LIST" ]; then
        bldmsg -p $p -error you must specify at least one dump directory.
        return 1
    fi

    return 0
}

set_global_vars()
{
    p=`basename $0`
    TMPA=/tmp/${p}A.$$

    #keep track of the directory where we were run in:
    BASEDIR=`pwd`

    set -a
    #export vars..
    LOGDIR=$BASEDIR
    GIT_REMOTE_REPO_URL=git@ecdump.gitconfusion:ecscm-master
    LOCAL_GIT_MASTER_DIR=$BASEDIR/ecscm-master.git
    LOCAL_GIT_MASTER_URL=file://$BASEDIR/ecscm-master.git
    LOCAL_GIT_WORKING_DIR=$BASEDIR/ecscm-work
    GIT_PROCESSING_LOG=$LOGDIR/${p}_git.log
    set +a

    return 0
}

create_local_git_master()
#clone or update the bare git repos that will be our local master repository.
#
{
    cd "$BASEDIR"

    if [ $DOCLEAN -eq 1 ]; then
        rm -rf "$LOCAL_GIT_MASTER_DIR"
    fi

    if [ ! -d "$LOCAL_GIT_MASTER_DIR" ]; then
        git clone --bare "$GIT_REMOTE_REPO_URL" "$LOCAL_GIT_MASTER_DIR"
        if [ $? -ne 0 ]; then
            bldmsg -error -p $p -status $? FAILED: git clone --bare "$GIT_REMOTE_REPO_URL" "$LOCAL_GIT_MASTER_DIR"
            return 1
        fi
    fi

    #note - fetch is a no-op if we just cloned, but do it anyway to verify the config.
    cd "$LOCAL_GIT_MASTER_DIR"
    git fetch
    if [ $? -ne 0 ]; then
        bldmsg -error -p $p -status $? FAILED in "'$LOCAL_GIT_MASTER_DIR'": git fetch
        return 1
    fi

    return 0
}

create_local_git_working()
#create the local git working directory, and make sure it is up-to-date with local master.
{
    cd "$BASEDIR"

    if [ $DOCLEAN -eq 1 ]; then
        rm -rf "$LOCAL_GIT_WORKING_DIR"
    fi

    if [ -d "$LOCAL_GIT_WORKING_DIR" ]; then
        cd "$LOCAL_GIT_WORKING_DIR"
        git pull
        if [ $? -ne 0 ]; then
            bldmsg -error -p $p -status $? FAILED: git pull in "'$LOCAL_GIT_WORKING_DIR'"
            return 1
        fi
    else
        git clone "$LOCAL_GIT_MASTER_URL" "$LOCAL_GIT_WORKING_DIR"
        if [ $? -ne 0 ]; then
            bldmsg -error -p $p -status $? FAILED: git clone "$LOCAL_GIT_MASTER_URL" "$LOCAL_GIT_WORKING_DIR"
            return 1
        fi

        cd "$LOCAL_GIT_WORKING_DIR"
    fi

    return 0
}

process_ecdump_list()
#process each directory in ecdump list
{
    set $ECDUMP_LIST
    while [ $# -gt 0 ]
    do
        cd "$BASEDIR"
        theDumpDir=$1; shift
        process_one_dumpdir "$theDumpDir"
        if [ $? -ne 0 ]; then
            bldmsg -error -p $p -status $? failed to process dump directory: "'$theDumpDir'"
            return 1
        fi
    done
    return 0
}

process_one_dumpdir()
#process a single ecdump directory.
#add all files to working dir and commit to local master.
#do not push to git fusion yet - that is handled separately.
{
    bldmsg -mark Processing ecdump directory $1

    if [ ! -d "$1" ]; then
        bldmsg -p $p -error Not a directory, "'$1'" - skipped.
        return 1
    fi

    cd "$1"

    bldmsg -mark git add --all in $1
    #mv .git from working dir to here:
    mv $LOCAL_GIT_WORKING_DIR/.git .
    git add --all
    if [ $? -ne 0 ]; then
        bldmsg -error -p $p -status $? FAILED in "'$1'": git add --all

        #attempt to reset git to previous state - but we are probably screwed at this point:
        bldmsg -mark git reset --hard in $1
        git reset --hard

        #move .git dir back:
        mv .git $LOCAL_GIT_WORKING_DIR

        return 1
    fi

    #otherwise, git add was a success - commit:

    bldmsg -mark git commit in $1
    git commit -m "ecdump $1"
    if [ $? -ne 0 ]; then
        bldmsg -error -p $p -status $? FAILED in "'$1'": git commit -m "'ecdump $1'"

        #move .git dir back:
        mv .git $LOCAL_GIT_WORKING_DIR
        return 1
    fi

    bldmsg -mark git push in $1
    git push
    if [ $? -ne 0 ]; then
        bldmsg -error -p $p -status $? FAILED in "'$1'": git push

        #move .git dir back:
        mv .git $LOCAL_GIT_WORKING_DIR
        return 1
    fi


    #SUCCESS! park .git in working dir:
    mv .git $LOCAL_GIT_WORKING_DIR

    return 0
}

do_remote_push()
{
    bldmsg -markbeg -p $p "git push local master -> remote master"

    cd "$BASEDIR"
    cd "$LOCAL_GIT_MASTER_DIR"

    git push
    if [ $? -ne 0 ]; then
        bldmsg -error -p $p -status $? FAILED in "'$LOCAL_GIT_MASTER_DIR'": git push
        bldmsg -markend -p $p -status 1 "git push local master -> remote master"
        return 1
    fi

    bldmsg -markend -p $p -status 0 "git push local master -> remote master"
    return 0
}
##################################### MAIN #####################################

set_global_vars

parse_args "$@"
if [ $? -ne 0 ]; then
    bldmsg -error -p $p -status $? failed to parse arguments
    usage 1
fi

#check environment and other settings:
check_setup
if [ $? -ne 0 ]; then
    bldmsg -error -p $p -status $? missing one or more required definitions - abort
    exit 1
fi

create_local_git_master
if [ $? -ne 0 ]; then
    bldmsg -error -p $p -status $? failed to create local git master repository.
    exit 1
fi

create_local_git_working
if [ $? -ne 0 ]; then
    bldmsg -error -p $p -status $? failed to create local git working repository.
    exit 1
fi

process_ecdump_list > $GIT_PROCESSING_LOG 2>&1
if [ $? -ne 0 ]; then
    bldmsg -error -p $p -status $? failed to process one or more directories in list: $ECDUMP_LIST
    bldmsg -error -p $p see $GIT_PROCESSING_LOG for details
    exit 1
fi

if [ $DOREMOTEPUSH -eq 1 ]; then
    do_remote_push
    if [ $? -ne 0 ]; then
        bldmsg -error -p $p -status $? failed to push changes to remote master.
        exit 1
    fi
fi

exit 0
