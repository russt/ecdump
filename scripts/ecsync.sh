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
 GIT_REMOTE_REPO_URL    The remote git-fusion repository we will sync to/from.
                        Current setting is $GIT_REMOTE_REPO_URL
 GIT_LOCAL_ROOT         Override where we locate the local git master repository directory.
                        Current setting is $GIT_LOCAL_ROOT
 LOCAL_GIT_MASTER_DIR   Local bare repository that we push to.
                        Current setting is $LOCAL_GIT_MASTER_DIR
 LOCAL_GIT_MASTER_URL   Local bare repository that we push to.
                        Current setting is $LOCAL_GIT_MASTER_URL
 LOCAL_GIT_WORKING_DIR  Local git working directory.  Must be on same filesystem as dump directories.
                        Current setting is $LOCAL_GIT_WORKING_DIR

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
    [ -z "$GIT_LOCAL_ROOT" ] && GIT_LOCAL_ROOT=/bld/ecdump
    [ -z "$GIT_REMOTE_REPO_URL" ] && GIT_REMOTE_REPO_URL=git@ecdump.gitconfusion:ecscm-master
    [ -z "$LOCAL_GIT_MASTER_DIR" ] && LOCAL_GIT_MASTER_DIR=$GIT_LOCAL_ROOT/ecscm-master.git
    [ -z "$LOCAL_GIT_MASTER_URL" ] && LOCAL_GIT_MASTER_URL=file://$LOCAL_GIT_MASTER_DIR
    #this has to be on same filesystem as we are moving .git dir back & forth.
    #Q:  can it be a symlink?
    [ -z "$LOCAL_GIT_WORKING_DIR" ] && LOCAL_GIT_WORKING_DIR=$BASEDIR/ecscm-work
    set +a

    mkdir -p "$GIT_LOCAL_ROOT"

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
        bldmsg -markbeg -p $p git clone --bare "$GIT_REMOTE_REPO_URL" "$LOCAL_GIT_MASTER_DIR"
        git clone --bare "$GIT_REMOTE_REPO_URL" "$LOCAL_GIT_MASTER_DIR"
        if [ $? -ne 0 ]; then
            bldmsg -error -p $p -status $? FAILED: git clone --bare "$GIT_REMOTE_REPO_URL" "$LOCAL_GIT_MASTER_DIR"
            bldmsg -markend -p $p -status 1 git clone --bare "$GIT_REMOTE_REPO_URL" "$LOCAL_GIT_MASTER_DIR"
            return 1
        fi
        bldmsg -markend -p $p -status 0 git clone --bare "$GIT_REMOTE_REPO_URL" "$LOCAL_GIT_MASTER_DIR"
    fi

    #note - fetch is a no-op if we just cloned, but do it anyway to verify the config.
    bldmsg -markbeg -p $p git fetch in $LOCAL_GIT_MASTER_DIR
    cd "$LOCAL_GIT_MASTER_DIR"
    git fetch
    if [ $? -ne 0 ]; then
        bldmsg -error -p $p -status $? FAILED in "'$LOCAL_GIT_MASTER_DIR'": git fetch
        bldmsg -markend -p $p -status 1 git fetch in $LOCAL_GIT_MASTER_DIR
        return 1
    fi
    bldmsg -markend -p $p -status 0 git fetch in $LOCAL_GIT_MASTER_DIR

    return 0
}

create_local_git_working()
#create the local git working directory, and make sure it is up-to-date with local master.
{
    cd "$BASEDIR"

    if [ $DOCLEAN -eq 1 ]; then
        bldmsg -markbeg -p $p removing "$LOCAL_GIT_WORKING_DIR"
        rm -rf "$LOCAL_GIT_WORKING_DIR"
        bldmsg -markend -p $p -status $? removing "$LOCAL_GIT_WORKING_DIR"
    fi

    if [ -d "$LOCAL_GIT_WORKING_DIR" ]; then
        cd "$LOCAL_GIT_WORKING_DIR"
        bldmsg -markbeg -p $p git pull in $LOCAL_GIT_WORKING_DIR
        git pull
        if [ $? -ne 0 ]; then
            bldmsg -error -p $p -status $? FAILED: git pull in "'$LOCAL_GIT_WORKING_DIR'"
            bldmsg -markend -p $p -status 1 git pull in $LOCAL_GIT_WORKING_DIR
            return 1
        fi
        bldmsg -markend -p $p -status 0 git pull in $LOCAL_GIT_WORKING_DIR
    else
        bldmsg -markbeg -p $p git clone -b master "$LOCAL_GIT_MASTER_URL" "$LOCAL_GIT_WORKING_DIR"
        git clone -b master "$LOCAL_GIT_MASTER_URL" "$LOCAL_GIT_WORKING_DIR"
        if [ $? -ne 0 ]; then
            bldmsg -error -p $p -status $? FAILED: git clone "$LOCAL_GIT_MASTER_URL" "$LOCAL_GIT_WORKING_DIR"
            bldmsg -markend -p $p -status 1 git clone "$LOCAL_GIT_MASTER_URL" "$LOCAL_GIT_WORKING_DIR"
            return 1
        fi
        bldmsg -markend -p $p -status 0 git clone "$LOCAL_GIT_MASTER_URL" "$LOCAL_GIT_WORKING_DIR"
    fi

    return 0
}

process_ecdump_list()
#process each directory in ecdump list
{
    cd "$BASEDIR"

    set $ECDUMP_LIST
    while [ $# -gt 0 ]
    do
        theDumpDir=$1; shift
        process_one_dumpdir "$theDumpDir"
        if [ $? -ne 0 ]; then
            bldmsg -error -p $p -status $? failed to process dump directory: "'$theDumpDir'"
            return 1
        fi
        if [ $DOREMOTEPUSH -eq 1 ]; then
            do_remote_push
            if [ $? -ne 0 ]; then
                bldmsg -error -p $p -status $? failed to push changes for $theDumpDir to remote master.
                return 1
            fi
        fi

    done
    return 0
}

process_one_dumpdir()
#process a single ecdump directory.
#add all files to working dir and commit to local master.
#do not push to git fusion yet - that is handled separately.
{
    ecdumpdir="$1"
    cd "$BASEDIR"

    bldmsg -mark Processing ecdump directory $ecdumpdir

    if [ ! -d "$ecdumpdir" ]; then
        bldmsg -p $p -error Not a directory, "'$ecdumpdir'" - skipped.
        return 1
    fi

    cd "$ecdumpdir"
    if [ -d .git ]; then
        bldmsg -warn -p $p cleaning up local .git directory from previous run in `pwd`
        rm -rf .git
    fi

    if [ ! -d "$LOCAL_GIT_WORKING_DIR" ]; then
        bldmsg -error -p $p -status 1 cannot proceed - $LOCAL_GIT_WORKING_DIR does not exist!
        return 1
    fi

    mv "$LOCAL_GIT_WORKING_DIR/.git" .
    if [ $? -ne 0 ]; then
        bldmsg -error -p $p -status $? FAILED: cannot move $LOCAL_GIT_WORKING_DIR/.git to `pwd`
        return 1
    fi

    bldmsg -markbeg -p $p git add --all in $ecdumpdir
    git add --all
    if [ $? -ne 0 ]; then
        bldmsg -error -p $p -status $? FAILED in "'$ecdumpdir'": git add --all
        bldmsg -markend -p $p -status 1 git add --all in $ecdumpdir

        #attempt to reset git to previous state - but we are probably screwed at this point:
        bldmsg -mark git reset --hard in $ecdumpdir
        git reset --hard

        #move .git dir back:
        mv .git "$LOCAL_GIT_WORKING_DIR"

        return 1
    fi
    bldmsg -markend -p $p -status 0 git add --all in $ecdumpdir

    #note - adding in a status here as we are getting an occasional commit error
    #that seems to be repaired by git status.  RT 5/13/13

    bldmsg -markbeg -p $p git status --short in $ecdumpdir
    git status --short
    if [ $? -ne 0 ]; then
        bldmsg -warn -p $p -status $? FAILED in "'$ecdumpdir'": git status --short - ignoring errors
        bldmsg -markend -p $p -status 1 git status --short in $ecdumpdir
    fi
    bldmsg -markend -p $p -status 0 git status --short in $ecdumpdir

    #git add was a success - commit:
    bldmsg -markbeg -p $p git commit in $ecdumpdir
    git commit -m "ecdump $ecdumpdir"
    if [ $? -ne 0 ]; then
        bldmsg -error -p $p -status $? FAILED in "'$ecdumpdir'": git commit -m "'ecdump $ecdumpdir'"
        bldmsg -markend -p $p -status 1 git commit in $ecdumpdir

        #move .git dir back:
        mv .git "$LOCAL_GIT_WORKING_DIR"
        return 1
    fi
    bldmsg -markend -p $p -status 0 git commit in $ecdumpdir

    bldmsg -markbeg -p $p git push in $ecdumpdir
    git push
    if [ $? -ne 0 ]; then
        bldmsg -error -p $p -status $? FAILED in "'$ecdumpdir'": git push
        bldmsg -markbeg -p $p -status 1 git push in $ecdumpdir

        #move .git dir back:
        mv .git $LOCAL_GIT_WORKING_DIR
        return 1
    fi
    bldmsg -markend -p $p -status 0 git push in $ecdumpdir

    #SUCCESS! park .git back to working dir:
    mv .git "$LOCAL_GIT_WORKING_DIR"

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

process_ecdump_list
if [ $? -ne 0 ]; then
    bldmsg -error -p $p -status $? failed to process one or more directories in list: $ECDUMP_LIST
    exit 1
fi

exit 0
