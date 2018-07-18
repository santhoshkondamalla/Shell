#!/usr/bin/env bash
set -x

wifi_on_or_off=$(cat /sys/class/net/enp4s0/carrier )

lan_to_wifi()
   {
   /sbin/ifconfig enp4s0 down && /usr/bin/nmcli c up abhra
   ret=$?
return $ret
   }

extract()
      {
     
      script -q -c "scp -p /mnt/test ubuntu@192.168.0.174:/tmp" > /tmp/out 2>&1
      cat /tmp/out
      ret=$?
return $ret
     }

wifi()
     {
    /sbin/iwgetid -r
     ret=$?
return $ret
     }

santhosh()
    {
    date
    ret=$?
return $ret
  }

abhra()
     {
     /usr/bin/nmcli c down abhra && /usr/bin/nmcli c up abhrainc
     ret=$?
return $ret
     }
extract1()
      {

      script -q -c "scp -p /mnt/test ubuntu@192.168.0.174:/tmp" > /tmp/out 2>&1
      cat /tmp/out
      ret=$?
return $ret
     }

wifi1()
     {
    /sbin/iwgetid -r
     ret=$?
return $ret
     }

santhosh1()
    {
    date 
    ret=$?
return $ret
  }

abhrainc()
     {
     /usr/bin/nmcli c down abhrainc && /usr/bin/nmcli c up abhra_tp_hyd
     ret=$?
return $ret
     }

extract2()
      {

      script -q -c "scp -p /mnt/test ubuntu@192.168.0.174:/tmp" > /tmp/out 2>&1
      cat /tmp/out
      ret=$?
return $ret
     }

wifi2()
     {
    /sbin/iwgetid -r
     ret=$?
return $ret
     }

santhosh2()
    {
    date 
    ret=$?
return $ret
  }

abhra_tp_hyd()
     {
     /usr/bin/nmcli c down abhra_tp_hyd && /usr/bin/nmcli c up abhra
     ret=$?
return $ret
     }

wifi_to_lan()
   {
   /usr/bin/nmcli c down abhra && /sbin/ifconfig enp4s0 up
   ret=$?
return $ret
   }

main()
    {
if [[ $wifi_on_or_off -eq 1 ]]
   then
echo "you are connetced lan we are moving to wifi" 
   lan_to_wifi
   extract
   wifi
   santhosh
   abhra
   extract1
   wifi1
   santhosh1
   abhrainc
   extract2
   wifi2
   santhosh2
   abhra_tp_hyd
   wifi_to_lan
else
   echo "you are connected to wifi"
   extract
   wifi
   santhosh
   abhra
   extract1
   wifi1
   santhosh1
   abhrainc
   extract2
   wifi2
   santhosh2
   abhra_tp_hyd
  ret=$?
return $ret
fi
}

main"$@"
exit $?
