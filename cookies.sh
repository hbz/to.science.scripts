#!/bin/bash

# convert cookie string (obtained via browser developer tools and used with wpull) to
# 7-field tab-separated Netscape cookie file format
# Usage:  ./cookies.sh hbz-nrw.de  "ROUTEID=plone.1; cookie-policy=accepted" > cookies.txt
# PATH is always set to "/", EXPIRATION -1 for no expiration 

domain=$1
cookies=$2

FLAG=TRUE    # A TRUE or FALSE value indicating if subdomains within the given domain can access the cookie.
SECURE=FALSE # A TRUE or FALSE value indicating if the cookie should be sent over HTTPS only.


echo $cookies \
| tr ';' '\n' \
| sed -E 's/^ *| *$//g' \
| awk -F= -v domain=$domain -v flag=$FLAG -v secure=$SECURE '{printf "%s\t%s\t/\t%s\t-1\t%s\t%s\n", domain, flag, secure, $1, $2}'
