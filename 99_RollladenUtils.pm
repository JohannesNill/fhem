##############################################
# $Id: 99_RollladenUtils.pm 7570 2017-02-12 20:31:44Z JohannesNill $


package main;

use strict;
use warnings;
use POSIX;

my $rollDevice = "RolladenWohn";

sub RollladenUtils_Initialize($$)
{
  my ($hash) = @_;
}

sub RLU_automation($){
  use Switch;

  my ($event, $state) = (shift, ReadingsVal($rollDevice, "automaticState",""));
  if(istHeizungAn()){
    switch ($event){
      case "rr_Rosi:home" {
          if ($state eq "Zu" and isTimeBetweenRange(sunset("CIVIL"), "22:30:00")){
            sendRollladen("on-for-timer 6");
            fhem("setreading $rollDevice automaticState Zu80");
          }
      }
      case "rr_Rosi:gone" {
          if($state eq "Zu80" and isTimeBetweenRange(sunset("CIVIL"), "22:30:00")){
            sendRollladen("off");
            fhem("setreading $rollDevice automaticState Zu");
          }
      }
      case "sunset" {
          if ($state eq "Offen" and !istRosiHome()){
            sendRollladen("off");
            fhem("setreading $rollDevice automaticState Zu");
          }
      }
      case "sunset+1800" {
          if ($state eq "Offen" and istRosiHome()){
            sendRollladen("off-for-timer 12");
            fhem("setreading $rollDevice automaticState Zu80");
          }
      }
      case "22:30" {
          if ($state eq "Zu80"){
            sendRollladen("off");
            fhem("setreading $rollDevice automaticState Zu");
          }
      }
      case "sunrise+900" {
          if ($state eq "Zu"){
            sendRollladen("on");
            fhem("setreading $rollDevice automaticState Offen");
          }
      }
    }
  }

  else{
    return if (Value("ModusBeschattungssteuerung") ne "An" or istRosiHome());

    if (($state eq "Offen" and (getAussentemperatur() > ReadingsVal("fht_GrossWohn", "measured-temp", 0)) and (ReadingsVal("fht_GrossWohn","measured-temp",0) > Value("TempBeschattungssteuerung")) and getHelligkeitText() eq "sonnig")  or  ($event eq "rr_Rosi:gone" and isTimeBetweenRange("07:00:00", "12:30:00") and (ReadingsVal("Wettervorhersage","fc1_high_c",0) > Value("TempBeschattungssteuerung")) and (ReadingsVal("Wettervorhersage","fc1_condition","") eq "sonnig"))){
      sendRollladen("off");
      fhem("setreading $rollDevice automaticState Zu");
    }
    elsif ($state eq "Zu" and ($event eq "sunset" or ReadingsVal("fht_GrossWohn","measured-temp",0) < (Value("TempBeschattungssteuerung") - 1.0))){
	  sendRollladen("on");
      fhem("setreading $rollDevice automaticState Offen");
    }
  }
}


1;
