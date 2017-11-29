##############################################
# $Id: 99_HaustuerAutomationUtils.pm 7000 2017-02-15 22:31:44Z JohannesNill $


package main;

use strict;
use warnings;
use POSIX;

# Gerätenamen
my $tuerkontakt = "door_Haustuere";
my $lichtInnen = "au_Treppenhaus";
my $lichtAussen = "strg_Haustuere";
my $bewegungsmelder = "Bewegungsmelder";
my $johannes = "strg_SchluesselSender_Btn_Johannes";
my $rosi = "strg_SchluesselSender_Btn_Rosi";

# Übergangszeiten in sek
my $zeitInnen = 240;
my $zeitAussen = 30;

# Zustandsvariablen
my $state = "init";

sub
HaustuerAutomationUtils_Initialize($$)
{
  my ($hash) = @_;
}

sub HTA_stateMachine($$){
	use Switch;
	my ($device, $event) = @_;
  my $trans = $device.$event;

  $state = "nichts" if ($state eq "init");

  if(istDunkel()){
    switch($state){

      # Zustandsübergang nach Zuständen
      case "nichts" {
        if ($trans eq $bewegungsmelder."motion"){
          $state = "kommen1";
          HTA_setLicht($lichtAussen, $zeitAussen);
          HTA_startStateTransmissionTimer($zeitAussen);
        }
        if ($trans eq $lichtInnen."An"){
          $state = "gehen1";
          HTA_startStateTransmissionTimer($zeitInnen);
        }
        if ($trans eq $johannes."closed" or $trans eq $rosi."closed"){
          $state = "gehen1";
          HTA_setLicht($lichtInnen, $zeitInnen);
          HTA_startStateTransmissionTimer($zeitInnen);
        }
      }

      case "kommen1" {
        if ($trans eq $tuerkontakt."open"){
          $state = "kommen2";
          HTA_setLicht($lichtInnen, $zeitInnen);
          HTA_startStateTransmissionTimer($zeitInnen);
        }
        if ($trans eq $lichtInnen."An"){
          $state = "beides";
          HTA_setLicht($lichtInnen, $zeitInnen);
          HTA_startStateTransmissionTimer($zeitInnen);
        }
      }

      case "kommen2" {
        if ($trans eq $tuerkontakt."closed"){
          $state = "kommen3";
          HTA_setLichtOff($lichtAussen);
          HTA_startStateTransmissionTimer($zeitInnen);
        }
      }
	  
	  case "kommen3" {
	  	if ($trans eq $johannes."closed" or $trans eq $rosi."closed"){
			$state = "nichts";
			HTA_setLichtOff($lichtInnen);
		}
	  }

      case "gehen1" {
        if ($trans eq $tuerkontakt."open"){
          $state = "gehen2";
          HTA_setLicht($lichtAussen, $zeitAussen);
          HTA_startStateTransmissionTimer($zeitAussen);
        }
        if ($trans eq $bewegungsmelder."motion"){
          $state = "beides";
          HTA_setLicht($lichtAussen, $zeitAussen);
          HTA_startStateTransmissionTimer($zeitAussen);
        }
      }

      case "gehen2" {
        if ($trans eq $tuerkontakt."closed"){
          $state = "gehen3";
          HTA_setLichtOff($lichtInnen);
          HTA_startStateTransmissionTimer($zeitAussen);
        }
      }

      else {$state = $state}
    }

    # Zustandsübergang nach Zeit
    if ($trans eq "timeexec"){
      $state = "nichts";
    }
  }
  
}

sub HTA_setLicht($$){
  my ($device, $duration) = @_;
  return fhem("set $device on-for-timer $duration");
}

sub HTA_setLichtOff($){
  my ($device) = shift;
  return fhem("set $device off");
}

sub HTA_startStateTransmissionTimer($){
  my ($time) = shift;
  RemoveInternalTimer("time,exec","HTA_interfaceTimerToStateMachine");
  InternalTimer(gettimeofday() + $time, "HTA_interfaceTimerToStateMachine", "time,exec");
}

sub HTA_interfaceTimerToStateMachine($){
  my ($device,$event) = split(",",shift);
  HTA_stateMachine($device,$event);
}

sub HTA_getState(){
  return $state;
}

sub HTA_setState($){
  $state = shift;
}

1;
