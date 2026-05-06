#!/usr/bin/env bash
# Submit URLs to IndexNow (Bing, Yandex, Seznam, Naver, DuckDuckGo via Bing).
# Google does not support IndexNow as of 2026 — use Search Console for Google.
#
# Usage:
#   ./scripts/indexnow.sh                  # submit every URL in sitemap.xml
#   ./scripts/indexnow.sh /vs/foo/         # submit one path
#   ./scripts/indexnow.sh https://...      # submit one absolute URL

set -euo pipefail

HOST="barnhub.online"
KEY="244a6082d8f9edfc0550b7f654acfe4b"
KEY_LOCATION="https://${HOST}/${KEY}.txt"
ENDPOINT="https://api.indexnow.org/indexnow"

cd "$(dirname "$0")/.."

# Build the URL list
urls=()
if [[ $# -gt 0 ]]; then
    for arg in "$@"; do
        if [[ "$arg" == http* ]]; then
            urls+=("$arg")
        else
            urls+=("https://${HOST}${arg}")
        fi
    done
else
    # Pull every <loc> from sitemap.xml
    while IFS= read -r u; do urls+=("$u"); done < <(
        grep -oE '<loc>[^<]+</loc>' sitemap.xml | sed -E 's:</?loc>::g'
    )
fi

if [[ ${#urls[@]} -eq 0 ]]; then
    echo "no URLs to submit" >&2
    exit 1
fi

# Build JSON payload (urlList: ["url1","url2",...])
url_json=$(printf '"%s",' "${urls[@]}")
url_json="[${url_json%,}]"

payload=$(cat <<JSON
{"host":"${HOST}","key":"${KEY}","keyLocation":"${KEY_LOCATION}","urlList":${url_json}}
JSON
)

echo "Submitting ${#urls[@]} URL(s) to IndexNow…"
http_code=$(curl -sS -o /tmp/indexnow.body -w '%{http_code}' \
    -X POST "$ENDPOINT" \
    -H 'Content-Type: application/json; charset=utf-8' \
    --data "$payload")

case "$http_code" in
    200) echo "✓ accepted (200)" ;;
    202) echo "✓ received, key verification pending (202) — first call only" ;;
    *)   echo "✗ failed (HTTP $http_code)"; cat /tmp/indexnow.body; exit 1 ;;
esac
