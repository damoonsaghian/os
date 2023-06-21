apt-get -qq install dbus-user-session pkexec kbd whois physlock
# kbd is needed for its openvt
# whois is needed for its mkpasswd

cat <<'__EOF__' > /usr/local/bin/chkpasswd
#!/bin/bash
set -e
username="$1"
shift
passwd_hashed="$(sed -n "/$username/p" /etc/shadow | cut -d ':' -f2)"
hash_method="$(echo "$passwd_hashed" | cut -d '$' -f3)"
case "$hash_method" in
	1) hash_method=md5 ;;
	5) hash_method=sha-256 ;;
	6) hash_method=sha-512 ;;
	*) echo "error: password hash type is unsupported"; exit 1 ;;
esac
salt="$(echo "$passwd_hashed" | cut -d '$' -f4)"
echo "$@"
printf "to run above command, enter root password: "
IFS= read -rs entered_passwd
entered_passwd_hashed="$(MKPASSWD_OPTIONS="--method='$hash_method' '$entered_passwd' '$salt'" mkpasswd)"
if [ "$entered_passwd_hashed" = "$passwd_hashed" ]; then
  exit 0
else
  exit 1
fi
__EOF__
chmod +x /usr/local/bin/chkpasswd

echo -n '#!pkexec /bin/sh
set -e
# switch to the first available virtual terminal and ask for root password
# and if successful, run the given command
if openvt -sw -- /usr/local/bin/chkpasswd root "$@"; then
	$@
else
	echo "authentication failure"
fi
' > /usr/local/bin/sudo
chmod +x /usr/local/bin/sudo

echo -n '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE policyconfig PUBLIC "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
	"http://www.freedesktop.org/standards/PolicyKit/1/policyconfig.dtd">
<policyconfig>
	<action id="org.local.pkexec.sudo">
		<description>sudo</description>
		<message>sudo</message>
		<defaults><allow_active>yes</allow_active></defaults>
		<annotate key="org.freedesktop.policykit.exec.path">/bin/sh</annotate>
		<annotate key="org.freedesktop.policykit.exec.argv1">/usr/local/bin/sudo</annotate>
	</action>
</policyconfig>
' > /usr/share/polkit-1/actions/org.local.pkexec.sudo.policy

echo '#!pkexec /bin/sh
set -e
username="$(logname)"
user_vt="$(cat /sys/class/tty/tty0/active | cut -c 4-)"
openvt --switch --console=13 -- sh -c \
	"physlock -l; while ! chkpasswd \"$username\"; do true; done && physlock -L; chvt \"$user_vt\""
' > /usr/local/bin/lock
chmod +x /usr/local/bin/lock

echo -n '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE policyconfig PUBLIC "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
	"http://www.freedesktop.org/standards/PolicyKit/1/policyconfig.dtd">
<policyconfig>
	<action id="org.local.pkexec.lock">
		<description>lock</description>
		<message>lock</message>
		<defaults><allow_active>yes</allow_active></defaults>
		<annotate key="org.freedesktop.policykit.exec.path">/bin/sh</annotate>
		<annotate key="org.freedesktop.policykit.exec.argv1">/usr/local/bin/lock</annotate>
	</action>
</policyconfig>
' > /usr/share/polkit-1/actions/org.local.pkexec.lock.policy

# console level keybinding: when "F8" or "XF86Lock" is pressed: /usr/local/bin/lock

# to prevent BadUSB, when a new input device is connected lock the session
echo 'ACTION=="add", ATTR{bInterfaceClass}=="03" RUN+="/usr/local/bin/lock"' > \
	/etc/udev/rules.d/80-lock-new-hid.rules

echo; echo -n "set username: "
read -r username
groupadd -f netdev; groupadd -f bluetooth
useradd --create-home --groups netdev,bluetooth --shell /bin/bash "$username" || true
echo >> "/home/$username/.bashrc"
cat <<'__EOF__' >> "/home/$username/.bashrc"
export PS1="\e[7m \u@\h \e[0m \e[7m \w \e[0m\n> "
echo "enter \"system\" to configure system settings"
__EOF__

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
