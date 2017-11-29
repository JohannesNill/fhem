##############################################
# $Id: 99_LightSpanningTreeUtils.pm 7570 2015-01-14 18:31:44Z JohannesNill $

package main;

use strict;
use warnings;
use POSIX;

my %trees;

sub LightSpanningTreeUtils_Initialize($$){
  my ($hash) = @_;

  %trees = (
      tree_1  => {
        name    => "Gang",
        licht   => "strg_LightGang",
        tuer_1  => {
          name    => "Tür JohannesWohn",
          kontakt => "door_JohannesWohn",
          raum    => {
            name    => "JohannesWohn",
            licht   => "rgbw_JohannesWohnDeckenlampe"
          }
        },
        tuer_2  => {
          name    => "Tür JohannesSchlaf",
          kontakt => "door_JohannesSchlaf",
          raum    => {
            name    => "JohannesSchlaf",
            licht   => "rgbw_JohannesSchlafBettbeleuchtung",
          }
        },
        tuer_3  => {
          name    => "Wohnungstüre",
          kontakt => "door_Wohnungstuere",
          raum    => {
            name    => "Treppenhaus",
            licht   => "au_Treppenhaus",
            tuer_1  => {
              name    => "Haustüre",
              kontakt => "door_Haustuere",
              raum    => {
                name    => "Außen",
                licht   => "strg_Haustuere",
              }
            }
          }
        }
      }
    );

}

sub LightSpanningTreeUtils_AutoSwitch($$){
  my ($device, $event) = @_;

  for my $tree (keys %trees){
    for my 
  }
}

sub searchForContact(%$){
  my (%hash) = %{(shift)};
  my ($kontakt) = shift;

  if($hash{kontakt} eq $kontakt){
    return 1;
  }
  return 0;

}

1;
