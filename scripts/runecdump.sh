#!/bin/sh
#runecdump.sh - wraper to run the daily dump

p=`basename $0`

yymmddhhmm=`date +%y%m%d%H%M`
#echo $yymmddhhmm

export ECDUMPROOT LOGROOT BUILDTIME_LOG
ECDUMPROOT=$PROJECT/$yymmddhhmm
LOGROOT=$PROJECT/logs/$yymmddhhmm
BUILDTIME_LOG=$LOGROOT/bldtime.log

logfile=$LOGROOT/ecdump.log

mkdir -p $LOGROOT
echo logfile is $logfile

##### run the command:
bldmsg -p $p -markbeg doecdump
doecdump.sh > $logfile 2>&1 
status=$?
bldmsg -p $p -status $status -markend doecdump

cd $LOGROOT
showtimes

exit $status
