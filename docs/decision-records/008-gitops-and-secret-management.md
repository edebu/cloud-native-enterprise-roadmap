# ADR 008: GitOps and Secret Management Integration

## Context & Problem Statement

Phase 2 kapsamında, `product-catalog-api` uygulamasını Docker ile konteynerleştirip Kubernetes manifestlerini hazırladık ve GCP Load Balancer (GKE Ingress) ile dış dünyaya açtık. Ancak:
1. Manifestler statik yapıdaydı ve ortamlar (dev/prod) arasında parametrik olarak özelleştirilemiyordu.
2. Deployment işlemi manuel `kubectl apply` komutları üzerinden yürütülüyordu; bu da Continuous Delivery (CD) standartlarına ve "Git as Single Source of Truth" ilkesine aykırıydı.
3. Database şifresi gibi hassas veriler (Secret) K8s manifest dosyalarında base64 ile statik olarak tutuluyordu; bu durum güvenlik riski oluşturuyordu.

Bu problemleri çözmek için parametrik paketleme (Helm), otomatik GitOps dağıtımı (ArgoCD) ve bulut entegrasyonlu secret yönetimi (External Secrets Operator) mimarisine geçilmesi kararlaştırılmıştır.

## Decision Drivers

- **Security (Güvenlik)**: Şifreler ve kimlik bilgileri kesinlikle Git deposuna commitlenmemeli, Secret Manager gibi güvenli kasa sistemlerinde tutulmalı ve least-privilege prensibine göre yönetilmelidir.
- **GitOps Pull Model**: Cluster durumu Git reposuyla otomatik olarak senkronize kalmalı, cluster üzerinde doğrudan manuel değişiklikler yapılmamalıdır (drift detection).
- **Maintainability (Bakım Kolaylığı)**: Farklı ortam konfigürasyonları şablonlarla (Helm) tek bir merkezden yönetilmelidir.

## Decisions

1. **Helm Chart Paketlemesi**:
   - `product-catalog-api` Kubernetes manifestleri bir Helm Chart yapısına dönüştürülmüştür.
   - İmaj tagleri, replica sayısı, kaynak sınırları ve veritabanı host bilgileri `values.yaml` üzerinden parametrik hale getirilmiştir.

2. **Terraform ile ArgoCD ve ESO Kurulumu**:
   - ArgoCD ve External Secrets Operator (ESO), altyapı bütünlüğünü korumak adına GKE Terraform state'i (`environments/dev/terraform/gke`) üzerinden Helm provider kullanılarak otomatik deploy edilmiştir.
   - GKE Autopilot mimarisinin ilk kurulumdaki node provisioning ve imaj çekme gecikmeleri nedeniyle, Terraform'daki Helm release zaman aşımı limitleri 15 dakikaya (`timeout = 900`) çıkarılmıştır.

3. **GCP Secret Manager & Workload Identity Entegrasyonu**:
   - GCP tarafında sadece Secret Manager'daki secret'ları okumaya yetkili `eso-secrets-sa` adında özel bir Google Service Account (GSA) oluşturulmuştur.
   - GSA, **Workload Identity** aracılığıyla ESO'nun Kubernetes Service Account'u (`external-secrets/external-secrets`) ile eşlenmiştir.
   - ESO KSA'i `iam.gke.io/gcp-service-account` annotation'ı ile etiketlenerek, ESO podlarının AWS/GCP credential dosyaları olmadan doğrudan GCP metadata sunucusu üzerinden yetki alması sağlanmıştır.

4. **External Secrets Operator Tanımları**:
   - ESO'nun GCP Secret Manager ile haberleşebilmesi için küme seviyesinde bir `ClusterSecretStore` tanımlanmıştır.
   - Uygulama düzeyinde tanımlanan bir `ExternalSecret` kaynağı yardımıyla, GCP Secret Manager'daki veritabanı şifresi (`cn-er-dev-db-password`) okunarak `cn-er-dev` namespace'inde otomatik olarak `product-catalog-api-secret` adında K8s secret'ı üretilmiştir.

5. **ArgoCD GitOps Entegrasyonu**:
   - Uygulamanın git deposundaki Helm chart'ı izleyen ve değişiklikleri otomatik olarak cluster'a uygulayan (`self-heal` ve `prune` aktif) bir ArgoCD `Application` kaynağı tanımlanmıştır.

## Consequences

- **Pros (Artıları)**:
  - **Sıfır Statik Secret**: Hassas veriler hiçbir şekilde kod depolarına veya manifestlere yansıtılmaz. Secret Manager güncellendiğinde, ESO secret'ı cluster'da otomatik yeniler.
  - **Güçlü Kimlik Doğrulama**: Workload Identity sayesinde cluster'a static GCP SA key JSON'ları yüklenmek zorunda kalınmaz. Yetkiler kısa süreli geçici tokenlar üzerinden yürütülür.
  - **Otomatik Dağıtım**: Kod veya manifestlerde yapılan her commit, ArgoCD tarafından anında algılanarak cluster'a yansıtılır.
- **Cons (Eksileri / Zorluklar)**:
  - **İlk Kurulum Gecikmesi**: GKE Autopilot üzerinde ilk kez node provision edilmesi ve platform podlarının ayağa kalkması 5-10 dakika sürebilir (Terraform timeout ayarıyla çözülmüştür).
  - **Selector Immutability**: Eski statik manifestlerden Helm şablonuna geçiş yapıldığında, deployment'ın `spec.selector` alanının değiştirilemez (immutable) olması nedeniyle eski deployment'ın cluster'dan manuel silinmesi gerekmiştir.
