#include "LuneXENetTestServer.h"

#include <arpa/inet.h>
#include <enet/enet.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define LUNEX_TEST_MAX_PAYLOAD 256

struct LuneXENetTestServer {
    ENetHost *host;
    pthread_t thread;
    atomic_bool stopping;
    atomic_bool connected;
    atomic_bool received;
    atomic_bool disconnected;
    uint16_t port;
    uint32_t connect_data;
    uint8_t channel_count;
    uint8_t received_channel_id;
    uint8_t received_payload[LUNEX_TEST_MAX_PAYLOAD];
    size_t received_payload_length;
    bool drop_first_datagram;
};

static void sleep_one_millisecond(void) {
    const struct timespec interval = {.tv_sec = 0, .tv_nsec = 1000000};
    (void)nanosleep(&interval, NULL);
}

static bool wait_for_flag(
    const atomic_bool *flag,
    uint32_t timeout_milliseconds
) {
    for (uint32_t elapsed = 0; elapsed < timeout_milliseconds; ++elapsed) {
        if (atomic_load_explicit(flag, memory_order_acquire)) {
            return true;
        }
        sleep_one_millisecond();
    }
    return atomic_load_explicit(flag, memory_order_acquire);
}

static void discard_first_datagram(LuneXENetTestServer *server) {
    uint8_t bytes[ENET_PROTOCOL_MAXIMUM_MTU];
    ENetBuffer buffer = {.data = bytes, .dataLength = sizeof(bytes)};
    ENetAddress peer_address;
    ENetAddress local_address;

    while (!atomic_load_explicit(&server->stopping, memory_order_acquire)) {
        const int received = enet_socket_receive(
            server->host->socket,
            &peer_address,
            &local_address,
            &buffer,
            1
        );
        if (received > 0) {
            return;
        }
        sleep_one_millisecond();
    }
}

static void *service_server(void *context) {
    LuneXENetTestServer *server = context;
    if (server->drop_first_datagram) {
        discard_first_datagram(server);
    }

    while (!atomic_load_explicit(&server->stopping, memory_order_acquire)) {
        ENetEvent event;
        const int result = enet_host_service(server->host, &event, 10);
        if (result <= 0) {
            continue;
        }
        switch (event.type) {
        case ENET_EVENT_TYPE_CONNECT:
            server->connect_data = event.data;
            server->channel_count = (uint8_t)event.peer->channelCount;
            atomic_store_explicit(&server->connected, true, memory_order_release);
            break;
        case ENET_EVENT_TYPE_RECEIVE: {
            const size_t length = event.packet->dataLength;
            if (length <= sizeof(server->received_payload)) {
                server->received_channel_id = event.channelID;
                server->received_payload_length = length;
                memcpy(server->received_payload, event.packet->data, length);
                ENetPacket *echo = enet_packet_create(
                    event.packet->data,
                    length,
                    ENET_PACKET_FLAG_RELIABLE
                );
                if (echo != NULL) {
                    (void)enet_peer_send(event.peer, event.channelID, echo);
                    enet_host_flush(server->host);
                }
                atomic_store_explicit(&server->received, true, memory_order_release);
            }
            enet_packet_destroy(event.packet);
            break;
        }
        case ENET_EVENT_TYPE_DISCONNECT:
            atomic_store_explicit(&server->disconnected, true, memory_order_release);
            break;
        case ENET_EVENT_TYPE_NONE:
            break;
        }
    }
    return NULL;
}

LuneXENetTestServer *lunex_enet_test_server_create(
    uint8_t channel_count,
    bool drop_first_datagram
) {
    if (channel_count == 0 || enet_initialize() != 0) {
        return NULL;
    }

    LuneXENetTestServer *server = calloc(1, sizeof(*server));
    if (server == NULL) {
        enet_deinitialize();
        return NULL;
    }
    atomic_init(&server->stopping, false);
    atomic_init(&server->connected, false);
    atomic_init(&server->received, false);
    atomic_init(&server->disconnected, false);
    server->drop_first_datagram = drop_first_datagram;

    ENetAddress address;
    memset(&address, 0, sizeof(address));
    if (enet_address_set_host(&address, "127.0.0.1") != 0 ||
        enet_address_set_port(&address, 0) != 0) {
        free(server);
        enet_deinitialize();
        return NULL;
    }
    server->host = enet_host_create(AF_INET, &address, 1, channel_count, 0, 0);
    if (server->host == NULL) {
        free(server);
        enet_deinitialize();
        return NULL;
    }
    const struct sockaddr_in *bound_address =
        (const struct sockaddr_in *)&server->host->address.address;
    server->port = ntohs(bound_address->sin_port);
    if (server->port == 0 || pthread_create(&server->thread, NULL, service_server, server) != 0) {
        enet_host_destroy(server->host);
        free(server);
        enet_deinitialize();
        return NULL;
    }
    return server;
}

uint16_t lunex_enet_test_server_port(const LuneXENetTestServer *server) {
    return server == NULL ? 0 : server->port;
}

bool lunex_enet_test_server_wait_for_connect(
    const LuneXENetTestServer *server,
    uint32_t expected_connect_data,
    uint8_t expected_channel_count,
    uint32_t timeout_milliseconds
) {
    return server != NULL &&
        wait_for_flag(&server->connected, timeout_milliseconds) &&
        server->connect_data == expected_connect_data &&
        server->channel_count == expected_channel_count;
}

bool lunex_enet_test_server_wait_for_receive(
    const LuneXENetTestServer *server,
    uint8_t expected_channel_id,
    const uint8_t *expected_payload,
    size_t expected_payload_length,
    uint32_t timeout_milliseconds
) {
    return server != NULL &&
        expected_payload != NULL &&
        expected_payload_length <= LUNEX_TEST_MAX_PAYLOAD &&
        wait_for_flag(&server->received, timeout_milliseconds) &&
        server->received_channel_id == expected_channel_id &&
        server->received_payload_length == expected_payload_length &&
        memcmp(server->received_payload, expected_payload, expected_payload_length) == 0;
}

bool lunex_enet_test_server_wait_for_disconnect(
    const LuneXENetTestServer *server,
    uint32_t timeout_milliseconds
) {
    return server != NULL && wait_for_flag(&server->disconnected, timeout_milliseconds);
}

void lunex_enet_test_server_destroy(LuneXENetTestServer *server) {
    if (server == NULL) {
        return;
    }
    atomic_store_explicit(&server->stopping, true, memory_order_release);
    (void)pthread_join(server->thread, NULL);
    enet_host_destroy(server->host);
    free(server);
    enet_deinitialize();
}
