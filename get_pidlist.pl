#!/usr/bin/perl -w
# Erzeugt PID-Liste auf Basis von Anfragen an Fedora REST-API (nicht an Elasticsearch)
#|---------------------+------------+-------------------------------------------------------------
#| Autor/Bearbeiter    | Datum      | Änderungsgrund
#|---------------------+------------+-------------------------------------------------------------
#| Ingolf Kuss         | 27.01.2021 | Skript erstellt für Reindexierung aller PIDs
#| Ingolf Kuss         | 03.07.2023 | Einschränkung der Liste auf einen Zeitraum der Neuanlage
#|---------------------+------------+-------------------------------------------------------------

use strict;
use warnings;
use File::Basename;
# https://metacpan.org/pod/WWW::Curl
use WWW::Curl;
use WWW::Curl::Easy;
use IO::Prompt::Tiny 'prompt';
use Pod::Usage;
use Getopt::Long;

my( $minDate, $maxDate, $maxResults, $tmpDir, $help, $man );
GetOptions(
  'f|minDate=s'  => \$minDate,
  't|maxDate=s'  => \$maxDate,
  'r|maxResults=s'  => \$maxResults,
  'd|tempDir=s'  => \$tmpDir,
  'h|help|?' => \$help,
  'm|man'    => \$man,
) or pod2usage(2);

pod2usage(1) if $help;
pod2usage(-exitval => 0, -verbose => 2) if $man;


# Max. Anzahl Fedora-Objekte, die dieses Skript liest
$minDate //= prompt( 'Enter minimum creation date (YYYY-MM-DD):  ', '2000-01-01' );
$maxDate //= prompt( 'Enter maximum creation date (YYYY-MM-DD):  ', '2099-12-31' );
$maxResults  //= prompt( 'Enter maximum number of results (pids): ', '200000' );
$tmpDir  //= prompt( 'Enter temp dir: ', '/opt/regal/regal-tmp' );

printf "minDate=%s\n", $minDate; 
printf "maxDate=%s\n", $maxDate; 
printf "maxResults=%d\n", $maxResults; 
printf "tempDir=%s\n", $tmpDir; 

# *****************
# Globale Variablen
# *****************
my $script = basename( $0 );
my $script_ohne_endung = $script;
$script_ohne_endung =~ s/\.pl$//;
my $pidfile = $script_ohne_endung . ".txt";
my $outfile; # Dateiname(n); Hier werden die einzelnen Tranchen der Fedora-Response abgelegt
my $resumptionToken; # Wiederaufnahme-Token zur Iteration der mehrfachen Curl-Aufrufe an die Fedora REST-API
my $curl = ""; # Curl-Objekt für Perl

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
    if( $line =~ /^[ \t]+<pid>edoweb:([0-9]+)<\/pid>$/ ) {
      $pid = $1;
      printf PID "edoweb:$pid\n";
    }
    elsif( $line =~ /^[ \t]+<token>(.*)<\/token>$/ ) {
      $resumptionToken = $1;
      printf "Resumption-Token: $resumptionToken\n";
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
    warn " WWW::Curl::Easy->new() failed; Curl-Objekt kann nicht angelegt werden !";
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
$outfile = $tmpDir . "/" . $script_ohne_endung . ".tranche" . sprintf("%04d", $tranche);
$curl->setopt(CURLOPT_URL, "http://localhost:8080/fedora/objects/?pid=true&query=pid~edoweb:*%20cDate>=$minDate%20cDate<=$maxDate&maxResults=$maxResults&resultFormat=xml");
my $fh;
open $fh, ">$outfile" or die "Kann Out-Datei $outfile nicht schreiben!($!)";
$curl->setopt(CURLOPT_WRITEDATA, $fh);
my $retcode = $curl->perform();
if ($retcode != 0) {
  warn "An error happened: ", $curl->strerror($retcode), " (rettcode)\n";
  warn "errbuf: ", $curl->errbuf;
}
else {
  print "HTTP Response Code: " . $curl->getinfo(CURLINFO_HTTP_CODE) . "\n";
}
# $curl->curl_easy_cleanup; 
close $fh;
print "\n";

# gelesene PIDs in PID-Liste fortschreiben
&write_to_pidfile;

# Solange weitere Tranchen lesen, bis es keine mehr gibt
while( $resumptionToken && $resumptionToken ne "" ) {
  # Nächste Tranche lesen
  $tranche++;
  printf "INFO: Hole Tranche Nr. %d (nächste 100 Objekte)\n", $tranche;
  $outfile = $tmpDir . "/" . $script_ohne_endung . ".tranche" . sprintf("%04d", $tranche);
  $curl->setopt(CURLOPT_URL, "http://localhost:8080/fedora/objects/?sessionToken=$resumptionToken&pid=true&query=pid~edoweb:*%20cDate>=$minDate%20cDate<=$maxDate&maxResults=$maxResults&resultFormat=xml"); # liefert die nächsten 100 Objekte
  open $fh, ">$outfile" or die "Kann Out-Datei $outfile nicht schreiben!($!)";
  $curl->setopt(CURLOPT_WRITEDATA, $fh);
  $retcode = $curl->perform();
  if ($retcode != 0) {
    warn "An error happened: ", $curl->strerror($retcode), " (rettcode)\n";
    warn "errbuf: ", $curl->errbuf;
  }
  else {
    print "HTTP Response Code: " . $curl->getinfo(CURLINFO_HTTP_CODE) . "\n";
  }
  close $fh;
  print "\n";
  # Nächste Tranche nach PID-File schreiben
  &write_to_pidfile;

  if( $tranche % 10 == 0 ) {
    # Frisches Curl-Objekt erzeugen
    printf "INFO: Perl Curl-Objekt wird neu erzeugt.\n";
    &create_curl_object;
    }
  }

printf "SUCCESS: Programm $script erfolgreich durchgelaufen. Beendet sich.\n";
exit 0;

__END__

=head1 Erzeuge PID-Liste auf Basis von Fedora-Anfragen

get_pidlist.pl

=head1 SYNOPSIS

    get_pidlist.pl [Optionen]

        Optionen:
          -f|minDate     kleinstes Anlagedatum der PIDS, Format: YYYY-MM-DD,   Default: 2000-01-01
          -t|maxDate     groesstes Anlagedatum der PIDS, Format: YYYY-MM-DD,   Default: 2099-31-12
          -r|maxResults  maximale Anzahl PIDS, die dieses Skript lesen wird,   Default: 200000
          -d|tempDir     ein temporaeres Arbeitsverzeichnis für dieses Skript, Default /opt/regal/regal-tmp
          -help          Diese Hilfe-Seite anzeigen

=cut
