#ifndef LUNEX_ENET_TEST_SERVER_H
#define LUNEX_ENET_TEST_SERVER_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef struct LuneXENetTestServer LuneXENetTestServer;

LuneXENetTestServer *lunex_enet_test_server_create(
    uint8_t channel_count,
    bool drop_first_datagram
);

uint16_t lunex_enet_test_server_port(const LuneXENetTestServer *server);

bool lunex_enet_test_server_wait_for_connect(
    const LuneXENetTestServer *server,
    uint32_t expected_connect_data,
    uint8_t expected_channel_count,
    uint32_t timeout_milliseconds
);

bool lunex_enet_test_server_wait_for_receive(
    const LuneXENetTestServer *server,
    uint8_t expected_channel_id,
    const uint8_t *expected_payload,
    size_t expected_payload_length,
    uint32_t timeout_milliseconds
);

bool lunex_enet_test_server_wait_for_disconnect(
    const LuneXENetTestServer *server,
    uint32_t timeout_milliseconds
);

void lunex_enet_test_server_destroy(LuneXENetTestServer *server);

#endif
