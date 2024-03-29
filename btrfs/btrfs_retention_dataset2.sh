#!/bin/bash

PROG=`basename $0`
echo $PROG

WHOAMI=`whoami`
if [ "$WHOAMI" != "root" ]; 
then echo "you must be root.";
exit;
fi

if ! mkdir /var/lock/mylock$PROG; then
  echo "Subject: $PROG lock failed. $*" | sendmail nixo@exprodigy.net
  exit 1
fi

dataset=$1
if [ "$dataset" == "" ]; then
  echo "Subject: $PROG failed, no dataset specified." | sendmail nixo@exprodigy.net
  rmdir /var/lock/mylock$PROG
  exit 1
fi

echo "you are root running retention for $dataset"

btrfs subvolume list "$dataset" >/dev/null 2>&1
ok=$?

if [ "$ok" != 0 ]; then
  echo "Subject: $PROG failed, can't find dataset $dataset." | sendmail nixo@exprodigy.net
  rmdir /var/lock/mylock$PROG
  exit 1
fi

RAND=$RANDOM

SNAPPATH=/tmp/${PROG}_snapshots_${RAND}
SNAPS=/tmp/${PROG}_snapshotnames_${RAND}
KEEPLIST=/tmp/${PROG}_dayskeeplist_${RAND}
KEEPLISTTEMP=/tmp/${PROG}_dayskeeplisttemp_${RAND}
KEEPWHOLEDAYSLIST=/tmp/${PROG}_dayskeepwholedayslist_${RAND}
SNAPSTOKEEP=/tmp/${PROG}_snapshotdaystokeeplist_${RAND}
SNAPSTODESTROY=/tmp/${PROG}_snapshotstodestroy_${RAND}
SNAPSONEDAY=/tmp/${PROG}_snapshotnamesoneday_${RAND}

keepfirstitem(){
day=$1
# echo "keeping the newest snapshot from day $day"
grep $day $SNAPS | sort -r > $SNAPSONEDAY
latest=`head -1 $SNAPSONEDAY`
if [ "$latest" != "" ]; then
  echo "The newest snapshot time for $day is $latest"
  echo $latest >> $KEEPLIST
fi 
}


# put the don't run twice thing here.

# first we get a list of all snapshots, figure out which ones we want to keep, then delete the rest

echo "getting all snapshots in a list"
btrfs subvolume list -r -s   ${dataset} | awk '{ print $NF }' > $SNAPPATH

cat $SNAPPATH | awk -F "_" '{ print $2 "_" $3 }' | sort -r > $SNAPS

# get a list of all of the days in the past 2 days, keep every snapshot 
for i in {0..1}; do ((keep[$(date +%Y%m%d -d "-$i day")]++)); done
echo ${!keep[@]}
# get the list of snapshots that include the days we want to keep
echo ${!keep[@]} | xargs -n1 echo | sort -r > $KEEPWHOLEDAYSLIST
grep -Ff $KEEPWHOLEDAYSLIST $SNAPS | sort -r > $KEEPLIST

# so now we have all the snapshots for the recent 2 days we want to keep


# get a list of all of the hours in the past 2 weeks, keep the most recent of each hour if any
# this will overlap with the first few days, but that's okay, it's the keep list we're unioning
declare -A keephours # this allows us to put _ in the key
for i in $(eval echo {0..$((24 * 14))}); do ((keephours[$(date +%Y%m%d_%H -d "-$i hours")]=1)); done

# now go through each item in keephours, get all the snapshots for that hour and keep only the newest one, append them to keeplist
for i in ${!keephours[@]}
do
    keepfirstitem $i
done


# get a list of all of the wednesdays in the past six months
#for i in {0..52}; do ((keepfirst[$(date +%Y%m%d -d "wednesday-$((i+1)) week")]++)); done
for i in {0..26}; do ((keepfirst[$(date +%Y%m%d -d "wednesday-$((i+1)) week")]++)); done

# now go through each item in keepfirst, get all the snapshots for that day and keep only the newest one, append them to keeplist

for i in ${!keepfirst[@]}
do
    keepfirstitem $i
done

# so now keeplist has all the snapnames we want to keep, everything from the last 2 weeks, and the latest of every wednesday

# now keeplist has exactly everything we want to keep sorted and nothing else


# now get the inverse of that, get all the snapshots that exists that aren't in the list of ones we want to keep
grep -vFf $KEEPLIST $SNAPS > $SNAPSTODESTROY


destroy_snap(){
  snapname=$1
  SNAPPATH=$2
  
  if [ "$snapname" == "" ]; then
    return
  fi
  # find the actual snap pathname for this snapname date
  path=`grep "$snapname" $SNAPPATH`
  echo "got snapname $snapname"
  echo $path
  if [ "$path" == "" ]; then
    echo "can't find snap date $snapname to destroy in master snaps list $SNAPPATH"
    return
  fi
  echo "destroying snapshot $path:   btrfs subvolume delete /home/$path"
  btrfs subvolume delete /home/$path
}

export -f destroy_snap

cat $SNAPSTODESTROY   | xargs -I {} bash -c 'destroy_snap "$@"' _ {} $SNAPPATH

rmdir /var/lock/mylock$PROG
