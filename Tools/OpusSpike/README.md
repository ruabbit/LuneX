# AudioToolbox Opus spike

This isolated macOS executable verifies whether Apple's system Opus decoder can
consume one raw packet in the same post-RTP form delivered by the Moonlight audio
receive path. The checked-in input is a fully synthetic 5 ms stereo packet, not a
host capture.

```sh
mkdir -p build/opus-spike
xcrun swiftc -warnings-as-errors \
  -framework AudioToolbox -framework CryptoKit \
  Tools/OpusSpike/main.swift \
  -o build/opus-spike/lunex-opus-spike
build/opus-spike/lunex-opus-spike \
  Tests/Fixtures/Moonlight/audio/stereo-5ms-opus.json
```

The spike does not play audio, contact a host, access Keychain, or add a
production dependency. It synthesizes an `OpusHead` magic cookie from negotiated
stream fields and asks `AudioConverter` for interleaved 16-bit PCM.

The first packet can produce fewer than the encoded 240 frames because the
system decoder applies codec priming. The spike requires a consistent positive
frame count and non-silent PCM; the production synchronization layer must not
assume a one-packet-to-one-output-buffer frame count.

`generate_fixture.c` is an optional development-only provenance tool. It uses a
locally installed libopus to create fully synthetic packets with Sunshine's
explicit stream, coupled-stream, bitrate, and identity-mapping profiles. It is
not part of any Xcode target and libopus is not a production dependency.
