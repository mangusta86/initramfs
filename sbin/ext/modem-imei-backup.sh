#!/sbin/busybox sh

BB=/sbin/busybox

if [ ! -f /data/.mangusta/modembackup.tar.gz ]; then
	$BB mkdir /data/.mangusta;
	$BB chmod 777 /data/.mangusta;
	$BB tar zcvf /data/.mangusta/modembackup.tar.gz /modem;
	$BB cat /dev/block/mmcblk0p3 > /data/.mangusta/imei-mmcblk0p3.img;
	$BB gzip /data/.mangusta/imei-mmcblk0p3.img;
	$BB cp /data/.mangusta/modembackup.tar.gz /data/share/;
	$BB cp /data/.mangusta/imei-mmcblk0p3.img /data/share/;
	$BB chmod 777 /data/share/imei-mmcblk0p3.img;
	$BB chmod 777 /data/share/modembackup.tar.gz;
	(
		sleep 120;
		cp /data/share/modembackup.tar.gz /sdcard/;
		cp /data/share/imei-mmcblk0p3.img /sdcard/;
	)&
fi;
