#!/usr/bin/perl -w
# Erzeugt PID-Liste auf Basis von Anfragen an Fedora REST-API (nicht an Elasticsearch)
# Autor: I. Kuss, hbz, 27.01.2021
# Beispielaufruf: perl get_pids.pl -s -m 100000 -n edoweb

use strict;
use warnings;
use File::Basename;
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
my $pidfile = $script_ohne_endung . ".txt";
my $REGAL_TMP = "/opt/regal/regal-tmp";
my $maxResults = 200000; # Max. Anzahl Fedora-Objekte, die dieses Skript liest
my $outfile; # Dateiname(n); Hier werden die einzelnen Tranchen der Fedora-Response abgelegt
my $resumptionToken; # Wiederaufnahme-Token zur Iteration der mehrfachen Curl-Aufrufe an die Fedora REST-API
my $curl = ""; # Curl-Objekt für Perl
my $namensraum = "";

# **********************************
# Auswertung Kommandozeilen-Optionen
# **********************************
my %opts=();
getopts('hm:n:o:sS', \%opts) or usage("ungültige Optionen");
if ( defined($opts{h}) ) {
  usage("Hilfeseite");
  }
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
sub write_to_pidfile {
  # geschriebene Datei öffnen, PIDs und Wiederaufnahme-Token herausfiltern, PIDs an PID-Liste anhängen
  open OUT, "$outfile" or die "Kann Out-Datei $outfile nicht zum Lesen oeffnen ($!)!\n";
  open PID, ">>$pidfile" or die "Kann an PID-Liste $pidfile nicht anhaengen ($!)!";
  my $line;
  my $pid;
  $resumptionToken = "";
  while (<OUT>) {
    $line = $_; chomp($line);
    # printf $log "$line\n";
    if( $line =~ /^[ \t]+<pid>$namensraum:(.*)<\/pid>$/ ) {
      $pid = $1;
      printf PID "$namensraum:$pid\n";
    }
    elsif( $line =~ /^[ \t]+<token>(.*)<\/token>$/ ) {
      $resumptionToken = $1;
      printf $log "Resumption-Token: $resumptionToken\n";
    }
  }
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
# Ausgabedatei löschen, falls schon exsitent
if( -e $pidfile ) {
  printf "WARN: PID-Liste $pidfile existiert schon !\n";
  print "Löschen (J/N) ? ";
  my $antwort = <STDIN>; chomp $antwort;
  printf "Antwort: $antwort\n";
  if( $antwort ne "J" ) {
    printf "INFO: Liste wird nicht gelöscht. Programmende.\n";
    exit 0;
  }
  unlink $pidfile;
}

# Öffnen der Perl-Schnittstelle zu Curl (Instanz erzeugen)
&create_curl_object;

# Erstmalige Anfrage; Lies erste Tranche
my $tranche = 0;
$outfile = $REGAL_TMP . "/" . $script_ohne_endung . ".tranche" . sprintf("%04d", $tranche);
$curl->setopt(CURLOPT_URL, "http://localhost:8080/fedora/objects/?pid=true&query=pid~$namensraum:*&maxResults=$maxResults&resultFormat=xml");
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

# gelesene PIDs in PID-Liste fortschreiben
&write_to_pidfile;

# Solange weitere Tranchen lesen, bis es keine mehr gibt
while( $resumptionToken && $resumptionToken ne "" ) {
  # Nächste Tranche lesen
  $tranche++;
  printf $log "INFO: Hole Tranche Nr. %d (nächste 100 Objekte)\n", $tranche;
  $outfile = $REGAL_TMP . "/" . $script_ohne_endung . ".tranche" . sprintf("%04d", $tranche);
  $curl->setopt(CURLOPT_URL, "http://localhost:8080/fedora/objects/?sessionToken=$resumptionToken&pid=true&query=pid~$namensraum:*&maxResults=$maxResults&resultFormat=xml"); # liefert die nächsten 100 Objekte
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
  # Nächste Tranche nach PID-File schreiben
  &write_to_pidfile;

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
  $script - Erzeuge PID-Liste auf Basis von Fedora REST-API-Aufrufen
  FEHLER: $msg

  Aufruf  :   $script
  Optionen:
       -h :   Zeige Hilfe (diese Informationen)
       -m :   maximale Anzahl Objekte, die diese PID-Liste haben soll
       -n :   Namensraum; das Prefix im Objekt-Identifier
       -o :   Output-Datei (die PID-Liste)
    -s,-S :   Ausgabe auf den Bildschirm (Screen); kein Schreiben in Protokolldatei
  Beispiel:   perl get_pids.pl -s -m 100000 -n edoweb
ENDE
  exit 0;
  }
