#!/usr/bin/env python3
"""
GCP Network and Compute Inventory Script

Collects VPC networks, compute instances, firewall rules, VPC peerings,
Cloud Routers, and HA VPN gateways from a GCP project and saves to JSON.

Usage:
    GCP_PROJECT_ID=your-project python3 gcp_inventory.py
"""

import json
import os
import sys
from datetime import datetime

try:
    from google.cloud import compute_v1
    from google.api_core.exceptions import GoogleAPIError, PermissionDenied
except ImportError as e:
    print(f"ERROR: Required GCP SDK packages are not installed: {e}", file=sys.stderr)
    print("Install with: pip install google-cloud-compute google-auth", file=sys.stderr)
    sys.exit(1)

try:
    from tabulate import tabulate
    HAS_TABULATE = True
except ImportError:
    HAS_TABULATE = False

DEFAULT_PROJECT_ID = "project-903fb6d7-a6c2-406c-9bb"


def print_setup_instructions():
    print("""
============================================================
  GCP Authentication Setup Instructions
============================================================
To use this script you need Application Default Credentials (ADC)
configured. Choose one of the following methods:

1. gcloud CLI (recommended for local use):
   $ gcloud auth application-default login
   $ gcloud config set project YOUR_PROJECT_ID

2. Service Account Key File:
   $ export GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json

3. Workload Identity (for GKE / Cloud Run / etc.):
   No action needed — credentials are injected automatically.

Set GCP_PROJECT_ID environment variable:
   $ export GCP_PROJECT_ID=your-project-id
   $ python3 gcp_inventory.py
============================================================
""")


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
        col_widths = [
            max(len(str(h)), max((len(str(r[i])) for r in rows), default=0))
            for i, h in enumerate(headers)
        ]
        fmt = "  " + "  ".join(f"{{:<{w}}}" for w in col_widths)
        print(fmt.format(*headers))
        print("  " + "  ".join("-" * w for w in col_widths))
        for row in rows:
            print(fmt.format(*[str(v) for v in row]))


def list_networks(project_id: str) -> list:
    """List all VPC networks with their subnets."""
    networks = []
    try:
        networks_client = compute_v1.NetworksClient()
        subnets_client = compute_v1.SubnetworksClient()

        for network in networks_client.list(project=project_id):
            subnet_details = []
            for subnet_url in (network.subnetworks or []):
                # URL: .../projects/PROJECT/regions/REGION/subnetworks/NAME
                parts = subnet_url.split("/")
                try:
                    region = parts[parts.index("regions") + 1]
                except (ValueError, IndexError):
                    region = ""
                subnet_name = parts[-1]
                try:
                    subnet = subnets_client.get(project=project_id, region=region, subnetwork=subnet_name)
                    subnet_details.append({
                        "name": subnet.name,
                        "region": subnet.region.split("/")[-1] if subnet.region else region,
                        "ip_cidr_range": subnet.ip_cidr_range,
                        "private_ip_google_access": subnet.private_ip_google_access,
                    })
                except (GoogleAPIError, Exception):
                    subnet_details.append({
                        "name": subnet_name,
                        "region": region,
                        "ip_cidr_range": "",
                        "private_ip_google_access": False,
                    })

            networks.append({
                "id": str(network.id),
                "name": network.name,
                "description": network.description,
                "auto_create_subnetworks": network.auto_create_subnetworks,
                "routing_mode": network.routing_config.routing_mode if network.routing_config else "",
                "mtu": network.mtu,
                "subnets_count": len(network.subnetworks or []),
                "subnets": subnet_details,
                "creation_timestamp": network.creation_timestamp,
            })
    except PermissionDenied as e:
        print(f"ERROR: Permission denied listing networks. Check IAM roles. {e}", file=sys.stderr)
        print_setup_instructions()
    except GoogleAPIError as e:
        print(f"ERROR listing networks: {e}", file=sys.stderr)
    return networks


def list_instances(project_id: str) -> list:
    """List all compute instances across all zones with internal/external IPs, status, zone."""
    instances = []
    try:
        agg_client = compute_v1.InstancesClient()
        for zone_name, zone_data in agg_client.aggregated_list(project=project_id):
            for inst in zone_data.instances or []:
                internal_ips = []
                external_ips = []
                for iface in inst.network_interfaces or []:
                    if iface.network_ip:
                        internal_ips.append(iface.network_ip)
                    for access_config in iface.access_configs or []:
                        if access_config.nat_i_p:
                            external_ips.append(access_config.nat_i_p)

                instances.append({
                    "id": str(inst.id),
                    "name": inst.name,
                    "zone": inst.zone.split("/")[-1] if inst.zone else zone_name.split("/")[-1],
                    "machine_type": inst.machine_type.split("/")[-1] if inst.machine_type else "",
                    "status": inst.status,
                    "internal_ips": internal_ips,
                    "external_ips": external_ips,
                    "creation_timestamp": inst.creation_timestamp,
                    "labels": dict(inst.labels) if inst.labels else {},
                    "tags": list(inst.tags.items) if inst.tags and inst.tags.items else [],
                })
    except PermissionDenied as e:
        print(f"ERROR: Permission denied listing instances. {e}", file=sys.stderr)
        print_setup_instructions()
    except GoogleAPIError as e:
        print(f"ERROR listing instances: {e}", file=sys.stderr)
    return instances


def list_firewall_rules(project_id: str) -> list:
    """List all firewall rules with direction, priority, and allowed protocols."""
    rules = []
    try:
        fw_client = compute_v1.FirewallsClient()
        for fw in fw_client.list(project=project_id):
            allowed = []
            for allow in fw.allowed or []:
                entry = {"protocol": allow.i_p_protocol}
                if allow.ports:
                    entry["ports"] = list(allow.ports)
                allowed.append(entry)

            denied = []
            for deny in fw.denied or []:
                entry = {"protocol": deny.i_p_protocol}
                if deny.ports:
                    entry["ports"] = list(deny.ports)
                denied.append(entry)

            rules.append({
                "id": str(fw.id),
                "name": fw.name,
                "description": fw.description,
                "network": fw.network.split("/")[-1] if fw.network else "",
                "direction": fw.direction,
                "priority": fw.priority,
                "source_ranges": list(fw.source_ranges or []),
                "destination_ranges": list(fw.destination_ranges or []),
                "target_tags": list(fw.target_tags or []),
                "source_tags": list(fw.source_tags or []),
                "allowed": allowed,
                "denied": denied,
                "disabled": fw.disabled,
                "creation_timestamp": fw.creation_timestamp,
            })
    except PermissionDenied as e:
        print(f"ERROR: Permission denied listing firewall rules. {e}", file=sys.stderr)
    except GoogleAPIError as e:
        print(f"ERROR listing firewall rules: {e}", file=sys.stderr)
    return rules


def list_peerings(project_id: str) -> list:
    """List all VPC peering connections by iterating networks."""
    peerings = []
    try:
        networks_client = compute_v1.NetworksClient()
        for network in networks_client.list(project=project_id):
            for peering in network.peerings or []:
                peerings.append({
                    "local_network": network.name,
                    "name": peering.name,
                    "peer_network": peering.network.split("/")[-1] if peering.network else "",
                    "peer_network_full": peering.network,
                    "state": peering.state,
                    "state_details": peering.state_details,
                    "auto_create_routes": peering.auto_create_routes,
                    "exchange_subnet_routes": peering.exchange_subnet_routes,
                    "export_custom_routes": peering.export_custom_routes,
                    "import_custom_routes": peering.import_custom_routes,
                })
    except PermissionDenied as e:
        print(f"ERROR: Permission denied listing peerings. {e}", file=sys.stderr)
    except GoogleAPIError as e:
        print(f"ERROR listing peerings: {e}", file=sys.stderr)
    return peerings


def list_routers(project_id: str) -> list:
    """List all Cloud Routers with BGP ASN across all regions."""
    routers = []
    try:
        routers_client = compute_v1.RoutersClient()
        for region_name, region_data in routers_client.aggregated_list(project=project_id):
            for router in region_data.routers or []:
                bgp = router.bgp
                bgp_peers = []
                for peer in router.bgp_peers or []:
                    bgp_peers.append({
                        "name": peer.name,
                        "peer_ip": peer.peer_ip_address,
                        "peer_asn": peer.peer_asn,
                        "advertised_route_priority": peer.advertised_route_priority,
                    })

                routers.append({
                    "id": str(router.id),
                    "name": router.name,
                    "region": router.region.split("/")[-1] if router.region else "",
                    "network": router.network.split("/")[-1] if router.network else "",
                    "description": router.description,
                    "bgp_asn": bgp.asn if bgp else None,
                    "bgp_advertise_mode": bgp.advertise_mode if bgp else "",
                    "bgp_peers": bgp_peers,
                    "bgp_peers_count": len(bgp_peers),
                    "creation_timestamp": router.creation_timestamp,
                })
    except PermissionDenied as e:
        print(f"ERROR: Permission denied listing routers. {e}", file=sys.stderr)
    except GoogleAPIError as e:
        print(f"ERROR listing routers: {e}", file=sys.stderr)
    return routers


def list_vpn_gateways(project_id: str) -> list:
    """List all HA VPN gateways across all regions."""
    gateways = []
    try:
        vpn_client = compute_v1.VpnGatewaysClient()
        for region_name, region_data in vpn_client.aggregated_list(project=project_id):
            for gw in region_data.vpn_gateways or []:
                interfaces = []
                for iface in gw.vpn_interfaces or []:
                    interfaces.append({
                        "id": iface.id,
                        "ip_address": iface.ip_address,
                        "interconnect_attachment": iface.interconnect_attachment,
                    })

                gateways.append({
                    "id": str(gw.id),
                    "name": gw.name,
                    "region": gw.region.split("/")[-1] if gw.region else "",
                    "network": gw.network.split("/")[-1] if gw.network else "",
                    "description": gw.description,
                    "stack_type": gw.stack_type,
                    "vpn_interfaces": interfaces,
                    "creation_timestamp": gw.creation_timestamp,
                })
    except PermissionDenied as e:
        print(f"ERROR: Permission denied listing VPN gateways. {e}", file=sys.stderr)
    except GoogleAPIError as e:
        print(f"ERROR listing VPN gateways: {e}", file=sys.stderr)
    return gateways


def main():
    project_id = os.environ.get("GCP_PROJECT_ID", DEFAULT_PROJECT_ID)
    output_path = "reports/gcp_inventory.json"

    print(f"Collecting GCP inventory for project: {project_id}")
    print("Note: Ensure gcloud ADC is configured. Run: gcloud auth application-default login")

    # --- Networks ---
    try:
        networks = list_networks(project_id)
    except Exception as e:
        print(f"\nERROR: Could not connect to GCP. Is gcloud authenticated?", file=sys.stderr)
        print_setup_instructions()
        sys.exit(1)

    print_table(
        ["Name", "Routing Mode", "Subnets", "Auto Subnets", "MTU"],
        [[n["name"], n["routing_mode"], n["subnets_count"], n["auto_create_subnetworks"], n["mtu"]]
         for n in networks],
        title="VPC Networks",
    )

    # --- Instances ---
    instances = list_instances(project_id)
    print_table(
        ["Name", "Zone", "Machine Type", "Status", "Internal IPs", "External IPs"],
        [[i["name"], i["zone"], i["machine_type"], i["status"],
          ", ".join(i["internal_ips"]), ", ".join(i["external_ips"])]
         for i in instances],
        title="Compute Instances",
    )

    # --- Firewall Rules ---
    fw_rules = list_firewall_rules(project_id)
    print_table(
        ["Name", "Network", "Direction", "Priority", "Source Ranges", "Disabled"],
        [[r["name"], r["network"], r["direction"], r["priority"],
          ", ".join(r["source_ranges"][:2]) + ("..." if len(r["source_ranges"]) > 2 else ""),
          r["disabled"]]
         for r in fw_rules],
        title="Firewall Rules",
    )

    # --- Peerings ---
    peerings = list_peerings(project_id)
    print_table(
        ["Local Network", "Peering Name", "Peer Network", "State"],
        [[p["local_network"], p["name"], p["peer_network"], p["state"]]
         for p in peerings],
        title="VPC Peerings",
    )

    # --- Routers ---
    routers = list_routers(project_id)
    print_table(
        ["Name", "Region", "Network", "BGP ASN", "BGP Peers"],
        [[r["name"], r["region"], r["network"], r["bgp_asn"], r["bgp_peers_count"]]
         for r in routers],
        title="Cloud Routers",
    )

    # --- VPN Gateways ---
    vpn_gateways = list_vpn_gateways(project_id)
    print_table(
        ["Name", "Region", "Network", "Stack Type", "Interfaces"],
        [[g["name"], g["region"], g["network"], g["stack_type"], len(g["vpn_interfaces"])]
         for g in vpn_gateways],
        title="HA VPN Gateways",
    )

    # --- Save JSON ---
    inventory = {
        "collected_at": datetime.utcnow().isoformat() + "Z",
        "project_id": project_id,
        "networks": networks,
        "instances": instances,
        "firewall_rules": fw_rules,
        "peerings": peerings,
        "routers": routers,
        "vpn_gateways": vpn_gateways,
    }

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "w") as f:
        json.dump(inventory, f, indent=2, default=str)

    print(f"\nInventory saved to: {output_path}")


if __name__ == "__main__":
    main()
