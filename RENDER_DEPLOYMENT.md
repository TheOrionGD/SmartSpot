# SmartSpot - Render Deployment Guide

This guide provides step-by-step instructions for deploying the **SmartSpot Backend** to [Render](https://render.com) and connecting your **Flutter Client** (Mobile, Web, Desktop) to the live service.

---

## 📋 Render Blueprint Specification (`render.yaml`)

Below is the updated Free-tier compliant blueprint export format defined in [`render.yaml`](file:///o:/PROJECTS/College/smartspot/render.yaml):

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
        sync: false
      - key: MAIL_FROM_NAME
        value: SmartSpot
      - key: CORS_ORIGIN
        sync: false
      region: oregon
      buildCommand: npm install
      startCommand: npm start
      healthCheckPath: /health
      autoDeployTrigger: commit
      rootDir: backend
```

> [!NOTE]
> Render does not allow attaching persistent disks (`disk:`) on Free Tier plans. If you upgrade to a paid Starter plan (`plan: starter`), you can re-attach a persistent disk (`sizeGB: 1`, `mountPath: /app/backend/data`).

---

## 🚀 Option A: Automated Blueprint Deployment (Recommended)

1. Log into your **[Render Dashboard](https://dashboard.render.com)**.
2. Click **New +** $\rightarrow$ **Blueprint**.
3. Select the repository `https://github.com/TheOrionGD/SmartSpot`.
4. Render will automatically detect [`render.yaml`](file:///o:/PROJECTS/College/smartspot/render.yaml) at the root of the repository.
5. Provide your values for `BREVO_API_KEY`, `MAIL_FROM`, and `CORS_ORIGIN` (or set `CORS_ORIGIN` to `*`).
6. Click **Apply**.

---

## 📱 Connecting the Flutter App to Render Backend

Once your backend is deployed, Render will provide a live URL such as:
`https://smartspot-backend.onrender.com`

### Verification
Test the health check endpoint in your browser or terminal:
```bash
curl https://smartspot-backend.onrender.com/health
```

### Running & Building Flutter with Live API URL
```powershell
flutter run -d windows --dart-define=API_BASE_URL=https://smartspot-backend.onrender.com
flutter build web --release --dart-define=API_BASE_URL=https://smartspot-backend.onrender.com
```
