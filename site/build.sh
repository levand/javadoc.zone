#!/bin/bash
cd "$(dirname "$0")"

rm -rf .build

node build.js
cp -r css .build/css

mkdir -p ../lambdas/templates/partial
handlebars templates/results.html -f ../lambdas/templates/results.js
handlebars templates/added.html -f ../lambdas/templates/added.js
handlebars templates/error.html -f ../lambdas/templates/error.js
handlebars templates/partial/head.html -f ../lambdas/templates/partial/head.js
handlebars templates/partial/footer.html -f ../lambdas/templates/partial/footer.js
