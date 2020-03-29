#!/bin/sh
# This script is designed to create an SSL certificate for use with Apache.
# The generated cert can then be sent out for signing or used as self-signed.

# CONSTANTS
SYSTEM_CERT_OUTPUT_DIR="/etc/pki/tls"

# GLOBALS
CERT_OUTPUT_DIR="${SYSTEM_CERT_OUTPUT_DIR}"
CERT_OUTPUT_FILENAME="ca"
CERT_EXPIRATION_DAYS="730"

CERT_COUNTRY=""
CERT_STATE=""
CERT_LOCATION=""
CERT_ORGANIZATION=""
CERT_ORGANIZATION_UNIT=""
CERT_COMMON_NAME=""

usage() {
	echo "Usage:"
	echo "  $0 [OPTIONS]"
	echo "     <[-c|--country] COUNTRY CODE> <[-st|--state] STATE> <[-l|--location] LOCATION> <[-o|--organization] ORGANIZATION>"
	echo "     <[-ou|--organization-unit] ORGANIZATION UNIT> <[-cn|--common-name] COMMON NAME>"
	echo "     <[-d|--output-dir] OUTPUT DIRECTORY> <[-f|--filename] FILE NAME> <[-x|--expiration] DAYS> <[-h|--help]>"
	echo 
	echo "  <[-c|--country] COUNTRY CODE> is the two digit country code used for generating the certificate"
	echo "         For example, \"US\""
	echo "  <[-st|--state] STATE> is the two digit state used for generating the certificate"
	echo "         For example, \"CA\""
	echo "  <[-l|--location] LOCATION> is the location of the company used for generating the certificate"
	echo "         For example, \"Palo Alto\""
	echo "  <[-o|--organization] ORGANIZATION> is the company name used for generating the certificate"
	echo "         For example, \"Example, Inc.\""
	echo "  <[-ou|--organization-unit] ORGANIZATION UNIT> is the unit of the company used for generating the certificate"
	echo "         For example, \"Technology Division\""
	echo "  <[-cn|--common-name] COMMON NAME> is the common name (server name) used for generating the certificate"
	echo "         For example, \"example.com\""
	echo "  <[-d|--output-dir] OUTPUT DIRECTORY> is the folder where the generated certificates are stored"
	echo "         By default it is ${CERT_OUTPUT_DIR}"
	echo "  <[-f|--filename] FILE NAME> is the name of the files generated"
	echo "         By default it is ${CERT_OUTPUT_FILENAME}"
	echo "  <[-x|--expiration]> is the number of days the certificate will be valid for"
	echo "         By default it is ${CERT_EXPIRATION_DAYS}"
	echo "  <[-h|--help]> displays this help file"
	exit 0
}

error(){
	echo "$0"
	exit 1
}

read_options() {
	while [ $# -gt 0 ]
	do
		case $1 in
		-c|--country)
			shift 1
			if [ $# -gt 0 ]
			then
				CERT_COUNTRY=$1
				shift 1
			else
				error "COUNTRY not defined."
			fi
			;;
		-st|--state)
			shift 1
			if [ $# -gt 0 ]
			then
				CERT_STATE=$1
				shift 1
			else
				error "STATE not defined."
			fi
			;;
		-l|--location)
			shift 1
			if [ $# -gt 0 ]
			then
				CERT_LOCATION=$1
				shift 1
			else
				error "LOCATION not defined."
			fi
			;;
		-o|--organization)
			shift 1
			if [ $# -gt 0 ]
			then
				CERT_ORGANIZATION=$1
				shift 1
			else
				error "ORGANIZATION not defined."
			fi
			;;
		-ou|--organization-unit)
			shift 1
			if [ $# -gt 0 ]
			then
				CERT_ORGANIZATION_UNIT=$1
				shift 1
			else
				error "ORGANIZATION UNIT not defined."
			fi
			;;
		-cn|--common-name)
			shift 1
			if [ $# -gt 0 ]
			then
				CERT_COMMON_NAME=$1
				shift 1
			else
				error "COMMON NAME not defined."
			fi
			;;
		-d|--output-dir)
			shift 1
			if [ $# -gt 0 ]
			then
				CERT_OUTPUT_DIR=$1
				shift 1
			else
				error "OUTPUT DIR not defined."
			fi
			;;
		-f|--filename)
			shift 1
			if [ $# -gt 0 ]
			then
				CERT_OUTPUT_FILENAME=$1
				shift 1
			else
				error "FILENAME not defined."
			fi
			;;
		-x|--expiration)
			shift 1
			if [ $# -gt 0 ]
			then
				CERT_EXPIRATION_DAYS=$1
				shift 1
			else
				error "EXPIRATION not defined."
			fi
			;;
		-\?|-h|--help)
			shift 1
			if [ $# -gt 0 ]
			then
				usage
				exit 0
			fi
			;;
		*)
			echo "Unrecognized option $1"
			usage
			exit 1
		esac
	done
}

check_root_user(){
	if [[ $EUID -ne 0 ]]
	then
		echo "This script must be run as a root user."
		exit 1
	fi
}


# Main starts here
read_options $@

# Check if the script is installing these directly to the pki directory
if [[ "$CERT_OUTPUT_DIR" == "$SYSTEM_CERT_OUTPUT_DIR" ]]
then 
	# If this is being installed to the system, check to make sure we are running as root user
	check_root_user
fi

# Generate the output folders if they don't exist
if [[ ! -e "$CERT_OUTPUT_DIR/certs" ]]
then
	mkdir -p "$CERT_OUTPUT_DIR/certs"
fi

if [[ ! -e "$CERT_OUTPUT_DIR/private" ]]
then
	mkdir -p "$CERT_OUTPUT_DIR/private"
fi

# Generate an 2048 bit RSA certificate with a password of 'password'
echo "Generating RSA Certificate..."
openssl genrsa -aes256 -passout pass:password 2048 > $CERT_OUTPUT_DIR/private/$CERT_OUTPUT_FILENAME.key
if [ $? != 0 ]
then
	error "Failed to generate the certificate"
fi

# Rip off the password ('password')
echo "Removing certificate password..."
openssl rsa -in $CERT_OUTPUT_DIR/private/$CERT_OUTPUT_FILENAME.key -passin pass:password -out $CERT_OUTPUT_DIR/private/$CERT_OUTPUT_FILENAME.key > /dev/null 2>&1
if [ $? != 0 ]
then
	error "Failed to remove certificate password"
fi

# Generate the key and cert with the info defined in the global variables
echo "Generating certificate and key..."
CERT_PARAMS="/C=$CERT_COUNTRY/ST=$CERT_STATE/L=$CERT_LOCATION/O=$CERT_ORGANIZATION/OU=$CERT_ORGANIZATION_UNIT/CN=$CERT_COMMON_NAME"
openssl req -utf8 -new -subj "$CERT_PARAMS" -key $CERT_OUTPUT_DIR/private/$CERT_OUTPUT_FILENAME.key -out $CERT_OUTPUT_DIR/private/$CERT_OUTPUT_FILENAME.csr > /dev/null 2>&1
if [ $? != 0 ]
then
	error "Failed to generate .csr"
fi

# Set the number of days and self sign the cert
echo "Self-signing certificate..."
openssl x509 -req -days $CERT_EXPIRATION_DAYS -in $CERT_OUTPUT_DIR/private/$CERT_OUTPUT_FILENAME.csr -signkey $CERT_OUTPUT_DIR/private/$CERT_OUTPUT_FILENAME.key -out $CERT_OUTPUT_DIR/certs/$CERT_OUTPUT_FILENAME.crt > /dev/null 2>&1
if [ $? != 0 ]
then
	error "Failed to generate .crt"
fi

# Combine the cert and key into a single file
echo "Creating .pem..."
cat $CERT_OUTPUT_DIR/certs/$CERT_OUTPUT_FILENAME.crt $CERT_OUTPUT_DIR/private/$CERT_OUTPUT_FILENAME.key > $CERT_OUTPUT_DIR/certs/$CERT_OUTPUT_FILENAME.pem
if [ $? != 0 ]
then
	error "Failed to generate .pem"
fi

# If we are on a linux box that has SELinux restore permissions if possible
which restorecon > /dev/null 2>&1
if [ $? != 0 ]
then
	echo "Did not attempt to restore permissions. restorecon is not installed. "
else 
	restorecon -RvF $CERT_OUTPUT_DIR
fi

echo "Done."