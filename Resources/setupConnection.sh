#!/usr/bin/expect -f
# exp_internal 1

# To do: Better error handling for exceptions. As of now users will get no indication that an error has occurred.

set primaryip [lindex $argv 0];
set secondaryip [lindex $argv 1];
set username [lindex $argv 2];
set password [lindex $argv 3];

send_user "   - Adding $primaryip $secondaryip"

expect ""

spawn fmsadmin wpe add $primaryip $secondaryip -u $username -p $password > /dev/null
expect {
    "FileMaker Server cannot verify the SSL certificate, error: 20632 (SSL certificate verification error). Do you want to connect using the unverified certificate? (y/n) " {
        send "y\r"
        exp_continue
    }
}

sleep 4
exit
