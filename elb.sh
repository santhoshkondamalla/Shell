#!/bin/bash
echo "finding the instances which are outofservice in Mumbai ELB Loadbalancer"
status=`aws --profile my-ap-south-1 elb describe-load-balancers --output=text |  grep -w LOADBALANCERDESCRIPTIONS | awk '{print $6}'`
for i in $status
do
status1=`aws --profile my-ap-south-1 elb describe-instance-health --load-balancer-name $i|grep -o OutOfService`
if [ "$status1" == "OutOfService" ]
then
echo "The failed instances are given below ELB $i"
#aws  --profile my-ap-south-1 elb describe-instance-health --load-balancer-name $i | grep -w "i*"
aws elb describe-instance-health --load-balancer-name $i  --output text  --query 'InstanceStates[*].{InstanceID: InstanceId,StateName: State}'  --profile my-ap-south-1  | grep -i outofservice
else
echo "No instances failed"
fi
done
