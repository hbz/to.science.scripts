
#!/bin/bash
# Dieses Skript räumt im Verzeichnis /tmp auf. 
# Das Skript sollte als täglicher cronjob eingestellt werden.
# I. Kuss, 16.09.2026

# Lösche alle Dateien "tmpmetadata*", die älter als 100 Tage sind.
find /tmp -type f -name "tmpmetadata*" -mtime +100 -delete

# Lösche alle Dateien "MIME*.tmp", die älter als 100 Tage sind.
find /tmp -type f -name "MIME*.tmp" -mtime +100 -delete
