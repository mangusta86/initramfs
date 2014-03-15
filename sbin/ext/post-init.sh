#!/sbin/busybox sh

BB=/sbin/busybox

# first mod the partitions then boot
$BB sh /sbin/ext/system_tune_on_init.sh;

ROOT_RW()
{
	$BB mount -o remount,rw /;
}
ROOT_RW;

# fix owners on critical folders
$BB chown -R root:root /tmp;
$BB chown -R root:root /res;
$BB chown -R root:root /sbin;
$BB chown -R root:root /lib;

# oom and mem perm fix
$BB chmod 666 /sys/module/lowmemorykiller/parameters/cost;
$BB chmod 666 /sys/module/lowmemorykiller/parameters/adj;

# protect init from oom
echo "-1000" > /proc/1/oom_score_adj;

# set sysrq to 2 = enable control of console logging level as with CM-KERNEL
echo "2" > /proc/sys/kernel/sysrq;

PIDOFINIT=$(pgrep -f "/sbin/ext/post-init.sh");
for i in $PIDOFINIT; do
	echo "-600" > /proc/"$i"/oom_score_adj;
done;

# allow user and admin to use all free mem.
echo 0 > /proc/sys/vm/user_reserve_kbytes;
echo 8192 > /proc/sys/vm/admin_reserve_kbytes;

if [ ! -d /data/.mangusta ]; then
	$BB mkdir -p /data/.mangusta;
fi;

# reset config-backup-restore
if [ -f /data/.mangusta/restore_running ]; then
	rm -f /data/.mangusta/restore_running;
fi;

# reset profiles auto trigger to be used by kernel ADMIN, in case of need, if new value added in default profiles
# just set numer $RESET_MAGIC + 1 and profiles will be reset one time on next boot with new kernel.
RESET_MAGIC=8;
if [ ! -e /data/.mangusta/reset_profiles ]; then
	echo "0" > /data/.mangusta/reset_profiles;
fi;
if [ "$(cat /data/.mangusta/reset_profiles)" -eq "$RESET_MAGIC" ]; then
	echo "no need to reset profiles";
else
	rm -f /data/.mangusta/*.profile;
	echo "$RESET_MAGIC" > /data/.mangusta/reset_profiles;
fi;

[ ! -f /data/.mangusta/default.profile ] && cp -a /res/customconfig/default.profile /data/.mangusta/default.profile;
[ ! -f /data/.mangusta/battery.profile ] && cp -a /res/customconfig/battery.profile /data/.mangusta/battery.profile;
[ ! -f /data/.mangusta/performance.profile ] && cp -a /res/customconfig/performance.profile /data/.mangusta/performance.profile;
[ ! -f /data/.mangusta/extreme_performance.profile ] && cp -a /res/customconfig/extreme_performance.profile /data/.mangusta/extreme_performance.profile;
[ ! -f /data/.mangusta/extreme_battery.profile ] && cp -a /res/customconfig/extreme_battery.profile /data/.mangusta/extreme_battery.profile;

$BB chmod -R 0777 /data/.mangusta/;

. /res/customconfig/customconfig-helper;
read_defaults;
read_config;

# custom boot booster stage 1
echo "$boot_boost" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq;

# Apps Install
$BB sh /sbin/ext/install.sh;

# Clean /res/ from no longer needed files to free modules kernel allocated mem
$BB rm -rf /res/misc/sql /res/images /res/misc/JellyB-* /res/misc/KitKat-CM-AOKP-11 /res/misc/vendor;

# busybox addons
if [ -e /system/xbin/busybox ] && [ ! -e /sbin/ifconfig ]; then
	$BB ln -s /system/xbin/busybox /sbin/ifconfig;
fi;

# some nice thing for dev
if [ ! -e /cpufreq ]; then
	$BB ln -s /sys/devices/system/cpu/cpu0/cpufreq /cpufreq;
	$BB ln -s /sys/devices/system/cpu/cpufreq/ /cpugov;
fi;

# enable kmem interface for everyone by GM
echo "0" > /proc/sys/kernel/kptr_restrict;

# Cortex parent should be ROOT/INIT and not STweaks
nohup /sbin/ext/cortexbrain-tune.sh;
CORTEX=$(pgrep -f "/sbin/ext/cortexbrain-tune.sh");
echo "-900" > /proc/"$CORTEX"/oom_score_adj;

# create init.d folder if missing
if [ ! -d /system/etc/init.d ]; then
	mkdir -p /system/etc/init.d/
	$BB chmod 755 /system/etc/init.d/;
fi;

(
if [ "$init_d" == "on" ]  then
	$BB sh /sbin/ext/run-init-scripts.sh;
fi;
)&


# for ntfs automounting
mount -t tmpfs -o mode=0777,gid=1000 tmpfs /mnt/ntfs

ROOT_RW;

(
	SD_COUNTER=0;
	while [ "$($BB mount | grep "/storage/sdcard0" | wc -l)" == "0" ]; do
		if [ "$SD_COUNTER" -ge "60" ]; then
			break;
		fi;
		echo "Waiting For Internal SDcard to be mounted";
		sleep 5;
		SD_COUNTER=$((SD_COUNTER+1));
		# max 5min
	done;

	if [ -e /sys/block/mmcblk1/queue/scheduler ]; then
		echo "deadline" > /sys/block/mmcblk1/queue/scheduler;
	fi;
)&

(
	COUNTER=0;
	echo "0" > /tmp/uci_done;
	$BB chmod 666 /tmp/uci_done;

	while [ "$(cat /tmp/uci_done)" != "1" ]; do
		if [ "$COUNTER" -ge "40" ]; then
			break;
		fi;
		echo "1000000" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq;
		echo "$boot_boost" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq;
		pkill -f "com.gokhanmoral.stweaks.app";
		echo "Waiting For UCI to finish";
		sleep 3;
		COUNTER=$((COUNTER+1));
		# max 2min
	done;

	#TODO
	# restore normal freq
	echo "$scaling_min_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq;
	if [ "$scaling_max_freq" -eq "1000000" ] && [ "$scaling_max_freq_oc" -gt "1000000" ]; then
		echo "$scaling_max_freq_oc" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq;
	else
		echo "$scaling_max_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq;
	fi;
	#TODO	


	# tweaks all the dm partitions that hold moved to sdcard apps
	sleep 30;
	DM_COUNT=$(find /sys/block/dm* | wc -l);
	if [ "$DM_COUNT" -gt "0" ]; then
		for d in $($BB mount | grep dm | cut -d " " -f1 | grep -v vold); do
			$BB mount -o remount,noauto_da_alloc "$d";
		done;

		DM=$(find /sys/block/dm*);
		for i in ${DM}; do
			echo "0" > "$i"/queue/rotational;
			echo "0" > "$i"/queue/iostats;
		done;
	fi;

	$BB mount -o remount,rw /storage/sdcard0;

	# script finish here, so let me know when
	echo "Done Booting" > /data/dm-boot-check;
	date >> /data/dm-boot-check;
)&

(
	# stop uci.sh from running all the PUSH Buttons in stweaks on boot
	$BB mount -o remount,rw rootfs;
	$BB chown -R root:system /res/customconfig/actions/;
	$BB chmod -R 6755 /res/customconfig/actions/;
	$BB mv /res/customconfig/actions/push-actions/* /res/no-push-on-boot/;
	$BB chmod 6755 /res/no-push-on-boot/*;

	# apply STweaks settings
	echo "booting" > /data/.mangusta/booting;
	chmod 777 /data/.mangusta/booting;
	pkill -f "com.gokhanmoral.stweaks.app";
	nohup $BB sh /res/uci.sh restore;
	UCI_PID=$(pgrep -f "/res/uci.sh");
	echo "-800" > /proc/"$UCI_PID"/oom_score_adj;
	ROOT_RW;
	echo "1" > /tmp/uci_done;

	# restore all the PUSH Button Actions back to there location
	$BB mv /res/no-push-on-boot/* /res/customconfig/actions/push-actions/;
	pkill -f "com.gokhanmoral.stweaks.app";

	# change USB mode MTP or Mass Storage
	$BB sh /res/uci.sh usb-mode "$usb_mode";

	# update cpu tunig after profiles load
	$BB sh /sbin/ext/cortexbrain-tune.sh apply_cpu update > /dev/null;
	$BB rm -f /data/.mangusta/booting;

	# ###############################################################
	# I/O related tweaks
	# ###############################################################

	mount -o remount,rw /system;
	# correct touch keys light, if rom mess user configuration
	$BB sh /res/uci.sh generic /sys/class/misc/notification/led_timeout_ms "$led_timeout_ms";

	# correct oom tuning, if changed by apps/rom
	$BB sh /res/uci.sh oom_config_screen_on "$oom_config_screen_on";
	$BB sh /res/uci.sh oom_config_screen_off "$oom_config_screen_off";
)&

(
	# kill radio logcat to sdcard
	$BB pkill -f "logcat -b radio -v time";

	# RADIO Backup
	$BB sh /sbin/ext/modem-imei-backup.sh;
)&
