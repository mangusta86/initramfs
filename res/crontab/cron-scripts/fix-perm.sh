#!/sbin/busybox sh

(
	PROFILE=`cat /data/.mangusta/.active.profile`;
	. /data/.mangusta/${PROFILE}.profile;

	if [ "$cron_fix_permissions" == "on" ]; then
		while [ ! `cat /proc/loadavg | cut -c1-4` \< "3.50" ]; do
			echo "Waiting For CPU to cool down";
			sleep 30;
		done;

		/system/xbin/fix_permissions -l -r -v > /dev/null 2>&1;
		date +%H:%M-%D-%Z > /data/crontab/cron-fix_permissions;
		echo "Done! Fixed Apps Permissions" >> /data/crontab/cron-fix_permissions;
	fi;
)&
