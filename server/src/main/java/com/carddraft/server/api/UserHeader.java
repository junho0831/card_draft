package com.carddraft.server.api;

import java.util.UUID;

final class UserHeader {
    private UserHeader() {
    }

    static UUID parse(String value) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException("X-User-Id 헤더가 필요합니다.");
        }
        try {
            return UUID.fromString(value);
        } catch (IllegalArgumentException ex) {
            throw new IllegalArgumentException("X-User-Id 헤더가 UUID 형식이 아닙니다.");
        }
    }
}
