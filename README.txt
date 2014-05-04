httpttsd
--------

What is it?

httpttsd is a stand-alone text-to-speech daemon written in Perl, and intended
for deployment on Microsoft Windows systems.

The server accepts standard HTTP connections on port 8256 and allows a client
to request a wav file containing the provided text converted to speech using
the specified voice and speech rate.

How do I run it?

I developed and run this script under cygwin, but it reportedly runs with
Strawberry Perl. It was developed with Perl 5.14, but is expected to work
with newer and older versions.

You'll require the Win32::OLE and the HTTP::Daemon perl modules installed.

The script requires no command line arguments to run, but you may optionally
override the default bind address (0.0.0.0) and port (8256).

Usage: httpttsd.pl [--host <ip-address>] [--port <port-number>]

Example usage:

Upon running the server, it'll bind to the main IP address of the host system
on port 8256. For the below examples, we'll assume it's running on a machine
with the IP of 10.0.0.1

After starting the daemon, if you visit http://10.0.0.1:8256/ in your browser,
you'll be presented with a basic HTML form. You can use this form to test the
daemon.

To get a .wav out of the server, POST to http://10.0.0.1:8256/speak.wav with
these three variables:

    voice=<name of voice to use>
    rate=<speaking rate from -10 to 10>
    text=<text you want spoken>

And a wav file will be returned providing all the information was valid. If
you specify and unknown voice, the system's default voice will be used.

To avoid plain text being misinterpreted as SSML markup, < and > are replaced
with the literal strings " less than " and " greater than " respectively. If
you would like to provide SSML to the server, you can set the optional POST
variable "ssml" and set it to non-zero.

To get a list of available voices, you can visit http://10.0.0.1:8256/voices

Special Notes:

I have included a tts_sed() function which you can use to perform any
operations you desire on the text before it is converted to speech.

I have included commented out examples for handling various emoticons.

Please note that the tts_sed() function is bypassed for SSML text.

Why was httpttsd written?

I wrote httpttsd to provide high quality text-to-speech to non-windows systems
running on the same local network. In my case, specifically for use in
conjunction with XBMC TTS, which adds screen-reader-esque text-to-speech
functionality to the XBMC media centre.
