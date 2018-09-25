#!/bin/bash

#set -x -T 

Description="creating deleting vpc/Subnets in AWS"
PROGNAME="$0"
##function for creating vpc
create_vpc() {
local func=create_vpc
local cidr=$1 
	if [[  $cidr  =~  ^[0-9]{1,3}\.[0-9]{1,3}\.0.0/16  ]]
       	then
      		echo "Please wait creating vpc" `aws ec2 create-vpc --cidr-block $cidr ` 
		else
		echo "Please enter correct cidr range . for help run `basename $PROGNAME` -h "
		fi
}

##function for deleting vpc 
delete_vpc() {
local func=delete_vpc
local vpcid=$1
aws ec2 describe-vpcs --query 'Vpcs[*].VpcId' | grep -w $vpcid  > /dev/null
	if [ $? = 0 ]
        then
             echo "Please wait deleting vpc" `aws ec2 delete-vpc --vpc-id $vpcid ` 
        else
             echo "$vpcid does not exist . for help run `basename $PROGNAME` -h "
       fi
}

##function for creating vpc 
create_subnet(){
local func=create_subnet
local cidr=$1
local vpcid=$2
	if [[ $cidr =~  ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.0/24  ]]
        then 
		echo "Please wait Creating subnet `aws ec2 create-subnet --vpc-id $vpcid --cidr-block $cidr`"
	else
               	echo "Please enter correct cidr range . for help run `basename $PROGNAME` -h "
        fi
}

##function for deleting subnet 
delete_subnet(){
local func=delete_subnet
local subnetid=$1
aws ec2 describe-subnets --query 'Subnets[*].SubnetId' | grep -w $subnetid  > /dev/null
	 if [ $? = 0 ]
 	 then
         	echo "Please wait deleting subnet" `aws ec2 delete-subnet --subnet-id $subnetid ` 
         else
        	echo "$subnetid does not exist . for help run `basename $PROGNAME` -h "
         fi

}
###Function for script usage
usage(){
echo -e "This script usage \n `basename $PROGNAME`  createvpc cidr range or deletevpc  vpcid" 
}

##main function start
read -p  "Please   select any one option createvpc |deletevpc |createsubnet |deletesubnet : " opt
	if [ "$opt" = "createvpc" ]	
        then 
            read -p "please enter cidr range " cidr
            echo "VPC created  of $cidr "  `create_vpc $cidr`
	elif [ "$opt" = "deletevpc" ]	
        then
            read -p "Please enter VpcId" vpcid
            echo "deleting vpc " `delete_vpc $vpcid`
	elif [ "$opt" = "createsubnet" ]
        then
            read -p "please enter cidr range and vpc id "  
            echo "subent creating  "  `create_subnet $@`
        elif [ "$opt" = "deletesubnet" ]
        then
	    read -p "Please enter subnetId" subnetid
            echo "deleting subnet" `delete_subnet $subnetid`
        else
            echo "Please enter valid Input"  
        fi
