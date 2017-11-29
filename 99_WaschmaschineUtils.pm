##############################################
# $Id: 99_WaschmaschineUtils.pm 7570 2017-05-26 20:31:44Z JohannesNill $


package main;

use strict;
use warnings;
use POSIX;

# Voreinstellungen
my $device = "power_Waschmaschine";

# Variablen
my $state = "init";
my $beginPower = 0;
my $beginTime = 0;
my $usedPower = 0;
my $usedTime = 0;

sub
WaschmaschineUtils_Initialize($$)
{
  my ($hash) = @_;
}


sub WMU_StateMachine($){
	my ($event) = shift;
	use Switch;
	$state = "aus" if ($state eq "init");
	
	switch($state){
		case "aus" {
			if ($event > 5){
				WMU_execLaeuft();
				$state = "läuft";
			}
		}
		case "läuft" {
			if ($event < 3){
				$state = "vorfertig";
				InternalTimer(gettimeofday() + 300, "WMU_StateMachine", "timer");
			}
		}
		case "vorfertig" {
			if (int($event) > 3){
				RemoveInterlTimer("timer","WMU_StateMachine");
				$state = "läuft";
			}
			if ($event eq "timer"){
				$state = "fertig";
				WMU_execFertig();
			}
		}
		case "fertig" {
			$state = "aus";
		}
	}
	
	fhem("set power_WaschmaschineState $state");
}


sub WMU_execLaeuft(){
	$beginPower = ReadingsVal($device, "energy", 0);
	$beginTime = gettimeofday();
}

sub WMU_execFertig(){
	$usedPower = ReadingsVal($device, "energy", 0) - $beginPower;
	$usedTime = gettimeofday() - $beginTime;
	fhem("msg \@rr_Rosi |Waschmaschine| Ich bin fertig! Es hat ".substr(sec2hms($usedTime),0,5)." gedauert und ".round(($usedPower/1000.0),2)."kW/h verbraucht.");
}

sub WMU_getState(){
 return $state;
}

sub WMU_setState($){
	$state = shift;
}

1;
