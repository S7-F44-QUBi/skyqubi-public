# S7 SkyQUB*i* — Architecture (Public Overview)

> **Release status (as of 2026-04-14):** the architecture below
> is the **stable public-facing overview**. Internal work on
> the CORE reframe (PRISM/GRID/WALL), the persona-internal
> council pattern, the immutable-fork rebuild ceremony, and
> voice calibration for the three personas is in active
> Chair-draft / Jamie-authorized review pending the household
> Chief of Covenant's witness. Full public launch:
> **July 7, 2026 · 7:00 AM Central**. See [README.md](README.md)
> for release status and path.

This is the high-level architecture. Internal runbooks, deploy procedures, and infrastructure details live in the private repo and are not published.

## The shape

```
  ┌────────────────────────────────────────────────────┐
  │                   You / Your App                    │
  └─────────────────────────┬──────────────────────────┘
                            │
                   (HTTP or direct CLI)
                            │
  ┌─────────────────────────▼──────────────────────────┐
  │             S7 Public Chat API / CLI                │
  │         (accepts a question, returns consensus)     │
  └─────────────────────────┬──────────────────────────┘
                            │
                  ┌─────────▼──────────┐
                  │    CWS Engine       │  ← the covenant layer
                  │   (classification,  │
                  │    circuit breaker) │
                  └─────────┬──────────┘
                            │
            ┌───────────────┼───────────────┐
            │               │               │
  ┌─────────▼─────┐ ┌───────▼──────┐ ┌─────▼─────────┐
  │  Witness 1    │ │  Witness 2   │ │  Witness N    │
  │  (qwen 3B)    │ │  (deepseek)  │ │  (qwen 0.6)   │
  └───────────────┘ └──────────────┘ └───────────────┘
            │               │               │
            └───────────────┼───────────────┘
                            │
                  ┌─────────▼──────────┐
                  │   MemPalace         │  ← shared memory
                  │   (Akashic index)   │
                  └─────────┬──────────┘
                            │
                  ┌─────────▼──────────┐
                  │  Memory Ledger      │  ← insert-only store
                  │  (PostgreSQL +      │
                  │   SQLite)           │
                  └────────────────────┘
```

## The flow

1. **You send a question** to the public chat API (or call the witness function directly).
2. **CWS Engine** receives it, forwards it in parallel to every witness. No witness sees another's answer.
3. **Each witness answers** independently. Different model family, different training data, different cognitive plane.
4. **CWS scores agreement** using embedding similarity (`all-minilm`) with Jaccard token fallback.
5. **Classification** is assigned:
   - **FERTILE** — agreement above threshold, answer returned
   - **AMBIGUOUS** — partial agreement, returned with confidence
   - **BABEL** — disagreement beyond 70%, circuit breaker trips, **no answer**
   - **UNVERIFIED** — insufficient witness response, no answer
6. **MemPalace records** the interaction in the Akashic language index for future recall, with PLAN location metadata and hallucination flags.
7. **Memory Ledger** stores the bond vectors in INSERT-only form. Nothing that entered the system can be made to have never existed.

## The covenant

The architecture embodies seven laws. See [COVENANT.md](COVENANT.md) for the full table.

The most important one: **the circuit breaker.** At 70% BABEL, the system refuses to answer. This is not a hyperparameter. It is the constant that makes disagreement a feature, not a failure.

## The witnesses

The default install runs the **lite 3+1 set** — three small models from three different families plus the CWS reporter. The full set is **7+1** — seven models on seven cognitive planes, plus the deterministic reporter at the center. Both sets use the same consensus and classification machinery; the lite set is optimized for running on hardware you already own.

| Lite set     | Full set (7 witnesses)    |
|--------------|---------------------------|
| qwen2.5:3b   | LLaMA 3.2 3B (Sensory)    |
| deepseek 1.3b| Mistral 7B (Episodic)     |
| qwen3:0.6b   | Gemma 2 9B (Semantic)     |
| + CWS        | Phi-4 (Associative)       |
|              | Qwen 32B (Abstract)       |
|              | DeepSeek R1 (Causal)      |
|              | BLOOM (Generative)        |
|              | + CWS                      |

## What the covenant protects against

- **Hallucinations** — one witness hallucinates something; the others don't; CWS notes the disagreement and either flags AMBIGUOUS or trips BABEL.
- **Prompt injection** — a witness is successfully attacked; the others aren't; same outcome.
- **Model collapse** — a single model is having a bad day; the consensus catches it.
- **Vendor capture** — no single model provider can dominate because the witnesses are architecturally diverse.

What it does **not** protect against: all witnesses being wrong in the same way. If every witness is trained on the same biased data, they may agree on something untrue. The covenant catches *disagreement*, not *error*. That's why the full set uses models from seven different training lineages.

## Sovereignty properties

- **No cloud dependency** — once models are downloaded, the system runs fully offline.
- **No telemetry** — S7 ships no metrics, usage data, or phone-home to any external service.
- **All ports on localhost** by default — nothing auto-exposes to the network.
- **Zero-trust per-endpoint** — every API endpoint authenticates its caller independently.
- **Insert-only memory** — nothing you put in can be erased. Good for audit trails, good for covenant.

## What's out of scope for this document

- Exact port numbers beyond the localhost bindings
- Internal hostnames, IP assignments, service mesh details
- Credentials, API keys, rotation schedule
- Deploy automation, CI/CD pipeline
- Database schemas beyond the conceptual level

Those live in the private repo's `docs/internal/` and are not published. If you're integrating S7 in a way that needs them, contact [omegaanswers@123tech.net](mailto:omegaanswers@123tech.net).

## The motto, again

*Love is the architecture.* Everything above is a consequence of taking that seriously.
