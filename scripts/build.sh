#!/bin/bash

set -euo pipefail

sass themes/lightspeed/raw-assets/style.scss > themes/lightspeed/assets/style.css
poetry run statik
