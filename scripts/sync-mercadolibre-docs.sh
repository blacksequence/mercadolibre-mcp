#!/usr/bin/env bash
set -euo pipefail

: "${FIRECRAWL_API_KEY:?Set FIRECRAWL_API_KEY.}"

# Inputs. Each defaults to the value the recorded run used.
DOC_URL="${DOC_URL:-"https://developers.mercadolibre.com.mx/es_ar"}"

PROMPT="map API Docs: \"Recursos de la API\" section and \"Primeros pasos\" section.
scrap all URLs using \`.mesh-row__content\` as CSS Filter; output each in markdown format, Exclude the URLs of images embedded in the Markdown from the output"

# Schema
SCHEMA='{
  "type": "object",
  "properties": {
    "source": { "type": "string" },
    "source_url": { "type": "string" },
    "sections": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "name": { "type": "string" },
          "section_citation": { "type": "string" },
          "items": { "type": "array" }
        },
        "required": ["name", "section_citation", "items"]
      }
    }
  },
  "required": ["source", "source_url", "sections"]
}'

# Start Run
STARTED="$(
  jq -n \
    --arg prompt "$PROMPT" \
    --argjson schema "$SCHEMA" \
    --arg url "$DOC_URL" \
    '{ prompt: $prompt, urls: [$url], schema: $schema, effort: "high" }' \
  | curl -sS -X POST https://api.firecrawl.dev/v2/agent \
      -H "Authorization: Bearer $FIRECRAWL_API_KEY" \
      -H "Content-Type: application/json" \
      -d @-
)"

ID="$(printf '%s' "$STARTED" | jq -r '.id // empty')"
if [ -z "$ID" ]; then
  printf '%s\n' "$STARTED" >&2
  exit 1
fi

# Poll Result
while :; do
  RESULT="$(curl -sS https://api.firecrawl.dev/v2/agent/"$ID" \
    -H "Authorization: Bearer $FIRECRAWL_API_KEY")"
  case "$(printf '%s' "$RESULT" | jq -r '.status // "processing"')" in
    processing) sleep 5 ;;
    *) break ;;
  esac
done

# Extract and Validate
DATA="$(printf '%s' "$RESULT" | jq -e '.data')"
if [ -z "$DATA" ] || [ "$DATA" = "null" ]; then
    echo "No valid data returned" >&2
    exit 1
fi

# Simple validation
echo "$DATA" | jq -e '.source | length > 0' > /dev/null || { echo "Invalid source" >&2; exit 1; }
echo "$DATA" | jq -e '.source_url | length > 0' > /dev/null || { echo "Invalid source_url" >&2; exit 1; }
echo "$DATA" | jq -e '.sections | length > 0' > /dev/null || { echo "Invalid sections" >&2; exit 1; }

# Save
mkdir -p docs/sources
echo "$DATA" | jq '.' > docs/sources/mercadolibre-docs.json
echo "Snapshot saved successfully"
