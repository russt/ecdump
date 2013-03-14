#!/bin/sh
#runecdump.sh - wraper to run the daily dump

p=`basename $0`

#make sure PROJECT dir is in path:
PATH="${PROJECT}:$PATH"

yymmddhhmm=`date +%y%m%d%H%M`
#echo $yymmddhhmm

export ECDUMPROOT LOGROOT
ECDUMPROOT="$PROJECT/$yymmddhhmm"
LOGROOT="$PROJECT/logs"

logfile="$LOGROOT/$yymmddhhmm".log

mkdir -p "$LOGROOT"
echo logfile is $logfile

##### run the command:
2>&1 doecdump.sh > "$logfile"
exit $?
