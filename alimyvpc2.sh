#!/bin/bash
#************************************************#
#                 myvpc2.sh                      #                #
#                Sept 14, 2018                   #
#                                                #
#   Please define variable SAMPLE_COMMON_PATH    #
#************************************************#

#set -x -T 
#set -x  

### defining global variables
Description="creating deleting vpc/Subnets in AWS"
PROGNAME=$0
OK_STATE=0


### Please define variable SAMPLE_COMMON_PATH

######## Config file
SAMPLE_COMMON_PATH=/root/myscripts/vpc.conf
source $SAMPLE_COMMON_PATH > /dev/null


##Function for  VPC Tags ######
vpc_tags(){
	local FUNC=vpc_tags
        aws --profile $PROFILENAME ec2 create-tags  --resources $VPC_ID --tags "Key=Name,Value=$VPC_NAME" --region $AWS_REGION
        echo "VPC ID '$VPC_ID' NAMED as '$VPC_NAME'."
}

##Function for creating vpc ############
create_vpc(){
	local FUNC=create_vpc
	echo "Creating VPC ..."
	VPC_ID=$(aws --profile $PROFILENAME ec2 create-vpc --cidr-block $VPC_CIDR --query 'Vpc.{VpcId:VpcId}' --output text --region $AWS_REGION)
	echo "VPC ID '$VPC_ID' CREATED in '$AWS_REGION' region." 
	if [[ -n "$VPC_ID" ]]
	then
        	vpc_tags
    	else
        	echo "$VPC_ID not found" 
        	exit 1 
    	fi
}

##Function for deleting vpc ###########
delete_vpc(){
	local FUNC=delete_vpc
        DEL_VPC=$(aws --profile "$PROFILENAME" ec2 delete-vpc --vpc-id "$DELETE_VPC" --region $AWS_REGION )
        RET=$?
        echo "deleting VPC..."$DEL_VPC""
    	if [[ $RET -eq ${OK_STATE} ]]
    	then 
      		echo "$DELETE_VPC deleted"
    	elif [[ $RET -eq "255" ]]
        then 
        	echo "$DELETE_VPC has dependency issue"
    	else
       	echo "$DELETE_VPC does not exist."
        exit 1
        fi 
}
############################################################################################

## Enable Auto-assign Public IP on Public Subnet
auto_assign_publicip() {
        local FUNC=auto_assign_publicip
        aws --profile "$PROFILENAME" ec2 modify-subnet-attribute --subnet-id $PUBLIC_SUBNET_ID --map-public-ip-on-launch --region $AWS_REGION
        echo "  'Auto-assign Public IP' ENABLED on Public Subnet ID" "'$PUBLIC_SUBNET_ID'."
}

# Add Public Subnet with Route Table
add_route_table(){
        local FUNC=add_route_table
        RESULT=$(aws --profile "$PROFILENAME" ec2 associate-route-table --subnet-id $PUBLIC_SUBNET_ID  --route-table-id $ROUTE_TABLE_ID --region $AWS_REGION)
        echo "  Public Subnet ID '$PUBLIC_SUBNET_ID' ASSOCIATED with Route Table ID"  "'$ROUTE_TABLE_ID'."
}

# Create route to Internet Gateway
create_route(){
        local FUNC=create_route
        ROUTE=$(aws ec2 --profile "$PROFILENAME" create-route  --route-table-id $ROUTE_TABLE_ID  --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID  --region $AWS_REGION)
        echo "  Route to '0.0.0.0/0' via Internet Gateway ID '$IGW_ID' ADDED to" "Route Table ID '$ROUTE_TABLE_ID'."
}


# Create Route Table
create_route_table() {
        local FUNC=create_route_table
        echo "Creating Route Table..."
        ROUTE_TABLE_ID=$(aws --profile "$PROFILENAME" ec2 create-route-table  --vpc-id $PUBLIC_SUBNET_VPC_ID --query 'RouteTable.{RouteTableId:RouteTableId}'   --output text  --region $AWS_REGION)
        echo "  Route Table ID '$ROUTE_TABLE_ID' CREATED."
        if [[ -n "$ROUTE_TABLE_ID" ]]
       	then
                create_route
                add_route_table
                auto_assign_publicip

       else
                echo "Route Table id  not found" 
       fi
}


# Attaching Internet gateway to  VPC
attach_igw(){
        local FUNC=attach_igw
        echo "Attaching Internet Gateway..."
        aws --profile "$PROFILENAME" ec2 attach-internet-gateway --vpc-id $PUBLIC_SUBNET_VPC_ID  --internet-gateway-id $IGW_ID --region $AWS_REGION
        echo "  Internet Gateway ID '$IGW_ID' ATTACHED to VPC ID '$PUBLIC_SUBNET_VPC_ID'."
}

# Creating  Internet gateway ###
create_igw() { 
	local FUNC=create_igw
        echo "Checking for existing Gateways"
        IGW_ID_OLD=$(aws --profile "$PROFILENAME" ec2 describe-internet-gateways --output text --filters "Name=attachment.vpc-id,Values=$PUBLIC_SUBNET_VPC_ID" --query 'InternetGateways[].InternetGatewayId')
        if [[ -n "$IGW_ID_OLD" ]]
        then 
             echo "Internet Gateway Already exist $IGW_ID_OLD"
             $IGW_ID_OLD=$IGW_ID 
        else
	echo "Creating Internet Gateway..."
	IGW_ID=$(aws --profile "$PROFILENAME" ec2 create-internet-gateway --query 'InternetGateway.{InternetGatewayId:InternetGatewayId}' --output text --region $AWS_REGION)
	echo "  Internet Gateway ID '$IGW_ID' CREATED."
        fi
        if [[ -n "$IGW_ID" ]]
        then
                attach_igw
                create_route_table
        else
                echo "Internet Gateway  not found" 
        fi
       
}

#####Function for public subnet tag ########
subnet_tag(){
        local FUNC=subnet_tag
        aws --profile $PROFILENAME ec2 create-tags   --resources $PUBLIC_SUBNET_ID  --tags "Key=Name,Value=$PUBLIC_SUBNET_NAME"  --region $AWS_REGION
        echo "  Subnet ID '$PUBLIC_SUBNET_ID' NAMED as"   "'$PUBLIC_SUBNET_NAME'."
}

##Function for creating subnet ##########
create_subnet(){
	local FUNC=create_subnet
	echo "Creating Public Subnet..."
        PUBLIC_SUBNET_ID=$(aws --profile $PROFILENAME ec2 create-subnet --vpc-id $PUBLIC_SUBNET_VPC_ID  --cidr-block $PUBLIC_SUBNET_CIDR --availability-zone $PUBLIC_SUBNET_AZ  --query 'Subnet.{SubnetId:SubnetId}'  --output text --region $AWS_REGION)
        echo "  Subnet ID '$PUBLIC_SUBNET_ID' CREATED in '$PUBLIC_SUBNET_AZ'"  "Availability Zone."
       if [[ -n "$PUBLIC_SUBNET_ID" ]]
       then
                subnet_tag
                create_igw                 
       else
                echo "SUBNET Required Details  not found" 
       fi
}


##FUNCtion for deleting subnet 
delete_subnet(){
    local FUNC=delete_subnet
    echo "Deleting  Subnet... $(aws --profile "$PROFILENAME" ec2 delete-subnet --subnet-id "$DELETE_SUBNET")"
    if [[ $? -eq $OK_STATE ]]
    then
         echo "$DELETE_SUBNET deleted"
    else
        echo "$DELETE_SUBNET does not exist. "
        exit 1 
    fi
}
###Function for script usage
usage(){
	echo  "Please define the all required  variables in SAMPLE_COMMON_PATH " 
}


do_main(){
   local FUNC=do_main

    if [[ $ACTION -eq  1 ]]  && [[ $VPC_CIDR != 1 ]]  &&  [[ $VPC_NAME != 1 ]]
    then
        create_vpc
    elif [[ $ACTION -eq  2 ]] && [[ $PUBLIC_SUBNET_CIDR != 1 ]]  &&  [[ $PUBLIC_SUBNET_AZ != 1 ]] && [[ $PUBLIC_SUBNET_NAME != 1 ]] && [[ $PUBLIC_SUBNET_VPC_ID != 1 ]]
    then
        create_subnet
    elif [[ $ACTION -eq  3 ]] &&  [[ $DELETE_VPC != 1 ]]
    then
         delete_vpc
    elif [[ $ACTION -eq  4 ]] && [[ $DELETE_SUBNET  != 1 ]]
    then
         delete_subnet
    else
        usage
        echo "unable to manage vpc/subnet"
        exit 1
    fi
}


do_main "$@"
RET=$?
exit $RET    


Source file:
#!/bin/bash
##### This is the configuration file of manging VPC
## ACTIONS
# 1. create VPC: For creating vpc VPC_NAME and VPC_CIDR required ,Assign ACTION Value 1, Leave remaing values=1 like DELETE_VPC=1, 
# 2. create Subnet : For creating Public Subent PUBLIC_SUBNET_CIDR, PUBLIC_SUBNET_AZ,PUBLIC_SUBNET_VPC_ID,PUBLIC_SUBNET_NAME,VPC_ID required , Assign ACTION Value 2, Leave remaing values=1 like DELETE_VPC=1.
#3. delete VPC : For deleting  vpc enter the VPC ID ,Assign ACTION Value 3, Leave remaing values=1 like VPC_CIDR=1
#4. delete Subnet : For deleting  subnet enter the Subnet ID ,Assign ACTION Value 4, Leave remaing values=1 like VPC_CIDR=1



PROFILENAME=aleem                               # Profile name must be required in all actions
AWS_REGION="ap-south-1"                         #Regions must be required  in all actions
ACTION=4                                        #Select ACtion As per the Requirement
VPC_NAME=1
VPC_CIDR=1
DELETE_VPC=1
PUBLIC_SUBNET_CIDR=1
PUBLIC_SUBNET_AZ=1
PUBLIC_SUBNET_NAME=1
PUBLIC_SUBNET_VPC_ID=1
DELETE_SUBNET="subnet-0f3f91b03a37e8b51"

