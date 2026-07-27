# 1. Service Account Oluşturulması
resource "google_service_account" "sa" {
  account_id   = var.service_account_id
  display_name = var.display_name
  project      = var.project_id
}

# 2. Least Privilege IAM Binding (Örn: Sadece Storage Object Viewer ve Log Writer rolleri)
resource "google_project_iam_member" "sa_storage_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.sa.email}"
}

resource "google_project_iam_member" "sa_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.sa.email}"
}