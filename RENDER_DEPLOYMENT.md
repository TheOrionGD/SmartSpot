# SmartSpot - Render Deployment Guide

This guide provides step-by-step instructions for deploying the **SmartSpot Backend** to [Render](https://render.com) and connecting your **Flutter Client** (Mobile, Web, Desktop) to the live service.

---

## 📋 Render Blueprint Specification (`render.yaml`)

Below is the complete blueprint specification defined in [`render.yaml`](file:///o:/PROJECTS/College/smartspot/render.yaml):

```yaml
# Exported from Render on 2026-08-24T06:07:41Z
version: "1"
projects:
- name: College-Projects
  environments:
  - name: Production
    services:
    - type: web
      name: smartspot-backend
      runtime: node
      repo: https://github.com/TheOrionGD/SmartSpot
      plan: free
      envVars:
      - key: NODE_ENV
        value: production
      - key: PORT
        value: "10000"
      - key: JWT_SECRET
        generateValue: true
      - key: DB_FILE
        value: ./data/smartspot.json
      - key: BREVO_API_KEY
        sync: false
      - key: MAIL_FROM
        value: godfrey.cs23@krct.ac.in
      - key: MAIL_FROM_NAME
        value: SmartSpot
      - key: CORS_ORIGIN
        value: "*"
      region: oregon
      buildCommand: npm install
      startCommand: npm start
      healthCheckPath: /health
      autoDeployTrigger: commit
      rootDir: backend
```

---

## 🚀 Blueprint Deployment Steps

1. Log into your **[Render Dashboard](https://dashboard.render.com)**.
2. Click **New +** $\rightarrow$ **Blueprint**.
3. Select the repository `https://github.com/TheOrionGD/SmartSpot`.
4. Render automatically parses [`render.yaml`](file:///o:/PROJECTS/College/smartspot/render.yaml).
5. Optionally fill in `BREVO_API_KEY` (for password reset emails) or leave blank, then click **Apply**.

---

## 📱 Connecting the Flutter App to Render Backend

Live Backend URL:
`https://smartspot-backend-55n9.onrender.com`

### Verification
Test the health check endpoint in your browser or terminal:
```bash
curl https://smartspot-backend-55n9.onrender.com/health
```

### Running & Building Flutter
*(The app now defaults to the live Render URL automatically!)*
```powershell
flutter run -d windows
flutter build web --release
```
