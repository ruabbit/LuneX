#ifndef LUNEX_ENET_BRIDGE_H
#define LUNEX_ENET_BRIDGE_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct LuneXENetConnection LuneXENetConnection;

typedef enum LuneXENetResult {
    LUNEX_ENET_OK = 0,
    LUNEX_ENET_ERROR_INVALID_ARGUMENT = -1,
    LUNEX_ENET_ERROR_INITIALIZATION = -2,
    LUNEX_ENET_ERROR_RESOLUTION = -3,
    LUNEX_ENET_ERROR_HOST_CREATION = -4,
    LUNEX_ENET_ERROR_CONNECTION = -5,
    LUNEX_ENET_ERROR_TIMEOUT = -6,
    LUNEX_ENET_ERROR_DISCONNECTED = -7,
    LUNEX_ENET_ERROR_SEND = -8,
    LUNEX_ENET_ERROR_SERVICE = -9,
    LUNEX_ENET_ERROR_PAYLOAD_TOO_LARGE = -10
} LuneXENetResult;

typedef enum LuneXENetEventType {
    LUNEX_ENET_EVENT_NONE = 0,
    LUNEX_ENET_EVENT_RECEIVE = 1,
    LUNEX_ENET_EVENT_DISCONNECT = 2
} LuneXENetEventType;

typedef struct LuneXENetEvent {
    LuneXENetEventType type;
    uint8_t channelID;
    uint32_t data;
    size_t payloadLength;
} LuneXENetEvent;

LuneXENetConnection *lunex_enet_connect(
    const char *host,
    uint16_t port,
    uint8_t channelCount,
    uint32_t connectData,
    uint32_t timeoutMilliseconds,
    LuneXENetResult *result
);

LuneXENetResult lunex_enet_send(
    LuneXENetConnection *connection,
    uint8_t channelID,
    const uint8_t *bytes,
    size_t length,
    bool reliable
);

LuneXENetResult lunex_enet_service(
    LuneXENetConnection *connection,
    uint32_t timeoutMilliseconds,
    uint8_t *payloadBuffer,
    size_t payloadCapacity,
    LuneXENetEvent *event
);

void lunex_enet_disconnect(LuneXENetConnection *connection);

#ifdef __cplusplus
}
#endif

#endif
