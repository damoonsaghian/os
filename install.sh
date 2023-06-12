set -e

arch="$(dpkg --print-architecture)"
case "$arch" in
s390x|mipsel|mips64el) echo "arichitecture \"$arch\" is not supported"; exit ;;
esac

command -v arch-chroot 1>/dev/null || apt-get -qq install arch-install-scripts

command -v fzy 1>/dev/null || apt-get -qq install fzy

umount --recursive --quiet /mnt || true

directory_of_this_file="$(dirname "$0")"

mnt_debootstrap() {
	command -v debootstrap 1>/dev/null || apt-get -qq install debootstrap
	debootstrap --variant=minbase --include="init,udev,netbase,ca-certificates,usr-is-merged" \
		--components=main,contrib,non-free-firmware stable /mnt
	# "usr-is-merged" is installed to avoid installing "usrmerge" (as a dependency for init-system-helpers)
}

mnt_install() {
	mount --bind "$directory_of_this_file" /mnt/mnt
	genfstab -U /mnt >> /mnt/etc/fstab
	arch-chroot /mnt sh /mnt/install-chroot.sh
}

answer="$(printf "install a new system\nrepair an existing system" | fzy -p "select an option: ")"

[ "$answer" = "repair an existing system" ] && {
	target_device="$(lsblk --nodep --noheadings -o NAME,SIZE,MODEL | 
		fzy -p "select the device containing the system: " | cut -d " " -f 1)"
	
	target_partitions="$(lsblk --list --noheadings -o PATH "/dev/$target_device")"
	target_partition1="$(echo "$target_partitions" | sed -n '2p')"
	target_partition2="$(echo "$target_partitions" | sed -n '3p')"
	
	mount "$target_partition2" /mnt
	if [ -d /sys/firmware/efi ]; then
		mkdir -p /mnt/boot/efi
		mount "$target_partition1" /mnt/boot/efi
	else
		case "$arch" in
		amd64|i386) ;;
		ppc64el) ;;
		*) mkdir /mnt/boot; mount "$target_partition1" /mnt/boot ;;
		esac
	fi
	
	[ -d /mnt/debootstrap ] && EXTRACT_DEB_TAR_OPTIONS=--overwrite mnt_debootstrap
	{
		arch-chroot /mnt apt-get dist-upgrade
		mnt_install
	} || {
		EXTRACT_DEB_TAR_OPTIONS=--overwrite mnt_debootstrap
		arch-chroot /mnt apt-get dist-upgrade
		mnt_install
	}
	
	echo; echo -n "the system on \"$target_device\" repaired successfully"
	answer="$(printf "no\nyes" | fzy -p "reboot the system? ")"
	[ "$answer" = yes ] || reboot
	exit
}

target_device="$(lsblk --nodep --noheadings -o NAME,SIZE,MODEL | fzy -p "select a device: " | cut -d " " -f 1)"
answer="$(printf "no\nyes" | fzy -p "WARNING! all the data on \"$target_device\" will be erased; continue? ")"
[ "$answer" = yes ] || exit

# create partitions
if [ -d /sys/firmware/efi ]; then
	first_part_type=uefi
	first_part_size="512M"
	part_label=gpt
else
	case "$arch" in
	amd64|i386)
		first_part_type="21686148-6449-6E6F-744E-656564454649"
		first_part_size="1M"
		part_label=gpt
		;;
 	ppc64el)
		first_part_type="41,*"
		first_part_size="1M"
		part_label=dos
		;;
	*)
		first_part_type="linux,*"
		first_part_size="512M"
		part_label=dos
		;;
	esac
fi
command -v sfdisk 1>/dev/null || apt-get -qq install fdisk
sfdisk --quiet --wipe always --label $part_label "/dev/$target_device" <<__EOF__
1M,$first_part_size,$first_part_type
,,linux
__EOF__

target_partitions="$(lsblk --list --noheadings -o PATH "/dev/$target_device")"
target_partition1="$(echo "$target_partitions" | sed -n '2p')"
target_partition2="$(echo "$target_partitions" | sed -n '3p')"

# format and mount partitions
mkfs.btrfs -f --quiet "$target_partition2"
mount "$target_partition2" /mnt
if [ -d /sys/firmware/efi ]; then
	mkfs.fat -F 32 "$target_partition1"
	mkdir -p /mnt/boot/efi
	mount "$target_partition1" /mnt/boot/efi
else
	case "$arch" in
	amd64|i386) ;;
	ppc64el) ;;
	*)
		mkfs.ext2 "$target_partition1"
		mkdir /mnt/boot
		mount "$target_partition1" /mnt/boot
		;;
	esac
fi

mnt_debootstrap
mnt_install

echo; echo -n "installation completed successfully"
answer="$(printf "no\nyes" | fzy -p "reboot the system? ")"
[ "$answer" = yes ] || reboot
