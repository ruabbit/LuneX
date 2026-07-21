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
  if (argc != 2 && argc != 3) {
    fprintf(
      stderr,
      "usage: %s <stereo|surround51|surround51-hq|surround71|surround71-hq> [packet-index]\n",
      argv[0]
    );
    return EXIT_FAILURE;
  }

  const profile_t *profile = find_profile(argv[1]);
  if (profile == NULL) {
    fprintf(stderr, "unknown profile: %s\n", argv[1]);
    return EXIT_FAILURE;
  }

  long packet_index = 0;
  if (argc == 3) {
    char *end = NULL;
    packet_index = strtol(argv[2], &end, 10);
    if (end == argv[2] || *end != '\0' || packet_index < 0 || packet_index > 31) {
      fprintf(stderr, "packet index must be between 0 and 31\n");
      return EXIT_FAILURE;
    }
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
  unsigned char packet[max_packet_size];
  for (long encoded_index = 0; encoded_index <= packet_index; ++encoded_index) {
    for (int frame = 0; frame < frames; ++frame) {
      for (int channel = 0; channel < profile->channels; ++channel) {
        const double frequency = 997.0 + (channel * 37.0);
        const long absolute_frame = (encoded_index * frames) + frame;
        pcm[(frame * profile->channels) + channel] =
          (float) (0.08 * sin(2.0 * M_PI * frequency * absolute_frame / 48000.0));
      }
    }

    const int bytes = opus_multistream_encode_float(
      encoder,
      pcm,
      frames,
      packet,
      sizeof(packet)
    );
    if (bytes < 0) {
      fprintf(stderr, "encoding failed: %s\n", opus_strerror(bytes));
      opus_multistream_encoder_destroy(encoder);
      return EXIT_FAILURE;
    }
    if (encoded_index == packet_index
        && fwrite(packet, 1, (size_t) bytes, stdout) != (size_t) bytes) {
      fprintf(stderr, "writing packet failed\n");
      opus_multistream_encoder_destroy(encoder);
      return EXIT_FAILURE;
    }
  }
  opus_multistream_encoder_destroy(encoder);
  return EXIT_SUCCESS;
}
