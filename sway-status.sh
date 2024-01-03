graph() {
	local graph= foreground_color=
	local percentage="$1"
	local percentage_average="$2"
	
	graph="$(echo "▁ ▁ ▂ ▃ ▄ ▅ ▅ ▆ ▇ ▇ █" | cut -d " " -f $(( percentage/10 + 1 )))"
	
	underline='underline="low" underline_color="#000000"'
	
	if [ "$percentage_average" -gt 90 ]; then
		echo "<span foreground=\"#ff0000\" background=\"#4d4d4d\" $underline>$graph</span>"
	elif [ "$percentage_average" -gt 80 ]; then
		echo "<span foreground=\"#ffff00\" background=\"#4d4d4d\" $underline>$graph</span>"
	elif [ "$percentage" -gt 5 ] || [ "$percentage_average" -gt 10 ]; then
		echo "<span background=\"#4d4d4d\" $underline>$graph</span>"
	else
		echo "<span foreground=\"#4d4d4d\" background=\"#4d4d4d\" $underline>$graph</span>"
	fi
}

last_time=0
cpu_usage_average=0
mem_usage_average=0
last_internet_total=0
last_internet_total=0
internet_speed_average=0

i3status -c /usr/local/share/i3status.conf | \
while IFS="|" read -r cpu_usage mem_usage bat_i3s wifi_i3s audio_i3s scrrec time_i3s; do
	time=$(date +%s)
	interval=$(( time - last_time ))
	[ $interval = 0 ] && {
		s="<span color='#000000'> | </span>"
		echo "$s$cpu$mem$s$disk$backup$pm$bat$s$gnunet$internet$s$wifi$cell$blt$audio$mic$cam$scr$time_i3s"
		continue
	}
	last_time=$time
	# last'minute average factor
	lmaf=$(( 60 / interval ))
	
	cpu_usage="$(echo $cpu_usage | cut -d % -f 1 | cut -d . -f 1 | sed 's/^0*//')"
	[ -z "$cpu_usage" ] && cpu_usage=0
	cpu="$(graph "$cpu_usage" "$(( cpu_usage_average/100 ))")"
	cpu_usage_average=$(( (cpu_usage*100 + cpu_usage_average*lmaf) / (lmaf+1) ))
	
	mem_usage="$(echo $mem_usage | cut -d % -f 1 | cut -d . -f 1 | sed 's/^0*//')"
	[ -z "$mem_usage" ] && mem_usage=0
	mem="$(graph "$mem_usage" "$(( mem_usage_average/100 ))")"
	mem_usage_average=$(( (mem_usage*100 + mem_usage_average*lmaf) / (lmaf+1) ))
	
	disk=
	# if writing to disk, disk_w=30
	# if reading from disk, disk_r=30
	# https://packages.debian.org/sid/sysstat
	# https://unix.stackexchange.com/questions/55212/how-can-i-monitor-disk-io
	if [ -n "$disk_w" ]; then
		if [ "$disk_w" -eq 30 ]; then
			disk="<span color='#000000'> | </span><span foreground=\"red\"></span>"
		else
			disk="<span color='#000000'> | </span><span foreground=\"#ffcccc\"></span>"
		fi
		disk_w=$(( disk_w - interval ))
		[ "$disk_w" -le 1 ] && disk_w=""
	fi
	if [ -n "$disk_r" ]; then
		if [ "$disk_r" -eq 30 ]; then
			disk="<span color='#000000'> | </span><span foreground=\"#0099ff\"></span>"
			[ "$disk_w" -eq 28 ] && disk="<span foreground=\"#ff00ff\"></span>"
		else
			disk="<span color='#000000'> | </span><span foreground=\"#ccffff\"></span>"
			[ -n "$disk_w" ] && disk="<span foreground=\"#ffccff\"></span>"
		fi
		disk_r=$(( disk_r - interval ))
		[ "$disk_r" -le 1 ] && disk_r=""
	fi
	
	# backup (sync) indicator: in'progress, completed
	# "<span color='#000000'> | </span>"
	backup=
	
	# system upgrade indicator: in'progress (red), system upgraded (green)
	# show a notification if upgrade failed
	# https://github.com/enkore/i3pystatus/wiki/Restart-reminder
	# "<span color='#000000'> | </span>"
	pm=
	
	if [ "$bat_i3s" = null ]; then
		bat=""
	else
		bat_status="$(echo "$bat_i3s" | cut -d ":" -f 1)"
		bat_percentage="$(echo "$bat_i3s" | cut -d ":" -f 2 | sed 's/^ *//')"
		bat="$(echo "          " | cut -d " " -f $(( bat_percentage/10 + 1 )))"
		bat="<span color='#000000'> | </span>$bat"
		[ "$bat_percentage" -lt 10 ] && bat="<span foreground=\"yellow\">$bat</span>"
		[ "$bat_percentage" -lt 5 ] && bat="<span foreground=\"red\">$bat</span>"
		[ "$bat_status" = CHR ] && bat="<span foreground=\"green\">$bat</span>"
	fi
	
	# "$gnunet_total  $gnunet_speed<span color='#000000'> | </span>"
	gnunet=
	
	# show the download/upload speed, plus total rx/tx since boot
	active_net_device="$(networkctl list | grep routable | { read -r _ net_dev _; echo $net_dev; })"
	[ -n "$active_net_device" ] && {
		read -r internet_rx < "/sys/class/net/$active_net_device/statistics/rx_bytes"
		read -r internet_tx < "/sys/class/net/$active_net_device/statistics/tx_bytes"
		internet_total=$(( (internet_rx + internet_tx)/100000 ))
		
		internet_speed=$(( (internet_total - last_internet_total) / interval ))
		last_internet_total=$internet_total
		
		# if there was network activity in the last 60 seconds, set color to green
		internet_speed_average=$(( (internet_speed + internet_speed_average*lmaf) / (lmaf+1) ))
		[ "$internet_speed_average" = 0 ] || internet_icon_foreground_color="foreground=\"green\""
		
		# each 20 seconds check for online status
		internet_online=1
		[ "$internet_online" = 0 ] && internet_icon_foreground_color='foreground="red"'
		
		internet_speed="$(( internet_speed/10 )).$(( internet_speed%10 ))"
		internet_total="$(( internet_total/10000 )).$(( (internet_total/1000)%10 ))"
		internet="$internet_total<span $internet_icon_foreground_color>  </span>$internet_speed"
	}
	
	if [ "$wifi_i3s" = null ]; then
		wifi=""
	elif [ "$wifi_i3s" -lt 25 ]; then
		wifi="<span foreground=\"#ff0000\"></span><span color='#000000'> | </span>"
	elif [ "$wifi_i3s" -lt 50 ]; then
		wifi="<span foreground=\"#ff7700\"></span><span color='#000000'> | </span>"
	elif [ "$wifi_i3s" -lt 75 ]; then
		wifi="<span foreground=\"#ffff00\"></span><span color='#000000'> | </span>"
	else
		wifi="<span color='#000000'> | </span>"
	fi
	
	# cell: "<span color='#000000'> | </span>"
	
	# bluetooth: "<span color='#000000'> | </span>"
	blt=
	
	audio_out_dev="$(echo "$audio_i3s" | cut -d ":" -f 1)"
	if [ "$audio_out_dev" = "Dummy Output" ]; then
		audio=""
	else
		audio_out_vol="$(echo "$audio_i3s" | cut -d ":" -f 2 | sed 's/^ *//' | cut -d % -f 1 | sed 's/^0*//')"
		[ -z "$audio_out_vol" ] && audio_out_vol=0
		if [ "$audio_out_vol" -eq 100 ]; then
			audio="<span color='#000000'> | </span>"
		elif [ "$audio_out_vol" -eq 0 ]; then
			audio="<span color='#000000'> | </span>"
		elif [ "$audio_out_vol" -lt 10 ]; then
			audio="<span foreground=\"red\"></span><span color='#000000'> | </span>"
		elif [ "$audio_out_vol" -lt 20 ]; then
			audio="<span foreground=\"#ffffcc\"></span><span color='#000000'> | </span>"
		elif [ "$audio_out_vol" -lt 50 ]; then
			audio="<span foreground=\"#ffffcc\"></span><span color='#000000'> | </span>"
		else
			audio="<span foreground=\"#ffffcc\"></span><span color='#000000'> | </span>"
		fi
	fi
	
	# mic: "<span color='#000000'> | </span>"
	# visible only when it's active; green if volume is full, yellow and red if volume is low
	# mic muted: "<span color='#000000'> | </span>"
	# https://github.com/xenomachina/i3pamicstatus
	#audio_In_dev=
	#[ "$audio_In_dev" = "Dummy Input" ] && mic=""
	
	# cam: "<span foreground=\"green\"></span><span color='#000000'> | </span>"
	# visible only when it's active
	cam=""
	
	# screen recording indicator:
	scr=""
	[ "$scrrec" = yes ] && scr="<span foreground=\"red\">⬤</span><span color='#000000'> | </span>"
	
	s="<span color='#000000'> | </span>"
	echo "$s$cpu$mem$disk$backup$pm$bat$s$gnunet$internet$s$wifi$cell$blt$audio$mic$cam$scr$time_i3s" \
	|| exit 1
done
