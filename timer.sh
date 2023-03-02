#!/bin/bash

# pesan pembuka
INTERRUPT_MSG="HITUNG MUNDUR BERHENTI !!"
TIMEUP_MSG="WAKTU TELAH HABIS !!!"

# konstanta perhitungan
SEC_PER_MIN=60
SEC_PER_HOUR=`expr $SEC_PER_MIN \* 60`
SEC_PER_DAY=`expr $SEC_PER_HOUR \* 24`
SEC_PER_WEEK=`expr $SEC_PER_DAY \* 7`
PAT_WDHMS="^([0-9]+):([0-9]+):([0-9]+):([0-9]+):([0-9]+)$"
PAT_DHMS="^([0-9]+):([0-9]+):([0-9]+):([0-9]+)$"
PAT_HMS="^([0-9]+):([0-9]+):([0-9]+)$"
PAT_MS="^([0-9]+):([0-9]+)$"
PAT_S="^([0-9]+)$"
NOW=`date +%s`

####################################################################

function show_hint {
	echo "Aturan Penggunaan : $(basename $0) [-f] <duration|-d date> [-q] [-t title] [-m message] [-e command]"
	echo "Contoh :"
	echo "   $(basename $0) 30        # menghitung mundur 30 detik"
	echo "   $(basename $0) 1:20:30   # menghitung mundur 1 jam 20 menit 30 detik"
	echo "   $(basename $0) -d 23:30  # menghitung mundur hingga pukul 11:30 PM"
	echo "Pilihan Perintah :"
	echo "   -f          Menjalankan program secara langsung."
	echo "   -q          Mode diam, tidak menampilkan pesan saat hitung mundur selesai."
	echo "   -t title    Membuat judul, dan tampilkan."
	echo "   -m message  Menunjukkan pesan pada bawah layar."
	echo "   -e command  Menjalankan program sesuai perintah."
}

####################################################################

function print_seconds {
	if [ $# -ne 5 ]; then
		echo "Error: function print_seconds takes 5 parameters"
		exit 1
	fi
	result=`expr $1 \* $SEC_PER_WEEK + $2 \* $SEC_PER_DAY`
	result=`expr $result + $3 \* $SEC_PER_HOUR + $4 \* $SEC_PER_MIN + $5`
	echo $result
}

####################################################################

function correct_date_sec {
	final=$1
	if [ $final -gt 0 ]; then echo $final; return; fi
	final=`expr $1 + $SEC_PER_DAY`
	if [ $final -gt 0 ]; then echo $final; return; fi
	final=`expr $1 + $SEC_PER_WEEK`
	if [ $final -gt 0 ]; then echo $final; return; fi
	echo "0"
}

####################################################################

sec_rem=0
param_prev=""
while [ $# -gt 0 ]; do
	param=$1
	shift
	
	if [ "${param:0:1}" == "-" ]; then
		if [ "$param" == "-f" ]; then
			NO_CONFIRM=true
		elif [ "$param" == "-q" ]; then
			NO_OUTPUT=true
		fi
		param_prev=$param
		continue
	fi
	
	case "$param_prev" in
	-d)
		UNTIL=`date -d "$param" +%s`
		
		if [ $? -ne 0 ]; then
			exit 1
		fi
		
		sec_rem=`expr $UNTIL - $NOW`
		
		if [ $sec_rem -lt 1 ]; then
			sec_rem=`correct_date_sec $sec_rem`
			if [ $sec_rem -lt 1 ]; then
				echo "Error: The date $param is already history."
				exit 1
			fi
			
			if [ -z "$NO_CONFIRM" ]; then
				echo "Warning: The given date is assumed to be: `date -d now\ +$sec_rem\ sec`"
				echo "Place an option -f before -d to suppress this warning"
				read -n 1 -p "Still proceed [Y]/n?" ch
				echo
				if [ "$ch" == "n" ] || [ "$ch" == "N" ]; then
					exit 1
				fi
				ch=""
			fi
		fi
	
		;;
	-t)
		TITLE="$param"
		;;
	-m)
		MESSAGE="$param"
		;;
	-e)
		EXECUTE="$param"
		;;
	*)
	
		if [[ "$param" =~ $PAT_WDHMS ]]; then    # W:D:H:M:S
			sec_rem=`print_seconds ${BASH_REMATCH[1]} ${BASH_REMATCH[2]} ${BASH_REMATCH[3]} \
				${BASH_REMATCH[4]} ${BASH_REMATCH[5]}`
		elif [[ "$param" =~ $PAT_DHMS ]]; then   # D:H:M:S
			sec_rem=`print_seconds 0 ${BASH_REMATCH[1]} ${BASH_REMATCH[2]} ${BASH_REMATCH[3]} \
			${BASH_REMATCH[4]}`
		elif [[ "$param" =~ $PAT_HMS ]]; then    # H:M:S
			sec_rem=`print_seconds 0 0 ${BASH_REMATCH[1]} ${BASH_REMATCH[2]} ${BASH_REMATCH[3]}`
		elif [[ "$param" =~ $PAT_MS ]]; then     # M:S
			sec_rem=`print_seconds 0 0 0 ${BASH_REMATCH[1]} ${BASH_REMATCH[2]}`
		elif [[ "$param" =~ $PAT_S ]]; then      # S
			sec_rem=`print_seconds 0 0 0 0 ${BASH_REMATCH[1]}`
		else
			echo "Error: Incorrect time format: $param"
			exit 1
		fi
		
		;;
	
	esac
	
	param_prev=""

done

####################################################################

if [ $sec_rem -eq 0 ]; then
	show_hint
	exit 1
fi

until_date=`expr $NOW + $sec_rem`

####################################################################

function cleanup_and_exit {
	tput cnorm
	stty echo
	clear
	if [ -z $NO_OUTPUT ] && [ ! -z "$2" ]; then
		echo $2
	fi
	
	if [ $1 -eq 0 ] && [ ! -z "$EXECUTE" ]; then
		eval $EXECUTE
	fi

	exit $1
}
trap 'cleanup_and_exit 1 "$INTERRUPT_MSG"' INT

####################################################################

clear
tput civis
stty -echo

while [ 0 -eq 0 ]; do
	
	sec_rem=`expr $until_date - $(date +%s)`
	if [ $sec_rem -lt 1 ]; then
		break
	fi

	if [ -z "$TIMEOUT_DATE" ]; then
		TIMEOUT_DATE=`date -d "now +$sec_rem sec"`
	fi
	
	interval=$sec_rem
	seconds=`expr $interval % 60`
	interval=`expr $interval - $seconds`
	minutes=`expr $interval % 3600 / 60`
	interval=`expr $interval - $minutes`
	hours=`expr $interval % 86400 / 3600`
	interval=`expr $interval - $hours`
	days=`expr $interval % 604800 / 86400`
	interval=`expr $interval - $hours`
	weeks=`expr $interval / 604800`
	
    echo "+==============================================+"
    echo "|Program dibuat oleh : Risnaldy Novendra Irawan|"
    echo "|NPM                 : 20083010017             |"
    echo "|Jurusan             : Sains Data              |"
    echo "+==============================================+"
    echo " "
	if [ ! -z "$TITLE" ]; then
		echo "$TITLE"
    fi
    echo "+---------------------------------------------------------+"
	echo "Waktu Saat ini         : $(date)                           "
	echo "Estimasi Waktu Selesai : $TIMEOUT_DATE                     "
    echo "+---------------------------------------------------------+"
    echo " "
	echo "+----------------------------+"
	echo "Minggu:    $weeks             "
	echo "Hari:      $days              "
	echo "Jam:       $hours             "
	echo "Menit:     $minutes           "
	echo "Detik:     $seconds           "
	echo "+----------------------------+"
	if [ ! -z "$EXECUTE" ]; then
		echo "Programs to execute on timeup:"
		echo " $EXECUTE"
		echo
	fi
	echo "tekan [q] untuk keluar dari program  "
	echo "                                     "
	if [ ! -z "$MESSAGE" ]; then
		echo "$MESSAGE"
	fi
	
	tput home
	
	read -n 1 -t 0.9 ch
	if [ "$ch" == "q" ]; then
		cleanup_and_exit 1 "$INTERRUPT_MSG"
	fi
	
done

cleanup_and_exit 0 "$TIMEUP_MSG"
