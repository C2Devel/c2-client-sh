#!/bin/bash

uriencode() {
  s="${1//'%'/%25}"
  s="${s//' '/%20}"
  s="${s//'"'/%22}"
  s="${s//'#'/%23}"
  s="${s//'$'/%24}"
  s="${s//'&'/%26}"
  s="${s//'+'/%2B}"
  s="${s//','/%2C}"
  s="${s//'/'/%2F}"
  s="${s//':'/%3A}"
  s="${s//';'/%3B}"
  s="${s//'='/%3D}"
  s="${s//'?'/%3F}"
  s="${s//'@'/%40}"
  s="${s//'['/%5B}"
  s="${s//']'/%5D}"
  printf %s "$s"
}

sha256_hex(){
  a="$@"
  echo -n -e "$a" | openssl dgst -binary -sha256 | od -An -vtx1 | sed 's/[ \n]//g' | sed 'N;s/\n//'
}

sha256_hmac_with_string_key_and_value(){
  KEY=$1
  DATA="$2"
  shift 2
  echo -n -e "$DATA" | openssl dgst -binary -sha256 -hmac "$KEY" | od -An -vtx1 | sed 's/[ \n]//g' | sed 'N;s/\n//'
}

sha256_hmac_with_hex_key_and_value(){
  KEY="$1"
  DATA="$2"
  shift 2
  echo -n -e "$DATA" | openssl dgst -binary -sha256 -mac HMAC -macopt "hexkey:$KEY" | od -An -vtx1 | sed 's/[ \n]//g' | sed 'N;s/\n//'
}


# version
VERSION="2014-10-01"

# host and parsed host
HOST=${EC2_URL/"https://"}
HOST=${HOST/":443"}
IFS='.' read -r -a PARSED_HOST <<< $HOST

# date and datetime
X_AMZ_DATE=$(date -u +%Y%m%d'T'%H%M%S'Z')
REQUEST_DATE=$(printf "${X_AMZ_DATE}" | cut -c 1-8)

# method
METHOD="GET"
#METHOD="POST"

# canonical uri
CANONICAL_URI="/"

# canonical request
args=()
for ((i=2;i<=$#;i++)); do args[$i-2]=$(uriencode "${!i}"); done

tmp_args=()
tmp_args[0]="Action=$1"
tmp_args[1]="Version=$VERSION"
for ((i=0;i<$((${#args[@]}/2));i++)); do tmp_args[$i+2]="${args[i*2]}=${args[i*2+1]}"; done
IFS=$'\n' sorted_args=($(sort <<<"${tmp_args[*]}"))

CANONICAL_QUERY_STRING="${sorted_args[0]}"
for ((i=1;i<${#sorted_args[@]};i++)); do CANONICAL_QUERY_STRING="$CANONICAL_QUERY_STRING&${sorted_args[i]}"; done

# body
BODY=""
if [ "$METHOD" = "POST" ]; then
 BODY="$CANONICAL_QUERY_STRING"
fi

# canonical headers
CANONICAL_HEADERS="host:$HOST\nx-amz-date:$X_AMZ_DATE\n"

# signed headers
SIGNED_HEADERS="host;x-amz-date"

# payload
PAYLOAD=$(sha256_hex $BODY)

# canonical request
CANONICAL_REQUEST="$METHOD\n$CANONICAL_URI\n$CANONICAL_QUERY_STRING\n$CANONICAL_HEADERS\n$SIGNED_HEADERS\n$PAYLOAD"
if [ "$METHOD" = "POST" ]; then
 CANONICAL_REQUEST="$METHOD\n$CANONICAL_URI\n\n$CANONICAL_HEADERS\n$SIGNED_HEADERS\n$PAYLOAD"
fi

# region and service
SERVICE="${PARSED_HOST[0]}"
REGION="${PARSED_HOST[0]}"
if [ "${#PARSED_HOST[@]}" -gt 1 ]; then
 REGION="${PARSED_HOST[1]}"
fi

# credential scope
CREDENTIAL_SCOPE="$REQUEST_DATE/$REGION/$SERVICE/aws4_request"

# string_to_sign
STRING_TO_SIGN="AWS4-HMAC-SHA256\n$X_AMZ_DATE\n$CREDENTIAL_SCOPE\n$(sha256_hex $CANONICAL_REQUEST)"

# signature
K_DATE=$(sha256_hmac_with_string_key_and_value "AWS4$EC2_SECRET_KEY" $REQUEST_DATE)
K_REGION=$(sha256_hmac_with_hex_key_and_value $K_DATE $REGION)
K_SERVICE=$(sha256_hmac_with_hex_key_and_value $K_REGION $SERVICE)
K_SIGNING=$(sha256_hmac_with_hex_key_and_value $K_SERVICE "aws4_request")
SIGNATURE=$(sha256_hmac_with_hex_key_and_value $K_SIGNING $STRING_TO_SIGN)

# scope
SCOPE="$EC2_ACCESS_KEY/$REQUEST_DATE/$REGION/$SERVICE/aws4_request"

# authorization header
AUTH_HEADER="AWS4-HMAC-SHA256 Credential=$SCOPE,SignedHeaders=$SIGNED_HEADERS,Signature=$SIGNATURE"


# run
if [ "$METHOD" = "POST" ]; then
 curl -k -XPOST -H "X-Amz-Date:$X_AMZ_DATE" -H "Authorization:$AUTH_HEADER" -H "Content-Type:application/x-www-form-urlencoded; charset=UTF-8" -H "Content-Length:${#BODY}" -d "$CANONICAL_QUERY_STRING" "$EC2_URL"
else
 curl -k -XGET -H "X-Amz-Date:$X_AMZ_DATE" -H "Authorization:$AUTH_HEADER" "$EC2_URL/?$CANONICAL_QUERY_STRING"
fi
