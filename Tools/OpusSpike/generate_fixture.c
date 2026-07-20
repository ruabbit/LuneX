#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <opus_multistream.h>

typedef struct {
  const char *name;
  int channels;
  int streams;
  int coupled_streams;
  int bitrate;
} profile_t;

static const profile_t profiles[] = {
  {"stereo", 2, 1, 1, 96000},
  {"surround51", 6, 4, 2, 256000},
  {"surround51-hq", 6, 6, 0, 1536000},
  {"surround71", 8, 5, 3, 450000},
  {"surround71-hq", 8, 8, 0, 2048000},
};

static const profile_t *find_profile(const char *name) {
  const size_t count = sizeof(profiles) / sizeof(profiles[0]);
  for (size_t index = 0; index < count; ++index) {
    if (strcmp(name, profiles[index].name) == 0) {
      return &profiles[index];
    }
  }
  return NULL;
}

int main(int argc, char **argv) {
  if (argc != 2) {
    fprintf(stderr, "usage: %s <stereo|surround51|surround51-hq|surround71|surround71-hq>\n", argv[0]);
    return EXIT_FAILURE;
  }

  const profile_t *profile = find_profile(argv[1]);
  if (profile == NULL) {
    fprintf(stderr, "unknown profile: %s\n", argv[1]);
    return EXIT_FAILURE;
  }

  uint8_t mapping[8];
  for (int channel = 0; channel < profile->channels; ++channel) {
    mapping[channel] = (uint8_t) channel;
  }

  int error = OPUS_OK;
  OpusMSEncoder *encoder = opus_multistream_encoder_create(
    48000,
    profile->channels,
    profile->streams,
    profile->coupled_streams,
    mapping,
    OPUS_APPLICATION_RESTRICTED_LOWDELAY,
    &error
  );
  if (encoder == NULL || error != OPUS_OK) {
    fprintf(stderr, "encoder creation failed: %s\n", opus_strerror(error));
    return EXIT_FAILURE;
  }

  opus_multistream_encoder_ctl(encoder, OPUS_SET_BITRATE(profile->bitrate));
  opus_multistream_encoder_ctl(encoder, OPUS_SET_VBR(0));

  enum { frames = 240, max_channels = 8, max_packet_size = 1400 };
  float pcm[frames * max_channels] = {0};
  for (int frame = 0; frame < frames; ++frame) {
    for (int channel = 0; channel < profile->channels; ++channel) {
      const double frequency = 997.0 + (channel * 37.0);
      pcm[(frame * profile->channels) + channel] =
        (float) (0.08 * sin(2.0 * M_PI * frequency * frame / 48000.0));
    }
  }

  unsigned char packet[max_packet_size];
  const int bytes = opus_multistream_encode_float(
    encoder,
    pcm,
    frames,
    packet,
    sizeof(packet)
  );
  opus_multistream_encoder_destroy(encoder);
  if (bytes < 0) {
    fprintf(stderr, "encoding failed: %s\n", opus_strerror(bytes));
    return EXIT_FAILURE;
  }
  if (fwrite(packet, 1, (size_t) bytes, stdout) != (size_t) bytes) {
    fprintf(stderr, "writing packet failed\n");
    return EXIT_FAILURE;
  }
  return EXIT_SUCCESS;
}
