#!/bin/bash
# from https://github.com/kylemanna/docker-openvpn

OVPN_DATA="ovpn-data-russian-vpn"
OVPN_CLIENT_FILE_PREFIX="russian-vpn"
OVPN_NAME="open-vpn"
DOMAIN_NAME="russian-vpn.atrapeznikov.me"

function show_help() {
	SCRIPT_NAME=$(basename "$0")
	echo "Usage: $SCRIPT_NAME [setup|teardown|generateuser|deleteuser|--help]"
	echo
	echo "Options:"
	echo "  setup               - Creates, inits and runs OVPN"
	echo "  teardown            - Stops and deletes all resources"
	echo "  generateuser <user> - Generates cerificate for a new user and saves its .ovpn file"
        echo "  deleteuser <user>   - Deletes user's certificate"	
	echo "  --help"
}

function setup() {
	echo "Generating docker volume $OVPN_DATA"
	docker volume create --name $OVPN_DATA

	# generate initial config for openvpn
	echo "Running generate initial config"
	docker run -v $OVPN_DATA:/etc/openvpn --rm kylemanna/openvpn ovpn_genconfig -u udp://$DOMAIN_NAME -D
	
	# generate this will pass phrase
	echo "Run creatint secret passphrase"
	docker run -v $OVPN_DATA:/etc/openvpn --rm -it kylemanna/openvpn ovpn_initpki
	
	# run ovpn server container
	echo "Run OVPN container $OVPN_NAME"
	docker run -v $OVPN_DATA:/etc/openvpn --name $OVPN_NAME -d -p 1194:1194/udp --cap-add=NET_ADMIN --restart=always kylemanna/openvpn
}

function generate_user() {
	USER=$1
	
	echo "Generating new client certificate for user $USER"
	docker run -v $OVPN_DATA:/etc/openvpn --rm -it kylemanna/openvpn easyrsa build-client-full $USER nopass

	USER_FILE="$OVPN_CLIENT_FILE_PREFIX-$USER.ovpn"
	
	echo "Saving certificate file to $USER_FILE"
	docker run -v $OVPN_DATA:/etc/openvpn --rm kylemanna/openvpn ovpn_getclient $USER > $USER_FILE 

}

function delete_user() {
	USER=$1
	
	echo "Deleting client certificate for user $USER"
	docker run -it -v $OVPN_DATA:/etc/openvpn --rm kylemanna/openvpn ovpn_revokeclient $USER 
}

function all_users() {
	echo "Getting list of all users"
	docker run -it -v $OVPN_DATA:/etc/openvpn --rm kylemanna/openvpn ovpn_getclient_all
}


function teardown() {
	echo "Stop docker container $OVPN_NAME"
	docker container stop $OVPN_NAME
	docker container rm $OVPN_NAME

	echo "Delete docker volume $OVPN_DATA"
	docker volume rm $OVPN_DATA
}

# Check number of args
if [ $# -eq 0 ]; then
    show_help
    exit 1
fi

case "$1" in
    setup)
        echo "Running setup..."
	setup
        ;;
    teardown)
        echo "Running teardown..."
	teardown
        ;;
    generateuser)
	echo "Running generate user"
	generate_user $2
	;;
    deleteuser)
	echo "Running delete user"
	delete_user $2
	;;
    users)
	echo "Running all users"
	all_users
	;;
    --help)
        show_help
        ;;
    *)
        show_help
        exit 1
        ;;
esac
