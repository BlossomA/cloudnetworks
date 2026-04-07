#!/usr/bin/env python3
"""
Generate architecture diagrams for the multi-cloud networking lab
Uses graphviz to create visual topology diagrams
Usage: python3 generate_diagram.py [--output diagrams/] [--format png|svg|pdf]
"""

import argparse
import os
import sys

try:
    from graphviz import Digraph
except ImportError:
    print("graphviz not installed. Run: pip3 install graphviz")
    print("Also install system graphviz: brew install graphviz  OR  apt-get install graphviz")
    sys.exit(1)


def create_aws_diagram(output_dir: str, fmt: str) -> str:
    dot = Digraph("aws-hub-spoke", comment="AWS Hub and Spoke Topology")
    dot.attr(rankdir="TB", bgcolor="white", fontname="Helvetica")
    dot.attr("node", fontname="Helvetica", fontsize="11")

    with dot.subgraph(name="cluster_aws") as aws:
        aws.attr(label="AWS (us-east-1)", style="filled", fillcolor="#FF9900", fontcolor="white",
                 color="#FF6600", penwidth="2")

        with aws.subgraph(name="cluster_tgw") as tgw_g:
            tgw_g.attr(label="Transit Gateway\n(ASN 64512)", style="dashed", color="#666")
            tgw_g.node("tgw", "Transit Gateway\n10.0.0.0/8", shape="rectangle",
                       style="filled", fillcolor="#FF9900", fontcolor="white")

        with aws.subgraph(name="cluster_hub_vpc") as hub:
            hub.attr(label="Hub VPC\n10.0.0.0/16", style="filled", fillcolor="#FFF3E0")
            hub.node("hub_public", "Public Subnet\n10.0.1.0/24", shape="box", style="filled",
                     fillcolor="#FFE0B2")
            hub.node("hub_private", "Private Subnet\n10.0.2.0/24\n[Test VM]", shape="box",
                     style="filled", fillcolor="#FFE0B2")
            hub.node("igw", "Internet Gateway", shape="diamond", style="filled",
                     fillcolor="#FFCC80")

        with aws.subgraph(name="cluster_spoke1") as s1:
            s1.attr(label="Spoke1 VPC\n10.1.0.0/16", style="filled", fillcolor="#E3F2FD")
            s1.node("spoke1_priv", "Private Subnet\n10.1.2.0/24\n[Test VM]", shape="box",
                    style="filled", fillcolor="#BBDEFB")

        with aws.subgraph(name="cluster_spoke2") as s2:
            s2.attr(label="Spoke2 VPC\n10.2.0.0/16", style="filled", fillcolor="#E8F5E9")
            s2.node("spoke2_priv", "Private Subnet\n10.2.2.0/24\n[Test VM]", shape="box",
                    style="filled", fillcolor="#C8E6C9")

        with aws.subgraph(name="cluster_vpn") as vpn:
            vpn.attr(label="VPN Connection\n(BGP/IPsec)", style="dashed", color="#E91E63")
            vpn.node("cgw", "Customer Gateway\n172.161.13.168\n(Azure On-Prem)", shape="oval",
                     style="filled", fillcolor="#FCE4EC")
            vpn.node("vgw", "VPN Gateway", shape="parallelogram", style="filled",
                     fillcolor="#F8BBD9")

    # Edges
    dot.edge("igw", "hub_public")
    dot.edge("hub_public", "hub_private")
    dot.edge("hub_private", "tgw", label="TGW Attachment")
    dot.edge("spoke1_priv", "tgw", label="TGW Attachment")
    dot.edge("spoke2_priv", "tgw", label="TGW Attachment")
    dot.edge("vgw", "tgw", label="Route propagation")
    dot.edge("cgw", "vgw", label="IPsec Tunnel 1\n(primary)", style="bold", color="#E91E63")
    dot.edge("cgw", "vgw", label="IPsec Tunnel 2\n(failover)", style="dashed", color="#E91E63")

    path = os.path.join(output_dir, "aws-topology")
    dot.render(path, format=fmt, cleanup=True)
    return f"{path}.{fmt}"


def create_azure_diagram(output_dir: str, fmt: str) -> str:
    dot = Digraph("azure-hub-spoke", comment="Azure Virtual WAN Topology")
    dot.attr(rankdir="TB", bgcolor="white", fontname="Helvetica")

    with dot.subgraph(name="cluster_azure") as azure:
        azure.attr(label="Azure (UK South)", style="filled", fillcolor="#0078D4",
                   fontcolor="white", color="#005A9E", penwidth="2")

        with azure.subgraph(name="cluster_vwan") as vwan:
            vwan.attr(label="Virtual WAN", style="filled", fillcolor="#D0E8FF")
            vwan.node("vhub", "Virtual Hub\n10.10.100.0/23\n(Standard SKU)", shape="rectangle",
                      style="filled", fillcolor="#0078D4", fontcolor="white")

        with azure.subgraph(name="cluster_hub_vnet") as hub:
            hub.attr(label="Hub VNet\n10.10.0.0/16", style="filled", fillcolor="#E3F2FF")
            hub.node("gw_subnet", "GatewaySubnet\n10.10.0.0/24", shape="box",
                     style="filled", fillcolor="#90CAF9")
            hub.node("mgmt_subnet", "Mgmt Subnet\n10.10.1.0/24\n[Hub VM]", shape="box",
                     style="filled", fillcolor="#90CAF9")
            hub.node("vpngw", "VPN Gateway\n(Active-Active\nBGP ASN 65515)", shape="parallelogram",
                     style="filled", fillcolor="#42A5F5", fontcolor="white")

        with azure.subgraph(name="cluster_spoke1") as s1:
            s1.attr(label="Spoke1 VNet\n10.11.0.0/16", style="filled", fillcolor="#E8F5E9")
            s1.node("az_spoke1", "Workload Subnet\n10.11.1.0/24\n[Spoke1 VM]", shape="box",
                    style="filled", fillcolor="#A5D6A7")

        with azure.subgraph(name="cluster_spoke2") as s2:
            s2.attr(label="Spoke2 VNet\n10.12.0.0/16", style="filled", fillcolor="#FFF8E1")
            s2.node("az_spoke2", "Workload Subnet\n10.12.1.0/24\n[Spoke2 VM]", shape="box",
                    style="filled", fillcolor="#FFE082")

    dot.edge("gw_subnet", "vpngw")
    dot.edge("vpngw", "vhub", label="VWAN connection")
    dot.edge("az_spoke1", "vhub", label="VHub Connection")
    dot.edge("az_spoke2", "vhub", label="VHub Connection")

    path = os.path.join(output_dir, "azure-topology")
    dot.render(path, format=fmt, cleanup=True)
    return f"{path}.{fmt}"


def create_gcp_diagram(output_dir: str, fmt: str) -> str:
    dot = Digraph("gcp-hub-spoke", comment="GCP VPC Peering Topology")
    dot.attr(rankdir="TB", bgcolor="white", fontname="Helvetica")

    with dot.subgraph(name="cluster_gcp") as gcp:
        gcp.attr(label="GCP (us-central1)", style="filled", fillcolor="#4285F4",
                 fontcolor="white", color="#1A73E8", penwidth="2")

        with gcp.subgraph(name="cluster_hub_vpc_gcp") as hub:
            hub.attr(label="Hub VPC\n(global)", style="filled", fillcolor="#E3F2FF")
            hub.node("gcp_hub_sub", "Subnet: 10.20.1.0/24\n[Hub VM + External IP]", shape="box",
                     style="filled", fillcolor="#90CAF9")
            hub.node("gcp_router", "Cloud Router\n(BGP ASN 65520)", shape="parallelogram",
                     style="filled", fillcolor="#42A5F5", fontcolor="white")
            hub.node("gcp_vpngw", "HA VPN Gateway\n(2x external IPs)", shape="oval",
                     style="filled", fillcolor="#1E88E5", fontcolor="white")

        with gcp.subgraph(name="cluster_spoke1_gcp") as s1:
            s1.attr(label="Spoke1 VPC\n(global)", style="filled", fillcolor="#E8F5E9")
            s1.node("gcp_s1", "Subnet: 10.21.1.0/24\n[Spoke1 VM]", shape="box",
                    style="filled", fillcolor="#A5D6A7")

        with gcp.subgraph(name="cluster_spoke2_gcp") as s2:
            s2.attr(label="Spoke2 VPC\n(global)", style="filled", fillcolor="#FFF8E1")
            s2.node("gcp_s2", "Subnet: 10.22.1.0/24\n[Spoke2 VM]", shape="box",
                    style="filled", fillcolor="#FFE082")

        gcp.node("gcp_onprem", "On-Premises\n172.161.13.168\n(Azure VM)", shape="oval",
                 style="filled", fillcolor="#FCE4EC")

    dot.edge("gcp_hub_sub", "gcp_s1", label="VPC Peering\n(bidirectional)", dir="both")
    dot.edge("gcp_hub_sub", "gcp_s2", label="VPC Peering\n(bidirectional)", dir="both")
    dot.edge("gcp_hub_sub", "gcp_router")
    dot.edge("gcp_router", "gcp_vpngw")
    dot.edge("gcp_vpngw", "gcp_onprem", label="HA VPN\n(BGP/IPsec)", style="bold",
             color="#E91E63")
    dot.node("note", "Note: Spoke1<->Spoke2\nnot directly peered\n(GCP non-transitive)",
             shape="note", style="filled", fillcolor="#FFFDE7")

    path = os.path.join(output_dir, "gcp-topology")
    dot.render(path, format=fmt, cleanup=True)
    return f"{path}.{fmt}"


def create_multicloud_diagram(output_dir: str, fmt: str) -> str:
    dot = Digraph("multicloud-overview", comment="Multi-Cloud Overview")
    dot.attr(rankdir="LR", bgcolor="white", fontname="Helvetica", size="20,12")

    dot.node("aws_hub", "AWS Hub VPC\n10.0.0.0/16\n(Transit Gateway)", shape="rectangle",
             style="filled", fillcolor="#FF9900", fontcolor="white")
    dot.node("aws_s1", "AWS Spoke1\n10.1.0.0/16", shape="box", style="filled",
             fillcolor="#FFE0B2")
    dot.node("aws_s2", "AWS Spoke2\n10.2.0.0/16", shape="box", style="filled",
             fillcolor="#FFE0B2")

    dot.node("az_hub", "Azure VWAN Hub\n10.10.100.0/23\n(VPN Gateway BGP)", shape="rectangle",
             style="filled", fillcolor="#0078D4", fontcolor="white")
    dot.node("az_s1", "Azure Spoke1\n10.11.0.0/16", shape="box", style="filled",
             fillcolor="#90CAF9")
    dot.node("az_s2", "Azure Spoke2\n10.12.0.0/16", shape="box", style="filled",
             fillcolor="#90CAF9")

    dot.node("gcp_hub", "GCP Hub VPC\n10.20.0.0/16\n(HA VPN + BGP)", shape="rectangle",
             style="filled", fillcolor="#4285F4", fontcolor="white")
    dot.node("gcp_s1", "GCP Spoke1\n10.21.0.0/16", shape="box", style="filled",
             fillcolor="#A5D6A7")
    dot.node("gcp_s2", "GCP Spoke2\n10.22.0.0/16", shape="box", style="filled",
             fillcolor="#A5D6A7")

    dot.node("onprem", "On-Premises\n172.161.13.168\n(Azure VM Proxy)", shape="oval",
             style="filled", fillcolor="#E0E0E0")

    dot.edge("aws_hub", "aws_s1", label="TGW Attach")
    dot.edge("aws_hub", "aws_s2", label="TGW Attach")
    dot.edge("az_hub", "az_s1", label="VHub Conn")
    dot.edge("az_hub", "az_s2", label="VHub Conn")
    dot.edge("gcp_hub", "gcp_s1", label="VPC Peer", dir="both")
    dot.edge("gcp_hub", "gcp_s2", label="VPC Peer", dir="both")

    dot.edge("onprem", "aws_hub", label="S2S VPN\n(BGP)", style="bold", color="#E91E63")
    dot.edge("onprem", "az_hub", label="IPsec VPN\n(BGP ASN 65515)", style="bold",
             color="#E91E63")
    dot.edge("onprem", "gcp_hub", label="HA VPN\n(BGP ASN 65520)", style="bold",
             color="#E91E63")

    path = os.path.join(output_dir, "multicloud-overview")
    dot.render(path, format=fmt, cleanup=True)
    return f"{path}.{fmt}"


def main():
    parser = argparse.ArgumentParser(description="Generate multi-cloud architecture diagrams")
    parser.add_argument("--output", default="diagrams", help="Output directory")
    parser.add_argument("--format", default="png", choices=["png", "svg", "pdf"],
                        help="Output format")
    args = parser.parse_args()

    os.makedirs(args.output, exist_ok=True)

    diagrams = [
        ("AWS topology", create_aws_diagram),
        ("Azure topology", create_azure_diagram),
        ("GCP topology", create_gcp_diagram),
        ("Multi-cloud overview", create_multicloud_diagram),
    ]

    for name, func in diagrams:
        print(f"Generating {name} ...", end=" ")
        path = func(args.output, args.format)
        print(f"-> {path}")

    print(f"\nAll diagrams written to: {args.output}/")


if __name__ == "__main__":
    main()
