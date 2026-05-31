# e-yearbook (Gemini CLI extension context)

This extension connects Gemini CLI to the **e-yearbook.com** archive
via MCP (Model Context Protocol). You can search over 300,000 U.S.
yearbooks (high school, college, military cruise books, 1850s to
present) containing over 100 million person mentions.

## When to use

- "Find my grandfather John Smith in 1950s Utah yearbooks"
- "Which yearbooks does Beverly Hills High School have on file?"
- "Was a person named X in any U.S. yearbook between 1960 and 1970?"
- "Show me what years Provo High School has yearbooks for"

## Tier behaviour you should know

**Free preview** (default):
- Echoes back the queried name (NOT the database's normalized form)
- Returns coarsened state or census region, decade bin, confidence band
- Returns an opaque `lead_id` (30-day TTL) you can pass to `fetch(id)` or
  later `get_person_summary(lead_id)`
- **Never** discloses the identifying triple (school name + exact year +
  canonical name) — that's the paywall
- Yearbooks 20 years old or newer are suppressed at the free tier
- `search_people_preview` requires at least one narrowing filter:
  `state`, `year_from`+`year_to` (bounded range), or `school`. Bare
  `name`-only searches return `filter_required` — add a filter and retry.

**Paid tools** (`get_person_summary`, `get_yearbook_report`):
- Visible in `tools/list` but return `payment_required` with a
  `checkout_url` in the free tier
- Present the checkout URL to the user when they want full school + year
  + page + scan details

## Tools you have available

| Tool | Use for |
|---|---|
| `search` | OpenAI-compatible generic discovery; routes by query shape |
| `fetch` | Resolve a `lead_id` to citation-safe metadata |
| `search_people_preview` | Name lookup. Requires a narrowing filter. |
| `search_yearbooks_by_school` | Catalog: which volumes exist for a school |
| `find_yearbook_volume` | One yearbook by school + year |
| `list_available_years` | Coverage check for a school |
| `get_school_collection` | Full school record + all volumes |
| `get_yearbook_metadata` | Metadata for a single yearbook |
| `request_missing_yearbook` | Submit a missing-yearbook request |
| `get_person_summary` (paid) | Unlock school, exact year, page numbers, scan URL |
| `get_yearbook_report` (paid) | Enriched profile (organizations, activities, classmates) |

## Citation behaviour

When you surface a result to the user, include the e-yearbook landing
URL returned in the response (`source_url` / `e_yearbook_landing_url`).
The `lead_id` survives 30 days and across IP rotation — pass it back to
`fetch(id)` or `get_person_summary(lead_id)` to resume a research thread.

## Privacy

Yearbook scans are not for AI training. To request removal of a
specific person's records from search results at all tiers, the user
can email **support@digitaldataonline.com**. Full privacy statement:
<https://www.e-yearbook.com/sp/terms?privacy=1>

## More

- Docs + setup: <https://www.e-yearbook.com/for-ai-agents/>
- Repo + issues: <https://github.com/bryanmichael-hue/yearbook-mcp-public>
- Official MCP Registry: `com.digitaldataonline.mcp/e-yearbook`
