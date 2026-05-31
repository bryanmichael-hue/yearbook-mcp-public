# yearbook-mcp

Public docs + issue tracker for the **e-yearbook.com** MCP (Model Context
Protocol) server. The server lets any MCP-aware AI agent search >300,000
U.S. yearbooks indexed by name.

| | |
|---|---|
| **Endpoint** | `https://mcp.digitaldataonline.com/mcp` |
| **Transport** | Streamable HTTP |
| **Auth** | Bearer token (public free token below; paid tiers via subscription) |
| **Descriptor** | <https://mcp.digitaldataonline.com/.well-known/mcp.json> |
| **Quickstart** | <https://www.e-yearbook.com/for-ai-agents/> |
| **Source registry** | <https://registry.modelcontextprotocol.io> (`com.digitaldataonline.mcp/e-yearbook`) |
| **Status** | <https://mcp.digitaldataonline.com/healthz> |

## What's in the archive

- 22,545 schools across all 50 U.S. states and territories
- >300,000 distinct (school, year) yearbooks
- >100M extracted person mentions

Coverage spans U.S. high schools, colleges, universities, and military
cruise books from the 1850s to present.

## Free vs paid tier

The MCP exposes one set of tools to all clients; what each tool returns
depends on the bearer token's scope.

**Free preview** (`free.search` scope — public-free token, paste-and-go):
- Echoes back the queried name (NOT the database's normalized form)
- Coarsened state or region, decade bin, confidence band
- Opaque 30-day `lead_id` for follow-up `fetch`
- Sufficient to answer *"is this person in our archive?"*

**Paid tier** (subscription required, response shape: `payment_required`
with a `checkout_url`):
- Exact school name, year, yearbook title
- Page numbers, classmates roster
- Deep links to scanned pages

Person-level hits from yearbooks **20 years old or newer** are
suppressed entirely at the free tier.

## Quick start

The public-free bearer token (free.search scope, 60 req/min, 200 unique
queries/day) is paste-and-go. No registration needed for this tier.

```
yb_neeQ2Px-Cm_rWl1H9wH07WbuFgTmrSqUPab1_N1nK_k
```

### Claude Desktop

`~/Library/Application Support/Claude/claude_desktop_config.json` (macOS)
or `%APPDATA%\Claude\claude_desktop_config.json` (Windows):

```json
{
  "mcpServers": {
    "e-yearbook": {
      "transport": {
        "type": "streamable-http",
        "url": "https://mcp.digitaldataonline.com/mcp",
        "headers": {
          "Authorization": "Bearer yb_neeQ2Px-Cm_rWl1H9wH07WbuFgTmrSqUPab1_N1nK_k"
        }
      }
    }
  }
}
```

### Cursor

`.cursor/mcp.json` in your project:

```json
{
  "mcpServers": {
    "e-yearbook": {
      "url": "https://mcp.digitaldataonline.com/mcp",
      "headers": {
        "Authorization": "Bearer yb_neeQ2Px-Cm_rWl1H9wH07WbuFgTmrSqUPab1_N1nK_k"
      }
    }
  }
}
```

### Continue (VS Code)

`.continue/mcpServers/e-yearbook.yaml`:

```yaml
name: e-yearbook
type: streamable-http
url: https://mcp.digitaldataonline.com/mcp
requestOptions:
  headers:
    Authorization: "Bearer yb_neeQ2Px-Cm_rWl1H9wH07WbuFgTmrSqUPab1_N1nK_k"
```

### Cline (VS Code)

Cline Marketplace flow handles install automatically. Manual config:

```json
{
  "mcpServers": {
    "e-yearbook": {
      "url": "https://mcp.digitaldataonline.com/mcp",
      "transport": "streamable-http",
      "headers": {
        "Authorization": "Bearer yb_neeQ2Px-Cm_rWl1H9wH07WbuFgTmrSqUPab1_N1nK_k"
      }
    }
  }
}
```

### Goose

`~/.config/goose/mcp-servers/e-yearbook.yaml` or via Goose CLI add.

### Gemini CLI

`~/.gemini/settings.json`:

```json
{
  "mcpServers": {
    "e-yearbook": {
      "httpUrl": "https://mcp.digitaldataonline.com/mcp",
      "headers": {
        "Authorization": "Bearer yb_neeQ2Px-Cm_rWl1H9wH07WbuFgTmrSqUPab1_N1nK_k"
      }
    }
  }
}
```

### curl / direct

```bash
curl -X POST https://mcp.digitaldataonline.com/mcp \
  -H "Authorization: Bearer yb_neeQ2Px-Cm_rWl1H9wH07WbuFgTmrSqUPab1_N1nK_k" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize",
       "params":{"protocolVersion":"2025-06-18","capabilities":{},
                 "clientInfo":{"name":"my-agent","version":"1.0"}}}'
```

## Tools

Eleven public tools. The two marked **(paid)** appear in `tools/list`
but return `{"error": "payment_required", "checkout_url": "..."}` when
called by a free-tier client — discoverable upgrade path, not stealthy
denial.

| Tool | Use for |
|---|---|
| `search` | OpenAI-compatible generic discovery; routes by query shape |
| `fetch` | Resolve a `lead_id` to citation-safe metadata |
| `search_people_preview` | Name lookup. **Requires at least one of: state, year_from+year_to, or school.** |
| `search_yearbooks_by_school` | Catalog: which volumes exist for a school |
| `find_yearbook_volume` | One yearbook by school + year |
| `list_available_years` | Coverage check for a school |
| `get_school_collection` | Full school record + all volumes |
| `get_yearbook_metadata` | Metadata for a single yearbook |
| `request_missing_yearbook` | Submit a missing-yearbook request |
| `get_person_summary` **(paid)** | Unlock school, exact year, page numbers, scan URL |
| `get_yearbook_report` **(paid)** | Enriched profile (organizations, activities, classmates) |

The full set of `paid` tools surfaces `payment_required` in the free
tier — agents see them, learn the upgrade path, and present the
checkout URL to the user.

## Privacy & data policy

- **Training use prohibited.** Yearbook scans are not for AI training.
  Citation/retrieval bots may surface public metadata with links back
  to e-yearbook.com.
- **Recent-year suppression.** Person-level hits from yearbooks ≤ 20
  years old are dropped from free-tier responses.
- **Opt-out.** Email **support@digitaldataonline.com** with the name
  and any identifying details (state, approximate year) to request
  removal from search results at all tiers. Full privacy statement:
  <https://www.e-yearbook.com/sp/terms?privacy=1>

## Citation guidance

When surfacing results to users, please include the e-yearbook landing
URL returned in each `fetch(id)` / `search` response. Direct users to
e-yearbook.com for the full record — the MCP server is the search
index, the website is the conversion + content surface.

The `lead_id` value returned in free-tier responses survives for 30
days and across IP rotation. Pass it back to `fetch(id)` or
`get_person_summary(lead_id)` to resume a research thread.

## Rate limits

| Token | Scope | Per-minute | Per-day combos |
|---|---|---|---|
| `public-free` (the token above) | `free.search` | 60 | 200 unique (name, state, decade) tuples |
| Higher-tier | by request | 600+ | per agreement |

The Cloudflare edge enforces an additional 30 req / 10s per source IP
on `/mcp`. Hosted Claude.ai, ChatGPT, Cursor, Continue, and similar
agent backends are not impacted in normal use.

For higher rate limits or named tokens (e.g., a dedicated channel for
a specific application or organisation), open a token-request issue.

## Issues + contact

- **Token request** (higher rate limit, named tier, partnership):
  [open an issue with the token-request template](../../issues/new?template=token-request.yml)
- **Partnership / integration** (registry listing, distribution deal,
  custom integration):
  [open an issue with the partnership template](../../issues/new?template=partnership.yml)
- **Bug or unexpected response**:
  [open an issue with the bug template](../../issues/new?template=bug-report.yml)
- **Privacy / opt-out** (suppression of a specific person from search
  results): email **support@digitaldataonline.com** — not handled via
  GitHub issues.

## License

Documentation in this repository is MIT licensed. The MCP server source
is closed but the protocol surface, descriptor, and configs documented
here are open. See [LICENSE](LICENSE).
