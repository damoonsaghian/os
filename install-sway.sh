apt-get -qq install sway swayidle i3status fonts-fork-awesome grim wl-clipboard xwayland tofi foot

echo -n '# run sway (if this script is not called by a display manager, and this is the first tty)
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
	[ -f "$HOME/.profile" ] && . "$HOME/.profile"
	exec sway -c /usr/local/share/sway.conf
fi
' > /etc/profile.d/zz-sway.sh
# this way, sway config can't be changed by a normal user

cp /mnt/sway.conf /mnt/sway-status.sh /usr/local/share/

echo -n 'general {
	output_format = "none"
	interval = 2
}
order += "cpu_usage"
order += "memory"
order += "battery all"
order += "wireless _first_"
order += "volume master"
order += "run_watch scrrec"
order += "time"
cpu_usage {
	format = "%usage"
}
memory {
	format = "%percentage_used"
}
battery all {
	format = "%status: %percentage"
	format_down = "null"
	format_percentage = "%d"
}
wireless _first_ {
	format_up = "%quality"
	format_down = "null"
	format_quality = "%d"
}
volume master {
	format = "%devicename: %volume"
}
run_watch scrrec {
	pidfile = ".cache/screenrec-pid"
	format = "%status"
}
time {
	format = "%Y-%m-%d  %a  %p  %I:%M"
}
' > /usr/local/share/i3status.conf

# mono'space fonts:
# , wide characters are forced to squeeze
# , narrow characters are forced to stretch
# , bold characters don’t have enough room
# proportional font for code:
# , generous spacing
# , large punctuation
# , and easily distinguishable characters
# , while allowing each character to take up the space that it needs
# "https://input.djr.com/"
apt-get -qq install fonts-noto-core fonts-hack
mkdir -p /etc/fonts
echo -n '<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
	<selectfont>
		<rejectfont>
			<pattern><patelt name="family"><string>NotoNastaliqUrdu</string></patelt></pattern>
			<pattern><patelt name="family"><string>NotoKufiArabic</string></patelt></pattern>
			<pattern><patelt name="family"><string>NotoNaskhArabic</string></patelt></pattern>
		</rejectfont>
	</selectfont>
	<alias>
		<family>serif</family>
		<prefer><family>NotoSerif</family></prefer>
	</alias>
	<alias>
		<family>sans</family>
		<prefer><family>NotoSans</family></prefer>
	</alias>
	<alias>
		<family>monospace</family>
		<prefer><family>Hack</family></prefer>
	</alias>
</fontconfig>
' > /etc/fonts/local.conf

# app launcher
# this is not the right way; there is no way to get the app name, hence the bad hack for "app_name"
# find a better solution
# https://github.com/Biont/sway-launcher-desktop/blob/master/sway-launcher-desktop.sh
cat <<'__EOF__' > /usr/local/share/sway-apps.sh
swaymsg mode apps
app_exec="$(tofi-drun --config=/usr/local/share/tofi.cfg)"
swaymsg mode default
app_name="$(echo "$app_exec" | cut -d " " -f1)"
app_name="$(basename "$app_name")"
cleanup_workspace="swaymsg [workspace=\"$app_name\"] kill"
swaymsg workspace "$app_name"
swaymsg [con_id=__focused__] focus || swaymsg exec "$app_exec; $cleanup_workspace"
__EOF__

cat <<'__EOF__' > /usr/local/share/sway-session.sh
printf 'lock\nsuspend\nexit\nreboot\npoweroff' | tofi --config=/usr/local/share/tofi.cfg | {
	read answer
	case $answer in
	lock) /usr/local/bin/lock ;;
	suspend) systemctl suspend ;;
	exit) swaymsg exit ;;
	reboot) systemctl reboot ;;
	poweroff) systemctl poweroff ;;
	esac
}
__EOF__

echo -n 'drun-launch = false
terminal = foot
history = false
font = sans
font-size = 18
text-color = eeeeee
background-color = 222222
selection-color = 4285F4
prompt-text = ""
text-cursor = true
width = 40%
height = 70%
border-width = 1
border-color = 4285F4
outline-width = 0
' > /usr/local/share/tofi.cfg

#= terminal
echo -n '#!/bin/sh
footclient --no-wait || foot
' > /usr/local/bin/terminal
chmod +x /usr/local/bin/terminal

mkdir -p /usr/local/share/applications
echo -n '[Desktop Entry]
Type=Application
Name=Terminal
Icon=terminal
Exec=/usr/local/bin/terminal
StartupNotify=true
' > /usr/local/share/applications/terminal.desktop
echo -n '[Desktop Entry]
Name=Foot
Exec=foot
NoDisplay=true
' > /usr/local/share/applications/foot.desktop
cp /usr/local/share/applications/foot.desktop /usr/local/share/applications/footclient.desktop
cp /usr/local/share/applications/foot.desktop /usr/local/share/applications/foot-server.desktop

cat <<'__EOF__' > /usr/local/share/foot.ini
font=monospace:size=10
[scrollback]
indicator-position=none
[cursor]
blink=yes
[key-bindings]
scrollback-up-page = Page_Up
scrollback-down-page = Page_Down
clipboard-copy = Control+c XF86Copy
clipboard-paste = Control+v XF86Paste
spawn-terminal = Control+n
search-start = Control+f
[search-bindings]
cancel = Escape
commit = none
find-next = Return
find-prev = Shift+Return
extend-to-next-whitespace = Shift+space
[text-bindings]
# make escape to act like ctrl+c
\x03 = Escape
[colors]
background=222222
foreground=eeeeee
regular0=403E41
regular1=FF6188
regular2=A9DC76
regular3=FFD866
regular4=FC9867
regular5=AB9DF2
regular6=78DCE8
regular7=FCFCFA
bright0=727072
bright1=FF6188
bright2=A9DC76
bright3=FFD866
bright4=FC9867
bright5=AB9DF2
bright6=78DCE8
bright7=FCFCFA
selection-background=555555
selection-foreground=dddddd
__EOF__
