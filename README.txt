httpttsd
--------

What is it?

httpttsd is a stand-alone text-to-speech daemon written in Perl, and intended
for deployment on Microsoft Windows systems.

The server accepts standard HTTP connections on port 8256 and allows a client
to request a wav file containing the provided text converted to speech using
the specified voice and speech rate.

How do I run it?

I developed and run this script under cygwin, but it reported runs with
Strawberry Perl.

You'll require the Win32::OLE and the HTTP::Daemon perl modules installed.

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

To get a list of available voices, you can visit http://10.0.0.1:8256/voices

Why was httpttsd written?

I wrote httpttsd to provide high quality text-to-speech to non-windows systems
running on the same local network. In my case, specifically for use in
conjunction with XBMC TTS, which adds screen-reader-esque text-to-speech
functionality to the XBMC media centre.

