apt-get -qq install kbd whois vlock pkexec
# kbd is needed for its openvt
# whois is needed for its mkpasswd

echo '#!/bin/sh
# openvt + vlock -a
' > /usr/local/bin/lock
chmod +x /usr/local/bin/lock

# console level keybinding: when "F8" or "XF86Lock" is pressed: /usr/local/bin/lock

# to prevent BadUSB, when a new input device is connected lock the session
echo 'ACTION=="add", ATTR{bInterfaceClass}=="03" RUN+="/usr/local/bin/lock"' > \
	/etc/udev/rules.d/80-lock-new-hid.rules

echo; echo -n "set username: "
read -r username
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

cat <<'__EOF__' > /usr/local/bin/sudo-chkpasswd
#!/bin/bash
set -e
root_passwd_hashed="$(sed -n '/root/p' /etc/shadow | cut -d ':' -f2)"
hash_method="$(echo "$root_passwd_hashed" | cut -d '$' -f2)"
case "$hash_method" in
	1) hash_method=md5 ;;
	5) hash_method=sha-256 ;;
	6) hash_method=sha-512 ;;
	*) echo "error: password hash type is unsupported"; exit 1 ;;
esac
salt="$(echo "$root_passwd_hashed" | cut -d '$' -f3)"
echo "$@"
printf "to run above command, enter root password: "
IFS= read -rs entered_passwd
entered_passwd_hashed="$(MKPASSWD_OPTIONS="--method='$hash_method' '$entered_passwd' '$salt'" mkpasswd)"
if [ "$entered_passwd_hashed" = "$root_passwd_hashed" ]; then
  exit 0
else
  exit 1
fi
__EOF__
chmod +x /usr/local/bin/sudo-chkpasswd
# https://askubuntu.com/questions/611580/how-to-check-the-password-entered-is-a-valid-password-for-this-user

echo -n '#!pkexec /bin/sh
set -e
# switch to the first available virtual terminal and ask for root password
# and if successful, run the given command
if openvt -sw -- /usr/local/bin/sudo-chkpasswd "$@"; then
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
