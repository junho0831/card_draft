package com.carddraft.server.model;

import java.util.UUID;

public record ProfileView(
        UUID userId,
        String playerName,
        int gold,
        int rankPoints,
        String rankName,
        int ownedCardCount,
        UUID selectedDeckId
) {
}
