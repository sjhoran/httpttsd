#!/usr/bin/perl -w

use strict;
use Win32::OLE;
use HTTP::Daemon;
use HTTP::Status;
use CGI;
use Getopt::Long;

# Set global defaults for audio output settings
my ($bits,$channels,$samplerate) = (8, 1, 22050);

# Default host and port for HTTP server
my ($host,$port) = ("0.0.0.0", 8256);
# Allow overriding of default host/port
my $clargs = GetOptions("port=i" => \$port, "host=s" => \$host);

sub tts_sed {
    my $_ = shift;

    # Perform the following substitutions beforehand
    #s/\bO:\)+/ angelic smiley face /g;
    #s/:D\b/ big smiley face /g;
    #s/(:\)+|:-\)+|:o\)+|\(+c:)/ smiley face /gi;
    #s/(\;\)+|\;-\)+|\;o\)+)/ winking smiley face /gi;
    #s/(=\)+|=-\)+|=o\)+)/ smiley face /gi;
    #s/(:\(+|:-\(+|:o\(+)/ frowny face /gi;
    #s/(=\(+|=-\(+|=o\(+)/ frowny face /gi;

    return $_;
}

sub get_voices {
    my $tts = shift;
    my %v;
    for (0..($tts->GetVoices->Count()-1)) {
        my $vd = $tts->GetVoices->Item($_)->GetDescription;
        $v{"$vd"} = $_;
    }
    return %v;
}

sub tts2wav() {
    my ($tts,$voiceid,$rate,$text) = @_;
    $tts->{Voice} = $tts->GetVoices->Item($voiceid);
    $tts->{Rate} = $rate;

    my %fmt;

    $fmt{'chans'} = { 1 => 0, 2 => 1 };
    $fmt{'bits'} = { 8 => 0, 16 => 2 };
    $fmt{'freq'} = {
        8000 => 4, 11025 => 8, 12000 => 12,
        16000 => 16, 22050 => 20, 24000 => 24,
        32000 => 28, 44100 => 32, 48000 => 36
    };
    my $outfmt = $fmt{'chans'}{$channels};
    $outfmt += $fmt{'bits'}{$bits};
    $outfmt += $fmt{'freq'}{$samplerate};
    my $type = Win32::OLE->new("SAPI.SpAudioFormat");
    $type->{Type} = $outfmt;

    my $stream = Win32::OLE->new("SAPI.SpMemoryStream");
    $stream->{Format} = $type;
    $tts->{AudioOutputStream} = $stream;

    $tts->Speak($text, 1);
    $tts->WaitUntilDone(-1);

    # pull in raw audio data to work with
    my $contents = $stream->GetData();

    # define vars to use when creating header
    my $len = length($contents);

    # Return speech of "null" if requested text resulted in a 0 byte.
    # audio stream. Make sure text isn't "null" to avoid infinite loop.
    if (!$len && $text ne "null") {
        return tts2wav($tts, $voiceid, $rate, "null");
    }

    # Return a ready to use .wav file for output or any other use
    return "RIFF" . pack('l', $len+36) . 'WAVEfmt '
        . pack('l', 16) . pack('s', 1)
        . pack('s', $channels) . pack('l', $samplerate)
        . pack('l', $samplerate*$bits/8)
        . pack('s', $channels*$bits/8) . pack('s', $bits)
        . 'data' . pack('l', $len) . $contents;
}

sub res {
    my ($contype,$resdata) = @_;
    HTTP::Response->new(
        RC_OK, OK => [ 'Content-Type' => $contype, "Content-Length" => length($resdata) ], $resdata
    )
}

sub create_web_form {
    my @voicelist = @_;
    my $cgi = CGI->new();
    return $cgi->start_html("httpttsd demonstration form")
        . '<form action="/speak.wav" method="post">'
        . 'Text to speak: ' . $cgi->textfield('text') . '<br />'
        . 'Voice: ' . $cgi->popup_menu('voice', \@voicelist) . '<br />'
        . 'Rate: ' . $cgi->popup_menu('rate', [0..10,-10..-1])
        . '<br />' . $cgi->submit . '</form>' . $cgi->end_html;
}

sub httpd {
    my ($ttshost,$ttsport) = @_;

    # Initiate text-to-speech object and build a hash of voices
    my $ttsobj = Win32::OLE->new("Sapi.SpVoice");
    my %voices = &get_voices($ttsobj);

    # Let's have a voicelist ready for use later.
    my @voicelist = (("Host Server's Default Voice"),sort(keys %voices));

    # Let's build the HTML form we'll send on invalid requests
    my $form = create_web_form(@voicelist);

    my $d = HTTP::Daemon->new(LocalPort => $ttsport, LocalAddr => $ttshost) || die;
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
                # Are we getting an SSML formatted chunk of text?
                # If we are, do nothing. If not, let's replace < and > to be safe.
                if (!$cgi->param('ssml')) {
                    $text = tts_sed($text);
                    $text =~ s/</ less than /g;
                    $text =~ s/>/ greater than /g;
                }

                # if we have voice, rate and text, spit out a wav, else 403
                if ($voice ne '' and $rate >= -10 and $rate <= 10 and $text ne '') {
                    my $vid = $voices{$voice} ? $voices{$voice} : 0;
                    print "\tOK. Sending wav for $voice($vid)/$rate/$text\n";
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
                $c->send_response(res ('text/html', $form));
            }
        }
        $c->close;
        undef($c);
    }
}

# Start our daemon
&httpd($host,$port);

