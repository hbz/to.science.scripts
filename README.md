# Installation to.science.scripts  
    cd /opt/toscience  
    git clone https://github.com/hbz/to.science.scripts.git  bin
    cd bin
  
# Edit variables and adjust to your own settings  
# Use same variables as already edited in to.science.install
    ln -s ../to.science.install/conf/variables.conf
      
# Create soft links  
    cd /opt/toscience/bin  
    ln -s /opt/toscience/bin/cdn cdn  
      
# Define cron jobs  
Sample crontab:  
    # For more information see the manual pages of crontab(5) and cron(8)  
    #   
    # m h  dom mon dow   command  
    0 2 * * * /opt/toscience/bin/turnOnOaiPmhPolling.sh  
    0 5 * * * /opt/toscience/bin/turnOffOaiPmhPolling.sh  
    05 7 * * * /opt/toscience/bin/register_urn.sh control  >> /opt/toscience/logs/control_urn_vergabe.log  
    1 1 * * * /opt/toscience/bin/register_urn.sh katalog >> /opt/toscience/logs/katalog_update.log  
    1 0 * * * /opt/toscience/bin/register_urn.sh register >> /opt/toscience/logs/register_urn.log  
    0 5 * * * /opt/toscience/bin/updateAll.sh > /dev/null  
    #0 23 * * * /opt/toscience/bin/loadCache.sh  
    0 1 * * * /opt/toscience/bin/import-logfiles.sh >/dev/null  
    # Start Edoweb Webgatherer Sequenz  
    0 20 * * * /opt/toscience/bin/runGatherer.sh >> /opt/toscience/logs/runGatherer.log  
    # Auswertung des letzten Webgatherer-Laufs  
    0 21 * * * /opt/toscience/bin/evalWebgatherer.sh >> /opt/toscience/logs/runGatherer.log  
    # Verschieben von Dateien aus dem Arbeitsverzeichnis von wpull ins Outputverzeichnis von wpull  
    0 22 * * * /opt/toscience/bin/ks.move_files_from_crawldir.sh >> /opt/toscience/logs/ks.move_files_from_crawldir.log  
    # Indexierung neu geharvesteter Webschnitte  
    0 2 * * * /opt/toscience/bin/backup-es.sh -c >> /opt/toscience/logs/backup-es.log 2>&1  
    30 2 * * * /opt/toscience/bin/backup-es.sh -b >> /opt/toscience/logs/backup-es.log 2>&1  
    0 2 * * * /opt/toscience/bin/backup-db.sh -c >> /opt/toscience/logs/backup-db.log 2>&1  
    30 2 * * * /opt/toscience/bin/backup-db.sh -b >> /opt/toscience/logs/backup-db.log 2>&1  
    0 2 * * * /opt/toscience/bin/depersonalize-apache-logs.sh  
    # Crawl Reports  
    0 22 * * * /opt/toscience/bin/crawlReport.sh >> /opt/toscience/logs/crawlReport.log  
