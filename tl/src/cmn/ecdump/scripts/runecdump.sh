#!/bin/sh
#runecdump - wraper to run the periodic dump driven from build framework

p=`basename $0`

yymmddhhmm=`date +%y%m%d%H%M`
#echo $yymmddhhmm

export ECDUMPROOT LOGROOT BUILDTIME_LOG YYMMDDHHMM
YYMMDDHHMM=$yymmddhhmm
ECDUMPROOT=$PROJECT/$yymmddhhmm
LOGROOT=$PROJECT/logs/$yymmddhhmm
BUILDTIME_LOG=$LOGROOT/bldtime.log

logfile=$LOGROOT/ecdump.log

mkdir -p $LOGROOT
echo logfile is $logfile

##### run the command:
bldmsg -p $p -markbeg doecdump
doecdump > $logfile 2>&1 
status=$?
bldmsg -p $p -status $status -markend doecdump

cd $LOGROOT
showtimes

exit $status
