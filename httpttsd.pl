#!/usr/bin/perl -w

use strict;
use Win32::OLE;

sub get_voices {
    my $tts = shift;
	my %v;
	for (0..($tts->GetVoices->Count()-1)) {
		my $vd = $tts->GetVoices->Item($_)->GetDescription;
		$v{$vd} = $_;
	}
	return %v;
}

sub tts2wav() {
    my ($tts,$voiceid,$rate,$text) = @_;
    $tts->{Voice} = $tts->GetVoices->Item($voiceid);
    $tts->{Rate} = $rate;

    # stereo = add 1
    # 16-bit = add 2
    # 8KHz = 4
    # 11KHz = 8
    # 12KHz = 12
    # 16KHz = 16
    # 22KHz = 20
    # 24KHz = 24
    # 32KHz = 28
    # 44KHz = 32
    # 48KHz = 36
    my $type = Win32::OLE->new("SAPI.SpAudioFormat");
    $type->{Type} = 22;

    my $stream = Win32::OLE->new("SAPI.SpMemoryStream");
    $stream->{Format} = $type;
    $tts->{AudioOutputStream} = $stream;

    $tts->Speak("$text", 1);
    $tts->WaitUntilDone(-1);

    # pull in raw audio data to work with
    my $contents = $stream->GetData();

    # define vars to use when creating header
    my $len = length($contents);
    my $samplerate = 22050;
    my $bits = 16;
    my $mode = 1;
    my $channels = 1;

    # Return a ready to use .wav file for output or any other use
    return "RIFF" . pack('l', $len+36) . 'WAVEfmt '
        . pack('l', $bits) . pack('s', $mode)
        . pack('s', $channels) . pack('l', $samplerate)
        . pack('l', $samplerate*$bits/8)
        . pack('s', $channels*$bits/8) . pack('s', $bits)
        . 'data' . pack('l', $len) . $contents;
}


my $ttsobj = Win32::OLE->new("Sapi.SpVoice");
my %voices = &get_voices($ttsobj);

sub get_voice_id {
	my ($vsn) = shift;
	my $vnum = $voices{"$vsn"};
	if ($vnum) {
		return $vnum;
	} else {
		return 0;
	}
}

# HTTP Daemon stuff
use HTTP::Daemon;
use HTTP::Status;
use CGI;

sub res {
    my ($contype,$resdata) = @_;
    HTTP::Response->new(
        RC_OK, OK => [ 'Content-Type' => $contype, "Content-Length" => length($resdata) ], $resdata
    )
}

# Let's have a voicelist ready for use later.
my @voicelist = (("Host Server's Default Voice"),sort(keys %voices));

my $d = HTTP::Daemon->new(LocalPort => 8256) || die;
print "Please contact me at: <URL:", $d->url, ">\n";
while (my $c = $d->accept) {
    while (my $r = $c->get_request) {
        if ($r->method eq 'POST' and $r->uri->path eq "/speak.wav") {
            # Let's feed the request into the CGI module so we can
            # work with the uri-encoded paramaters easily
            my $cgi = CGI->new( $r->content );

            my $voice = $cgi->param('voice') if (defined($cgi->param('voice')));
            my $rate = $cgi->param('rate') if (defined($cgi->param('rate')));
            my $text = $cgi->param('text') if (defined($cgi->param('text')));

            # if we have voice, rate and text, spit out a wav, else 403
            if ($voice ne '' and $rate >= -10 and $rate <= 10 and $text ne '') {
                print "\tOK. Sending wav for $text\n";
                my $vid = &get_voice_id($voice);
                $c->send_response(
                    res ('audio/x-wav', &tts2wav($ttsobj, $vid, $rate, $text))
                );
            } else {
                print "\tINVALID: One or more POST'd inputs was invalid.\n";
                $c->send_error(RC_FORBIDDEN)
            }
        } elsif ($r->method eq 'GET' and $r->uri->path eq '/voices') {
            print "\tOK: Client requested voicelist.\n";
            $c->send_response(res ('text/plain', join("\n", @voicelist)));
        } else {
            print "\tINVALID: Sending friendly HTML form page as reponse.\n";
            my $form = '
                <html><body><form method="post" action="/speak.wav">
                <label>Text to speak:
                    <input type="text" size="50" name="text" />
                </label>
                <br />
                <label>
                    Rate:
                    <select name="rate">
            ';
            $form .= "<option>$_</option>\n" for (0..10);
            $form .= '</select></label><br />
                <label>Voice:<select name="voice">';
            $form .= "<option>$_</option>\n" for (@voicelist);
            $form .= '
                </select><br /><input type="submit" value="Create WAV" />
                </body></html>
            ';
            $c->send_response(res ('text/html', $form));
        }
    }
    $c->close;
    undef($c);
}

