set -e

arch="$(dpkg --print-architecture)"

echo -n 'APT::Install-Recommends "false";
APT::AutoRemove::RecommendsImportant "false";
APT::AutoRemove::SuggestsImportant "false";
' > /etc/apt/apt.conf.d/99_norecommends

if [ -d /sys/firmware/efi ]; then
	apt-get --yes install systemd-boot
	mkdir -p /boot/efi/loader
	printf 'timeout 0\neditor no\n' > /boot/efi/loader/loader.conf
else
	case "$arch" in
	amd64|i386) apt-get --yes install grub-pc ;;
	ppc64el) apt-get --yes install grub-ieee1275 ;;
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

case "$arch" in
ppc64el) apt-get --yes install "linux-image-powerpc64le" ;;
i386)
	if grep -q '^flags.*\blm\b' /proc/cpuinfo; then
		apt-get --yes install "linux-image-686-pae"
	elif grep -q '^flags.*\bpae\b' /proc/cpuinfo; then
		apt-get --yes install "linux-image-686-pae"
	else
		apt-get --yes install "linux-image-686"
	fi ;;
armhf)
	if grep -q '^Features.*\blpae\b' /proc/cpuinfo; then
		apt-get --yes install "linux-image-armmp-lpae"
	else
		apt-get --yes install "linux-image-armmp"
	fi ;;
armel) apt-get --yes install "linux-image-marvell" ;;
*) apt-get --yes install "linux-image-$arch" ;;
esac

# search for required firmwares, and install them
# https://salsa.debian.org/debian/isenkram
# https://salsa.debian.org/installer-team/hw-detect
#
# this script installs required firmwares when a new hardware is added
echo -n '#!/bin/sh
' > /usr/local/bin/install-firmware
chmod +x /usr/local/bin/install-firmware
echo 'SUBSYSTEM=="firmware", ACTION=="add", RUN+="/usr/local/bin/install-firmware %k"' > \
	/etc/udev/rules.d/80-install-firmware.rules

apt-get --yes install pipewire-audio dbus-user-session systemd-timesyncd

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
apt-get --yes install systemd-resolved

. /mnt/install-sudo.sh

. /mnt/install-system.sh

. /mnt/install-sway.sh

echo; echo -n "set username: "
read -r username
useradd --create-home --groups netdev,bluetooth --shell /bin/bash "$username" || true
while ! passwd --quiet "$username"; do
	echo "an error occured; please try again"
done
echo; echo "set sudo password"
while ! passwd --quiet; do
	echo "an error occured; please try again"
done
# lock root account
passwd --lock root

# guest user:
# read'only access to projects
# in the same group as the first user
# during login, creates a symlink for each project directory

apt-get --yes install jina codev 2>/dev/null || true
