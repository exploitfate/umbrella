#!/usr/bin/env bash

export LC_ALL=C

# if you supply an alternate csv through domain_list_url you may need
# to adjust this value
csv_column="2"

# the dig flag list we'll be forming our queries with
# add to this all you want
# see "man dig" for more info
dig_flags="+multiline +noall +nocmd +noidnin +noidnout" # To dump response add " +answer"

# more information about the following list is available at
# http://s3-us-west-1.amazonaws.com/umbrella-static/index.html
domain_list_url="http://s3-us-west-1.amazonaws.com/umbrella-static/top-1m.csv.zip"

# it would be thoroughly irresponsible to point this at anything you
# don't own
resolver_address="10.1.0.1"

# resolver listening port
# using the unbound listening port by default
resolver_port="53"

# total domains
# the number of unique domains we'll query for, preferably divisible
# by four
# 500 domains is a nice "safe" number
total_domains="200000"

# Use parallel by default
use_parallel="yes"


# root check
root_check() {
	echo -e "checking if the user can obtain root ..."
	if [[ ! $EUID -eq 0 ]];then
		if [[ -x "$(command -v sudo)" ]]; then
			exec sudo bash "$0" "$@"
			exit $?
		else
			echo -e "\e[31;1m\t- please run dns-umbrella as root or install sudo\e[0m\n"
			exit 1
		fi
	fi
	echo -e "\t- done\n"
}

root_check


# create dns-umbrella directory
create_directory() {
        echo -e "checking if the dns-umbrella directory exists ..."
        if [ ! -d /opt/dns-umbrella ]; then
                echo -e "\t- directory not found, creating ..."
                mkdir /opt/dns-umbrella
                echo -e "\t- done\n"
        else
                echo -e "\t- directory already exists, skipping ...\n"
        fi
}

create_directory


# perform cleanup
# previous aborted runs might mess us up, make sure we have a clean
# slate to work with
cleanup() {
        echo "removing unneeded files ..."
	if [ -f /opt/dns-umbrella/top_domains_raw ]; then
		rm /opt/dns-umbrella/top_domains_raw
	fi
	if [ -f /opt/dns-umbrella/domain_list ]; then
		rm /opt/dns-umbrella/domain_list
	fi
	if [ -f /opt/dns-umbrella/dig_commands_main ]; then
		rm /opt/dns-umbrella/dig_commands_main
	fi
	if [ -f /opt/dns-umbrella/dig_commands_split01* ]; then
		rm /opt/dns-umbrella/dig_commands_split*
	fi
	if [ -f /opt/dns-umbrella/dig_commands_custom ]; then
		rm /opt/dns-umbrella/dig_commands_custom
	fi
	echo -e "\t- done\n"
}

cleanup


# download the top domains list
download_list() {
	echo "downloading the top domains list ..."
	if [ ! -f /opt/dns-umbrella/domains_raw ]; then
		echo -e "\tthis may take some time"
		unzip -q -o /opt/dns-umbrella/top-1m.csv.zip -d /opt/dns-umbrella
		sudo rm /opt/dns-umbrella/top-1m.csv.zip
		mv /opt/dns-umbrella/top-1m.csv /opt/dns-umbrella/domains_raw
		echo -e "\t- done\n"
	else
		echo -e "\t- top domains list already exists, skipping ...\n"
	fi
}

download_list


# prepare domains
prepare_domains() {
	echo "preparing the top ${total_domains} domains ..."
	# strip out the top domain entries
	let cut_limit=${total_domains}
	#sed -n -e "1,${cut_limit} p" -e "${cut_limit} q" /opt/dns-umbrella/domains_raw | cat >> /opt/dns-umbrella/top_domains_raw
	cat /opt/dns-umbrella/domains_raw | head -n ${cut_limit} | tee /opt/dns-umbrella/top_domains_raw > /dev/null 2>&1
	echo -e "\t- done\n"
	echo "filtering the domain column from the scv ..."
	# filter out the domain column from the csv
	cut -d , -f ${csv_column} /opt/dns-umbrella/top_domains_raw | tee /opt/dns-umbrella/domain_list > /dev/null 2>&1
	echo -e "\t- done\n"
	echo "building the master list of dig commands ..."
	# build the list of commands that we'll send to our resolver
	sed -e "s/.*/dig ${dig_flags} & @${resolver_address} -p ${resolver_port}/" /opt/dns-umbrella/domain_list | tee /opt/dns-umbrella/dig_commands_main > /dev/null 2>&1
	sed -i 's/\r//g' /opt/dns-umbrella/dig_commands_main
	echo -e "\t- done\n"
}

prepare_domains


# split the dig command list into smaller batches
split_dig_commands() {
	echo "splitting dig commands ..."
	# split into batches
	let split_limit="${total_domains} / 4"
	split -d -l ${split_limit} /opt/dns-umbrella/dig_commands_main /opt/dns-umbrella/dig_commands_split
	echo -e "\t- done\n"
	echo "making split dig command lists exectuable ..."
	# make them executable
	chmod +x /opt/dns-umbrella/dig_commands_split**
	echo -e "\t- done\n"
}


# lets get parallel
run_parallel_dig_commands() {
	echo "running dig commands in parallel ..."
	# use gnu parallel to do exactly what it sounds like
	parallel -u ::: /opt/dns-umbrella/dig_commands_split00 /opt/dns-umbrella/dig_commands_split01 /opt/dns-umbrella/dig_commands_split02 /opt/dns-umbrella/dig_commands_split03
	echo -e "\t- done\n"
}


# we won't use gnu-parallel by default
if [ "${use_parallel}" = "yes" ]; then
	split_dig_commands
	run_parallel_dig_commands
else
	echo "making master dig command list exectuable ..."
	# make them executable
	chmod +x /opt/dns-umbrella/dig_commands_main
	echo -e "\t- done\n"
	echo "running dig commands ..."
	# run dig commands
	/opt/dns-umbrella/dig_commands_main
	echo -e "\t- done\n"
fi


# custom domains
# the user may want to supply their own list of domains to lookup
custom_domains() {
	echo -e "checking if the custom_domains file exists ..."
	if [ -f /opt/dns-umbrella/custom_domains ]; then
		echo -e "\t- custom_domains list found ...\n"
		echo "building custom list of dig commands ..."
		# build the list of commands that we'll send to our resolver
		sed -e "s/.*/dig ${dig_flags} & @${resolver_address} -p ${resolver_port}/" /opt/dns-umbrella/custom_domains | tee /opt/dns-umbrella/dig_commands_custom > /dev/null 2>&1
		echo -e "\t- done\n"
		echo "making custom dig command list exectuable ..."
		# make them executable
		chmod +x /opt/dns-umbrella/dig_commands_custom
		echo -e "\t- done\n"
		echo "running custom dig commands ..."
		# run custom dig commands
		/opt/dns-umbrella/dig_commands_custom
		echo -e "\t- done\n"
	else
		echo -e "\t- custom domains list not found, skipping ...\n"
	fi
}

custom_domains


# cleanup
# comment this out if you want to examine any of the files created during a run
cleanup
