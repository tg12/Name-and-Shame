#!/bin/bash

#REQUIRED PARAMS (Special characters must be urlencoded.)
username='USERNAME_HERE'
password='PASSWORD_HERE'

#EXTRA OPTIONS
#uagent="Script by tg12r"
sleeptime=0 # seconds between requests
touch "cookie.txt" #create a temp. cookie file

# GRAB LOGIN TOKENS
echo "[+] Fetching twitter.com..." && sleep $sleeptime
initpage=$(curl -s -b "cookie.txt" -c "cookie.txt" -L -A "$uagent" "https://mobile.twitter.com/session/new")
token=$(echo "$initpage" | grep "authenticity_token" | sed -e 's/.*value="//' | cut -d '"' -f 1 | head -n 1)
# LOGIN
echo "[+] Submitting the login form..." && sleep $sleeptime
loginpage=$(curl -s -b "cookie.txt" -c "cookie.txt" -L -A "$uagent" -d "authenticity_token=$token&session[username_or_email]=$username&session[password]=$password&remember_me=1&wfa=1&commit=Log+in" "https://mobile.twitter.com/sessions")
# CHECK IF LOGIN FAILED
[[ "$loginpage" == *"/account/begin_password_reset"* ]] && { echo "[!] Login failed. Exiting."; exit; }
[[ "$loginpage" == *"/account/login_challenge"* ]] && { echo "[!] Login challenge encountered. Exiting."; exit; }
[[ "$loginpage" == *"/account/login_verification"* ]] && { echo "[!] Login verification encountered. Exiting."; exit; }
# GRAB COMPOSE TWEET TOKENS
echo "[+] Getting compose tweet page..." && sleep $sleeptime
composepage=$(curl -s -b "cookie.txt" -c "cookie.txt" -L -A "$uagent" "https://mobile.twitter.com/compose/tweet")

#make the file
grep -E '(BREAK-IN|Invalid user|Failed|refused|Illegal)' /var/log/auth.log | rev | cut -d\  -f4 | rev | sort -u > host.txt
#read the file
while read hostname
do
	IP=$hostname
	REVERSE_IP=$(echo $IP | awk -F "." '{print $4"."$3"."$2"."$1}')
	ASN_INFO=$(dig +short $REVERSE_IP.origin.asn.cymru.com TXT)
	PEER_INFO=$(dig +short $REVERSE_IP.peer.asn.cymru.com TXT)
	NUMBER=$(echo $ASN_INFO | cut -d'|' -f 1 | cut -d'"' -f 2 | cut -d' ' -f 1)
	ASN="AS$NUMBER"
	ASN_REPORT=$(dig +short $ASN.asn.cymru.com TXT)
	SUBNET=$(echo $ASN_INFO | cut -d'|' -f 2)
	COUNTRY=$(echo $ASN_INFO | cut -d'|' -f 3)
	ISSUER=$(echo $ASN_INFO | cut -d'|' -f 4)
	PEERS=$(echo $PEER_INFO | cut -d'|' -f 1 | cut -d'"' -f 2)
	REGISTRY_DATE=$(echo $ASN_REPORT | cut -d'|' -f 4)
	REGISTRANT=$(echo $ASN_REPORT | cut -d'|' -f 5 | cut -d'"' -f 1)

	# Print tab delimited with headers
	#echo "#Query,Subnet,Registrant,AS Number,Country,Issuer,Registry Date,Peer ASNs"
	#echo -e "$IP\t$SUBNET\t$REGISTRANT\t$ASN\t$COUNTRY\t$ISSUER\t$REGISTRY_DATE\t$PEERS"
	#echo -e "$IP\t$SUBNET\t$REGISTRANT\t$ASN\t$COUNTRY\t$ISSUER"

	temp="ATTACK FROM IP: "$IP
	tweet="$temp  WHO:$REGISTRANT"
	echo -e "$tweet"

	if [ $(echo "$tweet" | wc -c) -gt 140 ]; then
        	echo "[FAIL] Tweet must not be longer than 140 chars!" && exit 1
	elif [ "$tweet" == "" ]; then
        	echo "[FAIL] Nothing to tweet. Enter your text as argument." && exit 1
	fi

	# TWEET
	echo "[+] Posting a new tweet: $tweet..." && sleep $sleeptime
	tweettoken=$(echo "$composepage" | grep "authenticity_token" | sed -e 's/.*value="//' | cut -d '"' -f 1 | tail -n 1)
	update=$(curl -s -b "cookie.txt" -c "cookie.txt" -L -A "$uagent" -d "wfa=1&authenticity_token=$tweettoken&tweet[text]=$tweet&commit=Tweet" "https://mobile.twitter.com/compose/tweet")


	#OTHER FUNCTIONALITY ADD TO DODGY ASN FILE
	echo $ASN >> badASNs.txt

done < host.txt

#REMOVE DUPLICATES - SORT OF!!
#sort -u badASNs.txt

#OHTHER FUNCTIONALITY
#while read ASNTOBLOCK
#do
	#echo "DEBUG:" $ASNTOBLOCK
	#ASN=$ASNTOBLOCK; for s in $(whois -H -h riswhois.ripe.net -- -F -K -i $ASN | grep -v "^$" | grep -v "^%" | awk '{ print $2 }' ); do echo "  blocking $s"; sudo iptables -A INPUT -s $s -j REJECT &> /dev/null || sudo ip6tables -A INPUT -s $s -j REJECT; done
#done < badASNs.txt



# GRAB LOGOUT TOKENS
logoutpage=$(curl -s -b "cookie.txt" -c "cookie.txt" -L -A "$uagent" "https://mobile.twitter.com/account")

# LOGOUT
echo "[+] Logging out..." && sleep $sleeptime
logouttoken=$(echo "$logoutpage" | grep "authenticity_token" | sed -e 's/.*value="//' | cut -d '"' -f 1 | tail -n 1)
logout=$(curl -s -b "cookie.txt" -c "cookie.txt" -L -A "$uagent" -d "authenticity_token=$logouttoken" "https://mobile.twitter.com/session/destroy")

#Cleanup after ourselfs
rm "cookie.txt"
rm badASNs.txt host.txt
