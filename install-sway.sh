apt-get -qq install sway swayidle xwayland i3status fonts-fork-awesome fuzzel hicolor-icon-theme foot

# this way, Sway's config can't be changed by a normal user
# it means that, swayidle can't be disabled by a normal user (see sway.conf)
echo -n '# run sway (if this script is not called by root or a display manager, and this is the first tty)
if [ ! "$(id -u)" = 0 ] && [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
	[ -f "$HOME/.profile" ] && . "$HOME/.profile"
	exec sway -c /usr/local/share/sway.conf
fi
' > /etc/profile.d/zz-sway.sh

cp /mnt/sway.conf /mnt/sway-status.sh /usr/local/share/

echo -n 'workspace_name="$(swaymsg -p -t get_workspaces | grep "(focused)" | cut -d " " -f 2)"
swaymsg "rename workspace \"$workspace_name\" to 1; rename workspace 1 to \"$workspace_name\""
' > /usr/local/share/sway-preswitch.sh

echo -n 'general {
	output_format = "none"
	interval = 2
	separator="|"
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
	format = "%Y-%m-%d %a %p %I:%M"
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
# "https://github.com/iaolo/iA-Fonts/tree/master/iA%20Writer%20Quattro"
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

echo -n 'font=sans:size=12.5
prompt=" "
fields=name
terminal=foot
horizontal-pad=20
vertical-pad=20
image-size-ratio=0
line-height=38
layer=overlay
[colors]
background=000000ff
text=eeeeeeff
match=eeeeeeff
selection=4285F4ff
selection-text=ffffffff
selection-match=ffffffff
border=ffffff22
[border]
width=1
radius=0
[key-bindings]
cancel=Control+q Escape
' > /usr/local/share/fuzzel.ini

cat <<'__EOF__' > /usr/local/bin/sway-apps
#!/bin/sh
if [ "$@" = session-manager ]; then
	answer="$(printf "lock\nsuspend\nexit\nreboot\npoweroff" | fuzzel --dmenu --config=/usr/local/share/fuzzel.ini)"
	case $answer in
	lock) /usr/local/bin/lock ;;
	suspend) systemctl suspend ;;
	exit) swaymsg exit ;;
	reboot) systemctl reboot ;;
	poweroff) systemctl poweroff ;;
	esac
else
	swaymsg workspace "w$(echo -n "$@" | cut -d " " -f1 | md5sum | cut -d " " -f1)"
	swaymsg "[con_id=__focused__] focus" || swaymsg exec -- $@
fi
__EOF__
chmod +x /usr/local/bin/sway-apps

mkdir -p /usr/local/share/applications
echo -n '[Desktop Entry]
Type=Application
Name=​session manager
Exec=session-manager
' > /usr/local/share/applications/session-manager.desktop

mkdir -p /usr/local/share/applications
echo -n '[Desktop Entry]
Type=Application
Name=Terminal
Icon=foot
Exec=XDG_CONFIG_HOME=/usr/local/share foot
StartupNotify=true
' > /usr/local/share/applications/terminal.desktop
echo -n '[Desktop Entry]
Name=Foot
Type=Application
Exec=foot
NoDisplay=true
' > /usr/local/share/applications/foot.desktop
cp /usr/local/share/applications/foot.desktop /usr/local/share/applications/footclient.desktop
cp /usr/local/share/applications/foot.desktop /usr/local/share/applications/foot-server.desktop

cat <<'__EOF__' > /usr/local/share/foot/foot.ini
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
background=000000
foreground=EEEEEE
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
