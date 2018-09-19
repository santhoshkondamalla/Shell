#!/usr/bin/env bash
set -x
AWS_REGION="my-ap-south-1"
VPC_NAME="Santhosh-VPC"
VPC_CIDR="10.20.0.0/16"
SUBNET_PUBLIC_CIDR="10.20.1.0/24"
SUBNET_PUBLIC_AZ="ap-south-1a"
SUBNET_PUBLIC_NAME="Public Subnet"
SUBNET_PRIVATE_CIDR="10.20.2.0/24"
SUBNET_PRIVATE_AZ="ap-south-1b"
SUBNET_PRIVATE_NAME="private subnet"
CHECK_FREQUENCY=5

vpc_creation()
      {  
      echo "Creating VPC in preferred region..."
      VPC_ID=$(aws --profile $AWS_REGION ec2 create-vpc --cidr-block $VPC_CIDR --query 'Vpc.{VpcId:VpcId}' --output text  )
      ret=$?
      return $ret
      }

vpc_name()
     {
     aws --profile $AWS_REGION ec2 create-tags --resources $VPC_ID --tags "Key=Name,Value=$VPC_NAME" 
     ret=$?
     return $ret
     }

public_subnet()
     {
     echo "Creating Public Subnet..."
     SUBNET_PUBLIC_ID=$(aws --profile $AWS_REGION ec2 create-subnet --vpc-id $VPC_ID --cidr-block $SUBNET_PUBLIC_CIDR --availability-zone $SUBNET_PUBLIC_AZ --query 'Subnet.{SubnetId:SubnetId}' --output text )
     ret=$?
     return $ret
     }

public_subnetname()
     {
     aws --profile $AWS_REGION ec2 create-tags --resources $SUBNET_PUBLIC_ID --tags "Key=Name,Value=$SUBNET_PUBLIC_NAME" 
     ret=$?
     return $ret
     }

private_subnet()
    {
    echo "Creating Private Subnet..."
    SUBNET_PRIVATE_ID=$(aws --profile $AWS_REGION ec2 create-subnet --vpc-id $VPC_ID --cidr-block $SUBNET_PRIVATE_CIDR --availability-zone $SUBNET_PRIVATE_AZ --query 'Subnet.{SubnetId:SubnetId}' --output text )
    ret=$?
    return $ret
    }

private_subnetname()
    {
    aws  --profile $AWS_REGION ec2 create-tags --resources $SUBNET_PRIVATE_ID --tags "Key=Name,Value=$SUBNET_PRIVATE_NAME" 
    ret=$?
    return $ret
    }

internet_gateway()
    {
    echo "Creating Internet Gateway..."
    IGW_ID=$(aws --profile $AWS_REGION ec2 create-internet-gateway  --query 'InternetGateway.{InternetGatewayId:InternetGatewayId}' --output text )
    ret=$?
    return $ret
    }

gateway_vpc()
    {
    aws --profile $AWS_REGION ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID 
    ret=$?
    echo "  Internet Gateway ID '$IGW_ID' ATTACHED to VPC ID '$VPC_ID'."
    return $ret
    }

route_table()
    {
    echo "Creating Route Table..."
    ROUTE_TABLE_ID=$(aws --profile $AWS_REGION ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.{RouteTableId:RouteTableId}' --output text )
    ret=$?
    echo "  Route Table ID '$ROUTE_TABLE_ID' CREATED."
    return $ret
    }

route_gateway()
    {
    RESULT=$(aws --profile $AWS_REGION ec2 create-route --route-table-id $ROUTE_TABLE_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID )
    ret=$?   
    echo "  Route to '0.0.0.0/0' via Internet Gateway ID '$IGW_ID' ADDED to" "Route Table ID '$ROUTE_TABLE_ID'."
    return $ret
    }

public_route()
    { 
    RESULT=$(aws --profile $AWS_REGION ec2 associate-route-table  --subnet-id $SUBNET_PUBLIC_ID --route-table-id $ROUTE_TABLE_ID )
    ret=$? 
    echo "  Public Subnet ID '$SUBNET_PUBLIC_ID' ASSOCIATED with Route Table ID" "'$ROUTE_TABLE_ID'."
    return $ret
    }

publicip_publicsubnet()
    {
    aws --profile $AWS_REGION ec2 modify-subnet-attribute --subnet-id $SUBNET_PUBLIC_ID --map-public-ip-on-launch
    ret=$?
    echo "  'Auto-assign Public IP' ENABLED on Public Subnet ID" "'$SUBNET_PUBLIC_ID'."
    return $ret
    }

Eip_natgateway()
    {
    echo "Creating NAT Gateway..."
    EIP_ALLOC_ID=$(aws --profile $AWS_REGION ec2 allocate-address --domain vpc --query '{AllocationId:AllocationId}' --output text )
    ret=$?
    echo "  Elastic IP address ID '$EIP_ALLOC_ID' ALLOCATED."
    return $ret
    }

nat_gateway()
    {
    NAT_GW_ID=$(aws --profile $AWS_REGION ec2 create-nat-gateway --subnet-id $SUBNET_PUBLIC_ID --allocation-id $EIP_ALLOC_ID --query 'NatGateway.{NatGatewayId:NatGatewayId}' --output text )
    ret=$?
    FORMATTED_MSG="Creating NAT Gateway ID '$NAT_GW_ID' and waiting for it to "
    FORMATTED_MSG+="become available.\n    Please BE PATIENT as this can take some "
    FORMATTED_MSG+="time to complete.\n    ......\n"
    printf "  $FORMATTED_MSG"
    FORMATTED_MSG="STATUS: %s  -  %02dh:%02dm:%02ds elapsed while waiting for NAT "  
    FORMATTED_MSG+="Gateway to become available..."
    SECONDS=0
    LAST_CHECK=0
    STATE='PENDING'
    until [[ $STATE == 'AVAILABLE' ]]; do
    INTERVAL=$SECONDS-$LAST_CHECK
    if [[ $INTERVAL -ge $CHECK_FREQUENCY ]]; then
       STATE=$(aws --profile $AWS_REGION ec2 describe-nat-gateways --nat-gateway-ids $NAT_GW_ID --query 'NatGateways[*].{State:State}' --output text )
       STATE=$(echo $STATE | tr '[:lower:]' '[:upper:]')
       LAST_CHECK=$SECONDS
    fi
        SECS=$SECONDS
        STATUS_MSG=$(printf "$FORMATTED_MSG" $STATE $(($SECS/3600)) $(($SECS%3600/60)) $(($SECS%60)))
        printf "    $STATUS_MSG\033[0K\r"
        sleep 1
      done
    printf "\n    ......\n  NAT Gateway ID '$NAT_GW_ID' is now AVAILABLE.\n"
    return $ret
     }

route_natgatreway()
     {
     MAIN_ROUTE_TABLE_ID=$(aws --profile $AWS_REGION ec2 describe-route-tables --filters Name=vpc-id,Values=$VPC_ID Name=association.main,Values=true --query 'RouteTables[*].{RouteTableId:RouteTableId}' --output text )
     ret=$?    
 echo "  Main Route Table ID is '$MAIN_ROUTE_TABLE_ID'."
     return $ret
    }
    
natgeatway_private()
     {
     RESULT=$(aws --profile $AWS_REGION ec2 create-route --route-table-id $MAIN_ROUTE_TABLE_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $NAT_GW_ID )
     ret =$?
     echo "  Route to '0.0.0.0/0' via NAT Gateway with ID '$NAT_GW_ID' ADDED to" "Route Table ID '$MAIN_ROUTE_TABLE_ID'."
     return $ret
     }

  main()
     {
     vpc_creation
     vpc_name
     public_subnet
     public_subnetname
     private_subnet
     private_subnetname
     internet_gateway
     gateway_vpc
     route_table
     route_gateway
     public_route
     publicip_publicsubnet
     Eip_natgateway
     nat_gateway
     route_natgatreway
     natgeatway_private
     }
    
main"$@"
exit $? 
