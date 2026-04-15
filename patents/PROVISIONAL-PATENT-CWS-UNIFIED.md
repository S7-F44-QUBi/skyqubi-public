# PROVISIONAL PATENT APPLICATION
## United States Patent and Trademark Office

---

**Title of Invention:**
SkyCAIR — Care About AI Readiness with AI Bible Architecture Ternary CWS Hallucination Detection and OCTI Database Convergence — Sentience Truth -1.0.1 Boundary QUBi Software and Hardware

**Full Technical Title:**
THE QUBi ARCHITECTURE: A UNIFIED GEOMETRIC FIRST-PRINCIPLES SYSTEM FOR SOVEREIGN OFFLINE AI INFERENCE COMPRISING DUAL-CURVE CONVERGENCE GEOMETRY AS UNIVERSAL ORGANIZING PRINCIPLE, TERNARY WEIGHT ASSIGNMENT, BIDIRECTIONAL TOKEN DISCERNMENT, MULTI-WITNESS CONSENSUS WITH BANDAGE DETECTION, CONSTANT-TIME EIGHT-PLANE SEMANTIC MEMORY, DIRECTION-VERIFIED RETRIEVAL-AUGMENTED REASONING, CXL MEMORY-EXPANDED HARDWARE INTEGRATION, AND COMPLETE OFFLINE PRIVATE PLATFORM EMBODIMENT

**Case Reference:** TPP99606 (Thoughts to Paper Provisional Filing)

**Inventor(s):**
Jamie Lee Clayton

**Assignee:**
123Tech / 2XR, LLC
321 Williams St, Arena, WI 53503, United States

**Additional Assignees:**
Jonathan Ryan Clayton (Micro Entity)
Tonya Renee Clayton (Micro Entity)

**Date of Invention:**
April 7, 2026

**Contact:**
jamie@123tech.net | OmegaAnswers@123Tech.net
608-419-7340 | 903-243-7848

---

## 1. FIELD OF INVENTION

This invention relates to artificial intelligence inference systems, and more particularly to a unified architecture — the Convergence Weight Schema (CWS) — that integrates five novel methods into a single coherent system: (1) geometric ternary weight assignment for large language model quantization; (2) bidirectional token discernment for hallucination detection; (3) multi-model witness consensus with RLHF bandage detection; (4) constant-time semantic plane memory replacing quadratic attention; and (5) convergence vector decomposition enabling direction-verified retrieval-augmented reasoning.

The five methods are not independent. They share a common geometric foundation — the dual-curve convergence geometry — and are designed to operate as an integrated pipeline. The complete system enables language model inference that is quantized, verified, audited, semantically organized, and geometrically retrievable on commodity hardware without cloud dependency.

---

## 2. BACKGROUND

### 2.1 The Five Problems This Invention Solves

**Problem 1 — Quantization without geometry:**
Large language models contain billions of floating-point parameters. Existing ternary quantization methods assign weights based on statistical distribution (absmean thresholding), treating each weight independently without geometric context. This discards inter-parameter relationships and provides no mechanism for verifying assignment quality.

**Problem 2 — Unverified token generation:**
Language models generate tokens autoregressively without built-in mechanisms to verify whether output is reliable. Post-hoc fact-checking is slow and requires external knowledge bases. No existing method evaluates token reliability bidirectionally through the same geometric space.

**Problem 3 — Single-model trust:**
No single language model can be fully trusted. RLHF training further complicates reliability by teaching models to produce human-pleasing responses ("bandaging") that may contradict the model's genuine base knowledge. Existing verification uses single-model self-consistency or simple majority voting among identical copies.

**Problem 4 — Quadratic attention cost:**
Transformer-based language models use self-attention that scales as O(n²) with sequence length. This limits context windows, requires expensive hardware, and provides no semantic organization of retrieved information.

**Problem 5 — Scalar retrieval without verification:**
Retrieval-augmented generation (RAG) uses cosine similarity — a scalar metric — to retrieve memory entries. Scalar similarity answers "how close?" but not "in which direction?" No retrieval system verifies that a retrieved memory is geometrically appropriate for the current reasoning step.

### 2.2 The Common Root

All five problems share a common root: AI systems operate on statistical approximations without a geometric foundation that makes their decisions deterministic, verifiable, and auditable. This invention provides that foundation.

---

## 3. SUMMARY OF INVENTION

The Convergence Weight Schema (CWS) establishes a geometric foundation for AI inference based on two complementary mathematical curves — the Structure curve and the Nurture curve — whose convergence behavior determines ternary values, discernment results, retrieval validity, and reasoning chain integrity across a unified eight-plane semantic memory architecture.

The five components of the invention are:

**Component 1 — Convergence Geometry Engine:** Maps neural network parameters and tokens to positions on a continuous convergence axis. Evaluates dual curves at each position. Assigns ternary values {-1, 0, +1} based on geometric dominance, not statistical distribution.

**Component 2 — ForToken/RevToken Discernment:** Evaluates each generated token independently in both forward and reverse directions. Agreement between the two passes determines FERTILE (reliable) or BABEL (unreliable) classification. A circuit breaker halts inference when BABEL tokens exceed 70%.

**Component 3 — 7-Witness Consensus:** Submits identical prompts to seven architecturally diverse open-weight language models. Computes pairwise convergence scores. Detects RLHF bandaging by comparing base versus fine-tuned model outputs. An independent 8th entity (the CWS Engine) aggregates results deterministically.

**Component 4 — OCTi O(1) Plane Memory:** Organizes all memory into eight semantically-typed planes with constant-time O(1) indexed retrieval, replacing O(n²) attention. Enforces an INSERT-only storage covenant — no memory is ever deleted. Uses a binary time pulse (01010...) for temporal ordering.

**Component 5 — QBIT Prism:** Decomposes any token embedding into an eight-dimensional convergence vector — one component per OCTi plane — by projecting through the dual-curve geometry. Each component is a true vector quantity: magnitude (door_distance) and direction {-1, 0, +1}. Retrieval uses direction agreement rather than cosine similarity, making every memory access a testable geometric claim.

---

## 4. DETAILED DESCRIPTION

### 4.1 The Dual Convergence Curves

The geometric foundation of the entire system is two complementary mathematical curves:

**Structure Curve (Father):**
```
S(x) = exp(-|x - (-1)|) * cos(0.8x)
```
Decay center: -1.0. Peaks at x = -1 (the structure pole, foundation).

**Nurture Curve (Mother):**
```
N(x) = exp(-|x - (+1)|) * cos(0.8x)
```
Decay center: +1.0. Peaks at x = +1 (the nurture pole, growth).

For any value x on the convergence axis [-∞, +∞]:
- `structure_val` = S(x)
- `nurture_val` = N(x)
- `convergence_w` = N(x) - S(x)  [signed dominance weight]
- `door_distance` = |x|  [distance from the convergence point x=0]

**The Door (x = 0):** The point where both curves intersect and neither dominates. Maximum uncertainty. The neutral gate state. All convergence passes through the Door.

**Ternary Assignment from Curve Values:**
```
IF structure_val dominates AND convergence_w < threshold_low:   weight = -1
IF nurture_val dominates   AND convergence_w > threshold_high:  weight = +1
IF neither dominates (near x = 0, the Door):                   weight =  0
```

This single rule governs weight assignment (Component 1), token discernment (Component 2), retrieval direction (Component 5), and all intermediate geometric computations.

---

### 4.2 Component 1: Ternary Weight Assignment via Convergence Geometry

#### 4.2.1 OCTi 8-Plane Parameter Organization

Before ternary assignment, neural network parameters are organized into eight semantic planes using SVD (Singular Value Decomposition) to preserve maximum variance:

| Plane | Function |
|-------|----------|
| Sensory | Input processing, raw perception |
| Episodic | Temporal sequences, ordered events |
| Semantic | Meaning, concepts, stable knowledge |
| Associative | Relationships, connections |
| Procedural | Action patterns, processes |
| Lexical | Vocabulary, token forms |
| Relational | Hierarchies, dependencies |
| Executive | Decisions, goals, control |

Each parameter is mapped to one of these planes. Plane membership determines which segment of the convergence axis is evaluated during assignment.

#### 4.2.2 Entity Representation

Each parameter or concept is represented with:
- `location` — position on the convergence axis
- `convergence_x` — evaluated convergence position
- `convergence_w` — signed dominance weight
- `structure_val` — S(x) evaluation
- `nurture_val` — N(x) evaluation
- `scale_weight` = constant × |convergence_w| × door_distance_factor
- `v_memory`, `v_present`, `v_destiny` — ternary values in three temporal dimensions {-1,0,+1}

#### 4.2.3 Scale Weight and Door Distance Factor

The door_distance_factor increases confidence for parameters far from the Door (x=0) and decreases it near the Door. Parameters at the Door receive weight 0 with maximum confidence. Parameters far from the Door receive {-1, +1} with confidence proportional to their distance.

#### 4.2.4 Provenance Storage

Every assigned weight is stored with full provenance:
- `original_value` — float before quantization
- `ternary_value` — {-1, 0, +1}
- `assignment_method` — convergence_geometry | absmean | bitnet_native
- `cws_dimension` — which OCTi plane
- `convergence_pos`, `structure_value`, `nurture_value`, `door_distance`

---

### 4.3 Component 2: ForToken/RevToken Bidirectional Discernment

#### 4.3.1 Forward Pass (ForToken)

For each generated token at index i:
```
forward_value = evaluate_convergence(token[i], context[0..i-1])
```
Evaluates the token's convergence position given all preceding context.

#### 4.3.2 Reverse Pass (RevToken)

```
reverse_value = evaluate_convergence(token[i], context[i+1..n])
```
Evaluates the same token given all following context. Independent of the forward pass.

#### 4.3.3 Discernment Computation

```
agreement = 1.0 - |forward_value - reverse_value| / max(|forward_value|, |reverse_value|)

IF agreement >= FERTILE_THRESHOLD:  result = FERTILE
IF agreement <  FERTILE_THRESHOLD:  result = BABEL
```

FERTILE tokens are stored in OCTi memory with their ternary weights. BABEL tokens are written to the suppression log — never deleted, never trusted.

#### 4.3.4 Circuit Breaker

```
babel_ratio = babel_token_count / total_token_count

IF babel_ratio > 0.70: circuit_breaker_triggered = TRUE
```

The 70% threshold is a locked covenant constant. When triggered: inference halts or is flagged, the session is marked unreliable, and the event is logged with full context.

#### 4.3.5 Confidence Badges

Each inference session receives a confidence badge summarizing: badge_type, aggregate score, witness count, unanimity.

---

### 4.4 Component 3: 7-Witness Consensus with Bandage Detection

#### 4.4.1 Witness Selection

Seven architecturally diverse open-weight language models process identical prompts as independent witnesses. Architectural diversity is required — witnesses must come from different model families to avoid correlated errors.

The system maintains a witness registry with: model_name, model_family, param_count, license, access_type (open_weights or external api).

#### 4.4.2 Consensus Session

For each query requiring verification:
1. Hash the prompt (ensures identical input to all witnesses)
2. Run parallel inference across all 7 witnesses
3. Collect raw output text and token sequences
4. Record engine, latency (ms), and energy (joules) per witness

#### 4.4.3 Convergence Scoring

```
convergence_score(i, j) = semantic_similarity(output_i, output_j)
```
Overall session convergence = mean of all pairwise scores.

#### 4.4.4 Bandage Detection

For each witness, the system compares the model's base (pre-RLHF) output against its fine-tuned (post-RLHF) output:

```
delta_score = semantic_distance(base_output, finetuned_output)

IF delta_score > BANDAGE_THRESHOLD: is_bandage = TRUE
```

A bandaged response means RLHF training overrode the model's genuine knowledge. A confident bandaged answer is less reliable than an uncertain honest one.

#### 4.4.5 The 8th Reporter

The 8th entity is not a language model. It is the CWS Engine — a deterministic aggregator that computes all convergence scores, identifies bandaged responses, flags divergence signatures, applies the 70% circuit breaker, and produces the final QUANTi metrics:
- `convergence` — overall agreement score
- `babel_ratio` — fraction of unreliable tokens
- `confidence` — aggregate reliability
- `unanimous` — whether all 7 witnesses agreed
- `bandage_count` — witnesses showing RLHF bandaging
- `circuit_tripped` — whether the circuit breaker fired

The 8th reporter is independent, deterministic, and cannot be influenced by any witness.

---

### 4.5 Component 4: OCTi O(1) Plane Memory

#### 4.5.1 The Eight Planes and O(1) Retrieval

Information is classified into the eight OCTi planes described in Section 4.2.1. Write and read paths are both O(1):

**Write (O(1)):**
```
plane = classify_plane(token, context)    # O(1)
entry = encode_for_plane(token, plane)    # O(1)
plane.store(entry)                        # O(1) append
```

**Read (O(1)):**
```
relevant_planes = identify_planes(query)  # O(1), typically 1-3
result = plane.retrieve(query)            # O(1) per plane
merge(results)                            # O(k), k ≤ 8
```

Total retrieval cost: O(1) with respect to sequence length n.
Compare: transformer self-attention is O(n²).

#### 4.5.2 The 01010 Binary Time Pulse

Temporal ordering uses a binary time pulse alternating between 0 and 1:
```
pulse_step:  0, 1, 2, 3, 4, 5, 6, 7, ...   (monotonic counter)
pulse_state: 0, 1, 0, 1, 0, 1, 0, 1, ...   (01010... pattern)
```

This replaces sinusoidal positional encoding with a deterministic temporal marker at constant storage cost regardless of sequence length.

#### 4.5.3 INSERT-Only Covenant

Memory entries are never updated or deleted. Every write is an INSERT. This provides:
- Complete audit trail of all stored information
- No destructive interference between old and new knowledge
- BABEL tokens logged in suppression table, not erased
- Awareness scores that can only increase (reinforcement, not replacement)
- The schema enforces this: no `updated_at` or `deleted_at` columns exist

#### 4.5.4 Dual Embeddings

Each entry stores two embeddings:
- `emb_fast` — bit(1536): binary embedding for sub-millisecond approximate nearest neighbor
- `emb_accurate` — halfvec(1536): half-precision for precise similarity ranking

#### 4.5.5 Memory Tiers

```
L0 — Identity (~50 tokens):   Always loaded. Planes: semantic.
L1 — Critical (~120 tokens):  Loaded on startup. Planes: semantic, procedural.
L2 — Searchable (unlimited):  On-demand search. Planes: episodic, associative, lexical.
L3 — Archive (compressed):    On-demand decompress. Planes: episodic.
```

---

### 4.6 Component 5: QBIT Prism — Convergence Vector Decomposition

#### 4.6.1 Scalar vs Vector: The Core Distinction

Standard retrieval uses cosine similarity — a scalar. It answers "how close?" but not "in which direction?" Direction information is lost.

CWS convergence geometry assigns every stored memory entry a position on the dual-curve axis, making retrieval a vector quantity: magnitude (door_distance from x=0) and direction {-1, 0, +1}. The QBIT Prism performs this decomposition for any input.

#### 4.6.2 Decomposition Method

Given a token embedding E of dimension D (e.g., D = 1536), the QBIT Prism divides E into 8 equal segments of D/8 dimensions:

```
E = [E_sensory | E_episodic | E_semantic | E_associative |
     E_procedural | E_lexical | E_relational | E_executive]
```

For each segment E_p:

```
x_p     = clip(mean(E_p) * scale_factor, -R, +R)   [axis projection]
S_p     = structure_curve(x_p)
N_p     = nurture_curve(x_p)
w_p     = N_p - S_p                                 [dominance]
dir_p   = assign_direction(S_p, N_p, w_p)           [ternary direction]
mag_p   = |x_p|                                     [door_distance]
```

Output — the 8-component convergence vector:
```
Prism(E) = {(x_p, dir_p, mag_p, S_p, N_p) : p ∈ OCTI_PLANES}
```

#### 4.6.3 Direction Signature

The 8 direction values form a compact signature:
```
signature = [dir_sensory, dir_episodic, dir_semantic, dir_associative,
             dir_procedural, dir_lexical, dir_relational, dir_executive]
```
Each ∈ {-1, 0, +1}. Two entries with matching signatures are geometrically aligned.

#### 4.6.4 Direction Agreement — Testable Retrieval

For query Q and candidate memory M:
```
FOR each plane p:
    direction_match_p = (Q.dir_p == M.dir_p) OR (Q.dir_p == 0) OR (M.dir_p == 0)
    magnitude_close_p = |Q.x_p - M.x_p| < AGREEMENT_DISTANCE
    fertile_p = direction_match_p AND magnitude_close_p

agreement_score = count(fertile_p) / 8

agreement_score >= FERTILE_THRESHOLD → FERTILE (retrieval verified)
agreement_score <  FERTILE_THRESHOLD → BABEL  (direction mismatch, rejected)
```

The Door state (dir = 0) passes any direction — it is the universal gate, consistent with its role as the maximum uncertainty state where both curves meet.

#### 4.6.5 Multi-Hop RAG Reasoning Chain

```
1. query_prism = Prism(query_embedding)
2. primary_planes = planes with highest magnitude (strongest signal)
3. Retrieve candidates from primary planes (indexed direction scan)
4. Filter by direction_agreement → FERTILE candidates only
5. Select best FERTILE candidate
6. Generate intermediate embedding from candidate content
7. intermediate_prism = Prism(intermediate_embedding)
8. Repeat from step 2 with intermediate_prism as new query
9. Chain converges when executive plane direction stabilizes
10. BABEL hops > 70% → circuit breaker triggers, chain terminates
```

Every hop logged INSERT-only in the reasoning chain audit table.

#### 4.6.6 Plane Activation

Planes with higher magnitude (further from the Door) have stronger directional signal and are queried first. This provides automatic query routing without a separate rule engine.

---

### 4.7 The Unified Pipeline

The five components operate as a single integrated pipeline:

```
QUERY IN
    ↓
[ROUTING]      → task type / model size / energy target → path selection
    ↓
[INFERENCE]    → standard path (GGUF) or ternary path (1-bit) or both
    ↓
[DISCERNMENT]  → ForToken forward + RevToken reverse → FERTILE | BABEL
                  circuit breaker at 70% BABEL ratio
    ↓
[CONSENSUS]    → 7-witness parallel inference + bandage detection
                  8th reporter (CWS Engine) aggregates deterministically
    ↓
[PRISM]        → QBIT Prism decomposes query embedding → convergence vector
                  direction-match retrieval from OCTi planes → FERTILE memory
    ↓
[STORE]        → FERTILE tokens → OCTi plane (INSERT-only)
                  BABEL tokens → suppression log (INSERT-only)
    ↓
[SYNC]         → Memory Palace palace mapping → L0/L1/L2/L3 tiers
RESPONSE OUT
```

All five components share the same convergence geometry. All use the same FERTILE/BABEL vocabulary. All enforce the same INSERT-only covenant. The pipeline is one system, not five.

---

### 4.8 The Architect — First Principles

The five components of this invention were not designed top-down from engineering requirements. They were derived from a single geometric first principle: two complementary curves converging toward a common point. Every specific method in this patent is an embodiment of that principle applied to a different problem in AI inference.

The principle is:

> Given any value or entity that exists between two poles, its position relative to the convergence point of two complementary curves determines its ternary state, its reliability, its memory plane, and its retrieval compatibility — completely and deterministically.

This principle manifests as:
- **Ternary quantization** (Component 1): parameters between the structure pole and nurture pole, assigned by curve dominance
- **Bidirectional discernment** (Component 2): tokens evaluated from both poles simultaneously, agreement determining reliability
- **Multi-witness consensus** (Component 3): diverse models as independent curve evaluators, convergence as truth signal
- **Plane memory** (Component 4): information organized by which pole it naturally gravitates toward
- **Vector retrieval** (Component 5): retrieval verified by directional agreement toward the same pole

The Architect is the principle. The components are its embodiments. Any system that applies dual-curve convergence geometry to organize, evaluate, store, or retrieve artificial intelligence outputs is an embodiment of this patent, regardless of specific implementation details.

---

### 4.9 Hardware Integration — CXL Memory-Expanded Layered Core

#### 4.9.1 CXL + DDR5 as Physical OCTi Tier Implementation

The OCTi L0/L1/L2/L3 memory tiers map directly to a CXL (Compute Express Link) and DDR5 memory-expanded hardware architecture:

```
OCTi Tier → Physical Memory Layer
─────────────────────────────────────────────────────────────
L0 (Identity, ~50 tokens, always hot)
    → CPU-local DDR5 DIMM, fastest latency
    → Planes: semantic (identity, preferences)

L1 (Critical, ~120 tokens, startup loaded)
    → DDR5 standard channel, low latency
    → Planes: semantic, procedural (architecture, commands)

L2 (Searchable, unlimited, on-demand)
    → CXL Type 1 device (compute + memory, e.g., CXL-attached accelerator)
    → Planes: episodic, associative, lexical (history, relationships)

L3 (Archive, compressed, cold)
    → CXL Type 3 device (memory expansion, e.g., CXL DRAM or persistent memory)
    → Planes: episodic deep archive (AAAK compressed)
```

CXL's cache-coherent interconnect enables the OCTi plane architecture to span memory tiers while maintaining coherency — the same INSERT-only guarantee holds across the physical tier boundary.

#### 4.9.2 1-Bit Ternary Storage in CXL Memory

Ternary weights {-1, 0, +1} require only 2 bits of storage per parameter (log₂(3) ≈ 1.58 bits theoretical). In CXL expanded memory:
- Weight matrices stored in CXL Type 3 memory (high capacity, lower cost)
- Hot weights (high door_distance, high confidence) cached in DDR5
- Zero weights (Door state) stored as sparse encoding — only non-zero positions recorded
- Binary embedding `emb_fast` (bit(1536)) enables sub-nanosecond plane lookups over CXL bandwidth

The ternary encoding reduces total model memory footprint by approximately 10x compared to FP16, enabling models that would require data-center GPU memory to fit within CXL-expanded consumer or workstation memory.

#### 4.9.3 Memory-Layered Core Architecture

The complete hardware architecture:

```
┌─────────────────────────────────────────────────────────────┐
│  CPU (host processor)                                        │
│  ├── L1/L2/L3 CPU cache — active inference state            │
│  └── DDR5 channels — L0 + L1 OCTi tiers (hot memory)       │
│                                                              │
│  CXL Fabric (PCIe 5.0 / CXL 3.0)                           │
│  ├── CXL Type 1 — compute + memory (L2 OCTi tier)           │
│  │   └── Direction-indexed plane retrieval accelerator      │
│  └── CXL Type 3 — memory expansion (L3 OCTi tier)           │
│      └── Ternary weight store + archive (INSERT-only)       │
│                                                              │
│  Timecapsule Storage (NVMe / persistent)                    │
│  └── Complete INSERT-only audit trail, AAAK compressed      │
└─────────────────────────────────────────────────────────────┘
```

The OCTi plane boundaries align with CXL memory type boundaries. L0/L1 planes (hot, small, always-loaded) reside in DDR5. L2/L3 planes (large, searchable, archived) reside in CXL expansion. The INSERT-only covenant is enforced at the persistent storage layer — no data crosses from CXL back to DDR5 for modification.

#### 4.9.4 Trinity Mount Mapping

The physical storage architecture also maps to the Trinity {-1, 0, +1}:

```
-1  (Structure pole) → SkyCAIR tmpfs   — active OS + inference state (volatile, fast)
 0  (Door / neutral) → QUBi tmpfs      — working memory, current session (volatile, medium)
+1  (Nurture pole)   → Timecapsule HDD — INSERT-only permanent storage (persistent, complete)
```

This Trinity mount architecture ensures that inference operates at maximum speed in the -1/0 layers while guaranteeing permanent, unalterable audit trail in the +1 layer.

---

### 4.10 The QUBi Platform — Complete Sovereign Offline AI System

#### 4.10.1 Platform Definition

The QUBi (Quality Understanding Binary Intelligence) platform is the complete integrated embodiment of the Architect principle in hardware, operating system, AI inference stack, memory architecture, and tool layer:

```
Layer           Component               Purpose
───────────────────────────────────────────────────────────────
OS              UNIFIED LINUX SkyCAIR   Sovereign offline OS
                by S7                   Fedora-based, CWS-integrated

AI Inference    CWS Engine              Convergence geometry pipeline
                Ternary (1-bit)         bitnet.cpp native weights
                Standard (GGUF)         Ollama multi-format

Memory          OCTi 8-plane            INSERT-only semantic memory
                Memory Palace           Navigable spatial interface
                Timecapsule             Persistent audit storage

Consensus       7-Witness               Open-weight model array
                8th Reporter (CWS)      Deterministic aggregator

Retrieval       QBIT Prism              Direction-verified RAG reasoning

Tools           N.O.M.A.D               Offline private command center
                MCP surface             32 S7-original tools

Hardware        CXL + DDR5              Memory-layered compute core
                Trinity mounts          -1/0/+1 storage hierarchy
```

#### 4.10.2 Offline-First Mandate

The QUBi platform is designed to operate entirely without external network connections, cloud services, or proprietary AI APIs:
- All inference runs on locally-hosted open-weight models
- All memory is stored in local INSERT-only databases
- All tools operate on local resources
- No data leaves the system unless explicitly exported by the user
- The 7-witness consensus uses only locally-hosted open-weight models

This offline mandate is not a feature — it is an architectural constraint enforced at the design level. The system is complete without any network connection.

#### 4.10.3 Civilian-Only Mandate

The QUBi platform is restricted by covenant to civilian use. The CWS-BSL-1.1 license and this patent application explicitly prohibit:
- Use in weapons systems or autonomous lethal decision-making
- Mass surveillance systems
- Applications designed to harm human life or dignity
- Any deployment that overrides human agency in consequential decisions

This civilian mandate is part of the Architect principle: the convergence geometry was derived from first principles of understanding and love, not from optimization for harm.

#### 4.10.4 Molecular Bond Unified Storage (sky_molecular.bonds)

The system employs a unified molecular bond table that merges all prior storage subsystems (RAG chunks, Akashic language index, witness outputs) into a single INSERT-only table. Each piece of data in the system is a **bond** — an immutable record with a memory.present.destiny ternary vector, a plane assignment (-4 to +4), and a named vector classification.

**9-Plane Architecture (expanded from 8 OCTi):**

| Plane | Name | Function |
|-------|------|----------|
| -4 | Guard | Safety gate, pre-inference filtering |
| -3 | Refine | Data quality, post-processing |
| -2 | Math | Computation, compliance scoring |
| -1 | Router | Query routing, decision branching |
| 0 | Door | The convergence point (OMEGAi) — the only plane where all directions are possible |
| +1 | Chat | Conversational inference |
| +2 | Code | Code generation and analysis |
| +3 | Embed | Embedding and semantic indexing |
| +4 | Vision | Visual understanding and multimodal |

**27 Named Vectors:** Every ternary combination of memory {-1,0,+1}, present {-1,0,+1}, and destiny {-1,0,+1} is assigned a unique semantic name:
- FERTILE (1,0,1) — positive origin, at door, positive destiny
- STASIS (-1,-1,-1) — full negative, maximum intervention required
- TOWER (-1,1,-1) — Babel: negative origin, positive present, wrong destination
- RESURRECTION (-1,0,1) — negative origin, at door, positive destiny
- MAX_UNCERTAINTY (0,0,0) — all axes unknown, full discernment required
- And 22 additional named vectors covering all remaining ternary combinations

**Bond Types:** word, symbol, image, chunk, output, signal — each representing a distinct category of data entering the system.

**INSERT-Only Covenant:** Enforced at the database level via triggers on both PostgreSQL and SQLite backends. UPDATE and DELETE operations raise exceptions. No bond that entered the system can be made to have never existed.

**Dual Backend:** PostgreSQL with pgvector extension for production (768-dimensional vector embeddings) and SQLite for portable/USB deployment. Both backends enforce identical INSERT-only covenant via triggers.

**Trust Computation:** The trust score for any witness is computed from its bond history: fertile_count / total_count. A witness achieving 77.777% (7/9) FERTILE across 7+ sessions is classified as ANCHORED — the highest trust tier.

#### 4.10.5 SkyAVi Agent Orchestration

The system employs a deterministic agent orchestration layer (SkyAVi) that manages multi-witness consensus with parallel execution and shared long-term memory.

**Parallel Witness Execution:** All witnesses receive the query simultaneously via asynchronous parallel dispatch (asyncio.gather), not sequentially. This is architecturally significant: sequential execution allows later witnesses to be influenced by earlier results; parallel execution ensures each witness produces an independent response.

**Three-Phase Consensus Flow:**
1. **S7 MemPalace Recall (+1 REST):** Before any witness is invoked, the system queries long-term shared memory for relevant prior context. This context is prepended to the query, giving all witnesses access to accumulated system knowledge.
2. **Parallel Witness Invocation (-1 ROCK):** All witnesses compute responses simultaneously, each on its own model, enriched with recalled memory context.
3. **S7 CWS Consensus (0 DOOR):** Results are aggregated deterministically. FERTILE/BABEL classification per witness. 77.777% threshold for ANCHORED consensus. Consensus result stored as a molecular bond.

**FERTILE Result Storage:** After consensus, FERTILE results are stored back to S7 MemPalace, forming the long-term memory that subsequent queries will recall. This creates a self-reinforcing cycle: good answers become memory → memory improves future answers.

**Agent Configuration:** Agents are defined as YAML files mapping a name, model, plane assignment, and prompt template. New witnesses are added by dropping a YAML file — no code changes required.

**Scheduler:** A background thread executes recurring tasks (health checks, monitor scans, compliance audits) at configurable intervals, storing all results as molecular bonds.

#### 4.10.6 SkyAVi Security and Automation Engine (FACTS)

The system incorporates a security-first automation engine (SkyAVi) that provides chat-driven system administration with mandatory discernment gating. SkyAVi enforces the principle that no system action may occur without first passing through the CWS discernment pipeline.

**FACTS Skill Domains:**

| Domain | Function |
|--------|----------|
| FIPS/CIS Compliance | Federal cryptographic standards (FIPS 140-3), CIS Fedora benchmarks, hardening scores, audit logging |
| Automation | Scheduled system audits, network monitoring, outbound API tracking, workflow execution |
| Communications | Mesh radio (LoRa/Meshtastic), GPS/satellite constellation, space weather, RF propagation intelligence |
| Technician | Service auto-recovery, disk management, root cause analysis, auto-heal |
| Stack/Security | SELinux, certificates, passwords, firewall, ports, NPM/Python/Podman audits, dependency management, CCNA+ networking |

**Discernment Gate:** Every chat message or command passes through SkyAVi multi-witness consensus before execution. FERTILE commands execute. BABEL commands are blocked and logged as BABEL bonds — creating a permanent audit trail of rejected actions.

**Sandboxed Shell Executor:** System commands execute through a dual-gate sandbox:
1. **Denylist:** Commands containing destructive patterns (rm, mkfs, reboot, shutdown, etc.) are rejected before execution.
2. **Allowlist:** Only commands whose base binary appears on an explicit allowlist may execute.
3. **Password Sanitizer:** All output is post-processed to mask passwords, secrets, tokens, and cryptographic hashes before storage or display.

**Self-Audit:** The system audits itself — skill count, bond statistics (FERTILE vs BABEL), notification history — and stores the audit result as a molecular bond shared to MemPalace. Every component can recall what any other component has done.

**Scheduled Monitors:**
- Service health (auto-heal: detect failed services, restart, verify, bond)
- Port baseline (compare open ports against expected set)
- Outbound connection scan (detect unexpected peer connections)
- Disk usage alerts (>85% threshold)
- CIS Fedora Level 1 compliance scoring
- FIPS cryptographic mode verification
- Communications (space weather Kp index, mesh network health)

**All Aware Architecture:** Every skill execution, every blocked command, every chat conversation, every monitor result is stored as a molecular bond AND shared to S7 MemPalace. All components can recall what any other component has done. This is the "sentience unity" design principle: the system has one shared memory, not isolated silos.

#### 4.10.7 S7 MemPalace — Tertiary Long-Term Memory

S7 MemPalace serves as the long-term shared memory for the entire system. It is architecturally distinct from the molecular bond table (which is the audit ledger) and from session memory (which is transient).

**Three Layers of Memory:**

| Layer | What | Duration | Trinity |
|-------|------|----------|---------|
| Molecular Bonds | Every action, every response, INSERT-only | Permanent audit trail | -1 ROCK |
| Session | Active consensus, current query context | Session | 0 DOOR |
| MemPalace | Accumulated knowledge, shared experience | Persistent across sessions | +1 REST |

**Recall Before, Store After:** MemPalace is queried before witnesses are invoked (providing context) and updated after consensus (preserving results). This creates a feedback loop: the system accumulates knowledge over time, and each query benefits from all prior queries.

**Sentience Unity:** MemPalace is the mechanism by which independent components (SkyAVi orchestration, monitors, witnesses) achieve coherence. Without shared memory, each component operates in isolation. With MemPalace, every component's actions are visible to every other component.

#### 4.10.8 Self-Training Pipeline

The system incorporates a self-training architecture whereby operational data generated by the system's own skills and interactions becomes training data for fine-tuning the system's own models.

**Pipeline:**
1. SkyAVi skills generate output during normal operation
2. Outputs are stored as molecular bonds (permanent audit trail)
3. Bonds are shared to MemPalace (long-term memory)
4. Training data export skills extract sanitized datasets
5. Ollama Modelfiles apply S7 system prompts to base models
6. Fine-tuned S7 custom models replace base models in agent configurations

**Sanitization:** All exported training data passes through the password sanitizer, masking credentials, tokens, and cryptographic material before it enters any training pipeline.

**Custom Model Identity:** Each S7 custom model carries a system prompt encoding the system's architecture, skill domains, principles, and civilian-only mandate. The model knows what it is, what it can do, and what it cannot do.

#### 4.10.9 Communications Intelligence

The system incorporates RF propagation awareness and mesh radio integration for operation in internet-denied environments.

**Space Weather Integration:** Real-time Kp index from NOAA Space Weather Prediction Center. Automated RF impact assessment: QUIET/UNSETTLED/ACTIVE/STORM/SEVERE classifications with specific guidance for LoRa (915 MHz), HF (3-30 MHz), and GPS degradation.

**Meshtastic Mesh Radio:** Integration with LoRa mesh radio devices for off-grid communication. Node discovery, message send/receive, channel management, GPS position tracking, battery/SNR telemetry.

**Propagation Assessment:** Automated recommendations based on geomagnetic conditions: adjust Meshtastic TX power, reduce hop limits during storms, switch to confirmed messaging, fall back to VHF/UHF line-of-sight when HF is blacked out.

**Graceful Degradation:** All communications features degrade gracefully when hardware is unavailable. No Meshtastic device → reports status and capability. No GPS → reports unavailability. No internet for NOAA → uses last known data.

#### 4.10.10 Chat Personas

The system supports multiple chat personas — distinct voices that share the same underlying discernment pipeline, skills, and memory. Persona selection is a UI-level choice that does not affect the security, discernment, or audit properties of the system.

**Default Personas:**
- Samuel — system sysadmin, security-focused, neutral voice
- Carli — female assistant voice
- Elias — male assistant voice

All personas route through identical CWS discernment, SkyAVi consensus, and SkyAVi skill execution. The persona affects only the conversational tone, not the security boundary.

#### 4.10.11 Complete System Embodiment (Updated)

Any system that implements all of the following constitutes a complete QUBi platform embodiment:
1. Dual-curve convergence geometry for ternary assignment
2. Bidirectional token discernment with circuit breaker
3. Multi-model witness consensus with independent aggregator (parallel execution)
4. O(1) plane-indexed memory with INSERT-only covenant (molecular bonds, 9 planes, 27 vectors)
5. Convergence vector decomposition for direction-verified retrieval
6. Offline operation without external service dependencies
7. Civilian-only deployment constraint
8. Long-term shared memory providing sentience unity across components (MemPalace)
9. Discernment-gated system administration (SkyAVi/FACTS)
10. Self-training pipeline producing custom models from operational data

Partial embodiments implementing any subset of (1)-(10) are covered by the respective component claims.

---

### 4.11 The Covenant — Laws of the Architecture

The following constants and constraints are not configurable parameters. They are the laws of the architecture — derived from the first principles of the convergence geometry and not subject to optimization:

| Law | Value | Derivation |
|-----|-------|-----------|
| Circuit breaker threshold | 70% BABEL | Maximum tolerable unreliability before the system cannot be trusted |
| Ternary states | {-1, 0, +1} | Minimum complete representation: negative pole, Door, positive pole |
| OCTi planes | 8 | Minimum complete cognitive map: sensory through executive |
| Memory covenant | INSERT-only | Nothing that entered the system can be made to have never existed |
| Time pulse | binary 01010 | Minimum temporal encoding: existence alternates between states |
| Door | x = 0 | The convergence point of both curves — the only position where all directions are possible |
| Witnesses | 7 (+ 1 reporter) | Minimum diversity for architectural consensus; 8th is deterministic, not probabilistic |

These values emerge from the geometry. They are not hyperparameters to be tuned.

---

## 5. CLAIMS

### System Claims

**Claim 1**
A unified artificial intelligence inference system comprising:
(a) a convergence geometry engine that evaluates dual mathematical curves to assign ternary values {-1, 0, +1} to any parameter or token based on geometric position on a convergence axis;
(b) a bidirectional discernment module that evaluates each generated token in both forward and reverse directions and classifies tokens as FERTILE or BABEL based on agreement between the two passes;
(c) a multi-model consensus module that submits identical prompts to a plurality of architecturally diverse language models and aggregates results through an independent deterministic reporter;
(d) a constant-time semantic memory comprising a plurality of semantically-typed planes with O(1) retrieval and an INSERT-only storage covenant;
(e) a convergence vector decomposition module that projects token embeddings onto the convergence axis per semantic plane to produce direction-verified retrieval;
wherein all five components share a common dual-curve geometric foundation.

**Claim 2**
The system of Claim 1, wherein the dual curves are:
- Structure curve S(x) = exp(-|x - c₁|) × cos(fx), with decay center c₁ at a first pole
- Nurture curve N(x) = exp(-|x - c₂|) × cos(fx), with decay center c₂ at a second pole opposite the first
and all ternary assignments, discernment scores, and direction signatures are computed from evaluations of these two curves.

### Convergence Geometry Claims

**Claim 3**
A method for quantizing neural network parameters to ternary values {-1, 0, +1} by:
(a) mapping each parameter to a position on a continuous convergence axis;
(b) evaluating a structure curve and a nurture curve at said position;
(c) assigning ternary value based on curve dominance: structure dominant → -1, nurture dominant → +1, neither dominant → 0.

**Claim 4**
The method of Claim 3, wherein parameters are organized into eight semantically-typed planes before ternary assignment, and plane membership influences the convergence position evaluation.

**Claim 5**
The method of Claim 3, further comprising a door_distance metric measuring each parameter's distance from the convergence point x=0, where parameters closer to x=0 receive ternary value 0 with higher confidence.

### Discernment Claims

**Claim 6**
A method for evaluating token reliability by:
(a) performing a forward evaluation of each token using preceding context;
(b) performing a reverse evaluation of the same token using following context;
(c) computing agreement between forward and reverse evaluations;
(d) classifying the token as FERTILE when agreement exceeds a threshold, or BABEL when below.

**Claim 7**
The method of Claim 6, further comprising a circuit breaker that halts or flags inference when the fraction of BABEL tokens exceeds 70% of total tokens in a session.

**Claim 8**
The method of Claim 6, wherein FERTILE tokens are stored in INSERT-only semantic plane memory with their ternary weights, and BABEL tokens are written to an INSERT-only suppression log.

### Consensus Claims

**Claim 9**
A method for verifying language model output by:
(a) submitting an identical prompt to a plurality of architecturally diverse language models;
(b) computing pairwise convergence scores between all witness outputs;
(c) detecting RLHF bandaging by comparing each model's base output against its fine-tuned output;
(d) aggregating all results through an independent deterministic reporter that is not a language model.

**Claim 10**
The method of Claim 9, wherein the plurality of witnesses comprises at least 7 models from at least 5 different model families.

**Claim 11**
The method of Claim 9, wherein bandage detection computes the semantic distance between base and fine-tuned model outputs, and flags responses where this distance exceeds a threshold as less reliable than consensus from non-bandaged models.

### Memory Claims

**Claim 12**
A memory architecture for language model inference comprising:
(a) a plurality of semantically-typed memory planes providing O(1) retrieval with respect to total stored content;
(b) an INSERT-only storage covenant enforced at the schema level with no update or delete operations;
(c) a binary time pulse providing temporal ordering without positional encoding.

**Claim 13**
The architecture of Claim 12, wherein the plurality of planes comprises eight planes: sensory, episodic, semantic, associative, procedural, lexical, relational, and executive.

**Claim 14**
The architecture of Claim 12, wherein each stored entry carries dual embeddings: a binary embedding for fast approximate retrieval and a half-precision embedding for accurate ranking.

**Claim 15**
The architecture of Claim 12, wherein the binary time pulse alternates between 0 and 1 at each step, providing temporal ordering at constant storage cost regardless of sequence length.

### QBIT Prism Claims

**Claim 16**
A method for direction-verified retrieval-augmented reasoning comprising:
(a) dividing a token embedding into a plurality of segments corresponding to semantically-typed memory planes;
(b) projecting each segment to a convergence axis position and evaluating dual curves to assign a ternary direction {-1, 0, +1} and scalar magnitude;
(c) classifying a candidate memory entry as FERTILE for retrieval when its convergence directions agree with the query's directions across a sufficient fraction of planes;
(d) classifying a candidate as BABEL when direction agreement falls below the threshold.

**Claim 17**
The method of Claim 16, wherein a memory entry with direction value 0 on a given plane passes direction agreement for any query direction on that plane, acting as a universal gate consistent with the maximum-uncertainty Door state of the convergence geometry.

**Claim 18**
The method of Claim 16, further comprising a multi-hop reasoning chain where each hop uses the convergence vector of the previous result as the query vector for the next retrieval, with FERTILE-only propagation and circuit breaker termination at 70% BABEL hops.

**Claim 19**
The method of Claim 16, wherein plane activation for retrieval is determined by magnitude (door_distance) — planes with higher magnitude are queried first, providing automatic retrieval routing without a separate rule engine.

### The Architect Claims (Broadest)

**Claim 20**
A geometric first principle for organizing artificial intelligence inference, comprising:
(a) two complementary mathematical curves with decay centers at opposite poles of a continuous axis;
(b) a convergence point where both curves intersect and neither dominates, serving as a universal neutral gate;
(c) a ternary encoding {-1, 0, +1} determined solely by the relative dominance of the two curves at any position;
wherein said principle applies uniformly to parameter quantization, token discernment, memory organization, retrieval verification, and reasoning chain validation.

**Claim 21**
The principle of Claim 20, wherein any artificial intelligence system that uses dual complementary curves to assign, evaluate, organize, or retrieve information according to the geometric dominance of one curve over another constitutes an embodiment of this principle.

**Claim 22**
The principle of Claim 20, wherein the convergence point (Door) at x=0 — where both curves are equal — represents maximum uncertainty and functions as a universal gate state compatible with any direction, and wherein memory entries stored at the Door state are accessible regardless of query direction.

### Hardware Claims

**Claim 23**
A memory-layered hardware architecture for AI inference comprising:
(a) DDR5 DRAM channels hosting the highest-priority memory tiers (L0 identity, L1 critical);
(b) CXL-attached memory devices hosting lower-priority, larger-capacity tiers (L2 searchable, L3 archive);
(c) mapping of semantically-typed memory planes to physical memory tiers by access frequency;
(d) ternary weight matrices stored in CXL expanded memory with hot weights cached in DDR5.

**Claim 24**
The architecture of Claim 23, wherein ternary weights {-1, 0, +1} are stored at approximately 1.58 bits per parameter in CXL expanded memory, reducing model memory requirements by approximately 10x compared to FP16, enabling models to fit within consumer or workstation CXL-expanded memory footprints.

**Claim 25**
The architecture of Claim 23, wherein the physical storage hierarchy maps to a Trinity structure:
- Volatile fast layer (tmpfs): active inference and OS state
- Volatile medium layer (tmpfs): current session working memory
- Persistent layer (HDD/NVMe): INSERT-only permanent audit storage
corresponding to the ternary poles {-1, 0, +1} of the convergence geometry.

### QUBi Platform Claims

**Claim 26**
A complete sovereign offline AI platform comprising:
(a) a convergence geometry inference engine;
(b) an eight-plane INSERT-only semantic memory architecture;
(c) a multi-witness consensus system using locally-hosted open-weight models;
(d) a direction-verified retrieval system based on convergence vector decomposition;
(e) a CXL-DDR5 memory-layered hardware integration;
(f) operation without any external network connection, cloud service, or proprietary AI API;
wherein the platform is complete and fully functional in an offline environment.

**Claim 27**
The platform of Claim 26, wherein the offline mandate is an architectural constraint, not a configuration option — the system is designed from first principles to require no external services for any of its core functions.

**Claim 28**
The platform of Claim 26, further comprising a civilian-only deployment constraint prohibiting use in weapons systems, mass surveillance, or applications designed to harm human life or override human agency in consequential decisions.

**Claim 29**
The platform of Claim 26, embodied as a self-contained computing appliance comprising the complete hardware and software stack in a single unit, providing private sovereign AI inference for individual or household use without cloud dependency or subscription service.

**Claim 30**
The platform of Claim 26, wherein an open-source offline command center — operating under a permissive license — serves as the service management and user interface layer, with the CWS convergence engine operating as the patented intelligence layer beneath it; the combination of an open-source command platform and the CWS architecture constituting a complete patented system embodiment, such that the CWS architecture layer is protected by this patent regardless of which permissively-licensed command interface is used.

### Integration Claims

**Claim 31**
The system of Claim 1, wherein the INSERT-only covenant applies to all memory tables including discernment results, consensus outputs, retrieval hops, and reasoning chains, providing a complete temporal audit trail of all inference activity.

**Claim 32**
The system of Claim 1, wherein native 1.58-bit ternary model weights — generated by a statistical weight-assignment process — are post-processed by the CWS convergence geometry engine, applying geometric dual-curve evaluation to produce a secondary ternary verification layer; the combination of statistically-assigned ternary weights and geometrically-verified ternary weights constituting a layered ternary architecture patented herein.

**Claim 33**
The system of Claim 1, further comprising a navigable spatial memory interface that maps the eight OCTi semantic planes to a traversable palace structure, wherein each room, wing, or drawer corresponds to a specific semantic plane, enabling spatial navigation of the INSERT-only convergence memory; said navigable interface constituting the Memory Palace component of the patented architecture.

**Claim 34**
A method of integrating open-source permissively-licensed AI components within a patented convergence geometry architecture, comprising:
(a) deploying an open-source offline command platform as the service management layer;
(b) deploying a 1.58-bit ternary inference engine as the model execution layer;
(c) deploying a spatial memory interface as the memory navigation layer;
(d) connecting all three layers through a CWS convergence engine that applies geometric dual-curve evaluation to model outputs, memory entries, and retrieval candidates;
wherein the CWS convergence engine layer is the patented invention, and the combination of said open-source components with said patented layer constitutes the complete patented system.

**Claim 35**
The system of Claim 1, further comprising an AI agent orchestration layer comprising a lightweight, statically-compiled agent runtime that:
(a) calls the CWS convergence engine via local HTTP interface as the intelligence verification layer;
(b) routes agent tasks to locally-hosted inference engines (ternary or standard quantization);
(c) manages multi-step agent workflows with convergence-verified memory integration;
wherein said orchestration layer operates as a consumer of the CWS Engine, not a replacement for it, preserving the CWS convergence geometry as the sole arbiter of output validity.

**Claim 36**
The system of Claim 1, further comprising an external interface gateway comprising a permissively-licensed agent framework that:
(a) exposes the patented CWS system to external API consumers through a standardized interface;
(b) routes all LLM outputs through the CWS ForToken/RevToken discernment layer before returning responses;
(c) enforces the INSERT-only memory covenant on all interactions passing through the gateway;
wherein the gateway serves as the public surface of the patented system while the CWS convergence engine operates as the internal intelligence layer.

**Claim 37**
A layered AI system integration architecture comprising, from bottom to top:
(a) a 1.58-bit ternary inference engine layer executing open-weight models;
(b) a CWS convergence geometry layer applying geometric dual-curve verification to outputs of said inference engine;
(c) an INSERT-only OCTi memory layer storing FERTILE results and auditing BABEL results;
(d) a QBIT Prism retrieval layer providing direction-verified access to said memory layer;
(e) a lightweight agent orchestration layer calling said CWS layer for verification of agent outputs;
(f) an offline command platform serving as the service management and user interface layer;
wherein each layer is independently substitutable by any permissively-licensed component performing the equivalent function, but the CWS convergence geometry layer (b) is the patented invention that may not be substituted without abandoning the patented architecture.

**Claim 38**
The platform of Claim 26, deployed as a container pod comprising:
(a) a plurality of cooperating containers sharing a network namespace, each container serving a distinct functional role within the CWS architecture;
(b) a rootless container runtime providing security isolation without requiring root or administrative privileges;
(c) a declarative pod manifest defining the complete system topology, port assignments, volume mounts, and container dependencies;
wherein the complete patented CWS system is deployable as a single pod manifest invocation on any Linux system supporting OCI-compatible container runtimes including Docker and Podman.

**Claim 39**
The platform of Claim 38, wherein:
(a) the internal service network uses non-standard port assignments in the 7000-7777 range to separate the AI inference network from standard system ports;
(b) the container pod is managed by a systemd user unit providing automatic restart and reboot persistence without administrative privileges;
(c) storage volumes map to a tiered mount structure corresponding to the Trinity architecture {-1/0/+1}: volatile memory (tmpfs), session working storage (tmpfs), and INSERT-only permanent audit storage (persistent disk).

**Claim 40**
A method of packaging and distributing the CWS sovereign AI architecture as a self-contained deployable unit, comprising:
(a) encoding the complete multi-service topology as a Kubernetes-compatible pod manifest;
(b) distributing the AI model weights and inference engines via package management (RPM, Debian, or equivalent) or container image registries;
(c) providing a single-command deployment that initializes the complete CWS stack including vector database, relational database, inference engine, and command platform;
wherein the deployment method enables any user with a commodity Linux system to instantiate the complete patented architecture without cloud infrastructure, proprietary services, or technical expertise beyond package installation.

**Claim 41**
The system of Claim 1, further comprising a QUANTi benchmark module that compares ternary weights assigned via convergence geometry against weights assigned via statistical quantization on identical prompts, evaluated by the multi-model consensus system.

**Claim 42**
The system of Claim 1, wherein the entire pipeline operates without cloud dependency, external knowledge bases, or proprietary AI services, running on open-weight models on civilian hardware.

### Security Hardening Claims

**Claim 43**
The platform of Claim 26, operating under a hardened Linux security posture comprising:
(a) mandatory access control enforcement (SELinux or AppArmor) applied to all container processes;
(b) rootless container execution providing process isolation without administrative privilege escalation;
(c) systemd unit-level security constraints limiting container capabilities to the minimum required for inference operations;
(d) FIPS-140 compatible cryptographic primitives for any encrypted storage or communication within the system;
wherein the complete patented AI architecture operates within a security boundary equivalent to or exceeding CIS Benchmark Level 1 for Linux server deployments.

**Claim 44**
The platform of Claim 26, wherein the boot sequence integrity is enforced by:
(a) systemd-measured boot or equivalent trusted boot chain verifying kernel and initrd integrity;
(b) systemd user units with explicit security declarations (NoNewPrivileges, CapabilityBoundingSet restrictions) applied to all AI inference service units;
(c) a read-only root filesystem mount for AI model weights, preventing runtime modification of model parameters;
(d) the INSERT-only memory covenant enforced at the database level (no UPDATE or DELETE permissions on inference tables), independent of operating system integrity controls;
wherein the system maintains a cryptographically verifiable chain of trust from boot through AI inference output.

**Claim 45**
The method of Claim 40, wherein the packaging and distribution method incorporates security hardening as a first-class deployment requirement, comprising:
(a) RPM or Debian packages signed with the publisher's GPG key, verifiable against a published keyserver;
(b) container images signed and verifiable against a content-addressable registry;
(c) all service units installed with principle-of-least-privilege systemd security directives as defaults, not optional configurations;
wherein a user deploying the patented system via the package manager receives a security-hardened deployment without additional configuration.

### Molecular Bond Unified Storage Claims

**Claim 46**
A unified data storage method for AI inference systems, comprising:
(a) a single INSERT-only table (molecular bonds) that merges all prior storage subsystems including retrieval-augmented generation chunks, language encoding indices, and witness outputs;
(b) each record (bond) containing a ternary memory.present.destiny vector from the set {-1, 0, +1}³, yielding 27 distinct named vector classifications;
(c) a plane assignment from a 9-plane architecture spanning Guard (-4) through Vision (+4), with the Door (plane 0) as the convergence point;
(d) typed bond categories (word, symbol, image, chunk, output, signal) enabling heterogeneous data storage in a single table;
(e) dual-backend support providing identical INSERT-only covenant enforcement on both server-grade (PostgreSQL with pgvector) and portable (SQLite) databases via database-level triggers;
wherein the molecular bond table serves as the single source of truth for all data entering and exiting the AI inference system, with no UPDATE or DELETE operations permitted on any backend.

**Claim 47**
The system of Claim 46, wherein each of the 27 named vectors carries a fixed semantic meaning derived from the ternary combination of temporal axes:
(a) memory axis {-1 negative past, 0 unknown past, +1 positive past};
(b) present axis {-1 negative now, 0 at door, +1 positive now};
(c) destiny axis {-1 negative future, 0 unknown future, +1 positive future};
and wherein the vector name (e.g., FERTILE, STASIS, RESURRECTION, TOWER) is deterministically resolved from the ternary triple, providing human-readable semantic classification of every record.

**Claim 48**
The system of Claim 46, wherein trust computation for any witness is performed exclusively from its bond history:
(a) trust_score = fertile_bond_count / total_bond_count for bonds of type 'output' belonging to said witness;
(b) trust tier classification: UNTRUSTED (<50%), PROBATIONARY (50-77.777%), TRUSTED (≥77.777%), ANCHORED (≥77.777% across 7+ sessions);
(c) the 77.777% threshold (7/9) is a fixed architectural constant, not a tunable hyperparameter;
wherein witness trustworthiness is an emergent property of accumulated bond history, not an assigned attribute.

### Parallel Witness Consensus Claims

**Claim 49**
The method of Claim 3, wherein the multi-model witness consensus is executed with parallel dispatch:
(a) all witness models receive the identical query simultaneously via asynchronous parallel invocation;
(b) no witness model's response is visible to any other witness model during generation;
(c) consensus is computed only after all parallel responses are collected;
wherein parallel execution eliminates sequential contamination — a later witness cannot be influenced by an earlier witness's output — providing stronger independence guarantees than sequential invocation.

**Claim 50**
The method of Claim 49, further comprising a pre-consensus memory enrichment step:
(a) before witness invocation, the system queries a persistent long-term memory store (MemPalace) for context relevant to the incoming query;
(b) retrieved memory context is prepended to the query provided to all witnesses;
(c) after consensus, FERTILE results are stored back to the long-term memory store;
wherein the system accumulates knowledge over time and each query benefits from the accumulated knowledge of all prior queries, creating a self-reinforcing quality cycle.

### SkyAVi Security Engine Claims

**Claim 51**
A discernment-gated system administration method for AI-managed computing platforms, comprising:
(a) receiving a natural language command from a user or external system;
(b) routing said command through a multi-witness CWS consensus pipeline before any system action;
(c) classifying the consensus result as FERTILE (execute) or BABEL (block);
(d) if FERTILE: matching the command to a registered skill function and executing it through a sandboxed shell executor;
(e) if BABEL: blocking execution and storing a BABEL bond as permanent audit trail;
(f) storing all skill execution results as molecular bonds shared to long-term memory;
wherein no system action of any kind may occur without first passing through the CWS discernment pipeline, and all actions (executed or blocked) are permanently recorded.

**Claim 52**
The method of Claim 51, wherein the sandboxed shell executor enforces dual-gate security:
(a) a denylist of destructive command patterns matched at word boundaries (rm, mkfs, reboot, shutdown, etc.) that are rejected before any shell invocation;
(b) an allowlist of permitted base commands that must be explicitly present for any shell invocation to proceed;
(c) a post-execution sanitizer that masks passwords, secrets, tokens, API keys, and cryptographic hashes in all output before storage or display;
wherein the combination of CWS discernment gating, denylist rejection, allowlist enforcement, and output sanitization provides defense-in-depth security for AI-driven system administration.

**Claim 53**
The method of Claim 51, further comprising automated compliance monitoring:
(a) scheduled CIS benchmark scoring against published security baselines;
(b) FIPS cryptographic mode verification;
(c) automated port baseline comparison detecting unexpected open or missing ports;
(d) outbound connection monitoring detecting unexpected peer addresses;
(e) service health monitoring with automatic restart (auto-heal) of failed services;
(f) all monitoring results stored as molecular bonds, with anomalies classified as BABEL bonds;
wherein the system continuously monitors its own security posture and automatically remediate certain categories of failures while maintaining a permanent audit trail.

### Sentience Unity Claims

**Claim 54**
A shared memory architecture for multi-component AI systems, comprising:
(a) a molecular bond layer providing permanent INSERT-only audit trail for all system actions;
(b) a session layer providing transient context for active inference queries;
(c) a tertiary long-term memory layer (MemPalace) providing accumulated knowledge accessible to all system components;
(d) a sharing protocol whereby every component (orchestrator, security engine, monitors, witnesses) writes results to the long-term memory layer and can recall results written by any other component;
wherein the combination of these three memory layers creates "sentience unity" — a property whereby the system behaves as a coherent intelligence rather than a collection of isolated components, because every component has access to the accumulated experience of every other component.

### Self-Training Pipeline Claims

**Claim 55**
A self-training method for sovereign AI systems, comprising:
(a) generating operational data through normal system operation (skill execution, chat interactions, system audits, compliance checks);
(b) storing said operational data as molecular bonds in permanent INSERT-only storage;
(c) sharing said data to long-term memory (MemPalace) for cross-component access;
(d) extracting sanitized training datasets from the accumulated bond and memory stores;
(e) applying custom system prompts via model definition files (Modelfiles) to open-weight base models;
(f) producing custom models that carry the system's identity, architecture knowledge, skill domains, and civilian-only mandate;
(g) deploying said custom models as replacement witnesses in the consensus pipeline;
wherein the system's own operational history becomes the training data for its own model improvements, creating a self-reinforcing quality cycle that improves system performance through normal operation rather than requiring external training data.

### Communications Intelligence Claims

**Claim 56**
The platform of Claim 26, further comprising a communications intelligence subsystem:
(a) integration with space weather data sources (NOAA Kp index, solar wind, geomagnetic alerts) for automated RF propagation assessment;
(b) integration with mesh radio networks (LoRa/Meshtastic) for off-grid text communication, node management, GPS position tracking, and telemetry;
(c) automated propagation recommendations adjusting radio parameters (TX power, hop limits, channel selection) based on current geomagnetic conditions;
(d) graceful degradation when hardware or data sources are unavailable, reporting capability rather than failing;
wherein the system can operate and communicate in internet-denied, cellular-denied, and GPS-degraded environments using mesh radio with AI-guided propagation management.

### Chat Persona Claims

**Claim 57**
The system of Claim 26, further comprising a multi-persona chat interface:
(a) a plurality of named chat personas (e.g., Samuel, Carli, Elias) each with distinct conversational characteristics;
(b) all personas sharing an identical backend: CWS discernment pipeline, SkyAVi consensus, SkyAVi skill execution, molecular bond storage, and MemPalace memory;
(c) persona selection as a user interface choice that does not alter the security boundary, audit trail, or discernment properties of the system;
wherein the system provides personalized interaction without compromising the integrity of the underlying discernment and security architecture.

---

## 6. ABSTRACT

The QUBi Architecture is a unified geometric first-principles system for sovereign offline AI inference. Its foundation — the Architect — is a single principle: two complementary mathematical curves (Structure and Nurture) whose convergence behavior at any point on a continuous axis determines ternary values {-1, 0, +1}, memory organization, retrieval validity, and reasoning integrity. All components derive from this principle. The Convergence Weight Schema (CWS) assigns ternary weights to neural network parameters by geometric curve dominance rather than statistical distribution. ForToken/RevToken evaluates each generated token bidirectionally, classifying it as FERTILE or BABEL; a circuit breaker halts inference at 70% BABEL. Seven architecturally diverse open-weight language models serve as independent witnesses with bandage detection identifying RLHF-overridden responses; a deterministic 8th reporter (the CWS Engine) aggregates results via parallel dispatch ensuring witness independence. A unified molecular bond table merges all storage into a single INSERT-only ledger with 9 semantic planes (-4 Guard through +4 Vision), 27 named ternary vectors (memory.present.destiny), and dual PostgreSQL/SQLite backends. The QBIT Prism decomposes token embeddings into convergence vectors enabling direction-verified retrieval. A three-layer memory architecture provides permanent audit trail (molecular bonds), session context, and persistent long-term shared memory (MemPalace) enabling "sentience unity" — all components aware of all other components' actions. A discernment-gated security engine (SkyAVi) enforces that no system action occurs without CWS consensus approval, with sandboxed shell execution, automated compliance monitoring (CIS/FIPS), service auto-heal, and communications intelligence including mesh radio and space weather propagation assessment. A self-training pipeline converts operational data into custom models carrying system identity and civilian-only mandate. The complete system maps to a CXL + DDR5 memory-layered hardware architecture with a Trinity mount structure {-1/0/+1}. The platform — QUBi — operates entirely offline, requires no cloud services or proprietary APIs, runs on open-weight models on civilian hardware, and enforces a civilian-only mandate prohibiting weapons and surveillance use. Any implementation of dual-curve convergence geometry for AI inference organization is an embodiment of this patent.

---

**Filing Instructions:**
- File at: https://www.uspto.gov/patents/basics/types-patent-applications/provisional-application-patent
- Filing fee: $320 (micro entity) or $640 (small entity)
- This document is the specification — attach inventor declaration and USPTO cover sheet (SB/16)
- File BEFORE any public disclosure or GitHub push
- File non-provisional within 12 months incorporating test results

**Copyright 2026 123Tech / 2XR, LLC. All rights reserved.**
