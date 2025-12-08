#!/bin/bash
echo "=== CHECKING VPC COST-RELATED RESOURCES ==="
echo ""

echo "1. ELASTIC IPs (Cost: $0.005/hour each):"
aws ec2 describe-addresses --region me-south-1 \
    --query "Addresses[*].[PublicIp,AllocationId,InstanceId || 'UNATTACHED']" \
    --output table

echo ""
echo "2. VPC ENDPOINTS (Cost: $0.0121/hour each):"
aws ec2 describe-vpc-endpoints --region me-south-1 \
    --query "VpcEndpoints[*].[VpcEndpointId,ServiceName,State]" \
    --output table

echo ""
echo "3. NAT GATEWAYS (Cost: ~$32/month + $0.045/GB):"
aws ec2 describe-nat-gateways --region me-south-1 \
    --query "NatGateways[*].[NatGatewayId,State]" \
    --output table

echo ""
echo "4. RUNNING INSTANCES with Public IPs:"
aws ec2 describe-instances --region me-south-1 \
    --query "Reservations[*].Instances[*].[InstanceId,PublicIpAddress || 'No-Public-IP',InstanceType]" \
    --output table
