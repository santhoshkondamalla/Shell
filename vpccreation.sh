#!/bin/bash

AWS_REGION="my-ap-south-1"
VPC_NAME="My VPC"
VPC_CIDR="10.20.0.0/16"
SUBNET_PUBLIC_CIDR="10.20.1.0/24"
SUBNET_PUBLIC_AZ="ap-south-1a"
SUBNET_PUBLIC_NAME="Public Subnet"
SUBNET_PRIVATE_CIDR="10.20.2.0/24"
SUBNET_PRIVATE_AZ="ap-south-1b"
SUBNET_PRIVATE_NAME="private subnet"
CHECK_FREQUENCY=5

# Create VPC
echo "Creating VPC in preferred region..."
VPC_ID=$(aws --profile $AWS_REGION ec2 create-vpc --cidr-block $VPC_CIDR --query 'Vpc.{VpcId:VpcId}' --output text  )
echo "  VPC ID '$VPC_ID' CREATED in '$AWS_REGION' region."

# Add Name tag to VPC
aws --profile $AWS_REGION ec2 create-tags --resources $VPC_ID --tags "Key=Name,Value=$VPC_NAME" 
echo "  VPC ID '$VPC_ID' NAMED as '$VPC_NAME'."

# Create Public Subnet
echo "Creating Public Subnet..."
SUBNET_PUBLIC_ID=$(aws --profile $AWS_REGION ec2 create-subnet --vpc-id $VPC_ID --cidr-block $SUBNET_PUBLIC_CIDR --availability-zone $SUBNET_PUBLIC_AZ --query 'Subnet.{SubnetId:SubnetId}' --output text )
echo "  Subnet ID '$SUBNET_PUBLIC_ID' CREATED in '$SUBNET_PUBLIC_AZ'" "Availability Zone."

# Add Name tag to Public Subnet
aws --profile $AWS_REGION ec2 create-tags --resources $SUBNET_PUBLIC_ID --tags "Key=Name,Value=$SUBNET_PUBLIC_NAME" 
echo "  Subnet ID '$SUBNET_PUBLIC_ID' NAMED as" "'$SUBNET_PUBLIC_NAME'."

# Create Private Subnet
echo "Creating Private Subnet..."
SUBNET_PRIVATE_ID=$(aws --profile $AWS_REGION ec2 create-subnet --vpc-id $VPC_ID --cidr-block $SUBNET_PRIVATE_CIDR --availability-zone $SUBNET_PRIVATE_AZ --query 'Subnet.{SubnetId:SubnetId}' --output text )
echo "  Subnet ID '$SUBNET_PRIVATE_ID' CREATED in '$SUBNET_PRIVATE_AZ'" "Availability Zone."

# Add Name tag to Private Subnet
aws  --profile $AWS_REGION ec2 create-tags --resources $SUBNET_PRIVATE_ID --tags "Key=Name,Value=$SUBNET_PRIVATE_NAME" 
echo "  Subnet ID '$SUBNET_PRIVATE_ID' NAMED as '$SUBNET_PRIVATE_NAME'."

# Create Internet gateway
echo "Creating Internet Gateway..."
IGW_ID=$(aws --profile $AWS_REGION ec2 create-internet-gateway  --query 'InternetGateway.{InternetGatewayId:InternetGatewayId}' --output text )
echo "  Internet Gateway ID '$IGW_ID' CREATED."

# Attach Internet gateway to your VPC
aws --profile $AWS_REGION ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID 
echo "  Internet Gateway ID '$IGW_ID' ATTACHED to VPC ID '$VPC_ID'."

# Create Route Table
echo "Creating Route Table..."
ROUTE_TABLE_ID=$(aws --profile $AWS_REGION ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.{RouteTableId:RouteTableId}' --output text )
echo "  Route Table ID '$ROUTE_TABLE_ID' CREATED."

# Create route to Internet Gateway
RESULT=$(aws --profile $AWS_REGION ec2 create-route --route-table-id $ROUTE_TABLE_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID )
echo "  Route to '0.0.0.0/0' via Internet Gateway ID '$IGW_ID' ADDED to" "Route Table ID '$ROUTE_TABLE_ID'."

# Associate Public Subnet with Route Table
RESULT=$(aws --profile $AWS_REGION ec2 associate-route-table  --subnet-id $SUBNET_PUBLIC_ID --route-table-id $ROUTE_TABLE_ID )
echo "  Public Subnet ID '$SUBNET_PUBLIC_ID' ASSOCIATED with Route Table ID" "'$ROUTE_TABLE_ID'."

# Enable Auto-assign Public IP on Public Subnet
aws --profile $AWS_REGION ec2 modify-subnet-attribute --subnet-id $SUBNET_PUBLIC_ID --map-public-ip-on-launch
echo "  'Auto-assign Public IP' ENABLED on Public Subnet ID" "'$SUBNET_PUBLIC_ID'."

# Allocate Elastic IP Address for NAT Gateway
echo "Creating NAT Gateway..."
EIP_ALLOC_ID=$(aws --profile $AWS_REGION ec2 allocate-address --domain vpc --query '{AllocationId:AllocationId}' --output text )
echo "  Elastic IP address ID '$EIP_ALLOC_ID' ALLOCATED."

# Create NAT Gateway
NAT_GW_ID=$(aws --profile $AWS_REGION ec2 create-nat-gateway --subnet-id $SUBNET_PUBLIC_ID --allocation-id $EIP_ALLOC_ID --query 'NatGateway.{NatGatewayId:NatGatewayId}' --output text )
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

# Create route to NAT Gateway
MAIN_ROUTE_TABLE_ID=$(aws --profile $AWS_REGION ec2 describe-route-tables --filters Name=vpc-id,Values=$VPC_ID Name=association.main,Values=true --query 'RouteTables[*].{RouteTableId:RouteTableId}' --output text )
echo "  Main Route Table ID is '$MAIN_ROUTE_TABLE_ID'."
RESULT=$(aws --profile $AWS_REGION ec2 create-route --route-table-id $MAIN_ROUTE_TABLE_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $NAT_GW_ID )
echo "  Route to '0.0.0.0/0' via NAT Gateway with ID '$NAT_GW_ID' ADDED to" "Route Table ID '$MAIN_ROUTE_TABLE_ID'."
echo "COMPLETED"

