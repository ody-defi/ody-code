// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library CommonTypes {
    struct TimeRange {
        uint64 startAt;
        uint64 endAt;
    }

    struct PageRequest {
        uint32 offset;
        uint32 limit;
    }

    struct PageInfo {
        uint32 offset;
        uint32 limit;
        uint32 total;
    }

    struct EntityMeta {
        bytes32 entityId;
        uint64 createdAt;
        uint64 updatedAt;
    }
}
