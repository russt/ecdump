#!/bin/sh

#wraper to run the daily dump

yymmddhhmm=`date +%y%m%d%H%M`

#echo $yymmddhhmm

ecroot="$PROJECT/$yymmddhhmm"
logroot="$PROJECT/logs"
logfile="$logroot/$yymmddhhmm".log

mkdir -p "$logroot"

echo dumping with ECDUMP_IGNORES=$ECDUMP_IGNORES
echo logfile is $logfile

bldmsg -markbeg ecdump > "$logfile"
ecdump -clean -verbose -props ~/.jdbc/commander-slave.props -dump "$ecroot" -P "$PROJECT/bnrprojects2.txt" >> "$logfile" 2>&1
status=$?
bldmsg -status $status -markend ecdump >> "$logfile"
