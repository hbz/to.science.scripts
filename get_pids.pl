#!/usr/bin/perl -w
# Erzeugt PID-Liste auf Basis von Anfragen an Fedora REST-API (nicht an Elasticsearch)
#| Autor     | Datum      | Beschreibung
#|-----------+------------+---------------------------------------------------
#| I. Kuss   | 27.01.2021 | Neuanlage
#| I. Kuss   | 15.06.2021 | Erzeugt auch eine Identifier-Liste. Identifier sind HT-Nrn.
#|           |            | Für EDOZWO-1070 (Dublettenabgleich).
# Beispielaufruf:
# perl get_pids.pl -s -m 100000 -n edoweb -o $REGAL_LOGS/get_pids.txt -i $REGAL_LOGS/get_identifiers.txt
# Output der PID-Liste standardmäßig (ohne Option -o) nach $REGAL_LOGS/get_pids.txt
# Output der Identifier-Liste standardmäßig (ohne Option -i) nach $REGAL_LOGS/get_identifiers.txt

use strict;
use warnings;
use File::Basename;
use File::Copy;
use Getopt::Std;
# https://metacpan.org/pod/WWW::Curl
use WWW::Curl;
use WWW::Curl::Easy;

# *****************
# Globale Variablen
# *****************
my $script = basename( $0 );
my $log = *STDOUT;
my $script_ohne_endung = $script;
$script_ohne_endung =~ s/\.pl$//;
my $REGAL_TMP = "/opt/regal/regal-tmp";
my $outfile; # Dateiname(n); Hier werden die einzelnen Tranchen der Fedora-Response abgelegt (PIDS und Identifier)
my $REGAL_LOGS = "/opt/regal/logs";
my $pidfile = $REGAL_LOGS . "/" . "get_pids" . ".txt"; # PID-Liste
my $idfile = $REGAL_LOGS . "/" . "get_identifiers" . ".txt"; # Identifier-Liste
my $maxResults = 200000; # Max. Anzahl Fedora-Objekte, die dieses Skript liest
my $resumptionToken; # Wiederaufnahme-Token zur Iteration der mehrfachen Curl-Aufrufe an die Fedora REST-API
my $curl = ""; # Curl-Objekt für Perl
my $namensraum = "";
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
my $zeitstempel = sprintf ("%04d%02d%02d%02d%02d%02d", $year+1900,$mon+1,$mday,$hour,$min,$sec);

# **********************************
# Auswertung Kommandozeilen-Optionen
# **********************************
my %opts=();
getopts('hi:m:n:o:sS', \%opts) or usage("ungültige Optionen");
if ( defined($opts{h}) ) {
  usage("Hilfeseite");
  }
if ( defined($opts{i}) ) {
  $idfile = $opts{i};
  }
printf $log "Output-Datei (Identifier-Liste): %s\n", $idfile;
if( !defined($opts{s}) && !defined($opts{S}) ) {
  my $logdatei = $script;
  $logdatei =~ s/\.pl$/.log/;
  open LOG, ">$logdatei" or die "Kann Protokolldatei $logdatei nicht oeffnen ($!)!\n";
  $log = *LOG;
  printf "Schreibe Protokoll nach %s\n", $logdatei;
  }
if ( defined($opts{m}) ) {
  $maxResults = $opts{m};
  }
printf $log "Maximale Anzahl Objekte: %d\n", $maxResults;
if ( defined($opts{n}) ) {
  $namensraum = $opts{n};
  }
if ( ! $namensraum || $namensraum eq "" ) {
  usage("Bitte einen Namensraum vergeben");
  }
printf $log "Namensraum: %s\n", $namensraum;
if ( defined($opts{o}) ) {
  $pidfile = $opts{o};
  }
printf $log "Output-Datei (PID-Liste): %s\n", $pidfile;

# Kommandozeilen-Parameter
# if (! $ARGV[0] ) { usage(); }

# **********************
# Funktionsdeklarationen
# **********************
sub write_to_lists {
  # geschriebene Datei öffnen, PIDs und Wiederaufnahme-Token herausfiltern
  # PIDs an PID-Liste anhängen, Identifier an Identifier-Liste anhängen
  open OUT, "$outfile" or die "Kann Out-Datei $outfile nicht zum Lesen oeffnen ($!)!\n";
  open PID, ">>$pidfile" or die "Kann an PID-Liste $pidfile nicht anhaengen ($!)!";
  open IDF, ">>$idfile" or die "Kann an Identifier-Liste $idfile nicht anhaengen ($!)!";
  my $line;
  my $pid = "";
  my $identifier = "";
  $resumptionToken = "";
  while (<OUT>) {
    $line = $_; chomp($line);
    # printf $log "$line\n";
    if( $line =~ /^[ \t]+<objectFields>$/ ) {
      # Beginn eines neuen Objektes
      $pid = "";
      $identifier = "";
    }
    elsif( $line =~ /^[ \t]+<pid>$namensraum:(.*)<\/pid>$/ ) {
      $pid = $1;
    }
    elsif( $line =~ /^[ \t]+<identifier>$namensraum:(.*)<\/identifier>$/ ) {
      # die PID kommt noch einmal als Identifier => ignorieren
      # printf $log "Identifier $namensraum:$1 wird ignoriert.\n";
    }
    elsif( $line =~ /^[ \t]+<identifier>(.*)<\/identifier>$/ ) {
      # anderer Identifier (HT-Nummer) => merken
      # printf $log "Identifier $1 gefunden.\n";
      if( defined $identifier && $identifier ne "") {
        # Anhängen an schon eingelesene(n) Identifikator(en)
          $identifier .= ", " . $1;
        }
      else {
          $identifier = $1;
        }
    }
    elsif( $line =~ /^[ \t]+<\/objectFields>$/ ) {
      # Ende des Objektes. Objekt ausgeben.
      printf PID "$namensraum:$pid\n";
      if( defined $identifier && $identifier ne "" ) {
        printf IDF "$identifier;$namensraum:$pid\n";
      }
    }
    elsif( $line =~ /^[ \t]+<token>(.*)<\/token>$/ ) {
      $resumptionToken = $1;
      printf $log "Resumption-Token: $resumptionToken\n";
    }
  }
  close IDF;
  close PID;
  close OUT;
  return;
}

sub create_curl_object {
  # Öffnen der Perl-Schnittstelle zu Curl (neue Instanz von WWW::Curl erzeugen)
  $curl = WWW::Curl::Easy->new();
  if( ! $curl ){
    printf $log "WARN: WWW::Curl::Easy->new() failed; Curl-Objekt kann nicht angelegt werden !\n";
    exit 1;
   }
  # $curl->setopt(CURLOPT_HEADER,1);
  $curl->setopt(CURLOPT_VERBOSE,1);
  return;
}

# ****************************
# BEGINN der Hauptverarbeitung
# ****************************
# Ausgabedateien löschen, falls schon exsitent
if( -e $pidfile ) {
  printf $log "INFO: PID-Liste $pidfile existiert schon.\n";
  my $oldpidfile = $pidfile.".".$zeitstempel;
  printf $log "INFO: Bestehende PID-Liste wird umbenannt nach $oldpidfile.\n";
  move( $pidfile, $oldpidfile ) or die "Kann PID-Liste $pidfile nicht umbenennen nach $oldpidfile ($!)!";
}
if( -e $idfile ) {
  printf $log "INFO: Identifier-Liste $idfile existiert schon.\n";
  my $oldidfile = $idfile.".".$zeitstempel;
  printf $log "INFO: Bestehende Identifier-Liste wird umbenannt nach $oldidfile.\n";
  move( $idfile, $oldidfile ) or die "Kann Identifier-Liste $idfile nicht umbenennen nach $oldidfile ($!)!";
}

# Öffnen der Perl-Schnittstelle zu Curl (Instanz erzeugen)
&create_curl_object;

# Erstmalige Anfrage; Lies erste Tranche
my $tranche = 0;
$outfile = $REGAL_TMP . "/" . $script_ohne_endung . ".tranche" . sprintf("%04d", $tranche);
$curl->setopt(CURLOPT_URL, "http://localhost:8080/fedora/objects/?pid=true&identifier=true&query=pid~$namensraum:*&maxResults=$maxResults&resultFormat=xml");
my $fh;
open $fh, ">$outfile" or die "Kann Out-Datei $outfile nicht schreiben!($!)";
$curl->setopt(CURLOPT_WRITEDATA, $fh);
my $retcode = $curl->perform();
if ($retcode != 0) {
  printf $log "WARN: An error happened: ". $curl->strerror($retcode). " (retcode)\n";
  printf $log "WARN Error-Buffer: ". $curl->errbuf . "\n";
}
else {
  print $log "HTTP Response Code: " . $curl->getinfo(CURLINFO_HTTP_CODE) . "\n";
}
# $curl->curl_easy_cleanup; 
close $fh;
print $log "\n";

# gelesene PIDs und Identifier in Listen fortschreiben
&write_to_lists;

# Solange weitere Tranchen lesen, bis es keine mehr gibt
while( $resumptionToken && $resumptionToken ne "" ) {
  # Nächste Tranche lesen
  $tranche++;
  printf $log "INFO: Hole Tranche Nr. %d (nächste 100 Objekte)\n", $tranche;
  $outfile = $REGAL_TMP . "/" . $script_ohne_endung . ".tranche" . sprintf("%04d", $tranche);
  $curl->setopt(CURLOPT_URL, "http://localhost:8080/fedora/objects/?sessionToken=$resumptionToken&pid=true&identifier=true&query=pid~$namensraum:*&maxResults=$maxResults&resultFormat=xml"); # liefert die nächsten 100 Objekte
  open $fh, ">$outfile" or die "Kann Out-Datei $outfile nicht schreiben!($!)";
  $curl->setopt(CURLOPT_WRITEDATA, $fh);
  $retcode = $curl->perform();
  if ($retcode != 0) {
    printf $log "WARN: An error happened: ". $curl->strerror($retcode). " (retcode)\n";
    printf $log "WARN: Error-Buffer: ". $curl->errbuf . "\n";
  }
  else {
    print $log "HTTP Response Code: " . $curl->getinfo(CURLINFO_HTTP_CODE) . "\n";
  }
  close $fh;
  print $log "\n";
  # Nächste Tranche nach Listen schreiben
  &write_to_lists;

  if( $tranche % 10 == 0 ) {
    # Frisches Curl-Objekt erzeugen
    printf $log "INFO: Perl Curl-Objekt wird neu erzeugt.\n";
    &create_curl_object;
    }
  }

printf $log "SUCCESS: Programm $script erfolgreich durchgelaufen. Beendet sich.\n";
close LOG;
exit 0;

sub usage {
  my $msg = shift;
  print <<ENDE;
  $script - Erzeugt Listen von PIDs und Identifiern (HT-Nummern) auf Basis von Fedora REST-API-Aufrufen
  FEHLER: $msg

  Aufruf  :   $script
  Optionen:
       -h :   Zeige Hilfe (diese Informationen)
       -i :   Output-Datei : die Identifier-Liste
       -m :   maximale Anzahl Objekte, die diese PID-Liste haben soll
       -n :   Namensraum; das Prefix im Objekt-Identifier
       -o :   Output-Datei : die PID-Liste
    -s,-S :   Ausgabe auf den Bildschirm (Screen); kein Schreiben in Protokolldatei
  Beispiel:   perl get_pids.pl -s -m 100000 -n edoweb
ENDE
  exit 0;
  }
