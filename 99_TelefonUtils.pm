##############################################
# $Id: 99_TelefonUtils.pm 7570 2015-01-14 18:31:44Z JohannesNill $

package main;

#use strict;
use warnings;
use POSIX;

sub
TelefonUtils_Initialize($$)
{
  my ($hash) = @_;
}


sub FB_Anruf($){
  my ($fbDevice) = shift;
  my $extname = (ReadingsVal($fbDevice,"external_name",""));
  my $extnum = (ReadingsVal($fbDevice,"external_number",0));
  my $intnum = (ReadingsVal($fbDevice,"internal_number",0));
  my $resident = '@rr_Johannes,@rr_Rosi';
  my %tellows = getTellowsRating($extnum);

  if($extname eq "unknown"){
  	$extname = "Unbekannt";
  }

  fhem("msg $resident |Festnetzanruf| von $extname ($extnum) ".$tellows{'text'}.TGU_generateClickAnswers("Tellows-Website"));
  TGU_registerTelegramListener($resident, $extnum);

  if(istJohannesHome()){
  	SonosSpeak(JohannesAufenthalt(),"Anruf von $extname");
	fhem("msg light ".$tellows{'scoreColor'}) if(JohannesAufenthalt() eq "Wohnzimmer");
  }

  if(ReadingsVal("SamsungTVremote", "state", "disconnected") eq "opened"){
  		$extname =~ tr/ /_/;
  		fhem("set SamsungTV call $extname $extnum $intnum");
		InternalTimer(gettimeofday() + 10, "fhem", "set SamsungTVremote ENTER");
  }
}

sub FB_AnrufAnswer($$$){
  my ($answer, $resident, $extnum) = @_;
  if($answer eq "Tellows"){
    fhem('msg '.$resident.' |Festnetzanruf| Hier ist der Link: https://www.tellows.de/num/'.$extnum);
  }
}


sub getTellowsRating($){
	my ($number) = @_;
	my %tellows = ();
	$result = GetFileFromURL("http://www.tellows.de/basic/num/".$number."?xml=1&partner=test&apikey=test123", 5);
	if(not defined($result)){
		return "Tellows nicht erreichbar";
	}
	else{
		$result =~ /<score>(\d)/;
		$tellows{'score'} = $1;

		$result =~ /<searches>([\d]+)/;
		$tellows{'searches'} = $1;

		$result =~ /<comments>([\d]+)/;
		$tellows{'comments'} = $1;

		$result =~ /<scoreColor>([^"]*?)</;
		$tellows{'scoreColor'} = $1;

		$result =~ /<scorePath>([^"]*?)</;
		$tellows{'scorePath'} = $1;

		$result =~ /<location>([^"]*?)</;
		$tellows{'location'} = $1;

		$result =~ /<country>([^"]*?)</;
		$tellows{'country'} = $1;

		if($result =~ /<name>([^"]*?)</){
			$tellows{'mostCritic'} = $1;
			$result =~ /<count>([\d]+)/;
			$tellows{'mostCriticCount'} = $1;
		}
		else{
			$tellows{'mostCritic'} = 0;
			$tellows{'mostCriticCount'} = 0;
		}

		$tellows{'location'} = $tellows{'location'}.", ".$tellows{'country'} if ($tellows{'country'} ne "Deutschland");

		if($tellows{'score'} == 5){
			$tellows{'text'} = "aus ".$tellows{'location'}.", Tellows-Score: neutral";
		}
		elsif($tellows{'score'} < 5){
			$tellows{'text'} = "aus ".$tellows{'location'}.", Tellows-Score: positiv (".$tellows{'score'}."), häufigster Lob: ".$tellows{'mostCritic'}." (".$tellows{'mostCriticCount'}." x)";
		}
		else{
			$tellows{'text'} = "aus ".$tellows{'location'}.", Tellows-Score: negativ (".$tellows{'score'}."), häufigster Reklamegrund: ".$tellows{'mostCritic'}." (".$tellows{'mostCriticCount'}." x)";
		}

		return %tellows;
	}
}


sub getTellowsScore($){
	my ($number) = @_;
	%tellows = getTellowsRating($number);
	return $tellows{'score'};
}


1;
