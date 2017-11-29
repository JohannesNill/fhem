##############################################
# $Id: 99_SonosUtils.pm 7570 2015-01-14 18:31:44Z Johannes Nill $


package main;

use strict;
use warnings;
use POSIX;

sub
SonosUtils_Initialize($$)
{
  my ($hash) = @_;
}


sub defineUhrzeitAnsage($){
	use Time::Local;
  my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime;
	#my ($player, $count, $volume) = (makeSonosParameter(shift), shift, shift);
	my ($player, $count, $volume) = split(",", shift);
	$player = makeSonosParameter($player);
	$volume //= "45";
	$count = 0 unless $count;
	my $enable = ReadingsVal("Sonos_Schlafzimmer","schlafStatus","error");

	if($count > 0 && $count < 10){
		SonosSpeak($player, pickRandomItem("Guten morgen sir. ","Guten Morgen. ","Hallo. ","Aufwachen Sir. ")."Es ist ".sprintf("%02d:%02d", $hour, $min), 38);
	}
	
	my $delay = 0;
	if(($enable eq "alarmRunning") && ($count >= 10)){
		SonosSpeak($player, "Es ist ".sprintf("%02d:%02d", $hour, $min)." . Achtung! Wecker wird nun ausgeschaltet", 50);
	}
	if(($enable eq "alarmRunning") && ($count < 10)){
		if($count == 0){
			$min += 5;
			$delay += (5*60);
		}
		do{
			$min++;
			$delay += 60;
			if($min >= 60){
				$min -= 60;
				$hour++;
			}
		}while(($min % 5) != 0);

		#my $uhrzeit = sprintf("%02d:%02d", $hour, $min);
		#my $parameter = '"'.$player.'"'.", ".$count.", ".'"'.$volume.'"';
		#generateAt($uhrzeit.":00", "{defineUhrzeitAnsage($parameter)}", "Sonos-Wecker", "Nächste Iteration ($count) der Uhrzeitansage")
		
		$count++;
		InternalTimer(gettimeofday() + $delay, "defineUhrzeitAnsage", join(",", $player, $count, $volume));
	}
	
}

sub SonosJohannesGotoSleep(){
  use Time::Local;
  my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime;
  my $ansage = "Gute Nacht. ";
  my %alarms = getSonosAlarm(getJohannesSchlafzimmer());
	my %vorlesungen;
  my %termine;
	my $weckZeit = "";

	if($hour < 12){
		$weckZeit = $alarms{dayToString($wday)}{StartTime};
		%vorlesungen = getVorlesungen();
    %termine = getTermine();
	}
	else{
		$weckZeit = $alarms{dayToString($wday + 1)}{StartTime};
		%vorlesungen = getVorlesungen("tomorrow");
    %termine = getTermine("tomorrow");
	}

  my $ersterTerm = minTime($vorlesungen{0}{beginn}, $termine{0}{beginn});
  return $ansage."Achtung! Trotz anstehendem Termin wurde kein Wecker gestellt. " if(defined($ersterTerm) and !defined($weckZeit));

  if(((time2dec(TU_Get_Difference($weckZeit, $ersterTerm)) < 1.2) or minTime($ersterTerm, $weckZeit) eq $ersterTerm) and defined($ersterTerm)){
    if($ersterTerm eq $vorlesungen{0}{beginn}){
      $ansage .= "Achtung! Ihre Vorlesung in ".$vorlesungen{0}{titel}." beginnt um ".substr($vorlesungen{0}{beginn},0,5).". ";
    }
    if($ersterTerm eq $termine{0}{beginn}){
      $ansage .= "Achtung! Ich habe Ihren Kalender getscheckt, morgen um ".substr($termine{0}{beginn},0,5)." ist ".$termine{0}{titel}.". ";
    }
    return $ansage."Der Wecker wurde allerdings auf ".substr($weckZeit,0,5)." gestellt. Das ist in ".(int(substr(TU_Get_Difference(CurrentTime(), $weckZeit),0,2)))." Stunden und ".(int(substr(TU_Get_Difference(CurrentTime(), $weckZeit),3,2)))." Minuten.";
  }

	if($weckZeit ne ""){
		$ansage .= "Der Wecker wurde auf ".substr($weckZeit,0,5)." gestellt. ";
		$ansage .= "Das ist in ".(int(substr(TU_Get_Difference(CurrentTime(), $weckZeit),0,2)))." Stunden und ".(int(substr(TU_Get_Difference(CurrentTime(), $weckZeit),3,2)))." Minuten.";
	}
	else{
		$ansage .= "Es ist kein Wecker gestellt.";
	}
  return $ansage;
}

sub SonosSpeak($$;$$$){
	my ($roomParam, $text, $volume, $language, $modus) = @_;
	$volume //= "30";
	$language //="de-DE";
	$modus //="Speak1";
  my (@rooms, @allRooms);

  @allRooms = devspec2array("TYPE=SONOSPLAYER");

  if ($roomParam eq "all"){
    @rooms = @allRooms;
  }
  else{
    @rooms = split(/\,/, $roomParam);
  }

  for my $i (reverse 0 .. $#rooms){
    $rooms[$i] = makeSonosParameter($rooms[$i]);
    splice(@rooms, $i) if(!defined($defs{$rooms[$i]}));
    if($rooms[$i] eq "Sonos_Wohnzimmer" and Value("STV_Steuerung") eq "Ein"){
			fhem("set STV_Steuerung Pause");
			InternalTimer(gettimeofday() + (int(length($text)/6)), "fhem", "set STV_Steuerung Play");
		}
  }

  if(scalar @rooms > 1){
    my $oldGroups = fhem("get Sonos Groups");
    fhem("set Sonos Groups [".join(",",@rooms)."]");
    InternatTimer(gettimeofday() + (int(length($text)/6)) + 4, "fhem", "set Sonos Groups $oldGroups");
    return fhem("sleep 1.5;set $rooms[0] $modus $volume $language $text");
  }
  elsif(scalar @rooms == 1){
    return fhem("set $rooms[0] $modus $volume $language $text")
  }

	return 0;
}

sub getSonosAlarm($){
	my ($room) = makeSonosParameter (shift);
	my @days = ("Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday");
	my @IDs = split(/\,/, ReadingsVal($room, "AlarmListIDs", 0));
	my $AlarmList = eval(ReadingsVal($room, "AlarmList", "{}"));
	my %Alarms = ();

	foreach my $day (@days){
		foreach my $ID (@IDs){
			if (int($AlarmList->{$ID}{"Recurrence_".$day}) == 1){
				$Alarms{$day}{StartTime} = $AlarmList->{$ID}{StartTime} if ($AlarmList->{$ID}{Enabled} eq '1');
			}
		}
	}
	return %Alarms;
}

sub getSonosAlarmDay($$){
	my ($room, $day) = (makeSonosParameter(shift), shift);
	my %alarms = getSonosAlarm($room);
	$day -= 7 while($day >= 7);
	return $alarms{dayToString($day)}{StartTime};
}

sub getSonosLiedDesMonats() {

	my $txt = fhem("get FileLog_Sonos_Wohnzimmer Sonos_Wohnzimmer-2016-02.log 2016-02-05 2016-02-06 4:::");
	fhem("set test ".$txt);

}

sub playYoutubeSonos($$){
	my ($room, $link) = (makeSonosParameter (shift), shift);
	$room =~tr/\///d;

	fhem("\"/opt/fhem/youtubeAudio/youtube.sh $room $link\"");
}

sub SON_tguPlayYoutube($$){
  my ($link, $resident) = @_;
  fhem("msg $resident |Sonos| Sieht nach einem YouTube-Video aus. In welchem Raum soll ich abspielen?".TGU_generateClickAnswers("Wohnzimmer","Schlafzimmer","Abbruch"));
  TGU_registerTelegramListener($resident, $link);
}

sub SON_tguPlayYoutubeAnswer($$$){
  my ($answer, $resident, $link) = @_;
  if($answer eq "Wohnzimmer" or $answer eq "Schlafzimmer"){
	  fhem("msg $resident |Sonos| Starte Download, das wird einen Moment dauern...");
	  SonosWenigerBass($answer, $resident);
	  playYoutubeSonos($answer, $link);
	}
	elsif(lc($answer) eq "abbruch"){
		fhem("msg $resident |Sonos| Ok, ich lasse es bleiben.");
	}
	else{
		fhem("msg $resident |Sonos| Der angegebene Raum ist ungültig!");
	}
}

sub playSchallplatte($){
	my ($room) = makeSonosParameter (shift);
	fhem("set $room PlayURI http://192.168.178.65:8000/raspi");
}

sub playTagesschau($$;$){
	my ($room, $version, $volume) = @_;
	$room = makeSonosParameter ($room);
	$volume = 33 unless $volume;
	if($version eq "lang" or $version eq "15"){
		fhem("set $room PlayURITemp ".Value("rss_tagesschau15min")." $volume");
		return 1;
	}
	elsif($version eq "kurz" or $version eq "100"){
		fhem("set $room PlayURITemp //SYNOLOGY-NAS/Sonos-Speak/tagesschau100sek.wav $volume");
		return 1;
	}
	return "wrong parameter, use \"kurz\" or \"lang\"";
}

sub SON_playWarnung($){
	my ($room) = makeSonosParameter(shift);
	fhem("set $room PlayURITemp //SYNOLOGY-NAS/Sonos-Speak/SonosWarnung.mp3 50");
}

sub makeSonosParameter($){
	return makeDeviceParameter(ucfirst(shift), "Sonos_");
}


sub SON_getGroupsRG() {
	my $groups = CommandGet(undef, SONOS_getSonosPlayerByName(undef)->{NAME}.\
		' Groups');
	
	my $result = '';
	my $i = 0;
	while ($groups =~ m/\[(.*?)\]/ig) {
		my @member = split(/, /, $1);
		@member = map { my $elem = $_; $elem = FW_makeImage('icoSONOSPLAYER_icon-'.\
			ReadingsVal($elem, 'playerType', '').'.png', '', '').ReadingsVal($elem,\
			'roomNameAlias', $elem); $elem; } @member;
		
		$result .= '<li>'.++$i.'. Gruppe:<ul style="list-style-type: none; \
			padding-left: 0px;"><li>'.join('</li><li>', @member).'</li></ul></li>';
	}
	return '<ul>'.$result.'</ul>';
}

sub SonosWenigerBass($$){
	my ($room, $resident) = (makeSonosParameter (shift), shift);
  return if (exitOnInterval(3600));
  my $time = CurrentTime();
  if ((maxTime($time, "23:00:00") eq $time or minTime($time, "06:00:00") eq $time) and istRosiHome()){
  	TGU_registerTelegramListener($resident, $room);
  	fhem("msg $resident |Sonos| Es ist spät, soll ich den Bass herunterdrehen?".TGU_generateClickAnswers("Ja","Nein"));
  }
}

sub SonosWenigerBassAnswer($$$){
  my ($answer, $resident, $room) = (shift, shift, makeSonosParameter (shift));
  if($answer eq "Ja"){
    fhem("msg $resident |Sonos| OK, ich drehe den Bass herunter. Morgen ist alles wieder normal.");
    fhem("set $room Bass -7");
    InternalTimer(gettimeofday() + 2400, "fhem", "set $room Bass 0");
  }
  elsif($answer eq "Nein"){
    TGU_registerTelegramListener($resident);
    fhem("msg $resident |Sonos| OK, es bleibt alles so, wies hier ist.");
  }
}

sub SonosWenigerBassAnswerAnswer($$){
  my ($answer, $resident) = @_;
  if (lc($answer) eq "bleib doch ruhig"){
    fhem("msg $resident |Sonos| NEIN JETZT HALT DEINE SCHNAUTZE! DU OBER- äh- ZICKE!");
  }
}

sub SON_askForRandomYoutubeVideo($){
  my ($resident) = shift;
  fhem("msg $resident |Sonos| Soll ich noch ein zufälliges Video abspielen?".TGU_generateClickAnswers("Ja","Liste","Nein"));
  TGU_registerTelegramListener($resident);
}

sub SON_askForRandomYoutubeVideoAnswer($$;$){
  my ($answer, $resident, $playlistID) = @_;
  if ($answer eq "Ja"){
    my $video;
    if ($playlistID){
      $video = GAU_getRandomYoutubeVideoFromPlaylist($playlistID);
    }
    else{
      $video = GAU_getRandomYoutubeVideoFromPlaylist();
    }
	  fhem('set telegramBot message @Johannes_Nill Markdown *Sonos:* '.$video);
    fhem("msg $resident |Sonos| ist das in Ordnung?".TGU_generateClickAnswers("Ja","Anderes","Liste","Abbruch"));
    TGU_registerTelegramListener($resident, $video);
  }
  elsif ($answer eq "Liste"){
  	SON_askForRandomYoutubeVideoListPlaylists($resident);
  }
  else{
    fhem("msg $resident |Sonos| Ok, dann lasse ich es bleiben.");
  }
}

sub SON_askForRandomYoutubeVideoListPlaylists($){
	my ($resident) = @_;
	fhem("msg $resident |Sonos| Hier ein paar Playlists: ".TGU_generateClickAnswers(GAU_getTitlesOfYoutubePlaylists()));
	TGU_registerTelegramListener($resident);
}

sub SON_askForRandomYoutubeVideoListPlaylistsAnswer($$){
  my ($answer, $resident) = @_;
  GAU_undefVideos(undef);
  SON_askForRandomYoutubeVideoAnswer("Ja", $resident, GAU_getPlaylistIdFromIndex($answer-1));
}

sub SON_askForRandomYoutubeVideoAnswerAnswer($$$){
  my ($answer, $resident, $video) = @_;
  if ($answer eq "Ja"){
    fhem("msg $resident |Sonos| Starte Download, das wird einen Moment dauern...");
    playYoutubeSonos(getJohannesSchlafzimmer(), $video);
    fhem("set ".makeSonosParameter(getJohannesSchlafzimmer())." Volume 2");
  }
  if ($answer eq "Anderes"){
    SON_askForRandomYoutubeVideoAnswer("Ja", $resident);
  }
  if ($answer eq "Liste"){
  	SON_askForRandomYoutubeVideoListPlaylists($resident);
  }
  if ($answer eq "Abbruch"){
    fhem("msg $resident |Sonos| Ok, dann lasse ich es bleiben.");
  }
}














1;
