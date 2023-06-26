apt-get -qq install sway swayidle i3status fonts-fork-awesome grim wl-clipboard xwayland \
	fuzzel hicolor-icon-theme foot

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

cat <<'__EOF__' > /usr/local/share/sway-session.sh
printf 'lock\nsuspend\nexit\nreboot\npoweroff' | {
	swaymsg '[workspace=__focused__] opacity 0.5; mode session_manager' > /dev/null 2>&1
	fuzzel --dmenu --config=/usr/local/share/fuzzel.ini 
	swaymsg '[workspace=__focused__] opacity 1; mode default' > /dev/null 2>&1
} | {
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

cat <<'__EOF__' > /usr/local/share/sway-apps.sh
swaymsg '[workspace=__focused__] opacity 0.5; mode app_launcher'
fuzzel --launch-prefix=/usr/local/bin/sway-apps --config=/usr/local/share/fuzzel.ini
swaymsg '[workspace=__focused__] opacity 1; mode default'
__EOF__

cat <<'__EOF__' > /usr/local/bin/sway-apps
#!/bin/sh
workspace_name="$(echo -n "$1" | md5sum)"
swaymsg workspace "$workspace_name"
swaymsg "[con_id=__focused__] focus" ||
	swaymsg exec "$@; swaymsg \"[workspace=$workspace_name] kill\""
__EOF__
chmod +x /usr/local/bin/sway-apps

echo -n 'font=sans:size=12.5
prompt=" "
terminal=foot
horizontal-pad=20
vertical-pad=20
image-size-ratio=0
line-height=38
layer=overlay
[border]
width=0
radius=0
[colors]
background=222222ff
text=eeeeeeff
match=eeeeeeff
selection=4285F4dd
selection-text=ffffffff
selection-match=ffffffff
' > /usr/local/share/fuzzel.ini

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

mkdir -p /usr/local/share/icons/hicolor/scalable/apps
echo -n '<?xml version="1.0" encoding="UTF-8"?>
<svg height="128px" viewBox="0 0 128 128" width="128px">
	<linearGradient id="a" gradientUnits="userSpaceOnUse" x1="11.999989" x2="115.999989" y1="64" y2="64">
		<stop offset="0" stop-color="#3d3846"/>
		<stop offset="0.05" stop-color="#77767b"/>
		<stop offset="0.1" stop-color="#5e5c64"/>
		<stop offset="0.899999" stop-color="#504e56"/>
		<stop offset="0.95" stop-color="#77767b"/>
		<stop offset="1" stop-color="#3d3846"/>
	</linearGradient>
	<linearGradient id="b" gradientUnits="userSpaceOnUse" x1="12" x2="112.041023" y1="60" y2="80.988281">
		<stop offset="0" stop-color="#77767b"/>
		<stop offset="0.384443" stop-color="#9a9996"/>
		<stop offset="0.720567" stop-color="#77767b"/>
		<stop offset="1" stop-color="#68666f"/>
	</linearGradient>
	<path d="m 20 22 h 88 c 4.417969 0 8 3.582031 8 8 v 78 c 0 4.417969 -3.582031 8 -8 8 h -88 c -4.417969 0 -8 -3.582031 -8 -8 v -78 c 0 -4.417969 3.582031 -8 8 -8 z m 0 0" fill="url(#a)"/>
	<path d="m 20 12 h 88 c 4.417969 0 8 3.582031 8 8 v 80 c 0 4.417969 -3.582031 8 -8 8 h -88 c -4.417969 0 -8 -3.582031 -8 -8 v -80 c 0 -4.417969 3.582031 -8 8 -8 z m 0 0" fill="url(#b)"/>
	<path d="m 20 14 h 88 c 3.3125 0 6 2.6875 6 6 v 80 c 0 3.3125 -2.6875 6 -6 6 h -88 c -3.3125 0 -6 -2.6875 -6 -6 v -80 c 0 -3.3125 2.6875 -6 6 -6 z m 0 0" fill="#241f31"/>
	<g fill="#62c9ea">
		<path d="m 46.011719 40.886719 l -14.011719 -7.613281 v 4.726562 l 9.710938 4.628906 v 0.144532 l -9.710938 5.226562 v 4.726562 l 14.011719 -8.210937 z m 0 0"/>
		<path d="m 50 56 v 4 h 16 v -4 z m 0 0"/>
	</g>
</svg>
' > /usr/local/share/icons/hicolor/scalable/apps/terminal.svg
