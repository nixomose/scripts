#!/bin/bash

# this is run out of /etc/crontab every minute
# if there is terminal that is not idle or X is not idle
# take a btrfs snapshot of /home into /home/snaps/home_<date>

PROG=`basename $0`
echo $PROG

WHOAMI=`whoami`
if [ "$WHOAMI" != "root" ]; 
then echo "you must be root.";
exit;
fi

reason=`cat /var/lock/mylockreason$PROG`
msg=`mkdir /var/lock/mylock$PROG 2>&1`
if [ "$?" != "0" ]  ; then

  echo "couldn't lock /var/lock/mylock$PROG. waiting 30 minutes to send an email, waiting for delta=900"
  # don't generate output and thus an email more than once every 30 minutes
  last=`cat /var/lock/mylocktimer$PROG` 2>/dev/null
  if [ -z "$last" ]; then
    last="0";
  fi
echo "last=   " $last  
  now=`date +%s`
echo "now=    " $now
  delta=`echo $(( $now - $last ))` # this is 30 minutes
echo "delta = " $delta
  if [ "$delta" -gt 900 ]; then # 15 minutes
    echo "Subject: $PROG lock failed. $msg last=$last now=$now delta=$delta reason=$reason" | sendmail nixo@exprodigy.net
    # reset timer
    echo `date +%s` > /var/lock/mylocktimer$PROG 2>&1
  fi
  exit 1
fi

# reset timer
echo `date +%s` > /var/lock/mylocktimer$PROG 2>&1

dobackup=0

w | awk '{print $5}' | grep "s$" | grep -v days >/dev/null
if [ "$?" == "0" ]; then
  dobackup=1;
  echo "taking snapshot because of non idle terminal `date +%Y%m%d_%H%M`" | tee /var/lock/mylockreason$PROG
fi

x=`sudo -u nixo bash -c "export DISPLAY=:0.0 && export XAUTHORITY=/home/nixo/.Xauthority && xprintidle"`
y=$(( $x / 1000 ))
if [ "$y" -lt "60" ]; then 
  dobackup=1;
  echo "taking snapshot because of non idle X on main display `date +%Y%m%d_%H%M`"  | tee /var/lock/mylockreason$PROG
fi
 
# check plan9 if it's there
x=`sudo -u nixo bash -c "export DISPLAY=:9.0 && export XAUTHORITY=/home/nixo/.Xauthority && xprintidle"`
result=$?
echo "result $result"
if [ "$result" == "0" ]; then
  y=$(( $x / 1000 ))
  if [ "$y" -lt "60" ]; then 
    dobackup=1;
    echo "taking snapshot because of non idle X on plan9 `date +%Y%m%d_%H%M`"  | tee /var/lock/mylockreason$PROG
  fi
else  
  echo "plan9 not detected"
fi 

# check planb if it's there
x=`sudo -u nixo bash -c "export DISPLAY=:8.0 && export XAUTHORITY=/home/nixo/.Xauthority && xprintidle"`
result=$?
echo "result $result"
if [ "$result" == "0" ]; then
  y=$(( $x / 1000 ))
  if [ "$y" -lt "60" ]; then 
    dobackup=1;
    echo "doing backup because of non idle X on planb `date +%Y%m%d_%H%M`"  | tee /var/lock/mylockreason$PROG
  fi
else  
  echo "planb not detected"
fi 

if [ "$dobackup" == "1" ]; then
  # make a snapshot of it.
  DATE=`date +%Y%m%d_%H%M`
  echo "btrfs subvolume snapshot -r /home /home/snaps/homenixo_$DATE"
  btrfs subvolume snapshot -r /home /home/snaps/homenixo_$DATE
fi

rmdir /var/lock/mylock$PROG
