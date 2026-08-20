# M-Pesa STK + FCM setup

## M-Pesa (Daraja)
```bash
npx supabase secrets set MPESA_CONSUMER_KEY=... MPESA_CONSUMER_SECRET=... MPESA_PASSKEY=... MPESA_SHORTCODE=174379 MPESA_ENV=sandbox
npx supabase functions deploy mpesa-stk-push
npx supabase functions deploy mpesa-callback
```

## FCM
1. Firebase project + google-services.json
2. Add firebase_core + firebase_messaging
3. getToken → FcmService.registerToken
4. `npx supabase secrets set FCM_SERVER_KEY=...` && deploy send-fcm
