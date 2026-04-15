# Blockchain / Ledger / Cryptocurrency — Best Features, Mapped to S7

**Research brief.** Not a recommendation to build a coin or chain.
A survey of what real distributed-ledger systems do well, paired
against what S7 already has, what S7 should consider adopting,
and what S7 should **refuse** on covenant grounds.

Jamie's ask, 2026-04-13: *"research blockchain legder cryptocurrency
and the best features."*

The framing: S7 already has most of what blockchain gives you,
without the energy cost, the speculation, or the pseudonymous
maximalism. This doc is about which *real* features from the
crypto world are worth stealing, and which are covenant-forbidden.

---

## Part 1 — Cryptographic primitives (the foundation)

| Feature | What it does | S7 has it? | Verdict |
|---|---|---|---|
| **SHA-256 / SHA-3 hash chain** | every entry references previous entry's hash → tamper-evident sequential log | partial — `source_text_hash` per row, no chain linkage yet | **adopt** — add `prev_row_hash` to `audit.file_change_history` so each row Merkle-links to the previous |
| **Merkle tree** | efficient proof that an item is in a large set without revealing the whole set | no | **consider** — build a Merkle root over `cws_core.location_id` daily, publish root in `appliance.snapshot` |
| **EdDSA / Ed25519** | fast, short signatures; every tx signed by the author's private key | yes — ISOs signed with ssh-ed25519 | **already in** |
| **Threshold signatures (FROST, MuSig2)** | N-of-M signers produce one signature; no single key can sign alone | no | **consider** — perfect fit for the Reporter's 77.777777% threshold |
| **Zero-knowledge proofs (zk-SNARKs / zk-STARKs)** | prove you know something without revealing it | no | **defer** — useful for privacy-preserving matrix queries but heavy to implement |
| **Verifiable Random Functions (VRF)** | deterministic randomness with a signature proving fairness | no | **consider** — useful for fair `akashic_seed` generation without trust |
| **Public-key infrastructure (PKI)** | identity without a central authority | yes — per-appliance akashic_seed + ssh-ed25519 | **already in** |

---

## Part 2 — Consensus mechanisms (how distributed nodes agree)

| Mechanism | Used by | S7 fit | Verdict |
|---|---|---|---|
| **Proof of Work** | Bitcoin, Monero | none | **refuse** — energy waste is against the covenant (civilian + ecological) |
| **Proof of Stake** | Ethereum, Cardano, Solana | minimal | **refuse** — requires a financial stake, pulls the system into speculation |
| **Proof of Authority (PoA)** | Ethereum testnets, private chains | **direct match** | **already in** — S7 already works this way; appliances are pre-authorized by covenant, not elected |
| **Byzantine Fault Tolerance (BFT)** | Tendermint, Hyperledger | partial | **consider** — the 7+1 witness model is BFT-shaped; formalising with a library would harden it |
| **Proof of History** | Solana | none | **defer** — interesting (timestamp chain via VDF) but Solana-specific |
| **Delegated PoS** | EOS, Tron | none | **refuse** — plutocratic governance, against named-stewards model |
| **Proof of Personhood** | Worldcoin | none | **refuse** — iris-biometric dragnet, covenant violation |
| **Proof of Coverage** | Helium | relevant | **inspiration** — for a hypothetical S7 mesh network (future), the "I'm actually here" proof pattern is useful |

**Key insight:** the 7+1 witness set at 77.777777% consensus is
already a BFT variant. What's missing is formal cryptographic
accountability — the witnesses vote but no one signs the vote.
A threshold signature scheme (FROST) would turn the existing
Reporter into a real BFT consensus node.

---

## Part 3 — Ledger structures

| Structure | Examples | S7 fit |
|---|---|---|
| **Linear chain** (one block at a time) | Bitcoin, Litecoin | matches `audit.file_change_history` already |
| **DAG** (multiple parallel branches) | IOTA, Hedera Hashgraph | matches ForToken/RevToken strand structure already! |
| **Sharded** | Ethereum 2, Polkadot | overkill for one-appliance deployment |
| **Sidechains** | Liquid, Polygon | no |
| **Layer 2 rollups (Optimistic, ZK)** | Arbitrum, Optimism, zkSync | no |

**Key insight:** S7's strand model (`for_token` / `rev_token` per
LocationID) is already a DAG. IOTA's "tangle" is essentially the
same shape. The difference is cryptographic linking — S7 uses UUID
references, not hash pointers. **Changing `for_token` / `rev_token`
from UUIDs to content hashes of the parent row would turn the
strand into a proper hash-chained DAG**, tamper-evident end to
end.

---

## Part 4 — Token standards (what you track on the ledger)

| Standard | What it is | S7 analog | Verdict |
|---|---|---|---|
| **ERC-20 (fungible)** | interchangeable units (coins) | none | **refuse** — S7 is not a coin |
| **ERC-721 (NFT)** | unique, transferable tokens | `akashic.ribbon` is close | **partial** — ribbons are innovation provenance, not salable assets |
| **ERC-1155 (semi-fungible)** | batched mixed tokens | none | **refuse** |
| **ERC-5114 (Soulbound)** | **non-transferable** identity tokens | `appliance.appliance` matches | **direct analog already** — S7 appliance rows ARE soulbound: tied to a physical unit, non-transferable, revocable on retirement |
| **DIDs + Verifiable Credentials** (W3C) | decentralized identifiers + signed claims | `license_ledger` is close | **adopt** — add a `did` column to `appliance.appliance` in W3C DID format (`did:s7:S7-REF-0001`) for interoperability with regulators |

**Key insight:** S7 already issues soulbound identity tokens via
`appliance.appliance`. What's missing is the W3C DID wrapper —
a standardized format a regulator / partner / auditor can parse
without learning S7-specific schema.

---

## Part 5 — Privacy features

| Feature | Used by | S7 fit |
|---|---|---|
| **Confidential transactions** | Monero, Mimblewimble | **refuse** — anonymity is against S7's accountability posture |
| **Mixing / coinjoin** | Wasabi, Samourai | **refuse** — same reason |
| **Stealth addresses** | Monero, Zcash | **refuse** — same |
| **Zero-knowledge proofs for payload privacy** | zkSNARKs | **consider** — prove matrix membership without exposing content; non-anonymity-related use |
| **Selective disclosure (Verifiable Credentials + BBS+ sigs)** | Hyperledger AnonCreds | **adopt** — share only the fields a verifier needs |

**Key insight:** privacy-by-obscurity features are against S7's
covenant. Privacy-by-design features (selective disclosure, ZK
membership proofs) are compatible because they preserve
accountability while hiding specific fields.

---

## Part 6 — Governance

| Mechanism | Examples | S7 fit | Verdict |
|---|---|---|---|
| **DAO with token voting** | MakerDAO, Uniswap | plutocratic | **refuse** — against named-stewards model |
| **Quadratic voting** | Gitcoin Grants | fairer | **refuse** — still anonymous, still token-gated |
| **Conviction voting** | 1Hive | time-weighted | **interesting** — maps onto `aptitude_delta` over time |
| **Named stewards** | most traditional orgs | **S7's model** | **already in** — Tonya = Chief of Covenant, Trinity = Foundation of Faith, Jonathan = co-steward, Reporter = algorithmic tiebreaker |
| **1-person-1-vote** | Worldcoin | dragnet biometric | **refuse** — covenant violation |

**Key insight:** S7 rejected DAO governance from the start. The
stewardship model is explicit and named. No governance features
from the crypto world are needed.

---

## Part 7 — Storage

| Feature | Used by | S7 fit | Verdict |
|---|---|---|---|
| **IPFS (content-addressed storage)** | Filecoin, Ceramic | useful | **consider** — any S7 ISO / snapshot could be addressed by its SHA-256 and pinned on IPFS, giving a peer-to-peer distribution layer for X27/R101/F44 |
| **Filecoin / Arweave** (incentivized storage) | Filecoin, Arweave | none | **refuse** — token-incentivized storage pulls into speculation |
| **Git** | — | yes | **already in** — S7 is already git-first |
| **Nostr relays** | Nostr | different shape | **consider** — Nostr's cryptographic event model is a clean public-key ledger without a chain |

---

## Part 8 — What S7 should ADD (concrete adoption list)

Ranked by how much they tighten S7 against covenant needs:

1. **Hash chain on `audit.file_change_history`** — add `prev_row_hash`
   computed from sha256 of previous row. Every new row links to the
   last one. Tamper-evident without any new dependencies. ~1 day.

2. **W3C DID on `appliance.appliance`** — add `did TEXT` column,
   format `did:s7:<serial>`. One column + a helper. Interop with
   regulators and partners for free. ~2 hours.

3. **Merkle root of the matrix in `appliance.snapshot`** — compute
   daily, publish in the snapshot row. Proves matrix state at a
   point in time without exposing content. ~half day.

4. **FROST threshold signature on Reporter verdicts** — when the
   Reporter graduates a FRONTIER to FOUNDATION, require a 7-of-9
   threshold signature across the witness set. Turns the existing
   77.777777% threshold into cryptographic accountability. ~2 days
   with an existing FROST library (Python: `frost-lib`).

5. **Content-hash strand tokens** — change `for_token` / `rev_token`
   from UUID to the sha256 of the target row's canonical
   serialization. Upgrades the strand from "pointer" to "Merkle
   parent pointer." Tamper-evident end to end. ~1 day.

6. **IPFS address for every shipped ISO** — pin X27/R101/F44 ISOs
   on IPFS, record the CID in `akashic.ribbon` alongside
   `first_commit`. Peer-to-peer distribution without trusting
   GitHub Releases. ~half day if an IPFS daemon is available.

---

## Part 9 — What S7 should REFUSE (explicit)

With reasons so future me doesn't relitigate:

- **Any Proof of Work** — energy waste is against the covenant
- **Any token with a market price** — pulls into speculation,
  against civilian-only
- **Cross-chain bridges** — most hacked category in crypto history,
  $2B+ stolen through bridges in 2022-2024; S7 has zero reason to
  expose that attack surface
- **Anonymous addresses / mixers** — against the accountability
  posture (ledger + audit + license_ledger all name the witness)
- **Plutocratic DAO voting** — S7 has named stewards; no governance
  token needed
- **Proof of Personhood via biometric dragnet** — Worldcoin's
  model is a civilian-rights violation on its face

---

## Part 10 — Summary table

| Dimension | S7 today | Best crypto feature | Gap? |
|---|---|---|---|
| Identity | per-appliance akashic_seed + license_ledger | W3C DID | add `did` column (small) |
| Audit ledger | INSERT-only postgres tables | hash-chained log | add `prev_row_hash` (small) |
| Consensus | 77.777777% witness threshold | BFT with threshold sigs | add FROST (medium) |
| Storage proof | none | Merkle root | add daily Merkle root (small) |
| Distribution | git + signed ISOs | IPFS CIDs | optional (small) |
| Privacy | per-appliance cipher | ZK selective disclosure | defer (large) |
| Governance | named stewards | DAO | **reject** |
| Economics | none | tokens | **reject** |

**Bottom line:** S7's architecture already sits inside the
blockchain design space — INSERT-only audit, PKI, strand-DAG,
soulbound identity, consensus threshold. What's missing is ~3
small additions (hash chain on audit, DID column, Merkle root on
snapshots) and 1 medium one (FROST threshold sigs on Reporter).
Everything else from the crypto world is either already present
in a different form or covenant-forbidden.

S7 is what blockchain wanted to be before it got distracted by
token prices.
