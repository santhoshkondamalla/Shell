#!/bin/bash

echo "#############################profile##############################"
echo "Enter the profile(my-ap-south-1)"
read profile

echo "############################# AMI #########################################"
echo "Enter the AMI ID"
read ami

echo "##############################choose keypair##############################"
aws --profile $profile ec2 describe-key-pairs --output text | awk '{ print $3}'
echo "Choose one "
read key

echo "################################vpc#################################"
aws --profile $profile ec2 describe-vpcs  --query 'Vpcs[*].[VpcId,Tags[0].Value]'
echo "choose vpc"
read vpc

echo "##################################subnets##########################"
aws --profile $profile ec2 describe-subnets --output text  | grep $vpc | awk '{ print $9,$4}'
echo "choose subnet"
read subnet

echo "########################security Groups#############################"
echo "Create new security group? Type "yes" to create new or "no" to continue "
read ans
if [ $ans = "yes" ]
then
       echo "Enter the security group name"
       read sg_name
       aws --profile $profile ec2 create-security-group --group-name $sg_name --vpc-id $vpc --description $sg_name
       if  [ $? != 0 ]
       then 
              echo "creation of security group failed"
              exit 1
      fi
      sleep
fi
aws --profile $profile ec2 describe-security-groups  --output=text | grep $vpc | awk '{ print $5,$1,$6,$8 }'
echo "choose security group"
read sg_id

echo "######################################instance type###########################################"
echo " valid instance type: t2.micro "
read instance

echo "Please confirm the details"
echo -e "Region: $region \nAMI:$ami \nKeyPair:$key \nVPC=$vpc \nSubnet:$subnet \nSecurityGroupID:$sg_id \nInstanceType:$instance"

echo "Please enter "yes" to confirm the details to continue"
read ans1
then
       INSTANCE_ID=`aws --profile $profile ec2 run-instances --image-id $ami --min-count 1 --max-count 1 --key-name $key --security-group-ids $sg_id --instance-type $instance --subnet-id $subnet  | grep "InstanceId" | awk '{ print $2 }' | tr -d  '"' | tr -d ','`
       echo "Please wait while we launch the instance for you..."
       sleep 20
       if [ $? != 0 ]
      then 
      echo "instance creation failed"
      else
      echo "instance startup in progress"
      sleep 20
      aws --profile $profile ec2 describe-instances --output table --instance-ids $INSTANCE_ID
     fi
 
echo "############################################completed###########################"
           

