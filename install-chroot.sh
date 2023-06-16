set -e

arch="$(dpkg --print-architecture)"

echo -n 'APT::Install-Recommends "false";
APT::AutoRemove::RecommendsImportant "false";
APT::AutoRemove::SuggestsImportant "false";
' > /etc/apt/apt.conf.d/99_norecommends

case "$arch" in
ppc64el) apt-get -qq install "linux-image-powerpc64le" ;;
i386)
	if grep -q '^flags.*\blm\b' /proc/cpuinfo; then
		apt-get -qq install "linux-image-686-pae"
	elif grep -q '^flags.*\bpae\b' /proc/cpuinfo; then
		apt-get -qq install "linux-image-686-pae"
	else
		apt-get -qq install "linux-image-686"
	fi ;;
armhf)
	if grep -q '^Features.*\blpae\b' /proc/cpuinfo; then
		apt-get -qq install "linux-image-armmp-lpae"
	else
		apt-get -qq install "linux-image-armmp"
	fi ;;
armel) apt-get -qq install "linux-image-marvell" ;;
*) apt-get -qq install "linux-image-$arch" ;;
esac

if [ -d /sys/firmware/efi ]; then
	echo "root=UUID=$(findmnt -n -o UUID /) ro quiet" > /etc/kernel/cmdline
	apt-get -qq install systemd-boot
	mkdir -p /boot/efi/loader
	printf 'timeout 0\neditor no\n' > /boot/efi/loader/loader.conf
else
	case "$arch" in
	amd64|i386) apt-get -qq install grub-pc ;;
	ppc64el) apt-get -qq install grub-ieee1275 ;;
	esac
	# lock Grub for security
	# recovery mode in Debian requires root password
	# so there is no need to disable generation of recovery mode menu entries
	# we just have to disable menu editing and other admin operations
	[ -f /boot/grub/grub.cfg ] && {
		printf 'set superusers=""\nset timeout=0\n' > /boot/grub/custom.cfg
		update-grub
	}
fi

# search for required firmwares, and install them
# https://salsa.debian.org/debian/isenkram
# https://salsa.debian.org/installer-team/hw-detect
#
# for now just install all firmwares
apt-get -qq install live-task-non-free-firmware-pc
#
# this script installs required firmwares when a new hardware is added
echo -n '#!/bin/sh
' > /usr/local/bin/install-firmware
chmod +x /usr/local/bin/install-firmware
echo 'SUBSYSTEM=="firmware", ACTION=="add", RUN+="/usr/local/bin/install-firmware %k"' > \
	/etc/udev/rules.d/80-install-firmware.rules

echo 'LANG=C.UTF-8' > /etc/default/locale

apt-get -qq install pipewire-audio dbus-user-session systemd-timesyncd

echo -n '[Match]
Name=en*
Name=eth*
#Type=ether
#Name=! veth*
[Network]
DHCP=yes
[DHCPv4]
RouteMetric=100
[IPv6AcceptRA]
RouteMetric=100
' > /etc/systemd/network/20-ethernet.network
echo -n '[Match]
Name=wl*
#Type=wlan
#WLANInterfaceType=station
[Network]
DHCP=yes
IgnoreCarrierLoss=3s
[DHCPv4]
RouteMetric=600
[IPv6AcceptRA]
RouteMetric=600
' > /etc/systemd/network/20-wireless.network
echo -n '[Match]
Name=ww*
#Type=wwan
[Network]
DHCP=yes
IgnoreCarrierLoss=3s
[DHCPv4]
RouteMetric=700
[IPv6AcceptRA]
RouteMetric=700
' > /etc/systemd/network/20-wwan.network
# https://gitlab.archlinux.org/archlinux/archiso/-/blob/master/configs/releng/airootfs/etc/systemd/network/20-wwan.network
# https://wiki.archlinux.org/title/Mobile_broadband_modem
# https://github.com/systemd/systemd/issues/20370
systemctl enable systemd-networkd
apt-get -qq install systemd-resolved

. /mnt/install-sudo.sh

. /mnt/install-system.sh

. /mnt/install-sway.sh

# allow udisks2 to mount all devices except when it's an EFI partition
echo -n 'polkit.addRule(function(action, subject) {
	function isEfiPartition(devicePath) {
		var partitionType = polkit.spawn("lsblk --noheadings -o PARTTYPENAME " + devicePath);
		if (partitionType === "EFI System") return true;
	};
	if (subject.local && subject.active && (
		action.id === "org.freedesktop.udisks2.filesystem-mount" ||
		action.id === "org.freedesktop.udisks2.filesystem-mount-system"
	)) {
		if (!isEfiPartition(action.lookup("device")) {
			return polkit.Result.YES;
		} else {
			return polkit.Result.NO;
		}
	}
});
' > /etc/polkit-1/rules.d/49-udisks.rules

apt-get -qq install jina codev 2>/dev/null || true
