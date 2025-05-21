#!/bin/bash

print_usage() {
  echo "Usage:"
  echo "  $0 -u <single_api_key>"
  echo "  $0 -l <file_with_api_keys>"
  exit 1
}

if [[ $# -eq 0 ]]; then
  print_usage
fi

single_key=""
file_keys=""

while getopts "u:l:" opt; do
  case $opt in
    u) single_key="$OPTARG" ;;
    l) file_keys="$OPTARG" ;;
    *) print_usage ;;
  esac
done

if [[ -z "$single_key" && -z "$file_keys" ]]; then
  echo "Error: You must provide either a single API key (-u) or a file with keys (-l)."
  exit 1
fi

# Print color legend
echo -e "\n\033[0;32mGreen:\033[0m Valid key (200)"
echo -e "\033[1;33mYellow:\033[0m Forbidden (403)\n"

# Endpoint definitions: type|url
endpoints=(
  "GET|https://maps.googleapis.com/maps/api/staticmap?center=45%2C10&zoom=7&size=400x400&key="
  "GET|https://maps.googleapis.com/maps/api/streetview?size=400x400&location=40.720032,-73.988354&fov=90&heading=235&pitch=10&key="
  "GET|https://www.google.com/maps/embed/v1/place?q=place_id:ChIJyX7muQw8tokR2Vf5WBBk1iQ&key="
  "GET|https://maps.googleapis.com/maps/api/directions/json?origin=Disneyland&destination=Universal+Studios+Hollywood4&key="
  "GET|https://maps.googleapis.com/maps/api/geocode/json?latlng=40,30&key="
  "GET|https://maps.googleapis.com/maps/api/distancematrix/json?units=imperial&origins=40.6655101,-73.89188969999998&destinations=40.6905615%2C"
  "GET|https://maps.googleapis.com/maps/api/place/findplacefromtext/json?input=Museum%20of%20Contemporary%20Art%20Australia&inputtype=textquer"
  "GET|https://maps.googleapis.com/maps/api/place/autocomplete/json?input=Bingh&types=%28cities%29&key="
  "GET|https://maps.googleapis.com/maps/api/elevation/json?locations=39.7391536,-104.9847034&key="
  "GET|https://maps.googleapis.com/maps/api/timezone/json?location=39.6034810,-119.6822510&timestamp=1331161200&key="
  "GET|https://roads.googleapis.com/v1/nearestRoads?points=60.170880,24.942795|60.170879,24.942796|60.170877,24.942796&key="
  "GET|https://www.googleapis.com/geolocation/v1/geolocate?key="
  "POST|https://maps.googleapis.com/maps/api/staticmap?center=45%2C10&zoom=7&size=400x400&key="
  "POST|https://maps.googleapis.com/maps/api/streetview?size=400x400&location=40.720032,-73.988354&fov=90&heading=235&pitch=10&key="
  "POST|https://www.google.com/maps/embed/v1/place?q=place_id:ChIJyX7muQw8tokR2Vf5WBBk1iQ&key="
  "POST|https://maps.googleapis.com/maps/api/directions/json?origin=Disneyland&destination=Universal+Studios+Hollywood4&key="
  "POST|https://maps.googleapis.com/maps/api/geocode/json?latlng=40,30&key="
  "POST|https://maps.googleapis.com/maps/api/distancematrix/json?units=imperial&origins=40.6655101,-73.89188969999998&destinations=40.6905615%2C"
  "POST|https://maps.googleapis.com/maps/api/place/findplacefromtext/json?input=Museum%20of%20Contemporary%20Art%20Australia&inputtype=textquer"
  "POST|https://maps.googleapis.com/maps/api/place/autocomplete/json?input=Bingh&types=%28cities%29&key="
  "POST|https://maps.googleapis.com/maps/api/elevation/json?locations=39.7391536,-104.9847034&key="
  "POST|https://maps.googleapis.com/maps/api/timezone/json?location=39.6034810,-119.6822510&timestamp=1331161200&key="
  "POST|https://roads.googleapis.com/v1/nearestRoads?points=60.170880,24.942795|60.170879,24.942796|60.170877,24.942796&key="
  "POST|https://www.googleapis.com/geolocation/v1/geolocate?key="
)

get_post_body() {
  case "$1" in
    *vision.googleapis.com*) echo '{"requests":[{"image":{"content":""},"features":[{"type":"LABEL_DETECTION"}]}]}' ;;
    *speech.googleapis.com*) echo '{"config":{"encoding":"LINEAR16","languageCode":"en-US"},"audio":{"content":""}}' ;;
    *language.googleapis.com*) echo '{"document":{"type":"PLAIN_TEXT","content":"Hello world"},"encodingType":"UTF8"}' ;;
    *) echo '{}' ;;
  esac
}

extract_error_message() {
  local body="$1"
  if command -v jq >/dev/null 2>&1; then
    jq -r '
      if .error_message then .error_message
      elif .error and .error.message then .error.message
      elif .error and .error.status then .error.status
      elif .status then .status
      else empty end
    ' <<< "$body"
  else
    echo "$body" | grep -E '"error_message"|"status"|"message"'
  fi
}

check_key() {
  key=$1
  valid_found=0
  total=0
  valid=0
  errors=0
  echo -e "\n\033[1;36m================ Checking API Key: $key ================\033[0m"
  endpoint_count=${#endpoints[@]}
  idx=1
  for entry in "${endpoints[@]}"; do
    method="${entry%%|*}"
    endpoint="${entry#*|}"
    url="${endpoint}${key}"

    # Color codes
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m' # No Color

    # Curl with timeout
    if [[ "$method" == "POST" ]]; then
      body_data=$(get_post_body "$endpoint")
      response=$(curl -sS --max-time 10 -X POST -H "Content-Type: application/json" --data "$body_data" --write-out "HTTPSTATUS:%{http_code}" "$url")
    else
      response=$(curl -sS --max-time 10 --write-out "HTTPSTATUS:%{http_code}" "$url")
    fi

    http_status=$(echo "$response" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
    body=$(echo "$response" | sed -e 's/HTTPSTATUS\:.*//g')

    # Only show 200 and 403 responses
    if [[ $http_status -ne 200 && $http_status -ne 403 ]]; then
      ((idx++))
      continue
    fi

    # Hide responses containing "REQUEST_DENIED", "invalid", or "The provided API key is invalid."
    if echo "$body" | grep -q -iE 'REQUEST_DENIED|invalid|The provided API key is invalid.'; then
      ((idx++))
      continue
    fi

    ((total++))

    # Choose color
    if [[ $http_status -eq 200 ]]; then
      COLOR=$GREEN
      valid_found=1
      ((valid++))
    elif [[ $http_status -eq 403 ]]; then
      COLOR=$YELLOW
      ((errors++))
    fi

    # Print endpoint progress
    echo -e "[${idx}/${endpoint_count}] ${COLOR}$url"

    # Pretty-print JSON if possible
    if command -v jq >/dev/null 2>&1 && echo "$body" | jq . >/dev/null 2>&1; then
      echo "$body" | jq .
      echo -e "${NC}-----------------------------------------------------"
    else
      echo -e "$body${NC}"
      echo "-----------------------------------------------------"
    fi
    ((idx++))
  done

  # Save valid key if found
  if [[ $valid_found -eq 1 ]]; then
    if ! grep -Fxq "$key" valid_keys.txt 2>/dev/null; then
      echo "$key" >> valid_keys.txt
      echo -e "\033[0;32m[+] Saved valid key to valid_keys.txt\033[0m"
      # Critical banner
      echo -e "\n\033[41;97;1m==================== CRITICAL: VALID KEY FOUND! ====================\033[0m"
      echo -e "\033[41;97;1m==  API KEY: $key\033[0m"
      echo -e "\033[41;97;1m===================================================================\033[0m\n"
    fi
  fi

  # Print summary for this key
  echo -e "\033[1;36m[Summary for $key] Checked: $total, Valid: $valid, Forbidden: $errors\033[0m"
  echo -e "\033[1;36m================ Finished for API Key: $key ================\033[0m\n"
}

if [[ -n "$single_key" ]]; then
  check_key "$single_key"
elif [[ -n "$file_keys" ]]; then
  while IFS= read -r key; do
    [[ -z "$key" ]] && continue
    check_key "$key"
  done < "$file_keys"
fi

# Deduplicate valid_keys.txt at the end
if [[ -f valid_keys.txt ]]; then
  sort -u valid_keys.txt -o valid_keys.txt
fi
