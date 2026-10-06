#!/usr/bin/ksh
# Fixed-scope Uno discovery refresh. No Apache restart, ecommerce or Stripe changes.
set -eu
umask 077
fail() { echo "REFUSED: $*" >&2; exit 1; }
test "$(/usr/bin/uname -n)" = uno || fail 'run on uno'
test "$(/usr/xpg4/bin/id -u)" = 0 || fail 'run as root on uno'
# Uno's observed, root-owned /usr/local -> /export/local alias is intentional.
# Write via the physical path, after checking its ancestry, not through the alias.
D=/export/local/apache/htdocs
W=/var/opt/yb-discovery-20261006
/usr/bin/perl - 0 /usr/local /export/local \
    / /usr /export /export/local /export/local/apache "$D" \
    "$D/for-ai-agents" "$D/.well-known" /var /var/opt <<'YB_UNO_PREFLIGHT'
use strict;
use warnings;
use Fcntl ':mode';
use Cwd 'realpath';
my $owner = shift @ARGV;
my $alias = shift @ARGV;
my $physical = shift @ARGV;
my @a = lstat($alias);
die "REFUSED: unexpected alias $alias\n"
    unless @a && S_ISLNK($a[2]) && $a[4] == $owner
        && readlink($alias) eq $physical;
my $resolved = realpath("$alias/apache/htdocs");
die "REFUSED: document-root alias resolves elsewhere\n"
    unless defined($resolved) && $resolved eq "$physical/apache/htdocs";
for my $p (@ARGV) {
    my @s = lstat($p);
    die "REFUSED: missing directory $p\n" unless @s;
    die "REFUSED: not a physical directory $p\n" unless S_ISDIR($s[2]);
    die "REFUSED: unexpected owner or writable ancestry $p\n"
        unless $s[4] == $owner && ($s[2] & 0022) == 0;
}
print "UNO_PREFLIGHT_OK; approved alias and physical ancestry verified; no mutation.\n";
YB_UNO_PREFLIGHT
mkdir -m 0700 "$W"
mkdir -m 0700 "$W/original" "$W/staged"
# Preserve the exact originals and permissions before changing any public file.
for name in index.html mcp.json mcp-server llms.txt; do
    case "$name" in
        index.html) rel=for-ai-agents/index.html ;;
        mcp.json|mcp-server) rel=.well-known/$name ;;
        llms.txt) rel=llms.txt ;;
    esac
    test -f "$D/$rel" && test ! -L "$D/$rel"
    test ! -e "$D/$rel.refresh-20261006"
    cp -p "$D/$rel" "$W/original/$name"
    /usr/bin/digest -a sha256 "$W/original/$name"
done
cat > "$W/staged/index.html" <<'YB_DISCOVERY_PAYLOAD_0'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>e-yearbook.com — For AI Agents</title>
<meta name="description" content="Connect your AI agent to e-yearbook.com via MCP. Search over 300,000 U.S. yearbooks programmatically.">
<link rel="alternate" type="text/markdown" href="/llms.txt">
<link rel="describedby" type="application/json" href="/.well-known/mcp.json">
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
         max-width: 820px; margin: 2em auto; padding: 0 1em; line-height: 1.6;
         color: #222; background: #fff; }
  h1, h2, h3 { line-height: 1.25; }
  h1 { margin-bottom: 0.2em; }
  .lede { color: #555; font-size: 1.05em; margin-top: 0; }
  code, pre { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; }
  pre { background: #f5f5f7; padding: 1em; border-radius: 6px; overflow-x: auto;
        border: 1px solid #e5e5ea; }
  code { background: #f5f5f7; padding: 1px 4px; border-radius: 3px; }
  pre code { background: transparent; padding: 0; }
  table { border-collapse: collapse; width: 100%; margin: 1em 0; }
  th, td { border: 1px solid #e5e5ea; padding: 0.5em 0.8em; text-align: left; }
  th { background: #f5f5f7; }
  a { color: #0366d6; }
  .pill { display: inline-block; padding: 2px 8px; border-radius: 10px;
          font-size: 0.85em; background: #eaf2fc; color: #0366d6; }
  .pill.paid { background: #fdf6e3; color: #735c0f; }
  footer { margin-top: 3em; padding-top: 1em; border-top: 1px solid #e5e5ea;
           color: #777; font-size: 0.9em; }
</style>
</head>
<body>

<div id="payment-success-banner" style="display:none; background:#e6f4ea;
     border:1px solid #b7dfc2; color:#1e5631; padding:0.85em 1em;
     border-radius:6px; margin-bottom:1.5em;">
  <strong>Returned from Checkout.</strong>
  Payment and entitlement confirmation may take a few seconds. For a summary
  bundle, retry <code>get_person_summary</code> with the same lead; it returns
  the private <code>bundle_token</code> for people 2–10. For an exact-image
  purchase, the integration requests a fresh link with
  <code>POST /access/image/link</code>. This page does not confirm payment.
</div>
<script>
  // ?payment=success only means the browser returned from Checkout -- NOT a
  // confirmed entitlement (the webhook confirms that asynchronously). Show a
  // pending note; never assert the payment/entitlement is confirmed.
  if (new URLSearchParams(window.location.search).get('payment') === 'success') {
    var b = document.getElementById('payment-success-banner');
    if (b) b.style.display = 'block';
  }
</script>

<h1>For AI Agents</h1>
<div style="background:#fff4e5; border:1px solid #f0c890; color:#7a4a00;
     padding:0.85em 1em; border-radius:6px; margin-bottom:1.5em;">
  <strong>Free archive search. Two distinct paid products.</strong>
  Summary bundles cover up to 10 unique people for $1.99 over 24 hours, without
  images. The separate exact-image API offers one verified page for $1.99 with
  30 days of hosted re-access, currently limited to released Berkeley 1921
  occurrences. Availability is checked before checkout.
</div>
<p class="lede">
  Connect any MCP-aware agent to the e-yearbook.com yearbook archive.
  Free preview finds possible matches without confirming a person's school or
  exact year. The MCP endpoint is unchanged: <code>https://mcp.digitaldataonline.com/mcp</code>.
</p>

<h2>Quick start</h2>

<p>Copy the snippet for your client. The token below is the
   <strong>public-free</strong> bearer: 60 requests/minute,
   <code>free.search</code> scope, 200 unique (name, state, decade)
   combinations per day. No registration needed for this tier.</p>

<p style="background:#eaf2fc; padding:0.75em 1em; border-radius:6px; font-size:0.9em;">
  <strong>Public bearer token</strong> (paste-and-go):<br>
  <code style="user-select:all;">yb_neeQ2Px-Cm_rWl1H9wH07WbuFgTmrSqUPab1_N1nK_k</code>
</p>

<p>For higher rate limits or paid-tier scope, see
   <a href="#contact">Contact</a> below.</p>

<h3>Claude Desktop</h3>
<p>Add to <code>~/Library/Application Support/Claude/claude_desktop_config.json</code>
   (macOS) or <code>%APPDATA%\Claude\claude_desktop_config.json</code> (Windows):</p>
<pre><code>{
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
}</code></pre>

<h3>Claude Code / curl</h3>
<pre><code>curl -X POST https://mcp.digitaldataonline.com/mcp \
  -H "Authorization: Bearer yb_neeQ2Px-Cm_rWl1H9wH07WbuFgTmrSqUPab1_N1nK_k" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{
    "jsonrpc":"2.0","id":1,"method":"initialize",
    "params":{
      "protocolVersion":"2025-06-18",
      "capabilities":{},
      "clientInfo":{"name":"my-agent","version":"1.0"}
    }
  }'</code></pre>

<h3>Cursor</h3>
<p>Add to <code>.cursor/mcp.json</code> in your project:</p>
<pre><code>{
  "mcpServers": {
    "e-yearbook": {
      "url": "https://mcp.digitaldataonline.com/mcp",
      "headers": { "Authorization": "Bearer yb_neeQ2Px-Cm_rWl1H9wH07WbuFgTmrSqUPab1_N1nK_k" }
    }
  }
}</code></pre>

<h3>Continue (VS Code)</h3>
<p>Add to <code>~/.continue/config.json</code> under <code>mcpServers</code>:</p>
<pre><code>{
  "name": "e-yearbook",
  "url": "https://mcp.digitaldataonline.com/mcp",
  "headers": { "Authorization": "Bearer yb_neeQ2Px-Cm_rWl1H9wH07WbuFgTmrSqUPab1_N1nK_k" }
}</code></pre>

<h3>OpenAI Responses API (search / fetch)</h3>
<p>The MCP exposes <code>search</code> and <code>fetch</code> tools that are
   shape-compatible with OpenAI's deep-research connectors.</p>
<pre><code>curl https://api.openai.com/v1/responses \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-5",
    "tools": [{
      "type": "mcp",
      "server_url": "https://mcp.digitaldataonline.com/mcp",
      "server_label": "e-yearbook",
      "headers": {
        "Authorization": "Bearer yb_neeQ2Px-Cm_rWl1H9wH07WbuFgTmrSqUPab1_N1nK_k"
      }
    }],
    "input": "Find John Smith in Utah yearbooks from the 1950s"
  }'</code></pre>

<h2>Tool reference</h2>

<table>
<thead><tr><th>Tool</th><th>Tier</th><th>What it does</th></tr></thead>
<tbody>
<tr><td><code>health_check</code></td><td><span class="pill">free</span></td><td>Connection diagnostics.</td></tr>
<tr><td><code>search</code></td><td><span class="pill">free</span></td>
    <td>OpenAI-compatible discovery; routes by detected kind (person / yearbook / school).</td></tr>
<tr><td><code>fetch</code></td><td><span class="pill">free</span></td>
    <td>OpenAI-compatible citation-safe metadata for an <code>id</code>.</td></tr>
<tr><td><code>search_people_preview</code></td><td><span class="pill">free</span></td>
    <td>Name search; returns coarsened region + decade + confidence band. Does NOT confirm school or exact year.</td></tr>
<tr><td><code>search_yearbooks_by_school</code></td><td><span class="pill">free</span></td>
    <td>Catalog discovery — find all volumes for a school.</td></tr>
<tr><td><code>find_yearbook_volume</code></td><td><span class="pill">free</span></td>
    <td>Single yearbook lookup by school + year.</td></tr>
<tr><td><code>list_available_years</code></td><td><span class="pill">free</span></td>
    <td>Coverage check — what years do we have for this school.</td></tr>
<tr><td><code>get_school_collection</code></td><td><span class="pill">free</span></td>
    <td>School record + every yearbook we have for it.</td></tr>
<tr><td><code>get_yearbook_metadata</code></td><td><span class="pill">free</span></td>
    <td>Single yearbook metadata lookup.</td></tr>
<tr><td><code>request_missing_yearbook</code></td><td><span class="pill">free</span></td>
    <td>Submit a request when we don't have the yearbook your user wants.</td></tr>
<tr><td><code>get_person_summary</code></td><td><span class="pill paid">paid</span></td>
    <td>Person detail via a $1.99 summary bundle: up to 10 unique people over 24 hours. Uses a private <code>bundle_token</code>; images are not included. A paused checkout returns <code>image_delivery_pending</code>, not a purchase link.</td></tr>
<tr><td><code>get_yearbook_report</code></td><td><span class="pill paid">paid</span></td>
    <td>Full enriched yearbook profile — organizations, activities, classmates. Separate e-yearbook subscription (not the person-summary product).</td></tr>
</tbody>
</table>

<h2>Free previews vs summary and report access</h2>

<table>
<thead><tr><th>Field</th><th>Free</th><th>Paid</th></tr></thead>
<tbody>
<tr><td>Matched query name (echoed)</td><td>✅</td><td>✅</td></tr>
<tr><td>Coarsened region + decade</td><td>✅</td><td>✅</td></tr>
<tr><td>Confidence band</td><td>✅</td><td>✅</td></tr>
<tr><td>Canonical name (DB-normalized)</td><td>—</td><td>✅</td></tr>
<tr><td>School name</td><td>—</td><td>✅</td></tr>
<tr><td>Exact year + yearbook title</td><td>—</td><td>✅</td></tr>
<tr><td>Page numbers / scan links</td><td>—</td><td>— (unavailable unless the book is verified and the feature is enabled)</td></tr>
<tr><td>Classmates</td><td>—</td><td>Where available in a separately authorized yearbook report</td></tr>
<tr><td>Deep scan URL</td><td>—</td><td>Separate product; not included</td></tr>
</tbody>
</table>

<p>The summary bundle (<code>person_bundle_10_v1</code>) costs $1.99 for up to
   10 unique people over 24 hours. Re-viewing a claimed person is free until
   expiry. Page and scan delivery are not included. Existing live entitlements
   remain usable when new checkout is paused. A yearbook report is a separate
   subscription product; neither product implies archive-wide image access.</p>

<h2 id="exact-images">Exact page images — separate integration API</h2>
<p><code>occurrence_image_v3</code> costs $1.99 for one verified exact page image,
   with 30 days of hosted re-access from successful payment. Current coverage is
   released, verified occurrences in <strong>University of California Berkeley
   1921</strong>, not every page in that book or every search result.</p>
<p>On the MCP host, <code>POST /payments/checkout/image</code> creates or reuses
   checkout; <code>POST /access/image/link</code> obtains a fresh link after
   payment. Both accept a JSON body with <code>lead_id</code> and
   <code>occurrence</code> (the verified release's occurrence digest, not a page
   number). Keep these credentials in the body, never in these route URLs.</p>
<p><strong>Integration limit:</strong> current public MCP search does not supply
   that occurrence digest, and there is no public MCP image-checkout tool.
   Integrations need a provisioned occurrence mapping. Do not guess a digest
   or buy a summary bundle expecting an image. Contact us for integration help.</p>
<p>Image URLs expire in 5 minutes; the purchase's hosted access lasts 30 days.
   These are bearer links: anyone holding a valid link can open the image.
   Keep links private. Refund or revocation stops access. Checkout can refuse
   an unavailable image before contacting Stripe; a checkout return page is
   never proof of payment.</p>

<h2>Example queries</h2>

<ul>
<li>"Find my grandfather's high school yearbook"</li>
<li>"Search old yearbooks by name"</li>
<li>"Find John Smith in Utah yearbooks from the 1950s"</li>
<li>"Old classmates lookup for class reunion"</li>
<li>"Military cruise book 1968"</li>
<li>"What years does Beverly Hills High School have available?"</li>
</ul>

<h2>Citation format</h2>

<p>When you surface results to a user, include the <code>e_yearbook_landing_url</code>
   returned in each result. Example:</p>

<blockquote>
  We found a potential match for <em>John Smith</em> in the West region in the 1970s
  (medium confidence). See: <a href="#">https://www.e-yearbook.com/yearbook-search/result?lead_id=ld_xxxx&amp;utm_source=mcp</a>.
  Verify the exact school and year on e-yearbook.com.
</blockquote>

<p>Please don't paraphrase the result without the citation link — users
   can verify and unlock the full record from there.</p>

<h2>Rate limits and abuse policy</h2>

<ul>
<li><strong>Per-token rate limit:</strong> 60 requests/minute (default; can be raised on request).</li>
<li><strong>Privacy budget:</strong> 200 unique (name, state, decade) combinations per token per day. Resets midnight UTC.</li>
<li><strong>Filter-confirm protection:</strong> Free-tier requests that combine name + school + exact year return a
    <code>verification_required</code> envelope; the warehouse is never queried.
    This prevents agents from confirming identity via cross-referencing.</li>
<li><strong>Recent-year suppression:</strong> Free-tier person searches in yearbooks ≤20 years old are suppressed.</li>
<li><strong>Cloudflare edge rate limit:</strong> 30 requests/10 seconds per IP. Hosted agents typically far below this.</li>
</ul>

<h2>Privacy and opt-out</h2>

<p>People appearing in our archive can request removal at
   <a href="/sp/terms?privacy=1">/sp/terms?privacy=1</a>.
   Honored opt-outs are suppressed at all tiers (free and paid).</p>

<h2 id="contact">Contact</h2>

<ul>
<li>Higher-tier token request (faster rate limit, paid scope):
    <a href="https://github.com/bryanmichael-hue/yearbook-mcp-public/issues/new?labels=token-request&amp;title=Token+request">open a GitHub Issue</a></li>
<li>Partnerships / agent platform integration:
    <a href="https://github.com/bryanmichael-hue/yearbook-mcp-public/issues/new?labels=partnership&amp;title=Partnership+request">open a GitHub Issue</a></li>
<li>Bug reports / questions:
    <a href="https://github.com/bryanmichael-hue/yearbook-mcp-public/issues">github.com/bryanmichael-hue/yearbook-mcp-public/issues</a></li>
<li>Machine descriptor: <a href="/.well-known/mcp.json">/.well-known/mcp.json</a></li>
<li>Discovery file: <a href="/llms.txt">/llms.txt</a></li>
</ul>

<footer>
  <p>Free discovery, summary bundles, and limited exact-image delivery are distinct.
     Honor live availability and privacy refusals. Product documentation refreshed
     October 6, 2026; the public MCP endpoint has not changed.</p>
</footer>

</body>
</html>
YB_DISCOVERY_PAYLOAD_0
test "$(/usr/bin/digest -a sha256 "$W/staged/index.html")" = "fb40aad56b86d865737f54f10571a13b1ecf74f6559d76120341aaa5c9ee5b80"
cat > "$W/staged/mcp.json" <<'YB_DISCOVERY_PAYLOAD_1'
{
  "name": "e-yearbook.com",
  "version": "1.3.0",
  "description": "Search over 300,000 U.S. yearbooks (high school / college / military) from the 1850s to present. Free, privacy-limited previews; $1.99 10-person summary bundles (24 hours, no images). Separate $1.99 exact page-image HTTP API with 30-day hosted re-access for verified Berkeley 1921 occurrences only. Image checkout is not a public MCP tool.",
  "endpoint": "https://mcp.digitaldataonline.com/mcp",
  "transport": "streamable-http",
  "auth": {
    "bearer": {
      "register": "https://www.e-yearbook.com/for-ai-agents"
    }
  },
  "tools": [
    "health_check",
    "search",
    "fetch",
    "search_people_preview",
    "search_yearbooks_by_school",
    "find_yearbook_volume",
    "list_available_years",
    "get_school_collection",
    "get_yearbook_metadata",
    "request_missing_yearbook",
    "get_person_summary",
    "get_yearbook_report"
  ],
  "data_policy": {
    "free_tier_disclosure": "matched query name + coarsened region + coarsened decade + confidence band",
    "paid_tier_unlock": "get_person_summary offers the summary bundle when checkout is enabled; it does not purchase an image. get_yearbook_report uses separate subscription access. Exact images use the separate HTTP API below. Honor live refusals; never infer payment success from a return URL.",
    "person_bundle_terms": {
      "offer_code": "person_bundle_10_v1",
      "applies_to": "get_person_summary",
      "availability": "subject_to_live_checkout_gate",
      "price_usd": 1.99,
      "people_limit": 10,
      "duration": "24h",
      "replays_free": true,
      "scan_access_included": false,
      "page_delivery_included": false
    },
    "exact_image_terms": {
      "product_code": "occurrence_image_v3",
      "price_usd": 1.99,
      "purchase_unit": "one verified occurrence's exact page image",
      "hosted_access_days": 30,
      "access_starts": "successful_payment",
      "delivery_token_ttl_seconds": 300,
      "authorization": "bearer; anyone holding a valid link can use it",
      "coverage": [
        "CA_UniversityofCaliforniaBerkeley_1921"
      ],
      "availability": "released_available_occurrences_only; subject_to_live_gates",
      "checkout": {
        "method": "POST",
        "path": "/payments/checkout/image"
      },
      "reaccess": {
        "method": "POST",
        "path": "/access/image/link"
      },
      "body_fields": [
        "lead_id",
        "occurrence"
      ],
      "occurrence_format": "verified release occurrence digest, not a page number",
      "discovery_limit": "Current public MCP search does not supply the image occurrence digest. Integrations need a provisioned occurrence mapping; do not invent one.",
      "credential_handling": "POST JSON body; never put lead_id in these route URLs",
      "included_in_summary_bundle": false
    },
    "training_use": "prohibited",
    "opt_out": "https://www.e-yearbook.com/sp/terms?privacy=1",
    "opt_out_contact": "mailto:support@digitaldataonline.com",
    "citation_policy": "Surface the e-yearbook landing URL returned by fetch(id) when presenting results to users."
  },
  "registries": [
    {
      "name": "Official MCP Registry",
      "url": "https://registry.modelcontextprotocol.io/"
    }
  ],
  "support": "https://www.e-yearbook.com/for-ai-agents",
  "issues": "https://github.com/bryanmichael-hue/yearbook-mcp-public/issues",
  "source_repo": "https://github.com/bryanmichael-hue/yearbook-mcp-public"
}
YB_DISCOVERY_PAYLOAD_1
test "$(/usr/bin/digest -a sha256 "$W/staged/mcp.json")" = "0255e1bf26848cfe9cdde46a1da24ac9337f79345dffc51eb526c2db14eaa570"
cat > "$W/staged/mcp-server" <<'YB_DISCOVERY_PAYLOAD_2'
{
  "name": "e-yearbook.com",
  "version": "1.3.0",
  "description": "Search over 300,000 U.S. yearbooks (high school / college / military) from the 1850s to present. Free, privacy-limited previews; $1.99 10-person summary bundles (24 hours, no images). Separate $1.99 exact page-image HTTP API with 30-day hosted re-access for verified Berkeley 1921 occurrences only. Image checkout is not a public MCP tool.",
  "endpoint": "https://mcp.digitaldataonline.com/mcp",
  "transport": "streamable-http",
  "auth": {
    "bearer": {
      "register": "https://www.e-yearbook.com/for-ai-agents"
    }
  },
  "tools": [
    "health_check",
    "search",
    "fetch",
    "search_people_preview",
    "search_yearbooks_by_school",
    "find_yearbook_volume",
    "list_available_years",
    "get_school_collection",
    "get_yearbook_metadata",
    "request_missing_yearbook",
    "get_person_summary",
    "get_yearbook_report"
  ],
  "data_policy": {
    "free_tier_disclosure": "matched query name + coarsened region + coarsened decade + confidence band",
    "paid_tier_unlock": "get_person_summary offers the summary bundle when checkout is enabled; it does not purchase an image. get_yearbook_report uses separate subscription access. Exact images use the separate HTTP API below. Honor live refusals; never infer payment success from a return URL.",
    "person_bundle_terms": {
      "offer_code": "person_bundle_10_v1",
      "applies_to": "get_person_summary",
      "availability": "subject_to_live_checkout_gate",
      "price_usd": 1.99,
      "people_limit": 10,
      "duration": "24h",
      "replays_free": true,
      "scan_access_included": false,
      "page_delivery_included": false
    },
    "exact_image_terms": {
      "product_code": "occurrence_image_v3",
      "price_usd": 1.99,
      "purchase_unit": "one verified occurrence's exact page image",
      "hosted_access_days": 30,
      "access_starts": "successful_payment",
      "delivery_token_ttl_seconds": 300,
      "authorization": "bearer; anyone holding a valid link can use it",
      "coverage": [
        "CA_UniversityofCaliforniaBerkeley_1921"
      ],
      "availability": "released_available_occurrences_only; subject_to_live_gates",
      "checkout": {
        "method": "POST",
        "path": "/payments/checkout/image"
      },
      "reaccess": {
        "method": "POST",
        "path": "/access/image/link"
      },
      "body_fields": [
        "lead_id",
        "occurrence"
      ],
      "occurrence_format": "verified release occurrence digest, not a page number",
      "discovery_limit": "Current public MCP search does not supply the image occurrence digest. Integrations need a provisioned occurrence mapping; do not invent one.",
      "credential_handling": "POST JSON body; never put lead_id in these route URLs",
      "included_in_summary_bundle": false
    },
    "training_use": "prohibited",
    "opt_out": "https://www.e-yearbook.com/sp/terms?privacy=1",
    "opt_out_contact": "mailto:support@digitaldataonline.com",
    "citation_policy": "Surface the e-yearbook landing URL returned by fetch(id) when presenting results to users."
  },
  "registries": [
    {
      "name": "Official MCP Registry",
      "url": "https://registry.modelcontextprotocol.io/"
    }
  ],
  "support": "https://www.e-yearbook.com/for-ai-agents",
  "issues": "https://github.com/bryanmichael-hue/yearbook-mcp-public/issues",
  "source_repo": "https://github.com/bryanmichael-hue/yearbook-mcp-public"
}
YB_DISCOVERY_PAYLOAD_2
test "$(/usr/bin/digest -a sha256 "$W/staged/mcp-server")" = "0255e1bf26848cfe9cdde46a1da24ac9337f79345dffc51eb526c2db14eaa570"
cat > "$W/staged/llms.txt" <<'YB_DISCOVERY_PAYLOAD_3'
# e-yearbook.com

> Search over 300,000 U.S. yearbooks and over 95 million searchable person mentions.
> Free privacy-limited previews; summary bundles and limited exact images are distinct products.

## MCP
- Endpoint: https://mcp.digitaldataonline.com/mcp (Streamable HTTP)
- Setup and public free bearer: https://www.e-yearbook.com/for-ai-agents/
- Descriptor: https://www.e-yearbook.com/.well-known/mcp.json
- Alternate descriptor: https://www.e-yearbook.com/.well-known/mcp-server
- MCP-host descriptor: https://mcp.digitaldataonline.com/.well-known/mcp.json
- Public docs: https://github.com/bryanmichael-hue/yearbook-mcp-public
- Official registry name: com.digitaldataonline.mcp/e-yearbook (0.5.0)

## Products and limits
**Summary bundle — `person_bundle_10_v1`:** $1.99 for up to 10 unique people
over 24 hours. `get_person_summary(lead_id)` returns an offer when checkout is
enabled; after confirmed payment, retry it and keep the private `bundle_token`
for additional people. Re-viewing claimed people is free until expiry. Images
are not included. During a checkout pause, honor `image_delivery_pending` and
`checkout_available: false`; existing live entitlements can still restore.

**Exact image — `occurrence_image_v3`:** a separate $1.99 purchase for one
verified exact page image, with 30 days of hosted re-access from successful
payment. Current coverage is released, verified University of California
Berkeley 1921 occurrences only—not every page or search result.

This is a separate HTTP integration, not a public MCP tool:

- `POST /payments/checkout/image`: create or reuse checkout.
- `POST /access/image/link`: obtain a fresh link after payment.
- Send `lead_id` and `occurrence` in a JSON body to the MCP host, not in these
  route URLs. The occurrence is a verified release digest, not a page number.
- **Current MCP search does not supply the image occurrence digest.** An
  integration needs a provisioned occurrence mapping; never invent one or buy
  a summary bundle expecting an image. Contact support for integration help.
- Image links are 5-minute bearer capabilities: anyone holding a valid link
  can use it. Keep them private. The hosted entitlement lasts 30 days; refunds
  and revocation stop access. A return from Checkout is not payment proof.

**Yearbook report:** `get_yearbook_report` uses separate subscription access.
No product here promises archive-wide scans. Always honor the live response;
ask the user before initiating a purchase.

## Privacy and citation
Free person previews do not confirm school, exact year or canonical name.
Always include the returned e-yearbook citation URL. Never publish private
lead, bundle or image-link capabilities. Yearbooks 20 years old or newer
are suppressed in free person search. Training use of scans is prohibited.
Privacy: https://www.e-yearbook.com/sp/terms?privacy=1
Opt-out and integration help: support@digitaldataonline.com

Updated: 2026-10-06. Honor live refusals; static documentation is not checkout authorization.
YB_DISCOVERY_PAYLOAD_3
test "$(/usr/bin/digest -a sha256 "$W/staged/llms.txt")" = "7383c147044d1522df99554d7d74fd6f63797d45b6db09cc195e76913f4791a9"
rollback() {
    trap - EXIT HUP INT TERM
    for name in index.html mcp.json mcp-server llms.txt; do
        case "$name" in
            index.html) rel=for-ai-agents/index.html ;;
            mcp.json|mcp-server) rel=.well-known/$name ;;
            llms.txt) rel=llms.txt ;;
        esac
        cp -p "$W/original/$name" "$D/$rel.refresh-20261006"
        mv -f "$D/$rel.refresh-20261006" "$D/$rel"
    done
    echo "FAILED: originals restored; preserve $W for inspection."
    exit 1
}
trap rollback EXIT HUP INT TERM
for name in index.html mcp.json mcp-server llms.txt; do
    case "$name" in
        index.html) rel=for-ai-agents/index.html ;;
        mcp.json|mcp-server) rel=.well-known/$name ;;
        llms.txt) rel=llms.txt ;;
    esac
    cp "$W/staged/$name" "$D/$rel.refresh-20261006"
    chown root:root "$D/$rel.refresh-20261006"
    chmod 0444 "$D/$rel.refresh-20261006"
    mv -f "$D/$rel.refresh-20261006" "$D/$rel"
done
test "$(/usr/bin/digest -a sha256 "$D/for-ai-agents/index.html")" = "fb40aad56b86d865737f54f10571a13b1ecf74f6559d76120341aaa5c9ee5b80"
test "$(/usr/bin/digest -a sha256 "$D/.well-known/mcp.json")" = "0255e1bf26848cfe9cdde46a1da24ac9337f79345dffc51eb526c2db14eaa570"
test "$(/usr/bin/digest -a sha256 "$D/.well-known/mcp-server")" = "0255e1bf26848cfe9cdde46a1da24ac9337f79345dffc51eb526c2db14eaa570"
test "$(/usr/bin/digest -a sha256 "$D/llms.txt")" = "7383c147044d1522df99554d7d74fd6f63797d45b6db09cc195e76913f4791a9"
cmp "$D/.well-known/mcp.json" "$D/.well-known/mcp-server"
trap - EXIT HUP INT TERM
echo "UNO_DISCOVERY_REFRESH_OK; four files verified. Originals: $W/original"
echo "No Apache configuration, ecommerce files, Stripe settings or services changed."
