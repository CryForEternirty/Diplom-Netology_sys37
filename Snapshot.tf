resource "yandex_compute_snapshot_schedule" "daily_snapshots" {
  name = "daily-snapshots"

  schedule_policy {
    expression = "05 16 * * *"  # Ежедневно в 16:05 UTC = 19:05 MSK (Московское время)
  }

  retention_period = "168h"  # Храним снапшоты 7 дней (168 часов)
  snapshot_count   = 7       # Храним до 7 снапшотов

  snapshot_spec {
    description = "Daily snapshot for backup"
  }

  disk_ids = [
    yandex_compute_instance.bastion.boot_disk.0.disk_id,
    yandex_compute_instance.nginx-1.boot_disk.0.disk_id,
    yandex_compute_instance.nginx-2.boot_disk.0.disk_id,
    yandex_compute_instance.zabbix.boot_disk.0.disk_id,
    yandex_compute_instance.elastic.boot_disk.0.disk_id,
    yandex_compute_instance.kibana.boot_disk.0.disk_id
  ]
}