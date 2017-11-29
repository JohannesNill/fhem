##############################################
# $Id: 99_LightUtils.pm 7570 2016-12-10 18:31:44Z JohannesNill $
#
# Save this file as 99_myUtils.pm, and create your own functions in the new
# file. They are then available in every Perl expression.

package main;

use strict;
use warnings;
use POSIX;

sub
LightUtils_Initialize($$)
{
  my ($hash) = @_;
}

sub setRGBWWQueue($$){
	my ($device) = shift;
	my (@commands) = split ("#",shift);

	foreach my $command (@commands){
		fhem("set $device $command q");
	}
}

sub setRGBWW {
  my %hash = %{(shift)};
  my $val;
  return 0 unless $hash{device};
  $hash{time} = 0.5 unless $hash{time};
  $hash{fun_animation} = 0 unless $hash{fun_animation};
  $val = 100 if $hash{command} eq "on";
  $val = 0 if $hash{command} eq "off";
  $hash{command} = "hsv ".$hash{hsv} if(defined($hash{hsv}));
  $hash{command} = "rgb ".$hash{rgb} if(defined($hash{rgb}));
  $hash{count} = 3 unless $hash{count};
  $hash{command} = "rgb FFFFFF" if ($hash{command} eq "on");
  if((($hash{fun_animation} > 1 and int(rand($hash{fun_animation})) == 0) or $hash{fun_animation} == 1)){
    my $oldVal = ReadingsVal($hash{device},"val","");
    my @fun_rgb = ();
	$val = (split(",", $hash{hsv}))[2] if(defined($hash{hsv}));
	$val = getValFromRgb($hash{rgb}) if(defined($hash{rgb}));
    if($oldVal >= $val){
      for (my $i = $hash{count}; $i > 0; $i--){
        push (@fun_rgb, "hsv ".int(rand(360)).','.(30 + int(rand(30))).','.($val+(($oldVal-$val)*($i/$hash{count}))).' '.($hash{time}/(2*$hash{count})));
      }
    }
    if($oldVal < $val){
      for (my $i = 1; $i <= $hash{count}; $i++){
        push (@fun_rgb, "hsv ".int(rand(360)).','.(30 + int(rand(30))).','.($oldVal+(($val-$oldVal)*($i/$hash{count}))).' '.($hash{time}/(2*$hash{count})));
      }
    }
    setRGBWWQueue($hash{device},join("#",@fun_rgb).'#'.$hash{command}.' '.($hash{time}/2.0));
  }
  else{
    fhem("set ".$hash{device}.' '.$hash{command}.' '.$hash{time});
  }

}

#sub setRGBWW {
#  my %hash = %{(shift)};
#  $hash{device} = "rgbw_JohannesWohnDeckenlampe" unless $hash{device};
#  $hash{time} = 0.5 unless $hash{time};
#  $hash{fun_animation} = 0 unless $hash{fun_animation};
#  $hash{command} = "val ".$hash{val} if(defined($hash{val}));
#  $hash{val} = 100 if $hash{command} eq "on";
#  $hash{val} = 0 if $hash{command} eq "off";
#  $hash{val} = getValFromRgb($hash{command}) unless $hash{val};
#  $hash{count} = 3 unless $hash{count};
#  $hash{command} = "rgb FFFFFF" if ($hash{command} eq "on");
#  if((($hash{fun_animation} > 1 and int(rand($hash{fun_animation})) == 0) or $hash{fun_animation} == 1) and (defined($hash{val}))){
#    my $oldVal = ReadingsVal($hash{device},"val","");
#    my @fun_rgb = ();
#    if($oldVal >= $hash{val}){
#      for (my $i = $hash{count}; $i > 0; $i--){
#        push (@fun_rgb, "rgb ".generateRandomColor(int(($hash{val}+(($i/$hash{count})*($oldVal-$hash{val})))*(16/100))).' '.($hash{time}/(2*$hash{count})));
#      }
#    }
 #   if($oldVal < $hash{val}){
#      for (my $i = 1; $i <= $hash{count}; $i++){
#        push (@fun_rgb, "rgb ".generateRandomColor(int(($oldVal+(($i/$hash{count})*($hash{val}-$oldVal)))*(16/100))).' '.($hash{time}/(2*$hash{count})));
#      }
#    }
#    setRGBWWQueue($hash{device},join("#",@fun_rgb).','.$hash{command}.' '.($hash{time}/2.0));
#  }
 # else{
#    fhem("set ".$hash{device}.' '.$hash{command}.' '.$hash{time});
#  }
#}

sub setRGBWWAmbient($){
	my ($device) = shift;
	if(getKeyValue("LU_RGBWWAmbientEnable_$device") == "1"){
		my @values;
		my $period = getKeyValue("LU_RGBWWAmbientPeriod_$device");
		my $iterations = 32;
		push(@values, "hue ".generateRandomHueAmbient()." $period") for(1 .. $iterations);
		setRGBWWQueue($device, join("#",@values));
		InternalTimer(gettimeofday() + (($iterations*$period) - 1), "setRGBWWAmbient", $device);
	}
}

sub RGBWWAmbientStart($;$$){
	my ($device, $period, $sat) = @_;
	$period //= "20";
	$sat //= "50";
	fhem("set $device sat $sat q");
	setKeyValue("LU_RGBWWAmbientEnable_$device", "1");
	setKeyValue("LU_RGBWWAmbientPeriod_$device", $period);
	setRGBWWAmbient($device);
}

sub RGBWWAmbientStop($){
	my ($device) = shift;
	setKeyValue("LU_RGBWWAmbientEnable_$device", "0");
	fhem("set $device rgb ".ReadingsVal($device, "rgb", ""));
}

sub msg_rgbw_JohannesWohnFlash(;$){
	my ($farbe) = @_;
	$farbe //= "weiß";
	my $status = ReadingsVal("rgbw_JohannesWohnDeckenlampe","rgb","000000");
	$farbe = getRgbFromText($farbe);
	setRGBWWQueue("rgbw_JohannesWohnDeckenlampe","rgb $farbe 0.6#rgb $status 0.9");
}

sub playRandomRGBWW($$$){
	my ($device,$anzahl,$lange) = @_;
	my @commands;

	push(@commands,"rgb ".generateRandomColor()." 1".$lange*rand()) for (1..$anzahl);
	setRGBWWQueue($device, join("|",@commands));
}

sub WakeUpRGBWW($$){
	my ($device, $duration) = @_;
	my $stepTime = int($duration/4);
	setRGBWWQueue($device, "hsv 0,100,0 0.1#hsv 5,95,25 $stepTime#hsv 10,80,50 $stepTime#hsv 15,55,75 $stepTime#hsv 60,0,100 $stepTime");
}

sub generateRandomColor(;$){
  my ($max) = shift;
  $max = 16 unless $max;
	my $code;
	$code .= generateRandomHex($max) for (1..6);
	return $code
}

sub generateRandomHex(;$){
  my ($max) = shift;
  $max = 16 unless $max;
  return uc(sprintf("%x", rand $max));
}

sub generateRandomHueAmbient(){
	my $hue = int(rand(180)) - 60;
	$hue += 360 if($hue < 0);
	return $hue;
}

sub getValFromRgb($){
  my ($rgb) = shift;
  #return 0 if(index($rgb,"rgb") <= -1);
  #$rgb = substr($rgb, 4,6);
  my ($r, $g, $b) = (hex(substr($rgb,0,2)), hex(substr($rgb,2,2)), hex(substr($rgb,4,2)));
  return int(($r*100.0)/255) if($r >= $g and $r >= $b);
  return int(($g*100.0)/255) if($g > $r and $g > $b);
  return int(($b*100.0)/255) if($b > $g and $b > $r);
}

1;
