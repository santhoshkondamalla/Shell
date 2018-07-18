#!/usr/bin/env bash
set -x
ftp_user=ftpuser
ftp_pass=ftpuser
server=192.168.0.58
destdir="/opt"

latestfile()
          {
  file="$( lftp -u $ftp_user,$ftp_pass -e "ls -t1 | head -1 ; quit" 192.168.0.58 | awk '{print $9}' )"
   echo "$file"
   ret=$?
   return $ret
          }
file_download()
             {
    cd $destdir
#    curl -O ftp://$ftp_user:ftp_pass@$server/$file
    wget ftp://$ftp_user:$ftp_pass@$server/$file
    ret=$?
    return $ret
             }    
main()
    {
    latestfile
    file_download
    }
main $*
exit $?


comment: this build download latest build from ftp server
