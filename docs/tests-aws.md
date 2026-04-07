# AWS Hub-and-Spoke Test Results

## Infrastructure
- Hub VPC: vpc-04e8cfee9a79095a6 (10.0.0.0/16)
- Spoke1 VPC: vpc-0ac1360ac10abcd12 (10.1.0.0/16)
- Spoke2 VPC: vpc-09804da567ff9f940 (10.2.0.0/16)
- Transit Gateway: tgw-056b20bd96eb74f40

## Route Propagation
- 10.0.0.0/16 -> Hub attachment: Active (propagated)
- 10.1.0.0/16 -> Spoke1 attachment: Active (propagated)
- 10.2.0.0/16 -> Spoke2 attachment: Active (propagated)

## Connectivity Test
- Spoke1 (10.1.2.222) to Spoke2 (10.2.2.218): Reachable = True
- Analysis ID: nia-026ea84f46fa483e4
- Status: Succeeded

## VPC Flow Logs
- Hub: fl-07db67873c46f3e95
- Spoke1: fl-05149de3a63f18bec
- Spoke2: fl-0b171d7959078c7de
- Destination: s3://multi-cloud-net-flowlogs-416852954517
