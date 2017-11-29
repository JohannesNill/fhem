##############################################
# $Id: 99_FHTUtils.pm 1005 2015-01-14 18:31:44Z JohannesNill $


package main;

use strict;
use warnings;
use POSIX;

my $state = "init";
my $oldState = "init";


sub
FHTUtils_Initialize($$)
{
  my ($hash) = @_;
}

# Enter you functions below _this_ line.

sub FHT_BadLueftenCalculation(){
  my $oldTemp = ReadingsVal("fht_ThermostatBad_Climate","winOpenStateTemp","");
	my $oldHum = ReadingsVal("fht_ThermostatBad_Climate","winOpenStateHum","");
	my $isTemp = ReadingsVal("fht_ThermostatBad_Climate","measured-temp","");
	my $isHum = ReadingsVal("fht_ThermostatBad_Climate","humidity","");
	my $outTemp = ReadingsVal("Aussenthermometer","temperature",0);
	my $outHum = ReadingsVal("Aussenthermometer","humidity",0);
	my $showerPerson = '@'.ReadingsVal("fht_ThermostatBad_Climate","isShoweringPerson","");
	if(($isTemp < ($oldTemp - 2.0) and $outTemp < 10.0)  or  ($isHum < ($oldHum - (35.0-((10.0*$outHum)/100.0))))  or  ($isTemp < 15.0)){
    	TGU_registerTelegramListener($showerPerson, join("|",$oldTemp,$oldHum,$isTemp,$isHum,$outTemp,$outHum));
		fhem("msg $showerPerson |Badfenster| Meiner Meinung nach wurde genug gelüftet.".TGU_generateClickAnswers("Mehr Infos"));
		fhem("setreading fht_ThermostatBad_Climate winOpenMsgDelivered 1");
	}
  fhem("set test ".(join("|",$oldTemp,$oldHum,$isTemp,$isHum,$outTemp,$outHum)));
}

sub FHT_BadLueftenCalculationAnswer($$$){
  my ($answer, $resident, $oldTemp,$oldHum,$isTemp,$isHum,$outTemp,$outHum) = (shift, shift, split("|",shift));
  if($answer eq "Mehr"){
    fhem('msg '.$resident.' |Badfenster| Folgendes: \nTemperatur-Drop: '.($oldTemp-$isTemp).'°C \nLuftfeuchte-Drop: '.($oldHum-$isHum).'% \nIst-Temperatur: '.$isTemp.'°C \nIst-Luftfeuchtigkeit: '.$isHum."%");
  }
}

sub FHT_getBadShoweringPerson(){
	if(ReadingsVal("fht_ThermostatBad_Climate","isShowering",0) == 1){
		if(istJohannesHome() and !istRosiHome()){
			return "rr_Johannes";
		}
		if(!istJohannesHome() and istRosiHome()){
			return "rr_Rosi";
		}
		if(istJohannesHome() and istRosiHome()){
			if(JohannesAufenthalt() eq "unbekannt"){
				return "rr_Johannes";
			}
			else{
				return "rr_Rosi";
			}
		}
	}
	else{
		return "rr_Johannes";
	}
}

sub FHT_JohannesKommtHeim(){
  return if(!istHeizungAn());
  my $time = CurrentTime();
  if (minTime($time, "22:30:00") eq $time and maxTime($time, "06:00:00") eq $time){
    setFHT("JohannesWohn","day");
    return "Heizung wird eingeschaltet";
  }
  else{
    TGU_registerTelegramListener('@rr_Johannes');
    fhem("msg \@rr_Johannes |Heizung| Ich bin mir nicht sicher. Soll ich die Heizung einschalten?".TGU_generateClickAnswers("Ja","Nein"));
    return "Sieh auf dein Telefon.";
  }
}

sub FHT_JohannesKommtHeimAnswer($$){
  my ($answer, $resident) = @_;
  if ($answer eq "Ja"){
    setFHT("JohannesWohn","day");
    fhem("msg \@rr_Johannes |Heizung| Alles klar, ich fahre hoch.");
  }
  elsif($answer eq "Nein"){
    fhem("msg \@rr_Johannes |Heizung| OK, ich bleibe aus.");
  }
}

sub FHT_generateShutdownTimeSpec(){
  use Time::Local;
  my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime;
  my $SonosAlarm = getSonosAlarmDay(getJohannesSchlafzimmer(), $wday + 1);
  return "20:00:00" if ($SonosAlarm == undef);
  return TU_Get_Decrement($SonosAlarm, "10:00:00");
}

sub FHT_setShutdown(){
	use Time::Local;
	my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime;
	return if (getSonosAlarmDay(getJohannesSchlafzimmer(), $wday + 1) == undef or !istJohannesHome() or !istHeizungAn());
  	fhem("msg \@rr_Johannes |Heizung| Dein Wecker klingelt in 10 Stunden. Soll ich schonmal die Heizung herunterfahren?".TGU_generateClickAnswers("Sofort","1 Stunde", "2 Stunden", "Abbruch"));
  	TGU_registerTelegramListener('@rr_Johannes');
}

sub FHT_setShutdownAnswer($$){
  use Switch;
  my ($param, $resident) = @_;
  switch ($param) {
    case "Sofort" {
      setFHT("JohannesWohn","night");
      setFHT("JohannesSchlaf","night");
      fhem("msg $resident |Heizung| OK, ich fahre sofort herunter.");
    }
    case "1" {
      generateAt(3600,'{setFHT("JohannesWohn","night")}');
      generateAt(3601,'{setFHT("JohannesSchlaf","night")}');
      fhem("msg $resident |Heizung| OK, ich fahre in einer Stunde herunter.");
    }
    case "2" {
      generateAt(7200,'{setFHT("JohannesWohn","night")}');
      generateAt(7201,'{setFHT("JohannesSchlaf","night")}');
      fhem("msg $resident |Heizung| OK, ich fahre in zwei Stunden herunter.");
    }
    case "Abbruch" {
      fhem("msg $resident |Heizung| OK, dann lasse ich es halt bleiben.");
    }
  }
}

sub setFHT($$;$$$){
	my ($device, $firstTemperature, $duration, $secoundTemperature, $ignoreHeizungCondition) = @_;
	$duration = 0 unless $duration;
	$secoundTemperature //= "night";
	$device = makeDeviceParameter($device,"fht_");
	$ignoreHeizungCondition = 0 unless $ignoreHeizungCondition;
	$firstTemperature = getTemperatureFromToken($firstTemperature, $device);
	$secoundTemperature = getTemperatureFromToken($secoundTemperature, $device);
	if(istHeizungAn() or $ignoreHeizungCondition != 0){
		fhem("set $device desired-temp $firstTemperature");
		if($duration > 0){
			fhem("setreading $device delayDevice ".generateAt($duration, "set $device desired-temp ".$secoundTemperature, $device, "Rücksetzen auf Temperatur $secoundTemperature nach $duration Sekunden"));
			fhem("setreading $device delayTemperature $firstTemperature");
			fhem("setreading $device delayNotify ".generateNotify($device.":desired-temp:.*","if(ReadingsVal(\"".$device."\", \"delayTemperature\", \"\") ne ReadingsVal(\"".$device."\", \"desired-temp\", \"\")){\n fhem(\"delete \".ReadingsVal(\"".$device."\", \"delayDevice\", \"\"));;\n}", ($duration-1),1));
		}
	}
}



################################################
# Prüft, ob Raum aktuell beheizt werden sollte
# return 1: IST Heiz-Zeit
# return 0: ist KEINE Heiz-Zeit
sub istHeizZeit($$){
	my ($raum, $zeit) = @_;
    use Switch;
	use Time::Local;
    my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime;
    my $wtag;
    my $from1; my $from2; my $to1; my $to2;
    switch ($wday){
    	case 0	{$wtag = "sun-"}
        case 1	{$wtag = "mon-"}
        case 2	{$wtag = "tue-"}
        case 3	{$wtag = "wed-"}
        case 4	{$wtag = "thu-"}
        case 5	{$wtag = "fri-"}
        case 6	{$wtag = "sat-"}
        else 	{return "error"}
    }
    $from1 = ReadingsVal($raum, $wtag."from1", "12:00");
    $from2 = ReadingsVal($raum, $wtag."from2", "12:00");
    $to1 = ReadingsVal($raum, $wtag."to1", "12:00");
    $to2 = ReadingsVal($raum, $wtag."to2", "12:00");

    if(($zeit gt $from1 && $zeit lt $to1) or ($zeit gt $from2 && $zeit lt $to2)){
    	return 1;
    }
    else{
    	return 0;
    }
}

sub FHT_StateMachine($$){
  use Switch;
  my ($device, $event) = @_;
  my ($trans) = $device.$event;

  return 0 if (!istHeizungAn());

  $state = "static.Aus" if ($state eq "init");
  switch($state){
    case "static.Aus" {
      if ($trans eq makeSonosParameter(getJohannesSchlafzimmer()).":AlarmRunning: 1" and hasJohannesVorlesung()){
        FHT_setState("wait.Vorlesung");
      }
      if (($device eq "rr_Johannes" and $event eq "home" and isTimeBetweenRange("08:00:00","22:30:00")) or (makeSonosParameter(getJohannesSchlafzimmer())."AlarmRunning: 1" and !hasJohannesVorlesung())){
        FHT_setState("static.Wohnzimmer");
      }
    }

#    "static.Wohnzimmer" {}

#    "static.SchlafzimmerKurz" {}

#    "static.SchlafzimmerLang" {}

#    "wait.Vorlesung" {}

#    "wait.GehenNachricht" {}

#    "wait.KommenSpät" {}
  }


}

sub FHT_setState($){
  use Switch;
  my ($new) = shift;
  return 0 if !($new eq "static.Aus" or $new eq "static.Wohnzimmer" or $new eq "static.SchlafzimmerLang" or $new eq "static.SchlafzimmerKurz" or $new eq "wait.Vorlesung" or $new eq "wait.GehenNachricht" or $new eq "wait.KommenSpät");
  $oldState = $state;
  $state = $new;

  switch($state){
    case "static.Aus" {
      setFHT("Wohnzimmer","night");
      setFHT("Schlafzimmer","night");
    }

    case "static.Wohnzimmer" {
      setFHT("Wohnzimmer","day");
      setFHT("Schlafzimmer","night");
    }

    case "static.SchlafzimmerKurz" {
      setFHT("Wohnzimmer","19.0");
      setFHT("Schlafzimmer","19.0");
    }

    case "static.SchlafzimmerLang" {
      setFHT("Wohnzimmer","17.0");
      setFHT("Schlafzimmer","19.5");
    }

    case "wait.KommenSpät" {
      FHT_JohannesKommtHeimSpaet();
    }

  }
}

sub FHT_getState(){
  return $state;
}

sub FHT_JohannesKommtHeimSpaet(){
  return if (!istHeizungAn());
  TGU_registerTelegramListener('@rr_Johannes');
  fhem("msg \@rr_Johannes |Heizung| Ich bin mir nicht sicher. Soll ich die Heizung einschalten?".TGU_generateClickAnswers("Ja","Nein"));
}

sub FHT_JohannesKommtHeimSpaetAnswer($$){
  my ($answer, $resident) = @_;
  if($answer eq "Ja"){
    fhem("msg $resident |Heizung| Ok, wohin gehst du?".TGU_generateClickAnswers("Wohnzimmer","Schlafzimmer"));
    TGU_registerTelegramListener('@rr_Johannes');
  }
  else{
    fhem("msg $resident |Heizung| Alles klar, ich bleibe aus.");
  }
}

sub FHT_JohannesKommtHeimSpaetAnswerAnswer($$){
  my ($answer, $resident) = @_;
  FHT_StateMachine("rr_Johannes", $answer) if ($answer eq "Wohnzimmer" or $answer eq "Schlafzimmer");
}

1;
