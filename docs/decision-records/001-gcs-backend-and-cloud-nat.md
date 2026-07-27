# ADR 001: Remote GCS Backend ve Cloud NAT Tercihi

## Status
Accepted

## Context
Aşama 1 altyapı kurulumunda, Terraform state dosyalarının güvenliği, takım çalışmasına uygunluğu ve kilitlenme (state locking) mekanizmaları gereksinimi vardır. Ayrıca, özel ağdaki (private subnet) sunucuların dış dünya ile güvenli iletişim kurabilmesi ancak bastion host veya NAT çözümleri ile mümkündür.

## Decision
1. **Remote Backend:** Yerel `terraform.tfstate` kullanımı yerine Google Cloud Storage (GCS) bucket ve yerleşik nesne kilitleme (Object Locking) mekanizması seçilmiştir.
2. **Secure Egress:** Güvenlik açığı yaratabilecek ve yönetim yükü getirecek Bastion Host (Jumping Box) konfigürasyonu yerine, GCP Cloud Router destekli **Cloud NAT** mimarisi benimsenmiştir.

## Consequences
- Takım üyeleri aynı altyapı state'i üzerinde çakışma yaşamadan güvenle çalışabilir.
- Private subnet içerisindeki iş yükleri dışarıdan doğrudan erişime kapalı tutulurken, paket çıkışları kontrollü ve loglanabilir hale gelmiştir.