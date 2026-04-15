import { useState, useEffect, useCallback, useRef } from "react";

const C = {
  bg: "#0a0e17", surface: "#111827", surfaceHi: "#1a2236",
  border: "#1e293b", borderHi: "#334155",
  accent: "#3b82f6", accentDim: "#1e3a6e",
  green: "#22c55e", greenDim: "#14532d",
  gold: "#eab308", goldDim: "#713f12",
  red: "#ef4444", redDim: "#7f1d1d",
  purple: "#a855f7", purpleDim: "#581c87",
  cyan: "#06b6d4", cyanDim: "#164e63",
  text: "#e2e8f0", textDim: "#94a3b8", textMute: "#64748b",
};

const SERVICES = [
  { id: "ollama", name: "Ollama", port: 7081, type: "inference", path: "Standard", color: C.accent, status: "running" },
  { id: "bitnet", name: "bitnet.cpp", port: 7091, type: "inference", path: "Ternary", color: C.cyan, status: "running" },
  { id: "cws", name: "CWS Engine", port: 7090, type: "core", path: "8th Reporter", color: C.gold, status: "running" },
  { id: "qdrant", name: "Qdrant", port: 7086, type: "memory", path: "Document RAG", color: C.green, status: "running" },
  { id: "mempalace", name: "MemPalace", port: 7092, type: "memory", path: "Conversations", color: C.purple, status: "running" },
  { id: "anythingllm", name: "AnythingLLM", port: 7078, type: "rag", path: "Workspaces", color: C.accent, status: "running" },
  { id: "kiwix", name: "Kiwix", port: 7083, type: "archive", path: "Archives", color: C.textDim, status: "running" },
  { id: "kolibri", name: "TriForce", port: 7084, type: "education", path: "Academy", color: C.textDim, status: "running" },
  { id: "maps", name: "ProtoMaps", port: 7085, type: "archive", path: "Maps", color: C.textDim, status: "running" },
];

const WITNESSES = [
  "LLaMA 3 8B", "Mistral 7B", "Gemma 2 9B", "Phi-4 14B",
  "Grok-1", "DeepSeek V3", "BLOOM 176B"
];

const PALACE_WINGS = [
  { name: "private-ai", rooms: 6, drawers: 142, halls: ["facts", "decisions", "events", "advice"] },
  { name: "archives", rooms: 3, drawers: 87, halls: ["facts"] },
  { name: "triforce", rooms: 4, drawers: 53, halls: ["facts", "events"] },
  { name: "skycair-os", rooms: 5, drawers: 94, halls: ["decisions", "facts"] },
  { name: "claude-dev", rooms: 8, drawers: 231, halls: ["decisions", "events", "advice"] },
];

const MCP_TOOLS = [
  "mempalace_status", "mempalace_search", "mempalace_list_wings", "mempalace_list_rooms",
  "mempalace_add_drawer", "mempalace_get_drawer", "mempalace_add_wing", "mempalace_add_room",
  "mempalace_kg_add", "mempalace_kg_search", "mempalace_kg_relate", "mempalace_kg_neighbors",
  "mempalace_diary_write", "mempalace_diary_read", "mempalace_compress", "mempalace_wake_up",
  "mempalace_mine", "mempalace_split", "mempalace_delete_drawer"
];

function usePulse(interval = 1500) {
  const [tick, setTick] = useState(0);
  useEffect(() => { const t = setInterval(() => setTick(p => p + 1), interval); return () => clearInterval(t); }, [interval]);
  return tick;
}

function Badge({ children, color = C.accent, glow = false }) {
  return (
    <span style={{
      display: "inline-block", padding: "2px 8px", borderRadius: 4, fontSize: 10, fontWeight: 700,
      background: color + "22", color, border: `1px solid ${color}44`,
      boxShadow: glow ? `0 0 8px ${color}44` : "none", letterSpacing: "0.05em",
    }}>{children}</span>
  );
}

function StatusDot({ status }) {
  const c = status === "running" ? C.green : status === "warning" ? C.gold : C.red;
  return <span style={{ display: "inline-block", width: 8, height: 8, borderRadius: "50%", background: c, boxShadow: `0 0 6px ${c}66`, marginRight: 6 }} />;
}

function Card({ title, children, accent = C.accent, span = 1, style = {} }) {
  return (
    <div style={{
      background: C.surface, border: `1px solid ${C.border}`, borderRadius: 8,
      borderTop: `2px solid ${accent}`, padding: 16, gridColumn: `span ${span}`,
      ...style,
    }}>
      {title && <div style={{ fontSize: 11, fontWeight: 700, color: C.textDim, textTransform: "uppercase", letterSpacing: "0.1em", marginBottom: 10 }}>{title}</div>}
      {children}
    </div>
  );
}

function InferencePanel({ tick }) {
  const [mode, setMode] = useState("dual");
  const tokSec = mode === "ternary" ? (5.2 + Math.random() * 1.8).toFixed(1) : mode === "standard" ? (12.4 + Math.random() * 3).toFixed(1) : (8.8 + Math.random() * 2.5).toFixed(1);
  const memGB = mode === "ternary" ? "0.4" : mode === "standard" ? "3.2" : "3.6";
  const energy = mode === "ternary" ? "0.028" : mode === "standard" ? "0.156" : "0.092";

  return (
    <Card title="Dual-Path Inference" accent={C.cyan} span={2}>
      <div style={{ display: "flex", gap: 6, marginBottom: 12 }}>
        {["standard", "ternary", "dual"].map(m => (
          <button key={m} onClick={() => setMode(m)} style={{
            padding: "4px 12px", borderRadius: 4, border: `1px solid ${mode === m ? C.cyan : C.border}`,
            background: mode === m ? C.cyan + "22" : "transparent", color: mode === m ? C.cyan : C.textDim,
            fontSize: 11, fontWeight: 600, cursor: "pointer", textTransform: "uppercase",
          }}>{m}</button>
        ))}
      </div>
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8 }}>
        <div style={{ background: C.surfaceHi, borderRadius: 6, padding: 10, border: `1px solid ${mode !== "ternary" ? C.accent + "44" : C.border}` }}>
          <div style={{ fontSize: 10, color: C.textMute, marginBottom: 4 }}>STANDARD · Ollama :7081</div>
          <div style={{ fontSize: 20, fontWeight: 700, color: mode !== "ternary" ? C.accent : C.textMute }}>{mode !== "ternary" ? "ACTIVE" : "IDLE"}</div>
          <div style={{ fontSize: 10, color: C.textDim }}>GGUF 4-8 bit · CPU+GPU</div>
        </div>
        <div style={{ background: C.surfaceHi, borderRadius: 6, padding: 10, border: `1px solid ${mode !== "standard" ? C.cyan + "44" : C.border}` }}>
          <div style={{ fontSize: 10, color: C.textMute, marginBottom: 4 }}>TERNARY · bitnet.cpp :7091</div>
          <div style={{ fontSize: 20, fontWeight: 700, color: mode !== "standard" ? C.cyan : C.textMute }}>{mode !== "standard" ? "ACTIVE" : "IDLE"}</div>
          <div style={{ fontSize: 10, color: C.textDim }}>1.58-bit native · CPU only</div>
        </div>
      </div>
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 8, marginTop: 10 }}>
        <div style={{ textAlign: "center" }}>
          <div style={{ fontSize: 22, fontWeight: 700, color: C.text }}>{tokSec}</div>
          <div style={{ fontSize: 9, color: C.textMute }}>TOKENS/SEC</div>
        </div>
        <div style={{ textAlign: "center" }}>
          <div style={{ fontSize: 22, fontWeight: 700, color: C.text }}>{memGB} GB</div>
          <div style={{ fontSize: 9, color: C.textMute }}>MEMORY</div>
        </div>
        <div style={{ textAlign: "center" }}>
          <div style={{ fontSize: 22, fontWeight: 700, color: C.text }}>{energy} J</div>
          <div style={{ fontSize: 9, color: C.textMute }}>ENERGY/TOK</div>
        </div>
      </div>
    </Card>
  );
}

function CWSPanel({ tick }) {
  const babel = (0.12 + Math.random() * 0.15).toFixed(2);
  const convergence = (0.82 + Math.random() * 0.12).toFixed(2);
  const fertile = Math.floor(85 + Math.random() * 12);
  const babelPct = parseFloat(babel) * 100;
  const tripped = babelPct > 70;

  return (
    <Card title="CWS · 8th Reporter (QUANTi)" accent={C.gold}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 8 }}>
        <Badge color={C.gold}>ForToken ✓</Badge>
        <Badge color={C.gold}>RevToken ✓</Badge>
        <Badge color={tripped ? C.red : C.green} glow={tripped}>{tripped ? "BABEL TRIP" : "CLEAR"}</Badge>
      </div>
      <div style={{ marginBottom: 8 }}>
        <div style={{ display: "flex", justifyContent: "space-between", fontSize: 10, color: C.textMute, marginBottom: 3 }}>
          <span>Babel Ratio</span><span>{babel} / 0.70</span>
        </div>
        <div style={{ height: 6, background: C.surfaceHi, borderRadius: 3, overflow: "hidden" }}>
          <div style={{ height: "100%", width: `${Math.min(babelPct / 70 * 100, 100)}%`, background: babelPct > 50 ? C.gold : C.green, borderRadius: 3, transition: "width 0.5s" }} />
        </div>
      </div>
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 6 }}>
        <div style={{ background: C.surfaceHi, borderRadius: 4, padding: 6, textAlign: "center" }}>
          <div style={{ fontSize: 18, fontWeight: 700, color: C.gold }}>{convergence}</div>
          <div style={{ fontSize: 9, color: C.textMute }}>CONVERGENCE</div>
        </div>
        <div style={{ background: C.surfaceHi, borderRadius: 4, padding: 6, textAlign: "center" }}>
          <div style={{ fontSize: 18, fontWeight: 700, color: C.green }}>{fertile}%</div>
          <div style={{ fontSize: 9, color: C.textMute }}>FERTILE</div>
        </div>
      </div>
      <div style={{ marginTop: 8, fontSize: 10, color: C.textDim }}>
        7 witnesses: {WITNESSES.map((w, i) => (
          <span key={w} style={{ color: C.textMute }}>{i > 0 && " · "}{w}</span>
        ))}
      </div>
    </Card>
  );
}

function MemoryPanel({ tick }) {
  const totalDrawers = PALACE_WINGS.reduce((s, w) => s + w.drawers, 0);
  const syncCount = 12 + (tick % 5);

  return (
    <Card title="Memory · Dual-Store + MCP Bridge" accent={C.purple} span={2}>
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 8, marginBottom: 10 }}>
        <div style={{ background: C.surfaceHi, borderRadius: 6, padding: 8, borderLeft: `3px solid ${C.green}` }}>
          <div style={{ fontSize: 10, color: C.textMute }}>Qdrant :7086</div>
          <div style={{ fontSize: 14, fontWeight: 700, color: C.text }}>Document RAG</div>
          <div style={{ fontSize: 10, color: C.green }}>Vectors: 14,832</div>
        </div>
        <div style={{ background: C.surfaceHi, borderRadius: 6, padding: 8, borderLeft: `3px solid ${C.purple}` }}>
          <div style={{ fontSize: 10, color: C.textMute }}>MemPalace :7092</div>
          <div style={{ fontSize: 14, fontWeight: 700, color: C.text }}>Conversations</div>
          <div style={{ fontSize: 10, color: C.purple }}>{totalDrawers} drawers · 96.6%</div>
        </div>
        <div style={{ background: C.surfaceHi, borderRadius: 6, padding: 8, borderLeft: `3px solid ${C.gold}` }}>
          <div style={{ fontSize: 10, color: C.textMute }}>PostgreSQL :7090</div>
          <div style={{ fontSize: 14, fontWeight: 700, color: C.text }}>CWS Schema</div>
          <div style={{ fontSize: 10, color: C.gold }}>5 schemas · ~35 tables</div>
        </div>
      </div>
      <div style={{ fontSize: 10, fontWeight: 700, color: C.textDim, marginBottom: 6 }}>PALACE WINGS</div>
      <div style={{ display: "flex", gap: 4, flexWrap: "wrap", marginBottom: 10 }}>
        {PALACE_WINGS.map(w => (
          <div key={w.name} style={{ background: C.surfaceHi, borderRadius: 4, padding: "3px 8px", fontSize: 10 }}>
            <span style={{ color: C.purple, fontWeight: 700 }}>{w.name}</span>
            <span style={{ color: C.textMute }}> {w.rooms}r · {w.drawers}d</span>
          </div>
        ))}
      </div>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <div style={{ fontSize: 10, color: C.textDim }}>
          Bridge sync: <span style={{ color: C.green }}>{syncCount} FERTILE</span> · <span style={{ color: C.red }}>0 BABEL</span>
        </div>
        <Badge color={C.purple}>19 MCP TOOLS</Badge>
      </div>
    </Card>
  );
}

function MCPPanel() {
  const [expanded, setExpanded] = useState(false);
  return (
    <Card title="MCP Tool Surface · Claude Code Bridge" accent={C.accent}>
      <div style={{ fontSize: 10, color: C.textDim, marginBottom: 8 }}>
        Claude Code connects via MCP to all services. CLAUDE.md auto-generated from MemPalace wake-up (~170 tokens L0+L1).
      </div>
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 6, marginBottom: 8 }}>
        {[
          { label: "MemPalace", count: 19, color: C.purple },
          { label: "CWS", count: 8, color: C.gold },
          { label: "AnythingLLM", count: 12, color: C.accent },
        ].map(g => (
          <div key={g.label} style={{ background: C.surfaceHi, borderRadius: 4, padding: 6, textAlign: "center" }}>
            <div style={{ fontSize: 16, fontWeight: 700, color: g.color }}>{g.count}</div>
            <div style={{ fontSize: 9, color: C.textMute }}>{g.label}</div>
          </div>
        ))}
      </div>
      <button onClick={() => setExpanded(!expanded)} style={{
        background: "transparent", border: `1px solid ${C.border}`, borderRadius: 4,
        color: C.textDim, fontSize: 10, padding: "3px 8px", cursor: "pointer", width: "100%",
      }}>{expanded ? "▲ Hide Tools" : "▼ Show All 19 MemPalace MCP Tools"}</button>
      {expanded && (
        <div style={{ marginTop: 8, display: "flex", flexWrap: "wrap", gap: 3 }}>
          {MCP_TOOLS.map(t => (
            <span key={t} style={{ fontSize: 9, padding: "2px 6px", borderRadius: 3, background: C.purple + "18", color: C.purple, border: `1px solid ${C.purple}33` }}>{t}</span>
          ))}
        </div>
      )}
    </Card>
  );
}

function ServicesPanel() {
  return (
    <Card title="Service Stack · Ports 7078–7092" accent={C.green}>
      <div style={{ display: "flex", flexDirection: "column", gap: 4 }}>
        {SERVICES.map(s => (
          <div key={s.id} style={{ display: "flex", alignItems: "center", justifyContent: "space-between", padding: "3px 0", borderBottom: `1px solid ${C.border}22` }}>
            <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
              <StatusDot status={s.status} />
              <span style={{ fontSize: 11, color: C.text, fontWeight: 600 }}>{s.name}</span>
            </div>
            <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
              <span style={{ fontSize: 10, color: C.textMute }}>{s.path}</span>
              <span style={{ fontSize: 10, color: s.color, fontFamily: "monospace" }}>:{s.port}</span>
            </div>
          </div>
        ))}
      </div>
    </Card>
  );
}

function DataFlowPanel({ tick }) {
  const flows = [
    { from: "Claude Code", to: "MemPalace", label: "Stop hook → save", color: C.purple },
    { from: "MemPalace", to: "CWS", label: "FERTILE → import", color: C.gold },
    { from: "CWS", to: "MemPalace", label: "results → publish", color: C.cyan },
    { from: "MemPalace", to: "CLAUDE.md", label: "wake-up → 170 tok", color: C.green },
    { from: "AnythingLLM", to: "Qdrant", label: "embed → vectors", color: C.accent },
    { from: "Query", to: "bitnet.cpp", label: "ternary → infer", color: C.cyan },
    { from: "Query", to: "Ollama", label: "standard → infer", color: C.accent },
    { from: "7 Witnesses", to: "CWS", label: "consensus → QUANTi", color: C.gold },
  ];
  const active = tick % flows.length;

  return (
    <Card title="Data Flow · Convergence Pipeline" accent={C.cyan} span={2}>
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 4 }}>
        {flows.map((f, i) => (
          <div key={i} style={{
            display: "flex", alignItems: "center", gap: 6, padding: "4px 8px",
            background: i === active ? f.color + "15" : "transparent",
            borderRadius: 4, border: i === active ? `1px solid ${f.color}44` : "1px solid transparent",
            transition: "all 0.3s",
          }}>
            <span style={{ fontSize: 10, color: f.color, fontWeight: 700, minWidth: 80 }}>{f.from}</span>
            <span style={{ fontSize: 10, color: C.textMute }}>→</span>
            <span style={{ fontSize: 10, color: C.text, fontWeight: 600, minWidth: 70 }}>{f.to}</span>
            <span style={{ fontSize: 9, color: C.textMute, marginLeft: "auto" }}>{f.label}</span>
          </div>
        ))}
      </div>
    </Card>
  );
}

function QuerySimulator({ tick }) {
  const [query, setQuery] = useState("");
  const [result, setResult] = useState(null);
  const [processing, setProcessing] = useState(false);

  const simulate = useCallback(() => {
    if (!query.trim()) return;
    setProcessing(true);
    setResult(null);
    setTimeout(() => {
      setResult({
        path: Math.random() > 0.5 ? "ternary" : "dual",
        witnesses: 7,
        unanimous: Math.random() > 0.3,
        babel: (Math.random() * 0.25).toFixed(2),
        fertile: Math.floor(88 + Math.random() * 10),
        fortoken: true,
        revtoken: true,
        mempalace_hit: Math.random() > 0.4,
        qdrant_hit: Math.random() > 0.5,
        tokens: Math.floor(40 + Math.random() * 120),
        latency: Math.floor(80 + Math.random() * 400),
      });
      setProcessing(false);
    }, 1200);
  }, [query]);

  return (
    <Card title="Query Simulator" accent={C.green} span={2}>
      <div style={{ display: "flex", gap: 6, marginBottom: 10 }}>
        <input
          value={query}
          onChange={e => setQuery(e.target.value)}
          onKeyDown={e => e.key === "Enter" && simulate()}
          placeholder="Enter a query to trace through the convergence pipeline..."
          style={{
            flex: 1, background: C.surfaceHi, border: `1px solid ${C.border}`, borderRadius: 4,
            padding: "6px 10px", color: C.text, fontSize: 12, outline: "none",
          }}
        />
        <button onClick={simulate} disabled={processing} style={{
          padding: "6px 16px", borderRadius: 4, border: "none", cursor: "pointer",
          background: processing ? C.surfaceHi : C.accent, color: C.text, fontSize: 11, fontWeight: 700,
        }}>{processing ? "..." : "TRACE"}</button>
      </div>
      {result && (
        <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 6 }}>
          <div style={{ background: C.surfaceHi, borderRadius: 4, padding: 6, textAlign: "center" }}>
            <div style={{ fontSize: 14, fontWeight: 700, color: result.path === "ternary" ? C.cyan : C.accent }}>{result.path.toUpperCase()}</div>
            <div style={{ fontSize: 9, color: C.textMute }}>PATH</div>
          </div>
          <div style={{ background: C.surfaceHi, borderRadius: 4, padding: 6, textAlign: "center" }}>
            <div style={{ fontSize: 14, fontWeight: 700, color: result.unanimous ? C.green : C.gold }}>{result.unanimous ? "7/7" : "6/7"}</div>
            <div style={{ fontSize: 9, color: C.textMute }}>CONSENSUS</div>
          </div>
          <div style={{ background: C.surfaceHi, borderRadius: 4, padding: 6, textAlign: "center" }}>
            <div style={{ fontSize: 14, fontWeight: 700, color: C.green }}>{result.fertile}%</div>
            <div style={{ fontSize: 9, color: C.textMute }}>FERTILE</div>
          </div>
          <div style={{ background: C.surfaceHi, borderRadius: 4, padding: 6, textAlign: "center" }}>
            <div style={{ fontSize: 14, fontWeight: 700, color: C.text }}>{result.latency}ms</div>
            <div style={{ fontSize: 9, color: C.textMute }}>LATENCY</div>
          </div>
          <div style={{ gridColumn: "span 4", display: "flex", gap: 6, flexWrap: "wrap" }}>
            <Badge color={C.gold}>ForToken ✓</Badge>
            <Badge color={C.gold}>RevToken ✓</Badge>
            <Badge color={parseFloat(result.babel) < 0.7 ? C.green : C.red}>Babel: {result.babel}</Badge>
            {result.mempalace_hit && <Badge color={C.purple}>MemPalace HIT</Badge>}
            {result.qdrant_hit && <Badge color={C.green}>Qdrant HIT</Badge>}
            <Badge color={C.textDim}>{result.tokens} tokens</Badge>
          </div>
        </div>
      )}
    </Card>
  );
}

export default function SkyCAIRCommandCenter() {
  const tick = usePulse(2000);
  const pulseState = tick % 2 === 0 ? "0" : "1";

  return (
    <div style={{ background: C.bg, minHeight: "100vh", padding: 16, fontFamily: "'JetBrains Mono', 'SF Mono', 'Fira Code', monospace" }}>
      <div style={{ maxWidth: 900, margin: "0 auto" }}>
        {/* Header */}
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 16, padding: "12px 16px", background: C.surface, borderRadius: 8, border: `1px solid ${C.border}` }}>
          <div>
            <div style={{ fontSize: 18, fontWeight: 800, color: C.text, letterSpacing: "0.05em" }}>
              <span style={{ color: C.textMute }}>UNIFIED LINUX</span>{" "}
              <span style={{ color: C.accent }}>SkyCAIR</span>{" "}
              <span style={{ color: C.textMute }}>by</span>{" "}
              <span style={{ color: C.gold }}>S7</span>
            </div>
            <div style={{ fontSize: 10, color: C.textMute, marginTop: 2 }}>
              Command Center · Convergence Architecture v2.2.1 · 01010 pulse: <span style={{ color: pulseState === "1" ? C.gold : C.cyan, fontWeight: 700 }}>{pulseState}</span>
            </div>
          </div>
          <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
            <Badge color={C.green} glow>9 SERVICES</Badge>
            <Badge color={C.purple}>19 MCP</Badge>
            <Badge color={C.gold}>7 WITNESSES</Badge>
          </div>
        </div>

        {/* Grid */}
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
          <InferencePanel tick={tick} />
          <CWSPanel tick={tick} />
          <MemoryPanel tick={tick} />
          <MCPPanel />
          <ServicesPanel />
          <DataFlowPanel tick={tick} />
          <QuerySimulator tick={tick} />
        </div>

        {/* Footer */}
        <div style={{ marginTop: 16, textAlign: "center", padding: "10px 0" }}>
          <div style={{ fontSize: 9, color: C.textMute }}>
            BSL-1.1 · 123Tech.net · Evolve2Linux.com · SkyNetSSL (Safe Secure Linux) · OmegaAnswers@123Tech.net
          </div>
          <div style={{ fontSize: 9, color: C.textMute, marginTop: 2, fontStyle: "italic" }}>
            Love is the architecture. Let the world test and develop.
          </div>
        </div>
      </div>
    </div>
  );
}
