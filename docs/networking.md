---
title: Networking (VPC)
icon: lucide/network
---

# Networking: VPC, Built by Hand

## Overview

### 4.1 What a VPC Is

A VPC (Virtual Private Cloud) is your own isolated network within an AWS region — think of it as your private data centre network in the cloud. Nothing can enter or leave your VPC unless you explicitly allow it.

When you create a VPC, you define a CIDR block — the total pool of private IP addresses available to everything inside it.

.vi-title{font-family:'IBM Plex Sans Condensed',sans-serif;font-size:13px;font-weight:700;fill:var(--ink)}
.vi-label{font-family:'IBM Plex Sans Condensed',sans-serif;font-size:13px;font-weight:700;fill:var(--accent-strong)}
.vi-chip{font-family:'IBM Plex Mono',monospace;font-size:11px;fill:var(--surface);letter-spacing:.01em}
.vi-note{font-family:'IBM Plex Sans',sans-serif;font-size:11px;fill:var(--ink-muted)}
.vi-legend{font-family:'IBM Plex Sans',sans-serif;font-size:11px;fill:var(--ink-muted)}






VPC — public and private subnets

Internet


Internet Gateway


VPC 10.0.0.0/16 — fahad-devops-vpc

Public — 10.0.1.0/24

ALB · NAT Gateway

Private — 10.0.10.0/24

EC2 · RDS

Public subnet — has a route to the Internet Gateway

Private subnet — no direct internet route
The real build (4.8) uses 3 tiers × 2 AZs = 6 subnets.
See 4.9 for the full picture.

### 4.2 CIDR Planning on Paper

CIDR (Classless Inter-Domain Routing) notation defines a range of IP addresses. Before the mental math, here's what's actually happening under the hood.

#### An IP address is just 32 bits (ones and zeros)

You see `10.0.0.0`, but the computer sees:

```
10  .  0   .  0   .  0
↓      ↓      ↓      ↓
00001010.00000000.00000000.00000000
```

Each of the 4 numbers (called octets) is 8 bits. 4 × 8 = **32 bits total**. The range of each octet is 0–255 because 8 bits can represent 2⁸ = 256 values (`00000000` to `11111111`).

#### The `/` number = how many bits are locked

The number after `/` tells you: **how many bits from the left are fixed (the network part).** The remaining bits are yours to use for individual addresses (the host part).

.cidr-title{font-family:'IBM Plex Sans Condensed',sans-serif;font-size:13px;font-weight:700;fill:var(--ink)}
                .cidr-label{font-family:'IBM Plex Sans Condensed',sans-serif;font-size:13px;font-weight:700;fill:var(--accent-strong)}
                .cidr-bits{font-family:'IBM Plex Mono',monospace;font-size:11.5px;fill:var(--surface);letter-spacing:.02em}
                .cidr-note{font-family:'IBM Plex Sans',sans-serif;font-size:11px;fill:var(--ink-muted)}
                .cidr-legend{font-family:'IBM Plex Sans',sans-serif;font-size:11.5px;fill:var(--ink-muted)}
                .cidr-formula-title{font-family:'IBM Plex Sans Condensed',sans-serif;font-size:13px;font-weight:700;fill:var(--accent-strong)}
                .cidr-formula{font-family:'IBM Plex Sans',sans-serif;font-size:11.5px;fill:var(--ink)}
                .cidr-formula-sm{font-family:'IBM Plex Mono',monospace;font-size:11px;fill:var(--ink-muted)}
                .cidr-insight-title{font-family:'IBM Plex Sans Condensed',sans-serif;font-size:13px;font-weight:700;fill:var(--ink-muted)}
                .cidr-insight{font-family:'IBM Plex Sans',sans-serif;font-size:11.5px;fill:var(--ink-muted)}
              
The / number = how many bits are LOCKED from the left
 /16 
/16

00001010.00000000
.

xxxxxxxx.xxxxxxxx
16 bits locked (10.0)
16 bits free → 2¹⁶ = 65,536
 /24 
/24

00001010.00000000.00000000
.

xxxxxxxx
24 bits locked (10.0.0)
8 bits free → 2⁸ = 256
 /28 
/28

00001010.00000000.00000000.0000

xxxx
28 bits locked
4 bits free → 2⁴ = 16
 Legend 

= Network part (locked — same for all addresses in this range)

= Host part (free — each combination = one unique address)
 Formula box 

The formula
Total addresses = 2 ^ (32 − the / number)
 Insight box 

Quick mental shortcut
Bigger / number = fewer addresses (more bits locked)  ·  Smaller / number = more addresses

#### How the calculation works

Each free bit can be either 0 or 1 — two choices. With multiple free bits, you multiply the choices together:

```
/16 → 32 − 16 = 16 free bits

2 × 2 × 2 × 2 × 2 × 2 × 2 × 2 × 2 × 2 × 2 × 2 × 2 × 2 × 2 × 2
└──────────────────────── 16 times ────────────────────────────────┘
= 2¹⁶ = 65,536 addresses
```

```
/24 → 32 − 24 = 8 free bits

2 × 2 × 2 × 2 × 2 × 2 × 2 × 2
└────────── 8 times ───────────┘
= 2⁸ = 256 addresses
```

```
/28 → 32 − 28 = 4 free bits

2 × 2 × 2 × 2
└─ 4 times ──┘
= 2⁴ = 16 addresses
```

Think of it like a combination lock. A 4-digit lock where each digit is 0–9 has 10 × 10 × 10 × 10 = 10,000 combinations. Same idea here — but each "digit" is a bit (only 0 or 1), so it's 2 instead of 10, multiplied by itself for each free bit.

#### Walking through /24 step by step

`10.0.1.0/24` means:

```
10   .   0   .   1   .   0
Fixed    Fixed   Fixed   Free (this octet can be anything 0-255)
```

24 bits are locked = the first 3 octets (`10.0.1`) never change. The last octet (8 bits) is free, so it ranges from 0 to 255:

```
First address:  10.0.1.0
                10.0.1.1
                10.0.1.2
                ...
                10.0.1.254
Last address:   10.0.1.255

Total: 256 addresses
```

#### Now /16

`10.0.0.0/16` means:

```
10   .   0   .   0   .   0
Fixed    Fixed   Free     Free (last 2 octets can be anything)
```

16 bits locked = first 2 octets (`10.0`) never change. The last 2 octets are free:

```
First address:  10.0.0.0
                10.0.0.1
                ...
                10.0.0.255
                10.0.1.0      ← third octet increments
                10.0.1.1
                ...
                10.0.255.254
Last address:   10.0.255.255

Total: 256 × 256 = 65,536 addresses
```

#### And /28

`10.0.0.0/28` means 28 bits are locked — that's 3 full octets (24 bits) plus 4 more bits into the last octet. Only 4 bits are free:

```
Last octet in binary: 0000xxxx
                           ↑ only these 4 bits change

xxxx can be: 0000 (0) to 1111 (15)

First address:  10.0.0.0
Last address:   10.0.0.15

Total: 2⁴ = 16 addresses
```

#### The cheat sheet you'll actually use

Every CIDR from /16 to /32. The "third octet range" column is for mid-octet splits — the tricky ones. Pin this somewhere visible.

| CIDR | Free bits | Total addresses | Usable (AWS) | 3rd octet: free bits | 3rd octet range | Used for |
|---|---|---|---|---|---|---|
| `/16` | 16 | 65,536 | 65,531 | 8 (fully free) | 0 – 255 | VPC level |
| `/17` | 15 | 32,768 | 32,763 | 7 | 0 – 127 | Half a VPC |
| `/18` | 14 | 16,384 | 16,379 | 6 | 0 – 63 | Large subnet |
| `/19` | 13 | 8,192 | 8,187 | 5 | 0 – 31 | Large subnet |
| `/20` | 12 | 4,096 | 4,091 | 4 | 0 – 15 | Large subnet |
| `/21` | 11 | 2,048 | 2,043 | 3 | 0 – 7 | Medium subnet |
| `/22` | 10 | 1,024 | 1,019 | 2 | 0 – 3 | Medium subnet |
| `/23` | 9 | 512 | 507 | 1 | 0 – 1 | Medium subnet |
| `/24` | 8 | 256 | 251 | 0 (locked) | — | Standard subnet (most common) |
| `/25` | 7 | 128 | 123 | 4th octet split: 0 – 127 | Small subnet |
| `/26` | 6 | 64 | 59 | 4th octet split: 0 – 63 | Small subnet |
| `/27` | 5 | 32 | 27 | 4th octet split: 0 – 31 | Small subnet |
| `/28` | 4 | 16 | 11 | 4th octet split: 0 – 15 | AWS minimum subnet |
| `/29` | 3 | 8 | 3 | 4th octet split: 0 – 7 | Tiny (only 3 usable!) |
| `/30` | 2 | 4 | — | 4th octet split: 0 – 3 | Point-to-point link |
| `/31` | 1 | 2 | — | 4th octet split: 0 – 1 | Point-to-point link (RFC 3021) |
| `/32` | 0 | 1 | — | Single IP | Security group rules, host routes |

!!! note "Pattern"

    Each step down in the CIDR number **doubles** the addresses. /24 = 256, /23 = 512, /22 = 1,024. Each step up **halves** them. /24 = 256, /25 = 128, /26 = 64.

!!! success "Mid-octet formula"

    For /17 to /23 (third octet splits): spill = /number − 16. Free bits in 3rd octet = 8 − spill. Max value = 2^free − 1.  
    For /25 to /31 (fourth octet splits): same idea but spill = /number − 24.

#### AWS reserves 5 IPs in every subnet

- .0 — network address
- .1 — VPC router
- .2 — DNS server
- .3 — reserved for future use
- .255 — broadcast (not supported in VPC, but reserved)

So a /24 subnet (256 addresses) actually has 251 usable.

#### How this applies to your VPC on Day 4

```
VPC:         10.0.0.0/16      ← your entire network: 65,536 addresses
             │
             ├── 10.0.1.0/24  ← public subnet AZ-a: 256 addresses (251 usable)
             ├── 10.0.2.0/24  ← public subnet AZ-b: 256 addresses
             ├── 10.0.10.0/24 ← private app AZ-a:   256 addresses
             ├── 10.0.11.0/24 ← private app AZ-b:   256 addresses
             ├── 10.0.20.0/24 ← private DB AZ-a:    256 addresses
             └── 10.0.21.0/24 ← private DB AZ-b:    256 addresses

             6 subnets × 256 = 1,536 used out of 65,536 available
             Plenty of room to add more subnets later
```

The VPC is /16 (big pool), and you carve it into /24 subnets (smaller pools) — like dividing a large office floor into rooms: the floor is the VPC, each room is a subnet.

#### Why this layout

- Gaps between ranges (1–2, 10–11, 20–21) leave room for future subnets
- Two AZs for fault tolerance (if AZ-a dies, AZ-b keeps running)
- Three tiers (public, app, database) for network-level isolation
- The 10.0.x.0 numbering makes it easy to identify the tier at a glance

#### Practice: CIDR & Subnetting Quiz

**Q1.** How many total IP addresses are in 10.0.0.0/24?

- **A.** 128
- **B.** 256
- **C.** 512
- **D.** 1,024

??? success "✓ Correct — B) 256"

    32 − 24 = 8 free bits. 2⁸ = 256 addresses.

    **A) 128** — This would be 2⁷, which is a /25 (32 − 7 = 25), not /24.

    **B) 256** — ✓ Correct. 32 − 24 = 8 free bits → 2⁸ = 256.

    **C) 512** — This would be 2⁹, which is a /23 (32 − 9 = 23).

    **D) 1,024** — This would be 2¹⁰, which is a /22.

**Q2.** How many **usable** IP addresses in a /24 subnet on AWS?

- **A.** 256
- **B.** 254
- **C.** 251
- **D.** 250

??? success "✓ Correct — C) 251"

    256 total − 5 reserved by AWS = 251 usable.

    **A) 256** — This is the *total* count, not usable. AWS reserves 5 IPs in every subnet.

    **B) 254** — This would be correct in traditional networking (just .0 and .255 reserved). But AWS reserves 5: .0 (network), .1 (router), .2 (DNS), .3 (future), .255 (broadcast).

    **C) 251** — ✓ Correct. 256 − 5 = 251 usable.

    **D) 250** — Off by one. Only 5 are reserved, not 6.

**Q3.** What is the IP range of 10.0.5.0/24?

- **A.** 10.0.5.0 – 10.0.5.255
- **B.** 10.0.0.0 – 10.0.5.255
- **C.** 10.0.5.0 – 10.0.6.0
- **D.** 10.0.5.0 – 10.0.5.128

??? success "✓ Correct — A) 10.0.5.0 – 10.0.5.255"

    /24 locks the first 3 octets (10.0.5). Only the last octet is free (0–255).

    **A) 10.0.5.0 – 10.0.5.255** — ✓ Correct. /24 = first 3 octets locked, last octet free (0–255).

    **B) 10.0.0.0 – 10.0.5.255** — Wrong. This starts at 10.0.0.0, but the CIDR starts at 10.0.5.0. The third octet is locked at 5, not ranging 0–5.

    **C) 10.0.5.0 – 10.0.6.0** — Wrong. This crosses into the next subnet (10.0.6.x). A /24 stays within one value of the third octet.

    **D) 10.0.5.0 – 10.0.5.128** — Wrong. This is only half the range. A /24 goes up to .255, not .128. A range ending at .128 would be closer to a /25.

**Q4.** How many addresses in a /20 subnet?

- **A.** 1,024
- **B.** 2,048
- **C.** 4,096
- **D.** 8,192

??? success "✓ Correct — C) 4,096"

    32 − 20 = 12 free bits. 2¹² = 4,096.

    **A) 1,024** — This is 2¹⁰ = /22 (32 − 10 = 22).

    **B) 2,048** — This is 2¹¹ = /21 (32 − 11 = 21).

    **C) 4,096** — ✓ Correct. 2¹² = /20.

    **D) 8,192** — This is 2¹³ = /19 (32 − 13 = 19).

**Q5.** Which CIDR gives you exactly 16 addresses?

- **A.** /26
- **B.** /27
- **C.** /28
- **D.** /30

??? success "✓ Correct — C) /28"

    16 = 2⁴. You need 4 free bits. 32 − 4 = 28.

    **A) /26** — 32 − 26 = 6 free bits → 2⁶ = 64 addresses. Too many.

    **B) /27** — 32 − 27 = 5 free bits → 2⁵ = 32 addresses. Still too many.

    **C) /28** — ✓ Correct. 32 − 28 = 4 free bits → 2⁴ = 16.

    **D) /30** — 32 − 30 = 2 free bits → 2² = 4 addresses. Too few.

**Q6.** You have 10.0.0.0/16 as your VPC. Can 10.0.3.0/24 be a subnet inside it?

- **A.** Yes — 10.0.3.0 falls within the 10.0.0.0/16 range
- **B.** No — /24 is larger than /16
- **C.** No — the third octet must be 0
- **D.** Yes — but only if it's in the same AZ

??? success "✓ Correct — A) Yes"

    This is purely a math question: does the subnet's range fit inside the VPC's range?

    **A) Yes — falls within range** — ✓ Correct. VPC range is 10.0.0.0–10.0.255.255. Subnet range is 10.0.3.0–10.0.3.255. It fits.

    **B) No — /24 is larger than /16** — Backwards. Larger / number = smaller subnet. /24 (256 IPs) is smaller than /16 (65,536 IPs), so it fits inside.

    **C) No — third octet must be 0** — Wrong. The /16 VPC covers ALL values of the third octet (0–255). 10.0.3.x, 10.0.99.x, 10.0.200.x all fit.

    **D) Yes — but only if same AZ** — The AZ part is wrong. CIDR validity is pure math — the IPs either fit or they don't, regardless of which AZ you place the subnet in. You choose the AZ after the CIDR is validated.

**Q7.** Can these two subnets coexist in the same VPC?  
`10.0.1.0/24` and `10.0.1.128/25`

- **A.** Yes — they're different CIDR blocks
- **B.** No — they overlap (10.0.1.128–255 is in both)
- **C.** Yes — /25 is smaller so it fits inside /24
- **D.** No — you can't use /25 in AWS

??? success "✓ Correct — B) No, they overlap"

    Write out both ranges — the overlap becomes obvious.

    **A) Yes — different CIDRs** — Different CIDR notation doesn't mean non-overlapping. 10.0.1.0/24 covers .0–.255; 10.0.1.128/25 covers .128–.255. The .128–.255 range exists in both — that's an overlap. AWS rejects this.

    **B) No — they overlap** — ✓ Correct. /24 = 10.0.1.0–10.0.1.255. /25 = 10.0.1.128–10.0.1.255. The second range is entirely inside the first.

    **C) Yes — /25 fits inside /24** — "Fits inside" is exactly the problem! Two subnets cannot overlap — each IP address must belong to exactly one subnet. The /25 is a subset of the /24, so they conflict.

    **D) No — can't use /25** — You can use /25 in AWS. The minimum is /28. The problem is the overlap, not the prefix length.

**Q8.** You need a subnet for 100 EC2 instances on AWS. What's the smallest CIDR that fits?

- **A.** /25 (128 addresses, 123 usable)
- **B.** /24 (256 addresses, 251 usable)
- **C.** /26 (64 addresses, 59 usable)
- **D.** /27 (32 addresses, 27 usable)

??? success "✓ Correct — A) /25"

    You need 100 instances + 5 AWS reserved = 105 minimum. Find the smallest power of 2 that's ≥ 105.

    **A) /25 — 128 total, 123 usable** — ✓ Correct. 123 usable ≥ 100 needed. This is the smallest CIDR that works.

    **B) /24 — 256 total, 251 usable** — Works, but wastes 151 addresses. /25 is sufficient and more efficient.

    **C) /26 — 64 total, 59 usable** — Too small. 59 usable < 100 needed. You'd run out of IPs.

    **D) /27 — 32 total, 27 usable** — Way too small. Only 27 usable IPs for 100 instances.

**Q9.** What is the IP range of 172.16.0.0/20?

- **A.** 172.16.0.0 – 172.16.0.255
- **B.** 172.16.0.0 – 172.16.15.255
- **C.** 172.16.0.0 – 172.16.31.255
- **D.** 172.16.0.0 – 172.16.255.255

??? success "✓ Correct — B) 172.16.0.0 – 172.16.15.255"

    /20 locks 20 bits. The first 2 octets use 16 bits, leaving 4 more locked bits in the third octet. The third octet is *split*: upper 4 bits locked, lower 4 bits free.

    **A) 172.16.0.0 – 172.16.0.255** — This is a /24 (only 256 addresses). /20 is much larger — 4,096 addresses. The third octet isn't locked at 0; it can range 0–15.

    **B) 172.16.0.0 – 172.16.15.255** — ✓ Correct. 4 free bits in the third octet → 2⁴ − 1 = 15 → range 0–15. Fourth octet fully free (0–255). Total: 16 × 256 = 4,096.

    **C) 172.16.0.0 – 172.16.31.255** — This would be /19. In /19: 32 − 19 = 13 free bits. Third octet has 5 free bits → 2⁵ − 1 = 31. Close, but one bit off from /20.

    **D) 172.16.0.0 – 172.16.255.255** — This is a /16 (entire third and fourth octets free). /20 locks 4 bits of the third octet, so it can only go up to 15, not 255.

**Q10.** Your VPC is 10.0.0.0/16. How many /24 subnets can it hold?

- **A.** 16
- **B.** 64
- **C.** 256
- **D.** 512

??? success "✓ Correct — C) 256"

    Divide the VPC's total by the subnet's size: 65,536 ÷ 256 = 256.

    **A) 16** — This would be correct if each subnet were /20 (4,096 addresses). 65,536 ÷ 4,096 = 16.

    **B) 64** — This would be /24-sized subnets in a /18 VPC. 16,384 ÷ 256 = 64.

    **C) 256** — ✓ Correct. /16 = 65,536 addresses. /24 = 256 addresses. 65,536 ÷ 256 = 256. The third octet (0–255) gives exactly 256 possible /24 blocks.

    **D) 512** — This would be /25-sized subnets (128 each) in a /16 VPC. 65,536 ÷ 128 = 512.

#### Deep Practice: CIDR — Building from Basics to Mid-Octet Splits

**Q1.** How many total bits are in an IPv4 address?

- **A.** 16 bits
- **B.** 32 bits
- **C.** 64 bits
- **D.** 128 bits

??? success "✓ Correct — B) 32 bits"

    An IP address is 4 octets × 8 bits = 32 bits. This never changes for IPv4.

    **A) 16 bits** — This is only 2 octets. An IPv4 address has 4 octets.

    **B) 32 bits** — ✓ Correct. 4 octets × 8 bits = 32.

    **C) 64 bits** — This would be 8 octets. IPv4 only has 4.

    **D) 128 bits** — This is the size of an IPv6 address, not IPv4.

**Q2.** In 10.0.0.0/24, what does the /24 mean?

- **A.** The number of servers allowed
- **B.** The total number of addresses
- **C.** How many bits are locked from the left (the network part)
- **D.** The cost tier of the subnet

??? success "✓ Correct — C) Bits locked from the left"

    The / number tells you how many of the 32 bits are fixed (the network part). The remaining bits are free for host addresses.

    **A) Number of servers** — No, the / has nothing to do with server count directly. It defines the address range size.

    **B) Total addresses** — Close idea, but the / number isn't the count itself. It's the locked bits. You calculate addresses from it: 2^(32 − /number).

    **C) Bits locked from the left** — ✓ Correct. /24 = 24 bits locked, 8 bits free.

    **D) Cost tier** — No, CIDR has nothing to do with pricing.

**Q3.** If 24 bits are locked, how many bits are FREE?

- **A.** 8
- **B.** 24
- **C.** 16
- **D.** 4

??? success "✓ Correct — A) 8"

    32 total − 24 locked = 8 free bits. This subtraction is the first step of every CIDR calculation.

    **A) 8** — ✓ Correct. 32 − 24 = 8.

    **B) 24** — That's the locked bits, not the free bits. You subtracted the wrong way.

    **C) 16** — This would be 32 − 16, which is a /16, not /24.

    **D) 4** — This would be 32 − 28, which is a /28.

**Q4.** If you have 3 free bits, how many addresses? (2 × 2 × 2 = ?)

- **A.** 6
- **B.** 8
- **C.** 9
- **D.** 12

??? success "✓ Correct — B) 8"

    Each bit has 2 choices (0 or 1). You multiply: 2 × 2 × 2 = 8.

    **A) 6** — You might have added: 2 + 2 + 2 = 6. But bits multiply, not add.

    **B) 8** — ✓ Correct. 2 × 2 × 2 = 2³ = 8.

    **C) 9** — You might be thinking 3² = 9. But it's 2³, not 3².

    **D) 12** — No standard operation on 2 and 3 gives 12 here.

**Q5.** How many addresses in a /26? (Two steps: free bits, then 2^free)

- **A.** 26
- **B.** 32
- **C.** 64
- **D.** 128

??? success "✓ Correct — C) 64"

    Step 1: 32 − 26 = 6 free bits. Step 2: 2⁶ = 64.

    **A) 26** — That's the / number itself, not the address count. Don't confuse the two.

    **B) 32** — This is 2⁵ = /27. One bit off.

    **C) 64** — ✓ Correct. 2⁶ = 2×2×2×2×2×2 = 64.

    **D) 128** — This is 2⁷ = /25. You subtracted one too many.

**Q6.** How many addresses in a /25?

- **A.** 128
- **B.** 64
- **C.** 256
- **D.** 32

??? success "✓ Correct — A) 128"

    32 − 25 = 7 free bits. 2⁷ = 128.

    **A) 128** — ✓ Correct. 2⁷ = 128.

    **B) 64** — This is 2⁶ = /26. One bit too few.

    **C) 256** — This is 2⁸ = /24. One bit too many.

    **D) 32** — This is 2⁵ = /27. Two bits too few.

**Q7.** Which is SMALLER: /24 or /28?

- **A.** /28 is bigger — it has more addresses
- **B.** /28 is smaller — it has fewer addresses (16 vs 256)
- **C.** They're the same size
- **D.** It depends on the region

??? success "✓ Correct — B) /28 is smaller"

    Bigger / number = more locked bits = fewer free bits = fewer addresses = smaller subnet.

    **A) /28 is bigger** — This is the most common CIDR mistake. The / number and the size go in opposite directions. /28 locks more bits, so fewer addresses.

    **B) /28 is smaller** — ✓ Correct. /28 = 2⁴ = 16 addresses. /24 = 2⁸ = 256 addresses.

    **C) Same size** — No, different / numbers always give different sizes.

    **D) Depends on region** — CIDR is pure math. Region doesn't affect it.

**Q8.** What is the range of 10.0.5.0/24?

- **A.** 10.0.5.0 – 10.0.5.255
- **B.** 10.0.0.0 – 10.0.5.255
- **C.** 10.0.5.0 – 10.0.255.255
- **D.** 10.5.0.0 – 10.5.255.255

??? success "✓ Correct — A) 10.0.5.0 – 10.0.5.255"

    /24 locks 3 octets. The third octet is 5 and stays 5. Only the last octet is free: 0–255.

    **A) 10.0.5.0 – 10.0.5.255** — ✓ Correct. Three octets locked (10.0.5), last octet free (0–255).

    **B) 10.0.0.0 – 10.0.5.255** — Wrong start address. The CIDR starts at 10.0.5.0, not 10.0.0.0. The third octet is locked at 5.

    **C) 10.0.5.0 – 10.0.255.255** — This frees the third octet (5–255). That would be a /16 starting at 10.0.5.0, not a /24.

    **D) 10.5.0.0 – 10.5.255.255** — The 5 moved to the second octet. The original has 5 in the third octet position.

**Q9.** What is the range of 10.0.0.0/16?

- **A.** 10.0.0.0 – 10.0.0.255
- **B.** 10.0.0.0 – 10.0.16.255
- **C.** 10.0.0.0 – 10.0.255.255
- **D.** 10.0.0.0 – 10.255.255.255

??? success "✓ Correct — C) 10.0.0.0 – 10.0.255.255"

    /16 locks 2 octets (10.0). The third AND fourth octets are both free (each 0–255).

    **A) 10.0.0.0 – 10.0.0.255** — This is a /24 (only last octet free). /16 frees two octets.

    **B) 10.0.0.0 – 10.0.16.255** — The "16" doesn't go into the IP range. /16 means 16 bits locked, which frees the entire third and fourth octets.

    **C) 10.0.0.0 – 10.0.255.255** — ✓ Correct. Two octets locked (10.0), two free (0–255 each).

    **D) 10.0.0.0 – 10.255.255.255** — This frees three octets, which would be a /8, not /16.

**Q10.** /16 locks 16 bits. How many **full octets** is that?

- **A.** 1 full octet (the first)
- **B.** 2 full octets (the first two)
- **C.** 3 full octets
- **D.** 16 octets

??? success "✓ Correct — B) 2 full octets"

    16 bits ÷ 8 bits per octet = exactly 2 octets. This is a clean octet boundary — no splitting.

    **A) 1 octet** — 1 octet = 8 bits. That's a /8, not /16.

    **B) 2 octets** — ✓ Correct. 16 ÷ 8 = 2. Clean boundary.

    **C) 3 octets** — 3 octets = 24 bits. That's a /24.

    **D) 16 octets** — Octets and bits are different. 16 bits = 2 octets, not 16 octets.

**Q11.** /20 locks 20 bits. The first 2 octets use 16 bits. Where do the remaining 4 locked bits go?

- **A.** Exactly 2 full octets, nothing more
- **B.** 2 full octets + 4 bits into the third octet
- **C.** 2 full octets + the entire third octet
- **D.** 20 octets

??? success "✓ Correct — B) 2 octets + 4 bits into the third"

    20 − 16 = 4 extra bits that spill into the third octet. The third octet is now SPLIT: 4 bits locked, 4 bits free. This is what makes mid-octet CIDRs like /20 tricky.

    **A) Exactly 2 octets** — That would only be 16 bits. We have 20 to lock — 4 more bits need to go somewhere.

    **B) 2 octets + 4 bits into the third** — ✓ Correct. 16 + 4 = 20. The third octet is split in half.

    **C) 2 octets + entire third** — The entire third octet would be 8 more bits = 24 total. That's a /24, not /20.

    **D) 20 octets** — An IPv4 address only has 4 octets total.

**Q12.** In a /20, the third octet has 4 locked bits and 4 free bits. What values can the third octet be?

- **A.** Only 0 (it's fully locked)
- **B.** 0 – 3 (4 values)
- **C.** 0 – 15 (16 values)
- **D.** 0 – 255 (fully free)

??? success "✓ Correct — C) 0 – 15"

    4 free bits = 2⁴ = 16 possible values. Range: 0 to 15.

    **A) Only 0** — It's not fully locked — 4 bits are free. Zero free bits would mean a value of only 0.

    **B) 0 – 3** — 4 values = 2² = 2 free bits. But we have 4 free bits, not 2. Don't confuse the number of free bits (4) with the number of values from 2 free bits (4).

    **C) 0 – 15** — ✓ Correct. 4 free bits → 2⁴ = 16 values → 0 through 15.

    **D) 0 – 255** — That would mean all 8 bits are free, which is a /16. In /20, only 4 of the 8 bits in the third octet are free.

**Q13.** Now put it together: what is the range of 172.16.0.0/20?

- **A.** 172.16.0.0 – 172.16.0.255
- **B.** 172.16.0.0 – 172.16.15.255
- **C.** 172.16.0.0 – 172.16.31.255
- **D.** 172.16.0.0 – 172.16.255.255

??? success "✓ Correct — B) 172.16.0.0 – 172.16.15.255"

    Combine everything from the previous questions: first 2 octets locked (172.16). Third octet: 0–15 (4 free bits). Fourth octet: 0–255 (fully free).

    **A) 172.16.0.0 – 172.16.0.255** — This is a /24 (256 addresses). It only uses the fourth octet. /20 is much bigger — 4,096 addresses spread across 16 values of the third octet.

    **B) 172.16.0.0 – 172.16.15.255** — ✓ Correct. Third octet: 0–15 (from Q12). Fourth octet: 0–255. Total: 16 × 256 = 4,096.

    **C) 172.16.0.0 – 172.16.31.255** — 31 = 2⁵ − 1 = 5 free bits in third octet. That's /19 (19 locked = 16 + 3), not /20 (16 + 4). One extra free bit.

    **D) 172.16.0.0 – 172.16.255.255** — 255 means the entire third octet is free = /16. The /20 locks 4 bits of the third octet, limiting it to 0–15.

**Q14.** Same method — what is the range of 192.168.0.0/19?

- **A.** 192.168.0.0 – 192.168.15.255
- **B.** 192.168.0.0 – 192.168.19.255
- **C.** 192.168.0.0 – 192.168.31.255
- **D.** 192.168.0.0 – 192.168.63.255

??? success "✓ Correct — C) 192.168.0.0 – 192.168.31.255"

    /19: 19 − 16 = 3 bits locked in third octet. 8 − 3 = 5 free bits. 2⁵ = 32 values = 0–31.

    **A) ...15.255** — 15 = 2⁴ − 1 = 4 free bits in third octet. That's /20, not /19.

    **B) ...19.255** — 19 is the / number, not the max of the third octet. Don't put the / number into the range.

    **C) ...31.255** — ✓ Correct. 5 free bits → 2⁵ = 32 → max value = 31.

    **D) ...63.255** — 63 = 2⁶ − 1 = 6 free bits. That's /18 (16 + 2 locked in third), not /19.

**Q15.** What is the range and size of 10.1.0.0/21?

- **A.** 10.1.0.0 – 10.1.0.255 (256 addresses)
- **B.** 10.1.0.0 – 10.1.3.255 (1,024 addresses)
- **C.** 10.1.0.0 – 10.1.15.255 (4,096 addresses)
- **D.** 10.1.0.0 – 10.1.7.255 (2,048 addresses)

??? success "✓ Correct — D) 10.1.0.0 – 10.1.7.255 (2,048)"

    /21: 21 − 16 = 5 bits locked in third octet. 8 − 5 = 3 free bits. 2³ = 8 values = 0–7. Fourth octet fully free. Total: 8 × 256 = 2,048.

    **A) ...0.255 (256)** — This is a /24. Only the fourth octet is free. /21 has 3 free bits in the third octet too.

    **B) ...3.255 (1,024)** — 3 = 2² − 1 = 2 free bits in third octet = /22 (16 + 6). Close, but one bit off from /21.

    **C) ...15.255 (4,096)** — 15 = 2⁴ − 1 = 4 free bits = /20. /21 has one fewer free bit.

    **D) ...7.255 (2,048)** — ✓ Correct. 3 free bits → 2³ = 8 → max value 7. Total: 8 × 256 = 2,048.

### 4.3 Subnet Types: Public vs Private

Public subnet
:   Has a route to the Internet Gateway. Instances can have public IPs and be reached from the internet (if the security group allows it). Used for load balancers, bastion hosts, NAT gateways.

Private subnet
:   No direct route to the internet. Instances can't be reached from outside; they access the internet through a NAT Gateway in a public subnet. Used for application servers, databases, anything that shouldn't be directly internet-accessible.

!!! success "Golden rule"

    Databases and application servers go in private subnets. Only load balancers and NAT gateways go in public subnets.

### 4.4 Route Tables

Every subnet is associated with a route table that determines where traffic goes.

#### Public subnet route table

```
Destination        Target
10.0.0.0/16        local           ← traffic within the VPC stays in the VPC
0.0.0.0/0          igw-xxxxxxxx    ← everything else goes to the Internet Gateway
```

#### Private subnet route table

```
Destination        Target
10.0.0.0/16        local           ← traffic within the VPC stays in the VPC
0.0.0.0/0          nat-xxxxxxxx    ← everything else goes through NAT Gateway
```

The difference: public subnets route to the Internet Gateway (direct, bidirectional). Private subnets route through a NAT Gateway (outbound only — the internet can't initiate connections in).

### 4.5 Key Network Components

#### Internet Gateway (IGW)

Attached to the VPC. Provides a path between the VPC and the internet — instances in public subnets with a public IP communicate through it. One IGW per VPC; horizontally scaled, redundant, and managed by AWS — not a bottleneck.

#### NAT Gateway

Sits in a public subnet. Lets private-subnet instances initiate outbound connections (downloading updates, calling external APIs) without being reachable from the internet.

!!! note "Cost"

    $0.045/hour (~$32/month) per NAT Gateway, plus data processing charges. For production, put one in each AZ for fault tolerance. For dev/learning, one is enough — just know it's a single point of failure.

!!! success "Cost-saving tip"

    Consider a NAT Instance (a small EC2 instance configured to do NAT) instead — ~$3/month for a t3.nano vs $32/month. Less reliable, but fine for learning.

#### Bastion Host (Jump Box)

An EC2 instance in a public subnet that you SSH into, then SSH from there into private instances — the only instance with a public IP and SSH access, a single auditable entry point into your private network.

**Modern alternative:** AWS Systems Manager Session Manager — no bastion, no SSH keys to manage, all sessions logged in CloudTrail.

### 4.6 Security Groups vs NACLs

Two layers of firewall, working at different levels.

| Aspect | Security Group | NACL |
|---|---|---|
| **Level** | Instance (attached to ENI) | Subnet (all traffic entering/leaving) |
| **State** | Stateful — allowed inbound response is auto-allowed outbound | Stateless — must explicitly allow both directions |
| **Rules** | Allow only (implicit deny for everything else) | Allow and Deny, evaluated in rule-number order |
| **Default** | Deny all inbound, allow all outbound | Allow all inbound and outbound |
| **Evaluation** | All rules together (most permissive wins) | In order (first match wins) |

#### Practical security group design

!!! note "ALB (public)"

    ```
    Inbound:  TCP 443 from 0.0.0.0/0     (HTTPS from anywhere)
    Inbound:  TCP 80 from 0.0.0.0/0      (HTTP, redirects to HTTPS)
    Outbound: All traffic to app-sg        (forward to app servers)
    ```

!!! note "App servers"

    ```
    Inbound:  TCP 8080 from alb-sg        (only from the load balancer)
    Outbound: TCP 5432 to db-sg           (connect to database)
    Outbound: TCP 443 to 0.0.0.0/0       (call external APIs via NAT)
    ```

!!! note "Database"

    ```
    Inbound:  TCP 5432 from app-sg        (only from app servers)
    Outbound: None needed                  (database doesn't initiate connections)
    ```

**Notice the chain:** internet → ALB (443) → app (only from ALB) → database (only from app). Each layer only talks to its neighbor — the database cannot be reached from the internet, there's no path.

### 4.7 VPC Flow Logs

Captures metadata about IP traffic flowing through your VPC — source/destination IP, port, protocol, action (ACCEPT/REJECT), bytes transferred. Doesn't capture packet contents — it's metadata, not a packet capture.

Sent to CloudWatch Logs or S3. Essential for:

- Debugging connectivity issues ("why can't my app reach the database?")
- Security auditing ("who tried to access this subnet?")
- Compliance ("prove that no unauthorized traffic reached the database subnet")

### 4.8 Building the VPC by Hand — Step by Step

The practical exercise for Day 4. Do it in the console first to understand each component, then repeat via CLI to prove you can script it.

1. Create the VPC with CIDR 10.0.0.0/16
2. Create 6 subnets (public × 2 AZs, private-app × 2 AZs, private-db × 2 AZs)
3. Create and attach an Internet Gateway
4. Create a NAT Gateway in one public subnet (allocate an Elastic IP first)
5. Create route tables — public → 0.0.0.0/0 to IGW, associate with public subnets; private → 0.0.0.0/0 to NAT Gateway, associate with private subnets
6. Create security groups (ALB-sg, app-sg, db-sg) with the rules described above
7. Enable VPC Flow Logs to CloudWatch
8. Verify: launch a test instance in the public subnet, confirm internet access. Launch one in the private subnet, confirm it can reach the internet via NAT but cannot be reached from outside.

### 4.9 Why Each Component Exists — and What Breaks Without It

Now that you've built every piece, here's the full justification for each one — what it does, why it exists, and what fails if you remove it.

.vd-title{font-family:'IBM Plex Sans Condensed',sans-serif;font-size:13px;font-weight:700;fill:var(--ink)}
                .vd-label{font-family:'IBM Plex Sans Condensed',sans-serif;font-size:13px;font-weight:700;fill:var(--accent-strong)}
                .vd-chip{font-family:'IBM Plex Mono',monospace;font-size:11.5px;fill:var(--surface);letter-spacing:.01em}
                .vd-note{font-family:'IBM Plex Sans',sans-serif;font-size:11px;fill:var(--ink-muted)}
                .vd-legend{font-family:'IBM Plex Sans',sans-serif;font-size:11.5px;fill:var(--ink-muted)}
              
How the pieces fit together

Internet


Internet Gateway



VPC 10.0.0.0/16 — fahad-devops-vpc
AZ-a — ap-south-1a
AZ-b — ap-south-1b
 Public subnets 

Public 10.0.1.0/24

ALB (alb-sg)

NAT Gateway

Public 10.0.2.0/24

ALB (alb-sg)


 Private app subnets 

Private app 10.0.10.0/24

EC2 (app-sg)

Private app 10.0.11.0/24

EC2 (app-sg)


 Private DB subnets 

Private DB 10.0.20.0/24

RDS (db-sg)

Private DB 10.0.21.0/24

RDS (db-sg)
 Legend 

Public subnet — internet-facing (ALB, NAT)

Private app subnet — reachable only from the ALB

Private DB subnet — reachable only from the app tier
Only one NAT Gateway (in AZ-a) — a deliberate cost trade-off for this learning build.
Production would place one NAT per AZ for redundancy.

#### VPC (fahad-devops-vpc — 10.0.0.0/16)

What it does
:   Your private isolated network inside AWS. Nothing can enter or leave unless you explicitly allow it.

Why it exists
:   Without a VPC, all your resources sit on a shared flat network. The VPC is the wall around your house — it defines what's inside your network and what's outside.

Without it
:   You'd have to use the default VPC, which puts everything in public subnets with public IPs. Fine for testing; a security risk for production.

#### Public subnets (10.0.1.0/24, 10.0.2.0/24)

What they do
:   Subnets where the route table points `0.0.0.0/0` to the Internet Gateway. Resources here can have public IPs and be reached from the internet.

Why they exist
:   The ALB needs to receive traffic from users on the internet. The NAT Gateway needs internet access to relay traffic for private instances. These are the *only* things that should be internet-facing.

Without them
:   No way for users to reach your application — your ALB would have no internet connectivity.

Why two?
:   One per AZ (ap-south-1a and ap-south-1b). If AZ-a goes down, the ALB in AZ-b keeps serving. This is high availability.

#### Application Load Balancer (fahad-alb)

What it does
:   Sits in both public subnets, terminates TLS, and distributes incoming requests across healthy targets in the app subnets.

Why it exists
:   Users need one stable DNS name to hit, not a shifting list of individual EC2 IPs. The ALB also health-checks targets — if the App instance in AZ-a stops responding, the ALB simply stops sending it traffic, no manual intervention needed.

Without it
:   You'd expose EC2 instances directly to the internet (defeating the whole private-subnet design), or hand out individual instance IPs that break every time Auto Scaling replaces one.

Why registered in both public subnets?
:   An ALB is inherently multi-AZ — AWS runs its nodes in every AZ you attach it to. Registering both public subnets gives it the same redundancy as the rest of the architecture, for free.

#### Private app subnets (10.0.10.0/24, 10.0.11.0/24)

What they do
:   Subnets with no direct internet route. Traffic goes outbound only through the NAT Gateway.

Why they exist
:   Your application servers don't need to be internet-facing. They receive traffic *only* from the ALB, and reach the internet *only* through NAT. Even if your app has a vulnerability, an attacker can't directly connect from the internet.

Without them
:   You'd put app servers in public subnets with public IPs. Any misconfigured security group would expose them directly to the internet.

#### EC2 instances (Auto Scaling group, app-sg)

What they do
:   Run the actual application code, one per AZ at minimum, launched through an Auto Scaling Group rather than as standalone instances.

Why Auto Scaling instead of a fixed instance?
:   If an instance crashes or an AZ has issues, the ASG launches a replacement automatically in a healthy AZ — you don't get paged to manually relaunch a server at 2am.

Why they can only be reached through the ALB
:   `app-sg` only allows inbound traffic from `alb-sg`. Even if you know an instance's private IP, you can't connect to it directly — traffic has to come through the load balancer, which is the only thing the security group trusts.

#### Private DB subnets (10.0.20.0/24, 10.0.21.0/24)

What they do
:   The most isolated subnets. No internet route at all (or outbound-only via NAT for updates).

Why they exist
:   Your database is the crown jewel — it holds all your customer data. It should *only* be reachable from the app servers, nothing else. Not from the internet, not from your laptop, not from any other service.

Why separate from app subnets?
:   So you can apply different security groups per tier. DB-sg only allows port 5432 from App-sg. Separate subnets also let you apply different NACL rules per tier.

#### RDS (db-sg)

What it does
:   A managed relational database in the private DB subnets, holding the application's persistent data.

Why it exists
:   `db-sg` allows inbound traffic only from `app-sg` on port 5432. The database has no route to the internet in either direction — nothing outside the app tier can reach it, and it can't reach out.

Without it
:   You'd run your own database engine on EC2, taking on patching, backups, and failover yourself — the trade-off from the shared responsibility model in [3.2](iam-accounts.md#32-shared-responsibility-model).

Why two DB subnets, one per AZ?
:   So RDS Multi-AZ has somewhere to place a synchronous standby in AZ-b. If the primary in AZ-a fails, AWS promotes the standby automatically — the active-passive failover pattern from [2.6](principles.md#26-multi-region-architecture), applied at the database layer.

#### Internet Gateway (fahad-igw)

What it does
:   The door between your VPC and the public internet. Bidirectional — traffic flows both in and out.

Why it exists
:   Without it, nothing in your VPC can reach the internet, and no one on the internet can reach anything in your VPC. Your ALB wouldn't work, your users couldn't connect.

Without it
:   A completely isolated VPC. Useful for extremely sensitive air-gapped workloads, but not for a web application.

Key detail
:   One IGW per VPC. Fully managed by AWS — horizontally scaled, redundant, never a bottleneck.

#### NAT Gateway (fahad-nat)

What it does
:   Sits in a public subnet, relays outbound traffic for private subnets. One-way — the internet can't initiate connections through it.

Why it exists
:   Your app servers in private subnets need to reach the internet: downloading OS updates, calling external APIs (Stripe, SendGrid), pulling Docker images. NAT lets them do this without being directly reachable.

Without it
:   Your private instances would be completely isolated — they couldn't install packages, call external services, or push metrics to external monitoring.

Why in a public subnet?
:   The NAT needs internet access to relay traffic. It gets this through the IGW via the public route table. Putting it in a private subnet would create a chicken-and-egg problem — NAT needs internet to provide internet.

!!! danger "Cost warning"

    NAT Gateway is ~$32/month — the most expensive component in your VPC. Delete it when not studying. Also delete the Elastic IP after, or it charges too.

#### Route tables (fahad-public-rt, fahad-private-rt)

What they do
:   Rules that tell traffic where to go. Every subnet is associated with one route table: "if the destination matches this CIDR, send it there."

Why they exist
:   Without route tables, traffic inside the VPC wouldn't know how to reach the internet or other subnets. Route tables are the GPS of your network.

| Route table | Rule | Meaning |
|---|---|---|
| **fahad-public-rt** | `10.0.0.0/16 → local` | Traffic within the VPC stays internal |
| `0.0.0.0/0 → IGW` | Everything else goes to the internet |
| **fahad-private-rt** | `10.0.0.0/16 → local` | Traffic within the VPC stays internal |
| `0.0.0.0/0 → NAT` | Everything else goes outbound through NAT |

!!! note "Without them"

    Every subnet would use the VPC's main route table (which has only the `local` route). No internet access for anything.

#### Security groups (fahad-alb-sg, fahad-app-sg, fahad-db-sg)

What they do
:   Stateful firewalls attached to individual resources. They define *who* can talk to *whom* on *which port*.

The chain
:   Internet → ALB-sg (port 443) → App-sg (port 8080, only from ALB-sg) → DB-sg (port 5432, only from App-sg)

Without them
:   Everything in the VPC could talk to everything else on any port. A compromised ALB could connect directly to the database.

Why reference security groups (not IPs)?
:   If you wrote "allow from 10.0.1.0/24," you'd have to update it every time the ALB's IP changes. By referencing `ALB-sg` as the source, it automatically applies to anything that has ALB-sg attached — regardless of IP.

#### VPC Flow Logs

What they do
:   Capture metadata about every network connection — source IP, destination IP, port, protocol, accept/reject, bytes. Sent to CloudWatch Logs.

Why they exist
:   When something doesn't work ("my app can't reach the database"), flow logs tell you whether the traffic was attempted and rejected (security group issue) or never attempted (routing issue).

Without them
:   Debugging network issues blind. "Is traffic being blocked or not reaching?" becomes a guessing game.

#### What about NACLs?

!!! note "Deliberately skipped"

    This build kept every subnet's NACL at its AWS default (allow all in, allow all out) and did all the enforcement with security groups instead. Security groups already implement the exact alb → app → db chain from [4.6](#46-security-groups-vs-nacls); stacking a second, stateless firewall on top adds real operational cost (remembering to open *both* directions for every rule) without adding protection this architecture doesn't already have. Custom NACLs earn their place as a second layer at the public subnet boundary in stricter, compliance-driven environments — worth revisiting later, not required for this build.

#### How a user request flows through all these components

```
1. User types your-app.com
2. Route 53 resolves to ALB's IP
3. Request hits ALB in public subnet         (ALB-sg allows port 443)
4. ALB forwards to EC2 in private app subnet (App-sg allows from ALB-sg)
5. EC2 queries RDS in private DB subnet      (DB-sg allows from App-sg)
6. Response flows back: RDS → EC2 → ALB → user

If EC2 needs to call Stripe API:
7. EC2 → NAT Gateway → IGW → internet       (outbound only, no inbound)
```

!!! success "The test"

    For each component, ask: "what breaks if I remove this?" If you can answer that for every piece, you understand the VPC. If you can't, re-read that component's section.
