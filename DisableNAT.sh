#!/bin/sh

# Check if script runs directly after boot. If so, wait for 10 seconds.
uptimeMinutes=`cat /proc/uptime | awk '{print $1}'`
if [ ${uptimeMinutes::-3} -lt 300 ]
	then
		logger "NAT script: Script executed for the 1st time after boot"
		sleep 10
	else
		logger "NAT script: Script executed via cron job"
fi

check_nat() {
	# Check if standard rules exist
    if iptables -t nat -S UBIOS_POSTROUTING_USER_HOOK | grep -e "UBIOS_POSTROUTING_USER_HOOK -o eth8 -m comment --comment 00" -e "UBIOS_POSTROUTING_USER_HOOK -o eth9 -m comment --comment 00" > /dev/null
    then
		# If yes, return true
        return 0
    else
		# If no, return false
        return 1
    fi
}

delete_nat() {
    local deleted=false

	# Iterate and delete all rules that match the criteria
    while iptables -t nat -S UBIOS_POSTROUTING_USER_HOOK | grep -e "UBIOS_POSTROUTING_USER_HOOK -o eth8 -m comment --comment 00" -e "UBIOS_POSTROUTING_USER_HOOK -o eth9 -m comment --comment 00" > /dev/null; do
        iptables -t nat -D UBIOS_POSTROUTING_USER_HOOK 1
        deleted=true
    done

	# Return the status of rule deletion
    if $deleted; then
		logger "Default NAT rules deleted successfully"
        return 0
    else
		logger "Error encountered while deleting rules."
        return 1
    fi
}

# Check if nat rules exist, if yes, delete
check_nat
if [ $? -eq 0 ]; then
    logger "NAT-Script: Default rules found"
    delete_nat
    if [ $? -eq 0 ]; then
        logger "Deleted rules"
    else
        logger "Could not delete NAT Rules."
        exit 1  # Exit script with error 1
    fi
fi

# Check if job exists, if not, make one
if ls /etc/cron.d/DisableNat-v1.2 > /dev/null 2>&1
	then 
		logger "NAT script: Cron job available"
	else
		echo "*/15 * * * * /mnt/data/on_boot.d/DisableNAT-v1.2.sh" > /etc/cron.d/delete-nat
		logger "NAT script: Cron job does not exist and is created"
		/etc/init.d/crond restart
fi
