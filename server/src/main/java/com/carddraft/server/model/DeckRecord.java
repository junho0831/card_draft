package com.carddraft.server.model;

import java.util.List;
import java.util.UUID;

public record DeckRecord(
        UUID id,
        String name,
        boolean selected,
        List<String> cardIds
) {
}
