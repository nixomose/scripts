#!/bin/bash

# this is run out of /etc/crontab every minute
# if there is terminal that is not idle or X is not idle
# do a backup to zfs and snapshot it.

# example cron entry:
# * * * * * root /bin/backupnotidle.sh > /dev/null 2>&1

EMAIL=me@example.com
USERNAME=me

if ! mkdir /var/lock/mylock; then
  echo "Subject: backupnotidle lock failed." | sendmail $EMAIL
  exit 1
fi

# apparently needed for xprintidle
export DISPLAY=:0.0

dobackup=0

w | awk '{print $5}' | grep "s$" | grep -v days >/dev/null
if [ "$?" == "0" ]; then
  dobackup=1;
  echo "doing backup because of non idle terminal"
fi

x=`sudo -u $USERNAME xprintidle`
y=$(( $x / 1000 ))
if [ "$y" -lt "60" ]; then 
  dobackup=1;
  echo "doing backup because of non idle X"
fi
 
if [ "$dobackup" == "1" ]; then

# insert your script here to rsync whatever you want to back up.
# for example...
rsync -al /home/$USERNAME     /tank/backup

# make a snapshot of it.
DATE=`date +%Y%m%d_%H%M`
zfs snapshot  tank/backup@$DATE
fi

# delete old snapshots
# this script can be found here:
# https://github.com/nixomose/zfs-scripts/tree/master/scripts

delete_snapshots.sh -d 7 -t -p z

rmdir /var/lock/mylock
