#!/bin/bash
# Check a deployed example serves the demo site and, for the examples with a
# backend, that the backend URL in config.json returns the expected message.
# Usage: ./test.sh s3|cf-s3|lambda|api-gateway|dynamodb
set -euo pipefail

EXAMPLE=${1:?usage: ./test.sh s3|cf-s3|lambda|api-gateway|dynamodb}
case "$EXAMPLE" in
  s3) STACK=S3Stack ;;
  cf-s3) STACK=CFS3Stack ;;
  lambda) STACK=LambdaStack ;;
  api-gateway) STACK=APIGatewayStack ;;
  dynamodb) STACK=DynamoDBStack ;;
  *) echo "Unknown example $EXAMPLE"; exit 1 ;;
esac

SITE_MARKER="AWS for Frontend Developers Demo Site"

output() {
  lstk aws cloudformation describe-stacks --stack-name "$STACK" \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text
}

# Print the body, or fail with the status and body when the status differs
expect_status() {
  local expected=$1 body status
  shift
  body=$(curl -s -m 30 -w '\n%{http_code}' "$@")
  status=${body##*$'\n'}
  body=${body%$'\n'*}
  if [ "$status" != "$expected" ]; then
    echo "Test failed: $* returned HTTP $status, expected $expected: $body" >&2
    return 1
  fi
  echo "$body"
}

if [ "$EXAMPLE" = s3 ]; then
  bucket=$(lstk aws cloudformation describe-stack-resources --stack-name "$STACK" \
    --query "StackResources[?ResourceType=='AWS::S3::Bucket'].PhysicalResourceId" --output text)
  SITE="http://$bucket.s3-website.localhost.localstack.cloud:4566"
else
  SITE="http://$(output CloudFrontDistributionURL):4566"
fi
echo "Site: $SITE"

if [[ "$(expect_status 200 "$SITE/")" != *"$SITE_MARKER"* ]]; then
  echo "Test failed: $SITE/ did not serve index.html"
  exit 1
fi
echo "PASS: the site serves index.html"

if [ "$EXAMPLE" = s3 ]; then
  if [[ "$(expect_status 404 "$SITE/missing-page")" != *"Something didn't work"* ]]; then
    echo "Test failed: a missing page did not serve error.html"
    exit 1
  fi
  echo "PASS: a missing page returns 404 with error.html"
fi

case "$EXAMPLE" in
  s3|cf-s3)
    echo "Test passed: $EXAMPLE serves the demo site"
    exit 0
    ;;
  lambda)
    URL=$(output LambdaFunctionURL)
    CONFIG_KEY=function_url
    EXPECTED="You successfully called the Lambda from a function URL!"
    ;;
  api-gateway)
    URL="$(output APIGatewayURL)hello"
    CONFIG_KEY=api_url
    EXPECTED="You successfully called the Lambda from API Gateway!"
    ;;
  dynamodb)
    URL="$(output APIGatewayURL)hello"
    CONFIG_KEY=api_url
    EXPECTED="You successfully received data from a DynamoDB table!"
    ;;
esac

config=$(expect_status 200 "$SITE/config.json")
configured=$(echo "$config" | jq -r ".$CONFIG_KEY")
if [ "$configured" = null ] || [ -z "$configured" ]; then
  echo "Test failed: config.json has no $CONFIG_KEY: $config"
  exit 1
fi
echo "PASS: config.json has $CONFIG_KEY $configured"

# check_backend <url>: the URL returns the expected message
check_backend() {
  local response
  response=$(expect_status 200 "$1") || return 1
  if ! echo "$response" | jq -e --arg m "$EXPECTED" '.message == $m' > /dev/null 2>&1; then
    echo "Test failed: $1 returned '$response', expected message '$EXPECTED'" >&2
    return 1
  fi
}

check_backend "$URL"
echo "PASS: the stack output URL $URL returned '$EXPECTED'"

# The site calls the configured URL, and for API Gateway falls back to the URL
# without the region segment (see site_assets/main.js)
site_url=$configured
[ "$CONFIG_KEY" = api_url ] && site_url="${configured}hello"
if check_backend "$site_url"; then
  echo "PASS: the URL the site loads from config.json returned the message"
elif [ "$CONFIG_KEY" = api_url ]; then
  fallback="$(echo "$configured" | awk -F. 'BEGIN {OFS="."} {$3=""; sub(/\.\./, "."); print}')hello"
  check_backend "$fallback"
  echo "PASS: the site's fallback URL $fallback returned the message"
else
  exit 1
fi

echo "Test passed: $EXAMPLE serves the demo site and its backend responds"
