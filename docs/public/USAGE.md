# Using S7 SkyQUB*i*

> **Release status (as of 2026-04-14):** S7 SkyQUB*i* is in the
> **pre-launch testing window**. Full public launch on
> **July 7, 2026 · 7:00 AM Central**. The CLI and HTTP API
> interactions below are stable for the current deployment.
> The persona chat interface (Carli / Elias / Samuel) lands
> with the GO-LIVE ceremony after voice calibration is
> completed and signed by the household's Chief of Covenant.
> See [README.md](README.md) for the full release status.

Once you have the pod running (see [INSTALL.md](INSTALL.md)), there are three ways to interact with the witness network: the CLI, the HTTP API, and the upcoming chat interface.

## The fastest test — ask the witnesses a question

```bash
curl -s http://127.0.0.1:57088/witness -H 'Content-Type: application/json' \
  -d '{"question": "What is 2 + 2?"}' | jq
```

You should see something like:

```json
{
  "classification": "FERTILE",
  "confidence": 0.94,
  "answer": "4",
  "witnesses": [
    {"model": "qwen2.5:3b",       "response": "4"},
    {"model": "deepseek-coder:1.3b", "response": "4"},
    {"model": "qwen3:0.6b",       "response": "4"}
  ]
}
```

All three witnesses agreed. Classification is **FERTILE**. You get an answer.

## Tripping the circuit breaker

Ask a question the witnesses will genuinely disagree on:

```bash
curl -s http://127.0.0.1:57088/witness -H 'Content-Type: application/json' \
  -d '{"question": "Is 1 a prime number?"}' | jq
```

You'll often see:

```json
{
  "classification": "BABEL",
  "confidence": 0.42,
  "answer": null,
  "reason": "witnesses below 70% agreement threshold — circuit breaker tripped"
}
```

No answer. That's the covenant working. S7 refuses rather than guesses.

## Classification states

| State         | Meaning                                                  |
|---------------|----------------------------------------------------------|
| **FERTILE**   | Witnesses agree above threshold → answer is returned     |
| **AMBIGUOUS** | Partial agreement → returned with confidence score      |
| **BABEL**     | Too much disagreement → circuit breaker, no answer     |
| **UNVERIFIED**| Not enough witnesses responded in time → no answer     |

## Reading the witnesses list

```bash
curl -s http://127.0.0.1:57088/witnesses | jq
```

Returns the live witness roster — which models are loaded, what cognitive plane each sits on, current health. This is what's rendered in the live OCT*i* network visualization on [skyqubi.com](https://skyqubi.com).

## Full witness set (advanced)

The default install uses the lite 3+1 witness set. For the full 7+1 set (LLaMA 3.2, Mistral, Gemma 2 9B, Phi-4, Qwen 32B, DeepSeek R1, BLOOM + CWS reporter) see the deploy guide in the repo.

Each full witness sits on one cognitive plane:

| Plane       | Model        |
|-------------|--------------|
| Sensory     | LLaMA 3.2 3B |
| Episodic    | Mistral 7B   |
| Semantic    | Gemma 2 9B   |
| Associative | Phi-4        |
| Abstract    | Qwen 32B     |
| Causal      | DeepSeek R1  |
| Generative  | BLOOM        |

The CWS reporter sits at the center and refuses to speak when the seven disagree.

## The chat interface

Coming July 7, 2026 at [skyqubi.ai](https://skyqubi.ai). Today it's a scripted preview of what the real chat will look like. The underlying witness network is the same — the chat just wraps it in a friendlier interface.

## What NOT to do

- **Don't expose port 57088 directly to the internet.** Put a reverse proxy in front with TLS + authentication.
- **Don't assume FERTILE means "true".** It means "the witnesses agree." Witnesses can agree on something incorrect. The covenant is a *disagreement* detector, not a truth oracle.
- **Don't ignore BABEL states.** When the circuit breaker trips, there's usually a real reason — research the disagreement rather than forcing an answer.

## The motto

*Love is the architecture.* The witnesses watch each other. The covenant holds them all.
