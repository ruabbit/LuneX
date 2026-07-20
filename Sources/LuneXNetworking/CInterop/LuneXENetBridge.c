#include "LuneXENetBridge.h"

#include <enet/enet.h>
#include <stdlib.h>
#include <string.h>

struct LuneXENetConnection {
    ENetHost *host;
    ENetPeer *peer;
    uint8_t channelCount;
};

static void set_result(LuneXENetResult *result, LuneXENetResult value) {
    if (result != NULL) {
        *result = value;
    }
}

static void destroy_connection(LuneXENetConnection *connection) {
    if (connection == NULL) {
        return;
    }
    if (connection->peer != NULL) {
        enet_peer_disconnect_now(connection->peer, 0);
        connection->peer = NULL;
    }
    if (connection->host != NULL) {
        enet_host_destroy(connection->host);
        connection->host = NULL;
    }
    free(connection);
    enet_deinitialize();
}

LuneXENetConnection *lunex_enet_connect(
    const char *host,
    uint16_t port,
    uint8_t channelCount,
    uint32_t connectData,
    uint32_t timeoutMilliseconds,
    LuneXENetResult *result
) {
    if (host == NULL || host[0] == '\0' || port == 0 || channelCount == 0 ||
        timeoutMilliseconds == 0) {
        set_result(result, LUNEX_ENET_ERROR_INVALID_ARGUMENT);
        return NULL;
    }
    if (enet_initialize() != 0) {
        set_result(result, LUNEX_ENET_ERROR_INITIALIZATION);
        return NULL;
    }

    LuneXENetConnection *connection = calloc(1, sizeof(*connection));
    if (connection == NULL) {
        enet_deinitialize();
        set_result(result, LUNEX_ENET_ERROR_INITIALIZATION);
        return NULL;
    }

    ENetAddress remoteAddress;
    memset(&remoteAddress, 0, sizeof(remoteAddress));
    if (enet_address_set_host(&remoteAddress, host) != 0 ||
        enet_address_set_port(&remoteAddress, port) != 0) {
        destroy_connection(connection);
        set_result(result, LUNEX_ENET_ERROR_RESOLUTION);
        return NULL;
    }

    connection->host = enet_host_create(
        remoteAddress.address.ss_family,
        NULL,
        1,
        channelCount,
        0,
        0
    );
    if (connection->host == NULL) {
        destroy_connection(connection);
        set_result(result, LUNEX_ENET_ERROR_HOST_CREATION);
        return NULL;
    }
    connection->channelCount = channelCount;

    (void)enet_socket_set_option(connection->host->socket, ENET_SOCKOPT_QOS, 1);
    connection->peer = enet_host_connect(
        connection->host,
        &remoteAddress,
        channelCount,
        connectData
    );
    if (connection->peer == NULL) {
        destroy_connection(connection);
        set_result(result, LUNEX_ENET_ERROR_CONNECTION);
        return NULL;
    }

    ENetEvent event;
    const int serviceResult = enet_host_service(
        connection->host,
        &event,
        timeoutMilliseconds
    );
    if (serviceResult == 0) {
        destroy_connection(connection);
        set_result(result, LUNEX_ENET_ERROR_TIMEOUT);
        return NULL;
    }
    if (serviceResult < 0 || event.type != ENET_EVENT_TYPE_CONNECT) {
        destroy_connection(connection);
        set_result(result, LUNEX_ENET_ERROR_CONNECTION);
        return NULL;
    }

    enet_host_flush(connection->host);
    enet_peer_ping_interval(connection->peer, 100);
    enet_peer_timeout(connection->peer, 2, 10000, 10000);
    set_result(result, LUNEX_ENET_OK);
    return connection;
}

LuneXENetResult lunex_enet_send(
    LuneXENetConnection *connection,
    uint8_t channelID,
    const uint8_t *bytes,
    size_t length,
    bool reliable
) {
    if (connection == NULL || connection->host == NULL || connection->peer == NULL ||
        bytes == NULL || length == 0 || channelID >= connection->channelCount) {
        return LUNEX_ENET_ERROR_INVALID_ARGUMENT;
    }
    const enet_uint32 flags = reliable ? ENET_PACKET_FLAG_RELIABLE : 0;
    ENetPacket *packet = enet_packet_create(bytes, length, flags);
    if (packet == NULL) {
        return LUNEX_ENET_ERROR_SEND;
    }
    if (enet_peer_send(connection->peer, channelID, packet) != 0) {
        enet_packet_destroy(packet);
        return LUNEX_ENET_ERROR_SEND;
    }
    enet_host_flush(connection->host);
    return LUNEX_ENET_OK;
}

LuneXENetResult lunex_enet_service(
    LuneXENetConnection *connection,
    uint32_t timeoutMilliseconds,
    uint8_t *payloadBuffer,
    size_t payloadCapacity,
    LuneXENetEvent *event
) {
    if (connection == NULL || connection->host == NULL || event == NULL ||
        payloadBuffer == NULL || payloadCapacity == 0) {
        return LUNEX_ENET_ERROR_INVALID_ARGUMENT;
    }
    memset(event, 0, sizeof(*event));

    ENetEvent enetEvent;
    const int serviceResult = enet_host_service(
        connection->host,
        &enetEvent,
        timeoutMilliseconds
    );
    if (serviceResult < 0) {
        return LUNEX_ENET_ERROR_SERVICE;
    }
    if (serviceResult == 0) {
        event->type = LUNEX_ENET_EVENT_NONE;
        return LUNEX_ENET_OK;
    }

    event->channelID = enetEvent.channelID;
    event->data = enetEvent.data;
    switch (enetEvent.type) {
    case ENET_EVENT_TYPE_RECEIVE:
        event->type = LUNEX_ENET_EVENT_RECEIVE;
        event->payloadLength = enetEvent.packet->dataLength;
        if (enetEvent.packet->dataLength > payloadCapacity) {
            enet_packet_destroy(enetEvent.packet);
            return LUNEX_ENET_ERROR_PAYLOAD_TOO_LARGE;
        }
        memcpy(payloadBuffer, enetEvent.packet->data, enetEvent.packet->dataLength);
        enet_packet_destroy(enetEvent.packet);
        return LUNEX_ENET_OK;
    case ENET_EVENT_TYPE_DISCONNECT:
        event->type = LUNEX_ENET_EVENT_DISCONNECT;
        return LUNEX_ENET_OK;
    case ENET_EVENT_TYPE_CONNECT:
    case ENET_EVENT_TYPE_NONE:
        event->type = LUNEX_ENET_EVENT_NONE;
        return LUNEX_ENET_OK;
    }
    return LUNEX_ENET_ERROR_SERVICE;
}

void lunex_enet_disconnect(LuneXENetConnection *connection) {
    destroy_connection(connection);
}
