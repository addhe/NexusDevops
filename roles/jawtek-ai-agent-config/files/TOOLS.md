# TOOLS.md - JawTek AI Agent

## Cloud Run Management

### Service Operations
```bash
# Check service status
gcloud run services describe jawtekid-digital-transformation-products \
  --region=us-west1 --project=awanmasterpiece

# List revisions
gcloud run revisions list \
  --service=jawtekid-digital-transformation-products \
  --region=us-west1 --project=awanmasterpiece

# View service logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=jawtekid-digital-transformation-products" \
  --limit=50 --project=awanmasterpiece --format=json

# Update service (e.g., scaling)
gcloud run services update jawtekid-digital-transformation-products \
  --region=us-west1 --project=awanmasterpiece \
  --min-instances=1 --max-instances=5
```

### Traffic Management
```bash
# View traffic splits
gcloud run services describe jawtekid-digital-transformation-products \
  --region=us-west1 --project=awanmasterpiece \
  --format='value(status.traffic)'

# Update traffic split
gcloud run services update-traffic jawtekid-digital-transformation-products \
  --region=us-west1 --project=awanmasterpiece \
  --to-revisions=REVISION_NAME=100
```

### Deployment
```bash
# Deploy new revision
gcloud run deploy jawtekid-digital-transformation-products \
  --region=us-west1 --project=awanmasterpiece \
  --image=gcr.io/awanmasterpiece/IMAGE:TAG

# Rollback to previous revision
gcloud run services update-traffic jawtekid-digital-transformation-products \
  --region=us-west1 --project=awanmasterpiece \
  --to-revisions=PREVIOUS_REVISION=100
```

## Service URL

https://jawtekid-digital-transformation-products-361046956504.us-west1.run.app

---

**Owner:** Om Awan (@BroAwn, ID: 319535690)
**Service:** jawtekid-digital-transformation-products
**Region:** us-west1