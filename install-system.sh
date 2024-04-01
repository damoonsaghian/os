apt-get -qq install iwd wireless-regdb bluez rfkill passwd fzy

cp /mnt/system /usr/local/bin/
chmod +x /usr/local/bin/system

systemctl enable iwd.service

echo '# allow rfkill for users in the netdev group
KERNEL=="rfkill", MODE="0664", GROUP="netdev"
' > /etc/udev/rules.d/80-rfkill.rules

echo; echo "setting timezone"
# guess the timezone, but let the user to confirm it
command -v wget > /dev/null 2>&1 || apt-get -qq install wget > /dev/null 2>&1 || true
geoip_tz="$(wget -q -O- 'http://ip-api.com/line/?fields=timezone')"
geoip_tz_continent="$(echo "$geoip_tz" | cut -d / -f1)"
geoip_tz_city="$(echo "$geoip_tz" | cut -d / -f2)"
tz_continent="$(ls -1 -d /usr/share/zoneinfo/*/ | cut -d / -f5 |
	fzy -p "select a continent: " -q "$geoip_tz_continent")"
tz_city="$(ls -1 /usr/share/zoneinfo/"$tz_continent"/* | cut -d / -f6 |
	fzy -p "select a city: " -q "$geoip_tz_city")"
ln -sf "/usr/share/zoneinfo/${tz_continent}/${tz_city}" /etc/localtime

echo -n 'polkit.addRule(function(action, subject) {
	if (
		action.id == "org.freedesktop.timedate1.set-timezone" &&
		subject.local && subject.active
	) {
		return polkit.Result.YES;
	}
});
' > /etc/polkit-1/rules.d/49-timezone.rules

echo 'APT::AutoRemove::SuggestsImportant "false";' > /etc/apt/apt.conf.d/99_norecommends

cat <<'__EOF__' > /usr/local/bin/ospkg-deb
#!/usr/bin/env -S pkexec /bin/bash
mode="$1"
meta_package=ospkg-"$PKEXEC_UID"--"$2"
packages="$3"

if [ "$1" = add ]; then
	# if there a package named "$meta_package" is already installed,
	# and its dependencies (when sorted) is equal to "$packages" (when sorted),
	# fix and exit
	
	# if there is a old package with the same name, find its version, and version=version+1
	# otherwise version is 0
	
	# create the meta package
	mkdir -p /tmp/ospkg-deb/"$meta_package"/debian
	cat <<-__EOF2__ > /tmp/ospkg-deb/"$meta_package"/debian/control
	Package: $meta_package
	Version: $version
	Architecture: all
	Depends: $packages
	Installed-Size:
	Maintainer: Daeng Bo
	Description: A metapackage for Daeng
	Detailed description (optional, and notice the leading space)
	__EOF2__
	dpkg --build /tmp/ospkg-deb/"$meta_package" /tmp/ospkg-deb/
	
	apt-get update
	apt-get install /tmp/ospkg-deb/"$meta_package"_"$version"_all.deb
elif [ "$1" == remove ]; then
	apt-get purge -- "$meta_package"
elif [ "$1" == update ]; then
	apt-get update
elif [ "$1" == upgrade ]; then
	apt-get update
	apt-get dist-upgrade
fi

apt-get -qq --purge autoremove
apt-get -qq autoclean
__EOF__
chmod +x /usr/local/bin/ospkg-deb

echo -n '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE policyconfig PUBLIC "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
	"http://www.freedesktop.org/standards/PolicyKit/1/policyconfig.dtd">
<policyconfig>
	<action id="org.local.pkexec.ospkg-deb">
		<description>ospkg-deb</description>
		<message>ospkg-deb</message>
		<defaults><allow_active>yes</allow_active></defaults>
		<annotate key="org.freedesktop.policykit.exec.path">/bin/bash</annotate>
		<annotate key="org.freedesktop.policykit.exec.argv1">/usr/local/bin/ospkg-deb</annotate>
	</action>
</policyconfig>
' > /usr/share/polkit-1/actions/org.local.pkexec.ospkg-deb.policy

# https://www.freedesktop.org/wiki/Software/systemd/inhibit/
cat <<'__EOF__' > /usr/local/share/automatic-update.sh
metered_connection() {
	local active_net_device="$(ip route show default | head -1 | sed -n "s/.* dev \([^\ ]*\) .*/\1/p")"
	local is_metered=false
	case "$active_net_device" in
		ww*) is_metered=true ;;
	esac
	# todo: DHCP option 43 ANDROID_METERED
	$is_metered
}
metered_connection && exit 0

apt-get update
export DEBIAN_FRONTEND=noninteractive
apt-get -qq -o Dpkg::Options::=--force-confnew dist-upgrade

apt-get -qq --purge autoremove
apt-get -qq autoclean
__EOF__

mkdir -p /usr/local/lib/systemd/system
echo -n '[Unit]
Description=automatic update
ConditionACPower=true
After=network-online.target
[Service]
Type=oneshot
ExecStartPre=-/usr/lib/apt/apt-helper wait-online
ExecStart=/bin/sh /usr/local/share/automatic-update.sh
KillMode=process
TimeoutStopSec=900
Nice=19
' > /usr/local/lib/systemd/system/automatic-update.service
echo -n '[Unit]
Description=automatic update
[Timer]
OnBootSec=5min
OnUnitInactiveSec=24h
RandomizedDelaySec=5min
[Install]
WantedBy=timers.target
' > /usr/local/lib/systemd/system/automatic-update.timer
systemctl enable automatic-update.timer
