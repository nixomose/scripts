#!/bin/bash

# generic script to backup zfs snapshots to another place incrementally, ie only sending the destination the snapshots it doesn't have
# this assumes both sides are local


export SRC=$1
export DEST=$2

# if DEST is on another machine, set REMOTE="ssh io.local"
export REMOTE="$3"

echo "sending from $SRC to $DEST"

# you don't have to touch anything below here.

PROG=`basename $0`
echo $PROG
# this should match what you have in cron
OUTFILE=`echo $PROG | tr -d '.'`
OUTFILE=${OUTFILE}.out
echo "outfile=${OUTFILE}"

WHOAMI=`whoami`
if [ "$WHOAMI" != "root" ]; 
then echo "you must be root.";
exit;
fi

echo "you are root"

DATE=`date +%Y%m%d_%H%M`

# see if any data was written to live dataset not in the last snapshot
# root@run:/home/nixo/zfstools# zfs list -o name,written z/astudio  -p
# NAME       WRITTEN
# z/astudio   196608
size=`zfs list -o written $SRC  -p |tail -1`
echo "size of written to $SRC is $size"
if [ "$(($size))" == "0" ]; then
  echo "no change to dataset since last snapshot. not making new snapshot"
else
  echo "making latest snapshot called $DATE"
  echo "zfs snapshot $SRC@$DATE"
        zfs snapshot $SRC@$DATE
fi


if ! mkdir /var/lock/mylock$PROG; then
  echo "Subject: $PROG lock failed." > /tmp/$PROG.mail
  echo "" >> /tmp/$PROG.mail
  cat /tmp/$OUTFILE >> /tmp/$PROG.mail

  cat /tmp/$PROG.mail | sendmail nixo@exprodigy.net

  exit 1
fi


# to make the initial snapshot backup to which we send incrementals, I did this: (to send to remote)
# sudo zfs send zhome/smark@20200421_0839 | ssh root@io.local zfs recv zbackup/dattowekmodsnapshots
# the io zhome/homenixo example (for local)
# zfs send zhome/homenixo@20200507_0838 | pv | zfs recv zbackup/homenixo

# we need to get from io the last snapshot it has and we start with that.

# well that works well enough until you leave a vm off for 3 days over july 4th weekend
# and the retention script removes the last snapshot that you want to incremental from and
# it fails. so what makes more sense is to get the last snapshot that both have and start with that
# and the ultimate fallback is if that doesn't exist, there is no shared snapshot then you just send the first one.
# and the next pass will pick up the incremental.
# it would also make sense to keep the most recent few snapshots no matter what, but that's the retention script.


# here's how you can match lists... 
# zfs list zhome/homenixo    -r -tall -o name | grep "@" | awk -F"@" '{ print $2 }' |  sort > t1
# zfs list zbackup/homenixo  -r -tall -o name | grep "@" | awk -F"@" '{ print $2 }' |  sort > t2 
# comm t1 t2 -12 | tail -1
# that gets you the last shared snapshot name

# 7/13/2020 get SNAPA by finding the last snap that both have.
        zfs list -t snap -o name $SRC  | grep "@" | awk -F"@" '{ print $2 }' | sort > /tmp/${PROG}_local_snaps
$REMOTE zfs list -t snap -o name $DEST | grep "@" | awk -F"@" '{ print $2 }' | sort > /tmp/${PROG}_remote_snaps

SNAPA=`comm -12 /tmp/${PROG}_local_snaps /tmp/${PROG}_remote_snaps | tail -1`

if [ "x$SNAPA" == "x" ]; then
  echo "couldn't get last shared snapshot from io $SRC and $DEST"

  # at this point you should send the first snapshot, let's do that.
  # then exit, the next time we run, it will pick up the incrementals
  
  FIRSTSNAP=`zfs list -t snap -o name $SRC  | grep "@" | sort | head -1`
  if [ "x$FIRSTSNAP" == "x" ]; then
    echo "there isn't even a first snap to send."
  rmdir /var/lock/mylock$PROG
  exit
fi

  echo "sending first snap ${FIRSTSNAP} from $SRC to $DEST"
  echo "zfs send $FIRSTSNAP "'|'" $REMOTE zfs recv -F $DEST"
  zfs send $FIRSTSNAP | $REMOTE zfs recv -F $DEST

  rmdir /var/lock/mylock$PROG
  exit
fi

echo "last shared snap is: $SNAPA"

# now we prepend zhome/homenixo@  to make it local
SNAPA="${SRC}@${SNAPA}"


# this gets us the current last snapshot from SRC
SNAPZ=`zfs list -t snap -o name $SRC | tail -1`

echo "snapshot range"
echo "[$SNAPA]"
echo "[$SNAPZ]"

if [ "$SNAPA" == "$SNAPZ" ]; then
  echo "first and last snapshot to move is the same, nothing to do."
  rmdir /var/lock/mylock$PROG
  exit
fi

echo "send command:"
echo "zfs send -I $SNAPA $SNAPZ | $REMOTE sudo zfs recv -d -F $DEST"
      zfs send -I $SNAPA $SNAPZ | $REMOTE sudo zfs recv -d -F $DEST


# now compare the snapshot lists just for fun
        zfs list -t all -r $SRC | grep "$SRC@"  | awk -F "@" '{ print $2 }' | awk '{ print $1 }' > /tmp/zlist`echo $SRC  | tr -d '/'`
$REMOTE zfs list -t all -r $DEST| grep "$DEST@" | awk -F "@" '{ print $2 }' | awk '{ print $1 }' > /tmp/zlist`echo $DEST | tr -d '/'`

diff /tmp/zlist`echo $SRC | tr -d '/'` /tmp/zlist`echo $DEST | tr -d '/'`

rmdir /var/lock/mylock$PROG






