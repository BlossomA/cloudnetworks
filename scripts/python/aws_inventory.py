#!/usr/bin/env python3
"""
AWS Network and Compute Inventory Script

Collects VPCs, subnets, transit gateways, EC2 instances, flow logs,
and security groups from a given AWS region and saves results to JSON.
"""

import argparse
import json
import os
import sys
from datetime import datetime

import boto3
from botocore.exceptions import ClientError

try:
    from tabulate import tabulate
    HAS_TABULATE = True
except ImportError:
    HAS_TABULATE = False


def get_session(region: str) -> boto3.Session:
    access_key = os.environ.get("AWS_ACCESS_KEY_ID")
    secret_key = os.environ.get("AWS_SECRET_ACCESS_KEY")

    if not access_key or not secret_key:
        print("ERROR: AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY must be set in the environment.", file=sys.stderr)
        sys.exit(1)

    return boto3.Session(
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key,
        region_name=region,
    )


def get_name_tag(tags: list) -> str:
    if not tags:
        return ""
    for tag in tags:
        if tag.get("Key") == "Name":
            return tag.get("Value", "")
    return ""


def list_vpcs(ec2_client) -> list:
    """Describe all VPCs and return a simplified list."""
    try:
        response = ec2_client.describe_vpcs()
    except ClientError as e:
        print(f"ERROR listing VPCs: {e.response['Error']['Message']}", file=sys.stderr)
        return []

    vpcs = []
    for vpc in response.get("Vpcs", []):
        vpcs.append({
            "id": vpc.get("VpcId", ""),
            "cidr": vpc.get("CidrBlock", ""),
            "name": get_name_tag(vpc.get("Tags", [])),
            "state": vpc.get("State", ""),
            "is_default": vpc.get("IsDefault", False),
        })
    return vpcs


def list_subnets(ec2_client, vpc_id: str) -> list:
    """List subnets for a given VPC."""
    try:
        response = ec2_client.describe_subnets(
            Filters=[{"Name": "vpc-id", "Values": [vpc_id]}]
        )
    except ClientError as e:
        print(f"ERROR listing subnets for VPC {vpc_id}: {e.response['Error']['Message']}", file=sys.stderr)
        return []

    subnets = []
    for subnet in response.get("Subnets", []):
        subnets.append({
            "id": subnet.get("SubnetId", ""),
            "vpc_id": subnet.get("VpcId", ""),
            "cidr": subnet.get("CidrBlock", ""),
            "availability_zone": subnet.get("AvailabilityZone", ""),
            "name": get_name_tag(subnet.get("Tags", [])),
            "available_ips": subnet.get("AvailableIpAddressCount", 0),
            "map_public_ip": subnet.get("MapPublicIpOnLaunch", False),
        })
    return subnets


def list_transit_gateways(ec2_client) -> dict:
    """List transit gateways and their attachments."""
    gateways = []
    try:
        response = ec2_client.describe_transit_gateways()
        for tgw in response.get("TransitGateways", []):
            gateways.append({
                "id": tgw.get("TransitGatewayId", ""),
                "arn": tgw.get("TransitGatewayArn", ""),
                "name": get_name_tag(tgw.get("Tags", [])),
                "state": tgw.get("State", ""),
                "owner_id": tgw.get("OwnerId", ""),
                "amazon_side_asn": tgw.get("Options", {}).get("AmazonSideAsn", ""),
            })
    except ClientError as e:
        print(f"ERROR listing transit gateways: {e.response['Error']['Message']}", file=sys.stderr)

    attachments = []
    try:
        response = ec2_client.describe_transit_gateway_attachments()
        for att in response.get("TransitGatewayAttachments", []):
            attachments.append({
                "id": att.get("TransitGatewayAttachmentId", ""),
                "transit_gateway_id": att.get("TransitGatewayId", ""),
                "resource_type": att.get("ResourceType", ""),
                "resource_id": att.get("ResourceId", ""),
                "state": att.get("State", ""),
                "name": get_name_tag(att.get("Tags", [])),
            })
    except ClientError as e:
        print(f"ERROR listing transit gateway attachments: {e.response['Error']['Message']}", file=sys.stderr)

    return {"gateways": gateways, "attachments": attachments}


def list_instances(ec2_client) -> list:
    """List all EC2 instances across all reservations."""
    try:
        response = ec2_client.describe_instances()
    except ClientError as e:
        print(f"ERROR listing instances: {e.response['Error']['Message']}", file=sys.stderr)
        return []

    instances = []
    for reservation in response.get("Reservations", []):
        for inst in reservation.get("Instances", []):
            # Collect all private IPs across network interfaces
            private_ips = []
            public_ips = []
            for iface in inst.get("NetworkInterfaces", []):
                for priv in iface.get("PrivateIpAddresses", []):
                    addr = priv.get("PrivateIpAddress")
                    if addr:
                        private_ips.append(addr)
                    assoc = priv.get("Association", {})
                    pub = assoc.get("PublicIp")
                    if pub:
                        public_ips.append(pub)

            instances.append({
                "id": inst.get("InstanceId", ""),
                "name": get_name_tag(inst.get("Tags", [])),
                "instance_type": inst.get("InstanceType", ""),
                "state": inst.get("State", {}).get("Name", ""),
                "private_ip": inst.get("PrivateIpAddress", ""),
                "public_ip": inst.get("PublicIpAddress", ""),
                "all_private_ips": private_ips,
                "all_public_ips": public_ips,
                "vpc_id": inst.get("VpcId", ""),
                "subnet_id": inst.get("SubnetId", ""),
                "availability_zone": inst.get("Placement", {}).get("AvailabilityZone", ""),
                "launch_time": inst.get("LaunchTime", "").isoformat() if inst.get("LaunchTime") else "",
            })
    return instances


def list_flow_logs(ec2_client) -> list:
    """List all VPC flow logs."""
    try:
        response = ec2_client.describe_flow_logs()
    except ClientError as e:
        print(f"ERROR listing flow logs: {e.response['Error']['Message']}", file=sys.stderr)
        return []

    flow_logs = []
    for fl in response.get("FlowLogs", []):
        flow_logs.append({
            "id": fl.get("FlowLogId", ""),
            "resource_id": fl.get("ResourceId", ""),
            "traffic_type": fl.get("TrafficType", ""),
            "log_destination_type": fl.get("LogDestinationType", ""),
            "log_destination": fl.get("LogDestination", ""),
            "log_format": fl.get("LogFormat", ""),
            "deliver_logs_status": fl.get("DeliverLogsStatus", ""),
            "flow_log_status": fl.get("FlowLogStatus", ""),
        })
    return flow_logs


def list_security_groups(ec2_client, vpc_id: str) -> list:
    """List security groups for a given VPC."""
    try:
        response = ec2_client.describe_security_groups(
            Filters=[{"Name": "vpc-id", "Values": [vpc_id]}]
        )
    except ClientError as e:
        print(f"ERROR listing security groups for VPC {vpc_id}: {e.response['Error']['Message']}", file=sys.stderr)
        return []

    groups = []
    for sg in response.get("SecurityGroups", []):
        groups.append({
            "id": sg.get("GroupId", ""),
            "name": sg.get("GroupName", ""),
            "description": sg.get("Description", ""),
            "vpc_id": sg.get("VpcId", ""),
            "inbound_rules_count": len(sg.get("IpPermissions", [])),
            "outbound_rules_count": len(sg.get("IpPermissionsEgress", [])),
            "inbound_rules": sg.get("IpPermissions", []),
            "outbound_rules": sg.get("IpPermissionsEgress", []),
        })
    return groups


def print_table(headers: list, rows: list, title: str = "") -> None:
    if title:
        print(f"\n{'='*60}")
        print(f"  {title}")
        print(f"{'='*60}")
    if not rows:
        print("  (no items found)")
        return
    if HAS_TABULATE:
        print(tabulate(rows, headers=headers, tablefmt="grid"))
    else:
        col_widths = [max(len(str(h)), max((len(str(r[i])) for r in rows), default=0)) for i, h in enumerate(headers)]
        fmt = "  " + "  ".join(f"{{:<{w}}}" for w in col_widths)
        print(fmt.format(*headers))
        print("  " + "  ".join("-" * w for w in col_widths))
        for row in rows:
            print(fmt.format(*[str(v) for v in row]))


def main():
    parser = argparse.ArgumentParser(description="AWS Network and Compute Inventory")
    parser.add_argument("--region", default="us-east-1", help="AWS region (default: us-east-1)")
    parser.add_argument("--output", default="reports/aws_inventory.json", help="Output JSON file path")
    args = parser.parse_args()

    print(f"Collecting AWS inventory in region: {args.region}")

    session = get_session(args.region)
    ec2 = session.client("ec2")

    # --- VPCs ---
    vpcs = list_vpcs(ec2)
    print_table(
        ["ID", "CIDR", "Name", "State", "Default"],
        [[v["id"], v["cidr"], v["name"], v["state"], v["is_default"]] for v in vpcs],
        title="VPCs",
    )

    # --- Subnets (per VPC) ---
    all_subnets = []
    for vpc in vpcs:
        subnets = list_subnets(ec2, vpc["id"])
        all_subnets.extend(subnets)
    print_table(
        ["ID", "VPC", "CIDR", "AZ", "Name", "Available IPs"],
        [[s["id"], s["vpc_id"], s["cidr"], s["availability_zone"], s["name"], s["available_ips"]] for s in all_subnets],
        title="Subnets",
    )

    # --- Transit Gateways ---
    tgw_data = list_transit_gateways(ec2)
    print_table(
        ["ID", "Name", "State", "ASN", "Owner"],
        [[g["id"], g["name"], g["state"], g["amazon_side_asn"], g["owner_id"]] for g in tgw_data["gateways"]],
        title="Transit Gateways",
    )
    print_table(
        ["Attachment ID", "TGW ID", "Resource Type", "Resource ID", "State"],
        [[a["id"], a["transit_gateway_id"], a["resource_type"], a["resource_id"], a["state"]] for a in tgw_data["attachments"]],
        title="Transit Gateway Attachments",
    )

    # --- EC2 Instances ---
    instances = list_instances(ec2)
    print_table(
        ["ID", "Name", "Type", "State", "Private IP", "Public IP", "VPC"],
        [[i["id"], i["name"], i["instance_type"], i["state"], i["private_ip"], i["public_ip"], i["vpc_id"]] for i in instances],
        title="EC2 Instances",
    )

    # --- Flow Logs ---
    flow_logs = list_flow_logs(ec2)
    print_table(
        ["ID", "Resource", "Traffic Type", "Destination Type", "Status"],
        [[f["id"], f["resource_id"], f["traffic_type"], f["log_destination_type"], f["flow_log_status"]] for f in flow_logs],
        title="VPC Flow Logs",
    )

    # --- Security Groups (per VPC) ---
    all_sgs = []
    for vpc in vpcs:
        sgs = list_security_groups(ec2, vpc["id"])
        all_sgs.extend(sgs)
    print_table(
        ["ID", "Name", "VPC", "Inbound Rules", "Outbound Rules"],
        [[sg["id"], sg["name"], sg["vpc_id"], sg["inbound_rules_count"], sg["outbound_rules_count"]] for sg in all_sgs],
        title="Security Groups",
    )

    # --- Save JSON ---
    inventory = {
        "collected_at": datetime.utcnow().isoformat() + "Z",
        "region": args.region,
        "vpcs": vpcs,
        "subnets": all_subnets,
        "transit_gateways": tgw_data,
        "instances": instances,
        "flow_logs": flow_logs,
        "security_groups": all_sgs,
    }

    output_path = args.output
    os.makedirs(os.path.dirname(output_path) if os.path.dirname(output_path) else ".", exist_ok=True)
    with open(output_path, "w") as f:
        json.dump(inventory, f, indent=2, default=str)

    print(f"\nInventory saved to: {output_path}")


if __name__ == "__main__":
    main()
