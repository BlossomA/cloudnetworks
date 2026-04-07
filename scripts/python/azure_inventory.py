#!/usr/bin/env python3
"""
Azure Network and Compute Inventory Script

Collects VNets, Virtual WANs, Virtual Hubs, VMs, NSGs, and Network Watchers
from an Azure subscription and saves results to JSON.
"""

import json
import os
import sys
from datetime import datetime

try:
    from azure.identity import ClientSecretCredential
    from azure.mgmt.network import NetworkManagementClient
    from azure.mgmt.compute import ComputeManagementClient
    from azure.core.exceptions import AzureError
except ImportError as e:
    print(f"ERROR: Required Azure SDK packages are not installed: {e}", file=sys.stderr)
    print("Install with: pip install azure-mgmt-network azure-mgmt-compute azure-identity", file=sys.stderr)
    sys.exit(1)

try:
    from tabulate import tabulate
    HAS_TABULATE = True
except ImportError:
    HAS_TABULATE = False


def get_credentials():
    subscription_id = os.environ.get("AZURE_SUBSCRIPTION_ID")
    tenant_id = os.environ.get("AZURE_TENANT_ID")
    client_id = os.environ.get("AZURE_CLIENT_ID")
    client_secret = os.environ.get("AZURE_CLIENT_SECRET")

    missing = [k for k, v in {
        "AZURE_SUBSCRIPTION_ID": subscription_id,
        "AZURE_TENANT_ID": tenant_id,
        "AZURE_CLIENT_ID": client_id,
        "AZURE_CLIENT_SECRET": client_secret,
    }.items() if not v]

    if missing:
        print(f"ERROR: Missing required environment variables: {', '.join(missing)}", file=sys.stderr)
        sys.exit(1)

    credential = ClientSecretCredential(
        tenant_id=tenant_id,
        client_id=client_id,
        client_secret=client_secret,
    )
    return credential, subscription_id


def list_vnets(network_client: NetworkManagementClient) -> list:
    """List all VNets across all resource groups."""
    vnets = []
    try:
        for vnet in network_client.virtual_networks.list_all():
            subnets = []
            for subnet in (vnet.subnets or []):
                subnets.append({
                    "name": subnet.name,
                    "address_prefix": subnet.address_prefix,
                    "id": subnet.id,
                })
            vnets.append({
                "id": vnet.id,
                "name": vnet.name,
                "location": vnet.location,
                "resource_group": vnet.id.split("/")[4] if vnet.id else "",
                "address_space": list(vnet.address_space.address_prefixes) if vnet.address_space else [],
                "subnets": subnets,
                "subnets_count": len(subnets),
                "provisioning_state": vnet.provisioning_state,
            })
    except AzureError as e:
        print(f"ERROR listing VNets: {e}", file=sys.stderr)
    return vnets


def list_virtual_wans(network_client: NetworkManagementClient) -> list:
    """List all Virtual WANs in the subscription."""
    vwans = []
    try:
        for vwan in network_client.virtual_wans.list():
            vwans.append({
                "id": vwan.id,
                "name": vwan.name,
                "location": vwan.location,
                "resource_group": vwan.id.split("/")[4] if vwan.id else "",
                "type": vwan.type,
                "provisioning_state": vwan.provisioning_state,
                "disable_vpn_encryption": vwan.disable_vpn_encryption,
                "allow_branch_to_branch_traffic": vwan.allow_branch_to_branch_traffic,
            })
    except AzureError as e:
        print(f"ERROR listing Virtual WANs: {e}", file=sys.stderr)
    return vwans


def list_virtual_hubs(network_client: NetworkManagementClient) -> list:
    """List all Virtual Hubs in the subscription."""
    hubs = []
    try:
        for hub in network_client.virtual_hubs.list():
            hubs.append({
                "id": hub.id,
                "name": hub.name,
                "location": hub.location,
                "resource_group": hub.id.split("/")[4] if hub.id else "",
                "address_prefix": hub.address_prefix,
                "virtual_wan": hub.virtual_wan.id if hub.virtual_wan else "",
                "sku": hub.sku,
                "provisioning_state": hub.provisioning_state,
                "routing_state": hub.routing_state,
            })
    except AzureError as e:
        print(f"ERROR listing Virtual Hubs: {e}", file=sys.stderr)
    return hubs


def list_vms(compute_client: ComputeManagementClient, network_client: NetworkManagementClient) -> list:
    """List all VMs with network details."""
    vms = []
    try:
        for vm in compute_client.virtual_machines.list_all():
            resource_group = vm.id.split("/")[4] if vm.id else ""

            # Gather NIC details for IPs
            private_ips = []
            public_ips = []
            try:
                vm_detail = compute_client.virtual_machines.get(resource_group, vm.name, expand="instanceView")
                nics = vm_detail.network_profile.network_interfaces if vm_detail.network_profile else []
                for nic_ref in nics:
                    nic_rg = nic_ref.id.split("/")[4]
                    nic_name = nic_ref.id.split("/")[-1]
                    try:
                        nic = network_client.network_interfaces.get(nic_rg, nic_name)
                        for ip_config in (nic.ip_configurations or []):
                            if ip_config.private_ip_address:
                                private_ips.append(ip_config.private_ip_address)
                            if ip_config.public_ip_address:
                                pip_name = ip_config.public_ip_address.id.split("/")[-1]
                                pip_rg = ip_config.public_ip_address.id.split("/")[4]
                                try:
                                    pip = network_client.public_ip_addresses.get(pip_rg, pip_name)
                                    if pip.ip_address:
                                        public_ips.append(pip.ip_address)
                                except AzureError:
                                    pass
                    except AzureError:
                        pass
            except AzureError:
                pass

            vms.append({
                "id": vm.id,
                "name": vm.name,
                "location": vm.location,
                "resource_group": resource_group,
                "vm_size": vm.hardware_profile.vm_size if vm.hardware_profile else "",
                "os_type": vm.storage_profile.os_disk.os_type if vm.storage_profile and vm.storage_profile.os_disk else "",
                "private_ips": private_ips,
                "public_ips": public_ips,
                "provisioning_state": vm.provisioning_state,
            })
    except AzureError as e:
        print(f"ERROR listing VMs: {e}", file=sys.stderr)
    return vms


def list_nsgs(network_client: NetworkManagementClient) -> list:
    """List all Network Security Groups."""
    nsgs = []
    try:
        for nsg in network_client.network_security_groups.list_all():
            security_rules = nsg.security_rules or []
            default_rules = nsg.default_security_rules or []
            nsgs.append({
                "id": nsg.id,
                "name": nsg.name,
                "location": nsg.location,
                "resource_group": nsg.id.split("/")[4] if nsg.id else "",
                "security_rules_count": len(security_rules),
                "default_rules_count": len(default_rules),
                "total_rules_count": len(security_rules) + len(default_rules),
                "provisioning_state": nsg.provisioning_state,
            })
    except AzureError as e:
        print(f"ERROR listing NSGs: {e}", file=sys.stderr)
    return nsgs


def list_network_watchers(network_client: NetworkManagementClient) -> list:
    """List all Network Watchers."""
    watchers = []
    try:
        for watcher in network_client.network_watchers.list_all():
            watchers.append({
                "id": watcher.id,
                "name": watcher.name,
                "location": watcher.location,
                "resource_group": watcher.id.split("/")[4] if watcher.id else "",
                "provisioning_state": watcher.provisioning_state,
            })
    except AzureError as e:
        print(f"ERROR listing Network Watchers: {e}", file=sys.stderr)
    return watchers


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
    print("Collecting Azure inventory...")

    credential, subscription_id = get_credentials()
    network_client = NetworkManagementClient(credential, subscription_id)
    compute_client = ComputeManagementClient(credential, subscription_id)

    # --- VNets ---
    vnets = list_vnets(network_client)
    print_table(
        ["Name", "Location", "Resource Group", "Address Space", "Subnets", "State"],
        [[v["name"], v["location"], v["resource_group"], ", ".join(v["address_space"]), v["subnets_count"], v["provisioning_state"]] for v in vnets],
        title="Virtual Networks (VNets)",
    )

    # --- Virtual WANs ---
    vwans = list_virtual_wans(network_client)
    print_table(
        ["Name", "Location", "Resource Group", "State"],
        [[v["name"], v["location"], v["resource_group"], v["provisioning_state"]] for v in vwans],
        title="Virtual WANs",
    )

    # --- Virtual Hubs ---
    hubs = list_virtual_hubs(network_client)
    print_table(
        ["Name", "Location", "Resource Group", "Address Prefix", "SKU", "State"],
        [[h["name"], h["location"], h["resource_group"], h["address_prefix"], h["sku"], h["provisioning_state"]] for h in hubs],
        title="Virtual Hubs",
    )

    # --- VMs ---
    vms = list_vms(compute_client, network_client)
    print_table(
        ["Name", "Location", "Resource Group", "VM Size", "OS", "Private IPs", "Public IPs", "State"],
        [[v["name"], v["location"], v["resource_group"], v["vm_size"], v["os_type"],
          ", ".join(v["private_ips"]), ", ".join(v["public_ips"]), v["provisioning_state"]] for v in vms],
        title="Virtual Machines",
    )

    # --- NSGs ---
    nsgs = list_nsgs(network_client)
    print_table(
        ["Name", "Location", "Resource Group", "Custom Rules", "Default Rules", "Total", "State"],
        [[n["name"], n["location"], n["resource_group"], n["security_rules_count"],
          n["default_rules_count"], n["total_rules_count"], n["provisioning_state"]] for n in nsgs],
        title="Network Security Groups (NSGs)",
    )

    # --- Network Watchers ---
    watchers = list_network_watchers(network_client)
    print_table(
        ["Name", "Location", "Resource Group", "State"],
        [[w["name"], w["location"], w["resource_group"], w["provisioning_state"]] for w in watchers],
        title="Network Watchers",
    )

    # --- Save JSON ---
    inventory = {
        "collected_at": datetime.utcnow().isoformat() + "Z",
        "subscription_id": subscription_id,
        "vnets": vnets,
        "virtual_wans": vwans,
        "virtual_hubs": hubs,
        "virtual_machines": vms,
        "network_security_groups": nsgs,
        "network_watchers": watchers,
    }

    output_path = "reports/azure_inventory.json"
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "w") as f:
        json.dump(inventory, f, indent=2, default=str)

    print(f"\nInventory saved to: {output_path}")


if __name__ == "__main__":
    main()
