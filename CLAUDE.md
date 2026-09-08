# Project instructions

## This repo is public — never add real security-sensitive values

This repository (`index.html`, `week2.html`, and any future week files) is a
public-facing site. Do not write real AWS account IDs, real resource IDs
(VPC/subnet/security-group/AMI/instance/route-table/IGW/NAT/launch-template
IDs, etc.), real public IP addresses, or any other credential-like or
account-identifying values into any tracked file.

This applies **even when the user pastes terminal output, CLI results, or
another AI's response that contains real values** — extract the teaching
content, but replace any real identifier with an obviously fake placeholder
before writing it to a file. Good placeholder conventions already used in
this repo:

- AWS account ID → `111122223333` (AWS's own documentation placeholder)
- Resource IDs → keep the real prefix/shape but replace the hex suffix, e.g.
  `vpc-0123456789abcdef0`, `subnet-0aaa1111aaaa11111`, `ami-0bbbbbbbbbbbbbbbb`
- Public IP addresses → `203.0.113.10` (IANA TEST-NET-3 documentation range)
- When the same real ID appears in multiple places, map it to the *same*
  fake value everywhere so cross-references and comparison tables still
  read correctly — don't just replace every ID with one generic value.

If the user pastes something containing real account/resource IDs, either
scrub it silently before adding it to a file, or flag it and ask — never
add it verbatim on the assumption that "they pasted it, so it's fine."

Before considering any content addition to this repo done, a quick
`grep -nE '\b[0-9]{12}\b'` and a scan for resource-ID-shaped strings
(`ami-`, `vpc-`, `subnet-`, `sg-`, `i-`, `igw-`, `rtb-`, `nat-`, `lt-`
followed by hex) is a good final check.
